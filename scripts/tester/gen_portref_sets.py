"""Generate Strategy Tester inputs for the cross-implementation port check.

This is NOT a parity run: it prepares the MQL5 side of a check that compares the
``PinePort\\Wonderwhales`` indicator against an independent Python port of the
same documented spec. Only an export produced by TradingView itself can
establish Pine parity.

Writes, under ``reports/build/``:
  tester-sets/<scenario>.set   (staged into MQL5\\Profiles\\Tester)
  tester-run/<scenario>.ini

Scenarios (symbol XAUUSDm, one year, mode SAR_EMA):
  portref_dump_<tf>   WonderwhalesDumpTesterEA -> sim_portref_dump_<tf>.csv

The EA is read-only and tester-only (it refuses to run on a chart) and writes the
bar plus the indicator buffers for every closed bar, so the Python port can be
compared bar by bar.

Why not PineSignalLabEA: it requires ``BarsCalculated(handle) >= Bars()``, but
inside the tester ``Bars()`` also counts the history the terminal preloads before
FromDate while the indicator only calculates the tested range, so the logger
never emits a row (measured 2026-11-06: calculated=71009 vs rates_total=141805,
signals=0). The dump EA reads shift=1 per closed bar instead and does not depend
on that equality.

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\gen_portref_sets.py
  .venv\\Scripts\\python.exe scripts\\tester\\gen_portref_sets.py --terminal "<data folder>"
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_SETS = REPO_ROOT / "reports" / "build" / "tester-sets"
OUT_INI = REPO_ROOT / "reports" / "build" / "tester-run"

SYMBOL = "XAUUSDm"
FROM_DATE = "2025.01.01"
TO_DATE = "2026.01.01"
DEPOSIT = 10000
#--- Bars skipped on both sides when comparing (indicator warm-up).
WARMUP_BARS = 300

#--- The 2-mode EA uses mode SAR_EMA on M15/M5/M1 for Scalp, so all three are
#--- validated here.
TIMEFRAMES = ("M1", "M5", "M15")

#--- The dump EA must create the indicator with the same inputs the 2-mode EA
#--- and the documented parity runbook use.
DUMP_INPUTS = {
    "InpMode": 2,               # WW_MODE_SAR_EMA
    "InpPsarEngine": 0,         # WW_PSAR_ISAR (shipped engine)
    "InpPsarStart": 0.02,
    "InpPsarInc": 0.02,
    "InpPsarMax": 0.20,
    "InpFastEma": 20,
    "InpSlowEma": 50,
    "InpEma200": 200,
    "InpAtrLen": 14,
    "InpMinAtrPct": 0.5,
    "InpVolMaLen": 20,
    "InpRsiLen": 14,
    "InpBbLen": 20,
    "InpBbMult": 2.0,
}


def render(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def detect_terminal_data_dir() -> Path | None:
    base = Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal"
    if not base.is_dir():
        return None
    for entry in sorted(base.iterdir()):
        if (entry / "MQL5" / "Experts").is_dir():
            return entry
    return None


def scenarios() -> list[tuple[str, str, str, dict]]:
    out: list[tuple[str, str, str, dict]] = []
    for tf in TIMEFRAMES:
        name = f"portref_dump_{tf.lower()}"
        inputs = dict(DUMP_INPUTS)
        inputs["InpOutputFile"] = f"sim_{name}.csv"
        out.append((name, "WonderwhalesDumpTesterEA", tf, inputs))

    #--- Same run on M5 but with the self-implemented PSAR, so the port check can
    #--- confirm the indicator implements that recurrence consistently.
    name = "portref_dump_m5_builtin"
    inputs = dict(DUMP_INPUTS)
    inputs["InpPsarEngine"] = 1
    inputs["InpOutputFile"] = f"sim_{name}.csv"
    out.append((name, "WonderwhalesDumpTesterEA", "M5", inputs))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", default="", help="MT5 data folder (contains MQL5\\)")
    args = parser.parse_args()

    terminal = Path(args.terminal) if args.terminal else detect_terminal_data_dir()
    tester_profiles = (terminal / "MQL5" / "Profiles" / "Tester") if terminal else None
    if tester_profiles:
        tester_profiles.mkdir(parents=True, exist_ok=True)
    else:
        print("NOTE: no MT5 data folder; .set files written but not staged")

    OUT_SETS.mkdir(parents=True, exist_ok=True)
    OUT_INI.mkdir(parents=True, exist_ok=True)

    for name, expert, period, inputs in scenarios():
        lines = [
            f"; {name} - {expert} - {SYMBOL} {period}",
            "; Cross-implementation port check: NOT a parity run.",
            "; Read-only; no orders. Runs inside the Strategy Tester only.",
            "[TesterInputs]",
        ]
        lines += [f"{key}={render(value)}" for key, value in inputs.items()]
        (OUT_SETS / f"{name}.set").write_text("\n".join(lines) + "\n",
                                              encoding="utf-8", newline="\n")

        ini = "\n".join([
            "[Common]", "", "[Tester]",
            f"Expert={expert}",
            f"ExpertParameters={name}.set",
            f"Symbol={SYMBOL}", f"Period={period}", "Model=1",
            f"FromDate={FROM_DATE}", f"ToDate={TO_DATE}",
            f"Deposit={DEPOSIT}", "Currency=USD", "Leverage=1:100",
            "Optimization=0", "Visual=0", "ShutdownTerminal=1",
            "ReplaceReport=1", f"Report=tester_{name}", "",
        ])
        (OUT_INI / f"{name}.ini").write_text(ini, encoding="utf-8", newline="\n")

        staged = ""
        if tester_profiles:
            target = tester_profiles / f"{name}.set"
            try:
                target.write_text((OUT_SETS / f"{name}.set").read_text(encoding="utf-8"),
                                  encoding="utf-8", newline="\n")
                staged = " staged"
            except OSError:
                staged = " STAGE_BLOCKED"
        print(f"WROTE {name} expert={expert} period={period}{staged}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
