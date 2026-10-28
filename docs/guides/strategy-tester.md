# Strategy Tester — hướng dẫn và mẫu báo cáo

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `sim-strategy-tester.md`, `SIM_STRATEGY_TESTER_REPORT.md`.

Nội dung:
1. Strategy Tester thủ công cho EA mô phỏng (W8 + W10)
2. Strategy Tester report — <scenario>

---
## Strategy Tester thủ công cho EA mô phỏng (W8 + W10)

**Trạng thái 2026-10-28:** 13/15 scenario đã chạy bằng Strategy Tester headless
(`terminal64.exe /config:…`, model *1 minute OHLC*, `XAUUSDm` M15, 2026.01.05–2026.10.01): 3 `ww_*`,
10 runner/grid/DCA. 2 scenario `plan_*` là `BLOCKED_PERFORMANCE`. Report + CSV thật lưu trong
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
| `plan_baseline`, `plan_edge_tp3_stop_only` | `BLOCKED_PERFORMANCE` — PriceActionMTF quá chậm ở toàn kỳ 9 tháng; diagnostic 1 tháng xong 197 s với 0 entry |
| 6 contract test indicator | PASS — 6/6 suite, 547 check, xem [`../reference/simulation.md`](../reference/simulation.md) |
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

### 9.2 `plan_*` — `BLOCKED_PERFORMANCE`

Full kỳ 2026.01.05–2026.10.01 không hoàn tất sau ~13 phút; `metatester64` tính lại PriceActionMTF với
chi phí tăng gần bậc hai theo số bar. Diagnostic rút còn 2026.01.05–2026.02.04: xong 197 s,
`entries=0 rejected=0 trades=0` — chưa đủ để kết luận gì về logic plan. Không có report cho
`plan_baseline` (chỉ CSV `INIT`) và `plan_edge_tp3_stop_only`. Muốn chạy được phải tối ưu cache
indicator trước; không ghi đè trạng thái này bằng suy luận.

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
