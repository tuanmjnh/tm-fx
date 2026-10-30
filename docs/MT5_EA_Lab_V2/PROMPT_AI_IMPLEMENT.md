# Prompt triển khai cho AI / người tiếp tục

**Mục đích:** giữ cho mọi lần tiếp tục triển khai có cùng ranh giới an toàn và cùng chuẩn bằng chứng.  
**Đối tượng:** AI coding agent hoặc kỹ sư tiếp nhận repository.

## 1. Bắt buộc — không thương lượng

1. **Chỉ ba chiến lược:** `PATrendRiderXAUv1`, `GridEA`, `DCAEA`. Không thêm chiến lược mới nếu chưa có yêu cầu và ADR.
2. **Live/real bị cấm.** Không tạo `REAL`, `LIVE`, `BYPASS_DEMO_CHECK` hoặc bất kỳ cờ tương tự. `ACCOUNT_TRADE_MODE` phải là DEMO hoặc `MQL_TESTER`; nếu không, EA phải `INIT_FAILED` và log lý do.
3. **Đường gửi lệnh duy nhất:** `mt5/Include/Exec/ExecBroker.mqh`. Chỉ `PATrendRiderXAUv1DemoEA` và `ExecDemoProbe` được gọi. Mọi EA khác phải không có `OrderSend`, `CTrade`, `MqlTradeRequest`, `Position*`, `Order*`.
4. **Dry-run mặc định:** `InpEnableExecution=false`.
5. **Một vị thế, SL/TP bắt buộc** trong DemoEA. Không grid, DCA, martingale, averaging.
6. **DCA/Grid demo execution bị chặn** cho tới khi có ADR mới. Không tự mở rộng phạm vi.
7. **Không credential** trong code/config/log/artifact/Git. Không tự động hóa hộp thoại đăng nhập.
8. **Không bịa kết quả.** Không tuyên bố compile/backtest/demo thành công nếu chưa chạy và kiểm tra output thật.
9. **Không xóa hoặc ghi đè file người dùng** khi chưa xác nhận. Không `git push`; người dùng tự push.
10. **Không sửa lịch sử** trong `PROGRESS.md` để làm đẹp kết quả. Chỉ thêm mục mới hoặc sửa lỗi có ghi chú.

## 2. Quy trình làm việc

1. **Đọc trạng thái hiện tại:** [`ROADMAP.md`](ROADMAP.md), [`TEST_REPORT.md`](TEST_REPORT.md), [`EVIDENCE.md`](EVIDENCE.md), và mục mới nhất của [`../PROGRESS.md`](../PROGRESS.md).
2. **Chọn một việc nhỏ, có thể kiểm chứng.** Ghi rõ việc đó thuộc phase nào.
3. **Kiểm tra môi trường** trước khi chạy: build terminal, data folder, quyền ghi, trạng thái Git. Không giả định.
4. **Thực hiện thay đổi tối thiểu.** Không refactor ngoài phạm vi; không thêm abstraction cho tương lai.
5. **Chạy gate thật:**
   - `.venv\Scripts\python.exe scripts\validate-project.py`
   - `.venv\Scripts\python.exe scripts\validate_demo_execution.py`
   - `.venv\Scripts\python.exe -m pytest -q`
   - Compile MQL5 nếu có thay đổi `.mq5/.mqh`.
6. **Ghi bằng chứng:** log, CSV, report, exit code, thời điểm, đường dẫn. Không ghi "đã chạy" nếu không có output.
7. **Cập nhật tài liệu:** thêm mục vào `PROGRESS.md`; cập nhật `TEST_REPORT.md`/`EVIDENCE.md` nếu số liệu thay đổi.
8. **Kết thúc bằng báo cáo PASS/FAIL/BLOCKED** cho từng hạng mục, kèm số liệu thật.

## 3. Chuẩn bằng chứng

| Loại | Bằng chứng hợp lệ | Không hợp lệ |
|---|---|---|
| Compile | Log có `Result: 0 errors, 0 warnings` + `.ex5` | Exit code 0/1 đơn thuần |
| Contract test | Log runtime có `pass=N fail=0` | Compile thành công |
| Python test | Output pytest có số passed/failed | "Chắc là pass" |
| Strategy Tester | `.htm` + CSV SUMMARY + `.set`/`.ini` | Ảnh chụp không có cấu hình |
| Demo execution | Journal CSV + log EA + tab History | Tester fill (là mô phỏng) |
| Broker acceptance | Log probe + tab History của server | Tester order |
| Profitability | Chuỗi forward test đủ dài, out-of-sample, chi phí thật | Một khoảng test ngắn |

## 4. Trạng thái tiếp nhận (2026-10-29)

- PATrendRider: engine, SimEA, DemoEA đã có; contract 82/82; tester và demo execution có bằng chứng.
- DemoEA đang armed trên demo nhưng **0 `ENTRY`** do regime `RANGE`/`bias_unknown`. Đây là hành vi đúng của bộ lọc, không phải lỗi.
- Broker demo đã chấp nhận một lệnh 0.01 qua `ExecDemoProbe` (BUY, có SL/TP, đóng trong 103 ms, `pnl=-0.24`).
- Grid/DCA chỉ mô phỏng; demo execution bị chặn.
- Profitability `UNPROVEN`.

## 5. Việc được phép làm ngay

- Giám sát journal demo, đối soát khi có `ENTRY`.
- Viết thêm test cho các nhánh chưa phủ (state restore, kill switch, retcode).
- Hoàn tất GitHub audit (đọc source/license/commit; không copy nếu chưa rõ license).
- Cải thiện tài liệu, sửa link, thêm troubleshooting.
- Tối ưu hiệu năng `PriceActionMTF` nếu không đổi hành vi tín hiệu (có test hồi quy).

## 6. Việc phải dừng và hỏi

- Mở demo execution cho Grid/DCA.
- Thay đổi guard demo/live.
- Thêm dependency mới hoặc code third-party.
- Đổi logic tín hiệu PATrendRider.
- Tăng risk mặc định hoặc bỏ SL/TP.
- Bất kỳ thao tác nào liên quan tài khoản thật, credential hoặc đăng nhập tự động.

## 7. Định nghĩa "xong"

Một việc chỉ được coi là xong khi:

1. Thay đổi nằm trong phạm vi đã nêu.
2. Gate liên quan đã chạy thật và pass (hoặc FAIL/BLOCKED được ghi rõ).
3. Bằng chứng được lưu và dẫn đường dẫn.
4. Tài liệu v2/PROGRESS được cập nhật.
5. Không có credential, không có live order, không có kết quả bịa.
