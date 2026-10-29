"""Static validation for the whole MT5 EA & AI Lab project.

Scans every MQL5 source under ``mt5/`` for order-sending, trade-class, socket,
web-request, account and credential APIs, checks for placeholder markers and
verifies the Track C layout and presets with the same fail-closed rules used by
``scripts/validate_sim_configs.py``.

ADR 0003 allows trading APIs in exactly three demo-execution sources. Those
files are still scanned for network, socket and credential APIs, and the demo
guardrails are asserted separately by ``scripts/validate_demo_execution.py``.

This script never compiles, never starts MetaTrader, never touches an account
and never connects to a broker.

Exit codes:
    0  every static check passed
    1  at least one check failed
    2  the project root or a required directory is missing
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

FORBIDDEN_API = re.compile(
    r"\b(?:"
    r"OrderSendAsync|OrderSend|OrderCalcMargin|OrderCalcProfit|OrderCheck|"
    r"CTrade|MqlTradeRequest|MqlTradeResult|MqlTradeCheckResult|"
    r"PositionOpen|PositionClose|PositionModify|PositionSelect|"
    r"OrderOpen|OrderClose|OrderModify|OrderDelete|"
    r"WebRequest|SocketCreate|SocketConnect|SocketSend|SocketRead|"
    r"AccountInfoInteger|AccountInfoDouble|AccountInfoString|AccountInfo|"
    r"TerminalInfoString\s*\(\s*TERMINAL_PASSWORD"
    r")\b"
)

#--- Exec sources are exempt from FORBIDDEN_API but never from these.
EXEC_SOURCES = {
    "mt5/Include/Exec/ExecGuard.mqh",
    "mt5/Include/Exec/ExecBroker.mqh",
    "mt5/Experts/PATrendRiderXAUv1DemoEA.mq5",
    "mt5/Scripts/ExecGuardTests.mq5",
    "mt5/Scripts/ExecDemoProbe.mq5",
}

EXEC_FORBIDDEN_API = re.compile(
    r"\b(?:WebRequest|SocketCreate|SocketConnect|SocketSend|SocketRead|"
    r"AccountInfoString|TerminalInfoString"
    r")\b"
)

FORBIDDEN_INCLUDE = re.compile(r'#include\s*[<"](?:Trade|Expert)[\\/]', re.IGNORECASE)

PLACEHOLDER = re.compile(r"\b(TODO|FIXME|TBD|PLACEHOLDER|NOT_IMPLEMENTED)\b")

REQUIRED_FILES = (
    "README.md",
    "pyproject.toml",
    "docs/README.md",
    "docs/PROGRESS.md",
    "docs/MASTER_ROADMAP.md",
    "docs/guides/install-and-test.md",
    "docs/guides/strategy-tester.md",
    "docs/guides/toolchain.md",
    "docs/indicators/README.md",
    "docs/indicators/parity.md",
    "docs/reference/architecture.md",
    "docs/reference/simulation.md",
    "docs/reference/testing.md",
    "docs/reference/risk.md",
    "docs/reference/release.md",
    "configs/project.example.json",
    "configs/sim/runner_trailing.json",
    "configs/sim/grid_lab.json",
    "configs/sim/dca_lab.json",
    "configs/sim/pine_plan_lab.json",
    "configs/sim/pa_trendrider_xau.json",
    "mt5/Include/Sim/SimTypes.mqh",
    "mt5/Include/Sim/SimValidate.mqh",
    "mt5/Include/Sim/SimPortfolio.mqh",
    "mt5/Include/Sim/SimCostModel.mqh",
    "mt5/Include/Sim/SimRiskGuard.mqh",
    "mt5/Include/Sim/SimTrailing.mqh",
    "mt5/Include/Sim/SimGrid.mqh",
    "mt5/Include/Sim/SimDca.mqh",
    "mt5/Include/Sim/SimPlan.mqh",
    "mt5/Include/Sim/SimLogger.mqh",
    "mt5/Experts/RunnerTrailingLabEA.mq5",
    "mt5/Experts/GridLabEA.mq5",
    "mt5/Experts/DCALabEA.mq5",
    "mt5/Experts/PinePlanSimEA.mq5",
    "mt5/Scripts/SimCoreTests.mq5",
    "mt5/Scripts/SimPlanTests.mq5",
    "mt5/Include/TrendRider/TRTypes.mqh",
    "mt5/Include/TrendRider/TRConfig.mqh",
    "mt5/Include/TrendRider/TRSwing.mqh",
    "mt5/Include/TrendRider/TRStructure.mqh",
    "mt5/Include/TrendRider/TRTrend.mqh",
    "mt5/Include/TrendRider/TRPullback.mqh",
    "mt5/Include/TrendRider/TRSignal.mqh",
    "mt5/Include/TrendRider/TRAtr.mqh",
    "mt5/Include/TrendRider/TRRisk.mqh",
    "mt5/Include/TrendRider/TRTrailing.mqh",
    "mt5/Include/TrendRider/TRState.mqh",
    "mt5/Include/TrendRider/TRMarketData.mqh",
    "mt5/Experts/PATrendRiderXAUv1SimEA.mq5",
    "mt5/Scripts/TrendRiderContractTests.mq5",
    "mt5/Include/Exec/ExecGuard.mqh",
    "mt5/Include/Exec/ExecBroker.mqh",
    "mt5/Experts/PATrendRiderXAUv1DemoEA.mq5",
    "mt5/Scripts/ExecGuardTests.mq5",
    "mt5/Scripts/ExecDemoProbe.mq5",
    "configs/demo/pa_trendrider_xau_demo.json",
    "docs/decisions/0003-demo-execution-scope.md",
    "docs/guides/demo-execution.md",
    "scripts/validate_demo_execution.py",
)

SIM_EAS = {
    "RunnerTrailingLabEA.mq5": ("SimPortfolio.mqh", "SimLogger.mqh"),
    "GridLabEA.mq5": ("SimPortfolio.mqh", "SimLogger.mqh"),
    "DCALabEA.mq5": ("SimPortfolio.mqh", "SimLogger.mqh", "SimDca.mqh"),
    "PinePlanSimEA.mq5": ("SimPortfolio.mqh", "SimLogger.mqh", "SimPlan.mqh"),
    "PATrendRiderXAUv1SimEA.mq5": (
        "SimPortfolio.mqh",
        "SimLogger.mqh",
        "TRConfig.mqh",
        "TRSignal.mqh",
        "TRRisk.mqh",
        "TRTrailing.mqh",
        "TRState.mqh",
        "TRMarketData.mqh",
    ),
}

SIM_CORE_TESTS_INCLUDES = (
    "SimPortfolio.mqh",
    "SimLogger.mqh",
    "SimCostModel.mqh",
    "SimRiskGuard.mqh",
    "SimTrailing.mqh",
    "SimGrid.mqh",
    "SimDca.mqh",
)


def mql_sources(mt5_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in mt5_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in {".mq5", ".mqh"}
    )


def _code_only(text: str) -> str:
    """Drops comments so a documentation mention is never a guard breach."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def scan_forbidden_api(path: Path, root: Path) -> list[str]:
    issues: list[str] = []
    relative = path.relative_to(root).as_posix()
    is_exec = relative in EXEC_SOURCES
    text = path.read_text(encoding="utf-8")
    code = _code_only(text)
    for lineno, line in enumerate(code.splitlines(), 1):
        if not is_exec:
            for match in FORBIDDEN_API.finditer(line):
                token = match.group(0).split("(")[0].strip()
                issues.append(f"{path}:{lineno}: forbidden API {token}")
        else:
            for match in EXEC_FORBIDDEN_API.finditer(line):
                token = match.group(0).split("(")[0].strip()
                issues.append(f"{path}:{lineno}: forbidden API {token} in exec source")
    for lineno, line in enumerate(text.splitlines(), 1):
        if FORBIDDEN_INCLUDE.search(line):
            issues.append(f"{path}:{lineno}: forbidden include {line.strip()}")
    return issues


def scan_placeholders(path: Path) -> list[str]:
    issues: list[str] = []
    text = path.read_text(encoding="utf-8")
    for lineno, line in enumerate(text.splitlines(), 1):
        for match in PLACEHOLDER.finditer(line):
            issues.append(f"{path}:{lineno}: placeholder marker {match.group(1)}")
    return issues


def check_layout(root: Path) -> list[str]:
    return [
        f"missing {relative}"
        for relative in REQUIRED_FILES
        if not (root / relative).is_file()
    ]


def check_sim_structure(root: Path) -> list[str]:
    issues: list[str] = []
    for name, includes in SIM_EAS.items():
        path = root / "mt5" / "Experts" / name
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for include in includes:
            if include not in text:
                issues.append(f"{path.name}: missing include {include}")

    tests = root / "mt5" / "Scripts" / "SimCoreTests.mq5"
    if tests.is_file():
        text = tests.read_text(encoding="utf-8")
        for include in SIM_CORE_TESTS_INCLUDES:
            if include not in text:
                issues.append(f"SimCoreTests.mq5: missing include {include}")

    plan_tests = root / "mt5" / "Scripts" / "SimPlanTests.mq5"
    if plan_tests.is_file():
        text = plan_tests.read_text(encoding="utf-8")
        if "SimPlan.mqh" not in text:
            issues.append("SimPlanTests.mq5: missing include SimPlan.mqh")
    return issues


def check_exec_structure(root: Path) -> list[str]:
    issues: list[str] = []

    demo_ea = root / "mt5" / "Experts" / "PATrendRiderXAUv1DemoEA.mq5"
    broker = root / "mt5" / "Include" / "Exec" / "ExecBroker.mqh"
    guard = root / "mt5" / "Include" / "Exec" / "ExecGuard.mqh"
    tests = root / "mt5" / "Scripts" / "ExecGuardTests.mq5"
    probe = root / "mt5" / "Scripts" / "ExecDemoProbe.mq5"

    for path in (demo_ea, broker, guard, tests, probe):
        if not path.is_file():
            issues.append(f"missing {path.relative_to(root).as_posix()}")
    if issues:
        return issues

    demo_text = demo_ea.read_text(encoding="utf-8")
    required_demo = (
        "ACCOUNT_TRADE_MODE",
        "MQLInfoInteger(MQL_TESTER)",
        "ExecContextAllowed",
        "ExecFindOwnPosition",
        "ExecOpenMarket",
        "ExecModifyStops",
        "InpEnableExecution",
        "InpTakeProfitR",
        "InpKillSwitchFile",
        "InpAllowedSymbols",
    )
    for token in required_demo:
        if token not in demo_text:
            issues.append(f"DemoEA missing guard token {token}")
    if not re.search(r"InpEnableExecution\s*=\s*false", demo_text):
        issues.append("DemoEA must default InpEnableExecution to false (dry-run)")
    for token in (
        "InpMaxGridLevels",
        "InpMaxDcaAdds",
        "InpVolumeMultiplier",
        "InpAddVolumeMultiplier",
    ):
        if token in demo_text:
            issues.append(f"DemoEA must not expose {token} (no grid/DCA in v1)")

    if "OrderSend" not in broker.read_text(encoding="utf-8"):
        issues.append("ExecBroker must contain the guarded OrderSend call")
    guard_text = _code_only(guard.read_text(encoding="utf-8"))
    for token in ("OrderSend", "AccountInfo", "PositionGet", "HistorySelect"):
        if token in guard_text:
            issues.append(f"ExecGuard must stay pure; found {token}")

    test_text = tests.read_text(encoding="utf-8")
    for token in (
        "not_demo_account",
        "account_trade_disabled",
        "terminal_trade_disabled",
        "symbol_not_allowed",
        "symbol_trade_disabled",
        "symbol_close_only",
        "kill_switch_active",
        "dry_run",
        "take_profit_invalid",
        "stop_below_broker_level",
        "risk_budget_exceeded",
        "free_margin_insufficient",
    ):
        if token not in test_text:
            issues.append(f"ExecGuardTests must assert reason token {token}")
    if "TEST|RESULT|ALL_PASS" not in test_text:
        issues.append("ExecGuardTests must print an ALL_PASS result line")

    probe_text = _code_only(probe.read_text(encoding="utf-8"))
    for token in (
        "MQLInfoInteger(MQL_TESTER)",
        "ExecContextAllowed",
        "ExecSymbolAllowed",
        "ExecSymbolTradable",
        "ExecOpenMarket",
        "ExecClosePosition",
        "FileIsExist",
        "void OnStart",
    ):
        if token not in probe_text:
            issues.append(f"ExecDemoProbe missing guard token {token}")
    if not re.search(r"InpConfirm\s*=\s*false", probe_text):
        issues.append("ExecDemoProbe must default InpConfirm to false")
    if "OrderSend" in probe_text:
        issues.append("ExecDemoProbe must route orders through ExecBroker, not OrderSend")
    if "ExecBroker.mqh" not in probe.read_text(encoding="utf-8"):
        issues.append("ExecDemoProbe must include ExecBroker.mqh")
    probe_magic = re.search(r"InpMagicNumber\s*=\s*(\d+)", probe_text)
    demo_magic = re.search(r"InpMagicNumber\s*=\s*(\d+)", demo_text)
    if probe_magic is None or demo_magic is None:
        issues.append("Exec scope must declare an explicit magic in DemoEA and ExecDemoProbe")
    elif probe_magic.group(1) == demo_magic.group(1):
        issues.append("ExecDemoProbe magic must differ from the DemoEA magic")
    return issues


def check_demo_presets(root: Path) -> list[str]:
    issues: list[str] = []
    try:
        sim_configs = _load_sim_configs()
    except Exception as exc:  # noqa: BLE001 - report any import failure
        return [f"cannot import mt5_ea_ai_lab.sim_configs: {exc}"]

    demo_dir = root / "configs" / "demo"
    if not demo_dir.is_dir():
        return [f"missing {demo_dir.relative_to(root).as_posix()}"]
    presets = sorted(demo_dir.glob("*.json"))
    if not presets:
        return ["configs/demo: no preset files"]

    for path in presets:
        try:
            config = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            issues.append(f"{path.name}: cannot read: {exc}")
            continue
        issues.extend(
            f"{path.name}: {message}" for message in sim_configs.validate_preset(config)
        )
        if not isinstance(config, dict):
            continue
        inputs = config.get("inputs")
        if not isinstance(inputs, dict):
            continue
        if config.get("ea") != "PATrendRiderXAUv1DemoEA":
            issues.append(f"{path.name}: demo presets must target PATrendRiderXAUv1DemoEA")
        if inputs.get("InpEnableExecution") is not False:
            issues.append(f"{path.name}: InpEnableExecution must default to false")
        if float(inputs.get("InpTakeProfitR", 0.0)) <= 0.0:
            issues.append(f"{path.name}: InpTakeProfitR must be positive")
        if inputs.get("InpMaxPositions") != 1:
            issues.append(f"{path.name}: InpMaxPositions must be 1")
        if "XAUUSD" not in str(inputs.get("InpAllowedSymbols", "")):
            issues.append(f"{path.name}: InpAllowedSymbols must allow XAUUSD")
    return issues


def _load_sim_configs():
    source_dir = REPO_ROOT / "python" / "src"
    if str(source_dir) not in sys.path:
        sys.path.insert(0, str(source_dir))
    from mt5_ea_ai_lab import sim_configs

    return sim_configs


def check_presets(root: Path) -> tuple[list[str], list[str]]:
    """Return (issues, passed_labels)."""
    issues: list[str] = []
    passed: list[str] = []
    try:
        sim_configs = _load_sim_configs()
    except Exception as exc:  # noqa: BLE001 - report any import failure
        return [f"cannot import mt5_ea_ai_lab.sim_configs: {exc}"], passed

    presets_dir = root / "configs" / "sim"
    if not presets_dir.is_dir():
        return [f"missing {presets_dir}"], passed

    for path in sim_configs.preset_files(presets_dir):
        try:
            config = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            issues.append(f"{path.name}: cannot read: {exc}")
            continue
        problems = sim_configs.validate_preset(config)
        if problems:
            issues.extend(f"{path.name}: {message}" for message in problems)
        else:
            passed.append(path.name)

    project_path = root / "configs" / "project.example.json"
    try:
        project = json.loads(project_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        issues.append(f"project.example.json: cannot read: {exc}")
    else:
        problems = sim_configs.validate_project(project, root)
        if problems:
            issues.extend(f"project.example.json: {message}" for message in problems)
        else:
            passed.append("project.example.json")
    return issues, passed


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="project root (default: repository root)",
    )
    args = parser.parse_args(argv)

    root: Path = args.root.resolve()
    mt5_dir = root / "mt5"
    if not mt5_dir.is_dir():
        print(f"ERROR: missing {mt5_dir}", file=sys.stderr)
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

    report("layout", check_layout(root))

    sources = mql_sources(mt5_dir)
    if not sources:
        report("mql sources", ["no .mq5/.mqh file under mt5/"])
    else:
        issues: list[str] = []
        for path in sources:
            try:
                issues.extend(scan_forbidden_api(path, root))
            except OSError as exc:
                issues.append(f"{path}: cannot read: {exc}")
        report(f"forbidden API scan ({len(sources)} sources)", issues)

        issues = []
        for path in sources:
            try:
                issues.extend(scan_placeholders(path))
            except OSError as exc:
                issues.append(f"{path}: cannot read: {exc}")
        report(f"placeholder scan ({len(sources)} sources)", issues)

    report("simulation EA structure", check_sim_structure(root))

    report("demo execution structure", check_exec_structure(root))
    report("demo presets", check_demo_presets(root))

    preset_issues, passed = check_presets(root)
    for label in passed:
        checks += 1
        print(f"PASS: preset {label}")
    report("preset validation", preset_issues)

    print(f"SUMMARY: checks={checks} fail={failures}")
    print("Static checks only: nothing was compiled, no MT5 terminal was started and no broker was contacted.")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
