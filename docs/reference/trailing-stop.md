# Trailing stop — mô phỏng Python

- **Trạng thái:** đã triển khai trong backtester Python và có test; chưa có implementation MQL5/EA.
- **Phạm vi:** một vị thế tại một thời điểm, dữ liệu OHLC, mô phỏng offline. Không execution, không kết nối
  broker, không gửi lệnh.
- **Mã nguồn:** `python/src/mt5_ea_ai_lab/backtest/trailing.py`,
  `python/src/mt5_ea_ai_lab/backtest/engine.py`, `python/src/mt5_ea_ai_lab/backtest/models.py`.
- **Config mẫu:** `configs/backtest.trailing-synthetic.yaml`.

## 1. Cấu hình

Thêm vào `execution` của backtest YAML:

```yaml
execution:
  trailing_stop_points: 200.0        # khoảng cách stop, đơn vị point
  trailing_activation_points: 300.0  # excursion tối thiểu để bắt đầu kéo stop
```

| Field | Mặc định | Ý nghĩa |
|---|---|---|
| `trailing_stop_points` | `null` | Khoảng cách giữa mức giá thuận lợi nhất và stop; phải `> 0` nếu bật |
| `trailing_activation_points` | `null` | Excursion tối thiểu từ entry fill để kéo stop lần đầu; `null` = kéo ngay |

`trailing_activation_points` chỉ hợp lệ khi có `trailing_stop_points`; cấu hình activation mà không có
trailing bị từ chối. Các field không bật được để `null` và không thay đổi hành vi cũ.

## 2. Quy tắc mô phỏng

- **Entry fill** là mốc tính excursion và stop ban đầu, không phải close của bar phát tín hiệu.
- **Long:** ứng viên stop = `high` của bar − `trailing_stop_points × point_size`.
  **Short:** ứng viên stop = `low` của bar + `trailing_stop_points × point_size`.
- **Chỉ siết, không nới:** long lấy `max(stop hiện tại, ứng viên)`, short lấy
  `min(stop hiện tại, ứng viên)`.
- **Activation:** chỉ xét ứng viên khi excursion thuận lợi
  `(high − entry_fill)` cho long hoặc `(entry_fill − low)` cho short đạt ngưỡng activation.
- **Hiệu lực từ bar kế tiếp:** stop được tính ở cuối bar đã đóng từ high/low, nhưng không được giả định
  chạm trong chính bar đã tạo ra nó. OHLC không cho biết high hay low xuất hiện trước, nên đây là quy ước
  bảo thủ, tránh look-ahead.
- **Stop tĩnh:** nếu bật cả `stop_loss_points`, stop ban đầu là stop tĩnh; trailing chỉ thay thế khi mức
  mới tốt hơn. Stop tĩnh bị chạm trước khi trailing move ghi `exit_reason=stop_loss`.
- **Gap:** nếu open vượt stop, fill là open tệ hơn, cùng quy tắc với stop-loss:
  long `min(open, stop)`, short `max(open, stop)`.
- **Exit reason:** trailing đã move và stop bị chạm → `trailing_stop`; stop tĩnh chưa move → `stop_loss`;
  hết dữ liệu → `end_of_data` (đóng tại close cuối, kể cả khi trailing đang cao hơn close với long).
- **Cùng bar SL/TP:** giữ quy ước stop được giả định khớp trước; trailing không thay đổi quy ước này.

## 3. Chạy demo

```powershell
.\.venv\Scripts\python.exe scripts\run_backtest.py `
  --config configs\backtest.trailing-synthetic.yaml
```

Config mẫu dùng `datasets/samples/synthetic_ml_demo.csv`, EMA 8/21, trailing 200 point, activation 300
point, không có stop tĩnh và không có take-profit.

## 4. Kết quả demo thực tế

Lần chạy 2026-10-28, dataset synthetic 1.800 bar:

| Hạng mục | Giá trị |
|---|---|
| Exit code | `0` |
| Bars | 1.800 |
| Trades | 54 |
| `trailing_stop` | 13 |
| `opposite_signal` | 41 |
| Final equity | 10.175,60 |
| Net profit | +175,60 |
| Max drawdown | 251,40 |
| Profit factor | 1,2989 |
| Win rate | 0,3889 |
| Exposure | 0,8539 |

Đây là kiểm tra cơ chế trên dữ liệu synthetic, **không phải** kết quả thị trường, không phải khuyến nghị
giao dịch và không chứng minh trailing stop có lợi nhuận. Artifact nằm trong
`reports/backtests/demo-trailing-synthetic/` (gitignored).

## 5. Test

Các test tập trung vào:

- Long trail theo high, short trail theo low; stop không bao giờ nới.
- Activation chặn move đầu tiên và giữ stop hiện tại; activation đúng bằng excursion vẫn cho move.
- Backtest integration: trailing khóa lãi và fill ở bar kế tiếp; activation trì hoãn stop; stop tĩnh giữ
  `exit_reason=stop_loss`; short trail theo low.
- Config YAML parse hai field mới; activation thiếu trailing bị từ chối; ML CLI từ chối trailing vì ML
  simulation không hỗ trợ stop.

Toàn bộ suite tại thời điểm trailing stop (2026-10-28): **170 passed in 15.13s**. Sau khi thêm bounded
DCA/grid, suite hiện là **198 passed**.

## 6. Giới hạn

- Không mô phỏng tick path; trailing chỉ cập nhật theo bar đã đóng và có hiệu lực bar kế tiếp.
- Không có breakeven stop, step trailing, trailing theo ATR, partial close hay nhiều vị thế.
- Không mô hình leverage, margin, margin call, swap/financing, thanh khoản hoặc requote.
- Chưa có implementation MQL5/EA; không có execution hay kết nối broker.
- Kết quả phụ thuộc mạnh vào timeframe, khoảng dữ liệu, spread/slippage giả định và tham số trailing.
