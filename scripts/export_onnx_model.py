"""Export a Phase 7 JSON logistic model to ONNX and optionally verify parity.

Exit codes:
    0  model exported (and parity passed when --fixture is given)
    1  model, fixture or output could not be loaded/written
    2  ONNX validation or Python-ONNX parity failed

The exported graph is inference-only: scaler + logistic layer + sigmoid.
No trading, order or account code is present.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

import numpy as np
import pandas as pd

from mt5_ea_ai_lab.experiment_store import sha256_file
from mt5_ea_ai_lab.models import (
    ModelError,
    OnnxExportError,
    compare_python_onnx,
    export_onnx_model,
    load_model,
    save_onnx_metadata,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export the JSON logistic model to ONNX and compare predictions."
    )
    parser.add_argument(
        "--model",
        default=str(REPO_ROOT / "reports" / "ml" / "demo-phase7-ml" / "model.json"),
        help="path to model.json produced by train_ml_baseline.py",
    )
    parser.add_argument(
        "--out-dir",
        default=str(REPO_ROOT / "models" / "candidates" / "demo-phase7-ml"),
        help="directory for model.onnx, metadata and parity reports",
    )
    parser.add_argument(
        "--fixture",
        default=None,
        help="optional CSV containing the model feature columns for parity checking",
    )
    parser.add_argument("--opset", type=int, default=13, help="ONNX opset (default 13)")
    parser.add_argument(
        "--tolerance",
        type=float,
        default=1e-5,
        help="maximum absolute probability difference (default 1e-5)",
    )
    return parser


def _load_fixture(path: Path, feature_names: list[str]) -> np.ndarray:
    try:
        frame = pd.read_csv(path)
    except (FileNotFoundError, OSError, pd.errors.ParserError) as exc:
        raise OnnxExportError(f"cannot read fixture: {exc}") from exc
    missing = [name for name in feature_names if name not in frame.columns]
    if missing:
        raise OnnxExportError(f"fixture is missing feature columns: {missing}")
    if frame.empty:
        raise OnnxExportError("fixture has no rows")
    matrix = frame[feature_names].to_numpy(dtype=float)
    if not np.isfinite(matrix).all():
        raise OnnxExportError("fixture contains non-finite feature values")
    return matrix


def _write_parity(out_dir: Path, comparison: dict) -> None:
    python_values = comparison["python_probabilities"]
    onnx_values = comparison["onnx_probabilities"]
    frame = pd.DataFrame(
        {
            "row": np.arange(len(python_values), dtype=int),
            "python_probability": python_values,
            "onnx_probability": onnx_values,
            "abs_diff": np.abs(np.asarray(python_values) - np.asarray(onnx_values)),
        }
    )
    frame.to_csv(out_dir / "onnx_parity.csv", index=False)
    summary = {
        key: comparison[key]
        for key in ("rows", "tolerance", "max_abs_diff", "mean_abs_diff", "within_tolerance")
    }
    summary["schema_version"] = 1
    (out_dir / "onnx_parity.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    model_path = Path(args.model).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        artifact = load_model(model_path)
        comparison = None
        if args.fixture is not None:
            matrix = _load_fixture(Path(args.fixture).resolve(), artifact["feature_names"])
    except (ModelError, OnnxExportError, OSError) as exc:
        print(f"input_error: {exc}", file=sys.stderr)
        return 1

    onnx_path = out_dir / "model.onnx"
    try:
        metadata = export_onnx_model(
            artifact,
            onnx_path,
            opset=args.opset,
            model_source_sha256=sha256_file(model_path),
        )
    except (OnnxExportError, OSError) as exc:
        print(f"export_error: {exc}", file=sys.stderr)
        return 2

    if args.fixture is not None:
        try:
            comparison = compare_python_onnx(
                artifact, onnx_path, matrix, tolerance=args.tolerance
            )
        except (OnnxExportError, OSError) as exc:
            print(f"onnx_error: {exc}", file=sys.stderr)
            return 2
        _write_parity(out_dir, comparison)
        metadata["parity"] = {
            key: comparison[key]
            for key in (
                "rows",
                "tolerance",
                "max_abs_diff",
                "mean_abs_diff",
                "within_tolerance",
            )
        }

    try:
        save_onnx_metadata(out_dir / "model_metadata.json", metadata)
    except OSError as exc:
        print(f"output_error: {exc}", file=sys.stderr)
        return 1

    print(
        f"onnx_model={onnx_path} sha256={metadata['onnx_sha256']} "
        f"features={len(artifact['feature_names'])} opset={metadata['onnx_opset']}"
    )
    if comparison is not None:
        print(
            f"parity_rows={comparison['rows']} "
            f"max_abs_diff={comparison['max_abs_diff']:.3e} "
            f"tolerance={comparison['tolerance']:.1e} "
            f"status={'pass' if comparison['within_tolerance'] else 'fail'}"
        )
        if not comparison["within_tolerance"]:
            print("parity_error: ONNX and Python predictions differ", file=sys.stderr)
            return 2
    else:
        print("parity_status=not_checked (no --fixture)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
