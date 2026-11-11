# Strategy Tester — InfiniteRunner

Repo còn **một EA**: `InfiniteRunnerXAUV2DemoEA` (`XAUUSDm`, M5). Scenario tester được **sinh** từ JSON nguồn sự thật
(`configs/demo/infinite_runner_demo.json`) — không sửa `.set` bằng tay.

## 1. Sinh scenario + chạy

```powershell
.venv\Scripts\python.exe scripts\tester\gen_ir_sets.py
scripts\tester\run_tester.ps1 -Scenario <tên> -TimeoutSec 10800
```

`run_tester.ps1` stage `.set` vào `MQL5\Profiles\Tester\`, chạy terminal headless, rồi lưu artefacts vào
`reports/build/tester-reports/<scenario>/` (`sim_*.csv`, `tester_*.htm`, `tester_*.png`). Run dài cần
`-TimeoutSec 7200+`.

## 2. Scenario có sẵn (15, sinh bởi `gen_ir_sets.py`)

| Nhóm | Scenario |
|---|---|
| Hạ tầng | `infinite_runner_demo_exec`, `infinite_runner_legacy_exec` |
| U1 fixcheck | `infinite_runner_fixcheck` |
| Baseline dài | `infinite_runner_long_baseline`, `infinite_runner_long_base_nolock` |
| Đo exit/edge | `long_exit_run`, `long_fixedrr`, `long_fixedrr15`, `long_fixedrr_clean` |
| Hướng khác | `long_mtf`, `long_regime` (H-D) |
| Tần suất/chi phí | `long_nolimit`, `long_spread200` (H-C) |
| Trend khung lớn (H-B) | `long_htf_h1`, `long_htf_h4` |

Mọi run là `NOT_STRATEGY_RESULT`; kết luận nằm ở [`../30-research/infinite-runner-long-run-study.md`](../30-research/infinite-runner-long-run-study.md).

## 3. Phân tích

```powershell
.venv\Scripts\python.exe scripts\tester\analyse_ir.py   reports\build\tester-reports\<scenario>\sim_*.csv
.venv\Scripts\python.exe scripts\tester\ir_breakdown.py reports\build\tester-reports\<scenario>\sim_*.csv
.venv\Scripts\python.exe scripts\tester\build_ir_evidence.py   # cập nhật evidence pack nhỏ đã commit
```
