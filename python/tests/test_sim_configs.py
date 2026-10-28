"""Fail-closed checks for Track C simulation presets and snapshots."""

from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

from mt5_ea_ai_lab.sim_configs import (
    snapshot_path,
    validate_preset,
    validate_project,
    write_snapshot,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIGS = REPO_ROOT / "configs" / "sim"
PROJECT = REPO_ROOT / "configs" / "project.example.json"

PRESETS = (
    ("runner_trailing.json", "RunnerTrailingLabEA"),
    ("grid_lab.json", "GridLabEA"),
    ("dca_lab.json", "DCALabEA"),
    ("pine_plan_lab.json", "PinePlanSimEA"),
)


def _preset(filename: str) -> dict:
    return json.loads((CONFIGS / filename).read_text(encoding="utf-8"))


def _project() -> dict:
    return json.loads(PROJECT.read_text(encoding="utf-8"))


@pytest.mark.parametrize(("filename", "ea"), PRESETS)
def test_repository_presets_validate(filename: str, ea: str) -> None:
    config = _preset(filename)
    assert config["ea"] == ea
    assert validate_preset(config) == []


def test_project_file_validates() -> None:
    project = _project()
    assert len(project["scenarios"]) >= 9
    assert validate_project(project, REPO_ROOT) == []


@pytest.mark.parametrize("mode", ["LIVE", "PAPER", "simulation_only", ""])
def test_execution_mode_is_fail_closed(mode: str) -> None:
    config = _preset("dca_lab.json")
    config["execution_mode"] = mode
    assert any("execution_mode" in issue for issue in validate_preset(config))


def test_allow_live_trading_true_is_rejected() -> None:
    config = _preset("grid_lab.json")
    config["allow_live_trading"] = True
    assert any("allow_live_trading" in issue for issue in validate_preset(config))

    del config["allow_live_trading"]
    assert any("allow_live_trading" in issue for issue in validate_preset(config))


def test_unknown_input_is_rejected() -> None:
    config = _preset("runner_trailing.json")
    config["inputs"]["InpMadeUp"] = 1
    assert any("InpMadeUp" in issue for issue in validate_preset(config))


def test_account_and_broker_fields_are_rejected() -> None:
    config = _preset("dca_lab.json")
    config["inputs"]["InpAccountLogin"] = 123
    config["broker_server"] = "example"
    issues = validate_preset(config)
    assert any("InpAccountLogin" in issue for issue in issues)
    assert any("broker_server" in issue for issue in issues)


def test_dca_zero_adds_valid_and_negative_adds_invalid() -> None:
    config = _preset("dca_lab.json")
    config["inputs"]["InpMaxDcaAdds"] = 0
    assert validate_preset(config) == []

    config["inputs"]["InpMaxDcaAdds"] = -1
    assert any("InpMaxDcaAdds" in issue for issue in validate_preset(config))


def test_dca_trigger_mode_cross_checks() -> None:
    config = _preset("dca_lab.json")
    config["inputs"]["InpTriggerMode"] = 0
    config["inputs"]["InpDcaDistancePoints"] = 0.0
    assert validate_preset(config)

    config = _preset("dca_lab.json")
    config["inputs"]["InpTriggerMode"] = 1
    config["inputs"]["InpBarsBetweenAdds"] = 0
    assert any("InpBarsBetweenAdds" in issue for issue in validate_preset(config))


def test_dca_caps_must_cover_base_volume() -> None:
    config = _preset("dca_lab.json")
    config["inputs"]["InpMaxAddVolume"] = 0.05
    assert any("InpMaxAddVolume" in issue for issue in validate_preset(config))

    config = _preset("dca_lab.json")
    config["inputs"]["InpMaxVirtualExposure"] = 0.05
    assert any("InpMaxVirtualExposure" in issue for issue in validate_preset(config))


def test_grid_mode_target_cross_checks() -> None:
    config = _preset("grid_lab.json")
    config["inputs"]["InpExitMode"] = 1
    config["inputs"]["InpBasketTargetPoints"] = 0.0
    assert any("InpBasketTargetPoints" in issue for issue in validate_preset(config))

    config = _preset("grid_lab.json")
    config["inputs"]["InpExitMode"] = 0
    config["inputs"]["InpLevelTargetPoints"] = 0.0
    assert any("InpLevelTargetPoints" in issue for issue in validate_preset(config))

    config = _preset("grid_lab.json")
    config["inputs"]["InpSpacingMode"] = 0
    config["inputs"]["InpSpacingPoints"] = 0.0
    assert any("InpSpacingPoints" in issue for issue in validate_preset(config))

    config = _preset("grid_lab.json")
    config["inputs"]["InpSpacingMode"] = 1
    config["inputs"]["InpAtrPeriod"] = 1
    assert any("InpAtrPeriod" in issue for issue in validate_preset(config))


def test_runner_cross_checks() -> None:
    config = _preset("runner_trailing.json")
    config["inputs"]["InpSlowEma"] = config["inputs"]["InpFastEma"]
    assert any("InpSlowEma" in issue for issue in validate_preset(config))

    config = _preset("runner_trailing.json")
    config["inputs"]["InpBreakEvenEnabled"] = True
    config["inputs"]["InpBreakEvenTriggerPoints"] = 0.0
    assert any("InpBreakEvenTriggerPoints" in issue for issue in validate_preset(config))

    config = _preset("runner_trailing.json")
    config["inputs"]["InpTrailMode"] = 0
    config["inputs"]["InpTrailFixedPoints"] = 0.0
    assert any("InpTrailFixedPoints" in issue for issue in validate_preset(config))


def test_project_scenario_overrides_are_validated() -> None:
    project = _project()
    scenario = project["scenarios"][3]
    scenario["overrides"] = {"InpMaxGridLevels": 0}
    issues = validate_project(project, REPO_ROOT)
    assert any("InpMaxGridLevels" in issue for issue in issues)


def test_project_scenario_preset_must_match_ea() -> None:
    project = _project()
    project["scenarios"][0]["preset"] = "configs/sim/grid_lab.json"
    issues = validate_project(project, REPO_ROOT)
    assert any("preset" in issue for issue in issues)


def test_project_rejects_duplicate_scenario_names() -> None:
    project = _project()
    project["scenarios"].append(copy.deepcopy(project["scenarios"][0]))
    issues = validate_project(project, REPO_ROOT)
    assert any("duplicate" in issue for issue in issues)


def test_plan_preset_rejects_bad_management_flags() -> None:
    config = _preset("pine_plan_lab.json")
    config["inputs"]["InpBreakEvenEnabled"] = True
    config["inputs"]["InpBreakEvenTriggerPoints"] = 0.0
    config["inputs"]["InpTrailEnabled"] = True
    config["inputs"]["InpTrailFixedPoints"] = 0.0
    issues = validate_preset(config)
    assert any("InpBreakEvenTriggerPoints" in issue for issue in issues)
    assert any("InpTrailFixedPoints" in issue for issue in issues)


def test_plan_preset_rejects_exposure_below_volume() -> None:
    config = _preset("pine_plan_lab.json")
    config["inputs"]["InpVolume"] = 2.0
    config["inputs"]["InpMaxVirtualExposure"] = 1.0
    assert any(
        "InpMaxVirtualExposure" in issue for issue in validate_preset(config)
    )


def test_plan_preset_source_and_filter_enums() -> None:
    config = _preset("pine_plan_lab.json")
    config["inputs"]["InpSource"] = 3
    config["inputs"]["InpSideFilter"] = 2
    issues = validate_preset(config)
    assert any("InpSource" in issue for issue in issues)
    assert any("InpSideFilter" in issue for issue in issues)


def test_plan_preset_accepts_short_only_filter() -> None:
    config = _preset("pine_plan_lab.json")
    config["inputs"]["InpSideFilter"] = -1
    config["inputs"]["InpTargetMode"] = 2
    assert validate_preset(config) == []


def test_snapshot_is_content_addressed() -> None:
    first = _preset("dca_lab.json")
    second = copy.deepcopy(first)
    assert snapshot_path(Path("x"), first) == snapshot_path(Path("x"), second)

    second["inputs"]["InpMaxDcaAdds"] = 1
    assert snapshot_path(Path("x"), first) != snapshot_path(Path("x"), second)


def test_snapshot_never_overwrites(tmp_path: Path) -> None:
    config = _preset("grid_lab.json")
    path, created = write_snapshot(tmp_path, config)
    assert created is True
    assert json.loads(path.read_text(encoding="utf-8"))["ea"] == "GridLabEA"

    path.write_text("sentinel\n", encoding="utf-8")
    same_path, created_again = write_snapshot(tmp_path, config)
    assert same_path == path
    assert created_again is False
    assert path.read_text(encoding="utf-8") == "sentinel\n"
