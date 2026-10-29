# Testing — quy ước, metric và test plan

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `testing-guide.md`, `TEST_PLAN.md`.

Nội dung:
1. Hướng dẫn kiểm thử backtester, experiment store, ML, ONNX, pipeline và bounded basket (Phase 4–9)
2. Test plan — Wonderwhales PinePort

---
## Hướng dẫn kiểm thử backtester, experiment store, ML, ONNX, pipeline và bounded basket (Phase 4–9)

- **Phạm vi:** mô phỏng bar-by-bar cho baseline EMA crossover bằng Python, bounded DCA/grid basket,
  metadata run trong SQLite, so sánh hai run, ML baseline (label/feature/split/logistic/model card),
  export/kiểm chứng ONNX và pipeline end-to-end.
- **Trạng thái:** backtester, bounded basket simulator, store, comparator, ML CLI, ONNX export/parity và
  pipeline đã chạy thật; Strategy Tester của MT5 đã chạy 2026-10-29; EA `LabOnnxInference` đã chạy cả
  trên chart lẫn trong Strategy Tester, 24/24 hàng khớp Python (xem `onnx.md` §3.1).
- **Cảnh báo:** mọi kết quả từ `datasets/samples/synthetic_ema_cross_demo.csv` và
  `datasets/samples/synthetic_ml_demo.csv` là synthetic, không phải lịch sử thị trường và không dùng để
  đánh giá lợi nhuận.

### 1. Cách chạy

```powershell
# Từ thư mục gốc repository
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# Chạy toàn bộ test
.\.venv\Scripts\python.exe -m pytest

# Backtest bằng cấu hình mẫu (không ghi experiment store)
.\.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml

# Ghi đè thư mục output
.\.venv\Scripts\python.exe scripts\run_backtest.py `
  --config configs\backtest.example.yaml --out-dir reports\backtests\manual-run

# Backtest có metadata SQLite; artifact vào reports\backtests\<experiment_id>
.\.venv\Scripts\python.exe scripts\run_backtest.py `
  --config configs\experiment.example.yaml `
  --store --experiment-id manual-phase6-001

# Bounded DCA/grid simulator (không dùng experiment store)
.\.venv\Scripts\python.exe scripts\run_basket_backtest.py `
  --config configs\backtest.bounded-basket-synthetic.yaml
.\.venv\Scripts\python.exe scripts\run_basket_backtest.py `
  --config configs\backtest.bounded-grid-synthetic.yaml

# So sánh hai run đã lưu
.\.venv\Scripts\python.exe scripts\compare_experiments.py `
  --db experiments\experiments.sqlite `
  --baseline manual-phase6-001 --run manual-phase6-002

# ML baseline (synthetic demo); thêm --store để ghi metadata
.\.venv\Scripts\python.exe scripts\train_ml_baseline.py `
  --config configs\ml_baseline.example.yaml

# Export ONNX từ model Phase 7 và kiểm tra parity trên fixture cố định
.\.venv\Scripts\python.exe scripts\export_onnx_model.py `
  --model reports\ml\demo-phase7-ml\model.json `
  --out-dir models\candidates\demo-phase7-ml `
  --fixture python\tests\fixtures\onnx_feature_fixture.csv

# Pipeline end-to-end: validate -> backtest -> ML -> store -> report
.\.venv\Scripts\python.exe scripts\run_pipeline.py `
  --config configs\pipeline.example.yaml
```

`run_backtest.py` trả các exit code:

| Code | Ý nghĩa |
|---|---|
| `0` | Backtest hoàn tất |
| `1` | Không đọc được config hoặc dataset |
| `2` | Validation dữ liệu thất bại (`invalid_data`) |
| `3` | Backtest lỗi sau khi đã nạp dữ liệu |
| `4` | `experiment_id` đã tồn tại trong store; không ghi đè |
| `5` | Không mở/ghi được experiment store |

`compare_experiments.py` trả `0` khi comparable, `1` khi không comparable (báo cáo vẫn được ghi) và `2`
khi thiếu database/run hoặc ID không hợp lệ.

`run_basket_backtest.py` trả `0` khi mô phỏng hoàn tất, `1` khi config/dataset không đọc được, `2` khi
validation dữ liệu thất bại và `3` khi mô phỏng lỗi sau khi nạp dữ liệu. CLI này chưa nối experiment
store, không có exit `4/5` và chạy lại cùng config sẽ ghi đè artifact.

`train_ml_baseline.py` trả `0` thành công, `1` lỗi config/dataset, `2` validation dữ liệu lỗi, `3` lỗi
feature/split/train/evaluate, `4` `experiment_id` đã tồn tại và `5` không mở/ghi được store. Artifact ML
nằm trong `outputs.report_dir/<experiment_id>/`:
| File | Nội dung |
|---|---|
| `summary.json` | Config, split/checks, threshold, metric phân loại, metric chiến lược, benchmark, warning |
| `model.json` | Feature schema, scaler mean/scale, coefficient, intercept, hyperparameter, dependency |
| `model_card.md` | Model card dạng đọc được |
| `predictions.csv` | Dự đoán test kèm `label`/`future_return` để audit |
| `fold_predictions.csv` | Dự đoán out-of-fold của walk-forward validation |
| `feature_schema.json`, `label_schema.json`, `split_plan.json` | Schema và integrity check |
| `validation.json`, `validation.csv` | Validation OHLCV của dataset |

`export_onnx_model.py` trả `0` khi export + parity đạt, `1` khi model/fixture/thư mục output không
đọc/ghi được và `2` khi ONNX checker hoặc parity thất bại. Artifact trong `--out-dir`:

| File | Nội dung |
|---|---|
| `model.onnx` | Graph float32: `Sub(mean) → Div(scale) → MatMul(coefficients) → Add(intercept) → Sigmoid` |
| `model_metadata.json` | Opset/IR, input/output shape, thứ tự feature, threshold, hash model JSON/ONNX, kích thước |
| `onnx_parity.json`, `onnx_parity.csv` | Kết quả đối chiếu Python–ONNX trên fixture (chỉ khi truyền `--fixture`) |

`run_pipeline.py` trả `0` khi cả hai stage hoàn tất, `1` config/dataset lỗi hoặc hai stage lệch dataset,
`2` validation dữ liệu lỗi (ML không chạy), `3` stage lỗi sau khi nạp dữ liệu, `4` ID/báo cáo đã tồn tại
và `5` lỗi store. Artifact:

```text
reports/pipeline/<id>-backtest/   # summary, trades, equity, signals, validation
reports/pipeline/<id>-ml/         # summary, model, model card, predictions, split/schema
reports/pipeline/<id>/            # pipeline_summary.json + pipeline_report.md
```

Báo cáo pipeline gắn nhãn demo/synthetic, liệt kê limitation và hash dữ liệu/model. Chạy lại cùng ID bị
từ chối và không ghi đè.

Artifact backtest trong `outputs.report_dir` (khi dùng `--store`: trong `<report_dir>/<experiment_id>`):

| File | Nội dung |
|---|---|
| `summary.json` | Trạng thái, config, metadata dữ liệu, validation, metric, benchmark, signal counts, trades |
| `trades.csv` | Trades ledger |
| `equity.csv` | Equity curve từng bar |
| `signals.csv` | Tín hiệu từng bar kèm EMA prev/now |
| `validation.json`, `validation.csv` | Báo cáo validation của dataset |
| `equity.png` | Tùy chọn khi `outputs.plot: true` |

Không dùng `--store`, chạy lại cùng config và dữ liệu sẽ ghi đè artifact. Có `--store`, ID trùng bị từ chối
và artifact của run khác không bị ghi đè. `reports/`, `experiments/*.sqlite` bị gitignore. Chi tiết store:
[`experiment-store.md`](experiment-store.md).

Bounded basket CLI ghi cùng thư mục `outputs.report_dir` (không có `--store`):

| File | Nội dung |
|---|---|
| `summary.json` | `engine=bounded_basket`, config, `effective_max_layers`, validation, metric, `hard_limits`, `basket_count` |
| `trades.csv` | Mỗi layer một row, thêm `basket_id` và `layer_index` |
| `baskets.csv` | Một row / basket: layer count, units, average entry, PnL, exit reason, blocked bars |
| `equity.csv` | `position` = `side * layer_count` |
| `signals.csv`, `validation.json/csv` | Như backtest thường |
| `equity.png` | Tùy chọn khi `outputs.plot: true` |

Metric trong `summary.json` tính trên per-layer trades, không phải per-basket. Chi tiết quy tắc và giới
hạn: [`bounded-basket.md`](bounded-basket.md).

### 2. Hợp đồng thời gian

1. Tín hiệu tại bar `i` chỉ dùng close của các bar `0..i`; không dùng dữ liệu tương lai.
2. Tín hiệu được **thực thi tại open của bar `i+1`**. Không có same-bar execution.
3. Tín hiệu ở bar cuối cùng không có bar kế tiếp nên không được thực thi.
4. Vị thế còn mở khi hết dữ liệu được đóng tại **close của bar cuối** với chi phí exit bình thường và
   `exit_reason=end_of_data`. Đây là quy ước mô phỏng, không phải quyết định chiến lược.
5. Tại open của bar kế tiếp, tín hiệu ngược chiều đóng vị thế hiện tại rồi mở vị thế mới
   (`exit_reason=opposite_signal`). Engine một vị thế không có pyramiding; tối đa một vị thế tại một thời
   điểm. Bounded DCA/grid là simulator riêng: một basket, nhiều layer, quy tắc ở mục 4.2.

### 3. Giá khớp và chi phí

- Giá tham chiếu là open/close/high/low của bar; không dùng tick data.
- Mỗi lần khớp chịu `half_spread + slippage` theo hướng bất lợi:

  ```text
  half_spread = spread_points * point_size / 2
  slippage    = slippage_points * point_size
  buy_fill    = raw_price + half_spread + slippage
  sell_fill   = raw_price - half_spread - slippage
  ```

- `commission_per_side` là tiền tệ quote cho **mỗi lần khớp** (entry và exit), không phải per lot.
- `position_units` là số đơn vị base currency; PnL tính bằng quote currency:
  `(exit_fill - entry_fill) * side * position_units`.
- Không mô hình leverage, margin, margin call, swap/financing, contract size, làm tròn tick size, lot
  constraint, requote, latency hay partial fill.
- Benchmark buy-and-hold dùng cùng `ExecutionConfig`: mua tại open đầu tiên, bán tại close cuối cùng,
  chịu spread/slippage/commission như chiến lược. Benchmark chỉ là baseline, không phải cam kết hiệu năng.

### 4. Stop-loss, take-profit, trailing stop và gap

- SL/TP được neo theo **entry fill**, không theo giá close của tín hiệu:

  ```text
  long  stop  = entry_fill - stop_loss_points  * point_size
  long  target= entry_fill + take_profit_points* point_size
  short stop  = entry_fill + stop_loss_points  * point_size
  short target= entry_fill - take_profit_points* point_size
  ```

- SL/TP được kiểm tra trong cùng bar entry và các bar sau đó bằng high/low.
- Nếu cả SL và TP đều có thể bị chạm trong một bar, **SL được giả định khớp trước**. Đây là quy ước bảo
  thủ; dữ liệu OHLC không cho biết thứ tự thật trong bar.
- Nếu giá mở cửa đã vượt SL (gap), fill là giá mở cửa tệ hơn, không phải giá SL:
  long gap-down → `min(open, stop)`, short gap-up → `max(open, stop)`.
- Nếu giá mở cửa đã vượt TP, fill là giá mở cửa tốt hơn: long gap-up → `max(open, target)`,
  short gap-down → `min(open, target)`.
- Không mô phỏng slippage riêng cho SL/TP ngoài `slippage_points` đã áp dụng cho mọi fill. Gap được xử lý
  bằng open của bar, không bằng tick.

#### 4.1 Trailing stop

- Bật bằng `trailing_stop_points` (khoảng cách, point) và tùy chọn `trailing_activation_points`
  (excursion tối thiểu để bắt đầu kéo). Activation thiếu trailing bị từ chối.
- Long trail dưới `high`, short trail trên `low`; stop chỉ siết, không nới.
- Stop được tính từ bar đã đóng và chỉ có hiệu lực từ **bar kế tiếp**; không giả định chạm trong chính bar
  đã tạo ra nó vì OHLC không cho biết thứ tự high/low.
- Stop tĩnh vẫn là stop ban đầu nếu bật; trailing chỉ thay khi tốt hơn. Gap dùng quy tắc open tệ hơn như SL.
- Stop bị chạm sau khi trailing move ghi `exit_reason=trailing_stop`; trước khi move ghi `stop_loss`.
- Chi tiết, config mẫu và kết quả demo: [`trailing-stop.md`](trailing-stop.md).

#### 4.2 Bounded DCA/grid basket

- Simulator riêng `run_bounded_basket`, một basket tại một thời điểm; không thay engine một vị thế.
- Hard cap: `max_layers`, `max_total_units`, `max_basket_loss` (lỗ ròng), tối đa một layer mỗi bar.
  `effective_max_layers = min(max_layers, floor(max_total_units / layer_units))`.
- Mở layer đầu tại open bar kế tiếp. Level thêm:
  `dca = last_fill - side*step`, `grid = first_fill - side*layer_count*step`.
- Exit được kiểm tra trước add; nếu loss cap và TP cùng trong một bar, loss cap thắng. Layer mới chỉ ảnh
  hưởng level từ bar kế tiếp.
- TP neo theo average entry; loss cap dịch stop theo commission entry + exit để fill tại stop (không gap)
  đúng lỗ ròng. Gap có thể vượt cap; đọc `hard_limits.loss_cap_overshoot`.
- Tín hiệu ngược chiều đóng basket nếu `close_on_opposite_signal: true`; nếu false thì bỏ qua.
- `trades.csv` là per-layer; metric `trade_count`/`win_rate`/`profit_factor` không phải per-basket.
- Chi tiết, công thức, config và demo: [`bounded-basket.md`](bounded-basket.md).

### 5. Định nghĩa metric

| Metric | Định nghĩa |
|---|---|
| `bars` | Số bar có trong equity curve |
| `initial_equity`, `final_equity` | Vốn đầu kỳ và equity sau khi đóng vị thế cuối kỳ |
| `net_profit` | `final_equity - initial_equity` |
| `total_return` | `final_equity / initial_equity - 1` |
| `gross_profit` | Tổng `pnl` của các trade có `pnl > 0` (đã trừ commission) |
| `gross_loss` | Trị tuyệt đối tổng `pnl` của các trade có `pnl < 0` (đã trừ commission) |
| `profit_factor` | `gross_profit / gross_loss`; `null` nếu không có trade lỗ |
| `win_count`, `loss_count` | Số trade lãi/lỗ; trade `pnl = 0` không thuộc cả hai |
| `win_rate` | `win_count / trade_count`; `null` nếu không có trade |
| `average_trade` | Trung bình `pnl` trên mọi trade |
| `average_win`, `average_loss` | Trung bình trade lãi/lỗ; `average_loss` là số âm |
| `expectancy` | Hiện bằng `average_trade` (tiền tệ tuyệt đối), không phải R-multiple |
| `total_commission` | Tổng commission của mọi trade |
| `max_drawdown` | Mức giảm lớn nhất từ đỉnh equity, đơn vị tiền tệ, luôn `>= 0` |
| `max_drawdown_pct` | `max_drawdown` tính theo tỷ lệ đỉnh, luôn `>= 0` |
| `exposure_ratio` | Tỷ lệ bar có vị thế mở tại cuối bar, trước khi đóng vị thế cuối kỳ |
| `exit_reason_counts` | Số trade theo `stop_loss`, `take_profit`, `trailing_stop`, `opposite_signal`, `end_of_data` |
| `sharpe_ratio` | Luôn `null`: chưa định nghĩa return frequency và annualization |

`gross_profit`/`gross_loss` dùng `pnl` sau commission, không dùng cột `gross_pnl` trước commission. Cột
`gross_pnl` trong trades ledger là PnL trước commission nhưng đã gồm spread/slippage.

Bounded basket dùng cùng công thức metric trên **per-layer trades**, nên `trade_count`, `win_rate`,
`profit_factor` và `exit_reason_counts` mô tả từng layer, không phải từng basket. Số basket và lý do
đóng basket nằm riêng ở `basket_count` và `basket_exit_reason_counts`
(`basket_take_profit`, `basket_loss_cap`, `opposite_signal`, `end_of_data`). `hard_limits` chứa cap cấu
hình, giá trị lớn nhất quan sát được, `blocked_add_bars`, `baskets_at_layer_cap`, lỗ ròng tệ nhất và
`loss_cap_overshoot`.

Không báo Sharpe/Sortino/Calmar cho đến khi return series, tần suất và annualization được định nghĩa rõ.

### 6. Trades ledger và equity curve

`trades.csv`:

| Cột | Ý nghĩa |
|---|---|
| `trade_id` | Số thứ tự tăng dần |
| `side` | `long` hoặc `short` |
| `entry_time`, `exit_time` | Timestamp mở bar nơi fill xảy ra (UTC) |
| `entry_bar`, `exit_bar` | Index bar trong dataset |
| `entry_fill`, `exit_fill` | Giá đã gồm spread/slippage |
| `units` | `position_units` |
| `gross_pnl` | PnL trước commission |
| `commission` | Tổng commission entry + exit |
| `pnl` | `gross_pnl - commission` |
| `bars_held` | `exit_bar - entry_bar`; có thể bằng `0` nếu SL/TP chạm trong bar entry |
| `exit_reason` | Lý do đóng vị thế |

`equity.csv`: `timestamp`, `cash`, `unrealized`, `equity = cash + unrealized`, `position`.
`unrealized` đánh giá tại close so với entry fill và **không** trừ chi phí exit giả định. Ở bar cuối,
vị thế bị đóng theo quy ước nên `cash` và `equity` phản ánh PnL đã thực hiện, `position = 0`.

Bounded basket thêm hai cột vào `trades.csv`: `basket_id` và `layer_index`. Mỗi layer là một row, nên
một basket đóng sẽ tạo nhiều row cùng `exit_time`/`exit_fill`/`exit_reason`. `baskets.csv` có một row mỗi
basket: `basket_id`, `side`, `mode`, thời điểm mở/đóng, `layer_count`, `units`, `average_entry`,
`exit_fill`, `gross_pnl`, `commission`, `pnl`, `bars_held`, `exit_reason`, `blocked_add_bars`,
`layer_cap_reached`. `equity.csv` giữ `position = side * layer_count`; `unrealized` cộng excursion của
tất cả layer đang mở.

### 7. Validation và fail-closed

Runner gọi loader và validator trước khi backtest:

- Lỗi validation (timestamp trùng/không tăng, OHLC không nhất quán, giá âm/không hữu hạn, sai symbol/
  timeframe, dataset rỗng) → `status=invalid_data`, exit code `2`, **không** chạy backtest.
- Warning (ví dụ `synthetic_dataset`, gap) không chặn backtest nhưng được ghi trong `validation.json`.
- Loader và validator không tự sửa, sort, deduplicate hay fill dữ liệu.
- Backtest từ chối thêm dữ liệu không hợp lệ tại thời điểm chạy (timestamp, OHLC, NaN/Inf) để tránh chạy
  trên input không rõ nguồn.

### 8. Tái lập

- Không có random trong signal, execution hay metric. `seed` được ghi vào summary và metadata nhưng hiện
  không được dùng; nếu sau này thêm thành phần ngẫu nhiên, seed phải được truyền tường minh.
- Cùng config + cùng dataset tạo ra trades/equity/signals/metric giống nhau. Chỉ `generated_at_utc` và
  đường dẫn tuyệt đối trong summary là khác giữa các lần chạy.
- Test `test_repeated_runs_are_identical` so sánh trực tiếp trades, equity, signals, metrics và benchmark.
- Test `test_generate_signals_has_no_look_ahead` thay đổi close tương lai và xác nhận tín hiệu quá khứ
  không đổi.
- Với `--store`, mỗi run lưu thêm:
  - `config_hash`: hash JSON canonical của data descriptor/strategy/execution/seed; không gồm đường dẫn,
    output hay notes;
  - `data_fingerprint`: SHA-256 byte gốc của dataset;
  - `code_version`, `git_commit`, `git_dirty`.
- Hai run được coi là comparable khi cả hai `completed`, cùng config hash, cùng data fingerprint, cùng
  code version và (nếu có) cùng git commit. Worktree dirty hoặc dữ liệu synthetic chỉ tạo warning; xem
  [`experiment-store.md`](experiment-store.md).

### 9. ML baseline (Phase 7)

- **Label:** `future_return[t] = close[t+horizon]/close[t] - 1`; `1` nếu vượt `+min_return`, `0` nếu dưới
  `-min_return`; dead zone và tail thiếu horizon bị loại. `label_end_bar_index` dùng để purge.
- **Feature:** 12 feature causal; test `test_features_are_causal` thay đổi toàn bộ dữ liệu sau bar 90 và
  xác nhận feature trước bar 90 không đổi.
- **Split:** 60/20/20 theo thời gian, purge theo label horizon; 3 fold expanding-window. CLI dừng nếu một
  trong bốn check trong `split_plan.json` false.
- **Threshold:** chọn trên out-of-fold validation bằng balanced accuracy (grid 0.30–0.70, tie-break gần
  0.5); test không được dùng để chọn feature/threshold/model và chỉ đánh giá một lần.
- **Metric:** confusion matrix, accuracy, balanced accuracy, precision, recall, F1, ROC-AUC, Brier score
  cho phân loại; trade count, net profit, return, drawdown, exposure và exit reason cho mô phỏng chiến
  lược. Không báo Sharpe/Sortino.
- **Benchmark:** majority classifier; momentum rule (trailing 3 bar); buy & hold cùng cost model.
- **Mô phỏng:** entry tại open bar kế tiếp, exit tại open sau `horizon` bar; dự đoán chồng lấn bị bỏ qua;
  spread/slippage/commission áp dụng cho mọi fill.

Demo synthetic (1.800 bar, 1.489 sample sau purge) cho test ROC-AUC 0.5708, balanced accuracy 0.5584;
chiến lược ML lỗ -151.60 sau chi phí, kém buy & hold +295.30. Đây là kết quả nghiên cứu trên fixture,
không phải hiệu năng thị trường. Chi tiết: [`ml-baseline.md`](ml-baseline.md).

### 10. ONNX inference (Phase 8)

- **Graph:** dựng trực tiếp từ `model.json` (không pickle/skl2onnx), opset 13, IR 8, float32, batch động;
  inference shape `[1, 12]` → `[1, 1]`. Mean/scale của StandardScaler nhúng trong graph.
- **Feature order:** lấy từ `model_metadata.json` và phải khớp `feature_schema.json`; nhập sai thứ tự
  hoặc sai số feature bị từ chối, không tự suy diễn.
- **Parity:** `scripts/export_onnx_model.py --fixture ...` so sánh xác suất Python `float64` (từ JSON
  artifact) với ONNX Runtime `float32` trên 24 hàng test synthetic; tolerance tuyệt đối `1e-5`.
  Kết quả thực tế: max abs diff `4.673e-08`, mean `1.953e-08` → PASS.
- **Metadata/hash:** `model_metadata.json` ghi SHA-256 của model JSON và ONNX; dùng để phát hiện artifact
  bị thay đổi trước khi copy sang MT5.
- **EA harness:** `mt5/Experts/LabOnnxInference.mq5` gọi `OnnxCreate`, đặt input/output shape, đọc fixture
  CSV trong `MQL5/Files` và in xác suất; `OnTick` rỗng, không có API giao dịch.
- **Chưa kiểm chứng:** ONNX Runtime trong MT5 (build 5.0.0.6249) và parity runtime. Cần chạy EA thủ công
  theo [`onnx-inference.md`](onnx.md) trước khi kết luận tương thích. Compile 0 errors/0 warnings
  chỉ chứng minh mã hợp lệ, không chứng minh runtime.

### 11. Pipeline end-to-end (Phase 9)

- **Một lệnh:** `scripts/run_pipeline.py --config configs/pipeline.example.yaml`; stage backtest và ML
  dùng chung dataset, cùng experiment store.
- **Kiểm tra trước khi chạy:** hai stage config phải trỏ cùng đường dẫn dataset và cùng
  `data_kind`/`symbol`/`timeframe`; lệch bị từ chối với exit `1`.
- **Fail-safe:** dữ liệu lỗi dừng ở stage backtest (exit `2`, ML `skipped`); ID trùng exit `4` và không
  ghi đè báo cáo; thiếu model ONNX exit `1` khi export.
- **Báo cáo:** `pipeline_summary.json` + `pipeline_report.md` gắn nhãn demo/synthetic, metric chọn lọc,
  SHA-256 dữ liệu/model và limitation cố định.
- **Tái lập:** hai lần chạy khác ID cho cùng metric backtest/ML, data SHA-256 và `model_sha256`. Snapshot
  commit sạch (116 file, commit tạm `d3a9ea39…`, `git status` rỗng) cũng cho kết quả khớp hoàn toàn,
  duplicate exit `4` và ONNX parity 24/24 PASS; cần lặp lại sau commit chính thức. Quy trình ở
  [`end-to-end.md`](pipeline.md) mục 7.

### 12. Phạm vi test hiện có

- `python/tests/test_signals.py`: EMA seed, warm-up, crossover BUY/SELL/HOLD, disabled direction, invalid
  input, no look-ahead, determinism, config/length validation; fixture parity chung.
- `python/tests/test_backtest.py`:
  - hand-computed entry tại open bar kế tiếp, exit cuối kỳ;
  - spread + slippage + commission;
  - SL, TP, SL-vs-TP cùng bar (SL thắng), gap-through-stop;
  - reversal, no-trade, end-of-data close;
  - metric hand-computed (profit factor, drawdown, exposure);
  - reproducibility và input/config rejection.
- `python/tests/test_data_loader.py`, `test_validation.py`: Phase 3.
- `python/tests/test_parity.py`: so sánh signal CSV, tolerance số học, missing row, NaN/empty, duplicate
  key và artifact mismatch (Phase 5).
- `python/tests/test_experiment_store.py`: schema, fingerprint, duplicate ID, terminal transition,
  interrupted/cancelled, artifact hash, JSON NaN rejection, persistence.
- `python/tests/test_run_backtest_store.py`: CLI completed, duplicate exit `4` không ghi đè, invalid_data,
  load error, layout không `--store`, ID không hợp lệ.
- `python/tests/test_experiment_compare.py`, `test_compare_experiments_cli.py`: comparability, delta,
  warning, artifact JSON/CSV/Markdown, exit code `0/1/2`.
- `python/tests/test_features_labels.py`: causality, warm-up/finite, timestamp không tăng/trùng, forward
  label + tail, dead zone, giá không hợp lệ.
- `python/tests/test_ml_splits_model.py`: chia thời gian + purge, dataset ngắn/thứ tự dòng, model
  roundtrip/artifact sạch, single-class/thiếu feature, artifact lỗi, chọn threshold, metric degenerate.
- `python/tests/test_ml_strategy.py`: entry bar kế tiếp/overlap/incomplete horizon, chi phí, dự đoán
  không hợp lệ, momentum trailing return.
- `python/tests/test_train_ml_cli.py`: artifact/model card, tái lập model hash và metric, invalid data
  exit `2`, dataset quá nhỏ exit `3`, `--experiment-id` cần `--store`, ID trùng exit `4`.
- `python/tests/test_onnx_export.py`: export/hash/metadata, roundtrip metadata và threshold, từ chối sai
  shape/feature không hữu hạn, scale âm, tolerance âm, CLI export + parity pass, CLI thiếu feature exit `1`.
- `python/tests/test_pipeline_cli.py`: pipeline hoàn tất + hai row store, ID trùng không ghi đè, dữ liệu
  lỗi dừng trước ML, hai stage lệch dataset bị từ chối, stage config thiếu bị từ chối.
- `python/tests/test_trailing.py`: long/short trail, stop không nới, activation, tham số không hợp lệ;
  `test_backtest.py` thêm integration trailing/activation/static stop/short; CLI config parse và ML từ
  chối trailing.
- `python/tests/test_bounded_basket.py`: layer/TP/equity/position; `max_layers`; `max_total_units`; một
  add mỗi bar; loss cap ròng có/không commission; TP cùng fill; tín hiệu ngược chiều bật/tắt; DCA vs grid
  sau gap; hard-limit report; 11 cấu hình không hợp lệ; dữ liệu rỗng; CLI artifact, config lỗi, cờ không
  phải bool và hai config mẫu validate được.

- `python/tests/test_demo_execution.py`: preset demo `DEMO_ONLY` validate được; `SIMULATION_ONLY` bị từ
  chối cho EA demo và ngược lại; `allow_live_trading=true`, thiếu/TP=0, `InpMaxPositions=2`,
  `InpAllowedSymbols` rỗng bị từ chối; input của preset khớp đúng khai báo `input` trong DemoEA; magic
  demo khác magic mô phỏng; project file mô phỏng không được liệt kê EA demo; chạy
  `validate_demo_execution.py` và `validate-project.py` trên repo.
- `mt5/Scripts/ExecGuardTests.mq5`: 51 vector G1–G51 cho guard matrix (demo/real/contest, trade
  permission, symbol allow-list, TP math, broker stop level, volume normalization, risk budget và 12
  reason token). Compile 0/0; **đã chạy thật trong MetaEditor ngày 2026-10-29**:
  `TEST|RESULT|ALL_PASS|pass=51 fail=0|suite=execguard`. Script tổng hợp, không gọi `OrderSend`.
- `mt5/Scripts/ExecDemoProbe.mq5`: đóng khoảng trống "script synthetic không chứng minh đường gửi lệnh".
  Chạy trên tài khoản demo thật, `InpConfirm=false` mặc định nên không gửi lệnh; `InpConfirm=true` gửi
  **một** lệnh 0.01 rồi đóng ngay qua `ExecOpenMarket`/`ExecClosePosition`. **PASS runtime 2026-10-29**:
  `PROBE|DONE|position=2762481907|deals=2|pnl=-0.24|balance=4999.76` (xem [`../PROGRESS.md`](../PROGRESS.md)
  §45). Probe từ chối chạy trong Strategy Tester và khi `MQL_TRADE_ALLOWED` tắt; bằng chứng này chứng minh
  *transport*, không chứng minh chiến lược có lãi và không có `ENTRY` nào do chính DemoEA gửi.

- `python/tests/test_watch_demo_journal.py`: 13 test cho `scripts/watch_demo_journal.py` — parse đúng 18
  cột và từ chối cột sai, checkpoint chỉ báo dòng appended, dòng EA đang viết dở không bị tiêu thụ, phát
  hiện journal bị ghi đè lại, phân loại `ORDER`/`FAULT`, histogram block reason, exit `1` khi có
  `ENTRY`/`ERROR`, exit `0` khi chỉ có `ENTRY_BLOCKED`, exit `2` khi thiếu journal, kill switch file luôn
  alert, `--quiet` chỉ in dòng alert, và source không chứa trading API.

Chạy gần nhất (bounded DCA/grid, 2026-10-28): **198 passed in 11.26s** trên repo chính. Trước đó:
trailing stop **170 passed in 15.13s**; snapshot Phase 9 **155 passed in 12.69s**.

### 13. Giới hạn và việc cần làm ở phase sau

- Dữ liệu mẫu là synthetic; không có kết luận hiệu năng.
- Chưa chạy MT5 Strategy Tester. `LabSignalExport.mq5` mới compile; parity MQL5/Python vẫn là hạng mục
  thủ công mở (xem [`parity.md`](parity.md)).
- Không mô hình hóa swap, margin, leverage, thanh khoản, requote, latency, weekend gap ngoài bar có sẵn.
- Không có Sharpe/Sortino. Phase 7 có walk-forward expanding-window để chọn threshold và một test holdout,
  nhưng chưa retrain từng test block và chưa có hyperparameter search quy mô lớn.
- Không có portfolio/multi-symbol; mỗi run chỉ một dataset và một vị thế.
- ML baseline chỉ một symbol/timeframe/horizon; kết quả test là single holdout, không phải bằng chứng tổng
  quát hóa trên dữ liệu thật. ONNX đã export và parity offline, nhưng EA chưa chạy trong MT5 và chưa lấy
  feature từ bar hiện tại (chỉ đọc fixture).
- Chưa kiểm tra ONNX Runtime version/provider/giới hạn opset của build MT5; sai lệch float32 chỉ được
  chấp nhận trong tolerance `1e-5`, không phải bitwise.
- Experiment store là SQLite cục bộ: không tự phát hiện process bị kill, chưa có retention, chưa kiểm thử
  ghi đồng thời nhiều process. Database/artifact bị gitignore và phải được sao lưu thủ công nếu cần.
- Comparison chỉ so sánh metadata/metric, không so sánh từng dòng trades/equity.
- `reports/` và artifact backtest bị gitignore; muốn lưu kết quả lâu dài phải sao lưu store + artifact.
- Pipeline end-to-end đã tái lập trên snapshot commit sạch tạm thời; cần lặp lại sau commit chính thức
  và vẫn chưa bao gồm stage ONNX/MT5. Hai stage dùng chung dataset nhưng là hai chiến lược khác nhau.
- Bounded DCA/grid là mô phỏng một basket tại một thời điểm, không có nhiều basket song song, không có
  margin/leverage/margin call và không nối experiment store. Loss cap là lỗ **ròng** nhưng gap qua stop
  vẫn có thể vượt cap; đọc `loss_cap_overshoot`. Metric là per-layer, không phải per-basket, và chưa có
  implementation MQL5/EA hay Strategy Tester cho cơ chế này.
- Demo execution (`PATrendRiderXAUv1DemoEA`) chỉ được kiểm chứng tĩnh và bằng guard contract test; chưa
  có bằng chứng chạy dry-run/entry trên tài khoản demo thật. Slippage, partial fill, requote và swap do
  broker quyết định, không được mô hình hóa. Không suy ra hiệu năng chiến lược từ journal demo.

## Test plan — Wonderwhales PinePort

- **Ngày:** 2026-10-28
- **Phạm vi:** contract, indicator, EA signal-only và comparator.
- **Nguyên tắc:** compile không thay thế runtime test; unit test không thay thế parity; không tuyên bố PASS
  cho bước chưa chạy.

### 1. Ma trận kiểm thử

| ID | Lớp | Nội dung | Công cụ | Trạng thái |
|---|---|---|---|---|
| T1 | Static | File bắt buộc, buffer 0–17, mode 0–3, 13 input, 36 test ID, không API giao dịch | `scripts/validate_pineport.py` | PASS |
| T2 | Compile | Indicator + contract tests + EA, đọc log UTF-16 | `scripts/build_pineport.ps1` | PASS (0 error/0 warning) |
| T3 | Unit (MQL5) | 36 vector A–E cho dir/flip, mode gate, confirmed gate, cross, missing | `WonderwhalesContractTests.mq5` | **PASS 36/36** (2026-10-28) |
| T3b | Unit (MQL5) | 47 vector A–H cho bucket, flag, sweep, pivot, setup, tracking, CLX, RMA/clamp | `LongKacoVSAContractTests.mq5` | **PASS 47/47** |
| T3c | Unit (MQL5) | 82 vector A–O cho clamp/MA/series, regime, ribbon, zone, structure, candle, MTF, setup, score, risk, gates, state, hash | `TMFusionZonesContractTests.mq5` | **PASS 82/82** |
| T3d | Unit (MQL5) | 119 vector A–P cho math/time, series, pivot, structure, pattern, liquidity, zone, candle, score, MTF, regime, plan, state, gates, hash, bar policy | `PriceActionMTFContractTests.mq5` | **PASS 120/120** |
| T3e | Unit (MQL5) | 105 vector A–O cho math/time, volume/VSA/OBV, session, structure, event ring, zones/FVG/OB, candles, indicators, scoring, MTF, plan/gates, state TP 3 tầng, hash, bar policy, normalize | `TMXAUSignals2ContractTests.mq5` | **PASS 107/107** |
| T3f | Unit (MQL5) | 155 vector A–P cho math/time, VWAP/session, structure, zones, candle, gates, plan TP 3 tầng, normalize | `TMIndicator2ContractTests.mq5` | **PASS 155/155** |
| T4 | Unit (Python) | Comparator: schema, khóa, tolerance, NaN, filter, warm-up, offset, CLI | `pytest python/tests/test_pine_parity.py` | PASS |
| T4b | Unit (Python) | Audit CSV EA: thứ tự, căn timeframe, đồng nhất symbol/mode/hash, giá rỗng, ATR âm, `detected_at` | `pytest python/tests/test_signal_audit.py` | PASS |
| T5 | Runtime indicator | Gắn indicator lên chart, kiểm tra plot/buffer, không repaint | MT5 thủ công | **NOT_RUN** |
| T6 | Runtime EA | EA đọc `shift=1`, ghi CSV đúng schema, không trùng | MT5 thủ công | **NOT_RUN** |
| T7 | Strategy Tester | Chạy EA trong tester, đọc Journal/Experts | MT5 thủ công | **PASS một phần** — 13/15 scenario EA mô phỏng; 2 `plan_*` `BLOCKED_PERFORMANCE` |
| T8 | Parity | So CSV Pine thật với CSV EA | `scripts/compare_pine_exports.py` | **BLOCKED** (thiếu reference) |

### 2. T1 — Static validation

```powershell
.venv\Scripts\python.exe scripts\validate_pineport.py
```

Kỳ vọng: `VALIDATION_OK: pass=... fail=0`, exit 0.

Kiểm tra: contract version, enum buffer/mode, 18 `SetIndexBuffer`, plot 0–2 là `INDICATOR_DATA`,
iBands buffer 0/1/2, EA `iCustom` + `shift=1`, header CSV 14 cột, 13 input, đủ 36 test ID, không
`OrderSend`/`CTrade`/`WebRequest`/`AccountInfo`.

### 3. T2 — Compile

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1
```

Kỳ vọng: cả bảy file `0 errors, 0 warnings`, exit 0. Script đọc nội dung log, không tin exit code của
MetaEditor (CLI có thể trả 1 dù log thành công).

Nếu MetaEditor ở đường dẫn khác:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1 `
  -MetaEditorPath "D:\MetaTrader 5\MetaEditor64.exe"
```

Deploy vào data folder MT5 (copy + compile, không mở terminal):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1          # dry run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply   # copy + compile
```

### 4. T3 — 36 vector hợp đồng

1. Sync `mt5/Scripts/WonderwhalesContractTests.mq5` và `mt5/Include/PinePort/WonderwhalesContract.mqh`
   vào data folder.
2. Compile (T2).
3. Kéo script vào một chart bất kỳ, chọn OK. Script không đọc dữ liệu thị trường, không giao dịch.
4. Tab **Experts** phải có `TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0`.

Nếu fail: đọc từng dòng `TEST|...|FAIL` để biết ID và giá trị thực. Không sửa test để khớp code nếu
contract đúng.

**Trạng thái hiện tại:** **PASS 36/36** trong Strategy Tester (2026-10-28); wrapper chạy một lần từ
`OnTick`. Bằng chứng: `reports/build/contract-reports/results.txt`.

#### 4b. T3c — 82 vector TM Fusion Zones

1. Sync `mt5/Scripts/TMFusionZonesContractTests.mq5` và `mt5/Include/PinePort/TMFusionZonesContract.mqh`
   vào data folder.
2. Compile (T2).
3. Kéo script vào chart bất kỳ. Script không đọc dữ liệu thị trường, không giao dịch, không ghi file.
4. Tab **Experts** phải có `TEST|RESULT|ALL_PASS|pass=82 fail=0|contract=1.0.0`.

**Trạng thái hiện tại:** **PASS 82/82** trong Strategy Tester (2026-10-28).

#### 4c. T3d — 119 vector Price Action MTF

1. Sync `mt5/Scripts/PriceActionMTFContractTests.mq5` và
   `mt5/Include/PinePort/PriceActionMTFContract.mqh` vào data folder.
2. Compile (T2).
3. Kéo script vào chart bất kỳ. Script không đọc dữ liệu thị trường, không giao dịch, không ghi file.
4. Tab **Experts** phải có `TEST|RESULT|ALL_PASS|pass=120 fail=0|contract=1.0.0`.

**Trạng thái hiện tại:** **PASS 120/120** trong Strategy Tester (2026-10-28); 3 vector B7/B9/C3/E8
được sửa theo đặc tả sau lần chạy đầu.

#### 4d. T3e — 105 vector TM XAU Signals 2

1. Sync `mt5/Scripts/TMXAUSignals2ContractTests.mq5` và
   `mt5/Include/PinePort/TMXAUSignals2Contract.mqh` vào data folder.
2. Compile (T2).
3. Kéo script vào chart bất kỳ. Script không đọc dữ liệu thị trường, không giao dịch, không ghi file.
4. Tab **Experts** phải có `TEST|RESULT|ALL_PASS|pass=107 fail=0|contract=1.0.0` (105 vector hợp đồng
   + 2 kiểm tra bổ sung C6b/N1b).

**Trạng thái hiện tại:** **PASS 107/107** trong Strategy Tester (2026-10-28).

### 5. T4 — Python comparator tests

```powershell
.venv\Scripts\python.exe -m pytest python\tests\test_pine_parity.py -q
```

Kỳ vọng: toàn bộ pass. Test dùng dữ liệu tổng hợp trong thư mục tạm; không phải parity thật.

### 6. T5 — Indicator runtime

1. Sync `mt5/Indicators/PinePort/Wonderwhales.mq5` và include.
2. Compile, mở chart EURUSD M5 (hoặc symbol/timeframe đã chốt).
3. Kéo indicator vào chart; kiểm tra:
   - PSAR line vẽ liên tục sau warm-up.
   - Mũi tên BUY/SELL chỉ xuất hiện ở nến đã đóng.
   - Không có mũi tên nhấp nháy trong nến đang chạy.
4. Mở Data Window, kiểm tra 3 plot có giá trị; buffer chẩn đoán không hiển thị.
5. Đổi mode và input; xác nhận tín hiệu đổi theo mode, không có lỗi journal.
6. Ghi lại build, symbol, timeframe, khoảng ngày, mode và ảnh/log.

**Chưa chạy:** không được ghi PASS.

### 7. T6 — EA runtime

1. Sync `PineSignalLabEA.mq5`, include `LabLogger.mqh` và `PinePort/WonderwhalesContract.mqh`.
2. Compile EA; gắn vào cùng chart với indicator.
3. Kiểm tra Journal:
   - `event=init` có `input_hash`.
   - Không có `indicator_create_failed`, `copy_time_failed`, `buffer_copy_failed` lặp vô hạn.
   - Khi có tín hiệu: `event=signal` với `bar_open`, `confirmed_at`, `signal_id`.
4. Kiểm tra `MQL5/Files/pine_signal_log.csv`:
   - Header đúng 14 cột.
   - Mỗi `bar_open_time` chỉ một dòng.
   - `confirmed_at = bar_open_time + timeframe`.
   - Audit: `.venv\Scripts\python.exe scripts\audit_signal_csv.py --csv <csv> --offset-minutes 180`;
     exit 0 và `status=ok`.
5. Khởi động lại EA; xác nhận không ghi lại bar cuối đã có trong CSV.
6. Không có lệnh nào được gửi; không có truy cập tài khoản.

**Chưa chạy:** không được ghi PASS.

### 8. T7 — Strategy Tester

1. `Ctrl+R`, chọn `PineSignalLabEA`, symbol/timeframe, khoảng ngày.
2. Modeling mode phù hợp; EA không có execution nên kết quả là log tín hiệu, không phải P&L.
3. Đọc Journal/Experts và CSV trong `MQL5/Files` (tester dùng thư mục riêng).
4. Ghi lại build, khoảng ngày, số tín hiệu, lỗi.

**Chưa chạy.** Không dùng kết quả này để tuyên bố lợi nhuận.

### 9. T8 — Parity

Xem [`PINE_PARITY_Wonderwhales.md`](../indicators/parity.md). Cần CSV reference thật từ Pine.
Không tạo CSV giả. Trạng thái hiện tại: `BLOCKED`.

### 10. Tiêu chí dừng

Một thay đổi logic chỉ được merge khi:

- T1 và T2 pass.
- T4 pass.
- Nếu thay đổi chạm logic tín hiệu: cập nhật contract + vector, chạy T3 và ghi kết quả thật.
- Nếu thay đổi chạm CSV/schema: cập nhật comparator + test, chạy T4.
- Không thêm API giao dịch hoặc kết nối broker.

## Test plan — LabSignal runtime + Strategy Tester (2026-10-29)

Bổ sung cho các ma trận phía trên: lần đầu chạy runtime cho `LabSignalEngineTests.mq5`, parity EMA,
runtime ONNX và Strategy Tester cho `LabSignalEA.mq5`. Mọi số liệu dưới đây lấy từ log thật của terminal
build 6292 trên `XAUUSDm`, không suy ra từ lần chạy trước.

### 1. Ma trận

| ID | Lớp | Nội dung | Công cụ | Kết quả |
|---|---|---|---|---|
| L1 | Static | Bố cục, quét API bị cấm, placeholder, cấu trúc EA mô phỏng/demo, preset | `scripts/validate-project.py` | `checks=14 fail=0` |
| L2 | Static | Phạm vi ADR 0003, guardrail DemoEA, order probe, journal watcher | `scripts/validate_demo_execution.py` | `checks=8 fail=0` |
| L3 | Static | Preset mô phỏng + snapshot cấu hình | `scripts/validate_sim_configs.py` | `checked=7 fail=0` |
| L4 | Compile | 30 nguồn MQL5 (thêm `Indicators.mqh`, `SignalEngine.mqh`, `LabSignalEngineTests`, `LabSignalExport`, `LabSignalEA`, `LabOnnxInference`) | `scripts/build-mql5.ps1` | **BUILD_OK 30 source(s), 0 errors, 0 warnings** |
| L5 | Unit MQL5 | Engine mua/bán/giữ, insufficient bars, config/giá không hợp lệ, deterministic | `LabSignalEngineTests.mq5` | **PASS `pass=53 fail=0`**, `TEST\|RESULT\|ALL_PASS` (2026-10-29 14:28:37) |
| L6 | Parity EMA | EMA window MQL5 ↔ Python trên fixture chuẩn hóa | `LabSignalExport` + `scripts/compare_signals.py` | **PASS** (fixture đúng; xem ghi chú sự cố fixture sai bên dưới) |
| L7 | Runtime ONNX | Nạp `model.onnx`, chạy 24 hàng fixture, so `probability` với Python | `LabOnnxInference.mq5` + `onnx_parity` | **PASS 24/24**, max abs `4.927e-08`, mean `1.997e-08`, tol `1e-5`; provider CPU (CUDA/TensorRT fail trên máy này) |
| L8 | Strategy Tester | `LabSignalEA` signal-only, kỳ vọng 0 trade | `terminal64.exe /config:...\lab_signal_ea_m5.ini` | **PASS** — xem §2 |
| L9 | Python | Toàn bộ suite | `pytest -q` | **372 passed in 15.73s** (chạy lại 2026-10-29) |

### 2. L8 — Strategy Tester `LabSignalEA`

| Trường | Giá trị thật |
|---|---|
| Terminal | MetaTrader 5 EXNESS x64 **build 6292** |
| Symbol / period | `XAUUSDm` / `M5` |
| Khoảng dữ liệu | 2026.09.01 – 2026.10.28 |
| Model | 1 minute OHLC |
| Deposit | 5 000 USD, leverage 1:100 |
| Ticks / bars | 225 340 ticks, 11 285 bars, `invalid_bars=0` |
| Signal | `BUY_OK=219`, `SELL_OK=212`, `HOLD_NO_CROSS=10 854` |
| Trade | **0** (đúng kỳ vọng: EA signal-only, không có API gửi lệnh) |
| Kết quả tester | `successfully finished` trong `0:00:00.407` |
| Balance cuối | `5000.00 USD` |

Artifact (bị gitignore, lưu cục bộ): `reports/build/tester-reports/lab_signal_ea_m5/`
(`lab_signal_ea_m5.htm`, `.png`, `lab_signal_ea_signals.log.gz`, `summary.json` với `status: pass`,
`evidence_sha256`).

Cách chạy lại:

```powershell
# MT5 phải đóng trước khi chạy headless
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\lab_signal_ea_m5.ini"
```

### 3. Sự cố fixture sai (ghi lại để không lặp)

Lần đối chiếu EMA đầu tiên dùng nhầm fixture (fixture của cặp/khung khác), khiến comparator báo mismatch
trong khi code không sai. Đã dừng, đối chiếu lại đúng fixture chuẩn hóa trong `python/tests/fixtures/`,
rồi chạy lại: PASS. Bài học: mọi kết quả parity phải ghi rõ đường dẫn fixture và hash; không "sửa code cho
khớp fixture" khi chưa xác nhận fixture đúng.

### 4. Điều kiện môi trường đã phát hiện

- Algo Trading của terminal được lưu ở `config\common.ini` mục `[Experts] Enabled=`. Khi tắt, mọi EA có guard
  `terminal_trade_disabled` sẽ từ chối `OnInit` với mã 1 — đây là fail-closed đúng thiết kế, không phải bug EA.
- `common.ini` bị ghi đè 0 byte trong lúc sự cố công cụ; đã dựng lại tối thiểu (`Enabled=1`, `Account=0`,
  `Profile=0`) và terminal tự bổ sung phần còn thiếu. Hệ quả: terminal mất phiên đăng nhập tự động và cần
  người dùng đăng nhập một lần bằng hộp thoại `Login` (không tự động hóa bước xác thực).
