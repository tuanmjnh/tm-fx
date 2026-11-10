"""Forward-looking label generation for the ML baseline."""

from mt5_ea_ai_lab.labels.cost_adjusted import (
    COST_LABEL_SCHEMA_VERSION,
    CostAdjustedLabelConfig,
    make_cost_adjusted_labels,
)
from mt5_ea_ai_lab.labels.direction import (
    LABEL_SCHEMA_VERSION,
    DirectionLabelConfig,
    LabelError,
    LabelSet,
    make_direction_labels,
)

__all__ = [
    "COST_LABEL_SCHEMA_VERSION",
    "LABEL_SCHEMA_VERSION",
    "CostAdjustedLabelConfig",
    "DirectionLabelConfig",
    "LabelError",
    "LabelSet",
    "make_cost_adjusted_labels",
    "make_direction_labels",
]
