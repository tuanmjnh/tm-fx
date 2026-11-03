# End-to-end pipeline — demo-phase9 (sample report)

> Bản sao đã lược đường dẫn tuyệt đối từ báo cáo sinh bởi `reports/pipeline/demo-phase9/pipeline_report.md`.
> Dữ liệu là **synthetic**; không phải kết quả thị trường và không phải khuyến nghị giao dịch.

- **Status:** `completed`
- **Generated (UTC):** 2026-10-27T16:31:14+00:00
- **Data:** `datasets/samples/synthetic_ml_demo.csv` (synthetic, EURUSD M5)
- **Data SHA-256:** `17fc3cc63c23fc94caf64ca44e29b7aa64779f8927b10a23b97ac5f86b47deaf`
- **Demo:** yes — synthetic/fixture data is not market performance.

## Stages

| Stage | Experiment ID | Status | Exit | Report |
|---|---|---|---|---|
| backtest | `demo-phase9-backtest` | `completed` | 0 | `reports/pipeline/demo-phase9-backtest` |
| ml | `demo-phase9-ml` | `completed` | 0 | `reports/pipeline/demo-phase9-ml` |

## Backtest — EMA crossover

| Metric | Value |
|---|---|
| Bars | 1800 |
| Trades | 49 |
| Final equity | 10241.8000 |
| Net profit | 241.8000 |
| Total return | 0.0242 |
| Max drawdown | 259.0000 |
| Profit factor | 1.4207 |
| Exposure | 0.9594 |

## ML baseline — logistic regression

| Metric | Value |
|---|---|
| Test samples | 299 |
| Threshold | 0.5000 |
| Test ROC-AUC | 0.5708 |
| Test balanced accuracy | 0.5584 |
| Test accuracy | 0.5686 |
| ML trades | 84 |
| ML net profit | -151.6000 |
| Buy & hold net profit | 295.3000 |

## Limitations

- Synthetic/fixture data is not market history; no performance claim is made.
- Python simulation only; MT5 Strategy Tester and ONNX runtime were not run.
- One symbol, one timeframe, one position; no portfolio or multi-asset testing.
- Costs are fixed spread/slippage/commission assumptions, not live execution.
- ML metrics are a single holdout; overfitting and regime shift remain possible.
- No broker connection, credentials, live orders or automatic execution.

ML warnings:

- `data_kind_synthetic: not market data`
- `ml_strategy_not_profitable_after_costs`
- `worktree_dirty`

## Reproduce

```powershell
.\.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml --run-id demo-phase9
```

Re-running with the same config and dataset must produce the same model hash and metrics; a new
`--run-id` is required because experiment IDs are immutable.

> Lệnh trên chỉ chạy lại được sau khi xóa artifact demo cũ, hoặc dùng ID mới
> (`--run-id demo-phase9-replay`). Chạy lại với `demo-phase9` sẽ trả exit `4` và không ghi đè báo cáo.
