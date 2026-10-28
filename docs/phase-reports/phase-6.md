# Phase 6 — Reporting và experiment tracking

- **Trạng thái:** `DONE` (2026-10-27).
- **Phạm vi:** SQLite experiment store, config hash, data fingerprint, git/code state, trạng thái run,
  artifact hash và báo cáo so sánh hai run.
- **Không bao gồm:** tracking từ xa/UI, phát hiện crash tự động, retention/archival, so sánh per-trade,
  ML/ONNX, Strategy Tester MT5.

## 1. Deliverables

| Deliverable | Vị trí |
|---|---|
| Fingerprint utilities | `python/src/mt5_ea_ai_lab/experiment_store/fingerprints.py` |
| SQLite store + schema v1 | `python/src/mt5_ea_ai_lab/experiment_store/store.py` |
| So sánh và artifact JSON/CSV/Markdown | `python/src/mt5_ea_ai_lab/experiment_store/report.py` |
| Export package | `python/src/mt5_ea_ai_lab/experiment_store/__init__.py` |
| Tích hợp backtest CLI | `scripts/run_backtest.py` (`--store`, `--db`, `--experiment-id`) |
| CLI so sánh | `scripts/compare_experiments.py` |
| Config mẫu runnable | `configs/experiment.example.yaml` |
| Test store/fingerprint | `python/tests/test_experiment_store.py` |
| Test tích hợp backtest | `python/tests/test_run_backtest_store.py` |
| Test so sánh | `python/tests/test_experiment_compare.py` |
| Test CLI so sánh | `python/tests/test_compare_experiments_cli.py` |
| Hướng dẫn store/comparability | `docs/experiment-store.md` |
| Báo cáo Phase 6 | `docs/phase-reports/phase-6.md` |

## 2. Quyết định thiết kế

- **SQLite chỉ giữ metadata:** config JSON/path/hash, data path/fingerprint, git/code state, metric,
  validation, trạng thái và danh sách artifact. Trades/equity/signals vẫn là CSV/JSON trong `reports/`.
- **Append-only theo experiment ID:** `experiment_id` là khóa chính; ID trùng bị từ chối, không cập nhật
  hay ghi đè row cũ. Chỉ row `running` mới được chuyển sang trạng thái terminal.
- **Sáu trạng thái:** `running`, `completed`, `failed`, `invalid_data`, `cancelled`, `interrupted`.
  `completed` bắt buộc có metric; `failed`/`invalid_data` bắt buộc có error.
- **Config hash chỉ gồm phần ngữ nghĩa:** data descriptor (`data_kind`, `symbol`, `timeframe`, `timezone`),
  strategy, execution, seed. Loại trừ ID, đường dẫn, output, plot và notes.
- **Data fingerprint là SHA-256 byte-level:** thay đổi nội dung file làm đổi fingerprint; chuyển định dạng
  file tương đương cũng làm đổi fingerprint.
- **Git state được ghi, không được coi là bảo đảm:** commit + dirty; dirty chỉ tạo warning khi so sánh.
- **Artifact có hash:** mỗi artifact được lưu đường dẫn, SHA-256 và kích thước để có thể kiểm tra file
  bị thay đổi sau run.
- **Cô lập output khi dùng store:** artifact vào `<report_dir>/<experiment_id>`, tránh hai run khác ID ghi
  đè nhau.
- **Fail closed:** store không mở/ghi được → exit code `5`; ID trùng → `4`; JSON có NaN/Inf bị từ chối.
- **Comparability chặt:** cả hai `completed`, cùng config hash, cùng data fingerprint, cùng code version
  và (nếu có) cùng git commit. Báo cáo vẫn được ghi khi không comparable, kèm lý do.
- **Không secret:** schema không có field credential; tài liệu cảnh báo không đặt secret trong config,
  notes hay artifact.

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả thực tế |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **119 passed in 3.71s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `run_backtest.py --config configs\backtest.example.yaml --out-dir reports\backtests\phase6-nostore-check` | Exit code `0`; layout cũ, không tạo DB |
| `run_backtest.py --config configs\backtest.example.yaml --store --db experiments\phase6-demo.sqlite --experiment-id phase6-demo-a --out-dir reports\backtests\phase6-demo` | Exit code `0`; `completed`; final equity 10,294.60; config hash `bcdcefd79b26…`; data fingerprint `10c84c2eb8a7…` |
| Chạy lại cùng ID `phase6-demo-a` | Exit code **4**; `duplicate_experiment`; summary và row cũ không đổi |
| Run `phase6-demo-b` cùng config | Exit code `0`; cùng config hash/data fingerprint |
| `compare_experiments.py --baseline phase6-demo-a --run phase6-demo-b` | Exit code **0**; `comparable`, mọi delta bằng `0`; warning: dirty worktree ×2 + synthetic data |
| Run `phase6-demo-alt` (commission 5.0/chiều) | Exit code `0`; final equity 10,289.60; config hash `4486451d2d17…` |
| `compare_experiments.py --baseline phase6-demo-a --run phase6-demo-alt` | Exit code **1**; `not_comparable`, reason `config_hash_mismatch`; báo cáo vẫn ghi |
| Run với dataset timestamp trùng, `--store` | Exit code **2**; row `invalid_data`; artifact summary + validation JSON/CSV |
| Run với dataset không tồn tại, `--store` | Exit code **1**; row `failed`; `data_fingerprint=null`; error `load_error: ...` |

Database demo chứa 5 run: 3 `completed`, 1 `invalid_data`, 1 `failed`. Database nằm ở
`experiments/phase6-demo.sqlite` (gitignored); báo cáo so sánh nằm ở
`reports/comparisons/phase6-demo-a__vs__phase6-demo-b/` và
`reports/comparisons/phase6-demo-a__vs__phase6-demo-alt/` (gitignored).

### Kết quả so sánh tái lập

Hai run `phase6-demo-a` và `phase6-demo-b` dùng cùng config, cùng data byte và cùng code; mọi metric
bằng nhau, delta `0`. Điều này xác nhận cơ chế ghi metadata và tái lập của backtester, **không** phải
bằng chứng hiệu năng. Cả hai run có `git_dirty=true` vì Phase 1–6 chưa commit; warning này là đúng và
phải được xử lý bằng một commit trước khi dùng comparison làm bằng chứng tái lập mạnh.

Run `phase6-demo-alt` chỉ đổi commission từ 2.5 lên 5.0 mỗi chiều, nên bị chặn so sánh bởi
`config_hash_mismatch` dù final equity khác 5.00. Đây là hành vi mong muốn: thay đổi chi phí là thay đổi
giả định mô phỏng.

## 4. Tiêu chí nghiệm thu

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Một run không bị ghi đè âm thầm | Đạt | Exit `4`; test `test_duplicate_experiment_id_does_not_overwrite`, `test_duplicate_run_returns_4_without_overwriting` (kiểm tra cả row và summary) |
| Mỗi kết quả liên kết tới cấu hình và dữ liệu | Đạt | `config_json`, `config_hash`, `config_path`, `data_path`, `data_fingerprint`, `data_kind`, `symbol`, `timeframe` |
| Test interrupted/failed/duplicate | Đạt | `test_running_run_can_be_marked_interrupted`, `test_failed_requires_error`, `test_load_error_is_recorded`, hai test duplicate |
| Phân biệt `failed`, `completed`, `invalid_data`, `cancelled` | Đạt | CHECK constraint + test lifecycle; `cancelled` có `test_running_run_can_be_cancelled`, `interrupted` có test riêng |
| SQLite cho metadata; CSV/JSON cho artifact | Đạt | 3 bảng SQLite; artifact CSV/JSON + hash trong `experiment_artifacts` |
| Schema/migration đơn giản | Đạt | `PRAGMA user_version=1`; `ExperimentStore._migrate` từ chối version mới hơn |
| Báo cáo so sánh baseline và run mới | Đạt | `comparison.json/csv/md`; exit `0/1/2`; test comparable và không comparable |
| Không ghi mật khẩu/API key | Đạt (thiết kế) | Không có field credential; cảnh báo trong docs/risk; không có secret trong demo |
| Store/CLI tách khỏi execution | Đạt | Không có API tài khoản/order; chỉ đọc dataset, ghi metadata/artifact |

## 5. Test đã bổ sung

- `test_experiment_store.py` (18 test): metadata, duplicate, terminal transition, interrupted, cancelled,
  metric bắt buộc, error bắt buộc, NaN rejection, artifact roundtrip/hash, list/filter/order, ID validation,
  persistence, canonical JSON, git state unavailable.
- `test_run_backtest_store.py` (7 test): completed + artifact, duplicate không ghi đè, invalid_data, load
  error, layout không store, `--experiment-id` yêu cầu `--store`, ID độc hại bị chặn trước khi tạo DB.
- `test_experiment_compare.py` (10 test): delta, không completed, config/data/code/commit mismatch, warning
  dirty/unknown/synthetic, metric null, non-finite metric, artifact JSON/CSV/Markdown, ID đầu vào.
- `test_compare_experiments_cli.py` (5 test): comparable, config mismatch, missing run, missing DB, ID
  không hợp lệ.

Tổng: **119 pass** (79 test Phase 5 + 40 test Phase 6).

## 6. File đã tạo/sửa

Tạo mới:

- `python/src/mt5_ea_ai_lab/experiment_store/fingerprints.py`
- `python/src/mt5_ea_ai_lab/experiment_store/store.py`
- `python/src/mt5_ea_ai_lab/experiment_store/report.py`
- `scripts/compare_experiments.py`
- `python/tests/test_experiment_store.py`
- `python/tests/test_run_backtest_store.py`
- `python/tests/test_experiment_compare.py`
- `python/tests/test_compare_experiments_cli.py`
- `docs/experiment-store.md`
- `docs/phase-reports/phase-6.md`

Cập nhật:

- `python/src/mt5_ea_ai_lab/experiment_store/__init__.py`
- `scripts/run_backtest.py`
- `configs/experiment.example.yaml` (placeholder → cấu hình runnable)
- `.gitignore` (`*.sqlite-wal`, `*.sqlite-shm`, `*.db-journal`)
- `docs/testing-guide.md`, `docs/architecture.md`, `docs/environment.md`,
  `docs/risk-and-limitations.md`, `README.md`

Không đổi: MQL5 source, dependency Python (dùng `sqlite3` stdlib), `requirements.txt`.

## 7. Vấn đề còn tồn tại

1. **Worktree dirty:** mọi run demo có `git_dirty=true`; comparison vẫn `comparable` nhưng chỉ là cảnh
   báo. Cần commit Phase 1–6 trước khi dùng kết quả làm bằng chứng tái lập.
2. **Không tự phát hiện process bị kill:** row có thể kẹt `running`; phải gọi `mark_interrupted` thủ công.
   Chưa có CLI cho thao tác này.
3. **Chưa kiểm thử nhiều process ghi đồng thời:** SQLite có locking nhưng hành vi chưa được xác minh.
4. **So sánh chỉ ở mức metadata/metric:** không so sánh từng trade, equity curve hay signal row.
5. **Data fingerprint byte-level:** đổi định dạng file tương đương làm mất comparability.
6. **Config hash loại trừ đường dẫn/output/notes:** hai run cùng cấu hình nhưng output khác vẫn comparable.
7. **SQLite cục bộ, không mã hóa/retention/backup tự động:** database và report bị gitignore, cần sao lưu
   thủ công nếu muốn lưu lâu dài.
8. **Chưa có UI/list CLI:** chỉ dùng SQLite client hoặc `ExperimentStore.list_runs()`.
9. **Chưa có model version:** `code_version` đã có; model artifact/version sẽ được thêm ở Phase 7–8.
10. **Parity MQL5/Python vẫn mở:** `LabSignalExport.mq5` chưa chạy trong terminal; không có kết luận
    tương đương.
11. **Demo synthetic:** các con số 10,294.60/10,289.60 chỉ minh họa cơ chế, không phải hiệu năng.

## 8. Kiểm tra thủ công gợi ý

1. Chạy:
   `.\.venv\Scripts\python.exe scripts\run_backtest.py --config configs\experiment.example.yaml --store --experiment-id <unique-id>`
2. Mở `reports\backtests\<unique-id>\summary.json`; xác nhận `experiment_store.config_hash`,
   `data_fingerprint`, `git_commit`, `git_dirty`.
3. Mở `experiments\experiments.sqlite` bằng SQLite client; kiểm tra row `experiments` và event
   `NULL → running → completed`.
4. Chạy lại cùng ID; xác nhận exit `4` và artifact cũ không đổi.
5. Chạy run thứ hai với ID khác, cùng config; dùng `compare_experiments.py`; xác nhận `comparable`, delta 0,
   và đọc cảnh báo dirty/synthetic.
6. Đổi commission trong một config copy, chạy run mới và so sánh; xác nhận `config_hash_mismatch` và exit
   `1`.
7. Không đặt mật khẩu/token/API key trong config/notes; không commit database/report.

## 9. Bước tiếp theo

Phase 7 — AI/ML baseline: định nghĩa label/horizon trước, feature chỉ dùng dữ liệu có sẵn, chia
train/validation/test theo thời gian, walk-forward, benchmark không ML và lưu model artifact/model card.
Experiment store hiện có thể lưu `code_version`; khi có model cần bổ sung model ID/version và feature
schema vào metadata. Chưa tuyên bố kết quả ML hay tương đương MQL5/Python.
