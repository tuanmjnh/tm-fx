"""Cost-adjusted (triple-barrier) labels for the ML baseline (T4.1).

``direction.make_direction_labels`` labels the raw ``close[t+H]`` move. That is
*not* what a trade earns: entering long pays the spread once, so a move must
clear the spread before it is profitable. This module labels the OUTCOME OF THE
NEXT LONG TRADE at ``close[t]`` with a triple barrier:

    stop   at entry - stop_price       (adverse; label 0)
    target at entry + target_price     (favourable; label 1)
    timeout after ``horizon`` bars     (label by the net sign)

and subtracts a one-off ``spread_price`` (+ ``slippage_price``) from the raw
outcome, so ``net_r`` is the realised R after cost. Label 1 = the trade made
money after cost, 0 = it did not. The label still uses future bars, so it must
never be a feature; ``label_end_bar_index`` lets time splits purge overlaps.

The single-barriers are conservative: a bar whose range touches both the stop and
the target is counted as the stop (worst case).
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

import numpy as np
import pandas as pd

from mt5_ea_ai_lab.labels.direction import LabelError, LabelSet

COST_LABEL_SCHEMA_VERSION = 1


@dataclass(frozen=True)
class CostAdjustedLabelConfig:
    horizon: int = 12
    stop_price: float = 5.0
    target_price: float = 5.0
    spread_price: float = 0.19
    slippage_price: float = 0.0

    def validate(self) -> None:
        if isinstance(self.horizon, bool) or self.horizon <= 0:
            raise LabelError("horizon must be a positive integer")
        if not (self.stop_price > 0.0):
            raise LabelError("stop_price must be positive")
        if not (self.target_price > 0.0):
            raise LabelError("target_price must be positive")
        if self.spread_price < 0.0:
            raise LabelError("spread_price must be non-negative")
        if self.slippage_price < 0.0:
            raise LabelError("slippage_price must be non-negative")

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def make_cost_adjusted_labels(
    frame: pd.DataFrame,
    config: CostAdjustedLabelConfig | None = None,
) -> LabelSet:
    """Build triple-barrier labels net of spread; ``frame`` needs OHLC + timestamp."""

    active = config or CostAdjustedLabelConfig()
    active.validate()

    required = ("timestamp", "high", "low", "close")
    missing = [column for column in required if column not in frame.columns]
    if missing:
        raise LabelError(f"missing required columns: {missing}")
    if frame.empty:
        raise LabelError("cannot label an empty dataset")

    close = frame["close"].to_numpy(dtype=float)
    high = frame["high"].to_numpy(dtype=float)
    low = frame["low"].to_numpy(dtype=float)
    for name, values in (("close", close), ("high", high), ("low", low)):
        if not np.isfinite(values).all() or not (values > 0.0).all():
            raise LabelError(f"{name} prices must be finite and positive")

    timestamps = pd.to_datetime(frame["timestamp"], errors="coerce", utc=True)
    if timestamps.isna().any():
        raise LabelError("timestamp column contains invalid values")
    if timestamps.duplicated().any():
        raise LabelError("timestamp column contains duplicates")
    if not timestamps.is_monotonic_increasing:
        raise LabelError("timestamps must be sorted in increasing order")

    rows = len(close)
    horizon = active.horizon
    cost = active.spread_price + active.slippage_price

    bar_index: list[int] = []
    stamp: list[Any] = []
    entry: list[float] = []
    outcome_name: list[str] = []
    net_price: list[float] = []
    net_r: list[float] = []
    label: list[int] = []
    end_index: list[int] = []
    dropped_tail = min(horizon, rows)
    dropped_flat = 0

    for t in range(0, rows - horizon):
        ref = close[t]
        stop_level = ref - active.stop_price
        target_level = ref + active.target_price
        outcome = "timeout"
        raw = close[t + horizon] - ref
        for k in range(t + 1, t + horizon + 1):
            if low[k] <= stop_level:
                outcome, raw = "stop", -active.stop_price
                break
            if high[k] >= target_level:
                outcome, raw = "target", active.target_price
                break
        net = raw - cost
        if net == 0.0:
            dropped_flat += 1
            continue
        bar_index.append(t)
        stamp.append(timestamps.to_numpy()[t])
        entry.append(ref)
        outcome_name.append(outcome)
        net_price.append(net)
        net_r.append(net / active.stop_price)
        label.append(1 if net > 0.0 else 0)
        end_index.append(t + horizon)

    output = pd.DataFrame(
        {
            "bar_index": np.asarray(bar_index, dtype=int),
            "timestamp": stamp,
            "entry_close": np.asarray(entry, dtype=float),
            "outcome": outcome_name,
            "net_price": np.asarray(net_price, dtype=float),
            "net_r": np.asarray(net_r, dtype=float),
            "label": np.asarray(label, dtype=int),
            "label_end_bar_index": np.asarray(end_index, dtype=int),
        }
    )
    counts = {
        "positive": int(output["label"].sum()),
        "negative": int((output["label"] == 0).sum()),
        "kept": int(len(output)),
        "total_bars": int(rows),
        "dropped_tail": int(dropped_tail),
        "dropped_flat": int(dropped_flat),
        "target": int((output["outcome"] == "target").sum()),
        "stop": int((output["outcome"] == "stop").sum()),
        "timeout": int((output["outcome"] == "timeout").sum()),
    }
    schema = {
        "schema_version": COST_LABEL_SCHEMA_VERSION,
        "target": "cost_adjusted_long_triple_barrier",
        "definition": (
            "1 if the long trade from close[t] nets > 0 after spread+slippage "
            "with stop/target barriers over horizon bars, else 0"
        ),
        "horizon": horizon,
        "stop_price": active.stop_price,
        "target_price": active.target_price,
        "spread_price": active.spread_price,
        "slippage_price": active.slippage_price,
        "net_r": "(raw_outcome - spread - slippage) / stop_price",
        "label_end_bar_index": "bar_index + horizon",
        "counts": counts,
        "config": active.to_dict(),
        "note": "labels use future prices and must not be treated as features; "
                "a bar touching both barriers counts as the stop",
    }

    return LabelSet(
        frame=output.reset_index(drop=True),
        config=active,  # type: ignore[arg-type]
        dropped_tail=counts["dropped_tail"],
        dropped_ambiguous=counts["dropped_flat"],
        counts=counts,
        schema=schema,
    )
