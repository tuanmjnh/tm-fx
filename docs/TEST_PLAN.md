# Test plan — Wonderwhales PinePort

- **Ngày:** 2026-10-28
- **Phạm vi:** contract, indicator, EA signal-only và comparator.
- **Nguyên tắc:** compile không thay thế runtime test; unit test không thay thế parity; không tuyên bố PASS
  cho bước chưa chạy.

## 1. Ma trận kiểm thử

| ID | Lớp | Nội dung | Công cụ | Trạng thái |
|---|---|---|---|---|
| T1 | Static | File bắt buộc, buffer 0–17, mode 0–3, 13 input, 36 test ID, không API giao dịch | `scripts/validate_pineport.py` | PASS |
| T2 | Compile | Indicator + contract tests + EA, đọc log UTF-16 | `scripts/build_pineport.ps1` | PASS (0 error/0 warning) |
| T3 | Unit (MQL5) | 36 vector A–E cho dir/flip, mode gate, confirmed gate, cross, missing | `WonderwhalesContractTests.mq5` | **COMPILED_NOT_RUN** |
| T4 | Unit (Python) | Comparator: schema, khóa, tolerance, NaN, filter, warm-up, offset, CLI | `pytest python/tests/test_pine_parity.py` | PASS |
| T5 | Runtime indicator | Gắn indicator lên chart, kiểm tra plot/buffer, không repaint | MT5 thủ công | **NOT_RUN** |
| T6 | Runtime EA | EA đọc `shift=1`, ghi CSV đúng schema, không trùng | MT5 thủ công | **NOT_RUN** |
| T7 | Strategy Tester | Chạy EA trong tester, đọc Journal/Experts | MT5 thủ công | **NOT_RUN** |
| T8 | Parity | So CSV Pine thật với CSV EA | `scripts/compare_pine_exports.py` | **BLOCKED** (thiếu reference) |

## 2. T1 — Static validation

```powershell
.venv\Scripts\python.exe scripts\validate_pineport.py
```

Kỳ vọng: `VALIDATION_OK: pass=... fail=0`, exit 0.

Kiểm tra: contract version, enum buffer/mode, 18 `SetIndexBuffer`, plot 0–2 là `INDICATOR_DATA`,
iBands buffer 0/1/2, EA `iCustom` + `shift=1`, header CSV 14 cột, 13 input, đủ 36 test ID, không
`OrderSend`/`CTrade`/`WebRequest`/`AccountInfo`.

## 3. T2 — Compile

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1
```

Kỳ vọng: cả ba file `0 errors, 0 warnings`, exit 0. Script đọc nội dung log, không tin exit code của
MetaEditor (CLI có thể trả 1 dù log thành công).

Nếu MetaEditor ở đường dẫn khác:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1 `
  -MetaEditorPath "D:\MetaTrader 5\MetaEditor64.exe"
```

## 4. T3 — 36 vector hợp đồng

1. Sync `mt5/Scripts/WonderwhalesContractTests.mq5` và `mt5/Include/PinePort/WonderwhalesContract.mqh`
   vào data folder.
2. Compile (T2).
3. Kéo script vào một chart bất kỳ, chọn OK. Script không đọc dữ liệu thị trường, không giao dịch.
4. Tab **Experts** phải có `TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0`.

Nếu fail: đọc từng dòng `TEST|...|FAIL` để biết ID và giá trị thực. Không sửa test để khớp code nếu
contract đúng.

**Trạng thái hiện tại:** chỉ compile; chưa chạy.

## 5. T4 — Python comparator tests

```powershell
.venv\Scripts\python.exe -m pytest python\tests\test_pine_parity.py -q
```

Kỳ vọng: toàn bộ pass. Test dùng dữ liệu tổng hợp trong thư mục tạm; không phải parity thật.

## 6. T5 — Indicator runtime

1. Sync `mt5/Indicators/PinePort/Wonderwhales.mq5` và include.
2. Compile, mở chart EURUSD M5 (hoặc symbol/timeframe đã chốt).
3. Kéo indicator vào chart; kiểm tra:
   - PSAR line vẽ liên tục sau warm-up.
   - Mũi tên BUY/SELL chỉ xuất hiện ở nến đã đóng.
   - Không có mũi tên nhấp nháy trong nến đang chạy.
4. Mở Data Window, kiểm tra 3 plot có giá trị; buffer chẩn đoán không hiển thị.
5. Đổi mode và input; xác nhận tín hiệu đổi theo mode, không có lỗi journal.
6. Ghi lại build, symbol, timeframe, khoảng ngày, mode và ảnh/log.

**Chưa chạy:** không được ghi PASS.

## 7. T6 — EA runtime

1. Sync `PineSignalLabEA.mq5`, include `LabLogger.mqh` và `PinePort/WonderwhalesContract.mqh`.
2. Compile EA; gắn vào cùng chart với indicator.
3. Kiểm tra Journal:
   - `event=init` có `input_hash`.
   - Không có `indicator_create_failed`, `copy_time_failed`, `buffer_copy_failed` lặp vô hạn.
   - Khi có tín hiệu: `event=signal` với `bar_open`, `confirmed_at`, `signal_id`.
4. Kiểm tra `MQL5/Files/pine_signal_log.csv`:
   - Header đúng 14 cột.
   - Mỗi `bar_open_time` chỉ một dòng.
   - `confirmed_at = bar_open_time + timeframe`.
5. Khởi động lại EA; xác nhận không ghi lại bar cuối đã có trong CSV.
6. Không có lệnh nào được gửi; không có truy cập tài khoản.

**Chưa chạy:** không được ghi PASS.

## 8. T7 — Strategy Tester

1. `Ctrl+R`, chọn `PineSignalLabEA`, symbol/timeframe, khoảng ngày.
2. Modeling mode phù hợp; EA không có execution nên kết quả là log tín hiệu, không phải P&L.
3. Đọc Journal/Experts và CSV trong `MQL5/Files` (tester dùng thư mục riêng).
4. Ghi lại build, khoảng ngày, số tín hiệu, lỗi.

**Chưa chạy.** Không dùng kết quả này để tuyên bố lợi nhuận.

## 9. T8 — Parity

Xem [`PINE_PARITY_Wonderwhales.md`](PINE_PARITY_Wonderwhales.md). Cần CSV reference thật từ Pine.
Không tạo CSV giả. Trạng thái hiện tại: `BLOCKED`.

## 10. Tiêu chí dừng

Một thay đổi logic chỉ được merge khi:

- T1 và T2 pass.
- T4 pass.
- Nếu thay đổi chạm logic tín hiệu: cập nhật contract + vector, chạy T3 và ghi kết quả thật.
- Nếu thay đổi chạm CSV/schema: cập nhật comparator + test, chạy T4.
- Không thêm API giao dịch hoặc kết nối broker.
