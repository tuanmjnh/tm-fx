# Wonderwhales XAU 2-mode — bot demo thứ sáu

**EA demo:** `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` · **magic** `25008001` · **nhãn** `NOT_RUN` (đã
compile 0/0; tester headless + phiên demo chart chưa chạy trong bằng chứng commit này). Nguồn yêu cầu:
[`Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md`](Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md) (v2.2) và
[ADR 0009](../90-decisions/0009-wonderwhales-xau-2mode-demo-bot.md).

## 1. Chiến lược

Một bot, **một magic**, hai chế độ `InpTradingMode`:

- **Scalp (`WW2_SCALP`):** M15 là bộ lọc xu hướng (EMA20/EMA50 + giá so EMA200), M5 là setup
  (PSAR flip cùng bias + EMA đồng thuận), M1 là ngà kích hoạt.
- **Swing (`WW2_SWING`):** W1 là xu hướng nền, D1 đồng thuận (ưu tiên EMA200), H1 PSAR flip.
- `WW2_SIGNAL_ONLY`: chỉ đọc tín hiệu và ghi log, không gửi lệnh (dry-run có chủ đích).

Tín hiệu đọc từ indicator `PinePort\Wonderwhales` (hợp đồng 18 buffer, `shift=1` — nến đã đóng), **không**
tự tính lại PSAR/EMA/ATR trong EA. SL ban đầu = swing đã xác nhận (M5 cho Scalp, H1 cho Swing) + buffer
ATR, fallback `×ATR`, có sàn/trần. TP bắt buộc = `InpTakeProfitR` × khoảng SL. Break-even (có buffer chi
phí) + trailing cấu trúc/PSAR/ATR/step qua `WW2TrailingCoordinator` — **chỉ siết SL**, R luôn tính từ SL
ban đầu đã lưu. Mặc định đầu tiên: `InpTradingMode=SCALP`, `InpEnableExecution=true`, `InpDemoOnly=true`
(chặn tài khoản real).

**Cổng parity (S2):** `InpRequireParity=true` **chặn mọi entry** (`reason=parity_blocked`) cho tới khi
parity Pine ↔ MT5 được chứng minh. Kết quả có được khi bỏ parity **không** phải kết quả chiến lược hợp lệ.

## 2. Cấu trúc code

| File | Vai trò |
|---|---|
| `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | EA: input, vòng đời, phối hợp, điểm gửi lệnh duy nhất qua `ExecBroker` |
| `mt5/Include/Wonderwhales/WW2Types.mqh` | enum mode, struct signal/position, R từ initial SL |
| `mt5/Include/Wonderwhales/WW2SignalReader.mqh` | đọc buffer theo contract (không tự tính lại) |
| `mt5/Include/Wonderwhales/WW2ScalpStrategy.mqh`, `WW2SwingStrategy.mqh` | logic bias/setup/trigger thuần |
| `mt5/Include/Wonderwhales/WW2Swing.mqh`, `WW2InitialStop.mqh` | swing fractal + khoảng SL ban đầu |
| `mt5/Include/Wonderwhales/WW2RiskSizer.mqh` | volume theo tiền lỗ tại SL; min-lot vượt budget → bỏ |
| `mt5/Include/Wonderwhales/WW2RiskGuard.mqh` | daily/weekly/drawdown/chuỗi thua + cooldown, lưu bền vững |
| `mt5/Include/Wonderwhales/WW2TrailingCoordinator.mqh` | gộp ứng viên SL, chọn tốt nhất, không nới |
| `mt5/Include/Wonderwhales/WW2Telemetry.mqh` | file telemetry riêng (R, SL, lý do trailing, EMA/PSAR/ATR) |
| `mt5/Include/Exec/*`, `mt5/Include/Sim/SimLogger.mqh` | guard demo/tester, điểm gửi lệnh, journal 18 cột |
| `mt5/Scripts/WW2CoreTests.mq5` | test thuần logic (sizer, guard, trailing, swing, strategy) |
| `mt5/Indicators/PinePort/Wonderwhales.mq5` | indicator nguồn tín hiệu |

**Ràng buộc:** chỉ `ExecBroker` gửi/sửa/đóng lệnh; các module `Wonderwhales/*` chỉ trả giá trị (không gọi
API account/trading), nên static gate "chỉ Exec gửi lệnh" còn hiệu lực.

## 3. Bảng input (nhóm chuẩn)

Input khai theo 6 nhóm của [`input-convention.md`](input-convention.md) — **đúng tên này** trùng key trong
`configs/demo/wonderwhales_xau_2mode_demo.json`. Bảng dưới là giá trị mặc định trong source (preset có thể
đặt khác theo chế độ).

| Nhóm | Input | Mặc định |
|---|---|---|
| `01 Execution` | `InpEnableExecution` | `true` |
| | `InpDemoOnly` | `true` (bắt buộc; `false` → `INIT_PARAMETERS_INCORRECT`) |
| | `InpAllowedSymbols` / `InpMagicNumber` / `InpMaxSlippagePoints` | `"XAUUSD"` / `25008001` / `30` |
| | `InpTradingMode` / `InpSignalMode` | `WW2_SCALP` / `WW_MODE_SAR_EMA` |
| `02 Risk` | `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes` | `0.15` / `1` / `20` |
| | `InpMaxConsecutiveLosses` | `2` |
| | `InpMaxDailyLossPct` / `InpMaxWeeklyLossPct` / `InpMaxDrawdownPct` | `1.0` / `2.0` / `5.0` |
| | `InpMaxSpreadPoints` / `InpMaxSpreadRatioToSlPct` | `600.0` / `10.0` |
| | `InpMaxExposure` / `InpHaltOnBreach` | `0.10` / `true` |
| `03 Stops` | `InpTakeProfitR` / `InpMinStopPoints` / `InpMaxStopPoints` | `1.5` / `150.0` / `100000.0` |
| | `InpScalpBufferAtr` / `InpScalpSlAtrFallback` | `0.20` / `1.2` |
| | `InpSwingBufferAtr` / `InpSwingSlAtrFallback` | `0.30` / `2.0` |
| | `InpBreakEvenCostBuffer` / `InpBreakEvenBufferPoints` | `true` / `50.0` |
| `04 Journal and state` | `InpEnableLog` / `InpLogFile` | `true` / `"wonderwhales_xau_2mode_demo.csv"` |
| | `InpEnableTelemetry` / `InpTelemetryFile` | `true` / `"wonderwhales_xau_2mode_telemetry.csv"` |
| | `InpPersistState` / `InpStateFile` / `InpResetStateOnInit` / `InpDebug` | `true` / `"wonderwhales_xau_2mode_demo_state.csv"` / `false` / `false` |
| `05 Kill switch` | `InpKillSwitchFile` / `InpCloseOnKillSwitch` | `"WONDERWHALES_XAU_2MODE_DEMO_STOP.txt"` / `true` |
| | `InpRequireParity` | `true` (cổng parity chặn entry) |
| `06 Strategy` | `InpPsarStart`/`InpPsarInc`/`InpPsarMax` | `0.02`/`0.02`/`0.20` |
| | `InpFastEma`/`InpSlowEma`/`InpEma200` | `20`/`50`/`200` |
| | `InpAtrLen`/`InpMinAtrPct`/`InpVolMaLen`/`InpRsiLen`/`InpBbLen`/`InpBbMult` | `14`/`0.5`/`20`/`14`/`20`/`2.0` |
| | `InpWarmupBars` | `300` |
| | `InpScalpBiasTF`/`InpScalpSetupTF`/`InpScalpTriggerTF` | `M15`/`M5`/`M1` |
| | `InpSwingBiasTF`/`InpSwingSetupTF`/`InpSwingTriggerTF` | `W1`/`D1`/`H1` |
| | `InpBreakEvenTriggerR`/`InpTrailTriggerR`/`InpMinTrailStepPoints` | `1.0`/`1.3`/`50.0` |
| | `InpSwingRrMin`/`InpSwingConfirmBars`/`InpStructureLookbackBars` | `1.8`/`2`/`300` |
| | `InpEnableStructureTrail`/`InpEnablePsarTrail`/`InpEnableAtrTrail`/`InpEnableStepTrail` | `true`/`false`/`false`/`false` |
| | `InpStepTrailPoints`/`InpTrailBufferAtr`/`InpExitOnFlip`/`InpMaxHoldingBars` | `300.0`/`0.25`/`true`/`0` |

### Ánh xạ spec (tên Việt) → input engine

Vài giá trị spec tách theo chế độ được gộp vào **một** input, đặt theo **preset** (một chế độ chạy tại một
thời điểm — spec §1.2). Một nguồn sự thật, tránh hai tham số mâu thuẫn.

| Nhóm spec | Tên spec | Input engine | Ghi chú |
|---|---|---|---|
| `00` | `CheDoGiaoDich` | `InpTradingMode` | enum `WW2_SIGNAL_ONLY/SCALP/SWING` |
| `00` | `BatGuiLenh` / `ChiGiaoDichTaiKhoanDemo` | `InpEnableExecution` / `InpDemoOnly` | ADR 0006; demo-only bắt buộc |
| `00` | `MaGiaoDichDuocPhep` / `Magic` | `InpAllowedSymbols` / `InpMagicNumber` | một magic `25008001` |
| `01` | `CheDoTinHieu` / tham số PSAR/EMA/ATR | `InpSignalMode` + `InpPsar*`/`Inp*Ema`/`InpAtrLen`/`InpMinAtrPct` | |
| `03` | `Scalp_RR_MucTieu` **và** `Swing_RR_MucTieu` | `InpTakeProfitR` | preset Scalp `1.5`, Swing `2.5` |
| `03` | `Swing_RR_ToiThieu` | `InpSwingRrMin` | kiểm ở `OnInit` khi chế độ SWING |
| `03` | `Scalp_BufferSwing_ATR` / `Swing_BufferSwing_ATR` | `InpScalpBufferAtr` / `InpSwingBufferAtr` | |
| `03` | `Scalp_SL_ATR_DuPhong` / `Swing_SL_ATR_DuPhong` | `InpScalpSlAtrFallback` / `InpSwingSlAtrFallback` | |
| `04` | `Scalp_RuiRoMoiLenh_PhanTram` / `Swing_..._PhanTram` | `InpRiskPercent` | preset Scalp `0.15`, Swing `0.25` |
| `04` | `GioiHanKhoiLuongToiDa` | `InpMaxExposure` | phase C: `InpMaxLots` → `InpMaxExposure` |
| `04` | `LoToiDaTrongNgay/Tuan_PhanTram`, `DrawdownToiDa_PhanTram` | `InpMaxDailyLossPct`/`InpMaxWeeklyLossPct`/`InpMaxDrawdownPct` | |
| `04` | `SoLenhThuaLienTiepToiDa` | `InpMaxConsecutiveLosses` | |
| `05` | `BatHoaVon` / `HoaVon_CongBuChiPhi` | `InpBreakEvenCostBuffer` + `InpBreakEvenTriggerR` | preset đặt `*_KichHoatBE_R` |
| `05` | `BatTrailingCauTruc/PSAR/ATR/Buoc` | `InpEnableStructureTrail`/`InpEnablePsarTrail`/`InpEnableAtrTrail`/`InpEnableStepTrail` | |
| `05` | `BuocTrailing_Points` / `Trailing_Buffer_ATR` | `InpStepTrailPoints` / `InpTrailBufferAtr` | |
| `05` | `SoNenXacNhanSwing` / `KhoangCachToiThieuSuaSL_Points` | `InpSwingConfirmBars` / `InpMinTrailStepPoints` | |
| `06` | `SpreadToiDa_Points` / `SpreadToiDa_PhanTramKhoangSL` | `InpMaxSpreadPoints` / `InpMaxSpreadRatioToSlPct` | |
| `07` | `BatGhiNhatKy` / `TenFileTelemetry` / `BatParity` | `InpEnableLog`+`InpLogFile` / `InpTelemetryFile` / `InpRequireParity` | |

**Không có** input số lệnh/ngày (`Scalp/Swing_ToiDaLenhMoiNgay`): spec v2.1 đã bỏ hạn mức đó; số lệnh chỉ
bị chặn gián tiếp qua risk guard.

## 4. Preset, magic và file

- Preset JSON: [`configs/demo/wonderwhales_xau_2mode_demo.json`](../../configs/demo/wonderwhales_xau_2mode_demo.json)
  (`DEMO_ONLY`, `allow_live_trading=false`, `InpEnableExecution=true`, `InpRequireParity=true`, symbol
  `XAUUSDm`, timeframe `M5`).
- Magic `25008001` (kế tiếp dải `2500X001`; PA 25002001, Grid 25004001, DCA 25005001, IR 25006001,
  WW 25007001).
- Kill switch `WONDERWHALES_XAU_2MODE_DEMO_STOP.txt`; state
  `wonderwhales_xau_2mode_demo_state.csv`; telemetry `wonderwhales_xau_2mode_telemetry.csv`.
- Journal chính `wonderwhales_xau_2mode_demo.csv` — **giữ hợp đồng 18 cột**; trường mở rộng ở file telemetry.

## 5. Bằng chứng

Nhãn **`NOT_RUN`** — chỉ có compile.

- Compile `0 errors / 0 warnings` (`scripts/deploy_pineport.ps1 -Apply -Force`, gồm cả `WW2CoreTests`).
- Cổng xanh sau khi đăng ký: `validate-project.py fail=0`, `validate_demo_execution.py fail=0`,
  `check_docs_links.py broken=0`, `pytest` không giảm so với 436.
- **Chưa** chạy Strategy Tester headless cho Scalp/Swing và **chưa** chạy phiên demo chart — xem
  [`../PROGRESS.md`](../PROGRESS.md) cho trạng thái thật. Cổng parity chưa đạt ⇒ mọi entry bị chặn
  (`parity_blocked`); kết quả khi bỏ parity không phải kết quả chiến lược.
- Chạy `Scripts > WW2CoreTests` trên chart demo để kiểm vector thuần logic (kỳ vọng
  `TEST|RESULT|ALL_PASS`).

## 6. Giới hạn / quirk đã biết

- **Parity Pine ↔ MT5 vẫn `BLOCKED`** (chưa có CSV tham chiếu Pine) ⇒ EA chặn entry. Đây là hành vi có chủ
  đích, không phải lỗi.
- Chỉ chạy **một chế độ demo tại một thời điểm**; không chạy đồng thời Scalp + Swing.
- Mode của lệnh được lưu trong state lúc vào; nếu operator đổi `InpTradingMode` khi đang có vị thế, EA vẫn
  quản lý theo mode đã lưu (không theo input mới).
- Halt do `InpMaxDrawdownPct` và kill switch dính tới khi restart (state giữ cờ); halt daily/weekly tự mở
  sang ngày/tuần server mới.
- Min-lot vượt ngân sách → **bỏ qua** (không làm tròn lên).
- `InpSwingRrMin` chỉ có hiệu lực khi `InpTradingMode=SWING`.
- Không dùng file này cho tài khoản real; mọi thay đổi cho phép real cần ADR mới.
