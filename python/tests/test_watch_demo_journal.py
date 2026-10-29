"""Tests for ``scripts/watch_demo_journal.py`` — the read-only demo journal watcher.

Covers the CSV contract, the byte checkpoint, partial-line handling and the alert
semantics a monitoring run depends on. Nothing here touches MT5 or a broker.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
WATCHER = REPO_ROOT / "scripts" / "watch_demo_journal.py"


def _load():
    spec = importlib.util.spec_from_file_location("watch_demo_journal", WATCHER)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


watcher = _load()


def _row(event: str, reason: str, side: str = "SELL", price: str = "0.00000000") -> str:
    fields = [
        "2026.10.29 06:00:00",
        "2026.10.29 05:55:00",
        "PATrendRiderXAUv1DemoEA",
        "1.00",
        "6B439450",
        "XAUUSDm",
        "PERIOD_H1/PERIOD_M15/PERIOD_M5",
        event,
        side,
        price,
        "0.0100",
        price,
        "4042.79000000",
        "4048.79000000",
        "0.0000",
        "4999.76",
        "0.0048",
        reason,
    ]
    assert len(fields) == len(watcher.EXPECTED_HEADER)
    return ",".join(fields)


def _journal(tmp_path: Path, rows: list[str]) -> Path:
    path = tmp_path / watcher.JOURNAL_NAME
    body = "\r\n".join([",".join(watcher.EXPECTED_HEADER), *rows])
    path.write_text(body + "\r\n", encoding="utf-8", newline="")
    return path


def test_parses_documented_columns(tmp_path: Path) -> None:
    path = _journal(tmp_path, [_row("RISK", "ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE")])
    records, offset, restarted = watcher.read_records(path, 0)
    assert restarted is False
    assert offset == path.stat().st_size
    assert [record["event"] for record in records] == ["RISK"]
    assert records[0]["symbol"] == "XAUUSDm"
    assert records[0]["reason"].startswith("ENTRY_BLOCKED|")


def test_wrong_column_count_is_a_journal_error(tmp_path: Path) -> None:
    path = tmp_path / watcher.JOURNAL_NAME
    path.write_text("a,b,c\r\n", encoding="utf-8", newline="")
    with pytest.raises(watcher.JournalError):
        watcher.read_records(path, 0)


def test_checkpoint_reports_only_appended_rows(tmp_path: Path) -> None:
    path = _journal(tmp_path, [_row("RISK", "ENTRY_BLOCKED|reason=regime_range")])
    _, offset, _ = watcher.read_records(path, 0)
    with path.open("ab") as handle:
        handle.write((_row("ENTRY", "ORDER_FILLED|order=17|deal=18|ok|done", "BUY") + "\r\n").encode())
    records, new_offset, restarted = watcher.read_records(path, offset)
    assert restarted is False
    assert [record["event"] for record in records] == ["ENTRY"]
    assert new_offset == path.stat().st_size


def test_partial_line_is_not_consumed(tmp_path: Path) -> None:
    path = _journal(tmp_path, [_row("INIT", "mode=DEMO_EXECUTION")])
    _, offset, _ = watcher.read_records(path, 0)
    tail = _row("EXIT", "broker_close|pnl=1.20", "BUY")
    with path.open("ab") as handle:
        handle.write(tail.encode())
    records, held_offset, _ = watcher.read_records(path, offset)
    assert records == []
    assert held_offset == offset
    with path.open("ab") as handle:
        handle.write(b"\r\n")
    records, _, _ = watcher.read_records(path, offset)
    assert [record["event"] for record in records] == ["EXIT"]


def test_recreated_journal_resets_the_checkpoint(tmp_path: Path) -> None:
    path = _journal(tmp_path, [_row("INIT", "mode=DRY_RUN")] * 4)
    path.write_text(
        "\r\n".join([",".join(watcher.EXPECTED_HEADER), _row("BOS", "tf=M5|event=BOS_BEAR")]) + "\r\n",
        encoding="utf-8",
        newline="",
    )
    records, _, restarted = watcher.read_records(path, 9999)
    assert restarted is True
    assert [record["event"] for record in records] == ["BOS"]


def test_alert_kinds_separate_orders_from_faults() -> None:
    assert watcher.classify({"event": "ENTRY", "reason": ""}) == "ORDER"
    assert watcher.classify({"event": "TRAIL", "reason": ""}) == "ORDER"
    assert watcher.classify({"event": "KILL", "reason": ""}) == "FAULT"
    assert watcher.classify({"event": "RISK", "reason": "ENTRY_BLOCKED|reason=bias_unknown"}) is None
    assert watcher.classify({"event": "REGIME", "reason": ""}) is None


def test_blocked_reason_histogram(tmp_path: Path) -> None:
    rows = [
        _row("RISK", "ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE"),
        _row("RISK", "ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE"),
        _row("RISK", "ENTRY_BLOCKED|reason=lot_rejected|regime=TREND"),
        _row("BOS", "tf=M5|event=BOS_BULL"),
    ]
    path = _journal(tmp_path, rows)
    records, _, _ = watcher.read_records(path, 0)
    assert watcher.block_reasons(records) == {
        "reason=bias_unknown": 2,
        "reason=lot_rejected": 1,
    }


def test_main_exits_one_when_a_real_entry_appears(tmp_path: Path, capsys) -> None:
    path = _journal(
        tmp_path,
        [
            _row("RISK", "ENTRY_BLOCKED|reason=bias_unknown"),
            _row("ENTRY", "ORDER_FILLED|order=17|deal=18|ok|done", "BUY", "4045.79000000"),
            _row("EXIT", "broker_close|pnl=-0.24", "BUY", "4045.55000000"),
        ],
    )
    code = watcher.main(["--csv", str(path), "--state", str(tmp_path / "cp.json"), "--from-start"])
    assert code == 1
    lines = capsys.readouterr().out.splitlines()
    assert any(line.startswith("WATCH|ENTRY|") and "side=BUY" in line for line in lines)
    assert any(line.startswith("WATCH|SUMMARY|events=3") for line in lines)
    assert any(line.startswith("WATCH|BLOCKED|reason=bias_unknown=1") for line in lines)


def test_main_quiet_keeps_only_alert_lines(tmp_path: Path, capsys) -> None:
    path = _journal(
        tmp_path,
        [_row("RISK", "ENTRY_BLOCKED|reason=regime_range"), _row("ERROR", "order_send_failed")],
    )
    code = watcher.main(
        ["--csv", str(path), "--state", str(tmp_path / "cp.json"), "--from-start", "--quiet"]
    )
    assert code == 1
    body = [line for line in capsys.readouterr().out.splitlines() if not line.startswith("WATCH|INIT|")]
    assert body == ["WATCH|ERROR|2026.10.29 06:00:00|2026.10.29 05:55:00|order_send_failed"]


def test_main_exits_zero_while_every_setup_is_blocked(tmp_path: Path) -> None:
    path = _journal(tmp_path, [_row("RISK", "ENTRY_BLOCKED|reason=regime_range")])
    assert watcher.main(["--csv", str(path), "--state", str(tmp_path / "cp.json"), "--from-start"]) == 0


def test_main_exits_two_without_a_journal(tmp_path: Path) -> None:
    assert watcher.main(["--csv", str(tmp_path / "absent.csv")]) == 2


def test_kill_switch_file_always_raises_an_alert(tmp_path: Path) -> None:
    path = _journal(tmp_path, [_row("RISK", "ENTRY_BLOCKED|reason=risk_locked")])
    (tmp_path / watcher.KILL_SWITCH_NAME).write_text("stop\n", encoding="utf-8")
    assert (
        watcher.main(["--csv", str(path), "--state", str(tmp_path / "cp.json"), "--from-start", "--quiet"])
        == 1
    )


def test_watcher_stays_read_only() -> None:
    text = WATCHER.read_text(encoding="utf-8")
    for forbidden in ("OrderSend", "CTrade", "MqlTradeRequest", "import MetaTrader5"):
        assert forbidden not in text
    assert 'path.open("rb")' in text
    assert 'open("w"' not in text and 'open("wb"' not in text
