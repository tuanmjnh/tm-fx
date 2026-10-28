"""Audit a signal CSV produced by the MQL5 Wonderwhales EA.

This checks structural integrity of a single EA export. It is not a parity
check: parity needs a real Pine reference and lives in ``pine_parity``.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd

from mt5_ea_ai_lab.evaluation.pine_parity import (
    PRICE_COLUMNS,
    format_bar_time,
    load_pine_parity_csv,
    timeframe_seconds,
)

_EPOCH = pd.Timestamp("1970-01-01", tz="UTC")


@dataclass(frozen=True)
class AuditIssue:
    kind: str
    detail: str

    def to_dict(self) -> dict[str, str]:
        return {"kind": self.kind, "detail": self.detail}


@dataclass(frozen=True)
class SignalAuditReport:
    source: str
    rows: int
    first_bar: str
    last_bar: str
    symbols: tuple[str, ...]
    timeframes: tuple[str, ...]
    signal_counts: dict[str, int]
    side_counts: dict[str, int]
    empty_price_cells: int
    empty_atr_cells: int
    issues: tuple[AuditIssue, ...]

    @property
    def status(self) -> str:
        return "ok" if not self.issues else "issues"

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "source": self.source,
            "rows": self.rows,
            "first_bar": self.first_bar,
            "last_bar": self.last_bar,
            "symbols": list(self.symbols),
            "timeframes": list(self.timeframes),
            "signal_counts": dict(self.signal_counts),
            "side_counts": dict(self.side_counts),
            "empty_price_cells": self.empty_price_cells,
            "empty_atr_cells": self.empty_atr_cells,
            "issue_count": len(self.issues),
            "issues": [issue.to_dict() for issue in self.issues],
        }


def _sorted_counts(series: pd.Series) -> dict[str, int]:
    counts = series.value_counts().sort_index()
    return {str(key): int(value) for key, value in counts.items()}


def audit_signal_csv(
    path: str | Path, *, offset_minutes: float = 0.0
) -> SignalAuditReport:
    """Validate one EA export; raises PineParityError when it is unreadable."""

    source = Path(path)
    frame = load_pine_parity_csv(source, offset_minutes=offset_minutes)
    issues: list[AuditIssue] = []

    symbols = tuple(sorted(frame["symbol"].unique()))
    timeframes = tuple(sorted(frame["timeframe"].unique()))
    if len(symbols) > 1:
        issues.append(AuditIssue("mixed_symbols", ", ".join(symbols)))
    if len(timeframes) > 1:
        issues.append(AuditIssue("mixed_timeframes", ", ".join(timeframes)))
    if "mode" in frame.columns:
        modes = tuple(sorted(frame["mode"].unique()))
        if len(modes) > 1:
            issues.append(AuditIssue("mixed_modes", ", ".join(modes)))
    if "input_hash" in frame.columns:
        hashes = tuple(sorted(frame["input_hash"].unique()))
        if len(hashes) > 1:
            issues.append(AuditIssue("mixed_input_hash", ", ".join(hashes)))

    times = pd.to_datetime(frame["bar_open_time"], utc=True, format="mixed")
    if not times.is_monotonic_increasing:
        issues.append(
            AuditIssue("not_sorted", "bar_open_time is not in non-decreasing order")
        )
    if times.duplicated().any():
        duplicates = times[times.duplicated()].head(3)
        issues.append(
            AuditIssue(
                "duplicate_bar_time",
                ", ".join(format_bar_time(value) for value in duplicates),
            )
        )

    if len(timeframes) == 1:
        seconds = timeframe_seconds(timeframes[0])
        if seconds:
            epoch_seconds = (
                (times - _EPOCH) // pd.Timedelta(seconds=1)
            ).astype("int64")
            off_grid = epoch_seconds % seconds != 0
            if off_grid.any():
                sample = ", ".join(
                    format_bar_time(value) for value in times[off_grid].head(3)
                )
                issues.append(
                    AuditIssue(
                        "off_grid",
                        f"{int(off_grid.sum())} bar(s) not aligned to "
                        f"{timeframes[0]}: {sample}",
                    )
                )

    empty_prices = int(frame[list(PRICE_COLUMNS)].isna().sum().sum())
    if empty_prices:
        issues.append(
            AuditIssue("empty_price", f"{empty_prices} empty psar/fast/slow cell(s)")
        )
    empty_atr = int(frame["atr_pct"].isna().sum())
    if empty_atr:
        issues.append(AuditIssue("empty_atr_pct", f"{empty_atr} empty atr_pct cell(s)"))

    negative_atr = frame["atr_pct"] < 0
    if negative_atr.any():
        issues.append(
            AuditIssue(
                "negative_atr_pct",
                f"{int(negative_atr.sum())} row(s) with negative atr_pct",
            )
        )

    if {"detected_at", "confirmed_at"}.issubset(frame.columns):
        detected = pd.to_datetime(frame["detected_at"], utc=True, format="mixed")
        confirmed = pd.to_datetime(frame["confirmed_at"], utc=True, format="mixed")
        early = detected < confirmed
        if early.any():
            sample = ", ".join(
                format_bar_time(value) for value in times[early].head(3)
            )
            issues.append(
                AuditIssue(
                    "detected_before_confirmed",
                    f"{int(early.sum())} row(s) detected before bar close: {sample}",
                )
            )

    return SignalAuditReport(
        source=str(source),
        rows=int(len(frame)),
        first_bar=format_bar_time(times.min()),
        last_bar=format_bar_time(times.max()),
        symbols=symbols,
        timeframes=timeframes,
        signal_counts=_sorted_counts(frame["signal_id"]),
        side_counts=_sorted_counts(frame["side"]),
        empty_price_cells=empty_prices,
        empty_atr_cells=empty_atr,
        issues=tuple(issues),
    )


def write_audit_report(report: SignalAuditReport, out_dir: str | Path) -> Path:
    target = Path(out_dir)
    target.mkdir(parents=True, exist_ok=True)
    json_path = target / "signal_audit.json"
    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return json_path
