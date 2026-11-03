# Phase 7 — AI/ML baseline

- **Trạng thái:** `DONE` (2026-10-27).
- **Phạm vi:** label hướng giá có horizon, feature causal, chia thời gian có purge, walk-forward
  expanding-window, logistic regression, metric phân loại và mô phỏng chiến lược sau chi phí.
- **Không bao gồm:** ONNX/MQL5 inference, hyperparameter search quy mô lớn, portfolio/multi-symbol,
  calibration xác suất, execution thật, Strategy Tester MT5.
- **Cảnh báo:** toàn bộ kết quả demo dùng dữ liệu **synthetic**; không phải kết quả thị trường và không
  phải khuyến nghị giao dịch.

## 1. Deliverables

| Deliverable | Vị trí |
|---|---|
| Feature pipeline causal | `python/src/mt5_ea_ai_lab/features/basic.py` |
| Label hướng giá + horizon/dead zone | `python/src/mt5_ea_ai_lab/labels/direction.py` |
| Chia thời gian và purge | `python/src/mt5_ea_ai_lab/models/splits.py` |
| Logistic regression + JSON artifact | `python/src/mt5_ea_ai_lab/models/logistic.py` |
| Model card | `python/src/mt5_ea_ai_lab/models/card.py` |
| Metric phân loại và chọn threshold | `python/src/mt5_ea_ai_lab/evaluation/ml.py` |
| Mô phỏng chiến lược dựa trên dự đoán | `python/src/mt5_ea_ai_lab/backtest/ml_strategy.py` |
| CLI train/evaluate | `scripts/train_ml_baseline.py` |
| Sinh dataset demo | `scripts/generate_synthetic_ml_dataset.py` |
| Config mẫu runnable | `configs/ml_baseline.example.yaml` |
| Dataset demo synthetic | `datasets/samples/synthetic_ml_demo.csv` |
| Test feature/label | `python/tests/test_features_labels.py` |
| Test split/model/metric | `python/tests/test_ml_splits_model.py` |
| Test mô phỏng chiến lược | `python/tests/test_ml_strategy.py` |
| Test CLI + store | `python/tests/test_train_ml_cli.py` |
| Hướng dẫn ML baseline | `docs/reference/ml-baseline.md` |
| Báo cáo Phase 7 | `docs/phase-reports/phase-7.md` |

## 2. Quyết định thiết kế

- **Label được định nghĩa trước model:** `future_return[t] = close[t+horizon]/close[t] - 1`; nhãn `1`
  khi vượt `+min_return`, `0` khi dưới `-min_return`, bỏ các biến động trong dead zone và các bar cuối
  không đủ horizon. `label_end_bar_index` được lưu để purge.
- **Feature chỉ dùng dữ liệu đến bar `t`:** 12 feature từ return, EMA, volatility, stochastic, range,
  body và volume z-score. Test causality sửa toàn bộ dữ liệu tương lai và xác nhận feature quá khứ không
  đổi.
- **Purge theo label horizon, không theo số dòng:** sample bị loại nếu `label_end_bar_index` chạm segment
  kế tiếp. Bốn integrity check được ghi vào `split_plan.json`; CLI dừng nếu bất kỳ check nào false.
- **Threshold chọn trên out-of-fold validation:** grid 0.30–0.70, metric balanced accuracy, tie-break gần
  0.5. Test cuối không tham gia chọn feature, hyperparameter hay threshold.
- **Fit cuối trên train + validation:** sau khi chọn threshold, model được fit lại trên hai segment đã
  purge; test chỉ được đánh giá một lần.
- **Artifact JSON thay vì pickle:** scaler mean/scale, coefficient, intercept, hyperparameter, feature
  schema, phiên bản code và dependency. Inference bằng NumPy; không unpickle object Python.
- **Tách metric phân loại khỏi metric chiến lược:** accuracy/balanced accuracy/ROC-AUC/Brier không được
  trình bày như lợi nhuận. Mô phỏng chiến lược dùng cùng cost model của Phase 4.
- **Mô phỏng không chồng lấn:** vào lệnh tại open bar kế tiếp, thoát tại open sau `horizon` bar; dự đoán
  chồng lấn bị bỏ qua để tránh tạo position liên tục không có căn cứ.
- **Benchmark không ML:** majority classifier cho phân loại; momentum rule (trailing return) và buy &
  hold cho chiến lược.
- **Fail closed:** thiếu feature/label hợp lệ, split check false, artifact sai schema, xác suất ngoài
  `[0, 1]` hoặc bar range không hợp lệ đều dừng chương trình.
- **Store tái sử dụng Phase 6:** run ML lưu `config_hash`, `data_fingerprint`, git state, metric, artifact
  hash; ID trùng bị từ chối. Không thêm field credential.

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả thực tế |
|---|---|
| `.venv\Scripts\python.exe scripts\generate_synthetic_ml_dataset.py` | Exit code `0`; 1.800 nến M5 EURUSD synthetic; seed 20261027 |
| `.venv\Scripts\python.exe scripts\train_ml_baseline.py --config configs\ml_baseline.example.yaml` | Exit code `0`; threshold 0.50; test ROC-AUC 0.5708; balanced accuracy 0.5584 |
| `train_ml_baseline.py ... --store --db experiments\phase7-demo.sqlite --experiment-id phase7-demo-store` | Exit code `0`; row `completed`; 10 artifact có hash |
| Chạy lại cùng ID `phase7-demo-store` | Exit code **4**; `duplicate_experiment`; row và artifact cũ không đổi |
| `.venv\Scripts\python.exe -m pytest -q` | **143 passed in 8.55s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

### Kết quả demo (synthetic)

Dataset `datasets/samples/synthetic_ml_demo.csv`: 1.800 bar; feature còn 1.787 dòng sau warm-up 13 bar;
label giữ 1.507 dòng (784 positive/723 negative, bỏ 290 dead-zone và 3 tail). Sau purge còn
894 train / 296 validation / 299 test.

| Hạng mục | Giá trị |
|---|---|
| OOF samples / ROC-AUC / balanced accuracy | 595 / 0.5443 / 0.5479 |
| Threshold chọn | 0.50 |
| Test samples | 299 (187 positive, 112 negative) |
| Test ROC-AUC | 0.5708 |
| Test balanced accuracy | 0.5584 |
| Test accuracy / F1 | 0.5686 / 0.6346 |
| Test Brier score | 0.2483 |
| Test precision / recall | 0.6747 / 0.5989 |
| Majority-class accuracy / balanced accuracy | 0.6254 / 0.5000 |

| Chiến lược (cùng test window, horizon 3) | Trades | Net profit | Return | Max drawdown | Exposure |
|---|---|---|---|---|---|
| ML logistic | 84 | -151.60 | -1.52% | 175.40 | 72.6% |
| Momentum rule | 86 | -197.10 | -1.97% | 205.00 | 74.4% |
| Buy & hold | 1 | +295.30 | +2.95% | n/a | 100% |

Model yếu (ROC-AUC 0.5708, balanced accuracy 0.5584), thấp hơn majority classifier về accuracy
(0.5686 so với 0.6254 do class imbalance), và chiến lược ML lỗ sau chi phí, kém buy & hold. Báo cáo giữ
nguyên các con số; không có kết luận lợi nhuận.

Thông tin tái lập: `model_sha256=5c5260f3daec807c1c67b23ec691e1c9047a60ce78c96f311f9a03bf4be859e8`;
config hash `abee20763963a73e1ad18b479d4d5796d1cae40519dbc525265941f69f6215e6`; data fingerprint
`17fc3cc63c23fc94caf64ca44e29b7aa64779f8927b10a23b97ac5f86b47deaf`. Warning của run:
`data_kind_synthetic`, `ml_strategy_not_profitable_after_costs`, `worktree_dirty`.

## 4. Tiêu chí nghiệm thu

| Tiêu chí (roadmap) | Kết quả | Bằng chứng |
|---|---|---|
| Định nghĩa target/label trước model, ghi rõ horizon | Đạt | `labels/direction.py`; `label_schema.json`; `docs/reference/ml-baseline.md` mục 2 |
| Feature chỉ dùng dữ liệu có sẵn tại thời điểm dự đoán | Đạt | `test_features_are_causal` sửa tương lai và so sánh feature quá khứ |
| Baseline đơn giản (logistic regression) | Đạt | `models/logistic.py`; artifact JSON; demo chạy thật |
| Chia train/validation/test theo thời gian, không shuffle | Đạt | `models/splits.py`; `split_plan.json`; `test_time_split_is_chronological_and_purged` |
| Walk-forward/expanding-window validation | Đạt | 3 fold expanding; threshold chọn trên OOF; `classification.folds` |
| Test cuối không dùng chọn feature/threshold/model | Đạt | Threshold chọn trên OOF; test chỉ đánh giá một lần; không có bước tune trên test |
| Đánh giá cả metric dự đoán và metric chiến lược | Đạt | `summary.json` tách `classification` và `strategy`; model card |
| Lưu feature schema, preprocessing, model artifact, model card, dependency | Đạt | `feature_schema.json`, `model.json`, `model_card.md`, `dependencies` |
| Có benchmark không dùng ML | Đạt | Majority classifier; momentum rule; buy & hold |
| Không có data leakage đã biết | Đạt (trong phạm vi đã test) | Purge theo label end; causality test; feature/label tách biệt |
| Metric vẫn được báo khi model không tốt | Đạt | Demo báo AUC 0.5708, strategy lỗ; warning `ml_strategy_not_profitable_after_costs` |
| Không quảng bá dựa trên một metric | Đạt | Báo accuracy, balanced accuracy, ROC-AUC, Brier, confusion, strategy và benchmark cùng lúc |

## 5. Test đã bổ sung

- `test_features_labels.py` (6 test): causality, warm-up/finite, timestamp không tăng/trùng, forward
  label + tail, dead zone, giá không hợp lệ.
- `test_ml_splits_model.py` (8 test): chia thời gian + purge, dataset ngắn, thứ tự dòng, model
  roundtrip/artifact sạch, single-class/thiếu feature, artifact lỗi, chọn threshold, metric degenerate.
- `test_ml_strategy.py` (4 test): entry bar kế tiếp/overlap/incomplete horizon, chi phí, dự đoán không hợp
  lệ, momentum trailing return.
- `test_train_ml_cli.py` (6 test): chạy đủ artifact/model card, tái lập model hash/metric, invalid data
  exit `2`, dataset quá nhỏ exit `3`, `--experiment-id` cần `--store`, ID trùng exit `4` không ghi đè.

Tổng: **24 test Phase 7**; toàn bộ suite **143 passed** (119 test Phase 6 + 24 test Phase 7).

## 6. File đã tạo/sửa

Tạo mới:

- `python/src/mt5_ea_ai_lab/features/basic.py`
- `python/src/mt5_ea_ai_lab/labels/direction.py`
- `python/src/mt5_ea_ai_lab/models/splits.py`
- `python/src/mt5_ea_ai_lab/models/logistic.py`
- `python/src/mt5_ea_ai_lab/models/card.py`
- `python/src/mt5_ea_ai_lab/evaluation/ml.py`
- `python/src/mt5_ea_ai_lab/backtest/ml_strategy.py`
- `scripts/generate_synthetic_ml_dataset.py`
- `scripts/train_ml_baseline.py`
- `configs/ml_baseline.example.yaml`
- `datasets/samples/synthetic_ml_demo.csv`
- `python/tests/test_features_labels.py`
- `python/tests/test_ml_splits_model.py`
- `python/tests/test_ml_strategy.py`
- `python/tests/test_train_ml_cli.py`
- `docs/reference/ml-baseline.md`
- `docs/phase-reports/phase-7.md`

Cập nhật:

- `python/src/mt5_ea_ai_lab/features/__init__.py`, `labels/__init__.py`, `models/__init__.py`,
  `evaluation/__init__.py`, `backtest/__init__.py`
- `README.md`, `docs/reference/architecture.md`, `docs/guides/install-and-test.md`, `docs/reference/testing.md`,
  `docs/reference/risk.md`, `docs/reference/data-dictionary.md`, `datasets/samples/README.md`

Không đổi dependency: `scikit-learn 1.9.1` đã có trong `requirements.txt` từ Phase 0. Không thêm ONNX,
không thêm execution, không thay đổi MQL5 source.

## 7. Vấn đề còn tồn tại

1. **Chất lượng model:** ROC-AUC 0.5708 và balanced accuracy 0.5584 trên synthetic là yếu; không suy ra
   hiệu quả trên dữ liệu thật.
2. **Class imbalance:** accuracy bị chi phối bởi lớp positive (62.5% test); phải đọc balanced accuracy,
   precision/recall và confusion matrix.
3. **Chỉ một symbol/timeframe/horizon:** chưa kiểm tra độ nhạy với horizon, dead zone hay feature set.
4. **Chưa có hyperparameter search:** `C=1.0` cố định; threshold chỉ grid 0.30–0.70.
5. **Chưa walk-forward retrain từng test block:** chỉ expanding-window OOF để chọn threshold và một lần
   fit cuối; kết quả test là single holdout.
6. **Metric chiến lược phụ thuộc giả định chi phí:** spread 8 point, slippage 1 point, commission 1 mỗi
   chiều; không mô hình hóa spread biến động.
7. **Momentum benchmark đơn giản:** trailing 3-bar return, không tối ưu; chỉ là baseline.
8. **Worktree dirty:** mọi run demo có `git_dirty=true`; cần commit Phase 1–7 trước khi dùng kết quả làm
   bằng chứng tái lập mạnh.
9. **Chưa export ONNX/MQL5:** Phase 8 sẽ kiểm tra schema, thứ tự feature, normalization và tolerance.
10. **Chưa chạy MT5 Strategy Tester:** không có kết luận parity hay hiệu năng MT5.
11. **Demo synthetic:** các con số chỉ minh họa pipeline và cách báo cáo trung thực, không phải hiệu
    năng thị trường.

## 8. Kiểm tra thủ công gợi ý

1. Chạy:
   `.\.venv\Scripts\python.exe scripts\train_ml_baseline.py --config configs\ml_baseline.example.yaml`
2. Mở `reports\ml\demo-phase7-ml\summary.json`; xác nhận `split.checks` đều `true`, threshold 0.50,
   metric test và strategy nằm trong cùng file nhưng tách mục.
3. Đọc `model_card.md`; xác nhận có label, feature, split, metric, benchmark, chi phí và giới hạn.
4. Mở `predictions.csv`; xác nhận `label`/`future_return` chỉ để audit và không nằm trong
   `feature_schema.json`.
5. Chạy lại cùng config; xác nhận `model_sha256` và test metric không đổi.
6. Chạy với `--store --experiment-id <unique-id>`; kiểm tra row `completed` và 10 artifact trong
   `experiments\*.sqlite`.
7. Chạy lại cùng ID; xác nhận exit `4` và artifact cũ không đổi.
8. Không đặt secret trong config/notes; không commit `reports/ml` hay database.

## 9. Bước tiếp theo

Phase 8 — ONNX/MQL5 inference: chọn exported model phù hợp, kiểm tra schema/thứ tự feature/normalization,
so sánh dự đoán Python–ONNX trên fixture cố định, tạo EA inference-only (không gửi lệnh) và chạy
Strategy Tester nếu môi trường cho phép. Nếu ONNX/MT5 không tương thích, giữ Python làm môi trường đánh
giá và ghi rõ blocker thay vì tạo workaround chưa xác minh.
