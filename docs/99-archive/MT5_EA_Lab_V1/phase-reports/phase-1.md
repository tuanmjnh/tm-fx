# Báo cáo Phase 1 — EA signal-only đầu tiên

- **Ngày:** 2026-10-27
- **Trạng thái:** `READY_FOR_MANUAL_VALIDATION`
- **Lý do:** EA compile thành công bằng MetaEditor CLI (0 errors, 0 warnings) nhưng **chưa chạy
  Strategy Tester**, nên chưa xác minh được khởi tạo và đọc bar ở runtime.

## 1. Tóm tắt

Phase 1 tạo EA MQL5 chỉ đọc dữ liệu và ghi log, không có bất kỳ API giao dịch hay tài khoản nào:

- `mt5/Experts/LabSignalEA.mq5` — xử lý `OnInit`, `OnTick`, `OnDeinit`; phát hiện nến mới dựa trên
  `CopyTime`; đọc tối đa 2 nến bằng `CopyRates`; chọn nến đã đóng mà không giả định thứ tự mảng;
  validate OHLC; log một dòng cho mỗi nến đóng.
- `mt5/Include/LabLogger.mqh` — logger có cấu trúc `LAB|<time>|<LEVEL>|<context>|event=...`.
- `mt5/README.md` — ánh xạ thư mục, hướng dẫn compile/sync/Strategy Tester, mẫu log, giới hạn.

Đã sửa một lỗi trong quá trình phát triển: input `InpLogEveryTick` ban đầu không được nối với logger
(debug luôn tắt). Đã thêm `CLabLogger::SetDebugEnabled()` và gọi trong `OnInit`.

## 2. File đã tạo/sửa

| File | Trạng thái | Ghi chú |
|---|---|---|
| `mt5/Experts/LabSignalEA.mq5` | Tạo mới | EA signal-only; không có hàm execution |
| `mt5/Include/LabLogger.mqh` | Tạo mới | Logger; có `SetDebugEnabled` |
| `mt5/README.md` | Tạo mới | Hướng dẫn sync/compile/tester và mẫu log |
| `docs/guides/install-and-test.md` | Cập nhật | Ghi kết quả compile Phase 1 |
| `docs/phase-reports/phase-1.md` | Tạo mới | Báo cáo này |

Không sửa roadmap/prompt. Không có file người dùng bị xóa/ghi đè.

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:...LabSignalEA.mq5 /log:...compile.log` | Tiến trình trả **exit code 1**; log báo `Result: 0 errors, 0 warnings, 885 ms elapsed, cpu='X64 Regular'`; `LabSignalEA.ex5` được tạo (19,574 bytes) |
| Giải mã `compile.log` (UTF-16) | Xác nhận include `..\Include\LabLogger.mqh` được resolve; không có error/warning |
| `grep -E "OrderSend\|OrderSendAsync\|OrderModify\|OrderDelete\|PositionOpen\|PositionClose\|CTrade\|CExpert\|AccountInfo\|AccountLogin\|TERMINAL_CONNECTED" mt5/**/*.mq5 *.mqh` | `NO_EXECUTION_OR_ACCOUNT_APIS` |
| `.venv/Scripts/python.exe -m pytest` (Phase 0 test, không đổi) | 11 passed — không bị ảnh hưởng bởi Phase 1 |

Ghi chú: MetaEditor CLI trả exit code 1 dù biên dịch thành công. Báo cáo giữ nguyên cả hai dữ kiện;
không tuyên bố exit code 0.

## 4. Hành vi EA

- `OnInit`: log `event=init` (symbol, timeframe, digits, point, tick_size, bars, tester, build); cảnh báo
  nếu symbol chưa được chọn; nếu `Bars()==0` log `event=history_unavailable` và vẫn init; nếu `CopyTime`
  thất bại log `event=copy_time_failed` và trả `INIT_FAILED`; thành công log `event=init_ok` kèm thời
  gian bar/server/UTC.
- `OnTick`: đếm tick; (tùy chọn) log DEBUG bid/ask; phát hiện bar mới bằng `CopyTime`; chỉ xử lý khi bar
  hiện tại đổi; đọc 2 nến bằng `CopyRates`, chọn nến cũ hơn bar hiện tại có thời gian lớn nhất; validate
  OHLC nếu bật; log `event=new_bar` hoặc `event=bar_invalid`. Không spam log mỗi tick.
- `OnDeinit`: log reason, tổng tick, số nến đã log, số nến invalid.
- Mọi lỗi dữ liệu đều **fail-closed**: bar không hợp lệ không được coi là tín hiệu.

## 5. Xác minh thủ công còn lại

Chưa chạy Strategy Tester. Cần người dùng thực hiện (agent không tự mở GUI vì terminal có thể kết nối
broker):

1. Sync `mt5/Experts/LabSignalEA.mq5` và `mt5/Include/LabLogger.mqh` vào đúng data folder.
2. Compile trong MetaEditor (`F7`), xác nhận 0 errors/0 warnings.
3. Chạy Strategy Tester với `EURUSD`, `M5`, khoảng ngày có sẵn; không chọn tài khoản thật.
4. Xác nhận log có `event=init`, `event=init_ok`, `event=new_bar` khi sang nến, `event=deinit` khi dừng.
5. Ghi build, symbol, timeframe, khoảng ngày và kết quả vào báo cáo.

## 6. Tiêu chí nghiệm thu Phase 1

| Tiêu chí | Kết quả | Ghi chú |
|---|---|---|
| Code không chứa hàm gửi lệnh | Đạt | Grep không thấy API execution/account |
| Biên dịch thành công trong MetaEditor hoặc ghi rõ lỗi môi trường | Đạt | 0 errors, 0 warnings; exit code 1 được ghi rõ |
| Có cách xác minh bar time và symbol/timeframe trong log | Đạt | `event=init_ok` và `event=new_bar` chứa đủ trường |
| Không tuyên bố compile/backtest nếu chưa có công cụ xác nhận | Đạt một phần | Compile có log thật; **runtime chưa chạy** nên trạng thái là `READY_FOR_MANUAL_VALIDATION` |

## 7. Hạn chế và rủi ro

- Chưa có kết quả Strategy Tester; chưa chứng minh EA xử lý đúng khi history reload hoặc symbol đổi.
- `CopyRates(...,0,2,...)` giả định cửa sổ 2 nến đủ để tìm nến trước; nếu terminal trả bất thường,
  EA log `closed_bar_not_found` và bỏ qua bar đó (an toàn, nhưng có thể mất một bar).
- Log dùng `TimeCurrent()` (server time) cho timestamp; trường `utc_time` chỉ xuất hiện ở `init_ok`.
- Chưa có test tự động cho MQL5; kiểm chứng dựa vào compile và log runtime.
- Build terminal hiện tại 5.0.0.6249; hành vi có thể khác trên build khác.

## 8. Phase tiếp theo

Phase 2 — tách indicator và signal engine (`Indicators.mqh`, `SignalEngine.mqh`), baseline EMA
crossover chỉ dùng nến đóng, warm-up, reason code, phân biệt `HOLD` với `UNKNOWN`.
