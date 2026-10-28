"""OHLCV validation.

Validation reports problems and never repairs, sorts or de-duplicates the
input. A dataset with warnings can still pass; any error makes it fail.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from mt5_ea_ai_lab.data.loader import (
    OPTIONAL_COLUMNS,
    PRICE_COLUMNS,
    REQUIRED_COLUMNS,
    DatasetMetadata,
)

SCHEMA_VERSION = 1


@dataclass(frozen=True)
class ValidationIssue:
    code: str
    severity: str
    message: str
    count: int = 0
    details: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "severity": self.severity,
            "message": self.message,
            "count": self.count,
            "details": self.details,
        }


@dataclass
class ValidationReport:
    row_count: int
    issues: list[ValidationIssue]
    stats: dict[str, Any]
    metadata: dict[str, Any]

    @property
    def errors(self) -> list[ValidationIssue]:
        return [issue for issue in self.issues if issue.severity == "error"]

    @property
    def warnings(self) -> list[ValidationIssue]:
        return [issue for issue in self.issues if issue.severity == "warning"]

    @property
    def passed(self) -> bool:
        return not self.errors

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": SCHEMA_VERSION,
            "passed": self.passed,
            "row_count": self.row_count,
            "metadata": self.metadata,
            "stats": self.stats,
            "issues": [issue.to_dict() for issue in self.issues],
        }

    def to_json(self, path: str | Path) -> Path:
        destination = Path(path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(self.to_dict(), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        return destination

    def to_csv(self, path: str | Path) -> Path:
        destination = Path(path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        rows = [
            {
                "code": issue.code,
                "severity": issue.severity,
                "message": issue.message,
                "count": issue.count,
                "details": json.dumps(issue.details, sort_keys=True),
            }
            for issue in self.issues
        ]
        frame = pd.DataFrame(
            rows,
            columns=["code", "severity", "message", "count", "details"],
        )
        frame.to_csv(destination, index=False)
        return destination


def _numeric_values(df: pd.DataFrame, column: str) -> np.ndarray:
    series = pd.to_numeric(df[column], errors="coerce")
    return series.to_numpy(dtype=float, na_value=np.nan)


def _step_seconds(expected_step: float | pd.Timedelta | None) -> float | None:
    if expected_step is None:
        return None
    if isinstance(expected_step, pd.Timedelta):
        return float(expected_step.total_seconds())
    return float(expected_step)


def validate_ohlcv(
    df: pd.DataFrame,
    *,
    metadata: DatasetMetadata | dict[str, Any] | None = None,
    symbol: str | None = None,
    timeframe: str | None = None,
    expected_step: float | pd.Timedelta | None = None,
    max_gap_factor: float = 3.0,
    ohlc_tolerance: float = 1e-12,
) -> ValidationReport:
    """Validate an OHLCV frame and return a deterministic report."""

    if isinstance(metadata, DatasetMetadata):
        meta = metadata.to_dict()
    elif metadata is not None:
        meta = dict(metadata)
    else:
        meta = {"data_kind": "unknown"}

    issues: list[ValidationIssue] = []
    stats: dict[str, Any] = {"row_count": int(len(df))}

    if meta.get("data_kind") == "synthetic":
        issues.append(
            ValidationIssue(
                code="synthetic_dataset",
                severity="warning",
                message="Synthetic fixture; this is not market history.",
                count=int(len(df)),
            )
        )

    if df.empty:
        issues.append(
            ValidationIssue(
                code="empty_dataset",
                severity="error",
                message="Dataset has no rows.",
            )
        )
        return ValidationReport(len(df), issues, stats, meta)

    missing = [column for column in REQUIRED_COLUMNS if column not in df.columns]
    if missing:
        issues.append(
            ValidationIssue(
                code="missing_columns",
                severity="error",
                message="Required columns are missing.",
                count=len(missing),
                details={"missing_columns": missing},
            )
        )
        return ValidationReport(len(df), issues, stats, meta)

    timestamps = pd.to_datetime(df["timestamp"], errors="coerce", utc=True)
    invalid_timestamps = int(timestamps.isna().sum())
    duplicate_timestamps = int(timestamps.duplicated(keep="first").sum())
    differences = timestamps.diff().dt.total_seconds()
    out_of_order = int((differences < 0).sum())

    stats.update(
        {
            "invalid_timestamps": invalid_timestamps,
            "duplicate_timestamps": duplicate_timestamps,
            "out_of_order_timestamps": out_of_order,
        }
    )
    valid_timestamps = timestamps.dropna()
    if not valid_timestamps.empty:
        stats["first_timestamp"] = valid_timestamps.min().isoformat()
        stats["last_timestamp"] = valid_timestamps.max().isoformat()

    if invalid_timestamps:
        issues.append(
            ValidationIssue(
                code="invalid_timestamps",
                severity="error",
                message="Timestamp values could not be parsed.",
                count=invalid_timestamps,
            )
        )
    if duplicate_timestamps:
        issues.append(
            ValidationIssue(
                code="duplicate_timestamps",
                severity="error",
                message="Duplicate timestamps found.",
                count=duplicate_timestamps,
            )
        )
    if out_of_order:
        issues.append(
            ValidationIssue(
                code="out_of_order_timestamps",
                severity="error",
                message="Timestamps are not strictly increasing.",
                count=out_of_order,
            )
        )

    non_finite: dict[str, int] = {}
    for column in (*REQUIRED_COLUMNS, *OPTIONAL_COLUMNS):
        if column == "timestamp" or column not in df.columns:
            continue
        values = _numeric_values(df, column)
        count = int(np.count_nonzero(~np.isfinite(values)))
        if count:
            non_finite[column] = count
    stats["non_finite_values"] = non_finite
    if non_finite:
        issues.append(
            ValidationIssue(
                code="non_finite_values",
                severity="error",
                message="NaN or infinite numeric values found.",
                count=sum(non_finite.values()),
                details={"columns": non_finite},
            )
        )

    open_prices, high_prices, low_prices, close_prices = (
        _numeric_values(df, column) for column in PRICE_COLUMNS
    )
    finite_ohlc = (
        np.isfinite(open_prices)
        & np.isfinite(high_prices)
        & np.isfinite(low_prices)
        & np.isfinite(close_prices)
    )
    non_positive = finite_ohlc & (
        (open_prices <= 0.0)
        | (high_prices <= 0.0)
        | (low_prices <= 0.0)
        | (close_prices <= 0.0)
    )
    high_inconsistent = finite_ohlc & (
        high_prices + ohlc_tolerance
        < np.maximum(np.maximum(open_prices, close_prices), low_prices)
    )
    low_inconsistent = finite_ohlc & (
        low_prices - ohlc_tolerance
        > np.minimum(np.minimum(open_prices, close_prices), high_prices)
    )

    stats["non_positive_price_rows"] = int(np.count_nonzero(non_positive))
    stats["high_inconsistent_rows"] = int(np.count_nonzero(high_inconsistent))
    stats["low_inconsistent_rows"] = int(np.count_nonzero(low_inconsistent))

    if stats["non_positive_price_rows"]:
        issues.append(
            ValidationIssue(
                code="non_positive_prices",
                severity="error",
                message="OHLC prices must be strictly positive.",
                count=stats["non_positive_price_rows"],
            )
        )
    if stats["high_inconsistent_rows"]:
        issues.append(
            ValidationIssue(
                code="ohlc_high_inconsistent",
                severity="error",
                message="High is below open, close or low.",
                count=stats["high_inconsistent_rows"],
            )
        )
    if stats["low_inconsistent_rows"]:
        issues.append(
            ValidationIssue(
                code="ohlc_low_inconsistent",
                severity="error",
                message="Low is above open, close or high.",
                count=stats["low_inconsistent_rows"],
            )
        )

    for column, code in (
        ("tick_volume", "negative_tick_volume"),
        ("real_volume", "negative_real_volume"),
        ("spread", "negative_spread"),
    ):
        if column not in df.columns:
            continue
        values = _numeric_values(df, column)
        count = int(np.count_nonzero(np.isfinite(values) & (values < 0.0)))
        stats[f"{code}_rows"] = count
        if count:
            issues.append(
                ValidationIssue(
                    code=code,
                    severity="error",
                    message=f"{column} contains negative values.",
                    count=count,
                )
            )

    expected_symbol = symbol or meta.get("symbol")
    expected_timeframe = timeframe or meta.get("timeframe")
    for column, expected_value, label in (
        ("symbol", expected_symbol, "symbol"),
        ("timeframe", expected_timeframe, "timeframe"),
    ):
        if column not in df.columns:
            continue
        values = df[column].dropna().astype(str).str.strip()
        values = values[values != ""].str.upper()
        if expected_value:
            mismatches = int((values != str(expected_value).strip().upper()).sum())
            stats[f"{label}_mismatch_rows"] = mismatches
            if mismatches:
                issues.append(
                    ValidationIssue(
                        code=f"{label}_mismatch",
                        severity="error",
                        message=f"Rows do not match expected {label} {expected_value!r}.",
                        count=mismatches,
                    )
                )
        else:
            unique_values = sorted(values.unique().tolist())
            stats[f"{label}_unique_values"] = unique_values
            if len(unique_values) > 1:
                issues.append(
                    ValidationIssue(
                        code=f"mixed_{label}s",
                        severity="warning",
                        message=f"Multiple {label} values present in one dataset.",
                        count=len(unique_values),
                        details={f"{label}s": unique_values},
                    )
                )

    unique_sorted = pd.Series(valid_timestamps.unique()).sort_values()
    if len(unique_sorted) >= 3:
        positive_diffs = unique_sorted.diff().dt.total_seconds().dropna()
        positive_diffs = positive_diffs[positive_diffs > 0.0]
        step_seconds = _step_seconds(expected_step)
        if step_seconds is None and not positive_diffs.empty:
            modes = positive_diffs.mode()
            if not modes.empty:
                step_seconds = float(modes.iloc[0])
        if step_seconds is not None and step_seconds > 0.0:
            threshold = max_gap_factor * step_seconds
            gaps = positive_diffs[positive_diffs > threshold]
            stats["expected_step_seconds"] = step_seconds
            stats["gap_count"] = int(len(gaps))
            stats["largest_gap_seconds"] = float(positive_diffs.max())
            if len(gaps):
                issues.append(
                    ValidationIssue(
                        code="timestamp_gaps",
                        severity="warning",
                        message=(
                            "Timestamp gaps exceed the expected step; "
                            "weekends and sessions can cause this."
                        ),
                        count=int(len(gaps)),
                        details={
                            "expected_step_seconds": step_seconds,
                            "max_gap_factor": max_gap_factor,
                            "largest_gap_seconds": float(gaps.max()),
                        },
                    )
                )

    stats["data_kind"] = meta.get("data_kind", "unknown")
    return ValidationReport(int(len(df)), issues, stats, meta)
