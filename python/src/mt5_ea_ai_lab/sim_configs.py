"""Fail-closed validation for the InfiniteRunner demo preset.

The repository now ships a single demo bot: ``InfiniteRunnerXAUV2DemoEA``. Its
preset is validated for ``DEMO_ONLY`` execution (ADR 0003/ADR 0005): it may
describe a guarded demo-account EA but must never allow live trading. This module
reads local JSON presets and never connects to a broker, opens an account or sends
an order. The MQL5 EA remains authoritative.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

EXECUTION_MODE = "SIMULATION_ONLY"
DEMO_MODE = "DEMO_ONLY"

_ALLOWED_TOP_LEVEL = {
    "schema_version",
    "ea",
    "project",
    "version",
    "strategy",
    "symbol",
    "timeframe",
    "execution_mode",
    "allow_live_trading",
    "description",
    "inputs",
    "enum_map",
    "assumptions",
    "presets",
    "scenarios",
}

#--- Anything that looks like broker/account/session data is rejected outright.
_SENSITIVE_KEY = re.compile(
    r"(login|password|passwd|investor|server|account|token|secret|"
    r"credential|apikey|api_key|broker)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Num:
    minimum: float | None = None
    maximum: float | None = None
    integer: bool = False
    min_exclusive: bool = False


@dataclass(frozen=True)
class Enum:
    values: tuple[int, ...]


BOOL = "bool"
STR = "str"
STR_LIST = "str_list"

#--- MT5 period constants and their length in seconds. The InfiniteRunner demo
#--- cross-check compares durations rather than enum names.
_TF_SECONDS: dict[int, int] = {
    1: 60,
    2: 120,
    3: 180,
    4: 240,
    5: 300,
    6: 360,
    10: 600,
    12: 720,
    15: 900,
    20: 1200,
    30: 1800,
    16385: 3600,
    16386: 7200,
    16387: 10800,
    16388: 14400,
    16390: 21600,
    16392: 28800,
    16394: 43200,
    16408: 86400,
    32769: 604800,
    49153: 2419200,
}

#--- Inputs shared by the demo-execution EA (ADR 0004). Execution defaults to
#--- enabled; the strategy-specific caps stay per EA.
_DEMO_EXECUTION_COMMON: dict[str, Any] = {
    "InpEnableExecution": BOOL,
    "InpAllowedSymbols": STR_LIST,
    "InpMagicNumber": Num(minimum=1.0, integer=True),
    "InpMaxSlippagePoints": Num(minimum=0.0, maximum=1000.0, integer=True),
    "InpKillSwitchFile": STR,
    "InpEnableLog": BOOL,
    "InpLogFile": STR,
    "InpDebug": BOOL,
    "InpMaxSpreadPoints": Num(minimum=0.0),
}

EA_INPUTS: dict[str, dict[str, Any]] = {
    #--- ADR 0005: the InfiniteRunner_XAU V2 demo bot. One runner position
    #--- toward a far mandatory safety TP with a monotonic trail; decisions on
    #--- closed bars; BE/trailing anchored to the stored initial R.
    "InfiniteRunnerXAUV2DemoEA": {
        **_DEMO_EXECUTION_COMMON,
        "InpCloseOnKillSwitch": BOOL,
        "InpPersistState": BOOL,
        "InpStateFile": STR,
        "InpResetStateOnInit": BOOL,
        "InpDirectionMode": Enum((0, 1, 2)),
        "InpH1TF": Num(minimum=0.0, integer=True),
        "InpM15TF": Num(minimum=0.0, integer=True),
        "InpEntryTF": Num(minimum=0.0, integer=True),
        "InpEmaFast": Num(minimum=2.0, integer=True),
        "InpEmaSlow": Num(minimum=2.0, integer=True),
        "InpSlopeBars": Num(minimum=1.0, maximum=200.0, integer=True),
        "InpSlowSlopeTolPoints": Num(minimum=0.0),
        "InpPullbackTolPoints": Num(minimum=0.0),
        "InpBreakoutBars": Num(minimum=2.0, maximum=240.0, integer=True),
        "InpMaxPositions": Num(minimum=1.0, maximum=1.0, integer=True),
        "InpCooldownMinutes": Num(minimum=0.0, maximum=1440.0, integer=True),
        "InpMinBarsBetweenEntries": Num(minimum=0.0, maximum=1000.0, integer=True),
        "InpMaxTradesPerDay": Num(minimum=1.0, maximum=5000.0, integer=True),
        "InpLotMode": Enum((0, 1)),
        "InpLots": Num(minimum=0.0, maximum=100.0),
        "InpRiskPercent": Num(minimum=0.0, maximum=10.0),
        "InpMaxLots": Num(minimum=0.0, maximum=100.0),
        "InpMaxSpreadAtrRatio": Num(minimum=0.0, maximum=10.0),
        "InpAbnormalAtrRatio": Num(minimum=0.0, maximum=100.0),
        "InpAtrPeriod": Num(minimum=2.0, maximum=500.0, integer=True),
        "InpAtrBaselineBars": Num(minimum=10.0, maximum=5000.0, integer=True),
        "InpMaxDailyLossPct": Num(minimum=0.0, maximum=100.0),
        "InpMaxDrawdownPct": Num(minimum=0.0, maximum=100.0),
        "InpMaxConsecutiveLosses": Num(minimum=0.0, integer=True),
        "InpLossStreakCooldownMinutes": Num(minimum=0.0, maximum=1440.0, integer=True),
        "InpHaltOnBreach": BOOL,
        "InpManualResetDrawdown": BOOL,
        "InpSlMode": Enum((0, 1)),
        "InpInitialSlPoints": Num(minimum=0.0),
        "InpSlAtrMultiplier": Num(minimum=0.0),
        "InpMinStopPoints": Num(minimum=0.0),
        "InpMaxStopPoints": Num(minimum=0.0),
        "InpTrailMode": Enum((0, 1)),
        "InpTrailStartPts": Num(minimum=0.0),
        "InpTrailDistancePts": Num(minimum=0.0),
        "InpTrailStepPts": Num(minimum=0.0),
        "InpTrailAtrMultiplier": Num(minimum=0.0),
        "InpBreakEvenTriggerR": Num(minimum=0.0),
        "InpBreakEvenBufferPts": Num(minimum=0.0),
        "InpSafetyTpPoints": Num(minimum=0.0),
        "InpEnableStepTrailing": BOOL,
        "InpStep1_TriggerPoints": Num(minimum=0.0),
        "InpStep1_LockPoints": Num(minimum=0.0),
        "InpStep2_TriggerPoints": Num(minimum=0.0),
        "InpStep2_LockPoints": Num(minimum=0.0),
        "InpStep3_TriggerPoints": Num(minimum=0.0),
        "InpStep3_LockPoints": Num(minimum=0.0),
    },
}

#--- ADR 0005: the InfiniteRunner demo EA is the only preset allowed to request
#--- execution, and only with DEMO_ONLY.
DEMO_EA_NAMES = ("InfiniteRunnerXAUV2DemoEA",)

EA_EXECUTION_MODE: dict[str, str] = {
    name: (DEMO_MODE if name in DEMO_EA_NAMES else EXECUTION_MODE)
    for name in EA_INPUTS
}

EA_NAMES = tuple(EA_INPUTS)
SIM_EA_NAMES = tuple(
    name for name in EA_INPUTS if EA_EXECUTION_MODE[name] == EXECUTION_MODE
)


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _validate_value(name: str, spec: Any, value: Any) -> list[str]:
    if spec is BOOL:
        if not isinstance(value, bool):
            return [f"{name}: must be a boolean"]
        return []
    if spec is STR:
        if not isinstance(value, str) or not value.strip():
            return [f"{name}: must be a non-empty string"]
        if "," in value:
            return [f"{name}: must not contain a comma (CSV reason column)"]
        return []
    if spec is STR_LIST:
        if not isinstance(value, str) or not value.strip():
            return [f"{name}: must be a non-empty string"]
        items = [item.strip() for item in value.split(",")]
        if any(not item for item in items):
            return [f"{name}: must not contain an empty list item"]
        return []
    if isinstance(spec, Enum):
        if not _is_number(value) or float(value) != int(value):
            return [f"{name}: must be an integer enum"]
        if int(value) not in spec.values:
            return [f"{name}: {int(value)} is not one of {list(spec.values)}"]
        return []
    if not _is_number(value):
        return [f"{name}: must be a number"]
    if spec.integer and float(value) != int(value):
        return [f"{name}: must be an integer"]
    if spec.minimum is not None:
        if spec.min_exclusive and value <= spec.minimum:
            return [f"{name}: must be greater than {spec.minimum}"]
        if not spec.min_exclusive and value < spec.minimum:
            return [f"{name}: must be at least {spec.minimum}"]
    if spec.maximum is not None and value > spec.maximum:
        return [f"{name}: must be at most {spec.maximum}"]
    return []


def _cross_checks(ea: str, inputs: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    #--- ADR 0005: InfiniteRunner demo stop band, mandatory safety TP, trail
    #--- and lot-mode consistency.
    if ea == "InfiniteRunnerXAUV2DemoEA":
        if inputs["InpEmaSlow"] <= inputs["InpEmaFast"]:
            issues.append("InpEmaSlow: must be greater than InpEmaFast")
        trend = _TF_SECONDS.get(int(inputs["InpH1TF"]))
        structure = _TF_SECONDS.get(int(inputs["InpM15TF"]))
        entry = _TF_SECONDS.get(int(inputs["InpEntryTF"]))
        if trend is None or structure is None or entry is None:
            issues.append("timeframes: must use known MT5 period constants")
        elif not (trend > structure > entry):
            issues.append("timeframes: must be ordered H1 > M15 > entry")
        if inputs["InpMaxStopPoints"] < inputs["InpMinStopPoints"]:
            issues.append("InpMaxStopPoints: must cover InpMinStopPoints")
        if inputs["InpSafetyTpPoints"] < inputs["InpMinStopPoints"]:
            issues.append("InpSafetyTpPoints: mandatory TP must clear the stop band")
        if inputs["InpSlMode"] == 0 and inputs["InpInitialSlPoints"] <= 0:
            issues.append("InpInitialSlPoints: must be positive in fixed SL mode")
        if inputs["InpSlMode"] == 1 and inputs["InpSlAtrMultiplier"] <= 0:
            issues.append("InpSlAtrMultiplier: must be positive in ATR SL mode")
        if inputs["InpTrailMode"] == 0 and inputs["InpTrailDistancePts"] <= 0:
            issues.append("InpTrailDistancePts: must be positive in fixed trail mode")
        if inputs["InpTrailMode"] == 1 and inputs["InpTrailAtrMultiplier"] <= 0:
            issues.append("InpTrailAtrMultiplier: must be positive in ATR trail mode")
        if inputs["InpTrailStartPts"] <= 0 or inputs["InpTrailStepPts"] <= 0:
            issues.append("trailing: trail start and trail step must be positive")
        if inputs["InpLotMode"] == 1 and inputs["InpRiskPercent"] <= 0:
            issues.append("InpRiskPercent: must be positive in risk-percent lot mode")
        if inputs["InpMaxLots"] <= 0:
            issues.append("InpMaxLots: exposure cap must be positive")
        if inputs["InpMaxTradesPerDay"] < 1:
            issues.append("InpMaxTradesPerDay: must be at least 1")
        if inputs["InpMaxConsecutiveLosses"] > 0 and inputs["InpLossStreakCooldownMinutes"] <= 0:
            issues.append(
                "InpLossStreakCooldownMinutes: a loss-streak guard needs a "
                "recovery cooldown (0 is a permanent dead end)"
            )
        if inputs["InpEnableStepTrailing"]:
            steps = (
                (inputs["InpStep1_TriggerPoints"], inputs["InpStep1_LockPoints"]),
                (inputs["InpStep2_TriggerPoints"], inputs["InpStep2_LockPoints"]),
                (inputs["InpStep3_TriggerPoints"], inputs["InpStep3_LockPoints"]),
            )
            for index, (trigger, lock) in enumerate(steps, start=1):
                if trigger <= 0 or lock < 0 or lock >= trigger:
                    issues.append(
                        f"InpStep{index}: lock must be below the trigger"
                    )
            if not (
                steps[0][0] < steps[1][0] < steps[2][0]
                and steps[0][1] < steps[1][1] < steps[2][1]
            ):
                issues.append("step trailing: triggers and locks must increase")
    return issues


def validate_preset(config: Any) -> list[str]:
    """Returns a list of problems; an empty list means the preset is valid."""

    if not isinstance(config, dict):
        return ["config: must be a JSON object"]

    issues: list[str] = []
    for key in config:
        if key not in _ALLOWED_TOP_LEVEL:
            issues.append(f"{key}: unknown top-level field")
        if _SENSITIVE_KEY.search(str(key)):
            issues.append(f"{key}: account/broker/session fields are not allowed")

    if config.get("schema_version") != 1:
        issues.append("schema_version: must be 1")
    ea = config.get("ea")
    if ea not in EA_INPUTS:
        issues.append(f"ea: must be one of {list(EA_NAMES)}")
        return issues
    version = config.get("version")
    if not isinstance(version, str) or not version.strip():
        issues.append("version: must be a non-empty string")
    expected_mode = EA_EXECUTION_MODE[ea]
    if config.get("execution_mode") != expected_mode:
        issues.append(f"execution_mode: must be {expected_mode} for {ea}")
    if config.get("allow_live_trading") is not False:
        issues.append("allow_live_trading: must be false")

    spec = EA_INPUTS[ea]
    inputs = config.get("inputs")
    if not isinstance(inputs, dict):
        issues.append("inputs: must be a JSON object")
        return issues

    for name in spec:
        if name not in inputs:
            issues.append(f"{name}: missing required input")
    for name, value in inputs.items():
        if name not in spec:
            issues.append(f"{name}: unknown input for {ea}")
            continue
        if _SENSITIVE_KEY.search(name):
            issues.append(f"{name}: account/broker/session fields are not allowed")
            continue
        issues.extend(_validate_value(name, spec[name], value))

    if not issues:
        issues.extend(_cross_checks(ea, inputs))
    return issues


def validate_project(config: Any, root: Path) -> list[str]:
    """Validates a project file and every preset or scenario it references."""

    if not isinstance(config, dict):
        return ["project: must be a JSON object"]

    issues: list[str] = []
    for key in config:
        if key not in _ALLOWED_TOP_LEVEL:
            issues.append(f"{key}: unknown top-level field")
        if _SENSITIVE_KEY.search(str(key)):
            issues.append(f"{key}: account/broker/session fields are not allowed")

    if config.get("schema_version") != 1:
        issues.append("schema_version: must be 1")
    if not isinstance(config.get("project"), str) or not config["project"].strip():
        issues.append("project: must be a non-empty string")
    if config.get("execution_mode") != EXECUTION_MODE:
        issues.append(f"execution_mode: must be {EXECUTION_MODE}")
    if config.get("allow_live_trading") is not False:
        issues.append("allow_live_trading: must be false")

    presets = config.get("presets")
    if not isinstance(presets, dict):
        issues.append("presets: must be a JSON object")
        return issues
    for ea in SIM_EA_NAMES:
        if ea not in presets:
            issues.append(f"presets.{ea}: missing preset path")
        elif not isinstance(presets[ea], str):
            issues.append(f"presets.{ea}: path must be a string")
    for ea, path in presets.items():
        if ea not in SIM_EA_NAMES:
            issues.append(f"presets.{ea}: unknown simulation EA")
            continue
        if not isinstance(path, str):
            continue
        preset_path = root / path
        if not preset_path.exists():
            issues.append(f"presets.{ea}: missing file {path}")
            continue
        preset = _load_json(preset_path, f"presets.{ea}", issues)
        if preset is None:
            continue
        issues.extend(f"presets.{ea}: {item}" for item in validate_preset(preset))
        if isinstance(preset, dict) and preset.get("ea") != ea:
            issues.append(f"presets.{ea}: file declares ea={preset.get('ea')}")

    scenarios = config.get("scenarios", [])
    if not isinstance(scenarios, list):
        issues.append("scenarios: must be a list")
        return issues
    seen: set[str] = set()
    for index, scenario in enumerate(scenarios):
        prefix = f"scenarios[{index}]"
        if not isinstance(scenario, dict):
            issues.append(f"{prefix}: must be an object")
            continue
        name = scenario.get("name")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9_]+", name or ""):
            issues.append(f"{prefix}.name: must match [a-z0-9_]+")
        elif name in seen:
            issues.append(f"{prefix}.name: duplicate scenario {name}")
        else:
            seen.add(name)

        ea = scenario.get("ea")
        if ea not in SIM_EA_NAMES:
            issues.append(f"{prefix}.ea: must be one of {list(SIM_EA_NAMES)}")
            continue
        path = scenario.get("preset")
        if path != presets.get(ea):
            issues.append(f"{prefix}.preset: must match presets.{ea}")
            continue
        overrides = scenario.get("overrides", {})
        if not isinstance(overrides, dict):
            issues.append(f"{prefix}.overrides: must be an object")
            continue
        for key in overrides:
            if _SENSITIVE_KEY.search(str(key)):
                issues.append(f"{prefix}.overrides.{key}: field is not allowed")
        merged = _merge_scenario(root, path, ea, overrides, prefix, issues)
        if merged is not None:
            for item in validate_preset(merged):
                issues.append(f"{prefix}: {item}")
    return issues


def _load_json(path: Path, label: str, issues: list[str]) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        issues.append(f"{label}: cannot read {path.name}: {exc}")
    except json.JSONDecodeError as exc:
        issues.append(f"{label}: invalid JSON in {path.name}: {exc}")
    return None


def _merge_scenario(
    root: Path,
    path: Any,
    ea: str,
    overrides: dict[str, Any],
    prefix: str,
    issues: list[str],
) -> dict[str, Any] | None:
    if not isinstance(path, str):
        issues.append(f"{prefix}.preset: must be a string")
        return None
    preset = _load_json(root / path, f"{prefix}.preset", issues)
    if not isinstance(preset, dict) or not isinstance(preset.get("inputs"), dict):
        issues.append(f"{prefix}.preset: must contain inputs")
        return None
    for name in overrides:
        if name not in EA_INPUTS[ea]:
            issues.append(f"{prefix}.overrides.{name}: unknown input for {ea}")
    merged = dict(preset)
    merged["ea"] = ea
    merged["inputs"] = {**preset["inputs"], **overrides}
    return merged


def _fnv1a32(text: str) -> str:
    value = 2166136261
    for byte in text.encode("utf-8"):
        value ^= byte
        value = (value * 16777619) & 0xFFFFFFFF
    return f"{value:08X}"


def snapshot_path(directory: Path, config: dict[str, Any]) -> Path:
    name = str(config.get("ea") or config.get("project") or "config")
    safe = re.sub(r"[^A-Za-z0-9_-]+", "_", name)
    canonical = json.dumps(config, sort_keys=True, separators=(",", ":"))
    return directory / f"{safe}-{_fnv1a32(canonical)}.json"


def write_snapshot(directory: Path, config: dict[str, Any]) -> tuple[Path, bool]:
    """Writes one immutable snapshot; returns (path, created)."""

    path = snapshot_path(directory, config)
    if path.exists():
        return path, False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(config, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return path, True


def preset_files(configs_dir: Path) -> Iterable[Path]:
    return sorted(configs_dir.glob("*.json"))
