"""Evaluation metrics and signal parity checks."""

from mt5_ea_ai_lab.evaluation.metrics import buy_and_hold_benchmark, compute_metrics
from mt5_ea_ai_lab.evaluation.ml import classification_metrics, select_threshold
from mt5_ea_ai_lab.evaluation.parity import (
    KEY_COLUMNS,
    MISMATCH_COLUMNS,
    NUMERIC_COLUMNS,
    PARITY_COLUMNS,
    ParityReport,
    SignalComparisonError,
    compare_signal_files,
    format_timestamp,
    load_signal_csv,
    write_report,
)

__all__ = [
    "KEY_COLUMNS",
    "MISMATCH_COLUMNS",
    "NUMERIC_COLUMNS",
    "PARITY_COLUMNS",
    "ParityReport",
    "SignalComparisonError",
    "buy_and_hold_benchmark",
    "classification_metrics",
    "compare_signal_files",
    "compute_metrics",
    "format_timestamp",
    "load_signal_csv",
    "select_threshold",
    "write_report",
]
