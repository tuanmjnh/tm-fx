"""Contract for scripts/tester/gen_ww2_sets.py measurement matrix.

The generator must refuse to emit an arm the EA would reject at OnInit, and the
trail arms must actually arm the trail trigger. Both rules come from real
failures on 2026-11-05 (a silent 0-bar run and a no-op trail arm).
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "tester" / "gen_ww2_sets.py"


def _load():
    spec = importlib.util.spec_from_file_location("gen_ww2_sets", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_measure_matrix_has_eight_valid_arms() -> None:
    module = _load()
    scenarios = module.measure_scenarios()
    assert len(scenarios) == 8
    for name, _period, from_date, to_date, deposit, values in scenarios:
        module._check_measure_arm(name, values)
        assert deposit == 100000
        assert from_date < to_date
        assert values["InpRequireParity"] is False


def test_trail_arms_arm_the_trail_trigger() -> None:
    module = _load()
    arms = {name.rsplit("_", 1)[1]: values for name, _p, _f, _t, _d, values
            in module.measure_scenarios() if name.endswith("_is_a")
            or name.endswith("_is_b") or name.endswith("_is_c")
            or name.endswith("_is_d")}
    assert arms["a"]["InpTrailTriggerR"] >= 1e8
    assert arms["b"]["InpTrailTriggerR"] >= 1e8
    assert arms["c"]["InpEnableStructureTrail"] is True
    assert arms["c"]["InpTrailTriggerR"] < 1e8
    assert arms["d"]["InpEnablePsarTrail"] is True


def test_gate_matrix_has_four_valid_arms() -> None:
    module = _load()
    scenarios = module.gate_scenarios()
    assert len(scenarios) == 4
    by_name = {name: values for name, _p, _f, _t, _d, values in scenarios}
    for name, values in by_name.items():
        module._check_measure_arm(name, values)
    #--- The control must reproduce the shipped behaviour exactly...
    assert by_name["ww2_meas_scalp_is_gate_w1"]["InpTriggerWindowBars"] == 1
    #--- ...and w5 must differ from it in this one input only.
    control = by_name["ww2_meas_scalp_is_gate_w1"]
    window = by_name["ww2_meas_scalp_is_gate_w5"]
    diff = {k for k in control if control[k] != window[k]}
    assert diff == {"InpTriggerWindowBars"}
    assert window["InpTriggerWindowBars"] == 5
    #--- Gate runs use the arm-A management (no trailing), so only the gate moves.
    for values in by_name.values():
        assert values["InpEnableStructureTrail"] is False
        assert values["InpEnablePsarTrail"] is False


def test_rejects_trail_trigger_below_break_even() -> None:
    module = _load()
    with pytest.raises(ValueError, match="rejects this at OnInit"):
        module._check_measure_arm("bad", {
            "InpBreakEvenTriggerR": 1e9, "InpTrailTriggerR": 1.3})


def test_rejects_enabled_trail_candidate_with_disabled_trigger() -> None:
    module = _load()
    with pytest.raises(ValueError, match="never be evaluated"):
        module._check_measure_arm("bad", {
            "InpBreakEvenTriggerR": 1.0, "InpTrailTriggerR": 1e9,
            "InpEnableStructureTrail": True})
