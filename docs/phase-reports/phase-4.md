# Phase 4 — Python backtester cho nghiên cứu

- **Trạng thái:** `DONE` (Python backtester và CLI đã chạy thật, 2026-10-27).
- **Phạm vi:** mô phỏng bar-by-bar, cost model tường minh, trades ledger, equity curve và metric.
- **Không bao gồm:** Strategy Tester MT5, execution thật, ML, experiment store.

## 1. Deliverables

| Deliverable | Vị trí |
|---|---|
| Signal thuần Python | `python/src/mt5_ea_ai_lab/signals/ema_crossover.py` |
| Backtest models | `python/src/mt5_ea_ai_lab/backtest/models.py` |
| Backtest engine | `python/src/mt5_ea_ai_lab/backtest/engine.py` |
| Metric và benchmark | `python/src/mt5_ea_ai_lab/evaluation/metrics.py` |
| CLI | `scripts/run_backtest.py` |
| Config mẫu | `configs/backtest.example.yaml` |
| Dataset demo synthetic | `datasets/samples/synthetic_ema_cross_demo.csv` |
| Unit test | `python/tests/test_signals.py`, `python/tests/test_backtest.py` |
| Hướng dẫn giả định mô phỏng | `docs/reference/testing.md` |
| Báo cáo Phase 4 | `docs/phase-reports/phase-4.md` |

## 2. Quyết định thiết kế

- **Tách signal khỏi execution:** `generate_signals` chỉ tạo tín hiệu; engine mới mô phỏng vị thế.
- **Không look-ahead:** tín hiệu tại bar `i` dùng close đến `i`; fill tại open bar `i+1`.
- **Một vị thế:** tín hiệu ngược chiều đóng rồi đảo vị thế tại open bar kế tiếp; không pyramiding.
- **Chi phí tường minh:** spread, slippage, commission theo `ExecutionConfig`; không có chi phí ẩn.
- **SL/TP trong bar:** dùng high/low; nếu cả hai cùng chạm, SL thắng (bảo thủ).
- **Gap:** fill tại open nếu open đã vượt SL/TP, không dùng giá SL/TP lý tưởng.
- **Đóng cuối kỳ:** vị thế mở được đóng tại close bar cuối với `exit_reason=end_of_data`.
- **Metric trung thực:** `sharpe_ratio=null` và ghi lý do; không báo annualized metric khi chưa định nghĩa.
- **Tái lập:** không random; `seed` được ghi nhưng chưa dùng; test so sánh artifact giữa hai lần chạy.
- **Fail closed:** validation lỗi → exit code `2`, không backtest; input sai trong engine → `BacktestInputError`.

## 3. Lệnh và kết quả thực tế

| Lệnh | Kết quả thực tế |
|---|---|
| `.venv\Scripts\python.exe -m pip install --no-cache-dir PyYAML==6.0.3` | Thành công; `PyYAML 6.0.3`; đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe -m pytest -q` | **62 passed in 1.67s** |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code `0`; `bars=8 trades=1 final_equity=10294.60 net_profit=294.60` |
| CLI với dataset có timestamp trùng | Exit code `2`; `invalid_data`, 1 error `duplicate_timestamps`; có `validation.json` |
| CLI với config thiếu `strategy` | Exit code `1`; `config_error: config.strategy is required` |
| CLI với `outputs.plot: true` | Exit code `0`; tạo `equity.png` (39,008 bytes) |

Artifact của lần chạy mẫu nằm trong `reports/backtests/demo-ema-cross-synthetic/` (bị gitignore):
`summary.json`, `trades.csv`, `equity.csv`, `signals.csv`, `validation.json`, `validation.csv`.

### Kết quả hand-calculated của demo

Dataset synthetic 8 bar, strategy fast=2/slow=3, units=10,000, spread=2 point, slippage=1 point,
commission=2.5 mỗi chiều:

- Tín hiệu BUY tại bar index 5 (close 1.09), fill tại open bar 6 = 1.09002.
- Đóng cuối kỳ tại close bar 7 = 1.11998.
- Gross PnL = `(1.11998 - 1.09002) * 10,000 = 299.60`.
- Commission = `2.5 * 2 = 5.00`; PnL = `294.60`; final equity = `10,294.60`.
- Benchmark buy-and-hold cùng chi phí: `194.60`; không so sánh như bằng chứng hiệu năng.

## 4. Tiêu chí nghiệm thu

| Tiêu chí | Kết quả | Bằng chứng |
|---|---|---|
| Unit test cho vào/ra, chi phí, vị thế cuối kỳ, bar gap, không giao dịch | Đạt | `test_buy_executes_at_next_open_and_closes_at_end_of_data`, `test_costs_are_applied_to_both_fills_and_commission_per_side`, `test_gap_through_stop_fills_at_the_worse_open`, `test_no_trade_dataset_keeps_equity_flat` |
| Test nhỏ có expected output tính tay | Đạt | Demo 300.00 no-cost / 294.60 có phí; stop-loss -10.00; reversal -200/+500 |
| Chạy lại cùng config thu được kết quả tương đương | Đạt | `test_repeated_runs_are_identical`; trades/equity/signals/metrics/benchmark bằng nhau |
| Mọi metric được định nghĩa; không báo Sharpe khi chưa xác định annualization | Đạt | Bảng metric trong `docs/reference/testing.md`; `sharpe_ratio=null`, `undefined_metrics` |
| Tách signal, execution assumptions và metric | Đạt | `signals/`, `backtest/`, `evaluation/` độc lập |
| Xuất trades ledger, equity curve, summary | Đạt | `trades.csv`, `equity.csv`, `signals.csv`, `summary.json` |
| Benchmark baseline | Đạt | `buy_and_hold_benchmark` dùng cùng cost model |
| Seed cố định cho phần ngẫu nhiên | Đạt (không có random) | `seed` được ghi trong summary; không có RNG trong engine |
| `docs/reference/testing.md` giải thích giả định | Đạt | Đã tạo |

## 5. File đã tạo/sửa

Tạo mới:

- `python/src/mt5_ea_ai_lab/signals/ema_crossover.py`
- `python/src/mt5_ea_ai_lab/backtest/models.py`
- `python/src/mt5_ea_ai_lab/backtest/engine.py`
- `python/src/mt5_ea_ai_lab/evaluation/metrics.py`
- `python/tests/test_signals.py`
- `python/tests/test_backtest.py`
- `scripts/run_backtest.py`
- `configs/backtest.example.yaml`
- `datasets/samples/synthetic_ema_cross_demo.csv`
- `docs/reference/testing.md`
- `docs/phase-reports/phase-4.md`

Cập nhật:

- `python/src/mt5_ea_ai_lab/signals/__init__.py`
- `python/src/mt5_ea_ai_lab/backtest/__init__.py`
- `python/src/mt5_ea_ai_lab/evaluation/__init__.py`
- `datasets/samples/README.md`
- `requirements.txt` (thêm `PyYAML==6.0.3`)
- `.gitignore` (bỏ qua temp dir của pip/pytest khi `TEMP` trỏ vào repo)
- `docs/reference/strategy-signal-spec.md` (ghi chú cửa sổ EMA của EA so với fixture)
- `README.md`, `docs/reference/architecture.md`, `docs/guides/install-and-test.md`, `docs/reference/risk.md`

## 6. Vấn đề còn tồn tại

1. **Dữ liệu demo là synthetic**, chỉ 8 bar. Không có kết luận hiệu năng hay độ bền của chiến lược.
2. **EMA window chưa thống nhất với fixture Phase 2.** EA/Python dùng cửa sổ cuộn `slow_period + 1`;
   fixture trong `strategy-signal-spec.md` gọi hàm với toàn bộ chuỗi. Phase 5 phải chọn một quy ước,
   cập nhật fixture/self-check script và so sánh cùng cửa sổ.
3. **Không có thứ tự intrabar thật.** Quy ước SL-first có thể làm kết quả bảo thủ hơn hoặc khác thực tế.
4. **Không mô phỏng** swap/financing, leverage/margin, contract size, tick rounding, lot constraints,
   requote, latency, partial fill, thanh khoản.
5. **Chưa chạy Strategy Tester MT5.** Không có so sánh MQL5/Python trong phase này.
6. **Metric annualized chưa có.** Sharpe/Sortino để `null`; không có walk-forward/out-of-sample.
7. **Report bị gitignore.** Kết quả chỉ tồn tại cục bộ; experiment store là Phase 6.
8. `generated_at_utc` và đường dẫn tuyệt đối khác nhau giữa các lần chạy; so sánh tái lập phải dùng
   trades/equity/signals/metric.

## 7. Kiểm tra thủ công gợi ý

1. Chạy CLI với `configs/backtest.example.yaml`.
2. Mở `summary.json`, xác nhận `status=completed`, `data_kind=synthetic`, `metrics.sharpe_ratio=null`.
3. Mở `trades.csv`, kiểm tra entry bar 6, exit bar 7, `entry_fill=1.09002`, `exit_fill=1.11998`,
   `pnl=294.6`.
4. Mở `signals.csv`, xác nhận BUY tại `2024-01-01T00:25:00+00:00` (bar index 5).
5. Bật `outputs.plot: true`, chạy lại và mở `equity.png`.
6. Không kết nối tài khoản môi giới, không chạy execution.

## 8. Bước tiếp theo

Phase 5 — so sánh tín hiệu MQL5 và Python trên cùng fixture, thống nhất cửa sổ EMA/warm-up, định nghĩa
tolerance số học và xuất báo cáo mismatch. Không tuyên bố tương đương nếu chưa chạy cả hai phía.
