"""Parity checks for InfiniteRunner XAU v2 engines vs MQL5 includes."""

from __future__ import annotations

import re
from pathlib import Path

from mt5_ea_ai_lab.infinite_runner import (
    calc_lot,
    evaluate_direction,
    trailing_evaluate,
)

REPO = Path(__file__).resolve().parents[2]
IR_DIR = REPO / "mt5" / "Include" / "InfiniteRunner"
EA = REPO / "mt5" / "Experts" / "InfiniteRunnerXAUDemoEA.mq5"
V1 = REPO / "github-demo" / "InfiniteRunner_XAU" / "InfiniteRunner_XAU.mq5"
TESTS = REPO / "mt5" / "Scripts" / "InfiniteRunnerContractTests.mq5"

BULL = {
    "fast": 2000.0,
    "slow": 1990.0,
    "fast_slope": 1.0,
    "slow_slope": 0.2,
    "close": 2001.0,
    "close_prev": 1995.0,
    "fast_prev": 1998.0,
}
BEAR = {
    "fast": 1990.0,
    "slow": 2000.0,
    "fast_slope": -1.0,
    "slow_slope": -0.2,
    "close": 1988.0,
    "close_prev": 1996.0,
    "fast_prev": 1992.0,
}
BUY_RECLAIM = {
    "fast": 2000.0,
    "slow": 1990.0,
    "fast_slope": 0.4,
    "slow_slope": 0.1,
    "close": 2002.0,
    "close_prev": 1998.0,
    "fast_prev": 2000.0,
}
NO_RECLAIM = dict(BUY_RECLAIM, close_prev=2005.0)


def test_v1_source_is_untouched() -> None:
    text = V1.read_text(encoding="utf-8")
    assert '#property version   "1.00"' in text
    assert "InpLots" in text
    assert "trade.Buy" in text


def test_aligned_buy_and_sell() -> None:
    decision, reason = evaluate_direction(
        "EMA_MTF", BULL, BULL, BUY_RECLAIM, BULL
    )
    assert decision == "BUY_ALLOWED"
    assert reason == "ema_mtf_buy"
    sell_m5 = {
        "fast": 1990.0,
        "slow": 2000.0,
        "fast_slope": -0.4,
        "slow_slope": -0.1,
        "close": 1987.0,
        "close_prev": 1992.0,
        "fast_prev": 1990.0,
    }
    decision, reason = evaluate_direction("EMA_MTF", BEAR, BEAR, sell_m5, BEAR)
    assert decision == "SELL_ALLOWED"
    assert reason == "ema_mtf_sell"


def test_conflict_and_missing_trigger() -> None:
    decision, reason = evaluate_direction(
        "EMA_MTF", BULL, BEAR, BUY_RECLAIM, BULL
    )
    assert decision == "NO_TRADE"
    assert reason == "h1_m15_conflict"
    decision, reason = evaluate_direction(
        "EMA_MTF", BULL, BULL, NO_RECLAIM, BULL
    )
    assert reason == "m5_buy_trigger_missing"


def test_pa_mode_is_not_faked() -> None:
    decision, reason = evaluate_direction(
        "PA_MTF", BULL, BULL, BUY_RECLAIM, BULL
    )
    assert decision == "NO_TRADE"
    assert reason == "pa_mode_not_implemented"


def test_legacy_uses_closed_chart_ema() -> None:
    decision, reason = evaluate_direction(
        "LEGACY_EMA", None, None, None, BULL
    )
    assert decision == "BUY_ALLOWED"
    assert reason == "legacy_closed_ema"


def test_risk_lot_floor_and_reject() -> None:
    ok, volume, reason = calc_lot(
        "RISK_PERCENT", 10000.0, 0.25, 0.01, 1.0, 250.0
    )
    assert ok and abs(volume - 0.10) < 1e-9
    ok, volume, reason = calc_lot(
        "RISK_PERCENT", 10000.0, 0.01, 0.01, 1.0, 250.0
    )
    assert not ok and reason == "min_volume_exceeds_risk"


def test_trailing_is_monotonic() -> None:
    buy = trailing_evaluate(
        is_buy=True,
        entry=2000.0,
        sl=1990.0,
        price=2010.0,
        initial_risk=10.0,
        trail_distance=5.0,
        trail_step=0.5,
        trail_start_r=1.5,
        break_even_r=1.0,
    )
    assert buy.update and buy.new_sl > 1990.0
    missing = trailing_evaluate(
        is_buy=True,
        entry=2000.0,
        sl=0.0,
        price=2010.0,
        initial_risk=10.0,
        trail_distance=5.0,
        trail_step=0.5,
        trail_start_r=1.5,
        break_even_r=1.0,
    )
    assert not missing.update and missing.reason == "SL_MISSING"


def test_mql_engines_stay_pure() -> None:
    forbidden = (
        "OrderSend",
        "CTrade",
        "MqlTradeRequest",
        "WebRequest",
        "SocketCreate",
        "AccountInfo",
    )
    for path in IR_DIR.glob("*.mqh"):
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            assert token not in text, f"{token} in {path.name}"


def test_demo_ea_uses_closed_bars_and_exec_broker() -> None:
    text = EA.read_text(encoding="utf-8")
    assert "CopyBuffer" in text
    assert "CopyBuffer(fast_handle,0,1,need,fast)" in text
    assert "ExecOpenMarket" in text
    assert "ExecCalcProfit" in text
    assert "InpEnableExecution        = false" in text
    assert "OrderSend" not in re.sub(r"//[^\n]*", "", text)
    assert "InpTakeProfitR" in text
    assert "InpMaxPositions           = 1" in text
    assert "IR_DIR_EMA_MTF" in text


def test_contract_script_covers_core_ids() -> None:
    text = TESTS.read_text(encoding="utf-8")
    for test_id in ("D1", "D3", "D6", "R2", "T4", "T5", "T6"):
        assert f'Record("{test_id}"' in text
    assert "ALL_PASS" in text
