# Toolchain dùng chung (W7)

Năm script root kiểm tra môi trường, build MQL5, chạy pytest, validate tĩnh và đóng gói source.
Không script nào mở terminal MT5, kết nối broker, đọc file tài khoản hay gửi lệnh.

| Script | Việc chính | Exit code |
|---|---|---|
| `scripts/check-environment.ps1` | Layout, Python ≥ 3.11, pytest, MetaEditor, quyền ghi `reports\` | 0 OK, 1 thiếu điều kiện, 2 root sai |
| `scripts/build-mql5.ps1` | Compile **mọi** `.mq5` dưới `mt5\`, mỗi file một log, xóa `.ex5` cũ trước khi build | 0 OK, 1 có source fail, 2 thiếu MetaEditor/không có source |
| `scripts/run-python-tests.ps1` | Chạy pytest bằng venv, giữ nguyên exit code | exit code của pytest; 2 thiếu Python/pytest |
| `scripts/validate-project.py` | Quét API giao dịch/broker trong toàn bộ `mt5\`, placeholder, layout, preset | 0 OK, 1 fail, 2 thiếu `mt5\` |
| `scripts/package-source.ps1` | Zip source + manifest SHA256, loại `.venv`/log/report/artifact | 0 OK, 1 có secret hoặc lỗi, 2 thiếu root |

## Cách chạy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-environment.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\*"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-python-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-python-tests.ps1 -PytestArgs "-k","sim"

.venv\Scripts\python.exe scripts\validate-project.py

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package-source.ps1 -Version 0.8.3
```

`-MetaEditorPath` dùng khi MetaEditor không nằm ở `C:\Program Files\MetaTrader 5 EXNESS\`.

## Quy tắc fail-closed

- `check-environment.ps1` chỉ đọc đường dẫn và phiên bản; không `Get-Content`, không đọc biến môi trường
  chứa secret.
- `build-mql5.ps1` coi **log** là bằng chứng: thiếu log, thiếu dòng `Result:`, lỗi, warning, hoặc không
  sinh `.ex5` đều fail — kể cả khi CLI trả exit 0. MetaEditor thường trả exit 1 dù biên dịch thành công.
- `validate-project.py` chặn `OrderSend*`, `CTrade`, `MqlTradeRequest/Result`, `Position*`, `Order*`,
  `WebRequest`, `Socket*`, `AccountInfo*`, `TerminalInfoString(TERMINAL_PASSWORD)` và include
  `Trade\*`/`Expert\*` trên mọi `.mq5`/`.mqh`. Placeholder (`TODO`, `FIXME`, ...) cũng fail.
- `package-source.ps1` quét secret dạng gán chuỗi (`password|passwd|api_key|secret|token` + giá trị
  trong ngoặc) trước khi copy; dừng ngay nếu khớp. Zip không chứa `.ex5`, log, `.venv`, `reports`,
  dataset, model hay file credential.
- `validate-project.py` dùng lại `mt5_ea_ai_lab.sim_configs` nên preset/scenario sai vẫn bị chặn.

## Bằng chứng chạy thật (2026-10-28)

| Lệnh | Kết quả |
|---|---|
| `check-environment.ps1` | `SUMMARY: checks=22 fail=0`, `ENVIRONMENT_OK` |
| `build-mql5.ps1` | 25 source, 0 errors, 0 warnings, `BUILD_OK` |
| `run-python-tests.ps1` | `328 passed`, `TESTS_OK` |
| `validate-project.py` | `SUMMARY: checks=11 fail=0` (kể cả `WonderwhalesSimEA`) |
| `package-source.ps1 -Version 0.8.3` | 222 file — bản hiện tại: calibration `XAUUSDm` (stop 3000, spread 600/400) + kết quả 3 scenario tester; sha256 `f772277f…572645` |
| `package-source.ps1 -Version 0.8.2` | 222 file — gồm `WonderwhalesSimEA` nhưng **trước** calibration spread/stop |
| `package-source.ps1 -Version 0.8.1` | 220 file — trước `WonderwhalesSimEA`, giữ làm mốc lịch sử |
| `package-source.ps1 -Version 0.8.0` | 220 file sau hợp nhất docs (W10) — trước hai bản sửa `SimPlan`, giữ làm mốc lịch sử |

Byte size `.ex5` thay đổi theo bản MetaEditor và cách truyền đường dẫn biên dịch; các con số trong báo cáo
phase cũ là ảnh chụp lịch sử, không phải invariant. Điều kiện đúng là dòng `Result:` trong log.

## Chưa làm được ở môi trường này

- Chạy `SimCoreTests` (123/0) và `SimPlanTests` (39/0) trong MT5: đã PASS ngày 2026-10-28.
- Strategy Tester: 18/18 registry scenario đã chạy và có SUMMARY (`presets=6 scenarios=18`;
  3 `ww_*`, 3 runner, 3 grid, 4 dca, 3 `plan_*`, 2 `pa_trendrider_*`); `plan_baseline`
  và `plan_edge_tp3_stop_only` 0 trade là quirk `rr1 < rrMin` của source, không phải lỗi port;
  `plan_rr2` (bridge `rr1=2.0`) cho 93 trade ảo, CSV kiểm toán PASS — xem [`../PROGRESS.md`](../PROGRESS.md) §58;
  contract test 6 indicator **6/6 PASS**
  (547 check) ngày 2026-10-28, `PriceActionMTF` chạy lại `pass=125 fail=0` ngày 2026-10-29.
- Compile/test thành công không chứng minh hành vi runtime hay P&L; W8 vẫn là bước bắt buộc.
