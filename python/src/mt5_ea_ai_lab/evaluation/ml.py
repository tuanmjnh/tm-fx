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


def gate_baselines(
    net_r: np.ndarray,
    selected: np.ndarray,
    n_random: int = 2000,
    seed: int = 12345,
) -> dict[str, Any]:
    """Compare a gate's trades with the two mandatory baselines (T4.2).

    ``net_r``    realised R per candidate trade (after cost), one value each.
    ``selected`` boolean mask: True where the model would enter.

    Baselines:
      * ``always_in``  mean(net_r) over every candidate - "always enter";
      * ``random``     distribution of mean(net_r) over ``n_random`` random
                       subsets of the SAME size as ``selected`` (its p5/p95 give
                       the band a real gate has to clear).

    A model has value only if its mean beats BOTH the always-in mean and the
    random 95th percentile. Deterministic for a given seed.
    """

    values = np.asarray(net_r, dtype=float)
    mask = np.asarray(selected, dtype=bool)
    if values.shape != mask.shape:
        raise ModelError("net_r and selected must have the same shape")
    if values.size == 0:
        raise ModelError("gate_baselines needs a non-empty sample")
    if not np.isfinite(values).all():
        raise ModelError("net_r contains non-finite values")
    n_selected = int(mask.sum())

    always_in = float(values.mean())
    model = float(values[mask].mean()) if n_selected else float("nan")

    if n_selected == 0 or n_selected == values.size or n_random <= 0:
        random_stats = {"mean": always_in, "p5": always_in, "p95": always_in}
    else:
        rng = np.random.default_rng(seed)
        means = np.empty(n_random, dtype=float)
        for i in range(n_random):
            means[i] = values[rng.choice(values.size, size=n_selected, replace=False)].mean()
        p5, p95 = np.percentile(means, [5.0, 95.0])
        random_stats = {"mean": float(means.mean()), "p5": float(p5), "p95": float(p95)}

    beats_always_in = bool(n_selected > 0 and model > always_in)
    beats_random = bool(n_selected > 0 and model > random_stats["p95"])
    return {
        "candidates": int(values.size),
        "selected": n_selected,
        "selected_rate": float(n_selected / values.size),
        "model_net_r": model,
        "always_in_net_r": always_in,
        "random_net_r_mean": random_stats["mean"],
        "random_net_r_p5": random_stats["p5"],
        "random_net_r_p95": random_stats["p95"],
        "delta_vs_always_in": (model - always_in) if n_selected else None,
        "delta_vs_random_p95": (model - random_stats["p95"]) if n_selected else None,
        "beats_always_in": beats_always_in,
        "beats_random_p95": beats_random,
        "has_value": beats_always_in and beats_random,
        "n_random": int(n_random),
        "seed": int(seed),
    }
