from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pandas as pd
import pytest
import yaml

from mt5_ea_ai_lab.experiment_store import ExperimentStore

REPO_ROOT = Path(__file__).resolve().parents[2]
DEMO_DATA = REPO_ROOT / "datasets" / "samples" / "synthetic_ml_demo.csv"


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "run_pipeline_script", REPO_ROOT / "scripts" / "run_pipeline.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def runner() -> ModuleType:
    return load_script()


def _execution() -> dict[str, float]:
    return {
        "initial_equity": 10_000.0,
        "position_units": 10_000.0,
        "point_size": 0.00001,
        "spread_points": 8.0,
        "slippage_points": 1.0,
        "commission_per_side": 1.0,
    }


def write_stage_configs(
    tmp_path: Path,
    *,
    data_path: Path,
    backtest_data_path: Path | None = None,
    ml_data_path: Path | None = None,
) -> tuple[Path, Path, Path]:
    report_dir = tmp_path / "reports"
    db_path = tmp_path / "experiments.sqlite"

    backtest = {
        "experiment_id": "stage-backtest",
        "data": {
            "path": str(backtest_data_path or data_path),
            "symbol": "EURUSD",
            "timeframe": "M5",
            "timezone": "UTC",
            "data_kind": "synthetic",
        },
        "strategy": {
            "fast_period": 8,
            "slow_period": 21,
            "allow_long": True,
            "allow_short": True,
        },
        "execution": {**_execution(), "stop_loss_points": None, "take_profit_points": None},
        "seed": 42,
        "outputs": {"report_dir": str(report_dir), "plot": False},
    }
    ml = {
        "experiment_id": "stage-ml",
        "data": {
            "path": str(ml_data_path or data_path),
            "symbol": "EURUSD",
            "timeframe": "M5",
            "timezone": "UTC",
            "data_kind": "synthetic",
        },
        "features": {
            "ema_fast": 5,
            "ema_slow": 20,
            "return_windows": [1, 3, 5, 10],
            "volatility_window": 10,
            "volume_window": 10,
            "stochastic_window": 14,
        },
        "labels": {"horizon": 3, "min_return": 0.00015},
        "splits": {
            "train_fraction": 0.6,
            "validation_fraction": 0.2,
            "initial_train_fraction": 0.5,
            "folds": 3,
        },
        "model": {"C": 1.0, "max_iter": 1000, "class_weight": None, "seed": 42},
        "execution": _execution(),
        "outputs": {"report_dir": str(report_dir)},
    }
    pipeline = {
        "experiment_id": "pipeline-test",
        "backtest_config": str(tmp_path / "backtest.yaml"),
        "ml_config": str(tmp_path / "ml.yaml"),
        "outputs": {"report_dir": str(report_dir)},
        "store": {"db": str(db_path)},
    }
    (tmp_path / "backtest.yaml").write_text(
        yaml.safe_dump(backtest, sort_keys=False), encoding="utf-8"
    )
    (tmp_path / "ml.yaml").write_text(
        yaml.safe_dump(ml, sort_keys=False), encoding="utf-8"
    )
    pipeline_path = tmp_path / "pipeline.yaml"
    pipeline_path.write_text(
        yaml.safe_dump(pipeline, sort_keys=False), encoding="utf-8"
    )
    return pipeline_path, report_dir, db_path


def write_invalid_dataset(path: Path) -> Path:
    start = pd.Timestamp("2024-01-01T00:00:00Z")
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12]
    rows = []
    previous = closes[0]
    for index, close in enumerate(closes):
        timestamp = start + pd.Timedelta(minutes=5 * index)
        if index == 3:
            timestamp = start + pd.Timedelta(minutes=5 * (index - 1))
        rows.append(
            {
                "timestamp": timestamp.isoformat(),
                "open": previous,
                "high": max(previous, close) + 0.001,
                "low": min(previous, close) - 0.001,
                "close": close,
                "tick_volume": 100,
            }
        )
        previous = close
    path.write_text(pd.DataFrame(rows).to_csv(index=False), encoding="utf-8")
    return path


def test_pipeline_completes_and_records_both_stages(
    runner: ModuleType, tmp_path: Path
) -> None:
    pipeline_path, report_dir, db_path = write_stage_configs(tmp_path, data_path=DEMO_DATA)
    assert runner.main(["--config", str(pipeline_path)]) == 0

    summary_path = report_dir / "pipeline-test" / "pipeline_summary.json"
    report_path = report_dir / "pipeline-test" / "pipeline_report.md"
    assert summary_path.is_file()
    assert report_path.is_file()
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    assert summary["status"] == "completed"
    assert summary["demo"] is True
    assert summary["stages"]["backtest"]["status"] == "completed"
    assert summary["stages"]["backtest"]["metrics"]["bars"] == 1800
    assert summary["stages"]["backtest"]["metrics"]["trade_count"] == 49
    assert summary["stages"]["ml"]["status"] == "completed"
    assert summary["stages"]["ml"]["metrics"]["test_samples"] == 299
    assert len(summary["stages"]["ml"]["model_sha256"]) == 64
    assert "not market performance" in report_path.read_text(encoding="utf-8")

    store = ExperimentStore(db_path)
    try:
        ids = {run.experiment_id for run in store.list_runs(limit=10)}
    finally:
        store.close()
    assert {"pipeline-test-backtest", "pipeline-test-ml"} <= ids


def test_duplicate_pipeline_run_is_rejected_without_overwrite(
    runner: ModuleType, tmp_path: Path
) -> None:
    pipeline_path, report_dir, _ = write_stage_configs(tmp_path, data_path=DEMO_DATA)
    assert runner.main(["--config", str(pipeline_path)]) == 0
    summary_path = report_dir / "pipeline-test" / "pipeline_summary.json"
    before = summary_path.read_bytes()

    assert runner.main(["--config", str(pipeline_path)]) == 4
    assert summary_path.read_bytes() == before


def test_invalid_data_stops_before_ml(runner: ModuleType, tmp_path: Path) -> None:
    dataset = write_invalid_dataset(tmp_path / "invalid.csv")
    pipeline_path, report_dir, _ = write_stage_configs(tmp_path, data_path=dataset)

    assert runner.main(["--config", str(pipeline_path)]) == 2
    summary = json.loads(
        (report_dir / "pipeline-test" / "pipeline_summary.json").read_text(
            encoding="utf-8"
        )
    )
    assert summary["status"] == "invalid_data"
    assert summary["stages"]["backtest"]["status"] == "invalid_data"
    assert summary["stages"]["ml"]["status"] == "skipped"


def test_mismatched_stage_datasets_are_rejected(
    runner: ModuleType, tmp_path: Path
) -> None:
    first = DEMO_DATA
    second = write_invalid_dataset(tmp_path / "other.csv")
    pipeline_path, report_dir, _ = write_stage_configs(
        tmp_path,
        data_path=first,
        backtest_data_path=first,
        ml_data_path=second,
    )

    assert runner.main(["--config", str(pipeline_path)]) == 1
    assert not (report_dir / "pipeline-test" / "pipeline_summary.json").exists()


def test_missing_stage_config_is_rejected(runner: ModuleType, tmp_path: Path) -> None:
    pipeline_path, report_dir, _ = write_stage_configs(tmp_path, data_path=DEMO_DATA)
    config = yaml.safe_load(pipeline_path.read_text(encoding="utf-8"))
    config["backtest_config"] = str(tmp_path / "missing.yaml")
    pipeline_path.write_text(
        yaml.safe_dump(config, sort_keys=False), encoding="utf-8"
    )

    assert runner.main(["--config", str(pipeline_path)]) == 1
    assert not (report_dir / "pipeline-test" / "pipeline_summary.json").exists()
