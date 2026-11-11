# Chạy thử lần đầu — InfiniteRunner

Repo hiện chỉ còn **một bot demo**: `InfiniteRunnerXAUV2DemoEA` (magic `25006001`, `XAUUSDm`, M5). Hướng dẫn
này dựng MT5, deploy, và chạy thử trong **Strategy Tester**.

> **Ranh giới an toàn:** chỉ **demo** hoặc **Strategy Tester**; tài khoản real/live bị chặn ở `OnInit`
> (`ExecContextAllowed`). Mọi kết quả là `NOT_STRATEGY_RESULT`; lợi nhuận `UNPROVEN`.

## 1. Cài đặt

- Cài MetaTrader 5 (Exness/MT5). Mở **File > Open Data Folder**, ghi lại đường dẫn.
- Python: xem [`../20-operations/install.md`](../20-operations/install.md) (Python 3.11, `requirements.txt`).

## 2. Compile & deploy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply -Force -TerminalDataDir "<Data Folder>"
```

Kỳ vọng: `DEPLOY_OK: files copied and compiled with 0 errors and 0 warnings`. Script copy `Include\Exec`,
`Include\Sim`, `Include\InfiniteRunner`, EA `InfiniteRunnerXAUV2DemoEA.mq5` và các script test.

## 3. Kiểm guard (tuỳ chọn, trên chart demo)

Kéo `Scripts > IRCoreTests` vào một chart → tab **Experts** phải in
`TEST|RESULT|ALL_PASS|pass=N fail=0|ir=1`.

## 4. Chạy Strategy Tester

1. `Ctrl+R` → **Expert** = `InfiniteRunnerXAUV2DemoEA`, **Symbol** = `XAUUSDm`, **Period** = `M5`,
   **Model** = "1 minute OHLC".
2. **Inputs**: nạp [`../20-operations/presets/infinite_runner_v2.set`](../20-operations/presets/infinite_runner_v2.set)
   (hoặc `infinite_runner_v2_demo_run.set`).
3. **Deposit** ≥ 1.000; bấm **Start**. Journal CSV (`sim_ir_*.csv`) nằm trong Files của agent tester.

## 5. Đọc journal

Journal 18 cột (`event`: INIT / DECISION / ENTRY / SL_UPDATE / EXIT / BLOCKED / SUMMARY). Phân tích:

```powershell
.venv\Scripts\python.exe scripts\tester\analyse_ir.py reports\build\tester-reports\<scenario>\sim_*.csv
```
