"""EMA crossover signals aligned with the MQL5 baseline.

Signals at bar ``i`` use only closes up to and including ``i``. The EMA is
recomputed on a rolling window of ``slow_period + 1`` closes, matching the
window the MQL5 EA passes to its signal engine.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Sequence

import numpy as np
import pandas as pd

SIGNAL_UNKNOWN = "UNKNOWN"
SIGNAL_HOLD = "HOLD"
SIGNAL_BUY = "BUY"
SIGNAL_SELL = "SELL"

REASON_OK = "OK"
REASON_INSUFFICIENT_HISTORY = "INSUFFICIENT_HISTORY"
REASON_INVALID_CONFIG = "INVALID_CONFIG"
REASON_INVALID_INPUT = "INVALID_INPUT"
REASON_INDICATOR_FAILED = "INDICATOR_FAILED"
REASON_NO_CROSS = "NO_CROSS"
REASON_LONG_DISABLED = "LONG_DISABLED"
REASON_SHORT_DISABLED = "SHORT_DISABLED"


@dataclass(frozen=True)
class EmaCrossConfig:
    fast_period: int
    slow_period: int
    allow_long: bool = True
    allow_short: bool = True

    def validate(self) -> None:
        if self.fast_period <= 0:
            raise ValueError("fast_period must be positive")
        if self.slow_period <= 0:
            raise ValueError("slow_period must be positive")
        if self.fast_period >= self.slow_period:
            raise ValueError("fast_period must be lower than slow_period")


def _usable_values(values: np.ndarray) -> bool:
    return bool(np.isfinite(values).all() and (values > 0.0).all())


def compute_ema(values: Sequence[float], period: int) -> np.ndarray:
    """EMA seeded with the SMA of the first ``period`` values.

    Returns an array of NaNs when the input is too short or contains a
    non-finite/non-positive value.
    """

    array = np.asarray(values, dtype=float)
    output = np.full(array.shape, np.nan, dtype=float)
    if period <= 0 or array.size < period or not _usable_values(array):
        return output

    output[period - 1] = float(array[:period].mean())
    alpha = 2.0 / (period + 1.0)
    for index in range(period, array.size):
        output[index] = alpha * array[index] + (1.0 - alpha) * output[index - 1]
    return output


def evaluate_crossover(
    fast_prev: float,
    slow_prev: float,
    fast_now: float,
    slow_now: float,
    *,
    allow_long: bool,
    allow_short: bool,
) -> tuple[str, str]:
    """Pure crossover rule mirroring ``LabEvaluateCrossover``."""

    values = (fast_prev, slow_prev, fast_now, slow_now)
    if not all(np.isfinite(value) and value > 0.0 for value in values):
        return SIGNAL_UNKNOWN, REASON_INVALID_INPUT

    if fast_prev <= slow_prev and fast_now > slow_now:
        if not allow_long:
            return SIGNAL_HOLD, REASON_LONG_DISABLED
        return SIGNAL_BUY, REASON_OK

    if fast_prev >= slow_prev and fast_now < slow_now:
        if not allow_short:
            return SIGNAL_HOLD, REASON_SHORT_DISABLED
        return SIGNAL_SELL, REASON_OK

    return SIGNAL_HOLD, REASON_NO_CROSS


def generate_signals(
    close: Sequence[float],
    timestamps: Sequence[Any],
    config: EmaCrossConfig,
) -> pd.DataFrame:
    """Generate one signal row per bar without using future data."""

    config.validate()
    closes = np.asarray(close, dtype=float)
    times = list(timestamps)
    if len(closes) != len(times):
        raise ValueError("close and timestamps must have the same length")

    rows: list[dict[str, Any]] = []
    for index in range(closes.size):
        signal = SIGNAL_UNKNOWN
        reason = REASON_OK
        fast_prev = slow_prev = fast_now = slow_now = float("nan")

        if index < config.slow_period:
            reason = REASON_INSUFFICIENT_HISTORY
        else:
            window = closes[index - config.slow_period : index + 1]
            if not _usable_values(window):
                reason = REASON_INDICATOR_FAILED
            else:
                fast = compute_ema(window, config.fast_period)
                slow = compute_ema(window, config.slow_period)
                fast_prev, slow_prev = float(fast[-2]), float(slow[-2])
                fast_now, slow_now = float(fast[-1]), float(slow[-1])
                signal, reason = evaluate_crossover(
                    fast_prev,
                    slow_prev,
                    fast_now,
                    slow_now,
                    allow_long=config.allow_long,
                    allow_short=config.allow_short,
                )

        rows.append(
            {
                "timestamp": times[index],
                "signal": signal,
                "reason": reason,
                "fast_prev": fast_prev,
                "slow_prev": slow_prev,
                "fast": fast_now,
                "slow": slow_now,
            }
        )

    return pd.DataFrame(
        rows,
        columns=[
            "timestamp",
            "signal",
            "reason",
            "fast_prev",
            "slow_prev",
            "fast",
            "slow",
        ],
    )
