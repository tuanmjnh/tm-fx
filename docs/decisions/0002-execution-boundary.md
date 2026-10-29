# ADR 0002 — Ranh giới execution và chạy trên Exness MT5

> **Cập nhật 2026-10-29:** ADR [0003](0003-demo-execution-scope.md) đã thay thế **mục 1, 2 và 6** của
> ADR này: repository có execution **chỉ trên tài khoản demo/Strategy Tester**, qua
> `PATrendRiderXAUv1DemoEA` + `mt5/Include/Exec/*`. Các mục còn lại (không tài khoản live, không
> credential, không hứa hẹn lợi nhuận) vẫn hiệu lực. Nội dung dưới đây giữ nguyên làm lịch sử.

- **Ngày:** 2026-10-28
- **Trạng thái:** Accepted, thay thế một phần bởi ADR 0003
- **Bối cảnh:** người dùng yêu cầu một bot “chạy trực tiếp trên Exness MT5”. Repository hiện tại là
  signal-only theo ADR 0001: không có `OrderSend`, `CTrade`, không kết nối broker, không lưu credential.
  Các kết quả DCA/grid, trailing stop và ML mới chỉ là mô phỏng offline trên dữ liệu synthetic.

## Quyết định

1. **Repo này tiếp tục không có execution.** Không thêm hoặc kích hoạt `OrderSend`, `OrderSendAsync`,
   `OrderModify`, `OrderDelete`, `PositionOpen`, `PositionClose`, `CTrade.Buy`, `CTrade.Sell` hoặc đường
   tự động mở/đóng lệnh.
2. **“Chạy trên Exness MT5” trong phạm vi repo** nghĩa là: compile EA/script, chạy self-check, export
   parity, chạy ONNX harness và Strategy Tester với dữ liệu offline. Không chạy trên tài khoản live.
3. **Không đăng nhập tài khoản live** và không nhập mật khẩu, investor password, OTP, server hay token
   vào agent, script, config, log hay artifact. Nếu terminal hiện hộp thoại đăng nhập, chọn Cancel.
4. **`LabSignalEA` là signal-only.** Khi chạy trên chart hoặc Strategy Tester, **0 trade là kết quả
   đúng**. Không diễn giải log tín hiệu thành bằng chứng hiệu năng hay sẵn sàng live.
5. **Nếu muốn execution thật**, phải tạo scope mới (repo hoặc module riêng) và có ADR/review riêng. Bản
   tối thiểu phải có:
   - chỉ chấp nhận tài khoản demo; từ chối init nếu không phải demo;
   - mặc định dry-run, chỉ bật gửi lệnh bằng cờ tường minh;
   - tối đa một vị thế, SL/TP bắt buộc, giới hạn lot/risk, max daily loss và kill switch;
   - không martingale, grid hoặc DCA ở bản execution đầu tiên;
   - không lưu credential, không log thông tin tài khoản;
   - kiểm thử trên Strategy Tester/demo trước, không cam kết lợi nhuận.
6. **Live execution không được hỗ trợ** bởi repo này. Mọi thay đổi phạm vi phải được người dùng chấp
   thuận rõ ràng trước khi viết code.

## Hệ quả

- Docs và release checklist phải tiếp tục ghi rõ “không execution/live”.
- `docs/guides/install-and-test.md` chỉ hướng dẫn compile, self-check, parity, ONNX và Strategy Tester offline.
- Không có kết quả backtest/live nào được dùng làm cam kết hiệu năng.
- Muốn có bot demo, cần một kế hoạch riêng với yêu cầu an toàn ở mục 5; không tự thêm vào repo hiện tại.

## Phương án đã cân nhắc

- **Thêm execution trực tiếp vào repo hiện tại:** loại. Vi phạm ADR 0001, release checklist và tăng rủi
  ro mất vốn; không có guard demo/risk phù hợp.
- **Bản demo-only ngay trong repo này:** chưa duyệt. Cần scope mới, test và review riêng.
- **Giữ signal-only + Strategy Tester offline:** chọn. Đây là phạm vi hiện tại và là bước kiểm chứng an
  toàn trước mọi quyết định execution sau này.
