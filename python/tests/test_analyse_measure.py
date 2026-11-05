"""Functional contract for scripts/tester/analyse_measure.py (task B harness).

The harness decides whether an ablation arm is usable, so its arithmetic is
tested against a synthetic journal instead of being trusted by inspection.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "tester" / "analyse_measure.py"

HEADER = (
    "logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,"
    "price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason"
)


def _row(event: str, equity: float, reason: str) -> str:
    return (
        "2024.01.02 10:00:00,2024.01.02 10:00:00,WonderwhalesXAU2ModeEA,1.00,"
        f"ABC,XAUUSDm,SCALP,{event},BUY,2000.0,0.10,2000.0,1990.0,2015.0,"
        f"0.10,{equity},0.0,{reason}"
    )


def _write(path: Path, rows: list[str]) -> Path:
    path.write_text("\n".join([HEADER, *rows]) + "\n", encoding="utf-8")
    return path


def _run(*args: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                          capture_output=True, text=True, check=False)


def test_winrate_expectancy_and_drawdown(tmp_path: Path) -> None:
    journal = _write(tmp_path / "sim_ww2_meas_scalp_is_a.csv", [
        _row("EXIT", 100150.0, "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=150.00|r=1.50"),
        _row("EXIT", 100050.0, "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=-100.00|r=-1.00"),
        _row("EXIT", 100200.0, "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=150.00|r=1.50"),
    ])
    run = _run(journal)
    assert run.returncode == 0, run.stderr
    out = run.stdout
    assert "LABEL: NOT_STRATEGY_RESULT" in out
    assert "trades=3 wins=2 losses=1 flat=0 winrate=66.67%" in out
    assert "net=200.00" in out
    assert "expectancy_usd=66.67" in out
    assert "expectancy_r=0.67" in out
    assert "profit_factor=3.00" in out
    #--- peak 100150 -> trough 100050 is the worst sampled drawdown.
    assert "max_drawdown_pct=0.10" in out
    assert "exit_kinds BROKER_EXIT=3" in out
    assert "r_buckets <=-0.9=1 -0.9..-0.1=0 -0.1..0.1=0 0.1..0.9=0 >=0.9=2" in out
    assert "sample=INSUFFICIENT_SAMPLE" in out
    assert "INSUFFICIENT_SAMPLE" in out.split("SUMMARY", 1)[1]


def test_unknown_r_is_excluded_from_expectancy(tmp_path: Path) -> None:
    journal = _write(tmp_path / "sim_ww2_meas_scalp_is_b.csv", [
        _row("EXIT", 100100.0, "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=100.00|r=1.00"),
        _row("EXIT", 100000.0, "BROKER_EXIT|mode=SCALP|pnl_known=0|pnl=0.00|r=NA"),
    ])
    run = _run(journal)
    assert run.returncode == 0, run.stderr
    assert "r_known=1 r_na=1" in run.stdout
    assert "expectancy_r=1.00" in run.stdout


def test_missing_pnl_is_counted_not_guessed(tmp_path: Path) -> None:
    journal = _write(tmp_path / "sim_ww2_meas_scalp_is_c.csv", [
        _row("EXIT", 100000.0, "BROKER_EXIT|mode=SCALP|pnl_known=0|r=NA"),
    ])
    run = _run(journal)
    assert run.returncode == 0, run.stderr
    assert "pnl_missing=1" in run.stdout
    assert "net=0.00" in run.stdout


def test_directory_discovery_and_telemetry_trail_mix(tmp_path: Path) -> None:
    _write(tmp_path / "sim_ww2_meas_scalp_is_a.csv", [
        _row("EXIT", 100100.0, "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=100.00|r=1.00"),
    ])
    _write(tmp_path / "sim_ww2_meas_scalp_is_b.csv", [
        _row("EXIT", 100000.0, "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=-50.00|r=-0.50"),
    ])
    #--- The telemetry CSV has its own 12-column header, not the journal one.
    (tmp_path / "sim_ww2_meas_scalp_is_b_telemetry.csv").write_text(
        "logged_at,bar_time,ticket,mode,r,sl,trail_reason,ema_fast,ema_slow,"
        "ema200,atr_pct,sar_dir\n"
        "2024.01.02 10:00:00,2024.01.02 10:00:00,1,SCALP,0.00,1990.00,ENTRY,1,2,3,0.5,1\n"
        "2024.01.02 11:00:00,2024.01.02 11:00:00,1,SCALP,1.00,2000.00,BE,1,2,3,0.5,1\n"
        "2024.01.02 12:00:00,2024.01.02 12:00:00,1,SCALP,1.40,2005.00,STRUCTURE,1,2,3,0.5,1\n",
        encoding="utf-8",
    )
    run = _run(tmp_path)
    assert run.returncode == 0, run.stderr
    assert run.stdout.count("MEASURE ") == 2
    assert "trail no_telemetry_file" in run.stdout
    assert "trail BE=1 STRUCTURE=1" in run.stdout


def test_empty_journal_fails_closed(tmp_path: Path) -> None:
    journal = _write(tmp_path / "sim_ww2_meas_scalp_oos_a.csv", [])
    run = _run(journal)
    assert run.returncode == 2
    assert "empty journal" in run.stderr


def test_missing_input_fails_closed(tmp_path: Path) -> None:
    run = _run(tmp_path / "does-not-exist.csv")
    assert run.returncode == 2
    assert "not found" in run.stderr


def test_identical_arms_are_flagged(tmp_path: Path) -> None:
    #--- Regression for 2026-11-05: arms C/D produced byte-identical results
    #--- because the trail trigger was disabled, so trailing never ran.
    for arm in "bcd":
        _write(tmp_path / f"sim_ww2_meas_scalp_is_{arm}.csv", [
            _row("EXIT", 100100.0,
                 "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=100.00|r=1.00"),
            _row("EXIT", 100000.0,
                 "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=-100.00|r=-1.00"),
        ])
    _write(tmp_path / "sim_ww2_meas_scalp_is_a.csv", [
        _row("EXIT", 100050.0,
             "BROKER_EXIT|mode=SCALP|pnl_known=1|pnl=50.00|r=0.50"),
    ])
    run = _run(tmp_path)
    assert run.returncode == 0, run.stderr
    assert "WARNING: identical closed-trade outcome across 3 arms" in run.stdout
    assert "sim_ww2_meas_scalp_is_b" in run.stdout.split("WARNING", 1)[1]
    #--- Distinct outcomes must not be flagged.
    assert "outcome across 1 arm" not in run.stdout
