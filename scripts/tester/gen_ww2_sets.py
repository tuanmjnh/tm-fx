"""Generate Strategy Tester inputs for WonderwhalesXAU2ModeEA (ADR 0009).

Writes, from the single source of truth configs/demo/wonderwhales_xau_2mode_demo.json:
  reports/build/tester-sets/<scenario>.set   (staged into MQL5\\Profiles\\Tester)
  reports/build/tester-run/<scenario>.ini

Scenarios:
  ww2_scalp_parity_on  parity gate ON  -> proves entries are blocked (parity_blocked).
  ww2_scalp_demo_exec  parity OFF      -> proves the ExecBroker order path (infrastructure only).
  ww2_swing_demo_exec  parity OFF      -> same, Swing mode (starts 2018 so W1/D1 EMA200 has history).
  ww2_scalp_census     parity ON, InpDebug ON -> per-bar signal census, zero orders.
  ww2_meas_scalp_<window>_<arm>  8 measurement runs: in/out of sample x ablation arm A..D.
  ww2_meas_scalp_<window>_gate_<w>  4 trigger-window runs: in/out of sample x trigger window.
  ww2_meas_scalp_<window>_setup_<s> 4 setup-window runs: in/out of sample x setup window.
  ww2_meas_scalp_<window>_combo_<c> 4 combination runs: trigger 5 fixed, setup 1 vs 5.

Parity is unproven, so every parity-off run is NOT a strategy result. The
measurement matrix changes ONE variable per arm so the effect of each
management rule is attributable:

  A  base: fixed SL/TP only (no exit-on-flip, no holding cap, no trail)
  B  A + break-even at 1.0R
  C  B + structure trail
  D  C + PSAR trail

Two event-window matrices, each on the arm-A management and each changing exactly
one input:

  gate_w1  last trigger bar only (shipped behaviour, control)
  gate_w5  any M1 bar of the closed M5 setup bar
  setup_s1 last M5 setup bar only (control)
  setup_s5 M5 flip within the last five closed M5 bars (trigger window still 1)
  combo_c1 trigger window 5 with setup window 1 (control for the combination)
  combo_c5 trigger window 5 with setup window 5

Usage:
  .venv\\Scripts\\python.exe scripts\\tester\\gen_ww2_sets.py
  .venv\\Scripts\\python.exe scripts\\tester\\gen_ww2_sets.py --terminal "<data folder>"
  .venv\\Scripts\\python.exe scripts\\tester\\gen_ww2_sets.py --write-tracked-presets

The .set is a derived artefact: never edit it by hand, edit the JSON and re-run.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESET = ROOT / "configs/demo/wonderwhales_xau_2mode_demo.json"
OUT_SETS = ROOT / "reports/build/tester-sets"
OUT_INI = ROOT / "reports/build/tester-run"
TRACKED = ROOT / "docs/20-operations/presets"

# name, chart period, from_date, to_date, deposit, overrides
SCENARIOS = (
    ("ww2_scalp_parity_on", "M5", "2026.01.05", "2026.10.01", 10000,
     {"InpTradingMode": 1, "InpRequireParity": True}),
    ("ww2_scalp_demo_exec", "M5", "2026.01.05", "2026.10.01", 10000,
     {"InpTradingMode": 1, "InpRequireParity": False}),
    ("ww2_swing_demo_exec", "H1", "2018.01.01", "2026.10.01", 10000,
     {"InpTradingMode": 2, "InpRequireParity": False, "InpTakeProfitR": 2.5}),
    # Diagnostic only: census ON, parity ON (no orders can be sent). 100k equity
    # and 0.15% risk keep the min-lot sizer from hiding signals, so the census
    # answers "why so few trades" with per-bar gate counts.
    ("ww2_scalp_census", "M5", "2024.01.01", "2026.10.01", 100000,
     {"InpTradingMode": 1, "InpRequireParity": True, "InpDebug": True,
      "InpRiskPercent": 0.15}),
)

#--- Measurement harness -------------------------------------------------
# The guard caps are OFF on purpose: a risk halt in the middle of a window
# would truncate the sample and make the arms incomparable. 100k equity at
# 0.15% risk (150 USD) keeps the min-lot sizer from silently dropping signals.
MEASURE_BASE = {
    "InpTradingMode": 1,
    "InpRequireParity": False,
    "InpRiskPercent": 0.15,
    "InpMaxExposure": 10.0,
    "InpExitOnFlip": False,
    "InpMaxHoldingBars": 0,
    "InpBreakEvenTriggerR": 1e9,
    #--- Trail candidates are evaluated only when r >= trail_trigger_r
    #--- (WW2TrailingCoordinator) and OnInit rejects trail < break-even, so the
    #--- arms that enable a candidate set 1.3 themselves (shipped preset value).
    #--- Keeping 1e9 here makes "management off" mean exactly that.
    "InpTrailTriggerR": 1e9,
    "InpEnableStructureTrail": False,
    "InpEnablePsarTrail": False,
    "InpEnableAtrTrail": False,
    "InpEnableStepTrail": False,
    "InpMaxDailyLossPct": 0.0,
    "InpMaxWeeklyLossPct": 0.0,
    "InpMaxDrawdownPct": 0.0,
    "InpMaxConsecutiveLosses": 0,
    "InpCooldownMinutes": 0,
}

MEASURE_ARMS = {
    "a": {},                                                        # fixed SL/TP only
    "b": {"InpBreakEvenTriggerR": 1.0},                              # + break-even
    #--- C and D must arm the trail trigger, otherwise the structure/PSAR
    #--- candidates are never evaluated (the 2026-11-05 no-op). The variable
    #--- under test is the trail candidate; the trigger is its arming point.
    "c": {"InpBreakEvenTriggerR": 1.0, "InpTrailTriggerR": 1.3,
          "InpEnableStructureTrail": True},                          # + structure
    "d": {"InpBreakEvenTriggerR": 1.0, "InpTrailTriggerR": 1.3,
          "InpEnableStructureTrail": True,
          "InpEnablePsarTrail": True},                               # + PSAR
}

MEASURE_WINDOWS = {
    "is": ("2024.01.01", "2025.06.30"),
    "oos": ("2025.07.01", "2026.10.01"),
}

#--- Entry-gate ablation (task D), measured on the SAME base management as arm
#--- A so the only difference between the runs is the trigger window.
#--- w1 = control: read only the last trigger bar (shipped behaviour).
#--- w5 = scan every M1 bar of the closed M5 bar (5 = M5/M1).
GATE_VARIANTS = {
    "w1": {"InpTriggerWindowBars": 1},
    "w5": {"InpTriggerWindowBars": 5},
}

#--- Task E: the M5 setup window, measured with the trigger window held at its
#--- shipped default (1) so only the setup window changes.
SETUP_VARIANTS = {
    "s1": {"InpSetupWindowBars": 1},
    "s5": {"InpSetupWindowBars": 5},
}

#--- Task F: add the setup window on top of the best single change so far.
#--- The control is the trigger-window winner (1,5), so exactly one input moves.
COMBO_VARIANTS = {
    "c1": {"InpTriggerWindowBars": 5, "InpSetupWindowBars": 1},
    "c5": {"InpTriggerWindowBars": 5, "InpSetupWindowBars": 5},
}


def _window_scenarios(variants: dict, tag: str) -> tuple:
    out = []
    for window, (from_date, to_date) in MEASURE_WINDOWS.items():
        for variant, overrides in variants.items():
            values = dict(MEASURE_BASE)
            values.update(overrides)
            name = f"ww2_meas_scalp_{window}_{tag}_{variant}"
            _check_measure_arm(name, values)
            out.append((name, "M5", from_date, to_date, 100000, values))
    return tuple(out)


def gate_scenarios() -> tuple:
    """In-sample / out-of-sample x trigger-window variant, one variable at a time."""
    return _window_scenarios(GATE_VARIANTS, "gate")


def setup_scenarios() -> tuple:
    """In-sample / out-of-sample x setup-window variant, one variable at a time."""
    return _window_scenarios(SETUP_VARIANTS, "setup")


def combo_scenarios() -> tuple:
    """Trigger window fixed at its winner; the setup window is the only mover."""
    return _window_scenarios(COMBO_VARIANTS, "combo")


def _check_measure_arm(name: str, values: dict) -> None:
    """Mirror the EA's OnInit guard so an invalid arm cannot be generated.

    WonderwhalesXAU2ModeEA aborts with
    ``init_parameters_invalid|trail_trigger_below_break_even`` when the trail
    trigger is lower than the break-even trigger. That failure used to look like
    a finished run (empty report, exit code 0), so it is cheaper to refuse here.
    """
    be = float(values.get("InpBreakEvenTriggerR", 0.0))
    trail = float(values.get("InpTrailTriggerR", 0.0))
    if trail < be:
        raise ValueError(
            f"{name}: InpTrailTriggerR ({trail}) < InpBreakEvenTriggerR ({be}); "
            "the EA rejects this at OnInit"
        )
    if not any(values.get(flag) for flag in (
            "InpEnableStructureTrail", "InpEnablePsarTrail",
            "InpEnableAtrTrail", "InpEnableStepTrail")):
        return
    if trail >= 1e8:
        raise ValueError(
            f"{name}: a trail flag is on but InpTrailTriggerR is disabled; "
            "the candidate would never be evaluated"
        )


def measure_scenarios() -> tuple:
    """In-sample / out-of-sample x ablation arm, one variable at a time."""
    out = []
    for window, (from_date, to_date) in MEASURE_WINDOWS.items():
        for arm, overrides in MEASURE_ARMS.items():
            values = dict(MEASURE_BASE)
            values.update(overrides)
            name = f"ww2_meas_scalp_{window}_{arm}"
            _check_measure_arm(name, values)
            out.append((name, "M5", from_date, to_date, 100000, values))
    return tuple(out)


SCENARIOS += measure_scenarios()
SCENARIOS += gate_scenarios()
SCENARIOS += setup_scenarios()
SCENARIOS += combo_scenarios()

# Tracked operator presets: one per mode (see docs/10-bots/wonderwhales-2mode.md).
TRACKED_VARIANTS = {
    "wonderwhales_xau_2mode_scalp": {
        "InpTradingMode": 1, "InpTakeProfitR": 1.5, "InpRiskPercent": 0.15,
        "InpCooldownMinutes": 20, "InpBreakEvenTriggerR": 1.0, "InpTrailTriggerR": 1.3,
    },
    "wonderwhales_xau_2mode_swing": {
        "InpTradingMode": 2, "InpTakeProfitR": 2.5, "InpRiskPercent": 0.25,
        "InpCooldownMinutes": 60, "InpBreakEvenTriggerR": 1.2, "InpTrailTriggerR": 1.5,
    },
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--terminal", default="", help="MT5 data folder (contains MQL5\\)")
    parser.add_argument("--write-tracked-presets", action="store_true",
                        help="also regenerate docs/20-operations/presets/*.set")
    args = parser.parse_args()

    preset = json.loads(PRESET.read_text(encoding="utf-8"))
    base = dict(preset["inputs"])

    terminal = Path(args.terminal) if args.terminal else detect_terminal_data_dir()
    tester_profiles = (terminal / "MQL5" / "Profiles" / "Tester") if terminal else None
    if tester_profiles:
        tester_profiles.mkdir(parents=True, exist_ok=True)
    else:
        print("NOTE: no MT5 data folder; .set files written but not staged")

    OUT_SETS.mkdir(parents=True, exist_ok=True)
    OUT_INI.mkdir(parents=True, exist_ok=True)

    for name, period, from_date, to_date, deposit, overrides in SCENARIOS:
        values = dict(base)
        values.update({
            "InpEnableExecution": True,
            "InpDemoOnly": True,
            "InpRiskPercent": 1.0,           # tester-only: min lot clears the budget
            "InpResetStateOnInit": True,
            "InpLogFile": f"sim_{name}.csv",
            "InpStateFile": f"{name}_state.csv",
            "InpTelemetryFile": f"sim_{name}_telemetry.csv",
        })
        values.update(overrides)
        assert values["InpTakeProfitR"] > 0.0, "mandatory TP"
        assert values["InpMaxPositions"] == 1, "single position"

        if "_gate_" in name:
            note = [
                "; Entry-gate run: parity is unproven, so this is NOT a strategy result.",
                "; w1 = last trigger bar only (control), w5 = any M1 bar of the M5 setup bar.",
            ]
        elif "_setup_" in name:
            note = [
                "; Setup-window run: parity is unproven, so this is NOT a strategy result.",
                "; s1 = last M5 bar only (control), s5 = flip within the last 5 M5 bars.",
            ]
        elif "_combo_" in name:
            note = [
                "; Combination run: parity is unproven, so this is NOT a strategy result.",
                "; c1 = trigger 5 + setup 1 (control), c5 = trigger 5 + setup 5.",
            ]
        elif name.startswith("ww2_meas_"):
            note = [
                "; Measurement arm: parity is unproven, so this is NOT a strategy result.",
                "; A=base, B=+break-even, C=+structure, D=+PSAR; one variable per arm.",
            ]
        else:
            note = ["; parity-off runs are infrastructure evidence, NOT a strategy result."]
        lines = [
            f"; {name} - WonderwhalesXAU2ModeEA - XAUUSDm {period}",
            "; Strategy Tester = virtual demo account (ADR 0009).",
            *note,
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
            "ReplaceReport=1", f"Report=tester_{name}", "",
        ])
        (OUT_INI / f"{name}.ini").write_text(ini, encoding="utf-8", newline="\n")

        if tester_profiles:
            try:
                shutil.copyfile(OUT_SETS / f"{name}.set", tester_profiles / f"{name}.set")
                print(f"STAGED {tester_profiles / f'{name}.set'}")
            except PermissionError:
                print(f"STAGE_BLOCKED {tester_profiles / f'{name}.set'} - copy manually")
        print(f"WROTE {name} period={period} parity={values['InpRequireParity']} mode={values['InpTradingMode']}")

    if args.write_tracked_presets:
        TRACKED.mkdir(parents=True, exist_ok=True)
        for name, overrides in TRACKED_VARIANTS.items():
            values = dict(base)
            values.update(overrides)
            header = [
                "; ====================================================================",
                f"; CAU HINH TESTER CHO WonderwhalesXAU2ModeEA (XAUUSD / Vang) - {name}",
                "; Du an: MT5 EA & AI Lab (tm-fx)",
                f"; File: docs/20-operations/presets/{name}.set",
                "; Nguon: configs/demo/wonderwhales_xau_2mode_demo.json (JSON la nguon su that).",
                f";   InpTradingMode={values['InpTradingMode']} (1=SCALP, 2=SWING).",
                "; Quy uoc: chi tai khoan DEMO va Strategy Tester (ADR 0009). InpRequireParity=true",
                ";   chan moi entry (parity_blocked) cho toi khi parity Pine<->MT5 duoc chung minh.",
                "; ====================================================================",
                "", "[TesterInputs]",
            ]
            body = [f"{k}={render(v)}" for k, v in values.items()]
            (TRACKED / f"{name}.set").write_text("\n".join(header + body) + "\n",
                                                 encoding="utf-8", newline="\n")
            print(f"WROTE tracked {TRACKED / f'{name}.set'}")

    print(f"INPUTS={len(base)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
