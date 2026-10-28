"""Static validation for the TM Fusion Zones PinePort sources and docs.

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
    "contract": "mt5/Include/PinePort/TMFusionZonesContract.mqh",
    "indicator": "mt5/Indicators/PinePort/TMFusionZones.mq5",
    "tests": "mt5/Scripts/TMFusionZonesContractTests.mq5",
    "spec": "docs/indicators/tm-fusion-zones.md",
    "audit": "docs/indicators/tm-fusion-zones.md",
    "buffer_contract": "docs/indicators/tm-fusion-zones.md",
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
    *(f"B{i}" for i in range(1, 6)),
    *(f"C{i}" for i in range(1, 7)),
    *(f"D{i}" for i in range(1, 5)),
    *(f"E{i}" for i in range(1, 6)),
    *(f"F{i}" for i in range(1, 10)),
    *(f"G{i}" for i in range(1, 6)),
    *(f"H{i}" for i in range(1, 5)),
    *(f"I{i}" for i in range(1, 6)),
    *(f"J{i}" for i in range(1, 6)),
    *(f"K{i}" for i in range(1, 6)),
    *(f"L{i}" for i in range(1, 8)),
    *(f"M{i}" for i in range(1, 8)),
    *(f"N{i}" for i in range(1, 9)),
    *(f"O{i}" for i in range(1, 3)),
}

EXPECTED_ENUMS = (
    ("ENUM_FZ_MA", [0, 1, 2]),
    ("ENUM_FZ_SL_MODE", [0, 1]),
    ("ENUM_FZ_TP_MODE", [0, 1]),
    ("ENUM_FZ_ASSET", [0, 1, 2, 3, 4, 5]),
    ("ENUM_FZ_HTF", [0, 1, 2, 3]),
    ("ENUM_FZ_SETUP", [0, 1, 2, 3]),
    ("ENUM_FZ_BLOCK", [0, 1, 2, 3, 4, 5, 6]),
    ("ENUM_FZ_REGIME", [0, 1, 2]),
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
        "FZ_PLOT_BUFFERS": 10,
        "FZ_CONTRACT_BUFFERS": 23,
        "FZ_TOTAL_BUFFERS": 33,
    }
    for name, expected in constants.items():
        if re.search(rf"#define\s+{name}\s+{expected}\b", text):
            checker.ok(f"contract declares {name} {expected}")
        else:
            checker.fail(f"contract does not declare {name} {expected}")

    block = re.search(r"enum\s+ENUM_FZ_BUFFER\s*\{(.*?)\};", text, re.S)
    if not block:
        checker.fail("contract has no ENUM_FZ_BUFFER")
    else:
        mapping = {
            name: int(value)
            for name, value in re.findall(r"(FZ_BUF_\w+)\s*=\s*(\d+)", block.group(1))
        }
        values = sorted(mapping.values())
        if len(mapping) == 23 and values == list(range(10, 33)):
            checker.ok("contract buffer enum covers 10..32 exactly once")
        else:
            checker.fail(f"contract buffer enum is not 10..32 exactly once: {values}")
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

    if 'FZ_CONTRACT_VERSION  "1.0.0"' in text:
        checker.ok("contract version is 1.0.0")
    else:
        checker.fail("contract version is not 1.0.0")
    return mapping


def check_indicator(checker: Checker, buffer_map: dict[str, int]) -> None:
    text = checker.read("indicator")
    if text is None:
        return

    if re.search(r"#property\s+indicator_buffers\s+33\b", text):
        checker.ok("indicator declares 33 buffers")
    else:
        checker.fail("indicator does not declare 33 buffers")
    if re.search(r"#property\s+indicator_plots\s+10\b", text):
        checker.ok("indicator declares 10 plots")
    else:
        checker.fail("indicator does not declare 10 plots")
    if "TMFusionZonesContract.mqh" in text:
        checker.ok("indicator includes TMFusionZonesContract.mqh")
    else:
        checker.fail("indicator does not include TMFusionZonesContract.mqh")

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
    if len(bindings) == 33 and indices == list(range(33)):
        checker.ok("indicator binds buffers 0..32 exactly once")
    else:
        checker.fail(f"indicator buffer bindings are not 0..32 exactly once: {indices}")

    data_ok = all(
        kind == "INDICATOR_DATA"
        for index, kind in bindings
        if 0 <= index < 10
    ) and len([1 for index, _ in bindings if 0 <= index < 10]) == 10
    calc_ok = all(
        kind == "INDICATOR_CALCULATIONS"
        for index, kind in bindings
        if 10 <= index < 33
    ) and len([1 for index, _ in bindings if 10 <= index < 33]) == 23
    if data_ok and calc_ok:
        checker.ok("buffers 0..9 are DATA plots and 10..32 are CALCULATIONS")
    else:
        checker.fail("buffer kinds do not match the 10 DATA / 23 CALC contract")

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
    if len(inputs) == 40:
        checker.ok("indicator declares exactly 40 inputs")
    else:
        checker.fail(f"indicator declares {len(inputs)} inputs, expected 40")


def check_tests(checker: Checker) -> None:
    text = checker.read("tests")
    if text is None:
        return

    ids = set(
        re.findall(
            r'"(A[1-5]|B[1-5]|C[1-6]|D[1-4]|E[1-5]|F[1-9]|G[1-5]|H[1-4]|'
            r'I[1-5]|J[1-5]|K[1-5]|L[1-7]|M[1-7]|N[1-8]|O[1-2])"',
            text,
        )
    )
    if ids == EXPECTED_TEST_IDS:
        checker.ok("contract test script contains all 82 test IDs")
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
        "indicator_buffers 33",
        "indicator_plots 10",
        "## 14. Test vector (82)",
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
        description="Static validation for TM Fusion Zones PinePort sources."
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
