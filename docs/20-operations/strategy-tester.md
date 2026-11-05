# Strategy Tester — hướng dẫn và mẫu báo cáo

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `sim-strategy-tester.md`, `SIM_STRATEGY_TESTER_REPORT.md`.

Nội dung:
1. Strategy Tester thủ công cho EA mô phỏng (W8 + W10)
2. Strategy Tester report — <scenario>

---
## Strategy Tester thủ công cho EA mô phỏng (W8 + W10)

**Trạng thái 2026-10-29:** 15/15 scenario đã chạy bằng Strategy Tester headless
(`terminal64.exe /config:…`, model *1 minute OHLC*, `XAUUSDm` M15, 2026.01.05–2026.10.01): 3 `ww_*`,
10 runner/grid/DCA, 2 `plan_*`. Report + CSV thật lưu trong
`reports/build/tester-reports/`. Agent chỉ dùng CLI headless có `ShutdownTerminal=1`, không điều khiển
GUI và không nhập credential.

### 1. Nguyên tắc

- Chỉ chạy trong Strategy Tester của MT5 với EA **simulation-only**. Terminal sẽ hiển thị **0 deal** —
  đó là kết quả đúng, vì EA chỉ tạo vị thế ảo trong bộ nhớ và ghi CSV.
- Không dùng tài khoản live, không nhập mật khẩu/token vào repo, không đăng nhập broker chỉ để tải history.
  Nếu thiếu dữ liệu lịch sử → ghi `BLOCKED`, không thay bằng dữ liệu synthetic trong tester.
- Không kết luận EA đúng chỉ vì compile hoặc vì tester chạy hết. Bằng chứng là CSV + Journal + các
  invariant ở mục 5.
- Logger mở file ở chế độ **append**. Mỗi lần chạy phải dùng `InpLogFile` riêng, ví dụ
  `sim_runner_baseline_20261028.csv`, để không trộn dòng với lần trước.
- Strategy Tester chạy trong sandbox riêng. File CSV thường nằm ở
  `%APPDATA%\MetaQuotes\Terminal\<hash>\Tester\Agent-*\MQL5\Files\` (hoặc thư mục agent tương ứng của bản
  MT5 đang dùng). Không sửa file trong `MQL5\Files` của terminal chính.

### 2. Chuẩn bị (một lần)

1. Mở MT5 EXNESS bằng tài khoản demo/offline mà bạn tự chọn. Không cần đăng nhập trong repo này.
2. Tải history cho symbol sẽ test ở khung thời gian chạy, tối thiểu khoảng ngày sẽ test. Các preset
   Runner/Grid/DCA/Plan viết cho `EURUSD`; preset Wonderwhales ghim `XAUUSDm` qua `InpRequireSymbol`
   (yêu cầu test `XAUUSDm` M15 hoặc M5 kể từ 2026-10-28).
3. Copy source vào Data Folder và compile bằng toolchain của repo:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\*"
   ```
   Script chỉ compile, không mở terminal. Nếu bạn dùng `deploy_pineport.ps1`, chỉ dùng chế độ copy/compile,
   không dùng chế độ chạy terminal.
4. Xác nhận trong MT5 Navigator có `RunnerTrailingLabEA`, `GridLabEA`, `DCALabEA`, `PinePlanSimEA`,
   `WonderwhalesSimEA`, và trong `MQL5\Indicators\PinePort\` có `Wonderwhales` cùng indicator nguồn của
   plan (PA/X2/TM2).

### 3. Thông số chung

| Mục | Giá trị |
|---|---|
| Expert | một trong 5 EA ở trên |
| Symbol | `EURUSD` cho Runner/Grid/DCA/Plan; `XAUUSDm` cho Wonderwhales (hoặc symbol có history thật; ghi rõ) |
| Period | `H1` cho Runner/Grid/DCA/Plan; `M15` hoặc `M5` cho Wonderwhales |
| Model | `Every tick based on real ticks` nếu có, nếu không ghi rõ model đã dùng |
| Deposit | `10000` (chỉ là balance ảo của EA; tester deposit không được EA dùng) |
| Leverage | bất kỳ; EA không dùng margin |
| Date range | ghi rõ từ ngày → ngày, tối thiểu 6 tháng nếu có history |
| Optimization | `Disabled` |
| Visual mode | bật/tắt tùy ý; ghi lại |

### 4. Preset đầu vào

Nhập tay theo bảng dưới (JSON preset là nguồn chuẩn; validator đã kiểm tra các giá trị này). Với scenario
stress/edge, sửa đúng các input trong cột override.

#### 4.1 `RunnerTrailingLabEA` — `configs/sim/runner_trailing.json`

| Input | Giá trị |
|---|---|
| `InpInitialBalance` | 10000.0 |
| `InpVolume` | 1.0 |
| `InpEnableLog` | true |
| `InpLogFile` | sim_runner_log.csv |
| `InpDebug` | false |
| `InpSideFilter` | 0 |
| `InpFastEma` | 20 |
| `InpSlowEma` | 50 |
| `InpAtrPeriod` | 14 |
| `InpAtrSlMultiplier` | 2.0 |
| `InpBreakEvenEnabled` | true |
| `InpBreakEvenTriggerPoints` | 400.0 |
| `InpBreakEvenOffsetPoints` | 0.0 |
| `InpTrailMode` | 1 |
| `InpTrailFixedPoints` | 300.0 |
| `InpTrailAtrMultiplier` | 2.0 |
| `InpMinStopPoints` | 5.0 |
| `InpUpdateOnClosedBarOnly` | true |
| `InpMaxHoldingBars` | 0 |
| `InpCooldownBars` | 1 |
| `InpMaxSpreadPoints` | 50.0 |
| `InpMaxVirtualExposure` | 1.0 |
| `InpMaxDailyLossPct` | 2.0 |
| `InpMaxDrawdownPct` | 5.0 |
| `InpHaltOnBreach` | false |
| `InpCommissionPerVolume` | 0.0 |
| `InpSlippagePoints` | 0.0 |

#### 4.2 `GridLabEA` — `configs/sim/grid_lab.json`

| Input | Giá trị |
|---|---|
| `InpInitialBalance` | 10000.0 |
| `InpEnableLog` | true |
| `InpLogFile` | sim_grid_log.csv |
| `InpDebug` | false |
| `InpGridSide` | 1 |
| `InpSpacingMode` | 0 |
| `InpSpacingPoints` | 300.0 |
| `InpAtrPeriod` | 14 |
| `InpAtrMultiplier` | 1.0 |
| `InpMaxGridLevels` | 5 |
| `InpBaseVirtualVolume` | 0.1 |
| `InpVolumeMultiplier` | 1.5 |
| `InpMaxLevelVolume` | 1.0 |
| `InpExitMode` | 1 |
| `InpLevelTargetPoints` | 300.0 |
| `InpBasketTargetPoints` | 600.0 |
| `InpBasketStopPoints` | 900.0 |
| `InpMaxSpreadPoints` | 50.0 |
| `InpMaxVirtualExposure` | 2.0 |
| `InpMaxDailyLossPct` | 2.0 |
| `InpMaxDrawdownPct` | 5.0 |
| `InpHaltOnBreach` | false |
| `InpCommissionPerVolume` | 0.0 |
| `InpSlippagePoints` | 0.0 |

#### 4.3 `DCALabEA` — `configs/sim/dca_lab.json`

| Input | Giá trị |
|---|---|
| `InpInitialBalance` | 10000.0 |
| `InpEnableLog` | true |
| `InpLogFile` | sim_dca_log.csv |
| `InpDebug` | false |
| `InpDcaSide` | 1 |
| `InpBaseVirtualVolume` | 0.1 |
| `InpTriggerMode` | 0 |
| `InpDcaDistancePoints` | 300.0 |
| `InpBarsBetweenAdds` | 5 |
| `InpMaxDcaAdds` | 3 |
| `InpAddVolumeMultiplier` | 1.5 |
| `InpMaxAddVolume` | 1.0 |
| `InpBasketTargetPoints` | 600.0 |
| `InpBasketStopPoints` | 900.0 |
| `InpMaxSpreadPoints` | 50.0 |
| `InpMaxVirtualExposure` | 2.0 |
| `InpMaxDailyLossPct` | 2.0 |
| `InpMaxDrawdownPct` | 5.0 |
| `InpHaltOnBreach` | false |
| `InpCommissionPerVolume` | 0.0 |
| `InpSlippagePoints` | 0.0 |

#### 4.4 `PinePlanSimEA` — `configs/sim/pine_plan_lab.json`

| Input | Giá trị |
|---|---|
| `InpSource` | 0 (Price Action MTF) |
| `InpInitialBalance` | 10000.0 |
| `InpVolume` | 1.0 |
| `InpEnableLog` | true |
| `InpLogFile` | sim_plan_log.csv |
| `InpDebug` | false |
| `InpSideFilter` | 0 |
| `InpTargetMode` | 0 (TP1) |
| `InpMinStopPoints` | 5.0 |
| `InpMinTargetPoints` | 5.0 |
| `InpMaxHoldingBars` | 0 |
| `InpBreakEvenEnabled` | false |
| `InpBreakEvenTriggerPoints` | 400.0 |
| `InpBreakEvenOffsetPoints` | 0.0 |
| `InpTrailEnabled` | false |
| `InpTrailFixedPoints` | 300.0 |
| `InpMinStopPointsTrail` | 5.0 |
| `InpCooldownBars` | 1 |
| `InpMaxSpreadPoints` | 50.0 |
| `InpMaxVirtualExposure` | 1.0 |
| `InpMaxDailyLossPct` | 2.0 |
| `InpMaxDrawdownPct` | 5.0 |
| `InpHaltOnBreach` | false |
| `InpCommissionPerVolume` | 0.0 |
| `InpSlippagePoints` | 0.0 |

EA cần indicator nguồn (`PriceActionMTF`, `TMXAUSignals2` hoặc `TMIndicator2`) đã cài trong
`MQL5\Indicators\PinePort\`. Chạy `SimPlanTests` trước; kỳ vọng `pass=39 fail=0|suite=sim_plan`.

#### 4.5 `WonderwhalesSimEA` — `configs/sim/wonderwhales_xauusdm.json`

| Input | Giá trị |
|---|---|
| `InpInitialBalance` | 10000.0 |
| `InpVolume` | 0.1 |
| `InpEnableLog` | true |
| `InpLogFile` | sim_wonderwhales_xauusdm.csv |
| `InpDebug` | false |
| `InpRequireSymbol` | XAUUSDm |
| `InpMode` | 0 (SAR) |
| `InpPsarStart` / `InpPsarInc` / `InpPsarMax` | 0.02 / 0.02 / 0.2 |
| `InpFastEma` / `InpSlowEma` / `InpEma200` | 20 / 50 / 200 |
| `InpAtrLen` / `InpMinAtrPct` | 14 / 0.5 |
| `InpVolMaLen` / `InpRsiLen` / `InpBbLen` / `InpBbMult` | 20 / 14 / 20 / 2.0 |
| `InpWarmupBars` | 300 |
| `InpSideFilter` | 0 |
| `InpStopMode` | 0 (PSAR) |
| `InpAtrPctMultiplier` / `InpFixedStopPoints` | 2.0 / 3000.0 |
| `InpMinStopPoints` | 150.0 |
| `InpMaxHoldingBars` | 0 |
| `InpExitOnFlip` | true |
| `InpCooldownBars` | 1 |
| `InpMaxSpreadPoints` | 600.0 |
| `InpMaxVirtualExposure` | 0.1 |
| `InpMaxDailyLossPct` / `InpMaxDrawdownPct` | 2.0 / 5.0 |
| `InpHaltOnBreach` | false |
| `InpCommissionPerVolume` / `InpSlippagePoints` | 0.0 / 0.0 |

EA cần indicator `Wonderwhales` đã cài trong `MQL5\Indicators\PinePort\`. `WonderwhalesContractTests` đã
**PASS 36/36** trong Strategy Tester (2026-10-28); tab **Experts** có
`TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0`.

Lưu ý spec thật của `XAUUSDm` trên tài khoản demo Exness: **3 digits, point 0.001, contract size 100**;
spread đo tại 2026.09.01 00:00 là **260 points** (~0.26 USD). Vì vậy mặc định dùng
`InpMaxSpreadPoints=600.0` và `InpFixedStopPoints=3000.0`; cap 200 points cũ chặn toàn bộ tín hiệu.
P&L trong CSV vẫn theo **contract size = 1** của mô hình, không phải tiền broker. Khi chạy headless,
`ExpertParameters` chỉ được nhận file trong `MQL5\Profiles\Tester`; nút **Load** trong GUI đọc
`MQL5\Presets`.

### 5. Ma trận kịch bản

| Scenario | EA | Override so với preset |
|---|---|---|
| `runner_baseline` | RunnerTrailingLabEA | — |
| `runner_conservative_stress` | RunnerTrailingLabEA | `InpVolume=0.5`, `InpMaxVirtualExposure=0.5`, `InpMaxDailyLossPct=1.0`, `InpMaxDrawdownPct=2.0`, `InpMaxSpreadPoints=20.0`, `InpCooldownBars=5` |
| `runner_edge_no_breakeven` | RunnerTrailingLabEA | `InpBreakEvenEnabled=false`, `InpMaxHoldingBars=10` |
| `grid_baseline` | GridLabEA | — |
| `grid_conservative_stress` | GridLabEA | `InpMaxGridLevels=3`, `InpBaseVirtualVolume=0.05`, `InpMaxLevelVolume=0.2`, `InpMaxVirtualExposure=0.4`, `InpMaxSpreadPoints=20.0`, `InpMaxDailyLossPct=1.0`, `InpMaxDrawdownPct=2.0` |
| `grid_edge_single_level` | GridLabEA | `InpMaxGridLevels=1` |
| `dca_baseline` | DCALabEA | — |
| `dca_conservative_stress` | DCALabEA | `InpMaxDcaAdds=2`, `InpBaseVirtualVolume=0.05`, `InpAddVolumeMultiplier=1.2`, `InpMaxAddVolume=0.1`, `InpMaxVirtualExposure=0.3`, `InpBasketTargetPoints=300.0`, `InpBasketStopPoints=400.0`, `InpMaxSpreadPoints=20.0`, `InpMaxDailyLossPct=1.0`, `InpMaxDrawdownPct=2.0` |
| `dca_edge_no_adds` | DCALabEA | `InpMaxDcaAdds=0` |
| `dca_edge_bar_trigger` | DCALabEA | `InpTriggerMode=1`, `InpBarsBetweenAdds=10` |
| `plan_baseline` | PinePlanSimEA | — (nguồn PA, TP1, filter hai chiều) |
| `plan_edge_tp3_stop_only` | PinePlanSimEA | `InpTargetMode=1`, `InpMinStopPoints=20.0`, `InpMinTargetPoints=20.0`, `InpMaxSpreadPoints=20.0` |
| `ww_baseline` | WonderwhalesSimEA | — (XAUUSDm, PSAR stop, exit on flip) |
| `ww_conservative_stress` | WonderwhalesSimEA | `InpVolume=0.05`, `InpMaxVirtualExposure=0.05`, `InpMaxSpreadPoints=400.0`, `InpMaxDailyLossPct=1.0`, `InpMaxDrawdownPct=2.0`, `InpCooldownBars=5`, `InpMinStopPoints=200.0` |
| `ww_edge_atr_stop` | WonderwhalesSimEA | `InpStopMode=1`, `InpAtrPctMultiplier=3.0`, `InpExitOnFlip=false`, `InpMaxHoldingBars=16` |

Tổng cộng 15 scenario. `config_hash` khác nhau giữa các override là bình thường; mỗi report phải ghi
đúng preset + override đã dùng.

### 6. Invariant phải kiểm từ CSV (không chỉ nhìn equity)

| EA | Kiểm tra |
|---|---|
| Runner | SL long không giảm, short không tăng; breakeven chỉ kích hoạt sau ngưỡng; trailing không nới stop; stop bị gap ghi slippage bất lợi; tối đa 1 vị thế ảo; cooldown chặn entry mới |
| Grid | Số tầng ≤ `InpMaxGridLevels`; tổng volume ≤ `InpMaxVirtualExposure`; mỗi tầng đúng giá spacing; volume mỗi tầng ≤ `InpMaxLevelVolume`; basket stop bắt buộc |
| DCA | Số add ≤ `InpMaxDcaAdds`; tối đa 1 fill/bar; volume add = base × multiplier^n, clamp `InpMaxAddVolume`; exposure không vượt cap kể cả khi giá đi một chiều; stop/target tính trên average entry |
| PinePlan | `PLAN_VALID=1` trước mọi entry; SL đúng phía entry; target khớp đúng `TP1/TP3` đã chọn (không credit gap có lợi); SL kiểm trước target; tối đa 1 vị thế ảo; `ref_entry` chỉ là tham chiếu |
| Wonderwhales | Entry chỉ khi buffer buy/sell của bar đã đóng = 1.0; `InpWarmupBars` chặn tín hiệu đầu; SL đúng phía entry và cách fill ≥ `InpMinStopPoints` (nếu không → `STOP_REJECTED`, không vào lệnh); SL kiểm trước exit-on-flip; tối đa 1 vị thế ảo; cooldown chặn entry mới |
| Cả 5 | `SUMMARY` chỉ xuất hiện một lần; equity/drawdown khớp cột log; không có dòng `BLOCKED/HALTED` trái kỳ vọng; daily loss/drawdown dừng đúng ngưỡng |

### 7. Cách ghi report

Copy mục **“Strategy Tester report — <scenario>”** cuối tài liệu này thành
`reports/strategy-tester/<scenario>-<ngày>.md`, điền số liệu thật, đính kèm đường dẫn CSV và ảnh chụp
Results/Journal nếu cần. Không sửa mẫu gốc trong tài liệu.

Một scenario chỉ được đánh `PASS` khi:

1. Tester chạy hết khoảng ngày đã chọn, không có lỗi runtime trong Journal.
2. CSV tồn tại, có header đúng 18 cột, có ít nhất một entry và một exit.
3. Mọi invariant ở mục 6 đúng.
4. Các thông số tester (symbol, period, model, range, build, deposit) được ghi lại.

Nếu thiếu history, tester lỗi, hoặc CSV rỗng → `BLOCKED`/`FAIL`, không suy diễn từ kết quả compile.

### 8. Trạng thái hiện tại

| Hạng mục | Trạng thái |
|---|---|
| Hướng dẫn + template | PASS (tài liệu này) |
| `ww_baseline`, `ww_conservative_stress`, `ww_edge_atr_stop` | PASS — 3/3 report + CSV thật (2026-10-28), xem mục 9 |
| `runner_*` (3) | PASS — 3/3 report + CSV thật, xem mục 9.1 |
| `grid_*` (3) | PASS — 3/3 report + CSV thật, xem mục 9.1 |
| `dca_*` (4) | PASS — 4/4 report + CSV thật, xem mục 9.1 |
| `plan_baseline`, `plan_edge_tp3_stop_only` | PASS (0 trade, đúng thiết kế) — hết `BLOCKED_PERFORMANCE` sau khi tối ưu replay; xem mục 9.2 |
| `plan_rr2` | PASS — 93 trade ảo, CSV nhất quán, `halted=HALTED` vì drawdown 5.02 %; xem mục 9.3 |
| 6 contract test indicator | PASS — 6/6 suite, 547 check, xem [`../reference/simulation.md`](../30-research/simulation.md) |
| Kết luận hiệu năng | Không có; mọi số liệu phải đến từ report thật, không suy ra lợi nhuận |

### 9. Kết quả thật — WonderwhalesSimEA (2026-10-28)

Môi trường: `terminal64.exe /config:…` headless, model *1 minute OHLC*, `XAUUSDm` M15,
2026.01.05–2026.10.01, deposit 10 000 USD, leverage 1:100, build 6249, demo `464140826`
(Exness-MT5Trial17; file cấu hình không chứa credential). Report HTML có **0 deal** — đúng thiết kế
simulation-only; số liệu dưới đây lấy từ CSV 18 cột.

| Scenario | `config_hash` | Trades | Win / Loss | Net (model units) | Max DD | Blocks |
|---|---|---:|---:|---:|---:|---:|
| `ww_baseline` | `6E969FE1` | 869 | 318 / 551 | +26.97 | 0.85% | 0 |
| `ww_conservative_stress` | `69086031` | 787 | 276 / 511 | −7.50 | 0.46% | 139 (134 cooldown, 5 spread) |
| `ww_edge_atr_stop` | `C9EABF3B` | 795 | 390 / 405 | +24.96 | 0.88% | 0 |

Kiểm tra CSV: `config_hash` đồng nhất toàn file, SL luôn đúng phía entry, entry/exit khớp (baseline và
stress còn một vị thế ảo mở ở bar cuối). Net là **đơn vị mô hình** (contract size 1, không commission,
không swap, không margin); không phải lợi nhuận và không suy ra được lot hay P&L broker.
File: `reports/build/tester-reports/<scenario>/sim_ww_<scenario>.csv` và `tester_ww_<scenario>.htm`.

### 9.1 Kết quả thật — Runner / Grid / DCA (2026-10-28)

Cùng môi trường mục 9. Spread cap đã hiệu chỉnh theo spread đo được (~260 point): preset nền `600`,
scenario stress/edge `400`; lý do ở [`../PROGRESS.md`](../PROGRESS.md) §41. `Net` là **đơn vị mô hình**,
không phải lợi nhuận.

| Scenario | Trades / entries | Win / Loss | Net | Max DD | Blocks | Trạng thái RiskGuard |
|---|---:|---:|---:|---:|---:|---|
| `runner_baseline` | 54 | 5 / 49 | −467.63 | 5.09% | 279 | HALTED |
| `runner_conservative_stress` | 36 | 3 / 33 | −192.06 | 2.19% | 301 | HALTED |
| `runner_edge_no_breakeven` | 70 | 27 / 43 | −464.69 | 5.12% | 263 | HALTED |
| `grid_baseline` | 24 052 levels / 17 581 basket | — | +1 355.49 | 1.13% | 12 | ACTIVE |
| `grid_conservative_stress` | 22 916 / 17 513 | — | +422.91 | 0.29% | 80 | ACTIVE |
| `grid_edge_single_level` | 11 018 / 11 018 | — | −496.85 | 5.00% | 6 575 | HALTED |
| `dca_baseline` | 11 012 entry (+2 adds) | — | −497.06 | 5.00% | 6 581 | HALTED |
| `dca_conservative_stress` | 6 098 | — | −200.06 | 2.00% | 11 497 | HALTED |
| `dca_edge_no_adds` | 11 018 | — | −496.85 | 5.00% | 6 575 | HALTED |
| `dca_edge_bar_trigger` | 11 018 | — | −496.85 | 5.00% | 6 575 | HALTED |

Ghi chú trung thực:

- `HALTED` là RiskGuard dừng EA khi chạm ngưỡng drawdown/daily loss; không phải lỗi tester và không
  phải tín hiệu hiệu năng.
- `DCALabEA` in `adds=0` trong `SUMMARY` do bộ đếm bị reset khi đóng basket; CSV chứng minh có add
  (`dca_baseline`: volume 0.15 và 0.225 ngoài base 0.10). Đây là lỗi báo cáo đã biết, chưa sửa.
- `grid_edge_single_level` chỉ mở một level/basket nên trùng số với DCA — đúng cấu hình edge.
- File: `reports/build/tester-reports/<scenario>/` (CSV 18 cột + `tester_<scenario>.htm`).

### 9.2 `plan_*` — PASS với 0 trade (2026-10-29)

**Trước:** full kỳ 2026.01.05–2026.10.01 không hoàn tất sau ~13 phút; `metatester64` tính lại
PriceActionMTF với chi phí gần bậc hai theo số bar. Diagnostic 1 tháng mất 197 s.

**Sau khi tối ưu** (replay tăng dần + binary search HTF + cache HTF append-only; chi tiết và bảng đo
ở [`../indicators/price-action-mtf.md`](../30-research/indicators/price-action-mtf.md) §7.3):

| Scenario | Wall time | `config_hash` | SUMMARY |
|---|---:|---|---|
| `plan_baseline` | 389.9 s | `A529A48A` | `entries=0\|rejected=0\|trades=0\|net=0.00\|max_dd=0.0000\|blocks=0\|halted=ACTIVE` |
| `plan_edge_tp3_stop_only` | 409.8 s | `7DA9E7C9` | giống hệt `plan_baseline` |

Cả hai chạy đủ 9 tháng (`SUMMARY` tại bar `2026.09.30 23:45`), CSV có 2 dòng `INIT` + `SUMMARY`,
không có dòng trade.

**Vì sao 0 trade — không phải lỗi:** source Pine mặc định `pa_rr1 = 1.0` và `pa_rrMin = 1.5`, nên
`rrOk = (rr1 >= rrMin)` luôn false → `plan.valid = false` → không bao giờ có signal. Đây là quirk
của source được port nguyên (decision P9, xem
[`../indicators/price-action-mtf.md`](../30-research/indicators/price-action-mtf.md) §9). Chẩn đoán runtime
2026-10-29 trên `diag_plan_1m` (1 tháng, 25 715 nến) xác nhận: 25 714 nến `plan_valid=0`, trong khi
`dir_up=15 763`, `dir_dn=9 950`, `atr_ok=25 701`, `sl_ok=25 700`, `score=14..87` — mọi gate khác đều
đạt, chỉ `rrOk` chặn.

Muốn thấy trade phải đặt `rr1 >= rrMin` (ví dụ `rr1=2.0`) hoặc `rrMin=0`; đó là thay đổi cấu hình,
không phải sửa code. Bằng chứng: `reports/build/tester-reports/plan_baseline/` và
`reports/build/tester-reports/plan_edge_tp3_stop_only/` (CSV + htm + png).

### 9.3 `plan_rr2` — PASS với trade thật (2026-10-29)

Cùng EA và kỳ như mục 9.2, chỉ khác bridge: `InpPaRr1=2.0`, `InpPaRrMin=1.5`
(`reports/build/tester-sets/plan_rr2.set`). `PinePlanSimEA` `config_hash=D6CEF886`, indicator
`hash=E231116A`, `Model=1`, deposit 10 000 USD, leverage 1:100, build 6292, demo
`Exness-MT5Trial17`. Report: History Quality 100%, `Bars: 17595`, `Ticks: 1053473`.
Wall ≈ 336 s (dấu vết file: journal `INIT` 23:17:58.456 → CSV 23:23:34.549).

| Hạng mục | Giá trị |
|---|---|
| SUMMARY | `entries=93\|rejected=0\|trades=93\|wins=26\|losses=67\|flats=0\|net=-333.11\|realized=-333.11\|max_dd=5.0210\|blocks=99\|halted=HALTED` |
| Equity cuối | 9 666.89 (đơn vị mô hình, không phải lợi nhuận) |
| CSV | 287 dòng = 1 `INIT` + 93 `ENTRY` + 93 `EXIT` + 99 `RISK` + 1 `SUMMARY` |
| Lỗi cấu trúc | 0 — một `config_hash` toàn file, 93/93 ENTRY cặp EXIT, không vị thế mở cuối, 0 SL/TP sai phía |
| Hướng lệnh | 93 BUY / 0 SELL — xem [`../PROGRESS.md`](../PROGRESS.md) §58.5 và [`../indicators/price-action-mtf.md`](../30-research/indicators/price-action-mtf.md) §10.5 (quirk `Q11`) |

Chạy lại: `reports/build/tester-run/run_tester.ps1 -Scenario plan_rr2`.
Bằng chứng: `reports/build/tester-reports/plan_rr2/` (`sim_plan_rr2.csv`, `tester_plan_rr2.htm`,
`tester_plan_rr2.png`, `plan_rr2.journal.txt`).

## Bộ chạy tester headless trong repo (`scripts/tester/`)

Từ 2026-11-04, phần "chạy headless" được **track trong repo** để tái lập ở máy khác (trước đây runner chỉ
nằm trong `reports/build/` — gitignored). Đây là nhóm script **duy nhất mở MT5 terminal**; nó chạy trên
**tài khoản ảo của Strategy Tester**, không đăng nhập, không gửi lệnh thật, EA vẫn demo/tester-only
(ADR 0004/0006).

| File | Vai trò |
|---|---|
| [`run_tester.ps1`](../../scripts/tester/run_tester.ps1) | Chạy 1 `<scenario>.ini`, lưu report + mọi CSV `sim_<scenario>*.csv` (journal, census, telemetry) vào `reports/build/tester-reports/<scenario>/` |
| [`gen_ww2_sets.py`](../../scripts/tester/gen_ww2_sets.py) | Sinh `.set` (stage vào `MQL5\Profiles\Tester\`) + `.ini` từ JSON preset (không sửa tay `.set`) |
| [`analyse_census.py`](../../scripts/tester/analyse_census.py) | Đọc `<journal>_census.csv`, in funnel bias → setup → signal + lý do dừng + cross-check |

### Chạy một scenario

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply -Force   # compile EA vào terminal
.venv\Scripts\python.exe scripts\tester\gen_ww2_sets.py                                          # sinh .set/.ini từ JSON
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario ww2_scalp_demo_exec
```

- `run_tester.ps1` tự tìm data folder (`%APPDATA%\MetaQuotes\Terminal\*` có `MQL5\Experts`) và agent Files
  (`%APPDATA%\MetaQuotes\Tester\*\Agent-*\MQL5\Files`); chỉ định bằng `-TerminalDataDir` / `-AgentFilesDir`
  khi cần. Phải **đóng MT5 terminal** trước (script từ chối chạy nếu `terminal64` đang mở).
- `.set` phải nằm trong `MQL5\Profiles\Tester\` — script tự stage nếu có `reports\build\tester-sets\<scenario>.set`.

### Scenario của bot 2-mode (ADR 0009)

| Scenario | Kỳ vọng |
|---|---|
| `ww2_scalp_parity_on` | 0 ENTRY, nhiều `ENTRY_BLOCKED\|reason=parity_blocked` — chứng minh cổng parity |
| `ww2_scalp_demo_exec` | ENTRY/EXIT có SL+TP (TP = `InpTakeProfitR`), HALT theo guard |
| `ww2_swing_demo_exec` | ENTRY/EXIT + TRAIL (BE/structure); từ 2018 để W1/D1 EMA200 đủ history |
| `ww2_scalp_census` | Parity ON + `InpDebug=true`, 100k deposit, risk 0,15% → ghi `_census.csv`, **0 lệnh**; dùng để đếm tín hiệu |
| `ww2_meas_scalp_{is,oos}_{a,b,c,d}` | 8 lần đo management: in-sample 2024.01.01→2025.06.30, out-of-sample 2025.07.01→2026.10.01 × 4 nhánh A–D; parity OFF nên **`NOT_STRATEGY_RESULT`** |
| `ww2_meas_scalp_{is,oos}_gate_{w1,w5}` | 4 lần đo **cổng entry**: `w1` = chỉ cây trigger cuối (đối chứng), `w5` = mọi cây M1 của nến M5; cùng management nhánh A; **`NOT_STRATEGY_RESULT`** |

`.set` tracked (`InpRequireParity=true`) **không** tạo lệnh — đúng thiết kế S2. Muốn xem đường gửi lệnh thì
đặt `InpRequireParity=false`, và đó chỉ là bằng chứng **hạ tầng**, **không** phải kết quả chiến lược.

### Census tín hiệu (chẩn đoán "vì sao ít lệnh")

`InpDebug=true` bật census: mỗi nến chart đã đóng khi EA đang flat, EA ghi một dòng vào
`<tên journal>_census.csv` (suy ra từ `InpLogFile`, ví dụ `sim_ww2_scalp_census_census.csv`) với 15 cột:
`logged_at,bar_time,mode,bias_valid,bias_buy,bias_sell,setup_valid,setup_buy,setup_sell,setup_align,trigger_valid,trigger_buy,trigger_sell,signal,reason`.
`reason` là cổng **đầu tiên** không pass (`bias_invalid`, `no_m15_bias`/`no_w1_bias`, `setup_invalid`,
`no_m5_flip`/`no_d1_align`, `trigger_invalid`, `no_m1_confirm`/`no_h1_trigger`) hoặc `signal`.

Census chạy **song song** với đường vào lệnh (không thay thế, không đổi hành vi), nên nó ghi cả tín hiệu
mà parity/sizing sẽ chặn. Tổng hợp:

```powershell
.venv\Scripts\python.exe scripts\tester\analyse_census.py `
    reports\build\tester-reports\ww2_scalp_census\sim_ww2_scalp_census_census.csv
```

Kết quả Scalp 2024-01-01 → 2026-09-30 (194.869 nến): bias 82,27% → setup 2,90% của bias → signal 1,12%
của setup = **52 tín hiệu** (~19/năm). Nguyên nhân gốc và bảng đầy đủ:
[`../10-bots/wonderwhales-2mode.md`](../10-bots/wonderwhales-2mode.md) §5.1.

Census là **chẩn đoán**, không phải kết quả chiến lược: parity Pine ↔ MT5 vẫn `BLOCKED`.

### Measurement harness — đo trước khi đổi chiến lược

Mục tiêu: biết mỗi quy tắc quản lý (break-even, structure trail, PSAR trail) đóng góp gì vào
expectancy sau chi phí và drawdown, thay vì chỉ nhìn winrate. Nguyên tắc: **mỗi lần chạy đổi đúng một
biến**, và mọi nhánh được đo trên cả in-sample lẫn out-of-sample.

`gen_ww2_sets.py` sinh 8 scenario `ww2_meas_scalp_<window>_<arm>`:

| Cửa sổ | Ngày | Nhánh | Cấu hình thêm |
|---|---|---|---|
| `is` (in-sample) | 2024.01.01 → 2025.06.30 | `a` | base: chỉ SL/TP cố định |
| `oos` (out-of-sample) | 2025.07.01 → 2026.10.01 | `b` | `a` + break-even 1,0R |
| | | `c` | `b` + structure trail (arm ở 1,3R) |
| | | `d` | `c` + PSAR trail (cùng trigger 1,3R) |

Base dùng cho **mọi** nhánh: `InpExitOnFlip=false`, `InpMaxHoldingBars=0`,
`InpBreakEvenTriggerR=1e9`, `InpTrailTriggerR=1e9`, 4 cờ trail `false`, các cap risk `0`
(daily/weekly/drawdown/consecutive/cooldown), `InpMaxExposure=10.0`, `InpRiskPercent=0.15`,
deposit 100.000. Cap tắt để một HALT giữa cửa sổ không cắt ngắn mẫu và làm các nhánh mất tính so
sánh; equity lớn + risk nhỏ để bộ định cỡ min-lot không bỏ tín hiệu. Nhánh C/D tự bật
`InpTrailTriggerR=1.3` (giá trị preset) để candidate thật sự chạy — biến được đo là *candidate trail*,
còn trigger chỉ là điểm arm của nó.

Hai bẫy thật đã gặp khi dựng harness (2026-11-05), cả hai đều *im lặng* nên đã thêm chốt chặn:

| Bẫy | Triệu chứng | Chốt chặn |
|---|---|---|
| `WW2TrailingCoordinator` chỉ xét candidate structure/PSAR khi `r >= InpTrailTriggerR` | "tắt trail" bằng `1e9` làm C/D **không bao giờ chạy**; 3 nhánh giống hệt nhau và ma trận "chứng minh" sai rằng trailing vô dụng | `gen_ww2_sets.py` từ chối arm có cờ trail bật mà trigger tắt; `analyse_measure.py` in `WARNING: identical outcome` |
| `OnInit` từ chối `InpTrailTriggerR < InpBreakEvenTriggerR` (`init_parameters_invalid\|trail_trigger_below_break_even`) | run kết thúc **exit 0 sau ~12 s** với report `Bars 0`, và runner archive lại CSV của lần chạy trước như thể là mới | `gen_ww2_sets.py` từ chối cặp giá trị sai; `run_tester.ps1` fail-closed khi report 0 bar và chỉ xoá archive sau khi đã kiểm tra |

`analyse_measure.py` in `WARNING: identical outcome across N arms` khi nhiều nhánh có cùng
trades/net/win/loss — dấu hiệu một công tắc không hề tác động (dù hợp lệ hay bị vô hiệu).

```powershell
.venv\Scripts\python.exe scripts\tester\gen_ww2_sets.py
foreach ($w in 'is','oos') { foreach ($a in 'a','b','c','d') {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario "ww2_meas_scalp_${w}_${a}" } }
.venv\Scripts\python.exe scripts\tester\analyse_measure.py reports\build\tester-reports
```

`analyse_measure.py` đọc journal 18 cột và in, cho từng nhánh: số lệnh, winrate, net, expectancy tính
bằng **R** và bằng tiền, profit factor, max drawdown lấy từ cột `equity`, phân bố exit-kind, histogram R
và (nếu có file telemetry) tỉ lệ trail theo lý do. Nhánh dưới 30 lệnh bị gắn `INSUFFICIENT_SAMPLE` —
với ~19 tín hiệu/năm thì hai cửa sổ này **được dự đoán là nhỏ**, và một tỉ lệ trên 5 lệnh chỉ là nhiễu.
Nhánh có cùng trades/net/win/loss với nhánh khác bị gắn `WARNING: identical outcome` (dấu hiệu một công
tắc trail bị vô hiệu, xem bẫy ở trên).

R thực hiện được ghi ngay trong journal: dòng `EXIT` có thêm `|r=%.2f` (hoặc `|r=NA` khi không xác
định được anchor), tính bằng `pnl / (|entry − initial_sl| × volume × contract_size)`. Không thêm cột
nào — hợp đồng 18 cột giữ nguyên.

Toàn bộ ma trận chạy với `InpRequireParity=false` (parity Pine ↔ MT5 chưa chứng minh), nên kết quả là
**`NOT_STRATEGY_RESULT`**: dùng để xếp hạng giả thuyết và thiết kế bước (c), **không** phải bằng chứng
lợi nhuận.

#### Kết quả ma trận đo (2026-11-05)

In-sample 2024.01.01 → 2025.06.30 (`_is_`):

| Nhánh | Lệnh | Winrate | Net (USD) | Expectancy (R) | PF | MaxDD | Sự kiện trail |
|---|---:|---:|---:|---:|---:|---:|---|
| A | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | — |
| B | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | BE ×5 |
| C | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | BE ×5, STRUCTURE ×1 |
| D | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | BE ×5, PSAR ×2 |

Out-of-sample 2025.07.01 → 2026.10.01 (`_oos_`):

| Nhánh | Lệnh | Winrate | Net (USD) | Expectancy (R) | PF | MaxDD | Sự kiện trail |
|---|---:|---:|---:|---:|---:|---:|---|
| A | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% | — |
| B | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% | BE ×10 |
| C | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% | BE ×9, STRUCTURE ×1 |
| D | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% | BE ×9, STRUCTURE ×1 |

Mọi nhánh `INSUFFICIENT_SAMPLE` (n < 30). Đọc đúng:

1. **Mọi exit đều là −1R hoặc +1,5R** (thêm 3 scratch ~0R ở OOS B/C/D) — không có exit nào do stop đã
   trail bị chạm. Break-even và structure/PSAR **có bắn** (5–10 sự kiện) nhưng **không đổi kết cục** của
   bất kỳ lệnh nào: giá hoặc chạm TP 1,5R, hoặc quay lại SL 1R, trước khi stop trail kịp bị chạm.
2. **Break-even 1R trung tính ở IS** (5 lần arm đều là lệnh sau đó chạm TP) **và hơi có hại ở OOS**
   (−291,23 USD; −0,09R so với −0,01R của A) vì nó kéo 3 lệnh thắng về scratch ~0R.
3. **Winrate không phải vấn đề.** Với TP 1,5R, winrate hoà vốn là `1/(1+1,5) = 40%`. OOS A đạt đúng
   40% ⇒ expectancy ≈ 0. IS chỉ 28,57% ⇒ âm. Vấn đề nằm ở **chất lượng/lọc entry**, không ở exit.
4. **Mẫu quá nhỏ để tinh chỉnh** (21 và 25 lệnh): chênh lệch ~0,3R không phân biệt được với nhiễu.

⇒ Giả thuyết xếp hạng cho bước (c)/kế tiếp: (1) cổng entry (census §72 cho thấy hai cổng sự kiện một nến
chồng nhau) là nút thắt chính; (2) hình học SL/TP (TP 1,5R đòi winrate 40%) là ràng buộc thứ hai;
(3) trailing **không phải** đòn bẩy. Đây là **giả thuyết**, chưa phải kết luận.

#### Kết quả ma trận cổng entry (2026-11-05)

Ma trận thứ hai chỉ đổi **cửa sổ trigger** (`InpTriggerWindowBars`), giữ management nhánh A:

| Cửa sổ | Nhánh | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD | Sample |
|---|---|---:|---:|---:|---:|---:|---:|---|
| IS | `gate_w1` (đối chứng) | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | `INSUFFICIENT_SAMPLE` |
| IS | `gate_w5` | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% | OK |
| OOS | `gate_w1` (đối chứng) | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% | `INSUFFICIENT_SAMPLE` |
| OOS | `gate_w5` | 298 | 42,62% | +2.601,60 | +0,06 | 1,10 | 2,89% | OK |

`gate_w1` tái lập **chính xác** nhánh A ở cả hai cửa sổ — harness tự chứng minh mặc định `1` không đổi hành
vi. `gate_w5` tăng số lệnh ~13× và cải thiện expectancy ở cả hai cửa sổ, nhưng IS vẫn âm nên đây **không**
phải bằng chứng lợi nhuận. Chi tiết: bot page §5.4.

### Dữ liệu ở đâu

- **Giá (market data)**: terminal broker tải về (symbol `XAUUSDm`) — **không** nằm trong repo; đổi máy/broker
  thì phải để MT5 tải history (Symbols → Bars/Ticks → Request).
- **Report + CSV**: `reports/build/tester-reports/<scenario>/` (gitignored → chỉ có trên máy chạy; xem
  [`evidence.md`](evidence.md)).
- **Cấu hình**: `configs/demo/*.json` (nguồn sự thật) + `.set` track trong [`presets/`](presets/).

### Phương án GUI (không cần script)

MT5 → **Ctrl+R** → Expert + Symbol + Period + Model **1 minute OHLC** + khoảng ngày → tab **Inputs** bấm
**Load** chọn `.set` trong `docs/20-operations/presets/` → Start. Report ở tab Results/Graph; journal CSV ở
`MQL5\Files` (chart demo) hoặc `MQL5\Files` của tester agent (khi chạy tester).

## Strategy Tester report — <scenario>

> Copy file này vào `reports/strategy-tester/<scenario>-<YYYYMMDD>.md` và điền số liệu thật. Không điền
> giá trị ước lượng hoặc từ lần chạy khác.

### 1. Nhận dạng lần chạy

| Trường | Giá trị |
|---|---|
| Scenario | |
| EA | |
| EA version | |
| Preset / config hash | `configs/sim/<file>.json`; snapshot `reports/config-snapshots/<...>.json` |
| Ngày chạy (local) | |
| Người chạy | |
| MT5 build | |
| Symbol | |
| Period | |
| Model | |
| Date range | |
| Deposit | |
| Spread setting | |
| Visual mode | |
| `InpLogFile` | |

### 2. Override so với preset

| Input | Preset | Đã dùng |
|---|---|---|
| | | |

### 3. Kết quả tester (Results tab)

| Metric | Giá trị |
|---|---|
| Total net profit | |
| Gross profit | |
| Gross loss | |
| Profit factor | |
| Expected payoff | |
| Absolute drawdown | |
| Maximal drawdown | |
| Relative drawdown | |
| Total trades / deals | 0 (kỳ vọng; EA simulation-only) |
| Bars / ticks processed | |
| Journal errors | |

### 4. Bằng chứng CSV

| Trường | Giá trị |
|---|---|
| Đường dẫn CSV | |
| Số dòng dữ liệu (không tính header) | |
| Header đúng 18 cột | |
| Entry đầu tiên | |
| Exit cuối cùng | |
| Dòng `SUMMARY` | |
| Số dòng `BLOCKED` / `HALTED` | |

### 5. Invariant

| # | Kiểm tra | Kết quả | Ghi chú |
|---|---|---|---|
| 1 | Giới hạn vị thế/tầng/add không bị vượt | | |
| 2 | Exposure không vượt cap | | |
| 3 | Stop không bị nới | | |
| 4 | Slippage/slippage gap ghi bất lợi | | |
| 5 | Một fill mỗi bar (nếu áp dụng) | | |
| 6 | Daily loss/drawdown dừng đúng ngưỡng | | |
| 7 | Equity/drawdown trong CSV khớp tính tay trên mẫu | | |
| 8 | Không có lệnh thật (0 deal) | | |

### 6. Kết luận

- Verdict: `PASS` / `FAIL` / `BLOCKED`
- Lý do:
- Việc cần làm tiếp:

### 7. Đính kèm

- [ ] CSV log
- [ ] Ảnh Results
- [ ] Ảnh Journal
- [ ] Snapshot config
