# InfiniteRunner evidence pack

Small, committed evidence for the study [`../../infinite-runner-study.md`](../../infinite-runner-study.md). The raw
tester artefacts (journals up to ~190 MB, HTML reports) live locally under
`reports/build/tester-reports/` and are gitignored; only the equity PNG and a
compact metric JSON per scenario are committed.

Regenerate with:

```powershell
.venv\Scripts\python.exe scripts\tester\gen_ir_sets.py
scripts\tester\run_tester.ps1 -Scenario <scenario> -TimeoutSec 10800
.venv\Scripts\python.exe scripts\tester\build_ir_evidence.py
```

Every number is `NOT_STRATEGY_RESULT` (operational/measurement); evidence
`NOT_RUN`, profit `UNPROVEN`.

| scenario | description | trades | winrate | net | exp R | PF | maxDD | TP hits |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `infinite_runner_demo_exec` | shipped preset, 2026.01.05-10.01 (the run that deadlocked after 2 days, 101 trades) | 101 | 80.20% | 1.70 | 0.0034 | 1.017 | 0.49% | 0 |
| `infinite_runner_fixcheck` | U1 fix on the SAME window: trades all 9 months instead of deadlocking | 8364 | 72.15% | 763.55 | 0.0183 | 1.066 | 5.90% | 39 |
| `infinite_runner_long_baseline` | 2018-2026 shipped inputs; halts permanently at 8% drawdown on 2020.06.23 | 2406 | 71.07% | -793.01 | -0.0659 | 0.768 | 7.94% | 3 |
| `infinite_runner_long_base_nolock` | 2018-2026 reference: shipped step trailing, daily/DD halts off | 26130 | 72.97% | -685.40 | -0.0052 | 0.980 | 22.48% | 75 |
| `infinite_runner_long_exit_run` | U2: step trailing off so the fixed runner trail works (let winners run) | 34238 | 59.76% | -2077.69 | -0.0121 | 0.970 | 32.21% | 0 |
| `infinite_runner_long_fixedrr` | U3: no trail, SL 1R / TP 1R -> raw entry edge (break-even winrate 50%) | 26143 | 48.07% | -5796.01 | -0.0443 | 0.915 | 58.29% | 0 |
| `infinite_runner_long_fixedrr15` | U3 cross-check: SL 1R / TP 1.5R (break-even winrate 40%) | 18407 | 38.65% | -3839.00 | -0.0417 | 0.932 | 38.77% | 0 |
| `infinite_runner_long_fixedrr_clean` | U3 definitive: 1:1 with every guard off (no censoring) | 33668 | 48.08% | -7158.96 | -0.0425 | 0.918 | 71.94% | 0 |
| `infinite_runner_long_mtf` | 2018-2026 with InpDirectionMode=1 (IR_DIR_EMA_MTF): 31 trades / 8.75 years | 31 | 74.19% | -21.18 | -0.1366 | 0.489 | 0.23% | 0 |

## Experiment E1 — gross decomposition (side x year x tail)

Gross per trade = net P&L + spread cost (`--spread-price` 0.19). A broad
edge survives on both sides and across years AND does not vanish when the
best 0.5% of trades are removed. Anything else is luck / drift.

| scenario | overall gross R | BUY gross R | SELL gross R | gross R without best 0.5% |
|---|---:|---:|---:|---:|
| `infinite_runner_long_base_nolock` | +0.0328 | +0.0399 | +0.0258 | -0.0411 |
| `infinite_runner_long_exit_run` | +0.0259 | +0.0269 | +0.0249 | +0.0048 |
