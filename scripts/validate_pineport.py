"""Static validation for the Wonderwhales PinePort sources and docs.

This script checks structure and safety rules only. It never compiles, never
runs MT5 and never claims runtime or parity success.

Exit codes:
    0  every static check passed
    1  at least one check failed
    2  the project root or a required file could not be read
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "contract": "mt5/Include/PinePort/WonderwhalesContract.mqh",
    "indicator": "mt5/Indicators/PinePort/Wonderwhales.mq5",
    "ea": "mt5/Experts/PineSignalLabEA.mq5",
    "tests": "mt5/Scripts/WonderwhalesContractTests.mq5",
    "spec": "docs/indicators/wonderwhales.md",
    "audit": "docs/indicators/wonderwhales.md",
    "buffer_contract": "docs/indicators/wonderwhales.md",
    "parity": "docs/indicators/parity.md",
    "comparator": "scripts/compare_pine_exports.py",
    "parity_module": "python/src/mt5_ea_ai_lab/evaluation/pine_parity.py",
    "parity_tests": "python/tests/test_pine_parity.py",
}

FORBIDDEN_API = re.compile(
    r"\b(OrderSend|OrderSendAsync|OrderCalcMargin|CTrade|MqlTradeRequest|"
    r"MqlTradeResult|MqlTradeCheckResult|PositionOpen|PositionClose|"
    r"PositionModify|WebRequest|SocketCreate|SocketConnect|AccountInfo|"
    r"AccountInfoInteger|AccountInfoDouble|AccountInfoString|"
    r"TerminalInfoString\s*\(\s*TERMINAL_PASSWORD)\b"
)

PLACEHOLDER = re.compile(r"\b(TODO|FIXME|TBD|PLACEHOLDER|NOT_IMPLEMENTED)\b")

EXPECTED_TEST_IDS = {
    *(f"A{i}" for i in range(1, 10)),
    *(f"B{i}" for i in range(1, 11)),
    *(f"C{i}" for i in range(1, 5)),
    *(f"D{i}" for i in range(1, 8)),
    *(f"E{i}" for i in range(1, 7)),
}

EXPECTED_CSV_HEADER = (
    "detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,"
    "signal_id,side,sar_dir,psar,fast,slow,atr_pct,input_hash"
)


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.failures: list[str] = []
        self.passes: list[str] = []

    def fail(self, message: str) -> None:
        self.failures.append(message)
        print(f"FAIL: {message}")

    def ok(self, message: str) -> None:
        self.passes.append(message)
        print(f"PASS: {message}")

    def read(self, key: str) -> str | None:
        path = self.root / FILES[key]
        if not path.exists():
            self.fail(f"{key}: missing {FILES[key]}")
            return None
        try:
            return path.read_text(encoding="utf-8")
        except OSError as exc:
            self.fail(f"{key}: cannot read {FILES[key]}: {exc}")
            return None


def check_contract(checker: Checker) -> dict[str, int]:
    text = checker.read("contract")
    mapping: dict[str, int] = {}
    if text is None:
        return mapping

    if re.search(r"#define\s+WW_BUFFER_COUNT\s+18\b", text):
        checker.ok("contract declares WW_BUFFER_COUNT 18")
    else:
        checker.fail("contract does not declare WW_BUFFER_COUNT 18")

    block = re.search(r"enum\s+ENUM_WW_BUFFER\s*\{(.*?)\};", text, re.S)
    if not block:
        checker.fail("contract has no ENUM_WW_BUFFER")
    else:
        mapping = {
            name: int(value)
            for name, value in re.findall(r"(WW_BUF_\w+)\s*=\s*(\d+)", block.group(1))
        }
        values = sorted(mapping.values())
        if len(mapping) == 18 and values == list(range(18)):
            checker.ok("contract buffer enum covers 0..17 exactly once")
        else:
            checker.fail(f"contract buffer enum is not 0..17 exactly once: {values}")
            mapping = {}

    mode_block = re.search(r"enum\s+ENUM_WW_MODE\s*\{(.*?)\};", text, re.S)
    if not mode_block:
        checker.fail("contract has no ENUM_WW_MODE")
    else:
        values = [int(value) for value in re.findall(r"WW_MODE_\w+\s*=\s*(\d+)", mode_block.group(1))]
        if sorted(values) == [0, 1, 2, 3]:
            checker.ok("contract mode enum covers 0..3")
        else:
            checker.fail(f"contract mode enum is not 0..3: {values}")

    if 'WW_CONTRACT_VERSION "1.0.0"' in text:
        checker.ok("contract version is 1.0.0")
    else:
        checker.fail("contract version is not 1.0.0")
    return mapping


def check_indicator(checker: Checker, buffer_map: dict[str, int]) -> None:
    text = checker.read("indicator")
    if text is None:
        return

    if re.search(r"#property\s+indicator_buffers\s+18\b", text):
        checker.ok("indicator declares 18 buffers")
    else:
        checker.fail("indicator does not declare 18 buffers")
    if re.search(r"#property\s+indicator_plots\s+3\b", text):
        checker.ok("indicator declares 3 plots")
    else:
        checker.fail("indicator does not declare 3 plots")
    if "WonderwhalesContract.mqh" in text:
        checker.ok("indicator includes WonderwhalesContract.mqh")
    else:
        checker.fail("indicator does not include WonderwhalesContract.mqh")

    raw_bindings = re.findall(
        r"SetIndexBuffer\s*\(\s*(WW_BUF_\w+)\s*,\s*(\w+)\s*,\s*(INDICATOR_\w+)\s*\)",
        text,
    )
    bindings: list[tuple[int, str, str]] = []
    unknown: list[str] = []
    for name, array, kind in raw_bindings:
        if name not in buffer_map:
            unknown.append(name)
            continue
        bindings.append((buffer_map[name], array, kind))
    if unknown:
        checker.fail(f"indicator binds unknown buffer names: {', '.join(sorted(set(unknown)))}")

    indices = [index for index, _, _ in bindings]
    if len(indices) == 18 and sorted(indices) == list(range(18)):
        checker.ok("indicator binds buffers 0..17 exactly once")
    else:
        checker.fail(f"indicator buffer bindings are not 0..17 exactly once: {sorted(indices)}")

    plot_ok = True
    for index in (0, 1, 2):
        match = next((item for item in bindings if item[0] == index), None)
        if match is None or match[2] != "INDICATOR_DATA":
            plot_ok = False
            checker.fail(f"indicator plot buffer {index} is not INDICATOR_DATA")
    if plot_ok:
        checker.ok("indicator plot buffers 0..2 are INDICATOR_DATA")

    if re.search(r"CopyBuffer\s*\(\s*g_bb_handle\s*,\s*0\b", text) and \
       re.search(r"CopyBuffer\s*\(\s*g_bb_handle\s*,\s*1\b", text) and \
       re.search(r"CopyBuffer\s*\(\s*g_bb_handle\s*,\s*2\b", text):
        checker.ok("indicator reads iBands buffers 0/1/2")
    else:
        checker.fail("indicator does not read iBands buffers 0/1/2")
    if re.search(r"input\s+\w+\s+\w*[Cc]onfirm\w*", text):
        checker.fail("indicator declares a confirm-mode input; confirmOnClose must not be ported")
    else:
        checker.ok("indicator has no confirm-mode input")
    if re.search(r"confirmed\s*=\s*\(?\s*j\s*<\s*rates_total\s*-\s*1", text):
        checker.ok("indicator gates signals to closed bars")
    else:
        checker.fail("indicator does not gate signals to closed bars")


def check_ea(checker: Checker) -> None:
    text = checker.read("ea")
    if text is None:
        return

    if re.search(r'iCustom\s*\([^;]*?"PinePort\\\\Wonderwhales"', text, re.S):
        checker.ok("EA calls iCustom(\"PinePort\\\\Wonderwhales\")")
    else:
        checker.fail("EA does not call iCustom with PinePort\\Wonderwhales")

    for name in ("WW_BUF_BUY_SIGNAL", "WW_BUF_SELL_SIGNAL", "WW_BUF_SAR_DIR"):
        if re.search(
            rf"CopyBuffer\s*\(\s*g_handle\s*,\s*{name}\s*,\s*1\s*,\s*1\b", text
        ):
            checker.ok(f"EA reads {name} at shift=1")
        else:
            checker.fail(f"EA does not read {name} at shift=1")

    if EXPECTED_CSV_HEADER in text:
        checker.ok("EA CSV header matches the 14-column schema")
    else:
        checker.fail("EA CSV header does not match the documented schema")

    expected_inputs = [
        "InpMode",
        "InpPsarStart",
        "InpPsarInc",
        "InpPsarMax",
        "InpFastEma",
        "InpSlowEma",
        "InpEma200",
        "InpAtrLen",
        "InpMinAtrPct",
        "InpVolMaLen",
        "InpRsiLen",
        "InpBbLen",
        "InpBbMult",
    ]
    missing = [name for name in expected_inputs if f"input " not in text or name not in text]
    if missing:
        checker.fail(f"EA is missing config inputs: {', '.join(missing)}")
    else:
        checker.ok("EA declares all 13 contract inputs")


def check_tests(checker: Checker) -> None:
    text = checker.read("tests")
    if text is None:
        return

    ids = set(re.findall(r'"(A[1-9]|B10|B[1-9]|C[1-4]|D[1-7]|E[1-6])"', text))
    if ids == EXPECTED_TEST_IDS:
        checker.ok("contract test script contains all 36 test IDs")
    else:
        missing = sorted(EXPECTED_TEST_IDS - ids)
        extra = sorted(ids - EXPECTED_TEST_IDS)
        checker.fail(f"contract test IDs differ; missing={missing} extra={extra}")
    if "TEST|RESULT|" in text and "ALL_PASS" in text:
        checker.ok("contract test script prints TEST|RESULT|ALL_PASS")
    else:
        checker.fail("contract test script does not print the ALL_PASS marker")


def check_safety(checker: Checker) -> None:
    for key in ("contract", "indicator", "ea", "tests", "comparator", "parity_module"):
        text = checker.read(key)
        if text is None:
            continue
        api = sorted(set(FORBIDDEN_API.findall(text)))
        if api:
            checker.fail(f"{key}: forbidden API tokens: {', '.join(api)}")
        else:
            checker.ok(f"{key}: no forbidden trading/broker API")
        placeholder = sorted(set(PLACEHOLDER.findall(text)))
        if placeholder:
            checker.fail(f"{key}: placeholder tokens: {', '.join(placeholder)}")
        else:
            checker.ok(f"{key}: no placeholder tokens")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Static validation for Wonderwhales PinePort sources."
    )
    parser.add_argument(
        "--root",
        default=str(REPO_ROOT),
        help="repository root (default: parent of this script)",
    )
    args = parser.parse_args(argv)

    root = Path(args.root)
    if not root.exists():
        print(f"ERROR: root does not exist: {root}", file=sys.stderr)
        return 2

    checker = Checker(root)
    for key, relative in FILES.items():
        if not (root / relative).exists():
            checker.fail(f"{key}: missing {relative}")

    check_contract_state = check_contract(checker)
    check_indicator(checker, check_contract_state)
    check_ea(checker)
    check_tests(checker)
    check_safety(checker)

    print("")
    if checker.failures:
        print(
            f"VALIDATION_FAILED: pass={len(checker.passes)} fail={len(checker.failures)}"
        )
        return 1
    print(f"VALIDATION_OK: pass={len(checker.passes)} fail=0")
    print("Static checks only; compile/runtime/parity status is reported separately.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
