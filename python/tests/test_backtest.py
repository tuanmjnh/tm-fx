from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.backtest import (
    BacktestInputError,
    ExecutionConfig,
    run_backtest,
)
from mt5_ea_ai_lab.signals import EmaCrossConfig

DEMO_CLOSES = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12]
REVERSAL_CLOSES = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12, 1.11, 1.07, 1.03, 1.02]
STRATEGY = EmaCrossConfig(2, 3)
NO_COST = ExecutionConfig(position_units=10_000.0)
WITH_COST = ExecutionConfig(
    position_units=10_000.0,
    spread_points=2.0,
    slippage_points=1.0,
    commission_per_side=2.5,
)


def make_frame(
    closes: list[float],
    opens: list[float] | None = None,
    highs: list[float] | None = None,
    lows: list[float] | None = None,
) -> pd.DataFrame:
    count = len(closes)
    if opens is None:
        opens = [closes[0]] + closes[:-1]
    if highs is None:
        highs = [max(open_price, close) + 0.001 for open_price, close in zip(opens, closes)]
    if lows is None:
        lows = [min(open_price, close) - 0.001 for open_price, close in zip(opens, closes)]
    return pd.DataFrame(
        {
            "timestamp": pd.date_range(
                "2024-01-01", periods=count, freq="5min", tz="UTC"
            ),
            "open": opens,
            "high": highs,
            "low": lows,
            "close": closes,
        }
    )


def test_buy_executes_at_next_open_and_closes_at_end_of_data() -> None:
    frame = make_frame(DEMO_CLOSES)
    result = run_backtest(frame, STRATEGY, NO_COST)

    assert len(result.trades) == 1
    trade = result.trades.iloc[0]
    assert trade["side"] == "long"
    assert trade["entry_bar"] == 6
    assert trade["exit_bar"] == 7
    assert trade["entry_time"] == "2024-01-01T00:30:00+00:00"
    assert trade["exit_time"] == "2024-01-01T00:35:00+00:00"
    assert trade["entry_fill"] == pytest.approx(1.09)
    assert trade["exit_fill"] == pytest.approx(1.12)
    assert trade["gross_pnl"] == pytest.approx(300.0)
    assert trade["commission"] == pytest.approx(0.0)
    assert trade["pnl"] == pytest.approx(300.0)
    assert trade["bars_held"] == 1
    assert trade["exit_reason"] == "end_of_data"

    assert result.metrics["final_equity"] == pytest.approx(10_300.0)
    assert result.metrics["net_profit"] == pytest.approx(300.0)
    assert result.metrics["trade_count"] == 1
    assert result.metrics["win_rate"] == pytest.approx(1.0)
    assert result.metrics["exposure_ratio"] == pytest.approx(2 / 8)
    assert result.metrics["max_drawdown"] == pytest.approx(0.0)
    assert result.metrics["sharpe_ratio"] is None
    assert "sharpe_ratio" in result.metrics["undefined_metrics"]

    assert result.equity["equity"].iloc[6] == pytest.approx(10_100.0)
    assert result.equity["position"].iloc[6] == 1
    assert result.equity["equity"].iloc[7] == pytest.approx(10_300.0)
    assert result.equity["position"].iloc[7] == 0
    assert result.signals["signal"].iloc[5] == "BUY"


def test_costs_are_applied_to_both_fills_and_commission_per_side() -> None:
    result = run_backtest(make_frame(DEMO_CLOSES), STRATEGY, WITH_COST)

    trade = result.trades.iloc[0]
    assert trade["entry_fill"] == pytest.approx(1.09002)
    assert trade["exit_fill"] == pytest.approx(1.11998)
    assert trade["gross_pnl"] == pytest.approx(299.6)
    assert trade["commission"] == pytest.approx(5.0)
    assert trade["pnl"] == pytest.approx(294.6)
    assert result.metrics["final_equity"] == pytest.approx(10_294.6)

    benchmark = result.benchmark
    assert benchmark is not None
    assert benchmark["entry_fill"] == pytest.approx(1.10002)
    assert benchmark["exit_fill"] == pytest.approx(1.11998)
    assert benchmark["gross_pnl"] == pytest.approx(199.6)
    assert benchmark["commission"] == pytest.approx(5.0)
    assert benchmark["net_pnl"] == pytest.approx(194.6)


def test_stop_loss_fills_inside_the_entry_bar() -> None:
    frame = make_frame(DEMO_CLOSES)
    frame.loc[6, "low"] = 1.0885
    frame.loc[6, "high"] = 1.1010
    execution = ExecutionConfig(
        position_units=10_000.0, stop_loss_points=100.0
    )

    result = run_backtest(frame, STRATEGY, execution)

    trade = result.trades.iloc[0]
    assert trade["exit_reason"] == "stop_loss"
    assert trade["exit_bar"] == 6
    assert trade["exit_fill"] == pytest.approx(1.089)
    assert trade["gross_pnl"] == pytest.approx(-10.0)
    assert trade["pnl"] == pytest.approx(-10.0)
    assert result.metrics["final_equity"] == pytest.approx(9_990.0)
    assert result.metrics["loss_count"] == 1


def test_take_profit_fills_inside_the_entry_bar() -> None:
    frame = make_frame(DEMO_CLOSES)
    frame.loc[6, "low"] = 1.0895
    frame.loc[6, "high"] = 1.0950
    frame.loc[6, "close"] = 1.09
    execution = ExecutionConfig(
        position_units=10_000.0, take_profit_points=100.0
    )

    result = run_backtest(frame, STRATEGY, execution)

    trade = result.trades.iloc[0]
    assert trade["exit_reason"] == "take_profit"
    assert trade["exit_bar"] == 6
    assert trade["exit_fill"] == pytest.approx(1.091)
    assert trade["gross_pnl"] == pytest.approx(10.0)
    assert result.metrics["final_equity"] == pytest.approx(10_010.0)


def test_stop_loss_wins_when_stop_and_target_share_a_bar() -> None:
    frame = make_frame(DEMO_CLOSES)
    frame.loc[6, "low"] = 1.0880
    frame.loc[6, "high"] = 1.0920
    frame.loc[6, "close"] = 1.09
    execution = ExecutionConfig(
        position_units=10_000.0,
        stop_loss_points=100.0,
        take_profit_points=100.0,
    )

    result = run_backtest(frame, STRATEGY, execution)

    trade = result.trades.iloc[0]
    assert trade["exit_reason"] == "stop_loss"
    assert trade["exit_fill"] == pytest.approx(1.089)
    assert trade["pnl"] == pytest.approx(-10.0)


def test_trailing_stop_locks_profit_and_fills_on_the_next_bar() -> None:
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12, 1.13, 1.11, 1.09]
    execution = ExecutionConfig(
        position_units=10_000.0, trailing_stop_points=100.0
    )

    result = run_backtest(make_frame(closes), STRATEGY, execution)

    trade = result.trades.iloc[0]
    assert trade["entry_bar"] == 6
    assert trade["exit_bar"] == 7
    assert trade["entry_fill"] == pytest.approx(1.09)
    assert trade["exit_fill"] == pytest.approx(1.10)
    assert trade["pnl"] == pytest.approx(100.0)
    assert trade["exit_reason"] == "trailing_stop"
    assert result.metrics["exit_reason_counts"] == {"trailing_stop": 1}


def test_trailing_activation_delays_the_first_stop_move() -> None:
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.085, 1.13, 1.14]
    frame = make_frame(closes)

    immediate = run_backtest(
        frame,
        STRATEGY,
        ExecutionConfig(position_units=10_000.0, trailing_stop_points=100.0),
    )
    delayed = run_backtest(
        frame,
        STRATEGY,
        ExecutionConfig(
            position_units=10_000.0,
            trailing_stop_points=100.0,
            trailing_activation_points=2_000.0,
        ),
    )

    first = immediate.trades.iloc[0]
    assert first["exit_bar"] == 7
    assert first["exit_fill"] == pytest.approx(1.10)
    assert first["pnl"] == pytest.approx(100.0)

    second = delayed.trades.iloc[0]
    assert second["exit_bar"] == 9
    assert second["exit_fill"] == pytest.approx(1.13)
    assert second["pnl"] == pytest.approx(400.0)
    assert second["exit_reason"] == "trailing_stop"


def test_static_stop_keeps_its_reason_before_any_trailing_move() -> None:
    execution = ExecutionConfig(
        position_units=10_000.0,
        stop_loss_points=50.0,
        trailing_stop_points=100.0,
    )

    result = run_backtest(make_frame(DEMO_CLOSES), STRATEGY, execution)

    trade = result.trades.iloc[0]
    assert trade["exit_reason"] == "stop_loss"
    assert trade["exit_bar"] == 6
    assert trade["exit_fill"] == pytest.approx(1.0895)
    assert trade["pnl"] == pytest.approx(-5.0)


def test_trailing_stop_tracks_lows_for_a_short_position() -> None:
    execution = ExecutionConfig(
        position_units=10_000.0, trailing_stop_points=100.0
    )

    result = run_backtest(make_frame(REVERSAL_CLOSES), STRATEGY, execution)

    short_trade = result.trades.iloc[1]
    assert short_trade["side"] == "short"
    assert short_trade["entry_bar"] == 10
    assert short_trade["exit_bar"] == 11
    assert short_trade["entry_fill"] == pytest.approx(1.07)
    assert short_trade["exit_fill"] == pytest.approx(1.03)
    assert short_trade["pnl"] == pytest.approx(400.0)
    assert short_trade["exit_reason"] == "trailing_stop"


def test_gap_through_stop_fills_at_the_worse_open() -> None:
    frame = make_frame(
        DEMO_CLOSES,
        opens=[1.10, 1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.05],
        highs=[1.101, 1.101, 1.091, 1.081, 1.071, 1.091, 1.101, 1.06],
        lows=[1.099, 1.089, 1.079, 1.069, 1.059, 1.059, 1.0895, 1.04],
    )
    frame.loc[7, "close"] = 1.05
    execution = ExecutionConfig(
        position_units=10_000.0, stop_loss_points=100.0
    )

    result = run_backtest(frame, STRATEGY, execution)

    trade = result.trades.iloc[0]
    assert trade["exit_reason"] == "stop_loss"
    assert trade["exit_bar"] == 7
    assert trade["exit_fill"] == pytest.approx(1.05)
    assert trade["gross_pnl"] == pytest.approx(-400.0)


def test_opposite_signal_reverses_and_records_two_trades() -> None:
    result = run_backtest(make_frame(REVERSAL_CLOSES), STRATEGY, NO_COST)

    assert len(result.trades) == 2
    first, second = result.trades.iloc[0], result.trades.iloc[1]
    assert first["side"] == "long"
    assert first["exit_reason"] == "opposite_signal"
    assert first["entry_fill"] == pytest.approx(1.09)
    assert first["exit_fill"] == pytest.approx(1.07)
    assert first["pnl"] == pytest.approx(-200.0)
    assert second["side"] == "short"
    assert second["exit_reason"] == "end_of_data"
    assert second["entry_fill"] == pytest.approx(1.07)
    assert second["exit_fill"] == pytest.approx(1.02)
    assert second["pnl"] == pytest.approx(500.0)

    metrics = result.metrics
    assert metrics["trade_count"] == 2
    assert metrics["win_count"] == 1
    assert metrics["loss_count"] == 1
    assert metrics["win_rate"] == pytest.approx(0.5)
    assert metrics["gross_profit"] == pytest.approx(500.0)
    assert metrics["gross_loss"] == pytest.approx(200.0)
    assert metrics["profit_factor"] == pytest.approx(2.5)
    assert metrics["average_trade"] == pytest.approx(150.0)
    assert metrics["max_drawdown"] == pytest.approx(500.0)
    assert metrics["exposure_ratio"] == pytest.approx(0.5)
    assert result.metrics["final_equity"] == pytest.approx(10_300.0)


def test_no_trade_dataset_keeps_equity_flat() -> None:
    result = run_backtest(make_frame([1.10] * 7), STRATEGY, NO_COST)

    assert result.trades.empty
    assert result.metrics["trade_count"] == 0
    assert result.metrics["win_rate"] is None
    assert result.metrics["profit_factor"] is None
    assert result.metrics["final_equity"] == pytest.approx(10_000.0)
    assert result.metrics["max_drawdown"] == pytest.approx(0.0)
    assert result.metrics["exposure_ratio"] == pytest.approx(0.0)
    assert result.benchmark is not None
    assert result.benchmark["net_pnl"] == pytest.approx(0.0)


def test_repeated_runs_are_identical() -> None:
    frame = make_frame(REVERSAL_CLOSES)
    first = run_backtest(frame, STRATEGY, WITH_COST)
    second = run_backtest(frame, STRATEGY, WITH_COST)

    pd.testing.assert_frame_equal(first.trades, second.trades)
    pd.testing.assert_frame_equal(first.equity, second.equity)
    pd.testing.assert_frame_equal(first.signals, second.signals)
    assert first.metrics == second.metrics
    assert first.benchmark == second.benchmark


def test_input_validation_rejects_bad_frames() -> None:
    frame = make_frame(DEMO_CLOSES)

    with pytest.raises(BacktestInputError, match="empty"):
        run_backtest(frame.iloc[0:0], STRATEGY, NO_COST)

    with pytest.raises(BacktestInputError, match="missing required columns"):
        run_backtest(frame.drop(columns=["close"]), STRATEGY, NO_COST)

    duplicated = pd.concat([frame, frame.iloc[[1]]], ignore_index=True)
    with pytest.raises(BacktestInputError, match="duplicates"):
        run_backtest(duplicated, STRATEGY, NO_COST)

    with pytest.raises(BacktestInputError, match="increasing order"):
        run_backtest(frame.iloc[::-1].reset_index(drop=True), STRATEGY, NO_COST)

    inconsistent = frame.copy()
    inconsistent.loc[0, "high"] = 1.0
    with pytest.raises(BacktestInputError, match="high is below"):
        run_backtest(inconsistent, STRATEGY, NO_COST)

    non_positive = frame.copy()
    non_positive.loc[0, "close"] = 0.0
    with pytest.raises(BacktestInputError, match="positive"):
        run_backtest(non_positive, STRATEGY, NO_COST)

    non_finite = frame.copy()
    non_finite.loc[0, "close"] = np.nan
    with pytest.raises(BacktestInputError, match="non-finite"):
        run_backtest(non_finite, STRATEGY, NO_COST)


def test_execution_and_strategy_validation() -> None:
    with pytest.raises(BacktestInputError, match="initial_equity"):
        ExecutionConfig(initial_equity=0.0).validate()
    with pytest.raises(BacktestInputError, match="spread_points"):
        ExecutionConfig(spread_points=-1.0).validate()
    with pytest.raises(BacktestInputError, match="stop_loss_points"):
        ExecutionConfig(stop_loss_points=0.0).validate()
    with pytest.raises(BacktestInputError, match="trailing_stop_points"):
        ExecutionConfig(trailing_stop_points=0.0).validate()
    with pytest.raises(BacktestInputError, match="trailing_activation_points"):
        ExecutionConfig(trailing_activation_points=0.0).validate()
    with pytest.raises(BacktestInputError, match="requires trailing_stop_points"):
        ExecutionConfig(trailing_activation_points=100.0).validate()

    with pytest.raises(ValueError, match="lower than slow"):
        run_backtest(make_frame(DEMO_CLOSES), EmaCrossConfig(3, 3), NO_COST)
