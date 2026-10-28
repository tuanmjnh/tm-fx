"""Fail-closed validation for Track C simulation presets.

Simulation only: this module reads local JSON presets and never connects to a
broker, opens an account or sends an order. It mirrors the ``OnInit`` checks of
``RunnerTrailingLabEA``, ``GridLabEA`` and ``DCALabEA`` so a bad preset is
rejected before it reaches MetaTrader. The MQL5 EA remains authoritative.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

EXECUTION_MODE = "SIMULATION_ONLY"

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
STR_OPTIONAL = "str_optional"


_COMMON: dict[str, Any] = {
    "InpInitialBalance": Num(minimum=0.0, min_exclusive=True),
    "InpEnableLog": BOOL,
    "InpLogFile": STR,
    "InpDebug": BOOL,
    "InpMaxSpreadPoints": Num(minimum=0.0),
    "InpMaxDailyLossPct": Num(minimum=0.0, maximum=100.0),
    "InpMaxDrawdownPct": Num(minimum=0.0, maximum=100.0),
    "InpHaltOnBreach": BOOL,
    "InpCommissionPerVolume": Num(minimum=0.0),
    "InpSlippagePoints": Num(minimum=0.0),
}

EA_INPUTS: dict[str, dict[str, Any]] = {
    "RunnerTrailingLabEA": {
        **_COMMON,
        "InpVolume": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
        "InpSideFilter": Enum((0, 1, 2)),
        "InpFastEma": Num(minimum=1.0, integer=True),
        "InpSlowEma": Num(minimum=1.0, integer=True),
        "InpAtrPeriod": Num(minimum=1.0, integer=True),
        "InpAtrSlMultiplier": Num(minimum=0.0, min_exclusive=True),
        "InpBreakEvenEnabled": BOOL,
        "InpBreakEvenTriggerPoints": Num(minimum=0.0),
        "InpBreakEvenOffsetPoints": Num(minimum=0.0),
        "InpTrailMode": Enum((0, 1)),
        "InpTrailFixedPoints": Num(minimum=0.0),
        "InpTrailAtrMultiplier": Num(minimum=0.0),
        "InpMinStopPoints": Num(minimum=0.0),
        "InpUpdateOnClosedBarOnly": BOOL,
        "InpMaxHoldingBars": Num(minimum=0.0, integer=True),
        "InpCooldownBars": Num(minimum=0.0, integer=True),
        "InpMaxVirtualExposure": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
    },
    "GridLabEA": {
        **_COMMON,
        "InpGridSide": Enum((1, -1)),
        "InpSpacingMode": Enum((0, 1)),
        "InpSpacingPoints": Num(minimum=0.0),
        "InpAtrPeriod": Num(minimum=1.0, integer=True),
        "InpAtrMultiplier": Num(minimum=0.0),
        "InpMaxGridLevels": Num(minimum=1.0, maximum=1000.0, integer=True),
        "InpBaseVirtualVolume": Num(minimum=0.0, min_exclusive=True),
        "InpVolumeMultiplier": Num(minimum=1.0),
        "InpMaxLevelVolume": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
        "InpExitMode": Enum((0, 1)),
        "InpLevelTargetPoints": Num(minimum=0.0),
        "InpBasketTargetPoints": Num(minimum=0.0),
        "InpBasketStopPoints": Num(minimum=0.0, min_exclusive=True),
        "InpMaxVirtualExposure": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
    },
    "DCALabEA": {
        **_COMMON,
        "InpDcaSide": Enum((1, -1)),
        "InpBaseVirtualVolume": Num(minimum=0.0, min_exclusive=True),
        "InpTriggerMode": Enum((0, 1)),
        "InpDcaDistancePoints": Num(minimum=0.0),
        "InpBarsBetweenAdds": Num(minimum=0.0, integer=True),
        "InpMaxDcaAdds": Num(minimum=0.0, maximum=1000.0, integer=True),
        "InpAddVolumeMultiplier": Num(minimum=1.0),
        "InpMaxAddVolume": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
        "InpBasketTargetPoints": Num(minimum=0.0, min_exclusive=True),
        "InpBasketStopPoints": Num(minimum=0.0, min_exclusive=True),
        "InpMaxVirtualExposure": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
    },
    "PinePlanSimEA": {
        **_COMMON,
        "InpSource": Enum((0, 1, 2)),
        "InpSideFilter": Enum((-1, 0, 1)),
        "InpTargetMode": Enum((0, 1, 2)),
        "InpMinStopPoints": Num(minimum=0.0),
        "InpMinTargetPoints": Num(minimum=0.0),
        "InpMaxHoldingBars": Num(minimum=0.0, integer=True),
        "InpBreakEvenEnabled": BOOL,
        "InpBreakEvenTriggerPoints": Num(minimum=0.0),
        "InpBreakEvenOffsetPoints": Num(minimum=0.0),
        "InpTrailEnabled": BOOL,
        "InpTrailFixedPoints": Num(minimum=0.0),
        "InpMinStopPointsTrail": Num(minimum=0.0),
        "InpCooldownBars": Num(minimum=0.0, integer=True),
        "InpVolume": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
        "InpMaxVirtualExposure": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
    },
    "WonderwhalesSimEA": {
        **_COMMON,
        "InpVolume": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
        "InpRequireSymbol": STR_OPTIONAL,
        "InpMode": Enum((0, 1, 2, 3)),
        "InpPsarStart": Num(minimum=0.0, min_exclusive=True),
        "InpPsarInc": Num(minimum=0.0, min_exclusive=True),
        "InpPsarMax": Num(minimum=0.0, min_exclusive=True),
        "InpFastEma": Num(minimum=1.0, integer=True),
        "InpSlowEma": Num(minimum=1.0, integer=True),
        "InpEma200": Num(minimum=1.0, integer=True),
        "InpAtrLen": Num(minimum=1.0, integer=True),
        "InpMinAtrPct": Num(minimum=0.0),
        "InpVolMaLen": Num(minimum=1.0, integer=True),
        "InpRsiLen": Num(minimum=1.0, integer=True),
        "InpBbLen": Num(minimum=1.0, integer=True),
        "InpBbMult": Num(minimum=0.0, min_exclusive=True),
        "InpWarmupBars": Num(minimum=0.0, integer=True),
        "InpSideFilter": Enum((0, 1, 2)),
        "InpStopMode": Enum((0, 1, 2)),
        "InpAtrPctMultiplier": Num(minimum=0.0, min_exclusive=True),
        "InpFixedStopPoints": Num(minimum=0.0, min_exclusive=True),
        "InpMinStopPoints": Num(minimum=0.0),
        "InpMaxHoldingBars": Num(minimum=0.0, integer=True),
        "InpExitOnFlip": BOOL,
        "InpCooldownBars": Num(minimum=0.0, integer=True),
        "InpMaxVirtualExposure": Num(minimum=0.0, maximum=1000.0, min_exclusive=True),
    },
}

EA_NAMES = tuple(EA_INPUTS)


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
    if spec is STR_OPTIONAL:
        if not isinstance(value, str):
            return [f"{name}: must be a string"]
        if "," in value:
            return [f"{name}: must not contain a comma (CSV reason column)"]
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
    if ea == "RunnerTrailingLabEA":
        if inputs["InpSlowEma"] <= inputs["InpFastEma"]:
            issues.append("InpSlowEma: must be greater than InpFastEma")
        if inputs["InpBreakEvenEnabled"] and inputs["InpBreakEvenTriggerPoints"] <= 0:
            issues.append("InpBreakEvenTriggerPoints: must be positive when enabled")
        if inputs["InpTrailMode"] == 0 and inputs["InpTrailFixedPoints"] <= 0:
            issues.append("InpTrailFixedPoints: must be positive in fixed mode")
        if inputs["InpTrailMode"] == 1 and inputs["InpTrailAtrMultiplier"] <= 0:
            issues.append("InpTrailAtrMultiplier: must be positive in ATR mode")
        if inputs["InpMaxVirtualExposure"] < inputs["InpVolume"]:
            issues.append("InpMaxVirtualExposure: must cover InpVolume")

    if ea == "GridLabEA":
        if inputs["InpMaxLevelVolume"] < inputs["InpBaseVirtualVolume"]:
            issues.append("InpMaxLevelVolume: must cover InpBaseVirtualVolume")
        if inputs["InpMaxVirtualExposure"] < inputs["InpBaseVirtualVolume"]:
            issues.append("InpMaxVirtualExposure: must cover InpBaseVirtualVolume")
        if inputs["InpSpacingMode"] == 0 and inputs["InpSpacingPoints"] <= 0:
            issues.append("InpSpacingPoints: must be positive in fixed mode")
        if inputs["InpSpacingMode"] == 1:
            if inputs["InpAtrPeriod"] < 2:
                issues.append("InpAtrPeriod: must be at least 2 in ATR mode")
            if inputs["InpAtrMultiplier"] <= 0:
                issues.append("InpAtrMultiplier: must be positive in ATR mode")
        if inputs["InpExitMode"] == 0 and inputs["InpLevelTargetPoints"] <= 0:
            issues.append("InpLevelTargetPoints: must be positive in LEVEL mode")
        if inputs["InpExitMode"] == 1 and inputs["InpBasketTargetPoints"] <= 0:
            issues.append("InpBasketTargetPoints: must be positive in BASKET mode")

    if ea == "DCALabEA":
        if inputs["InpMaxAddVolume"] < inputs["InpBaseVirtualVolume"]:
            issues.append("InpMaxAddVolume: must cover InpBaseVirtualVolume")
        if inputs["InpMaxVirtualExposure"] < inputs["InpBaseVirtualVolume"]:
            issues.append("InpMaxVirtualExposure: must cover InpBaseVirtualVolume")
        if inputs["InpTriggerMode"] == 0 and inputs["InpDcaDistancePoints"] <= 0:
            issues.append("InpDcaDistancePoints: must be positive in price mode")
        if inputs["InpTriggerMode"] == 1 and inputs["InpBarsBetweenAdds"] < 1:
            issues.append("InpBarsBetweenAdds: must be at least 1 in bar mode")

    if ea == "PinePlanSimEA":
        if inputs["InpMaxVirtualExposure"] < inputs["InpVolume"]:
            issues.append("InpMaxVirtualExposure: must cover InpVolume")
        if inputs["InpBreakEvenEnabled"] and inputs["InpBreakEvenTriggerPoints"] <= 0:
            issues.append("InpBreakEvenTriggerPoints: must be positive when enabled")
        if inputs["InpTrailEnabled"] and inputs["InpTrailFixedPoints"] <= 0:
            issues.append("InpTrailFixedPoints: must be positive when enabled")

    if ea == "WonderwhalesSimEA":
        if inputs["InpSlowEma"] <= inputs["InpFastEma"]:
            issues.append("InpSlowEma: must be greater than InpFastEma")
        if inputs["InpEma200"] <= inputs["InpSlowEma"]:
            issues.append("InpEma200: must be greater than InpSlowEma")
        if inputs["InpWarmupBars"] < inputs["InpEma200"]:
            issues.append("InpWarmupBars: must cover InpEma200")
        if inputs["InpPsarStart"] > inputs["InpPsarMax"]:
            issues.append("InpPsarStart: must not exceed InpPsarMax")
        if inputs["InpPsarInc"] > inputs["InpPsarMax"]:
            issues.append("InpPsarInc: must not exceed InpPsarMax")
        if inputs["InpMaxVirtualExposure"] < inputs["InpVolume"]:
            issues.append("InpMaxVirtualExposure: must cover InpVolume")

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
    if config.get("execution_mode") != EXECUTION_MODE:
        issues.append(f"execution_mode: must be {EXECUTION_MODE}")
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
    for ea in EA_NAMES:
        if ea not in presets:
            issues.append(f"presets.{ea}: missing preset path")
        elif not isinstance(presets[ea], str):
            issues.append(f"presets.{ea}: path must be a string")
    for ea, path in presets.items():
        if ea not in EA_INPUTS:
            issues.append(f"presets.{ea}: unknown EA")
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
        if ea not in EA_INPUTS:
            issues.append(f"{prefix}.ea: must be one of {list(EA_NAMES)}")
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
