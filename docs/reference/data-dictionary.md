# Data dictionary — OHLCV dataset

- **Phạm vi:** Phase 3 (OHLCV), Phase 7 (feature/label/prediction/model artifact), Phase 8 (ONNX
  artifact/metadata) và Phase 9 (pipeline summary). Mô tả schema chuẩn, quy tắc chuẩn hóa, validation và
  dữ liệu dẫn xuất cho ML.
- **Mã nguồn:** `python/src/mt5_ea_ai_lab/data/loader.py`,
  `python/src/mt5_ea_ai_lab/validation/ohlcv.py`, `python/src/mt5_ea_ai_lab/features/basic.py`,
  `python/src/mt5_ea_ai_lab/labels/direction.py`, `python/src/mt5_ea_ai_lab/models/logistic.py`,
  `python/src/mt5_ea_ai_lab/models/onnx_export.py`.
- **CLI:** `scripts/validate_dataset.py`, `scripts/train_ml_baseline.py`, `scripts/export_onnx_model.py`,
  `scripts/run_pipeline.py`.

## 1. Schema chuẩn

Sau khi load, DataFrame dùng các cột sau (theo thứ tự). Cột ngoài schema được giữ nguyên ở cuối và không
bị dùng bởi validation.

| Cột | Kiểu | Bắt buộc | Ý nghĩa | Ghi chú |
|---|---|---|---|---|
| `timestamp` | `datetime64[ns, UTC]` | Có | Thời điểm mở nến | Luôn quy về UTC |
| `open` | float | Có | Giá mở | Phải hữu hạn, `> 0` |
| `high` | float | Có | Giá cao nhất | `>= max(open, close, low)` |
| `low` | float | Có | Giá thấp nhất | `<= min(open, close, high)` |
| `close` | float | Có | Giá đóng | Phải hữu hạn, `> 0` |
| `tick_volume` | float | Có | Số tick trong nến | Không âm |
| `spread` | float | Không | Spread tại thời điểm bar | Đơn vị theo nguồn; không tự quy đổi |
| `real_volume` | float | Không | Volume thật nếu broker cung cấp | Không âm; thường `0` với FX |
| `symbol` | string | Không | Symbol của từng dòng | Nếu có, phải khớp metadata |
| `timeframe` | string | Không | Timeframe của từng dòng | Nếu có, phải khớp metadata |

Không có cột `datetime` hay `date` sau chuẩn hóa: chúng được gộp/đổi tên thành `timestamp`.

## 2. Chuẩn hóa tên cột

Tên cột được strip, bỏ `< >`, lowercase, thay space/gạch ngang bằng `_`, rồi map alias:

| Alias | Chuẩn |
|---|---|
| `time` | `time` (ghép với `date` nếu chưa có `timestamp`) |
| `datetime`, `date_time` | `timestamp` |
| `tickvol`, `tick_vol`, `vol`, `volume` | `tick_volume` |
| `realvol`, `real_vol` | `real_volume` |
| `ticker` | `symbol` |
| `period` | `timeframe` |

- Nếu có `<DATE>` và `<TIME>` (export MT5) → ghép thành `timestamp`.
- Nếu chỉ có `date` → dùng làm `timestamp` (00:00).
- Nếu chỉ có `time` → dùng làm `timestamp`.
- Hai cột normalize về cùng tên → `DataLoadError`, không tự chọn cột.

## 3. Quy tắc timestamp

- Timestamp có offset: convert sang UTC.
- Timestamp không có offset: localize theo `--tz` (mặc định `UTC`), rồi convert UTC.
- Không tự đổi ngày/giờ, không tự sắp xếp. Giá trị không parse được → `NaT`, validation báo
  `invalid_timestamps`.
- Định dạng kỳ vọng: ISO 8601 hoặc `YYYY.MM.DD HH:MM[:SS]` (export MT5). Loader dùng
  `pd.to_datetime` với `errors="coerce"`.

**Quan trọng:** nến trong MT5 thường theo giờ server (broker), không phải UTC. Người dùng phải biết
timezone của nguồn và truyền `--tz` phù hợp; loader không đoán.

## 4. Loader và tính bất biến của dữ liệu

- Hỗ trợ `.csv` (mặc định phân cách `,`) và `.parquet`/`.pq` (cần `pyarrow`).
- Không ghi/không sửa file nguồn.
- Không sort, không drop duplicate, không fill gap, không sửa OHLC.
- Cột số được `pd.to_numeric(errors="coerce")`; giá trị không phải số trở thành `NaN` và **được báo**
  qua `non_finite_values`, không bị coi là hợp lệ.
- `data_kind` bắt buộc là `unknown`, `synthetic` hoặc `market`. Fixture trong repo luôn dùng
  `synthetic`; report gắn cảnh báo `synthetic_dataset`.

### Dữ liệu raw và processed

- `datasets/raw/` là dữ liệu gốc, bất biến. Không commit dữ liệu lớn.
- `datasets/processed/` là dữ liệu dẫn xuất; mỗi file phải kèm nguồn (raw file), tham số transform,
  thời điểm tạo và phiên bản code. Phase 3 chưa tạo processed data.
- Không có bước nào trong Phase 3 ghi vào `datasets/`.

## 5. Validation

### Mức độ

- **error**: dataset không đạt; `passed=false`; CLI exit code `2`.
- **warning**: dataset vẫn đạt; cần người đọc quyết định.

### Danh sách check

| Code | Mức | Điều kiện | Không tự sửa |
|---|---|---|---|
| `empty_dataset` | error | Không có dòng | Không fill |
| `missing_columns` | error | Thiếu cột bắt buộc | Không tạo cột |
| `invalid_timestamps` | error | `NaT` sau parse | Không nội suy |
| `duplicate_timestamps` | error | Timestamp trùng | Không drop |
| `out_of_order_timestamps` | error | Diff âm | Không sort |
| `non_finite_values` | error | `NaN`/`±Inf` ở cột số | Không fill |
| `non_positive_prices` | error | OHLC `<= 0` | Không thay |
| `ohlc_high_inconsistent` | error | `high < max(open, close, low)` | Không sửa high |
| `ohlc_low_inconsistent` | error | `low > min(open, close, high)` | Không sửa low |
| `negative_tick_volume` | error | `tick_volume < 0` | Không clamp |
| `negative_real_volume` | error | `real_volume < 0` | Không clamp |
| `negative_spread` | error | `spread < 0` | Không clamp |
| `symbol_mismatch` | error | Cột `symbol` khác expected | Không đổi |
| `timeframe_mismatch` | error | Cột `timeframe` khác expected | Không đổi |
| `mixed_symbols` | warning | Nhiều symbol, không có expected | Không tách file |
| `mixed_timeframes` | warning | Nhiều timeframe, không có expected | Không tách file |
| `timestamp_gaps` | warning | Gap > `max_gap_factor × expected_step` | Không fill |
| `synthetic_dataset` | warning | `data_kind=synthetic` | Không coi là market |

Dung sai OHLC mặc định `1e-12` (tuyệt đối) để tránh lỗi làm tròn dấu phẩy động.

### Gap

- `expected_step` lấy từ `--expected-step-seconds` nếu có; nếu không, lấy **mode** của các diff dương
  giữa timestamp duy nhất đã sort.
- Gap lớn hơn `max_gap_factor` lần step (mặc định 3) là warning.
- Cuối tuần, nghỉ lễ và phiên giao dịch khác nhau tạo gap hợp lệ; đây là lý do gap chỉ là warning.

## 6. Report

### JSON

```json
{
  "schema_version": 1,
  "passed": true,
  "row_count": 6,
  "metadata": {
    "source_path": "...",
    "file_format": "csv",
    "data_kind": "synthetic",
    "timezone": "UTC",
    "rows": 6,
    "original_columns": ["..."],
    "normalized_columns": ["..."],
    "symbol": "EURUSD",
    "timeframe": "M5"
  },
  "stats": {
    "row_count": 6,
    "invalid_timestamps": 0,
    "duplicate_timestamps": 0,
    "out_of_order_timestamps": 0,
    "non_finite_values": {},
    "non_positive_price_rows": 0,
    "high_inconsistent_rows": 0,
    "low_inconsistent_rows": 0,
    "expected_step_seconds": 300.0,
    "gap_count": 0,
    "largest_gap_seconds": 300.0,
    "data_kind": "synthetic"
  },
  "issues": [
    {
      "code": "synthetic_dataset",
      "severity": "warning",
      "message": "Synthetic fixture; this is not market history.",
      "count": 6,
      "details": {}
    }
  ]
}
```

- JSON dùng `sort_keys=True`, indent 2, newline cuối file → tất định.
- CSV có cột `code,severity,message,count,details` (`details` là JSON string).

### CLI

```powershell
.\.venv\Scripts\python.exe scripts\validate_dataset.py <file> `
  [--symbol EURUSD] [--timeframe M5] [--tz UTC] `
  [--data-kind unknown|synthetic|market] `
  [--expected-step-seconds 300] [--max-gap-factor 3] `
  [--out-dir reports\validation]
```

Output mặc định: `reports/validation/<stem>.validation.json` và `.csv` (bị `.gitignore`).

## 7. Giới hạn

- `tick_volume` là số tick, không phải volume thật; `spread` giữ đơn vị nguồn (thường là point).
- Chưa hỗ trợ tick data, bar bị thiếu do symbol đổi tên, hay lịch nghỉ lễ theo broker.
- Chưa kiểm tra timestamp trùng do DST; người dùng phải chọn `--tz` đúng.
- Parquet phụ thuộc `pyarrow`; nếu thiếu, loader báo lỗi rõ thay vì fallback im lặng.
- Fixture synthetic chỉ để test code, không dùng để đánh giá chiến lược.

## 8. ML feature/label/prediction schema (Phase 7)

### Feature set

`FeatureSet.frame` giữ `bar_index`, `timestamp` và 12 feature. Feature tại bar `t` chỉ dùng bar `<= t`;
warm-up bị loại, không forward-fill. Schema được ghi vào `feature_schema.json`.

| Feature | Công thức ngắn |
|---|---|
| `return_1`, `return_3`, `return_5`, `return_10` | `close.pct_change(k)` |
| `ema_gap` | `(EMA_fast - EMA_slow) / close` |
| `ema_slope` | `(EMA_fast[t] - EMA_fast[t-1]) / close` |
| `volatility` | Rolling std của return 1 bar |
| `return_z` | `return_1 / volatility` |
| `stochastic` | Vị trí close trong rolling high/low |
| `range_ratio` | `(high - low) / close` |
| `body_ratio` | `(close - open) / close` |
| `volume_z` | Rolling z-score của `tick_volume` |

### Label

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `bar_index` | int | Index bar gốc |
| `timestamp` | datetime UTC | Thời điểm bar |
| `future_return` | float | `close[t+horizon] / close[t] - 1` |
| `label` | int | `1` nếu `future_return > min_return`; `0` nếu `< -min_return` |
| `label_end_bar_index` | int | `bar_index + horizon`; dùng để purge |

Dead zone `|future_return| <= min_return` và các bar cuối không đủ horizon bị loại. Label dùng giá tương
lai nên **không bao giờ** được dùng làm feature.

### Prediction artifact

`predictions.csv` (test) và `fold_predictions.csv` (OOF):

| Cột | Ý nghĩa |
|---|---|
| `timestamp`, `bar_index` | Định danh bar |
| `label`, `future_return` | Chỉ để audit; model không đọc |
| `probability` | Xác suất lớp `1` |
| `threshold`, `predicted` | Threshold đã chọn và nhãn dự đoán |
| `fold` | Chỉ có trong `fold_predictions.csv` |

### Model artifact

`model.json` gồm `schema_version`, `kind=logistic_regression`, `feature_schema_version`, `feature_names`,
`preprocessing` (mean/scale), `coefficients`, `intercept`, `hyperparameters`, `decision_threshold`, số
sample train/validation, `code_version` và `dependencies`. Không chứa object Python/pickle; `load_model`
từ chối JSON thiếu schema, sai số feature hoặc giá trị không hữu hạn.

## 9. ONNX artifact schema (Phase 8)

`model.onnx` là graph float32 dựng từ `model.json`, không pickle và không phụ thuộc `skl2onnx`.

| Thuộc tính graph | Giá trị |
|---|---|
| Opset / IR | `13` / `8` |
| Input | `features`, `float32`, `[batch, 12]`; inference shape `[1, 12]` |
| Output | `probability`, `float32`, `[batch, 1]` |
| Node | `Sub(mean) → Div(scale) → MatMul(coefficients) → Add(intercept) → Sigmoid` |
| Preprocessing | mean/scale nhúng trong graph; caller chỉ truyền feature thô |

`model_metadata.json`:

| Field | Ý nghĩa |
|---|---|
| `schema_version`, `opset`, `ir_version` | Phiên bản metadata/graph |
| `input.name`, `input.shape`, `input.dtype`, `input.feature_names` | Contract input; thứ tự feature bắt buộc |
| `output.name`, `output.shape`, `output.dtype` | Contract output |
| `decision_threshold` | Threshold lấy từ model JSON; EA harness không tự đổi |
| `model_sha256`, `onnx_sha256` | SHA-256 của `model.json` nguồn và `model.onnx` |
| `model_size_bytes`, `onnx_size_bytes` | Kích thước artifact |
| `dependencies` | Phiên bản Python/onnx dùng khi export |
| `notes` | Giới hạn (float32, parity offline, chưa chạy MT5 runtime) |

`onnx_parity.csv` (khi truyền `--fixture`): `bar_index`, `timestamp`, `expected_probability` (Python),
`onnx_probability`, `abs_diff`, `within_tolerance`; `onnx_parity.json` tổng hợp max/mean abs diff,
tolerance và kết luận. Fixture dùng cho EA chỉ có 12 feature + header, không chứa nhãn hay giá tương lai.

## 10. Pipeline summary schema (Phase 9)

`reports/pipeline/<run_id>/pipeline_summary.json`:

| Field | Ý nghĩa |
|---|---|
| `status` | `completed`, `invalid_data`, `failed`, `duplicate_experiment`, `store_error` |
| `run_id` | ID người dùng; stage dùng `<run_id>-backtest` và `<run_id>-ml` |
| `generated_at_utc` | Thời điểm tạo báo cáo (khác nhau giữa các lần chạy) |
| `demo` | `true` nếu `data_kind != market` |
| `data` | `path`, `sha256`, `data_kind`, `symbol`, `timeframe` |
| `stages.backtest` | `experiment_id`, `exit_code`, `status`, `summary_path`, `summary_sha256`, metric chọn lọc, benchmark |
| `stages.ml` | `experiment_id`, `exit_code`, `status`, `summary_path`, `summary_sha256`, metric chọn lọc, `model_sha256` |
| `stages.ml.status=skipped` | Khi stage backtest thất bại |
| `limitations` | Danh sách giới hạn cố định (synthetic, chưa MT5, một symbol, chi phí, single holdout, không execution) |
| `notes` | Ghi chú từ pipeline config |

`pipeline_report.md` là bản đọc được của cùng payload, có bảng stage/metric và nhãn demo. Báo cáo tổng
hợp **không** thay thế `summary.json`, trades, equity hay model card của từng stage; audit phải đọc
artifact gốc trong `<run_id>-backtest/` và `<run_id>-ml/`.
