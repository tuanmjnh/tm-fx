"""Compare Pine reference exports with the MQL5 Wonderwhales signal log.

The Pine side is a CSV exported from a TradingView run of the same symbol,
timeframe and inputs. The MQL5 side is the CSV written by ``PineSignalLabEA``.
Rows are keyed by ``(bar_open_time, symbol, timeframe)``. Signal identifiers,
side and SAR direction must match exactly; prices and ATR% use absolute
tolerances.

This module never invents reference data. A synthetic file is only useful for
testing the comparator, not as parity evidence.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

KEY_COLUMNS = ("bar_open_time", "symbol", "timeframe")
TEXT_COLUMNS = ("signal_id", "side")
INT_COLUMNS = ("sar_dir",)
PRICE_COLUMNS = ("psar", "fast", "slow")
OSCILLATOR_COLUMNS = ("atr_pct",)
REQUIRED_COLUMNS = (*KEY_COLUMNS, *TEXT_COLUMNS, *INT_COLUMNS,
                    *PRICE_COLUMNS, *OSCILLATOR_COLUMNS)
OPTIONAL_COLUMNS = ("confirmed_at", "mode", "detected_at", "input_hash")

SIGNAL_SIDES = {
    "WW_BUY_SAR_FLIP": "BUY",
    "WW_SELL_SAR_FLIP": "SELL",
    "WW_BUY_EMA_CROSS": "BUY",
    "WW_SELL_EMA_CROSS": "SELL",
    "WW_BUY_SAR_EMA": "BUY",
    "WW_SELL_SAR_EMA": "SELL",
    "WW_BUY_SAR_EMA_ATR": "BUY",
    "WW_SELL_SAR_EMA_ATR": "SELL",
}

MISMATCH_COLUMNS = (
    "bar_open_time",
    "symbol",
    "timeframe",
    "field",
    "kind",
    "pine_value",
    "mql5_value",
    "difference",
)

MISSING_IN_MQL5 = "missing_in_mql5"
MISSING_IN_PINE = "missing_in_pine"
VALUE_MISMATCH = "value_mismatch"
NAN_MISMATCH = "nan_mismatch"

_TIMEFRAME_SECONDS = {
    "M1": 60,
    "M2": 120,
    "M3": 180,
    "M4": 240,
    "M5": 300,
    "M6": 360,
    "M10": 600,
    "M12": 720,
    "M15": 900,
    "M20": 1200,
    "M30": 1800,
    "H1": 3600,
    "H2": 7200,
    "H3": 10800,
    "H4": 14400,
    "H6": 21600,
    "H8": 28800,
    "H12": 43200,
}


class PineParityError(ValueError):
    """Raised when a CSV cannot be compared safely."""


@dataclass(frozen=True)
class PineMismatch:
    bar_open_time: str
    symbol: str
    timeframe: str
    field: str
    kind: str
    pine_value: Any
    mql5_value: Any
    difference: float | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "bar_open_time": self.bar_open_time,
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "field": self.field,
            "kind": self.kind,
            "pine_value": _json_value(self.pine_value),
            "mql5_value": _json_value(self.mql5_value),
            "difference": _json_value(self.difference),
        }


@dataclass(frozen=True)
class PineParityReport:
    pine_path: str
    mql5_path: str
    tolerance_price: float
    tolerance_oscillator: float
    pine_offset_minutes: float
    mql5_offset_minutes: float
    start: str | None
    warmup_bars: int
    rows_pine: int
    rows_mql5: int
    rows_compared: int
    input_hash_checked: bool
    mismatches: tuple[PineMismatch, ...]

    @property
    def mismatch_count(self) -> int:
        return len(self.mismatches)

    @property
    def status(self) -> str:
        return "match" if not self.mismatches else "mismatch"

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "pine_path": self.pine_path,
            "mql5_path": self.mql5_path,
            "tolerance_price": self.tolerance_price,
            "tolerance_oscillator": self.tolerance_oscillator,
            "pine_offset_minutes": self.pine_offset_minutes,
            "mql5_offset_minutes": self.mql5_offset_minutes,
            "start": self.start,
            "warmup_bars": self.warmup_bars,
            "rows_pine": self.rows_pine,
            "rows_mql5": self.rows_mql5,
            "rows_compared": self.rows_compared,
            "input_hash_checked": self.input_hash_checked,
            "mismatch_count": self.mismatch_count,
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


def format_bar_time(value: pd.Timestamp) -> str:
    return value.tz_convert("UTC").strftime("%Y-%m-%dT%H:%M:%SZ")


def timeframe_seconds(timeframe: str) -> int | None:
    normalized = timeframe.strip().upper()
    if normalized.startswith("PERIOD_"):
        normalized = normalized[len("PERIOD_"):]
    return _TIMEFRAME_SECONDS.get(normalized)


def _parse_timestamps(series: pd.Series, source: Path, column: str) -> pd.Series:
    raw = series.fillna("").astype(str).str.strip()
    empty = raw == ""
    parsed = pd.to_datetime(raw.where(~empty), utc=True, errors="coerce", format="mixed")
    invalid = parsed.isna() & ~empty
    if invalid.any():
        preview = ", ".join(str(index + 2) for index in series.index[invalid][:5])
        raise PineParityError(
            f"{source} has invalid {column} at CSV line(s): {preview}"
        )
    if empty.any():
        preview = ", ".join(str(index + 2) for index in series.index[empty][:5])
        raise PineParityError(
            f"{source} has empty {column} at CSV line(s): {preview}"
        )
    return parsed


def _parse_numeric(
    series: pd.Series,
    source: Path,
    column: str,
    *,
    allow_empty: bool,
) -> pd.Series:
    raw = series.fillna("").astype(str).str.strip()
    empty = raw == ""
    if empty.any() and not allow_empty:
        preview = ", ".join(str(index + 2) for index in series.index[empty][:5])
        raise PineParityError(
            f"{source} has empty {column} at CSV line(s): {preview}"
        )
    numeric = pd.to_numeric(raw.where(~empty), errors="coerce")
    invalid = numeric.isna() & ~empty
    if invalid.any():
        preview = ", ".join(str(index + 2) for index in series.index[invalid][:5])
        raise PineParityError(
            f"{source} has non-numeric {column} at CSV line(s): {preview}"
        )
    values = numeric.to_numpy(dtype=float)
    if np.isinf(values).any():
        raise PineParityError(
            f"{source} has infinite {column}; only finite values or empty cells are allowed"
        )
    return numeric.astype(float)


def load_pine_parity_csv(
    path: str | Path, *, offset_minutes: float = 0.0
) -> pd.DataFrame:
    """Load one export and normalize timestamps to UTC.

    ``offset_minutes`` is the server offset east of UTC (GMT+3 = 180). It is
    subtracted from the parsed timestamp to obtain UTC. Use it for the MQL5
    file when ``bar_open_time`` is broker server time. Pine exports are
    expected to be UTC and use the default 0.
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
        frame = pd.read_csv(source, dtype=str)
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

    keep = [*REQUIRED_COLUMNS, *(c for c in OPTIONAL_COLUMNS if c in frame.columns)]
    frame = frame.loc[:, keep].copy()

    for column in (*KEY_COLUMNS, *TEXT_COLUMNS):
        frame[column] = frame[column].fillna("").astype(str).str.strip()
        empty = frame.index[frame[column] == ""].tolist()
        if empty:
            preview = ", ".join(str(index + 2) for index in empty[:5])
            raise PineParityError(
                f"{source} has empty {column} at CSV line(s): {preview}"
            )

    frame["bar_open_time"] = _parse_timestamps(
        frame["bar_open_time"], source, "bar_open_time"
    ) - offset
    if "confirmed_at" in frame.columns:
        frame["confirmed_at"] = _parse_timestamps(
            frame["confirmed_at"], source, "confirmed_at"
        ) - offset
    if "detected_at" in frame.columns:
        frame["detected_at"] = _parse_timestamps(
            frame["detected_at"], source, "detected_at"
        ) - offset

    for column in INT_COLUMNS:
        numeric = _parse_numeric(frame[column], source, column, allow_empty=False)
        integral = numeric == np.floor(numeric)
        if not integral.all():
            preview = ", ".join(str(index + 2) for index in frame.index[~integral][:5])
            raise PineParityError(
                f"{source} has non-integer {column} at CSV line(s): {preview}"
            )
        frame[column] = numeric.astype(int)

    for column in (*PRICE_COLUMNS, *OSCILLATOR_COLUMNS):
        frame[column] = _parse_numeric(frame[column], source, column, allow_empty=True)

    for row in frame.itertuples(index=False):
        expected_side = SIGNAL_SIDES.get(row.signal_id)
        if expected_side is None:
            raise PineParityError(f"{source} has unknown signal_id: {row.signal_id}")
        if row.side != expected_side:
            raise PineParityError(
                f"{source} has side={row.side} for {row.signal_id}; expected {expected_side}"
            )
        expected_dir = 1 if expected_side == "BUY" else -1
        if int(row.sar_dir) != expected_dir:
            raise PineParityError(
                f"{source} has sar_dir={row.sar_dir} for {row.signal_id}; "
                f"expected {expected_dir}"
            )

    if "confirmed_at" in frame.columns:
        for row in frame.itertuples(index=False):
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
            f"{format_bar_time(row.bar_open_time)}/{row.symbol}/{row.timeframe}"
            for row in keys.head(3).itertuples(index=False)
        )
        raise PineParityError(
            f"{source} has duplicate (bar_open_time, symbol, timeframe) keys: {sample}"
        )

    frame["bar_open_time"] = frame["bar_open_time"].map(format_bar_time)
    if "confirmed_at" in frame.columns:
        frame["confirmed_at"] = frame["confirmed_at"].map(format_bar_time)
    if "detected_at" in frame.columns:
        frame["detected_at"] = frame["detected_at"].map(format_bar_time)

    return frame.reset_index(drop=True)


def load_bar_times(path: str | Path) -> pd.Series:
    source = Path(path)
    try:
        frame = pd.read_csv(source, dtype=str)
    except FileNotFoundError as exc:
        raise PineParityError(f"bar time file not found: {source}") from exc
    except (OSError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
        raise PineParityError(f"cannot read bar time file {source}: {exc}") from exc

    if "bar_open_time" not in frame.columns:
        raise PineParityError(f"{source} is missing required column: bar_open_time")
    if frame.empty:
        raise PineParityError(f"{source} contains no bar times")

    parsed = _parse_timestamps(frame["bar_open_time"], source, "bar_open_time")
    return parsed.map(format_bar_time).drop_duplicates().sort_values().reset_index(drop=True)


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


def _parse_start(value: str | None) -> pd.Timestamp | None:
    if value is None or str(value).strip() == "":
        return None
    parsed = pd.to_datetime(str(value).strip(), utc=True, errors="coerce")
    if pd.isna(parsed):
        raise PineParityError(f"start is not a valid timestamp: {value!r}")
    return parsed


def compare_pine_exports(
    pine_path: str | Path,
    mql5_path: str | Path,
    *,
    tolerance_price: float = 1e-8,
    tolerance_oscillator: float = 1e-6,
    pine_offset_minutes: float = 0.0,
    mql5_offset_minutes: float = 0.0,
    start: str | None = None,
    warmup_bars: int = 0,
    bar_times_path: str | Path | None = None,
) -> PineParityReport:
    tolerance_price = _validate_tolerance(tolerance_price, "tolerance_price")
    tolerance_oscillator = _validate_tolerance(
        tolerance_oscillator, "tolerance_oscillator"
    )
    if (
        isinstance(warmup_bars, bool)
        or not isinstance(warmup_bars, int)
        or warmup_bars < 0
    ):
        raise PineParityError(f"warmup_bars must be a non-negative integer, got {warmup_bars!r}")
    if warmup_bars > 0 and bar_times_path is None:
        raise PineParityError("warmup_bars requires bar_times_path")

    pine = load_pine_parity_csv(pine_path, offset_minutes=pine_offset_minutes)
    mql5 = load_pine_parity_csv(mql5_path, offset_minutes=mql5_offset_minutes)

    start_time = _parse_start(start)
    if start_time is not None:
        start_text = format_bar_time(start_time)
        pine = pine.loc[pine["bar_open_time"] >= start_text]
        mql5 = mql5.loc[mql5["bar_open_time"] >= start_text]

    if warmup_bars > 0:
        assert bar_times_path is not None
        times = load_bar_times(bar_times_path)
        if len(times) < warmup_bars:
            raise PineParityError(
                f"bar time file has {len(times)} rows, fewer than warmup_bars={warmup_bars}"
            )
        excluded = set(times.iloc[:warmup_bars])
        pine = pine.loc[~pine["bar_open_time"].isin(excluded)]
        mql5 = mql5.loc[~mql5["bar_open_time"].isin(excluded)]

    pine = pine.reset_index(drop=True)
    mql5 = mql5.reset_index(drop=True)
    if pine.empty or mql5.empty:
        raise PineParityError(
            "no rows remain after filtering; refusing to report parity on an empty set"
        )

    merged = pine.merge(
        mql5,
        on=list(KEY_COLUMNS),
        how="outer",
        suffixes=("_pine", "_mql5"),
        indicator=True,
        validate="one_to_one",
    ).rename(columns={"_merge": "merge_state"})

    mismatches: list[PineMismatch] = []
    for row in merged.itertuples(index=False):
        key = {
            "bar_open_time": row.bar_open_time,
            "symbol": row.symbol,
            "timeframe": row.timeframe,
        }
        if row.merge_state == "left_only":
            mismatches.append(
                PineMismatch(**key, field="*", kind=MISSING_IN_MQL5,
                             pine_value=None, mql5_value=None)
            )
            continue
        if row.merge_state == "right_only":
            mismatches.append(
                PineMismatch(**key, field="*", kind=MISSING_IN_PINE,
                             pine_value=None, mql5_value=None)
            )
            continue

        for field in TEXT_COLUMNS:
            left = getattr(row, f"{field}_pine")
            right = getattr(row, f"{field}_mql5")
            if left != right:
                mismatches.append(
                    PineMismatch(**key, field=field, kind=VALUE_MISMATCH,
                                 pine_value=left, mql5_value=right)
                )

        left_dir = int(getattr(row, "sar_dir_pine"))
        right_dir = int(getattr(row, "sar_dir_mql5"))
        if left_dir != right_dir:
            mismatches.append(
                PineMismatch(**key, field="sar_dir", kind=VALUE_MISMATCH,
                             pine_value=left_dir, mql5_value=right_dir)
            )

        for field, tolerance in (
            *((column, tolerance_price) for column in PRICE_COLUMNS),
            *((column, tolerance_oscillator) for column in OSCILLATOR_COLUMNS),
        ):
            left = float(getattr(row, f"{field}_pine"))
            right = float(getattr(row, f"{field}_mql5"))
            if math.isnan(left) and math.isnan(right):
                continue
            if math.isnan(left) or math.isnan(right):
                mismatches.append(
                    PineMismatch(**key, field=field, kind=NAN_MISMATCH,
                                 pine_value=left, mql5_value=right)
                )
                continue
            difference = left - right
            if abs(difference) > tolerance:
                mismatches.append(
                    PineMismatch(**key, field=field, kind=VALUE_MISMATCH,
                                 pine_value=left, mql5_value=right,
                                 difference=difference)
                )

    input_hash_checked = "input_hash" in pine.columns and "input_hash" in mql5.columns
    if input_hash_checked:
        for row in merged.itertuples(index=False):
            if row.merge_state != "both":
                continue
            left = getattr(row, "input_hash_pine")
            right = getattr(row, "input_hash_mql5")
            if left != right:
                mismatches.append(
                    PineMismatch(
                        bar_open_time=row.bar_open_time,
                        symbol=row.symbol,
                        timeframe=row.timeframe,
                        field="input_hash",
                        kind=VALUE_MISMATCH,
                        pine_value=left,
                        mql5_value=right,
                    )
                )

    mismatches.sort(
        key=lambda item: (
            item.bar_open_time,
            item.symbol,
            item.timeframe,
            item.field,
            item.kind,
        )
    )

    return PineParityReport(
        pine_path=str(pine_path),
        mql5_path=str(mql5_path),
        tolerance_price=tolerance_price,
        tolerance_oscillator=tolerance_oscillator,
        pine_offset_minutes=float(pine_offset_minutes),
        mql5_offset_minutes=float(mql5_offset_minutes),
        start=start,
        warmup_bars=warmup_bars,
        rows_pine=int(len(pine)),
        rows_mql5=int(len(mql5)),
        rows_compared=int((merged["merge_state"] == "both").sum()),
        input_hash_checked=input_hash_checked,
        mismatches=tuple(mismatches),
    )


def write_report(
    report: PineParityReport, out_dir: str | Path
) -> tuple[Path, Path]:
    destination = Path(out_dir)
    destination.mkdir(parents=True, exist_ok=True)
    json_path = destination / "pine_mismatch_report.json"
    csv_path = destination / "pine_mismatch_report.csv"

    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    report.to_frame().to_csv(csv_path, index=False)
    return json_path, csv_path
