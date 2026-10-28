"""ONNX export for the JSON logistic-regression artifact.

The graph embeds the scaler and the logistic layer explicitly:

    (features - mean) / scale @ coefficients + intercept -> sigmoid

No Python object is pickled and no scikit-learn converter is required. The
exported model is inference-only; it cannot place orders.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import numpy as np

from mt5_ea_ai_lab import __version__
from mt5_ea_ai_lab.models.logistic import (
    ModelError,
    predict_proba,
    validate_model_artifact,
)

ONNX_SCHEMA_VERSION = 1
ONNX_OPSET = 13
ONNX_IR_VERSION = 8
PARITY_TOLERANCE = 1e-5
INPUT_NAME = "features"
OUTPUT_NAME = "probability"


class OnnxExportError(ValueError):
    """Raised when a model cannot be exported or evaluated safely."""


def _import_onnx() -> Any:
    try:
        import onnx
    except ImportError as exc:  # pragma: no cover - dependency is pinned
        raise OnnxExportError("onnx is required for export") from exc
    return onnx


def _import_runtime() -> Any:
    try:
        import onnxruntime as ort
    except ImportError as exc:  # pragma: no cover - dependency is pinned
        raise OnnxExportError("onnxruntime is required for ONNX inference") from exc
    return ort


def _feature_matrix(X: np.ndarray, feature_count: int) -> np.ndarray:
    matrix = np.asarray(X, dtype=float)
    if matrix.ndim != 2 or matrix.shape[1] != feature_count:
        raise OnnxExportError(
            f"expected a matrix with {feature_count} feature columns"
        )
    if not np.isfinite(matrix).all():
        raise OnnxExportError("feature matrix contains non-finite values")
    return matrix


def build_onnx_model(artifact: dict[str, Any], *, opset: int = ONNX_OPSET) -> Any:
    """Build and validate the ONNX graph for a logistic artifact."""

    try:
        validate_model_artifact(artifact)
    except ModelError as exc:
        raise OnnxExportError(str(exc)) from exc
    if opset <= 0:
        raise OnnxExportError("opset must be positive")

    onnx = _import_onnx()
    from onnx import TensorProto, helper, numpy_helper

    feature_names = list(artifact["feature_names"])
    feature_count = len(feature_names)
    mean = np.asarray(artifact["preprocessing"]["mean"], dtype=np.float32)
    scale = np.asarray(artifact["preprocessing"]["scale"], dtype=np.float32)
    coefficients = np.asarray(artifact["coefficients"], dtype=np.float32).reshape(
        feature_count, 1
    )
    intercept = np.asarray([float(artifact["intercept"])], dtype=np.float32)

    initializers = [
        numpy_helper.from_array(mean, "mean"),
        numpy_helper.from_array(scale, "scale"),
        numpy_helper.from_array(coefficients, "coefficients"),
        numpy_helper.from_array(intercept, "intercept"),
    ]
    nodes = [
        helper.make_node("Sub", [INPUT_NAME, "mean"], ["centered"]),
        helper.make_node("Div", ["centered", "scale"], ["scaled"]),
        helper.make_node("MatMul", ["scaled", "coefficients"], ["logits"]),
        helper.make_node("Add", ["logits", "intercept"], ["biased"]),
        helper.make_node("Sigmoid", ["biased"], [OUTPUT_NAME]),
    ]
    inputs = [
        helper.make_tensor_value_info(
            INPUT_NAME, TensorProto.FLOAT, ["batch", feature_count]
        )
    ]
    outputs = [
        helper.make_tensor_value_info(OUTPUT_NAME, TensorProto.FLOAT, ["batch", 1])
    ]
    graph = helper.make_graph(nodes, "logistic_direction", inputs, outputs, initializers)
    model = helper.make_model(
        graph,
        opset_imports=[helper.make_opsetid("", opset)],
        producer_name="mt5-ea-ai-lab",
        producer_version=__version__,
        doc_string="Standard scaler + logistic sigmoid; inference only.",
    )
    model.ir_version = ONNX_IR_VERSION
    onnx.checker.check_model(model)
    return model


def export_onnx_model(
    artifact: dict[str, Any],
    destination: str | Path,
    *,
    opset: int = ONNX_OPSET,
    model_source_sha256: str | None = None,
) -> dict[str, Any]:
    """Write ``destination`` and return metadata for the exported graph."""

    model = build_onnx_model(artifact, opset=opset)
    target = Path(destination)
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = model.SerializeToString()
    target.write_bytes(payload)

    feature_count = len(artifact["feature_names"])
    metadata = {
        "schema_version": ONNX_SCHEMA_VERSION,
        "kind": "onnx_logistic_direction",
        "onnx_opset": int(opset),
        "ir_version": ONNX_IR_VERSION,
        "input": {
            "name": INPUT_NAME,
            "dtype": "float32",
            "shape": [1, feature_count],
            "feature_names": list(artifact["feature_names"]),
        },
        "output": {
            "name": OUTPUT_NAME,
            "dtype": "float32",
            "shape": [1, 1],
        },
        "preprocessing": "standard_scaler embedded in the graph",
        "decision_threshold": float(artifact.get("decision_threshold", 0.5)),
        "model_schema_version": artifact.get("schema_version"),
        "model_code_version": artifact.get("code_version"),
        "model_sha256": model_source_sha256,
        "onnx_sha256": hashlib.sha256(payload).hexdigest(),
        "onnx_size_bytes": len(payload),
        "parity_tolerance": PARITY_TOLERANCE,
        "code_version": __version__,
        "dependencies": {
            "onnx": _import_onnx().__version__,
            "onnxruntime": _import_runtime().__version__,
            "numpy": np.__version__,
        },
        "notes": "Inference only; the graph contains no trading or order logic.",
    }
    return metadata


def save_onnx_metadata(path: str | Path, metadata: dict[str, Any]) -> Path:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(metadata, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return destination


def load_onnx_metadata(path: str | Path) -> dict[str, Any]:
    source = Path(path)
    try:
        metadata = json.loads(source.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise OnnxExportError(f"ONNX metadata not found: {source}") from exc
    except json.JSONDecodeError as exc:
        raise OnnxExportError(f"invalid ONNX metadata JSON: {exc}") from exc
    if not isinstance(metadata, dict):
        raise OnnxExportError("ONNX metadata must be a JSON object")
    if metadata.get("schema_version") != ONNX_SCHEMA_VERSION:
        raise OnnxExportError("unsupported ONNX metadata schema_version")
    return metadata


def _session(onnx_path: str | Path) -> Any:
    ort = _import_runtime()
    try:
        return ort.InferenceSession(
            str(onnx_path), providers=["CPUExecutionProvider"]
        )
    except Exception as exc:  # onnxruntime raises several concrete types
        raise OnnxExportError(f"cannot open ONNX model: {exc}") from exc


def predict_onnx(onnx_path: str | Path, X: np.ndarray) -> np.ndarray:
    """Return class-1 probabilities using ONNX Runtime."""

    session = _session(onnx_path)
    inputs = session.get_inputs()
    outputs = session.get_outputs()
    if len(inputs) != 1 or len(outputs) != 1:
        raise OnnxExportError("expected exactly one input and one output")
    input_meta = inputs[0]
    feature_count = input_meta.shape[-1]
    if not isinstance(feature_count, int):
        raise OnnxExportError("ONNX input feature count is not fixed")
    matrix = _feature_matrix(X, feature_count)
    try:
        result = session.run(
            [outputs[0].name], {input_meta.name: matrix.astype(np.float32)}
        )
    except Exception as exc:
        raise OnnxExportError(f"ONNX inference failed: {exc}") from exc
    probabilities = np.asarray(result[0], dtype=float).reshape(-1)
    if probabilities.shape[0] != matrix.shape[0]:
        raise OnnxExportError("ONNX output row count does not match input")
    if not np.isfinite(probabilities).all():
        raise OnnxExportError("ONNX output contains non-finite values")
    if ((probabilities < 0.0) | (probabilities > 1.0)).any():
        raise OnnxExportError("ONNX output is outside [0, 1]")
    return probabilities


def compare_python_onnx(
    artifact: dict[str, Any],
    onnx_path: str | Path,
    X: np.ndarray,
    *,
    tolerance: float = PARITY_TOLERANCE,
) -> dict[str, Any]:
    """Compare NumPy and ONNX predictions on the same feature matrix."""

    if tolerance < 0.0:
        raise OnnxExportError("tolerance must be non-negative")
    matrix = _feature_matrix(X, len(artifact["feature_names"]))
    try:
        python_probabilities = predict_proba(artifact, matrix)
    except ModelError as exc:
        raise OnnxExportError(str(exc)) from exc
    onnx_probabilities = predict_onnx(onnx_path, matrix)
    differences = np.abs(python_probabilities - onnx_probabilities)
    max_difference = float(differences.max()) if differences.size else 0.0
    return {
        "rows": int(matrix.shape[0]),
        "tolerance": float(tolerance),
        "max_abs_diff": max_difference,
        "mean_abs_diff": float(differences.mean()) if differences.size else 0.0,
        "within_tolerance": bool(max_difference <= tolerance),
        "python_probabilities": python_probabilities.tolist(),
        "onnx_probabilities": onnx_probabilities.tolist(),
    }
