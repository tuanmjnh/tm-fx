# Chuẩn input dùng chung — hợp đồng cho phase C

**Trạng thái:** đặc tả đã duyệt (thiết kế [`../superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md`](../superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md) §9).
**Phạm vi:** bot demo duy nhất `InfiniteRunnerXAUV2DemoEA` (và mọi EA demo thêm sau này). Tài liệu này
**không sửa code** — phase C mới áp dụng; tên input hiện tại nằm ở trang bot
[`infinite-runner.md`](infinite-runner.md) và trong source.

Bảng gap ở mục 5 đọc từ source `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5`; nếu khác thiết kế §9 thì
bảng này thắng.

---

## 1. Sáu nhóm cố định, đúng thứ tự

Mọi EA demo phải khai input theo đúng 6 nhóm dưới đây, **đúng thứ tự này**. Mục đích: mở `input group`
trong source là thấy đủ các lớp an toàn theo thứ tự hình dung được (thi hành → rủi ro → dừng lỗ → nhật
ký → công tắc tắt → chiến lược), và validator tương lai đối chiếu được theo nhóm.

| # | Group | Input bắt buộc |
|---|---|---|
| 1 | `01 Execution` | `InpEnableExecution`, `InpAllowedSymbols`, `InpMagicNumber`, `InpMaxSlippagePoints` |
| 2 | `02 Risk` | `InpRiskPercent`, `InpMaxPositions`, `InpCooldownMinutes`, `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`, `InpMaxSpreadPoints`, `InpHaltOnBreach` |
| 3 | `03 Stops` | SL/TP đặc thù theo loại bot (bảng mục 3) |
| 4 | `04 Journal and state` | `InpEnableLog`, `InpLogFile`, `InpPersistState`, `InpStateFile`, `InpResetStateOnInit`, `InpDebug` |
| 5 | `05 Kill switch` | `InpKillSwitchFile`, `InpCloseOnKillSwitch` |
| 6 | `06 Strategy` | tham số riêng của bot, sub-group theo chủ đề |

Hiện trạng tên nhóm của EA duy nhất (`InfiniteRunnerXAUV2DemoEA`): nhóm đầu là `Demo execution` (gộp cả
kill switch) — chuẩn yêu cầu tách thành `01 Execution` + `05 Kill switch`; EA dùng `Journal and state`,
`Risk`, `Direction`, `Entry control`, `Initial SL`, `Trailing`, `Step Trailing` — các nhóm đặc thù này
thành sub-group con trong `06 Strategy`/`03 Stops` ở phase C.

## 2. Quy tắc đặt tên

- Tiền tố `Inp` + PascalCase; đơn vị nằm trong tên: `...Points`, `...Minutes`, `...Percent`, `...R`.
  Ví dụ đúng: `InpMaxSpreadPoints`, `InpCooldownMinutes`, `InpMaxDailyLossPct`.
  Ví dụ lệch chuẩn đang chạy: `InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts` (IR) —
  thiếu `...Points` đầy đủ; đổi ở phase C.
- Boolean đọc như mệnh đề: `InpEnableX`, `InpCloseOnKillSwitch`, `InpPersistState`, `InpHaltOnBreach`.
- Tên file: `Inp<What>File`.
  - Kill switch: `<BOT>_DEMO_STOP.txt` — IR dùng `INFINITE_RUNNER_DEMO_STOP.txt`.
  - Log/state: `<bot>_demo*.csv` — `infinite_runner_demo.csv`, `infinite_runner_demo_state.csv`.
- Không viết tắt ngoài `SL`, `TP`, `R`, `ATR`, `PSAR`.
- **Tên input trong EA == key trong `configs/demo/*.json`, giữ nguyên tiền tố `Inp`** (validator đối chiếu
  theo đúng tên này; không có lớp dịch tên nào ở giữa). Đổi tên input mà quên đổi key JSON là lỗi phổ
  biến nhất — preset cũ sẽ bị bỏ qua âm thầm.

## 3. SL/TP theo loại bot

Mọi loại bot đều bắt buộc có SL và TP thật; khác nhau ở *cách* đặt:

| Loại | Bot | SL | TP | Input đặc thù |
|---|---|---|---|---|
| `runner_trailing` | IR | cấu trúc hoặc fixed | TP an toàn xa `InpSafetyTpPoints` + trailing | `InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts`, `InpBreakEvenTriggerR` |

Ghi chú:

- Bảng liệt kê **tên đang chạy** (kể cả hậu tố `Pts` của IR — sẽ đổi thành `...Points` ở phase C, xem
  mục 7). Bốn tên trailing của IR ở cột cuối chỉ là 3 input `...Pts` + `InpBreakEvenTriggerR`.
- IR bắt buộc `InpSafetyTpPoints` > 0 (validator ép; default 100000 points — TP "an toàn xa" mà trailing
  mới là cơ chế thoát thật).

## 4. Bất biến kiểm được bằng máy

Cột "hiện tại" cho biết validator (`scripts/validate-project.py`) đã ép hay chưa:

| Bất biến | Hiện tại | Phase C |
|---|---|---|
| `InpEnableExecution` mặc định `true` (ADR 0006) | Đã ép (EA + preset) | Giữ |
| Magic duy nhất: probe 25002002, IR 25006001 | Đã ép | Giữ |
| EA có `InpKillSwitchFile` + `InpCloseOnKillSwitch` | Đã có | Giữ |
| EA có `InpRiskPercent` / `InpMaxPositions` / `InpCooldownMinutes` | Đã có | Giữ |
| Preset JSON đủ key trùng tên input, không thừa/thiếu | Đã ép | Giữ |

## 5. Bảng gap hiện tại → chuẩn

| Vấn đề | Bot đang lệch | Chuẩn |
|---|---|---|
| Tên group | `Demo execution` (gộp kill switch) | `01 Execution` + `05 Kill switch` |
| Tên group | `Direction`, `Entry control`, `Initial SL`, `Trailing`, `Step Trailing` | sub-group trong `06 Strategy`/`03 Stops` |
| Hậu tố đơn vị | `InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts` | Chuẩn hoá về `Points`; phase C đổi tên + cập nhật preset cùng lúc |

## 6. Ánh xạ preset

- Nguồn sự thật: `configs/demo/infinite_runner_demo.json`. File khai `ea`, `execution_mode`, `symbol`,
  `timeframe` và khối `inputs` với key **trùng đúng tên input** trong EA (quy tắc mục 2).
- Dẫn xuất thủ công: `.set` cho Strategy Tester ở [`../20-operations/presets/`](../20-operations/presets/).
  `.set` không bao giờ là nơi khai thay đổi — sửa `.set` mà không sửa JSON là cấu hình rác: lần sinh lại
  sẽ mất.
- **Quy tắc đổi input an toàn:** đổi input trong EA ⇒ phải đổi JSON + `.set` + chạy validator **trong cùng
  một commit**:

  ```powershell
  .\.venv\Scripts\Activate.ps1
  python scripts\validate-project.py     # SUMMARY: checks=N fail=0
  ```

- Preset demo thuộc ADR 0004/0006: chỉ nhắm EA demo, execution bật mặc định. Chi tiết vận hành preset:
  [`../20-operations/presets.md`](../20-operations/presets.md).

## 7. Thứ tự migration phase C

1. **Đổi tên group** về 6 nhóm ở mục 1 (đổi cả thứ tự nhóm), tách kill switch ra `05 Kill switch`.
2. **Đổi `Pts`→`Points` cuối cùng** (`InpTrailStartPts`, `InpTrailDistancePts`, `InpTrailStepPts`) — sửa
   preset JSON + `.set` cùng lúc.
3. **Chạy validator + compile:** `python scripts\validate-project.py` (fail=0) và
   `scripts\build-mql5.ps1` (0 errors, 0 warnings).
4. **Ghi [`../PROGRESS.md`](../PROGRESS.md)** kèm `config_hash` mới nếu preset đổi.

---

*Đọc tiếp: danh mục bot ở [`README.md`](README.md); trang bot ở [`infinite-runner.md`](infinite-runner.md);
trạng thái bằng chứng theo nhãn ở [`../PROGRESS.md`](../PROGRESS.md).*
