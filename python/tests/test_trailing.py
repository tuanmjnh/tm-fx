from __future__ import annotations

import pytest

from mt5_ea_ai_lab.backtest.trailing import next_trailing_stop


def update(
    *,
    side: int = 1,
    entry_fill: float = 1.10,
    current_stop: float | None = None,
    bar_high: float = 1.12,
    bar_low: float = 1.09,
    distance: float = 0.001,
    activation: float | None = None,
) -> float | None:
    return next_trailing_stop(
        side=side,
        entry_fill=entry_fill,
        current_stop=current_stop,
        bar_high=bar_high,
        bar_low=bar_low,
        distance=distance,
        activation=activation,
    )


def test_long_stop_trails_below_the_bar_high() -> None:
    assert update() == pytest.approx(1.119)


def test_long_stop_never_moves_down() -> None:
    assert update(current_stop=1.115, bar_high=1.11) == pytest.approx(1.115)
    assert update(current_stop=1.115, bar_high=1.12) == pytest.approx(1.119)


def test_short_stop_trails_above_the_bar_low() -> None:
    assert update(side=-1, entry_fill=1.10, bar_high=1.11, bar_low=1.08) == pytest.approx(
        1.081
    )


def test_short_stop_never_moves_up() -> None:
    assert update(
        side=-1, current_stop=1.085, bar_high=1.11, bar_low=1.09
    ) == pytest.approx(1.085)
    assert update(
        side=-1, current_stop=1.085, bar_high=1.11, bar_low=1.08
    ) == pytest.approx(1.081)


def test_activation_delays_the_first_move() -> None:
    assert update(activation=0.02, bar_high=1.105) is None
    assert update(activation=0.02, bar_high=1.12) == pytest.approx(1.119)


def test_activation_keeps_the_existing_stop_until_reached() -> None:
    assert update(current_stop=1.09, activation=0.02, bar_high=1.105) == pytest.approx(
        1.09
    )


def test_activation_exact_excursion_allows_the_move() -> None:
    assert update(activation=0.01, bar_high=1.11) == pytest.approx(1.109)


def test_invalid_parameters_are_rejected() -> None:
    with pytest.raises(ValueError, match="side"):
        update(side=0)
    with pytest.raises(ValueError, match="distance"):
        update(distance=0.0)
    with pytest.raises(ValueError, match="activation"):
        update(activation=0.0)
