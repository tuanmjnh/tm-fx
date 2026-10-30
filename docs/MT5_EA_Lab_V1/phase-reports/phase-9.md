# Phase 9 — End-to-end pipeline và đánh giá cuối

- **Trạng thái:** `DONE` (2026-10-27); tái lập trên snapshot commit sạch đã xác minh 2026-10-28.
- **Phạm vi:** một lệnh chạy load/validate → backtest EMA → ML baseline → experiment store → báo cáo tổng
  hợp trên cùng một dataset; kiểm tra fail-safe với dữ liệu lỗi/model thiếu và kiểm tra tái lập cùng
  config/dataset.
- **Không bao gồm:** execution thật, kết nối broker, MT5 Strategy Tester, ONNX runtime MT5, portfolio
  nhiều symbol, hyperparameter search.
- **Cảnh báo:** toàn bộ demo dùng dữ liệu **synthetic**; các con số chỉ minh họa cơ chế pipeline, không
  phải hiệu năng thị trường.

## 1. Deliverables

| Deliverable | Vị trí |
|---|---|
| Orchestrator pipeline (validate → backtest → ML → store → report) | `scripts/run_pipeline.py` |
| Config demo end-to-end | `configs/pipeline.example.yaml`, `configs/backtest.synthetic-ml.yaml` |
| Test fail-safe và tái lập | `python/tests/test_pipeline_cli.py` (5 test) |
| Sample report gắn nhãn demo/synthetic | `docs/phase-reports/phase-9-sample-report.md` |
| Hướng dẫn pipeline, exit code, artifact | `docs/reference/pipeline.md` |
| Checklist phát hành nội bộ | `docs/reference/release.md` |
| Báo cáo Phase 9 | `docs/phase-reports/phase-9.md` |

Artifact sinh ra (gitignored): `reports/pipeline/demo-phase9/` (báo cáo tổng hợp),
`reports/pipeline/demo-phase9-backtest/`, `reports/pipeline/demo-phase9-ml/` và
`experiments/phase9-demo.sqlite`.

## 2. Quyết định thiết kế

- **Tái sử dụng chính CLI stage thay vì viết lại logic:** pipeline nạp `run_backtest.py` và
  `train_ml_baseline.py` qua `importlib` và gọi `main()` với cùng tham số CLI; hành vi stage, exit code và
  artifact giống chạy tay, không có bản sao logic thứ hai.
- **Dataset là nguồn sự thật duy nhất:** pipeline yêu cầu hai stage config trỏ cùng đường dẫn dataset và
  cùng `data_kind`/`symbol`/`timeframe`; lệch cấu hình bị từ chối trước khi chạy stage.
- **Không lặp lại khối `data` trong config pipeline:** tránh hai nguồn dữ liệu có thể lệch nhau.
- **Run ID bất biến:** mỗi stage lưu `<run_id>-backtest`/`<run_id>-ml`; pipeline từ chối chạy nếu báo cáo
  tổng hợp đã tồn tại, nên không ghi đè kết quả cũ. Store cũng từ chối ID trùng.
- **Fail-safe theo exit code:** dữ liệu không hợp lệ dừng trước ML; stage lỗi được ghi vào báo cáo với
  trạng thái tương ứng; pipeline trả lại exit code của stage lỗi.
- **Báo cáo tổng hợp trung thực:** ghi data SHA-256, hash summary từng stage, metric chọn lọc, warning của
  ML và danh sách limitation cố định; luôn gắn nhãn demo khi `data_kind != market`.
- **Không chạy MT5/ONNX/execution:** pipeline chỉ gồm các bước Python offline; các hạng mục runtime MT5
  vẫn là kiểm tra thủ công riêng.

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả thực tế |
|---|---|
| `.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml` | Exit code **0**; `pipeline=demo-phase9 status=completed`; hai stage `completed` |
| Chạy lại `--run-id demo-phase9-b` (cùng config/dataset) | Exit code **0**; metric backtest/ML, data SHA-256 và model SHA-256 giống lần đầu |
| Chạy lại `demo-phase9` (ID đã tồn tại) | Exit code **4**; `duplicate_experiment`; hash báo cáo cũ không đổi |
| Pipeline với dataset timestamp trùng (test) | Exit code **2**; backtest `invalid_data`; ML `skipped` |
| Pipeline với hai stage trỏ hai dataset khác nhau (test) | Exit code **1**; không tạo báo cáo |
| Pipeline thiếu stage config (test) | Exit code **1**; không tạo báo cáo |
| `export_onnx_model.py --model ...missing...` | Exit code **1**; `input_error: model artifact not found` |
| Snapshot commit sạch: `pytest -q` | **155 passed in 12.69s** |
| Snapshot commit sạch: pipeline `--run-id clean-check` | Exit `0`; metric/data SHA/model SHA khớp `demo-phase9`; warning `worktree_dirty` không còn |
| Snapshot commit sạch: chạy lại `clean-check` | Exit `4`; không ghi đè |
| Snapshot commit sạch: export ONNX từ model mới | Exit `0`; parity 24 hàng PASS; ONNX SHA `a7ae4a25…64f9d3` |
| `.venv\Scripts\python.exe -m pytest -q` (repo chính) | **155 passed in 11.22s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

### Kết quả demo `demo-phase9` (synthetic, 1.800 bar)

| Hạng mục | Giá trị |
|---|---|
| Data SHA-256 | `17fc3cc63c23fc94caf64ca44e29b7aa64779f8927b10a23b97ac5f86b47deaf` |
| Backtest config hash | `9972905d369e70ffaef3ebd7a08fab59350b4fbd2d194fa167ed6ce227ef5b43` |
| ML config hash | `abee20763963a73e1ad18b479d4d5796d1cae40519dbc525265941f69f6215e6` |
| Backtest | 49 trade; final equity 10.241,80; net +241,80; max drawdown 259,00; profit factor 1,4207; exposure 95,94% |
| ML test | 299 sample; threshold 0,50; ROC-AUC 0,5708; balanced accuracy 0,5584; accuracy 0,5686 |
| ML strategy | 84 trade; net -151,60; buy & hold +295,30 |
| Model JSON SHA-256 | `5c5260f3daec807c1c67b23ec691e1c9047a60ce78c96f311f9a03bf4be859e8` |
| ML warnings | `data_kind_synthetic`, `ml_strategy_not_profitable_after_costs`, `worktree_dirty` |

Các con số trên cho thấy backtest EMA có lãi nhẹ trên fixture, còn ML lỗ sau chi phí và kém buy & hold.
Không được dùng để kết luận chiến lược hoặc hiệu năng thị trường.

## 4. Tiêu chí nghiệm thu

| Tiêu chí (roadmap) | Kết quả | Bằng chứng |
|---|---|---|
| Test Python chạy xanh trong môi trường đã khai báo | Đạt | **155 passed in 11.28s**; compileall và pip check sạch |
| Chạy pipeline bằng một cấu hình cố định | Đạt | `configs/pipeline.example.yaml`; exit `0` |
| Nạp dữ liệu, validate, tạo feature/tín hiệu, backtest, lưu experiment, sinh report | Đạt | Hai stage `completed`; hai row trong `experiments/phase9-demo.sqlite`; báo cáo JSON/Markdown |
| Thử dữ liệu lỗi và model thiếu để xác minh fail-safe | Đạt | Test exit `2`/`1`; duplicate exit `4`; ONNX missing model exit `1` |
| Kiểm tra khả năng lặp lại sau checkout commit sạch | Đạt trên snapshot commit sạch | Snapshot 116 file, commit tạm `d3a9ea39…`, `git status` sạch; 155 test pass; pipeline exit `0`; metric/data SHA/model SHA khớp; ONNX parity PASS. Cần lặp lại sau commit chính thức để gắn commit hash repository |
| Có thể tái tạo một run demo từ hướng dẫn | Đạt (cùng worktree và snapshot sạch) | `docs/reference/pipeline.md` mục 1 và 7; metric/hash khớp |
| Sample report đánh dấu demo/synthetic | Đạt | `docs/phase-reports/phase-9-sample-report.md` |
| Checklist phát hành nội bộ | Đạt | `docs/reference/release.md` |
| Không có mật khẩu/tài khoản môi giới | Đạt | Không có credential trong code/config/report; không kết nối broker |
| Không có lệnh giao dịch thật hoặc cơ chế tự kích hoạt execution | Đạt | Không có `OrderSend`/`CTrade.Buy`/`CTrade.Sell`; pipeline chỉ gọi backtest/ML |
| Giới hạn và giả định hiển thị rõ trong báo cáo | Đạt | `limitations` trong `pipeline_summary.json` và mục Limitations của report |

Phase 9 được đánh dấu `DONE` vì toàn bộ deliverable và tiêu chí kỹ thuật đạt. Tái lập đã được xác minh
trên snapshot commit sạch tạm thời; bước còn lại chỉ là lặp lại ngắn sau khi người dùng commit chính thức
để gắn kết quả với commit hash của repository.

## 5. Test đã bổ sung

- `write_stage_configs`/`write_pipeline_config` dựng config tạm cho từng test.
- `test_pipeline_runs_both_stages_and_writes_store`: exit `0`, hai row store, báo cáo JSON/Markdown tồn
  tại, metric khớp summary stage.
- `test_duplicate_pipeline_run_is_rejected_without_overwrite`: chạy lần hai cùng ID → exit `4`, nội dung
  báo cáo không đổi.
- `test_invalid_data_stops_before_ml`: dataset timestamp trùng → exit `2`, ML `skipped`.
- `test_mismatched_stage_datasets_are_rejected`: hai stage khác dataset → exit `1`, không có báo cáo.
- `test_missing_stage_config_is_rejected`: stage config không tồn tại → exit `1`, không có báo cáo.

Tổng: **5 test Phase 9**; toàn bộ suite **155 passed** (150 test Phase 0–8 + 5 test Phase 9).

## 6. File đã tạo/sửa

Tạo mới:

- `scripts/run_pipeline.py`
- `configs/pipeline.example.yaml`
- `configs/backtest.synthetic-ml.yaml`
- `python/tests/test_pipeline_cli.py`
- `docs/reference/pipeline.md`
- `docs/reference/release.md`
- `docs/phase-reports/phase-9.md`
- `docs/phase-reports/phase-9-sample-report.md`

Cập nhật:

- `README.md` (trạng thái, cấu trúc, config mẫu, lệnh pipeline, exit code, an toàn, liên kết)
- `docs/reference/architecture.md`, `docs/guides/install-and-test.md`, `docs/reference/testing.md`,
  `docs/reference/risk.md`, `docs/reference/data-dictionary.md`

Không thêm execution, không thay đổi signal engine/EA, không kết nối broker, không thêm secret.

## 7. Vấn đề còn tồn tại

1. **Tái lập sau commit chính thức chưa lặp lại:** đã xác minh trên snapshot commit sạch tạm thời
   (`d3a9ea39…`, 116 file, `git status` rỗng) với kết quả khớp hoàn toàn, nhưng snapshot không phải commit
   trong repository này và đã xóa sau kiểm tra. Sau khi người dùng commit Phase 0–9, chạy lại quy trình
   ngắn trong `docs/reference/pipeline.md` mục 7 để gắn kết quả với commit hash chính thức.
2. **MT5 Strategy Tester/ONNX runtime vẫn thủ công:** pipeline không chạy terminal; Phase 8 vẫn
   `READY_FOR_MANUAL_VALIDATION`.
3. **Dữ liệu synthetic:** không có kết luận về chất lượng dữ liệu thị trường thực, spread/slippage thực
   tế hay sample size.
4. **Một symbol/timeframe/vị thế:** chưa kiểm tra portfolio, đa tài sản hoặc đồng thời nhiều vị thế.
5. **ML single holdout:** chưa retrain từng test block, chưa hyperparameter search; nguy cơ overfitting
   và regime shift vẫn còn.
6. **Backtest EMA và ML là hai chiến lược khác nhau** dùng chung dataset, không phải một chiến lược
   thống nhất.
7. **Chi phí cố định:** spread 8 point, slippage 1 point, commission 1 mỗi chiều; không mô hình hóa
   spread biến động/thanh khoản.
8. **Store SQLite cục bộ không mã hóa:** database/report bị gitignore và cần backup thủ công.

## 8. Kiểm tra thủ công gợi ý

Tái lập trên snapshot commit sạch đã hoàn tất ngày 2026-10-28; các bước 1–5 chỉ cần lặp lại sau khi
commit chính thức để gắn kết quả với commit hash của repository.

1. Commit toàn bộ thay đổi Phase 0–9; xác nhận `git status` sạch và ghi lại commit hash.
2. Xóa/đổi tên artifact demo cũ (`reports/pipeline`, `experiments/phase9-demo.sqlite`) — đây là artifact
   gitignored, không phải dữ liệu người dùng.
3. Chạy `.\.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml --run-id clean-check`.
4. So sánh `pipeline_summary.json` với bảng mục 3: data SHA-256, model SHA-256, metric backtest/ML phải
   khớp; nếu khác, ghi rõ môi trường/dependency trước khi kết luận.
5. Chạy lại cùng `clean-check` để xác nhận exit `4` và báo cáo không bị ghi đè.
6. Thực hiện các kiểm tra MT5 còn mở theo `docs/reference/release.md` và `docs/reference/onnx.md`; ghi
   build terminal và kết quả thật.
7. Không đặt secret trong config/report; không commit `.sqlite`, model artifact hay output thí nghiệm.

## 9. Bước tiếp theo

Roadmap kết thúc ở Phase 9. Các hạng mục còn mở là kiểm tra thủ công, không phải phase mới:

- Lặp lại tái lập sau commit chính thức (mục 8, bước 1–5); snapshot sạch đã đạt.
- Chạy EA signal-only trong MT5 Strategy Tester (Phase 1/2/5).
- Chạy `LabOnnxInference.mq5` với ONNX Runtime thật trong MT5 (Phase 8).
- Chỉ khi có quyết định phạm vi mới mới xem xét execution; mọi mở rộng như vậy phải được đánh giá độc lập
  và không nằm trong roadmap hiện tại.
