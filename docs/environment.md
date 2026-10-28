# Kiểm kê môi trường — Phase 0

- **Ngày kiểm kê:** 2026-10-27
- **Phương pháp:** chỉ đọc thông tin phiên bản, danh sách thư mục và metadata file. Không cài phần mềm,
  không sửa PATH, không mở GUI, không kết nối tài khoản, không đọc nội dung file tài khoản.
- **Máy:** Windows 10.0.19045.6456 (64-bit)

## 1. Bảng kiểm kê

| Hạng mục | Kết quả | Trạng thái |
|---|---|---|
| Windows | 10.0.19045.6456 | PASS (roadmap khuyến nghị Windows 11; xem giới hạn) |
| Python | 3.11.9, cài user-scope (`%LOCALAPPDATA%\Programs\Python\Python311`) | PASS |
| Python launcher | `py -0p` chỉ có 3.11 (mặc định) | PASS |
| pip | 26.1.1 | PASS |
| Git | 2.53.0.windows.3 | PASS |
| Git repository | Ban đầu **không phải** Git repo; đã `git init -b main`, chưa commit | PASS (đã khởi tạo) |
| MT5 terminal | 5.0.0.6249, `C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe` | PASS (hiện diện) |
| MetaEditor | 5.0.0.6249, `C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe` | PASS (hiện diện) |
| MT5 Strategy Tester | `metatester64.exe` 5.0.0.6249 | PASS (hiện diện) |
| MT5 Data Folder | `%APPDATA%\MetaQuotes\Terminal\<terminal-id>` (ID cục bộ, không ghi vào repo) | PASS |
| `MQL5/Experts` | Tồn tại; chỉ có thư mục mặc định (`Advisors`, `Examples`, `Free Robots`) | PASS |
| Python venv | `.venv` tạo bằng Python 3.11.9, cài `requirements.txt` | Xem mục 3 |
| Pytest | Chạy smoke test trong `.venv` | Xem mục 3 |

Ghi chú: thư mục data của terminal chứa `accounts.dat`, `servers.dat`, `config/` và các file phiên.
Phase 0 chỉ liệt kê tên file/thư mục; **không đọc nội dung**, không sao chép vào repository. Các file này
nằm trong `.gitignore` để tránh commit nhầm.

## 2. Những gì chưa được xác minh

| Hạng mục | Lý do | Cách xác minh |
|---|---|---|
| Compile MQL5 | Đã compile Phase 1 bằng CLI: 0 errors, 0 warnings (xem mục 5) | Chạy lại trong MetaEditor GUI nếu cần xác nhận trực quan |
| Strategy Tester chạy EA | **Chưa chạy**; agent không điều khiển GUI | Người dùng: `Ctrl+R`, chọn EA/symbol/timeframe, xem Journal/Experts |
| Dữ liệu lịch sử của terminal | Không kiểm tra/không tải dữ liệu | Phase 1/3: xác nhận symbol và khoảng ngày có sẵn |
| ONNX runtime trong MT5 | Phase 8 chỉ compile EA; runtime **chưa chạy** | Chạy `LabOnnxInference` trong terminal và đối chiếu log với fixture |
| Kết nối broker/tài khoản | **Ngoài phạm vi, không được làm** | Không thực hiện |

## 3. Kết quả thiết lập Python (đã chạy thực tế)

Các lệnh dưới đây chạy trong `.venv` (Python 3.11.9) tại thư mục gốc repository.

| Lệnh | Kết quả thực tế |
|---|---|
| `py -3.11 -m venv .venv` | Tạo thành công |
| `.venv\Scripts\python.exe --version` | `Python 3.11.9` |
| `.venv\Scripts\python.exe -m pip --version` | `pip 24.0` |
| `.venv\Scripts\python.exe -m pip install --upgrade pip` | **Không hoàn tất**: tiến trình quay CPU, không có output sau khoảng 2 phút; đã dừng chủ động. Không ảnh hưởng cài dependency. |
| `.venv\Scripts\python.exe -m pip install -r requirements.txt` | Thành công: numpy 2.4.6, pandas 2.3.3, pyarrow 26.0.0, scikit-learn 1.9.1, matplotlib 3.11.2, PyYAML 6.0.3, pytest 9.1.1 (+ transitive deps) |
| `.venv\Scripts\python.exe -m pytest` | Phase 0: **11 passed**; Phase 3: **38 passed in 1.48s**; Phase 4: **62 passed in 1.67s**; Phase 5: **79 passed in 2.03s** (pytest 9.1.1, rootdir `tm-fx`, config `pyproject.toml`) |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests` | Exit code 0 |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| Import numpy/pandas/sklearn/matplotlib/pytest | Thành công; matplotlib cảnh báo không ghi được cache mặc định `%LOCALAPPDATA%\matplotlib` và tạo cache tạm trong repo |

Chi tiết đầy đủ, bao gồm lệnh và danh sách file: [`phase-reports/phase-0.md`](phase-reports/phase-0.md).

### Ghi chú môi trường

- Không chạy `.\.venv\Scripts\Activate.ps1`; các lệnh dùng trực tiếp interpreter trong `.venv` để tránh phụ
  thuộc Execution Policy. Người dùng có thể kích hoạt thủ công nếu PowerShell cho phép.
- Nếu cần dùng matplotlib ở phase sau, đặt cache vào thư mục ghi được, ví dụ trong phiên PowerShell:
  `$env:MPLCONFIGDIR = "$PWD\.venv\matplotlib-cache"`. Không cần thay đổi biến môi trường hệ thống.
  `run_backtest.py` tự dùng thư mục `.mplconfig` trong report dir khi tạo plot.
- Nâng cấp pip chỉ nên thực hiện khi cần; lần thử trong Phase 0 không hoàn tất nên baseline giữ pip 24.0.
- Trong Git Bash của môi trường kiểm thử, `TMP`/`TEMP` trỏ tới `/tmp` không hợp lệ với Python Windows, nên
  `tempfile.gettempdir()` rơi về thư mục hiện tại. Hệ quả: pip/pytest có thể tạo `pip-*`, `pytest-of-*`,
  `tmpsnub_*` ngay trong repo. Các mẫu này đã được thêm vào `.gitignore`; không phải dữ liệu dự án.

## 4. Quy trình xác minh MT5 thủ công (cho Phase 1)

1. Mở MT5. Dùng `File → Open Data Folder` (tên menu có thể khác theo ngôn ngữ/build).
2. Xác nhận data folder mở đúng terminal đang dùng. Không commit đường dẫn tuyệt đối hoặc terminal ID vào repo.
3. Copy/sync EA từ `mt5/Experts/` vào `<Data Folder>/MQL5/Experts/` (thao tác thủ công, không tự động).
4. Mở MetaEditor (`F4`), mở file `.mq5`, compile (`F7`). Ghi lại số warning/error thực tế.
5. Trong MT5, mở Strategy Tester (`Ctrl+R`), chọn EA, symbol, timeframe, khoảng ngày và chế độ visual
   nếu cần. Chạy và đọc tab Journal/Experts.
6. Không chọn tài khoản thật để chạy; chỉ dùng dữ liệu lịch sử/offline theo roadmap.
7. Ghi lại build terminal và kết quả vào báo cáo phase tương ứng.

Không tuyên bố đã compile hoặc backtest thành công nếu chưa thực hiện các bước trên và đọc kết quả thật.

## 5. Kết quả compile Phase 1 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:"...\mt5\Experts\LabSignalEA.mq5" /log:"...\mt5\compile.log"` | Exit code **1**; log: `Result: 0 errors, 0 warnings, 885 ms elapsed, cpu='X64 Regular'`; tạo `LabSignalEA.ex5` (19,574 bytes) |
| Đọc `compile.log` (UTF-16) | Include `..\Include\LabLogger.mqh` resolve đúng; không có error/warning |

MetaEditor CLI trong môi trường này trả exit code 1 dù biên dịch thành công. Quy tắc: luôn đọc nội dung
log, không kết luận chỉ từ exit code. Strategy Tester **chưa chạy**; quy trình thủ công ở mục 4 và
`mt5/README.md`. Chi tiết Phase 1: [`phase-reports/phase-1.md`](phase-reports/phase-1.md).

## 6. Kết quả Python Phase 3 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install pyarrow` | Cài `pyarrow 26.0.0`; đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe -m pytest` | **38 passed in 1.48s** |
| `.venv\Scripts\python.exe scripts\validate_dataset.py python\tests\fixtures\synthetic_eurusd_m5.csv --symbol EURUSD --timeframe M5 --data-kind synthetic --out-dir reports\validation` | Exit code **0**; 6 rows, 0 errors, 1 warning (`synthetic_dataset`); ghi JSON + CSV thật |
| CLI trên file có timestamp trùng | Exit code **2**; 1 error (`duplicate_timestamps`); ghi JSON + CSV |

`pyarrow` cần cho Parquet; nếu môi trường khác thiếu package này, loader báo lỗi rõ và test Parquet
được skip. Chi tiết: [`phase-reports/phase-3.md`](phase-reports/phase-3.md).

## 7. Kết quả Python Phase 4 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install --no-cache-dir PyYAML==6.0.3` | Cài `PyYAML 6.0.3`; đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe -m pytest -q` | **62 passed in 1.67s** |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code **0**; 8 bar, 1 trade, final equity 10,294.60, net profit 294.60; artifact JSON/CSV thật |
| CLI trên dataset có timestamp trùng | Exit code **2**; `status=invalid_data`, lỗi `duplicate_timestamps`; vẫn ghi validation report |
| CLI với config thiếu `strategy` | Exit code **1**; `config_error: config.strategy is required` |
| CLI với `outputs.plot: true` | Exit code **0**; tạo `equity.png` |

Artifact mẫu nằm ở `reports/backtests/demo-ema-cross-synthetic/` (gitignored). Chi tiết giả định mô phỏng:
[`testing-guide.md`](testing-guide.md); báo cáo phase: [`phase-reports/phase-4.md`](phase-reports/phase-4.md).

## 8. Kết quả Phase 5 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:...\LabSignalEngineTests.mq5` | Log: 0 errors, 0 warnings, 872 ms; `.ex5` 18,504 bytes; exit code 1 (hành vi CLI đã biết) |
| `MetaEditor64.exe /compile:...\LabSignalExport.mq5` | Log: 0 errors, 0 warnings, 959 ms; `.ex5` 22,906 bytes; exit code 1 |
| `.venv\Scripts\python.exe -m pytest -q` | **79 passed in 2.03s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `.venv\Scripts\python.exe scripts\export_python_signals.py` | Exit code **0**; 12 dòng: 1 BUY, 1 SELL, 7 HOLD, 3 UNKNOWN; ghi `reports/parity/parity_signals_python.csv` |
| `.venv\Scripts\python.exe scripts\compare_signals.py --mql5 reports\parity\parity_signals_python.csv --python reports\parity\parity_signals_python.csv --out-dir reports\parity\self_check` | Exit code **0**; 12/12 hàng, 0 mismatch; đây là self-comparison, không phải parity MQL5/Python |
| Comparator với bản copy bị sửa ở một numeric, một signal và một reason | Exit code **1**; 3 mismatch được liệt kê theo timestamp/field trong JSON + CSV |

`LabSignalExport.mq5` **chưa được chạy** trong terminal; chỉ compile. Không có file
`parity_signals_mql5.csv` thật trong repo. Vì vậy chưa có kết luận tương đương MQL5/Python. Quy trình thủ
công: [`parity.md`](parity.md); báo cáo phase: [`phase-reports/phase-5.md`](phase-reports/phase-5.md).

## 9. Kết quả Phase 6 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **119 passed in 3.71s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `scripts\run_backtest.py --config configs\backtest.example.yaml --out-dir reports\backtests\phase6-nostore-check` | Exit code **0**; 8 bar, 1 trade, final equity 10,294.60; layout cũ, không tạo DB |
| `scripts\run_backtest.py ... --store --db experiments\phase6-demo.sqlite --experiment-id phase6-demo-a` | Exit code **0**; row `completed`; artifact trong `reports\backtests\phase6-demo\phase6-demo-a` |
| Chạy lại cùng ID `phase6-demo-a` | Exit code **4**; `duplicate_experiment`; row và summary cũ không đổi |
| Run `phase6-demo-b` cùng config | Exit code **0**; cùng config hash `bcdcefd7…` và data fingerprint `10c84c2e…` |
| `scripts\compare_experiments.py --baseline phase6-demo-a --run phase6-demo-b` | Exit code **0**; `comparable`, delta bằng 0 cho mọi metric; 3 warning: dirty worktree ×2, synthetic data |
| Run `phase6-demo-alt` với commission 5.0 mỗi chiều | Exit code **0**; final equity 10,289.60; config hash `4486451d…` khác baseline |
| `scripts\compare_experiments.py --baseline phase6-demo-a --run phase6-demo-alt` | Exit code **1**; `not_comparable`, reason `config_hash_mismatch`; báo cáo vẫn được ghi |
| `scripts\run_backtest.py` với dataset timestamp trùng, `--store` | Exit code **2**; row `invalid_data`; artifact summary + validation JSON/CSV |
| `scripts\run_backtest.py` với dataset không tồn tại, `--store` | Exit code **1**; row `failed`, `data_fingerprint=null`, error `load_error: ...` |

Database demo: `experiments/phase6-demo.sqlite` (gitignored). Report so sánh:
`reports/comparisons/phase6-demo-a__vs__phase6-demo-b/` và
`reports/comparisons/phase6-demo-a__vs__phase6-demo-alt/` (gitignored). Mọi kết quả là synthetic và
worktree đang dirty, nên so sánh chỉ xác nhận cơ chế tái lập/metadata, không phải bằng chứng hiệu năng.
Chi tiết: [`experiment-store.md`](experiment-store.md); báo cáo phase:
[`phase-reports/phase-6.md`](phase-reports/phase-6.md).

## 10. Kết quả Phase 7 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe scripts\generate_synthetic_ml_dataset.py` | Exit code **0**; 1.800 nến M5 EURUSD synthetic, seed 20261027 |
| `.venv\Scripts\python.exe scripts\train_ml_baseline.py --config configs\ml_baseline.example.yaml` | Exit code **0**; threshold 0.50; test ROC-AUC 0.5708, balanced accuracy 0.5584; ML lỗ -151.60 sau chi phí |
| `scripts\train_ml_baseline.py ... --store --db experiments\phase7-demo.sqlite --experiment-id phase7-demo-store` | Exit code **0**; row `completed`; 10 artifact có hash |
| Chạy lại cùng ID `phase7-demo-store` | Exit code **4**; `duplicate_experiment`; row/artifact cũ không đổi |
| `.venv\Scripts\python.exe -m pytest -q` | **143 passed in 8.55s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code **0** |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

`scikit-learn 1.9.1`, `numpy 2.4.6`, `pandas 2.3.3` đã có và được pin từ Phase 0; Phase 7 không cài
thêm dependency. Dataset/report ML nằm ở `datasets/samples/synthetic_ml_demo.csv` và
`reports/ml/demo-phase7-ml/` (report bị gitignore). Kết quả synthetic yếu, chiến lược ML lỗ sau chi phí
và kém buy & hold; không phải kết quả thị trường. Chi tiết: [`ml-baseline.md`](ml-baseline.md); báo cáo
phase: [`phase-reports/phase-7.md`](phase-reports/phase-7.md).

Kết quả ONNX và giới hạn runtime MT5 được ghi ở mục 11.

## 11. Kết quả Phase 8 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install onnx==1.23.2 onnxruntime==1.31.1` | Cài trong venv: `onnx 1.23.2`, `onnxruntime 1.31.1` (+ protobuf 7.36.2, ml_dtypes 0.6.0, flatbuffers 25.12.19, typing_extensions 4.16.0); đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe scripts\export_onnx_model.py --model reports\ml\demo-phase7-ml\model.json --out-dir models\candidates\demo-phase7-ml --fixture python\tests\fixtures\onnx_feature_fixture.csv` | Exit code **0**; `model.onnx` 566 bytes, SHA-256 `a7ae4a25…64f9d3`; opset 13, IR 8; 24 hàng parity, max abs diff `4.673e-08`, mean `1.953e-08`, tolerance `1e-5` → PASS |
| `MetaEditor64.exe /compile:...\mt5\Experts\LabOnnxInference.mq5 /log:...\mt5\onnx.compile.log` | Log: **0 errors, 0 warnings**, 700 ms; `.ex5` 12,284 bytes; exit code 1 (hành vi CLI đã biết) |
| `.venv\Scripts\python.exe -m pytest -q` | **150 passed in 8.76s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

`onnx`/`onnxruntime` chỉ dùng cho export và kiểm chứng offline trong venv; không cài system-wide.
Artifact ONNX nằm ở `models/candidates/demo-phase7-ml/` (gitignored). EA **chưa chạy** trong MT5
terminal/Strategy Tester, nên ONNX Runtime trong MT5 và parity runtime vẫn chưa được xác minh; Phase 8
giữ `READY_FOR_MANUAL_VALIDATION`. Quy trình thủ công: [`onnx-inference.md`](onnx-inference.md); báo cáo
phase: [`phase-reports/phase-8.md`](phase-reports/phase-8.md).

## 12. Kết quả Phase 9 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml` | Exit code **0**; backtest 1.800 bar, 49 trade, net +241,80; ML 299 test sample, ROC-AUC 0,5708, balanced accuracy 0,5584, ML net -151,60; báo cáo `reports\pipeline\demo-phase9\pipeline_report.md` |
| `.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml --run-id demo-phase9-b` | Exit code **0**; metric backtest/ML, data SHA-256 và `model_sha256` khớp lần chạy đầu |
| Chạy lại `demo-phase9` | Exit code **4**; báo cáo cũ không đổi |
| `scripts\export_onnx_model.py --model ...\missing-model.json` | Exit code **1**; `input_error: model artifact not found`; không tạo artifact |
| `.venv\Scripts\python.exe -m pytest -q` | **155 passed in 11.28s** |
| Snapshot commit sạch: `pytest -q` | **155 passed in 12.69s** |
| Snapshot commit sạch: `run_pipeline.py --run-id clean-check` | Exit `0`; metric backtest/ML, data SHA-256 và `model_sha256` khớp `demo-phase9`; chạy lại exit `4` |
| Snapshot commit sạch: export ONNX từ model mới | Exit `0`; parity 24/24 PASS, max abs diff `4.673e-08`; ONNX SHA `a7ae4a25…64f9d3` |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

Database demo: `experiments/phase9-demo.sqlite` (gitignored), hai row `demo-phase9-backtest` và
`demo-phase9-ml` ở trạng thái `completed`. Report và database bị gitignore; bản sao báo cáo đã lược
đường dẫn nằm ở [`phase-reports/phase-9-sample-report.md`](phase-reports/phase-9-sample-report.md).
Tái lập đã xác minh trên snapshot commit sạch tạm thời (116 file, commit `d3a9ea39…`, `git status`
rỗng); cần lặp lại ngắn sau commit chính thức để gắn với commit hash repository. Chi tiết:
[`end-to-end.md`](end-to-end.md); báo cáo phase: [`phase-reports/phase-9.md`](phase-reports/phase-9.md).

## 13. Kết quả trailing stop (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **170 passed in 15.13s** |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.trailing-synthetic.yaml` | Exit code **0**; 1.800 bar, 54 trade, 13 `trailing_stop`, 41 `opposite_signal`, final equity 10.175,60, net +175,60, max drawdown 251,40 |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code **0**; baseline không trailing giữ nguyên: 8 bar, 1 trade, net +294,60 |

Dữ liệu là synthetic; kết quả chỉ kiểm tra cơ chế, không phải hiệu năng thị trường. Chi tiết quy tắc và
giới hạn: [`trailing-stop.md`](trailing-stop.md).

## 14. Kết quả bounded DCA/grid (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **198 passed in 11.26s** |
| `.venv\Scripts\python.exe scripts\run_basket_backtest.py --config configs\backtest.bounded-basket-synthetic.yaml` | Exit code **0**; 1.800 bar, 57 basket, 70 layer, final equity 9.858,43, net **-141,57**, max drawdown 145,39, exposure 0,6372, profit factor 0,1243, win rate 0,2857; exit 19 `basket_take_profit` / 38 `opposite_signal`; max layer 4/4, units 4.000/4.000, 15 `blocked_add_bars`, 1 basket chạm cap layer, lỗ basket tệ nhất 28,14, overshoot 0 |
| `.venv\Scripts\python.exe scripts\run_basket_backtest.py --config configs\backtest.bounded-grid-synthetic.yaml` | Exit code **0**; 1.800 bar, 60 basket, 83 layer, final equity 9.860,46, net **-139,54**, max drawdown 150,94, exposure 0,5161, profit factor 0,3761, win rate 0,3373; exit 2 `basket_loss_cap` / 25 `basket_take_profit` / 33 `opposite_signal`; max layer 3/3, units 6.000/6.000, 0 `blocked_add_bars`, 4 basket chạm cap layer, lỗ basket tệ nhất 20,000000000001123 với cap 20, overshoot 0 |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code **0**; baseline không đổi: 8 bar, 1 trade, final equity 10.294,60, net +294,60 |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

Dữ liệu là synthetic; cả hai demo đều lỗ sau chi phí, chỉ kiểm tra cơ chế layer/cap chứ không phải hiệu
năng thị trường. Loss cap là lỗ ròng; demo grid cho thấy cap 20 giữ được lỗ thực tế ở mức 20,000000000001123
và `loss_cap_overshoot = 0`. Report nằm trong `reports/backtests/demo-bounded-dca-synthetic/` và
`reports/backtests/demo-bounded-grid-synthetic/` (gitignored). Chi tiết quy tắc, công thức và giới hạn:
[`bounded-basket.md`](bounded-basket.md).

## 15. Đồng bộ và compile trong MT5 EXNESS (2026-10-28)

- Data Folder: `%APPDATA%\MetaQuotes\Terminal\<terminal-id>\MQL5` (một terminal duy nhất có thư mục
  `MQL5` trên máy kiểm thử; ID cục bộ không ghi vào repo).
- Đã copy một lần theo yêu cầu người dùng: source `.mq5`, include `.mqh`, fixture ONNX và `model.onnx`
  vào `MQL5\Files`; `parity_ema_cross.csv` vào `Terminal\Common\Files` cho `LabSignalExport`. Không có
  script tự động hóa trong repo (ADR 0001); mọi lần sync sau vẫn thủ công.
- Compile bằng MetaEditor64 CLI: `LabSignalEA.mq5`, `LabOnnxInference.mq5`,
  `LabSignalEngineTests.mq5`, `LabSignalExport.mq5` → **0 errors, 0 warnings** cho cả bốn file; CLI trả
  exit `1` như hành vi đã biết. `.ex5` đã sinh trong Data Folder.
- **Chưa** đăng nhập tài khoản, chưa chạy script, chưa chạy Strategy Tester và chưa xác minh ONNX runtime;
  các bước thủ công tiếp theo ở [`guide.md`](guide.md).
- Không bật execution: `LabSignalEA` là signal-only, 0 trade là đúng; ranh giới này ghi ở
  [`decisions/0002-execution-boundary.md`](decisions/0002-execution-boundary.md).
- Log compile nằm ở `reports/mt5/*.compile.log` (gitignored).
