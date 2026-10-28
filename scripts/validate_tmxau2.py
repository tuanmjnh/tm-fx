"""Static validation for the TM XAU Signals 2 PinePort sources and docs.

Checks V1-V14 of docs/indicators/tm-xau-signals-2.md section 15.
Structure and safety only: this script never compiles, never runs MT5 and
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
    "contract": "mt5/Include/PinePort/TMXAUSignals2Contract.mqh",
    "indicator": "mt5/Indicators/PinePort/TMXAUSignals2.mq5",
    "tests": "mt5/Scripts/TMXAUSignals2ContractTests.mq5",
    "buffer_contract": "docs/indicators/tm-xau-signals-2.md",
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
    *(f"A{i}" for i in range(1, 7)),
    *(f"B{i}" for i in range(1, 11)),
    *(f"C{i}" for i in range(1, 7)),
    *(f"D{i}" for i in range(1, 9)),
    *(f"E{i}" for i in range(1, 6)),
    *(f"F{i}" for i in range(1, 10)),
    *(f"G{i}" for i in range(1, 9)),
    *(f"H{i}" for i in range(1, 11)),
    *(f"I{i}" for i in range(1, 9)),
    *(f"J{i}" for i in range(1, 6)),
    *(f"K{i}" for i in range(1, 10)),
    *(f"L{i}" for i in range(1, 12)),
    *(f"M{i}" for i in range(1, 4)),
    *(f"N{i}" for i in range(1, 5)),
    *(f"O{i}" for i in range(1, 4)),
}

EXPECTED_ENUMS = (
    ("ENUM_X2_QUALITY", list(range(5))),
    ("ENUM_X2_BUCKET", list(range(6))),
    ("ENUM_X2_SESSION", list(range(5))),
    ("ENUM_X2_CLOSE", list(range(4))),
    ("ENUM_X2_BLOCK", list(range(8))),
    ("ENUM_X2_EVENT", list(range(9))),
)


def parse_enum(text: str, name: str) -> dict[str, int] | None:
    match = re.search(rf"enum\s+{name}\s*\{{(.*?)\}};", text, re.S)
    if not match:
        return None
    mapping: dict[str, int] = {}
    current = -1
    for entry in match.group(1).split(","):
        entry = entry.strip()
        if not entry:
            continue
        item = re.match(r"(\w+)\s*(?:=\s*(\d+))?", entry)
        if not item:
            continue
        current = int(item.group(2)) if item.group(2) else current + 1
        mapping[item.group(1)] = current
    return mapping


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
        "X2_PLOT_BUFFERS": 13,
        "X2_CONTRACT_BUFFERS": 140,
        "X2_TOTAL_BUFFERS": 153,
    }
    for name, expected in constants.items():
        if re.search(rf"#define\s+{name}\s+{expected}\b", text):
            checker.ok(f"V1 contract declares {name} {expected}")
        else:
            checker.fail(f"V1 contract does not declare {name} {expected}")

    enum_map = parse_enum(text, "ENUM_X2_BUFFER")
    if enum_map is None:
        checker.fail("V2 contract has no ENUM_X2_BUFFER")
    else:
        mapping = {name: value for name, value in enum_map.items()
                   if name.startswith("X2_BUF_")}
        values = sorted(mapping.values())
        if len(mapping) == 140 and values == list(range(13, 153)):
            checker.ok("V2 buffer enum covers 13..152 exactly once")
        else:
            checker.fail(
                f"V2 buffer enum is not 140 entries over 13..152: "
                f"count={len(mapping)}"
            )
            mapping = {}

    for enum_name, expected in EXPECTED_ENUMS:
        enum_map = parse_enum(text, enum_name)
        if enum_map is None:
            checker.fail(f"V3 contract has no {enum_name}")
            continue
        values = sorted(enum_map.values())
        if values == expected:
            checker.ok(f"V3 {enum_name} covers {expected[0]}..{expected[-1]}")
        else:
            checker.fail(f"V3 {enum_name} values differ: {values}")

    if re.search(r'#define\s+X2_CONTRACT_VERSION\s+"1\.0\.0"', text):
        checker.ok("V4 contract version is 1.0.0")
    else:
        checker.fail("V4 contract version is not 1.0.0")
    return mapping


def check_indicator(checker: Checker, buffer_map: dict[str, int]) -> None:
    text = checker.read("indicator")
    if text is None:
        return

    if re.search(r"#property\s+indicator_buffers\s+153\b", text):
        checker.ok("V5 indicator declares 153 buffers")
    else:
        checker.fail("V5 indicator does not declare 153 buffers")
    if re.search(r"#property\s+indicator_plots\s+13\b", text):
        checker.ok("V5 indicator declares 13 plots")
    else:
        checker.fail("V5 indicator does not declare 13 plots")
    if "TMXAUSignals2Contract.mqh" in text:
        checker.ok("V5 indicator includes TMXAUSignals2Contract.mqh")
    else:
        checker.fail("V5 indicator does not include TMXAUSignals2Contract.mqh")

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
            f"V6 indicator binds unknown buffer names: {', '.join(sorted(set(unknown)))}"
        )

    indices = sorted(index for index, _ in bindings)
    if len(bindings) == 153 and indices == list(range(153)):
        checker.ok("V6 indicator binds buffers 0..152 exactly once")
    else:
        checker.fail(
            f"V6 indicator buffer bindings are not 0..152 exactly once: {indices}"
        )

    data_ok = all(
        kind == "INDICATOR_DATA"
        for index, kind in bindings
        if 0 <= index < 13
    ) and len([1 for index, _ in bindings if 0 <= index < 13]) == 13
    calc_ok = all(
        kind == "INDICATOR_CALCULATIONS"
        for index, kind in bindings
        if 13 <= index < 153
    ) and len([1 for index, _ in bindings if 13 <= index < 153]) == 140
    if data_ok and calc_ok:
        checker.ok("V6 buffers 0..12 are DATA plots and 13..152 are CALCULATIONS")
    else:
        checker.fail("V6 buffer kinds do not match the 13 DATA / 140 CALC contract")

    if re.search(r"lastClosed\s*=\s*total\s*-\s*2", text) and re.search(
        r"j\s*<=\s*lastClosed", text
    ):
        checker.ok("V7 indicator replays closed bars only")
    else:
        checker.fail("V7 indicator does not gate the replay to closed bars")

    if re.search(r"input\s+\w+\s+\w*[Cc]onfirm\w*", text):
        checker.fail("V8 indicator declares a confirm-mode input")
    else:
        checker.ok("V8 indicator has no confirm-mode input")

    inputs = re.findall(r"^input\s+", text, re.M)
    if len(inputs) == 90:
        checker.ok("V9 indicator declares exactly 90 inputs")
    else:
        checker.fail(f"V9 indicator declares {len(inputs)} inputs, expected 90")


def check_tests(checker: Checker) -> None:
    text = checker.read("tests")
    if text is None:
        return

    ids = set(re.findall(r'Record\("([A-Z]\d+[a-z]?)"', text))
    missing = sorted(EXPECTED_TEST_IDS - ids)
    if not missing:
        checker.ok(f"V10 contract test script covers all {len(EXPECTED_TEST_IDS)} vectors")
    else:
        checker.fail(f"V10 contract test IDs missing: {missing}")

    if "TEST|RESULT|" in text and "ALL_PASS" in text:
        checker.ok("V11 contract test script prints TEST|RESULT|ALL_PASS")
    else:
        checker.fail("V11 contract test script does not print the ALL_PASS marker")


def check_docs(checker: Checker) -> None:
    text = checker.read("buffer_contract")
    if text is None:
        return

    expected_phrases = (
        "indicator_buffers 153",
        "## 14. Test vector",
        "NOT_IMPLEMENTED",
        "BLOCKED",
    )
    for phrase in expected_phrases:
        if phrase in text:
            checker.ok(f"V12 buffer contract states {phrase}")
        else:
            checker.fail(f"V12 buffer contract is missing {phrase}")


def check_safety(checker: Checker) -> None:
    for key in ("contract", "indicator", "tests"):
        text = checker.read(key)
        if text is None:
            continue
        api = sorted(set(FORBIDDEN_API.findall(text)))
        if api:
            checker.fail(f"V13 {key}: forbidden API tokens: {', '.join(api)}")
        else:
            checker.ok(f"V13 {key}: no forbidden trading/broker/file API")
        placeholder = sorted(set(PLACEHOLDER.findall(text)))
        if placeholder:
            checker.fail(f"V14 {key}: placeholder tokens: {', '.join(placeholder)}")
        else:
            checker.ok(f"V14 {key}: no placeholder tokens")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Static validation for TM XAU Signals 2 PinePort sources."
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
