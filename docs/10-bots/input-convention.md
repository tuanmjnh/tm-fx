# Chuẩn input dùng chung — hợp đồng cho phase C

**Trạng thái:** đặc tả đã duyệt (thiết kế [`../superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md`](../superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md) §9).
**Phạm vi:** 5 EA demo (`PATrendRiderXAUv1DemoEA`, `GridDemoEA`, `DCADemoEA`, `InfiniteRunnerXAUV2DemoEA`,
`WonderwhalesDemoEA`). Tài liệu này **không sửa code** — phase C mới áp dụng; mọi thứ trình bày ở đây là
đích tới, còn tên input hiện tại của từng EA nằm ở 5 trang bot.
**Hiện trạng từng EA** (bảng input tên thật + cột `Tên chuẩn (phase C)`): [`pa-trendrider.md`](pa-trendrider.md) ·
[`grid.md`](grid.md) · [`dca.md`](dca.md) · [`infinite-runner.md`](infinite-runner.md) · [`wonderwhales.md`](wonderwhales.md).
Bảng gap ở mục 5 đã kiểm bằng `Select-String` trên 5 file `mt5/Experts/*DemoEA.mq5` ngày 2026-11-03;
nếu khác thiết kế §9 thì bảng này thắng.

---

## 1. Sáu nhóm cố định, đúng thứ tự

Mọi EA demo phải khai input theo đúng 6 nhóm dưới đây, **đúng thứ tự này**. Mục đích: mở `input group`
trong source là thấy đủ các lớp an toàn theo thứ tự hình dung được (thi hành → rủi ro → dừng lỗ → nhật
ký → công tắc tắt → chiến lược), và validator tương lai đối chiếu được theo nhóm.

| # | Group | Input bắt buộc |
|---|---|---|
| 1 | `01 Execution` | `InpEnableExecution`, `InpAllowedSymbols`, `InpMagicNumber`, `InpMaxSlippagePoints` |
| 2 | `02 Risk` | `InpRiskPercent`, `InpMaxPositions`, `InpCooldownMinutes`, `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`, `InpMaxSpreadPoints`, `InpMaxExposure`, `InpHaltOnBreach` |
| 3 | `03 Stops` | SL/TP đặc thù theo loại bot (bảng mục 3) |
| 4 | `04 Journal and state` | `InpEnableLog`, `InpLogFile`, `InpPersistState`, `InpStateFile`, `InpResetStateOnInit`, `InpDebug` |
| 5 | `05 Kill switch` | `InpKillSwitchFile`, `InpCloseOnKillSwitch` |
| 6 | `06 Strategy` | tham số riêng của bot, sub-group theo chủ đề |

Hiện trạng tên nhóm (đã quét `input group` trên 5 EA ngày 2026-11-03):

- Cả 5 EA đều đặt nhóm đầu là `Demo execution` và nhét kill switch vào trong đó — chuẩn yêu cầu tách
  thành `01 Execution` + `05 Kill switch`.
- Grid/DCA dùng `Journal` (chuẩn: `04 Journal and state`), `RiskGuard` (chuẩn: `02 Risk`), `Exit`
  (chuẩn: `03 Stops` + `06 Strategy`).
- PA/IR/WW dùng `Journal and state` + `Risk` (đúng tên nhưng sai vị trí/thứ tự). Riêng PA thêm
  `Timeframes`, `Structure`, `Stops`, `Volatility and spread`; IR thêm `Direction`, `Entry control`,
  `Initial SL`, `Trailing`, `Step Trailing`; WW thêm `Wonderwhales signal`, `Stops and target` —
  các nhóm đặc thù này thành sub-group/sub-topic trong `06 Strategy`/`03 Stops` ở phase C.

## 2. Quy tắc đặt tên

- Tiền tố `Inp` + PascalCase; đơn vị nằm trong tên: `...Points`, `...Minutes`, `...Percent`, `...R`.
  Ví dụ đúng: `InpMaxSpreadPoints`, `InpCooldownMinutes`, `InpMaxDailyLossPct`, `InpTakeProfitR`.
  Ví dụ lệch chuẩn đang chạy: `InpTrailStartPts` (IR) — thiếu `...Points` đầy đủ; đổi ở phase C.
- Boolean đọc như mệnh đề: `InpEnableX`, `InpCloseOnKillSwitch`, `InpPersistState`, `InpHaltOnBreach`.
- Tên file: `Inp<What>File`.
  - Kill switch: `<BOT>_DEMO_STOP.txt` — đầy đủ 5 tên đang chạy:
    `PA_TREND_RIDER_DEMO_STOP.txt`, `GRID_DEMO_STOP.txt`, `DCA_DEMO_STOP.txt`,
    `INFINITE_RUNNER_DEMO_STOP.txt`, `WONDERWHALES_DEMO_STOP.txt`.
  - Log/state: `<bot>_demo*.csv` — ví dụ thật: `pa_trendrider_demo.csv`,
    `pa_trendrider_demo_state.csv`, `grid_demo.csv`, `dca_demo.csv`, `infinite_runner_demo.csv`,
    `infinite_runner_demo_state.csv`.
- Không viết tắt ngoài `SL`, `TP`, `R`, `ATR`, `DCA`, `PSAR`.
- **Tên input trong EA == key trong `configs/demo/*.json`, giữ nguyên tiền tố `Inp`** (validator đối chiếu
  theo đúng tên này; không có lớp dịch tên nào ở giữa). Đổi tên input mà quên đổi key JSON là lỗi phổ
  biến nhất — preset cũ sẽ bị bỏ qua âm thầm.

## 3. SL/TP theo 4 loại bot

Mọi loại bot đều bắt buộc có SL và TP thật; khác nhau ở *cách* đặt:

| Loại | Bot | SL | TP | Input đặc thù |
|---|---|---|---|---|
| `single_position` | PA, WW | cấu trúc/ATR | `InpTakeProfitR` (bội số R) | `InpMaxPositions=1` |
| `runner_trailing` | IR | cấu trúc hoặc fixed | TP an toàn xa `InpSafetyTpPoints` + trailing | `InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts`, `InpBreakEvenTriggerR` |
| `bounded_grid` | Grid | mỗi lệnh | basket TP | `InpMaxGridLevels`, `InpSpacingPoints`, `InpBasketTargetPoints`, `InpBasketStopPoints` |
| `bounded_dca` | DCA | mỗi lệnh | basket TP | `InpMaxDcaAdds`, `InpDcaDistancePoints`, `InpBasketTargetPoints`, `InpBasketStopPoints` |

Ghi chú:

- Bảng liệt kê **tên đang chạy** (kể cả hậu tố `Pts` của IR — sẽ đổi thành `...Points` ở phase C, xem
  mục 7). Bốn tên trailing của IR ở cột cuối chỉ là 3 input `...Pts` + `InpBreakEvenTriggerR`.
- Giỏ Grid/DCA **luôn** phải có `InpBasketStopPoints` > 0 (validator ép; default source là 900.0).
- PA và WW đều khẳng định "một vị thế theo magic": PA `InpMaxPositions=1` (validator ép), WW cap một
  vị thế ở cấp source. `InpTakeProfitR` PA = 3.0, WW = 2.0 (đọc từ source, khác preset).
- IR bắt buộc `InpSafetyTpPoints` > 0 (validator ép; default 100000 points — TP "an toàn xa" mà trailing
  mới là cơ chế thoát thật).

## 4. Bất biến kiểm được bằng máy

Cột "hiện tại" cho biết validator (`scripts/validate-project.py`) đã ép hay chưa:

| Bất biến | Hiện tại | Phase C |
|---|---|---|
| `InpEnableExecution` mặc định `true` (ADR 0006) | Đã ép (cả 5 EA + preset) | Giữ |
| Magic duy nhất: probe 25002002, PA 25002001, Grid 25004001, DCA 25005001, IR 25006001, WW 25007001 | Đã ép | Giữ |
| Mọi EA có `InpKillSwitchFile` | Đã có ở cả 5 | Giữ |
| Mọi EA có `InpCloseOnKillSwitch` | **PA thiếu** | Thêm vào PA |
| Mọi EA có `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes` | **Grid/DCA thiếu** | Thêm, hoặc ghi rõ `N/A` có lý do trong trang bot |
| Preset JSON đủ key trùng tên input, không thừa/thiếu | Đã ép một phần | Ép đủ |

Đọc cột "hiện tại" đúng: "Đã ép" nghĩa là `validate-project.py` sẽ fail nếu vi phạm; "PA thiếu"/"Grid/DCA
thiếu" là **gap phase C phải vá**, không phải trạng thái validator hiện tại.

## 5. Bảng gap hiện tại → chuẩn

### 5.1 Ma trận theo input (sự thật chính — đã quét từ source 2026-11-03)

| Input chuẩn | PA | Grid | DCA | IR | WW |
|---|---|---|---|---|---|
| `InpMaxDailyLossPct` | **thiếu** (đang là `InpDailyLossLimitPct`) | có | có | có | có |
| `InpMaxDrawdownPct` | có | có | có | có | có |
| `InpMaxConsecutiveLosses` | có | có | có | có | có |
| `InpMaxSpreadPoints` | có | có | có | có | có |
| `InpMaxExposure` | **thiếu** | có | có | **thiếu** (dùng `InpMaxLots`) | **thiếu** (dùng `InpMaxLots`) |
| `InpMaxPositions` | có | **thiếu** | **thiếu** | có | **thiếu** |
| `InpRiskPercent` | có | **thiếu** | **thiếu** | có | có |
| `InpCooldownMinutes` | có | **thiếu** | **thiếu** | có | có |
| `InpCloseOnKillSwitch` | **thiếu** | có | có | có | có |
| `InpHaltOnBreach` | **thiếu** | có | có | có | có |
| `InpKillSwitchFile` | có | có | có | có | có |

Chỉ 4 dòng `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`, `InpMaxSpreadPoints`, `InpKillSwitchFile` được
xác nhận "có ở cả 5 EA". Mọi dòng khác phải đọc đúng ô của từng cột — không suy ra từ dòng khác.

### 5.2 Lệch tên nhóm và tên input (bảng theo vấn đề)

| Vấn đề | Bot đang lệch | Chuẩn |
|---|---|---|
| Tên group | `Demo execution` (cả 5) | `01 Execution` |
| Tên group | `Journal` (Grid, DCA) vs `Journal and state` (PA, IR, WW) | `04 Journal and state` |
| Tên group | `RiskGuard` (Grid, DCA) vs `Risk` (IR, WW) | `02 Risk` |
| Tên group | `Exit` (Grid, DCA), `Stops and target` (WW) | `03 Stops` + `06 Strategy` |
| Kill switch tách khỏi Execution | Cả 5 EA đặt trong `Demo execution` | `05 Kill switch` |
| `InpCloseOnKillSwitch` | PA không có | Thêm, mặc định `true` |
| `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes` | Grid, DCA không có | Thêm (grid/DCA dùng `InpMaxPositions` = số level tối đa) |
| Tên TP/SL | `InpTakeProfitR` (PA, WW) vs `InpSafetyTpPoints` (IR) vs `InpBasketTargetPoints`/`InpBasketStopPoints` (Grid, DCA) | Giữ, nhưng khai báo theo loại bot ở bảng mục 3 |
| Hậu tố đơn vị | IR dùng `Pts` (`InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts`) trong khi 4 EA kia dùng `Points` | Chuẩn hoá về `Points`; phase C đổi tên + cập nhật preset cùng lúc |
| `InpMaxDailyLossPct` | PA đang là `InpDailyLossLimitPct` | Đổi tên ở phase C |
| `InpMaxExposure` | IR và WW dùng `InpMaxLots` | Phase C thay bằng `InpMaxExposure` |

### 5.3 Ghi chú bắt buộc

- `InpMaxLots` (IR, WW) không nằm trong chuẩn → phase C thay bằng `InpMaxExposure`.
- PA đổi `InpDailyLossLimitPct` → `InpMaxDailyLossPct`.
- Grid/DCA thêm `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes`.
- PA thêm `InpCloseOnKillSwitch` + `InpHaltOnBreach`.

## 6. Ánh xạ preset

- Nguồn sự thật: `configs/demo/*.json` — 5 file
  (`pa_trendrider_xau_demo.json`, `grid_demo.json`, `dca_demo.json`, `infinite_runner_demo.json`,
  `wonderwhales_demo.json`). Mỗi file khai `ea`, `execution_mode`, `symbol`, `timeframe` và khối
  `inputs` với key **trùng đúng tên input** trong EA (quy tắc mục 2).
- Dẫn xuất thủ công: `.set` cho Strategy Tester ở [`../20-operations/presets/`](../20-operations/presets/)
  (hiện 4 file: `pa_trendrider_xau.set`, `grid_demo.set`, `dca_demo.set`, `infinite_runner_v2.set`;
  WW chưa có file `.set`). `.set` không bao giờ là nơi khai thay đổi — sửa `.set` mà không sửa JSON là
  cấu hình rác: lần sinh lại sẽ mất.
- **Quy tắc đổi input an toàn:** đổi input trong EA ⇒ phải đổi JSON + `.set` + chạy validator **trong cùng
  một commit**:

  ```powershell
  .\.venv\Scripts\Activate.ps1
  python scripts\validate-project.py     # SUMMARY: checks=N fail=0
  ```

- Validator đã ép một phần (`InpEnableExecution=true`, `InpAllowedSymbols` chứa `XAUUSD`,
  `InpMaxSpreadPoints>0`, basket stop Grid/DCA > 0, `InpSafetyTpPoints` IR > 0, `InpMaxPositions=1`
  cho PA/IR, magic đúng ADR); phase C ép đủ "đủ key, không thừa/thiếu".
- Preset demo thuộc ADR 0004/0006: chỉ nhắm 5 EA demo, execution bật mặc định. Chi tiết vận hành preset:
  [`../20-operations/presets.md`](../20-operations/presets.md).

## 7. Thứ tự migration phase C

**Mỗi lần một EA** — không chạm 5 EA trong một commit; mỗi EA là một commit riêng có thể rollback.

Thứ tự trong từng EA:

1. **Thêm input thiếu** theo ma trận mục 5.1 của EA đó (ví dụ PA: `InpCloseOnKillSwitch`,
   `InpHaltOnBreach`; Grid/DCA: `InpRiskPercent`, `InpMaxPositions`, `InpCooldownMinutes`;
   IR/WW: `InpMaxExposure` thay `InpMaxLots`).
2. **Đổi tên group** về 6 nhóm ở mục 1 (đổi cả thứ tự nhóm).
3. **Đổi `Pts`→`Points` cuối cùng** (chỉ IR: `InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts`)
   — vì mỗi lần đổi tên phải sửa preset JSON + `.set` cùng lúc, nên gom vào một bước cuối của EA đó.
4. **Chạy validator + compile:** `python scripts\validate-project.py` (fail=0) và
   `scripts\build-mql5.ps1` (0 errors, 0 warnings).
5. **Ghi [`../PROGRESS.md`](../PROGRESS.md)** — mỗi EA một mục, kèm `config_hash` mới nếu preset đổi.

Đổi tên input = đổi hành vi cấu hình: preset cũ với tên mới sẽ bị bỏ qua âm thầm — đó là lý do buộc
JSON + `.set` + validator đi cùng nhau ở bước 3–4.

### 7.1 Sai lầm thường gặp

| Sai lầm | Hậu quả | Cách tránh |
|---|---|---|
| Đổi tên input trong EA mà quên key trong `configs/demo/*.json` | preset bỏ qua key cũ âm thầm; EA chạy giá trị default | validator + kiểm tra diff JSON trong cùng commit |
| Đổi input mà quên `.set` | Tester chạy cấu hình cũ, report ngược đời | `.set` luôn sinh/đối chiếu từ JSON trước khi chạy |
| Suy "có ở cả 5 EA" từ một dòng gap | bảng gap sai, phase C bỏ sót | đọc từng ô của ma trận mục 5.1 theo EA |
| Nhét kill switch vào `01 Execution` cho tiện | chuẩn `05 Kill switch` vô nghĩa, audit khó | tách nhóm theo mục 1, kể cả khi source chưa tách |
| Đặt giá trị 0 cho ngưỡng halt để "cho bot chạy tiếp" | mất chốt halt (`InpMaxDailyLossPct`, `InpMaxDrawdownPct`) | 0 = tắt kiểm tra là quyết định có chủ đích, phải ghi trong preset description |

---

*Đọc tiếp: danh mục bot ở [`README.md`](README.md); hiện trạng input từng EA ở 5 trang bot (mục đầu
trang này); trạng thái bằng chứng theo nhãn ở [`../PROGRESS.md`](../PROGRESS.md).*
