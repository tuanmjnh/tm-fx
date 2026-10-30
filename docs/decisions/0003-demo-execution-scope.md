# ADR 0003 — Phạm vi execution chỉ tài khoản demo

- **Ngày:** 2026-10-29
- **Trạng thái:** Accepted; mục 1 và câu "không grid/DCA" ở mục 3 đã được thay bởi
  [ADR 0004](0004-all-bots-demo-execution.md) (2026-10-30): mọi bot được execution đầy đủ trên demo.
- **Thay thế một phần:** [ADR 0002](0002-execution-boundary.md) mục 1, 2 và 6. Các mục còn lại của
  ADR 0002 (không tài khoản live, không credential, không hứa hẹn lợi nhuận) vẫn hiệu lực.
- **Bối cảnh:** chủ dự án yêu cầu bỏ quy tắc "chỉ tạo vị thế ảo, không gửi lệnh thật" và cho phép chạy
  trên tài khoản demo. ADR 0002 đã ghi rõ: muốn có execution phải tạo scope mới, có ADR riêng và đáp ứng
  danh sách an toàn tối thiểu. Yêu cầu này chính là sự chấp thuận đó.

## Quyết định

1. **Repository có execution, nhưng chỉ cho tài khoản demo.** Đường thực thi duy nhất là
   `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` cùng hai module `mt5/Include/Exec/ExecGuard.mqh` và
   `mt5/Include/Exec/ExecBroker.mqh`. Không file nào khác được gọi API gửi lệnh.
2. **Tài khoản live/real vẫn bị cấm.** `ExecGuard` chỉ chấp nhận `ACCOUNT_TRADE_MODE_DEMO` hoặc môi
   trường Strategy Tester (tài khoản ảo). Mọi trường hợp khác khiến `OnInit` trả `INIT_FAILED`; EA không
   chuyển sang chế độ mô phỏng ngầm.
3. **Guardrail bắt buộc của EA demo:**
   - `InpEnableExecution=false` mặc định: dry-run, chỉ ghi nhật ký quyết định, không gửi lệnh.
   - Bật gửi lệnh bằng cờ tường minh `InpEnableExecution=true`; không có cờ "live".
   - Tối đa một vị thế của EA (magic riêng); EA không mở vị thế thứ hai.
   - SL và TP bắt buộc trên mọi lệnh (`InpTakeProfitR > 0`); khối lượng tính từ tick size/tick value
     và ngân sách rủi ro, làm tròn xuống volume step, từ chối nếu lot tối thiểu vượt ngân sách.
   - `InpRiskPercent`, `InpDailyLossLimitPct`, `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`,
     `InpCooldownMinutes` giữ nguyên ngữ nghĩa ledger của Track C.
   - Kill switch `InpKillSwitchFile` (mặc định `PA_TREND_RIDER_DEMO_STOP.txt` trong `MQL5/Files`): file
     tồn tại thì EA đóng vị thế và ngừng vào lệnh cho tới khi khởi động lại sau khi xoá file.
   - Không martingale, không grid, không DCA trong phạm vi demo execution đầu tiên.
4. **Không credential, không đăng nhập.** EA không đọc/ghi login, password, investor password, OTP,
   server hay token; không dùng `WebRequest`, socket. Người dùng tự đăng nhập terminal bằng tay.
5. **Các EA mô phỏng không đổi.** `PATrendRiderXAUv1SimEA` và các EA Track C vẫn tạo vị thế ảo, không gọi
   API lệnh. Bằng chứng Strategy Tester cũ vẫn hợp lệ và không bị trộn với kết quả demo.
6. **Không quảng bá hiệu năng.** Kết quả demo/backtest không phải cam kết lợi nhuận hay bằng chứng sẵn
   sàng live. Mọi tài liệu phải giữ `NOT_RUN`/`BLOCKED` khi chưa có bằng chứng chạy thật.
7. **Live execution vẫn cần scope mới.** Bất kỳ thay đổi nào cho phép tài khoản real phải có ADR mới,
   được chủ dự án chấp thuận trước khi viết code.

## Hệ quả

- Static gate (`scripts/validate-project.py`) chỉ miễn trừ API lệnh cho đúng các file Exec; mọi source
  khác vẫn bị chặn. `scripts/validate_demo_execution.py` kiểm tra các guardrail ở trên.
- Preset demo dùng `execution_mode: DEMO_ONLY`, `allow_live_trading: false`, và nằm ở `configs/demo/`.
- Tài liệu vận hành: `docs/guides/demo-execution.md`.
- Kết quả demo chỉ có giá trị vận hành (EA chạy đúng guardrail), không phải kết luận chiến lược.

## Phương án đã cân nhắc

- **Bỏ hoàn toàn quy tắc an toàn, cho EA cũ gửi lệnh:** loại. Không có guard demo, dễ chạy nhầm tài
  khoản thật và làm mất giá trị bằng chứng mô phỏng.
- **Thêm cờ execution vào chính EA mô phỏng:** loại. Trộn hai chế độ trong một file làm bằng chứng cũ
  khó tái lập và tăng rủi ro bật nhầm.
- **EA demo riêng, dùng chung engine tín hiệu TrendRider, guard độc lập:** chọn.
