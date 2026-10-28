from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

from mt5_ea_ai_lab.experiment_store import (
    ComparisonError,
    compare_ids,
    compare_runs,
    write_comparison,
)

CONFIG_HASH = "a" * 64
DATA_HASH = "b" * 64
COMMIT = "c" * 40

BASE_METRICS = {
    "bars": 8,
    "final_equity": 10_000.0,
    "net_profit": 0.0,
    "total_return": 0.0,
    "trade_count": 2,
    "win_rate": 0.5,
    "profit_factor": 1.5,
    "average_trade": 0.0,
    "max_drawdown": 100.0,
    "max_drawdown_pct": 0.01,
    "exposure_ratio": 0.25,
    "total_commission": 10.0,
}


def make_record(experiment_id: str = "base", **overrides: object) -> dict[str, object]:
    values: dict[str, object] = {
        "experiment_id": experiment_id,
        "status": "completed",
        "config_hash": CONFIG_HASH,
        "data_fingerprint": DATA_HASH,
        "code_version": "0.1.0",
        "git_commit": COMMIT,
        "git_dirty": False,
        "data_kind": "synthetic",
        "symbol": "EURUSD",
        "timeframe": "M5",
        "metrics": dict(BASE_METRICS),
    }
    values.update(overrides)
    return values


def test_comparable_runs_produce_metric_deltas() -> None:
    baseline = make_record()
    run = make_record(
        "candidate",
        metrics={
            **BASE_METRICS,
            "final_equity": 10_200.0,
            "net_profit": 200.0,
            "total_return": 0.02,
            "trade_count": 3,
            "win_rate": 2 / 3,
            "profit_factor": 2.0,
            "max_drawdown": 150.0,
            "exposure_ratio": 0.5,
        },
    )

    report = compare_runs(baseline, run)

    assert report["status"] == "comparable"
    assert report["reasons"] == []
    assert report["baseline"]["experiment_id"] == "base"
    assert report["run"]["experiment_id"] == "candidate"
    rows = {row["metric"]: row for row in report["metrics"]}
    assert rows["final_equity"]["delta"] == 200.0
    assert rows["final_equity"]["delta_pct"] == pytest.approx(0.02)
    assert rows["trade_count"]["delta"] == 1
    assert rows["max_drawdown"]["delta"] == 50.0
    assert rows["average_trade"]["delta"] == 0.0


def test_non_completed_run_is_not_comparable() -> None:
    report = compare_runs(make_record(), make_record("candidate", status="failed"))

    assert report["status"] == "not_comparable"
    assert "run_status:failed" in report["reasons"]


def test_config_data_and_metrics_mismatches_are_blocking() -> None:
    report = compare_runs(
        make_record(),
        make_record("candidate", config_hash="d" * 64),
    )
    assert "config_hash_mismatch" in report["reasons"]

    report = compare_runs(
        make_record(),
        make_record("candidate", data_fingerprint="e" * 64),
    )
    assert "data_fingerprint_mismatch" in report["reasons"]

    report = compare_runs(
        make_record(data_fingerprint=None),
        make_record("candidate", data_fingerprint=None),
    )
    assert "data_fingerprint_mismatch" in report["reasons"]

    report = compare_runs(
        make_record(metrics=None),
        make_record("candidate"),
    )
    assert "baseline_missing_metrics" in report["reasons"]

    report = compare_runs(
        make_record(metrics="not a mapping"),
        make_record("candidate"),
    )
    assert "baseline_missing_metrics" in report["reasons"]

    report = compare_runs(
        make_record(config_hash=None),
        make_record("candidate", config_hash=None),
    )
    assert "config_hash_mismatch" in report["reasons"]

    report = compare_runs(
        make_record(code_version=None),
        make_record("candidate", code_version=None),
    )
    assert "code_version_mismatch" in report["reasons"]


def test_non_finite_metric_values_are_omitted(tmp_path: Path) -> None:
    baseline = make_record(metrics={**BASE_METRICS, "final_equity": float("nan")})
    run = make_record(
        "candidate", metrics={**BASE_METRICS, "final_equity": float("inf")}
    )

    report = compare_runs(baseline, run)
    row = {item["metric"]: item for item in report["metrics"]}["final_equity"]

    assert row == {
        "metric": "final_equity",
        "baseline": None,
        "run": None,
        "delta": None,
        "delta_pct": None,
    }
    artifacts = write_comparison(report, tmp_path / "comparison")
    payload = json.loads(artifacts["json"].read_text(encoding="utf-8"))
    assert payload["baseline"]["metrics"]["final_equity"] is None


def test_code_version_and_commit_mismatches_are_blocking() -> None:
    report = compare_runs(
        make_record(),
        make_record("candidate", code_version="0.2.0"),
    )
    assert "code_version_mismatch" in report["reasons"]

    report = compare_runs(
        make_record(),
        make_record("candidate", git_commit="f" * 40),
    )
    assert "git_commit_mismatch" in report["reasons"]


def test_warnings_for_dirty_unknown_and_synthetic_state() -> None:
    report = compare_runs(
        make_record(git_dirty=True),
        make_record("candidate", git_commit=None),
    )

    assert report["status"] == "comparable"
    assert "dirty_worktree:base" in report["warnings"]
    assert "unknown_git_commit" in report["warnings"]
    assert "synthetic_data" in report["warnings"]


def test_missing_metric_values_do_not_produce_deltas() -> None:
    baseline = make_record(metrics={**BASE_METRICS, "profit_factor": None})
    run = make_record("candidate", metrics={**BASE_METRICS, "profit_factor": 2.0})

    rows = {row["metric"]: row for row in compare_runs(baseline, run)["metrics"]}

    assert rows["profit_factor"] == {
        "metric": "profit_factor",
        "baseline": None,
        "run": 2.0,
        "delta": None,
        "delta_pct": None,
    }


def test_write_comparison_creates_json_csv_and_markdown(tmp_path: Path) -> None:
    report = compare_runs(make_record(), make_record("candidate"))

    artifacts = write_comparison(report, tmp_path / "comparison")

    assert artifacts["json"].is_file()
    assert artifacts["csv"].is_file()
    assert artifacts["markdown"].is_file()
    payload = json.loads(artifacts["json"].read_text(encoding="utf-8"))
    assert payload["status"] == "comparable"
    assert payload["metrics"]

    with artifacts["csv"].open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    assert rows[0] == ["metric", "baseline", "run", "delta", "delta_pct"]
    assert rows[1][1] == "8"

    markdown = artifacts["markdown"].read_text(encoding="utf-8")
    assert "`comparable`" in markdown
    assert "| final_equity |" in markdown
    assert "not evidence of future performance" in markdown


def test_compare_ids_is_stable() -> None:
    assert compare_ids("base-1", "run-2") == "base-1__vs__run-2"


def test_rejects_non_record_input() -> None:
    with pytest.raises(ComparisonError):
        compare_runs("not a record", make_record())
