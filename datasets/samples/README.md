# Samples

Chỉ đặt tại đây các mẫu **nhỏ, không nhạy cảm**, dùng cho test hoặc tài liệu.

- Ghi rõ trong tên file hoặc metadata rằng dữ liệu là `synthetic`, `fixture` hay trích từ nguồn thực.
- Không đặt dữ liệu lịch sử lớn hoặc dữ liệu có điều kiện cấp phép hạn chế.
- Không coi dữ liệu synthetic là dữ liệu thị trường thật.

## Nội dung hiện có

- `synthetic_ema_cross_demo.csv` — 8 nến M5 EURUSD **synthetic** tạo thủ công cho test/backtest demo.
  Có một tín hiệu BUY tại bar index 5 (nến thứ 6); backtest vào lệnh tại open bar 6.
  Không phải dữ liệu thị trường thật, không dùng để đánh giá chiến lược.
- `parity_ema_cross.csv` — 12 nến M5 EURUSD **synthetic** dùng chung cho parity MQL5/Python (Phase 5).
  Kỳ vọng 3 `UNKNOWN`, 7 `HOLD`, 1 `BUY` tại 00:25 và 1 `SELL` tại 00:45 với fast=2, slow=3.
  Không phải dữ liệu thị trường thật.
- `synthetic_ml_demo.csv` — 1.800 nến M5 EURUSD **synthetic** cho ML baseline (Phase 7), sinh tất định
  bằng `scripts/generate_synthetic_ml_dataset.py` (seed 20261027). Có regime, return AR(1), OHLC nhất quán
  và volume/spread giả lập. Kết quả demo: test ROC-AUC 0.5708, balanced accuracy 0.5584; chiến lược ML lỗ
  -151.60 sau chi phí và kém buy & hold. **Không phải dữ liệu thị trường thật**, không dùng để đánh giá
  lợi nhuận hay suy ra hành vi giá.
- Fixture validation nhỏ nằm ở `python/tests/fixtures/synthetic_eurusd_m5.csv` (6 nến, cũng là synthetic).
