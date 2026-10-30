"""Pure-Python parity helpers for InfiniteRunner XAU v2 engines.

Mirrors mt5/Include/InfiniteRunner/*.mqh. No broker, account or order APIs.
"""

from __future__ import annotations

from dataclasses import dataclass


def ema_slope(now: float, then: float, lookback: int) -> float:
    if lookback <= 0:
        return 0.0
    return (now - then) / lookback


def buy_reclaim(
    close: float,
    close_prev: float,
    fast: float,
    fast_prev: float,
    slow: float,
    pullback_tol: float,
) -> bool:
    if close_prev > fast_prev + max(pullback_tol, 0.0):
        return False
    return close > fast and close > slow


def sell_reclaim(
    close: float,
    close_prev: float,
    fast: float,
    fast_prev: float,
    slow: float,
    pullback_tol: float,
) -> bool:
    if close_prev < fast_prev - max(pullback_tol, 0.0):
        return False
    return close < fast and close < slow


def bias_from_ema(
    fast: float,
    slow: float,
    fast_slope: float,
    slow_slope: float,
    min_fast_slope: float,
    max_slow_down: float,
) -> str:
    if fast > slow and fast_slope > min_fast_slope and slow_slope >= -max_slow_down:
        return "BULL"
    if fast < slow and fast_slope < -min_fast_slope and slow_slope <= max_slow_down:
        return "BEAR"
    return "NONE"


def evaluate_direction(
    mode: str,
    h1: dict[str, float] | None,
    m15: dict[str, float] | None,
    m5: dict[str, float] | None,
    chart: dict[str, float] | None,
    min_fast_slope: float = 0.0,
    max_slow_down: float = 0.5,
    pullback_tol: float = 1.0,
) -> tuple[str, str]:
    if mode == "PA_MTF":
        return "NO_TRADE", "pa_mode_not_implemented"
    if mode == "LEGACY_EMA":
        if chart is None:
            return "DATA_NOT_READY", "legacy_ema_not_ready"
        buy = chart["fast"] >= chart["slow"]
        return ("BUY_ALLOWED" if buy else "SELL_ALLOWED"), "legacy_closed_ema"
    if h1 is None or m15 is None or m5 is None:
        return "DATA_NOT_READY", "mtf_ema_not_ready"
    h1_bias = bias_from_ema(
        h1["fast"], h1["slow"], h1["fast_slope"], h1["slow_slope"],
        min_fast_slope, max_slow_down,
    )
    m15_bias = bias_from_ema(
        m15["fast"], m15["slow"], m15["fast_slope"], m15["slow_slope"],
        min_fast_slope, max_slow_down,
    )
    buy_trig = buy_reclaim(
        m5["close"], m5["close_prev"], m5["fast"], m5["fast_prev"], m5["slow"],
        pullback_tol,
    )
    sell_trig = sell_reclaim(
        m5["close"], m5["close_prev"], m5["fast"], m5["fast_prev"], m5["slow"],
        pullback_tol,
    )
    if h1_bias == "NONE" or m15_bias == "NONE":
        return "NO_TRADE", "mtf_bias_unclear"
    if h1_bias != m15_bias:
        return "NO_TRADE", "h1_m15_conflict"
    if h1_bias == "BULL":
        if not buy_trig:
            return "NO_TRADE", "m5_buy_trigger_missing"
        return "BUY_ALLOWED", "ema_mtf_buy"
    if not sell_trig:
        return "NO_TRADE", "m5_sell_trigger_missing"
    return "SELL_ALLOWED", "ema_mtf_sell"


def normalize_volume(
    volume: float, volume_min: float, volume_max: float, volume_step: float
) -> float:
    if volume <= 0 or volume_min <= 0 or volume_step <= 0 or volume_max < volume_min:
        return 0.0
    value = int(volume / volume_step + 1e-9) * volume_step
    value = round(value, 8)
    if value > volume_max:
        value = round(volume_max, 8)
    if value < volume_min:
        return 0.0
    return value


def calc_lot(
    mode: str,
    equity: float,
    risk_percent: float,
    fixed_lot: float,
    max_lots: float,
    loss_per_lot: float,
    volume_min: float = 0.01,
    volume_max: float = 5.0,
    volume_step: float = 0.01,
) -> tuple[bool, float, str]:
    if loss_per_lot <= 0:
        return False, 0.0, "loss_per_lot_invalid"
    if mode == "FIXED":
        raw = fixed_lot
    else:
        risk_money = equity * risk_percent / 100.0
        if risk_money <= 0:
            return False, 0.0, "risk_budget_invalid"
        raw = risk_money / loss_per_lot
    if max_lots > 0:
        raw = min(raw, max_lots)
    volume = normalize_volume(raw, volume_min, volume_max, volume_step)
    if volume <= 0:
        return False, 0.0, "min_volume_exceeds_risk"
    return True, volume, "ok"


def sl_improves(is_buy: bool, candidate: float, current: float, step: float) -> bool:
    need = max(step, 0.0)
    if is_buy:
        return candidate > current + need - 1e-12
    return candidate < current - need + 1e-12


@dataclass
class TrailResult:
    update: bool
    new_sl: float
    reason: str


def trailing_evaluate(
    *,
    is_buy: bool,
    entry: float,
    sl: float,
    price: float,
    initial_risk: float,
    trail_distance: float,
    trail_step: float,
    trail_start_r: float,
    break_even_r: float,
    min_stop: float = 0.5,
) -> TrailResult:
    if sl <= 0:
        return TrailResult(False, sl, "SL_MISSING")
    profit = (price - entry) if is_buy else (entry - price)
    profit_r = profit / initial_risk
    if profit <= 0:
        return TrailResult(False, sl, "HOLD_NO_PROFIT")
    candidate = sl
    reason = "HOLD"
    if profit_r >= break_even_r:
        be = entry
        if sl_improves(is_buy, be, candidate, 0.0):
            candidate = be
            reason = "BREAK_EVEN"
    if profit_r >= trail_start_r and trail_distance > 0:
        fixed = price - trail_distance if is_buy else price + trail_distance
        if sl_improves(is_buy, fixed, candidate, trail_step):
            candidate = fixed
            reason = "TRAIL_FIXED"
    if not sl_improves(is_buy, candidate, sl, trail_step):
        return TrailResult(False, sl, "HOLD_NOT_IMPROVING")
    if min_stop > 0:
        if is_buy and candidate > price - min_stop:
            return TrailResult(False, sl, "TRAIL_TOO_CLOSE")
        if not is_buy and candidate < price + min_stop:
            return TrailResult(False, sl, "TRAIL_TOO_CLOSE")
    return TrailResult(True, candidate, reason)
