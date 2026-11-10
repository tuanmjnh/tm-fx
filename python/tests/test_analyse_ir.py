"""Arithmetic checks for the T2.2 additions to scripts/tester/analyse_ir.py.

Uses a synthetic 18-column journal with four known trades so the break-even
winrate, the gross / doubled-spread model and the seeded bootstrap CI can be
verified exactly.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "tester" / "analyse_ir.py"

HEADER = ("logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,"
          "side,price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason")


def _load():
    spec = importlib.util.spec_from_file_location("analyse_ir", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _entry(bar_time: str, side: str, price: float, sl: float) -> str:
    return (f"2026-01-01 00:00:00,{bar_time},InfiniteRunnerXAUV2DemoEA,2.00,ABCDEF,"
            f"XAUUSDm,PERIOD_M5,ENTRY,{side},{price:.8f},0.0100,{price:.8f},"
            f"{sl:.8f},0.0,0.0100,10000.00,0.0,legacy|ok")


def _exit(bar_time: str, side: str, pnl: float) -> str:
    return (f"2026-01-01 00:00:00,{bar_time},InfiniteRunnerXAUV2DemoEA,2.00,ABCDEF,"
            f"XAUUSDm,PERIOD_M5,EXIT,{side},0.0,0.0100,0.0,0.0,0.0,0.0,10000.00,0.0,"
            f"closed|history|pnl={pnl:.2f}|streak=0|cooldown_until=1970.01.01 00:00")


def _write(tmp_path: Path) -> Path:
    rows = [HEADER]
    rows += [_entry("2020.01.02 00:00:00", "BUY", 2000.0, 1995.0), _exit("2020.01.02 01:00:00", "BUY", 2.0)]
    rows += [_entry("2020.06.02 00:00:00", "SELL", 2000.0, 2005.0), _exit("2020.06.02 01:00:00", "SELL", -5.0)]
    rows += [_entry("2021.01.02 00:00:00", "BUY", 2000.0, 1995.0), _exit("2021.01.02 01:00:00", "BUY", 10.0)]
    rows += [_entry("2021.06.02 00:00:00", "SELL", 2000.0, 2005.0), _exit("2021.06.02 01:00:00", "SELL", -5.0)]
    path = tmp_path / "sim_test.csv"
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return path


def test_break_even_winrate(tmp_path: Path) -> None:
    r = _load().analyse(_write(tmp_path), spread_price=0.19, ci_samples=200, ci_seed=1)
    assert r["winrate"] == pytest.approx(50.0)
    #--- p* = L / (W + L) = 5 / (6 + 5)
    assert r["break_even_winrate"] == pytest.approx(100.0 * 5.0 / 11.0)
    assert r["winrate_gap_pp"] == pytest.approx(50.0 - 100.0 * 5.0 / 11.0)


def test_spread_model(tmp_path: Path) -> None:
    r = _load().analyse(_write(tmp_path), spread_price=0.19, ci_samples=200, ci_seed=1)
    assert r["net"] == pytest.approx(2.0)
    assert r["spread_cost_total"] == pytest.approx(4 * 0.19)
    assert r["gross"] == pytest.approx(2.0 + 4 * 0.19)
    assert r["net_spread_x2"] == pytest.approx(2.0 - 4 * 0.19)


def test_expectancy_and_ci(tmp_path: Path) -> None:
    r = _load().analyse(_write(tmp_path), spread_price=0.19, ci_samples=400, ci_seed=7)
    assert r["expectancy_usd"] == pytest.approx(0.5)
    assert r["expectancy_r"] == pytest.approx(2.0 / (4 * 5.0))
    lo, hi = r["expectancy_usd_ci95"]
    assert lo <= r["expectancy_usd"] <= hi


def test_ci_is_seed_deterministic(tmp_path: Path) -> None:
    path = _write(tmp_path)
    a = _load().analyse(path, ci_samples=300, ci_seed=99)
    b = _load().analyse(path, ci_samples=300, ci_seed=99)
    assert a["expectancy_usd_ci95"] == b["expectancy_usd_ci95"]
    assert a["expectancy_r_ci95"] == b["expectancy_r_ci95"]


def test_doubled_spread_raises_the_cost(tmp_path: Path) -> None:
    path = _write(tmp_path)
    base = _load().analyse(path, spread_price=0.19, ci_samples=100, ci_seed=1)
    x2 = _load().analyse(path, spread_price=0.38, ci_samples=100, ci_seed=1)
    assert x2["net_spread_x2"] == pytest.approx(base["net_spread_x2"] - 4 * 0.19)
