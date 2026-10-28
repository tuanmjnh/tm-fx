"""Trailing-stop price update for the deterministic bar backtester.

OHLC data does not reveal whether the high or the low occurred first. The stop
is therefore calculated from a completed bar and applied from the next bar; it
is never assumed to trigger inside the bar that moved it.
"""

from __future__ import annotations


def next_trailing_stop(
    *,
    side: int,
    entry_fill: float,
    current_stop: float | None,
    bar_high: float,
    bar_low: float,
    distance: float,
    activation: float | None,
) -> float | None:
    if side not in (1, -1):
        raise ValueError("side must be 1 or -1")
    if distance <= 0.0:
        raise ValueError("trailing distance must be positive")
    if activation is not None and activation <= 0.0:
        raise ValueError("trailing activation must be positive or None")

    favorable = bar_high if side > 0 else bar_low
    excursion = (favorable - entry_fill) * side
    if activation is not None and excursion < activation:
        return current_stop

    candidate = favorable - side * distance
    if current_stop is None:
        return candidate
    if side > 0:
        return max(current_stop, candidate)
    return min(current_stop, candidate)
