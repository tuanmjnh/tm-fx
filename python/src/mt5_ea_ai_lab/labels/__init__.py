"""Forward-looking label generation for the ML baseline."""

from mt5_ea_ai_lab.labels.direction import (
    LABEL_SCHEMA_VERSION,
    DirectionLabelConfig,
    LabelError,
    LabelSet,
    make_direction_labels,
)

__all__ = [
    "LABEL_SCHEMA_VERSION",
    "DirectionLabelConfig",
    "LabelError",
    "LabelSet",
    "make_direction_labels",
]
