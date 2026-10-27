"""Phase 0 smoke tests: the package layout imports cleanly."""

import importlib

import pytest

import mt5_ea_ai_lab

SUBPACKAGES = [
    "data",
    "validation",
    "features",
    "labels",
    "signals",
    "backtest",
    "models",
    "evaluation",
    "reporting",
    "experiment_store",
]


def test_package_has_version() -> None:
    assert mt5_ea_ai_lab.__version__ == "0.1.0"


@pytest.mark.parametrize("name", SUBPACKAGES)
def test_subpackage_importable(name: str) -> None:
    module = importlib.import_module(f"mt5_ea_ai_lab.{name}")
    assert module.__doc__
