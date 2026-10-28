"""Run a bounded DCA/grid basket simulation from a YAML configuration.

Simulation only: no order routing, broker connection or account access.

Exit codes:
    0  simulation completed
    1  configuration or dataset could not be loaded
    2  dataset validation failed (invalid_data)
    3  simulation failed after loading

Artifacts are written to the configured report directory: summary.json,
trades.csv, equity.csv, signals.csv, baskets.csv, validation.json/csv and an
optional equity.png. Re-running the same configuration overwrites those
artifacts. This CLI is intentionally not wired into the experiment store yet.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

import pandas as pd
import yaml

from mt5_ea_ai_lab.backtest import (
    BacktestInputError,
    BoundedBasketConfig,
    run_bounded_basket,
)
from mt5_ea_ai_lab.data.loader import DATA_KINDS, DataLoadError, load_ohlcv
from mt5_ea_ai_lab.signals import EmaCrossConfig
from mt5_ea_ai_lab.validation import validate_ohlcv

TIMEFRAME_STEP_SECONDS: dict[str, float] = {
    "M1": 60.0,
    "M5": 300.0,
    "M15": 900.0,
    "M30": 1800.0,
    "H1": 3600.0,
    "H4": 14400.0,
    "D1": 86400.0,
}

BASKET_FIELDS = (
    "initial_equity",
    "layer_units",
    "max_layers",
    "max_total_units",
    "step_points",
    "take_profit_points",
    "max_basket_loss",
    "point_size",
    "spread_points",
    "slippage_points",
    "commission_per_side",
)


class ConfigError(ValueError):
    """Raised when the YAML configuration is missing or malformed."""


def _require_mapping(value: Any, name: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ConfigError(f"{name} must be a mapping")
    return value


def _require_key(mapping: dict[str, Any], key: str, name: str) -> Any:
    if key not in mapping:
        raise ConfigError(f"{name}.{key} is required")
    return mapping[key]


def _require_int(value: Any, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ConfigError(f"{name} must be an integer")
    return value


def _require_float(value: Any, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ConfigError(f"{name} must be a number")
    return float(value)


def _require_bool(value: Any, name: str) -> bool:
    if not isinstance(value, bool):
        raise ConfigError(f"{name} must be a boolean")
    return value


def _resolve(path_value: str, base: Path) -> Path:
    candidate = Path(path_value)
    return candidate if candidate.is_absolute() else (base / candidate)


def load_config(path: Path) -> dict[str, Any]:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ConfigError(f"config file not found: {path}") from exc
    except yaml.YAMLError as exc:
        raise ConfigError(f"cannot parse YAML config: {exc}") from exc

    config = _require_mapping(raw, "config")
    experiment_id = _require_key(config, "experiment_id", "config")
    if not isinstance(experiment_id, str) or not experiment_id.strip():
        raise ConfigError("config.experiment_id must be a non-empty string")

    data = _require_mapping(_require_key(config, "data", "config"), "config.data")
    data_path = _require_key(data, "path", "config.data")
    if not isinstance(data_path, str) or not data_path.strip():
        raise ConfigError("config.data.path must be a non-empty string")
    data_kind = data.get("data_kind", "unknown")
    if data_kind not in DATA_KINDS:
        raise ConfigError(f"config.data.data_kind must be one of {DATA_KINDS}")
    symbol = data.get("symbol")
    timeframe = data.get("timeframe")
    timezone_name = data.get("timezone", "UTC")

    strategy = _require_mapping(
        _require_key(config, "strategy", "config"), "config.strategy"
    )
    strategy_config = EmaCrossConfig(
        fast_period=_require_int(
            _require_key(strategy, "fast_period", "config.strategy"),
            "config.strategy.fast_period",
        ),
        slow_period=_require_int(
            _require_key(strategy, "slow_period", "config.strategy"),
            "config.strategy.slow_period",
        ),
        allow_long=_require_bool(
            strategy.get("allow_long", True), "config.strategy.allow_long"
        ),
        allow_short=_require_bool(
            strategy.get("allow_short", True), "config.strategy.allow_short"
        ),
    )
    strategy_config.validate()

    basket_raw = _require_mapping(
        _require_key(config, "basket", "config"), "config.basket"
    )
    basket_kwargs: dict[str, Any] = {}
    for field in BASKET_FIELDS:
        value = _require_key(basket_raw, field, "config.basket")
        key = f"config.basket.{field}"
        basket_kwargs[field] = (
            _require_int(value, key)
            if field == "max_layers"
            else _require_float(value, key)
        )
    if "mode" in basket_raw:
        mode = basket_raw["mode"]
        if not isinstance(mode, str):
            raise ConfigError("config.basket.mode must be a string")
        basket_kwargs["mode"] = mode
    if "close_on_opposite_signal" in basket_raw:
        basket_kwargs["close_on_opposite_signal"] = _require_bool(
            basket_raw["close_on_opposite_signal"],
            "config.basket.close_on_opposite_signal",
        )
    basket_config = BoundedBasketConfig(**basket_kwargs)
    basket_config.validate()

    outputs = _require_mapping(config.get("outputs", {}), "config.outputs")
    report_dir = outputs.get("report_dir", "reports/backtests")
    if not isinstance(report_dir, str) or not report_dir.strip():
        raise ConfigError("config.outputs.report_dir must be a non-empty string")
    plot = _require_bool(outputs.get("plot", False), "config.outputs.plot")

    seed = config.get("seed", 0)
    if isinstance(seed, bool) or not isinstance(seed, int):
        raise ConfigError("config.seed must be an integer")

    return {
        "experiment_id": experiment_id.strip(),
        "data_path": data_path.strip(),
        "data_kind": data_kind,
        "symbol": str(symbol) if symbol else None,
        "timeframe": str(timeframe) if timeframe else None,
        "timezone": str(timezone_name),
        "strategy": strategy_config,
        "basket": basket_config,
        "seed": seed,
        "report_dir": report_dir.strip(),
        "plot": plot,
        "notes": config.get("notes"),
    }


def _write_csv(
    path: Path, frame: pd.DataFrame, timestamp_columns: tuple[str, ...] = ()
) -> None:
    output = frame.copy()
    for column in timestamp_columns:
        if column in output.columns and len(output):
            output[column] = output[column].map(
                lambda value: pd.Timestamp(value).isoformat()
            )
    output.to_csv(path, index=False)


def _write_summary(path: Path, summary: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(summary, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def _equity_plot(equity: pd.DataFrame, destination: Path) -> None:
    cache_dir = destination.parent / ".mplconfig"
    cache_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("MPLCONFIGDIR", str(cache_dir))
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    figure, axes = plt.subplots(figsize=(9, 4.5))
    axes.plot(equity["timestamp"], equity["equity"], color="#1f6feb", linewidth=1.5)
    axes.set_title("Equity curve (bounded basket)")
    axes.set_xlabel("Time (UTC)")
    axes.set_ylabel("Equity (quote currency)")
    axes.grid(True, alpha=0.3)
    figure.autofmt_xdate()
    figure.tight_layout()
    figure.savefig(destination, dpi=120)
    plt.close(figure)


def _execute(
    args: argparse.Namespace, config: dict[str, Any], config_path: Path
) -> int:
    data_path = _resolve(config["data_path"], REPO_ROOT)
    report_dir = _resolve(args.out_dir or config["report_dir"], REPO_ROOT)
    report_dir.mkdir(parents=True, exist_ok=True)

    summary: dict[str, Any] = {
        "status": "started",
        "engine": "bounded_basket",
        "experiment_id": config["experiment_id"],
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "config_path": str(config_path),
        "repo_root": str(REPO_ROOT),
        "data": {
            "path": str(data_path),
            "data_kind": config["data_kind"],
            "symbol": config["symbol"],
            "timeframe": config["timeframe"],
        },
        "strategy": asdict(config["strategy"]),
        "basket": config["basket"].to_dict(),
        "effective_max_layers": config["basket"].effective_max_layers(),
        "seed": config["seed"],
        "deterministic": True,
        "notes": config["notes"],
    }
    summary_path = report_dir / "summary.json"

    try:
        frame, loaded_metadata = load_ohlcv(
            data_path,
            symbol=config["symbol"],
            timeframe=config["timeframe"],
            timezone=config["timezone"],
            data_kind=config["data_kind"],
        )
    except (DataLoadError, FileNotFoundError, OSError) as exc:
        print(f"load_error: {exc}", file=sys.stderr)
        summary["status"] = "failed"
        summary["error"] = f"load_error: {exc}"
        _write_summary(summary_path, summary)
        return 1

    summary["data"]["metadata"] = loaded_metadata.to_dict()

    expected_step = (
        TIMEFRAME_STEP_SECONDS.get(config["timeframe"])
        if config["timeframe"]
        else None
    )
    validation = validate_ohlcv(
        frame, metadata=loaded_metadata, expected_step=expected_step
    )
    validation_json = validation.to_json(report_dir / "validation.json")
    validation_csv = validation.to_csv(report_dir / "validation.csv")
    summary["validation"] = {
        "passed": validation.passed,
        "errors": len(validation.errors),
        "warnings": len(validation.warnings),
        "json": str(validation_json),
        "csv": str(validation_csv),
        "issues": [issue.to_dict() for issue in validation.issues],
    }

    if not validation.passed:
        summary["status"] = "invalid_data"
        _write_summary(summary_path, summary)
        print(
            f"invalid_data: {len(validation.errors)} validation error(s); "
            f"see {validation_json}",
            file=sys.stderr,
        )
        return 2

    try:
        result = run_bounded_basket(frame, config["strategy"], config["basket"])
    except (BacktestInputError, ValueError) as exc:
        summary["status"] = "failed"
        summary["error"] = f"simulation_error: {exc}"
        _write_summary(summary_path, summary)
        print(f"simulation_error: {exc}", file=sys.stderr)
        return 3

    trades_path = report_dir / "trades.csv"
    equity_path = report_dir / "equity.csv"
    signals_path = report_dir / "signals.csv"
    baskets_path = report_dir / "baskets.csv"
    _write_csv(trades_path, result.trades)
    _write_csv(equity_path, result.equity, ("timestamp",))
    _write_csv(signals_path, result.signals, ("timestamp",))
    _write_csv(baskets_path, result.baskets)

    summary.update(
        {
            "status": "completed",
            "metrics": result.metrics,
            "hard_limits": result.hard_limits,
            "signal_counts": result.to_summary_dict()["signal_counts"],
            "basket_count": int(len(result.baskets)),
            "basket_exit_reason_counts": result.to_summary_dict()[
                "basket_exit_reason_counts"
            ],
            "artifacts": {
                "summary": str(summary_path),
                "trades": str(trades_path),
                "equity": str(equity_path),
                "signals": str(signals_path),
                "baskets": str(baskets_path),
                "validation_json": str(validation_json),
                "validation_csv": str(validation_csv),
            },
        }
    )

    plot_path: Path | None = None
    if config["plot"] and not args.no_plot and not result.equity.empty:
        plot_path = report_dir / "equity.png"
        _equity_plot(result.equity, plot_path)
        summary["artifacts"]["equity_plot"] = str(plot_path)

    _write_summary(summary_path, summary)

    limits = result.hard_limits
    print(
        f"experiment={config['experiment_id']} status=completed "
        f"bars={result.metrics['bars']} baskets={len(result.baskets)} "
        f"layers={result.metrics['trade_count']} "
        f"final_equity={result.metrics['final_equity']:.2f} "
        f"net_profit={result.metrics['net_profit']:.2f} "
        f"max_layers_observed={limits['max_observed_layers']} "
        f"blocked_add_bars={limits['blocked_add_bars']}"
    )
    print(f"report_dir={report_dir}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run a bounded DCA/grid basket simulation from a YAML config."
    )
    parser.add_argument(
        "--config",
        default=str(REPO_ROOT / "configs" / "backtest.bounded-basket-synthetic.yaml"),
        help="path to the basket YAML config",
    )
    parser.add_argument(
        "--out-dir",
        default=None,
        help="override outputs.report_dir (resolved against the repository root)",
    )
    parser.add_argument(
        "--no-plot",
        action="store_true",
        help="disable the equity plot even when outputs.plot is true",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    config_path = Path(args.config).resolve()

    try:
        config = load_config(config_path)
    except (ConfigError, BacktestInputError, ValueError) as exc:
        print(f"config_error: {exc}", file=sys.stderr)
        return 1

    try:
        return _execute(args, config, config_path)
    except OSError as exc:
        print(f"io_error: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
