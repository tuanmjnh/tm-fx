"""Static checks for the demo-only execution scope (ADR 0003)."""

from __future__ import annotations

import copy
import importlib.util
import json
import re
from pathlib import Path

import pytest

from mt5_ea_ai_lab.sim_configs import (
    DEMO_MODE,
    EA_EXECUTION_MODE,
    validate_preset,
    validate_project,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEMO_PRESET = REPO_ROOT / "configs" / "demo" / "pa_trendrider_xau_demo.json"
SIM_PRESET = REPO_ROOT / "configs" / "sim" / "pa_trendrider_xau.json"
PROJECT = REPO_ROOT / "configs" / "project.example.json"
DEMO_EA = REPO_ROOT / "mt5" / "Experts" / "PATrendRiderXAUv1DemoEA.mq5"


def _json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_script(name: str):
    path = REPO_ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_demo_preset_validates() -> None:
    config = _json(DEMO_PRESET)
    assert config["ea"] == "PATrendRiderXAUv1DemoEA"
    assert config["execution_mode"] == DEMO_MODE
    assert config["allow_live_trading"] is False
    assert validate_preset(config) == []


def test_demo_ea_requires_demo_mode() -> None:
    assert EA_EXECUTION_MODE["PATrendRiderXAUv1DemoEA"] == DEMO_MODE
    config = _json(DEMO_PRESET)
    config["execution_mode"] = "SIMULATION_ONLY"
    assert any("execution_mode" in issue for issue in validate_preset(config))

    sim = _json(SIM_PRESET)
    sim["execution_mode"] = DEMO_MODE
    assert any("execution_mode" in issue for issue in validate_preset(sim))


@pytest.mark.parametrize("mode", ["LIVE", "PAPER", "demo_only", ""])
def test_demo_preset_mode_is_fail_closed(mode: str) -> None:
    config = _json(DEMO_PRESET)
    config["execution_mode"] = mode
    assert any("execution_mode" in issue for issue in validate_preset(config))


def test_demo_preset_cannot_enable_live() -> None:
    config = _json(DEMO_PRESET)
    config["allow_live_trading"] = True
    assert any("allow_live_trading" in issue for issue in validate_preset(config))


def test_demo_preset_requires_take_profit() -> None:
    config = _json(DEMO_PRESET)
    del config["inputs"]["InpTakeProfitR"]
    assert any("InpTakeProfitR" in issue for issue in validate_preset(config))

    config = _json(DEMO_PRESET)
    config["inputs"]["InpTakeProfitR"] = 0.0
    assert any("InpTakeProfitR" in issue for issue in validate_preset(config))


def test_demo_preset_rejects_second_position() -> None:
    config = _json(DEMO_PRESET)
    config["inputs"]["InpMaxPositions"] = 2
    assert any("InpMaxPositions" in issue for issue in validate_preset(config))


def test_demo_preset_rejects_empty_symbol_list() -> None:
    config = _json(DEMO_PRESET)
    config["inputs"]["InpAllowedSymbols"] = ""
    assert any("InpAllowedSymbols" in issue for issue in validate_preset(config))


def test_demo_preset_inputs_match_ea_declarations() -> None:
    text = DEMO_EA.read_text(encoding="utf-8")
    declared = set(re.findall(r"^\s*input\s+\S+\s+(\w+)\s*=", text, re.MULTILINE))
    declared.discard("group")
    preset = set(_json(DEMO_PRESET)["inputs"])
    assert declared, "DemoEA must declare inputs"
    assert preset == declared


def test_demo_magic_differs_from_simulation() -> None:
    demo = _json(DEMO_PRESET)["inputs"]["InpMagicNumber"]
    sim = _json(SIM_PRESET)["inputs"]["InpMagicNumber"]
    assert demo != sim


def test_project_file_cannot_list_demo_ea() -> None:
    project = _json(PROJECT)
    project["presets"]["PATrendRiderXAUv1DemoEA"] = (
        "configs/demo/pa_trendrider_xau_demo.json"
    )
    assert any(
        "PATrendRiderXAUv1DemoEA" in issue
        for issue in validate_project(copy.deepcopy(project), REPO_ROOT)
    )


def test_demo_execution_validator_passes() -> None:
    script = _load_script("validate_demo_execution")
    assert script.main(["--root", str(REPO_ROOT)]) == 0


def test_project_validator_passes() -> None:
    script = _load_script("validate-project")
    assert script.main(["--root", str(REPO_ROOT)]) == 0
