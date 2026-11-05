# `scripts/tester/` — bộ chạy Strategy Tester (được track)

Đây là nhóm script **duy nhất trong repo mở MT5 terminal** (`terminal64.exe /config:`). Nó chạy
trên **tài khoản ảo của Strategy Tester**, không đăng nhập, không gửi lệnh thật. EA vẫn demo/tester-only
(ADR 0004/0006). Hướng dẫn đầy đủ: [`docs/20-operations/strategy-tester.md`](../../docs/20-operations/strategy-tester.md).

| File | Vai trò |
|---|---|
| `run_tester.ps1` | Chạy 1 scenario headless, lưu report + mọi CSV `sim_<scenario>*.csv` (journal, census, telemetry) vào `reports/build/tester-reports/<scenario>/`. Fail-closed nếu report 0 bar (run bị abort) — không archive CSV cũ. |
| `gen_ww2_sets.py` | Sinh `.set` + `.ini` cho `WonderwhalesXAU2ModeEA` từ JSON preset (không sửa tay `.set`). |
| `analyse_census.py` | Đọc `<journal>_census.csv` và in funnel bias → setup → signal, lý do dừng, cross-check. |
| `analyse_measure.py` | Đọc journal của ma trận đo `ww2_meas_scalp_*` và in trades/winrate/net/expectancy R+USD/PF/max DD/exit-kind/histogram R/trail mix; nhánh <30 lệnh → `INSUFFICIENT_SAMPLE`. |

## Chạy nhanh

```powershell
# 1) Sinh input cho bot 2-mode (từ configs/demo/wonderwhales_xau_2mode_demo.json)
.venv\Scripts\python.exe scripts\tester\gen_ww2_sets.py

# 2) Chạy một scenario (đóng terminal MT5 trước nếu đang mở)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario ww2_scalp_demo_exec

# 3) Chẩn đoán "vì sao ít lệnh": census (0 lệnh, chỉ ghi CSV) rồi phân tích
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario ww2_scalp_census
.venv\Scripts\python.exe scripts\tester\analyse_census.py `
    reports\build\tester-reports\ww2_scalp_census\sim_ww2_scalp_census_census.csv

# 4) Ma trận đo 8 lần (in/out-of-sample × nhánh A–D) rồi tổng hợp
foreach ($w in 'is','oos') { foreach ($a in 'a','b','c','d') {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario "ww2_meas_scalp_${w}_${a}" } }
.venv\Scripts\python.exe scripts\tester\analyse_measure.py reports\build\tester-reports
```

Scenario: `ww2_scalp_parity_on`, `ww2_scalp_demo_exec`, `ww2_swing_demo_exec`, `ww2_scalp_census`,
`ww2_meas_scalp_{is,oos}_{a,b,c,d}` (management), `ww2_meas_scalp_{is,oos}_gate_{w1,w5}` (cửa sổ
trigger), `ww2_meas_scalp_{is,oos}_setup_{s1,s5}` (cửa sổ setup) và
`ww2_meas_scalp_{is,oos}_combo_{c1,c5}` (tổ hợp), `ww2_meas_scalp_{is,oos}_geom_{tp10,tp125,tp15,tp20}`
(hình học TP) và `ww2_meas_scalp_{is,oos}_qual_{q0,q1}` (chất lượng tín hiệu).
Census bật bằng `InpDebug=true` và ghi `<tên journal>_census.csv`; chi tiết ở
[`docs/10-bots/wonderwhales-2mode.md`](../../docs/10-bots/wonderwhales-2mode.md) §5.1.
Mọi ma trận đo chạy parity OFF nên mọi output là **`NOT_STRATEGY_RESULT`** (§5.2 cùng file).

Yêu cầu: EA đã compile vào terminal (`powershell -File scripts\deploy_pineport.ps1 -Apply -Force`) và
`terminal64.exe` ở đường dẫn mặc định (hoặc truyền `-Exe`).

## Dữ liệu ở đâu

- **Dữ liệu giá**: do terminal broker tải về (symbol `XAUUSDm`), không nằm trong repo.
- **Report + CSV**: `reports/build/tester-reports/<scenario>/` (gitignored — chỉ có trên máy chạy).
- **Nguồn sự thật cấu hình**: `configs/demo/*.json` + `.set` track trong `docs/20-operations/presets/`.
