# ML baseline — Phase 7

- **Trạng thái:** triển khai và chạy thật trên dữ liệu **synthetic**; không phải kết quả thị trường.
- **Mã nguồn:** `features/basic.py`, `labels/direction.py`, `models/splits.py`,
  `models/logistic.py`, `models/card.py`, `evaluation/ml.py`, `backtest/ml_strategy.py`.
- **CLI:** `scripts/train_ml_baseline.py`.
- **Cấu hình mẫu:** `configs/ml_baseline.example.yaml`.

## 1. Mục tiêu và phạm vi

Phase 7 trả lời câu hỏi: với một định nghĩa label rõ ràng và quy trình chia thời gian có purge, một
baseline logistic regression có tạo ra thông tin dự đoán ngoài mẫu hay không, và nếu có thì kết quả mô
phỏng chiến lược ra sao sau chi phí.

Phạm vi:

- một symbol, một timeframe, một horizon;
- feature chỉ từ OHLCV và volume có sẵn;
- model logistic regression chuẩn hóa;
- test cuối chỉ dùng một lần để báo cáo;
- không có ONNX, không có MQL5 inference, không có execution.

## 2. Label

`make_direction_labels` định nghĩa:

```text
future_return[t] = close[t + horizon] / close[t] - 1
label[t] = 1 nếu future_return[t] >  min_return
label[t] = 0 nếu future_return[t] < -min_return
bị loại   nếu |future_return[t]| <= min_return hoặc không có đủ horizon
```

- `horizon = 3` nến, `min_return = 0.00015` trong demo.
- `label_end_bar_index = bar_index + horizon`; trường này được dùng để purge.
- Label dùng giá tương lai nên **không bao giờ** được đưa vào feature matrix.
- `predictions.csv` có cột `label` và `future_return` chỉ để audit; model không đọc hai cột này.

## 3. Feature pipeline

12 feature, tất cả tính từ dữ liệu đến bar `t`:

| Feature | Công thức ngắn |
|---|---|
| `return_1`, `return_3`, `return_5`, `return_10` | `close.pct_change(k)` |
| `ema_gap` | `(EMA_fast - EMA_slow) / close` |
| `ema_slope` | `(EMA_fast[t] - EMA_fast[t-1]) / close` |
| `volatility` | độ lệch chuẩn rolling của return 1 bar |
| `return_z` | `return_1 / volatility` |
| `stochastic` | vị trí close trong rolling high/low |
| `range_ratio` | `(high - low) / close` |
| `body_ratio` | `(close - open) / close` |
| `volume_z` | z-score rolling của `tick_volume` |

Warm-up (demo: 13 bar) bị loại, không forward-fill. Nếu timestamp trùng/không tăng hoặc OHLC không hợp
lệ, pipeline dừng thay vì tự sửa dữ liệu. Feature EMA dùng `ewm(adjust=False)`; đây là baseline nghiên
cứu, **không** tuyên bố parity với EMA MQL5 (parity thuộc Phase 5).

Test `test_features_are_causal` thay đổi toàn bộ OHLC/volume sau bar 90 và xác nhận mọi feature trước
bar 90 không đổi.

## 4. Chia dữ liệu và purge

- Chia theo thứ tự thời gian: 60% train, 20% validation, 20% test (trên các dòng đã có feature + label).
- Một dòng bị purge khỏi train nếu `label_end_bar_index >= bar_index` đầu tiên của validation; tương tự
  giữa validation và test.
- Với walk-forward expanding window: 3 fold; mỗi fold train từ đầu chuỗi đến trước validation fold,
  validation là một khối thời gian kế tiếp; fold cuối vẫn purge trước test.
- Test không tham gia chọn feature, hyperparameter hay threshold. Threshold được chọn trên dự đoán
  out-of-fold của các fold validation bằng **balanced accuracy**, tie-break gần 0.5.
- Model cuối được fit lại trên train + validation (đã purge), threshold giữ nguyên, rồi test được đánh
  giá một lần.

`split_plan.json` ghi kích thước từng segment, từng fold và bốn integrity check:
`train_labels_end_before_validation`, `train_labels_end_before_test`,
`validation_labels_end_before_test`, `chronological_segments`. CLI dừng nếu bất kỳ check nào false.

## 5. Model và artifact

- StandardScaler + Logistic Regression (`solver=lbfgs`, L2, `C=1.0`, `max_iter=1000`, seed 42).
- Artifact `model.json` chứa tên feature, mean/scale, coefficient, intercept, hyperparameter, phiên bản
  code và dependency. Inference dùng NumPy, **không unpickle** object Python.
- Threshold và lý do chọn nằm trong artifact và `summary.json`.
- `model_card.md` ghi data, label, feature, split, metric, benchmark, chi phí và giới hạn.

## 6. Kết quả demo (synthetic, 2026-10-27)

Dataset: `datasets/samples/synthetic_ml_demo.csv`, 1.800 nến M5 EURUSD **synthetic**, sinh bằng
`scripts/generate_synthetic_ml_dataset.py` với seed cố định.

| Hạng mục | Giá trị |
|---|---|
| Feature rows (sau warm-up 13 bar) | 1.787 |
| Dòng có feature + label trước purge | 1.507 (784 positive/723 negative) |
| Train / validation / test sau purge | 894 / 296 / 299 (tổng 1.489) |
| Walk-forward folds | 3 (199, 200, 196 validation sample) |
| OOF ROC-AUC | 0.5443 |
| Threshold chọn trên OOF | 0.50 |
| Test ROC-AUC | 0.5708 |
| Test balanced accuracy | 0.5584 |
| Test accuracy / F1 | 0.5686 / 0.6346 |
| Test Brier score | 0.2483 |
| Majority-class accuracy / balanced accuracy | 0.6254 / 0.5000 |

Metric phân loại **không** phải kết quả giao dịch. Với cùng cửa sổ test, horizon 3 bar, spread 8 point,
slippage 1 point, commission 1 mỗi chiều và 10.000 unit:

| Chiến lược | Trades | Net profit | Total return | Max drawdown | Exposure |
|---|---|---|---|---|---|
| ML logistic | 84 | -151.60 | -1.52% | 175.40 | 72.6% |
| Momentum rule (trailing 3 bar) | 86 | -197.10 | -1.97% | 205.00 | 74.4% |
| Buy & hold | 1 | +295.30 | +2.95% | n/a | 100% |

Kết quả này cho thấy model yếu, chiến lược ML lỗ sau chi phí và kém buy & hold trong giai đoạn test.
Báo cáo giữ nguyên kết quả; không có kết luận lợi nhuận hay khuyến nghị tăng position size.

## 7. Lệnh và artifact

```powershell
# Chạy demo
.\.venv\Scripts\python.exe scripts\train_ml_baseline.py `
  --config configs\ml_baseline.example.yaml

# Lưu metadata vào SQLite; ID trùng trả exit 4
.\.venv\Scripts\python.exe scripts\train_ml_baseline.py `
  --config configs\ml_baseline.example.yaml `
  --store --db experiments\experiments.sqlite --experiment-id phase7-demo-001
```

Exit code: `0` thành công; `1` lỗi config/dataset; `2` validation dữ liệu lỗi; `3` lỗi
feature/split/train/evaluate; `4` ID đã tồn tại; `5` store lỗi.

Artifact trong `reports/ml/<experiment_id>/`:

- `summary.json` — toàn bộ cấu hình, metric, benchmark, warning, hash;
- `model.json` — model artifact JSON;
- `model_card.md` — model card;
- `predictions.csv` — dự đoán test kèm label/future return để audit;
- `fold_predictions.csv` — dự đoán OOF;
- `feature_schema.json`, `label_schema.json`, `split_plan.json`;
- `validation.json`, `validation.csv`.

## 8. Chống leakage và fail-safe

- Feature builder từ chối timestamp trùng/không tăng; label builder từ chối close không dương.
- Purge theo `label_end_bar_index`, không theo số dòng, vì label có thể bị loại do dead zone.
- `tests/test_ml_splits_model.py` kiểm tra label train/validation kết thúc trước segment kế tiếp.
- `tests/test_train_ml_cli.py` kiểm tra dữ liệu lỗi trả `2`, dataset quá nhỏ trả `3`, ID trùng trả `4`,
  và chạy lại cùng config cho cùng model hash/test metric.
- `load_model` từ chối JSON thiếu schema, sai số feature, scaler/coefficient không hữu hạn hoặc scale
  không dương.
- Không có đường execution hay kết nối broker trong module ML.

## 9. Giới hạn

- Dữ liệu demo là synthetic; không suy ra hành vi thị trường thật.
- Một symbol, một horizon, một bộ feature; chưa thử regime detection hay calibration xác suất.
- Accuracy cao có thể chỉ phản ánh class imbalance; phải đọc cùng balanced accuracy, precision/recall,
  ROC-AUC và confusion matrix.
- Chưa mô hình hóa leverage, margin, financing, slippage theo thanh khoản.
- Chưa có walk-forward retraining tự động cho từng test block; Phase 7 dùng expanding-window OOF để chọn
  threshold và một lần fit cuối.
- ONNX đã export và parity Python–ONNX offline đạt (Phase 8), nhưng EA mới compile, chưa chạy trong MT5
  và chưa lấy feature từ bar hiện tại; xem [`onnx-inference.md`](onnx.md).
- Không có bằng chứng live performance; mọi con số chỉ là kết quả nghiên cứu trên dữ liệu đã ghi.
