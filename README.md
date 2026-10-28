# MT5 EA & AI Lab

Repository nghiên cứu độc lập để phát triển EA MQL5, pipeline dữ liệu/ML bằng Python và quy trình
backtest có thể tái lập cho MetaTrader 5.

- **Trạng thái:** Phase 9 — end-to-end pipeline **DONE** (2026-10-27; tái lập trên snapshot commit sạch
  đã xác minh 2026-10-28). Phase 8 — ONNX/MQL5 inference **READY_FOR_MANUAL_VALIDATION**: export ONNX và
  parity Python–ONNX đã chạy thật; EA `LabOnnxInference.mq5` compile 0 errors/0 warnings nhưng chưa chạy
  trong terminal. Phase 0/3/4/6/7/9 **DONE**; Phase 5 **READY_FOR_MANUAL_VALIDATION** (MQL5 export đã
  compile nhưng chưa chạy); Phase 1/2 compile 0 errors/0 warnings, chờ chạy Strategy Tester/self-check
  thủ công. Track C W1–W7, W9, W10 **PASS** (compile + static + toolchain); `SimCoreTests` 123/0 và
  `SimPlanTests` 39/0 đã **PASS runtime** trong MT5 ngày 2026-10-28; W8 Strategy Tester **`NOT_RUN`** —
  4 EA mô phỏng chưa chạy trong terminal.
- **Phạm vi hiện tại:** signal-only, mô phỏng offline (SL/TP tĩnh, trailing stop, bounded DCA/grid
  basket và vị thế ảo theo trade plan của PinePort), metadata thí nghiệm cục bộ, ML baseline, ONNX
  inference-only và pipeline end-to-end trên dữ liệu synthetic. Không gửi lệnh giao dịch thật, không
  kết nối tài khoản môi giới, không lưu thông tin đăng nhập.
- **MT5:** 24 file `.mq5` và 19 file `.mqh` đã compile **0 errors, 0 warnings** bằng
  `scripts/build-mql5.ps1` (2026-10-28); self-check, parity runtime, ONNX runtime, `SimCoreTests`,
  `SimPlanTests` và Strategy Tester vẫn chờ chạy thủ công. Quy trình:
  [`docs/guides/install-and-test.md`](docs/guides/install-and-test.md).
- **Ranh giới execution:** repo này không hỗ trợ live execution. Quyết định và điều kiện cho một scope
  demo-only riêng nằm ở [`docs/decisions/0002-execution-boundary.md`](docs/decisions/0002-execution-boundary.md).
- **Tài liệu nguồn:** [`docs/ROADMAP_MT5_EA_AI_LAB.md`](docs/ROADMAP_MT5_EA_AI_LAB.md) và
  [`docs/PROMPT_AI_IMPLEMENT_ROADMAP.md`](docs/PROMPT_AI_IMPLEMENT_ROADMAP.md).

> Kết quả backtest/mô phỏng không đảm bảo lợi nhuận trong tương lai. Mọi con số phải ghi rõ dữ liệu,
> khoảng thời gian, giả định chi phí và trạng thái dữ liệu (thực, sample hay synthetic).

## Yêu cầu môi trường

| Thành phần | Yêu cầu | Đã xác minh trong Phase 0 |
|---|---|---|
| OS | Windows 10/11 64-bit | Windows 10.0.19045.6456 |
| Python | 3.11 64-bit | 3.11.9 (64-bit) |
| Git | 2.x | 2.53.0.windows.3 |
| MT5 + MetaEditor | Bản cài chính thức | MT5 5.0.0.6249 (bản EXNESS), có `MetaEditor64.exe`, `metatester64.exe` |

Chi tiết kiểm kê, trạng thái từng mục và các bước xác minh thủ công còn lại:
[`docs/guides/install-and-test.md`](docs/guides/install-and-test.md).

## Thiết lập môi trường (PowerShell)

```powershell
# Từ thư mục gốc repository
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1

# venv dùng pip đi kèm (pip 24.0); nâng cấp pip là tùy chọn
pip install -r requirements.txt

# Chạy kiểm thử
python -m pytest
```

Nếu PowerShell chặn script kích hoạt, dùng trực tiếp interpreter của venv thay vì đổi chính sách
thực thi toàn hệ thống:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pytest
```

## Cấu trúc repository

```text
tm-fx/                             # tên thư mục hiện tại; nội dung theo roadmap "mt5-ea-ai-lab"
├── README.md
├── requirements.txt
├── pyproject.toml                 # cấu hình pytest; chưa đóng gói package
├── configs/                       # ví dụ data/strategy/experiment/backtest/ML/pipeline
├── docs/
│   ├── README.md                  # điểm vào duy nhất cho toàn bộ tài liệu
│   ├── PROGRESS.md                # nhật ký phase/W + trạng thái thật
│   ├── MASTER_ROADMAP.md
│   ├── ROADMAP_MT5_EA_AI_LAB.md
│   ├── PROMPT_AI_IMPLEMENT_ROADMAP.md
│   ├── guides/                    # install-and-test, strategy-tester, toolchain
│   ├── indicators/                # inventory, parity, 6 tài liệu indicator PinePort
│   ├── reference/                 # architecture, simulation, testing, risk, release, …
│   ├── decisions/
│   ├── phase-reports/
│   └── *-pack/                    # input pack gốc, chỉ đọc
├── mt5/
│   ├── Experts/                   # signal-only, ONNX harness, 4 EA mô phỏng
│   ├── Include/                   # Logger, Indicators, SignalEngine, PinePort, Sim
│   ├── Indicators/PinePort/       # 6 indicator port
│   ├── Files/                     # fixture CSV cho ONNX runtime (copy sang MQL5/Files)
│   └── Scripts/                   # self-check, parity export, contract/sim tests
├── python/
│   ├── src/mt5_ea_ai_lab/
│   │   ├── data/                  # loader CSV/Parquet (Phase 3)
│   │   ├── validation/            # OHLCV validation + report (Phase 3)
│   │   ├── features/              # causal feature pipeline (Phase 7)
│   │   ├── labels/                # forward direction labels + horizon (Phase 7)
│   │   ├── signals/               # EMA crossover signal-only (Phase 4)
│   │   ├── backtest/              # position lifecycle, cost model, prediction simulation (Phase 4, 7)
│   │   ├── models/                # logistic baseline, purged time splits, model card, ONNX (Phase 7–8)
│   │   ├── evaluation/            # metric, benchmark, parity comparator, ML metrics (Phase 4–7)
│   │   └── experiment_store/      # SQLite metadata, fingerprint, comparison (Phase 6)
│   └── tests/                     # unit tests + fixture synthetic
├── datasets/{raw,processed,samples}/
├── models/{candidates/,registry.json}
├── experiments/                   # SQLite metadata local (Phase 6, gitignored)
├── reports/                       # báo cáo sinh ra (Phase 3+)
└── scripts/                       # validate, backtest, parity, ML, ONNX, pipeline
```

Backtest hiện chỉ hỗ trợ một symbol và baseline EMA crossover hoặc ML prediction horizon cố định.
Engine một vị thế có SL/TP tĩnh và trailing stop tùy chọn. Bounded DCA/grid là simulator **riêng**,
một basket tại một thời điểm với cap layer/unit/loss; không có pyramiding theo tín hiệu, không có nhiều
basket song song. Cả hai engine đều không có execution. Experiment store là SQLite cục bộ, không phải
dịch vụ từ xa. Phase 9 có một lệnh chạy validate → backtest → ML → store → report trên cùng dataset;
pipeline không bao gồm MT5 Strategy Tester, ONNX runtime, bounded basket hay execution.

## Cấu hình mẫu

- [`configs/data.example.yaml`](configs/data.example.yaml)
- [`configs/strategy.example.yaml`](configs/strategy.example.yaml)
- [`configs/backtest.example.yaml`](configs/backtest.example.yaml)
- [`configs/backtest.synthetic-ml.yaml`](configs/backtest.synthetic-ml.yaml)
- [`configs/backtest.trailing-synthetic.yaml`](configs/backtest.trailing-synthetic.yaml)
- [`configs/backtest.bounded-basket-synthetic.yaml`](configs/backtest.bounded-basket-synthetic.yaml)
- [`configs/backtest.bounded-grid-synthetic.yaml`](configs/backtest.bounded-grid-synthetic.yaml)
- [`configs/experiment.example.yaml`](configs/experiment.example.yaml)
- [`configs/ml_baseline.example.yaml`](configs/ml_baseline.example.yaml)
- [`configs/pipeline.example.yaml`](configs/pipeline.example.yaml)

Mọi giá trị (symbol, timeframe, chi phí) là placeholder, không phải kết quả thị trường.
`configs/experiment.example.yaml` là cấu hình runnable cho experiment store; dữ liệu vẫn là synthetic.
`configs/ml_baseline.example.yaml` chạy ML baseline trên `datasets/samples/synthetic_ml_demo.csv`.
`configs/pipeline.example.yaml` chạy pipeline end-to-end trên cùng dataset synthetic đó và lưu hai run
vào `experiments/phase9-demo.sqlite`.

## Lệnh

```powershell
# Phase 3 — validate CSV/Parquet, ghi JSON + CSV vào reports/validation/
.\.venv\Scripts\python.exe scripts\validate_dataset.py `
  python\tests\fixtures\synthetic_eurusd_m5.csv `
  --symbol EURUSD --timeframe M5 --data-kind synthetic

# Phase 4 — backtest baseline EMA crossover từ YAML
.\.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml

# Trailing stop — mô phỏng trên cùng dataset synthetic
.\.venv\Scripts\python.exe scripts\run_backtest.py `
  --config configs\backtest.trailing-synthetic.yaml

# Bounded DCA/grid — simulator riêng, hard cap layer/unit/loss
.\.venv\Scripts\python.exe scripts\run_basket_backtest.py `
  --config configs\backtest.bounded-basket-synthetic.yaml
.\.venv\Scripts\python.exe scripts\run_basket_backtest.py `
  --config configs\backtest.bounded-grid-synthetic.yaml

# Phase 5 — export tín hiệu Python và so sánh với export MQL5
.\.venv\Scripts\python.exe scripts\export_python_signals.py
.\.venv\Scripts\python.exe scripts\compare_signals.py `
  --mql5 reports\parity\parity_signals_mql5.csv `
  --python reports\parity\parity_signals_python.csv `
  --out-dir reports\parity\mql5_vs_python

# Phase 6 — backtest có metadata SQLite; artifact vào <report_dir>\<experiment_id>
.\.venv\Scripts\python.exe scripts\run_backtest.py `
  --config configs\experiment.example.yaml --store --experiment-id demo-phase6-001

# Phase 6 — so sánh hai run đã lưu
.\.venv\Scripts\python.exe scripts\compare_experiments.py `
  --db experiments\experiments.sqlite `
  --baseline demo-phase6-001 --run demo-phase6-002

# Phase 7 — train/evaluate ML baseline; artifact + model card vào reports/ml/<experiment_id>
.\.venv\Scripts\python.exe scripts\train_ml_baseline.py `
  --config configs\ml_baseline.example.yaml
# Tùy chọn lưu metadata vào experiment store (ID trùng bị từ chối)
.\.venv\Scripts\python.exe scripts\train_ml_baseline.py `
  --config configs\ml_baseline.example.yaml --store --experiment-id phase7-demo-001

# Phase 8 — export model sang ONNX và so sánh Python–ONNX trên fixture cố định
.\.venv\Scripts\python.exe scripts\export_onnx_model.py `
  --model reports\ml\demo-phase7-ml\model.json `
  --out-dir models\candidates\demo-phase7-ml `
  --fixture python\tests\fixtures\onnx_feature_fixture.csv

# Phase 9 — pipeline end-to-end: validate -> backtest -> ML -> store -> report
.\.venv\Scripts\python.exe scripts\run_pipeline.py `
  --config configs\pipeline.example.yaml --run-id demo-phase9

# Chạy toàn bộ unit test
.\.venv\Scripts\python.exe -m pytest

# W7 — toolchain dùng chung (check, build, test, validate, package)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-environment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-python-tests.ps1
.\.venv\Scripts\python.exe scripts\validate-project.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-source.ps1 -Version 0.8.1
```

`validate_dataset.py` trả exit code `0` khi pass (warning được phép), `1` khi không đọc được file, `2`
khi có lỗi validation. `run_backtest.py` trả `0` khi hoàn tất, `1` khi lỗi config/dataset, `2` khi dữ
liệu không hợp lệ, `3` khi backtest lỗi, `4` khi `experiment_id` đã tồn tại và `5` khi store không
mở/ghi được. `run_basket_backtest.py` trả `0` khi mô phỏng hoàn tất, `1` khi config/dataset lỗi, `2` khi
validation dữ liệu thất bại và `3` khi mô phỏng lỗi; CLI này chưa nối experiment store.
`train_ml_baseline.py` dùng cùng quy ước `0–5`, trong đó `3` là lỗi feature/split/train/
evaluate. `compare_signals.py` trả `0` khi mọi hàng khớp, `1` khi có mismatch và `2` khi input không
hợp lệ. `compare_experiments.py` trả `0` khi comparable, `1` khi không comparable và `2` khi thiếu
database/run. `export_onnx_model.py` trả `0` khi export và parity đạt, `1` khi model/fixture/output
không đọc/ghi được và `2` khi ONNX validation hoặc parity thất bại. `run_pipeline.py` trả `0` khi cả
hai stage hoàn tất, `1` khi config/stage config không đọc được hoặc không nhất quán, `2` khi dataset
không hợp lệ, `3` khi một stage thất bại, `4` khi run ID hoặc experiment ID đã tồn tại và `5` khi store
không mở/ghi được. Giả định mô phỏng và định nghĩa metric:
[`docs/reference/testing.md`](docs/reference/testing.md). Quy trình parity và tolerance:
[`docs/reference/parity.md`](docs/reference/parity.md). Schema/trạng thái store và quy tắc comparability:
[`docs/reference/experiment-store.md`](docs/reference/experiment-store.md). Quy trình ML, label/split và giới hạn:
[`docs/reference/ml-baseline.md`](docs/reference/ml-baseline.md). Trailing stop, activation, quy ước bar kế tiếp và giới hạn:
[`docs/reference/trailing-stop.md`](docs/reference/trailing-stop.md). Bounded DCA/grid, hard cap, quy tắc fill và giới hạn:
[`docs/reference/bounded-basket.md`](docs/reference/bounded-basket.md).

## An toàn và giới hạn

- Không có `OrderSend`, `CTrade.Buy`, `CTrade.Sell` hoặc đường thực thi lệnh nào trong repository.
- Không commit `.env`, mật khẩu, token, `accounts.dat`, `servers.dat` hay dữ liệu tài khoản.
- Không đặt secret trong config, `notes` hay artifact: SQLite store lưu `config_json`, `notes` và đường
  dẫn artifact.
- Dữ liệu lớn, model artifact, log, SQLite database và output thí nghiệm bị loại khỏi Git (xem
  `.gitignore`).
- Không kết nối Exness hay bất kỳ tài khoản môi giới nào. Không chạy live execution trong repo này;
  `LabSignalEA` là signal-only và **0 trade là kết quả đúng**. Xem
  [`docs/decisions/0002-execution-boundary.md`](docs/decisions/0002-execution-boundary.md).
- ML baseline chỉ dùng dữ liệu synthetic trong demo; metric phân loại và metric chiến lược mô phỏng được
  báo cáo riêng, không phải bằng chứng lợi nhuận.
- Bounded DCA/grid có simulator Python và 4 EA MQL5 mô phỏng (runner/grid/DCA/plan) chưa chạy trong
  terminal; không nối experiment store và không thay đổi engine một vị thế. Demo synthetic lỗ sau chi
  phí, không dùng làm khuyến nghị chiến lược.
- Pipeline Phase 9 chỉ chạy validate/backtest/ML/store/report cục bộ; không chạy MT5 Strategy Tester,
  ONNX runtime hay bất kỳ đường thực thi lệnh nào.
- Run ID và experiment ID là bất biến: chạy lại cùng ID bị từ chối thay vì ghi đè báo cáo cũ.

Danh sách rủi ro đầy đủ: [`docs/reference/risk.md`](docs/reference/risk.md).
Báo cáo Phase 0: [`docs/phase-reports/phase-0.md`](docs/phase-reports/phase-0.md).
Báo cáo Phase 1: [`docs/phase-reports/phase-1.md`](docs/phase-reports/phase-1.md).
Báo cáo Phase 2: [`docs/phase-reports/phase-2.md`](docs/phase-reports/phase-2.md).
Báo cáo Phase 3: [`docs/phase-reports/phase-3.md`](docs/phase-reports/phase-3.md).
Báo cáo Phase 4: [`docs/phase-reports/phase-4.md`](docs/phase-reports/phase-4.md).
Báo cáo Phase 5: [`docs/phase-reports/phase-5.md`](docs/phase-reports/phase-5.md).
Báo cáo Phase 6: [`docs/phase-reports/phase-6.md`](docs/phase-reports/phase-6.md).
Báo cáo Phase 7: [`docs/phase-reports/phase-7.md`](docs/phase-reports/phase-7.md).
Báo cáo Phase 8: [`docs/phase-reports/phase-8.md`](docs/phase-reports/phase-8.md).
Báo cáo Phase 9: [`docs/phase-reports/phase-9.md`](docs/phase-reports/phase-9.md).
Báo cáo mẫu Phase 9: [`docs/phase-reports/phase-9-sample-report.md`](docs/phase-reports/phase-9-sample-report.md).
Đặc tả tín hiệu: [`docs/reference/strategy-signal-spec.md`](docs/reference/strategy-signal-spec.md).
Parity MQL5/Python: [`docs/reference/parity.md`](docs/reference/parity.md).
Experiment store: [`docs/reference/experiment-store.md`](docs/reference/experiment-store.md).
ML baseline: [`docs/reference/ml-baseline.md`](docs/reference/ml-baseline.md).
ONNX inference: [`docs/reference/onnx.md`](docs/reference/onnx.md).
Pipeline end-to-end: [`docs/reference/pipeline.md`](docs/reference/pipeline.md).
Bounded DCA/grid: [`docs/reference/bounded-basket.md`](docs/reference/bounded-basket.md).
Simulation core MQL5 (portfolio/logger/validate): [`docs/reference/simulation.md`](docs/reference/simulation.md).
Runner trailing, Grid, DCA và PinePlanSimEA (mô phỏng): [`docs/reference/simulation.md`](docs/reference/simulation.md).
Preset/validator fail-closed: [`docs/reference/simulation.md`](docs/reference/simulation.md).
Toolchain root (check/build/test/validate/package): [`docs/guides/toolchain.md`](docs/guides/toolchain.md).
Strategy Tester cho 4 EA mô phỏng: [`docs/guides/strategy-tester.md`](docs/guides/strategy-tester.md).
Cài đặt/kiểm thử Track C: [`docs/guides/install-and-test.md`](docs/guides/install-and-test.md).
Mục lục tài liệu đầy đủ: [`docs/README.md`](docs/README.md).
Release checklist: [`docs/reference/release.md`](docs/reference/release.md).
Từ điển dữ liệu: [`docs/reference/data-dictionary.md`](docs/reference/data-dictionary.md).
Hướng dẫn MT5: [`docs/guides/install-and-test.md`](docs/guides/install-and-test.md), [`mt5/README.md`](mt5/README.md).
Ranh giới execution: [`docs/decisions/0002-execution-boundary.md`](docs/decisions/0002-execution-boundary.md).
