"""Generate Strategy Tester inputs for WonderwhalesXAU2ModeEA (ADR 0009).

Writes, from the single source of truth configs/demo/wonderwhales_xau_2mode_demo.json:
  reports/build/tester-sets/<scenario>.set   (staged into MQL5\\Profiles\\Tester)
  reports/build/tester-run/<scenario>.ini

Scenarios:
  ww2_scalp_parity_on  parity gate ON  -> proves entries are blocked (parity_blocked).
  ww2_scalp_demo_exec  parity OFF      -> proves the ExecBroker order path (infrastructure only).
  ww2_swing_demo_exec  parity OFF      -> same, Swing mode (starts 2018 so W1/D1 EMA200 has history).

Parity is unproven, so the parity-off runs are NOT a strategy result.

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

# name, chart period, from_date, overrides
SCENARIOS = (
    ("ww2_scalp_parity_on", "M5", "2026.01.05",
     {"InpTradingMode": 1, "InpRequireParity": True}),
    ("ww2_scalp_demo_exec", "M5", "2026.01.05",
     {"InpTradingMode": 1, "InpRequireParity": False}),
    ("ww2_swing_demo_exec", "H1", "2018.01.01",
     {"InpTradingMode": 2, "InpRequireParity": False, "InpTakeProfitR": 2.5}),
)

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

    for name, period, from_date, overrides in SCENARIOS:
        values = dict(base)
        values.update({
            "InpEnableExecution": True,
            "InpDemoOnly": True,
            "InpRiskPercent": 1.0,           # tester-only: min lot clears the budget
            "InpResetStateOnInit": True,
            "InpLogFile": f"sim_{name}.csv",
            "InpStateFile": f"{name}_state.csv",
            "InpTelemetryFile": f"{name}_telemetry.csv",
        })
        values.update(overrides)
        assert values["InpTakeProfitR"] > 0.0, "mandatory TP"
        assert values["InpMaxPositions"] == 1, "single position"

        lines = [
            f"; {name} - WonderwhalesXAU2ModeEA - XAUUSDm {period}",
            "; Strategy Tester = virtual demo account (ADR 0009).",
            "; parity-off runs are infrastructure evidence, NOT a strategy result.",
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
            f"FromDate={from_date}", "ToDate=2026.10.01",
            "Deposit=10000", "Currency=USD", "Leverage=1:100",
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
