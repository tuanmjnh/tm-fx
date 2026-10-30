# Configuration Matrix — flexible filters with explicit semantics

## 1. Design rules

- Every strategy filter has an explicit boolean `Enable...`; do not encode OFF as an undocumented magic value.
- Every numeric input documents unit and valid range.
- `0` is used as OFF only when the table below explicitly says so.
- Strategy Tester diagnostic presets may turn off optional filters to confirm the pipeline; Demo profile must keep critical risk controls enabled.
- There is no unlimited position/layer/volume/exposure mode.

## 2. Runtime groups

| Group | Inputs | OFF semantics | Available modes |
|---|---|---|---|
| Run mode | `RunMode` | None | SIGNAL_DIAGNOSTIC / STRATEGY_TESTER / DEMO_EXECUTION |
| Symbol | `UseChartSymbol`, `InpSymbol` | Chart symbol can be used | All |
| Direction | `DirectionMode`, EMA/PA settings | Select explicit mode | All |
| Trend filter | `EnableTrendFilter` | false = SKIP filter | Diagnostic/Tester; demo default on where required by strategy |
| Candle confirm | `EnableCandleConfirm` | false = SKIP | All |
| Spread filter | `EnableSpreadFilter`, `MaxSpreadPoints` | false = skip entry filter; spread cost still modelled | All; demo default on |
| ATR filter | `EnableVolatilityFilter`, `MaxAtrRatio` | false = skip abnormal-vol filter | All; demo default on |
| Session filter | `EnableSessionFilter`, session start/end | false = any session allowed | All |
| Cooldown | `EnableCooldown`, `CooldownMinutes` | false = no cooldown | All |
| Entry gap | `EnableMinBarsBetweenEntries`, `MinBars` | false = no bar-gap throttle; duplicate signal guard remains | All |
| Daily trade count | `EnableMaxTradesPerDay`, `MaxTradesPerDay` | false = no strategy-level count cap; order/position/exposure cap remains | Tester; demo default on |
| Lot mode | `FIXED_LOT / RISK_PERCENT` | None | Tester/Demo |
| Fixed lot | `FixedLot` | Must be >0 and normalized | Tester/Demo |
| Risk percent | `RiskPercent` | Used only in RISK_PERCENT | Tester/Demo |
| Max positions | `MaxPositions` | Must be finite positive integer | Tester/Demo |
| Max layers/adds | `MaxGridLayers`, `MaxDcaAdds` | Must be finite positive integer; not unlimited | Tester/Demo |
| Max total lots | `MaxTotalLots` | Must be finite positive | Tester/Demo |
| Daily loss guard | `EnableDailyLossGuard`, `MaxDailyLossPct` | Tester can turn off for diagnostic runs; Demo requires on | Tester/Demo |
| Equity DD guard | `EnableEquityDDGuard`, `MaxEquityDDPct` | Tester can turn off for diagnostic runs; Demo requires on | Tester/Demo |
| TP mode | `TPMode` | `NONE` is valid for Runner/PATrendRider | By strategy |
| Trailing | `TrailingMode` | `OFF/FIXED/ATR/SWING/HYBRID` | By strategy |
| Logs | `LogLevel`, `LogFile` | Logging may not be fully disabled for diagnostic builds | All |

## 3. Immutable technical checks

These are not strategy filters and must not have bypass switches:

- invalid/zero Bid or Ask;
- missing/stale quote or unavailable required history;
- symbol disabled/close-only when opening is requested;
- volume outside symbol min/max/step or aggregate volume limit;
- invalid margin calculation or insufficient margin;
- invalid tick size/price alignment;
- invalid SL/TP relative to broker stop/freeze levels;
- duplicate signal/request or unresolved in-flight request;
- incompatible account margin mode for the strategy;
- unknown runtime mode when an order request is requested;
- non-demo account for `DEMO_EXECUTION`;
- emergency/kill switch.

## 4. Presets

### `diagnostic_loose`

Purpose: verify that bars/data/signal calculation and tester execution pipeline are connected. Disable optional trend/session/spread/volatility/cooldown/min-bars filters one at a time or as a documented diagnostic matrix. Use fixed volume that is valid for the tester symbol, one position initially, a valid SL, and a finite exposure cap. It is not a performance preset and must not be copied to demo.

### `baseline`

Strategy-defined filters with default values documented. Risk settings are explicit. No parameter optimization before a baseline report exists.

### `risk_stress`

Simulate elevated spread/commission/slippage, high ATR, gaps, margin pressure, extended trend/range, restarts and loss streaks. Keep deterministic test settings and record them.

### `demo_guarded`

All mandatory guards enabled; finite max positions/layers/volume, daily loss/equity DD stop, spread/volatility filter and kill switch configured. This preset requires runtime demo recognition.

## 5. Important sizing behaviour

If `RiskPercent` gives a volume below `SYMBOL_VOLUME_MIN`, the EA must return `BLOCKED_MIN_VOLUME_EXCEEDS_RISK_BUDGET`; it must not silently round up and exceed the risk budget. To test signal/execution flow in Strategy Tester, use a separate fixed-volume diagnostic preset and label it as such.
