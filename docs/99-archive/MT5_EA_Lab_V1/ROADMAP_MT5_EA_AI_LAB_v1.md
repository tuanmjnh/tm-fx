# MT5 EA & AI Lab — Roadmap xây dựng EA và AI Trading Bot cho MT5/Exness

- **Phiên bản tài liệu:** 1.0
- **Ngày lập:** 2026-10-27
- **Ngôn ngữ tài liệu:** Tiếng Việt
- **Phạm vi:** Dự án độc lập, không phụ thuộc `tm-trading`, `tm-hub` hay bất kỳ dự án hiện có nào khác.
- **Nguyên tắc mặc định:** Nghiên cứu, backtest và mô phỏng. Không gửi lệnh giao dịch thật; không yêu cầu hoặc lưu thông tin đăng nhập tài khoản môi giới.

> Tài liệu này là kế hoạch kỹ thuật để xây dựng môi trường nghiên cứu EA/AI. Kết quả backtest không đảm bảo lợi nhuận trong tương lai. Không được chuyển sang giao dịch tiền thật chỉ dựa trên kết quả mô phỏng.
>
> **Cập nhật 2026-10-29:** nguyên tắc "không gửi lệnh" được nới đúng một phạm vi — execution
> **chỉ trên tài khoản demo**, qua `PATrendRiderXAUv1DemoEA` + `mt5/Include/Exec/*`, dry-run mặc định,
> theo [`decisions/0003-demo-execution-scope.md`](../../decisions/0003-demo-execution-scope.md). Live/real vẫn
> bị cấm và cần ADR mới. Các phase mô tả EA signal-only bên dưới vẫn giữ nguyên hành vi đó.

---

## 1. Tầm nhìn và mục tiêu

Xây dựng một bộ công cụ độc lập để:

1. Viết và kiểm thử **EA bằng MQL5** trong MetaTrader 5.
2. Phát triển **pipeline dữ liệu, feature engineering, mô hình ML và đánh giá bằng Python**.
3. So sánh tín hiệu MQL5 và Python trên cùng bộ dữ liệu.
4. Mô phỏng kết quả chiến lược với các giả định chi phí rõ ràng.
5. Lưu lịch sử thí nghiệm, tham số, phiên bản code/model, chỉ số và báo cáo.
6. Nghiên cứu tích hợp mô hình đã huấn luyện vào MQL5 bằng ONNX khi các giai đoạn trước đã đạt tiêu chí.
7. Tạo nền tảng để sau này có thể mở rộng sang công cụ nghiên cứu khác mà không gắn chặt với một broker hay một dự án phần mềm khác.

### 1.1 Mục tiêu không thuộc phiên bản đầu

- Không triển khai tự động gửi lệnh giao dịch thật.
- Không lưu mật khẩu, mã xác thực, investor password, token hay thông tin nhạy cảm của tài khoản môi giới.
- Không xây dựng cơ chế vượt giới hạn của broker, né giám sát hoặc giả mạo môi trường.
- Không cam kết hoặc tối ưu theo mục tiêu “đảm bảo thắng”, “đảm bảo lợi nhuận” hay chỉ số duy nhất.
- Chưa cần dashboard web, cloud deployment, microservices, agent tự thao tác máy tính, Telegram, tin tức/LLM hay đa tài sản trong MVP.

## 2. Người dùng và cách sử dụng dự kiến

- **Nhà phát triển:** Viết MQL5, Python, cấu hình và bài kiểm thử.
- **Nhà nghiên cứu:** Chạy backtest, phân tích chỉ số, so sánh các phiên bản và đánh giá mô hình.
- **MT5 desktop:** Môi trường chạy EA và Strategy Tester.
- **Python local environment:** Môi trường xử lý dữ liệu, huấn luyện mô hình và báo cáo.

Nên dùng Windows 11 cho môi trường phát triển ban đầu vì MetaTrader 5/MetaEditor là ứng dụng Windows phổ biến. Các bước cài đặt và tên menu cần được xác minh theo phiên bản MT5 thực tế trên máy.

## 3. Stack công nghệ đề xuất

| Thành phần | Công nghệ | Vai trò |
|---|---|---|
| EA và custom indicator | MQL5 | Đọc dữ liệu, tính toán chỉ báo, tạo tín hiệu, ghi log, chạy Strategy Tester |
| Phân tích dữ liệu | Python 3.11 64-bit (điểm khởi đầu đề xuất) | Làm sạch dữ liệu, đặc trưng, backtest nghiên cứu, đánh giá |
| Dữ liệu dạng bảng | pandas, NumPy | Xử lý dữ liệu và tính toán |
| ML cơ bản | scikit-learn | Baseline và mô hình phân loại/hồi quy ban đầu |
| Biểu đồ nghiên cứu | matplotlib | Trực quan hóa kết quả |
| Dữ liệu trung gian | CSV, Parquet | Lưu dữ liệu OHLC, feature, tín hiệu và kết quả |
| Metadata/thí nghiệm | SQLite | Lưu cấu hình, lịch sử chạy, metric và tham chiếu tới artifact |
| Kiểm thử Python | pytest | Unit test và regression test |
| Kiểm thử EA | MetaEditor compiler + MT5 Strategy Tester | Biên dịch, debug và kiểm thử logic EA |
| Quản lý mã nguồn | Git | Lưu lịch sử thay đổi và phiên bản |
| Tích hợp mô hình về sau | ONNX + API ONNX trong MQL5 (nếu tương thích) | Chạy suy luận trong MQL5 mà không cần gọi dịch vụ Python ở mỗi tick |

### 3.1 Quy tắc lựa chọn công nghệ

- Không thêm thư viện nếu chưa có yêu cầu rõ ràng.
- Khóa phiên bản các dependency trong `requirements.txt` hoặc lock file khi baseline đã ổn định.
- Xác minh tương thích phiên bản Python, MetaTrader 5 terminal, package MetaTrader5 và ONNX trước khi phụ thuộc vào chúng.
- Ưu tiên code dễ đọc, dễ kiểm thử và có thể tái tạo kết quả trước tối ưu hiệu năng.

## 4. Kiến trúc tổng thể

```text
                 ┌───────────────────────────┐
                 │ Data sources / MT5 history│
                 └─────────────┬─────────────┘
                               │
                 ┌─────────────▼─────────────┐
                 │ Data ingestion & validation│
                 │ Python, CSV/Parquet        │
                 └─────────────┬─────────────┘
                               │
                  ┌────────────▼────────────┐
                  │ Shared data contract    │
                  │ timestamp/OHLC/spread   │
                  └───────┬──────────┬──────┘
                          │          │
             ┌────────────▼───┐  ┌───▼────────────────┐
             │ EA / MQL5      │  │ Python research    │
             │ indicators     │  │ features / ML      │
             │ signal engine  │  │ backtest / metrics  │
             └────────────┬───┘  └───┬────────────────┘
                          │          │
                          └────┬─────┘
                               │
                  ┌────────────▼────────────┐
                  │ Validation & comparison │
                  │ MT5 tester / Python     │
                  └────────────┬────────────┘
                               │
                  ┌────────────▼────────────┐
                  │ Reports & experiment DB │
                  │ CSV / JSON / SQLite     │
                  └─────────────────────────┘
```

### 4.1 Nguyên tắc kiến trúc

1. **Tách signal khỏi execution:** signal engine không được tự gửi lệnh. MVP chỉ phát tín hiệu và mô phỏng.
2. **Tách dữ liệu khỏi mô hình:** mô hình không tự lấy dữ liệu tùy ý; đầu vào phải qua data contract đã kiểm tra.
3. **Tái lập:** mọi lần chạy cần lưu phiên bản code, cấu hình, data range, symbol, timeframe, seed nếu áp dụng và phiên bản thư viện.
4. **Không look-ahead:** feature tại thời điểm `t` chỉ sử dụng dữ liệu sẵn có đến `t`.
5. **Không phụ thuộc mạng trong backtest chính:** backtest nên sử dụng snapshot dữ liệu và artifact đã lưu, không phụ thuộc API live.
6. **Fail closed:** dữ liệu thiếu, model không tải được, schema sai hoặc giá trị NaN/Inf phải tạo lỗi rõ ràng; không tự suy diễn tín hiệu.
7. **Không gửi lệnh thật:** không viết hoặc bật đường đi gọi `OrderSend`, `CTrade.Buy`, `CTrade.Sell` hay execution tương tự trong MVP. Nếu repository có code như vậy, phải đánh dấu và giữ tắt trong phạm vi này.

## 5. Cấu trúc repository mục tiêu

```text
mt5-ea-ai-lab/
├── README.md
├── ROADMAP_MT5_EA_AI_LAB.md
├── PROMPT_AI_IMPLEMENT_ROADMAP.md
├── requirements.txt
├── pyproject.toml                 # tùy chọn, nếu cần cấu hình package/lint
├── .gitignore
├── configs/
│   ├── data.example.yaml
│   ├── strategy.example.yaml
│   └── experiment.example.yaml
├── docs/
│   ├── architecture.md
│   ├── data-dictionary.md
│   ├── testing-guide.md
│   ├── risk-and-limitations.md
│   └── decisions/
├── mt5/
│   ├── Experts/
│   │   └── LabSignalEA.mq5
│   ├── Include/
│   │   ├── Indicators.mqh
│   │   ├── SignalEngine.mqh
│   │   └── Logger.mqh
│   └── README.md                  # cách cài/sync sang Data Folder MT5
├── python/
│   ├── src/mt5_ea_ai_lab/
│   │   ├── data/
│   │   ├── validation/
│   │   ├── features/
│   │   ├── labels/
│   │   ├── signals/
│   │   ├── backtest/
│   │   ├── models/
│   │   ├── evaluation/
│   │   ├── reporting/
│   │   └── experiment_store/
│   └── tests/
├── datasets/
│   ├── raw/                       # không commit dữ liệu lớn/quyền hạn chế
│   ├── processed/
│   └── samples/                   # chỉ chứa mẫu nhỏ, không nhạy cảm
├── models/
│   ├── candidates/                # artifact local, có thể gitignore
│   └── registry.json              # metadata phiên bản model, không chứa bí mật
├── experiments/
│   └── README.md
├── reports/
│   └── README.md
└── scripts/
    ├── validate_dataset.py
    ├── run_backtest.py
    └── compare_signals.py
```

AI coding agent có thể điều chỉnh tên thư mục theo cấu trúc repository hiện có nhưng phải giữ nguyên sự phân tách về chức năng và giải thích mọi thay đổi kiến trúc.

## 6. Data contract và schema

### 6.1 Dữ liệu giá chuẩn

Schema chuẩn hóa tối thiểu:

| Trường | Kiểu đề xuất | Quy tắc |
|---|---|---|
| `timestamp` | datetime UTC hoặc timezone được ghi rõ | Không trùng trong cùng series; sắp xếp tăng dần |
| `symbol` | string | Phải giữ tên symbol gốc và metadata liên quan |
| `timeframe` | string | Ví dụ M5, M15, H1; phải xác thực |
| `open` | float64 | Hữu hạn, lớn hơn 0 nếu là giá thông thường |
| `high` | float64 | `high >= max(open, close, low)` |
| `low` | float64 | `low <= min(open, close, high)` |
| `close` | float64 | Hữu hạn, lớn hơn 0 nếu là giá thông thường |
| `tick_volume` | int/float nullable | Không giả định giống real volume |
| `spread` | numeric nullable | Ghi rõ đơn vị và cách lấy |
| `source` | string | Nguồn dữ liệu và loại snapshot |

Không giả định mọi symbol đều là FX. Quy tắc về giá, tick size, contract size, volume step, point và digits cần được lấy từ metadata của symbol tương ứng nếu thật sự cần sử dụng. Không hardcode thông số cho mọi sản phẩm.

### 6.2 Dữ liệu tín hiệu

Các trường tối thiểu:

- `event_time`
- `symbol`
- `timeframe`
- `strategy_id`
- `strategy_version`
- `signal` (`BUY`, `SELL`, `HOLD`, `UNKNOWN` hoặc enum nội bộ tương đương)
- `reason_codes`
- `input_bar_time`
- `feature_snapshot` hoặc tham chiếu tới feature file
- `model_id` và `model_version` nếu có AI
- `created_at`

Tín hiệu `UNKNOWN`/lỗi dữ liệu phải khác với `HOLD`: `HOLD` là quyết định của logic; `UNKNOWN` là không thể đánh giá đáng tin cậy.

### 6.3 Dữ liệu giao dịch mô phỏng

- ID giao dịch mô phỏng, strategy/version, symbol và timeframe.
- Thời điểm tín hiệu, thời điểm giả lập vào/ra.
- Giá giả lập, spread, slippage, commission và các chi phí liên quan.
- Lý do thoát, P&L trước/sau chi phí.
- Các giả định của mô hình khớp lệnh.

Không gọi những kết quả này là kết quả giao dịch thật.

## 7. Roadmap theo giai đoạn

## Phase 0 — Khởi tạo và kiểm kê môi trường

**Mục tiêu:** repository có tài liệu, cấu hình và cách chạy kiểm thử rõ ràng.

### Công việc
- Kiểm tra Windows, Python, Git, MT5 desktop và MetaEditor có sẵn hay chưa.
- Không tự cài phần mềm toàn hệ thống hoặc thay đổi PATH mà chưa thông báo.
- Tạo cấu trúc thư mục mục tiêu.
- Tạo `.gitignore` cho `.venv`, dữ liệu lớn, credentials, log cục bộ và model artifact nếu cần.
- Tạo `README.md`, hướng dẫn thiết lập và lệnh chạy.
- Ghi các giả định phiên bản trong tài liệu.

### Deliverables
- Skeleton repository.
- `README.md`, `docs/reference/architecture.md`, `docs/reference/risk.md`.
- Python virtual environment hướng dẫn được, dependency list ban đầu.
- Checklist môi trường và trạng thái kiểm tra.

### Acceptance criteria
- Người khác đọc README biết cách chuẩn bị môi trường và chạy test.
- Không có bí mật hoặc dữ liệu tài khoản trong Git.
- Chưa có logic giao dịch thật.

## Phase 1 — EA signal-only đầu tiên

**Mục tiêu:** xác nhận MQL5 compile được, khởi tạo đúng và đọc được bar/time-series trong Strategy Tester.

### Công việc
- Tạo `LabSignalEA.mq5` chỉ log trạng thái và bar mới.
- Xử lý `OnInit`, `OnTick`, `OnDeinit`.
- Kiểm tra lỗi dữ liệu trả về từ API MQL5.
- Ghi log có cấu trúc, tránh spam log theo từng tick nếu không cần.
- Viết hướng dẫn copy/sync file vào `MQL5/Experts` của đúng terminal.
- Chạy biên dịch bằng MetaEditor và thử Strategy Tester thủ công nếu môi trường cho phép.

### Deliverables
- EA signal-only.
- `mt5/README.md`.
- Mẫu log và hướng dẫn xác minh.

### Acceptance criteria
- Code không chứa hàm gửi lệnh.
- Biên dịch thành công trong MetaEditor hoặc lỗi môi trường được ghi rõ.
- Có cách xác minh bar time và symbol/timeframe trong log.
- Agent không được tuyên bố đã compile hoặc backtest thật nếu không có công cụ MT5 để xác nhận.

## Phase 2 — Signal engine và chỉ báo

**Mục tiêu:** tách tính toán chỉ báo khỏi quyết định tín hiệu.

### Công việc
- Tạo các hàm/module tính indicator và signal độc lập.
- Bắt đầu với một chiến lược minh họa đơn giản, ví dụ EMA crossover với bộ lọc tùy chọn; không ngụ ý chiến lược sinh lời.
- Chỉ dùng nến đã đóng trong quy tắc baseline, trừ khi chiến lược định nghĩa rõ khác.
- Định nghĩa warm-up period và xử lý thiếu dữ liệu.
- Log reason code cho từng quyết định.
- Viết test cho biên, dữ liệu thiếu, nến đầu tiên và trạng thái chưa đủ indicator history.

### Deliverables
- `Indicators.mqh`, `SignalEngine.mqh`, tests hoặc fixture tương ứng.
- Tài liệu định nghĩa chiến lược và tín hiệu.
- Mẫu dữ liệu/expected output để đối chiếu.

### Acceptance criteria
- Cùng input và cấu hình cho cùng kết quả.
- Không có look-ahead do truy cập bar index sai.
- `HOLD` khác với lỗi/`UNKNOWN`.
- Logic không phụ thuộc vào việc gửi lệnh.

## Phase 3 — Python data pipeline và validation

**Mục tiêu:** nạp, chuẩn hóa và xác minh dữ liệu trước khi phân tích.

### Công việc
- Xây loader cho CSV/Parquet.
- Chuẩn hóa timestamp/timezone, symbol, timeframe và column names.
- Validate duplicate/out-of-order timestamps, OHLC consistency, null, NaN/Inf và khoảng trống dữ liệu.
- Tạo báo cáo chất lượng dữ liệu, không tự lặng lẽ sửa dữ liệu lỗi.
- Lưu dữ liệu raw bất biến; processed data phải có thông tin nguồn và quy trình transform.
- Nếu chưa có MT5 history export, tạo fixture tổng hợp nhỏ dành riêng cho unit tests và đánh dấu rõ là dữ liệu giả lập.

### Deliverables
- Python package `data/` và `validation/`.
- `scripts/validate_dataset.py`.
- `docs/reference/data-dictionary.md`.
- Bộ fixture và unit tests.

### Acceptance criteria
- Có test cho file rỗng, cột thiếu, timestamp trùng, dữ liệu sai thứ tự, OHLC mâu thuẫn và giá trị không hữu hạn.
- Kết quả validation được lưu ra JSON/CSV.
- Không coi dữ liệu tổng hợp là dữ liệu lịch sử thị trường.

## Phase 4 — Python backtester cho nghiên cứu

**Mục tiêu:** kiểm thử các tín hiệu một cách tái lập và có mô hình chi phí minh bạch.

### Công việc
- Xây engine mô phỏng position/trade lifecycle theo đặc tả.
- Tách signal generation, execution assumptions và metric calculation.
- Quy định rõ giá khớp mô phỏng, timing, xử lý gap, SL/TP nếu có, vị thế cuối kỳ và thứ tự xử lý khi SL/TP đều có thể bị chạm trong một bar.
- Mô hình hóa spread, slippage, commission và chi phí khác khi phù hợp; đánh dấu rõ giả định nếu dữ liệu chi phí không có.
- Không dùng dữ liệu tương lai cho quyết định tại thời điểm hiện tại.
- Xuất trades ledger, equity curve và summary metrics.
- Thêm benchmark baseline và seed cố định cho những phần có tính ngẫu nhiên.

### Deliverables
- `backtest/`, `evaluation/`.
- `scripts/run_backtest.py`.
- Báo cáo summary JSON/CSV và biểu đồ tùy chọn.
- `docs/reference/testing.md` giải thích giả định mô phỏng.

### Acceptance criteria
- Unit tests cho vào/ra, chi phí, vị thế cuối kỳ, bar gap và trường hợp không có giao dịch.
- Một test nhỏ có expected output tính tay.
- Có thể chạy lại cùng config và thu được kết quả tương đương.
- Mọi metric được định nghĩa; không báo Sharpe nếu tần suất/annualization chưa được xác định.

## Phase 5 — So sánh EA MQL5 với Python

**Mục tiêu:** phát hiện khác biệt giữa implementation MQL5 và Python.

### Công việc
- Chuẩn hóa định nghĩa EMA/RSI/ATR, warm-up, nến đóng/mở và rounding.
- Dùng một fixture dữ liệu chung cho hai implementation.
- Xuất tín hiệu từ MQL5 bằng log/file theo cách Strategy Tester cho phép; nếu chưa tự động hóa được thì viết quy trình export thủ công và ghi hạn chế.
- Xây `compare_signals.py` để so sánh timestamp, feature và signal.
- Định nghĩa tolerance số học; không dùng tolerance để che lỗi logic.

### Deliverables
- Script so sánh tín hiệu.
- Báo cáo mismatch.
- Tài liệu về sai khác indicator do cách tính hoặc nguồn dữ liệu.

### Acceptance criteria
- Mismatch được liệt kê rõ theo timestamp và field.
- Không tuyên bố tương đương khi chỉ so sánh một vài hàng.
- Nếu chưa có thể chạy terminal tự động, hạn chế đó phải được nói rõ.

## Phase 6 — Reporting và experiment tracking

**Mục tiêu:** quản lý lịch sử thí nghiệm một cách đáng tin cậy.

### Công việc
- Lưu `experiment_id`, timestamp, git commit, config hash, data fingerprint, code/model version và metric.
- Dùng SQLite cho metadata; CSV/JSON/Parquet cho artifact lớn.
- Tạo bảng kết quả có thể so sánh nhiều lần chạy.
- Không ghi mật khẩu/API key trong database/log.
- Phân biệt `failed`, `completed`, `invalid_data` và `cancelled`.

### Deliverables
- `experiment_store/`.
- Schema SQLite/migration đơn giản.
- Báo cáo so sánh baseline và run mới.

### Acceptance criteria
- Một run không thể bị ghi đè âm thầm bởi run khác.
- Mỗi kết quả liên kết được tới cấu hình và dữ liệu.
- Có test cho interrupted/failed run và duplicate experiment ID.

## Phase 7 — AI/ML baseline

**Mục tiêu:** huấn luyện mô hình dự đoán có kiểm soát và kiểm tra khả năng tổng quát hóa.

### Công việc
- Định nghĩa target/label trước khi tạo mô hình; ghi rõ horizon, cách tạo label và chi phí/threshold nếu có.
- Xây feature pipeline chỉ sử dụng dữ liệu khả dụng tại thời điểm dự đoán.
- Bắt đầu với baseline đơn giản như Logistic Regression hoặc một mô hình phù hợp với target.
- Chia dữ liệu theo thời gian thành train/validation/test; không shuffle ngẫu nhiên toàn bộ chuỗi thời gian nếu làm rò rỉ tương lai.
- Dùng walk-forward hoặc expanding-window validation khi phù hợp.
- Giữ test cuối cùng không dùng để chọn feature/threshold/model.
- Đánh giá cả metric dự đoán lẫn kết quả của chiến lược mô phỏng; không đánh đồng hai loại metric.
- Lưu feature schema, preprocessing, model artifact, model card và phiên bản dependency.

### Deliverables
- `features/`, `labels/`, `models/`.
- Script train/evaluate.
- Model card và báo cáo validation ngoài mẫu.

### Acceptance criteria
- Có benchmark không dùng ML.
- Không có data leakage đã biết.
- Metric được báo cáo cả khi model không tốt.
- Không tự động quảng bá mô hình dựa trên một metric duy nhất.

## Phase 8 — Nghiên cứu ONNX/MQL5 inference

**Mục tiêu:** xác minh có thể chuyển mô hình từ Python sang ONNX và chạy suy luận tương thích trong môi trường MQL5.

### Công việc
- Chọn mô hình/operations có khả năng export ONNX.
- Kiểm tra schema, thứ tự feature, kiểu dữ liệu, normalization và output mapping.
- Đối chiếu dự đoán trên một bộ fixture cố định giữa Python và ONNX.
- Tạo EA inference-only: chỉ đọc input và in ra prediction; tuyệt đối không gửi lệnh.
- Dùng `OnnxCreate`/`OnnxCreateFromBuffer`, cấu hình shape/type phù hợp nếu API và build MT5 hỗ trợ.
- Kiểm thử ONNX trong Strategy Tester; ghi lại phiên bản terminal và runtime.
- Nếu tương thích không đạt, giữ Python làm môi trường đánh giá và ghi rõ blocker; không tự tạo workaround không được xác minh.

### Deliverables
- Artifact ONNX và metadata nếu export thành công.
- EA hoặc harness suy luận không giao dịch.
- Báo cáo sai lệch Python–ONNX.

### Acceptance criteria
- Kết quả nằm trong tolerance định trước và giải thích được.
- Sai schema/feature/missing model làm chương trình dừng an toàn, không sinh tín hiệu giả.
- Không có execution code.

## Phase 9 — Giả lập tiến trình end-to-end và đánh giá cuối

**Mục tiêu:** kiểm chứng toàn bộ chu trình nghiên cứu từ dữ liệu tới báo cáo.

### Công việc
- Chạy pipeline bằng một cấu hình cố định.
- Nạp dữ liệu, validate, tạo feature/tín hiệu, backtest, lưu experiment và sinh report.
- Thử với dữ liệu lỗi và mô hình thiếu để xác minh fail-safe.
- Kiểm tra khả năng lặp lại sau khi checkout commit sạch.
- Viết báo cáo limitation: chất lượng dữ liệu, spread/slippage assumptions, sample size, overfitting risks và chưa có khẳng định live performance.

### Deliverables
- Một lệnh chạy pipeline theo tài liệu.
- Sample report được đánh dấu là demo/synthetic nếu dùng fixture.
- Checklist phát hành nội bộ.

### Acceptance criteria
- Test Python chạy xanh trong môi trường đã khai báo.
- Có thể tái tạo một run demo từ hướng dẫn.
- Không có mật khẩu/tài khoản môi giới.
- Không có lệnh giao dịch thật hoặc cơ chế tự kích hoạt execution.
- Các giới hạn và giả định hiển thị rõ trong báo cáo.

## 8. Metrics và định nghĩa báo cáo

Tối thiểu cân nhắc các trường sau, nhưng chỉ tính metric khi dữ liệu và định nghĩa thích hợp:

- Số lượng giao dịch mô phỏng.
- Gross P&L, modeled costs, net P&L.
- Profit factor, expectancy trên giao dịch.
- Maximum drawdown và cách đo equity.
- Win rate cùng phân phối lãi/lỗ; không sử dụng win rate đơn độc.
- Average/median win, loss và holding duration.
- Sharpe/Sortino chỉ khi có định nghĩa return series, tần suất lấy mẫu và annualization rõ ràng.
- Metric ML: confusion matrix, precision/recall, ROC-AUC hoặc metric phù hợp với loại bài toán và imbalance.
- Kết quả train/validation/test phân tách rõ ràng.

Mọi báo cáo phải ghi dữ liệu, khoảng thời gian, symbol/timeframe, model/strategy version, chi phí được đưa vào và trạng thái dữ liệu (thực, sample hay synthetic).

## 9. Cài đặt MT5 và thao tác thủ công

1. Cài MetaTrader 5 desktop từ nguồn chính thức phù hợp với môi trường cần kiểm thử.
2. Mở terminal và dùng `File → Open Data Folder` để tìm đúng thư mục dữ liệu terminal.
3. Mở `MQL5/Experts` trong Data Folder và copy/sync EA vào đó.
4. Mở MetaEditor từ terminal hoặc phím `F4`, mở file `.mq5` và biên dịch.
5. Trong MT5, mở Strategy Tester bằng `Ctrl+R`, chọn EA, symbol, timeframe, khoảng ngày và chế độ kiểm thử.
6. Chạy EA signal-only ở Visual mode khi cần quan sát log; kiểm tra tab Journal/Experts và báo cáo tester.
7. Nếu terminal chưa có dữ liệu lịch sử cần thiết, ghi rõ nguồn và phạm vi dữ liệu đang thiếu; không tự coi dữ liệu được tải là chính xác đầy đủ.

Các tên menu có thể khác theo ngôn ngữ hoặc build. Agent coding không được giả vờ đã điều khiển GUI hay kiểm thử terminal nếu không có quyền/công cụ thực tế.

## 10. Chiến lược kiểm thử phần mềm

### Python

- Unit tests: data validator, indicators/features, label generation, metrics, cost model, position lifecycle.
- Regression tests: fixture đầu vào và kết quả mong đợi.
- Property tests nếu phù hợp: timestamps luôn tăng sau validation; metric không trả NaN trong trường hợp xác định; chi phí không bị âm do lỗi sign.
- Integration tests: nạp fixture → validate → signal → backtest → report.
- Reproducibility tests: config và dữ liệu giống nhau cho kết quả nhất quán.

### MQL5

- Compile trong MetaEditor.
- Kiểm tra chỉ số bar, indicator handles, `CopyBuffer` return count và `BarsCalculated`.
- Xử lý `INVALID_HANDLE`, `EMPTY_VALUE`, dữ liệu chưa đủ và lỗi copy buffer.
- Kiểm thử trực quan và Journal trong Strategy Tester.
- Kiểm tra không gọi execution function.

## 11. Bảo mật, an toàn và quản trị thay đổi

- Không commit `.env`, mật khẩu, tài khoản MT5, token, khóa API hay dữ liệu cá nhân.
- Chỉ dùng dataset mà người phát triển có quyền sử dụng.
- Ghi lại nguồn, thời điểm tải và điều kiện cấp phép dữ liệu.
- Không tự tải/chạy executable/script từ nguồn không được duyệt.
- Không tự thay đổi quyền hệ thống, firewall, antivirus hoặc cấu hình bảo mật.
- Không kết nối tài khoản môi giới trong quá trình MVP.
- Không triển khai `OrderSend`, `CTrade.Buy`, `CTrade.Sell` hay execution path tương đương trong MVP.
- Mọi mở rộng sang execution phải là một quyết định/phạm vi mới được xem xét độc lập; không nằm trong prompt triển khai roadmap này.

## 12. Definition of Done cho mỗi phase

Một phase chỉ được đánh dấu `DONE` khi:

1. Mục tiêu và deliverables của phase hoàn tất.
2. Code có test phù hợp hoặc lý do có tài liệu nếu không thể test tự động.
3. Các lệnh test đã chạy được ghi rõ, kèm kết quả thực tế.
4. Không che giấu lỗi hoặc blocker.
5. README/docs được cập nhật.
6. Chưa phá các phase đã hoàn thành.
7. Không thêm execution code hoặc bí mật.
8. Tạo bản tóm tắt thay đổi, files changed, tests, limitation và phase tiếp theo.

Nếu không có MT5/MetaEditor cài trong môi trường agent, phase MQL5 phải được ghi là `READY_FOR_MANUAL_VALIDATION`, không phải `DONE`.

## 13. Lệnh dự kiến cho Python

Tùy cấu trúc package thực tế, ưu tiên cung cấp các lệnh nhất quán như:

```powershell
# Tạo môi trường ảo
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1

# Cài dependencies
python -m pip install --upgrade pip
pip install -r requirements.txt

# Chạy unit tests
python -m pytest python/tests -q

# Kiểm tra một dataset
python scripts/validate_dataset.py --input datasets/samples/example.csv

# Chạy một backtest demo (sau khi script và CLI được triển khai)
python scripts/run_backtest.py --config configs/experiment.example.yaml
```

Các lệnh trên là giao diện mục tiêu. Agent phải đồng bộ với CLI được triển khai thực tế, không để README chỉ dẫn tới file hoặc tham số không tồn tại.

## 14. Thứ tự ưu tiên triển khai

1. Phase 0: repo skeleton + docs + môi trường.
2. Phase 1: EA signal-only.
3. Phase 2: signal engine.
4. Phase 3: data pipeline/validation.
5. Phase 4: Python backtester.
6. Phase 5: parity comparison MQL5/Python.
7. Phase 6: experiment tracking.
8. Phase 7: ML baseline.
9. Phase 8: ONNX inference.
10. Phase 9: end-to-end reproducibility.

**Không triển khai tất cả trong một lượt.** Mỗi phase phải kết thúc bằng báo cáo và tiêu chí nghiệm thu trước khi bắt đầu phase kế tiếp.

## 15. Tài liệu tham khảo chính thức

- MQL5 Documentation: https://www.mql5.com/en/docs
- MQL5 ONNX: https://www.mql5.com/en/docs/onnx
- MQL5 Python integration: https://www.mql5.com/en/docs/python_metatrader5
- MQL5 `WebRequest`: https://www.mql5.com/en/docs/network/webrequest
- MetaTrader 5 Strategy Testing: https://www.metatrader5.com/en/terminal/help/algotrading/testing
- MetaTrader 5 Strategy Optimization: https://www.metatrader5.com/en/terminal/help/algotrading/strategy_optimization
- Python: https://docs.python.org/3/
- pandas: https://pandas.pydata.org/docs/
- scikit-learn: https://scikit-learn.org/stable/
- pytest: https://docs.pytest.org/
- ONNX: https://onnx.ai/

Các trang tài liệu có thể thay đổi theo phiên bản. Trước khi dùng API cụ thể, cần kiểm tra lại tài liệu và build thực tế.
