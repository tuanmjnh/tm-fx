"""Static validation of the demo-only execution scope (ADR 0003).

Asserts the guardrails that separate demo execution from live trading:

* the execution EA only accepts a demo or Strategy Tester account;
* dry-run is the default and enabling execution is an explicit flag;
* every order carries a mandatory take profit and one position at most;
* a kill-switch file exists and no grid/DCA path is exposed;
* trading APIs live only in the three Exec sources; the simulation EAs and
  presets are untouched and still refuse orders;
* no network, socket or credential API is used anywhere in the Exec scope.

This script never compiles, never starts MetaTrader, never logs in and never
sends an order. Real behaviour is proven only by running the EA on a demo
account and keeping its journal.

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

ADR = "docs/decisions/0003-demo-execution-scope.md"
GUIDE = "docs/guides/demo-execution.md"
DEMO_EA = "mt5/Experts/PATrendRiderXAUv1DemoEA.mq5"
SIM_EA = "mt5/Experts/PATrendRiderXAUv1SimEA.mq5"
EXEC_GUARD = "mt5/Include/Exec/ExecGuard.mqh"
EXEC_BROKER = "mt5/Include/Exec/ExecBroker.mqh"
EXEC_TESTS = "mt5/Scripts/ExecGuardTests.mq5"
DEMO_PRESET = "configs/demo/pa_trendrider_xau_demo.json"
SIM_PRESET = "configs/sim/pa_trendrider_xau.json"

EXEC_SOURCES = (EXEC_GUARD, EXEC_BROKER, DEMO_EA, EXEC_TESTS)

#--- Never allowed in the demo execution scope, even though trading APIs are.
FORBIDDEN_EXEC = re.compile(
    r"\b(?:WebRequest|SocketCreate|SocketConnect|SocketSend|SocketRead|"
    r"AccountInfoString|TerminalInfoString|"
    r"CTrade|MqlTradeAsyncRequest)\b"
)

FORBIDDEN_LIVE = re.compile(r"\bACCOUNT_TRADE_MODE_REAL\b")

REASON_TOKENS = (
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
)


def _read(root: Path, relative: str) -> str:
    return (root / relative).read_text(encoding="utf-8")


def _code_only(text: str) -> str:
    """Drops comments so a documentation mention is never a guard breach."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", "", text)


def _input_default(text: str, name: str) -> str | None:
    match = re.search(
        rf"^\s*input\s+\S+\s+{name}\s*=\s*([^;]+);", text, re.MULTILINE
    )
    return match.group(1).strip() if match else None


def check_files(root: Path) -> list[str]:
    return [
        f"missing {relative}"
        for relative in (
            ADR,
            GUIDE,
            DEMO_EA,
            SIM_EA,
            EXEC_GUARD,
            EXEC_BROKER,
            EXEC_TESTS,
            DEMO_PRESET,
            SIM_PRESET,
        )
        if not (root / relative).is_file()
    ]


def check_adr(root: Path) -> list[str]:
    issues: list[str] = []
    text = _read(root, ADR)
    if "Accepted" not in text:
        issues.append("ADR 0003 must be Accepted")
    if "0002-execution-boundary.md" not in text:
        issues.append("ADR 0003 must state which ADR 0002 items it replaces")
    for token in ("ACCOUNT_TRADE_MODE_DEMO", "INIT_FAILED", "DEMO_ONLY", "kill switch"):
        if token.lower() not in text.lower():
            issues.append(f"ADR 0003 must mention {token}")
    return issues


def check_demo_ea(root: Path) -> list[str]:
    issues: list[str] = []
    text = _read(root, DEMO_EA)

    if _input_default(text, "InpEnableExecution") != "false":
        issues.append("InpEnableExecution must default to false (dry-run)")
    tp = _input_default(text, "InpTakeProfitR")
    if tp is None:
        issues.append("InpTakeProfitR is missing")
    else:
        try:
            if float(tp) <= 0.0:
                issues.append("InpTakeProfitR must be positive")
        except ValueError:
            issues.append("InpTakeProfitR must be numeric")
    if _input_default(text, "InpMaxPositions") not in (None, "1"):
        issues.append("InpMaxPositions must be fixed to 1")
    if _input_default(text, "InpKillSwitchFile") in (None, '""'):
        issues.append("InpKillSwitchFile must name a kill-switch file")
    if _input_default(text, "InpAllowedSymbols") in (None, '""'):
        issues.append("InpAllowedSymbols must not be empty")

    for token in (
        "ExecContextAllowed",
        "ExecFindOwnPosition",
        "ExecOpenMarket",
        "ExecModifyStops",
        "MQLInfoInteger(MQL_TESTER)",
        "ExecTakeProfitPrice",
        "ExecRiskBudgetOk",
    ):
        if token not in text:
            issues.append(f"DemoEA must call {token}")
    if "INIT_FAILED" not in text:
        issues.append("DemoEA must fail closed with INIT_FAILED on a guard breach")
    if FORBIDDEN_LIVE.search(_code_only(text)):
        issues.append("DemoEA must not reference ACCOUNT_TRADE_MODE_REAL")
    for token in (
        "InpMaxGridLevels",
        "InpMaxDcaAdds",
        "InpVolumeMultiplier",
        "InpAddVolumeMultiplier",
    ):
        if token in text:
            issues.append(f"DemoEA must not expose {token}")
    return issues


def check_exec_sources(root: Path) -> list[str]:
    issues: list[str] = []
    for relative in EXEC_SOURCES:
        code = _code_only(_read(root, relative))
        for match in FORBIDDEN_EXEC.finditer(code):
            issues.append(f"{relative}: forbidden API {match.group(0)}")
        if relative != EXEC_TESTS and FORBIDDEN_LIVE.search(code):
            issues.append(f"{relative}: must not reference ACCOUNT_TRADE_MODE_REAL")

    tests_code = _code_only(_read(root, EXEC_TESTS))
    if "ACCOUNT_TRADE_MODE_REAL" not in tests_code:
        issues.append("ExecGuardTests must assert that a real account is rejected")
    if "!ExecContextAllowed" not in tests_code:
        issues.append("ExecGuardTests must assert a negative context result")

    for token in REASON_TOKENS:
        if token not in _read(root, EXEC_GUARD):
            issues.append(f"ExecGuard must define reason token {token}")
        if token not in _read(root, EXEC_TESTS):
            issues.append(f"ExecGuardTests must assert reason token {token}")

    if "OrderSend" not in _read(root, EXEC_BROKER):
        issues.append("ExecBroker must own the guarded OrderSend call")
    if "OrderSend" in _read(root, EXEC_GUARD):
        issues.append("ExecGuard must stay pure")

    sim_text = _read(root, SIM_EA)
    for token in ("OrderSend(", "MqlTradeRequest", "PositionSelect("):
        if token in sim_text:
            issues.append(f"SimEA must remain simulation-only; found {token}")
    return issues


def check_presets(root: Path) -> list[str]:
    issues: list[str] = []
    demo = json.loads(_read(root, DEMO_PRESET))
    sim = json.loads(_read(root, SIM_PRESET))

    if demo.get("ea") != "PATrendRiderXAUv1DemoEA":
        issues.append("demo preset must target PATrendRiderXAUv1DemoEA")
    if demo.get("execution_mode") != "DEMO_ONLY":
        issues.append("demo preset execution_mode must be DEMO_ONLY")
    if demo.get("allow_live_trading") is not False:
        issues.append("demo preset allow_live_trading must be false")
    if demo.get("symbol") != "XAUUSDm":
        issues.append("demo preset symbol must be XAUUSDm")

    demo_inputs = demo.get("inputs", {})
    sim_inputs = sim.get("inputs", {})
    if demo_inputs.get("InpEnableExecution") is not False:
        issues.append("demo preset must ship with InpEnableExecution=false")
    if demo_inputs.get("InpMaxPositions") != 1:
        issues.append("demo preset InpMaxPositions must be 1")
    if not float(demo_inputs.get("InpTakeProfitR", 0.0)) > 0.0:
        issues.append("demo preset InpTakeProfitR must be positive")
    if "XAUUSD" not in str(demo_inputs.get("InpAllowedSymbols", "")):
        issues.append("demo preset InpAllowedSymbols must allow XAUUSD")
    if demo_inputs.get("InpMagicNumber") == sim_inputs.get("InpMagicNumber"):
        issues.append("demo magic must differ from the simulation magic")

    if sim.get("execution_mode") != "SIMULATION_ONLY":
        issues.append("simulation preset must stay SIMULATION_ONLY")
    if "InpEnableExecution" in sim_inputs or "InpTakeProfitR" in sim_inputs:
        issues.append("simulation preset must not gain execution inputs")

    source_dir = REPO_ROOT / "python" / "src"
    if str(source_dir) not in sys.path:
        sys.path.insert(0, str(source_dir))
    from mt5_ea_ai_lab import sim_configs

    issues.extend(
        f"demo preset: {item}" for item in sim_configs.validate_preset(demo)
    )
    issues.extend(
        f"simulation preset: {item}" for item in sim_configs.validate_preset(sim)
    )
    return issues


def check_guide(root: Path) -> list[str]:
    issues: list[str] = []
    text = _read(root, GUIDE).lower()
    for token in ("demo", "dry-run", "kill switch", "take profit", "live"):
        if token not in text:
            issues.append(f"demo guide must cover {token}")
    for phrase in ("guaranteed profit", "lợi nhuận chắc chắn", "moi thang"):
        if phrase in text:
            issues.append(f"demo guide must not promise results: {phrase}")
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
        report("demo execution files", file_issues)
        print(f"SUMMARY: checks={checks} fail={failures}")
        return 1

    report("demo execution files", [])
    report("ADR 0003 scope", check_adr(root))
    report("demo EA guardrails", check_demo_ea(root))
    report("exec sources", check_exec_sources(root))
    report("demo and simulation presets", check_presets(root))
    report("demo guide", check_guide(root))

    print(f"SUMMARY: checks={checks} fail={failures}")
    print("Static checks only: nothing was compiled, no terminal was started and no broker was contacted.")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
