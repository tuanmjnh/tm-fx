from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mt5_ea_ai_lab.features import FeatureConfig, FeatureError, build_features
from mt5_ea_ai_lab.labels import DirectionLabelConfig, LabelError, make_direction_labels


def make_frame(rows: int = 80, seed: int = 7) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    close = 1.10 * np.exp(np.cumsum(rng.normal(0.0, 0.0005, rows)))
    open_price = np.r_[close[0], close[:-1]]
    high = np.maximum(open_price, close) + 0.0002
    low = np.minimum(open_price, close) - 0.0002
    return pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=rows, freq="5min", tz="UTC"),
            "open": open_price,
            "high": high,
            "low": low,
            "close": close,
            "tick_volume": rng.integers(50, 150, rows),
        }
    )


def test_features_are_causal() -> None:
    frame = make_frame(120)
    baseline = build_features(frame, FeatureConfig())

    changed = frame.copy()
    changed.loc[90:, ["open", "high", "low", "close"]] *= 1.10
    changed.loc[90:, "tick_volume"] += 500
    after = build_features(changed, FeatureConfig())

    early_base = baseline.frame[baseline.frame["bar_index"] < 90]
    early_after = after.frame[after.frame["bar_index"] < 90]
    assert list(early_base["bar_index"]) == list(early_after["bar_index"])
    for name in baseline.feature_names:
        np.testing.assert_allclose(
            early_base[name].to_numpy(),
            early_after[name].to_numpy(),
            rtol=0.0,
            atol=0.0,
        )


def test_feature_output_drops_warmup_and_is_finite() -> None:
    frame = make_frame(80)
    features = build_features(frame, FeatureConfig())
    assert features.rows == len(features.frame)
    assert features.rows < len(frame)
    assert features.warmup_bars > 0
    assert features.frame["bar_index"].iloc[0] == features.warmup_bars
    assert not features.frame[list(features.feature_names)].isna().any().any()
    assert features.schema["feature_count"] == len(features.feature_names)
    assert len(features.schema["feature_names"]) == len(features.feature_names)


def test_features_reject_unsorted_and_duplicate_timestamps() -> None:
    frame = make_frame(40)
    shuffled = frame.sample(frac=1.0, random_state=1).reset_index(drop=True)
    with pytest.raises(FeatureError, match="sorted"):
        build_features(shuffled)

    duplicated = frame.copy()
    duplicated.loc[5, "timestamp"] = duplicated.loc[4, "timestamp"]
    with pytest.raises(FeatureError, match="duplicates"):
        build_features(duplicated)


def test_labels_use_forward_returns_and_drop_tail() -> None:
    close = [100.0, 101.0, 100.5, 100.2, 102.0, 101.5]
    frame = pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=len(close), freq="5min", tz="UTC"),
            "close": close,
        }
    )
    labels = make_direction_labels(frame, DirectionLabelConfig(horizon=2, min_return=0.0))
    assert labels.counts["kept"] == 4
    assert labels.counts["dropped_tail"] == 2
    assert labels.counts["dropped_ambiguous"] == 0
    assert list(labels.frame["label"]) == [1, 0, 1, 1]
    assert list(labels.frame["label_end_bar_index"]) == [2, 3, 4, 5]
    expected = [close[index + 2] / close[index] - 1.0 for index in range(4)]
    np.testing.assert_allclose(labels.frame["future_return"].to_numpy(), expected)


def test_labels_drop_dead_zone() -> None:
    close = [100.0, 100.0, 100.05, 100.2, 100.21, 100.5]
    frame = pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=len(close), freq="5min", tz="UTC"),
            "close": close,
        }
    )
    labels = make_direction_labels(frame, DirectionLabelConfig(horizon=2, min_return=0.001))
    kept = labels.frame
    assert labels.counts["dropped_ambiguous"] == 1
    assert int(kept["bar_index"].iloc[0]) == 1
    assert list(kept["label"]) == [1, 1, 1]


def test_labels_reject_bad_prices() -> None:
    frame = pd.DataFrame(
        {
            "timestamp": pd.date_range("2024-01-01", periods=3, freq="5min", tz="UTC"),
            "close": [100.0, 0.0, 101.0],
        }
    )
    with pytest.raises(LabelError, match="positive"):
        make_direction_labels(frame)
