# Wonderwhales XAU 2-mode — bot demo thứ sáu

**EA demo:** `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` · **magic** `25008001` · **nhãn** `NOT_RUN`
(compile 0/0; tester headless đã chạy cổng parity + đường gửi lệnh; **kết quả chiến lược vẫn `NOT_RUN`** vì
parity chưa đạt và chưa có phiên demo chart). Nguồn yêu cầu:
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
| | `InpPersistState` / `InpStateFile` / `InpResetStateOnInit` / `InpDebug` | `true` / `"wonderwhales_xau_2mode_demo_state.csv"` / `false` / `false` (`true` = bật census chẩn đoán) |
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
- Preset tester dẫn xuất (nguồn sự thật vẫn là JSON): `docs/20-operations/presets/wonderwhales_xau_2mode_scalp.set`
  và `wonderwhales_xau_2mode_swing.set` (đặt `InpTradingMode` + các giá trị riêng theo chế độ).

## 5. Bằng chứng

**Nhãn trạng thái: `NOT_RUN`.** Compile + cổng tĩnh + hai chứng minh hạ tầng (Strategy Tester headless,
`terminal64.exe /config:`) + một census tín hiệu + một ma trận đo management (8 lần chạy); **không** có kết
quả chiến lược hợp lệ vì parity Pine ↔ MT5 chưa đạt và chưa có phiên demo chart. Chi tiết đầy đủ ở
[`../PROGRESS.md`](../PROGRESS.md) §71 (bot), §72 (census) và §73 (measurement harness).

- **Compile** `0 errors / 0 warnings` (`scripts/deploy_pineport.ps1 -Apply -Force`, gồm cả `WW2CoreTests`).
- **Cổng tĩnh xanh:** `validate-project.py checks=15 fail=0`, `validate_demo_execution.py checks=14 fail=0`,
  `check_docs_links.py broken=0 checked=427`, `pytest 452 passed`.
- **Cổng parity chặn entry (chứng minh):** scenario `ww2_scalp_parity_on` (`InpRequireParity=true`) →
  **0 ENTRY**, `52778` dòng `ENTRY_BLOCKED|reason=parity_blocked|parity_not_proven`; SUMMARY
  `trades=0|entries=0|parity=REQUIRED`. Bằng chứng: `reports/build/tester-reports/ww2_scalp_parity_on/`.
- **Đường gửi lệnh + quản lý (Scalp):** scenario `ww2_scalp_demo_exec` (parity off) → **6 ENTRY / 6 EXIT**,
  mọi lệnh có **SL và TP** (TP = 1.5R), volume ≤ `InpMaxExposure` và lỗ ≤ budget, kết thúc bằng HALT
  `max_drawdown_reached|dd=5.00%` đóng vị thế (`RISK_HALT`).
- **Đường gửi lệnh + trailing (Swing):** scenario `ww2_swing_demo_exec` (parity off, lịch sử từ 2018 để có
  W1/D1 EMA200) → **16 ENTRY / 16 EXIT**, **10 TRAIL** (BE ở r≈1.0, structure ở r≥1.3; R luôn từ initial
  SL, ≤ ~1.7), 4 HALT (3 daily loss + 1 drawdown 5.01%).
- **Hai scenario parity-off chỉ là bằng chứng hạ tầng (`NOT_STRATEGY_RESULT`)**, không phải kết quả chiến
  lược: `net=-442.99` (Scalp) và `net=-292.99` (Swing) với risk tester 1% là số của một cấu hình chưa kiểm
  định, **không** phải cam kết hay đánh giá bot.
- **Census tín hiệu (chẩn đoán, không phải kết quả chiến lược):** scenario `ww2_scalp_census` →
  194.869 nến M5 (2024-01-01 → 2026-09-30), **52 tín hiệu** (~19/năm). Chi tiết ở §5.1.
- **Ma trận đo management (chẩn đoán, `NOT_STRATEGY_RESULT`):** 8 run `ww2_meas_scalp_{is,oos}_{a,b,c,d}`
  → trailing/BE không đổi kết cục lệnh nào; nút thắt là entry. Chi tiết ở §5.2.
- Chạy `Scripts > WW2CoreTests` trên chart demo để kiểm vector thuần logic (kỳ vọng
  `TEST|RESULT|ALL_PASS|pass=N fail=0|ww2=1`).

### 5.1 Census tín hiệu Scalp — vì sao rất ít lệnh

`InpDebug=true` bật **census**: mỗi nến chart đã đóng (khi đang flat) EA ghi một dòng vào
`<tên journal>_census.csv` với từng cổng bias/setup/trigger và **lý do** chuỗi AND dừng lại. Census
chạy **độc lập** với đường vào lệnh nên vẫn ghi được cả tín hiệu mà cổng parity hay bộ định cỡ sẽ chặn.
Nó không gửi lệnh, không đụng hợp đồng 18 cột của journal.

Scenario: `ww2_scalp_census` (M5, 2024.01.01 → 2026.10.01, deposit 100.000, parity ON, risk 0,15% —
equity lớn + risk nhỏ để min-lot không che mất tín hiệu). Chạy:

```powershell
.\.venv\Scripts\python.exe scripts\tester\gen_ww2_sets.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario ww2_scalp_census
.\.venv\Scripts\python.exe scripts\tester\analyse_census.py `
    reports\build\tester-reports\ww2_scalp_census\sim_ww2_scalp_census_census.csv
```

Kết quả (194.869 nến, 2,75 năm):

| Cổng | Số nến | % tổng | % của cổng trước |
|---|---|---|---|
| bias (M15 EMA20/50 + EMA200) | 160.310 | 82,27% | — (long 93.640 / short 66.670) |
| setup (M5 PSAR flip **cùng phía** bias) | 4.657 | 2,39% | 2,90% của nến có bias |
| signal (M1 xác nhận) | 52 | 0,03% | 1,12% của nến setup |

Lý do dừng (`reason`, một dòng một lý do):

| reason | Số nến | % |
|---|---|---|
| `no_m5_flip` | 155.653 | 79,88% |
| `no_m15_bias` | 34.559 | 17,73% |
| `no_m1_confirm` | 4.605 | 2,36% |
| `signal` | 52 | 0,03% |

Tín hiệu theo năm: 2024 = 13, 2025 = 23, 2026 = 16. Counter-trend setup (flip ngược bias) bị loại:
734 khi bias long, 643 khi bias short. `setup_pass_without_align=0` xác nhận lớp kiểm tra EMA của EA
không bao giờ mâu thuẫn với indicator.

**Nguyên nhân gốc (có số liệu):** với `InpSignalMode=WW_MODE_SAR_EMA`, indicator đã định nghĩa
`buy = PSAR flip && fast_ema > slow_ema` (`WwApplyMode` trong `WonderwhalesContract.mqh`). Vì vậy
`m5.buy`/`m1.buy` là **sự kiện một nến** (đúng nến flip), không phải trạng thái. Cổng M5 chỉ mở ở
2,90% số nến có bias, và cổng M1 đòi thêm một flip M1 **trên đúng nến M1 vừa đóng trùng nến M5** —
điều này giết 98,88% số nến đã qua M5. Kiểm tra `m5.fast_ema>=m5.slow_ema` trong EA là dư thừa ở mode
này (0 lần nó từ chối một setup đã pass). Nói cách khác: ít lệnh **không** phải do bộ lọc bias quá chặt
(82% nến có bias) mà do **hai cổng sự kiện một nến chồng lên nhau**.

Đây là chẩn đoán, **không** phải bằng chứng lợi nhuận: parity Pine ↔ MT5 vẫn `BLOCKED`, nhãn chiến lược
vẫn `NOT_RUN`, profit `UNPROVEN`.

### 5.2 Measurement harness — đo management trước khi tinh chỉnh

Sau census (§5.1), bước (b) dựng một ma trận đo 8 lần chạy để biết mỗi quy tắc quản lý đóng góp gì, thay
vì chỉ nhìn winrate. Nguyên tắc: **mỗi nhánh đổi đúng một biến**, đo trên cả in-sample lẫn out-of-sample,
và loại cap risk (để một HALT không cắt ngắn mẫu). Chi tiết cách chạy:
[`../20-operations/strategy-tester.md`](../20-operations/strategy-tester.md) §"Measurement harness".

Cấu hình base: `InpExitOnFlip=false`, `InpMaxHoldingBars=0`, BE/trail tắt, các cap risk `0`,
`InpRiskPercent=0.15`, deposit 100.000, **parity OFF**. Nhánh: A = chỉ SL/TP; B = A + BE 1,0R;
C = B + structure trail (arm 1,3R); D = C + PSAR trail.

Kết quả (2026-11-05, `reports/build/tester-reports/ww2_meas_scalp_*`):

| Cửa sổ | Nhánh | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| IS 2024.01.01→2025.06.30 | A/B/C/D | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% |
| OOS 2025.07.01→2026.10.01 | A | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% |
| OOS | B/C/D | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% |

Mọi nhánh `INSUFFICIENT_SAMPLE` (n < 30). Ba điều rút ra:

1. **Mọi exit là −1R hoặc +1,5R** (thêm 3 scratch ở OOS B/C/D). Break-even và structure/PSAR **có bắn**
   (5–10 sự kiện trail, ghi trong telemetry) nhưng **không đổi kết cục lệnh nào** — giá chạm TP hoặc SL
   trước khi stop trail kịp bị chạm. Trailing **không phải** đòn bẩy ở cấu hình này.
2. **BE 1R trung tính ở IS, hơi có hại ở OOS** (−291,23 USD so với A) vì nó kéo 3 lệnh thắng về scratch.
3. **Winrate không phải vấn đề:** TP 1,5R ⇒ winrate hoà vốn 40%; OOS A đúng 40% (expectancy ≈ 0), IS
   28,57% (âm). Nút thắt là **chất lượng entry**, khớp với census §5.1 (hai cổng một-nến chồng nhau).

Chi tiết R: dòng `EXIT` của journal có thêm `|r=%.2f` (hoặc `|r=NA`), tính từ SL ban đầu; hợp đồng 18 cột
không đổi. **Toàn bộ ma trận là `NOT_STRATEGY_RESULT`** (parity OFF, parity chưa chứng minh) — chỉ để xếp
hạng giả thuyết, **không** phải bằng chứng lợi nhuận.

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
- Swing cần **lịch sử W1/D1 dài** để EMA200 của chỉ báo có giá trị (buffer `EMPTY_VALUE` → không vào lệnh);
  scenario tester Swing vì thế bắt đầu từ 2018. Trên chart demo, cần đủ nến W1/D1 trước khi mong có lệnh.
- **Sự cố đã sửa (2026-11-04):** `ReconcilePosition` từng ghi đè SL ban đầu bằng SL broker đã trailing làm R
  nổ (287, 471). Đã tách `current_sl` (SL hiện tại) khỏi `initial_sl` (neo R); thêm test `r_ignores_trailed_stop`.
- **Sửa theo review (2026-11-04):**
  - Kill switch và risk-halt chạy **trước** warm-up guard (trước đây lệnh quản trị khẩn bị bỏ qua khi thiếu
    nến). Kill-switch halt được **giải phóng khi khởi động lại** sau khi operator xoá file (các halt khác vẫn dính).
  - `InpHaltOnBreach=false` giờ có tác dụng: chặn entry nhưng **không** đóng vị thế (vị thế giữ SL/TP broker).
  - Trailing cấu trúc cộng/trừ `InpTrailBufferAtr × ATR` **ngoài** swing đã xác nhận (trước đây đặt đúng trên swing).
  - BE/trailing chỉ arm khi **nến quản lý đóng cùng hướng** với vị thế.
  - Vị thế adopt khi mất state được quản lý **an toàn** (không đoán mode theo Inputs, không suy R từ SL có thể
    đã trailing) — đúng spec §7.3/§12.18.
  - Validator giờ ép token `parity_blocked` (cổng parity không thể bị xoá âm thầm mà cổng tĩnh vẫn xanh).
- Không dùng file này cho tài khoản real; mọi thay đổi cho phép real cần ADR mới.
