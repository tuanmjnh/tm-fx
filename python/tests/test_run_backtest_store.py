from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pandas as pd
import pytest
import yaml

from mt5_ea_ai_lab.backtest import BacktestInputError
from mt5_ea_ai_lab.experiment_store import ExperimentStore, sha256_file

REPO_ROOT = Path(__file__).resolve().parents[2]
CLOSES = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12]


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "run_backtest_script", REPO_ROOT / "scripts" / "run_backtest.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def runner() -> ModuleType:
    return load_script()


def write_dataset(path: Path, *, duplicate_timestamp: bool = False) -> Path:
    start = pd.Timestamp("2024-01-01T00:00:00Z")
    rows = []
    previous_close = CLOSES[0]
    for index, close in enumerate(CLOSES):
        timestamp = start + pd.Timedelta(minutes=5 * index)
        if duplicate_timestamp and index == 3:
            timestamp = start + pd.Timedelta(minutes=5 * (index - 1))
        open_price = previous_close
        rows.append(
            {
                "timestamp": timestamp.isoformat(),
                "open": open_price,
                "high": max(open_price, close) + 0.001,
                "low": min(open_price, close) - 0.001,
                "close": close,
                "tick_volume": 100,
            }
        )
        previous_close = close
    path.write_text(pd.DataFrame(rows).to_csv(index=False), encoding="utf-8")
    return path


def write_config(
    path: Path,
    *,
    data_path: Path,
    report_dir: Path,
    experiment_id: str = "cli-exp",
    execution_extra: dict[str, object] | None = None,
) -> Path:
    execution = {
        "initial_equity": 10_000.0,
        "position_units": 10_000.0,
        "point_size": 0.00001,
        "spread_points": 2.0,
        "slippage_points": 1.0,
        "commission_per_side": 2.5,
        "stop_loss_points": None,
        "take_profit_points": None,
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
        "strategy": {
            "fast_period": 2,
            "slow_period": 3,
            "allow_long": True,
            "allow_short": True,
        },
        "execution": execution,
        "seed": 42,
        "outputs": {"report_dir": str(report_dir), "plot": False},
        "notes": "cli integration test",
    }
    path.write_text(yaml.safe_dump(config, sort_keys=False), encoding="utf-8")
    return path


def test_store_success_creates_completed_run(runner: ModuleType, tmp_path: Path) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "reports",
    )
    db_path = tmp_path / "experiments.sqlite"

    exit_code = runner.main(
        [
            "--config",
            str(config_path),
            "--store",
            "--db",
            str(db_path),
            "--experiment-id",
            "cli-a",
            "--out-dir",
            str(tmp_path / "out"),
        ]
    )

    assert exit_code == 0
    report_dir = tmp_path / "out" / "cli-a"
    for name in (
        "summary.json",
        "trades.csv",
        "equity.csv",
        "signals.csv",
        "validation.json",
        "validation.csv",
    ):
        assert (report_dir / name).is_file()

    summary = json.loads((report_dir / "summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "completed"
    assert summary["experiment_store"]["config_hash"]
    assert summary["experiment_store"]["data_fingerprint"] == sha256_file(data_path)

    with ExperimentStore(db_path) as store:
        record = store.get_run("cli-a")

    assert record is not None
    assert record.status == "completed"
    assert record.metrics is not None
    assert record.metrics["final_equity"] == pytest.approx(10_294.60)
    assert record.data_fingerprint == sha256_file(data_path)
    assert record.report_dir == str(report_dir)
    assert {artifact.name for artifact in record.artifacts} == {
        "summary",
        "trades",
        "equity",
        "signals",
        "validation_json",
        "validation_csv",
    }
    assert all(artifact.sha256 for artifact in record.artifacts)


def test_duplicate_run_returns_4_without_overwriting(
    runner: ModuleType, tmp_path: Path
) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "reports",
    )
    db_path = tmp_path / "experiments.sqlite"
    arguments = [
        "--config",
        str(config_path),
        "--store",
        "--db",
        str(db_path),
        "--experiment-id",
        "cli-a",
        "--out-dir",
        str(tmp_path / "out"),
    ]
    assert runner.main(arguments) == 0

    summary_path = tmp_path / "out" / "cli-a" / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    summary["sentinel"] = "do-not-overwrite"
    summary_path.write_text(json.dumps(summary), encoding="utf-8")
    with ExperimentStore(db_path) as store:
        before = store.get_run("cli-a")

    assert runner.main(arguments) == 4

    assert json.loads(summary_path.read_text(encoding="utf-8"))["sentinel"] == (
        "do-not-overwrite"
    )
    with ExperimentStore(db_path) as store:
        after = store.get_run("cli-a")
        events = store.list_events("cli-a")
    assert after == before
    assert len(events) == 2


def test_invalid_data_is_recorded(runner: ModuleType, tmp_path: Path) -> None:
    data_path = write_dataset(tmp_path / "data.csv", duplicate_timestamp=True)
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "reports",
    )
    db_path = tmp_path / "experiments.sqlite"

    exit_code = runner.main(
        [
            "--config",
            str(config_path),
            "--store",
            "--db",
            str(db_path),
            "--experiment-id",
            "cli-invalid",
            "--out-dir",
            str(tmp_path / "out"),
        ]
    )

    assert exit_code == 2
    with ExperimentStore(db_path) as store:
        record = store.get_run("cli-invalid")
    assert record is not None
    assert record.status == "invalid_data"
    assert record.error is not None
    assert record.error.startswith("invalid_data:")
    assert record.validation is not None
    assert record.validation["errors"] > 0
    assert {artifact.name for artifact in record.artifacts} == {
        "summary",
        "validation_json",
        "validation_csv",
    }
    assert not (tmp_path / "out" / "cli-invalid" / "trades.csv").exists()


def test_load_error_is_recorded(runner: ModuleType, tmp_path: Path) -> None:
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=tmp_path / "missing.csv",
        report_dir=tmp_path / "reports",
    )
    db_path = tmp_path / "experiments.sqlite"

    exit_code = runner.main(
        [
            "--config",
            str(config_path),
            "--store",
            "--db",
            str(db_path),
            "--experiment-id",
            "cli-missing",
            "--out-dir",
            str(tmp_path / "out"),
        ]
    )

    assert exit_code == 1
    with ExperimentStore(db_path) as store:
        record = store.get_run("cli-missing")
    assert record is not None
    assert record.status == "failed"
    assert record.data_fingerprint is None
    assert record.error is not None
    assert record.error.startswith("load_error:")
    assert [artifact.name for artifact in record.artifacts] == ["summary"]


def test_without_store_keeps_original_report_layout(
    runner: ModuleType, tmp_path: Path
) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "reports",
    )
    db_path = tmp_path / "experiments.sqlite"

    exit_code = runner.main(
        [
            "--config",
            str(config_path),
            "--out-dir",
            str(tmp_path / "out"),
        ]
    )

    assert exit_code == 0
    assert (tmp_path / "out" / "summary.json").is_file()
    assert not (tmp_path / "out" / "cli-exp").exists()
    assert not db_path.exists()


def test_experiment_id_requires_store(runner: ModuleType, tmp_path: Path) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "reports",
    )

    exit_code = runner.main(
        ["--config", str(config_path), "--experiment-id", "cli-a"]
    )

    assert exit_code == 1


def test_invalid_experiment_id_is_rejected_before_creating_db(
    runner: ModuleType, tmp_path: Path
) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "reports",
    )
    db_path = tmp_path / "experiments.sqlite"

    exit_code = runner.main(
        [
            "--config",
            str(config_path),
            "--store",
            "--db",
            str(db_path),
            "--experiment-id",
            "../escape",
        ]
    )

    assert exit_code == 1
    assert not db_path.exists()


def test_load_config_parses_trailing_stop_fields(
    runner: ModuleType, tmp_path: Path
) -> None:
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=tmp_path / "data.csv",
        report_dir=tmp_path / "reports",
        execution_extra={
            "trailing_stop_points": 150.0,
            "trailing_activation_points": 50.0,
        },
    )

    config = runner.load_config(config_path)

    assert config["execution"].trailing_stop_points == pytest.approx(150.0)
    assert config["execution"].trailing_activation_points == pytest.approx(50.0)


def test_load_config_rejects_activation_without_trailing(
    runner: ModuleType, tmp_path: Path
) -> None:
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=tmp_path / "data.csv",
        report_dir=tmp_path / "reports",
        execution_extra={"trailing_activation_points": 50.0},
    )

    with pytest.raises(BacktestInputError, match="requires trailing_stop_points"):
        runner.load_config(config_path)
