"""Classification metrics and threshold selection for the ML baseline."""

from __future__ import annotations

from typing import Any

import numpy as np

from mt5_ea_ai_lab.models.logistic import ModelError


def _finite_metric(value: Any) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if np.isfinite(number) else None


def classification_metrics(
    y_true: np.ndarray,
    y_score: np.ndarray,
    threshold: float,
) -> dict[str, Any]:
    """Report metrics even for a poorly performing or degenerate model."""

    from sklearn.metrics import confusion_matrix, roc_auc_score

    truth = np.asarray(y_true, dtype=int)
    scores = np.asarray(y_score, dtype=float)
    if truth.shape != scores.shape:
        raise ModelError("y_true and y_score must have the same shape")
    if truth.size == 0:
        raise ModelError("cannot compute metrics for an empty sample")
    if not np.isfinite(scores).all():
        raise ModelError("scores contain non-finite values")
    if not 0.0 <= threshold <= 1.0:
        raise ModelError("threshold must be between 0 and 1")

    predicted = (scores >= threshold).astype(int)
    matrix = confusion_matrix(truth, predicted, labels=[0, 1])
    tn, fp, fn, tp = (int(value) for value in matrix.reshape(-1))
    positives = int((truth == 1).sum())
    negatives = int((truth == 0).sum())
    single_class = positives == 0 or negatives == 0
    roc_auc = None if single_class else _finite_metric(roc_auc_score(truth, scores))
    brier = float(np.mean((scores - truth) ** 2))
    accuracy = (tp + tn) / truth.size
    recall = tp / (tp + fn) if tp + fn else 0.0
    specificity = tn / (tn + fp) if tn + fp else 0.0
    precision = tp / (tp + fp) if tp + fp else 0.0
    f1 = 2.0 * precision * recall / (precision + recall) if precision + recall else 0.0

    return {
        "samples": int(truth.size),
        "positives": positives,
        "negatives": negatives,
        "positive_rate": float(positives / truth.size),
        "threshold": float(threshold),
        "predicted_positive": int(predicted.sum()),
        "predicted_positive_rate": float(predicted.mean()),
        "accuracy": _finite_metric(accuracy),
        "balanced_accuracy": _finite_metric(0.5 * (recall + specificity)),
        "precision": _finite_metric(precision),
        "recall": _finite_metric(recall),
        "f1": _finite_metric(f1),
        "roc_auc": roc_auc,
        "brier_score": _finite_metric(brier),
        "confusion": {"tn": tn, "fp": fp, "fn": fn, "tp": tp},
        "roc_auc_defined": not single_class,
    }


def select_threshold(
    y_true: np.ndarray,
    y_score: np.ndarray,
    grid: tuple[float, ...] | None = None,
) -> dict[str, Any]:
    """Choose the threshold with the best balanced accuracy.

    Balanced accuracy is used because the class balance is not guaranteed.
    Ties are resolved in favour of the threshold closest to 0.5. Test labels
    must not be passed to this function.
    """

    from sklearn.metrics import confusion_matrix

    truth = np.asarray(y_true, dtype=int)
    scores = np.asarray(y_score, dtype=float)
    thresholds = grid or tuple(round(0.30 + 0.01 * step, 2) for step in range(41))
    if truth.size == 0 or truth.shape != scores.shape:
        raise ModelError("threshold selection needs aligned non-empty arrays")
    if set(np.unique(truth).tolist()) != {0, 1}:
        raise ModelError("threshold selection needs both classes")

    best: dict[str, Any] | None = None
    for threshold in thresholds:
        matrix = confusion_matrix(truth, (scores >= threshold).astype(int), labels=[0, 1])
        tn, fp, fn, tp = (int(value) for value in matrix.reshape(-1))
        recall = tp / (tp + fn) if tp + fn else 0.0
        specificity = tn / (tn + fp) if tn + fp else 0.0
        score = 0.5 * (recall + specificity)
        if best is None:
            best = {"threshold": float(threshold), "balanced_accuracy": score}
            continue
        current = (score, -abs(threshold - 0.5))
        previous = (best["balanced_accuracy"], -abs(best["threshold"] - 0.5))
        if current > previous:
            best = {"threshold": float(threshold), "balanced_accuracy": score}
    assert best is not None
    best["selection_metric"] = "balanced_accuracy"
    best["grid_size"] = len(thresholds)
    best["tie_break"] = "closest to 0.5"
    return best
