"""Static validation of the demo-only execution scope (ADR 0004).

Asserts the guardrails that separate demo execution from live trading:

* every demo EA (TrendRider, Grid, DCA) only accepts a demo or Strategy Tester
  account and fails closed on anything else;
* execution is enabled by default in both code and presets (ADR 0006) and a dry-run
  is the explicit InpEnableExecution=false override used for comparison runs;
* every order carries a mandatory SL/TP; the TrendRider EA keeps one position,
  while Grid/DCA baskets stay bounded in level count, volume and loss budget;
* a kill-switch file exists for each bot and a basket is flattened on breach;
* trading APIs live only in the Exec sources (guard, broker, shared basket
  helpers, the three demo EAs, contract tests, order probe); the simulation EAs
  and presets are untouched and still refuse orders;
* the order probe stays confirm-gated, tester-refusing and on its own magic;
* the demo journal watcher stays read-only and mirrors the EA's CSV contract;
* no network, socket or credential API is used anywhere in the Exec scope.

This script never compiles, never starts MetaTrader, never logs in and never
sends an order. Real behaviour is proven only by running the EA on a demo
account and keeping its journal.

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
import importlib.util
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

ADR = "docs/decisions/0004-all-bots-demo-execution.md"
ADR_0003 = "docs/decisions/0003-demo-execution-scope.md"
GUIDE = "docs/guides/demo-execution.md"
DEMO_EA = "mt5/Experts/PATrendRiderXAUv1DemoEA.mq5"
GRID_DEMO_EA = "mt5/Experts/GridDemoEA.mq5"
DCA_DEMO_EA = "mt5/Experts/DCADemoEA.mq5"
IR_DEMO_EA = "mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5"
SIM_EA = "mt5/Experts/PATrendRiderXAUv1SimEA.mq5"
EXEC_GUARD = "mt5/Include/Exec/ExecGuard.mqh"
EXEC_BROKER = "mt5/Include/Exec/ExecBroker.mqh"
EXEC_COMMON = "mt5/Include/Exec/ExecDemoCommon.mqh"
EXEC_TESTS = "mt5/Scripts/ExecGuardTests.mq5"
EXEC_PROBE = "mt5/Scripts/ExecDemoProbe.mq5"
SIM_LOGGER = "mt5/Include/Sim/SimLogger.mqh"
JOURNAL_WATCHER = "scripts/watch_demo_journal.py"
DEMO_PRESET = "configs/demo/pa_trendrider_xau_demo.json"
GRID_DEMO_PRESET = "configs/demo/grid_demo.json"
DCA_DEMO_PRESET = "configs/demo/dca_demo.json"
IR_DEMO_PRESET = "configs/demo/infinite_runner_demo.json"
SIM_PRESET = "configs/sim/pa_trendrider_xau.json"

#--- ADR 0004 + ADR 0005: one demo EA per strategy, each with its own shape.
DEMO_EAS = {
    DEMO_EA: "single_position",
    GRID_DEMO_EA: "bounded_basket",
    DCA_DEMO_EA: "bounded_basket",
    IR_DEMO_EA: "runner_trailing",
}

EXEC_SOURCES = (
    EXEC_GUARD,
    EXEC_BROKER,
    EXEC_COMMON,
    *DEMO_EAS,
    EXEC_TESTS,
    EXEC_PROBE,
)

#--- Never allowed in the demo execution scope, even though trading APIs are.
FORBIDDEN_EXEC = re.compile(
    r"\b(?:WebRequest|SocketCreate|SocketConnect|SocketSend|SocketRead|"
    r"AccountInfoString|TerminalInfoString|"
    r"CTrade|MqlTradeAsyncRequest)\b"
)

FORBIDDEN_LIVE = re.compile(r"\bACCOUNT_TRADE_MODE_REAL\b")

#--- The journal watcher is Python; it must never reach a trading API at all.
FORBIDDEN_WATCHER = re.compile(
    r"\b(?:OrderSend|CPositionInfo|CTrade|MqlTradeRequest|MqlTradeResult|"
    r"positions_get|order_send|trading_set_timeout|import\s+MetaTrader5)\b"
)

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
            ADR_0003,
            GUIDE,
            DEMO_EA,
            GRID_DEMO_EA,
            DCA_DEMO_EA,
            SIM_EA,
            EXEC_GUARD,
            EXEC_BROKER,
            EXEC_COMMON,
            EXEC_TESTS,
            DEMO_PRESET,
            GRID_DEMO_PRESET,
            DCA_DEMO_PRESET,
            IR_DEMO_PRESET,
            SIM_PRESET,
            EXEC_PROBE,
            JOURNAL_WATCHER,
        )
        if not (root / relative).is_file()
    ]


def check_adr(root: Path) -> list[str]:
    issues: list[str] = []
    text = _read(root, ADR)
    if "Accepted" not in text:
        issues.append("ADR 0004 must be Accepted")
    for token in ("0003-demo-execution-scope.md",
                  "ACCOUNT_TRADE_MODE_DEMO",
                  "INIT_FAILED",
                  "DEMO_ONLY",
                  "kill switch"):
        if token.lower() not in text.lower():
            issues.append(f"ADR 0004 must mention {token}")
    if "NOT_RUN" not in text:
        issues.append("ADR 0004 must keep demo runs at NOT_RUN until evidence exists")

    adr3 = _read(root, ADR_0003)
    if "0004-all-bots-demo-execution.md" not in adr3:
        issues.append("ADR 0003 must point at the superseding ADR 0004")
    return issues


def check_demo_ea(root: Path, relative: str = DEMO_EA) -> list[str]:
    issues: list[str] = []
    text = _read(root, relative)
    label = Path(relative).name

    if _input_default(text, "InpEnableExecution") != "true":
        issues.append(f"{label}: InpEnableExecution must default to true (ADR 0006)")
    if _input_default(text, "InpKillSwitchFile") in (None, '""'):
        issues.append(f"{label}: InpKillSwitchFile must name a kill-switch file")
    if _input_default(text, "InpAllowedSymbols") in (None, '""'):
        issues.append(f"{label}: InpAllowedSymbols must not be empty")

    for token in (
        "ExecContextAllowed",
        "ExecOpenMarket",
        "MQLInfoInteger(MQL_TESTER)",
        "ExecSymbolAllowed",
    ):
        if token not in text:
            issues.append(f"{label}: must call {token}")
    if "INIT_FAILED" not in text:
        issues.append(f"{label}: must fail closed with INIT_FAILED on a guard breach")
    if FORBIDDEN_LIVE.search(_code_only(text)):
        issues.append(f"{label}: must not reference ACCOUNT_TRADE_MODE_REAL")
    if "OrderSend" in _code_only(text):
        issues.append(f"{label}: must route orders through ExecBroker, not OrderSend")

    if relative == DEMO_EA:
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
        for token in (
            "ExecFindOwnPosition",
            "ExecModifyStops",
            "ExecTakeProfitPrice",
            "ExecRiskBudgetOk",
        ):
            if token not in text:
                issues.append(f"DemoEA must call {token}")
        for token in (
            "InpMaxGridLevels",
            "InpMaxDcaAdds",
            "InpVolumeMultiplier",
            "InpAddVolumeMultiplier",
        ):
            if token in text:
                issues.append(f"DemoEA must not expose {token} (single position)")

    if relative == IR_DEMO_EA:
        #--- ADR 0005: the runner must keep its mandatory far safety TP, its
        #--- stop band and its monotonic trail inputs.
        tp = _input_default(text, "InpSafetyTpPoints")
        if tp is None:
            issues.append("InpSafetyTpPoints is missing")
        else:
            try:
                if float(tp) <= 0.0:
                    issues.append("InpSafetyTpPoints must be positive")
            except ValueError:
                issues.append("InpSafetyTpPoints must be numeric")
        if _input_default(text, "InpMaxPositions") not in (None, "1"):
            issues.append("InpMaxPositions must be fixed to 1")
        for token in (
            "ExecFindOwnPosition",
            "ExecModifyStops",
            "ExecCalcProfit",
            "ExecMarginRequired",
            "ExecClosedPnl",
            "IRMonotonicBetter",
        ):
            if token not in text:
                issues.append(f"InfiniteRunner demo EA must use {token}")
        for token in (
            "InpMaxGridLevels",
            "InpMaxDcaAdds",
            "ExecDemoBasketClose",
        ):
            if token in text:
                issues.append(f"InfiniteRunner demo EA must not expose {token} (runner)")
    return issues


def check_bounded_baskets(root: Path) -> list[str]:
    """Grid/DCA demo EAs may hold several positions, so their caps are the
    guardrail: bounded count, bounded volume, bounded loss at the basket stop,
    a mandatory basket SL/TP and a flush on halt."""
    issues: list[str] = []
    expectations = {
        GRID_DEMO_EA: (
            "InpMaxGridLevels",
            "InpMaxLevelVolume",
            "InpVolumeMultiplier",
            "InpBasketStopPoints",
            "InpBasketTargetPoints",
            "InpMaxExposure",
            "InpMaxBasketLossPct",
            "InpMaxConsecutiveLosses",
            "InpMaxDailyLossPct",
            "InpMaxDrawdownPct",
        ),
        DCA_DEMO_EA: (
            "InpMaxDcaAdds",
            "InpMaxAddVolume",
            "InpAddVolumeMultiplier",
            "InpBasketStopPoints",
            "InpBasketTargetPoints",
            "InpMaxExposure",
            "InpMaxBasketLossPct",
            "InpMaxConsecutiveLosses",
            "InpMaxDailyLossPct",
            "InpMaxDrawdownPct",
        ),
    }
    for relative, inputs in expectations.items():
        text = _read(root, relative)
        for name in inputs:
            if _input_default(text, name) is None:
                issues.append(f"{relative}: missing cap input {name}")
        for token in (
            "ExecDemoBasketClose",
            "ExecDemoBasketSetStops",
            "BasketLossBudgetOk",
            "ExecDemoBasketLossMoney",
            "ExecRiskBudgetOk",
            "ExecDemoKillSwitchPresent",
            "ExecDemoHistoryPnl",
        ):
            if token not in text:
                issues.append(f"{relative}: must use {token}")
        #--- A basket must always be flattened when a hard cap trips.
        for token in ("CloseBasket(\"RISK_HALT\")", "CloseBasket(\"KILL_SWITCH\")"):
            if token not in text:
                issues.append(f"{relative}: must flatten the basket on {token}")
        if not re.search(r"InpMaxExposure\s*=\s*[\d.]+", text):
            issues.append(f"{relative}: InpMaxExposure must have a finite default")

    common = _code_only(_read(root, EXEC_COMMON))
    if "OrderSend" in common:
        issues.append("ExecDemoCommon must not call OrderSend directly")
    if "ExecClosePosition" not in common or "ExecModifyStops" not in common:
        issues.append("ExecDemoCommon must route through ExecClosePosition/ExecModifyStops")
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


def check_probe(root: Path) -> list[str]:
    """The probe is the only code allowed to prove broker acceptance, so it
    must stay demo-only, tester-refusing and confirm-gated."""
    issues: list[str] = []
    code = _code_only(_read(root, EXEC_PROBE))

    if _input_default(code, "InpConfirm") != "false":
        issues.append("InpConfirm must default to false (no order without a hand edit)")
    for token in (
        "MQLInfoInteger(MQL_TESTER)",
        "MQLInfoInteger(MQL_TRADE_ALLOWED)",
        "ExecContextAllowed",
        "ExecSymbolAllowed",
        "ExecSymbolTradable",
        "ExecTakeProfitValid",
        "ExecStopsRespectBroker",
        "ExecMarginRequired",
        "ExecOpenMarket",
        "ExecClosePosition",
        "FileIsExist",
        "void OnStart",
    ):
        if token not in code:
            issues.append(f"probe must call {token}")
    if "OrderSend" in code:
        issues.append("probe must reach the broker only through ExecBroker.mqh")
    if "ExecBroker.mqh" not in _read(root, EXEC_PROBE):
        issues.append("probe must include ExecBroker.mqh")

    ea_code = _code_only(_read(root, DEMO_EA))
    probe_magic = re.search(r"InpMagicNumber\s*=\s*(\d+)", code)
    ea_magic = re.search(r"InpMagicNumber\s*=\s*(\d+)", ea_code)
    if probe_magic is None or ea_magic is None:
        issues.append("probe and DemoEA must declare an explicit magic default")
    elif probe_magic.group(1) == ea_magic.group(1):
        issues.append("probe magic must differ from the DemoEA magic")

    ea_kill = _input_default(ea_code, "InpKillSwitchFile")
    probe_kill = _input_default(code, "InpKillSwitchFile")
    if probe_kill in (None, '""'):
        issues.append("probe must name a kill-switch file")
    elif probe_kill != ea_kill:
        issues.append("probe and DemoEA must share one kill-switch file")
    return issues


def check_journal_watcher(root: Path) -> list[str]:
    """The demo journal watcher must stay a read-only consumer of the EA journal."""
    issues: list[str] = []
    path = root / JOURNAL_WATCHER
    if not path.is_file():
        return [f"missing {JOURNAL_WATCHER}"]
    text = path.read_text(encoding="utf-8")
    if FORBIDDEN_WATCHER.search(text):
        issues.append("journal watcher must not touch any trading API")

    state_path = re.search(r'DEFAULT_STATE_PATH\s*=\s*REPO_ROOT\s*/\s*"reports"', text)
    if state_path is None:
        issues.append("journal watcher must keep its checkpoint under reports/")

    spec = importlib.util.spec_from_file_location("watch_demo_journal", path)
    if spec is None or spec.loader is None:
        return issues + [f"cannot import {JOURNAL_WATCHER}"]
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    logger = _read(root, SIM_LOGGER)
    declared = re.search(r'SIM_LOG_HEADER\s+"([^"]+)"', logger)
    if declared is None:
        issues.append("SimLogger.mqh must declare SIM_LOG_HEADER")
    elif tuple(declared.group(1).split(",")) != tuple(module.EXPECTED_HEADER):
        issues.append("watcher columns must equal the SimLogger CSV header")

    ea_code = _code_only(_read(root, DEMO_EA))
    for constant, input_name in (
        ("JOURNAL_NAME", "InpLogFile"),
        ("KILL_SWITCH_NAME", "InpKillSwitchFile"),
    ):
        want = _input_default(ea_code, input_name)
        got = getattr(module, constant, None)
        if want is None or got is None:
            issues.append(f"watcher and DemoEA must both define {input_name}")
        elif got != want.strip('"'):
            issues.append(f"watcher {constant} must match the DemoEA {input_name}")

    emitted = set(re.findall(r'Event\("([A-Z_]+)"', ea_code))
    for event in module.ALERT_EVENTS:
        if event not in emitted:
            issues.append(f"watcher alerts on {event}, which the DemoEA never emits")
    for event in ("ENTRY", "EXIT"):
        if event not in module.ALERT_KINDS:
            issues.append(f"watcher must alert on real {event} rows")
    if set(module.ALERT_KINDS.values()) - {"ORDER", "FAULT"}:
        issues.append("watcher alert kinds must be ORDER or FAULT")
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
    if demo_inputs.get("InpEnableExecution") is not True:
        issues.append("demo preset must ship with InpEnableExecution=true (ADR 0006)")
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

    #--- ADR 0004: the Grid/DCA demo presets must be fail-closed too and must
    #--- keep their bounded-basket caps explicit.
    for relative, expected_ea in (
        (GRID_DEMO_PRESET, "GridDemoEA"),
        (DCA_DEMO_PRESET, "DCADemoEA"),
    ):
        name = Path(relative).name
        preset = json.loads(_read(root, relative))
        inputs = preset.get("inputs", {})
        if preset.get("ea") != expected_ea:
            issues.append(f"{name}: must target {expected_ea}")
        if preset.get("execution_mode") != "DEMO_ONLY":
            issues.append(f"{name}: execution_mode must be DEMO_ONLY")
        if preset.get("allow_live_trading") is not False:
            issues.append(f"{name}: allow_live_trading must be false")
        if inputs.get("InpEnableExecution") is not True:
            issues.append(f"{name}: must ship with InpEnableExecution=true (ADR 0006)")
        if "XAUUSD" not in str(inputs.get("InpAllowedSymbols", "")):
            issues.append(f"{name}: InpAllowedSymbols must allow XAUUSD")
        if not float(inputs.get("InpBasketStopPoints", 0.0)) > 0.0:
            issues.append(f"{name}: basket stop must be positive (mandatory SL)")
        if not float(inputs.get("InpMaxBasketLossPct", 0.0)) > 0.0:
            issues.append(f"{name}: basket loss budget must be positive")
        if not float(inputs.get("InpMaxExposure", 0.0)) > 0.0:
            issues.append(f"{name}: exposure cap must be positive")
        if inputs.get("InpHaltOnBreach") is not True:
            issues.append(f"{name}: InpHaltOnBreach must be true")
        issues.extend(
            f"{name}: {item}" for item in sim_configs.validate_preset(preset)
        )

    #--- ADR 0005: the InfiniteRunner demo preset is fail-closed too and pins
    #--- the runner-specific guards (single position, mandatory far safety TP,
    #--- hardened stop band).
    ir_name = Path(IR_DEMO_PRESET).name
    ir = json.loads(_read(root, IR_DEMO_PRESET))
    ir_inputs = ir.get("inputs", {})
    if ir.get("ea") != "InfiniteRunnerXAUV2DemoEA":
        issues.append(f"{ir_name}: must target InfiniteRunnerXAUV2DemoEA")
    if ir.get("execution_mode") != "DEMO_ONLY":
        issues.append(f"{ir_name}: execution_mode must be DEMO_ONLY")
    if ir.get("allow_live_trading") is not False:
        issues.append(f"{ir_name}: allow_live_trading must be false")
    if ir_inputs.get("InpEnableExecution") is not True:
        issues.append(f"{ir_name}: must ship with InpEnableExecution=true (ADR 0006)")
    if "XAUUSD" not in str(ir_inputs.get("InpAllowedSymbols", "")):
        issues.append(f"{ir_name}: InpAllowedSymbols must allow XAUUSD")
    if not float(ir_inputs.get("InpSafetyTpPoints", 0.0)) > 0.0:
        issues.append(f"{ir_name}: InpSafetyTpPoints must be positive (mandatory TP)")
    if ir_inputs.get("InpMaxPositions") != 1:
        issues.append(f"{ir_name}: InpMaxPositions must be 1")
    if not float(ir_inputs.get("InpMinStopPoints", 0.0)) > 0.0:
        issues.append(f"{ir_name}: InpMinStopPoints must be positive")
    issues.extend(
        f"{ir_name}: {item}" for item in sim_configs.validate_preset(ir)
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
    report("ADR 0004 scope", check_adr(root))
    report("demo EA guardrails", check_demo_ea(root))
    report("grid demo EA guardrails", check_demo_ea(root, GRID_DEMO_EA))
    report("dca demo EA guardrails", check_demo_ea(root, DCA_DEMO_EA))
    report("infinite runner demo EA guardrails", check_demo_ea(root, IR_DEMO_EA))
    report("bounded grid/DCA baskets", check_bounded_baskets(root))
    report("exec sources", check_exec_sources(root))
    report("demo order probe", check_probe(root))
    report("demo journal watcher", check_journal_watcher(root))
    report("demo and simulation presets", check_presets(root))
    report("demo guide", check_guide(root))

    print(f"SUMMARY: checks={checks} fail={failures}")
    print("Static checks only: nothing was compiled, no terminal was started and no broker was contacted.")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
