from __future__ import annotations

import csv
import importlib.util
import json
from pathlib import Path

import pytest

from mt5_ea_ai_lab.evaluation.pine_parity import PineParityError
from mt5_ea_ai_lab.evaluation.plan_audit import (
    REQUIRED_COLUMNS,
    audit_plan_csv,
    reason_tokens,
    write_audit_report,
)

REPO_ROOT = Path(__file__).resolve().parents[2]

HASH = "D6CEF886"
SOURCE = "PriceActionMTF"


def _tokens_text(tokens: dict[str, str]) -> str:
    label = tokens.pop("label", None)
    parts = [label] if label else []
    parts += [f"{key}={value}" for key, value in tokens.items()]
    return "|".join(parts)


def _init(**overrides: str) -> dict[str, str]:
    row = {
        "logged_at": "2026.01.05 00:00:00",
        "bar_time": "1970.01.01 00:00:00",
        "ea": "PinePlanSimEA",
        "version": "1.00",
        "config_hash": HASH,
        "symbol": "XAUUSDm",
        "timeframe": "PERIOD_M15",
        "event": "INIT",
        "side": "NONE",
        "price": "0.00000000",
        "volume": "1.0000",
        "entry": "0.00000000",
        "sl": "0.00000000",
        "tp": "0.00000000",
        "exposure": "0.0000",
        "equity": "10000.00",
        "drawdown_pct": "0.0000",
        "reason": _tokens_text(
            {"label": "SIMULATION_ONLY", "source": SOURCE, "config_hash": HASH}
        ),
    }
    row.update(overrides)
    return row


def _entry(bar: str = "2026.01.05 07:00:00", **overrides: str) -> dict[str, str]:
    row = {
        "logged_at": bar,
        "bar_time": bar,
        "ea": "PinePlanSimEA",
        "version": "1.00",
        "config_hash": HASH,
        "symbol": "XAUUSDm",
        "timeframe": "PERIOD_M15",
        "event": "ENTRY",
        "side": "BUY",
        "price": "4420.439",
        "volume": "1.0000",
        "entry": "4420.439",
        "sl": "4403.033",
        "tp": "4454.415",
        "exposure": "1.0000",
        "equity": "9999.92",
        "drawdown_pct": "0.0008",
        "reason": _tokens_text(
            {
                "label": "PLAN_ENTRY",
                "source": SOURCE,
                "ref_entry": "4420.161",
                "risk": "ACTIVE",
                "spread_points": "160.0",
            }
        ),
    }
    row.update(overrides)
    return row


def _exit(bar: str = "2026.01.05 09:00:00", **overrides: str) -> dict[str, str]:
    row = {
        "logged_at": bar,
        "bar_time": bar,
        "ea": "PinePlanSimEA",
        "version": "1.00",
        "config_hash": HASH,
        "symbol": "XAUUSDm",
        "timeframe": "PERIOD_M15",
        "event": "EXIT",
        "side": "BUY",
        "price": "4454.415",
        "volume": "1.0000",
        "entry": "4420.439",
        "sl": "4403.033",
        "tp": "4454.415",
        "exposure": "1.0000",
        "equity": "10033.89",
        "drawdown_pct": "0.0008",
        "reason": _tokens_text(
            {"label": "TARGET_HIT", "mode": "TP1", "bars": "8", "pnl": "33.89",
             "commission": "0.0000"}
        ),
    }
    row.update(overrides)
    return row


def _risk(bar: str = "2026.01.05 10:00:00", **overrides: str) -> dict[str, str]:
    row = {
        "logged_at": bar,
        "bar_time": bar,
        "ea": "PinePlanSimEA",
        "version": "1.00",
        "config_hash": HASH,
        "symbol": "XAUUSDm",
        "timeframe": "PERIOD_M15",
        "event": "RISK",
        "side": "BUY",
        "price": "4421.000",
        "volume": "1.0000",
        "entry": "4420.439",
        "sl": "4403.033",
        "tp": "4454.415",
        "exposure": "0.0000",
        "equity": "10033.89",
        "drawdown_pct": "0.0008",
        "reason": _tokens_text(
            {"label": "ENTRY_BLOCKED", "reason": "cooldown", "state": "ACTIVE"}
        ),
    }
    row.update(overrides)
    return row


def _summary(
    bar: str = "2026.09.30 23:45:00",
    *,
    entries: int = 1,
    rejected: int = 0,
    trades: int = 1,
    wins: int = 1,
    losses: int = 0,
    flats: int = 0,
    net: str = "33.89",
    realized: str = "33.89",
    blocks: int = 1,
    **overrides: str,
) -> dict[str, str]:
    row = {
        "logged_at": bar,
        "bar_time": bar,
        "ea": "PinePlanSimEA",
        "version": "1.00",
        "config_hash": HASH,
        "symbol": "XAUUSDm",
        "timeframe": "PERIOD_M15",
        "event": "SUMMARY",
        "side": "NONE",
        "price": "4155.953",
        "volume": "0.0000",
        "entry": "0.00000000",
        "sl": "0.00000000",
        "tp": "0.00000000",
        "exposure": "0.0000",
        "equity": "10033.89",
        "drawdown_pct": "0.0008",
        "reason": _tokens_text(
            {
                "source": SOURCE,
                "entries": str(entries),
                "rejected": str(rejected),
                "trades": str(trades),
                "wins": str(wins),
                "losses": str(losses),
                "flats": str(flats),
                "net": net,
                "realized": realized,
                "max_dd": "0.0100",
                "blocks": str(blocks),
                "halted": "ACTIVE",
            }
        ),
    }
    row.update(overrides)
    return row


def _traded(**overrides: str) -> list[dict[str, str]]:
    """INIT + one closed BUY + one blocked RISK attempt + SUMMARY."""

    return [
        _init(),
        _entry(**overrides),
        _exit(**overrides),
        _risk(**overrides),
        _summary(),
    ]


def _write(path: Path, rows: list[dict[str, str]]) -> Path:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(REQUIRED_COLUMNS))
        writer.writeheader()
        writer.writerows(rows)
    return path


def _issue_kinds(path: Path) -> set[str]:
    return {issue.kind for issue in audit_plan_csv(path).issues}


def test_reason_tokens_splits_labels_and_pairs() -> None:
    parsed = reason_tokens("SL_GAP|gap_points=12.50|pnl=-4.00")

    assert parsed["label"] == "SL_GAP"
    assert parsed["gap_points"] == "12.50"
    assert parsed["pnl"] == "-4.00"


def test_traded_journal_is_clean(tmp_path: Path) -> None:
    path = _write(tmp_path / "plan.csv", _traded())

    report = audit_plan_csv(path)

    assert report.status == "ok", [issue.to_dict() for issue in report.issues]
    assert report.rows == 5
    assert report.config_hashes == (HASH,)
    assert report.entries == 1
    assert report.exits == 1
    assert report.max_concurrent_positions == 1
    assert not report.open_position_at_end
    assert report.event_counts == {
        "ENTRY": 1,
        "EXIT": 1,
        "INIT": 1,
        "RISK": 1,
        "SUMMARY": 1,
    }
    assert report.exit_reason_counts == {"TARGET_HIT": 1}
    assert report.risk_reason_counts == {"ENTRY_BLOCKED": 1}
    assert report.summary["net"] == "33.89"
    assert report.first_bar == "2026-01-05T07:00:00Z"


def test_empty_plan_journal_is_clean(tmp_path: Path) -> None:
    path = _write(tmp_path / "plan.csv", [_init(), _summary(
        entries=0, trades=0, wins=0, net="0.00", realized="0.00", blocks=0,
    )])

    report = audit_plan_csv(path)

    assert report.status == "ok", [issue.to_dict() for issue in report.issues]
    assert report.entries == 0
    assert report.first_bar == "2026-09-30T23:45:00Z"


@pytest.mark.parametrize(
    "drop",
    ["reason", "config_hash", "side"],
)
def test_missing_column_raises(tmp_path: Path, drop: str) -> None:
    columns = [column for column in REQUIRED_COLUMNS if column != drop]
    path = tmp_path / "plan.csv"
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerow(_init())
        writer.writerow(_summary(entries=0, trades=0, wins=0, net="0.00",
                                realized="0.00", blocks=0))

    with pytest.raises(PineParityError, match="missing required columns"):
        audit_plan_csv(path)


def test_unexpected_column_raises(tmp_path: Path) -> None:
    rows = [_init(), _summary(entries=0, trades=0, wins=0, net="0.00",
                             realized="0.00", blocks=0)]
    path = tmp_path / "plan.csv"
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=[*REQUIRED_COLUMNS, "extra"], extrasaction="ignore"
        )
        writer.writeheader()
        for row in rows:
            writer.writerow({**row, "extra": "1"})

    with pytest.raises(PineParityError, match="unexpected columns"):
        audit_plan_csv(path)


def test_header_only_raises(tmp_path: Path) -> None:
    path = tmp_path / "plan.csv"
    path.write_text(",".join(REQUIRED_COLUMNS) + "\n", encoding="utf-8")

    with pytest.raises(PineParityError, match="no data rows"):
        audit_plan_csv(path)


def test_missing_file_raises(tmp_path: Path) -> None:
    with pytest.raises(PineParityError, match="not found"):
        audit_plan_csv(tmp_path / "absent.csv")


def test_mixed_config_hash_is_flagged(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(config_hash="AAAA1111"),
        _exit(config_hash="AAAA1111"),
        _risk(config_hash="AAAA1111"),
        _summary(config_hash="AAAA1111"),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "mixed_config_hash" in _issue_kinds(path)


def test_wrong_ea_and_unknown_event_are_flagged(tmp_path: Path) -> None:
    rows = [
        _init(ea="OtherEA"),
        _entry(),
        _exit(),
        _risk(event="PAUSE"),
        _summary(blocks=0, entries=0, trades=1, rejected=0),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    kinds = _issue_kinds(path)

    assert "unexpected_ea" in kinds
    assert "unknown_event" in kinds


def test_init_must_open_the_journal(tmp_path: Path) -> None:
    rows = [_entry(), _init(), _exit(), _risk(), _summary()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "init_not_first" in _issue_kinds(path)


def test_summary_must_close_the_journal(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _summary(), _exit()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "summary_not_last" in _issue_kinds(path)


def test_missing_summary_is_flagged(tmp_path: Path) -> None:
    path = _write(tmp_path / "plan.csv", [_init(), _entry(), _exit()])

    assert "summary_row_count" in _issue_kinds(path)


def test_init_reason_must_stay_simulation_only(tmp_path: Path) -> None:
    rows = [
        _init(reason=f"REAL_TRADES|source={SOURCE}|config_hash={HASH}"),
        _entry(),
        _exit(),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "init_not_simulation_only" in _issue_kinds(path)


def test_init_reason_hash_must_match_the_column(tmp_path: Path) -> None:
    rows = [
        _init(reason=f"SIMULATION_ONLY|source={SOURCE}|config_hash=BBBB2222"),
        _entry(),
        _exit(),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "init_hash_mismatch" in _issue_kinds(path)


def test_nested_entry_is_flagged(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(),
        _entry(bar_time="2026.01.05 07:15:00"),
        _exit(),
        _risk(),
        _summary(trades=1, entries=2),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "nested_entry" in _issue_kinds(path)


def test_orphan_exit_is_flagged(tmp_path: Path) -> None:
    rows = [_init(), _exit(), _summary(trades=1, entries=0)]
    path = _write(tmp_path / "plan.csv", rows)

    assert "orphan_exit" in _issue_kinds(path)


def test_unclosed_position_is_flagged(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(),
        _summary(entries=1, trades=0, wins=0, net="0.00", realized="0.00", blocks=0),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    kinds = _issue_kinds(path)

    assert kinds == {"open_position_at_end"}


def test_summary_trade_count_must_match_exit_rows(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _exit(), _risk(), _summary(trades=2, wins=2)]
    path = _write(tmp_path / "plan.csv", rows)

    kinds = _issue_kinds(path)

    assert "summary_trades_mismatch" in kinds
    assert "exit_missing_pnl" not in kinds


def test_exit_side_must_match_the_position(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(side="SELL", entry="4420.439", sl="4437.000", tp="4387.000"),
        _exit(side="BUY"),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "exit_side_mismatch" in _issue_kinds(path)


def test_stop_and_target_geometry_is_checked(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(side="SELL", entry="4420.439", sl="4403.033", tp="4454.415"),
        _exit(side="SELL", entry="4420.439", sl="4403.033", tp="4454.415"),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    kinds = _issue_kinds(path)

    assert "stop_on_wrong_side" in kinds
    assert "target_on_wrong_side" in kinds


def test_entry_side_must_be_buy_or_sell(tmp_path: Path) -> None:
    rows = [_init(), _entry(side="NONE"), _exit(), _risk(), _summary()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "invalid_side" in _issue_kinds(path)


def test_non_numeric_price_is_flagged(tmp_path: Path) -> None:
    rows = [_init(), _entry(price="abc"), _exit(), _risk(), _summary()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "invalid_price" in _issue_kinds(path)


def test_zero_volume_entry_is_flagged(tmp_path: Path) -> None:
    rows = [_init(), _entry(volume="0.0000"), _exit(), _risk(), _summary()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "non_positive_volume" in _issue_kinds(path)


def test_summary_counters_are_recounted(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _exit(), _risk(), _summary(entries=2, rejected=1)]
    path = _write(tmp_path / "plan.csv", rows)

    kinds = _issue_kinds(path)

    assert "summary_entries_mismatch" in kinds
    assert "summary_rejected_mismatch" in kinds


def test_summary_trade_split_must_add_up(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _exit(), _risk(), _summary(wins=2)]
    path = _write(tmp_path / "plan.csv", rows)

    assert "summary_trade_split_mismatch" in _issue_kinds(path)


def test_summary_net_must_match_exit_pnl(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _exit(), _risk(), _summary(net="99.00")]
    path = _write(tmp_path / "plan.csv", rows)

    assert "summary_net_mismatch" in _issue_kinds(path)


def test_summary_realized_must_match_exit_pnl(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _exit(), _risk(), _summary(realized="-5.00")]
    path = _write(tmp_path / "plan.csv", rows)

    assert "summary_realized_mismatch" in _issue_kinds(path)


def test_exit_without_pnl_token_is_flagged(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(),
        _exit(reason="SL_HIT|bars=4|commission=0.0000"),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "exit_missing_pnl" in _issue_kinds(path)


def test_summary_missing_field_is_flagged(tmp_path: Path) -> None:
    reason = _summary()["reason"].replace("|blocks=1", "")
    rows = [_init(), _entry(), _exit(), _risk(), _summary(reason=reason)]
    path = _write(tmp_path / "plan.csv", rows)

    assert "summary_missing_field" in _issue_kinds(path)


def test_equity_and_drawdown_ranges_are_checked(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(equity="-1.00", drawdown_pct="140.0000"),
        _exit(),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    kinds = _issue_kinds(path)

    assert "negative_equity" in kinds
    assert "drawdown_out_of_range" in kinds


def test_bars_must_not_run_backwards(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(bar_time="2026.01.05 09:00:00"),
        _exit(bar_time="2026.01.05 08:00:00"),
        _risk(),
        _summary(),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    assert "not_sorted" in _issue_kinds(path)


def test_off_grid_bar_is_flagged(tmp_path: Path) -> None:
    rows = [_init(), _entry(bar_time="2026.01.05 07:02:00"), _exit(), _risk(),
            _summary()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "off_grid" in _issue_kinds(path)


def test_unparseable_bar_time_is_flagged(tmp_path: Path) -> None:
    rows = [_init(), _entry(bar_time="not-a-time"), _exit(), _risk(), _summary()]
    path = _write(tmp_path / "plan.csv", rows)

    assert "invalid_bar_time" in _issue_kinds(path)


def test_server_offset_shifts_the_bars(tmp_path: Path) -> None:
    rows = [
        _init(),
        _entry(bar_time="2026.01.05 10:00:00"),
        _exit(bar_time="2026.01.05 12:00:00"),
        _risk(bar_time="2026.01.05 13:00:00"),
        _summary(bar_time="2026.10.01 02:45:00"),
    ]
    path = _write(tmp_path / "plan.csv", rows)

    report = audit_plan_csv(path, offset_minutes=180)

    assert report.status == "ok", [issue.to_dict() for issue in report.issues]
    assert report.first_bar == "2026-01-05T07:00:00Z"


def test_write_report_serializes_issues(tmp_path: Path) -> None:
    rows = [_init(), _entry(), _exit(), _risk(), _summary(net="99.00")]
    path = _write(tmp_path / "plan.csv", rows)

    report = audit_plan_csv(path)
    json_path = write_audit_report(report, tmp_path / "out")
    payload = json.loads(json_path.read_text(encoding="utf-8"))

    assert json_path.name == "plan_audit.json"
    assert payload["status"] == "issues"
    assert payload["issue_count"] == 1
    assert payload["issues"][0]["kind"] == "summary_net_mismatch"
    assert payload["config_hashes"] == [HASH]


def _load_cli():
    spec = importlib.util.spec_from_file_location(
        "audit_plan_csv_script",
        REPO_ROOT / "scripts" / "audit_plan_csv.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_cli_exit_codes(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    cli = _load_cli()
    clean = _write(tmp_path / "clean.csv", _traded())
    issues = _write(tmp_path / "issues.csv", [_init(), _entry(), _exit(), _risk(),
                                              _summary(net="99.00")])
    invalid = tmp_path / "invalid.csv"
    invalid.write_text("bar_time,symbol\n2026.01.05 07:00:00,XAUUSDm\n", encoding="utf-8")

    assert cli.main(["--csv", str(clean), "--out-dir", str(tmp_path / "a")]) == 0
    assert "status=ok" in capsys.readouterr().out

    assert cli.main(["--csv", str(issues), "--out-dir", str(tmp_path / "b")]) == 1
    assert "issue kind=summary_net_mismatch" in capsys.readouterr().out

    assert cli.main(["--csv", str(invalid), "--out-dir", str(tmp_path / "c")]) == 2
    assert "audit_error" in capsys.readouterr().err
