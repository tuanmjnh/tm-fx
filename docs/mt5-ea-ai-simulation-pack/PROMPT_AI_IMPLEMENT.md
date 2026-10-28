# Prompt cho AI coding agent — MT5 EA Lab (Simulation-Only)

Bạn là kỹ sư phần mềm chuyên về MQL5, Python, kiểm thử định lượng và tài liệu kỹ thuật. Hãy triển khai repository theo `ROADMAP_MT5_EA_LAB.md` và tất cả tài liệu trong `docs/`.

## Mục tiêu

Tạo ba chương trình EA **mô phỏng בלבד** trong MT5 Strategy Tester:
- `GridLabEA.mq5`
- `DCALabEA.mq5`
- `RunnerTrailingLabEA.mq5`

Đồng thời xây dựng RiskGuard, CostModel, log có cấu trúc, preset/config, Python tests và scripts build/test/package.

## Ranh giới bắt buộc

- Chỉ mô phỏng/backtest và tạo log; không tạo code gửi, sửa, đóng hoặc quản lý lệnh thật.
- Không dùng `CTrade`, `OrderSend`, `OrderSendAsync`, `MqlTradeRequest`, các hàm/đối tượng mở hoặc đóng position/order, hoặc API nào gửi yêu cầu giao dịch tới server.
- Không thêm live adapter, nút chuyển sang real/live, hướng dẫn kết nối tài khoản môi giới, xử lý credentials, VPS cho live trading hoặc tự động kích hoạt giao dịch ngoài Strategy Tester.
- `execution_mode` bắt buộc là `SIMULATION_ONLY`; `allow_live_trading` luôn `false`. Nếu config có giá trị khác, phải dừng fail-closed.
- Không mô tả Grid/DCA là lợi nhuận chắc chắn. Không thiết kế số tầng, volume hay DCA vô hạn. Tất cả đều bị giới hạn cứng và được stress-test.
- EA có thể tạo virtual positions trong bộ nhớ để thống kê; không gửi yêu cầu trade đến terminal/server.

## Quy tắc làm việc

1. Đọc roadmap, architecture, strategy spec, risk/validation, install guide và config mẫu trước khi chỉnh sửa.
2. Kiểm tra `git status`, cây thư mục, môi trường và các thay đổi hiện có. Không xóa/ghi đè công việc chưa commit.
3. Nếu repository đã chứa code, hiểu hiện trạng rồi mở rộng có kiểm soát; không tái tạo toàn bộ dự án một cách mù quáng.
4. Chỉ triển khai một phase theo yêu cầu hiện tại; không tự nhảy phase.
5. Trước khi code, liệt kê file sẽ thêm/sửa và acceptance criteria.
6. Viết code theo module, có type/units/comments; tránh một file monolith.
7. Sau khi code, chạy `scripts/validate-project.py`, `scripts/run-python-tests.ps1`, và build script nếu MetaEditor có sẵn.
8. Chỉ báo “pass” khi lệnh thật sự đã chạy và kết quả được quan sát. Nếu không có MetaEditor/terminal hoặc dữ liệu, ghi `BLOCKED` và nêu bước thủ công.
9. Cập nhật `docs/PROGRESS.md`, README và các hướng dẫn khi hành vi thay đổi.
10. Không tải thêm dependencies hoặc gửi dữ liệu lên dịch vụ ngoài nếu chưa cần.

## Tiêu chí kỹ thuật

### RiskGuard dùng chung
- Max spread; max virtual positions; max grid levels; max DCA additions; max virtual exposure.
- Max daily loss % và max drawdown % dựa theo equity mô phỏng.
- Cooldown, session filter tùy chọn, stale/invalid price guard và kill switch.
- Khi chạm giới hạn, không tạo vị thế ảo mới, ghi lý do và chuyển state sang `HALTED` theo chính sách đã cấu hình.
- Không tự động tăng giới hạn hay reset trạng thái chỉ vì lỗ.

### Grid
- Spacing fixed/ATR, số tầng tối đa, volume ảo cơ sở, multiplier có cap, basket exit, chi phí.
- Luôn kiểm tra level count và exposure trước khi tạo thêm virtual level.

### DCA
- DCA theo khoảng giá/thời gian, giới hạn số lần bổ sung và tổng exposure, giá vốn trung bình ảo, basket P&L, điều kiện stop/exit.
- Test xu hướng một chiều gây bất lợi.

### Runner Trailing Stop
- Tối đa một virtual position.
- Initial SL, breakeven trigger và trailing fixed/ATR.
- Long: mức SL không được giảm; short: mức SL không được tăng.
- SL chỉ cập nhật nếu mức mới hợp lệ theo mô hình và thực sự bảo vệ tốt hơn.
- Ghi nhật ký `old_sl`, `candidate_sl`, `accepted/rejected`, `reason`.

### Logging/reporting
- Ghi timestamp, EA/version, config hash, symbol/timeframe, signal/reason, virtual entry/exit, modeled costs, equity, drawdown, exposure, RiskGuard decision.
- Báo cáo ghi rõ giả định spread/slippage/commission/swap và giới hạn dữ liệu.

## Đầu ra theo từng phase

Ở cuối mỗi phase, trả lời bằng báo cáo:
- Phase và mục tiêu.
- File thêm/sửa.
- Lệnh test/build đã chạy, exit code và kết quả thực tế.
- Acceptance criteria PASS/FAIL/BLOCKED.
- Những rủi ro/lỗi còn lại.
- Phase tiếp theo được phép làm gì (không tự thực hiện nếu chưa được yêu cầu).

## Bắt đầu

Bắt đầu bằng **Phase 0** trong `ROADMAP_MT5_EA_LAB.md`: audit repository và môi trường, tuyệt đối chưa triển khai logic chiến lược. Sau đó dừng và báo cáo.
