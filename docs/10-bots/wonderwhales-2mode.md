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
| | `InpTriggerWindowBars` | `1` (`1` = chỉ cây trigger cuối, hành vi gốc; `5` = mọi cây M1 của nến M5) |
| | `InpSetupWindowBars` | `1` (`1` = chỉ nến setup cuối, hành vi gốc; `5` = flip trong 5 nến setup gần nhất) |
| | `InpScalpRequireSarAgree` | `false` (bật = đòi hướng PSAR của khung setup **còn** đồng ý lúc trigger; chỉ chặn khi `InpSetupWindowBars>1`) |
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
[`../PROGRESS.md`](../PROGRESS.md) §71 (bot), §72 (census), §73 (measurement harness), §74 (parity runbook)
và §75–§79 (sửa cổng entry → bộ lọc chất lượng). **Báo cáo tổng hợp một mạch (a→h):**
[`../30-research/wonderwhales-scalp-study.md`](../30-research/wonderwhales-scalp-study.md).

- **Compile** `0 errors / 0 warnings` (`scripts/deploy_pineport.ps1 -Apply -Force`, gồm cả `WW2CoreTests`).
- **Cổng tĩnh xanh:** `validate-project.py checks=15 fail=0`, `validate_demo_execution.py checks=14 fail=0`,
  `check_docs_links.py broken=0 checked=430`, `pytest 452 passed`.
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
- **Cổng parity (bước c):** comparator `compare_pine_exports.py` (+ `pine_parity.py`, 25 test) đã sẵn sàng;
  thêm exit code `3` = `parity=BLOCKED` để tách "thiếu reference" khỏi lỗi schema. Chưa có CSV Pine
  ⇒ `BLOCKED`. Runbook ở §5.3.
- **Sửa cổng entry (task D, chẩn đoán `NOT_STRATEGY_RESULT`):** `InpTriggerWindowBars` (mặc định `1` =
  hành vi gốc) — `w5` tăng số lệnh ~13× và cải thiện expectancy ở cả IS lẫn OOS; OOS +0,06R/PF 1,10 nhưng
  IS vẫn âm. Chi tiết và bảng số ở §5.4.
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

### 5.3 Parity Pine ↔ MT5 — runbook (bước (c))

**Trạng thái: `BLOCKED`** — comparator **đã có sẵn** và đã test, chỉ thiếu **CSV reference thật do Pine
xuất**. Đây là thứ duy nhất còn giữ `InpRequireParity=true` (chặn mọi entry, `reason=parity_blocked`).
Không tạo CSV giả. Công cụ: [`scripts/compare_pine_exports.py`](../../scripts/compare_pine_exports.py) +
[`pine_parity.py`](../../python/src/mt5_ea_ai_lab/evaluation/pine_parity.py); schema và luật so ở
[`../30-research/indicators/parity.md`](../30-research/indicators/parity.md).

Bộ input phải **khoá giống hệt ở cả hai phía**:

| Input | Giá trị |
|---|---|
| Signal mode | `SAR_EMA` (`InpSignalMode=WW_MODE_SAR_EMA`) |
| PSAR start / inc / max | `0.02` / `0.02` / `0.2` |
| Fast / Slow / EMA200 | `20` / `50` / `200` |
| ATR length / Min ATR % | `14` / `0.5` |
| Vol MA / RSI / BB len / BB mult | `20` / `14` / `20` / `2.0` |
| Warm-up | `300` bar |
| Confirm on bar close | `true` (bản port chỉ hỗ trợ chế độ này — D16/P3) |
| Symbol / timeframe | `XAUUSDm` / `M5`, chốt một khoảng ngày đủ dài |

Các bước:

1. **Pine (TradingView):** chạy `Wonderwhales.pine` (bản indicator, **không** phải Backtest) trên XAUUSD M5 với
   input khoá ở trên, `Confirm signals on bar close = true`; xuất các dòng tín hiệu ra CSV theo schema
   `bar_open_time,symbol,timeframe,signal_id,side,sar_dir,psar,fast,slow,atr_pct` (UTC). Lưu ở
   `reports/pine_parity/pine_reference.csv`.
2. **MQL5:** attach `Scripts > PineSignalLabEA` trên `XAUUSDm M5` với `InpMode=WW_MODE_SAR_EMA` và cùng
   bộ psar/ema/atr/warmup; EA ghi `MQL5\Files\pine_signal_log.csv`. So trên log của **indicator** (không
   phải journal của EA) để phép so là hàm thuần của chuỗi nến: EA 2-mode đọc chính indicator đó ở `shift=1`,
   nên parity indicator là điều kiện cần cho tín hiệu của EA.
3. **So:**
   ```powershell
   .venv\Scripts\python.exe scripts\compare_pine_exports.py `
     --pine reports\pine_parity\pine_reference.csv `
     --mql5 "$env:APPDATA\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06\MQL5\Files\pine_signal_log.csv" `
     --out-dir reports\pine_parity --mql5-offset-minutes 180 `
     --warmup-bars 300 --bar-times reports\pine_parity\bars.csv
   ```
4. **Luật quyết định:** chỉ khi report có `status=match` **và** `mismatch_count=0` **và** số tín hiệu so
   `≥ 100` mới được đặt `InpRequireParity=false`; lưu JSON report làm bằng chứng. Mọi trường hợp khác giữ
   `true`. Exit code: `0` match, `1` mismatch, `2` lỗi schema/đối số, **`3` = `BLOCKED`** (thiếu file).

> **Bẫy phải xử lý trước khi so:** comparator khớp `symbol` **chính xác**. Broker Exness dùng `XAUUSDm` còn
> TradingView dùng `XAUUSD`, nên nếu để nguyên, *mọi* dòng thành `missing_in_*`. Phải ghi **cùng một chuỗi**
> ở cột `symbol` cả hai file (ví dụ sửa cột `symbol` của export Pine thành `XAUUSDm`) trước khi chạy.

**Không có TradingView Pro?** Có một kiểm tra *khác*, yếu hơn: **cross-implementation** — port spec Pine
sang Python rồi so từng nến với buffer của indicator (`WonderwhalesDumpTesterEA` +
`scripts/compare_wonderwhales_bars.py`). Kết quả 2026-11-06: EMA khớp hoàn toàn nhưng **PSAR lệch ~2,1–2,6%
hướng**, nên port **chưa** được kiểm chứng. Kiểm tra này **không** phải parity và **không** được dùng để gỡ
`InpRequireParity`. Chi tiết: [`../30-research/wonderwhales-scalp-study.md`](../30-research/wonderwhales-scalp-study.md) §11.

### 5.4 Sửa cổng entry — cửa sổ trigger (task D)

Census §5.1 chỉ ra nút thắt: cả ba cổng chỉ đọc `shift=1`, nên cổng M1 đòi **đúng cây M1 cuối cùng**
của nến M5 vừa đóng phải là cây flip — trong 5 cây M1 của nến M5 chỉ cây thứ 5 được xét. Đó là lý do
`no_m1_confirm` giết 98,88% số setup.

Sửa: input mới `InpTriggerWindowBars` (mặc định `1` = hành vi gốc; `5` = quét mọi cây M1 của nến M5).
Hàm `Ww2ReadTriggerWindow()` đọc các cây trigger trong cửa sổ và **lấy cây bắn gần nhất**; nếu không cây
nào bắn thì giữ nguyên trạng thái "không xác nhận" (cổng vẫn chặn). Cổng M1/`Ww2ScalpEvaluate` không đổi —
chỉ nguồn dữ liệu trigger đổi. Validator ép `window ≤ số cây trigger trong một nến setup` (5 cho M5/M1,
24 cho D1/H1).

Đo bằng ma trận sẵn có, **mỗi lượt đổi đúng một biến**, management nhánh A:

| Cửa sổ | Nhánh | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD | Sample |
|---|---|---:|---:|---:|---:|---:|---:|---|
| IS 2024.01.01→2025.06.30 | `gate_w1` (đối chứng) | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | `INSUFFICIENT_SAMPLE` |
| IS | `gate_w5` | **282** | 36,52% | −4.287,54 | **−0,10** | 0,83 | 5,95% | **OK** |
| OOS 2025.07.01→2026.10.01 | `gate_w1` (đối chứng) | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% | `INSUFFICIENT_SAMPLE` |
| OOS | `gate_w5` | **298** | 42,62% | **+2.601,60** | **+0,06** | 1,10 | 2,89% | **OK** |

Ba điều đọc được:

1. **Đối chứng trùng khớp tuyệt đối** với nhánh A (21 lệnh/−988,62 và 25 lệnh/−85,45): mặc định `1` **không
   đổi hành vi**, đúng như thiết kế — harness tự xác nhận điều này.
2. **Số lệnh ×~13** (21→282, 25→298) và **expectancy tốt lên ở cả hai cửa sổ** (−0,32→−0,10 R;
   −0,01→+0,06 R). OOS vượt 0 với PF 1,10; maxDD 2,89%.
3. **Vẫn `NOT_STRATEGY_RESULT`** (parity OFF). OOS dương *không* phải bằng chứng lợi nhuận, và **IS vẫn
   âm** ⇒ chất lượng entry **chưa** được chứng minh; chỉ khẳng định được rằng cửa sổ trigger là nút thắt
   thật và sửa nó cải thiện rõ rệt. Sample giờ đã `OK` nên harness bắt đầu xếp hạng được.

Giả thuyết kế tiếp (chưa làm): IS âm trong khi winrate 36,52% < 40% (winrate hoà vốn của TP 1,5R) ⇒ biến
cần thử tiếp là **cổng setup M5** (cửa sổ M5 / setup dạng trạng thái) hoặc **hình học SL/TP**.

### 5.5 Cửa sổ setup M5 (task E)

Sau khi sửa cửa sổ trigger (§5.4), thử tiếp **cửa sổ setup**: `InpSetupWindowBars` (mặc định `1` = chỉ
nến setup cuối; `5` = flip trong 5 nến setup gần nhất). Đo **một biến**: trigger window giữ nguyên `1`.

| Cấu hình (setup, trigger) | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| `(1, 1)` đối chứng | IS | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% |
| `(1, 1)` đối chứng | OOS | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% |
| `(5, 1)` setup s5 | IS | 235 | 37,45% | −2.734,12 | **−0,08** | 0,87 | 5,26% |
| `(5, 1)` setup s5 | OOS | 238 | 39,92% | −517,91 | **−0,01** | 0,97 | 1,83% |
| `(1, 5)` trigger w5 (§5.4) | IS | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% |
| `(1, 5)` trigger w5 (§5.4) | OOS | 298 | 42,62% | **+2.601,60** | **+0,06** | **1,10** | 2,89% |

Đọc:

1. Đối chứng `s1` **trùng khớp tuyệt đối** với nhánh A (và với `w1`) ⇒ hai mặc định đúng là không đổi hành vi.
2. **Cả hai cửa sổ đều là nút thắt thật.** Mỗi cái một mình tăng số lệnh ~11–13× và gần như cắt đôi
   expectancy âm ở IS (−0,32 → −0,08 / −0,10 R).
3. **Chỉ cửa sổ trigger vượt 0 ở OOS** (+0,06R, PF 1,10). Setup s5 cải thiện IS tốt hơn một chút
   (−0,08R so với −0,10R) nhưng **không** qua được OOS (−0,01R, PF 0,97).
4. Vẫn **`NOT_STRATEGY_RESULT`**: không phải bằng chứng lợi nhuận, IS vẫn âm.

Vì hai cửa sổ tác động khác nhau ở OOS, bước hợp lý kế tiếp là đo **tổ hợp `(5, 5)`** như một biến thêm
vào trên nền `(1, 5)` — chưa làm, chờ quyết định.

### 5.6 Tổ hợp hai cửa sổ (task F)

Đo tổ hợp `(setup 5, trigger 5)` như **một** biến thêm vào trên nền tốt nhất `(1, 5)`. Bảng tiến trình đầy đủ
(management nhánh A, parity OFF):

| Cấu hình (setup, trigger) | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| `(1, 1)` đối chứng | IS | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% |
| `(1, 1)` đối chứng | OOS | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% |
| `(5, 1)` setup | IS | 235 | 37,45% | −2.734,12 | −0,08 | 0,87 | 5,26% |
| `(5, 1)` setup | OOS | 238 | 39,92% | −517,91 | −0,01 | 0,97 | 1,83% |
| `(1, 5)` trigger | IS | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% |
| `(1, 5)` trigger | OOS | 298 | 42,62% | **+2.601,60** | **+0,06** | **1,10** | 2,89% |
| `(5, 5)` tổ hợp | IS | 854 | 41,92% | **+4.207,65** | **+0,03** | 1,06 | 5,46% |
| `(5, 5)` tổ hợp | OOS | 841 | 41,26% | **+2.517,92** | **+0,02** | 1,03 | 3,51% |

Đọc (đây là đánh đổi, **không** phải thắng rõ):

1. Tổ hợp làm **cả hai** cửa sổ dương — lần đầu IS dương — với số lệnh gấp ~3× so với từng cửa sổ riêng.
2. Nhưng **edge trên mỗi lệnh mỏng đi ở OOS**: +0,02R (PF 1,03) so với +0,06R (PF 1,10) của `(1,5)`. Cửa sổ
   setup rộng thêm **nhiều setup chất lượng thấp hơn**: tổng net tương đương ở OOS (2.518 so với 2.602) nhưng
   tốn gấp ~3× số lệnh, và maxDD tăng nhẹ.
3. PF 1,03–1,06 với winrate ~41–42% so với hoà vốn 40% (TP 1,5R) ⇒ edge **rất mỏng**, có thể nằm trong nhiễu
   và chi phí. `(1,5)` vẫn là cấu hình có edge/lệnh tốt nhất.
4. Vẫn **`NOT_STRATEGY_RESULT`** (parity OFF): không phải bằng chứng lợi nhuận.

Bước kế tiếp hợp lý (chưa làm, chờ quyết định): thử **hình học SL/TP** trên nền đã chọn, hoặc dò cửa sổ setup
trung gian (2–4) để tìm điểm edge bắt đầu loãng.

### 5.7 Hình học TP (task G)

Trên nền edge/lệnh tốt nhất `(setup 1, trigger 5)`, đổi **chỉ** `InpTakeProfitR` (SL giữ `1R`). Winrate
hoà vốn tương ứng: `1/(1+TP)` = 50% / 44,4% / 40% / 33,3%.

| TP | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1,0R | IS | 288 | 45,83% | −4.128,60 | −0,10 | 0,82 | 4,89% |
| 1,25R | IS | 284 | 40,49% | −4.401,09 | −0,11 | 0,82 | 5,47% |
| 1,5R (đối chứng) | IS | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% |
| 2,0R | IS | 273 | 30,40% | −4.312,03 | −0,11 | 0,84 | 5,81% |
| 1,0R | OOS | 307 | 48,53% | −1.578,98 | −0,03 | 0,93 | 3,69% |
| 1,25R | OOS | 305 | 44,26% | −601,54 | −0,01 | 0,98 | 3,59% |
| 1,5R (đối chứng) | OOS | 298 | 42,62% | **+2.601,60** | **+0,06** | **1,10** | 2,89% |
| 2,0R | OOS | 287 | 36,59% | **+3.912,31** | **+0,09** | **1,14** | 3,31% |

Đọc — **hai cửa sổ không đồng ý**, nên đây **không** phải bằng chứng chọn TP:

1. Winrate giảm đúng như dự đoán và luôn nằm **trên** winrate hoà vốn tương ứng.
2. **IS: cả bốn mức TP đều âm** (−0,10…−0,11R) với PF ~0,82–0,84 — hình học TP **không** giúp gì ở IS.
3. **OOS: ưu tiên TP lớn** đơn điệu (−0,03 → −0,01 → +0,06 → +0,09R; PF 1,14 ở TP 2,0R).
4. Mâu thuẫn IS/OOS nghĩa là lựa chọn TP **không** được hai cửa sổ cùng xác nhận; TP 2,0R tốt ở OOS có thể là
   đặc điểm chế độ 2025-07→2026-10 chứ không phải edge. Vẫn **`NOT_STRATEGY_RESULT`**.

Kết luận tạm: trong ba đòn bẩy đã đo (trailing, cửa sổ sự kiện, hình học TP), **cửa sổ sự kiện** là cái duy
nhất cải thiện rõ và nhất quán; edge còn lại vẫn mỏng và chưa được hai cửa sổ xác nhận cùng lúc.

### 5.8 Bộ lọc chất lượng SAR (task H)

Vì đổi exit không còn ăn thua, thử đổi **entry**: `InpScalpRequireSarAgree=true` đòi hướng PSAR của khung
setup **còn** đồng ý tại thời điểm trigger, loại bỏ setup mà xu hướng đã đảo ngược sau khi flip. Đo trên nền
`(5,5)` (cấu hình duy nhất dương ở cả hai cửa sổ), **một biến**.

| Cấu hình | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| `q0` tắt lọc (đối chứng) | IS | 854 | 41,92% | +4.207,65 | +0,03 | 1,06 | 5,46% |
| `q1` bật lọc | IS | 848 | 41,75% | +3.594,01 | +0,03 | 1,05 | 5,38% |
| `q0` tắt lọc (đối chứng) | OOS | 841 | 41,26% | +2.517,92 | +0,02 | 1,03 | 3,51% |
| `q1` bật lọc | OOS | 828 | 41,30% | +2.645,45 | +0,03 | 1,04 | 3,80% |

Đọc — bộ lọc này **bị loại**:

1. Đối chứng `q0` trùng khớp tuyệt đối với `combo_c5` (854 và 841 lệnh) ⇒ so sánh sạch.
2. Lọc chỉ bỏ **6 lệnh (IS)** và **13 lệnh (OOS)** ≈ 0,7–1,5% — vì cửa sổ trigger chỉ rộng 1 nến M5, quá ít
   thời gian để SAR M5 đảo ngược sau flip.
3. Tác động **đổi dấu giữa hai cửa sổ** (IS xấu hơn 613 USD, OOS tốt hơn 127 USD) và cùng bậc nhiễu ⇒
   không có tác dụng.

Kết luận: nghi vấn "chất lượng kém do xu hướng đã đảo sau flip" **không đúng**. Bốn đòn bẩy đã đo —
trailing (§5.2), cửa sổ sự kiện (§5.4–5.6), hình học TP (§5.7), bộ lọc chất lượng (§5.8) — chỉ **cửa sổ
sự kiện** cải thiện rõ; edge vẫn chưa được hai cửa sổ xác nhận cùng lúc.

## 6. Giới hạn / quirk đã biết

- **Parity Pine ↔ MT5 vẫn `BLOCKED`** (chưa có CSV tham chiếu Pine) ⇒ EA chặn entry. Đây là hành vi có chủ
  đích, không phải lỗi. Runbook để gỡ và luật quyết định ở §5.3; thiếu file cho exit code `3`
  (`parity=BLOCKED`) nên phân biệt được với lỗi schema.
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
