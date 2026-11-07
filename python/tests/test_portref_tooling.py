"""Contracts for the cross-implementation port-check tooling.

The reference builder must fail closed on bad input, and the scenario generator
must produce the MQL5 side that matches the Python side (same symbol, mode and
timeframes). None of this is parity evidence.
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
BUILDER = REPO_ROOT / "scripts" / "build_wonderwhales_reference.py"
GENERATOR = REPO_ROOT / "scripts" / "tester" / "gen_portref_sets.py"

BARS_HEADER = "bar_open_time,symbol,timeframe,open,high,low,close,tick_volume"


def _load_generator():
    spec = importlib.util.spec_from_file_location("gen_portref_sets", GENERATOR)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _write_bars(path: Path, prices: list[float]) -> Path:
    times = []
    start = 9 * 3600  # 09:00:00
    for index in range(len(prices)):
        total = start + index * 300
        times.append(f"2025.01.02 {total // 3600:02d}:{(total % 3600) // 60:02d}:00")
    lines = [BARS_HEADER]
    for stamp, price in zip(times, prices):
        lines.append(
            f"{stamp},XAUUSDm,M5,{price:.2f},{price + 0.5:.2f},"
            f"{price - 0.5:.2f},{price:.2f},{100 + len(lines)}"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(BUILDER), *args],
                          capture_output=True, text=True, check=False)


def test_builder_writes_the_comparator_schema(tmp_path: Path) -> None:
    prices = [float(p) for p in
              np.concatenate([np.linspace(10, 20, 60), np.linspace(20, 10, 60)])]
    bars = _write_bars(tmp_path / "bars.csv", prices)
    out = tmp_path / "ref.csv"
    run = _run("--bars", str(bars), "--out", str(out), "--mode", "sar")
    assert run.returncode == 0, run.stderr
    assert "CROSS_IMPLEMENTATION" in run.stdout

    text = out.read_text(encoding="utf-8")
    header = text.splitlines()[0]
    assert header == (
        "bar_open_time,symbol,timeframe,signal_id,side,sar_dir,psar,fast,"
        "slow,atr_pct"
    )
    rows = text.strip().splitlines()[1:]
    assert rows, "expected at least one signal row"
    for row in rows:
        fields = row.split(",")
        assert fields[1] == "XAUUSDm" and fields[2] == "M5"
        assert fields[3].startswith("WW_BUY_SAR_FLIP") or \
            fields[3] == "WW_SELL_SAR_FLIP"
        assert fields[4] in ("BUY", "SELL")
        assert (fields[8] == "1") == (fields[4] == "BUY")


def test_builder_missing_bars_fails_closed(tmp_path: Path) -> None:
    run = _run("--bars", str(tmp_path / "nope.csv"), "--out",
               str(tmp_path / "ref.csv"))
    assert run.returncode == 2
    assert "not a file" in run.stderr


def test_builder_rejects_bars_without_columns(tmp_path: Path) -> None:
    bars = tmp_path / "bars.csv"
    bars.write_text("bar_open_time,symbol\n2025.01.02 09:00:00,XAUUSDm\n",
                    encoding="utf-8")
    run = _run("--bars", str(bars), "--out", str(tmp_path / "ref.csv"))
    assert run.returncode == 2
    assert "missing columns" in run.stderr


def test_generator_covers_three_timeframes_and_matches_the_python_side() -> None:
    module = _load_generator()
    scenarios = module.scenarios()
    names = [name for name, _e, _p, _i in scenarios]
    assert names == [
        "portref_dump_m1", "portref_dump_m5", "portref_dump_m15",
        "portref_dump_m1_builtin", "portref_dump_m5_builtin",
        "portref_dump_m15_builtin",
    ]
    for name, expert, period, inputs in scenarios:
        assert name.startswith("portref_dump_")
        assert period in ("M1", "M5", "M15")
        assert inputs["InpOutputFile"] == f"sim_{name}.csv"
        assert expert == "WonderwhalesDumpTesterEA"
        #--- Must mirror the 2-mode EA: SAR + EMA trend filter.
        assert inputs["InpMode"] == 2
        assert inputs["InpFastEma"] == 20 and inputs["InpSlowEma"] == 50
    #--- Only the *_builtin runs switch the PSAR engine away from the shipped one.
    engines = {name: inputs["InpPsarEngine"] for name, _e, _p, inputs in scenarios}
    assert engines["portref_dump_m5"] == 0
    for tf in ("m1", "m5", "m15"):
        assert engines[f"portref_dump_{tf}_builtin"] == 1


def test_generator_range_and_symbol_are_locked() -> None:
    module = _load_generator()
    assert module.SYMBOL == "XAUUSDm"
    assert module.FROM_DATE < module.TO_DATE
    assert module.DEPOSIT > 0


def test_every_generated_set_has_a_unique_output_file() -> None:
    module = _load_generator()
    outputs = [inputs["InpOutputFile"] for _n, _e, _p, inputs
               in module.scenarios()]
    assert len(outputs) == len(set(outputs))


#--- Per-bar comparator ---------------------------------------------------

BAR_COMPARATOR = REPO_ROOT / "scripts" / "compare_wonderwhales_bars.py"
DUMP_HEADER = (
    "bar_open_time,symbol,timeframe,open,high,low,close,tick_volume,psar,"
    "sar_dir,buy_signal,sell_signal,fast,slow,atr_pct,blocked_buy,blocked_sell"
)


def _run_bars(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(BAR_COMPARATOR), *args],
                          capture_output=True, text=True, check=False)


def _synthetic_dump(path: Path, prices: list[float]) -> dict:
    """Write a dump whose MQL5 columns come from the Python port itself."""
    from mt5_ea_ai_lab.signals.wonderwhales import (
        MODE_SAR_EMA,
        WonderwhalesConfig,
        generate_bars,
    )

    times = pd.date_range("2025-01-02 09:00", periods=len(prices), freq="5min")
    bars = pd.DataFrame({
        "bar_open_time": [t.strftime("%Y.%m.%d %H:%M:%S") for t in times],
        "open": prices,
        "high": [p + 0.5 for p in prices],
        "low": [p - 0.5 for p in prices],
        "close": prices,
        "tick_volume": [100 + i for i in range(len(prices))],
    })
    evaluated = generate_bars(bars, WonderwhalesConfig(mode=MODE_SAR_EMA))
    lines = [DUMP_HEADER]
    for index, row in evaluated.iterrows():
        price = prices[index]
        lines.append(
            f"{bars['bar_open_time'].iloc[index]},XAUUSDm,M5,{price:.5f},"
            f"{price + 0.5:.5f},{price - 0.5:.5f},{price:.5f},{100 + index},"
            f"{row['psar'] if np.isfinite(row['psar']) else ''},"
            f"{row['sar_dir']},{int(row['signal_buy'])},{int(row['signal_sell'])},"
            f"{row['fast'] if np.isfinite(row['fast']) else ''},"
            f"{row['slow'] if np.isfinite(row['slow']) else ''},"
            f"{row['atr_pct']},{int(row['blocked_buy'])},{int(row['blocked_sell'])}"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {"bars": len(bars)}


def test_bars_comparator_matches_its_own_reference(tmp_path: Path) -> None:
    prices = [float(p) for p in
              np.concatenate([np.linspace(10, 20, 80), np.linspace(20, 10, 80)])]
    dump = tmp_path / "dump.csv"
    _synthetic_dump(dump, prices)
    run = _run_bars("--dump", str(dump), "--out-dir", str(tmp_path / "out"),
                    "--warmup-bars", "10")
    assert run.returncode == 0, run.stderr
    assert "CROSS_IMPLEMENTATION" in run.stdout
    assert "NOT Pine parity" in run.stdout
    assert json.loads(
        (tmp_path / "out" / "port_check_M5.json").read_text(encoding="utf-8")
    )["exact_match"]["sar_dir"]["match_rate"] == 1.0


def test_bars_comparator_flags_a_perturbed_value(tmp_path: Path) -> None:
    prices = [float(p) for p in
              np.concatenate([np.linspace(10, 20, 80), np.linspace(20, 10, 80)])]
    dump = tmp_path / "dump.csv"
    _synthetic_dump(dump, prices)
    text = dump.read_text(encoding="utf-8").splitlines()
    header = text[0].split(",")
    dir_index = header.index("sar_dir")
    fields = text[40].split(",")
    fields[dir_index] = "-1" if fields[dir_index] == "1" else "1"
    text[40] = ",".join(fields)
    dump.write_text("\n".join(text) + "\n", encoding="utf-8")
    run = _run_bars("--dump", str(dump), "--out-dir", str(tmp_path / "out"),
                    "--warmup-bars", "10")
    assert run.returncode == 0, run.stderr
    report = json.loads(
        (tmp_path / "out" / "port_check_M5.json").read_text(encoding="utf-8")
    )
    assert report["exact_match"]["sar_dir"]["match_rate"] < 1.0
    assert report["exact_match"]["sar_dir"]["first_mismatches"]


def test_bars_comparator_missing_file_fails_closed(tmp_path: Path) -> None:
    run = _run_bars("--dump", str(tmp_path / "nope.csv"))
    assert run.returncode == 2
    assert "not a file" in run.stderr
