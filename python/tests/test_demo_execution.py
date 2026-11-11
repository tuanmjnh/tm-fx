"""Static checks for the demo-only execution scope (ADR 0004/ADR 0005).

The repository ships a single demo bot, ``InfiniteRunnerXAUV2DemoEA``. These tests
pin the IR-only facts: one EA, one preset, one demo mode.
"""

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
    EA_NAMES,
    SIM_EA_NAMES,
    snapshot_path,
    validate_preset,
    validate_project,
    write_snapshot,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEMO_PRESET = REPO_ROOT / "configs" / "demo" / "infinite_runner_demo.json"
PROJECT = REPO_ROOT / "configs" / "project.example.json"
DEMO_EA = REPO_ROOT / "mt5" / "Experts" / "InfiniteRunnerXAUV2DemoEA.mq5"


def _json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_script(name: str):
    path = REPO_ROOT / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_only_the_infinite_runner_ea_remains() -> None:
    assert EA_NAMES == ("InfiniteRunnerXAUV2DemoEA",)
    assert SIM_EA_NAMES == ()
    assert set(EA_EXECUTION_MODE.values()) == {DEMO_MODE}


def test_demo_preset_validates() -> None:
    config = _json(DEMO_PRESET)
    assert config["ea"] == "InfiniteRunnerXAUV2DemoEA"
    assert config["execution_mode"] == DEMO_MODE
    assert config["allow_live_trading"] is False
    assert validate_preset(config) == []


def test_demo_ea_requires_demo_mode() -> None:
    assert EA_EXECUTION_MODE["InfiniteRunnerXAUV2DemoEA"] == DEMO_MODE
    config = _json(DEMO_PRESET)
    config["execution_mode"] = "SIMULATION_ONLY"
    assert any("execution_mode" in issue for issue in validate_preset(config))


@pytest.mark.parametrize("mode", ["LIVE", "PAPER", "demo_only", ""])
def test_demo_preset_mode_is_fail_closed(mode: str) -> None:
    config = _json(DEMO_PRESET)
    config["execution_mode"] = mode
    assert any("execution_mode" in issue for issue in validate_preset(config))


def test_demo_preset_cannot_enable_live() -> None:
    config = _json(DEMO_PRESET)
    config["allow_live_trading"] = True
    assert any("allow_live_trading" in issue for issue in validate_preset(config))


def test_demo_preset_requires_safety_tp() -> None:
    config = _json(DEMO_PRESET)
    del config["inputs"]["InpSafetyTpPoints"]
    assert any("InpSafetyTpPoints" in issue for issue in validate_preset(config))

    config = _json(DEMO_PRESET)
    config["inputs"]["InpSafetyTpPoints"] = 0.0
    assert any("InpSafetyTpPoints" in issue for issue in validate_preset(config))


def test_demo_preset_safety_tp_must_clear_the_stop_band() -> None:
    config = _json(DEMO_PRESET)
    config["inputs"]["InpSafetyTpPoints"] = float(config["inputs"]["InpMinStopPoints"]) - 1.0
    assert any("InpSafetyTpPoints" in issue for issue in validate_preset(config))


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


def test_unknown_input_is_rejected() -> None:
    config = _json(DEMO_PRESET)
    config["inputs"]["InpMadeUp"] = 1
    assert any("InpMadeUp" in issue for issue in validate_preset(config))


def test_account_and_broker_fields_are_rejected() -> None:
    config = _json(DEMO_PRESET)
    config["inputs"]["InpAccountLogin"] = 123
    config["broker_server"] = "example"
    issues = validate_preset(config)
    assert any("InpAccountLogin" in issue for issue in issues)
    assert any("broker_server" in issue for issue in issues)


def test_runner_demo_keeps_runner_guards() -> None:
    """ADR 0005: the runner preset pins one position, a mandatory far safety
    TP and a bounded stop band."""
    ir = _json(DEMO_PRESET)["inputs"]
    assert ir["InpMaxPositions"] == 1
    assert ir["InpSafetyTpPoints"] > 0.0
    assert ir["InpMaxStopPoints"] >= ir["InpMinStopPoints"] > 0.0
    assert ir["InpMaxConsecutiveLosses"] >= 0
    assert ir["InpHaltOnBreach"] is True
    #--- The loss-streak guard must be able to recover: a permanent lock stops
    #--- the bot forever, because the streak only clears on a winning trade and
    #--- a blocked bot never places one (measured on the 2026 journal).
    if ir["InpMaxConsecutiveLosses"] > 0:
        assert ir["InpLossStreakCooldownMinutes"] > 0


def test_runner_loss_streak_guard_must_recover() -> None:
    """A loss-streak limit with no recovery cooldown deadlocks the bot: the
    streak only clears on a win, and a blocked bot never places one. The
    validator must reject that combination."""
    config = _json(DEMO_PRESET)
    config["inputs"]["InpLossStreakCooldownMinutes"] = 0
    assert any(
        "InpLossStreakCooldownMinutes" in issue for issue in validate_preset(config)
    )


def test_step_trailing_locks_must_stay_below_triggers() -> None:
    config = _json(DEMO_PRESET)
    config["inputs"]["InpStep1_LockPoints"] = config["inputs"]["InpStep1_TriggerPoints"]
    assert any("InpStep1" in issue for issue in validate_preset(config))


def test_demo_ea_routes_orders_through_broker() -> None:
    """The demo EA routes orders through ExecBroker, never OrderSend directly."""
    code = re.sub(r"//[^\n]*", "", DEMO_EA.read_text(encoding="utf-8"))
    assert "OrderSend" not in code


def test_demo_execution_validator_passes() -> None:
    script = _load_script("validate_demo_execution")
    assert script.main(["--root", str(REPO_ROOT)]) == 0


def test_project_validator_passes() -> None:
    script = _load_script("validate-project")
    assert script.main(["--root", str(REPO_ROOT)]) == 0


def test_project_example_is_valid_ir_only() -> None:
    project = _json(PROJECT)
    assert project["presets"] == {}
    assert project["scenarios"] == []
    assert validate_project(project, REPO_ROOT) == []


def test_project_file_cannot_list_demo_ea_as_simulation() -> None:
    project = _json(PROJECT)
    project["presets"]["InfiniteRunnerXAUV2DemoEA"] = (
        "configs/demo/infinite_runner_demo.json"
    )
    assert any(
        "InfiniteRunnerXAUV2DemoEA" in issue
        for issue in validate_project(copy.deepcopy(project), REPO_ROOT)
    )


def test_snapshot_is_content_addressed() -> None:
    first = _json(DEMO_PRESET)
    second = copy.deepcopy(first)
    assert snapshot_path(Path("x"), first) == snapshot_path(Path("x"), second)

    second["inputs"]["InpMaxLots"] = 0.5
    assert snapshot_path(Path("x"), first) != snapshot_path(Path("x"), second)


def test_snapshot_never_overwrites(tmp_path: Path) -> None:
    config = _json(DEMO_PRESET)
    path, created = write_snapshot(tmp_path, config)
    assert created is True
    assert json.loads(path.read_text(encoding="utf-8"))["ea"] == "InfiniteRunnerXAUV2DemoEA"

    path.write_text("sentinel\n", encoding="utf-8")
    same_path, created_again = write_snapshot(tmp_path, config)
    assert same_path == path
    assert created_again is False
    assert path.read_text(encoding="utf-8") == "sentinel\n"
