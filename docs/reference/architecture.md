# Kiến trúc — MT5 EA & AI Lab

- **Phiên bản:** 1.9 (Phase 9 + trailing stop + bounded DCA/grid + execution boundary)
- **Ngày:** 2026-10-28
- **Trạng thái:** EA signal-only, signal engine MQL5, data pipeline/validation, Python backtester,
  bounded DCA/grid simulator, parity tooling MQL5/Python, experiment store/so sánh run, ML baseline,
  ONNX export/inference harness và pipeline end-to-end đã triển khai. ONNX runtime trong MT5 **chưa
  chạy**; Phase 8 ở trạng thái `READY_FOR_MANUAL_VALIDATION`. Phase 9 `DONE`; tái lập trên snapshot
  commit sạch đã xác minh 2026-10-28, còn bước lặp lại sau commit chính thức. Bốn file MQL5 compile
  0 errors/0 warnings trong Data Folder MT5 EXNESS ngày 2026-10-28. **Live execution không được hỗ trợ**
  trong repo này; xem [`decisions/0002-execution-boundary.md`](../decisions/0002-execution-boundary.md).

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
        │                            ├──► ONNX export ──► MQL5 inference harness
        │                            │
        └──────────────┬─────────────┘
                       ▼
  Simulation / comparison (Python backtester + bounded basket, MT5 Strategy Tester)
                       │
                       ▼
        Trades ledger, metrics, experiment metadata, reports
                       │
                       ▼
        End-to-end pipeline (validate → backtest → ML → store → report)
```

## 3. Ranh giới module

| Thư mục | Trách nhiệm | Phase |
|---|---|---|
| `python/src/mt5_ea_ai_lab/data/` | Nạp CSV/Parquet, chuẩn hóa timestamp/symbol/timeframe | 3 |
| `python/src/mt5_ea_ai_lab/validation/` | Schema, OHLC consistency, duplicate/out-of-order, NaN/Inf, gap report | 3 |
| `python/src/mt5_ea_ai_lab/features/` | Feature chỉ dùng dữ liệu có sẵn tại thời điểm `t` | 3, 7 |
| `python/src/mt5_ea_ai_lab/labels/` | Định nghĩa target/horizon, không dùng tương lai ngoài horizon | 7 |
| `python/src/mt5_ea_ai_lab/signals/` | Sinh tín hiệu từ feature/rule; không thực thi lệnh | 2, 7 |
| `python/src/mt5_ea_ai_lab/backtest/` | Mô phỏng position lifecycle, cost model, trailing stop và bounded DCA/grid basket | 4+ |
| `python/src/mt5_ea_ai_lab/models/` | Train/evaluate model, model card, artifact metadata, ONNX export | 7–8 |
| `python/src/mt5_ea_ai_lab/evaluation/` | Metric định nghĩa rõ ràng; so sánh signal MQL5/Python | 4–5, 7 |
| `python/src/mt5_ea_ai_lab/reporting/` | Report JSON/CSV/HTML từ artifact đã lưu | 4, 6 |
| `python/src/mt5_ea_ai_lab/experiment_store/` | SQLite metadata: run, fingerprint, trạng thái, artifact hash; so sánh run | 6 |
| `mt5/Experts/` | EA signal-only và ONNX inference harness (không giao dịch) | 1, 8 |
| `mt5/Include/` | `Indicators.mqh`, `SignalEngine.mqh`, `Logger.mqh` | 2 |
| `mt5/Scripts/` | Self-check signal engine; CSV export cho parity | 2, 5 |
| `scripts/` | CLI mỏng gọi package | 3–9 |

Không đặt logic tính toán trong script CLI. Script chỉ parse tham số, gọi module và ghi output.

## 4. Nguyên tắc ràng buộc

1. **Signal tách khỏi execution.** Không có execution trong repo này; `LabSignalEA` là signal-only và
   0 trade là kết quả đúng. Live execution bị loại theo
   [`decisions/0002-execution-boundary.md`](../decisions/0002-execution-boundary.md).
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

Chi tiết đầy đủ nằm trong roadmap, mục 6. `docs/reference/data-dictionary.md` sẽ được tạo ở Phase 3.

## 6. Lưu trữ

| Loại | Định dạng | Vị trí |
|---|---|---|
| Raw data (bất biến) | CSV/Parquet | `datasets/raw/` (gitignored) |
| Processed data | Parquet/CSV | `datasets/processed/` (gitignored) |
| Fixture nhỏ, synthetic | CSV | `datasets/samples/` |
| Model artifact | JSON + ONNX + metadata | `models/candidates/` (gitignored) + `models/registry.json` |
| Experiment metadata | SQLite | `experiments/` (gitignored) |
| Report | JSON/CSV/HTML/Markdown | `reports/` (gitignored) |

## 7. Môi trường và phiên bản

- Python 3.11.x (baseline 3.11.9, 64-bit), pin dependency trong `requirements.txt`.
- MT5 build 5.0.0.6249 (EXNESS) dùng cho kiểm thử compile/tester ở phase sau.
- Không giả định tính năng ONNX có sẵn; Phase 8 đã compile EA nhưng ONNX Runtime trong MT5 chưa chạy.

Chi tiết: [`environment.md`](../guides/install-and-test.md), quyết định: [`decisions/0001-project-baseline.md`](../decisions/0001-project-baseline.md).

## 8. Trạng thái triển khai

- Phase 0: skeleton, tài liệu, cấu hình mẫu và smoke test import. Xem
  [`phase-reports/phase-0.md`](../phase-reports/phase-0.md).
- Phase 1: EA signal-only `LabSignalEA.mq5` + logger. Compile 0 errors/0 warnings; Strategy Tester chưa
  chạy. Xem [`phase-reports/phase-1.md`](../phase-reports/phase-1.md).
- Phase 2: `Indicators.mqh`, `SignalEngine.mqh`, baseline EMA crossover chỉ dùng nến đóng và self-check
  script. Compile 0 errors/0 warnings; script chưa chạy. Xem
  [`strategy-signal-spec.md`](strategy-signal-spec.md) và [`phase-reports/phase-2.md`](../phase-reports/phase-2.md).
- Phase 3: loader CSV/Parquet, chuẩn hóa schema, validation OHLCV, report JSON/CSV, CLI
  `scripts/validate_dataset.py`; 38 Python test pass. Xem [`data-dictionary.md`](data-dictionary.md) và
  [`phase-reports/phase-3.md`](../phase-reports/phase-3.md).
- Phase 4: signal EMA crossover thuần Python, deterministic backtester, cost model tường minh, SL/TP tĩnh
  và trailing stop tùy chọn, trades ledger/equity/summary, benchmark buy-and-hold và CLI
  `scripts/run_backtest.py`; 62 Python test pass (con số lịch sử của Phase 4).
  Xem [`testing-guide.md`](testing.md), [`trailing-stop.md`](trailing-stop.md) và
  [`phase-reports/phase-4.md`](../phase-reports/phase-4.md).
- Phase 5: thống nhất cửa sổ EMA `slow+1`; fixture chung `parity_ema_cross.csv`;
  `LabSignalExport.mq5` (compile 0 errors/0 warnings, chưa chạy); `export_python_signals.py`;
  comparator `compare_signals.py` + `evaluation/parity.py`; 79 Python test pass. Parity thực tế chờ chạy
  export MQL5 thủ công. Xem [`parity.md`](parity.md) và
  [`phase-reports/phase-5.md`](../phase-reports/phase-5.md).
- Phase 6: SQLite experiment store với trạng thái `running/completed/failed/invalid_data/cancelled/
  interrupted`, config hash, data fingerprint, git commit/dirty, artifact hash; `run_backtest.py --store`;
  `compare_experiments.py` xuất JSON/CSV/Markdown; 119 Python test pass. Xem
  [`experiment-store.md`](experiment-store.md) và [`phase-reports/phase-6.md`](../phase-reports/phase-6.md).
- Phase 7: feature causal, label hướng giá có horizon/dead zone, chia thời gian 60/20/20 có purge,
  walk-forward expanding-window 3 fold, logistic regression artifact JSON, metric phân loại + mô phỏng
  chiến lược, benchmark majority/momentum/buy & hold, model card, CLI `scripts/train_ml_baseline.py`;
  143 Python test pass. Kết quả demo synthetic yếu và lỗ sau chi phí; không phải kết quả thị trường. Xem
  [`ml-baseline.md`](ml-baseline.md) và [`phase-reports/phase-7.md`](../phase-reports/phase-7.md).
- Phase 8: ONNX export tự dựng graph từ artifact JSON (opset 13, IR 8, float32, batch động),
  metadata/hash, kiểm tra parity Python–ONNX trên fixture 24 hàng (max abs diff 4.673e-08, tolerance
  1e-5) và EA `LabOnnxInference.mq5` chỉ suy luận, không giao dịch (compile 0 errors/0 warnings).
  ONNX runtime trong MT5 **chưa chạy** → `READY_FOR_MANUAL_VALIDATION`. Xem
  [`onnx-inference.md`](onnx.md) và [`phase-reports/phase-8.md`](../phase-reports/phase-8.md).
- Phase 9: pipeline end-to-end `scripts/run_pipeline.py` chạy validate → backtest EMA → ML baseline →
  experiment store → báo cáo tổng hợp trên cùng dataset; fail-safe dữ liệu/model/ID trùng; 155 Python
  test pass. Tái lập đã xác minh trên snapshot commit sạch (116 file, commit tạm `d3a9ea39…`): metric,
  data SHA-256, model SHA-256 và ONNX parity khớp; cần lặp lại sau commit chính thức. Xem
  [`end-to-end.md`](pipeline.md) và [`phase-reports/phase-9.md`](../phase-reports/phase-9.md).
- Trailing stop extension (sau Phase 9): trailing stop + activation tùy chọn trong backtester Python,
  cập nhật theo bar đã đóng và có hiệu lực bar kế tiếp; 170 Python test pass. Chưa có implementation
  MQL5/EA, không execution. Xem [`trailing-stop.md`](trailing-stop.md).
- Bounded DCA/grid extension (sau Phase 9): simulator riêng `run_bounded_basket` cho một basket nhiều
  layer với hard cap `max_layers`, `max_total_units`, `max_basket_loss` (lỗ ròng) và tối đa một add mỗi
  bar; CLI `scripts/run_basket_backtest.py`, hai config synthetic, 28 test riêng; toàn bộ suite 198
  Python test pass. Không execution, không store, chưa có MQL5/EA. Xem
  [`bounded-basket.md`](bounded-basket.md).
