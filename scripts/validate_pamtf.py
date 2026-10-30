"""Static validation for the Price Action MTF PinePort sources and docs.

Structure and safety only. This script never compiles, never runs MT5 and
never claims runtime or parity success.

Exit codes:
    0  every static check passed
    1  at least one check failed
    2  the project root could not be read
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "contract": "mt5/Include/PinePort/PriceActionMTFContract.mqh",
    "indicator": "mt5/Indicators/PinePort/PriceActionMTF.mq5",
    "tests": "mt5/Scripts/PriceActionMTFContractTests.mq5",
    "spec": "docs/indicators/price-action-mtf.md",
    "audit": "docs/indicators/price-action-mtf.md",
    "buffer_contract": "docs/indicators/price-action-mtf.md",
}

FORBIDDEN_API = re.compile(
    r"\b(OrderSend|OrderSendAsync|OrderCalcMargin|CTrade|MqlTradeRequest|"
    r"MqlTradeResult|MqlTradeCheckResult|PositionOpen|PositionClose|"
    r"PositionModify|WebRequest|SocketCreate|SocketConnect|AccountInfo|"
    r"AccountInfoInteger|AccountInfoDouble|AccountInfoString|"
    r"FileOpen|FileWrite|FileRead|TerminalInfoString|Alert|SendNotification|"
    r"SendMail)\b"
)

PLACEHOLDER = re.compile(r"\b(TODO|FIXME|TBD|PLACEHOLDER)\b")

EXPECTED_TEST_IDS = {
    *(f"A{i}" for i in range(1, 6)),
    *(f"B{i}" for i in range(1, 11)),
    *(f"C{i}" for i in range(1, 6)),
    *(f"D{i}" for i in range(1, 9)),
    *(f"E{i}" for i in range(1, 9)),
    *(f"F{i}" for i in range(1, 9)),
    *(f"G{i}" for i in range(1, 10)),
    *(f"H{i}" for i in range(1, 11)),
    *(f"I{i}" for i in range(1, 10)),
    *(f"J{i}" for i in range(1, 14)),
    *(f"K{i}" for i in range(1, 8)),
    *(f"L{i}" for i in range(1, 11)),
    *(f"M{i}" for i in range(1, 11)),
    *(f"N{i}" for i in range(1, 6)),
    *(f"O{i}" for i in range(1, 4)),
    *(f"P{i}" for i in range(1, 5)),
}

EXPECTED_ENUMS = (
    ("ENUM_PA_TP_MODE", [0, 1]),
    ("ENUM_PA_QUALITY", [0, 1, 2, 3, 4]),
    ("ENUM_PA_REGIME", [0, 1, 2]),
    ("ENUM_PA_PATTERN", [0, 1, 2, 3, 4]),
    ("ENUM_PA_BUCKET", [0, 1, 2, 3, 4, 5]),
    ("ENUM_PA_SESSION", [0, 1, 2, 3, 4]),
    ("ENUM_PA_CLOSE", [0, 1, 2, 3]),
    ("ENUM_PA_BLOCK", list(range(10))),
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

    constants = {
        "PA_PLOT_BUFFERS": 12,
        "PA_CONTRACT_BUFFERS": 95,
        "PA_TOTAL_BUFFERS": 107,
    }
    for name, expected in constants.items():
        if re.search(rf"#define\s+{name}\s+{expected}\b", text):
            checker.ok(f"contract declares {name} {expected}")
        else:
            checker.fail(f"contract does not declare {name} {expected}")

    block = re.search(r"enum\s+ENUM_PA_BUFFER\s*\{(.*?)\};", text, re.S)
    if not block:
        checker.fail("contract has no ENUM_PA_BUFFER")
    else:
        mapping = {
            name: int(value)
            for name, value in re.findall(r"(PA_BUF_\w+)\s*=\s*(\d+)", block.group(1))
        }
        values = sorted(mapping.values())
        if len(mapping) == 95 and values == list(range(12, 107)):
            checker.ok("contract buffer enum covers 12..106 exactly once")
        else:
            checker.fail(f"contract buffer enum is not 12..106 exactly once: {values}")
            mapping = {}

    for enum_name, expected in EXPECTED_ENUMS:
        match = re.search(rf"enum\s+{enum_name}\s*\{{(.*?)\}};", text, re.S)
        if not match:
            checker.fail(f"contract has no {enum_name}")
            continue
        values = sorted(
            int(value) for value in re.findall(r"=\s*(\d+)", match.group(1))
        )
        if values == expected:
            checker.ok(f"{enum_name} covers {expected}")
        else:
            checker.fail(f"{enum_name} values differ: {values}")

    if 'PA_CONTRACT_VERSION   "1.0.0"' in text:
        checker.ok("contract version is 1.0.0")
    else:
        checker.fail("contract version is not 1.0.0")
    return mapping


def check_indicator(checker: Checker, buffer_map: dict[str, int]) -> None:
    text = checker.read("indicator")
    if text is None:
        return

    if re.search(r"#property\s+indicator_buffers\s+107\b", text):
        checker.ok("indicator declares 107 buffers")
    else:
        checker.fail("indicator does not declare 107 buffers")
    if re.search(r"#property\s+indicator_plots\s+12\b", text):
        checker.ok("indicator declares 12 plots")
    else:
        checker.fail("indicator does not declare 12 plots")
    if "PriceActionMTFContract.mqh" in text:
        checker.ok("indicator includes PriceActionMTFContract.mqh")
    else:
        checker.fail("indicator does not include PriceActionMTFContract.mqh")

    raw_bindings = re.findall(
        r"SetIndexBuffer\s*\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(INDICATOR_\w+)\s*\)",
        text,
    )
    bindings: list[tuple[int, str]] = []
    unknown: list[str] = []
    for name, _array, kind in raw_bindings:
        if name.isdigit():
            index = int(name)
        elif name in buffer_map:
            index = buffer_map[name]
        else:
            unknown.append(name)
            continue
        bindings.append((index, kind))
    if unknown:
        checker.fail(
            f"indicator binds unknown buffer names: {', '.join(sorted(set(unknown)))}"
        )

    indices = sorted(index for index, _ in bindings)
    if len(bindings) == 107 and indices == list(range(107)):
        checker.ok("indicator binds buffers 0..106 exactly once")
    else:
        checker.fail(f"indicator buffer bindings are not 0..106 exactly once: {indices}")

    data_ok = all(
        kind == "INDICATOR_DATA"
        for index, kind in bindings
        if 0 <= index < 12
    ) and len([1 for index, _ in bindings if 0 <= index < 12]) == 12
    calc_ok = all(
        kind == "INDICATOR_CALCULATIONS"
        for index, kind in bindings
        if 12 <= index < 107
    ) and len([1 for index, _ in bindings if 12 <= index < 107]) == 95
    if data_ok and calc_ok:
        checker.ok("buffers 0..11 are DATA plots and 12..106 are CALCULATIONS")
    else:
        checker.fail("buffer kinds do not match the 12 DATA / 95 CALC contract")

    if re.search(r"lastClosed\s*=\s*total\s*-\s*2", text) and re.search(
        r"j\s*<=\s*lastClosed", text
    ):
        checker.ok("indicator replays closed bars only")
    else:
        checker.fail("indicator does not gate the replay to closed bars")

    if re.search(r"input\s+\w+\s+\w*[Cc]onfirm\w*", text):
        checker.fail("indicator declares a confirm-mode input; it must not be ported")
    else:
        checker.ok("indicator has no confirm-mode input")

    inputs = re.findall(r"^input\s+", text, re.M)
    if len(inputs) == 117:
        checker.ok("indicator declares exactly 117 inputs (115 Pine-parity + 2 bridge)")
    else:
        checker.fail(f"indicator declares {len(inputs)} inputs, expected 117")

    # The two EA bridge inputs must stay first: iCustom passes parameters by
    # position, so anything declared above them (including an `input group`
    # line) would shift the mapping.
    if re.search(r"^input group\b", text, re.M):
        checker.fail("indicator declares an input group; it consumes an iCustom slot")
    else:
        checker.ok("indicator declares no input group")

    first_inputs = re.findall(r"^input\s+\w+\s+(\w+)\s*=", text, re.M)[:2]
    if first_inputs == ["InpRr1Ea", "InpRrMinEa"]:
        checker.ok("EA bridge inputs InpRr1Ea/InpRrMinEa are the first two inputs")
    else:
        checker.fail(f"first two inputs are {first_inputs}, expected the EA bridge")


def check_tests(checker: Checker) -> None:
    text = checker.read("tests")
    if text is None:
        return

    ids = set(
        re.findall(
            r'"(A[1-5]|B(?:10|[1-9])|C[1-5]|D[1-8]|E[1-8]|F[1-8]|G[1-9]|'
            r'H(?:10|[1-9])|I[1-9]|J(?:1[0-3]|[1-9])|K[1-7]|L(?:10|[1-9])|'
            r'M(?:10|[1-9])|N[1-5]|O[1-3]|P[1-4])"',
            text,
        )
    )
    if ids == EXPECTED_TEST_IDS:
        checker.ok("contract test script contains all 124 test IDs")
    else:
        missing = sorted(EXPECTED_TEST_IDS - ids)
        extra = sorted(ids - EXPECTED_TEST_IDS)
        checker.fail(f"contract test IDs differ; missing={missing} extra={extra}")

    if "TEST|RESULT|" in text and "ALL_PASS" in text:
        checker.ok("contract test script prints TEST|RESULT|ALL_PASS")
    else:
        checker.fail("contract test script does not print the ALL_PASS marker")


def check_docs(checker: Checker) -> None:
    text = checker.read("buffer_contract")
    if text is None:
        return

    expected_phrases = (
        "indicator_buffers 107",
        "indicator_plots 12",
        "## 14. Test vector",
        "NOT_IMPLEMENTED",
        "BLOCKED",
    )
    for phrase in expected_phrases:
        if phrase in text:
            checker.ok(f"buffer contract states {phrase}")
        else:
            checker.fail(f"buffer contract is missing {phrase}")


def check_safety(checker: Checker) -> None:
    for key in ("contract", "indicator", "tests"):
        text = checker.read(key)
        if text is None:
            continue
        api = sorted(set(FORBIDDEN_API.findall(text)))
        if api:
            checker.fail(f"{key}: forbidden API tokens: {', '.join(api)}")
        else:
            checker.ok(f"{key}: no forbidden trading/broker/file API")
        placeholder = sorted(set(PLACEHOLDER.findall(text)))
        if placeholder:
            checker.fail(f"{key}: placeholder tokens: {', '.join(placeholder)}")
        else:
            checker.ok(f"{key}: no placeholder tokens")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Static validation for Price Action MTF PinePort sources."
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

    buffer_map = check_contract(checker)
    check_indicator(checker, buffer_map)
    check_tests(checker)
    check_docs(checker)
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
