"""Train and evaluate the Phase 7 logistic-regression baseline.

Exit codes:
    0  training, evaluation and reports completed
    1  configuration or dataset could not be loaded
    2  dataset validation failed (invalid_data)
    3  feature, split, training or evaluation failed after loading
    4  experiment_id already exists in the store (nothing was overwritten)
    5  experiment store could not record the run

The test segment is evaluated once after the threshold is selected on
walk-forward validation predictions. Test labels are written to the report
for audit only and are never used to fit or tune the model.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "python" / "src"))

import numpy as np
import pandas as pd
import yaml

from mt5_ea_ai_lab import __version__
from mt5_ea_ai_lab.backtest import (
    ExecutionConfig,
    PredictionInputError,
    PredictionStrategyConfig,
    momentum_predictions,
    simulate_predictions,
)
from mt5_ea_ai_lab.data.loader import DATA_KINDS, DataLoadError, load_ohlcv
from mt5_ea_ai_lab.evaluation import (
    buy_and_hold_benchmark,
    classification_metrics,
    select_threshold,
)
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
from mt5_ea_ai_lab.features import FeatureConfig, FeatureError, build_features
from mt5_ea_ai_lab.labels import (
    DirectionLabelConfig,
    LabelError,
    make_direction_labels,
)
from mt5_ea_ai_lab.models import (
    LogisticConfig,
    ModelError,
    SplitConfig,
    SplitError,
    fit_logistic,
    make_time_split,
    predict_proba,
    render_model_card,
    save_model,
)
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


def _require_int_list(value: Any, name: str) -> tuple[int, ...]:
    if not isinstance(value, list) or not value:
        raise ConfigError(f"{name} must be a non-empty list of integers")
    items = []
    for item in value:
        if isinstance(item, bool) or not isinstance(item, int) or item <= 0:
            raise ConfigError(f"{name} must contain positive integers")
        items.append(item)
    return tuple(items)


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

    features_raw = _require_mapping(config.get("features", {}), "config.features")
    feature_config = FeatureConfig(
        ema_fast=_require_int(features_raw.get("ema_fast", 5), "config.features.ema_fast"),
        ema_slow=_require_int(features_raw.get("ema_slow", 20), "config.features.ema_slow"),
        return_windows=_require_int_list(
            features_raw.get("return_windows", [1, 3, 5, 10]),
            "config.features.return_windows",
        ),
        volatility_window=_require_int(
            features_raw.get("volatility_window", 10),
            "config.features.volatility_window",
        ),
        volume_window=_require_int(
            features_raw.get("volume_window", 10), "config.features.volume_window"
        ),
        stochastic_window=_require_int(
            features_raw.get("stochastic_window", 14),
            "config.features.stochastic_window",
        ),
    )
    feature_config.validate()

    labels_raw = _require_mapping(
        _require_key(config, "labels", "config"), "config.labels"
    )
    label_config = DirectionLabelConfig(
        horizon=_require_int(
            _require_key(labels_raw, "horizon", "config.labels"),
            "config.labels.horizon",
        ),
        min_return=_require_float(
            labels_raw.get("min_return", 0.0), "config.labels.min_return"
        ),
    )
    label_config.validate()

    splits_raw = _require_mapping(config.get("splits", {}), "config.splits")
    split_config = SplitConfig(
        train_fraction=_require_float(
            splits_raw.get("train_fraction", 0.6), "config.splits.train_fraction"
        ),
        validation_fraction=_require_float(
            splits_raw.get("validation_fraction", 0.2),
            "config.splits.validation_fraction",
        ),
        initial_train_fraction=_require_float(
            splits_raw.get("initial_train_fraction", 0.5),
            "config.splits.initial_train_fraction",
        ),
        folds=_require_int(splits_raw.get("folds", 3), "config.splits.folds"),
    )
    split_config.validate()

    model_raw = _require_mapping(
        _require_key(config, "model", "config"), "config.model"
    )
    class_weight = model_raw.get("class_weight")
    if class_weight is not None and class_weight not in ("balanced",):
        raise ConfigError("config.model.class_weight must be null or 'balanced'")
    model_config = LogisticConfig(
        C=_require_float(model_raw.get("C", 1.0), "config.model.C"),
        max_iter=_require_int(model_raw.get("max_iter", 1000), "config.model.max_iter"),
        class_weight=class_weight,
        seed=_require_int(model_raw.get("seed", 0), "config.model.seed"),
    )
    model_config.validate()

    execution_raw = _require_mapping(
        _require_key(config, "execution", "config"), "config.execution"
    )
    execution_kwargs: dict[str, Any] = {}
    for field in EXECUTION_FIELDS:
        if field in execution_raw:
            execution_kwargs[field] = _require_float(
                execution_raw[field], f"config.execution.{field}"
            )
    for unsupported in (
        "stop_loss_points",
        "take_profit_points",
        "trailing_stop_points",
        "trailing_activation_points",
    ):
        if execution_raw.get(unsupported) is not None:
            raise ConfigError(
                f"config.execution.{unsupported} is not supported by the ML simulation"
            )
    execution_config = ExecutionConfig(**execution_kwargs)
    execution_config.validate()

    outputs = _require_mapping(config.get("outputs", {}), "config.outputs")
    report_dir = outputs.get("report_dir", "reports/ml")
    if not isinstance(report_dir, str) or not report_dir.strip():
        raise ConfigError("config.outputs.report_dir must be a non-empty string")

    return {
        "experiment_id": experiment_id.strip(),
        "data_path": data_path.strip(),
        "data_kind": data_kind,
        "symbol": str(symbol) if symbol else None,
        "timeframe": str(timeframe) if timeframe else None,
        "timezone": str(timezone_name),
        "features": feature_config,
        "labels": label_config,
        "splits": split_config,
        "model": model_config,
        "execution": execution_config,
        "report_dir": report_dir.strip(),
        "notes": config.get("notes"),
    }


def _effective_config(config: dict[str, Any]) -> dict[str, Any]:
    return {
        "data": {
            "data_kind": config["data_kind"],
            "symbol": config["symbol"],
            "timeframe": config["timeframe"],
            "timezone": config["timezone"],
        },
        "features": config["features"].to_dict(),
        "labels": config["labels"].to_dict(),
        "splits": asdict(config["splits"]),
        "model": config["model"].to_dict(),
        "execution": config["execution"].to_dict(),
    }


def _write_json(path: Path, payload: dict[str, Any]) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return path


def _write_frame(path: Path, frame: pd.DataFrame) -> Path:
    output = frame.copy()
    if "timestamp" in output.columns and len(output):
        output["timestamp"] = output["timestamp"].map(
            lambda value: pd.Timestamp(value).isoformat()
        )
    output.to_csv(path, index=False)
    return path


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


def _validation_block(
    validation: Any, json_path: Path, csv_path: Path
) -> dict[str, Any]:
    return {
        "passed": validation.passed,
        "errors": len(validation.errors),
        "warnings": len(validation.warnings),
        "json": str(json_path),
        "csv": str(csv_path),
        "issues": [issue.to_dict() for issue in validation.issues],
    }


def _aligned_dataset(frame: pd.DataFrame, feature_config: FeatureConfig, label_config: DirectionLabelConfig):
    features = build_features(frame, feature_config)
    labels = make_direction_labels(frame, label_config)
    label_columns = labels.frame[
        ["bar_index", "future_return", "label", "label_end_bar_index"]
    ]
    aligned = features.frame.merge(
        label_columns, on="bar_index", how="inner", validate="one_to_one"
    )
    if aligned.empty:
        raise ModelError("no rows remain after aligning features and labels")
    return features, labels, aligned


def _run_folds(
    aligned: pd.DataFrame,
    feature_names: tuple[str, ...],
    plan: Any,
    model_config: LogisticConfig,
) -> tuple[list[dict[str, Any]], np.ndarray, np.ndarray, list[dict[str, Any]]]:
    X = aligned[list(feature_names)]
    y = aligned["label"].to_numpy(dtype=int)
    fold_summaries: list[dict[str, Any]] = []
    fold_predictions: list[dict[str, Any]] = []
    oof_scores: list[np.ndarray] = []
    oof_truth: list[np.ndarray] = []

    for fold in plan.folds:
        train_positions = list(fold.train.bar_indices)
        validation_positions = list(fold.validation.bar_indices)
        artifact = fit_logistic(
            X.iloc[train_positions],
            y[train_positions],
            feature_names,
            model_config,
        )
        scores = predict_proba(artifact, X.iloc[validation_positions])
        truth = y[validation_positions]
        oof_scores.append(scores)
        oof_truth.append(truth)
        fold_summaries.append(
            {
                "fold": fold.index,
                "train_samples": len(train_positions),
                "validation_samples": len(validation_positions),
                "scores": scores,
                "truth": truth,
            }
        )
        for position, score, label in zip(validation_positions, scores, truth):
            fold_predictions.append(
                {
                    "fold": fold.index,
                    "bar_index": int(aligned["bar_index"].iloc[position]),
                    "timestamp": aligned["timestamp"].iloc[position],
                    "label": int(label),
                    "probability": float(score),
                }
            )

    return (
        fold_summaries,
        np.concatenate(oof_truth),
        np.concatenate(oof_scores),
        fold_predictions,
    )


def _test_predictions_frame(
    aligned: pd.DataFrame,
    test_positions: list[int],
    scores: np.ndarray,
    threshold: float,
) -> pd.DataFrame:
    predictions = pd.DataFrame(
        {
            "timestamp": aligned["timestamp"].iloc[test_positions].to_numpy(),
            "bar_index": aligned["bar_index"].iloc[test_positions].to_numpy(),
            "label": aligned["label"].iloc[test_positions].to_numpy(),
            "future_return": aligned["future_return"].iloc[test_positions].to_numpy(),
            "probability": scores,
            "threshold": threshold,
        }
    )
    predictions["predicted"] = (predictions["probability"] >= threshold).astype(int)
    return predictions


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
    report_dir = base_report_dir / experiment_id
    report_dir.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    summary: dict[str, Any] = {
        "status": "started",
        "experiment_id": experiment_id,
        "generated_at_utc": generated_at,
        "config_path": str(config_path),
        "repo_root": str(REPO_ROOT),
        "code_version": __version__,
        "deterministic": True,
        "data": {
            "path": str(data_path),
            "data_kind": config["data_kind"],
            "symbol": config["symbol"],
            "timeframe": config["timeframe"],
            "timezone": config["timezone"],
        },
        "execution": config["execution"].to_dict(),
        "notes": config["notes"],
    }
    if metadata is not None:
        summary["git_commit"] = metadata.git_commit
        summary["git_dirty"] = metadata.git_dirty
        summary["data_fingerprint"] = metadata.data_fingerprint
        summary["experiment_store"] = {
            "db_path": str(store.path) if store is not None else None,
            "config_hash": metadata.config_hash,
            "data_fingerprint": metadata.data_fingerprint,
            "git_commit": metadata.git_commit,
            "git_dirty": metadata.git_dirty,
        }
    else:
        git_state = read_git_state(REPO_ROOT)
        summary["git_commit"] = git_state.commit
        summary["git_dirty"] = git_state.dirty
        try:
            summary["data_fingerprint"] = sha256_file(data_path) if data_path.is_file() else None
        except OSError:
            summary["data_fingerprint"] = None

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
        _write_json(summary_path, summary)
        _finish_store(
            store,
            experiment_id,
            "failed",
            artifacts=_collect_artifacts([("summary", summary_path)]),
            error=summary["error"],
        )
        return 1

    summary["data"]["metadata"] = loaded_metadata.to_dict()
    summary["data"]["rows"] = loaded_metadata.rows
    expected_step = TIMEFRAME_STEP_SECONDS.get(config["timeframe"] or "")

    validation = validate_ohlcv(frame, metadata=loaded_metadata, expected_step=expected_step)
    validation_json = validation.to_json(report_dir / "validation.json")
    validation_csv = validation.to_csv(report_dir / "validation.csv")
    summary["data_validation"] = _validation_block(validation, validation_json, validation_csv)

    if not validation.passed:
        summary["status"] = "invalid_data"
        _write_json(summary_path, summary)
        message = f"invalid_data: {len(validation.errors)} validation error(s)"
        print(f"{message}; see {validation_json}", file=sys.stderr)
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
            validation=summary["data_validation"],
            error=message,
        )
        return 2

    try:
        features, labels, aligned = _aligned_dataset(
            frame, config["features"], config["labels"]
        )
        plan = make_time_split(aligned, config["labels"].horizon, config["splits"])
        if not all(plan.checks.values()):
            failed = [name for name, passed in plan.checks.items() if not passed]
            raise SplitError(f"split integrity check failed: {failed}")

        fold_summaries, oof_truth, oof_scores, fold_predictions = _run_folds(
            aligned, features.feature_names, plan, config["model"]
        )
        threshold_result = select_threshold(oof_truth, oof_scores)

        fold_metrics: list[dict[str, Any]] = []
        for fold_summary in fold_summaries:
            metrics = classification_metrics(
                fold_summary["truth"], fold_summary["scores"], threshold_result["threshold"]
            )
            fold_metrics.append(
                {
                    "fold": fold_summary["fold"],
                    "train_samples": fold_summary["train_samples"],
                    "validation_samples": fold_summary["validation_samples"],
                    "samples": metrics["samples"],
                    "roc_auc": metrics["roc_auc"],
                    "balanced_accuracy": metrics["balanced_accuracy"],
                    "accuracy": metrics["accuracy"],
                    "f1": metrics["f1"],
                }
            )
        oof_metrics = classification_metrics(
            oof_truth, oof_scores, threshold_result["threshold"]
        )

        final_positions = sorted(
            set(plan.train.bar_indices) | set(plan.validation.bar_indices)
        )
        X = aligned[list(features.feature_names)]
        y = aligned["label"].to_numpy(dtype=int)
        artifact = fit_logistic(
            X.iloc[final_positions], y[final_positions], features.feature_names, config["model"]
        )
        artifact["training"].update(
            {
                "first_bar_index": int(aligned["bar_index"].iloc[final_positions[0]]),
                "last_bar_index": int(aligned["bar_index"].iloc[final_positions[-1]]),
                "data_fingerprint": summary.get("data_fingerprint"),
                "segments": "train + validation with purge",
            }
        )
        artifact["decision_threshold"] = threshold_result["threshold"]
        artifact["threshold_selection"] = threshold_result
        artifact["label"] = labels.schema
        artifact["feature_schema_version"] = features.schema["schema_version"]

        test_positions = list(plan.test.bar_indices)
        test_scores = predict_proba(artifact, X.iloc[test_positions])
        test_truth = y[test_positions]
        test_metrics = classification_metrics(
            test_truth, test_scores, threshold_result["threshold"]
        )
        test_metrics_at_half = classification_metrics(test_truth, test_scores, 0.5)

        predictions = _test_predictions_frame(
            aligned, test_positions, test_scores, threshold_result["threshold"]
        )
        majority = 1 if int(test_truth.sum()) * 2 >= len(test_truth) else 0
        majority_metrics = classification_metrics(
            test_truth, np.full(len(test_truth), float(majority)), 0.5
        )

        test_start_bar = int(aligned["bar_index"].iloc[test_positions[0]])
        strategy_config = PredictionStrategyConfig(horizon=config["labels"].horizon)
        ml_strategy = simulate_predictions(
            frame,
            predictions[["bar_index", "probability", "threshold"]],
            config["execution"],
            strategy_config,
            evaluation_start_bar=test_start_bar,
            evaluation_end_bar=len(frame),
        )
        momentum = momentum_predictions(
            frame, lookback=config["labels"].horizon, start_bar=test_start_bar
        )
        momentum_strategy = simulate_predictions(
            frame,
            momentum,
            config["execution"],
            strategy_config,
            evaluation_start_bar=test_start_bar,
            evaluation_end_bar=len(frame),
        )
        buy_hold = buy_and_hold_benchmark(
            frame.iloc[test_start_bar:].reset_index(drop=True), config["execution"]
        )
    except (FeatureError, LabelError, SplitError, ModelError, PredictionInputError, ValueError) as exc:
        summary["status"] = "failed"
        summary["error"] = f"training_error: {exc}"
        _write_json(summary_path, summary)
        print(f"training_error: {exc}", file=sys.stderr)
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
            validation=summary["data_validation"],
            error=summary["error"],
        )
        return 3

    warnings: list[str] = []
    if config["data_kind"] != "market":
        warnings.append(f"data_kind_{config['data_kind']}: not market data")
    if len(test_truth) < 100:
        warnings.append("small_test_sample: fewer than 100 test samples")
    if test_metrics["roc_auc"] is None or test_metrics["roc_auc"] <= 0.5:
        warnings.append("test_roc_auc_not_above_0.5")
    if ml_strategy.metrics["net_profit"] <= 0.0:
        warnings.append("ml_strategy_not_profitable_after_costs")
    elif buy_hold is not None and ml_strategy.metrics["net_profit"] < buy_hold["net_pnl"]:
        warnings.append("ml_strategy_below_buy_and_hold")
    if summary.get("git_dirty"):
        warnings.append("worktree_dirty")

    feature_schema_path = _write_json(report_dir / "feature_schema.json", features.schema)
    label_schema_path = _write_json(report_dir / "label_schema.json", labels.schema)
    split_path = _write_json(report_dir / "split_plan.json", plan.to_dict())
    predictions_path = _write_frame(report_dir / "predictions.csv", predictions)
    fold_predictions_path = _write_frame(
        report_dir / "fold_predictions.csv", pd.DataFrame(fold_predictions)
    )
    model_path = save_model(report_dir / "model.json", artifact)
    model_hash = sha256_file(model_path)

    summary.update(
        {
            "status": "completed",
            "features": features.schema,
            "labels": labels.schema,
            "split": plan.to_dict(),
            "threshold": threshold_result,
            "model": artifact,
            "model_sha256": model_hash,
            "classification": {
                "oof": oof_metrics,
                "folds": fold_metrics,
                "test": test_metrics,
                "test_at_half": test_metrics_at_half,
                "majority_benchmark": majority_metrics,
            },
            "strategy": {
                "ml": {**ml_strategy.to_dict(), "metrics": ml_strategy.metrics},
                "momentum": {**momentum_strategy.to_dict(), "metrics": momentum_strategy.metrics},
                "buy_and_hold": buy_hold,
            },
            "warnings": warnings,
            "artifacts": {
                "summary": str(summary_path),
                "model": str(model_path),
                "model_card": str(report_dir / "model_card.md"),
                "predictions": str(predictions_path),
                "fold_predictions": str(fold_predictions_path),
                "feature_schema": str(feature_schema_path),
                "label_schema": str(label_schema_path),
                "split_plan": str(split_path),
                "validation_json": str(validation_json),
                "validation_csv": str(validation_csv),
            },
        }
    )
    _write_json(summary_path, summary)
    model_card_path = report_dir / "model_card.md"
    model_card_path.write_text(render_model_card(summary), encoding="utf-8")

    stored = _finish_store(
        store,
        experiment_id,
        "completed",
        artifacts=_collect_artifacts(
            [
                ("summary", summary_path),
                ("model", model_path),
                ("model_card", model_card_path),
                ("predictions", predictions_path),
                ("fold_predictions", fold_predictions_path),
                ("feature_schema", feature_schema_path),
                ("label_schema", label_schema_path),
                ("split_plan", split_path),
                ("validation_json", validation_json),
                ("validation_csv", validation_csv),
            ]
        ),
        metrics={
            "test_classification": test_metrics,
            "test_classification_at_half": test_metrics_at_half,
            "oof_classification": oof_metrics,
            "ml_strategy": ml_strategy.metrics,
            "momentum_strategy": momentum_strategy.metrics,
            "buy_and_hold": buy_hold,
        },
        benchmark={
            "majority_classification": majority_metrics,
            "momentum_strategy": momentum_strategy.metrics,
            "buy_and_hold": buy_hold,
        },
        signal_counts_value={
            "test_predicted_positive": int((test_scores >= threshold_result["threshold"]).sum()),
            "test_predicted_negative": int((test_scores < threshold_result["threshold"]).sum()),
            "ml_trades": int(ml_strategy.metrics["trade_count"]),
        },
        validation={
            "data": summary["data_validation"],
            "features": {
                "feature_count": features.schema["feature_count"],
                "warmup_bars": features.schema["warmup_bars"],
            },
            "labels": labels.counts,
            "splits": plan.checks,
            "warnings": warnings,
        },
    )

    print(
        f"experiment={experiment_id} status=completed "
        f"test_samples={test_metrics['samples']} threshold={threshold_result['threshold']:.2f} "
        f"roc_auc={test_metrics['roc_auc']} balanced_accuracy={test_metrics['balanced_accuracy']:.4f}"
    )
    print(
        f"ml_strategy trades={ml_strategy.metrics['trade_count']} "
        f"net_profit={ml_strategy.metrics['net_profit']:.2f} "
        f"buy_hold_net={buy_hold['net_pnl'] if buy_hold else None}"
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
        description="Train and evaluate the Phase 7 logistic-regression baseline."
    )
    parser.add_argument(
        "--config",
        default=str(REPO_ROOT / "configs" / "ml_baseline.example.yaml"),
        help="path to the ML YAML config",
    )
    parser.add_argument(
        "--out-dir",
        default=None,
        help="override outputs.report_dir (resolved against the repository root)",
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
    except (ConfigError, ValueError) as exc:
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
            config_hash = hash_config(_effective_config(config))
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
            config=_effective_config(config),
            config_hash=config_hash,
            code_version=__version__,
            data_path=str(data_path),
            data_fingerprint=data_fingerprint,
            data_kind=config["data_kind"],
            symbol=config["symbol"],
            timeframe=config["timeframe"],
            seed=config["model"].seed,
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
