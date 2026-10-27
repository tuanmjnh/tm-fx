# Kiến trúc — MT5 EA & AI Lab

- **Phiên bản:** 1.0 (Phase 0)
- **Ngày:** 2026-10-27
- **Trạng thái:** skeleton; chưa có module nghiệp vụ nào được triển khai.

## 1. Bối cảnh

Repository là môi trường nghiên cứu độc lập cho EA MQL5 và pipeline Python. Nó không import, không
gọi và không phụ thuộc `tm-trading`, `tm-hub` hay bất kỳ dự án nào khác.

MVP chỉ tạo tín hiệu và mô phỏng. Không có đường thực thi lệnh, không có kết nối tài khoản môi giới.

## 2. Luồng dữ liệu mục tiêu

```text
MT5 history export / CSV / synthetic fixture
        │
        ▼
Data ingestion + validation (Python)          ← schema, timezone, OHLC, NaN/Inf
        │
        ▼
Shared data contract: timestamp, symbol, timeframe, OHLC, volume/spread
        │
        ├────────────────────────────┐
        ▼                            ▼
MQL5 indicators + signal engine   Python features + model
        │                            │
        └──────────────┬─────────────┘
                       ▼
           Simulation / comparison (Python backtester, MT5 Strategy Tester)
                       │
                       ▼
        Trades ledger, metrics, experiment metadata, reports
```

## 3. Ranh giới module

| Thư mục | Trách nhiệm | Phase |
|---|---|---|
| `python/src/mt5_ea_ai_lab/data/` | Nạp CSV/Parquet, chuẩn hóa timestamp/symbol/timeframe | 3 |
| `python/src/mt5_ea_ai_lab/validation/` | Schema, OHLC consistency, duplicate/out-of-order, NaN/Inf, gap report | 3 |
| `python/src/mt5_ea_ai_lab/features/` | Feature chỉ dùng dữ liệu có sẵn tại thời điểm `t` | 3, 7 |
| `python/src/mt5_ea_ai_lab/labels/` | Định nghĩa target/horizon, không dùng tương lai ngoài horizon | 7 |
| `python/src/mt5_ea_ai_lab/signals/` | Sinh tín hiệu từ feature/rule; không thực thi lệnh | 2, 7 |
| `python/src/mt5_ea_ai_lab/backtest/` | Mô phỏng position lifecycle, cost model | 4 |
| `python/src/mt5_ea_ai_lab/models/` | Train/evaluate model, model card, artifact metadata | 7–8 |
| `python/src/mt5_ea_ai_lab/evaluation/` | Metric định nghĩa rõ ràng, tách prediction metric khỏi strategy metric | 4, 7 |
| `python/src/mt5_ea_ai_lab/reporting/` | Report JSON/CSV/HTML từ artifact đã lưu | 4, 6 |
| `python/src/mt5_ea_ai_lab/experiment_store/` | SQLite metadata: run, config hash, data fingerprint, status | 6 |
| `mt5/Experts/` | EA signal-only | 1 |
| `mt5/Include/` | `Indicators.mqh`, `SignalEngine.mqh`, `Logger.mqh` | 2 |
| `scripts/` | CLI mỏng gọi package | 3–5 |

Không đặt logic tính toán trong script CLI. Script chỉ parse tham số, gọi module và ghi output.

## 4. Nguyên tắc ràng buộc

1. **Signal tách khỏi execution.** Không có execution trong MVP.
2. **Dữ liệu tách khỏi model.** Model chỉ nhận input đã qua validation.
3. **Fail closed.** Thiếu dữ liệu/schema sai/model lỗi phải dừng với thông báo rõ; không tự suy diễn tín hiệu.
4. **Không look-ahead.** Feature/label tại `t` chỉ dùng dữ liệu có sẵn đến `t` (trừ horizon đã khai báo của label).
5. **Tái lập.** Mỗi run lưu git commit, config hash, data fingerprint, seed, phiên bản thư viện.
6. **Offline.** Backtest không phụ thuộc API live.
7. **`HOLD` ≠ `UNKNOWN`.** `HOLD` là quyết định; `UNKNOWN` là không đủ dữ liệu/độ tin cậy.

## 5. Data contract tối thiểu

Giá: `timestamp`, `symbol`, `timeframe`, `open`, `high`, `low`, `close`, `tick_volume` (nullable),
`spread` (nullable, ghi rõ đơn vị), `source`.

Tín hiệu: `event_time`, `symbol`, `timeframe`, `strategy_id`, `strategy_version`, `signal`,
`reason_codes`, `input_bar_time`, `feature_snapshot`/reference, `model_id`/`model_version` (nếu có),
`created_at`.

Chi tiết đầy đủ nằm trong roadmap, mục 6. `docs/data-dictionary.md` sẽ được tạo ở Phase 3.

## 6. Lưu trữ

| Loại | Định dạng | Vị trí |
|---|---|---|
| Raw data (bất biến) | CSV/Parquet | `datasets/raw/` (gitignored) |
| Processed data | Parquet/CSV | `datasets/processed/` (gitignored) |
| Fixture nhỏ, synthetic | CSV | `datasets/samples/` |
| Model artifact | file + metadata | `models/candidates/` (gitignored) + `models/registry.json` |
| Experiment metadata | SQLite | `experiments/` (gitignored) |
| Report | JSON/CSV/HTML | `reports/` (gitignored) |

## 7. Môi trường và phiên bản

- Python 3.11.x (baseline 3.11.9, 64-bit), pin dependency trong `requirements.txt`.
- MT5 build 5.0.0.6249 (EXNESS) dùng cho kiểm thử compile/tester ở phase sau.
- Không giả định tính năng ONNX có sẵn; xác minh ở Phase 8.

Chi tiết: [`environment.md`](environment.md), quyết định: [`decisions/0001-project-baseline.md`](decisions/0001-project-baseline.md).

## 8. Trạng thái triển khai

Phase 0 chỉ tạo skeleton, tài liệu, cấu hình mẫu và smoke test import. Chưa có logic dữ liệu, tín hiệu,
backtest, ML hay MQL5. Xem [`phase-reports/phase-0.md`](phase-reports/phase-0.md).
