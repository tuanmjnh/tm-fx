# Experiments

Thư mục này chứa metadata và artifact thí nghiệm **local**. Toàn bộ nội dung (trừ README) bị gitignore.

- Metadata: SQLite `experiments.sqlite` (Phase 6), schema v1.
- Artifact lớn: CSV/JSON trong thư mục con của từng experiment.
- Không lưu mật khẩu, API key, token hay thông tin tài khoản môi giới.
- Mỗi experiment phải tham chiếu được tới git commit, config hash, data fingerprint, symbol/timeframe và
  trạng thái (`running`, `completed`, `failed`, `invalid_data`, `cancelled`, `interrupted`).

Database/report demo Phase 6 chỉ tồn tại cục bộ và bị gitignore; chúng không phải một phần của repository.
