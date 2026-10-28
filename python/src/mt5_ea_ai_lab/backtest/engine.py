"""Deterministic bar backtester.

Timing contract:
- A signal is computed at the close of bar ``i`` from data up to ``i``.
- The signal is executed at the open of bar ``i + 1`` (no same-bar look-ahead).
- Stop-loss and take-profit are checked intrabar with high/low. If both could
  trigger in the same bar, the stop-loss is assumed to fill first.
- A trailing stop is recalculated from a completed bar and becomes active from
  the next bar; it is never assumed to trigger inside the bar that moved it.
- An open position at the end of the data is closed at the last close with
  normal exit costs (``exit_reason="end_of_data"``).
"""

from __future__ import annotations

from dataclasses import asdict, dataclass

import numpy as np
import pandas as pd

from mt5_ea_ai_lab.backtest.models import (
    EQUITY_COLUMNS,
    TRADE_COLUMNS,
    BacktestInputError,
    BacktestResult,
    ExecutionConfig,
)
from mt5_ea_ai_lab.backtest.trailing import next_trailing_stop
from mt5_ea_ai_lab.evaluation.metrics import buy_and_hold_benchmark, compute_metrics
from mt5_ea_ai_lab.signals.ema_crossover import (
    SIGNAL_BUY,
    SIGNAL_SELL,
    EmaCrossConfig,
    generate_signals,
)

_REQUIRED_INPUT = ("timestamp", "open", "high", "low", "close")


@dataclass
class _Position:
    side: int
    entry_time: pd.Timestamp
    entry_bar: int
    entry_fill: float
    entry_commission: float
    stop_price: float | None
    target_price: float | None
    trailing_active: bool = False


def prepare_frame(
    frame: pd.DataFrame,
) -> tuple[pd.Series, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    missing = [column for column in _REQUIRED_INPUT if column not in frame.columns]
    if missing:
        raise BacktestInputError(f"missing required columns: {missing}")
    if frame.empty:
        raise BacktestInputError("cannot backtest an empty dataset")

    timestamps = pd.to_datetime(frame["timestamp"], errors="coerce", utc=True)
    if timestamps.isna().any():
        raise BacktestInputError("timestamp column contains invalid values")
    if timestamps.duplicated().any():
        raise BacktestInputError("timestamp column contains duplicates")
    if not timestamps.is_monotonic_increasing:
        raise BacktestInputError("timestamps must be sorted in increasing order")

    open_prices = frame["open"].to_numpy(dtype=float)
    high_prices = frame["high"].to_numpy(dtype=float)
    low_prices = frame["low"].to_numpy(dtype=float)
    close_prices = frame["close"].to_numpy(dtype=float)
    ohlc = (open_prices, high_prices, low_prices, close_prices)
    if not all(np.isfinite(values).all() for values in ohlc):
        raise BacktestInputError("OHLC contains non-finite values")
    if not all((values > 0.0).all() for values in ohlc):
        raise BacktestInputError("OHLC prices must be positive")

    highest = np.maximum(np.maximum(open_prices, close_prices), low_prices)
    lowest = np.minimum(np.minimum(open_prices, close_prices), high_prices)
    if (high_prices + 1e-12 < highest).any():
        raise BacktestInputError("high is below open, close or low")
    if (low_prices - 1e-12 > lowest).any():
        raise BacktestInputError("low is above open, close or high")

    return timestamps.reset_index(drop=True), ohlc[0], ohlc[1], ohlc[2], ohlc[3]


def _intrabar_exit(
    position: _Position,
    open_price: float,
    high_price: float,
    low_price: float,
) -> tuple[str, float] | None:
    if position.side > 0:
        stop_hit = (
            position.stop_price is not None and low_price <= position.stop_price
        )
        target_hit = (
            position.target_price is not None and high_price >= position.target_price
        )
        if stop_hit:
            return "stop_loss", min(open_price, position.stop_price)
        if target_hit:
            return "take_profit", max(open_price, position.target_price)
    else:
        stop_hit = (
            position.stop_price is not None and high_price >= position.stop_price
        )
        target_hit = (
            position.target_price is not None and low_price <= position.target_price
        )
        if stop_hit:
            return "stop_loss", max(open_price, position.stop_price)
        if target_hit:
            return "take_profit", min(open_price, position.target_price)
    return None


def run_backtest(
    frame: pd.DataFrame,
    strategy: EmaCrossConfig,
    execution: ExecutionConfig,
) -> BacktestResult:
    strategy.validate()
    execution.validate()
    timestamps, open_prices, high_prices, low_prices, close_prices = prepare_frame(
        frame
    )
    signals = generate_signals(close_prices, timestamps, strategy)

    half_spread = execution.spread_points * execution.point_size / 2.0
    slippage = execution.slippage_points * execution.point_size
    units = execution.position_units

    cash = execution.initial_equity
    position: _Position | None = None
    pending: str | None = None
    trades: list[dict[str, object]] = []
    equity_rows: list[dict[str, object]] = []
    exposed_bars = 0

    def open_position(side: int, raw_price: float, time: pd.Timestamp, bar: int) -> _Position:
        nonlocal cash
        fill = raw_price + side * (half_spread + slippage)
        commission = execution.commission_per_side
        cash -= commission
        stop_price = (
            fill - side * execution.stop_loss_points * execution.point_size
            if execution.stop_loss_points is not None
            else None
        )
        target_price = (
            fill + side * execution.take_profit_points * execution.point_size
            if execution.take_profit_points is not None
            else None
        )
        return _Position(
            side=side,
            entry_time=time,
            entry_bar=bar,
            entry_fill=fill,
            entry_commission=commission,
            stop_price=stop_price,
            target_price=target_price,
        )

    def update_trailing_stop(
        current: _Position, high_price: float, low_price: float
    ) -> None:
        if execution.trailing_stop_points is None:
            return
        updated = next_trailing_stop(
            side=current.side,
            entry_fill=current.entry_fill,
            current_stop=current.stop_price,
            bar_high=high_price,
            bar_low=low_price,
            distance=execution.trailing_stop_points * execution.point_size,
            activation=(
                execution.trailing_activation_points * execution.point_size
                if execution.trailing_activation_points is not None
                else None
            ),
        )
        if updated != current.stop_price:
            current.stop_price = updated
            current.trailing_active = True

    def close_position(
        current: _Position,
        raw_price: float,
        time: pd.Timestamp,
        bar: int,
        reason: str,
    ) -> None:
        nonlocal cash
        fill = raw_price - current.side * (half_spread + slippage)
        gross_pnl = (fill - current.entry_fill) * current.side * units
        exit_commission = execution.commission_per_side
        cash += gross_pnl - exit_commission
        total_commission = current.entry_commission + exit_commission
        trades.append(
            {
                "trade_id": len(trades) + 1,
                "side": "long" if current.side > 0 else "short",
                "entry_time": current.entry_time.isoformat(),
                "exit_time": time.isoformat(),
                "entry_bar": current.entry_bar,
                "exit_bar": bar,
                "entry_fill": current.entry_fill,
                "exit_fill": fill,
                "units": units,
                "gross_pnl": gross_pnl,
                "commission": total_commission,
                "pnl": gross_pnl - total_commission,
                "bars_held": bar - current.entry_bar,
                "exit_reason": reason,
            }
        )

    for index in range(len(close_prices)):
        if pending is not None:
            desired_side = 1 if pending == SIGNAL_BUY else -1
            if position is None:
                position = open_position(
                    desired_side, float(open_prices[index]), timestamps.iloc[index], index
                )
            elif position.side != desired_side:
                close_position(
                    position,
                    float(open_prices[index]),
                    timestamps.iloc[index],
                    index,
                    "opposite_signal",
                )
                position = open_position(
                    desired_side, float(open_prices[index]), timestamps.iloc[index], index
                )
        pending = None

        if position is not None:
            exit_plan = _intrabar_exit(
                position,
                float(open_prices[index]),
                float(high_prices[index]),
                float(low_prices[index]),
            )
            if exit_plan is not None:
                reason, raw_price = exit_plan
                if reason == "stop_loss" and position.trailing_active:
                    reason = "trailing_stop"
                close_position(
                    position,
                    raw_price,
                    timestamps.iloc[index],
                    index,
                    reason,
                )
                position = None
            else:
                update_trailing_stop(
                    position,
                    float(high_prices[index]),
                    float(low_prices[index]),
                )

        unrealized = (
            (float(close_prices[index]) - position.entry_fill) * position.side * units
            if position is not None
            else 0.0
        )
        if position is not None:
            exposed_bars += 1
        equity_rows.append(
            {
                "timestamp": timestamps.iloc[index],
                "cash": cash,
                "unrealized": unrealized,
                "equity": cash + unrealized,
                "position": position.side if position is not None else 0,
            }
        )

        signal = str(signals["signal"].iloc[index])
        if signal in (SIGNAL_BUY, SIGNAL_SELL):
            pending = signal

    if position is not None:
        close_position(
            position,
            float(close_prices[-1]),
            timestamps.iloc[-1],
            len(close_prices) - 1,
            "end_of_data",
        )
        equity_rows[-1].update(
            {"cash": cash, "unrealized": 0.0, "equity": cash, "position": 0}
        )

    trades_frame = (
        pd.DataFrame(trades, columns=list(TRADE_COLUMNS))
        if trades
        else pd.DataFrame(columns=list(TRADE_COLUMNS))
    )
    equity_frame = pd.DataFrame(equity_rows, columns=list(EQUITY_COLUMNS))
    metrics = compute_metrics(
        trades_frame, equity_frame, execution.initial_equity, exposed_bars
    )
    benchmark = buy_and_hold_benchmark(frame, execution)

    return BacktestResult(
        trades=trades_frame,
        equity=equity_frame,
        signals=signals,
        metrics=metrics,
        benchmark=benchmark,
        config={
            "strategy": asdict(strategy),
            "execution": execution.to_dict(),
        },
    )
