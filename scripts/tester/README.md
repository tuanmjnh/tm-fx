# `scripts/tester/` — bộ chạy Strategy Tester (được track)

Đây là nhóm script **duy nhất trong repo mở MT5 terminal** (`terminal64.exe /config:`). Nó chạy
trên **tài khoản ảo của Strategy Tester**, không đăng nhập, không gửi lệnh thật. EA vẫn demo/tester-only
(ADR 0004/0006). Hướng dẫn đầy đủ: [`docs/20-operations/strategy-tester.md`](../../docs/20-operations/strategy-tester.md).

| File | Vai trò |
|---|---|
| `run_tester.ps1` | Chạy 1 scenario headless, lưu report + mọi CSV `sim_<scenario>*.csv` vào `reports/build/tester-reports/<scenario>/`. Fail-closed nếu report 0 bar (run bị abort) — không archive CSV cũ. |
| `gen_ir_sets.py` | Sinh `.set` + `.ini` cho `InfiniteRunnerXAUV2DemoEA` từ JSON preset (không sửa tay `.set`). |
| `analyse_ir.py` | Đọc journal InfiniteRunner, in phân rã lệnh/expectancy/lý do dừng. |
| `ir_breakdown.py` | Streaming breakdown lãi/lỗ theo hướng × năm × phân vị lệnh trên journal lớn. |
| `build_ir_evidence.py` | Tổng hợp JSON/PNG bằng chứng cho `docs/30-research/evidence/infinite-runner/`. |

## Chạy nhanh

```powershell
# 1) Sinh input cho bot (từ configs/demo/infinite_runner_demo.json)
.venv\Scripts\python.exe scripts\tester\gen_ir_sets.py

# 2) Chạy một scenario (đóng terminal MT5 trước nếu đang mở)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tester\run_tester.ps1 -Scenario <scenario>

# 3) Phân tích journal đã sinh
.venv\Scripts\python.exe scripts\tester\analyse_ir.py reports\build\tester-reports\<scenario>
```

Yêu cầu: EA đã compile vào terminal (`powershell -File scripts\deploy_pineport.ps1 -Apply -Force`) và
`terminal64.exe` ở đường dẫn mặc định (hoặc truyền `-Exe`).

## Dữ liệu ở đâu

- **Dữ liệu giá**: do terminal broker tải về (symbol `XAUUSDm`), không nằm trong repo.
- **Report + CSV**: `reports/build/tester-reports/<scenario>/` (gitignored — chỉ có trên máy chạy).
- **Nguồn sự thật cấu hình**: `configs/demo/*.json` + `.set` track trong `docs/20-operations/presets/`.
