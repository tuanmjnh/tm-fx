"""Compare MQL5 and Python signal exports.

Text fields (signal, reason) must match exactly. Numeric fields use an
absolute tolerance. Rows are keyed by ``(timestamp, symbol, timeframe)`` so
row order does not affect the result, and every row in both files is compared.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

KEY_COLUMNS = ("timestamp", "symbol", "timeframe")
TEXT_COLUMNS = ("signal", "reason")
NUMERIC_COLUMNS = ("fast_prev", "slow_prev", "fast", "slow")
PARITY_COLUMNS = (*KEY_COLUMNS, *TEXT_COLUMNS, *NUMERIC_COLUMNS)
MISMATCH_COLUMNS = (
    "timestamp",
    "symbol",
    "timeframe",
    "field",
    "kind",
    "mql5_value",
    "python_value",
    "difference",
)

MISSING_IN_MQL5 = "missing_in_mql5"
MISSING_IN_PYTHON = "missing_in_python"
VALUE_MISMATCH = "value_mismatch"
NAN_MISMATCH = "nan_mismatch"


class SignalComparisonError(ValueError):
    """Raised when a signal CSV cannot be compared safely."""


@dataclass(frozen=True)
class Mismatch:
    timestamp: str
    symbol: str
    timeframe: str
    field: str
    kind: str
    mql5_value: Any
    python_value: Any
    difference: float | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "timestamp": self.timestamp,
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "field": self.field,
            "kind": self.kind,
            "mql5_value": _json_value(self.mql5_value),
            "python_value": _json_value(self.python_value),
            "difference": _json_value(self.difference),
        }


@dataclass(frozen=True)
class ParityReport:
    mql5_path: str
    python_path: str
    tolerance: float
    rows_mql5: int
    rows_python: int
    rows_compared: int
    mismatches: tuple[Mismatch, ...]

    @property
    def mismatch_count(self) -> int:
        return len(self.mismatches)

    @property
    def status(self) -> str:
        return "match" if not self.mismatches else "mismatch"

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "tolerance": self.tolerance,
            "mql5_path": self.mql5_path,
            "python_path": self.python_path,
            "rows_mql5": self.rows_mql5,
            "rows_python": self.rows_python,
            "rows_compared": self.rows_compared,
            "mismatch_count": self.mismatch_count,
            "mismatches": [mismatch.to_dict() for mismatch in self.mismatches],
        }

    def to_frame(self) -> pd.DataFrame:
        return pd.DataFrame(
            [mismatch.to_dict() for mismatch in self.mismatches],
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


def format_timestamp(value: pd.Timestamp) -> str:
    return value.tz_convert("UTC").isoformat().replace("+00:00", "Z")


def load_signal_csv(path: str | Path) -> pd.DataFrame:
    """Load and validate one signal export with canonical columns."""

    source = Path(path)
    try:
        frame = pd.read_csv(source, dtype=str)
    except FileNotFoundError as exc:
        raise SignalComparisonError(f"signal file not found: {source}") from exc
    except (OSError, pd.errors.ParserError, pd.errors.EmptyDataError) as exc:
        raise SignalComparisonError(f"cannot read signal file {source}: {exc}") from exc

    missing = [column for column in PARITY_COLUMNS if column not in frame.columns]
    if missing:
        raise SignalComparisonError(
            f"{source} is missing required columns: {', '.join(missing)}"
        )
    if frame.empty:
        raise SignalComparisonError(f"{source} contains no signal rows")

    frame = frame.loc[:, list(PARITY_COLUMNS)].copy()
    for column in (*KEY_COLUMNS, *TEXT_COLUMNS):
        frame[column] = frame[column].fillna("").astype(str).str.strip()

    for column in (*KEY_COLUMNS, *TEXT_COLUMNS):
        empty = frame.index[frame[column] == ""].tolist()
        if empty:
            preview = ", ".join(str(index + 2) for index in empty[:5])
            raise SignalComparisonError(
                f"{source} has empty {column} at CSV line(s): {preview}"
            )

    parsed_timestamps = pd.to_datetime(
        frame["timestamp"], utc=True, errors="coerce", format="ISO8601"
    )
    invalid_timestamps = frame.index[parsed_timestamps.isna()].tolist()
    if invalid_timestamps:
        preview = ", ".join(str(index + 2) for index in invalid_timestamps[:5])
        raise SignalComparisonError(
            f"{source} has invalid timestamps at CSV line(s): {preview}"
        )
    frame["timestamp"] = parsed_timestamps.map(format_timestamp)

    for column in NUMERIC_COLUMNS:
        numeric = pd.to_numeric(frame[column], errors="coerce")
        invalid = frame[column].notna() & numeric.isna()
        if invalid.any():
            preview = ", ".join(str(index + 2) for index in frame.index[invalid][:5])
            raise SignalComparisonError(
                f"{source} has non-numeric {column} at CSV line(s): {preview}"
            )
        if np.isinf(numeric.to_numpy(dtype=float)).any():
            raise SignalComparisonError(
                f"{source} has infinite {column}; only finite values or empty cells are allowed"
            )
        frame[column] = numeric.astype(float)

    duplicated = frame.duplicated(subset=list(KEY_COLUMNS), keep=False)
    if duplicated.any():
        keys = frame.loc[duplicated, list(KEY_COLUMNS)].drop_duplicates()
        sample = "; ".join(
            f"{row.timestamp}/{row.symbol}/{row.timeframe}"
            for row in keys.head(3).itertuples(index=False)
        )
        raise SignalComparisonError(
            f"{source} has duplicate (timestamp, symbol, timeframe) keys: {sample}"
        )

    return frame.reset_index(drop=True)


def compare_signal_files(
    mql5_path: str | Path,
    python_path: str | Path,
    *,
    tolerance: float = 1e-9,
) -> ParityReport:
    """Compare every row of two signal exports.

    ``tolerance`` is an absolute tolerance applied only to numeric fields.
    Signals and reasons are compared exactly, so tolerance cannot hide a
    logic difference.
    """

    if (
        isinstance(tolerance, bool)
        or not isinstance(tolerance, (int, float))
        or not math.isfinite(float(tolerance))
        or tolerance < 0
    ):
        raise SignalComparisonError(
            f"tolerance must be a finite, non-negative number, got {tolerance!r}"
        )

    mql5 = load_signal_csv(mql5_path)
    python = load_signal_csv(python_path)

    merged = mql5.merge(
        python,
        on=list(KEY_COLUMNS),
        how="outer",
        suffixes=("_mql5", "_python"),
        indicator=True,
        validate="one_to_one",
    ).rename(columns={"_merge": "merge_state"})

    mismatches: list[Mismatch] = []
    for row in merged.itertuples(index=False):
        key = {
            "timestamp": row.timestamp,
            "symbol": row.symbol,
            "timeframe": row.timeframe,
        }
        merge_state = row.merge_state

        if merge_state == "left_only":
            mismatches.append(
                Mismatch(**key, field="*", kind=MISSING_IN_PYTHON,
                         mql5_value=None, python_value=None)
            )
            continue
        if merge_state == "right_only":
            mismatches.append(
                Mismatch(**key, field="*", kind=MISSING_IN_MQL5,
                         mql5_value=None, python_value=None)
            )
            continue

        for field in TEXT_COLUMNS:
            left = getattr(row, f"{field}_mql5")
            right = getattr(row, f"{field}_python")
            if left != right:
                mismatches.append(
                    Mismatch(**key, field=field, kind=VALUE_MISMATCH,
                             mql5_value=left, python_value=right)
                )

        for field in NUMERIC_COLUMNS:
            left = float(getattr(row, f"{field}_mql5"))
            right = float(getattr(row, f"{field}_python"))
            if math.isnan(left) and math.isnan(right):
                continue
            if math.isnan(left) or math.isnan(right):
                mismatches.append(
                    Mismatch(**key, field=field, kind=NAN_MISMATCH,
                             mql5_value=left, python_value=right)
                )
                continue
            difference = left - right
            if abs(difference) > tolerance:
                mismatches.append(
                    Mismatch(**key, field=field, kind=VALUE_MISMATCH,
                             mql5_value=left, python_value=right,
                             difference=difference)
                )

    mismatches.sort(
        key=lambda item: (
            item.timestamp,
            item.symbol,
            item.timeframe,
            item.field,
            item.kind,
        )
    )

    return ParityReport(
        mql5_path=str(mql5_path),
        python_path=str(python_path),
        tolerance=float(tolerance),
        rows_mql5=int(len(mql5)),
        rows_python=int(len(python)),
        rows_compared=int((merged["merge_state"] == "both").sum()),
        mismatches=tuple(mismatches),
    )


def write_report(report: ParityReport, out_dir: str | Path) -> tuple[Path, Path]:
    """Write ``mismatch_report.json`` and ``mismatch_report.csv``."""

    destination = Path(out_dir)
    destination.mkdir(parents=True, exist_ok=True)
    json_path = destination / "mismatch_report.json"
    csv_path = destination / "mismatch_report.csv"

    json_path.write_text(
        json.dumps(report.to_dict(), indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    report.to_frame().to_csv(csv_path, index=False)
    return json_path, csv_path
