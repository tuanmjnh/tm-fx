"""Independent arithmetic cross-check for the DCA basket vectors D16-D19.

The MQL5 vectors in ``mt5/Scripts/SimCoreTests.mq5`` assert the numbers below
from :class:`CSimPortfolio`; this module recomputes them from scratch with
plain Python so a change in either side breaks a test. Simulation only: no
broker, account or order API is involved.

Scenario (``docs/reference/simulation.md`` section 5): BUY 0.10 @ 1.1000 and 0.15 @ 1.0700,
average entry 1.082, exposure 0.25, target 1.112 (+0.03), stop 1.032 (-0.05).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TESTS = REPO_ROOT / "mt5" / "Scripts" / "SimCoreTests.mq5"


@dataclass(frozen=True)
class Fill:
    price: float
    volume: float
    commission: float = 0.0


FILLS = (Fill(1.1000, 0.10), Fill(1.0700, 0.15))


def _exposure(fills: tuple[Fill, ...]) -> float:
    return sum(fill.volume for fill in fills)


def _average_entry(fills: tuple[Fill, ...]) -> float:
    return sum(fill.price * fill.volume for fill in fills) / _exposure(fills)


def _gross_pnl(fills: tuple[Fill, ...], exit_price: float) -> float:
    return sum((exit_price - fill.price) * fill.volume for fill in fills)


def _net_realized(
    fills: tuple[Fill, ...], exit_price: float, exit_commission: float
) -> float:
    entry_commissions = sum(fill.commission for fill in fills)
    return _gross_pnl(fills, exit_price) - exit_commission - entry_commissions


def test_average_entry_and_exposure_match_vector_d16() -> None:
    assert _exposure(FILLS) == pytest.approx(0.25)
    assert _average_entry(FILLS) == pytest.approx(1.082)


def test_target_and_stop_pnl_match_vectors_d17_and_d19() -> None:
    assert _gross_pnl(FILLS, 1.112) == pytest.approx(0.0075)
    assert _gross_pnl(FILLS, 1.032) == pytest.approx(-0.0125)


def test_commission_reduces_realized_match_vector_d18() -> None:
    fills = (Fill(1.1000, 0.10, 0.05), Fill(1.0700, 0.15, 0.075))
    exit_commission = 0.125  # 0.5 per volume on 0.25 volume
    assert _gross_pnl(fills, 1.112) - exit_commission == pytest.approx(-0.1175)
    assert _net_realized(fills, 1.112, exit_commission) == pytest.approx(-0.2425)


def test_mql5_vectors_assert_the_same_numbers() -> None:
    text = TESTS.read_text(encoding="utf-8")
    for literal in (
        "1.082",
        "1.112",
        "1.032",
        "0.0075",
        "-0.0125",
        "-0.1175",
        "-0.2425",
    ):
        assert literal in text, f"missing DCA vector literal {literal}"
