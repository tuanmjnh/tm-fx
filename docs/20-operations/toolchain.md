# Toolchain dùng chung (W7)

Năm script root kiểm tra môi trường, build MQL5, chạy pytest, validate tĩnh và đóng gói source.
Không script nào **trong số này** mở terminal MT5, kết nối broker, đọc file tài khoản hay gửi lệnh.
Riêng bộ chạy Strategy Tester ở [`../../scripts/tester/`](../../scripts/tester/README.md) **có** mở
`terminal64.exe /config:` trên tài khoản ảo của tester — xem mục cuối trang này.

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

## Bằng chứng lịch sử (2026-10-28 — trước khi tinh gọn repo còn nhiều EA/indicator)

Các số dưới đây là **ảnh chụp lịch sử**, không phải invariant hiện tại: `check-environment.ps1 checks=22 fail=0`;
`build-mql5.ps1` 25 source 0/0; `run-python-tests.ps1 328 passed`; `validate-project.py checks=11 fail=0`;
`package-source.ps1` 220–222 file. Byte size `.ex5` đổi theo bản MetaEditor — điều kiện đúng là dòng `Result:`
trong log. Compile/test xanh **không** chứng minh hành vi runtime hay P&L.

## Bộ chạy Strategy Tester (`scripts/tester/`) — script duy nhất mở terminal

Khác năm script root, [`../../scripts/tester/run_tester.ps1`](../../scripts/tester/run_tester.ps1) **mở**
`terminal64.exe /config:` để chạy Strategy Tester. Nó chạy trên **tài khoản ảo của tester**, không đăng
nhập, không gửi lệnh thật; EA vẫn demo/tester-only (ADR 0004/0006). Input sinh bằng
[`../../scripts/tester/gen_ir_sets.py`](../../scripts/tester/gen_ir_sets.py) từ `configs/demo/*.json`.
Chi tiết + nơi lưu report: [`strategy-tester.md`](strategy-tester.md).
