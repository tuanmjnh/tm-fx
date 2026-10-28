from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.data.loader import load_ohlcv
from mt5_ea_ai_lab.validation import ValidationReport, validate_ohlcv

FIXTURES = Path(__file__).parent / "fixtures"
FIXTURE = FIXTURES / "synthetic_eurusd_m5.csv"


@pytest.fixture()
def dataset():
    frame, metadata = load_ohlcv(FIXTURE, timezone="UTC", data_kind="synthetic")
    return frame, metadata


def codes(report: ValidationReport) -> set[str]:
    return {issue.code for issue in report.issues}


def test_valid_fixture_passes_with_synthetic_label(dataset) -> None:
    frame, metadata = dataset

    report = validate_ohlcv(frame, metadata=metadata)

    assert report.passed
    assert report.errors == []
    assert "synthetic_dataset" in codes(report)
    assert report.stats["duplicate_timestamps"] == 0
    assert report.stats["out_of_order_timestamps"] == 0
    assert report.stats["expected_step_seconds"] == 300.0
    assert report.stats["gap_count"] == 0
    assert report.metadata["data_kind"] == "synthetic"


def test_empty_dataset_fails() -> None:
    report = validate_ohlcv(pd.DataFrame(), metadata={"data_kind": "unknown"})

    assert not report.passed
    assert "empty_dataset" in codes(report)
    assert report.row_count == 0


def test_missing_columns_fail(dataset) -> None:
    frame, metadata = dataset

    report = validate_ohlcv(frame.drop(columns=["close"]), metadata=metadata)

    assert not report.passed
    issue = next(issue for issue in report.issues if issue.code == "missing_columns")
    assert issue.details["missing_columns"] == ["close"]


def test_duplicate_timestamps_fail(dataset) -> None:
    frame, metadata = dataset
    duplicated = pd.concat([frame, frame.iloc[[0]]], ignore_index=True)

    report = validate_ohlcv(duplicated, metadata=metadata)

    assert not report.passed
    issue = next(issue for issue in report.issues if issue.code == "duplicate_timestamps")
    assert issue.count == 1


def test_out_of_order_timestamps_fail(dataset) -> None:
    frame, metadata = dataset
    shuffled = frame.iloc[[0, 2, 1, 3, 4, 5]].reset_index(drop=True)

    report = validate_ohlcv(shuffled, metadata=metadata)

    assert not report.passed
    issue = next(
        issue for issue in report.issues if issue.code == "out_of_order_timestamps"
    )
    assert issue.count == 1


def test_invalid_timestamps_fail(dataset) -> None:
    frame, metadata = dataset
    broken = frame.copy()
    broken.loc[0, "timestamp"] = pd.NaT

    report = validate_ohlcv(broken, metadata=metadata)

    assert not report.passed
    assert "invalid_timestamps" in codes(report)


def test_inconsistent_high_fails(dataset) -> None:
    frame, metadata = dataset
    broken = frame.copy()
    broken.loc[0, "high"] = broken.loc[0, "open"] - 0.001

    report = validate_ohlcv(broken, metadata=metadata)

    assert not report.passed
    assert "ohlc_high_inconsistent" in codes(report)


def test_inconsistent_low_fails(dataset) -> None:
    frame, metadata = dataset
    broken = frame.copy()
    broken.loc[0, "low"] = broken.loc[0, "high"] + 0.001

    report = validate_ohlcv(broken, metadata=metadata)

    assert not report.passed
    assert "ohlc_low_inconsistent" in codes(report)


def test_non_finite_values_fail(dataset) -> None:
    frame, metadata = dataset
    broken = frame.copy()
    broken.loc[0, "close"] = np.inf
    broken.loc[1, "open"] = np.nan

    report = validate_ohlcv(broken, metadata=metadata)

    assert not report.passed
    issue = next(issue for issue in report.issues if issue.code == "non_finite_values")
    assert issue.details["columns"]["close"] == 1
    assert issue.details["columns"]["open"] == 1


def test_non_positive_prices_fail(dataset) -> None:
    frame, metadata = dataset
    broken = frame.copy()
    broken.loc[0, "open"] = 0.0

    report = validate_ohlcv(broken, metadata=metadata)

    assert not report.passed
    assert "non_positive_prices" in codes(report)


def test_negative_volume_fails(dataset) -> None:
    frame, metadata = dataset
    broken = frame.copy()
    broken.loc[0, "tick_volume"] = -1

    report = validate_ohlcv(broken, metadata=metadata)

    assert not report.passed
    assert "negative_tick_volume" in codes(report)


def test_gap_is_a_warning_not_an_error(dataset) -> None:
    frame, metadata = dataset
    gapped = frame.drop(index=[2, 3]).reset_index(drop=True)
    gapped.loc[2:, "timestamp"] = gapped.loc[2:, "timestamp"] + pd.Timedelta(minutes=25)

    report = validate_ohlcv(gapped, metadata=metadata)

    assert report.passed
    issue = next(issue for issue in report.issues if issue.code == "timestamp_gaps")
    assert issue.severity == "warning"
    assert issue.count == 1


def test_symbol_mismatch_fails(dataset) -> None:
    frame, _ = dataset

    report = validate_ohlcv(frame, symbol="GBPUSD")

    assert not report.passed
    assert "symbol_mismatch" in codes(report)


def test_mixed_symbols_warn(dataset) -> None:
    frame, _ = dataset
    mixed = frame.copy()
    mixed.loc[0, "symbol"] = "GBPUSD"

    report = validate_ohlcv(mixed, metadata={"data_kind": "synthetic"})

    assert report.passed
    assert "mixed_symbols" in codes(report)


def test_report_writes_json_and_csv(dataset, tmp_path: Path) -> None:
    frame, metadata = dataset
    report = validate_ohlcv(frame, metadata=metadata)

    json_path = report.to_json(tmp_path / "nested" / "report.json")
    csv_path = report.to_csv(tmp_path / "nested" / "report.csv")

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    assert payload["schema_version"] == 1
    assert payload["passed"] is True
    assert payload["metadata"]["data_kind"] == "synthetic"
    assert any(issue["code"] == "synthetic_dataset" for issue in payload["issues"])

    issues = pd.read_csv(csv_path)
    assert list(issues.columns) == ["code", "severity", "message", "count", "details"]
    assert "synthetic_dataset" in issues["code"].tolist()


def test_report_is_deterministic(dataset) -> None:
    frame, metadata = dataset

    first = validate_ohlcv(frame, metadata=metadata).to_dict()
    second = validate_ohlcv(frame, metadata=metadata).to_dict()

    assert first == second
