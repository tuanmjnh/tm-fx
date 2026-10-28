"""Static guards for PinePlanSimEA and the shared plan rules."""

from __future__ import annotations

import re
from pathlib import Path

from mt5_ea_ai_lab.sim_configs import EA_INPUTS

REPO_ROOT = Path(__file__).resolve().parents[2]
EA = REPO_ROOT / "mt5" / "Experts" / "PinePlanSimEA.mq5"
PLAN = REPO_ROOT / "mt5" / "Include" / "Sim" / "SimPlan.mqh"
TESTS = REPO_ROOT / "mt5" / "Scripts" / "SimPlanTests.mq5"

REQUIRED_CONSTANTS = (
    "PA_BUF_PLAN_VALID",
    "PA_BUF_ENTRY",
    "PA_BUF_SL",
    "PA_BUF_TP1",
    "PA_BUF_SIG_LONG",
    "X2_BUF_PLAN_VALID",
    "X2_BUF_ENTRY",
    "X2_BUF_SL",
    "X2_BUF_TP3",
    "X2_BUF_SIG",
    "TM2_BUF_PLAN_VALID",
    "TM2_BUF_ENTRY",
    "TM2_BUF_SL",
    "TM2_BUF_TP3",
    "TM2_BUF_SIGNAL",
)

EXPECTED_TARGETS = ("tp1", "tp2", "tp3")


def _input_names() -> set[str]:
    text = EA.read_text(encoding="utf-8")
    return set(re.findall(r"^input\s+(?!group\b)\S+\s+(\w+)\s*=", text, re.MULTILINE))


def test_ea_inputs_match_validator_schema() -> None:
    assert _input_names() == set(EA_INPUTS["PinePlanSimEA"])


def test_ea_includes_plan_and_contracts() -> None:
    text = EA.read_text(encoding="utf-8")
    for include in (
        "SimPortfolio.mqh",
        "SimRiskGuard.mqh",
        "SimCostModel.mqh",
        "SimLogger.mqh",
        "SimPlan.mqh",
        "PriceActionMTFContract.mqh",
        "TMXAUSignals2Contract.mqh",
        "TMIndicator2Contract.mqh",
    ):
        assert include in text, f"missing include {include}"


def test_ea_buffer_mapping_uses_contract_constants() -> None:
    text = EA.read_text(encoding="utf-8")
    for constant in REQUIRED_CONSTANTS:
        assert constant in text, f"missing buffer constant {constant}"


def test_plan_module_has_no_indicator_access() -> None:
    text = PLAN.read_text(encoding="utf-8")
    for token in ("CopyBuffer", "iCustom", "SymbolInfo", "OrderSend", "CTrade"):
        assert token not in text


def test_plan_test_suite_declares_targets() -> None:
    text = TESTS.read_text(encoding="utf-8")
    assert "suite=sim_plan" in text
    assert "SimPlanValidate" in text
    assert "SimPlanResolveSide" in text
    assert "SimPlanTargetPrice" in text
    for target in EXPECTED_TARGETS:
        assert target in text
