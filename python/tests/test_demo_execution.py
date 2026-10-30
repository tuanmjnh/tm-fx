"""Static checks for the demo-only execution scope (ADR 0004)."""

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

#--- ADR 0004 + 0005: one demo EA per strategy, each with its own preset.
DEMO_EA_PRESETS = (
    ("PATrendRiderXAUv1DemoEA", "patrendriderxauv1demo", DEMO_PRESET),
    ("GridDemoEA", "griddemo", REPO_ROOT / "configs" / "demo" / "grid_demo.json"),
    ("DCADemoEA", "dcademo", REPO_ROOT / "configs" / "demo" / "dca_demo.json"),
    (
        "InfiniteRunnerXAUV2DemoEA",
        "infiniterunnerxauv2demo",
        REPO_ROOT / "configs" / "demo" / "infinite_runner_demo.json",
    ),
)


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


@pytest.mark.parametrize("ea,slug,preset_path", DEMO_EA_PRESETS)
def test_every_demo_preset_is_fail_closed(
    ea: str, slug: str, preset_path: Path
) -> None:
    """ADR 0004+0006: each bot has a demo preset that is valid and ships with
    execution enabled by default (set InpEnableExecution=false for dry-run)."""
    assert EA_EXECUTION_MODE[ea] == DEMO_MODE
    config = _json(preset_path)
    assert config["ea"] == ea
    assert config["execution_mode"] == DEMO_MODE
    assert config["allow_live_trading"] is False
    assert config["inputs"]["InpEnableExecution"] is True
    assert "XAUUSD" in config["inputs"]["InpAllowedSymbols"]
    assert validate_preset(config) == []

    config["inputs"]["InpEnableExecution"] = True
    #--- Enabling execution is allowed on demo; the demo-only mode still holds.
    assert config["execution_mode"] == DEMO_MODE


@pytest.mark.parametrize("ea,slug,preset_path", DEMO_EA_PRESETS)
def test_every_demo_preset_matches_ea_inputs(
    ea: str, slug: str, preset_path: Path
) -> None:
    ea_path = REPO_ROOT / "mt5" / "Experts" / f"{ea}.mq5"
    text = ea_path.read_text(encoding="utf-8")
    declared = set(re.findall(r"^\s*input\s+\S+\s+(\w+)\s*=", text, re.MULTILINE))
    declared.discard("group")
    preset = set(_json(preset_path)["inputs"])
    assert declared, f"{ea} must declare inputs"
    assert preset == declared


def test_demo_eas_use_distinct_magics() -> None:
    magics = [
        _json(preset_path)["inputs"]["InpMagicNumber"]
        for _, _, preset_path in DEMO_EA_PRESETS
    ]
    assert len(set(magics)) == len(magics)


def test_grid_and_dca_demo_keep_bounded_caps() -> None:
    """A demo basket must stay bounded: level/add count, volume and loss budget."""
    grid = _json(REPO_ROOT / "configs" / "demo" / "grid_demo.json")["inputs"]
    dca = _json(REPO_ROOT / "configs" / "demo" / "dca_demo.json")["inputs"]
    assert 1 <= grid["InpMaxGridLevels"] <= 50
    assert 0 <= dca["InpMaxDcaAdds"] <= 50
    for inputs in (grid, dca):
        assert inputs["InpMaxBasketLossPct"] > 0.0
        assert inputs["InpBasketStopPoints"] > 0.0
        assert inputs["InpMaxExposure"] > 0.0
        assert inputs["InpHaltOnBreach"] is True
        assert inputs["InpVolumeMultiplier" if "InpVolumeMultiplier" in inputs else
                      "InpAddVolumeMultiplier"] >= 1.0


@pytest.mark.parametrize("ea,slug,preset_path", DEMO_EA_PRESETS)
def test_demo_basket_bots_cannot_call_ordersend(
    ea: str, slug: str, preset_path: Path
) -> None:
    """Every demo EA routes orders through ExecBroker, never OrderSend directly."""
    text = (REPO_ROOT / "mt5" / "Experts" / f"{ea}.mq5").read_text(encoding="utf-8")
    code = re.sub(r"//[^\n]*", "", text)
    assert "OrderSend" not in code


def test_runner_demo_keeps_runner_guards() -> None:
    """ADR 0005: the runner preset pins one position, a mandatory far safety
    TP and a bounded stop band."""
    ir = _json(REPO_ROOT / "configs" / "demo" / "infinite_runner_demo.json")["inputs"]
    assert ir["InpMaxPositions"] == 1
    assert ir["InpSafetyTpPoints"] > 0.0
    assert ir["InpMaxStopPoints"] >= ir["InpMinStopPoints"] > 0.0
    assert ir["InpMaxConsecutiveLosses"] >= 0
    assert ir["InpHaltOnBreach"] is True


def test_demo_state_file_has_single_state_prefix() -> None:
    text = DEMO_EA.read_text(encoding="utf-8")
    assert '"state="+g_state.Serialize()' not in text
    assert r'g_state.Serialize()+"\r\n"' in text
    # Restore path still expects the "state=" line prefix.
    assert 'StringFind(line,"state=")==0' in text
    assert "g_state.Deserialize(state_text)" in text
