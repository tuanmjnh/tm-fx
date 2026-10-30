# Báo cáo Phase 2 — Signal engine và chỉ báo

- **Ngày:** 2026-10-27
- **Trạng thái:** `READY_FOR_MANUAL_VALIDATION`
- **Lý do:** code compile 0 errors/0 warnings; expected output đã được tính độc lập bằng Python, nhưng
  self-check script MQL5 **chưa được chạy** trong MT5.

## 1. Tóm tắt

Phase 2 tách tính toán indicator khỏi quyết định tín hiệu:

- `mt5/Include/Indicators.mqh` — SMA/EMA tất định, input chronological, validate giá hữu hạn và `> 0`.
- `mt5/Include/SignalEngine.mqh` — enum signal/reason, config, crossover thuần, engine EMA crossover.
- `mt5/Scripts/LabSignalEngineTests.mq5` — self-check 40+ assertion, in `TEST|PASS/FAIL` ra Experts.
- `mt5/Experts/LabSignalEA.mq5` — dùng engine trên nến đóng, log `event=signal` mỗi nến.
- `docs/reference/strategy-signal-spec.md` — định nghĩa chiến lược, warm-up, reason code, fixture/expected output.

Không có API giao dịch, không đọc tài khoản, không kết nối broker.

## 2. File đã tạo/sửa

| File | Trạng thái | Ghi chú |
|---|---|---|
| `mt5/Include/Indicators.mqh` | Tạo mới | SMA/EMA, seed SMA, fail-closed |
| `mt5/Include/SignalEngine.mqh` | Tạo mới | `LAB_SIGNAL_UNKNOWN/HOLD/BUY/SELL`, reason code |
| `mt5/Scripts/LabSignalEngineTests.mq5` | Tạo mới | Self-check, không giao dịch |
| `mt5/Experts/LabSignalEA.mq5` | Sửa | Thêm input EMA, gọi engine trên nến đóng, log signal |
| `docs/reference/strategy-signal-spec.md` | Tạo mới | Đặc tả + fixture + expected output |
| `mt5/README.md` | Sửa | Mapping `Scripts/`, input mới, event mới, cách chạy test |
| `docs/reference/architecture.md` | Sửa | Trạng thái Phase 1/2 |
| `README.md` | Sửa | Trạng thái Phase 2, link spec/report |
| `docs/phase-reports/phase-2.md` | Tạo mới | Báo cáo này |

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:...\LabSignalEA.mq5 /log:...\ea.compile.log` | Exit code **1**; log `Result: 0 errors, 0 warnings, 926 ms elapsed, cpu='X64 Regular'`; tạo `.ex5` 26,764 bytes (sau khi sửa bounds check) |
| `MetaEditor64.exe /compile:...\LabSignalEngineTests.mq5 /log:...\tests.compile.log` | Exit code **1**; log `Result: 0 errors, 0 warnings, 941 ms elapsed, cpu='X64 Regular'`; tạo `.ex5` 18,122 bytes |
| `grep -E "OrderSend\|OrderSendAsync\|OrderModify\|OrderDelete\|PositionOpen\|PositionClose\|CTrade\|CExpert\|AccountInfo\|AccountLogin\|TERMINAL_CONNECTED" mt5/**/*.mq5 *.mqh` | Không có kết quả |
| Python độc lập tính EMA cho các fixture | Khớp giá trị hard-code trong test (BUY/SELL/HOLD) |
| `.venv/Scripts/python.exe -m pytest` | 11 passed (không đổi từ Phase 0) |

Lưu ý: MetaEditor CLI trả exit code 1 dù log thành công — giữ nguyên cả hai dữ kiện.

Ghi chú thêm: một lần chạy compile bằng vòng lặp bash với đường dẫn ghép chuỗi trả exit code 0 nhưng
không tạo log/`.ex5` (đường dẫn không được MetaEditor hiểu). Đã chạy lại bằng đường dẫn tuyệt đối
Windows tường minh; kết quả trong bảng là từ lần chạy tường minh.

## 4. Thiết kế và kiểm soát look-ahead

- Hàm indicator nhận mảng chronological, không truy cập terminal.
- EA gọi `CopyRates(_Symbol,_Period,1,needed,...)`: shift `1` loại nến đang hình thành.
- Crossover chỉ dùng `t-1` và `t`, với `t` là nến đóng cuối cùng.
- Warm-up tối thiểu `slow_period + 1`; thiếu dữ liệu → `UNKNOWN` / `INSUFFICIENT_HISTORY`, không phải
  `HOLD`.
- Giá `<= 0` hoặc không hữu hạn → indicator `false` → `UNKNOWN` / `INDICATOR_FAILED`.

## 5. Xác minh thủ công còn lại

1. Sync `mt5/Include/Indicators.mqh`, `SignalEngine.mqh` vào `MQL5/Include/`.
2. Sync `mt5/Scripts/LabSignalEngineTests.mq5` vào `MQL5/Scripts/`; compile (`F7`).
3. Chạy script trên một chart; đọc Experts, kỳ vọng `TEST|RESULT|ALL_PASS`, `fail=0`.
4. Chạy `LabSignalEA` trong Strategy Tester; xác nhận `event=signal` xuất hiện sau mỗi `event=new_bar`.
5. Ghi pass/fail và build terminal vào báo cáo.

## 6. Tiêu chí nghiệm thu Phase 2

| Tiêu chí | Kết quả | Ghi chú |
|---|---|---|
| Cùng input và cấu hình cho cùng kết quả | Đạt một phần | Có test determinism và expected output độc lập; **chưa chạy MQL5 test** |
| Không look-ahead do truy cập bar index sai | Đạt theo thiết kế | Chỉ dùng nến đóng qua shift 1 và hai index cuối; chưa chứng minh runtime |
| `HOLD` khác `UNKNOWN` | Đạt | Enum và reason code tách biệt; test case cho cả hai |
| Logic không phụ thuộc gửi lệnh | Đạt | Không có API execution/account trong module |

## 7. Hạn chế và rủi ro

- Self-check script chưa chạy; lỗi runtime (nếu có) chưa được phát hiện.
- EMA seed bằng SMA có thể khác EMA mặc định của MT5; đây là lựa chọn có chủ đích, đã ghi trong spec.
- Chưa có benchmark hiệu năng; mỗi nến đóng tính lại toàn bộ EMA trên `slow+1` giá, chấp nhận được với
  warm-up nhỏ nhưng sẽ cần tối ưu nếu tăng cửa sổ ở phase sau.
- Chưa xử lý symbol/timeframe thay đổi giữa chừng.
- Test script dùng `PrintFormat` với `%.12f`; build khác có thể định dạng hơi khác nhưng giá trị so sánh
  dùng tolerance.

## 8. Phase tiếp theo

Phase 3 — Python data pipeline và validation: loader CSV/Parquet, chuẩn hóa timestamp/symbol/timeframe,
validate duplicate/out-of-order/OHLC/NaN/Inf/gap, báo cáo JSON/CSV, fixture synthetic và
`docs/reference/data-dictionary.md`.
