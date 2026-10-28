from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
from types import ModuleType

import numpy as np
import pytest

from mt5_ea_ai_lab.models import (
    OnnxExportError,
    compare_python_onnx,
    export_onnx_model,
    load_onnx_metadata,
    predict_onnx,
    predict_proba,
    save_model,
)

REPO_ROOT = Path(__file__).resolve().parents[2]


def sample_artifact() -> dict:
    return {
        "schema_version": 1,
        "kind": "logistic_regression",
        "target": "direction",
        "feature_names": ["alpha", "beta", "gamma"],
        "preprocessing": {
            "type": "standard_scaler",
            "mean": [0.1, -0.2, 0.3],
            "scale": [1.0, 2.0, 0.5],
        },
        "coefficients": [0.5, -1.2, 0.8],
        "intercept": 0.05,
        "hyperparameters": {"C": 1.0, "max_iter": 1000, "class_weight": None, "seed": 0},
        "training": {"samples": 100, "positive": 50, "negative": 50},
        "code_version": "0.1.0",
        "dependencies": {"numpy": "test", "pandas": "test", "scikit_learn": "test"},
    }


def sample_features() -> np.ndarray:
    return np.array(
        [
            [0.0, 0.0, 0.0],
            [1.0, -1.0, 2.0],
            [-0.5, 0.25, 0.75],
            [2.0, 3.0, -1.0],
        ],
        dtype=float,
    )


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "export_onnx_model_script",
        REPO_ROOT / "scripts" / "export_onnx_model.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_export_writes_metadata_and_matches_python(tmp_path: Path) -> None:
    artifact = sample_artifact()
    destination = tmp_path / "model.onnx"
    metadata = export_onnx_model(artifact, destination)

    assert destination.is_file()
    payload = destination.read_bytes()
    assert metadata["onnx_sha256"] == hashlib.sha256(payload).hexdigest()
    assert metadata["onnx_size_bytes"] == len(payload)
    assert metadata["onnx_opset"] == 13
    assert metadata["input"]["shape"] == [1, 3]
    assert metadata["input"]["feature_names"] == artifact["feature_names"]
    assert metadata["output"]["shape"] == [1, 1]
    assert metadata["decision_threshold"] == 0.5

    matrix = sample_features()
    comparison = compare_python_onnx(artifact, destination, matrix)
    assert comparison["rows"] == 4
    assert comparison["within_tolerance"] is True
    assert comparison["max_abs_diff"] <= 1e-5

    probabilities = predict_onnx(destination, matrix)
    np.testing.assert_allclose(
        probabilities, predict_proba(artifact, matrix), rtol=0.0, atol=1e-5
    )


def test_metadata_roundtrip_and_default_threshold(tmp_path: Path) -> None:
    artifact = sample_artifact()
    artifact["decision_threshold"] = 0.42
    destination = tmp_path / "model.onnx"
    metadata = export_onnx_model(artifact, destination, opset=13)
    metadata_path = tmp_path / "model_metadata.json"
    metadata_path.write_text(json.dumps(metadata), encoding="utf-8")

    loaded = load_onnx_metadata(metadata_path)
    assert loaded["decision_threshold"] == 0.42
    assert loaded["kind"] == "onnx_logistic_direction"
    assert loaded["model_schema_version"] == 1


def test_predict_onnx_rejects_wrong_shape_and_non_finite(tmp_path: Path) -> None:
    destination = tmp_path / "model.onnx"
    export_onnx_model(sample_artifact(), destination)

    with pytest.raises(OnnxExportError, match="feature columns"):
        predict_onnx(destination, np.zeros((2, 2)))
    with pytest.raises(OnnxExportError, match="non-finite"):
        predict_onnx(destination, np.array([[0.0, 0.0, np.nan]]))


def test_export_rejects_invalid_artifact(tmp_path: Path) -> None:
    artifact = sample_artifact()
    artifact["preprocessing"]["scale"][0] = 0.0
    with pytest.raises(OnnxExportError, match="scale"):
        export_onnx_model(artifact, tmp_path / "model.onnx")


def test_compare_rejects_negative_tolerance(tmp_path: Path) -> None:
    destination = tmp_path / "model.onnx"
    export_onnx_model(sample_artifact(), destination)
    with pytest.raises(OnnxExportError, match="tolerance"):
        compare_python_onnx(sample_artifact(), destination, sample_features(), tolerance=-1.0)


def test_cli_exports_and_checks_fixture(tmp_path: Path) -> None:
    script = load_script()
    model_path = tmp_path / "model.json"
    save_model(model_path, sample_artifact())

    fixture = tmp_path / "fixture.csv"
    matrix = sample_features()
    lines = ["alpha,beta,gamma"]
    for row in matrix:
        lines.append(",".join(str(value) for value in row))
    fixture.write_text("\n".join(lines) + "\n", encoding="utf-8")

    out_dir = tmp_path / "out"
    exit_code = script.main(
        [
            "--model",
            str(model_path),
            "--out-dir",
            str(out_dir),
            "--fixture",
            str(fixture),
        ]
    )

    assert exit_code == 0
    assert (out_dir / "model.onnx").is_file()
    assert (out_dir / "model_metadata.json").is_file()
    parity = json.loads((out_dir / "onnx_parity.json").read_text(encoding="utf-8"))
    assert parity["rows"] == 4
    assert parity["within_tolerance"] is True


def test_cli_rejects_fixture_with_missing_features(tmp_path: Path) -> None:
    script = load_script()
    model_path = tmp_path / "model.json"
    save_model(model_path, sample_artifact())
    fixture = tmp_path / "fixture.csv"
    fixture.write_text("alpha,beta\n1,2\n", encoding="utf-8")

    exit_code = script.main(
        [
            "--model",
            str(model_path),
            "--out-dir",
            str(tmp_path / "out"),
            "--fixture",
            str(fixture),
        ]
    )
    assert exit_code == 1
