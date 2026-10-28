from __future__ import annotations

import importlib.util
import json
from dataclasses import replace
from pathlib import Path
from types import ModuleType

import pandas as pd
import pytest
import yaml

from mt5_ea_ai_lab.backtest import (
    BacktestInputError,
    BoundedBasketConfig,
    run_bounded_basket,
)
from mt5_ea_ai_lab.signals import EmaCrossConfig

REPO_ROOT = Path(__file__).resolve().parents[2]
STRATEGY = EmaCrossConfig(2, 3)
BASE = BoundedBasketConfig(
    initial_equity=10_000.0,
    layer_units=10_000.0,
    max_layers=3,
    max_total_units=30_000.0,
    step_points=200.0,
    take_profit_points=300.0,
    max_basket_loss=300.0,
    point_size=0.00001,
)

# A buy at bar 5, entry at bar 6, then two adverse steps and a take profit.
LAYER_CLOSES = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.09, 1.085, 1.081, 1.079, 1.09]
REVERSAL_CLOSES = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.10, 1.12, 1.11, 1.07, 1.03, 1.02]


def make_frame(
    closes: list[float],
    opens: list[float] | None = None,
    highs: list[float] | None = None,
    lows: list[float] | None = None,
) -> pd.DataFrame:
    count = len(closes)
    if opens is None:
        opens = [closes[0]] + closes[:-1]
    if highs is None:
        highs = [
            max(open_price, close) + 0.001
            for open_price, close in zip(opens, closes)
        ]
    if lows is None:
        lows = [
            min(open_price, close) - 0.001
            for open_price, close in zip(opens, closes)
        ]
    return pd.DataFrame(
        {
            "timestamp": pd.date_range(
                "2024-01-01", periods=count, freq="5min", tz="UTC"
            ),
            "open": opens,
            "high": highs,
            "low": lows,
            "close": closes,
        }
    )


def test_basket_adds_layers_and_takes_profit_within_caps() -> None:
    result = run_bounded_basket(make_frame(LAYER_CLOSES), STRATEGY, BASE)

    assert len(result.baskets) == 1
    basket = result.baskets.iloc[0]
    assert basket["layer_count"] == 3
    assert basket["units"] == pytest.approx(30_000.0)
    assert basket["average_entry"] == pytest.approx(1.0876666667)
    assert basket["exit_fill"] == pytest.approx(1.0906666667)
    assert basket["pnl"] == pytest.approx(90.0)
    assert basket["exit_reason"] == "basket_take_profit"
    assert basket["blocked_add_bars"] == 1
    assert bool(basket["layer_cap_reached"]) is True

    assert list(result.trades["entry_bar"]) == [6, 7, 8]
    assert list(result.trades["entry_fill"]) == pytest.approx(
        [1.09, 1.088, 1.085]
    )
    assert list(result.trades["layer_index"]) == [0, 1, 2]
    assert list(result.trades["basket_id"]) == [1, 1, 1]

    assert result.metrics["trade_count"] == 3
    assert result.metrics["win_rate"] == pytest.approx(1.0)
    assert result.metrics["final_equity"] == pytest.approx(10_090.0)
    assert result.equity["position"].iloc[7] == 2
    assert result.equity["position"].iloc[10] == 0

    limits = result.hard_limits
    assert limits["max_observed_layers"] == 3
    assert limits["max_observed_units"] == pytest.approx(30_000.0)
    assert limits["layers_within_cap"] is True
    assert limits["units_within_cap"] is True
    assert limits["blocked_add_bars"] == 1
    assert limits["baskets_at_layer_cap"] == 1
    assert limits["loss_cap_overshoot"] == 0.0


def test_max_layers_is_a_hard_cap() -> None:
    config = replace(BASE, max_layers=2)
    result = run_bounded_basket(make_frame(LAYER_CLOSES), STRATEGY, config)

    basket = result.baskets.iloc[0]
    assert basket["layer_count"] == 2
    assert basket["units"] == pytest.approx(20_000.0)
    assert basket["blocked_add_bars"] == 3
    assert basket["exit_reason"] == "end_of_data"
    assert basket["pnl"] == pytest.approx(20.0)
    assert result.hard_limits["max_observed_layers"] == 2
    assert result.hard_limits["max_observed_layers"] <= config.max_layers


def test_max_total_units_is_a_hard_cap() -> None:
    config = replace(BASE, max_layers=5, max_total_units=15_000.0)
    assert config.effective_max_layers() == 1

    result = run_bounded_basket(make_frame(LAYER_CLOSES), STRATEGY, config)

    basket = result.baskets.iloc[0]
    assert basket["layer_count"] == 1
    assert basket["units"] == pytest.approx(10_000.0)
    assert basket["blocked_add_bars"] == 4
    assert basket["exit_reason"] == "end_of_data"
    assert basket["pnl"] == pytest.approx(0.0)
    assert result.hard_limits["max_observed_units"] == pytest.approx(10_000.0)
    assert result.hard_limits["max_observed_units"] <= config.max_total_units


def test_only_one_layer_is_added_per_bar() -> None:
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.09, 1.08, 1.08]
    result = run_bounded_basket(make_frame(closes), STRATEGY, BASE)

    per_bar = result.trades.groupby("entry_bar").size().to_dict()
    assert per_bar[7] == 1
    assert per_bar[8] == 1
    assert result.baskets.iloc[0]["layer_count"] == 3


def test_net_loss_cap_closes_the_basket() -> None:
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.09, 1.07, 1.07]
    config = replace(BASE, max_layers=1, max_basket_loss=100.0)
    result = run_bounded_basket(make_frame(closes), STRATEGY, config)

    basket = result.baskets.iloc[0]
    assert basket["exit_reason"] == "basket_loss_cap"
    assert basket["exit_fill"] == pytest.approx(1.08)
    assert basket["pnl"] == pytest.approx(-100.0)
    assert result.metrics["final_equity"] == pytest.approx(9_900.0)
    assert result.hard_limits["worst_realized_basket_loss"] == pytest.approx(100.0)
    assert result.hard_limits["loss_cap_overshoot"] == 0.0


def test_loss_cap_includes_entry_and_exit_commissions() -> None:
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.09, 1.07, 1.07]
    config = replace(
        BASE,
        max_layers=1,
        max_basket_loss=100.0,
        commission_per_side=2.5,
    )
    result = run_bounded_basket(make_frame(closes), STRATEGY, config)

    basket = result.baskets.iloc[0]
    assert basket["exit_reason"] == "basket_loss_cap"
    assert basket["exit_fill"] == pytest.approx(1.0805)
    assert basket["commission"] == pytest.approx(5.0)
    assert basket["pnl"] == pytest.approx(-100.0)


def test_take_profit_closes_every_layer_at_the_same_fill() -> None:
    result = run_bounded_basket(make_frame(LAYER_CLOSES), STRATEGY, BASE)

    exits = result.trades["exit_fill"].unique()
    assert len(exits) == 1
    assert exits[0] == pytest.approx(1.0906666667)
    assert set(result.trades["exit_reason"]) == {"basket_take_profit"}


def test_opposite_signal_closes_the_basket_and_opens_the_other_side() -> None:
    config = replace(BASE, take_profit_points=100_000.0, max_basket_loss=5_000.0)
    result = run_bounded_basket(make_frame(REVERSAL_CLOSES), STRATEGY, config)

    assert len(result.baskets) == 2
    first, second = result.baskets.iloc[0], result.baskets.iloc[1]
    assert first["exit_reason"] == "opposite_signal"
    assert first["close_bar"] == 10
    assert second["side"] == "short"
    assert second["open_bar"] == 10
    assert second["exit_reason"] == "end_of_data"


def test_opposite_signal_can_be_ignored() -> None:
    config = replace(
        BASE,
        take_profit_points=100_000.0,
        max_basket_loss=5_000.0,
        close_on_opposite_signal=False,
    )
    result = run_bounded_basket(make_frame(REVERSAL_CLOSES), STRATEGY, config)

    assert len(result.baskets) == 1
    basket = result.baskets.iloc[0]
    assert basket["side"] == "long"
    assert basket["exit_reason"] == "end_of_data"
    assert "opposite_signal" not in set(result.baskets["exit_reason"])


def test_grid_and_dca_diverge_after_a_gap_fill() -> None:
    closes = [1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.09, 1.085, 1.0855, 1.086, 1.09]
    opens = [1.10, 1.10, 1.09, 1.08, 1.07, 1.06, 1.09, 1.085, 1.0855, 1.086, 1.09]
    highs = [1.101, 1.101, 1.091, 1.081, 1.071, 1.091, 1.091, 1.086, 1.0865, 1.087, 1.09]
    lows = [1.099, 1.089, 1.079, 1.069, 1.059, 1.059, 1.089, 1.084, 1.0855, 1.0855, 1.089]
    frame = make_frame(closes, opens, highs, lows)

    dca = run_bounded_basket(frame, STRATEGY, replace(BASE, mode="dca"))
    grid = run_bounded_basket(frame, STRATEGY, replace(BASE, mode="grid"))

    assert dca.baskets.iloc[0]["layer_count"] == 2
    assert dca.baskets.iloc[0]["pnl"] == pytest.approx(50.0)
    assert grid.baskets.iloc[0]["layer_count"] == 3
    assert grid.baskets.iloc[0]["pnl"] == pytest.approx(95.0)
    assert grid.baskets.iloc[0]["exit_reason"] == "basket_take_profit"


def test_hard_limits_are_reported_on_the_basket_summary() -> None:
    result = run_bounded_basket(make_frame(LAYER_CLOSES), STRATEGY, BASE)
    summary = result.to_summary_dict()

    assert summary["basket_count"] == 1
    assert summary["basket_exit_reason_counts"] == {"basket_take_profit": 1}
    assert summary["hard_limits"]["effective_max_layers"] == 3
    assert summary["hard_limits"]["max_basket_loss"] == pytest.approx(300.0)
    assert summary["signal_counts"]["BUY"] >= 1


@pytest.mark.parametrize(
    ("config", "match"),
    [
        (replace(BASE, max_layers=0), "max_layers"),
        (replace(BASE, max_layers=True), "max_layers"),
        (replace(BASE, max_total_units=5_000.0), "max_total_units"),
        (replace(BASE, step_points=0.0), "step_points"),
        (replace(BASE, take_profit_points=0.0), "take_profit_points"),
        (replace(BASE, max_basket_loss=0.0), "max_basket_loss"),
        (replace(BASE, max_basket_loss=10_000.0), "lower than initial_equity"),
        (replace(BASE, spread_points=-1.0), "spread_points"),
        (replace(BASE, mode="martingale"), "mode"),
        (replace(BASE, close_on_opposite_signal="yes"), "close_on_opposite_signal"),
        (
            replace(
                BASE,
                max_layers=3,
                commission_per_side=100.0,
                max_basket_loss=300.0,
            ),
            "commissions",
        ),
    ],
)
def test_invalid_configs_are_rejected(
    config: BoundedBasketConfig, match: str
) -> None:
    with pytest.raises(BacktestInputError, match=match):
        config.validate()


def test_empty_dataset_is_rejected() -> None:
    frame = make_frame(LAYER_CLOSES).iloc[0:0]
    with pytest.raises(BacktestInputError, match="empty"):
        run_bounded_basket(frame, STRATEGY, BASE)


def load_script() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "run_basket_backtest_script",
        REPO_ROOT / "scripts" / "run_basket_backtest.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="module")
def runner() -> ModuleType:
    return load_script()


def write_dataset(path: Path) -> Path:
    frame = make_frame(LAYER_CLOSES)
    frame["tick_volume"] = 100
    path.write_text(frame.to_csv(index=False), encoding="utf-8")
    return path


def write_config(
    path: Path,
    *,
    data_path: Path,
    report_dir: Path,
    basket_extra: dict[str, object] | None = None,
) -> Path:
    basket = {
        "initial_equity": 10_000.0,
        "layer_units": 10_000.0,
        "max_layers": 3,
        "max_total_units": 30_000.0,
        "step_points": 200.0,
        "take_profit_points": 300.0,
        "max_basket_loss": 300.0,
        "point_size": 0.00001,
        "spread_points": 2.0,
        "slippage_points": 1.0,
        "commission_per_side": 1.0,
        "mode": "dca",
        "close_on_opposite_signal": True,
    }
    if basket_extra:
        basket.update(basket_extra)
    config = {
        "experiment_id": "cli-basket",
        "data": {
            "path": str(data_path),
            "symbol": "EURUSD",
            "timeframe": "M5",
            "timezone": "UTC",
            "data_kind": "synthetic",
        },
        "strategy": {
            "fast_period": 2,
            "slow_period": 3,
            "allow_long": True,
            "allow_short": True,
        },
        "basket": basket,
        "seed": 42,
        "outputs": {"report_dir": str(report_dir), "plot": False},
        "notes": "cli integration test",
    }
    path.write_text(yaml.safe_dump(config, sort_keys=False), encoding="utf-8")
    return path


def test_cli_writes_basket_artifacts(
    runner: ModuleType, tmp_path: Path
) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    report_dir = tmp_path / "report"
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=report_dir,
    )

    assert runner.main(["--config", str(config_path)]) == 0

    summary = json.loads((report_dir / "summary.json").read_text(encoding="utf-8"))
    assert summary["status"] == "completed"
    assert summary["engine"] == "bounded_basket"
    assert summary["hard_limits"]["layers_within_cap"] is True
    assert summary["hard_limits"]["units_within_cap"] is True
    for name in (
        "trades.csv",
        "equity.csv",
        "signals.csv",
        "baskets.csv",
        "validation.json",
        "validation.csv",
    ):
        assert (report_dir / name).is_file(), name

    baskets = pd.read_csv(report_dir / "baskets.csv")
    assert len(baskets) == 1
    assert baskets.iloc[0]["exit_reason"] == "basket_take_profit"

    trades = pd.read_csv(report_dir / "trades.csv")
    assert len(trades) == 3
    assert set(trades["basket_id"]) == {1}


def test_cli_rejects_invalid_basket_config(
    runner: ModuleType, tmp_path: Path
) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "report",
        basket_extra={"max_layers": 0},
    )

    assert runner.main(["--config", str(config_path)]) == 1
    assert not (tmp_path / "report" / "summary.json").exists()


def test_cli_rejects_non_boolean_opposite_signal_flag(
    runner: ModuleType, tmp_path: Path
) -> None:
    data_path = write_dataset(tmp_path / "data.csv")
    config_path = write_config(
        tmp_path / "config.yaml",
        data_path=data_path,
        report_dir=tmp_path / "report",
        basket_extra={"close_on_opposite_signal": "yes"},
    )

    assert runner.main(["--config", str(config_path)]) == 1


@pytest.mark.parametrize(
    "name",
    [
        "backtest.bounded-basket-synthetic.yaml",
        "backtest.bounded-grid-synthetic.yaml",
    ],
)
def test_shipped_basket_configs_validate(
    runner: ModuleType, name: str
) -> None:
    config = runner.load_config(REPO_ROOT / "configs" / name)

    assert config["data_kind"] == "synthetic"
    assert config["basket"].effective_max_layers() >= 1
