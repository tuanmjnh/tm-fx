"""Deterministic research backtester."""

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
    "signal_counts",
    "simulate_predictions",
]
