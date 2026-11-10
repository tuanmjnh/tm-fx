"""T1.1: the EA/demo counts in the catalog docs must match the tree.

One convention, enforced: 16 EA (6 demo + 10 lab) plus one dump-tester helper, so
mt5/Experts has 17 .mq5 and configs/demo has one preset per demo EA.
"""
from __future__ import annotations

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
EXPERTS = REPO_ROOT / "mt5" / "Experts"
DEMO_PRESETS = REPO_ROOT / "configs" / "demo"
CATALOG_DOCS = (
    "README.md",
    "docs/README.md",
    "docs/10-bots/README.md",
    "docs/00-start/roadmap.md",
)


def _text(relative: str) -> str:
    return (REPO_ROOT / relative).read_text(encoding="utf-8")


def _demo_eas() -> set[str]:
    names = set()
    for preset in DEMO_PRESETS.glob("*.json"):
        names.add(json.loads(preset.read_text(encoding="utf-8"))["ea"])
    return names


def test_demo_presets_map_to_experts() -> None:
    demo = _demo_eas()
    assert len(demo) == 6
    for ea in demo:
        assert (EXPERTS / f"{ea}.mq5").is_file(), ea


def test_expert_count_and_helper() -> None:
    experts = sorted(p.name for p in EXPERTS.glob("*.mq5"))
    demo = _demo_eas()
    assert len(experts) == 17
    #--- 16 EA = 6 demo + 10 lab, plus exactly one dump-tester helper.
    assert len(experts) == len(demo) + 10 + 1
    assert "WonderwhalesDumpTesterEA.mq5" in experts


def test_catalog_docs_use_the_canonical_counts() -> None:
    for relative in CATALOG_DOCS:
        text = _text(relative)
        assert "5 bot demo" not in text, relative
        assert "5 EA demo" not in text, relative
        assert "15 EA" not in text, relative
    for relative, needle in (
        ("README.md", "6 bot demo"),
        ("README.md", "16 EA"),
        ("docs/README.md", "6 bot demo"),
        ("docs/README.md", "16 EA"),
        ("docs/10-bots/README.md", "16 EA"),
        ("docs/10-bots/README.md", "6 EA demo"),
    ):
        assert needle in _text(relative), f"{relative} missing {needle!r}"
