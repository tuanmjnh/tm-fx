# Môi trường đã xác minh

**Ngày xác minh:** 2026-10-29  
**Máy:** Windows 10.0.19045 x64  
**Repository:** `D:\Applications\tm-fx` (nhánh `main`)

Tài liệu này ghi môi trường thực tế đã dùng để compile, chạy Strategy Tester và chạy demo. Không có credential, login, investor password, OTP hoặc token trong bất kỳ mục nào.

## 1. Phần mềm

| Thành phần | Phiên bản / đường dẫn | Ghi chú |
|---|---|---|
| MT5 terminal | **5.0.0.6292** | Xác minh bằng `VersionInfo.FileVersion` của `terminal64.exe` |
| Terminal executable | `C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe` | Bản Exness |
| MetaEditor | `C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe` | Cùng bản cài với terminal |
| MT5 Data Folder | `C:\Users\tuanmjnh\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06` | Hash thư mục thay đổi nếu cài lại terminal |
| Python | 3.11.9 | `D:\Applications\tm-fx\.venv\Scripts\python.exe` |
| pytest | 9.1.1 | Cài trong venv |
| PowerShell | 5.1.19041.6456 | Dùng cho script `.ps1` |

**Lưu ý build:** các con số cũ trong `docs/PROGRESS.md` §2 ghi build 6249 là snapshot trước khi cài lại. Build hiện tại là **6292**; mọi kết quả runtime mới đều lấy từ build này.

## 2. Thư mục dữ liệu MT5

```text
<Data Folder>/
├── MQL5/
│   ├── Experts/        # EA đã deploy (thủ công)
│   ├── Include/        # header dùng chung
│   ├── Scripts/        # ExecDemoProbe, contract tests
│   ├── Files/          # journal, state, kill switch
│   ├── Logs/           # log EA (UTF-16LE)
│   ├── Profiles/Tester # .set cho headless tester
│   └── Presets/        # .set cho GUI tester
├── Tester/
│   ├── logs/           # log Strategy Tester
│   └── <hash>/Agent-127.0.0.1-3000/  # sandbox agent
├── logs/               # journal terminal (UTF-16LE)
├── config/common.ini   # trạng thái Algo Trading
└── MQL5/Files/PA_TREND_RIDER_DEMO_STOP.txt  # kill switch (khi tồn tại)
```

**Quy tắc:** repo **không** tự động ghi vào Data Folder. Mọi lần deploy là thao tác thủ công có kiểm tra đường dẫn (ADR 0001). Không có script tự copy và không có script tự mở terminal.

## 3. Định dạng log

| Log | Đường dẫn | Encoding | Dùng để |
|---|---|---|---|
| Journal terminal | `<Data Folder>\logs\YYYYMMDD.log` | UTF-16LE | Trạng thái khởi động, login, tester |
| Log EA | `<Data Folder>\MQL5\Logs\YYYYMMDD.log` | UTF-16LE | `INIT`, `RISK`, `ENTRY`, `EXIT`, `KILL` |
| Journal CSV của DemoEA | `MQL5\Files\pa_trendrider_demo.csv` | UTF-8/ASCII, 18 cột | Audit và watcher |
| State DemoEA | `MQL5\Files\pa_trendrider_demo_state.csv` | text | Khôi phục ledger/state |
| Tester log | `<Data Folder>\Tester\logs\` | UTF-16LE | Kết quả từng scenario |
| Tester agent sandbox | `<Data Folder>\Tester\<hash>\Agent-127.0.0.1-3000\` | — | Bị xóa mỗi lần chạy; không copy tay vào đây |

Đọc log UTF-16LE bằng Python (`encoding="utf-16"`) hoặc PowerShell; `grep` mặc định có thể không khớp.

## 4. MetaEditor CLI

- Exit code **1** thường xuất hiện ngay cả khi compile thành công.
- Bằng chứng đúng là dòng `Result: 0 errors, 0 warnings` trong log compile và sự tồn tại của `.ex5`.
- Script `scripts/build-mql5.ps1` coi log là nguồn sự thật: thiếu log, thiếu `Result:`, có error/warning hoặc không sinh `.ex5` đều fail.

## 5. Strategy Tester headless

- Chạy bằng `terminal64.exe /config:<startup.ini>`.
- `.ini` không chứa credential; không tự động đăng nhập.
- `.set` cho headless phải nằm trong `MQL5\Profiles\Tester\`; GUI "Load" đọc `MQL5\Presets\`.
- Tester agent sandbox **rỗng** mỗi lần chạy. EA cần file ngoài (ví dụ model ONNX) phải khai báo `#property tester_file`; không copy tay vào sandbox.
- Kết quả lưu ở `reports/build/tester-reports/<scenario>/` (gitignored).

## 6. Quyền và an toàn

- **Không** lưu login/password/investor/OTP/server/token trong repo, config, log, report hoặc Git.
- **Không** tự động hóa hộp thoại Login. Nếu terminal hiện hộp thoại đăng nhập, người dùng tự đăng nhập hoặc Cancel.
- Algo Trading của terminal nằm ở `config\common.ini` → `[Experts] Enabled=`, nhưng **không dùng file này để bật/tắt bất kỳ thứ gì ngoài demo testing**. Việc bật/tắt luôn do người dùng thực hiện.
- Không chạy executable/script tải từ nguồn không được duyệt; không đổi firewall/antivirus/PATH.

## 7. Biến động môi trường cần kiểm tra lại

| Điểm | Cách kiểm |
|---|---|
| Build terminal thay đổi | `(Get-Item terminal64.exe).VersionInfo.FileVersion` và đọc lại log tester |
| Data Folder đổi sau cài lại | `TerminalInfoString(TERMINAL_DATA_PATH)` hoặc đường dẫn trong terminal |
| Python dependency trôi | `pip check`, so với `requirements.txt` |
| Algo Trading tắt | Dòng `INIT` phải có `mql_trade_allowed=1`; nếu `0`, dừng và sửa cấu hình |
| Ký tự log sai | Đọc bằng UTF-16; kiểm tra 18 cột của journal CSV |

## 8. Bằng chứng môi trường

| Nội dung | Đường dẫn |
|---|---|
| Compile toàn bộ | `reports/build/tester-run/compile_repo.log`, `compile_data.log` |
| Compile DemoEA | `reports/build/tester-run/demo_ea_compile.log` |
| Probe compile | `reports/build/tester-run/probe_compile.log` |
| Tester tổng | `reports/build/tester-run/tester_full_20261029.log` |
| Probe runtime | `reports/build/demo-exec-probe-20261029/` (gitignored) |
| Demo journal | `MQL5\Files\pa_trendrider_demo.csv` (Data Folder) |
