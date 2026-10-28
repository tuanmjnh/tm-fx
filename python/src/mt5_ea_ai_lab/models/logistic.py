"""Logistic-regression baseline with a JSON-only model artifact.

The persisted artifact contains the scaler parameters and coefficients so
predictions can be reproduced without unpickling an object. scikit-learn is
used only for fitting; inference uses NumPy.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import sklearn

from mt5_ea_ai_lab import __version__

MODEL_SCHEMA_VERSION = 1
MODEL_KIND = "logistic_regression"


class ModelError(ValueError):
    """Raised when a model cannot be fitted, saved or loaded safely."""


@dataclass(frozen=True)
class LogisticConfig:
    C: float = 1.0
    max_iter: int = 1000
    class_weight: str | None = None
    seed: int = 0

    def validate(self) -> None:
        if self.C <= 0.0:
            raise ModelError("C must be positive")
        if self.max_iter <= 0:
            raise ModelError("max_iter must be positive")
        if self.class_weight not in (None, "balanced"):
            raise ModelError("class_weight must be null or 'balanced'")
        if isinstance(self.seed, bool) or not isinstance(self.seed, int):
            raise ModelError("seed must be an integer")

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _as_matrix(X: pd.DataFrame | np.ndarray, feature_names: tuple[str, ...]) -> np.ndarray:
    if isinstance(X, pd.DataFrame):
        missing = [name for name in feature_names if name not in X.columns]
        if missing:
            raise ModelError(f"missing feature columns: {missing}")
        matrix = X[list(feature_names)].to_numpy(dtype=float)
    else:
        matrix = np.asarray(X, dtype=float)
        if matrix.ndim != 2 or matrix.shape[1] != len(feature_names):
            raise ModelError(
                f"expected a matrix with {len(feature_names)} feature columns"
            )
    if not np.isfinite(matrix).all():
        raise ModelError("feature matrix contains non-finite values")
    return matrix


def fit_logistic(
    X: pd.DataFrame,
    y: pd.Series | np.ndarray,
    feature_names: tuple[str, ...],
    config: LogisticConfig | None = None,
) -> dict[str, Any]:
    """Fit a standardized logistic regression and return its artifact."""

    from sklearn.linear_model import LogisticRegression
    from sklearn.preprocessing import StandardScaler

    active = config or LogisticConfig()
    active.validate()
    matrix = _as_matrix(X, feature_names)
    labels = np.asarray(y, dtype=int)
    if matrix.shape[0] != labels.shape[0]:
        raise ModelError("X and y must have the same number of rows")
    if matrix.shape[0] < 10:
        raise ModelError("at least 10 training samples are required")
    if set(np.unique(labels).tolist()) != {0, 1}:
        raise ModelError("training labels must contain both classes 0 and 1")

    scaler = StandardScaler().fit(matrix)
    scaled = scaler.transform(matrix)
    classifier = LogisticRegression(
        C=active.C,
        max_iter=active.max_iter,
        class_weight=active.class_weight,
        solver="lbfgs",
        random_state=active.seed,
    )
    classifier.fit(scaled, labels)
    coefficients = classifier.coef_.reshape(-1).astype(float)
    intercept = float(classifier.intercept_[0])
    if not np.isfinite(coefficients).all() or not np.isfinite(intercept):
        raise ModelError("fitted coefficients contain non-finite values")

    scale = np.asarray(scaler.scale_, dtype=float)
    scale[scale == 0.0] = 1.0
    return {
        "schema_version": MODEL_SCHEMA_VERSION,
        "kind": MODEL_KIND,
        "target": "direction",
        "feature_names": list(feature_names),
        "preprocessing": {
            "type": "standard_scaler",
            "mean": [float(value) for value in scaler.mean_],
            "scale": [float(value) for value in scale],
        },
        "coefficients": [float(value) for value in coefficients],
        "intercept": intercept,
        "hyperparameters": active.to_dict(),
        "training": {
            "samples": int(matrix.shape[0]),
            "positive": int((labels == 1).sum()),
            "negative": int((labels == 0).sum()),
        },
        "code_version": __version__,
        "dependencies": {
            "numpy": np.__version__,
            "pandas": pd.__version__,
            "scikit_learn": sklearn.__version__,
        },
    }


def save_model(path: str | Path, artifact: dict[str, Any]) -> Path:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(artifact, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    return destination


def validate_model_artifact(artifact: Any) -> dict[str, Any]:
    """Validate a model artifact dictionary and return it unchanged."""

    if not isinstance(artifact, dict):
        raise ModelError("model artifact must be a JSON object")
    if artifact.get("schema_version") != MODEL_SCHEMA_VERSION:
        raise ModelError("unsupported model artifact schema_version")
    if artifact.get("kind") != MODEL_KIND:
        raise ModelError("unsupported model kind")
    feature_names = artifact.get("feature_names")
    coefficients = artifact.get("coefficients")
    preprocessing = artifact.get("preprocessing")
    if not isinstance(feature_names, list) or not feature_names:
        raise ModelError("model artifact has no feature names")
    if not isinstance(coefficients, list) or len(coefficients) != len(feature_names):
        raise ModelError("coefficient count does not match feature count")
    if not isinstance(preprocessing, dict):
        raise ModelError("model artifact has no preprocessing block")
    if len(preprocessing.get("mean", [])) != len(feature_names):
        raise ModelError("scaler mean does not match feature count")
    if len(preprocessing.get("scale", [])) != len(feature_names):
        raise ModelError("scaler scale does not match feature count")
    try:
        mean = np.asarray(preprocessing["mean"], dtype=float)
        scale = np.asarray(preprocessing["scale"], dtype=float)
        coefficients_array = np.asarray(coefficients, dtype=float)
        intercept = float(artifact["intercept"])
    except (TypeError, ValueError, KeyError) as exc:
        raise ModelError(f"model artifact contains invalid numbers: {exc}") from exc
    if not np.isfinite(mean).all() or not np.isfinite(scale).all():
        raise ModelError("scaler parameters contain non-finite values")
    if not np.isfinite(coefficients_array).all() or not np.isfinite(intercept):
        raise ModelError("coefficients contain non-finite values")
    if (scale <= 0.0).any():
        raise ModelError("scaler scale must be positive")
    return artifact


def load_model(path: str | Path) -> dict[str, Any]:
    source = Path(path)
    try:
        artifact = json.loads(source.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ModelError(f"model artifact not found: {source}") from exc
    except json.JSONDecodeError as exc:
        raise ModelError(f"invalid model artifact JSON: {exc}") from exc

    return validate_model_artifact(artifact)


def _parameters(artifact: dict[str, Any]) -> tuple[np.ndarray, np.ndarray, np.ndarray, float]:
    mean = np.asarray(artifact["preprocessing"]["mean"], dtype=float)
    scale = np.asarray(artifact["preprocessing"]["scale"], dtype=float)
    if (scale == 0.0).any():
        raise ModelError("scaler scale must not contain zero")
    coefficients = np.asarray(artifact["coefficients"], dtype=float)
    intercept = float(artifact["intercept"])
    return mean, scale, coefficients, intercept


def predict_proba(
    artifact: dict[str, Any],
    X: pd.DataFrame | np.ndarray,
) -> np.ndarray:
    """Return the probability of class 1 for each row."""

    feature_names = tuple(artifact["feature_names"])
    matrix = _as_matrix(X, feature_names)
    mean, scale, coefficients, intercept = _parameters(artifact)
    standardized = (matrix - mean) / scale
    logits = standardized @ coefficients + intercept
    return 1.0 / (1.0 + np.exp(-np.clip(logits, -60.0, 60.0)))


def predict_labels(
    artifact: dict[str, Any],
    X: pd.DataFrame | np.ndarray,
    threshold: float,
) -> np.ndarray:
    if not 0.0 <= threshold <= 1.0:
        raise ModelError("threshold must be between 0 and 1")
    return (predict_proba(artifact, X) >= threshold).astype(int)
