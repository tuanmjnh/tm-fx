from __future__ import annotations

import csv
import importlib.util
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from mt5_ea_ai_lab.evaluation.signal_audit import (
    audit_signal_csv,
    write_audit_report,
)

REPO_ROOT = Path(__file__).resolve().parents[2]

HEADER = [
    "detected_at",
    "bar_open_time",
    "confirmed_at",
    "symbol",
    "timeframe",
    "mode",
    "signal_id",
    "side",
    "sar_dir",
    "psar",
    "fast",
    "slow",
    "atr_pct",
    "input_hash",
]


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _row(
    bar: str = "2026-01-05T10:00:00Z",
    *,
    signal_id: str = "WW_BUY_SAR_FLIP",
    minutes: int = 5,
    detected_offset: int = 2,
    **overrides: str,
) -> dict[str, str]:
    start = datetime.fromisoformat(bar.replace("Z", "+00:00"))
    confirmed = start + timedelta(minutes=minutes)
    detected = confirmed + timedelta(seconds=detected_offset)
    side = "BUY" if "BUY" in signal_id else "SELL"
    row = {
        "detected_at": _iso(detected),
        "bar_open_time": _iso(start),
        "confirmed_at": _iso(confirmed),
        "symbol": "EURUSD",
        "timeframe": "M5",
        "mode": "SAR",
        "signal_id": signal_id,
        "side": side,
        "sar_dir": "1" if side == "BUY" else "-1",
        "psar": "1.10000000",
        "fast": "1.10100000",
        "slow": "1.10050000",
        "atr_pct": "0.0010000000",
        "input_hash": "deadbeef",
    }
    row.update(overrides)
    return row


def _write(path: Path, rows: list[dict[str, str]]) -> Path:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=HEADER)
        writer.writeheader()
        writer.writerows(rows)
    return path


def _issue_kinds(path: Path) -> set[str]:
    return {issue.kind for issue in audit_signal_csv(path).issues}


def test_clean_file_reports_ok(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "signals.csv",
        [
            _row("2026-01-05T10:00:00Z"),
            _row("2026-01-05T10:10:00Z", signal_id="WW_SELL_SAR_FLIP"),
        ],
    )

    report = audit_signal_csv(path)

    assert report.status == "ok"
    assert report.rows == 2
    assert report.first_bar == "2026-01-05T10:00:00Z"
    assert report.last_bar == "2026-01-05T10:10:00Z"
    assert report.side_counts == {"BUY": 1, "SELL": 1}
    assert report.empty_price_cells == 0


def test_unsorted_rows_are_flagged(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "signals.csv",
        [
            _row("2026-01-05T10:10:00Z"),
            _row("2026-01-05T10:00:00Z"),
        ],
    )

    assert "not_sorted" in _issue_kinds(path)


def test_mixed_symbols_are_flagged(tmp_path: Path) -> None:
    path = _write(
        tmp_path / "signals.csv",
        [
            _row("2026-01-05T10:00:00Z"),
            _row("2026-01-05T10:05:00Z", symbol="GBPUSD"),
        ],
    )

    report = audit_signal_csv(path)

    assert report.symbols == ("EURUSD", "GBPUSD")
    assert "mixed_symbols" in {issue.kind for issue in report.issues}


def test_empty_price_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row(psar="")])

    report = audit_signal_csv(path)

    assert report.empty_price_cells == 1
    assert "empty_price" in {issue.kind for issue in report.issues}


def test_negative_atr_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row(atr_pct="-0.5")])

    assert "negative_atr_pct" in _issue_kinds(path)


def test_off_grid_bar_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row("2026-01-05T10:02:00Z")])

    assert "off_grid" in _issue_kinds(path)


def test_detected_before_confirmed_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row(detected_offset=-5)])

    assert "detected_before_confirmed" in _issue_kinds(path)


def test_server_offset_is_applied(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row("2026-01-05T13:00:00Z")])

    report = audit_signal_csv(path, offset_minutes=180)

    assert report.first_bar == "2026-01-05T10:00:00Z"
    assert report.status == "ok"


def test_write_report_serializes_issues(tmp_path: Path) -> None:
    path = _write(tmp_path / "signals.csv", [_row(atr_pct="-0.5")])
    report = audit_signal_csv(path)

    json_path = write_audit_report(report, tmp_path / "out")
    payload = json.loads(json_path.read_text(encoding="utf-8"))

    assert payload["status"] == "issues"
    assert payload["issue_count"] == 1
    assert payload["issues"][0]["kind"] == "negative_atr_pct"


def _load_cli():
    spec = importlib.util.spec_from_file_location(
        "audit_signal_csv_script",
        REPO_ROOT / "scripts" / "audit_signal_csv.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_cli_exit_codes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    cli = _load_cli()
    clean = _write(tmp_path / "clean.csv", [_row()])
    issues = _write(tmp_path / "issues.csv", [_row(atr_pct="-0.5")])
    invalid = tmp_path / "invalid.csv"
    invalid.write_text("bar_open_time,symbol\n2026-01-05T10:00:00Z,EURUSD\n", encoding="utf-8")

    assert cli.main(["--csv", str(clean), "--out-dir", str(tmp_path / "a")]) == 0
    assert "status=ok" in capsys.readouterr().out

    assert cli.main(["--csv", str(issues), "--out-dir", str(tmp_path / "b")]) == 1
    assert "issue kind=negative_atr_pct" in capsys.readouterr().out

    assert cli.main(["--csv", str(invalid), "--out-dir", str(tmp_path / "c")]) == 2
    assert "audit_error" in capsys.readouterr().err
