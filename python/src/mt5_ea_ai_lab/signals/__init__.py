"""Signal generation (no execution)."""

from mt5_ea_ai_lab.signals.ema_crossover import (
    REASON_INDICATOR_FAILED,
    REASON_INSUFFICIENT_HISTORY,
    REASON_INVALID_CONFIG,
    REASON_INVALID_INPUT,
    REASON_LONG_DISABLED,
    REASON_NO_CROSS,
    REASON_OK,
    REASON_SHORT_DISABLED,
    SIGNAL_BUY,
    SIGNAL_HOLD,
    SIGNAL_SELL,
    SIGNAL_UNKNOWN,
    EmaCrossConfig,
    compute_ema,
    evaluate_crossover,
    generate_signals,
)

__all__ = [
    "REASON_INDICATOR_FAILED",
    "REASON_INSUFFICIENT_HISTORY",
    "REASON_INVALID_CONFIG",
    "REASON_INVALID_INPUT",
    "REASON_LONG_DISABLED",
    "REASON_NO_CROSS",
    "REASON_OK",
    "REASON_SHORT_DISABLED",
    "SIGNAL_BUY",
    "SIGNAL_HOLD",
    "SIGNAL_SELL",
    "SIGNAL_UNKNOWN",
    "EmaCrossConfig",
    "compute_ema",
    "evaluate_crossover",
    "generate_signals",
]
