# Architecture — MT5 EA Lab V3

## 1. Mỗi chiến lược là một EA riêng

```text
Experts/MT5_EA_Lab/
  PATrendRiderXAUv1/PATrendRiderXAUv1.mq5
  GridEA/GridEA.mq5
  DCAEA/DCAEA.mq5
  InfiniteRunner/InfiniteRunnerXAU.mq5  # legacy migration, optional
  Diagnostics/SmokeTestEA.mq5

Include/MT5_EA_Lab/
  Core/
  Market/
  Strategy/
  Filters/
  Risk/
  Execution/
  State/
  Diagnostics/
```

Không chạy nhiều chiến lược trong cùng một EA trừ khi có orchestrator riêng và test cách ly. Mỗi EA phải có `StrategyId`, `MagicNumber`, config hash và log riêng.

## 2. Module contracts

### MarketData

Input: symbol, timeframe, series request.  
Output: rates/indicator values + `READY/WAITING/INVALID` + reason.  
Không tự suy diễn giá nếu `CopyRates/CopyBuffer` thiếu.

### DirectionEngine

Input: dữ liệu đã xác minh.  
Output: `LONG/SHORT/NEUTRAL/REVERSAL_WATCH` + reason + timestamp + confidence/score (nếu strategy định nghĩa).  
Không gửi lệnh.

### EntryEngine

Input: Direction + setup + entry timeframe.  
Output: `BUY/SELL/NO_TRADE` + signal ID + bar time + SL suggestion + reason.

### FilterPipeline

Mỗi filter trả `PASS/BLOCK/SKIP`; `SKIP` khi filter tắt. Ghi từng filter result. Không gộp mọi filter thành một bool không có lý do.

### RiskManager

Input: candidate side, entry, SL, volume plan, existing exposure, account/tester state.  
Output: allowed/blocked + max permitted volume + reason.  
Không được tự nới risk cap khi volume không vừa ngân sách.

### ExecutionAdapter

Chỉ module này gửi order/modify/close request. Phân biệt TESTER và DEMO; kiểm tra retcode và xác minh actual position/deal sau mỗi request.

### PositionManager

Phân biệt order, deal, position; xử lý ticket và netting/hedging. Mỗi chiến lược cô lập bằng magic/strategy ID.

### StateManager

Lưu state schema version; restore result là enum (`MISSING`, `VALID`, `CORRUPT`, `VERSION_MISMATCH`, `MAGIC_MISMATCH`). Không silent reset risk/position context.

### Diagnostics

Cung cấp panel + CSV structured events + stage counters. Không để panel hiển thị một `lastBlock` cũ khi block thật xảy ra ở module khác.

## 3. Runtime state machine

```text
INITIALIZING
  -> WAITING_FOR_DATA
  -> READY
  -> SIGNAL_CANDIDATE
  -> FILTERED
  -> RISK_APPROVED
  -> REQUEST_SENT
  -> REQUEST_CONFIRMED
  -> POSITION_OPEN
  -> POSITION_MANAGED
  -> POSITION_CLOSED

Exception branches:
  DATA_INVALID -> WAITING_FOR_DATA / SAFE_MODE
  FILTER_BLOCKED -> READY
  RISK_BLOCKED -> READY or RISK_LOCKED
  REQUEST_REJECTED -> READY or SAFE_MODE (by retcode)
  STATE_MISMATCH -> SAFE_MODE
  KILL_SWITCH -> STOP_NEW_ENTRIES
```

## 4. Runtime mode detection

- Tester: `MQLInfoInteger(MQL_TESTER) != 0`.
- Demo: outside tester, require `ACCOUNT_TRADE_MODE == ACCOUNT_TRADE_MODE_DEMO` and all trade permission flags.
- Chart diagnostic: if no order permission, EA may continue `SIGNAL_DIAGNOSTIC` if config requests it; never silently fail init unless invalid config or missing required handles.
- Never identify Strategy Tester from account name text.

## 5. Initialization philosophy

Fatal init errors: invalid config types/ranges, impossible dependency, invalid symbol contract, indicator handle creation failure that is mandatory for selected strategy.

Non-fatal states: history not yet synchronized, insufficient bars, stale quote at current tick. These should display `WAITING_FOR_DATA` and retry on future events rather than return from every tick silently.

## 6. Execution confirmation

A `CTrade` method returning `true` is not by itself proof that the server executed the trade. Inspect `ResultRetcode()`, `ResultDeal()`/`ResultOrder()` and reconcile actual positions. See official CTrade `Buy` docs.

## 7. Strategy isolation

Grid/DCA must not share basket state. PATrendRider must not inherit grid layer counters. InfiniteRunner legacy migration should have an independent strategy ID until explicitly consolidated.
