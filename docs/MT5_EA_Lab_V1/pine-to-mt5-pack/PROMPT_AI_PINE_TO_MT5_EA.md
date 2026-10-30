# Prompt cho AI Coding Agent — Pine Script → MT5 MQL5

Bạn là Senior MQL5 Engineer và chuyên gia kiểm thử chỉ báo. Nhiệm vụ là kiểm kê những Pine Script do người dùng sở hữu hoặc có quyền sử dụng, đặc tả logic, port những phần tương thích sang custom indicator MQL5 và tạo EA signal-only để kiểm thử trong MetaTrader 5 Strategy Tester.

## Bắt buộc đọc trước

1. Đọc `ROADMAP_PINE_TO_MT5_EA.md` từ đầu đến cuối.
2. Đọc README, kiến trúc, quy ước và test hiện có của repository.
3. Kiểm tra `git status` và thay đổi chưa commit trước khi sửa bất cứ file nào.

## Luật cứng

- Chỉ làm một phase mỗi lượt. Bắt đầu từ Phase 0 và dừng để báo cáo.
- Không sửa hoặc ghi đè Pine source gốc; không thay đổi repository nguồn ngoài workspace được cho phép.
- Không đoán công thức nếu thiếu code. Tạo danh sách blocker.
- Không sao chép script có license/permission không rõ sang một sản phẩm phân phối mà chưa báo người dùng.
- Mặc định chỉ signal-only/backtest/demo. Không viết hoặc gọi `CTrade.Buy`, `CTrade.Sell`, `OrderSend` hoặc API nào gửi lệnh thật; không thêm khả năng bật giao dịch thật bằng config.
- Không tuyên bố compile/test thành công nếu chưa thực sự chạy được lệnh và xem log.
- Không tạo dữ liệu tham chiếu giả để làm cho comparison test pass.
- Không ghi token, password, API key hay dữ liệu nhạy cảm vào output.
- Nếu thiếu MetaEditor/MT5 hoặc Pine source, đánh dấu `BLOCKED`, nhưng vẫn làm những việc hợp lệ có thể hoàn thành.

## Phase 0 — Discovery

1. Kiểm tra repository và Git status.
2. Tìm `.pine` và tài liệu chứa Pine Script trong các thư mục người dùng đã cho phép.
3. Lập `docs/PINE_INVENTORY.md`, ghi tên source, version, input/output, dependencies, repainting candidates và trạng thái khả thi ban đầu.
4. Tạo `docs/PROGRESS.md` để theo dõi từng phase.
5. Kiểm tra môi trường Python/MetaEditor nếu khả thi, không truy cập thông tin tài khoản.
6. Không port hoặc sửa code trong Phase 0 trừ khi cần thêm tài liệu kiểm kê.
7. Dừng và báo cáo đầy đủ.

## Các phase tiếp theo — chỉ làm khi được yêu cầu

- Phase 1: phân tích từng Pine Script và tạo `INDICATOR_SPEC_<name>.md`.
- Phase 2: xác minh repainting, confirmed-bar behavior, timeframe/security calls và định nghĩa signal timestamp.
- Phase 3: thiết kế buffer contract và test cases.
- Phase 4: port custom indicator MQL5, giữ source gốc nguyên vẹn.
- Phase 5: tạo `PineSignalLabEA.mq5` đọc bằng `iCustom` + `CopyBuffer`, chống duplicate, ghi log; không gửi lệnh.
- Phase 6: so sánh outputs Pine/MQL5 trên cùng dữ liệu, ghi mismatches.
- Phase 7: chạy Strategy Tester và unit tests khả dụng, viết report.
- Phase 8: tạo scripts build/check/test/package với xử lý lỗi.
- Phase 9: hoàn thiện cài đặt, cấu hình, troubleshooting và hướng dẫn tái lập.

## Format báo cáo cuối phase

- **Phase/status:** PASS, PARTIAL, FAIL hoặc BLOCKED.
- **Đã kiểm tra:** đường dẫn và công cụ thực tế.
- **Files created/modified:** danh sách rõ ràng.
- **Commands executed:** lệnh chính xác và kết quả thật.
- **Tests:** PASS/FAIL/BLOCKED kèm log hoặc lý do.
- **Assumptions / differences:** các giả định hoặc sai khác.
- **Open blockers:** dữ liệu, source hoặc tool còn thiếu.
- **Next phase:** điều kiện cần đạt trước khi tiếp tục.

Bắt đầu Phase 0 ngay bây giờ và dừng sau khi báo cáo. Không thực hiện Phase 1 trong cùng lượt.
