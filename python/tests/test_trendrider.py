"""Checks for the PA TrendRider XAU v1 preset, static validator and core.

The real runtime evidence lives in reports/build/tester-reports; these tests
only guard the fail-closed contract and the simulation-only structure.
"""

from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path

import pytest

from mt5_ea_ai_lab.sim_configs import validate_preset

REPO_ROOT = Path(__file__).resolve().parents[2]
PRESET = REPO_ROOT / "configs" / "sim" / "pa_trendrider_xau.json"
VALIDATOR = REPO_ROOT / "scripts" / "validate_trendrider.py"


def _preset() -> dict:
    return json.loads(PRESET.read_text(encoding="utf-8"))


def _load_validator():
    spec = importlib.util.spec_from_file_location("validate_trendrider", VALIDATOR)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _issues(config: dict) -> list[str]:
    return validate_preset(config)


def test_repository_preset_validates() -> None:
    config = _preset()
    assert config["ea"] == "PATrendRiderXAUv1SimEA"
    assert _issues(config) == []


def test_validator_passes_on_repository() -> None:
    assert _load_validator().main([]) == 0


@pytest.mark.parametrize(
    "mutation",
    [
        {"execution_mode": "LIVE"},
        {"allow_live_trading": True},
        {"inputs": {"InpMaxPositions": 2}},
        {"inputs": {"InpTrendTF": 15}},
        {"inputs": {"InpTrailingStartR": 0.5}},
        {"inputs": {"InpEntryBars": 50}},
        {"inputs": {"InpMaxSlAtr": 0.5}},
    ],
)
def test_tampered_preset_is_rejected(mutation: dict) -> None:
    config = copy.deepcopy(_preset())
    for key, value in mutation.items():
        if isinstance(value, dict):
            config[key].update(value)
        else:
            config[key] = value
    assert _issues(config)


def test_unknown_input_is_rejected() -> None:
    config = copy.deepcopy(_preset())
    config["inputs"]["InpTakeProfitPoints"] = 100.0
    assert any("unknown input" in issue for issue in _issues(config))


def test_core_portfolio_has_contract_size_support() -> None:
    source = (REPO_ROOT / "mt5/Include/Sim/SimPortfolio.mqh").read_text(
        encoding="utf-8"
    )
    assert "InitWithContractSize" in source
    assert "ContractSize" in source


def test_contract_suite_covers_contract_size() -> None:
    source = (REPO_ROOT / "mt5/Scripts/SimCoreTests.mq5").read_text(encoding="utf-8")
    assert 'Record("P23"' in source
    assert 'Record("P24"' in source
