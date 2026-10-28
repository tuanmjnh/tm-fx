"""Causal feature pipeline for the ML baseline.

Every feature at bar ``t`` is computed from bars ``<= t`` only. The builder
does not sort, fill or otherwise repair the input: unsorted or duplicate
timestamps are rejected, and rows without a complete feature vector (warm-up)
are dropped.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

import numpy as np
import pandas as pd

FEATURE_SCHEMA_VERSION = 1

_SOURCE_COLUMNS = ("timestamp", "open", "high", "low", "close", "tick_volume")


class FeatureError(ValueError):
    """Raised when features cannot be built from the input frame."""


@dataclass(frozen=True)
class FeatureConfig:
    ema_fast: int = 5
    ema_slow: int = 20
    return_windows: tuple[int, ...] = (1, 3, 5, 10)
    volatility_window: int = 10
    volume_window: int = 10
    stochastic_window: int = 14

    def validate(self) -> None:
        if self.ema_fast <= 0 or self.ema_slow <= 0:
            raise FeatureError("EMA periods must be positive")
        if self.ema_fast >= self.ema_slow:
            raise FeatureError("ema_fast must be lower than ema_slow")
        if not self.return_windows or any(window <= 0 for window in self.return_windows):
            raise FeatureError("return_windows must contain positive integers")
        for name in ("volatility_window", "volume_window", "stochastic_window"):
            if getattr(self, name) <= 0:
                raise FeatureError(f"{name} must be positive")

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class FeatureSet:
    frame: pd.DataFrame
    feature_names: tuple[str, ...]
    warmup_bars: int
    schema: dict[str, Any]

    @property
    def rows(self) -> int:
        return int(len(self.frame))


def _validate_frame(frame: pd.DataFrame) -> pd.DataFrame:
    missing = [column for column in _SOURCE_COLUMNS if column not in frame.columns]
    if missing:
        raise FeatureError(f"missing required columns: {missing}")
    if frame.empty:
        raise FeatureError("cannot build features from an empty dataset")

    timestamps = pd.to_datetime(frame["timestamp"], errors="coerce", utc=True)
    if timestamps.isna().any():
        raise FeatureError("timestamp column contains invalid values")
    if timestamps.duplicated().any():
        raise FeatureError("timestamp column contains duplicates")
    if not timestamps.is_monotonic_increasing:
        raise FeatureError("timestamps must be sorted in increasing order")

    prices = frame[["open", "high", "low", "close"]].to_numpy(dtype=float)
    if not np.isfinite(prices).all():
        raise FeatureError("OHLC contains non-finite values")
    if not (prices > 0.0).all():
        raise FeatureError("OHLC prices must be positive")
    return frame


def _safe_ratio(numerator: pd.Series, denominator: pd.Series) -> pd.Series:
    return numerator / denominator.replace(0.0, np.nan)


def build_features(
    frame: pd.DataFrame,
    config: FeatureConfig | None = None,
) -> FeatureSet:
    """Build the feature matrix and its schema.

    The output keeps ``bar_index`` (position in the input frame) and
    ``timestamp`` so labels and walk-forward splits can be aligned without
    relying on a re-indexed frame.
    """

    active = config or FeatureConfig()
    active.validate()
    source = _validate_frame(frame)

    close = source["close"].astype(float)
    high = source["high"].astype(float)
    low = source["low"].astype(float)
    open_price = source["open"].astype(float)
    volume = source["tick_volume"].astype(float)

    features: dict[str, pd.Series] = {}
    returns_1 = close.pct_change(1)
    for window in active.return_windows:
        features[f"return_{window}"] = close.pct_change(window)

    ema_fast = close.ewm(span=active.ema_fast, adjust=False).mean()
    ema_slow = close.ewm(span=active.ema_slow, adjust=False).mean()
    # ewm(adjust=False) is recursive and therefore causal; the span-based
    # recursive form matches the EMA shape used elsewhere in the lab closely
    # enough for a research baseline, without claiming parity with MQL5.
    features["ema_gap"] = _safe_ratio(ema_fast - ema_slow, close)
    features["ema_slope"] = _safe_ratio(ema_fast - ema_fast.shift(1), close)

    volatility = returns_1.rolling(
        active.volatility_window, min_periods=active.volatility_window
    ).std(ddof=0)
    features["volatility"] = volatility
    features["return_z"] = _safe_ratio(returns_1, volatility)

    rolling_high = high.rolling(
        active.stochastic_window, min_periods=active.stochastic_window
    ).max()
    rolling_low = low.rolling(
        active.stochastic_window, min_periods=active.stochastic_window
    ).min()
    features["stochastic"] = _safe_ratio(close - rolling_low, rolling_high - rolling_low)

    features["range_ratio"] = _safe_ratio(high - low, close)
    features["body_ratio"] = _safe_ratio(close - open_price, close)

    volume_mean = volume.rolling(
        active.volume_window, min_periods=active.volume_window
    ).mean()
    volume_std = volume.rolling(
        active.volume_window, min_periods=active.volume_window
    ).std(ddof=0)
    features["volume_z"] = _safe_ratio(volume - volume_mean, volume_std)

    feature_names = tuple(features.keys())
    output = pd.DataFrame({"bar_index": np.arange(len(source)), "timestamp": source["timestamp"].to_numpy()})
    for name in feature_names:
        output[name] = features[name].to_numpy(dtype=float)

    output = output.replace([np.inf, -np.inf], np.nan)
    complete = output[list(feature_names)].notna().all(axis=1)
    if not complete.any():
        raise FeatureError("no bar has a complete feature vector")
    first_complete = int(output.index[complete][0])
    output = output[complete].reset_index(drop=True)
    output["bar_index"] = output["bar_index"].astype(int)

    schema = {
        "schema_version": FEATURE_SCHEMA_VERSION,
        "feature_names": list(feature_names),
        "feature_count": len(feature_names),
        "dtype": "float64",
        "warmup_bars": first_complete,
        "rows": int(len(output)),
        "source_columns": list(_SOURCE_COLUMNS),
        "config": active.to_dict(),
        "causality": "features at bar t use bars <= t only",
    }

    return FeatureSet(
        frame=output,
        feature_names=feature_names,
        warmup_bars=first_complete,
        schema=schema,
    )
