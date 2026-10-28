"""Load OHLCV datasets and normalize column names.

The loader never modifies source files and never sorts or de-duplicates rows;
quality problems are reported by :mod:`mt5_ea_ai_lab.validation` instead of
being silently repaired.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd

REQUIRED_COLUMNS: tuple[str, ...] = (
    "timestamp",
    "open",
    "high",
    "low",
    "close",
    "tick_volume",
)
OPTIONAL_COLUMNS: tuple[str, ...] = ("spread", "real_volume")
PRICE_COLUMNS: tuple[str, ...] = ("open", "high", "low", "close")
DATA_KINDS: tuple[str, ...] = ("unknown", "synthetic", "market")

_COLUMN_ALIASES: dict[str, str] = {
    "time": "time",
    "datetime": "timestamp",
    "date_time": "timestamp",
    "open": "open",
    "high": "high",
    "low": "low",
    "close": "close",
    "tickvol": "tick_volume",
    "tick_vol": "tick_volume",
    "tick_volume": "tick_volume",
    "volume": "tick_volume",
    "vol": "tick_volume",
    "realvol": "real_volume",
    "real_vol": "real_volume",
    "real_volume": "real_volume",
    "spread": "spread",
    "symbol": "symbol",
    "ticker": "symbol",
    "timeframe": "timeframe",
    "period": "timeframe",
}


class DataLoadError(ValueError):
    """Raised when a dataset cannot be read or normalized."""


@dataclass(frozen=True)
class DatasetMetadata:
    """Facts about a loaded dataset; no timestamps are generated."""

    source_path: str
    file_format: str
    data_kind: str
    timezone: str
    rows: int
    original_columns: tuple[str, ...]
    normalized_columns: tuple[str, ...]
    symbol: str | None
    timeframe: str | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "source_path": self.source_path,
            "file_format": self.file_format,
            "data_kind": self.data_kind,
            "timezone": self.timezone,
            "rows": self.rows,
            "original_columns": list(self.original_columns),
            "normalized_columns": list(self.normalized_columns),
            "symbol": self.symbol,
            "timeframe": self.timeframe,
        }


def _normalize_column_name(name: str) -> str:
    cleaned = str(name).strip().strip("<>").strip().lower()
    cleaned = cleaned.replace(" ", "_").replace("-", "_")
    return _COLUMN_ALIASES.get(cleaned, cleaned)


def _read_frame(path: Path, separator: str) -> pd.DataFrame:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        try:
            return pd.read_csv(path, sep=separator)
        except pd.errors.EmptyDataError:
            return pd.DataFrame()
    if suffix in (".parquet", ".pq"):
        try:
            return pd.read_parquet(path)
        except ImportError as exc:
            raise DataLoadError(
                "Parquet support requires pyarrow; install it with "
                "`python -m pip install pyarrow`."
            ) from exc
    raise DataLoadError(f"unsupported dataset format: {suffix or '<none>'}")


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    normalized = [_normalize_column_name(column) for column in df.columns]
    duplicates = sorted({name for name in normalized if normalized.count(name) > 1})
    if duplicates:
        raise DataLoadError(
            "duplicate columns after normalization: " + ", ".join(duplicates)
        )
    frame = df.copy()
    frame.columns = normalized

    if "timestamp" not in frame.columns:
        if "date" in frame.columns and "time" in frame.columns:
            frame["timestamp"] = (
                frame["date"].astype(str).str.strip()
                + " "
                + frame["time"].astype(str).str.strip()
            )
        elif "date" in frame.columns:
            frame["timestamp"] = frame["date"]
        elif "time" in frame.columns:
            frame["timestamp"] = frame["time"]
    return frame


def _coerce_numeric_columns(df: pd.DataFrame) -> pd.DataFrame:
    frame = df.copy()
    numeric_columns = [
        column
        for column in (*REQUIRED_COLUMNS, *OPTIONAL_COLUMNS)
        if column != "timestamp" and column in frame.columns
    ]
    for column in numeric_columns:
        frame[column] = pd.to_numeric(frame[column], errors="coerce")
    return frame


def _parse_timestamps(df: pd.DataFrame, timezone: str) -> pd.DataFrame:
    frame = df.copy()
    if "timestamp" not in frame.columns:
        return frame

    try:
        parsed = pd.to_datetime(frame["timestamp"], errors="coerce", utc=False)
    except (ValueError, TypeError) as exc:
        raise DataLoadError(f"cannot parse timestamp column: {exc}") from exc

    if isinstance(parsed.dtype, pd.DatetimeTZDtype):
        frame["timestamp"] = parsed.dt.tz_convert("UTC")
    else:
        try:
            frame["timestamp"] = parsed.dt.tz_localize(timezone).dt.tz_convert("UTC")
        except (TypeError, ValueError, pd.errors.OutOfBoundsDatetime) as exc:
            raise DataLoadError(
                f"cannot localize timestamps to timezone {timezone!r}: {exc}"
            ) from exc
    return frame


def _single_value(df: pd.DataFrame, column: str) -> str | None:
    if column not in df.columns:
        return None
    values = df[column].dropna().astype(str).str.strip()
    values = values[values != ""].unique()
    return str(values[0]) if len(values) == 1 else None


def load_ohlcv(
    path: str | Path,
    *,
    symbol: str | None = None,
    timeframe: str | None = None,
    timezone: str = "UTC",
    data_kind: str = "unknown",
    separator: str = ",",
) -> tuple[pd.DataFrame, DatasetMetadata]:
    """Load a CSV/Parquet OHLCV file without repairing its contents.

    ``timezone`` describes how to interpret timestamp values that carry no
    offset. Timestamps with an offset are converted to UTC; timestamps without
    one are localized to ``timezone`` and then converted to UTC.
    """

    if data_kind not in DATA_KINDS:
        raise DataLoadError(
            f"data_kind must be one of {DATA_KINDS}, got {data_kind!r}"
        )

    source = Path(path)
    if not source.exists():
        raise FileNotFoundError(source)
    if not source.is_file():
        raise DataLoadError(f"dataset path is not a file: {source}")

    raw = _read_frame(source, separator)
    original_columns = tuple(str(column) for column in raw.columns)
    frame = _normalize_columns(raw)
    frame = _coerce_numeric_columns(frame)
    frame = _parse_timestamps(frame, timezone)

    canonical_present = [
        column
        for column in (*REQUIRED_COLUMNS, *OPTIONAL_COLUMNS)
        if column in frame.columns
    ]
    extras = [column for column in frame.columns if column not in canonical_present]
    frame = frame[canonical_present + extras]

    resolved_symbol = symbol or _single_value(frame, "symbol")
    resolved_timeframe = timeframe or _single_value(frame, "timeframe")

    metadata = DatasetMetadata(
        source_path=str(source),
        file_format=source.suffix.lower().lstrip("."),
        data_kind=data_kind,
        timezone=timezone,
        rows=int(len(frame)),
        original_columns=original_columns,
        normalized_columns=tuple(str(column) for column in frame.columns),
        symbol=resolved_symbol,
        timeframe=resolved_timeframe,
    )
    return frame, metadata
