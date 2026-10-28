"""Deterministic research backtester."""

from mt5_ea_ai_lab.backtest.bounded_basket import (
    BASKET_COLUMNS,
    BASKET_MODES,
    BASKET_TRADE_COLUMNS,
    BoundedBasketConfig,
    BoundedBasketResult,
    run_bounded_basket,
)
from mt5_ea_ai_lab.backtest.engine import run_backtest
from mt5_ea_ai_lab.backtest.ml_strategy import (
    PredictionInputError,
    PredictionStrategyConfig,
    PredictionStrategyResult,
    momentum_predictions,
    simulate_predictions,
)
from mt5_ea_ai_lab.backtest.models import (
    EQUITY_COLUMNS,
    TRADE_COLUMNS,
    BacktestInputError,
    BacktestResult,
    ExecutionConfig,
    signal_counts,
)

__all__ = [
    "BASKET_COLUMNS",
    "BASKET_MODES",
    "BASKET_TRADE_COLUMNS",
    "BoundedBasketConfig",
    "BoundedBasketResult",
    "EQUITY_COLUMNS",
    "TRADE_COLUMNS",
    "BacktestInputError",
    "BacktestResult",
    "ExecutionConfig",
    "PredictionInputError",
    "PredictionStrategyConfig",
    "PredictionStrategyResult",
    "momentum_predictions",
    "run_backtest",
    "run_bounded_basket",
    "signal_counts",
    "simulate_predictions",
]
