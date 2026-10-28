"""Bounded DCA/grid basket simulation.

Simulation only: this module never routes orders, connects to a broker or
accesses an account.

Timing contract:
- A signal is computed at the close of bar ``i`` and acted on at the open of
  bar ``i + 1``.
- A basket opens with one layer and may add at most one layer per bar when the
  adverse step level is reached.
- Basket exits are checked before adds. If the loss cap and the take profit are
  both inside one bar, the loss cap is assumed to fill first.
- A layer added on a bar only affects take-profit and loss-cap levels from the
  next bar, so a new layer cannot be closed by levels it changed itself.
- Fills through a level use the worse of the open and the trigger price.

Hard limits:
- ``max_layers`` caps the number of layers.
- ``max_total_units`` caps aggregate units.
- ``max_basket_loss`` is a net realized-loss cap. The price stop is derived
  from the basket's average entry and shifted closer by paid entry commissions
  and the exit commission, so a fill at the stop (without a gap) realizes
  exactly the cap. Gaps can still overshoot it.

Per-layer rows in ``trades`` are basket components, not independent trades.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any

import pandas as pd

from mt5_ea_ai_lab.backtest.engine import prepare_frame
from mt5_ea_ai_lab.backtest.models import (
    EQUITY_COLUMNS,
    TRADE_COLUMNS,
    BacktestInputError,
    signal_counts,
)
from mt5_ea_ai_lab.evaluation.metrics import compute_metrics
from mt5_ea_ai_lab.signals.ema_crossover import (
    SIGNAL_BUY,
    SIGNAL_SELL,
    EmaCrossConfig,
    generate_signals,
)

BASKET_MODES: tuple[str, ...] = ("dca", "grid")

BASKET_TRADE_COLUMNS: tuple[str, ...] = (*TRADE_COLUMNS, "basket_id", "layer_index")

BASKET_COLUMNS: tuple[str, ...] = (
    "basket_id",
    "side",
    "mode",
    "open_time",
    "close_time",
    "open_bar",
    "close_bar",
    "layer_count",
    "units",
    "average_entry",
    "exit_fill",
    "gross_pnl",
    "commission",
    "pnl",
    "bars_held",
    "exit_reason",
    "blocked_add_bars",
    "layer_cap_reached",
)

_EPSILON = 1e-9


@dataclass(frozen=True)
class BoundedBasketConfig:
    """Hard-capped DCA/grid assumptions.

    ``step_points`` is the adverse distance between layers. ``dca`` measures it
    from the last fill; ``grid`` measures fixed levels from the first fill.
    ``max_basket_loss`` is a net realized-loss cap in quote currency. No
    leverage, margin call or financing model is applied.
    """

    initial_equity: float = 10_000.0
    layer_units: float = 10_000.0
    max_layers: int = 3
    max_total_units: float = 30_000.0
    step_points: float = 200.0
    take_profit_points: float = 300.0
    max_basket_loss: float = 300.0
    point_size: float = 0.00001
    spread_points: float = 0.0
    slippage_points: float = 0.0
    commission_per_side: float = 0.0
    mode: str = "dca"
    close_on_opposite_signal: bool = True

    def validate(self) -> None:
        if isinstance(self.max_layers, bool) or not isinstance(self.max_layers, int):
            raise BacktestInputError("max_layers must be an integer")
        if self.max_layers < 1:
            raise BacktestInputError("max_layers must be at least 1")
        if self.initial_equity <= 0.0:
            raise BacktestInputError("initial_equity must be positive")
        if self.layer_units <= 0.0:
            raise BacktestInputError("layer_units must be positive")
        if self.max_total_units < self.layer_units:
            raise BacktestInputError(
                "max_total_units must be at least one layer_units"
            )
        for name in (
            "step_points",
            "take_profit_points",
            "max_basket_loss",
            "point_size",
        ):
            if getattr(self, name) <= 0.0:
                raise BacktestInputError(f"{name} must be positive")
        if self.max_basket_loss >= self.initial_equity:
            raise BacktestInputError(
                "max_basket_loss must be lower than initial_equity"
            )
        for name in ("spread_points", "slippage_points", "commission_per_side"):
            if getattr(self, name) < 0.0:
                raise BacktestInputError(f"{name} must be non-negative")
        minimum_room = 2.0 * self.effective_max_layers() * self.commission_per_side
        if self.max_basket_loss <= minimum_room:
            raise BacktestInputError(
                "max_basket_loss must exceed twice the maximum entry and exit "
                "commissions"
            )
        if self.mode not in BASKET_MODES:
            raise BacktestInputError(f"mode must be one of {BASKET_MODES}")
        if not isinstance(self.close_on_opposite_signal, bool):
            raise BacktestInputError("close_on_opposite_signal must be a boolean")

    def effective_max_layers(self) -> int:
        """Layers reachable while respecting both the layer and units caps."""

        by_units = int(self.max_total_units // self.layer_units + _EPSILON)
        return min(self.max_layers, by_units)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class _Layer:
    entry_time: pd.Timestamp
    entry_bar: int
    entry_fill: float
    entry_commission: float


@dataclass
class _Basket:
    basket_id: int
    side: int
    open_time: pd.Timestamp
    open_bar: int
    layer_units: float
    layers: list[_Layer]
    blocked_add_bars: int = 0

    @property
    def total_units(self) -> float:
        return float(len(self.layers)) * self.layer_units

    @property
    def average_entry(self) -> float:
        return float(
            sum(layer.entry_fill for layer in self.layers) / len(self.layers)
        )


@dataclass
class BoundedBasketResult:
    trades: pd.DataFrame
    equity: pd.DataFrame
    signals: pd.DataFrame
    baskets: pd.DataFrame
    metrics: dict[str, Any]
    config: dict[str, Any]
    hard_limits: dict[str, Any]

    def to_summary_dict(self) -> dict[str, Any]:
        return {
            "config": self.config,
            "metrics": self.metrics,
            "hard_limits": self.hard_limits,
            "signal_counts": signal_counts(self.signals),
            "basket_count": int(len(self.baskets)),
            "basket_exit_reason_counts": (
                {
                    str(reason): int(count)
                    for reason, count in self.baskets["exit_reason"]
                    .value_counts()
                    .sort_index()
                    .items()
                }
                if len(self.baskets)
                else {}
            ),
        }


def _basket_levels(
    basket: _Basket,
    config: BoundedBasketConfig,
    exit_cost: float,
) -> tuple[float, float | None]:
    """Raw trigger prices for take profit and the net loss cap.

    ``None`` for the loss trigger means the cap is already breached by paid
    entry commissions plus the exit commission, so the basket must close at the
    next market price.
    """

    average = basket.average_entry
    take_profit = average + basket.side * config.take_profit_points * config.point_size
    costs = sum(layer.entry_commission for layer in basket.layers)
    costs += config.commission_per_side * len(basket.layers)
    room = config.max_basket_loss - costs
    if room <= 0.0:
        return take_profit, None
    loss_price = average - basket.side * (room / basket.total_units - exit_cost)
    return take_profit, loss_price



def _next_add_level(
    basket: _Basket, config: BoundedBasketConfig
) -> float:
    distance = config.step_points * config.point_size
    if config.mode == "grid":
        anchor = basket.layers[0].entry_fill
        return anchor - basket.side * len(basket.layers) * distance
    return basket.layers[-1].entry_fill - basket.side * distance


def _level_reached(side: int, level: float, high: float, low: float) -> bool:
    return low <= level if side > 0 else high >= level


def _exit_plan(
    basket: _Basket,
    config: BoundedBasketConfig,
    exit_cost: float,
    open_price: float,
    high: float,
    low: float,
) -> tuple[str, float] | None:
    take_profit, loss_price = _basket_levels(basket, config, exit_cost)
    if loss_price is None:
        return "basket_loss_cap", open_price
    if basket.side > 0:
        if low <= loss_price:
            return "basket_loss_cap", min(open_price, loss_price)
        if high >= take_profit:
            return "basket_take_profit", max(open_price, take_profit)
    else:
        if high >= loss_price:
            return "basket_loss_cap", max(open_price, loss_price)
        if low <= take_profit:
            return "basket_take_profit", min(open_price, take_profit)
    return None


def _can_add(basket: _Basket, config: BoundedBasketConfig) -> bool:
    if len(basket.layers) >= config.max_layers:
        return False
    if (
        basket.total_units + config.layer_units
        > config.max_total_units + _EPSILON
    ):
        return False
    projected_costs = sum(
        layer.entry_commission for layer in basket.layers
    ) + config.commission_per_side
    projected_costs += config.commission_per_side * (len(basket.layers) + 1)
    return projected_costs < config.max_basket_loss


def _hard_limit_report(
    config: BoundedBasketConfig, baskets: pd.DataFrame
) -> dict[str, Any]:
    if baskets.empty:
        max_layers = 0
        max_units = 0.0
        blocked = 0
        layer_cap_baskets = 0
        worst_pnl = 0.0
        overshoot_baskets = 0
    else:
        max_layers = int(baskets["layer_count"].max())
        max_units = float(baskets["units"].max())
        blocked = int(baskets["blocked_add_bars"].sum())
        layer_cap_baskets = int(baskets["layer_cap_reached"].sum())
        pnl = baskets["pnl"].astype(float)
        worst_pnl = float(pnl.min())
        overshoot_baskets = int(
            ((-pnl) > config.max_basket_loss + _EPSILON).sum()
        )

    worst_loss = max(0.0, -worst_pnl)
    overshoot = worst_loss - config.max_basket_loss
    if overshoot <= _EPSILON:
        overshoot = 0.0
    return {
        "max_layers": config.max_layers,
        "effective_max_layers": config.effective_max_layers(),
        "layer_units": config.layer_units,
        "max_total_units": config.max_total_units,
        "max_basket_loss": config.max_basket_loss,
        "max_observed_layers": max_layers,
        "max_observed_units": max_units,
        "layers_within_cap": max_layers <= config.max_layers,
        "units_within_cap": max_units <= config.max_total_units + _EPSILON,
        "blocked_add_bars": blocked,
        "baskets_at_layer_cap": layer_cap_baskets,
        "worst_realized_basket_pnl": worst_pnl,
        "worst_realized_basket_loss": worst_loss,
        "loss_cap_overshoot": overshoot,
        "loss_cap_overshoot_baskets": overshoot_baskets,
    }


def run_bounded_basket(
    frame: pd.DataFrame,
    strategy: EmaCrossConfig,
    config: BoundedBasketConfig,
) -> BoundedBasketResult:
    strategy.validate()
    config.validate()
    timestamps, open_prices, high_prices, low_prices, close_prices = prepare_frame(
        frame
    )
    signals = generate_signals(close_prices, timestamps, strategy)

    half_spread = config.spread_points * config.point_size / 2.0
    slippage = config.slippage_points * config.point_size
    exit_cost = half_spread + slippage

    cash = config.initial_equity
    basket: _Basket | None = None
    pending: str | None = None
    trades: list[dict[str, object]] = []
    equity_rows: list[dict[str, object]] = []
    basket_rows: list[dict[str, object]] = []
    exposed_bars = 0

    def open_basket(
        side: int, raw_price: float, time: pd.Timestamp, bar: int
    ) -> _Basket:
        nonlocal cash
        fill = raw_price + side * (half_spread + slippage)
        commission = config.commission_per_side
        cash -= commission
        return _Basket(
            basket_id=len(basket_rows) + 1,
            side=side,
            open_time=time,
            open_bar=bar,
            layer_units=config.layer_units,
            layers=[
                _Layer(
                    entry_time=time,
                    entry_bar=bar,
                    entry_fill=fill,
                    entry_commission=commission,
                )
            ],
        )

    def add_layer(
        current: _Basket, raw_price: float, time: pd.Timestamp, bar: int
    ) -> None:
        nonlocal cash
        fill = raw_price + current.side * (half_spread + slippage)
        commission = config.commission_per_side
        cash -= commission
        current.layers.append(
            _Layer(
                entry_time=time,
                entry_bar=bar,
                entry_fill=fill,
                entry_commission=commission,
            )
        )

    def close_basket(
        current: _Basket,
        raw_price: float,
        time: pd.Timestamp,
        bar: int,
        reason: str,
    ) -> None:
        nonlocal cash
        exit_fill = raw_price - current.side * (half_spread + slippage)
        total_units = current.total_units
        average_entry = current.average_entry
        gross_pnl = (exit_fill - average_entry) * current.side * total_units
        entry_commission = sum(
            layer.entry_commission for layer in current.layers
        )
        exit_commission = config.commission_per_side * len(current.layers)
        cash += gross_pnl - exit_commission

        for layer_index, layer in enumerate(current.layers):
            layer_gross = (
                (exit_fill - layer.entry_fill) * current.side * config.layer_units
            )
            layer_commission = layer.entry_commission + config.commission_per_side
            trades.append(
                {
                    "trade_id": len(trades) + 1,
                    "side": "long" if current.side > 0 else "short",
                    "entry_time": layer.entry_time.isoformat(),
                    "exit_time": time.isoformat(),
                    "entry_bar": layer.entry_bar,
                    "exit_bar": bar,
                    "entry_fill": layer.entry_fill,
                    "exit_fill": exit_fill,
                    "units": config.layer_units,
                    "gross_pnl": layer_gross,
                    "commission": layer_commission,
                    "pnl": layer_gross - layer_commission,
                    "bars_held": bar - layer.entry_bar,
                    "exit_reason": reason,
                    "basket_id": current.basket_id,
                    "layer_index": layer_index,
                }
            )

        basket_rows.append(
            {
                "basket_id": current.basket_id,
                "side": "long" if current.side > 0 else "short",
                "mode": config.mode,
                "open_time": current.open_time.isoformat(),
                "close_time": time.isoformat(),
                "open_bar": current.open_bar,
                "close_bar": bar,
                "layer_count": len(current.layers),
                "units": total_units,
                "average_entry": average_entry,
                "exit_fill": exit_fill,
                "gross_pnl": gross_pnl,
                "commission": entry_commission + exit_commission,
                "pnl": gross_pnl - entry_commission - exit_commission,
                "bars_held": bar - current.open_bar,
                "exit_reason": reason,
                "blocked_add_bars": current.blocked_add_bars,
                "layer_cap_reached": len(current.layers)
                >= config.effective_max_layers(),
            }
        )

    for index in range(len(close_prices)):
        if pending is not None:
            desired_side = 1 if pending == SIGNAL_BUY else -1
            if basket is None:
                basket = open_basket(
                    desired_side,
                    float(open_prices[index]),
                    timestamps.iloc[index],
                    index,
                )
            elif basket.side != desired_side and config.close_on_opposite_signal:
                close_basket(
                    basket,
                    float(open_prices[index]),
                    timestamps.iloc[index],
                    index,
                    "opposite_signal",
                )
                basket = open_basket(
                    desired_side,
                    float(open_prices[index]),
                    timestamps.iloc[index],
                    index,
                )
        pending = None

        if basket is not None:
            exit_plan = _exit_plan(
                basket,
                config,
                exit_cost,
                float(open_prices[index]),
                float(high_prices[index]),
                float(low_prices[index]),
            )
            if exit_plan is not None:
                reason, raw_price = exit_plan
                close_basket(
                    basket,
                    raw_price,
                    timestamps.iloc[index],
                    index,
                    reason,
                )
                basket = None
            else:
                target = _next_add_level(basket, config)
                if _level_reached(
                    basket.side,
                    target,
                    float(high_prices[index]),
                    float(low_prices[index]),
                ):
                    if _can_add(basket, config):
                        raw_fill = (
                            min(float(open_prices[index]), target)
                            if basket.side > 0
                            else max(float(open_prices[index]), target)
                        )
                        add_layer(
                            basket,
                            raw_fill,
                            timestamps.iloc[index],
                            index,
                        )
                    else:
                        basket.blocked_add_bars += 1

        unrealized = (
            sum(
                (float(close_prices[index]) - layer.entry_fill)
                * basket.side
                * config.layer_units
                for layer in basket.layers
            )
            if basket is not None
            else 0.0
        )
        if basket is not None:
            exposed_bars += 1
        equity_rows.append(
            {
                "timestamp": timestamps.iloc[index],
                "cash": cash,
                "unrealized": unrealized,
                "equity": cash + unrealized,
                "position": (
                    basket.side * len(basket.layers) if basket is not None else 0
                ),
            }
        )

        signal = str(signals["signal"].iloc[index])
        if signal in (SIGNAL_BUY, SIGNAL_SELL):
            pending = signal

    if basket is not None:
        close_basket(
            basket,
            float(close_prices[-1]),
            timestamps.iloc[-1],
            len(close_prices) - 1,
            "end_of_data",
        )
        equity_rows[-1].update(
            {"cash": cash, "unrealized": 0.0, "equity": cash, "position": 0}
        )

    trades_frame = (
        pd.DataFrame(trades, columns=list(BASKET_TRADE_COLUMNS))
        if trades
        else pd.DataFrame(columns=list(BASKET_TRADE_COLUMNS))
    )
    equity_frame = pd.DataFrame(equity_rows, columns=list(EQUITY_COLUMNS))
    baskets_frame = (
        pd.DataFrame(basket_rows, columns=list(BASKET_COLUMNS))
        if basket_rows
        else pd.DataFrame(columns=list(BASKET_COLUMNS))
    )
    metrics = compute_metrics(
        trades_frame, equity_frame, config.initial_equity, exposed_bars
    )

    return BoundedBasketResult(
        trades=trades_frame,
        equity=equity_frame,
        signals=signals,
        baskets=baskets_frame,
        metrics=metrics,
        config={
            "strategy": asdict(strategy),
            "basket": config.to_dict(),
            "effective_max_layers": config.effective_max_layers(),
        },
        hard_limits=_hard_limit_report(config, baskets_frame),
    )
