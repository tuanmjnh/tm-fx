"""Simulate trades from causal model predictions.

The simulation is deliberately separate from label construction:
predictions are turned into long/short entries at the next bar's open and
exited after a fixed number of bars. Overlapping predictions are ignored so
the strategy holds at most one position, matching the single-position
backtester.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np
import pandas as pd

from mt5_ea_ai_lab.backtest.models import (
    EQUITY_COLUMNS,
    TRADE_COLUMNS,
    BacktestInputError,
    ExecutionConfig,
)
from mt5_ea_ai_lab.evaluation.metrics import compute_metrics


class PredictionInputError(ValueError):
    """Raised when predictions or prices cannot be simulated."""


@dataclass(frozen=True)
class PredictionStrategyConfig:
    horizon: int
    allow_long: bool = True
    allow_short: bool = True

    def validate(self) -> None:
        if isinstance(self.horizon, bool) or self.horizon <= 0:
            raise PredictionInputError("horizon must be a positive integer")
        if not self.allow_long and not self.allow_short:
            raise PredictionInputError("at least one side must be enabled")


@dataclass
class PredictionStrategyResult:
    trades: pd.DataFrame
    equity: pd.DataFrame
    metrics: dict[str, Any]
    decisions: int
    skipped_incomplete: int
    skipped_overlap: int
    skipped_disabled: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "metrics": self.metrics,
            "decisions": self.decisions,
            "skipped_incomplete": self.skipped_incomplete,
            "skipped_overlap": self.skipped_overlap,
            "skipped_disabled": self.skipped_disabled,
        }


def _prepare_prices(frame: pd.DataFrame) -> tuple[pd.Series, np.ndarray, np.ndarray]:
    required = ("timestamp", "open", "close")
    missing = [column for column in required if column not in frame.columns]
    if missing:
        raise PredictionInputError(f"missing required columns: {missing}")
    if frame.empty:
        raise PredictionInputError("cannot simulate an empty dataset")

    timestamps = pd.to_datetime(frame["timestamp"], errors="coerce", utc=True)
    if timestamps.isna().any() or timestamps.duplicated().any():
        raise PredictionInputError("timestamps must be valid and unique")
    if not timestamps.is_monotonic_increasing:
        raise PredictionInputError("timestamps must be sorted")

    open_prices = frame["open"].to_numpy(dtype=float)
    close_prices = frame["close"].to_numpy(dtype=float)
    if not np.isfinite(open_prices).all() or not (open_prices > 0.0).all():
        raise PredictionInputError("open prices must be finite and positive")
    if not np.isfinite(close_prices).all() or not (close_prices > 0.0).all():
        raise PredictionInputError("close prices must be finite and positive")
    return timestamps.reset_index(drop=True), open_prices, close_prices


def _prepare_predictions(predictions: pd.DataFrame) -> pd.DataFrame:
    required = ("bar_index", "probability", "threshold")
    missing = [column for column in required if column not in predictions.columns]
    if missing:
        raise PredictionInputError(f"missing prediction columns: {missing}")
    if predictions.empty:
        raise PredictionInputError("predictions are empty")

    frame = predictions[list(required)].copy()
    frame["bar_index"] = frame["bar_index"].astype(int)
    frame["probability"] = frame["probability"].astype(float)
    frame["threshold"] = frame["threshold"].astype(float)
    if not np.isfinite(frame["probability"]).all():
        raise PredictionInputError("probabilities contain non-finite values")
    if not ((frame["probability"] >= 0.0) & (frame["probability"] <= 1.0)).all():
        raise PredictionInputError("probabilities must be between 0 and 1")
    if not ((frame["threshold"] >= 0.0) & (frame["threshold"] <= 1.0)).all():
        raise PredictionInputError("thresholds must be between 0 and 1")
    if frame["bar_index"].duplicated().any():
        raise PredictionInputError("predictions contain duplicate bar_index values")
    if (frame["bar_index"] < 0).any():
        raise PredictionInputError("predictions contain negative bar_index values")
    return frame.sort_values("bar_index").reset_index(drop=True)


def simulate_predictions(
    frame: pd.DataFrame,
    predictions: pd.DataFrame,
    execution: ExecutionConfig,
    config: PredictionStrategyConfig,
    *,
    evaluation_start_bar: int | None = None,
    evaluation_end_bar: int | None = None,
) -> PredictionStrategyResult:
    timestamps, open_prices, close_prices = _prepare_prices(frame)
    config.validate()
    execution.validate()
    prepared = _prepare_predictions(predictions)

    total_bars = len(frame)
    if (prepared["bar_index"] >= total_bars).any():
        raise PredictionInputError("predictions reference a bar beyond the dataset")
    start_bar = (
        int(evaluation_start_bar)
        if evaluation_start_bar is not None
        else int(prepared["bar_index"].min())
    )
    end_bar = int(evaluation_end_bar) if evaluation_end_bar is not None else total_bars
    if start_bar < 0 or end_bar > total_bars or start_bar >= end_bar:
        raise PredictionInputError("invalid evaluation bar range")

    decisions = {
        int(row.bar_index): (float(row.probability), float(row.threshold))
        for row in prepared.itertuples(index=False)
        if start_bar <= int(row.bar_index) < total_bars
    }

    half_spread = execution.spread_points * execution.point_size / 2.0
    slippage = execution.slippage_points * execution.point_size
    units = execution.position_units
    cash = execution.initial_equity
    side = 0
    entry_bar = -1
    entry_fill = 0.0
    exit_bar = -1
    trades: list[dict[str, object]] = []
    equity_rows: list[dict[str, object]] = []
    exposed_bars = 0
    decision_count = 0
    skipped_incomplete = 0
    skipped_overlap = 0
    skipped_disabled = 0
    pending_side: int | None = None

    for bar in range(start_bar, end_bar):
        if pending_side is not None and side == 0:
            side = pending_side
            entry_bar = bar
            entry_fill = float(open_prices[bar]) + side * (half_spread + slippage)
            exit_bar = entry_bar + config.horizon
            cash -= execution.commission_per_side
        pending_side = None

        if side != 0 and bar == exit_bar:
            fill = float(open_prices[bar]) - side * (half_spread + slippage)
            gross = (fill - entry_fill) * side * units
            cash += gross - execution.commission_per_side
            trades.append(
                {
                    "trade_id": len(trades) + 1,
                    "side": "long" if side > 0 else "short",
                    "entry_time": timestamps.iloc[entry_bar].isoformat(),
                    "exit_time": timestamps.iloc[bar].isoformat(),
                    "entry_bar": entry_bar,
                    "exit_bar": bar,
                    "entry_fill": entry_fill,
                    "exit_fill": fill,
                    "units": units,
                    "gross_pnl": gross,
                    "commission": 2.0 * execution.commission_per_side,
                    "pnl": gross - 2.0 * execution.commission_per_side,
                    "bars_held": bar - entry_bar,
                    "exit_reason": "horizon",
                }
            )
            side = 0

        unrealized = (
            (float(close_prices[bar]) - entry_fill) * side * units if side != 0 else 0.0
        )
        if side != 0:
            exposed_bars += 1
        equity_rows.append(
            {
                "timestamp": timestamps.iloc[bar],
                "cash": cash,
                "unrealized": unrealized,
                "equity": cash + unrealized,
                "position": side,
            }
        )

        if bar not in decisions:
            continue
        probability, threshold = decisions[bar]
        decision_count += 1
        if probability >= threshold:
            desired = 1
        elif probability <= 1.0 - threshold:
            desired = -1
        else:
            desired = 0
        if desired == 0:
            continue
        if (desired > 0 and not config.allow_long) or (
            desired < 0 and not config.allow_short
        ):
            skipped_disabled += 1
            continue
        if side != 0 or bar + 1 + config.horizon >= end_bar:
            if side != 0:
                skipped_overlap += 1
            else:
                skipped_incomplete += 1
            continue
        pending_side = desired

    if side != 0:
        # Every accepted entry has a complete horizon inside the window, so this
        # can only happen if an input changed after validation.
        raise PredictionInputError("internal error: position left open at window end")

    trades_frame = (
        pd.DataFrame(trades, columns=list(TRADE_COLUMNS))
        if trades
        else pd.DataFrame(columns=list(TRADE_COLUMNS))
    )
    equity_frame = pd.DataFrame(equity_rows, columns=list(EQUITY_COLUMNS))
    metrics = compute_metrics(
        trades_frame, equity_frame, execution.initial_equity, exposed_bars
    )
    return PredictionStrategyResult(
        trades=trades_frame,
        equity=equity_frame,
        metrics=metrics,
        decisions=decision_count,
        skipped_incomplete=skipped_incomplete,
        skipped_overlap=skipped_overlap,
        skipped_disabled=skipped_disabled,
    )


def momentum_predictions(
    frame: pd.DataFrame,
    *,
    lookback: int = 3,
    start_bar: int = 0,
) -> pd.DataFrame:
    """No-ML rule: long when the trailing return is positive, short otherwise."""

    if lookback <= 0:
        raise PredictionInputError("lookback must be positive")
    close = frame["close"].astype(float)
    trailing = close.pct_change(lookback)
    rows = []
    for bar in range(max(start_bar, lookback), len(frame)):
        value = trailing.iloc[bar]
        if not np.isfinite(value):
            continue
        rows.append(
            {
                "bar_index": bar,
                "probability": 1.0 if value > 0.0 else 0.0,
                "threshold": 0.5,
            }
        )
    if not rows:
        raise PredictionInputError("momentum rule produced no predictions")
    return pd.DataFrame(rows, columns=["bar_index", "probability", "threshold"])
