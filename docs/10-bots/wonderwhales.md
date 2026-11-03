# Wonderwhales — bot demo thứ năm

**EA demo:** `mt5/Experts/WonderwhalesDemoEA.mq5` · **magic** `25007001` · **nhãn** `UNPROVEN` (đã có
tester thật, kết quả âm; phiên demo chart chưa chạy). Nguồn chưng cất:
[`../30-research/indicators/wonderwhales.md`](../30-research/indicators/wonderwhales.md),
[`../90-decisions/0007-wonderwhales-demo-bot.md`](../90-decisions/0007-wonderwhales-demo-bot.md).

## 1. Chiến lược

Tín hiệu đảo chiều Parabolic SAR từ indicator `PinePort\Wonderwhales` (buffer contract 18 buffer, đọc
`shift=1` — chỉ nến đã đóng): SAR lật lên → BUY, lật xuống → SELL; tuỳ chọn lọc EMA 20/50, EMA200,
ATR%, VSA volume, RSI, Bollinger (`InpMode`, `InpSideFilter`). **Một vị thế duy nhất** theo magic —
không grid, không DCA, không martingale. Stop ban đầu theo một trong ba mode: PSAR của nến tín hiệu
(`WW_STOP_PSAR`), ATR% × hệ số, hoặc fixed points; luôn có sàn `InpMinStopPoints` và tôn trọng stop
level của broker. TP bắt buộc = entry ± `InpTakeProfitR` × khoảng cách SL (mặc định 2R). Thoát thêm theo
tín hiệu đảo (`InpExitOnFlip`) hoặc `InpMaxHoldingBars` nếu khác 0; không break-even/trailing trong v1.
Volume từ `InpRiskPercent` trên equity qua `ExecCalcProfit`, chặn bởi `InpMaxLots`.

## 2. Cấu trúc code

| File | Vai trò |
|---|---|
| `mt5/Experts/WonderwhalesDemoEA.mq5` | EA demo: tín hiệu qua `iCustom`, một vị thế guard, SL/TP bắt buộc |
| `mt5/Include/PinePort/WonderwhalesContract.mqh` | Buffer contract (`WW_CONTRACT_VERSION`) — EA không tự tính lại indicator |
| `mt5/Include/Exec/ExecGuard.mqh`, `ExecBroker.mqh` | Rào chắn demo/tester và điểm gửi lệnh duy nhất |
| `mt5/Include/Sim/SimRiskGuard.mqh`, `SimLogger.mqh` | Guard rủi ro và journal CSV 18 cột |
| `mt5/Experts/WonderwhalesSimEA.mq5` | EA mô phỏng (vị thế ảo, giữ nguyên `SIMULATION_ONLY`, preset `configs/sim/wonderwhales_xauusdm.json`) |
| `mt5/Indicators/PinePort/Wonderwhales.mq5` | Indicator nguồn tín hiệu |

## 3. Bảng input

| Nhóm | Input (tên hiện tại) | Giá trị mặc định | Tên chuẩn (phase C) |
|---|---|---|---|
| Demo execution | `InpEnableExecution` | `true` | `InpEnableExecution` |
| | `InpAllowedSymbols` | `"XAUUSD"` | `InpAllowedSymbols` |
| | `InpMagicNumber` | `25007001` | `InpMagicNumber` |
| | `InpMaxSlippagePoints` | `30` | `InpMaxSlippagePoints` |
| | `InpKillSwitchFile` | `"WONDERWHALES_DEMO_STOP.txt"` | `InpKillSwitchFile` |
| | `InpCloseOnKillSwitch` | `true` | `InpCloseOnKillSwitch` |
| Journal and state | `InpEnableLog` / `InpLogFile` | `true` / `"wonderwhales_demo.csv"` | giữ |
| | `InpDebug` / `InpPersistState` | `false` / `true` | giữ |
| | `InpStateFile` | `"wonderwhales_demo_state.csv"` | giữ |
| | `InpResetStateOnInit` | `false` | giữ |
| Wonderwhales signal | `InpMode` | `WW_MODE_SAR` | giữ |
| | `InpPsarStart` / `InpPsarInc` / `InpPsarMax` | 0.02 / 0.02 / 0.20 | giữ |
| | `InpFastEma` / `InpSlowEma` / `InpEma200` | 20 / 50 / 200 | giữ |
| | `InpAtrLen` / `InpMinAtrPct` | 14 / 0.5 | giữ |
| | `InpVolMaLen` / `InpRsiLen` | 20 / 14 | giữ |
| | `InpBbLen` / `InpBbMult` | 20 / 2.0 | giữ |
| | `InpWarmupBars` | 300 | giữ |
| | `InpSideFilter` | `WW_SIDE_BOTH` | giữ |
| Stops and target | `InpStopMode` | `WW_STOP_PSAR` | giữ |
| | `InpAtrPctMultiplier` | 2.0 | giữ |
| | `InpFixedStopPoints` | 3000.0 | giữ |
| | `InpMinStopPoints` | 150.0 | giữ |
| | `InpTakeProfitR` | 2.0 | giữ |
| | `InpMaxHoldingBars` / `InpExitOnFlip` | 0 / `true` | giữ |
| Risk | `InpRiskPercent` | 1.0 | giữ |
| | `InpMaxLots` | 0.10 | `InpMaxExposure` (phase C) |
| | `InpMaxSpreadPoints` | 600.0 | giữ |
| | `InpCooldownBars` / `InpCooldownMinutes` | 1 / 30 | giữ |
| | `InpMaxDailyLossPct` / `InpMaxDrawdownPct` | 2.0 / 8.0 | giữ |
| | `InpMaxConsecutiveLosses` / `InpHaltOnBreach` | 3 / `true` | giữ |

Gap so chuẩn (xem thiết kế §9): `InpMaxLots` sẽ thay bằng `InpMaxExposure` (phase C); nhóm
`Stops and target` tách thành `03 Stops` + `06 Strategy` (phase C).

## 4. Preset và magic

- Preset JSON: [`configs/demo/wonderwhales_demo.json`](../../configs/demo/wonderwhales_demo.json)
  (`DEMO_ONLY`, `allow_live_trading=false`, `InpEnableExecution=true`, symbol `XAUUSDm`, timeframe M15).
- Chưa có preset `.set` riêng trong `docs/20-operations/presets/` (4 `.set` hiện có thuộc 4 bot demo đầu:
  PA, Grid, DCA, InfiniteRunner);
  scenario tester của EA demo dùng `reports/build/tester-sets/ww_demo_exec.set` (gitignored).
- Kill switch: `WONDERWHALES_DEMO_STOP.txt`; state file `wonderwhales_demo_state.csv`.
- Sim: `mt5/Experts/WonderwhalesSimEA.mq5`, preset `configs/sim/wonderwhales_xauusdm.json`
  (calibration `XAUUSDm`: 3 digits, point 0.001, contract 100, spread ~260 points).

## 5. Bằng chứng

Nhãn: **`UNPROVEN`** — tester của EA demo đã chạy thật (§69.4) nhưng net âm; phiên demo chart `NOT_RUN`.

- Strategy Tester `ww_demo_exec` (headless, 2026-11-03, XAUUSDm M15, 2026.01.05→15): **41 ENTRY / 41
  EXIT**, 18 block, 2 HALT + 1 RESUME; `SUMMARY: trades=41|wins=11|losses=30|net=−625.72|halted=HALTED`.
  Halt 1: daily loss 2.06% (2026-01-06) → tự `RESUME` sang ngày sau (đúng thiết kế khoá theo ngày).
  Halt 2: max drawdown 8.01% (2026-01-15) → dính tới hết kỳ. Bằng chứng:
  `reports/build/tester-reports/ww_demo_exec/` (gitignored); chi tiết [`../PROGRESS.md`](../PROGRESS.md) §69.4.
- SimEA (`WonderwhalesSimEA`, vị thế ảo): 3 scenario chạy thật 2026-10-28 (§40) — `ww_baseline` +26.97,
  `ww_conservative_stress` −7.50, `ww_edge_atr_stop` +24.96, model contract 1.
- Compile EA demo 0 errors / 0 warnings (§69.3) — chỉ chứng minh cú pháp.
- **Phiên demo chart (`NOT_RUN`):** chưa từng attach `WonderwhalesDemoEA` lên chart demo — cần operator.

## 6. Giới hạn / quirk đã biết

- Net **−625.72** trong 10 ngày tester là kết quả của mô hình backtest — **không phải cam kết lợi nhuận**;
  chiến lược `UNPROVEN`, chưa có forward test demo.
- Quirk vận hành: `.set` phải copy vào `MQL5\Profiles\Tester\` — lần chạy đầu thiếu bước này nên tester
  dùng input mặc định và đó là lần phát hiện bug halt vĩnh viễn (§69.4).
- Halt do `InpMaxDrawdownPct` và kill switch **dính tới khi operator khởi động lại** (state giữ cờ halt);
  halt do daily loss thì tự mở sang ngày (`RESUME`).
- `InpMaxLots=0.10` chặn kích thước lệnh; với ngân sách 1%/lệnh, tín hiệu stop rộng bị **bỏ qua** (skip),
  không làm tròn lên lot.
- Không break-even/trailing trong v1 — vị thế chỉ thoát bởi SL/TP, tín hiệu đảo, hoặc max holding.
- `WonderwhalesSimEA` giữ nguyên `SIMULATION_ONLY` (ADR 0007): ba scenario cũ của nó không được trộn với
  journal demo `wonderwhales_demo.csv`.
- Parity Pine ↔ MQL5 (Track B) vẫn `BLOCKED` — tín hiệu của port chưa được đối chiếu từng dòng với Pine gốc.
