"""Checks for the mandatory gate baselines (T4.2)."""
from __future__ import annotations

import numpy as np
import pytest

from mt5_ea_ai_lab.evaluation.ml import gate_baselines
from mt5_ea_ai_lab.models.logistic import ModelError


def test_good_selection_beats_both_baselines() -> None:
    net_r = np.array([-1.0, -1.0, -1.0, 2.0, 2.0, 2.0, 2.0, 2.0])
    selected = np.array([0, 0, 0, 1, 1, 1, 1, 1], dtype=bool)
    result = gate_baselines(net_r, selected, n_random=500, seed=1)
    assert result["model_net_r"] == pytest.approx(2.0)
    assert result["always_in_net_r"] == pytest.approx((-1.0 * 3 + 2.0 * 5) / 8.0)
    assert result["beats_always_in"] is True
    assert result["beats_random_p95"] is True
    assert result["has_value"] is True


def test_random_like_selection_has_no_value() -> None:
    net_r = np.array([-1.0, 2.0, -1.0, 2.0, -1.0, 2.0, -1.0, 2.0])
    selected = np.array([1, 1, 1, 1, 0, 0, 0, 0], dtype=bool)
    result = gate_baselines(net_r, selected, n_random=1000, seed=1)
    assert result["has_value"] is False
    assert result["beats_random_p95"] is False


def test_empty_selection_is_reported_not_crashed() -> None:
    net_r = np.array([1.0, -2.0, 3.0])
    result = gate_baselines(net_r, np.zeros(3, dtype=bool), n_random=10, seed=1)
    assert result["selected"] == 0
    assert result["has_value"] is False
    assert result["delta_vs_always_in"] is None


def test_shape_mismatch_is_rejected() -> None:
    with pytest.raises(ModelError):
        gate_baselines(np.array([1.0, 2.0]), np.array([True], dtype=bool))


def test_is_seed_deterministic() -> None:
    net_r = np.linspace(-2.0, 3.0, 20)
    selected = np.array([i % 3 == 0 for i in range(20)], dtype=bool)
    a = gate_baselines(net_r, selected, n_random=200, seed=7)
    b = gate_baselines(net_r, selected, n_random=200, seed=7)
    assert a["random_net_r_p95"] == b["random_net_r_p95"]
