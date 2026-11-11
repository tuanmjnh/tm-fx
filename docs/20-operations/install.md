# Cài đặt — InfiniteRunner

Repo chỉ còn **một bot demo**: `InfiniteRunnerXAUV2DemoEA` (`XAUUSDm`, M5). Tài liệu này gồm cài Python, cài MT5,
deploy source và kiểm guard.

## 1. Python

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Python 3.11 (baseline). Kiểm nhanh: `.venv\Scripts\python.exe -m pytest -q`.

## 2. MetaTrader 5

Cài MT5 (Exness hoặc MT5 gốc). Mở **File > Open Data Folder** để lấy `<Data Folder>` (chứa `MQL5\`). Kiểm môi trường:

```powershell
powershell -NoProfile -File scripts\check-environment.ps1
```

MetaEditor: `…\MetaEditor64.exe` (trong thư mục cài MT5). Sau khi cài lại MT5, đường dẫn cũ có thể đổi — dùng
`check-environment.ps1` để dò.

## 3. Deploy source (copy + compile)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply -Force -TerminalDataDir "<Data Folder>"
```

Copy `Include\Exec`, `Include\Sim`, `Include\InfiniteRunner`, `Experts\InfiniteRunnerXAUV2DemoEA.mq5`, và các script
test (`IRCoreTests`, `ExecGuardTests`, `ExecDemoProbe`, `SimCoreTests`, `SimPlanTests`, `CloseDemoPosition`); sau đó
compile. Kỳ vọng: `DEPLOY_OK … 0 errors and 0 warnings`.

Nếu MT5 đang mở: nhấn phải vào node trong Navigator → **Refresh** để nạp `.ex5` vừa compile.

## 4. Kiểm guard trên chart demo

Kéo `Scripts > IRCoreTests` vào chart → tab **Experts** phải in `TEST|RESULT|ALL_PASS|pass=N fail=0|ir=1`.
(`ExecGuardTests` kiểm ma trận guard của lớp `Exec`.)

## 5. Chạy

- Strategy Tester: [`strategy-tester.md`](strategy-tester.md).
- Chạy demo thật: gắn EA lên chart `XAUUSDm` M5 với preset [`presets/infinite_runner_v2_demo_run.set`](presets/infinite_runner_v2_demo_run.set)
  và [`../10-bots/infinite-runner.md`](../10-bots/infinite-runner.md) §4 (tối thiểu tài khoản, kill switch).
