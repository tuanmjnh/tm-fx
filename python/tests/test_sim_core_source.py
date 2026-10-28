from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SIM_DIR = REPO_ROOT / "mt5" / "Include" / "Sim"
LOGGER = SIM_DIR / "SimLogger.mqh"
TESTS = REPO_ROOT / "mt5" / "Scripts" / "SimCoreTests.mq5"
EXPERTS = REPO_ROOT / "mt5" / "Experts"

EXPECTED_COLUMNS = (
    "logged_at",
    "bar_time",
    "ea",
    "version",
    "config_hash",
    "symbol",
    "timeframe",
    "event",
    "side",
    "price",
    "volume",
    "entry",
    "sl",
    "tp",
    "exposure",
    "equity",
    "drawdown_pct",
    "reason",
)

FORBIDDEN_TOKENS = (
    "OrderSend",
    "OrderSendAsync",
    "CTrade",
    "MqlTradeRequest",
    "MqlTradeResult",
    "PositionOpen",
    "PositionClose",
    "PositionModify",
    "OrderOpen",
    "OrderClose",
    "OrderModify",
)


def _header_columns() -> tuple[str, ...]:
    text = LOGGER.read_text(encoding="utf-8")
    match = re.search(r'#define\s+SIM_LOG_HEADER\s+"([^"]+)"', text)
    assert match, "SIM_LOG_HEADER not found in SimLogger.mqh"
    return tuple(match.group(1).split(","))


def test_log_header_matches_documented_schema() -> None:
    columns = _header_columns()
    assert columns == EXPECTED_COLUMNS
    assert len(columns) == 18
    assert len(set(columns)) == len(columns)


def test_log_format_placeholders_match_header() -> None:
    text = LOGGER.read_text(encoding="utf-8")
    match = re.search(
        r"StringFormat\(\"([^\"]*)\",\s*TimeToString", text, re.DOTALL
    )
    assert match, "SimFormatLogLine format string not found"
    assert match.group(1).count("%") == len(EXPECTED_COLUMNS)


def test_sim_sources_contain_no_trade_apis() -> None:
    sources = (
        sorted(SIM_DIR.glob("*.mqh"))
        + [TESTS]
        + sorted(EXPERTS.glob("*.mq5"))
    )
    assert sources, "no simulation sources found"
    for path in sources:
        text = path.read_text(encoding="utf-8")
        for token in FORBIDDEN_TOKENS:
            assert token not in text, f"{token} found in {path.name}"


def _fnv1a32(text: str) -> str:
    value = 2166136261
    for byte in text.encode("utf-8"):
        value ^= byte
        value = (value * 16777619) & 0xFFFFFFFF
    return f"{value:08X}"


def test_fnv1a32_matches_mql5_vectors() -> None:
    assert _fnv1a32("abc") == "1A47E90B"
    assert _fnv1a32("") == "811C9DC5"


def test_sim_core_tests_cover_documented_groups() -> None:
    text = TESTS.read_text(encoding="utf-8")
    ids = re.findall(r'Record\("([A-Z]+\d+)"', text)
    assert len(ids) == len(set(ids)), "duplicate test id"
    prefixes = {re.match(r"[A-Z]+", test_id).group(0) for test_id in ids}
    assert prefixes == {"P", "V", "H", "L", "C", "R", "T", "G", "D"}
    assert len(ids) >= 123


def test_risk_guard_reason_tokens_are_stable() -> None:
    text = (SIM_DIR / "SimRiskGuard.mqh").read_text(encoding="utf-8")
    for token in (
        "price_invalid",
        "spread_exceeded",
        "cooldown_active",
        "max_virtual_positions_reached",
        "max_grid_levels_reached",
        "max_dca_adds_reached",
        "max_virtual_exposure_reached",
        "daily_loss_limit_reached",
        "max_drawdown_reached",
        "day_start_equity_invalid",
        "peak_equity_invalid",
        "kill_switch_active",
    ):
        assert f'"{token}"' in text, f"missing reason token {token}"


def test_cost_model_tokens_are_stable() -> None:
    validate = (SIM_DIR / "SimValidate.mqh").read_text(encoding="utf-8")
    cost = (SIM_DIR / "SimCostModel.mqh").read_text(encoding="utf-8")
    assert '"point_must_be_finite_positive"' in validate
    assert '"swap_must_be_finite"' in cost
    assert "SimValidatePoint(assumptions.point" in cost


def test_trailing_reason_tokens_are_stable() -> None:
    text = (SIM_DIR / "SimTrailing.mqh").read_text(encoding="utf-8")
    for token in ("invalid_inputs", "candidate_too_close", "not_improving"):
        assert f'"{token}"' in text, f"missing reason token {token}"


def test_grid_reason_tokens_are_stable() -> None:
    text = (SIM_DIR / "SimGrid.mqh").read_text(encoding="utf-8")
    for token in (
        "grid_level_invalid",
        "max_grid_levels_reached",
        "grid_volume_invalid",
        "exposure_invalid",
        "max_virtual_exposure_invalid",
        "max_virtual_exposure_reached",
    ):
        assert f'"{token}"' in text, f"missing reason token {token}"


def test_portfolio_partial_close_tokens_are_stable() -> None:
    text = (SIM_DIR / "SimPortfolio.mqh").read_text(encoding="utf-8")
    for token in ("min_profit_must_be_finite", "no_matching_positions"):
        assert f'"{token}"' in text, f"missing error token {token}"


def test_dca_reason_tokens_are_stable() -> None:
    text = (SIM_DIR / "SimDca.mqh").read_text(encoding="utf-8")
    for token in (
        "max_dca_adds_invalid",
        "dca_adds_invalid",
        "max_dca_adds_reached",
        "dca_volume_invalid",
        "exposure_invalid",
        "max_virtual_exposure_invalid",
        "max_virtual_exposure_reached",
    ):
        assert f'"{token}"' in text, f"missing reason token {token}"


def test_dca_ea_keeps_zero_adds_disabled() -> None:
    text = (REPO_ROOT / "mt5" / "Experts" / "DCALabEA.mq5").read_text(
        encoding="utf-8"
    )
    assert "if(InpMaxDcaAdds<=0)" in text
    assert "g_last_fill_bar==bar_time" in text
    assert "SimRiskGuard" in text or "SimRiskGuard.mqh" in text
