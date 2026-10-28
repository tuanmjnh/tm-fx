from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.data.loader import load_ohlcv
from mt5_ea_ai_lab.signals import (
    REASON_INSUFFICIENT_HISTORY,
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

DEMO_CLOSES = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12]
TIMESTAMPS = pd.date_range("2024-01-01", periods=len(DEMO_CLOSES), freq="5min", tz="UTC")


def test_compute_ema_seeds_with_sma() -> None:
    ema = compute_ema([1, 2, 3, 4, 5], 3)

    assert np.isnan(ema[0]) and np.isnan(ema[1])
    assert ema[2] == pytest.approx(2.0)
    assert ema[3] == pytest.approx(3.0)
    assert ema[4] == pytest.approx(4.0)


def test_compute_ema_rejects_short_or_invalid_input() -> None:
    assert np.isnan(compute_ema([1, 2, 3], 5)).all()
    assert np.isnan(compute_ema([1, 0, 2], 2)).all()
    assert np.isnan(compute_ema([1, float("nan"), 3], 2)).all()
    assert np.isnan(compute_ema([1, 2, 3], 0)).all()


def test_crossover_buy_and_long_disabled() -> None:
    signal, reason = evaluate_crossover(
        1.0, 1.1, 1.2, 1.15, allow_long=True, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_BUY, REASON_OK)

    signal, reason = evaluate_crossover(
        1.0, 1.1, 1.2, 1.15, allow_long=False, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_HOLD, REASON_LONG_DISABLED)


def test_crossover_sell_and_short_disabled() -> None:
    signal, reason = evaluate_crossover(
        1.2, 1.1, 1.0, 1.05, allow_long=True, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_SELL, REASON_OK)

    signal, reason = evaluate_crossover(
        1.2, 1.1, 1.0, 1.05, allow_long=True, allow_short=False
    )
    assert (signal, reason) == (SIGNAL_HOLD, REASON_SHORT_DISABLED)


def test_crossover_equality_counts_as_a_cross() -> None:
    signal, reason = evaluate_crossover(
        1.1, 1.1, 1.2, 1.15, allow_long=True, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_BUY, REASON_OK)


def test_crossover_no_cross_and_invalid_input() -> None:
    signal, reason = evaluate_crossover(
        1.2, 1.1, 1.3, 1.2, allow_long=True, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_HOLD, REASON_NO_CROSS)

    signal, reason = evaluate_crossover(
        float("nan"), 1.1, 1.2, 1.15, allow_long=True, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_UNKNOWN, REASON_INVALID_INPUT)

    signal, reason = evaluate_crossover(
        1.0, 0.0, 1.2, 1.15, allow_long=True, allow_short=True
    )
    assert (signal, reason) == (SIGNAL_UNKNOWN, REASON_INVALID_INPUT)


def test_generate_signals_warmup_and_buy_at_bar_five() -> None:
    frame = generate_signals(DEMO_CLOSES, TIMESTAMPS, EmaCrossConfig(2, 3))

    assert list(frame["signal"].iloc[:3]) == [SIGNAL_UNKNOWN] * 3
    assert list(frame["reason"].iloc[:3]) == [REASON_INSUFFICIENT_HISTORY] * 3
    assert frame["signal"].iloc[3] == SIGNAL_HOLD
    assert frame["signal"].iloc[4] == SIGNAL_HOLD
    assert frame["signal"].iloc[5] == SIGNAL_BUY
    assert frame["reason"].iloc[5] == REASON_OK
    assert frame["fast_prev"].iloc[5] == pytest.approx(1.065)
    assert frame["slow_prev"].iloc[5] == pytest.approx(1.07)
    assert frame["fast"].iloc[5] == pytest.approx(1.0816666666666666)
    assert frame["slow"].iloc[5] == pytest.approx(1.08)
    assert list(frame["signal"].iloc[6:]) == [SIGNAL_HOLD, SIGNAL_HOLD]
    assert list(frame["timestamp"]) == list(TIMESTAMPS)


def test_generate_signals_respects_disabled_direction() -> None:
    frame = generate_signals(
        DEMO_CLOSES, TIMESTAMPS, EmaCrossConfig(2, 3, allow_long=False)
    )

    assert frame["signal"].iloc[5] == SIGNAL_HOLD
    assert frame["reason"].iloc[5] == REASON_LONG_DISABLED


def test_generate_signals_has_no_look_ahead() -> None:
    config = EmaCrossConfig(2, 3)
    baseline = generate_signals(DEMO_CLOSES, TIMESTAMPS, config)

    changed = list(DEMO_CLOSES)
    changed[-1] = 2.0
    mutated = generate_signals(changed, TIMESTAMPS, config)

    pd.testing.assert_frame_equal(baseline.iloc[:-1], mutated.iloc[:-1])


def test_generate_signals_is_deterministic() -> None:
    config = EmaCrossConfig(2, 3)
    first = generate_signals(DEMO_CLOSES, TIMESTAMPS, config)
    second = generate_signals(DEMO_CLOSES, TIMESTAMPS, config)

    pd.testing.assert_frame_equal(first, second)


def test_generate_signals_rejects_invalid_config_and_lengths() -> None:
    with pytest.raises(ValueError):
        generate_signals(DEMO_CLOSES, TIMESTAMPS, EmaCrossConfig(3, 3))

    with pytest.raises(ValueError):
        generate_signals(DEMO_CLOSES, TIMESTAMPS[:-1], EmaCrossConfig(2, 3))


def test_shared_mql5_python_window_fixtures() -> None:
    config = EmaCrossConfig(2, 3)
    timestamps = pd.date_range("2024-01-01", periods=4, freq="5min", tz="UTC")

    buy = generate_signals([1.10, 1.09, 1.05, 1.12], timestamps, config)
    assert buy["signal"].iloc[-1] == SIGNAL_BUY
    assert buy["reason"].iloc[-1] == REASON_OK
    assert buy["fast_prev"].iloc[-1] == pytest.approx(1.065)
    assert buy["slow_prev"].iloc[-1] == pytest.approx(1.08)
    assert buy["fast"].iloc[-1] == pytest.approx(1.1016666666666666)
    assert buy["slow"].iloc[-1] == pytest.approx(1.10)

    sell = generate_signals([1.05, 1.06, 1.12, 1.00], timestamps, config)
    assert sell["signal"].iloc[-1] == SIGNAL_SELL
    assert sell["reason"].iloc[-1] == REASON_OK
    assert sell["fast_prev"].iloc[-1] == pytest.approx(1.0983333333333334)
    assert sell["slow_prev"].iloc[-1] == pytest.approx(1.0766666666666667)
    assert sell["fast"].iloc[-1] == pytest.approx(1.0327777777777777)
    assert sell["slow"].iloc[-1] == pytest.approx(1.0383333333333333)

    hold = generate_signals([1.10, 1.09, 1.08, 1.07], timestamps, config)
    assert hold["signal"].iloc[-1] == SIGNAL_HOLD
    assert hold["reason"].iloc[-1] == REASON_NO_CROSS


def test_shared_parity_fixture_signal_sequence() -> None:
    fixture = (
        Path(__file__).resolve().parents[2]
        / "datasets"
        / "samples"
        / "parity_ema_cross.csv"
    )
    frame, _ = load_ohlcv(fixture, data_kind="synthetic")
    signals = generate_signals(
        frame["close"], frame["timestamp"], EmaCrossConfig(2, 3)
    )

    assert signals["signal"].tolist() == [
        "UNKNOWN",
        "UNKNOWN",
        "UNKNOWN",
        "HOLD",
        "HOLD",
        "BUY",
        "HOLD",
        "HOLD",
        "HOLD",
        "SELL",
        "HOLD",
        "HOLD",
    ]
    assert signals["reason"].iloc[5] == "OK"
    assert signals["reason"].iloc[9] == "OK"


def test_generate_signals_marks_invalid_prices() -> None:
    closes = [1.10, 1.09, 1.08, 0.0, 1.06, 1.09, 1.10, 1.12]
    frame = generate_signals(closes, TIMESTAMPS, EmaCrossConfig(2, 3))

    assert frame["reason"].iloc[3] == "INDICATOR_FAILED"
    assert frame["signal"].iloc[3] == SIGNAL_UNKNOWN
    assert frame["signal"].iloc[7] == SIGNAL_HOLD


def test_invalid_config_message() -> None:
    with pytest.raises(ValueError, match="lower than slow"):
        EmaCrossConfig(3, 2).validate()

    with pytest.raises(ValueError, match="positive"):
        EmaCrossConfig(0, 2).validate()
