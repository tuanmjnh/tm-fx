"""Contract for scripts/tester/gen_ir_sets.py (the InfiniteRunner scenario matrix).

Every arm in the study changes exactly ONE thing versus the reference it is
compared against, so the effect of each change is attributable. Bookkeeping
inputs (log/state file names) are excluded from the diff.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "tester" / "gen_ir_sets.py"
PRESET = REPO_ROOT / "configs" / "demo" / "infinite_runner_demo.json"

BOOKKEEPING = {"InpLogFile", "InpStateFile"}


def _load():
    spec = importlib.util.spec_from_file_location("gen_ir_sets", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _effective() -> dict[str, dict]:
    base = dict(json.loads(PRESET.read_text(encoding="utf-8"))["inputs"])
    out: dict[str, dict] = {}
    for name, _p, _f, _t, _d, _report, overrides in _load().SCENARIOS:
        values = dict(base)
        values.update(overrides)
        out[name] = values
    return out


def _diff(a: dict, b: dict) -> set[str]:
    return {k for k in set(a) | set(b) if a.get(k) != b.get(k)} - BOOKKEEPING


def test_matrix_shape() -> None:
    scenarios = _load().SCENARIOS
    names = [s[0] for s in scenarios]
    assert len(names) == 13
    assert len(set(names)) == len(names)
    for _name, _period, from_date, to_date, deposit, _report, _ov in scenarios:
        assert from_date < to_date
        assert deposit > 0


def test_every_scenario_is_ea_valid() -> None:
    for name, values in _effective().items():
        assert values["InpSafetyTpPoints"] > 0.0, name
        assert values["InpMaxPositions"] == 1, name
        if values["InpMaxConsecutiveLosses"] > 0:
            assert values["InpLossStreakCooldownMinutes"] > 0, name


def test_exit_run_changes_only_step_trailing() -> None:
    eff = _effective()
    assert _diff(eff["infinite_runner_long_base_nolock"],
                 eff["infinite_runner_long_exit_run"]) == {"InpEnableStepTrailing"}
    assert eff["infinite_runner_long_exit_run"]["InpEnableStepTrailing"] is False


def test_fixedrr_changes_only_the_exit_geometry() -> None:
    eff = _effective()
    diff = _diff(eff["infinite_runner_long_base_nolock"],
                 eff["infinite_runner_long_fixedrr"])
    assert diff == {"InpEnableStepTrailing", "InpTrailStartPts", "InpSafetyTpPoints"}
    fixed = eff["infinite_runner_long_fixedrr"]
    assert fixed["InpEnableStepTrailing"] is False
    assert fixed["InpTrailStartPts"] >= 1e8          # parked far away = no trail
    assert fixed["InpSafetyTpPoints"] == 5000        # 1R TP


def test_fixedrr15_only_moves_the_take_profit() -> None:
    eff = _effective()
    diff = _diff(eff["infinite_runner_long_fixedrr"],
                 eff["infinite_runner_long_fixedrr15"])
    assert diff == {"InpSafetyTpPoints"}
    assert eff["infinite_runner_long_fixedrr15"]["InpSafetyTpPoints"] == 7500


def test_mtf_only_switches_the_direction_engine() -> None:
    eff = _effective()
    diff = _diff(eff["infinite_runner_long_base_nolock"],
                 eff["infinite_runner_long_mtf"])
    assert diff == {"InpDirectionMode"}
    assert eff["infinite_runner_long_mtf"]["InpDirectionMode"] == 1


def test_regime_only_switches_the_direction_engine() -> None:
    eff = _effective()
    diff = _diff(eff["infinite_runner_long_base_nolock"],
                 eff["infinite_runner_long_regime"])
    assert diff == {"InpDirectionMode"}
    assert eff["infinite_runner_long_regime"]["InpDirectionMode"] == 2


def test_nolimit_removes_only_the_entry_throttles() -> None:
    eff = _effective()
    diff = _diff(eff["infinite_runner_long_base_nolock"],
                 eff["infinite_runner_long_nolimit"])
    assert diff == {"InpMaxTradesPerDay", "InpMinBarsBetweenEntries"}
    assert eff["infinite_runner_long_nolimit"]["InpMinBarsBetweenEntries"] == 0


def test_spread200_changes_only_the_spread_cap() -> None:
    eff = _effective()
    diff = _diff(eff["infinite_runner_long_base_nolock"],
                 eff["infinite_runner_long_spread200"])
    assert diff == {"InpMaxSpreadPoints"}
    assert eff["infinite_runner_long_spread200"]["InpMaxSpreadPoints"] == 200.0


def test_clean_turns_every_guard_off() -> None:
    clean = _effective()["infinite_runner_long_fixedrr_clean"]
    assert clean["InpMaxDailyLossPct"] == 0.0
    assert clean["InpMaxDrawdownPct"] == 0.0
    assert clean["InpMaxConsecutiveLosses"] == 0
    assert clean["InpHaltOnBreach"] is False


def test_demo_exec_keeps_the_legacy_report_name() -> None:
    for name, _p, _f, _t, _d, report, _ov in _load().SCENARIOS:
        if name == "infinite_runner_demo_exec":
            assert report == "tester_ir_demo_exec"
