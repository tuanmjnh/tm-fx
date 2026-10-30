# Zero Trade Diagnostics — bắt buộc cho mọi EA

## 1. Nguyên tắc

Không được trả về một kết quả chung “không có tín hiệu”. Mỗi run phải tách được các giai đoạn: runtime → data → bar → direction → entry → filters → risk/sizing → margin → order-check → request → result → position.

## 2. Pipeline và reason codes

| Stage | Status/Counter | Reason codes ví dụ |
|---|---|---|
| Runtime | `run_mode_ok`, `run_mode_blocked` | `TESTER_MODE`, `DEMO_MODE`, `ACCOUNT_NOT_DEMO`, `TRADE_NOT_ALLOWED` |
| Data readiness | `data_ready`, `data_wait` | `HISTORY_NOT_SYNCED`, `BARS_INSUFFICIENT`, `HANDLE_INVALID`, `COPYRATES_SHORT`, `COPYBUFFER_SHORT` |
| Bar clock | `bars_seen`, `bars_processed` | `NO_NEW_BAR`, `BAR_TIME_INVALID` |
| Direction | `buy_bias`, `sell_bias`, `neutral` | `H1_BEAR`, `MTF_CONFLICT`, `EMA_NOT_ALIGNED`, `PA_STRUCTURE_UNKNOWN` |
| Setup | `setup_buy`, `setup_sell`, `setup_none` | `NO_PULLBACK`, `NO_RETEST`, `CANDLE_NOT_CONFIRMED`, `SETUP_EXPIRED` |
| Filter | count by filter | `SPREAD_FILTER`, `SESSION_FILTER`, `ATR_FILTER`, `COOLDOWN`, `MIN_BARS`, `MAX_TRADES_DAY` |
| Risk sizing | `sizing_pass`, `sizing_block` | `MIN_LOT_OVER_BUDGET`, `INVALID_TICK_VALUE`, `INVALID_STOP_DISTANCE`, `MAX_LOTS_CAP` |
| Margin | `margin_pass`, `margin_block` | `ORDER_CALC_MARGIN_FAILED`, `INSUFFICIENT_MARGIN` |
| Request precheck | `ordercheck_pass`, `ordercheck_block` | `INVALID_FILLING`, `INVALID_STOPS`, `SYMBOL_CLOSE_ONLY`, `VOLUME_STEP_INVALID` |
| Send result | `request_sent`, `request_rejected` | actual server retcode + description |
| Confirmation | `deal_confirmed`, `position_confirmed` | `NO_DEAL_AFTER_REQUEST`, `POSITION_RECONCILE_MISMATCH` |

## 3. Required panel

Show at least:

```text
EA / Version / ConfigHash
RUN_MODE / INIT_STATE
Symbol / Chart TF / Spread / ATR
H1 Direction / M15 Direction / Entry Signal
DataReady / BarsLoaded / WarmupProgress
Signals BUY / SELL / NONE
Filter blocks: Spread / Session / ATR / Cooldown / ...
Risk blocks: MinLot / MaxLots / DD / DailyLoss / Exposure / Margin
Requests sent / accepted / rejected / positions / deals
LAST_STAGE / LAST_REASON / LAST_RET_CODE
```

## 4. Required run report

For every tester pass, export:

- environment / terminal / MetaEditor/compiler version;
- EA name/version and source commit/hash;
- symbol exact name and contract specs;
- timeframe and date range;
- model (`Every tick based on real ticks`, `Every tick`, etc.);
- deposit/currency/leverage and cost assumptions;
- input preset hash;
- bars and ticks processed;
- counters by pipeline stage;
- trade count and report path;
- first blocking stage when count = 0;
- sample event records with timestamps.

## 5. Decision tree when zero trades

1. `OnInit` successful? If not, inspect first fatal config/dependency/handle error.
2. `OnTick` counter increasing? If not, wrong tester symbol/period/test date or EA not receiving ticks.
3. History ready? Inspect `BarsCalculated`, `CopyRates`, `CopyBuffer`, synchronization and warm-up progress.
4. Direction produces LONG/SHORT at least once? If no, run indicator/bias unit tests and check timeframe/shift/indexing.
5. Entry setup appears? If no, inspect pullback/retest/candle logic and signal bar timestamps.
6. Filters pass? If no, disable one optional filter at a time in `diagnostic_loose` and record the difference.
7. Sizing passes? Inspect risk budget vs symbol minimum volume; do not silently round up.
8. Margin and order precheck pass? Inspect margin mode, filling, stop level, tick size, volume step.
9. Request sent? If yes, inspect actual retcode/result and reconcile deal/position.
10. If request never sent, log exact preceding stage; no broad “no trade” explanation.

## 6. Regression tests

Create tests that intentionally cause one blocker at a time and assert the corresponding reason code. Ensure disabling an optional filter changes only that filter's counter and does not bypass execution invariants.
