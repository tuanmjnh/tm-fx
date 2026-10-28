from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from types import ModuleType

import pytest

from mt5_ea_ai_lab.experiment_store import ExperimentStore, RunMetadata

REPO_ROOT = Path(__file__).resolve().parents[2]


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "compare_experiments_script",
        REPO_ROOT / "scripts" / "compare_experiments.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def comparator() -> ModuleType:
    return load_script()


def seed_run(
    store: ExperimentStore,
    experiment_id: str,
    *,
    config_hash: str = "a" * 64,
    data_fingerprint: str = "b" * 64,
    code_version: str = "0.1.0",
    final_equity: float = 10_000.0,
) -> None:
    store.start_run(
        RunMetadata(
            experiment_id=experiment_id,
            config_path="configs/backtest.example.yaml",
            config={"strategy": {"fast_period": 2, "slow_period": 3}},
            config_hash=config_hash,
            code_version=code_version,
            data_fingerprint=data_fingerprint,
            data_kind="synthetic",
            symbol="EURUSD",
            timeframe="M5",
            seed=42,
            git_commit="c" * 40,
            git_dirty=False,
        )
    )
    store.complete_run(
        experiment_id,
        {
            "bars": 8,
            "final_equity": final_equity,
            "net_profit": final_equity - 10_000.0,
            "total_return": final_equity / 10_000.0 - 1.0,
            "trade_count": 1,
            "win_rate": 1.0,
            "profit_factor": None,
            "average_trade": 294.6,
            "max_drawdown": 0.0,
            "max_drawdown_pct": 0.0,
            "exposure_ratio": 0.25,
            "total_commission": 5.0,
        },
    )


def test_comparable_runs_write_reports(
    comparator: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    db_path = tmp_path / "experiments.sqlite"
    with ExperimentStore(db_path) as store:
        seed_run(store, "base")
        seed_run(store, "candidate")
    out_dir = tmp_path / "comparison"

    exit_code = comparator.main(
        [
            "--db",
            str(db_path),
            "--baseline",
            "base",
            "--run",
            "candidate",
            "--out-dir",
            str(out_dir),
        ]
    )

    assert exit_code == 0
    output = capsys.readouterr().out
    assert "comparison=comparable" in output
    assert "warnings=1" in output
    payload = json.loads((out_dir / "comparison.json").read_text(encoding="utf-8"))
    assert payload["status"] == "comparable"
    assert payload["metrics"]
    assert (out_dir / "comparison.csv").is_file()
    assert "`comparable`" in (out_dir / "comparison.md").read_text(encoding="utf-8")


def test_different_config_is_not_comparable(
    comparator: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    db_path = tmp_path / "experiments.sqlite"
    with ExperimentStore(db_path) as store:
        seed_run(store, "base")
        seed_run(store, "candidate", config_hash="d" * 64)

    exit_code = comparator.main(
        [
            "--db",
            str(db_path),
            "--baseline",
            "base",
            "--run",
            "candidate",
            "--out-dir",
            str(tmp_path / "comparison"),
        ]
    )

    assert exit_code == 1
    output = capsys.readouterr().out
    assert "comparison=not_comparable" in output
    assert "reason=config_hash_mismatch" in output


def test_missing_run_returns_2(
    comparator: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    db_path = tmp_path / "experiments.sqlite"
    with ExperimentStore(db_path) as store:
        seed_run(store, "base")

    exit_code = comparator.main(
        [
            "--db",
            str(db_path),
            "--baseline",
            "base",
            "--run",
            "missing",
            "--out-dir",
            str(tmp_path / "comparison"),
        ]
    )

    assert exit_code == 2
    assert "run_not_found: missing" in capsys.readouterr().err


def test_missing_database_returns_2(
    comparator: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = comparator.main(
        [
            "--db",
            str(tmp_path / "missing.sqlite"),
            "--baseline",
            "base",
            "--run",
            "candidate",
        ]
    )

    assert exit_code == 2
    assert "database not found" in capsys.readouterr().err


def test_invalid_ids_are_rejected_before_path_use(
    comparator: ModuleType, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    db_path = tmp_path / "experiments.sqlite"
    with ExperimentStore(db_path) as store:
        seed_run(store, "base")

    exit_code = comparator.main(
        [
            "--db",
            str(db_path),
            "--baseline",
            "base",
            "--run",
            "../escape",
        ]
    )

    assert exit_code == 2
    assert "input_error" in capsys.readouterr().err
    assert not (tmp_path / "escape").exists()
