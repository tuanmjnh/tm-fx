"""Audit the unified CSV written by PineMultiSignalLabEA.

Structural checks only. This never compares against Pine and never claims
runtime or parity success.

The expected header is::

    detected_at,bar_open_time,confirmed_at,symbol,timeframe,source,
    contract_version,signal_id,side,dir,score,entry,sl,tp1,tp2,tp3,
    reason,input_hash
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
    "detected_at",
    "bar_open_time",
    "confirmed_at",
    "symbol",
    "timeframe",
    "source",
    "contract_version",
    "signal_id",
    "side",
    "dir",
    "score",
    "entry",
    "sl",
    "tp1",
    "tp2",
    "tp3",
    "reason",
    "input_hash",
)

KNOWN_SOURCES: tuple[str, ...] = (
    "Wonderwhales",
    "LongKacoVSA",
    "TMFusionZones",
    "PriceActionMTF",
    "TMXAUSignals2",
    "TMIndicator2",
)

PRICE_COLUMNS: tuple[str, ...] = ("entry", "sl", "tp1", "tp2", "tp3")


@dataclass(frozen=True)
class AuditIssue:
    kind: str
    detail: str

    def to_dict(self) -> dict[str, str]:
        return {"kind": self.kind, "detail": self.detail}


@dataclass(frozen=True)
class MultiSignalAuditReport:
    source: str
    rows: int
    first_bar: str
    last_bar: str
    symbols: tuple[str, ...]
    timeframes: tuple[str, ...]
    sources: tuple[str, ...]
    source_counts: dict[str, int]
    side_counts: dict[str, int]
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
            "sources": list(self.sources),
            "source_counts": dict(self.source_counts),
            "side_counts": dict(self.side_counts),
            "issue_count": len(self.issues),
            "issues": [issue.to_dict() for issue in self.issues],
        }


def _sorted_counts(series: pd.Series) -> dict[str, int]:
    counts = series.value_counts().sort_index()
    return {str(key): int(value) for key, value in counts.items()}


def _parse_float(series: pd.Series, *, column: str, issues: list[AuditIssue]) -> pd.Series:
    values = pd.to_numeric(series.replace("", pd.NA), errors="coerce")
    unparsed = series[(series != "") & values.isna()]
    if not unparsed.empty:
        issues.append(
            AuditIssue(
                f"invalid_{column}",
                f"{len(unparsed)} non-numeric {column} value(s): "
                + ", ".join(sorted(unparsed.unique())[:3]),
            )
        )
    return values


def audit_multi_signal_csv(path: str | Path) -> MultiSignalAuditReport:
    """Validate one unified export; raises PineParityError when unreadable."""

    source = Path(path)
    if not source.exists():
        raise PineParityError(f"CSV not found: {source}")

    try:
        frame = pd.read_csv(source, dtype=str, keep_default_na=False)
    except (pd.errors.ParserError, UnicodeDecodeError) as exc:
        raise PineParityError(f"cannot parse CSV: {exc}") from exc

    missing = [column for column in REQUIRED_COLUMNS if column not in frame.columns]
    if missing:
        raise PineParityError(
            "missing required column(s): " + ", ".join(missing)
        )
    if frame.empty:
        raise PineParityError("CSV has a header but no data rows")

    issues: list[AuditIssue] = []

    symbols = tuple(sorted(frame["symbol"].unique()))
    timeframes = tuple(sorted(frame["timeframe"].unique()))
    sources = tuple(sorted(frame["source"].unique()))
    if len(symbols) > 1:
        issues.append(AuditIssue("mixed_symbols", ", ".join(symbols)))
    if len(timeframes) > 1:
        issues.append(AuditIssue("mixed_timeframes", ", ".join(timeframes)))

    unknown = sorted(set(sources) - set(KNOWN_SOURCES))
    if unknown:
        issues.append(AuditIssue("unknown_source", ", ".join(unknown)))

    times = pd.to_datetime(frame["bar_open_time"], utc=True, format="mixed")
    if times.isna().any():
        issues.append(AuditIssue("invalid_bar_time", "unparseable bar_open_time row(s)"))
    else:
        if not times.is_monotonic_increasing:
            issues.append(
                AuditIssue("not_sorted", "bar_open_time is not in non-decreasing order")
            )
        duplicated = frame.assign(_bar=times).duplicated(subset=["source", "_bar"])
        if duplicated.any():
            sample = frame.loc[duplicated, ["source", "bar_open_time"]].head(3)
            detail = ", ".join(
                f"{row.source}@{row.bar_open_time}" for row in sample.itertuples()
            )
            issues.append(
                AuditIssue(
                    "duplicate_signal",
                    f"{int(duplicated.sum())} duplicate source/bar row(s): {detail}",
                )
            )

    if len(timeframes) == 1:
        seconds = timeframe_seconds(timeframes[0])
        if seconds and times.notna().all():
            epoch_seconds = (times - pd.Timestamp("1970-01-01", tz="UTC")) // pd.Timedelta(
                seconds=1
            )
            off_grid = epoch_seconds.astype("int64") % seconds != 0
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

    bad_sides = sorted(set(frame["side"]) - {"BUY", "SELL"})
    if bad_sides:
        issues.append(AuditIssue("invalid_side", ", ".join(bad_sides)))

    dir_values = pd.to_numeric(frame["dir"].replace("", pd.NA), errors="coerce")
    unresolved_dir = frame["dir"] != ""
    bad_dir = unresolved_dir & ~dir_values.isin([-1, 0, 1])
    if bad_dir.any():
        sample = ", ".join(sorted(frame.loc[bad_dir, "dir"].unique())[:3])
        issues.append(AuditIssue("invalid_dir", sample))
    empty_dir = (frame["dir"] == "").sum()
    if empty_dir:
        issues.append(AuditIssue("empty_dir", f"{int(empty_dir)} empty dir cell(s)"))

    score = _parse_float(frame["score"], column="score", issues=issues)
    out_of_range = score.notna() & ((score < 0) | (score > 100))
    if out_of_range.any():
        issues.append(
            AuditIssue(
                "score_out_of_range",
                f"{int(out_of_range.sum())} score(s) outside 0..100",
            )
        )

    for column in PRICE_COLUMNS:
        values = _parse_float(frame[column], column=column, issues=issues)
        negative = values.notna() & (values < 0)
        if negative.any():
            issues.append(
                AuditIssue(
                    f"negative_{column}",
                    f"{int(negative.sum())} negative {column} value(s)",
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

    valid_times = times.dropna()
    return MultiSignalAuditReport(
        source=str(source),
        rows=int(len(frame)),
        first_bar=format_bar_time(valid_times.min()) if not valid_times.empty else "",
        last_bar=format_bar_time(valid_times.max()) if not valid_times.empty else "",
        symbols=symbols,
        timeframes=timeframes,
        sources=sources,
        source_counts=_sorted_counts(frame["source"]),
        side_counts=_sorted_counts(frame["side"]),
        issues=tuple(issues),
    )


def write_audit_report(report: MultiSignalAuditReport, out_dir: str | Path) -> Path:
    target = Path(out_dir)
    target.mkdir(parents=True, exist_ok=True)
    json_path = target / "multi_signal_audit.json"
    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return json_path
