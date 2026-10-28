"""Forward-direction labels for the ML baseline.

A label at bar ``t`` describes ``close[t + horizon] / close[t] - 1``. It is
therefore *not* available at ``t`` and must never be used as a feature; the
label end index is recorded so time splits can purge overlapping samples.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

import numpy as np
import pandas as pd

LABEL_SCHEMA_VERSION = 1


class LabelError(ValueError):
    """Raised when labels cannot be generated."""


@dataclass(frozen=True)
class DirectionLabelConfig:
    horizon: int = 3
    min_return: float = 0.0

    def validate(self) -> None:
        if isinstance(self.horizon, bool) or self.horizon <= 0:
            raise LabelError("horizon must be a positive integer")
        if self.min_return < 0.0:
            raise LabelError("min_return must be non-negative")

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class LabelSet:
    frame: pd.DataFrame
    config: DirectionLabelConfig
    dropped_tail: int
    dropped_ambiguous: int
    counts: dict[str, int]
    schema: dict[str, Any]

    @property
    def rows(self) -> int:
        return int(len(self.frame))


def make_direction_labels(
    frame: pd.DataFrame,
    config: DirectionLabelConfig | None = None,
) -> LabelSet:
    """Build binary direction labels and drop ambiguous/tail samples.

    ``frame`` must contain ``timestamp`` and ``close``. Output columns are
    ``bar_index``, ``timestamp``, ``future_return``, ``label`` and
    ``label_end_bar_index``.
    """

    active = config or DirectionLabelConfig()
    active.validate()

    missing = [column for column in ("timestamp", "close") if column not in frame.columns]
    if missing:
        raise LabelError(f"missing required columns: {missing}")
    if frame.empty:
        raise LabelError("cannot label an empty dataset")

    close = frame["close"].to_numpy(dtype=float)
    if not np.isfinite(close).all() or not (close > 0.0).all():
        raise LabelError("close prices must be finite and positive")

    timestamps = pd.to_datetime(frame["timestamp"], errors="coerce", utc=True)
    if timestamps.isna().any():
        raise LabelError("timestamp column contains invalid values")
    if timestamps.duplicated().any():
        raise LabelError("timestamp column contains duplicates")
    if not timestamps.is_monotonic_increasing:
        raise LabelError("timestamps must be sorted in increasing order")

    rows = len(close)
    horizon = active.horizon
    future_return = np.full(rows, np.nan, dtype=float)
    if rows > horizon:
        future_return[: rows - horizon] = close[horizon:] / close[: rows - horizon] - 1.0

    labels = np.full(rows, -1, dtype=int)
    positive = future_return > active.min_return
    negative = future_return < -active.min_return
    labels[positive] = 1
    labels[negative] = 0
    ambiguous = np.isfinite(future_return) & ~positive & ~negative

    kept = positive | negative
    output = pd.DataFrame(
        {
            "bar_index": np.arange(rows, dtype=int)[kept],
            "timestamp": timestamps.to_numpy()[kept],
            "future_return": future_return[kept],
            "label": labels[kept],
            "label_end_bar_index": (np.arange(rows, dtype=int) + horizon)[kept],
        }
    )

    counts = {
        "positive": int((output["label"] == 1).sum()),
        "negative": int((output["label"] == 0).sum()),
        "kept": int(len(output)),
        "total_bars": int(rows),
        "dropped_tail": int(min(horizon, rows)),
        "dropped_ambiguous": int(ambiguous.sum()),
    }
    schema = {
        "schema_version": LABEL_SCHEMA_VERSION,
        "target": "direction",
        "definition": "1 if close[t+horizon]/close[t]-1 > min_return, 0 if below -min_return",
        "horizon": horizon,
        "min_return": active.min_return,
        "label_end_bar_index": "bar_index + horizon",
        "counts": counts,
        "config": active.to_dict(),
        "note": "labels use future prices and must not be treated as features",
    }

    return LabelSet(
        frame=output.reset_index(drop=True),
        config=active,
        dropped_tail=counts["dropped_tail"],
        dropped_ambiguous=counts["dropped_ambiguous"],
        counts=counts,
        schema=schema,
    )
