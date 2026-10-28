"""Compare a Pine reference export with the unified MQL5 multi-source log.

Both files use the 18-column schema written by ``PineMultiSignalLabEA``::

    detected_at,bar_open_time,confirmed_at,symbol,timeframe,source,
    contract_version,signal_id,side,dir,score,entry,sl,tp1,tp2,tp3,
    reason,input_hash

Rows are keyed by ``(source, bar_open_time, symbol, timeframe)``. Signal ID,
side, direction and optional text columns must match exactly; scores and
prices use absolute tolerances.

This module never invents reference data. Synthetic frames in the tests only
exercise the comparator; they are not parity evidence.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from mt5_ea_ai_lab.evaluation.multi_signal_audit import KNOWN_SOURCES
from mt5_ea_ai_lab.evaluation.pine_parity import (
    PineParityError,
    _parse_numeric,
    _parse_timestamps,
    format_bar_time,
    timeframe_seconds,
)

KEY_COLUMNS = ("source", "bar_open_time", "symbol", "timeframe")
REQUIRED_COLUMNS = (
    "source",
    "bar_open_time",
    "symbol",
    "timeframe",
    "signal_id",
    "side",
    "dir",
    "score",
    "entry",
    "sl",
    "tp1",
    "tp2",
    "tp3",
)
EXACT_COLUMNS = ("signal_id", "side")
OPTIONAL_EXACT_COLUMNS = ("contract_version", "reason", "input_hash")
PRICE_COLUMNS = ("entry", "sl", "tp1", "tp2", "tp3")
SCORE_COLUMNS = ("score",)
TIMESTAMP_COLUMNS = ("bar_open_time", "confirmed_at", "detected_at")

MISSING_IN_MQL5 = "missing_in_mql5"
MISSING_IN_REFERENCE = "missing_in_reference"
VALUE_MISMATCH = "value_mismatch"
NAN_MISMATCH = "nan_mismatch"

MISMATCH_COLUMNS = (
    "source",
    "bar_open_time",
    "symbol",
    "timeframe",
    "field",
    "kind",
    "reference_value",
    "mql5_value",
    "difference",
)


@dataclass(frozen=True)
class MultiSourceMismatch:
    source: str
    bar_open_time: str
    symbol: str
    timeframe: str
    field: str
    kind: str
    reference_value: Any
    mql5_value: Any
    difference: float | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "bar_open_time": self.bar_open_time,
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "field": self.field,
            "kind": self.kind,
            "reference_value": _json_value(self.reference_value),
            "mql5_value": _json_value(self.mql5_value),
            "difference": _json_value(self.difference),
        }


@dataclass(frozen=True)
class SourceSummary:
    source: str
    reference_rows: int
    mql5_rows: int
    compared_rows: int
    mismatch_count: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "reference_rows": self.reference_rows,
            "mql5_rows": self.mql5_rows,
            "compared_rows": self.compared_rows,
            "mismatch_count": self.mismatch_count,
        }


@dataclass(frozen=True)
class MultiSourceParityReport:
    reference_path: str
    mql5_path: str
    tolerance_price: float
    tolerance_score: float
    reference_offset_minutes: float
    mql5_offset_minutes: float
    rows_reference: int
    rows_mql5: int
    rows_compared: int
    sources: tuple[SourceSummary, ...]
    mismatches: tuple[MultiSourceMismatch, ...]

    @property
    def mismatch_count(self) -> int:
        return len(self.mismatches)

    @property
    def status(self) -> str:
        return "match" if not self.mismatches else "mismatch"

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "reference_path": self.reference_path,
            "mql5_path": self.mql5_path,
            "tolerance_price": self.tolerance_price,
            "tolerance_score": self.tolerance_score,
            "reference_offset_minutes": self.reference_offset_minutes,
            "mql5_offset_minutes": self.mql5_offset_minutes,
            "rows_reference": self.rows_reference,
            "rows_mql5": self.rows_mql5,
            "rows_compared": self.rows_compared,
            "mismatch_count": self.mismatch_count,
            "sources": [item.to_dict() for item in self.sources],
            "mismatches": [item.to_dict() for item in self.mismatches],
        }

    def to_frame(self) -> pd.DataFrame:
        return pd.DataFrame(
            [item.to_dict() for item in self.mismatches],
            columns=MISMATCH_COLUMNS,
        )


def _json_value(value: Any) -> Any:
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, np.floating):
        number = float(value)
        return number if math.isfinite(number) else None
    if isinstance(value, np.integer):
        return int(value)
    return value


def _parse_optional_timestamps(
    series: pd.Series, source: Path, column: str
) -> pd.Series:
    raw = series.fillna("").astype(str).str.strip()
    empty = raw == ""
    parsed = pd.to_datetime(
        raw.where(~empty), utc=True, errors="coerce", format="mixed"
    )
    invalid = parsed.isna() & ~empty
    if invalid.any():
        preview = ", ".join(str(index + 2) for index in series.index[invalid][:5])
        raise PineParityError(
            f"{source} has invalid {column} at CSV line(s): {preview}"
        )
    return parsed


def _validate_tolerance(value: float, label: str) -> float:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not math.isfinite(float(value))
        or float(value) < 0
    ):
        raise PineParityError(
            f"{label} must be a finite, non-negative number, got {value!r}"
        )
    return float(value)


def load_multi_source_csv(
    path: str | Path, *, offset_minutes: float = 0.0
) -> pd.DataFrame:
    """Load one unified export and normalize timestamps to UTC.

    ``offset_minutes`` is the server offset east of UTC and is subtracted from
    parsed timestamps. Pine exports are expected to be UTC.
    """

    if (
        isinstance(offset_minutes, bool)
        or not isinstance(offset_minutes, (int, float))
        or not math.isfinite(float(offset_minutes))
    ):
        raise PineParityError(f"offset_minutes must be finite, got {offset_minutes!r}")
    offset = pd.Timedelta(minutes=float(offset_minutes))

    source = Path(path)
    try:
        frame = pd.read_csv(source, dtype=str, keep_default_na=False)
    except FileNotFoundError as exc:
        raise PineParityError(f"signal file not found: {source}") from exc
    except (OSError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
        raise PineParityError(f"cannot read signal file {source}: {exc}") from exc

    missing = [column for column in REQUIRED_COLUMNS if column not in frame.columns]
    if missing:
        raise PineParityError(
            f"{source} is missing required columns: {', '.join(missing)}"
        )
    if frame.empty:
        raise PineParityError(f"{source} contains no signal rows")

    optional = [
        column
        for column in (*OPTIONAL_EXACT_COLUMNS, "confirmed_at", "detected_at")
        if column in frame.columns
    ]
    keep = [*REQUIRED_COLUMNS, *optional]
    frame = frame.loc[:, list(dict.fromkeys(keep))].copy()
    frame = frame.fillna("").astype(str)

    for column in ("source", "symbol", "timeframe", *EXACT_COLUMNS):
        frame[column] = frame[column].str.strip()
        empty = frame.index[frame[column] == ""].tolist()
        if empty:
            preview = ", ".join(str(index + 2) for index in empty[:5])
            raise PineParityError(
                f"{source} has empty {column} at CSV line(s): {preview}"
            )

    for column in optional:
        frame[column] = frame[column].str.strip()

    unknown = sorted(set(frame["source"]) - set(KNOWN_SOURCES))
    if unknown:
        raise PineParityError(
            f"{source} has unknown source(s): {', '.join(unknown)}"
        )

    bad_sides = sorted(set(frame["side"]) - {"BUY", "SELL"})
    if bad_sides:
        raise PineParityError(
            f"{source} has invalid side value(s): {', '.join(bad_sides)}"
        )

    frame["bar_open_time"] = _parse_timestamps(
        frame["bar_open_time"], source, "bar_open_time"
    ) - offset
    for column in ("confirmed_at", "detected_at"):
        if column in frame.columns:
            frame[column] = _parse_optional_timestamps(
                frame[column], source, column
            ) - offset

    numeric = _parse_numeric(frame["dir"], source, "dir", allow_empty=False)
    integral = numeric == np.floor(numeric)
    if not integral.all():
        preview = ", ".join(str(index + 2) for index in frame.index[~integral][:5])
        raise PineParityError(
            f"{source} has non-integer dir at CSV line(s): {preview}"
        )
    frame["dir"] = numeric.astype(int)

    for column in (*PRICE_COLUMNS, *SCORE_COLUMNS):
        frame[column] = _parse_numeric(frame[column], source, column, allow_empty=True)

    if "confirmed_at" in frame.columns:
        for row in frame.itertuples(index=False):
            if pd.isna(row.confirmed_at):
                continue
            seconds = timeframe_seconds(row.timeframe)
            if seconds is None:
                continue
            expected = row.bar_open_time + pd.Timedelta(seconds=seconds)
            if row.confirmed_at != expected:
                raise PineParityError(
                    f"{source} has confirmed_at={format_bar_time(row.confirmed_at)} "
                    f"for bar {format_bar_time(row.bar_open_time)}; "
                    f"expected {format_bar_time(expected)}"
                )

    duplicated = frame.duplicated(subset=list(KEY_COLUMNS), keep=False)
    if duplicated.any():
        keys = frame.loc[duplicated, list(KEY_COLUMNS)].drop_duplicates()
        sample = "; ".join(
            f"{row.source}@{format_bar_time(row.bar_open_time)}"
            for row in keys.head(3).itertuples(index=False)
        )
        raise PineParityError(
            f"{source} has duplicate (source, bar_open_time, symbol, timeframe) "
            f"keys: {sample}"
        )

    for column in TIMESTAMP_COLUMNS:
        if column in frame.columns:
            frame[column] = frame[column].map(
                lambda value: "" if pd.isna(value) else format_bar_time(value)
            )

    return frame.reset_index(drop=True)


def compare_multi_source_exports(
    reference_path: str | Path,
    mql5_path: str | Path,
    *,
    tolerance_price: float = 1e-8,
    tolerance_score: float = 1e-6,
    reference_offset_minutes: float = 0.0,
    mql5_offset_minutes: float = 0.0,
) -> MultiSourceParityReport:
    tolerance_price = _validate_tolerance(tolerance_price, "tolerance_price")
    tolerance_score = _validate_tolerance(tolerance_score, "tolerance_score")

    reference = load_multi_source_csv(
        reference_path, offset_minutes=reference_offset_minutes
    )
    mql5 = load_multi_source_csv(mql5_path, offset_minutes=mql5_offset_minutes)

    merged = reference.merge(
        mql5,
        on=list(KEY_COLUMNS),
        how="outer",
        suffixes=("_reference", "_mql5"),
        indicator=True,
        validate="one_to_one",
    ).rename(columns={"_merge": "merge_state"})

    optional_columns = [
        column
        for column in OPTIONAL_EXACT_COLUMNS
        if column in reference.columns and column in mql5.columns
    ]

    mismatches: list[MultiSourceMismatch] = []
    for row in merged.itertuples(index=False):
        key = {
            "source": row.source,
            "bar_open_time": row.bar_open_time,
            "symbol": row.symbol,
            "timeframe": row.timeframe,
        }
        if row.merge_state == "left_only":
            mismatches.append(
                MultiSourceMismatch(
                    **key, field="*", kind=MISSING_IN_MQL5,
                    reference_value=None, mql5_value=None,
                )
            )
            continue
        if row.merge_state == "right_only":
            mismatches.append(
                MultiSourceMismatch(
                    **key, field="*", kind=MISSING_IN_REFERENCE,
                    reference_value=None, mql5_value=None,
                )
            )
            continue

        for field in (*EXACT_COLUMNS, "dir", *optional_columns):
            left = getattr(row, f"{field}_reference")
            right = getattr(row, f"{field}_mql5")
            if field == "dir":
                left, right = int(left), int(right)
            if left != right:
                mismatches.append(
                    MultiSourceMismatch(
                        **key, field=field, kind=VALUE_MISMATCH,
                        reference_value=left, mql5_value=right,
                    )
                )

        for field, tolerance in (
            *((column, tolerance_price) for column in PRICE_COLUMNS),
            *((column, tolerance_score) for column in SCORE_COLUMNS),
        ):
            left = float(getattr(row, f"{field}_reference"))
            right = float(getattr(row, f"{field}_mql5"))
            if math.isnan(left) and math.isnan(right):
                continue
            if math.isnan(left) or math.isnan(right):
                mismatches.append(
                    MultiSourceMismatch(
                        **key, field=field, kind=NAN_MISMATCH,
                        reference_value=left, mql5_value=right,
                    )
                )
                continue
            difference = left - right
            if abs(difference) > tolerance:
                mismatches.append(
                    MultiSourceMismatch(
                        **key, field=field, kind=VALUE_MISMATCH,
                        reference_value=left, mql5_value=right,
                        difference=difference,
                    )
                )

    mismatches.sort(
        key=lambda item: (
            item.bar_open_time,
            item.source,
            item.symbol,
            item.timeframe,
            item.field,
            item.kind,
        )
    )

    compared = merged.loc[merged["merge_state"] == "both"]
    summaries: list[SourceSummary] = []
    for source_name in sorted(set(reference["source"]) | set(mql5["source"])):
        source_mismatches = sum(
            1 for item in mismatches if item.source == source_name
        )
        summaries.append(
            SourceSummary(
                source=source_name,
                reference_rows=int((reference["source"] == source_name).sum()),
                mql5_rows=int((mql5["source"] == source_name).sum()),
                compared_rows=int((compared["source"] == source_name).sum()),
                mismatch_count=source_mismatches,
            )
        )

    return MultiSourceParityReport(
        reference_path=str(reference_path),
        mql5_path=str(mql5_path),
        tolerance_price=tolerance_price,
        tolerance_score=tolerance_score,
        reference_offset_minutes=float(reference_offset_minutes),
        mql5_offset_minutes=float(mql5_offset_minutes),
        rows_reference=int(len(reference)),
        rows_mql5=int(len(mql5)),
        rows_compared=int(len(compared)),
        sources=tuple(summaries),
        mismatches=tuple(mismatches),
    )


def write_parity_report(
    report: MultiSourceParityReport, out_dir: str | Path
) -> tuple[Path, Path]:
    destination = Path(out_dir)
    destination.mkdir(parents=True, exist_ok=True)
    json_path = destination / "multi_source_parity.json"
    csv_path = destination / "multi_source_parity_mismatches.csv"

    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    report.to_frame().to_csv(csv_path, index=False)
    return json_path, csv_path
