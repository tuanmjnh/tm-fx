"""Audit the simulation journal written by PinePlanSimEA.

Structural checks only: the header, the one-run-per-file identity columns, the
INIT/SUMMARY framing, the ENTRY/EXIT lifecycle, stop and target geometry, and
the SUMMARY counters against the rows that produced them. This is not a parity
check and it never claims a strategy is profitable.

The expected header is::

    logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,
    price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason

Net amounts are in model units: contract size 1 with no commission, slippage,
swap or margin unless the EA's cost inputs say otherwise.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd

from mt5_ea_ai_lab.evaluation.pine_parity import (
    PineParityError,
    format_bar_time,
    timeframe_seconds,
)

REQUIRED_COLUMNS: tuple[str, ...] = (
    "logged_at",
    "bar_time",
    "ea",
    "version",
    "config_hash",
    "symbol",
    "timeframe",
    "event",
    "side",
    "price",
    "volume",
    "entry",
    "sl",
    "tp",
    "exposure",
    "equity",
    "drawdown_pct",
    "reason",
)

EA_NAME = "PinePlanSimEA"
KNOWN_EVENTS: tuple[str, ...] = ("INIT", "ENTRY", "EXIT", "RISK", "SUMMARY")
#: INIT carries the epoch placeholder from the logger, so bar spans and ordering
#: are measured over the events that ran inside the simulation window.
BAR_EVENTS: tuple[str, ...] = ("ENTRY", "EXIT", "RISK", "SUMMARY")

#: tolerance between the summed EXIT pnl and the SUMMARY net, both of which the
#: EA prints with a fixed number of decimals.
NET_TOLERANCE = 0.05


@dataclass(frozen=True)
class AuditIssue:
    kind: str
    detail: str

    def to_dict(self) -> dict[str, str]:
        return {"kind": self.kind, "detail": self.detail}


@dataclass(frozen=True)
class PlanAuditReport:
    source: str
    rows: int
    ea: tuple[str, ...]
    versions: tuple[str, ...]
    config_hashes: tuple[str, ...]
    symbols: tuple[str, ...]
    timeframes: tuple[str, ...]
    first_bar: str
    last_bar: str
    event_counts: dict[str, int]
    entry_side_counts: dict[str, int]
    exit_reason_counts: dict[str, int]
    risk_reason_counts: dict[str, int]
    entries: int
    exits: int
    open_position_at_end: bool
    max_concurrent_positions: int
    summary: dict[str, str]
    issues: tuple[AuditIssue, ...]

    @property
    def status(self) -> str:
        return "ok" if not self.issues else "issues"

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "source": self.source,
            "rows": self.rows,
            "ea": list(self.ea),
            "versions": list(self.versions),
            "config_hashes": list(self.config_hashes),
            "symbols": list(self.symbols),
            "timeframes": list(self.timeframes),
            "first_bar": self.first_bar,
            "last_bar": self.last_bar,
            "event_counts": dict(self.event_counts),
            "entry_side_counts": dict(self.entry_side_counts),
            "exit_reason_counts": dict(self.exit_reason_counts),
            "risk_reason_counts": dict(self.risk_reason_counts),
            "entries": self.entries,
            "exits": self.exits,
            "open_position_at_end": self.open_position_at_end,
            "max_concurrent_positions": self.max_concurrent_positions,
            "summary": dict(self.summary),
            "issue_count": len(self.issues),
            "issues": [issue.to_dict() for issue in self.issues],
        }


def _sorted_counts(values: list[str]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for value in values:
        counts[value] = counts.get(value, 0) + 1
    return {key: counts[key] for key in sorted(counts)}


def reason_tokens(reason: str) -> dict[str, str]:
    """Split an MQL5 ``a=b|c=d`` reason field; leading bare words become labels."""

    out: dict[str, str] = {}
    for part in str(reason).split("|"):
        if "=" in part:
            key, _, value = part.partition("=")
            out[key.strip()] = value.strip()
        else:
            label = part.strip()
            if label:
                out.setdefault("label", label)
    return out


def _load(path: str | Path) -> pd.DataFrame:
    source = Path(path)
    if not source.exists():
        raise PineParityError(f"journal not found: {source}")
    try:
        frame = pd.read_csv(source, dtype=str, keep_default_na=False)
    except (OSError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
        raise PineParityError(f"cannot parse journal {source}: {exc}") from exc

    missing = [column for column in REQUIRED_COLUMNS if column not in frame.columns]
    if missing:
        raise PineParityError(
            f"{source} is missing required columns: {', '.join(missing)}"
        )
    extra = [column for column in frame.columns if column not in REQUIRED_COLUMNS]
    if extra:
        raise PineParityError(
            f"{source} has unexpected columns: {', '.join(extra)}"
        )
    if frame.empty:
        raise PineParityError(f"{source} has a header but no data rows")
    return frame


def _numbers(frame: pd.DataFrame, issues: list[AuditIssue]) -> pd.DataFrame:
    numeric = pd.DataFrame(index=frame.index)
    for column in ("price", "volume", "entry", "sl", "tp", "exposure", "equity",
                   "drawdown_pct"):
        values = pd.to_numeric(frame[column].replace("", pd.NA), errors="coerce")
        unparsed = frame[column].notna() & (frame[column] != "") & values.isna()
        if unparsed.any():
            sample = ", ".join(sorted(frame.loc[unparsed, column].unique())[:3])
            issues.append(
                AuditIssue(
                    f"invalid_{column}",
                    f"{int(unparsed.sum())} non-numeric {column} value(s): {sample}",
                )
            )
        numeric[column] = values
    return numeric


def _check_framing(frame: pd.DataFrame, issues: list[AuditIssue]) -> dict[str, str]:
    """Validate the INIT first / SUMMARY last shape; returns the SUMMARY tokens."""

    events = list(frame["event"])
    init_rows = [index for index, event in enumerate(events) if event == "INIT"]
    summary_rows = [index for index, event in enumerate(events) if event == "SUMMARY"]

    if len(init_rows) != 1:
        issues.append(
            AuditIssue("init_row_count", f"{len(init_rows)} INIT row(s), expected 1")
        )
    elif init_rows[0] != 0:
        issues.append(
            AuditIssue(
                "init_not_first",
                f"INIT is at data row {init_rows[0] + 1}, expected the first row",
            )
        )
    if len(summary_rows) != 1:
        issues.append(
            AuditIssue(
                "summary_row_count",
                f"{len(summary_rows)} SUMMARY row(s), expected 1",
            )
        )
    elif summary_rows[0] != len(events) - 1:
        issues.append(
            AuditIssue(
                "summary_not_last",
                f"SUMMARY is at data row {summary_rows[0] + 1}, "
                f"expected the last of {len(events)} rows",
            )
        )

    if init_rows:
        init = reason_tokens(frame.iloc[init_rows[0]]["reason"])
        if init.get("label") != "SIMULATION_ONLY":
            issues.append(
                AuditIssue(
                    "init_not_simulation_only",
                    f"INIT reason is {init.get('label', '')!r}, "
                    "expected SIMULATION_ONLY",
                )
            )
        if init.get("config_hash", "") != frame.iloc[init_rows[0]]["config_hash"]:
            issues.append(
                AuditIssue(
                    "init_hash_mismatch",
                    f"INIT reason config_hash={init.get('config_hash', '')!r} "
                    f"!= column config_hash={frame.iloc[init_rows[0]]['config_hash']!r}",
                )
            )

    if not summary_rows:
        return {}
    return reason_tokens(frame.iloc[summary_rows[0]]["reason"])


def _check_lifecycle(
    frame: pd.DataFrame, numeric: pd.DataFrame, issues: list[AuditIssue]
) -> tuple[int, bool]:
    """Walk the journal in order and check the single-position lifecycle."""

    open_position: dict[str, Any] | None = None
    open_count = 0
    max_concurrent = 0

    for index, event in enumerate(frame["event"]):
        row = frame.iloc[index]
        bar = str(row["bar_time"])
        if event == "INIT":
            continue

        if event == "ENTRY":
            if open_position is not None:
                issues.append(
                    AuditIssue(
                        "nested_entry",
                        f"ENTRY at {bar} while a position opened at "
                        f"{open_position['bar_time']} is still open",
                    )
                )
                open_count -= 1
            open_position = {
                "bar_time": bar,
                "side": row["side"],
                "entry": float(numeric["entry"].iloc[index]),
            }
            open_count += 1
            max_concurrent = max(max_concurrent, open_count)
            continue

        if event == "EXIT":
            if open_position is None:
                issues.append(
                    AuditIssue("orphan_exit", f"EXIT at {bar} with no open position")
                )
                continue
            if row["side"] != open_position["side"]:
                issues.append(
                    AuditIssue(
                        "exit_side_mismatch",
                        f"EXIT at {bar} is {row['side']} but the position opened "
                        f"{open_position['side']} at {open_position['bar_time']}",
                    )
                )
            open_position = None
            open_count -= 1
            continue

        if event == "SUMMARY":
            if open_position is not None:
                issues.append(
                    AuditIssue(
                        "open_position_at_end",
                        f"{open_position['side']} opened at "
                        f"{open_position['bar_time']} never closed",
                    )
                )
            break

    return (max_concurrent, open_position is not None)


def _check_geometry(
    frame: pd.DataFrame, numeric: pd.DataFrame, issues: list[AuditIssue]
) -> None:
    """Stop and target must sit on opposite sides of the entry, per direction."""

    for index, event in enumerate(frame["event"]):
        if event not in ("ENTRY", "EXIT"):
            continue
        row = frame.iloc[index]
        side = str(row["side"])
        if event == "ENTRY" and side not in ("BUY", "SELL"):
            issues.append(
                AuditIssue(
                    "invalid_side",
                    f"ENTRY at {row['bar_time']} has side {side!r}",
                )
            )
            continue

        entry = numeric["entry"].iloc[index]
        stop = numeric["sl"].iloc[index]
        target = numeric["tp"].iloc[index]
        volume = numeric["volume"].iloc[index]
        bar = str(row["bar_time"])

        if pd.notna(volume) and volume <= 0:
            issues.append(
                AuditIssue("non_positive_volume", f"{event} at {bar} volume={volume}")
            )

        if pd.isna(entry) or pd.isna(stop) or pd.isna(target):
            continue
        if entry <= 0:
            issues.append(
                AuditIssue(
                    "invalid_entry_price", f"{event} at {bar} entry={entry}"
                )
            )
            continue
        if side == "BUY":
            if stop >= entry:
                issues.append(
                    AuditIssue(
                        "stop_on_wrong_side",
                        f"{event} BUY at {bar} sl={stop} not below entry={entry}",
                    )
                )
            if target <= entry:
                issues.append(
                    AuditIssue(
                        "target_on_wrong_side",
                        f"{event} BUY at {bar} tp={target} not above entry={entry}",
                    )
                )
        elif side == "SELL":
            if stop <= entry:
                issues.append(
                    AuditIssue(
                        "stop_on_wrong_side",
                        f"{event} SELL at {bar} sl={stop} not above entry={entry}",
                    )
                )
            if target >= entry:
                issues.append(
                    AuditIssue(
                        "target_on_wrong_side",
                        f"{event} SELL at {bar} tp={target} not below entry={entry}",
                    )
                )


def _check_summary(
    frame: pd.DataFrame,
    numeric: pd.DataFrame,
    summary: dict[str, str],
    issues: list[AuditIssue],
) -> None:
    """Recount the journal and compare against the counters the EA printed."""

    if not summary:
        return

    events = list(frame["event"])
    entry_rows = [i for i, e in enumerate(events) if e == "ENTRY"]
    exit_rows = [i for i, e in enumerate(events) if e == "EXIT"]
    risk_rows = [i for i, e in enumerate(events) if e == "RISK"]
    risk_labels = [reason_tokens(frame.iloc[i]["reason"]).get("label", "") for i in risk_rows]

    def _as_int(key: str) -> int | None:
        raw = summary.get(key)
        if raw is None:
            issues.append(AuditIssue("summary_missing_field", f"no {key}= in SUMMARY"))
            return None
        try:
            return int(float(raw))
        except ValueError:
            issues.append(
                AuditIssue("summary_invalid_number", f"{key}={raw!r} is not a number")
            )
            return None

    checks = {
        "entries": len(entry_rows),
        "trades": len(exit_rows),
        "rejected": risk_labels.count("PLAN_REJECTED"),
        "blocks": risk_labels.count("ENTRY_BLOCKED"),
    }
    for key, observed in checks.items():
        declared = _as_int(key)
        if declared is not None and declared != observed:
            issues.append(
                AuditIssue(
                    f"summary_{key}_mismatch",
                    f"SUMMARY {key}={declared} but journal has {observed}",
                )
            )

    trades = _as_int("trades")
    wins = _as_int("wins")
    losses = _as_int("losses")
    flats = _as_int("flats")
    if None not in (trades, wins, losses, flats):
        if wins + losses + flats != trades:
            issues.append(
                AuditIssue(
                    "summary_trade_split_mismatch",
                    f"wins={wins} losses={losses} flats={flats} do not sum to "
                    f"trades={trades}",
                )
            )

    pnl_total = 0.0
    unparsed = 0
    for i in exit_rows:
        tokens = reason_tokens(frame.iloc[i]["reason"])
        if "pnl" not in tokens:
            unparsed += 1
            continue
        try:
            pnl_total += float(tokens["pnl"])
        except ValueError:
            unparsed += 1
    if unparsed:
        issues.append(
            AuditIssue(
                "exit_missing_pnl",
                f"{unparsed} EXIT row(s) without a pnl= token",
            )
        )

    for key in ("net", "realized"):
        raw = summary.get(key)
        if raw is None:
            issues.append(AuditIssue("summary_missing_field", f"no {key}= in SUMMARY"))
            continue
        try:
            declared = float(raw)
        except ValueError:
            issues.append(
                AuditIssue("summary_invalid_number", f"{key}={raw!r} is not a number")
            )
            continue
        if key == "net":
            if abs(declared - pnl_total) > NET_TOLERANCE:
                issues.append(
                    AuditIssue(
                        "summary_net_mismatch",
                        f"SUMMARY net={declared} but EXIT pnl sums to "
                        f"{round(pnl_total, 4)}",
                    )
                )
        elif abs(declared - pnl_total) > NET_TOLERANCE:
            issues.append(
                AuditIssue(
                    "summary_realized_mismatch",
                    f"SUMMARY realized={declared} but EXIT pnl sums to "
                    f"{round(pnl_total, 4)}",
                )
            )

    equity = numeric["equity"]
    negative = equity.notna() & (equity < 0)
    if negative.any():
        issues.append(
            AuditIssue(
                "negative_equity",
                f"{int(negative.sum())} row(s) with negative equity",
            )
        )
    drawdown = numeric["drawdown_pct"]
    bad_dd = drawdown.notna() & ((drawdown < 0) | (drawdown > 100))
    if bad_dd.any():
        issues.append(
            AuditIssue(
                "drawdown_out_of_range",
                f"{int(bad_dd.sum())} row(s) with drawdown_pct outside 0..100",
            )
        )


def _check_time(
    frame: pd.DataFrame, issues: list[AuditIssue], *, offset_minutes: float
) -> tuple[pd.Series, pd.Series]:
    logged = pd.to_datetime(
        frame["logged_at"].replace("", pd.NA), utc=True, errors="coerce", format="mixed"
    )
    if logged.isna().any():
        issues.append(
            AuditIssue(
                "invalid_logged_at",
                f"{int(logged.isna().sum())} row(s) with unparseable logged_at",
            )
        )

    bars = pd.to_datetime(
        frame["bar_time"].replace("", pd.NA), utc=True, errors="coerce", format="mixed"
    )
    if bars.isna().any():
        issues.append(
            AuditIssue(
                "invalid_bar_time",
                f"{int(bars.isna().sum())} row(s) with unparseable bar_time",
            )
        )
        return logged, bars

    offset = pd.Timedelta(minutes=offset_minutes)
    bars = bars - offset
    trade_mask = frame["event"].isin(BAR_EVENTS)
    series = bars[trade_mask].dropna()
    if not series.is_monotonic_increasing:
        issues.append(
            AuditIssue(
                "not_sorted",
                "bar_time is not in non-decreasing order over trade events",
            )
        )

    timeframes = tuple(sorted(set(frame["timeframe"])))
    if len(timeframes) == 1:
        seconds = timeframe_seconds(timeframes[0])
        if seconds:
            epoch = (series - pd.Timestamp("1970-01-01", tz="UTC")) // pd.Timedelta(
                seconds=1
            )
            off_grid = epoch.astype("int64") % seconds != 0
            if off_grid.any():
                sample = ", ".join(
                    format_bar_time(value) for value in series[off_grid].head(3)
                )
                issues.append(
                    AuditIssue(
                        "off_grid",
                        f"{int(off_grid.sum())} trade bar(s) not aligned to "
                        f"{timeframes[0]}: {sample}",
                    )
                )
    return logged, bars


def audit_plan_csv(
    path: str | Path, *, offset_minutes: float = 0.0
) -> PlanAuditReport:
    """Validate one PinePlanSimEA journal; raises PineParityError when unreadable."""

    source = Path(path)
    frame = _load(source)
    issues: list[AuditIssue] = []

    events = tuple(sorted(set(frame["event"])))
    unknown_events = sorted(set(events) - set(KNOWN_EVENTS))
    if unknown_events:
        issues.append(AuditIssue("unknown_event", ", ".join(unknown_events)))

    ea_values = tuple(sorted(set(frame["ea"])))
    if any(value != EA_NAME for value in ea_values):
        issues.append(
            AuditIssue("unexpected_ea", ", ".join(v for v in ea_values if v != EA_NAME))
        )

    symbols = tuple(sorted(set(frame["symbol"])))
    timeframes = tuple(sorted(set(frame["timeframe"])))
    hashes = tuple(sorted(set(frame["config_hash"])))
    if len(symbols) > 1:
        issues.append(AuditIssue("mixed_symbols", ", ".join(symbols)))
    if len(timeframes) > 1:
        issues.append(AuditIssue("mixed_timeframes", ", ".join(timeframes)))
    if len(hashes) > 1:
        issues.append(AuditIssue("mixed_config_hash", ", ".join(hashes)))

    _logged, bars = _check_time(frame, issues, offset_minutes=offset_minutes)
    numeric = _numbers(frame, issues)
    summary = _check_framing(frame, issues)
    max_concurrent, open_at_end = _check_lifecycle(frame, numeric, issues)
    _check_geometry(frame, numeric, issues)
    _check_summary(frame, numeric, summary, issues)

    entry_sides = list(frame.loc[frame["event"] == "ENTRY", "side"])
    exit_labels = [
        reason_tokens(value).get("label", "")
        for value in frame.loc[frame["event"] == "EXIT", "reason"]
    ]
    risk_labels = [
        reason_tokens(value).get("label", "")
        for value in frame.loc[frame["event"] == "RISK", "reason"]
    ]

    trade_bars = bars[frame["event"].isin(BAR_EVENTS)].dropna()
    return PlanAuditReport(
        source=str(source),
        rows=int(len(frame)),
        ea=ea_values,
        versions=tuple(sorted(set(frame["version"]))),
        config_hashes=hashes,
        symbols=symbols,
        timeframes=timeframes,
        first_bar=format_bar_time(trade_bars.min()) if not trade_bars.empty else "",
        last_bar=format_bar_time(trade_bars.max()) if not trade_bars.empty else "",
        event_counts=_sorted_counts(list(frame["event"])),
        entry_side_counts=_sorted_counts(entry_sides),
        exit_reason_counts=_sorted_counts(exit_labels),
        risk_reason_counts=_sorted_counts(risk_labels),
        entries=len(entry_sides),
        exits=len(exit_labels),
        open_position_at_end=open_at_end,
        max_concurrent_positions=max_concurrent,
        summary=summary,
        issues=tuple(issues),
    )


def write_audit_report(report: PlanAuditReport, out_dir: str | Path) -> Path:
    target = Path(out_dir)
    target.mkdir(parents=True, exist_ok=True)
    json_path = target / "plan_audit.json"
    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return json_path
