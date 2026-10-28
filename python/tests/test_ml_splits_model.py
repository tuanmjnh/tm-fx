from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.evaluation.ml import classification_metrics, select_threshold
from mt5_ea_ai_lab.models import (
    LogisticConfig,
    ModelError,
    SplitError,
    fit_logistic,
    load_model,
    make_time_split,
    predict_proba,
    save_model,
)


def aligned_frame(rows: int = 120, horizon: int = 10) -> pd.DataFrame:
    bar_index = np.arange(rows)
    return pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=rows, freq="5min", tz="UTC"),
            "bar_index": bar_index,
            "label": bar_index % 2,
            "label_end_bar_index": bar_index + horizon,
        }
    )


def test_time_split_is_chronological_and_purged() -> None:
    frame = aligned_frame()
    plan = make_time_split(frame, 10)
    assert all(plan.checks.values())
    assert max(plan.train.bar_indices) < min(plan.validation.bar_indices)
    assert max(plan.validation.bar_indices) < min(plan.test.bar_indices)
    assert max(frame["label_end_bar_index"].iloc[list(plan.train.bar_indices)]) < min(
        frame["bar_index"].iloc[list(plan.validation.bar_indices)]
    )
    assert max(frame["label_end_bar_index"].iloc[list(plan.validation.bar_indices)]) < min(
        frame["bar_index"].iloc[list(plan.test.bar_indices)]
    )
    for fold in plan.folds:
        assert max(frame["label_end_bar_index"].iloc[list(fold.train.bar_indices)]) < min(
            frame["bar_index"].iloc[list(fold.validation.bar_indices)]
        )
        assert fold.train.size >= 5
        assert fold.validation.size >= 2


def test_time_split_rejects_short_dataset() -> None:
    with pytest.raises(SplitError):
        make_time_split(aligned_frame(rows=10), 2)


def test_time_split_rejects_unsorted_rows() -> None:
    frame = aligned_frame()
    with pytest.raises(SplitError, match="increasing"):
        make_time_split(frame.iloc[::-1].reset_index(drop=True), 2)


def test_logistic_roundtrip_and_clean_artifact(tmp_path: Path) -> None:
    rng = np.random.default_rng(4)
    rows = 200
    feature_names = ("first", "second")
    X = pd.DataFrame(
        {
            "first": rng.normal(size=rows),
            "second": rng.normal(size=rows),
        }
    )
    y = (X["first"] + 0.1 * rng.normal(size=rows) > 0.0).astype(int)
    artifact = fit_logistic(X, y, feature_names, LogisticConfig(C=1.0, seed=7))
    assert artifact["kind"] == "logistic_regression"
    assert artifact["preprocessing"]["type"] == "standard_scaler"
    assert len(artifact["coefficients"]) == len(feature_names)

    path = save_model(tmp_path / "model.json", artifact)
    loaded = load_model(path)
    scores = predict_proba(loaded, X)
    assert np.isfinite(scores).all()
    metrics = classification_metrics(y.to_numpy(), scores, 0.5)
    assert metrics["roc_auc"] is not None and metrics["roc_auc"] > 0.8

    raw = json.loads(path.read_text(encoding="utf-8"))
    assert raw["feature_names"] == list(feature_names)
    json.dumps(raw, allow_nan=False)


def test_logistic_rejects_single_class_and_missing_features() -> None:
    X = pd.DataFrame({"a": [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]})
    with pytest.raises(ModelError, match="both classes"):
        fit_logistic(X, np.ones(10, dtype=int), ("a",))
    y = (X["a"] > 5.0).astype(int)
    artifact = fit_logistic(X, y, ("a",))
    with pytest.raises(ModelError, match="missing feature"):
        predict_proba(artifact, pd.DataFrame({"b": [1.0]}))


def test_load_model_rejects_invalid_artifact(tmp_path: Path) -> None:
    path = tmp_path / "model.json"
    path.write_text("{}", encoding="utf-8")
    with pytest.raises(ModelError):
        load_model(path)
    path.write_text("not-json", encoding="utf-8")
    with pytest.raises(ModelError):
        load_model(path)


def test_threshold_selection_uses_balanced_accuracy() -> None:
    truth = np.array([0, 0, 1, 1])
    scores = np.array([0.1, 0.2, 0.8, 0.9])
    result = select_threshold(truth, scores, grid=(0.3, 0.5, 0.7))
    assert result["balanced_accuracy"] == 1.0
    assert result["threshold"] == 0.5
    assert result["selection_metric"] == "balanced_accuracy"


def test_degenerate_classification_metrics_are_reported() -> None:
    truth = np.ones(10, dtype=int)
    scores = np.ones(10)
    metrics = classification_metrics(truth, scores, 0.5)
    assert metrics["roc_auc"] is None
    assert metrics["roc_auc_defined"] is False
    assert metrics["confusion"] == {"tn": 0, "fp": 0, "fn": 0, "tp": 10}
    assert metrics["accuracy"] == 1.0
    json.dumps(metrics, allow_nan=False)
