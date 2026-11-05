"""Unit tests for the independent Wonderwhales spec port (cross-implementation).

These test the port against the documented rules, never against MQL5 output, so
they stay meaningful if the MQL5 indicator changes. They are NOT parity evidence.
"""
from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.signals.wonderwhales import (
    MODE_EMA,
    MODE_SAR,
    MODE_SAR_EMA,
    MODE_SAR_EMA_ATR,
    SIGNAL_IDS,
    WonderwhalesConfig,
    compute_atr,
    compute_ema,
    compute_psar,
    generate_bars,
    psar_direction,
    signal_rows,
)


def _bars(prices: list[float], start: str = "2024-01-01") -> pd.DataFrame:
    times = pd.date_range(start, periods=len(prices), freq="5min")
    close = np.asarray(prices, dtype=float)
    return pd.DataFrame(
        {
            "bar_open_time": times,
            "open": close,
            "high": close + 0.5,
            "low": close - 0.5,
            "close": close,
            "tick_volume": np.arange(len(prices)) + 1,
        }
    )


def test_ema_is_seeded_with_the_sma_of_the_first_period() -> None:
    values = [10.0, 11.0, 12.0, 13.0]
    ema = compute_ema(values, 3)
    assert np.isnan(ema[0]) and np.isnan(ema[1])
    assert ema[2] == pytest.approx((10.0 + 11.0 + 12.0) / 3.0)
    alpha = 2.0 / 4.0
    assert ema[3] == pytest.approx(alpha * 13.0 + (1 - alpha) * ema[2])


def test_atr_uses_wilder_smoothing() -> None:
    high = [1.2, 1.3, 1.4, 1.5, 1.6]
    low = [1.0, 1.1, 1.2, 1.3, 1.4]
    close = [1.1, 1.2, 1.3, 1.4, 1.5]
    atr = compute_atr(high, low, close, 3)
    assert np.isnan(atr[1])
    #--- first three true ranges are 0.2 each
    assert atr[2] == pytest.approx(0.2)
    assert atr[3] == pytest.approx((0.2 * 2 + 0.2) / 3.0)


def test_psar_flips_side_on_a_reversal() -> None:
    falling = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0]
    rising = [6.0, 7.0, 8.0, 9.0, 10.0, 11.0]
    bars = _bars(falling + rising)
    psar = compute_psar(bars["high"], bars["low"], bars["close"],
                        0.02, 0.02, 0.2)
    evaluated = generate_bars(bars, WonderwhalesConfig(mode=MODE_SAR))
    #--- all bars are closed except the last, so a flip must be present.
    assert bool(evaluated["buy_flip"].any())


def test_direction_rule_equality_is_bearish() -> None:
    #--- psar == close must be treated as -1 (spec section 4.1 / S6).
    assert psar_direction(100.0, 100.0, 1) == -1
    assert psar_direction(99.0, 100.0, -1) == 1
    assert psar_direction(101.0, 100.0, 1) == -1
    #--- An invalid PSAR keeps the previous direction (spec S5).
    assert psar_direction(float("nan"), 100.0, 1) == 1
    assert psar_direction(0.0, 100.0, -1) == -1
    assert psar_direction(100.0, 0.0, 1) == 1


def test_last_bar_never_signals() -> None:
    prices = list(np.linspace(10.0, 20.0, 40)) + list(np.linspace(20.0, 10.0, 40))
    bars = _bars([float(p) for p in prices])
    evaluated = generate_bars(bars, WonderwhalesConfig(mode=MODE_SAR))
    assert not bool(evaluated["signal_buy"].iloc[-1])
    assert not bool(evaluated["signal_sell"].iloc[-1])


def test_mode_filters_apply_the_ema_gate() -> None:
    prices = list(np.linspace(10.0, 20.0, 60)) + list(np.linspace(20.0, 10.0, 60))
    bars = _bars([float(p) for p in prices])
    config = WonderwhalesConfig(mode=MODE_SAR_EMA)
    evaluated = generate_bars(bars, config)
    #--- An SAR-only flip blocked by the EMA trend must be flagged as blocked.
    blocked = evaluated["blocked_buy"] | evaluated["blocked_sell"]
    flips = evaluated["buy_flip"] | evaluated["sell_flip"]
    signals = evaluated["signal_buy"] | evaluated["signal_sell"]
    assert bool(flips.any())
    assert (signals & blocked).sum() == 0
    assert (signals | blocked).sum() <= flips.sum()


def test_ema_mode_uses_crossover_not_flips() -> None:
    prices = list(np.linspace(10.0, 20.0, 60)) + list(np.linspace(20.0, 10.0, 60))
    bars = _bars([float(p) for p in prices])
    evaluated = generate_bars(bars, WonderwhalesConfig(mode=MODE_EMA))
    assert bool((evaluated["signal_buy"] | evaluated["signal_sell"]).any())
    #--- EMA mode ignores the PSAR flips entirely.
    assert (evaluated["signal_buy"] & ~evaluated["ema_cross_up"]).sum() == 0
    assert (evaluated["signal_sell"] & ~evaluated["ema_cross_down"]).sum() == 0


def test_signal_rows_schema_and_signal_ids() -> None:
    prices = list(np.linspace(10.0, 20.0, 60)) + list(np.linspace(20.0, 10.0, 60))
    bars = _bars([float(p) for p in prices])
    #--- Plain SAR so flips are not filtered out by the EMA trend gate.
    rows = signal_rows(bars, WonderwhalesConfig(mode=MODE_SAR),
                       "XAUUSDm", "M5")
    assert list(rows.columns) == [
        "bar_open_time", "symbol", "timeframe", "signal_id", "side",
        "sar_dir", "psar", "fast", "slow", "atr_pct",
    ]
    assert len(rows) > 0
    for _, row in rows.iterrows():
        assert row["symbol"] == "XAUUSDm"
        assert row["timeframe"] == "M5"
        assert row["signal_id"] == SIGNAL_IDS[(MODE_SAR, row["side"] == "BUY")]
        expected_dir = 1 if row["side"] == "BUY" else -1
        assert row["sar_dir"] == expected_dir


def test_every_mode_has_signal_ids() -> None:
    for mode in (MODE_SAR, MODE_EMA, MODE_SAR_EMA, MODE_SAR_EMA_ATR):
        assert (mode, True) in SIGNAL_IDS
        assert (mode, False) in SIGNAL_IDS


def test_config_guards_match_the_spec() -> None:
    cfg = WonderwhalesConfig(fast_ema=50, slow_ema=50, psar_start=0.2,
                             psar_max=0.01, ema200=5, atr_len=0).normalized()
    assert cfg.slow_ema == 51          # slow must exceed fast
    assert cfg.psar_max == pytest.approx(0.2)   # clamped up to psar_start
    assert cfg.ema200 == 10            # minimum 10
    assert cfg.atr_len == 1


def test_unknown_mode_is_rejected() -> None:
    with pytest.raises(ValueError, match="unknown mode"):
        WonderwhalesConfig(mode=99).normalized()


def test_missing_bar_columns_are_rejected() -> None:
    with pytest.raises(ValueError, match="missing columns"):
        generate_bars(pd.DataFrame({"close": [1.0, 2.0]}), WonderwhalesConfig())
