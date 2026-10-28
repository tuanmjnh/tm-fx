"""Backtest metrics with explicit definitions.

Sharpe/Sortino are intentionally not computed: the return frequency and
annualization are not defined for this research harness.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

import numpy as np
import pandas as pd

if TYPE_CHECKING:
    from mt5_ea_ai_lab.backtest.models import ExecutionConfig


def _iso(value: Any) -> str | None:
    if value is None or pd.isna(value):
        return None
    return pd.Timestamp(value).isoformat()


def compute_metrics(
    trades: pd.DataFrame,
    equity: pd.DataFrame,
    initial_equity: float,
    exposed_bars: int | None = None,
) -> dict[str, Any]:
    bars = int(len(equity))
    final_equity = (
        float(equity["equity"].iloc[-1]) if bars else float(initial_equity)
    )

    equity_series = equity["equity"].astype(float)
    if bars:
        peaks = equity_series.cummax()
        drawdown = equity_series - peaks
        max_drawdown = max(0.0, float(-drawdown.min()))
        drawdown_pct = (equity_series / peaks.replace(0.0, np.nan) - 1.0).min()
        max_drawdown_pct = (
            max(0.0, float(-drawdown_pct)) if not pd.isna(drawdown_pct) else None
        )
        start = _iso(equity["timestamp"].iloc[0])
        end = _iso(equity["timestamp"].iloc[-1])
        if exposed_bars is None:
            exposed_bars = int((equity["position"] != 0).sum())
        exposure_ratio = float(exposed_bars / bars)
    else:
        max_drawdown = 0.0
        max_drawdown_pct = None
        start = end = None
        exposure_ratio = 0.0

    trade_count = int(len(trades))
    metrics: dict[str, Any] = {
        "bars": bars,
        "start": start,
        "end": end,
        "initial_equity": float(initial_equity),
        "final_equity": final_equity,
        "net_profit": final_equity - float(initial_equity),
        "total_return": final_equity / float(initial_equity) - 1.0,
        "gross_profit": 0.0,
        "gross_loss": 0.0,
        "profit_factor": None,
        "trade_count": trade_count,
        "win_count": 0,
        "loss_count": 0,
        "win_rate": None,
        "average_trade": None,
        "average_win": None,
        "average_loss": None,
        "expectancy": None,
        "total_commission": 0.0,
        "max_drawdown": max_drawdown,
        "max_drawdown_pct": max_drawdown_pct,
        "exposure_ratio": exposure_ratio,
        "exit_reason_counts": {},
        "sharpe_ratio": None,
        "undefined_metrics": {
            "sharpe_ratio": "annualization and return frequency are not defined"
        },
    }

    if trade_count:
        pnl = trades["pnl"].astype(float)
        wins = pnl[pnl > 0.0]
        losses = pnl[pnl < 0.0]
        gross_profit = max(0.0, float(wins.sum()))
        gross_loss = max(0.0, float(-losses.sum()))
        total_commission = max(0.0, float(trades["commission"].astype(float).sum()))

        metrics.update(
            {
                "gross_profit": gross_profit,
                "gross_loss": gross_loss,
                "profit_factor": (
                    gross_profit / gross_loss if gross_loss > 0.0 else None
                ),
                "win_count": int(len(wins)),
                "loss_count": int(len(losses)),
                "win_rate": float(len(wins) / trade_count),
                "average_trade": float(pnl.mean()),
                "average_win": float(wins.mean()) if len(wins) else None,
                "average_loss": float(losses.mean()) if len(losses) else None,
                "expectancy": float(pnl.mean()),
                "total_commission": total_commission,
                "exit_reason_counts": {
                    str(reason): int(count)
                    for reason, count in trades["exit_reason"]
                    .value_counts()
                    .sort_index()
                    .items()
                },
            }
        )

    return metrics


def buy_and_hold_benchmark(
    frame: pd.DataFrame,
    execution: ExecutionConfig,
) -> dict[str, Any] | None:
    """Long at the first open, exit at the last close, same cost model."""

    if frame.empty:
        return None

    half_spread = execution.spread_points * execution.point_size / 2.0
    slippage = execution.slippage_points * execution.point_size
    entry_fill = float(frame["open"].iloc[0]) + half_spread + slippage
    exit_fill = float(frame["close"].iloc[-1]) - half_spread - slippage
    gross_pnl = (exit_fill - entry_fill) * execution.position_units
    commission = 2.0 * execution.commission_per_side
    net_pnl = gross_pnl - commission

    return {
        "side": "long",
        "entry_fill": entry_fill,
        "exit_fill": exit_fill,
        "units": execution.position_units,
        "gross_pnl": gross_pnl,
        "commission": commission,
        "net_pnl": net_pnl,
        "return": net_pnl / execution.initial_equity,
        "bars": int(len(frame)),
        "start": _iso(frame["timestamp"].iloc[0]),
        "end": _iso(frame["timestamp"].iloc[-1]),
    }
