# Infinite Runner XAU V2 — bot demo thứ tư

**EA demo:** `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` · **magic** `25006001` · **nhãn** `NOT_RUN`
(tester đã có lệnh từ 2026-11-08, **chưa** có phiên demo thật). Nguồn chưng cất:
[`../99-archive/MT5_EA_Lab_V2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/README.md`](../99-archive/MT5_EA_Lab_V2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/README.md)
+ [`.../INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md`](../99-archive/MT5_EA_Lab_V2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md),
[`../90-decisions/0005-infiniterunner-xau-demo-bot.md`](../90-decisions/0005-infiniterunner-xau-demo-bot.md).

## 1. Chiến lược

"Runner" một vị thế chạy liên tục: giữ lệnh bằng trailing SL thay vì TP gần (khác V1 có TP=0). V2 quyết
định **chỉ trên nến đã đóng** (EMA/ATR đọc ở shift 1) — sửa lỗi quyết định trên nến đang chạy của V1.
Hai chế độ hướng: `IR_DIR_LEGACY_EMA` (EMA nhanh ngược chiều, parity V1 làm baseline A/B) và
`IR_DIR_EMA_MTF` (H1 context + M15 xác nhận + M5 pullback-reclaim); `NO_TRADE`/`REVERSAL_WATCH`/
`*_BLOCKED` là quyết định hợp lệ, không ép vào lệnh. Vào lệnh một vị thế theo hướng; thoát bằng
trailing/break-even: SL ban đầu theo mode fixed points hoặc ATR × hệ số (band `[InpMinStopPoints,
InpMaxStopPoints]`), BE ở `InpBreakEvenTriggerR`, trailing `InpTrailStartPts`/`InpTrailDistancePts`/
`InpTrailStepPts` (mode fixed) hoặc ATR × hệ số; SL chỉ siết (monotonic) dựa trên initial R lưu state.
**TP an toàn xa bắt buộc** `InpSafetyTpPoints=100000` — bot vẫn thoát bằng trailing SL, đáp ứng yêu cầu
SL+TP trên mọi lệnh. Có thêm step trailing 3 nấc khoá lợi nhuận (`InpEnableStepTrailing`).

## 2. Cấu trúc code

| File | Vai trò |
|---|---|
| `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` | EA demo ~1800 dòng: MTF closed-bar, guard, state file |
| `mt5/Include/InfiniteRunner/IRTypes.mqh` | Enums (direction/SL/trail/lot mode), reason codes |
| `mt5/Include/InfiniteRunner/IRDirection.mqh` | Bộ xác định hướng (legacy EMA / EMA MTF) |
| `mt5/Include/InfiniteRunner/IRTrailing.mqh` | BE + trailing từ initial R, monotonic SL |
| `mt5/Include/InfiniteRunner/IRRisk.mqh` | Circuit-breaker loss-streak thuần: block / arm cooldown / khôi phục |
| `mt5/Scripts/IRCoreTests.mq5` | Test thuần logic (loss-streak guard, step trailing, BE, monotonic, band) |
| `mt5/Include/Exec/ExecBroker.mqh` | Điểm gửi lệnh duy nhất (không `OrderSend` trực tiếp) |
| `mt5/Include/Sim/SimRiskGuard.mqh`, `SimLogger.mqh` | Guard rủi ro và journal CSV |

V1 tham chiếu `github-demo/InfiniteRunner_XAU/InfiniteRunner_XAU.mq5` giữ nguyên trạng, không compile
thành EA giao dịch; alt A đã lưu trữ (xem ADR 0005).

## 3. Bảng input

60 input khai báo — các nhóm chính (giá trị mặc định):

| Nhóm | Input (tên hiện tại) | Giá trị mặc định | Tên chuẩn (phase C) |
|---|---|---|---|
| Demo execution | `InpEnableExecution` | `true` | `InpEnableExecution` |
| | `InpAllowedSymbols` | `"XAUUSD"` | `InpAllowedSymbols` |
| | `InpMagicNumber` | `25006001` | `InpMagicNumber` |
| | `InpMaxSlippagePoints` | `30` | `InpMaxSlippagePoints` |
| | `InpKillSwitchFile` | `"INFINITE_RUNNER_DEMO_STOP.txt"` | `InpKillSwitchFile` |
| | `InpCloseOnKillSwitch` | `true` | `InpCloseOnKillSwitch` |
| Journal and state | `InpEnableLog` / `InpLogFile` | `true` / `"infinite_runner_demo.csv"` | giữ |
| | `InpPersistState` / `InpStateFile` | `true` / `"infinite_runner_demo_state.csv"` | giữ |
| | `InpResetStateOnInit` / `InpDebug` | `false` / `false` | giữ |
| Direction | `InpDirectionMode` | `IR_DIR_LEGACY_EMA` | giữ |
| | `InpH1TF` / `InpM15TF` / `InpEntryTF` | H1 / M15 / M5 | giữ |
| | `InpEmaFast` / `InpEmaSlow` | 21 / 50 | giữ |
| | `InpSlopeBars` / `InpSlowSlopeTolPoints` / `InpPullbackTolPoints` | 5 / 100 / 100 | giữ |
| Entry control | `InpMaxPositions` | 1 | giữ |
| | `InpCooldownMinutes` / `InpMinBarsBetweenEntries` / `InpMaxTradesPerDay` | 0 / 1 / 50 | giữ |
| Risk | `InpLotMode` / `InpLots` | `IR_LOT_FIXED` / 0.01 | giữ |
| | `InpRiskPercent` | 0.25 | giữ |
| | `InpMaxLots` | 0.20 | `InpMaxExposure` (phase C) |
| | `InpMaxSpreadPoints` | 600 | giữ |
| | `InpMaxSpreadAtrRatio` / `InpAbnormalAtrRatio` | 0.0 / 2.5 | giữ |
| | `InpAtrPeriod` / `InpAtrBaselineBars` | 14 / 100 | giữ |
| | `InpMaxDailyLossPct` / `InpMaxDrawdownPct` | 1.0 / 8.0 | giữ |
| | `InpMaxConsecutiveLosses` / `InpHaltOnBreach` / `InpManualResetDrawdown` | 3 / `true` / `false` | giữ |
| | `InpLossStreakCooldownMinutes` | 240 | giữ (mới 2026-11-09: hồi phục sau chuỗi thua; `0` = khoá vĩnh viễn) |
| Initial SL | `InpSlMode` / `InpInitialSlPoints` / `InpSlAtrMultiplier` | `IR_SL_FIXED` / 5000 / 3.0 | giữ |
| | `InpMinStopPoints` / `InpMaxStopPoints` | 500 / 20000 | giữ |
| Trailing | `InpTrailMode` | `IR_TRAIL_FIXED` | giữ |
| | `InpTrailStartPts` / `InpTrailDistancePts` / `InpTrailStepPts` | 3000 / 2500 / 500 | `InpTrailStartPoints` / `InpTrailDistancePoints` / `InpTrailStepPoints` (phase C) |
| | `InpTrailAtrMultiplier` / `InpBreakEvenTriggerR` / `InpBreakEvenBufferPts` | 2.0 / 0.0 / 100 | giữ |
| | `InpSafetyTpPoints` | 100000 | giữ |
| Step Trailing | `InpEnableStepTrailing` | `true` | giữ |
| | `InpStep1_TriggerPoints` / `InpStep1_LockPoints` | 1500.0 / 200.0 | giữ |
| | `InpStep2_TriggerPoints` / `InpStep2_LockPoints` | 3000.0 / 1500.0 | giữ |
| | `InpStep3_TriggerPoints` / `InpStep3_LockPoints` | 5000.0 / 3500.0 | giữ |

Gap so chuẩn (xem thiết kế §9): `InpMaxLots` sẽ thay bằng `InpMaxExposure` (phase C); hậu tố `Pts`
(`InpTrailStartPts`/`InpTrailStepPts`) chuẩn hoá về `...Points` (phase C, đổi tên + cập nhật preset
cùng lúc).

## 4. Preset và magic

- Preset JSON: [`configs/demo/infinite_runner_demo.json`](../../configs/demo/infinite_runner_demo.json)
  — `DEMO_ONLY`, `allow_live_trading=false`, `InpEnableExecution=true`, symbol `XAUUSDm`, timeframe M5,
  band SL 500–20000, `InpSafetyTpPoints=100000`, `InpMaxPositions=1`.
- Preset `.set`: [`docs/20-operations/presets/infinite_runner_v2.set`](../20-operations/presets/infinite_runner_v2.set)
  (dành cho `InfiniteRunnerXAUV2DemoEA`, M5).
- Kill switch: `INFINITE_RUNNER_DEMO_STOP.txt`; state file `infinite_runner_demo_state.csv`.
- Không có EA sim riêng (không bắt buộc theo ADR 0005).

## 5. Bằng chứng

Nhãn: **`NOT_RUN`** — chưa có phiên **demo thật** nào ghi kết quả; tester đã có kết quả có lệnh từ 2026-11-08
(§90, xem dưới) nhưng đó là backtest, không phải phiên demo.

- §65: hai luồng song song ghi đè nhau trước ADR — alt A mất, lưu trữ nguyên trạng; canonical = alt B.
- §66: ADR 0005 Accepted, đăng ký validator/preset/test xong; tester lần đầu (user chạy tay) **0 trades**
  — do `InpEnableExecution=false` (dry-run mặc định lúc đó) + tính chọn lọc MTF.
- §67: ADR 0006 đổi mặc định `InpEnableExecution=true`; đồng thời sửa bug thật: entry gọi
  `EvaluateRisk(0.0,…)` trước sizing → guard block `volume_to_add_invalid` → HALT vĩnh viễn mọi phiên
  (halt_on_breach). Sau fix, guard thường không còn giết phiên. Backtest lại V2 với `.set` mới là việc
  tiếp theo của chủ dự án.
- §90 (2026-11-08): **tester đã chạy có lệnh** — `infinite_runner_demo_exec`, XAUUSDm M5, 2026.01.05→2026.10.01,
  deposit 10.000 → `entries=101|exits=101|wins=81|losses=20|blocks=52462|sl_updates=113|realized=+1,70|
  halted=ACTIVE`, equity cuối 10.001,70. Với state sạch, tester **không** tái hiện chẩn đoán "vị thế lạc chiếm
  slot". Bằng chứng: `reports/build/tester-reports/infinite_runner_demo_exec/` (gitignored).
- §92 (2026-11-09): **chẩn đoán từ chính journal 101 lệnh** — cả 101 lệnh chỉ nằm trong **3 ngày đầu**
  (2026.01.05–01.07, chạm trần 50 lệnh/ngày); từ 2026.01.07 lệnh thua thứ 3 liên tiếp đặt `streak=3` và
  `EntryThrottlesOk` **chặn mọi entry vĩnh viễn** (`blocks=52.462`, trong đó 51.937 là `loss_streak`) vì
  streak chỉ reset khi có lệnh **thắng** — mà bot bị chặn thì không có lệnh nào. Đây là **deadlock**, không
  phải chiến lược. Kinh tế trong 101 lệnh: thắng TB **+$1,26 (0,25R)** so với thua đủ **−$5,00 (1R)** ⇒
  expectancy ≈ 0 (winrate 80,2% là *sản phẩm của exit*, không phải edge). Sửa: thêm
  `InpLossStreakCooldownMinutes=240` (cooldown, hết hạn tự xoá streak) qua module thuần `IRRisk.mqh`.
- Chưa có phiên **demo thật** có lệnh; lợi nhuận vẫn `UNPROVEN` (backtest không thay được phiên demo).
- §93 (2026-11-09): **nghiên cứu đầy đủ** — [`../30-research/infinite-runner-study.md`](../30-research/infinite-runner-study.md).
  Đo trên 2018–2026 (khoá daily/DD tắt): entry ở 1:1 winrate **48,08%** (< 50%) trên 33.668 lệnh ⇒ **không có
  edge**; ba định nghĩa exit (step trail / trail rộng / không trail) **đều âm**; mode `IR_DIR_EMA_MTF` chỉ 31
  lệnh/8,75 năm; preset ship tự halt ở DD 8% ngày 2020.06.23. Kết luận: không tinh chỉnh thêm trên tín hiệu này.

## 6. Giới hạn / quirk đã biết

- **Quirk hậu tố:** bot này dùng `Pts` (`InpTrailStartPts`, `InpTrailStepPts`) trong khi 4 EA demo còn
  lại dùng `Points` — lệch chuẩn đặt tên, sẽ được chuẩn hoá ở phase C.
- **Nhầm EA đã xảy ra thật:** log ngày 2026-10-30 cho thấy V1 tham chiếu (`InfiniteRunner_XAU.ex5`,
  `tp: 0.000`) đã được chạy nhầm thay vì V2 (§67.1) — kiểm tra đúng `.ex5` của
  `InfiniteRunnerXAUV2DemoEA` trước khi kết luận "không có lệnh".
- TP an toàn 100 000 points là "TP danh nghĩa" để thoả SL+TP bắt buộc — thoát lệnh thực tế bằng trailing
  SL; đừng kỳ vọng TP đó khớp lệnh.
- `InpMaxSpreadPoints=600` (mặc định) rộng hơn spread Exness thực đo (~150–300 points) — guard spread
  hầu như không chặn ở giá trị mặc định.
- `InpCooldownMinutes=0` mặc định — khoảng cách entry chỉ còn do `InpMinBarsBetweenEntries=1` và
  `InpMaxTradesPerDay=50`.
- **Deadlock loss-streak (đã sửa 2026-11-09):** trước đây `InpMaxConsecutiveLosses=3` chặn entry **vĩnh
  viễn** (streak chỉ xoá khi thắng) nên bot tự tắt sau ~2 ngày và không bao giờ vào lại. Nay
  `InpLossStreakCooldownMinutes` (>0) cho bot tự hồi phục sau cooldown; đặt `0` quay lại hành vi khoá vĩnh
  viễn (chỉ dùng khi cố ý).
- Lợi nhuận `UNPROVEN`; chưa có SELL/BUY nào của V2 trên demo; parity với V1 trên nến đóng là mục đích
  của mode `IR_DIR_LEGACY_EMA` chứ chưa được đối chiếu số.
