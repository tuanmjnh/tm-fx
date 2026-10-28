from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import numpy as np
import pandas as pd
import pytest
import yaml

from mt5_ea_ai_lab.experiment_store import ExperimentStore

REPO_ROOT = Path(__file__).resolve().parents[2]


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "train_ml_baseline_script",
        REPO_ROOT / "scripts" / "train_ml_baseline.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def cli() -> ModuleType:
    return load_script()


def make_frame(rows: int = 400) -> pd.DataFrame:
    phase = np.arange(rows, dtype=float)
    close = (
        1.10
        + 0.0015 * np.sin(phase / 2.5)
        + 0.0008 * np.sin(phase / 11.0)
        + 0.0002 * np.cos(phase / 1.3)
    )
    open_price = np.r_[close[0], close[:-1]]
    high = np.maximum(open_price, close) + 0.0003
    low = np.minimum(open_price, close) - 0.0003
    frame = pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=rows, freq="5min", tz="UTC"),
            "open": np.round(open_price, 5),
            "high": np.round(high, 5),
            "low": np.round(low, 5),
            "close": np.round(close, 5),
            "tick_volume": 80 + (np.arange(rows) * 13 % 60),
            "spread": 10,
            "real_volume": 0,
            "symbol": "EURUSD",
            "timeframe": "M5",
        }
    )
    frame["high"] = frame[["open", "high", "close", "low"]].max(axis=1)
    frame["low"] = frame[["open", "high", "close", "low"]].min(axis=1)
    return frame


def write_dataset(tmp_path: Path, frame: pd.DataFrame, name: str = "data.csv") -> Path:
    path = tmp_path / name
    output = frame.copy()
    output["timestamp"] = output["timestamp"].map(lambda value: value.isoformat())
    output.to_csv(path, index=False)
    return path


def write_config(
    tmp_path: Path,
    data_path: Path,
    *,
    experiment_id: str = "ml-test",
    report_dir: Path | None = None,
    execution_extra: dict[str, object] | None = None,
) -> Path:
    execution = {
        "initial_equity": 10_000.0,
        "position_units": 10_000.0,
        "point_size": 0.00001,
        "spread_points": 8.0,
        "slippage_points": 1.0,
        "commission_per_side": 1.0,
    }
    if execution_extra:
        execution.update(execution_extra)
    config = {
        "experiment_id": experiment_id,
        "data": {
            "path": str(data_path),
            "symbol": "EURUSD",
            "timeframe": "M5",
            "timezone": "UTC",
            "data_kind": "synthetic",
        },
        "features": {},
        "labels": {"horizon": 3, "min_return": 0.0001},
        "splits": {"train_fraction": 0.6, "validation_fraction": 0.2, "folds": 3},
        "model": {"C": 1.0, "max_iter": 500, "seed": 42},
        "execution": execution,
        "outputs": {"report_dir": str(report_dir or (tmp_path / "reports"))},
        "notes": "test fixture",
    }
    path = tmp_path / "config.yaml"
    path.write_text(yaml.safe_dump(config, sort_keys=False), encoding="utf-8")
    return path


def test_cli_completes_and_writes_auditable_artifacts(cli: ModuleType, tmp_path: Path) -> None:
    dataset = write_dataset(tmp_path, make_frame())
    config = write_config(tmp_path, dataset)
    out_dir = tmp_path / "reports"
    code = cli.main(["--config", str(config), "--out-dir", str(out_dir)])
    assert code == 0

    run_dir = out_dir / "ml-test"
    summary = json.loads((run_dir / "summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "completed"
    assert all(summary["split"]["checks"].values())
    assert summary["experiment_id"] == "ml-test"
    assert summary["model_sha256"]
    assert summary["classification"]["test"]["samples"] > 0
    assert summary["classification"]["test"]["roc_auc"] is not None
    assert summary["strategy"]["buy_and_hold"] is not None
    assert summary["warnings"]
    assert (run_dir / "model.json").is_file()
    assert (run_dir / "model_card.md").is_file()
    assert (run_dir / "predictions.csv").is_file()
    assert (run_dir / "feature_schema.json").is_file()
    assert (run_dir / "label_schema.json").is_file()
    assert (run_dir / "split_plan.json").is_file()
    card = (run_dir / "model_card.md").read_text(encoding="utf-8")
    assert "not evidence of live profitability" in card
    assert "Synthetic" in card

    predictions = pd.read_csv(run_dir / "predictions.csv")
    assert len(predictions) == summary["classification"]["test"]["samples"]
    assert set(predictions.columns) >= {"timestamp", "bar_index", "probability", "predicted"}


def test_cli_is_reproducible_for_same_config(cli: ModuleType, tmp_path: Path) -> None:
    dataset = write_dataset(tmp_path, make_frame())
    config = write_config(tmp_path, dataset)
    first = tmp_path / "first"
    second = tmp_path / "second"
    assert cli.main(["--config", str(config), "--out-dir", str(first)]) == 0
    assert cli.main(["--config", str(config), "--out-dir", str(second)]) == 0
    one = json.loads((first / "ml-test" / "summary.json").read_text(encoding="utf-8"))
    two = json.loads((second / "ml-test" / "summary.json").read_text(encoding="utf-8"))
    assert one["model_sha256"] == two["model_sha256"]
    assert one["classification"]["test"] == two["classification"]["test"]
    assert one["threshold"] == two["threshold"]


def test_cli_invalid_data_exits_2(cli: ModuleType, tmp_path: Path) -> None:
    frame = make_frame()
    frame.loc[10, "timestamp"] = frame.loc[9, "timestamp"]
    dataset = write_dataset(tmp_path, frame)
    config = write_config(tmp_path, dataset, experiment_id="invalid-data")
    out_dir = tmp_path / "reports"
    code = cli.main(["--config", str(config), "--out-dir", str(out_dir)])
    assert code == 2
    summary = json.loads((out_dir / "invalid-data" / "summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "invalid_data"
    assert summary["data_validation"]["errors"] >= 1


def test_cli_small_dataset_fails_safely(cli: ModuleType, tmp_path: Path) -> None:
    dataset = write_dataset(tmp_path, make_frame(rows=25))
    config = write_config(tmp_path, dataset, experiment_id="too-small")
    out_dir = tmp_path / "reports"
    code = cli.main(["--config", str(config), "--out-dir", str(out_dir)])
    assert code == 3
    summary = json.loads((out_dir / "too-small" / "summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "failed"
    assert summary["error"].startswith("training_error:")


def test_experiment_id_requires_store(cli: ModuleType, tmp_path: Path) -> None:
    dataset = write_dataset(tmp_path, make_frame(rows=60))
    config = write_config(tmp_path, dataset)
    code = cli.main(
        ["--config", str(config), "--experiment-id", "override", "--out-dir", str(tmp_path)]
    )
    assert code == 1


def test_store_rejects_duplicate_without_overwrite(cli: ModuleType, tmp_path: Path) -> None:
    dataset = write_dataset(tmp_path, make_frame())
    config = write_config(tmp_path, dataset, experiment_id="store-run")
    db = tmp_path / "ml.sqlite"
    out_dir = tmp_path / "reports"
    args = [
        "--config",
        str(config),
        "--out-dir",
        str(out_dir),
        "--store",
        "--db",
        str(db),
    ]
    assert cli.main(args) == 0
    assert cli.main(args) == 4
    store = ExperimentStore(db)
    try:
        run = store.get_run("store-run")
        assert run.status == "completed"
        assert any(artifact.name == "model" for artifact in run.artifacts)
        assert any(artifact.name == "model_card" for artifact in run.artifacts)
    finally:
        store.close()


def test_ml_config_rejects_trailing_stop(cli: ModuleType, tmp_path: Path) -> None:
    dataset = write_dataset(tmp_path, make_frame())
    config = write_config(
        tmp_path,
        dataset,
        execution_extra={"trailing_stop_points": 100.0},
    )

    assert cli.main(["--config", str(config), "--out-dir", str(tmp_path / "reports")]) == 1
