from __future__ import annotations

import json

import pandas as pd
import pytest

from mt5_ea_ai_lab.evaluation.parity import (
    MISMATCH_COLUMNS,
    PARITY_COLUMNS,
    SignalComparisonError,
    compare_signal_files,
    load_signal_csv,
    write_report,
)


def make_row(
    timestamp: str,
    *,
    signal: str = "HOLD",
    reason: str = "NO_CROSS",
    fast_prev: float | None = 1.10,
    slow_prev: float | None = 1.05,
    fast: float | None = 1.12,
    slow: float | None = 1.06,
) -> dict[str, object]:
    return {
        "timestamp": timestamp,
        "symbol": "EURUSD",
        "timeframe": "M5",
        "signal": signal,
        "reason": reason,
        "fast_prev": fast_prev,
        "slow_prev": slow_prev,
        "fast": fast,
        "slow": slow,
    }


def write_rows(path, rows) -> None:
    pd.DataFrame(rows, columns=list(PARITY_COLUMNS)).to_csv(path, index=False)


def base_rows() -> list[dict[str, object]]:
    return [
        make_row(
            "2024-01-01T00:00:00Z",
            signal="UNKNOWN",
            reason="INSUFFICIENT_HISTORY",
            fast_prev=None,
            slow_prev=None,
            fast=None,
            slow=None,
        ),
        make_row("2024-01-01T00:05:00Z", fast_prev=1.08, slow_prev=1.09, fast=1.10, slow=1.095),
        make_row(
            "2024-01-01T00:10:00Z",
            signal="BUY",
            reason="OK",
            fast_prev=1.09,
            slow_prev=1.10,
            fast=1.12,
            slow=1.11,
        ),
    ]


def test_identical_exports_match(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, base_rows())
    write_rows(python, base_rows())

    report = compare_signal_files(mql5, python)

    assert report.status == "match"
    assert report.mismatch_count == 0
    assert report.rows_mql5 == 3
    assert report.rows_python == 3
    assert report.rows_compared == 3


def test_row_order_and_timestamp_offsets_do_not_matter(tmp_path) -> None:
    mql5_rows = base_rows()
    python_rows = list(reversed(base_rows()))
    python_rows[0]["timestamp"] = "2024-01-01T00:10:00+00:00"
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, mql5_rows)
    write_rows(python, python_rows)

    report = compare_signal_files(mql5, python)

    assert report.status == "match"
    assert report.rows_compared == 3


def test_numeric_difference_within_tolerance_matches(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, base_rows())
    python_rows = base_rows()
    python_rows[1]["fast"] = 1.10 + 5e-10
    write_rows(python, python_rows)

    report = compare_signal_files(mql5, python, tolerance=1e-9)

    assert report.status == "match"


def test_numeric_difference_outside_tolerance_is_reported(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, base_rows())
    python_rows = base_rows()
    python_rows[1]["fast"] = 1.10 + 2e-9
    write_rows(python, python_rows)

    report = compare_signal_files(mql5, python, tolerance=1e-9)

    assert report.status == "mismatch"
    assert report.mismatch_count == 1
    mismatch = report.mismatches[0]
    assert mismatch.timestamp == "2024-01-01T00:05:00Z"
    assert mismatch.field == "fast"
    assert mismatch.kind == "value_mismatch"
    assert mismatch.difference == pytest.approx(-2e-9, rel=1e-6)


def test_signal_and_reason_mismatches_are_listed_per_field(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, base_rows())
    python_rows = base_rows()
    python_rows[2]["signal"] = "HOLD"
    python_rows[2]["reason"] = "NO_CROSS"
    write_rows(python, python_rows)

    report = compare_signal_files(mql5, python)

    assert report.status == "mismatch"
    assert {(item.field, item.kind) for item in report.mismatches} == {
        ("signal", "value_mismatch"),
        ("reason", "value_mismatch"),
    }
    signal_mismatch = next(
        item for item in report.mismatches if item.field == "signal"
    )
    assert signal_mismatch.timestamp == "2024-01-01T00:10:00Z"
    assert signal_mismatch.mql5_value == "BUY"
    assert signal_mismatch.python_value == "HOLD"


def test_signal_comparison_is_case_sensitive(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, base_rows())
    python_rows = base_rows()
    python_rows[2]["signal"] = "buy"
    write_rows(python, python_rows)

    report = compare_signal_files(mql5, python)

    assert report.status == "mismatch"
    assert any(item.field == "signal" for item in report.mismatches)


def test_missing_rows_are_reported_in_both_directions(tmp_path) -> None:
    rows = base_rows()
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, rows[:2])
    extra = make_row("2024-01-01T00:15:00Z")
    write_rows(python, [rows[1], extra])

    report = compare_signal_files(mql5, python)

    assert report.rows_compared == 1
    assert {item.kind for item in report.mismatches} == {
        "missing_in_mql5",
        "missing_in_python",
    }
    assert all(item.field == "*" for item in report.mismatches)


def test_nan_versus_value_is_reported_and_both_nan_is_not(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    mql5_rows = base_rows()
    mql5_rows[1]["fast"] = None
    write_rows(mql5, mql5_rows)
    write_rows(python, base_rows())

    report = compare_signal_files(mql5, python)

    assert report.status == "mismatch"
    assert report.mismatch_count == 1
    assert report.mismatches[0].field == "fast"
    assert report.mismatches[0].kind == "nan_mismatch"


def test_missing_columns_are_rejected(tmp_path) -> None:
    path = tmp_path / "signals.csv"
    frame = pd.DataFrame(base_rows(), columns=list(PARITY_COLUMNS)).drop(columns=["reason"])
    frame.to_csv(path, index=False)

    with pytest.raises(SignalComparisonError, match="missing required columns"):
        load_signal_csv(path)


def test_duplicate_keys_are_rejected(tmp_path) -> None:
    path = tmp_path / "signals.csv"
    rows = base_rows()
    write_rows(path, [rows[0], rows[0]])

    with pytest.raises(SignalComparisonError, match="duplicate"):
        load_signal_csv(path)


def test_empty_signal_is_rejected(tmp_path) -> None:
    path = tmp_path / "signals.csv"
    rows = base_rows()
    rows[0]["signal"] = ""
    write_rows(path, rows)

    with pytest.raises(SignalComparisonError, match="empty signal"):
        load_signal_csv(path)


def test_invalid_timestamp_is_rejected(tmp_path) -> None:
    path = tmp_path / "signals.csv"
    rows = base_rows()
    rows[0]["timestamp"] = "not-a-timestamp"
    write_rows(path, rows)

    with pytest.raises(SignalComparisonError, match="invalid timestamps"):
        load_signal_csv(path)


def test_non_numeric_value_is_rejected(tmp_path) -> None:
    path = tmp_path / "signals.csv"
    rows = base_rows()
    rows[1]["fast"] = "abc"
    write_rows(path, rows)

    with pytest.raises(SignalComparisonError, match="non-numeric fast"):
        load_signal_csv(path)


def test_negative_tolerance_is_rejected(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    write_rows(mql5, base_rows())
    write_rows(python, base_rows())

    with pytest.raises(SignalComparisonError, match="tolerance"):
        compare_signal_files(mql5, python, tolerance=-1.0)


def test_report_files_are_written_with_nan_as_null(tmp_path) -> None:
    mql5 = tmp_path / "mql5.csv"
    python = tmp_path / "python.csv"
    mql5_rows = base_rows()
    mql5_rows[1]["fast"] = None
    write_rows(mql5, mql5_rows)
    write_rows(python, base_rows())
    report = compare_signal_files(mql5, python)

    out_dir = tmp_path / "reports"
    json_path, csv_path = write_report(report, out_dir)

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    assert payload["status"] == "mismatch"
    assert payload["mismatch_count"] == 1
    assert payload["mismatches"][0]["kind"] == "nan_mismatch"
    assert payload["mismatches"][0]["mql5_value"] is None
    assert payload["mismatches"][0]["python_value"] == pytest.approx(1.10)

    csv_frame = pd.read_csv(csv_path)
    assert list(csv_frame.columns) == list(MISMATCH_COLUMNS)
    assert len(csv_frame) == 1
