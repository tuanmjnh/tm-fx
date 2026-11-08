"""Contract for scripts/ww2_parity_check.py (the WW2 parity decision wrapper).

It must never alter inputs, must fail closed when an export is missing or has the
wrong schema, and must refuse to ALLOW_FLIP unless the pre-agreed decision rule is
met (match, zero mismatches, enough signals).
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "ww2_parity_check.py"

HEADER = (
    "bar_open_time,symbol,timeframe,signal_id,side,sar_dir,psar,fast,slow,atr_pct"
)


def _row(index: int, symbol: str = "XAUUSDm", hour_shift: int = 0) -> str:
    #--- A valid BUY row: side and sar_dir must agree, and each bar must be unique.
    minutes = 5 * index
    hour = 9 + minutes // 60 + hour_shift
    stamp = f"2025-01-02T{hour:02d}:{minutes % 60:02d}:00Z"
    price = 2000.0 + index
    return (f"{stamp},{symbol},M5,WW_BUY_SAR_EMA,BUY,1,"
            f"{price - 1.0:.8f},{price:.8f},{price - 2.0:.8f},0.07")


def _write(path: Path, count: int, symbol: str = "XAUUSDm",
           hour_shift: int = 0) -> Path:
    rows = [_row(i, symbol, hour_shift) for i in range(count)]
    path.write_text("\n".join([HEADER, *rows]) + "\n", encoding="utf-8")
    return path


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, check=False)


def test_missing_reference_is_blocked(tmp_path: Path) -> None:
    mql5 = _write(tmp_path / "mql5.csv", 120)
    run = _run("--pine", str(tmp_path / "absent.csv"), "--mql5", str(mql5),
               "--out-dir", str(tmp_path / "out"), "--warmup-bars", "0")
    assert run.returncode == 3
    assert "parity=BLOCKED" in run.stderr
    assert "DECISION: KEEP_BLOCKED" in run.stdout


def test_match_with_enough_signals_allows_the_flip(tmp_path: Path) -> None:
    pine = _write(tmp_path / "pine.csv", 120)
    mql5 = _write(tmp_path / "mql5.csv", 120)
    run = _run("--pine", str(pine), "--mql5", str(mql5), "--out-dir",
               str(tmp_path / "out"), "--warmup-bars", "0",
               "--mql5-offset-minutes", "0", "--min-signals", "100")
    assert run.returncode == 0, run.stderr
    assert "status=match" in run.stdout
    assert "DECISION: ALLOW_FLIP" in run.stdout
    decision = (tmp_path / "out" / "ww2_parity_decision.txt").read_text(encoding="utf-8")
    assert "DECISION: ALLOW_FLIP" in decision
    assert "min_signals=100" in decision


def test_broker_server_offset_is_applied(tmp_path: Path) -> None:
    #--- The Pine export is UTC while the MQL5 log carries broker server time; the
    #--- default --mql5-offset-minutes 180 (Exness GMT+3) must align them.
    pine = _write(tmp_path / "pine.csv", 120)
    mql5 = _write(tmp_path / "mql5.csv", 120, hour_shift=3)
    run = _run("--pine", str(pine), "--mql5", str(mql5), "--out-dir",
               str(tmp_path / "out"), "--warmup-bars", "0", "--min-signals", "100")
    assert run.returncode == 0, run.stdout + run.stderr
    assert "mql5_offset_minutes=180" in run.stdout
    assert "DECISION: ALLOW_FLIP" in run.stdout


def test_match_but_too_few_signals_keeps_the_gate(tmp_path: Path) -> None:
    pine = _write(tmp_path / "pine.csv", 5)
    mql5 = _write(tmp_path / "mql5.csv", 5)
    run = _run("--pine", str(pine), "--mql5", str(mql5), "--out-dir",
               str(tmp_path / "out"), "--warmup-bars", "0",
               "--mql5-offset-minutes", "0", "--min-signals", "100")
    assert run.returncode == 1
    assert "status=match" in run.stdout
    assert "DECISION: KEEP_BLOCKED" in run.stdout
    assert "rows_compared=5 < min_signals=100" in run.stdout


def test_wrong_schema_is_invalid(tmp_path: Path) -> None:
    pine = tmp_path / "pine.csv"
    pine.write_text("bar_open_time,symbol\n2025-01-02T09:00:00Z,XAUUSDm\n",
                    encoding="utf-8")
    mql5 = _write(tmp_path / "mql5.csv", 3)
    run = _run("--pine", str(pine), "--mql5", str(mql5), "--warmup-bars", "0")
    assert run.returncode == 2
    assert "parity=INVALID" in run.stderr
    assert "missing required columns" in run.stderr


def test_symbol_mismatch_warns_about_the_known_trap(tmp_path: Path) -> None:
    pine = _write(tmp_path / "pine.csv", 120, symbol="XAUUSD")
    mql5 = _write(tmp_path / "mql5.csv", 120)
    run = _run("--pine", str(pine), "--mql5", str(mql5), "--out-dir",
               str(tmp_path / "out"), "--warmup-bars", "0",
               "--mql5-offset-minutes", "0")
    assert "WARN: symbol values differ" in run.stdout
    #--- Every row is unmatched, so the gate must stay shut.
    assert run.returncode == 1
    assert "DECISION: KEEP_BLOCKED" in run.stdout
