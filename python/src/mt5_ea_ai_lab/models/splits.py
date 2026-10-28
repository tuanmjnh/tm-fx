"""Time-ordered splits with purge for overlapping label horizons.

The split functions operate on an aligned frame that is sorted by
``bar_index`` and contains ``label_end_bar_index``. A sample is purged from a
segment when its label horizon reaches into the next segment, so training
never sees a label that was formed with prices from the validation/test
period.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np
import pandas as pd


class SplitError(ValueError):
    """Raised when a time split cannot be formed."""


@dataclass(frozen=True)
class SplitConfig:
    train_fraction: float = 0.6
    validation_fraction: float = 0.2
    initial_train_fraction: float = 0.5
    folds: int = 3

    def validate(self) -> None:
        if not 0.0 < self.train_fraction < 1.0:
            raise SplitError("train_fraction must be between 0 and 1")
        if not 0.0 < self.validation_fraction < 1.0:
            raise SplitError("validation_fraction must be between 0 and 1")
        if self.train_fraction + self.validation_fraction >= 1.0:
            raise SplitError("train_fraction + validation_fraction must be below 1")
        if not 0.0 < self.initial_train_fraction < 1.0:
            raise SplitError("initial_train_fraction must be between 0 and 1")
        if self.folds <= 0:
            raise SplitError("folds must be positive")


@dataclass(frozen=True)
class Segment:
    name: str
    bar_indices: tuple[int, ...]

    @property
    def size(self) -> int:
        return len(self.bar_indices)

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "size": self.size,
            "first_bar_index": self.bar_indices[0] if self.bar_indices else None,
            "last_bar_index": self.bar_indices[-1] if self.bar_indices else None,
        }


@dataclass(frozen=True)
class Fold:
    index: int
    train: Segment
    validation: Segment

    def to_dict(self) -> dict[str, Any]:
        return {
            "fold": self.index,
            "train": self.train.to_dict(),
            "validation": self.validation.to_dict(),
        }


@dataclass(frozen=True)
class SplitPlan:
    train: Segment
    validation: Segment
    test: Segment
    folds: tuple[Fold, ...]
    config: SplitConfig
    checks: dict[str, bool]

    def to_dict(self) -> dict[str, Any]:
        return {
            "train": self.train.to_dict(),
            "validation": self.validation.to_dict(),
            "test": self.test.to_dict(),
            "folds": [fold.to_dict() for fold in self.folds],
            "config": {
                "train_fraction": self.config.train_fraction,
                "validation_fraction": self.config.validation_fraction,
                "initial_train_fraction": self.config.initial_train_fraction,
                "folds": self.config.folds,
            },
            "purge": "samples whose label_end_bar_index reaches the next segment are removed",
            "checks": self.checks,
        }


def _validate_alignment(frame: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    required = ("bar_index", "label_end_bar_index")
    missing = [column for column in required if column not in frame.columns]
    if missing:
        raise SplitError(f"missing required columns: {missing}")
    if frame.empty:
        raise SplitError("cannot split an empty dataset")

    bar_index = frame["bar_index"].to_numpy(dtype=int)
    label_end = frame["label_end_bar_index"].to_numpy(dtype=int)
    if not np.all(np.diff(bar_index) > 0):
        raise SplitError("bar_index must be strictly increasing")
    if np.any(label_end < bar_index):
        raise SplitError("label_end_bar_index must not precede bar_index")
    return bar_index, label_end


def _positions(
    frame: pd.DataFrame,
    start: int,
    stop: int,
    *,
    next_start_bar: int | None,
) -> tuple[int, ...]:
    """Rows in ``[start, stop)`` whose label does not reach ``next_start_bar``."""

    label_end = frame["label_end_bar_index"].to_numpy(dtype=int)
    positions = []
    for position in range(start, stop):
        if next_start_bar is not None and label_end[position] >= next_start_bar:
            continue
        positions.append(position)
    return tuple(positions)


def make_time_split(
    frame: pd.DataFrame,
    horizon: int,
    config: SplitConfig | None = None,
) -> SplitPlan:
    """Create train/validation/test segments plus expanding-window folds.

    Percentages are applied to the number of aligned samples, not to raw bars.
    The final test rows are never used to fit a model or choose a threshold.
    """

    active = config or SplitConfig()
    active.validate()
    if horizon <= 0:
        raise SplitError("horizon must be positive")
    bar_index, _ = _validate_alignment(frame)
    n_rows = len(frame)
    if n_rows < 20:
        raise SplitError("at least 20 aligned samples are required")

    train_stop = int(np.floor(n_rows * active.train_fraction))
    validation_stop = int(
        np.floor(n_rows * (active.train_fraction + active.validation_fraction))
    )
    if train_stop < 5 or validation_stop - train_stop < 5 or n_rows - validation_stop < 5:
        raise SplitError("each segment must contain at least 5 samples")

    validation_start_bar = int(bar_index[train_stop])
    test_start_bar = int(bar_index[validation_stop])

    train_positions = _positions(
        frame, 0, train_stop, next_start_bar=validation_start_bar
    )
    validation_positions = _positions(
        frame, train_stop, validation_stop, next_start_bar=test_start_bar
    )
    test_positions = _positions(frame, validation_stop, n_rows, next_start_bar=None)
    if min(len(train_positions), len(validation_positions), len(test_positions)) < 5:
        raise SplitError("purge left fewer than 5 samples in a segment")

    development_rows = validation_stop
    initial_end = int(np.floor(development_rows * active.initial_train_fraction))
    if initial_end < 5:
        raise SplitError("initial training window is too small")
    remaining = development_rows - initial_end
    if remaining < active.folds * 2:
        raise SplitError("not enough samples for the requested walk-forward folds")

    folds: list[Fold] = []
    for fold_index in range(active.folds):
        fold_stop = initial_end + int(
            round(remaining * (fold_index + 1) / active.folds)
        )
        fold_stop = min(fold_stop, development_rows)
        fold_start = initial_end + int(round(remaining * fold_index / active.folds))
        if fold_stop - fold_start < 2:
            raise SplitError("walk-forward validation fold is too small")
        fold_validation_start_bar = int(bar_index[fold_start])
        fold_train = _positions(
            frame, 0, fold_start, next_start_bar=fold_validation_start_bar
        )
        fold_validation = _positions(
            frame, fold_start, fold_stop, next_start_bar=test_start_bar
        )
        if len(fold_train) < 5 or len(fold_validation) < 2:
            raise SplitError("purge left a walk-forward fold too small")
        folds.append(
            Fold(
                index=fold_index,
                train=Segment(f"fold_{fold_index}_train", fold_train),
                validation=Segment(f"fold_{fold_index}_validation", fold_validation),
            )
        )

    return SplitPlan(
        train=Segment("train", train_positions),
        validation=Segment("validation", validation_positions),
        test=Segment("test", test_positions),
        folds=tuple(folds),
        config=active,
        checks=_integrity_checks(frame, train_positions, validation_positions, test_positions),
    )


def _integrity_checks(
    frame: pd.DataFrame,
    train_positions: tuple[int, ...],
    validation_positions: tuple[int, ...],
    test_positions: tuple[int, ...],
) -> dict[str, bool]:
    label_end = frame["label_end_bar_index"].to_numpy(dtype=int)
    test_first_bar = int(frame["bar_index"].iloc[test_positions[0]])
    validation_first_bar = int(frame["bar_index"].iloc[validation_positions[0]])
    return {
        "train_labels_end_before_test": bool(
            max(label_end[position] for position in train_positions) < test_first_bar
        ),
        "validation_labels_end_before_test": bool(
            max(label_end[position] for position in validation_positions) < test_first_bar
        ),
        "train_labels_end_before_validation": bool(
            max(label_end[position] for position in train_positions) < validation_first_bar
        ),
        "chronological_segments": bool(
            max(int(frame["bar_index"].iloc[position]) for position in train_positions)
            < min(int(frame["bar_index"].iloc[position]) for position in validation_positions)
            < min(int(frame["bar_index"].iloc[position]) for position in test_positions)
        ),
    }
