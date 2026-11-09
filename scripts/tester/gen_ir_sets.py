"""Generate Strategy Tester inputs for InfiniteRunnerXAUV2DemoEA (ADR 0005).

Writes, from the single source of truth configs/demo/infinite_runner_demo.json:
  reports/build/tester-sets/<scenario>.set   (staged into MQL5\\Profiles\\Tester)
  reports/build/tester-run/<scenario>.ini

Scenarios:
  infinite_runner_demo_exec      shipped preset, 2026 window (infrastructure run).
  infinite_runner_legacy_exec    cooldown/risk-lot variant of the shipped preset.
  infinite_runner_fixcheck       proof that the loss-streak fix (U1) lets the bot
                                 trade the SAME window the old build deadlocked on.
  infinite_runner_long_baseline  2018-2026, shipped inputs (halts on 8% DD).
  infinite_runner_long_base_nolock  2018-2026, daily/DD halts off (reference).
  infinite_runner_long_exit_run  base, step trailing OFF (U2: let winners run).
  infinite_runner_long_fixedrr   base, no trail + TP at 1R (U3: raw entry edge).
  infinite_runner_long_fixedrr15 base, no trail + TP at 1.5R (U3 cross-check).
  infinite_runner_long_fixedrr_clean  as fixedrr but every guard off.
  infinite_runner_long_mtf       base, InpDirectionMode=1 (IR_DIR_EMA_MTF).

Every run here is an operational/measurement run, NOT a strategy result (see
docs/30-research/infinite-runner-study.md).

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\gen_ir_sets.py
  .venv\\Scripts\\python.exe scripts\\tester\\gen_ir_sets.py --terminal "<data folder>"

The .set is a derived artefact: never edit it by hand, edit the JSON and re-run.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESET = ROOT / "configs/demo/infinite_runner_demo.json"
OUT_SETS = ROOT / "reports/build/tester-sets"
OUT_INI = ROOT / "reports/build/tester-run"

#--- Long-window measurement runs share these: run the FULL window by turning the
#--- permanent daily/drawdown halts off (the shipped 8% DD lock ends the run after
#--- ~2.5 years). InpResetStateOnInit=true so a stale state cannot adopt a position.
LONG = {"InpMaxDailyLossPct": 0.0, "InpMaxDrawdownPct": 0.0,
        "InpResetStateOnInit": True, "InpDirectionMode": 0}

# name, period, from_date, to_date, deposit, report_name, overrides
SCENARIOS = (
    ("infinite_runner_demo_exec", "M5", "2026.01.05", "2026.10.01", 10000,
     "tester_ir_demo_exec",
     {"InpLogFile": "sim_ir_demo_exec.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpResetStateOnInit": False, "InpDirectionMode": 0}),
    ("infinite_runner_legacy_exec", "M5", "2026.10.20", "2026.10.30", 10000,
     "tester_ir_legacy_exec",
     {"InpLogFile": "sim_ir_demo_exec.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpResetStateOnInit": False, "InpDirectionMode": 0,
      "InpCooldownMinutes": 30, "InpMinBarsBetweenEntries": 3,
      "InpLotMode": 1, "InpBreakEvenTriggerR": 1.0}),
    ("infinite_runner_fixcheck", "M5", "2026.01.05", "2026.10.01", 10000,
     "tester_infinite_runner_fixcheck",
     {"InpLogFile": "sim_ir_fixcheck.csv",
      "InpStateFile": "infinite_runner_fixcheck_state.csv",
      "InpResetStateOnInit": True, "InpDirectionMode": 0}),
    ("infinite_runner_long_baseline", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_baseline",
     {"InpLogFile": "sim_ir_long_baseline.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpResetStateOnInit": True, "InpDirectionMode": 0}),
    ("infinite_runner_long_base_nolock", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_base_nolock",
     {"InpLogFile": "sim_ir_long_base_nolock.csv",
      "InpStateFile": "infinite_runner_demo_state.csv", **LONG}),
    ("infinite_runner_long_exit_run", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_exit_run",
     {"InpLogFile": "sim_ir_long_exit_run.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpEnableStepTrailing": False, **LONG}),
    ("infinite_runner_long_fixedrr", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_fixedrr",
     {"InpLogFile": "sim_ir_long_fixedrr.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpEnableStepTrailing": False, "InpTrailStartPts": 999999999,
      "InpSafetyTpPoints": 5000, **LONG}),
    ("infinite_runner_long_fixedrr15", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_fixedrr15",
     {"InpLogFile": "sim_ir_long_fixedrr15.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpEnableStepTrailing": False, "InpTrailStartPts": 999999999,
      "InpSafetyTpPoints": 7500, **LONG}),
    ("infinite_runner_long_fixedrr_clean", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_fixedrr_clean",
     {"InpLogFile": "sim_ir_long_fixedrr_clean.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      "InpEnableStepTrailing": False, "InpTrailStartPts": 999999999,
      "InpSafetyTpPoints": 5000, "InpMaxConsecutiveLosses": 0,
      "InpHaltOnBreach": False, **LONG}),
    ("infinite_runner_long_mtf", "M5", "2018.01.01", "2026.10.01", 10000,
     "tester_infinite_runner_long_mtf",
     {"InpLogFile": "sim_ir_long_mtf.csv",
      "InpStateFile": "infinite_runner_demo_state.csv",
      **LONG, "InpDirectionMode": 1}),
)


def render(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def note_for(name: str) -> list[str]:
    if name.startswith("infinite_runner_long_"):
        return [
            "; Long-window measurement run (2018-2026): NOT a strategy result.",
        ]
    if name == "infinite_runner_fixcheck":
        return [
            "; U1 fixcheck: the old build deadlocked here after 3 losses.",
            "; Operational evidence, NOT a strategy result.",
        ]
    return [
        "; Operational run (Strategy Tester = virtual demo account).",
        "; NOT a strategy result.",
    ]


def detect_terminal_data_dir() -> Path | None:
    base = Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal"
    if not base.is_dir():
        return None
    for entry in sorted(base.iterdir()):
        if (entry / "MQL5" / "Experts").is_dir():
            return entry
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", default="", help="MT5 data folder (contains MQL5\\)")
    args = parser.parse_args()

    preset = json.loads(PRESET.read_text(encoding="utf-8"))
    base = dict(preset["inputs"])

    terminal = Path(args.terminal) if args.terminal else detect_terminal_data_dir()
    tester_profiles = (terminal / "MQL5" / "Profiles" / "Tester") if terminal else None
    if tester_profiles:
        tester_profiles.mkdir(parents=True, exist_ok=True)

    OUT_SETS.mkdir(parents=True, exist_ok=True)
    OUT_INI.mkdir(parents=True, exist_ok=True)

    for name, period, from_date, to_date, deposit, report, overrides in SCENARIOS:
        values = dict(base)
        values.update(overrides)
        assert values["InpSafetyTpPoints"] > 0.0, "mandatory TP"
        assert values["InpMaxPositions"] == 1, "single position"
        if values["InpMaxConsecutiveLosses"] > 0:
            assert values["InpLossStreakCooldownMinutes"] > 0, "loss streak needs a cooldown"

        lines = [
            f"; {name} - InfiniteRunnerXAUV2DemoEA - XAUUSDm {period}",
            *note_for(name),
            "[TesterInputs]",
        ]
        lines += [f"{k}={render(v)}" for k, v in values.items()]
        (OUT_SETS / f"{name}.set").write_text("\n".join(lines) + "\n",
                                              encoding="utf-8", newline="\n")

        ini = "\n".join([
            "[Common]", "", "[Tester]",
            f"Expert={preset['ea']}",
            f"ExpertParameters={name}.set",
            "Symbol=XAUUSDm", f"Period={period}", "Model=1",
            f"FromDate={from_date}", f"ToDate={to_date}",
            f"Deposit={deposit}", "Currency=USD", "Leverage=1:100",
            "Optimization=0", "Visual=0", "ShutdownTerminal=1",
            "ReplaceReport=1", f"Report={report}", "",
        ])
        (OUT_INI / f"{name}.ini").write_text(ini, encoding="utf-8", newline="\n")

        if tester_profiles:
            try:
                shutil.copyfile(OUT_SETS / f"{name}.set", tester_profiles / f"{name}.set")
            except PermissionError:
                print(f"STAGE_BLOCKED {tester_profiles / f'{name}.set'} - copy manually")
        print(f"WROTE {name} report={report}")

    print(f"INPUTS={len(base)} SCENARIOS={len(SCENARIOS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
