# Bounded DCA/grid basket simulation

- **Ngày:** 2026-10-28
- **Trạng thái:** mô phỏng offline đã chạy thật; **không** có execution, broker hay MQL5/EA.
- **Phạm vi:** một basket tại một thời điểm, mở bằng tín hiệu EMA crossover, thêm layer theo bước giá
  bất lợi, đóng theo take profit / loss cap / tín hiệu ngược chiều / hết dữ liệu.
- **Cảnh báo:** demo dùng `datasets/samples/synthetic_ml_demo.csv` (synthetic). Kết quả chỉ kiểm tra cơ
  chế mô phỏng, không phải hiệu năng thị trường và không đảm bảo lợi nhuận.

## 1. Mục đích

Backtester một vị thế ở [`engine.py`](../python/src/mt5_ea_ai_lab/backtest/engine.py) không biểu diễn
được nhiều layer đồng thời. Module [`bounded_basket.py`](../python/src/mt5_ea_ai_lab/backtest/bounded_basket.py)
là simulator **riêng**, chỉ mô phỏng, dùng để nghiên cứu DCA/grid với giới hạn cứng. Không có
`OrderSend`, `CTrade`, kết nối tài khoản hay lưu thông tin đăng nhập.

Module không thay thế backtester cũ và không được gọi từ pipeline Phase 9. Nó có CLI riêng
`scripts/run_basket_backtest.py` và chưa ghi vào experiment store.

## 2. Giới hạn cứng

| Giới hạn | Ý nghĩa | Cách cưỡng chế |
|---|---|---|
| `max_layers` | Số layer tối đa trong một basket | Không mở layer khi `len(layers) >= max_layers` |
| `max_total_units` | Tổng unit tối đa của basket | Không mở layer nếu tổng unit vượt cap |
| `max_basket_loss` | Lỗ ròng tối đa của basket (quote currency) | Stop giá suy ra từ average entry, đã dịch theo commission entry + exit |
| 1 layer / bar | Không mô phỏng nhiều fill trong cùng một bar | Sau khi thêm một layer, bỏ qua các level còn lại trong bar |
| Commission room | Cap phải còn chỗ cho commission | Config bị từ chối nếu `max_basket_loss <= 2 * effective_max_layers * commission_per_side` |
| Equity guard | Cap không được vượt vốn ban đầu | Config bị từ chối nếu `max_basket_loss >= initial_equity` |

`effective_max_layers = min(max_layers, floor(max_total_units / layer_units))`. Cả hai cap đều được kiểm
tra khi thêm layer; `hard_limits` trong summary báo `max_observed_layers`, `max_observed_units`,
`layers_within_cap`, `units_within_cap`, `blocked_add_bars` và `baskets_at_layer_cap`.

`blocked_add_bars` đếm số bar mà level đã chạm nhưng bị cap chặn. Đây là bằng chứng cap thực sự bind,
không phải chỉ là giá trị cấu hình.

`max_basket_loss` là **lỗ ròng** gồm commission entry đã trả và commission exit dự kiến; stop được dịch
gần average entry hơn để fill tại stop (không gap) cho đúng cap. Gap qua stop vẫn có thể làm lỗ vượt cap;
`hard_limits.loss_cap_overshoot` và `loss_cap_overshoot_baskets` báo phần vượt thực tế. Spread/slippage
exit cũng được tính trong stop price.

## 3. Hợp đồng thời gian và quy tắc xác định

1. Tín hiệu tại close bar `i` được thực thi tại open bar `i + 1`.
2. Basket mở bằng layer đầu tiên tại open đó; layer đầu chịu spread/slippage/commission như mọi fill.
3. Mỗi bar, **exit được kiểm tra trước add**:
   - Nếu loss cap và take profit cùng nằm trong một bar, **loss cap được giả định khớp trước** (bảo thủ,
     vì OHLC không cho biết thứ tự high/low).
   - Nếu không exit, xét tối đa **một** layer mới.
4. Layer mới chỉ ảnh hưởng average entry, take profit và loss cap từ **bar kế tiếp**. Nó không thể bị
   đóng bởi chính các level mà nó vừa thay đổi trong cùng bar.
5. Tín hiệu ngược chiều:
   - `close_on_opposite_signal: true` (mặc định): đóng toàn bộ basket tại open bar kế tiếp với
     `exit_reason=opposite_signal`, rồi mở basket mới cùng open đó.
   - `false`: bỏ qua tín hiệu ngược chiều; basket tiếp tục chờ take profit / loss cap / hết dữ liệu.
6. Tín hiệu cùng chiều khi đang có basket bị bỏ qua; layer chỉ được thêm bởi bước giá, không bởi signal.
7. Basket còn mở khi hết dữ liệu được đóng tại close bar cuối với `exit_reason=end_of_data`.

### 3.1 Level thêm layer

```text
dca : next = last_fill  - side * step_points * point_size
grid: next = first_fill - side * layer_count * step_points * point_size
```

- `side = +1` long, `-1` short.
- `dca` đo từ fill gần nhất; `grid` đo các level cố định từ fill đầu tiên.
- Chỉ thêm khi bar chạm level: long `low <= next`, short `high >= next`.
- Fill theo nghĩa limit order: long `min(open, level) + half_spread + slippage`,
  short `max(open, level) - half_spread - slippage`. Gap qua level được hưởng giá open tốt hơn.

Hai mode giống nhau khi không có gap; khác nhau sau gap vì `dca` lấy fill gần nhất còn `grid` giữ mốc
layer đầu. Test `test_grid_and_dca_diverge_after_a_gap_fill` mô tả trường hợp này.

### 3.2 Take profit và loss cap

```text
average_entry = trung bình entry_fill của các layer
take_profit_raw = average_entry + side * take_profit_points * point_size
exit_commission = commission_per_side * layer_count
entry_commission = tổng commission đã trả khi mở layer
room = max_basket_loss - entry_commission - exit_commission
loss_raw = average_entry - side * (room / total_units - exit_cost)
exit_cost = half_spread + slippage
```

- Take profit là **giá raw**; PnL ròng sau khi trừ exit cost và commission.
- Loss cap là **lỗ ròng**; nếu `room <= 0`, basket đóng ngay tại open bar hiện tại
  (`exit_reason=basket_loss_cap`). Validation và `_can_add` ngăn trường hợp này trong cấu hình hợp lệ.
- Long: loss `min(open, loss_raw)`, TP `max(open, take_profit_raw)`. Short: loss `max(open, loss_raw)`,
  TP `min(open, take_profit_raw)`. Sau đó trừ exit cost như mọi fill.

## 4. Cấu hình

Các field trong section `basket` của YAML:

| Field | Mặc định | Ghi chú |
|---|---|---|
| `initial_equity` | `10000.0` | Vốn mô phỏng |
| `layer_units` | `10000.0` | Unit mỗi layer |
| `max_layers` | `3` | Cap số layer |
| `max_total_units` | `30000.0` | Cap tổng unit |
| `step_points` | `200.0` | Khoảng cách bất lợi giữa các layer |
| `take_profit_points` | `300.0` | TP từ average entry |
| `max_basket_loss` | `300.0` | Lỗ ròng tối đa; phải `< initial_equity` |
| `point_size` | `0.00001` | Quy đổi point |
| `spread_points`, `slippage_points` | `0.0` | Chi phí mỗi fill |
| `commission_per_side` | `0.0` | Commission mỗi fill (entry và exit) |
| `mode` | `dca` | `dca` hoặc `grid` |
| `close_on_opposite_signal` | `true` | Đóng basket khi tín hiệu ngược chiều |

Không mô hình leverage, margin, margin call, swap/financing, contract size, tick rounding, lot constraint,
requote, latency hay partial fill. `max_total_units` là cap kích thước, **không** phải kiểm tra margin.

## 5. Demo synthetic

```powershell
# DCA
.\.venv\Scripts\python.exe scripts\run_basket_backtest.py `
  --config configs\backtest.bounded-basket-synthetic.yaml

# Grid
.\.venv\Scripts\python.exe scripts\run_basket_backtest.py `
  --config configs\backtest.bounded-grid-synthetic.yaml
```

Kết quả thực tế trên `datasets/samples/synthetic_ml_demo.csv` (1.800 bar M5, EMA 8/21, có spread 8,
slippage 1, commission 1):

| Run | Baskets | Layers | Final equity | Net PnL | Max DD | Exit reasons | Cap quan sát |
|---|---:|---:|---:|---:|---:|---|---|
| DCA | 57 | 70 | 9.858,43 | -141,57 | 145,39 | 19 TP, 38 opposite | 4/4 layer, 4.000/4.000 unit, 15 blocked bar |
| Grid | 60 | 83 | 9.860,46 | -139,54 | 150,94 | 2 loss cap, 25 TP, 33 opposite | 3/3 layer, 6.000/6.000 unit, 4 basket tại layer cap |

- DCA: worst realized basket loss 28,14; loss cap 300 nên không có loss-cap exit.
- Grid: worst realized basket loss 20,00 với cap 20,00; `loss_cap_overshoot=0`, `loss_cap_overshoot_baskets=0`.
- Cả hai demo lỗ sau chi phí. Đây là kết quả trên fixture synthetic, không phải kết luận về DCA/grid.

## 6. Artifact

`scripts/run_basket_backtest.py` ghi vào `outputs.report_dir`:

| File | Nội dung |
|---|---|
| `summary.json` | `engine=bounded_basket`, config, `effective_max_layers`, validation, metrics, `hard_limits`, `basket_count`, `basket_exit_reason_counts` |
| `trades.csv` | Mỗi layer một row: `TRADE_COLUMNS` + `basket_id` + `layer_index` |
| `baskets.csv` | Một row / basket: side, mode, open/close time, layer count, units, average entry, exit fill, PnL, commission, exit reason, blocked bars, layer cap flag |
| `equity.csv` | `timestamp`, `cash`, `unrealized`, `equity`, `position`; `position` = `side * layer_count` |
| `signals.csv` | Tín hiệu EMA từng bar |
| `validation.json`, `validation.csv` | Validation OHLCV |
| `equity.png` | Tùy chọn khi `outputs.plot: true` |

Không có `--store`: chạy lại cùng config sẽ ghi đè artifact. Không có duplicate-ID guard, không có
config hash/data fingerprint, không có SQLite row.

Metric trong `summary.json` dùng `compute_metrics` trên **per-layer trades**. Vì vậy `trade_count`,
`win_rate`, `profit_factor`, `average_trade` là theo layer, không phải theo basket. Muốn đánh giá basket,
dùng `baskets.csv` (`pnl`, `exit_reason`, `layer_count`). Các layer trong cùng basket không độc lập.

## 7. Test

`python/tests/test_bounded_basket.py` gồm 28 test:

- mở layer, average entry, take profit, equity và `position`;
- cap `max_layers` và `max_total_units`, `blocked_add_bars`, `hard_limits`;
- tối đa một layer / bar;
- loss cap không cost và có commission (fill 1,0805, pnl đúng -100);
- TP đóng mọi layer cùng fill;
- tín hiệu ngược chiều bật/tắt;
- DCA và grid lệch nhau sau gap fill;
- validation config/dataset;
- CLI ghi artifact, từ chối config sai và boolean sai;
- hai config demo trong `configs/` load/validate được.

Chạy gần nhất: **198 passed** cho toàn bộ suite (170 test trước đó + 28 test bounded basket).

## 8. Giới hạn

- Chỉ một basket tại một thời điểm; không có multi-symbol, portfolio hay nhiều basket song song.
- Không có MQL5/EA tương ứng; không có Strategy Tester, không có execution.
- Không nối experiment store; không có config hash, data fingerprint hay chống ghi đè theo ID.
- Không mô hình margin/leverage/margin call. Với `max_total_units` lớn, notional có thể vượt equity mà
  simulator không dừng; đây là lựa chọn nghiên cứu, không phải mô phỏng tài khoản thật.
- Không mô hình tick path: thứ tự exit/add trong bar là quy ước; loss-first và one-add-per-bar là bảo thủ.
- Loss cap là lỗ ròng theo công thức, nhưng gap có thể làm vượt cap; đọc `loss_cap_overshoot`.
- Không có partial fill, requote, latency, spread biến động, swap hay weekend gap ngoài bar có sẵn.
- Không có bằng chứng hiệu năng: demo synthetic lỗ; không dùng để tăng size hay triển khai live.
