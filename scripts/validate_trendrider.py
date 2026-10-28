"""Static validation for the PA TrendRider XAU v1 simulation sources.

Checks structure, closed-bar discipline, the simulation-only boundary and the
preset contract. This script never compiles, never starts MetaTrader and never
claims runtime success; real results come from the Strategy Tester logs kept in
``reports/build/tester-reports``.

Exit codes:
    0  every static check passed
    1  at least one check failed
    2  the project root or a required file is missing
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

EA = "mt5/Experts/PATrendRiderXAUv1SimEA.mq5"
TESTS = "mt5/Scripts/TrendRiderContractTests.mq5"
PRESET = "configs/sim/pa_trendrider_xau.json"

MODULES = (
    "TRTypes.mqh",
    "TRConfig.mqh",
    "TRSwing.mqh",
    "TRStructure.mqh",
    "TRTrend.mqh",
    "TRPullback.mqh",
    "TRSignal.mqh",
    "TRAtr.mqh",
    "TRRisk.mqh",
    "TRTrailing.mqh",
    "TRState.mqh",
    "TRMarketData.mqh",
)

SUITE_RUNNERS = (
    "RunSwing",
    "RunStructure",
    "RunTrend",
    "RunPullback",
    "RunSignal",
    "RunRisk",
    "RunLedger",
    "RunTrailing",
    "RunState",
    "RunAtr",
)

FORBIDDEN_API = re.compile(
    r"\b(OrderSendAsync|OrderSend|OrderCalcMargin|OrderCalcProfit|OrderCheck|"
    r"CTrade|MqlTradeRequest|MqlTradeResult|MqlTradeCheckResult|"
    r"PositionOpen|PositionClose|PositionModify|PositionSelect|"
    r"OrderOpen|OrderClose|OrderModify|OrderDelete|"
    r"WebRequest|SocketCreate|SocketConnect|SocketSend|SocketRead|"
    r"AccountInfoInteger|AccountInfoDouble|AccountInfoString|AccountInfo)\b"
)

FORBIDDEN_INCLUDE = re.compile(r'#include\s*[<"](?:Trade|Expert)[\\/]', re.IGNORECASE)


def _read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def check_files(root: Path) -> list[str]:
    missing = [
        relative
        for relative in (EA, TESTS, PRESET, *(f"mt5/Include/TrendRider/{m}" for m in MODULES))
        if not (root / relative).is_file()
    ]
    return [f"missing {relative}" for relative in missing]


def check_ea_includes(root: Path) -> list[str]:
    text = _read(root, EA)
    return [
        f"EA missing include {module}"
        for module in MODULES
        if module not in text
    ]


def check_closed_bars(root: Path) -> list[str]:
    issues: list[str] = []
    market = _read(root, "mt5/Include/TrendRider/TRMarketData.mqh")
    if "CopyRates(_Symbol,timeframe,1," not in market:
        issues.append("TRMarketData must copy closed bars with start_pos=1")
    if "CopyRates" in _read(root, EA):
        issues.append("EA must load bars through TRMarketData, not CopyRates directly")
    if "iTime(_Symbol,InpEntryTF,0)" not in _read(root, EA):
        issues.append("EA must detect a new closed entry bar through iTime(...,0)")
    return issues


def check_simulation_boundary(root: Path) -> list[str]:
    issues: list[str] = []
    sources = [EA, *(f"mt5/Include/TrendRider/{m}" for m in MODULES)]
    for relative in sources:
        text = (root / relative).read_text(encoding="utf-8")
        for match in FORBIDDEN_API.finditer(text):
            issues.append(f"{relative}: forbidden API {match.group(0)}")
        for match in FORBIDDEN_INCLUDE.finditer(text):
            issues.append(f"{relative}: forbidden include {match.group(0)}")
    ea_text = _read(root, EA)
    if "InitWithContractSize" not in ea_text:
        issues.append("EA must size virtual P&L with the symbol contract size")
    if "WriteStateFile" not in ea_text or "RestoreStateFile" not in ea_text:
        issues.append("EA must persist and restore risk/position state")
    for token in ("InpUseFixedTP", "TakeProfit", "OrderSend"):
        if token in ea_text:
            issues.append(f"EA must not contain {token}")
    return issues


def check_contract_suite(root: Path) -> list[str]:
    text = _read(root, TESTS)
    issues = [
        f"contract tests missing {name}"
        for name in SUITE_RUNNERS
        if f"{name}()" not in text
    ]
    if "TEST|RESULT|ALL_PASS" not in text:
        issues.append("contract tests must print an ALL_PASS result line")
    if "RunAllTests" not in text:
        issues.append("contract tests must expose RunAllTests")
    return issues


def check_setup_lifecycle(root: Path) -> list[str]:
    issues: list[str] = []
    structure = _read(root, "mt5/Include/TrendRider/TRStructure.mqh")
    if "last_high.time!=m_broken_high_time" not in structure:
        issues.append("BOS dedupe must key on swing time, not a shifting index")
    ea_text = _read(root, EA)
    if 'StringFind(decision.reason,"bos_too_old")' not in ea_text:
        issues.append("EA must discard a pending BOS that exceeded its max age")
    return issues


def check_preset(root: Path) -> list[str]:
    issues: list[str] = []
    preset = json.loads(_read(root, PRESET))
    if preset.get("ea") != "PATrendRiderXAUv1SimEA":
        issues.append("preset declares the wrong ea")
    if preset.get("execution_mode") != "SIMULATION_ONLY":
        issues.append("preset execution_mode must be SIMULATION_ONLY")
    if preset.get("allow_live_trading") is not False:
        issues.append("preset allow_live_trading must be false")
    if preset.get("symbol") != "XAUUSDm":
        issues.append("preset symbol must be XAUUSDm")

    inputs = preset.get("inputs", {})
    expected_frames = {
        "InpTrendTF": 16385,
        "InpStructureTF": 15,
        "InpEntryTF": 5,
    }
    for name, value in expected_frames.items():
        if inputs.get(name) != value:
            issues.append(f"preset {name} must be {value}")
    if inputs.get("InpMaxPositions") != 1:
        issues.append("preset InpMaxPositions must be 1")
    if not inputs.get("InpEnableTrading"):
        issues.append("preset InpEnableTrading must be true for a baseline")
    return issues


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    args = parser.parse_args(argv)

    root: Path = args.root.resolve()
    if not (root / "mt5").is_dir():
        print(f"ERROR: missing {root / 'mt5'}", file=sys.stderr)
        return 2

    checks = 0
    failures = 0

    def report(name: str, issues: list[str]) -> None:
        nonlocal checks, failures
        checks += 1
        if issues:
            failures += 1
            print(f"FAIL: {name}")
            for issue in issues:
                print(f"  - {issue}")
        else:
            print(f"PASS: {name}")

    file_issues = check_files(root)
    if file_issues:
        report("trendrider files", file_issues)
        print(f"SUMMARY: checks={checks} fail={failures}")
        return 1

    report("trendrider files", [])
    report("EA module includes", check_ea_includes(root))
    report("closed-bar discipline", check_closed_bars(root))
    report("simulation-only boundary", check_simulation_boundary(root))
    report("contract suite", check_contract_suite(root))
    report("setup lifecycle", check_setup_lifecycle(root))
    report("trendrider preset", check_preset(root))

    print(f"SUMMARY: checks={checks} fail={failures}")
    print("Static checks only: nothing was compiled and no terminal was started.")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
