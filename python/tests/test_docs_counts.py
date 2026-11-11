"""The EA/demo counts in the catalog docs must match the tree.

The repository is IR-only: ``mt5/Experts`` has exactly one ``.mq5``
(``InfiniteRunnerXAUV2DemoEA.mq5``) and ``configs/demo`` has exactly one preset.
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

REMOVED_BOT_NAMES = (
    "Wonderwhales",
    "PATrendRider",
    "GridDemoEA",
    "DCADemoEA",
)


def _text(relative: str) -> str:
    return (REPO_ROOT / relative).read_text(encoding="utf-8")


def test_experts_has_only_the_infinite_runner() -> None:
    experts = sorted(p.name for p in EXPERTS.glob("*.mq5"))
    assert experts == ["InfiniteRunnerXAUV2DemoEA.mq5"]


def test_demo_presets_map_to_experts() -> None:
    presets = sorted(DEMO_PRESETS.glob("*.json"))
    assert [p.name for p in presets] == ["infinite_runner_demo.json"]
    config = json.loads(presets[0].read_text(encoding="utf-8"))
    assert config["ea"] == "InfiniteRunnerXAUV2DemoEA"
    assert (EXPERTS / "InfiniteRunnerXAUV2DemoEA.mq5").is_file()


def test_catalog_docs_describe_an_ir_only_repo() -> None:
    for relative in CATALOG_DOCS:
        text = _text(relative)
        assert "InfiniteRunner" in text, f"{relative} must describe the IR bot"
        for removed in REMOVED_BOT_NAMES:
            assert removed not in text, f"{relative} still mentions {removed}"
        assert "configs/sim" not in text, f"{relative} still references configs/sim"
        for stale in ("6 bot demo", "5 bot demo", "16 EA", "17 "):
            assert stale not in text, f"{relative} still claims {stale!r}"
