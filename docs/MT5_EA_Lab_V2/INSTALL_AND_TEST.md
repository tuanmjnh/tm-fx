# Cài đặt và kiểm thử

**Đối tượng:** người mới clone repository, hoặc người cần chạy lại toàn bộ từ đầu.  
**Nguyên tắc:** mọi bước đều có output kiểm chứng; không bước nào được mô tả là "đã chạy" nếu chưa thấy output thật.

## 1. Yêu cầu

- Windows 10/11 x64.
- MetaTrader 5 Exness đã cài; mở terminal một lần để tạo Data Folder.
- Python 3.11+ (repo dùng 3.11.9).
- PowerShell 5.1+.
- Quyền đọc/ghi `D:\Applications\tm-fx` và Data Folder.

Đường dẫn tham chiếu: [`ENVIRONMENT.md`](ENVIRONMENT.md).

## 2. Chuẩn bị Python

```powershell
cd D:\Applications\tm-fx
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pip check
```

Kỳ vọng: `No broken requirements found.`

## 3. Kiểm tra môi trường và layout

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-environment.ps1 -ProjectRoot .
```

Kỳ vọng: `SUMMARY: checks=... fail=0`, `ENVIRONMENT_OK`.

Nếu MetaEditor không nằm ở đường dẫn mặc định, thêm `-MetaEditorPath "C:\...\MetaEditor64.exe"`.

## 4. Compile MQL5

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1
```

- Script xóa `.ex5` cũ, compile từng file, lưu log riêng.
- MetaEditor CLI thường trả exit 1 dù thành công; **đọc log**: `Result: 0 errors, 0 warnings`.
- Kỳ vọng: `BUILD_OK`, mọi `.mq5` có `.ex5`.

Chỉ compile một nhóm:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\*"
```

## 5. Chạy Python tests và gate tĩnh

```powershell
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
```

- `pytest`: xem số passed thực tế; không dùng số cũ.
- `validate-project.py`: chặn API giao dịch ngoài allowlist, placeholder, layout, preset.
- `validate_demo_execution.py`: kiểm tra ADR 0003, DemoEA guardrail, probe, watcher, preset demo/sim.

Kỳ vọng: cả ba exit 0 và in `SUMMARY: checks=... fail=0` (pytest in số test).

## 6. Deploy MQL5 vào Data Folder (thủ công)

Repo **không** có script tự động copy. Thực hiện thủ công:

1. Xác định Data Folder: trong MT5, `File → Open Data Folder`, hoặc đọc `TerminalInfoString(TERMINAL_DATA_PATH)`.
2. Copy các thư mục cần thiết:
   - `mt5\Include\Sim\` → `<Data Folder>\MQL5\Include\Sim\`
   - `mt5\Include\TrendRider\` → `<Data Folder>\MQL5\Include\TrendRider\`
   - `mt5\Include\Exec\` → `<Data Folder>\MQL5\Include\Exec\`
   - `mt5\Include\PinePort\`, `mt5\Include\Common\` (nếu dùng indicator/EA liên quan)
   - `mt5\Experts\PATrendRiderXAUv1SimEA.mq5`, `PATrendRiderXAUv1DemoEA.mq5`, `GridLabEA.mq5`, `DCALabEA.mq5` → `<Data Folder>\MQL5\Experts\`
   - `mt5\Scripts\*.mq5` → `<Data Folder>\MQL5\Scripts\`
3. Compile lại trong Data Folder bằng MetaEditor hoặc CLI; kiểm tra `Result: 0 errors, 0 warnings`.

**Kiểm tra trước khi copy:** đúng Data Folder của terminal Exness đang dùng; không copy vào thư mục tester agent sandbox (bị xóa mỗi lần chạy).

## 7. Chạy Strategy Tester

### 7.1 GUI

1. Mở MT5 → `View → Strategy Tester`.
2. Chọn Expert, Symbol `XAUUSDm`, Period `M5` (PATrendRider) hoặc `M15` (Grid/DCA).
3. Load `.set` từ `reports\build\tester-sets\` hoặc `MQL5\Presets\`.
4. Chọn khoảng thời gian, deposit, leverage, model.
5. Start; lưu report `.htm` + CSV vào `reports\build\tester-reports\<scenario>\`.

### 7.2 Headless

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\<scenario>.ini"
```

- Không đưa credential vào `.ini`.
- `.set` phải nằm trong `MQL5\Profiles\Tester\` cho headless.
- Kiểm tra file CSV SUMMARY sau khi chạy; không suy luận từ việc terminal đóng.

Quy trình chi tiết và ma trận scenario: [`../guides/strategy-tester.md`](../guides/strategy-tester.md).

## 8. Chạy DemoEA trên tài khoản demo

Điều kiện bắt buộc:

- Terminal đang đăng nhập **tài khoản DEMO**.
- Algo Trading bật; tài khoản cho phép giao dịch.
- Symbol `XAUUSDm` có trong allowlist (`InpAllowedSymbols=XAUUSD`).
- `InpEnableExecution=true` chỉ khi thực sự muốn gửi lệnh.

Các bước:

1. Mở chart `XAUUSDm` M5.
2. Kéo `PATrendRiderXAUv1DemoEA` vào chart.
3. Kiểm tra dòng `INIT` trong `MQL5\Logs\YYYYMMDD.log`:
   - `mode=DEMO_EXECUTION`
   - `mql_trade_allowed=1`
   - `symbol=XAUUSDm`
   - `magic=25002001`
4. Theo dõi journal `MQL5\Files\pa_trendrider_demo.csv`.
5. Giám sát bằng script chỉ-đọc:

```powershell
.\.venv\Scripts\python.exe scripts\watch_demo_journal.py --from-start
.\.venv\Scripts\python.exe scripts\watch_demo_journal.py --watch --interval 60 --timeout 3600
```

- Exit `1` = có sự kiện (ENTRY/EXIT/TRAIL/FAULT), không phải "có lãi".
- Exit `2` = không tìm thấy journal hoặc sai schema.

Dừng khẩn cấp: tạo file `<Data Folder>\MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt`. EA sẽ đóng vị thế và khóa entry tới khi restart. Xem [`EXECUTION_AND_SAFETY.md`](EXECUTION_AND_SAFETY.md).

Quy trình đầy đủ: [`../guides/demo-execution.md`](../guides/demo-execution.md).

## 9. Chạy Grid/DCA

Chỉ chạy trong **Strategy Tester** hoặc trên chart với `SIMULATION_ONLY`. Hai EA này không có API gửi lệnh; kết quả là vị thế ảo + CSV.

```powershell
# Ví dụ headless
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\grid_baseline.ini"
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\dca_baseline.ini"
```

Không attach Grid/DCA vào tài khoản thật để "thử". Không kỳ vọng lệnh thật.

## 10. Checklist sau khi chạy

| Việc | Bằng chứng |
|---|---|
| Compile | Log `Result: 0 errors, 0 warnings`, `.ex5` tồn tại |
| Python tests | Output pytest với số passed/failed |
| Static gates | `SUMMARY: checks=N fail=0` |
| Tester | `.htm`, CSV SUMMARY, `.set`/`.ini` |
| DemoEA | Dòng `INIT` + journal CSV + tab History |
| Kill switch | Dòng `KILL` + `STATE ERROR_SAFE_MODE` |
| Không live | Không có lệnh nào trên tài khoản real; không credential trong repo |

## 11. Khi có lỗi

Xem [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md). Không "sửa" bằng cách tắt guard, đổi sang tài khoản thật, hoặc bỏ SL/TP.
