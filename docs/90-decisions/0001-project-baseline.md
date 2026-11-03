# ADR 0001 — Baseline dự án và môi trường Phase 0

- **Ngày:** 2026-10-27
- **Trạng thái:** Accepted
- **Bối cảnh:** repository hiện tại ban đầu chỉ có hai tài liệu roadmap/prompt, chưa có Git, chưa có code.

## Quyết định

1. **Repository độc lập.** Không import, sửa hay phụ thuộc `tm-trading`, `tm-hub` hoặc dự án khác.
2. **MVP signal-only.** Không có execution code, không kết nối broker, không lưu credential.
3. **Baseline Python 3.11 (64-bit)**, đã xác minh 3.11.9. Dependency pin theo `requirements.txt`.
4. **Baseline MT5 5.0.0.6249** (bản cài EXNESS) cho các phase MQL5. Chỉ dùng terminal/MetaEditor để
   compile và chạy Strategy Tester với dữ liệu offline; không đăng nhập tài khoản.
5. **Lưu trữ local-first:** CSV/Parquet cho dữ liệu, SQLite cho metadata, JSON cho report/registry.
   Không cloud, không dashboard, không API trong MVP.
6. **Windows 10 được chấp nhận cho Phase 0** dù roadmap khuyến nghị Windows 11. Không có hành vi nào phụ
   thuộc phiên bản Windows 11; nếu gặp lỗi đặc thù MT5, ghi nhận và đánh giá lại.
7. **Git được khởi tạo nhưng không commit trong Phase 0.** Người dùng quyết định thời điểm commit/push.

## Hệ quả

- Mọi hướng dẫn sync EA sang MT5 là thao tác thủ công có tài liệu; không có script tự động ghi vào data folder.
- Version MT5/MetaEditor phải được kiểm tra lại trước Phase 1 và Phase 8 vì hành vi API/ONNX có thể khác.
- Không có bằng chứng compile/tester trong Phase 0; Phase 1 sẽ tạo EA đầu tiên và chịu trách nhiệm xác minh.
- Nếu cần nâng Python hoặc MT5, tạo ADR mới và cập nhật `requirements.txt`, README, environment inventory.

## Phương án đã cân nhắc

- **Dùng chung môi trường Python toàn hệ thống:** bị loại vì khó tái lập và dễ xung đột dependency.
- **Đóng gói package ngay từ Phase 0:** hoãn; `pyproject.toml` hiện chỉ cấu hình pytest, tránh quyết định
  packaging khi chưa có module thực.
- **Tự động copy EA sang MT5 Data Folder:** bị loại vì thay đổi ngoài repository và có rủi ro vận hành.
