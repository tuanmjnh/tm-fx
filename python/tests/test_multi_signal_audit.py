from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from mt5_ea_ai_lab.evaluation.multi_signal_audit import (
    REQUIRED_COLUMNS,
    audit_multi_signal_csv,
    write_audit_report,
)
from mt5_ea_ai_lab.evaluation.pine_parity import PineParityError

HEADER = list(REQUIRED_COLUMNS)


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _row(
    bar: str = "2026-01-05T10:00:00Z",
    *,
    source: str = "TMIndicator2",
    signal_id: str = "TM2_BUY",
    side: str = "BUY",
    dir_value: str = "1",
    score: str = "80.5",
    minutes: int = 5,
    detected_offset: int = 2,
    **overrides: str,
) -> dict[str, str]:
    start = datetime.fromisoformat(bar.replace("Z", "+00:00"))
    confirmed = start + timedelta(minutes=minutes)
    detected = confirmed + timedelta(seconds=detected_offset)
    row = {
        "detected_at": _iso(detected),
        "bar_open_time": _iso(start),
        "confirmed_at": _iso(confirmed),
        "symbol": "EURUSD",
        "timeframe": "M5",
        "source": source,
        "contract_version": "1.0.0",
        "signal_id": signal_id,
        "side": side,
        "dir": dir_value,
        "score": score,
        "entry": "1.10000",
        "sl": "1.09500",
        "tp1": "1.10500",
        "tp2": "1.11000",
        "tp3": "1.11500",
        "reason": "",
        "input_hash": "A1B2C3D4",
    }
    row.update(overrides)
    return row


def _write(path: Path, rows: list[dict[str, str]]) -> Path:
    lines = [",".join(HEADER)]
    for row in rows:
        lines.append(",".join(row[column] for column in HEADER))
    path.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")
    return path


def test_valid_multi_source_export(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "signals.csv",
        [
            _row(bar="2026-01-05T10:00:00Z"),
            _row(
                bar="2026-01-05T10:05:00Z",
                source="Wonderwhales",
                signal_id="WW_SELL",
                side="SELL",
                dir_value="-1",
                score="",
                entry="",
                sl="",
                tp1="",
                tp2="",
                tp3="",
            ),
        ],
    )

    report = audit_multi_signal_csv(path)

    assert report.status == "ok"
    assert report.rows == 2
    assert report.sources == ("TMIndicator2", "Wonderwhales")
    assert report.source_counts == {"TMIndicator2": 1, "Wonderwhales": 1}
    assert report.side_counts == {"BUY": 1, "SELL": 1}
    assert report.symbols == ("EURUSD",)
    assert report.timeframes == ("M5",)


def test_missing_column_raises(tmp_path: Path) -> None:
    path = tmp_path / "bad.csv"
    path.write_text("detected_at,bar_open_time\r\n2026-01-05T10:05:00Z,2026-01-05T10:00:00Z\r\n")

    with pytest.raises(PineParityError, match="missing required column"):
        audit_multi_signal_csv(path)


def test_empty_export_raises(tmp_path: Path) -> None:
    path = _write(tmp_path / "empty.csv", [])

    with pytest.raises(PineParityError, match="no data rows"):
        audit_multi_signal_csv(path)


def test_duplicate_source_bar_is_flagged(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "dup.csv",
        [_row(), _row(signal_id="TM2_BUY_DUP")],
    )

    report = audit_multi_signal_csv(path)

    assert report.status == "issues"
    kinds = {issue.kind for issue in report.issues}
    assert "duplicate_signal" in kinds


def test_invalid_side_and_dir_are_flagged(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "bad_values.csv",
        [_row(side="LONG", dir_value="2")],
    )

    report = audit_multi_signal_csv(path)

    kinds = {issue.kind for issue in report.issues}
    assert "invalid_side" in kinds
    assert "invalid_dir" in kinds


def test_empty_dir_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "empty_dir.csv", [_row(dir_value="")])

    report = audit_multi_signal_csv(path)

    kinds = {issue.kind for issue in report.issues}
    assert "empty_dir" in kinds


def test_score_range_is_checked(tmp_path: Path) -> None:
    path = _write(tmp_path / "score.csv", [_row(score="120")])

    report = audit_multi_signal_csv(path)

    kinds = {issue.kind for issue in report.issues}
    assert "score_out_of_range" in kinds


def test_detected_before_confirmed_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "early.csv", [_row(detected_offset=-120)])

    report = audit_multi_signal_csv(path)

    kinds = {issue.kind for issue in report.issues}
    assert "detected_before_confirmed" in kinds


def test_mixed_symbols_are_flagged(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "mixed.csv",
        [_row(), _row(bar="2026-01-05T10:05:00Z", symbol="XAUUSD")],
    )

    report = audit_multi_signal_csv(path)

    kinds = {issue.kind for issue in report.issues}
    assert "mixed_symbols" in kinds


def test_unknown_source_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "unknown.csv", [_row(source="Mystery")])

    report = audit_multi_signal_csv(path)

    kinds = {issue.kind for issue in report.issues}
    assert "unknown_source" in kinds


def test_write_report_creates_json(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row()])
    report = audit_multi_signal_csv(path)

    json_path = write_audit_report(report, tmp_path / "out")

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    assert json_path.name == "multi_signal_audit.json"
    assert payload["status"] == "ok"
    assert payload["rows"] == 1
    assert payload["source_counts"] == {"TMIndicator2": 1}
