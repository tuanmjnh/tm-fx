# Experiments

Thư mục này chứa metadata và artifact thí nghiệm **local**. Toàn bộ nội dung (trừ README) bị gitignore.

- Metadata: SQLite (Phase 6).
- Artifact lớn: CSV/Parquet/JSON trong thư mục con của từng experiment.
- Không lưu mật khẩu, API key, token hay thông tin tài khoản môi giới.
- Mỗi experiment phải tham chiếu được tới git commit, config hash, data fingerprint, symbol/timeframe và
  trạng thái (`failed`, `completed`, `invalid_data`, `cancelled`).

Chưa có experiment nào được chạy.
