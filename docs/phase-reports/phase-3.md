# Báo cáo Phase 3 — Python data pipeline và validation

- **Ngày:** 2026-10-27
- **Trạng thái:** DONE
- **Phạm vi:** loader CSV/Parquet, chuẩn hóa schema, validation OHLCV, report JSON/CSV, fixture synthetic.

## 1. Tóm tắt

Phase 3 thêm pipeline đọc dữ liệu và validation không sửa dữ liệu:

- Loader đọc CSV/Parquet, chuẩn hóa tên cột (kể cả `<DATE>`/`<TIME>` của MT5), quy timestamp về UTC.
- Không sort, không drop duplicate, không fill gap, không sửa OHLC; mọi vấn đề được báo.
- Validation kiểm tra empty/missing columns/timestamp/duplicate/out-of-order/NaN/Inf/OHLC/volume/
  symbol/timeframe/gap, trả report tất định.
- CLI ghi JSON + CSV, exit code 0/1/2.
- Fixture synthetic 6 nến M5 được đánh dấu rõ; test không dùng dữ liệu thị trường.

## 2. File đã tạo/sửa

| File | Trạng thái | Ghi chú |
|---|---|---|
| `python/src/mt5_ea_ai_lab/data/loader.py` | Tạo mới | `load_ohlcv`, `DatasetMetadata`, alias cột |
| `python/src/mt5_ea_ai_lab/data/__init__.py` | Sửa | Export API |
| `python/src/mt5_ea_ai_lab/validation/ohlcv.py` | Tạo mới | `validate_ohlcv`, report JSON/CSV |
| `python/src/mt5_ea_ai_lab/validation/__init__.py` | Sửa | Export API |
| `scripts/validate_dataset.py` | Tạo mới | CLI, exit code 0/1/2 |
| `python/tests/test_data_loader.py` | Tạo mới | 12 test loader |
| `python/tests/test_validation.py` | Tạo mới | 15 test validation |
| `python/tests/fixtures/synthetic_eurusd_m5.csv` | Tạo mới | 6 nến synthetic hợp lệ |
| `python/tests/fixtures/README.md` | Tạo mới | Cảnh báo synthetic |
| `docs/reference/data-dictionary.md` | Tạo mới | Schema, check, report schema |
| `requirements.txt` | Sửa | Thêm `pyarrow==26.0.0` |
| `docs/guides/install-and-test.md` | Sửa | Kết quả cài pyarrow, 38 test, CLI |
| `README.md` | Sửa | Trạng thái Phase 3, lệnh khả dụng |
| `docs/phase-reports/phase-3.md` | Tạo mới | Báo cáo này |

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install pyarrow` | Cài `pyarrow 26.0.0` (venv, không system-wide) |
| `.venv\Scripts\python.exe -m pytest` | **38 passed in 1.48s** (11 smoke Phase 0 + 27 test Phase 3) |
| `validate_dataset.py ...synthetic_eurusd_m5.csv --data-kind synthetic` | Exit **0**; 6 rows, 0 errors, 1 warning; JSON + CSV được ghi |
| `validate_dataset.py` trên file có timestamp trùng | Exit **2**; 1 error `duplicate_timestamps`; JSON + CSV được ghi |
| Quét `datasets/` | Không có dữ liệu thị trường; chỉ fixture synthetic trong `python/tests/fixtures/` |

Một test ban đầu fail vì fixture giả lập trùng cột chưa đúng (`timestamp` + `time` không trùng sau
normalize). Đã sửa test dùng `timestamp` + `datetime`; lần chạy lại pass toàn bộ.

## 4. Hành vi validation

- `passed = không có error`; warning không làm fail.
- Empty file đọc thành DataFrame rỗng và bị báo `empty_dataset`.
- Missing columns dừng các check phụ thuộc, trả `missing_columns` kèm danh sách.
- Duplicate và out-of-order được đếm riêng; dữ liệu gốc giữ nguyên thứ tự và số dòng.
- Non-finite được đếm theo cột; OHLC check chỉ chạy trên các dòng có đủ 4 giá hữu hạn.
- Gap dùng mode của diff (hoặc `--expected-step-seconds`), chỉ warning vì weekend/session hợp lệ.
- `data_kind=synthetic` sinh warning `synthetic_dataset` trong mọi report.

## 5. Tiêu chí nghiệm thu Phase 3

| Tiêu chí | Kết quả | Ghi chú |
|---|---|---|
| Test cho file rỗng | Đạt | `test_empty_dataset_fails`, `test_empty_csv_returns_empty_frame` |
| Test cột thiếu | Đạt | `test_missing_columns_fail` |
| Test timestamp trùng | Đạt | `test_duplicate_timestamps_fail` |
| Test dữ liệu sai thứ tự | Đạt | `test_out_of_order_timestamps_fail` |
| Test OHLC mâu thuẫn | Đạt | high/low inconsistent |
| Test giá trị không hữu hạn | Đạt | NaN + Inf theo cột |
| Validation lưu JSON/CSV | Đạt | `to_json`/`to_csv`, test + CLI thực tế |
| Không coi synthetic là dữ liệu thị trường | Đạt | metadata `data_kind`, warning, fixture README |
| Dữ liệu raw bất biến | Đạt | Loader chỉ đọc; không ghi `datasets/` |

## 6. Hạn chế

- Chưa có dữ liệu lịch sử MT5 thật; chưa kiểm chứng timezone server của broker.
- `spread` giữ đơn vị nguồn, chưa quy đổi point/price.
- Gap chỉ là warning; không phát hiện bar thiếu trong phiên nếu khoảng thiếu nhỏ hơn ngưỡng.
- Chưa hỗ trợ tick data, Parquet partition, hay schema versioning cho processed data.
- Parquet phụ thuộc `pyarrow`; test tự skip nếu môi trường thiếu package.

## 7. Phase tiếp theo

Phase 4 — Python backtester: mô hình cost, trade lifecycle, ledger/equity, metrics, CLI
`scripts/run_backtest.py`, test với expected output tính tay, `docs/reference/testing.md`.
