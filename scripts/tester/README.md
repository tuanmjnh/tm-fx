# `scripts/tester/` — bộ chạy Strategy Tester (được track)

Đây là nhóm script **duy nhất trong repo mở MT5 terminal** (`terminal64.exe /config:`). Nó chạy
trên **tài khoản ảo của Strategy Tester**, không đăng nhập, không gửi lệnh thật. EA vẫn demo/tester-only
(ADR 0004/0006). Hướng dẫn đầy đủ: [`docs/20-operations/strategy-tester.md`](../../docs/20-operations/strategy-tester.md).

| File | Vai trò |
|---|---|
| `run_tester.ps1` | Chạy 1 scenario headless, lưu report + mọi CSV `sim_<scenario>*.csv` (journal, census, telemetry) vào `reports/build/tester-reports/<scenario>/`. |
| `gen_ww2_sets.py` | Sinh `.set` + `.ini` cho `WonderwhalesXAU2ModeEA` từ JSON preset (không sửa tay `.set`). |
| `analyse_census.py` | Đọc `<journal>_census.csv` và in funnel bias → setup → signal, lý do dừng, cross-check. |

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
```

Scenario: `ww2_scalp_parity_on`, `ww2_scalp_demo_exec`, `ww2_swing_demo_exec`, `ww2_scalp_census`.
Census bật bằng `InpDebug=true` và ghi `<tên journal>_census.csv`; chi tiết ở
[`docs/10-bots/wonderwhales-2mode.md`](../../docs/10-bots/wonderwhales-2mode.md) §5.1.

Yêu cầu: EA đã compile vào terminal (`powershell -File scripts\deploy_pineport.ps1 -Apply -Force`) và
`terminal64.exe` ở đường dẫn mặc định (hoặc truyền `-Exe`).

## Dữ liệu ở đâu

- **Dữ liệu giá**: do terminal broker tải về (symbol `XAUUSDm`), không nằm trong repo.
- **Report + CSV**: `reports/build/tester-reports/<scenario>/` (gitignored — chỉ có trên máy chạy).
- **Nguồn sự thật cấu hình**: `configs/demo/*.json` + `.set` track trong `docs/20-operations/presets/`.
