# Experiment store và so sánh run (Phase 6)

- **Trạng thái:** `DONE` (2026-10-27).
- **Phạm vi:** metadata run cục bộ trong SQLite, fingerprint cấu hình/dữ liệu, trạng thái run, artifact
  hash và báo cáo so sánh hai run.
- **Không bao gồm:** server tracking từ xa, dashboard web, lưu artifact lớn trong database, tự động phát
  hiện process bị kill, ML/ONNX.

## 1. Thành phần

| Thành phần | Vai trò |
|---|---|
| `python/src/mt5_ea_ai_lab/experiment_store/fingerprints.py` | Hash JSON canonical, hash file, đọc git commit/dirty |
| `python/src/mt5_ea_ai_lab/experiment_store/store.py` | Schema SQLite, vòng đời trạng thái, artifact metadata |
| `python/src/mt5_ea_ai_lab/experiment_store/report.py` | So sánh run, xuất JSON/CSV/Markdown |
| `scripts/run_backtest.py --store` | Ghi run vào store, cô lập artifact theo experiment ID |
| `scripts/compare_experiments.py` | CLI so sánh baseline và run mới |
| `python/tests/test_experiment_store.py` | Store, fingerprint, trạng thái, duplicate |
| `python/tests/test_run_backtest_store.py` | Tích hợp CLI: completed/invalid_data/failed/duplicate |
| `python/tests/test_experiment_compare.py` | Quy tắc comparability và artifact so sánh |
| `python/tests/test_compare_experiments_cli.py` | CLI so sánh, exit code, ID không hợp lệ |

Database mặc định: `experiments/experiments.sqlite` (bị gitignore). Artifact lớn vẫn là CSV/JSON trong
`reports/`; store chỉ giữ đường dẫn và SHA-256.

## 2. Schema

`PRAGMA user_version = 1`.

### `experiments`

| Cột | Ý nghĩa |
|---|---|
| `experiment_id` | Khóa chính; chuỗi `[A-Za-z0-9][A-Za-z0-9._-]{0,127}` |
| `status` | `running`, `completed`, `failed`, `invalid_data`, `cancelled`, `interrupted` |
| `created_at_utc`, `updated_at_utc`, `started_at_utc`, `finished_at_utc` | Mốc thời gian ISO 8601 UTC |
| `code_version` | `mt5_ea_ai_lab.__version__` tại thời điểm chạy |
| `git_commit`, `git_dirty` | Commit hiện tại và worktree có thay đổi chưa commit |
| `config_path`, `config_json`, `config_hash` | Đường dẫn config, cấu hình hiệu lực, hash canonical |
| `data_path`, `data_fingerprint`, `data_kind`, `symbol`, `timeframe` | Liên kết dataset và SHA-256 nội dung |
| `seed`, `report_dir`, `notes` | Tham số tái lập và ghi chú |
| `metrics_json`, `benchmark_json`, `signal_counts_json`, `validation_json` | Kết quả dạng JSON, không có NaN |
| `error` | Lý do cho `failed`/`invalid_data`/`cancelled`/`interrupted` |

### `experiment_events`

Ghi mọi chuyển trạng thái: `NULL → running`, sau đó `running → <terminal>`. Dùng để kiểm tra run không
bị đổi trạng thái hai lần.

### `experiment_artifacts`

Khóa `(experiment_id, name)`: đường dẫn, SHA-256 và kích thước của từng artifact. Tên hiện dùng:
`summary`, `trades`, `equity`, `signals`, `validation_json`, `validation_csv`, `equity_plot`.

### Vòng đời trạng thái

```text
(NEW) ──start_run──▶ running ──complete_run────▶ completed
                          ├──fail_run─────────▶ failed
                          ├──invalidate_run───▶ invalid_data
                          ├──cancel_run───────▶ cancelled
                          └──mark_interrupted─▶ interrupted
```

Chỉ row `running` mới được chuyển trạng thái. Row đã terminal không thể sửa; nỗ lực thứ hai trả
`InvalidTransitionError`. `experiment_id` đã tồn tại trả `DuplicateExperimentError` và **không** thay đổi
row cũ.

`completed` bắt buộc có `metrics`; `failed` và `invalid_data` bắt buộc có `error` không rỗng. JSON có
`NaN`/`Infinity` bị từ chối để tránh metric không đọc được bằng JSON chuẩn.

## 3. Fingerprint

- **Config hash:** SHA-256 của JSON canonical, chỉ gồm phần thay đổi hành vi mô phỏng:
  `data_kind`, `symbol`, `timeframe`, `timezone`, `strategy`, `execution`, `seed`.
  Loại trừ có chủ đích: `experiment_id`, đường dẫn dataset, `outputs`/`report_dir`, `plot`, `notes`.
- **Data fingerprint:** SHA-256 trên byte gốc của file dataset. Không phải hash của DataFrame đã chuẩn
  hóa; đổi định dạng file dù nội dung tương đương sẽ tạo fingerprint khác.
- **Code state:** `code_version`, `git_commit`, `git_dirty`. Nếu không có git hoặc không phải repository,
  commit/dirty là `null` và comparison phát warning.
- **Seed:** lưu trong metadata và nằm trong config hash; backtester hiện không dùng RNG.

## 4. Chạy backtest có store

```powershell
.\.venv\Scripts\python.exe scripts\run_backtest.py `
  --config configs\experiment.example.yaml `
  --store --experiment-id demo-phase6-001
```

- Database mặc định `experiments/experiments.sqlite`; đổi bằng `--db <path>`.
- Artifact được đặt tại `<outputs.report_dir>/<experiment_id>`, không ghi đè artifact của run khác.
- `--experiment-id` ghi đè ID trong config và **chỉ dùng được** với `--store`.
- Chạy lại cùng ID trả exit code `4` trước khi load dữ liệu; không ghi file, không sửa row.
- Exit code `5` khi không mở/ghi được store. Backtest có thể đã hoàn tất và artifact đã ghi; thông báo
  `store_error` nêu lỗi.

| Exit code | Ý nghĩa |
|---|---|
| `0` | Backtest hoàn tất và (nếu bật) metadata đã ghi |
| `1` | Config/dataset không đọc được; nếu bật store, row `failed` |
| `2` | Validation thất bại; nếu bật store, row `invalid_data` |
| `3` | Backtest lỗi sau khi load; nếu bật store, row `failed` |
| `4` | `experiment_id` đã tồn tại |
| `5` | Store không mở/ghi được |

Không có `--store`, hành vi Phase 4 giữ nguyên: artifact ghi trực tiếp vào `report_dir` và có thể bị ghi
đè bởi lần chạy sau.

## 5. So sánh hai run

```powershell
.\.venv\Scripts\python.exe scripts\compare_experiments.py `
  --db experiments\experiments.sqlite `
  --baseline demo-phase6-001 --run demo-phase6-002
```

Output mặc định: `reports/comparisons/<baseline>__vs__<run>/` gồm `comparison.json`, `comparison.csv`,
`comparison.md`. CLI chỉ đọc database.

| Exit code | Ý nghĩa |
|---|---|
| `0` | Hai run comparable; báo cáo đã ghi |
| `1` | Hai run không comparable; báo cáo vẫn ghi kèm lý do |
| `2` | Không đọc được database/run hoặc ID không hợp lệ |

### Điều kiện comparable

Cả hai run phải:

1. có `status=completed`;
2. có cùng `config_hash`;
3. có `data_fingerprint` khác `null` và giống nhau;
4. có cùng `code_version`;
5. nếu cả hai có `git_commit`, hai commit phải giống nhau.

Warning (không chặn): worktree dirty, thiếu git commit, ít nhất một run dùng dữ liệu `synthetic`.
Warning dirty nghĩa là code thực tế có thể khác commit đã ghi; kết quả vẫn hiển thị nhưng không nên dùng
làm bằng chứng tái lập mạnh.

### Metric trong báo cáo

`bars`, `final_equity`, `net_profit`, `total_return`, `trade_count`, `win_rate`, `profit_factor`,
`average_trade`, `max_drawdown`, `max_drawdown_pct`, `exposure_ratio`, `total_commission`.

Mỗi dòng có `baseline`, `run`, `delta = run - baseline` và `delta_pct` (bỏ trống nếu baseline bằng `0`
hoặc `null`). Không có metric annualized; Sharpe/Sortino vẫn `null`.

## 6. Run bị gián đoạn

Nếu process bị kill sau `start_run`, row ở trạng thái `running`. Store không tự phát hiện process đã
chết. Người vận hành có thể đánh dấu thủ công bằng API (không có CLI trong Phase 6):

```powershell
.\.venv\Scripts\python.exe -c "import sys; sys.path.insert(0, 'python/src'); from mt5_ea_ai_lab.experiment_store import ExperimentStore; s = ExperimentStore('experiments/experiments.sqlite'); s.mark_interrupted('demo-phase6-001', 'process killed'); s.close()"
```

`mark_interrupted` chỉ thành công khi row còn `running`; gọi lại trên row terminal sẽ lỗi. Đây là thao
tác metadata, không xóa artifact.

## 7. Giới hạn

- SQLite cục bộ, một file; chưa có replication/export sang nơi khác.
- Chưa có retention/archival; database và report tăng dần và bị gitignore.
- Chưa có UI để liệt kê run; dùng SQLite client hoặc API `ExperimentStore.list_runs()`.
- Chưa tự động phát hiện crash (xem mục 6); chưa có lock heartbeat.
- Chưa kiểm thử nhiều process ghi đồng thời; SQLite có locking nhưng hành vi chưa được xác minh.
- Comparison chỉ so sánh metadata/metric, không so sánh từng dòng trades hay equity.
- Config hash loại trừ đường dẫn/output/notes; hai run cùng cấu hình nhưng output khác nhau vẫn comparable.
- Data fingerprint là byte-level; chuyển CSV sang Parquet cùng nội dung sẽ không comparable.
- Không có secret scanning: không đặt mật khẩu/token/API key trong config, `notes` hay artifact.
- Database không mã hóa; bảo vệ bằng quyền filesystem.
