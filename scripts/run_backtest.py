"""Run a deterministic backtest from a YAML configuration.

Exit codes:
    0  backtest completed
    1  configuration or dataset could not be loaded
    2  dataset validation failed (invalid_data)
    3  backtest failed after loading
    4  experiment_id already exists in the store (nothing was overwritten)
    5  experiment store could not record the run

Artifacts are written to the configured report directory: summary.json,
trades.csv, equity.csv, signals.csv, validation.json/csv and an optional
equity.png. Without ``--store`` re-running the same configuration overwrites
those artifacts. With ``--store`` artifacts are isolated under
``<report_dir>/<experiment_id>`` and a duplicate experiment ID is rejected.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

import pandas as pd
import yaml

from mt5_ea_ai_lab import __version__
from mt5_ea_ai_lab.backtest import (
    BacktestInputError,
    ExecutionConfig,
    run_backtest,
    signal_counts,
)
from mt5_ea_ai_lab.data.loader import DATA_KINDS, DataLoadError, load_ohlcv
from mt5_ea_ai_lab.experiment_store import (
    Artifact,
    DuplicateExperimentError,
    ExperimentStore,
    FingerprintError,
    RunMetadata,
    StoreError,
    hash_config,
    read_git_state,
    sha256_file,
    validate_experiment_id,
)
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

EXECUTION_FIELDS = (
    "initial_equity",
    "position_units",
    "point_size",
    "spread_points",
    "slippage_points",
    "commission_per_side",
    "stop_loss_points",
    "take_profit_points",
    "trailing_stop_points",
    "trailing_activation_points",
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


def _require_optional_float(value: Any, name: str) -> float | None:
    if value is None:
        return None
    return _require_float(value, name)


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

    execution_raw = _require_mapping(
        _require_key(config, "execution", "config"), "config.execution"
    )
    execution_kwargs: dict[str, Any] = {}
    for field in EXECUTION_FIELDS:
        if field not in execution_raw:
            continue
        key = f"config.execution.{field}"
        if field in (
            "stop_loss_points",
            "take_profit_points",
            "trailing_stop_points",
            "trailing_activation_points",
        ):
            execution_kwargs[field] = _require_optional_float(execution_raw[field], key)
        else:
            execution_kwargs[field] = _require_float(execution_raw[field], key)
    execution_config = ExecutionConfig(**execution_kwargs)
    execution_config.validate()

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
        "execution": execution_config,
        "seed": seed,
        "report_dir": report_dir.strip(),
        "plot": plot,
        "notes": config.get("notes"),
    }


def build_effective_config(config: dict[str, Any]) -> dict[str, Any]:
    """Semantic configuration used for the experiment config hash.

    The dataset path, output directory, plot flag, notes and experiment ID are
    excluded on purpose: file content is covered by ``data_fingerprint`` and
    the other fields do not change simulation behavior.
    """

    return {
        "data": {
            "data_kind": config["data_kind"],
            "symbol": config["symbol"],
            "timeframe": config["timeframe"],
            "timezone": config["timezone"],
        },
        "strategy": asdict(config["strategy"]),
        "execution": config["execution"].to_dict(),
        "seed": config["seed"],
    }


def _iso_timestamps(series: pd.Series) -> pd.Series:
    return series.map(lambda value: pd.Timestamp(value).isoformat())


def _write_csv(path: Path, frame: pd.DataFrame, timestamp_columns: tuple[str, ...] = ()) -> None:
    output = frame.copy()
    for column in timestamp_columns:
        if column in output.columns and len(output):
            output[column] = _iso_timestamps(output[column])
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
    axes.set_title("Equity curve")
    axes.set_xlabel("Time (UTC)")
    axes.set_ylabel("Equity (quote currency)")
    axes.grid(True, alpha=0.3)
    figure.autofmt_xdate()
    figure.tight_layout()
    figure.savefig(destination, dpi=120)
    plt.close(figure)


def _collect_artifacts(items: list[tuple[str, Path]]) -> list[Artifact]:
    artifacts: list[Artifact] = []
    for name, path in items:
        if not path.is_file():
            continue
        try:
            artifacts.append(
                Artifact(
                    name=name,
                    path=str(path),
                    sha256=sha256_file(path),
                    size_bytes=path.stat().st_size,
                )
            )
        except OSError as exc:
            print(f"artifact_warning: {exc}", file=sys.stderr)
            artifacts.append(Artifact(name=name, path=str(path)))
    return artifacts


def _finish_store(
    store: ExperimentStore | None,
    experiment_id: str,
    status: str,
    *,
    artifacts: list[Artifact],
    metrics: dict[str, Any] | None = None,
    benchmark: dict[str, Any] | None = None,
    signal_counts_value: dict[str, Any] | None = None,
    validation: dict[str, Any] | None = None,
    error: str | None = None,
) -> bool:
    if store is None:
        return True
    try:
        store.finish_run(
            experiment_id,
            status,
            metrics=metrics,
            benchmark=benchmark,
            signal_counts=signal_counts_value,
            validation=validation,
            error=error,
            artifacts=artifacts,
        )
        return True
    except (StoreError, sqlite3.Error) as exc:
        print(f"store_error: {exc}", file=sys.stderr)
        return False


def _execute(
    args: argparse.Namespace,
    config: dict[str, Any],
    config_path: Path,
    store: ExperimentStore | None,
    metadata: RunMetadata | None,
) -> int:
    data_path = _resolve(config["data_path"], REPO_ROOT)
    base_report_dir = _resolve(args.out_dir or config["report_dir"], REPO_ROOT)
    experiment_id = metadata.experiment_id if metadata is not None else config["experiment_id"]
    report_dir = (
        base_report_dir / experiment_id if metadata is not None else base_report_dir
    )
    report_dir.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    summary: dict[str, Any] = {
        "status": "started",
        "experiment_id": experiment_id,
        "generated_at_utc": generated_at,
        "config_path": str(config_path),
        "repo_root": str(REPO_ROOT),
        "data": {
            "path": str(data_path),
            "data_kind": config["data_kind"],
            "symbol": config["symbol"],
            "timeframe": config["timeframe"],
        },
        "strategy": asdict(config["strategy"]),
        "execution": config["execution"].to_dict(),
        "seed": config["seed"],
        "deterministic": True,
        "notes": config["notes"],
    }
    if metadata is not None:
        summary["experiment_store"] = {
            "db_path": str(store.path) if store is not None else None,
            "config_hash": metadata.config_hash,
            "data_fingerprint": metadata.data_fingerprint,
            "git_commit": metadata.git_commit,
            "git_dirty": metadata.git_dirty,
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
        _finish_store(
            store,
            experiment_id,
            "failed",
            artifacts=_collect_artifacts([("summary", summary_path)]),
            error=summary["error"],
        )
        return 1

    summary["data"]["metadata"] = loaded_metadata.to_dict()

    expected_step = None
    if config["timeframe"] in TIMEFRAME_STEP_SECONDS:
        expected_step = TIMEFRAME_STEP_SECONDS[config["timeframe"]]

    validation = validate_ohlcv(
        frame,
        metadata=loaded_metadata,
        expected_step=expected_step,
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
        error_message = f"invalid_data: {len(validation.errors)} validation error(s)"
        print(f"{error_message}; see {validation_json}", file=sys.stderr)
        _finish_store(
            store,
            experiment_id,
            "invalid_data",
            artifacts=_collect_artifacts(
                [
                    ("summary", summary_path),
                    ("validation_json", validation_json),
                    ("validation_csv", validation_csv),
                ]
            ),
            validation=summary["validation"],
            error=error_message,
        )
        return 2

    try:
        result = run_backtest(frame, config["strategy"], config["execution"])
    except (BacktestInputError, ValueError) as exc:
        summary["status"] = "failed"
        summary["error"] = f"backtest_error: {exc}"
        _write_summary(summary_path, summary)
        print(f"backtest_error: {exc}", file=sys.stderr)
        _finish_store(
            store,
            experiment_id,
            "failed",
            artifacts=_collect_artifacts(
                [
                    ("summary", summary_path),
                    ("validation_json", validation_json),
                    ("validation_csv", validation_csv),
                ]
            ),
            validation=summary["validation"],
            error=summary["error"],
        )
        return 3

    trades_path = report_dir / "trades.csv"
    equity_path = report_dir / "equity.csv"
    signals_path = report_dir / "signals.csv"
    _write_csv(trades_path, result.trades)
    _write_csv(equity_path, result.equity, ("timestamp",))
    _write_csv(signals_path, result.signals, ("timestamp",))

    counts = signal_counts(result.signals)
    summary.update(
        {
            "status": "completed",
            "metrics": result.metrics,
            "benchmark": result.benchmark,
            "signal_counts": counts,
            "trades": result.trades.to_dict(orient="records"),
            "artifacts": {
                "summary": str(summary_path),
                "trades": str(trades_path),
                "equity": str(equity_path),
                "signals": str(signals_path),
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

    artifact_items = [
        ("summary", summary_path),
        ("trades", trades_path),
        ("equity", equity_path),
        ("signals", signals_path),
        ("validation_json", validation_json),
        ("validation_csv", validation_csv),
    ]
    if plot_path is not None:
        artifact_items.append(("equity_plot", plot_path))

    stored = _finish_store(
        store,
        experiment_id,
        "completed",
        artifacts=_collect_artifacts(artifact_items),
        metrics=result.metrics,
        benchmark=result.benchmark,
        signal_counts_value=counts,
        validation=summary["validation"],
    )

    print(
        f"experiment={experiment_id} status=completed "
        f"bars={result.metrics['bars']} trades={result.metrics['trade_count']} "
        f"final_equity={result.metrics['final_equity']:.2f} "
        f"net_profit={result.metrics['net_profit']:.2f}"
    )
    print(f"report_dir={report_dir}")
    if store is not None and metadata is not None:
        print(
            f"store={store.path} config_hash={metadata.config_hash} "
            f"data_fingerprint={metadata.data_fingerprint}"
        )
    return 0 if stored else 5


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run the deterministic EMA-crossover backtest from a YAML config."
    )
    parser.add_argument(
        "--config",
        default=str(REPO_ROOT / "configs" / "backtest.example.yaml"),
        help="path to the backtest YAML config",
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
    parser.add_argument(
        "--store",
        action="store_true",
        help="record run metadata in the SQLite experiment store",
    )
    parser.add_argument(
        "--db",
        default=str(REPO_ROOT / "experiments" / "experiments.sqlite"),
        help="SQLite database path used with --store",
    )
    parser.add_argument(
        "--experiment-id",
        default=None,
        help="experiment ID override; requires --store and must be unique",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    config_path = Path(args.config).resolve()

    try:
        config = load_config(config_path)
    except (ConfigError, BacktestInputError) as exc:
        print(f"config_error: {exc}", file=sys.stderr)
        return 1

    if args.experiment_id is not None and not args.store:
        print("config_error: --experiment-id requires --store", file=sys.stderr)
        return 1

    metadata: RunMetadata | None = None
    store: ExperimentStore | None = None
    if args.store:
        try:
            experiment_id = validate_experiment_id(
                args.experiment_id or config["experiment_id"]
            )
        except ValueError as exc:
            print(f"config_error: {exc}", file=sys.stderr)
            return 1

        data_path = _resolve(config["data_path"], REPO_ROOT)
        base_report_dir = _resolve(args.out_dir or config["report_dir"], REPO_ROOT)
        try:
            config_hash = hash_config(build_effective_config(config))
        except FingerprintError as exc:
            print(f"config_error: {exc}", file=sys.stderr)
            return 1

        data_fingerprint: str | None
        try:
            data_fingerprint = sha256_file(data_path) if data_path.is_file() else None
        except OSError as exc:
            print(f"fingerprint_warning: {exc}", file=sys.stderr)
            data_fingerprint = None

        git_state = read_git_state(REPO_ROOT)
        metadata = RunMetadata(
            experiment_id=experiment_id,
            config_path=str(config_path),
            config=build_effective_config(config),
            config_hash=config_hash,
            code_version=__version__,
            data_path=str(data_path),
            data_fingerprint=data_fingerprint,
            data_kind=config["data_kind"],
            symbol=config["symbol"],
            timeframe=config["timeframe"],
            seed=config["seed"],
            report_dir=str(base_report_dir / experiment_id),
            git_commit=git_state.commit,
            git_dirty=git_state.dirty,
            notes=config["notes"],
        )

        try:
            store = ExperimentStore(_resolve(args.db, REPO_ROOT))
        except (StoreError, sqlite3.Error, OSError) as exc:
            print(f"store_error: {exc}", file=sys.stderr)
            return 5

        try:
            store.start_run(metadata)
        except DuplicateExperimentError as exc:
            print(f"duplicate_experiment: {exc}", file=sys.stderr)
            store.close()
            return 4
        except (StoreError, ValueError, sqlite3.Error) as exc:
            print(f"store_error: {exc}", file=sys.stderr)
            store.close()
            return 5

    try:
        return _execute(args, config, config_path, store, metadata)
    finally:
        if store is not None:
            try:
                store.close()
            except sqlite3.Error as exc:
                print(f"store_error: {exc}", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
