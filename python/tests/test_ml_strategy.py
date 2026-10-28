from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.backtest import (
    ExecutionConfig,
    PredictionInputError,
    PredictionStrategyConfig,
    momentum_predictions,
    simulate_predictions,
)


def price_frame(rows: int = 30) -> pd.DataFrame:
    open_price = 100.0 + np.arange(rows, dtype=float)
    return pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=rows, freq="5min", tz="UTC"),
            "open": open_price,
            "close": open_price + 0.5,
        }
    )


def predictions(rows: list[tuple[int, float]]) -> pd.DataFrame:
    return pd.DataFrame(
        [
            {"bar_index": bar, "probability": probability, "threshold": 0.5}
            for bar, probability in rows
        ]
    )


def test_simulation_opens_next_bar_and_skips_overlap() -> None:
    frame = price_frame()
    predictions_frame = predictions([(2, 1.0), (10, 0.0), (12, 1.0), (28, 1.0)])
    execution = ExecutionConfig(
        initial_equity=10_000.0,
        position_units=1.0,
        point_size=0.01,
        spread_points=0.0,
        slippage_points=0.0,
        commission_per_side=0.0,
    )
    result = simulate_predictions(
        frame,
        predictions_frame,
        execution,
        PredictionStrategyConfig(horizon=3),
        evaluation_start_bar=0,
        evaluation_end_bar=30,
    )
    assert result.decisions == 4
    assert result.skipped_overlap == 1
    assert result.skipped_incomplete == 1
    assert len(result.trades) == 2
    first, second = result.trades.iloc[0], result.trades.iloc[1]
    assert first["side"] == "long"
    assert (first["entry_bar"], first["exit_bar"]) == (3, 6)
    assert first["pnl"] == pytest.approx(3.0)
    assert second["side"] == "short"
    assert (second["entry_bar"], second["exit_bar"]) == (11, 14)
    assert second["pnl"] == pytest.approx(-3.0)
    assert result.metrics["final_equity"] == pytest.approx(10_000.0)
    assert result.metrics["trade_count"] == 2


def test_simulation_applies_spread_slippage_and_commission() -> None:
    frame = price_frame()
    execution = ExecutionConfig(
        initial_equity=10_000.0,
        position_units=1.0,
        point_size=0.01,
        spread_points=10.0,   # half-spread 0.05
        slippage_points=5.0,  # slippage 0.05
        commission_per_side=1.0,
    )
    result = simulate_predictions(
        frame,
        predictions([(2, 1.0)]),
        execution,
        PredictionStrategyConfig(horizon=3),
        evaluation_start_bar=0,
        evaluation_end_bar=30,
    )
    trade = result.trades.iloc[0]
    expected_entry = frame["open"].iloc[3] + 0.10
    expected_exit = frame["open"].iloc[6] - 0.10
    assert trade["entry_fill"] == pytest.approx(expected_entry)
    assert trade["exit_fill"] == pytest.approx(expected_exit)
    assert trade["gross_pnl"] == pytest.approx(expected_exit - expected_entry)
    assert trade["pnl"] == pytest.approx(expected_exit - expected_entry - 2.0)
    assert result.metrics["net_profit"] == pytest.approx(expected_exit - expected_entry - 2.0)


def test_simulation_rejects_invalid_predictions() -> None:
    frame = price_frame()
    execution = ExecutionConfig()
    with pytest.raises(PredictionInputError, match="empty"):
        simulate_predictions(
            frame,
            pd.DataFrame(columns=["bar_index", "probability", "threshold"]),
            execution,
            PredictionStrategyConfig(horizon=3),
        )
    bad = predictions([(2, 1.5)])
    with pytest.raises(PredictionInputError, match="between 0 and 1"):
        simulate_predictions(frame, bad, execution, PredictionStrategyConfig(horizon=3))


def test_momentum_predictions_use_trailing_returns() -> None:
    rows = 12
    rising = price_frame(rows).assign(close=np.linspace(100.0, 110.0, rows))
    rising_pred = momentum_predictions(rising, lookback=3, start_bar=0)
    assert list(rising_pred["bar_index"]) == list(range(3, rows))
    assert (rising_pred["probability"] == 1.0).all()

    falling = price_frame(rows).assign(close=np.linspace(110.0, 100.0, rows))
    falling_pred = momentum_predictions(falling, lookback=3, start_bar=0)
    assert (falling_pred["probability"] == 0.0).all()
