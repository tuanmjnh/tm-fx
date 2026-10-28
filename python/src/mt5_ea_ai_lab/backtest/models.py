"""Backtest configuration and result containers."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

import pandas as pd


class BacktestInputError(ValueError):
    """Raised when market data or configuration cannot be backtested."""


@dataclass(frozen=True)
class ExecutionConfig:
    """Explicit execution and cost assumptions.

    ``position_units`` is a research size in base-currency units; PnL is in
    quote currency. Spread and slippage are in points and converted with
    ``point_size``. Commission is charged on every fill (entry and exit).
    No leverage, margin call or financing model is applied.

    ``trailing_stop_points`` is the distance kept below the highest high (long)
    or above the lowest low (short). ``trailing_activation_points`` delays the
    first move until that favorable excursion is reached.
    """

    initial_equity: float = 10_000.0
    position_units: float = 100_000.0
    point_size: float = 0.00001
    spread_points: float = 0.0
    slippage_points: float = 0.0
    commission_per_side: float = 0.0
    stop_loss_points: float | None = None
    take_profit_points: float | None = None
    trailing_stop_points: float | None = None
    trailing_activation_points: float | None = None

    def validate(self) -> None:
        if self.initial_equity <= 0.0:
            raise BacktestInputError("initial_equity must be positive")
        if self.position_units <= 0.0:
            raise BacktestInputError("position_units must be positive")
        if self.point_size <= 0.0:
            raise BacktestInputError("point_size must be positive")
        for name in ("spread_points", "slippage_points", "commission_per_side"):
            if getattr(self, name) < 0.0:
                raise BacktestInputError(f"{name} must be non-negative")
        for name in (
            "stop_loss_points",
            "take_profit_points",
            "trailing_stop_points",
            "trailing_activation_points",
        ):
            value = getattr(self, name)
            if value is not None and value <= 0.0:
                raise BacktestInputError(f"{name} must be positive or null")
        if (
            self.trailing_activation_points is not None
            and self.trailing_stop_points is None
        ):
            raise BacktestInputError(
                "trailing_activation_points requires trailing_stop_points"
            )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class BacktestResult:
    trades: pd.DataFrame
    equity: pd.DataFrame
    signals: pd.DataFrame
    metrics: dict[str, Any]
    benchmark: dict[str, Any]
    config: dict[str, Any]

    def to_summary_dict(self) -> dict[str, Any]:
        return {
            "config": self.config,
            "metrics": self.metrics,
            "benchmark": self.benchmark,
            "signal_counts": signal_counts(self.signals),
        }


TRADE_COLUMNS: tuple[str, ...] = (
    "trade_id",
    "side",
    "entry_time",
    "exit_time",
    "entry_bar",
    "exit_bar",
    "entry_fill",
    "exit_fill",
    "units",
    "gross_pnl",
    "commission",
    "pnl",
    "bars_held",
    "exit_reason",
)

EQUITY_COLUMNS: tuple[str, ...] = (
    "timestamp",
    "cash",
    "unrealized",
    "equity",
    "position",
)


def signal_counts(signals: pd.DataFrame) -> dict[str, int]:
    if signals.empty:
        return {}
    counts = signals["signal"].value_counts().sort_index()
    return {str(name): int(value) for name, value in counts.items()}
