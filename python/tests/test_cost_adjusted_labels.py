"""Arithmetic checks for cost-adjusted (triple-barrier) labels (T4.1)."""
from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.labels.cost_adjusted import (
    CostAdjustedLabelConfig,
    make_cost_adjusted_labels,
)
from mt5_ea_ai_lab.labels.direction import LabelError

CONFIG = CostAdjustedLabelConfig(horizon=2, stop_price=5.0, target_price=5.0,
                                 spread_price=0.19)


def _frame(highs, lows, closes) -> pd.DataFrame:
    stamps = pd.date_range("2026-01-01", periods=len(closes), freq="5min", tz="UTC")
    return pd.DataFrame({"timestamp": stamps, "high": highs, "low": lows,
                         "close": closes})


def test_target_hit_labels_one_after_cost() -> None:
    #--- t=0 close 2000; bar 1 high 2010 clears the 2005 target.
    frame = _frame([2001, 2010, 2001], [1999, 1999, 1999], [2000, 2005, 2001])
    result = make_cost_adjusted_labels(frame, CONFIG)
    row = result.frame.iloc[0]
    assert row["outcome"] == "target"
    assert row["label"] == 1
    assert row["net_r"] == pytest.approx((5.0 - 0.19) / 5.0)


def test_stop_hit_labels_zero() -> None:
    frame = _frame([2001, 2001, 2001], [1999, 1990, 1999], [2000, 1996, 2001])
    result = make_cost_adjusted_labels(frame, CONFIG)
    row = result.frame.iloc[0]
    assert row["outcome"] == "stop"
    assert row["label"] == 0
    assert row["net_r"] == pytest.approx((-5.0 - 0.19) / 5.0)


def test_single_bar_touching_both_barriers_counts_as_stop() -> None:
    frame = _frame([2001, 2008, 2001], [1999, 1993, 1999], [2000, 2002, 2001])
    result = make_cost_adjusted_labels(frame, CONFIG)
    assert result.frame.iloc[0]["outcome"] == "stop"


def test_timeout_is_decided_by_the_net_sign() -> None:
    win = _frame([2002, 2002, 2003], [1998, 1998, 1998], [2000, 2001, 2003])
    assert make_cost_adjusted_labels(win, CONFIG).frame.iloc[0]["label"] == 1
    loss = _frame([2002, 2002, 2001], [1998, 1998, 1997], [2000, 2000, 1997])
    row = make_cost_adjusted_labels(loss, CONFIG).frame.iloc[0]
    assert row["outcome"] == "timeout"
    assert row["label"] == 0


def test_schema_counts_and_tail() -> None:
    frame = _frame([2001, 2001, 2001, 2001], [1999, 1999, 1999, 1999],
                   [2000, 2000, 2000, 2000])
    result = make_cost_adjusted_labels(frame, CONFIG)
    assert result.schema["target"] == "cost_adjusted_long_triple_barrier"
    assert result.schema["counts"]["total_bars"] == 4
    assert result.dropped_tail == 2
    #--- rows with a label_end_bar_index beyond the frame are impossible.
    assert (result.frame["label_end_bar_index"] < 4).all()


def test_missing_ohlc_is_rejected() -> None:
    frame = pd.DataFrame({"timestamp": pd.date_range("2026-01-01", periods=3, freq="5min", tz="UTC"),
                          "close": [2000.0, 2001.0, 2002.0]})
    with pytest.raises(LabelError):
        make_cost_adjusted_labels(frame, CONFIG)
