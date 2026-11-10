"""Contract for scripts/tester/ir_breakdown.py (experiment E1 decomposition).

Uses a synthetic 18-column journal with known P&L so the side/year/tail split is
checked arithmetically. Cost per trade = spread_price * volume * contract.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "tester" / "ir_breakdown.py"

HEADER = ("logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,"
          "side,price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason")


def _load():
    spec = importlib.util.spec_from_file_location("ir_breakdown", SCRIPT)
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
    #--- A BUY 2020 +2, B SELL 2020 -5, C BUY 2021 +10, D SELL 2021 -5. Risk $5 each.
    rows += [_entry("2020.01.02 00:00:00", "BUY", 2000.0, 1995.0), _exit("2020.01.02 01:00:00", "BUY", 2.0)]
    rows += [_entry("2020.06.02 00:00:00", "SELL", 2000.0, 2005.0), _exit("2020.06.02 01:00:00", "SELL", -5.0)]
    rows += [_entry("2021.01.02 00:00:00", "BUY", 2000.0, 1995.0), _exit("2021.01.02 01:00:00", "BUY", 10.0)]
    rows += [_entry("2021.06.02 00:00:00", "SELL", 2000.0, 2005.0), _exit("2021.06.02 01:00:00", "SELL", -5.0)]
    path = tmp_path / "sim_test.csv"
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return path


def test_overall_and_gross(tmp_path: Path) -> None:
    r = _load().breakdown(_write(tmp_path), spread_price=0.19, tail_frac=0.005)
    o = r["overall"]
    assert o["n"] == 4
    assert o["net"] == pytest.approx(2.0)
    #--- gross = net + 4 * (0.19 * 0.01 * 100) = 2.0 + 0.76
    assert o["gross"] == pytest.approx(2.76)
    assert o["gross_per_trade"] == pytest.approx(0.69)
    assert o["gross_r"] == pytest.approx(2.76 / 20.0)
    assert o["net_r"] == pytest.approx(2.0 / 20.0)


def test_by_side(tmp_path: Path) -> None:
    r = _load().breakdown(_write(tmp_path), spread_price=0.19, tail_frac=0.005)
    buy, sell = r["by_side"]["BUY"], r["by_side"]["SELL"]
    assert (buy["n"], buy["net"]) == (2, pytest.approx(12.0))
    assert buy["gross"] == pytest.approx(12.38)
    assert (sell["n"], sell["net"]) == (2, pytest.approx(-10.0))
    assert sell["gross"] == pytest.approx(-9.62)


def test_by_year(tmp_path: Path) -> None:
    r = _load().breakdown(_write(tmp_path), spread_price=0.19, tail_frac=0.005)
    assert r["by_year"]["2020"]["net"] == pytest.approx(-3.0)
    assert r["by_year"]["2021"]["net"] == pytest.approx(5.0)
    assert r["by_year"]["2021"]["gross"] == pytest.approx(5.38)


def test_tail_drops_the_best_trade(tmp_path: Path) -> None:
    r = _load().breakdown(_write(tmp_path), spread_price=0.19, tail_frac=0.25)
    t = r["tail"]
    assert t["drop_n"] == 1
    assert t["drop_net"] == pytest.approx(10.0)
    assert t["kept"]["n"] == 3
    assert t["kept"]["net"] == pytest.approx(-8.0)
    assert t["kept"]["gross"] == pytest.approx(-7.43)


def test_spread_scales_the_gross(tmp_path: Path) -> None:
    #--- Doubling the implied spread doubles the reconstructed gross premium.
    path = _write(tmp_path)
    base = _load().breakdown(path, spread_price=0.19, tail_frac=0.005)
    doubled = _load().breakdown(path, spread_price=0.38, tail_frac=0.005)
    assert doubled["overall"]["gross"] == pytest.approx(
        base["overall"]["net"] + 2 * (base["overall"]["gross"] - base["overall"]["net"]))
