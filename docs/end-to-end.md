# End-to-end pipeline — Phase 9

- **Trạng thái:** `DONE` (2026-10-27); tái lập trên snapshot commit sạch đã xác minh 2026-10-28. Việc
  commit chính thức vào repository vẫn do người dùng thực hiện.
- **Phạm vi:** một lệnh chạy xuyên suốt load/validate → backtest EMA → ML baseline → experiment store →
  báo cáo tổng hợp, trên cùng một dataset.
- **Không bao gồm:** execution thật, kết nối broker, MT5 Strategy Tester, ONNX runtime MT5, portfolio
  nhiều symbol.
- **Cảnh báo:** cấu hình mẫu dùng dữ liệu **synthetic**; mọi con số chỉ minh họa pipeline, không phải
  hiệu năng thị trường.

## 1. Lệnh chạy

```powershell
# Từ thư mục gốc repository; cần .venv đã cài requirements.txt
.\.venv\Scripts\python.exe scripts\run_pipeline.py `
  --config configs\pipeline.example.yaml
```

Lần chạy đầu dùng `experiment_id: demo-phase9` và database `experiments/phase9-demo.sqlite`. Chạy lại
cùng `experiment_id` bị từ chối (exit `4`) và không ghi đè báo cáo. Muốn chạy lần mới, truyền ID khác:

```powershell
.\.venv\Scripts\python.exe scripts\run_pipeline.py `
  --config configs\pipeline.example.yaml --run-id demo-phase9-b
```

## 2. Cấu hình

[`configs/pipeline.example.yaml`](../configs/pipeline.example.yaml):

| Field | Ý nghĩa |
|---|---|
| `experiment_id` | Tiền tố ID; stage dùng `<id>-backtest` và `<id>-ml` |
| `backtest_config` | Config backtest, phải trỏ cùng dataset với ML |
| `ml_config` | Config ML baseline |
| `outputs.report_dir` | Thư mục gốc cho cả hai stage và báo cáo tổng hợp |
| `store.db` | SQLite experiment store dùng chung cho hai stage |

Pipeline kiểm tra hai stage config dùng **cùng đường dẫn dataset** và cùng `data_kind`/`symbol`/
`timeframe`; lệch cấu hình bị từ chối trước khi chạy stage.

`configs/backtest.synthetic-ml.yaml` chạy EMA 8/21 trên `datasets/samples/synthetic_ml_demo.csv` với
cùng chi phí như ML config. `configs/ml_baseline.example.yaml` giữ nguyên baseline Phase 7.

## 3. Stage và exit code

| Stage | Việc làm | Store ID |
|---|---|---|
| `backtest` | Load, validate OHLCV, chạy EMA crossover, ghi trades/equity/signals | `<id>-backtest` |
| `ml` | Feature/label, purge split, walk-forward, logistic, test, mô phỏng chiến lược | `<id>-ml` |
| `report` | Đọc hai `summary.json`, ghi báo cáo demo tổng hợp | không có row riêng |

| Exit code | Ý nghĩa |
|---|---|
| `0` | Cả hai stage `completed`; báo cáo tổng hợp đã ghi |
| `1` | Pipeline/stage config hoặc dataset không đọc được; dataset hai stage lệch nhau |
| `2` | Validation dữ liệu thất bại; stage ML không chạy |
| `3` | Stage lỗi sau khi đã nạp dữ liệu |
| `4` | `experiment_id`/báo cáo pipeline đã tồn tại; không ghi đè |
| `5` | Không mở/ghi được experiment store |

## 4. Artifact

```text
reports/pipeline/
├── <id>-backtest/            # summary, trades, equity, signals, validation
├── <id>-ml/                  # summary, model.json, model_card, predictions, split/schema
└── <id>/
    ├── pipeline_summary.json # trạng thái, metric chọn lọc, hash, limitation
    └── pipeline_report.md    # bản đọc được, gắn nhãn demo/synthetic
```

Báo cáo tổng hợp ghi rõ: dataset + SHA-256, trạng thái/exit code từng stage, metric backtest, metric
ML, warning của ML và danh sách limitation cố định (synthetic, chưa chạy MT5, một symbol, chi phí giả
định, single holdout, không execution).

## 5. Kết quả demo thực tế

Lần chạy `demo-phase9` (2026-10-27), dataset synthetic 1.800 bar:

| Hạng mục | Giá trị |
|---|---|
| Exit code | `0` |
| Data SHA-256 | `17fc3cc63c23fc94caf64ca44e29b7aa64779f8927b10a23b97ac5f86b47deaf` |
| Backtest config hash | `9972905d369e70ffaef3ebd7a08fab59350b4fbd2d194fa167ed6ce227ef5b43` |
| ML config hash | `abee20763963a73e1ad18b479d4d5796d1cae40519dbc525265941f69f6215e6` |
| Backtest | 49 trade; final equity 10.241,80; net +241,80; max drawdown 259,00; profit factor 1,4207 |
| ML test | 299 sample; threshold 0,50; ROC-AUC 0,5708; balanced accuracy 0,5584 |
| ML strategy | 84 trade; net -151,60; buy & hold +295,30 |
| MODEL SHA-256 | `5c5260f3daec807c1c67b23ec691e1c9047a60ce78c96f311f9a03bf4be859e8` |

Bản sao báo cáo (đã lược đường dẫn tuyệt đối):
[`phase-reports/phase-9-sample-report.md`](phase-reports/phase-9-sample-report.md). Report gốc nằm trong
`reports/pipeline/demo-phase9/` và bị `.gitignore`.

Kết quả cho thấy backtest EMA có lãi nhẹ trên fixture, còn ML lỗ sau chi phí và kém buy & hold. Không
được dùng các con số này để kết luận chiến lược.

## 6. Fail-safe đã kiểm tra

| Tình huống | Kỳ vọng | Kết quả thực tế |
|---|---|---|
| Dataset có timestamp trùng | Exit `2`, ML `skipped`, báo cáo `invalid_data` | `test_invalid_data_stops_before_ml` pass |
| Hai stage trỏ hai dataset khác nhau | Exit `1`, không tạo báo cáo | `test_mismatched_stage_datasets_are_rejected` pass |
| Stage config không tồn tại | Exit `1`, không tạo báo cáo | `test_missing_stage_config_is_rejected` pass |
| Chạy lại cùng ID | Exit `4`, báo cáo cũ không đổi | `test_duplicate_pipeline_run_is_rejected_without_overwrite` pass |
| Model ONNX không tồn tại | Exit `1`, không tạo artifact | `export_onnx_model.py --model ...missing...` → `input_error: model artifact not found`; exit `1` |
| Model JSON/ONNX sai schema | Fail closed | Phase 8 tests (`test_onnx_export.py`) |

## 7. Tái lập

Đã chạy hai lần với `demo-phase9` và `demo-phase9-b` (cùng config/dataset, khác experiment ID):

| Kiểm tra | Kết quả |
|---|---|
| Backtest metrics bằng nhau | Có |
| ML metrics bằng nhau | Có |
| `model_sha256` bằng nhau | Có (`5c5260f3…859e8`) |
| Data SHA-256 bằng nhau | Có |
| Báo cáo ghi `generated_at_utc`/đường dẫn khác nhau | Có, theo thiết kế |

Ngày 2026-10-28, đã kiểm tra thêm trên **snapshot commit sạch** trong thư mục tạm: sao chép đúng tập
file Git sẽ commit (116 file tracked + untracked không bị ignore, không có artifact/venv), tạo Git repo
tạm và commit sạch (`d3a9ea39…`, `git status` rỗng). Chạy từ snapshot này:

| Kiểm tra | Kết quả |
|---|---|
| `pytest -q` | **155 passed in 12.69s** |
| `run_pipeline.py --run-id clean-check` | Exit `0`; backtest 1.800 bar/49 trade/+241,80; ML 299 test/ROC-AUC 0,5708/-151,60 |
| So sánh với `demo-phase9` | Data SHA-256, metric backtest/ML và `model_sha256` **khớp hoàn toàn** |
| Chạy lại `clean-check` | Exit `4`; không ghi đè |
| Export ONNX từ model của snapshot | Exit `0`; parity 24 hàng PASS, max abs diff `4.673e-08`; ONNX SHA `a7ae4a25…64f9d3` |
| `compileall` + `pip check` | Exit `0`; không có dependency lỗi |

Khác biệt duy nhất: warning `worktree_dirty` không còn trong snapshot sạch. Snapshot chỉ là bằng chứng
tạm thời, không phải commit trong repository này và đã được xóa sau kiểm tra; sau khi người dùng commit
Phase 0–9, nên lặp lại quy trình ngắn sau để xác nhận commit chính thức:

1. `git status` phải sạch; ghi lại commit hash.
2. Xóa/đổi tên `reports/pipeline`, `experiments/phase9-demo.sqlite` cũ (artifact demo, gitignored).
3. Chạy lại lệnh ở mục 1 với `--run-id clean-check`.
4. So sánh `model_sha256`, data SHA-256, metric backtest/ML với bảng mục 5. Nếu khác, ghi rõ môi trường
   và dependency trước khi kết luận.

## 8. Giới hạn

- Toàn bộ demo dùng dữ liệu synthetic; không có kết luận thị trường.
- Chỉ một symbol/timeframe/vị thế; backtest EMA và ML dùng chung dataset nhưng là hai chiến lược khác
  nhau, không phải một chiến lược thống nhất.
- Chi phí cố định (spread 8 point, slippage 1 point, commission 1 mỗi chiều cho ML; backtest dùng cùng
  mức), không mô hình hóa spread biến động/thanh khoản.
- ML là single holdout; chưa retrain từng test block, chưa hyperparameter search.
- Pipeline không chạy MT5 Strategy Tester, không chạy ONNX Runtime trong MT5 và không có execution.
- Store là SQLite cục bộ, không mã hóa; database/report bị gitignore và phải backup thủ công nếu cần.
- Tái lập trên snapshot commit sạch đã xác minh; vẫn cần lặp lại sau commit chính thức để gắn với một
  commit hash trong repository. Xem mục 7.
