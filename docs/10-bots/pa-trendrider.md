# PA TrendRider XAU v1 — bot demo đầu tiên

**EA demo:** `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` · **magic** `25002001` · **nhãn** `PARTIAL`.
Nguồn chưng cất: [`../99-archive/MT5_EA_Lab_V1/PA_TrendRider_XAU_V1_Specification_Vietnamese.md`](../99-archive/MT5_EA_Lab_V1/PA_TrendRider_XAU_V1_Specification_Vietnamese.md),
[`../99-archive/MT5_EA_Lab_V2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md`](../99-archive/MT5_EA_Lab_V2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md).

## 1. Chiến lược

Price action đa khung: bias hợp nhất từ swing H1 và M15 (chỉ nến đã đóng, không repaint) quyết định
hướng được phép giao dịch; trên M5, engine cấu trúc phát BOS/CHoCH với buffer phá mức
`max(spread×2.0, ATR×0.10)`; vào lệnh khi giá retest vùng swing bị phá (± `InpRetestZoneAtr` × ATR) và có
nến xác nhận (body ≥ 0.5 ATR, close trong 25% ngoài của range), với tuổi setup ≤ 8 bar M5. Thoát bằng
SL cấu trúc (∓ `InpAtrStopBuffer` × ATR), TP = entry ± 3R (`InpTakeProfitR=3.0`), breakeven ở 1R,
trailing ATR từ 1.5R; CHoCH xác nhận theo hướng ngược thì đóng vị thế. Chỉ một vị thế theo magic.

## 2. Cấu trúc code

| File | Vai trò |
|---|---|
| `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` | EA demo: state machine 11 trạng thái, guard + lệnh qua `Exec/*` |
| `mt5/Include/TrendRider/*.mqh` (12 module) | Swing, cấu trúc BOS/CHoCH, bias merge, pullback/confirmation, tín hiệu, ATR, risk/trailing/state |
| `mt5/Include/Exec/ExecGuard.mqh`, `ExecBroker.mqh` | Rào chắn tài khoản demo/tester và điểm gửi lệnh duy nhất |
| `mt5/Scripts/TrendRiderContractTests.mq5` | Contract suite 82 vector |
| `mt5/Scripts/ExecDemoProbe.mq5` | Script kiểm tra đường lệnh thật (magic 25002002) |

## 3. Bảng input

47 input khai báo, chia 7 nhóm — liệt kê theo đúng thứ tự trong source (giá trị mặc định):

| Nhóm | Input (tên hiện tại) | Giá trị mặc định | Tên chuẩn (phase C) |
|---|---|---|---|
| Demo execution | `InpEnableExecution` | `true` | `InpEnableExecution` |
| | `InpAllowedSymbols` | `"XAUUSD"` | `InpAllowedSymbols` |
| | `InpMagicNumber` | `25002001` | `InpMagicNumber` |
| | `InpMaxSlippagePoints` | `30` | `InpMaxSlippagePoints` |
| | `InpTakeProfitR` | `3.0` | `InpTakeProfitR` |
| | `InpKillSwitchFile` | `"PA_TREND_RIDER_DEMO_STOP.txt"` | `InpKillSwitchFile` |
| Journal and state | `InpEnableLog` | `true` | `InpEnableLog` |
| | `InpLogFile` | `"pa_trendrider_demo.csv"` | `InpLogFile` |
| | `InpPersistState` | `true` | `InpPersistState` |
| | `InpStateFile` | `"pa_trendrider_demo_state.csv"` | `InpStateFile` |
| | `InpResetStateOnInit` | `false` | `InpResetStateOnInit` |
| | `InpDebug` | `false` | `InpDebug` |
| Timeframes | `InpTrendTF` / `InpStructureTF` / `InpEntryTF` | H1 / M15 / M5 | giữ |
| | `InpTrendBars` / `InpStructureBars` / `InpEntryBars` | 300 / 300 / 400 | giữ |
| Structure | `InpSwingLeft` / `InpSwingRight` | 2 / 2 | giữ |
| | `InpSpreadBufferMultiplier` | 2.0 | giữ |
| | `InpAtrBreakBufferMultiplier` | 0.10 | giữ |
| | `InpTrendMinDeltaAtr` | 0.05 | giữ |
| | `InpRetestZoneAtr` | 0.25 | giữ |
| | `InpConfirmationBodyAtr` | 0.5 | giữ |
| | `InpConfirmationCloseZone` | 0.25 | giữ |
| | `InpMaxSignalAgeBars` | 8 | giữ |
| Risk | `InpRiskPercent` | 0.25 | `InpRiskPercent` |
| | `InpMaxPositions` | 1 | `InpMaxPositions` |
| | `InpDailyLossLimitPct` | 1.0 | `InpMaxDailyLossPct` (phase C) |
| | `InpMaxDrawdownPct` | 8.0 | `InpMaxDrawdownPct` |
| | `InpMaxConsecutiveLosses` | 3 | `InpMaxConsecutiveLosses` |
| | `InpCooldownMinutes` | 30 | `InpCooldownMinutes` |
| | `InpManualResetDrawdown` | `false` | giữ |
| | `InpCommissionPerVolume` | 0.0 | giữ |
| Stops | `InpBreakEvenAtR` | 1.0 | giữ |
| | `InpTrailingStartR` | 1.5 | giữ |
| | `InpAtrStopBuffer` | 0.2 | giữ |
| | `InpAtrTrailingMultiplier` | 1.2 | giữ |
| | `InpMinSlAtr` / `InpMaxSlAtr` | 0.5 / 4.0 | giữ |
| | `InpUpdateOnClosedBarOnly` | `true` | giữ |
| Volatility and spread | `InpAtrPeriod` / `InpAtrBaselineBars` | 14 / 100 | giữ |
| | `InpAbnormalAtrRatio` | 2.5 | giữ |
| | `InpMaxSpreadPoints` | 600.0 | giữ |
| | `InpMaxSpreadAtrRatio` | 0.25 | giữ |

Gap so chuẩn (xem [`../superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md`](../superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md) §9):
**thiếu** input `InpCloseOnKillSwitch` (phase C: thêm, mặc định `true`); `InpDailyLossLimitPct` sẽ đổi tên thành
`InpMaxDailyLossPct` (phase C); kill switch đang nằm trong nhóm `Demo execution` (phase C: nhóm `05 Kill switch`).

## 4. Preset và magic

- Preset JSON: [`configs/demo/pa_trendrider_xau_demo.json`](../../configs/demo/pa_trendrider_xau_demo.json)
  (`DEMO_ONLY`, `allow_live_trading=false`, symbol `XAUUSDm`, timeframe M5).
- Preset `.set` (Strategy Tester): [`docs/20-operations/presets/pa_trendrider_xau.set`](../20-operations/presets/pa_trendrider_xau.set).
- Sim (mô phỏng): `mt5/Experts/PATrendRiderXAUv1SimEA.mq5`, magic `25001001` (chỉ log),
  preset `configs/sim/pa_trendrider_xau.json`.
- Kill switch: `PA_TREND_RIDER_DEMO_STOP.txt` trong `MQL5/Files`. Tài khoản chỉ demo/tester — real bị
  chặn ở `OnInit` (ADR 0002/0004; mặc định bật execution theo ADR 0006).

## 5. Bằng chứng

Nhãn: **`PARTIAL`** — đường gửi lệnh có bằng chứng thật (§44/§45), **chưa có ENTRY trên chart demo**
(§52), lợi nhuận `UNPROVEN`.

- Broker demo chấp nhận lệnh qua `ExecBroker`: `ExecDemoProbe` mở BUY 0.01 `XAUUSDm` deal `2468899165`
  @4045.79 (SL 4042.79 / TP 4048.79), đóng deal `2468899168` @4045.55, pnl −0.24, 103 ms — §44/§45.
- DemoEA trên chart: `INIT mode=DEMO_EXECUTION|restored=1|config_hash=6B439450|mql_trade_allowed=1`
  (§48.6, §50.4, §52) — nhưng `state=WAITING_FOR_SETUP`, **0 ENTRY** do bộ lọc regime (đúng thiết kế).
- Strategy Tester (demo path): `demo_exec_visual` — 4 ENTRY/4 EXIT, net −31.04 (§63); `demo_exec_gui_20261029`
  — 31 ENTRY/31 EXIT, net +53.72 (nguồn archive V2 §12.3). Backtest, không phải phiên live.
- SimEA: baseline 5k net −36.72, cost stress net −37.28 (§42); `TrendRiderContractTests` 82/82 PASS.
- Bằng chứng lưu ở `reports/build/tester-reports/` (gitignored); log chi tiết trong
  [`../PROGRESS.md`](../PROGRESS.md) §42–§45, §48–§52, §63.

## 6. Giới hạn / quirk đã biết

- **Chưa từng có `ENTRY` do DemoEA gửi trên tài khoản demo** (chỉ probe script và tester); lần chạy
  cuối `state=WAITING_FOR_SETUP`, chặn `bias_unknown`/`reversal_watch` — hành vi đúng của bộ lọc.
- Lợi nhuận `UNPROVEN`: mọi số net đều là backtest/mô hình, cửa sổ ngắn, một symbol/một bộ tham số.
- **Chưa có** input `InpCloseOnKillSwitch` (4 EA demo còn lại có) — khi kill switch kích hoạt, EA không
  chủ động đóng vị thế đang mở. Phase C sẽ thêm (mặc định `true`); chưa sửa hiện tại.
- `InpDailyLossLimitPct` lệch tên chuẩn `InpMaxDailyLossPct` (phase C).
- Panel/CSV chỉ ghi khi trạng thái đổi — file đứng yên nhiều bar không có nghĩa EA ngừng chạy (§50.5).
- Hành vi SELL trên broker thật `UNKNOWN` (probe chỉ BUY); chưa gặp retcode từ chối theo giờ/freeze.
