# Cài đặt và kiểm thử Wonderwhales PinePort

- **Đối tượng:** indicator `Wonderwhales`, EA `PineSignalLabEA`, contract tests.
- **Nguyên tắc:** signal-only. Không có lệnh thật, không kết nối broker, không lưu credential.
- **Phiên bản contract:** `1.0.0`.

## 1. Yêu cầu

| Thành phần | Phiên bản đã kiểm tra | Ghi chú |
|---|---|---|
| Windows | 10.0.19045 x64 | |
| MetaTrader 5 | 5.0.0.6249 | Terminal + MetaEditor |
| Python | 3.11.9 | Dùng `.venv` của repo |
| pytest | 9.1.1 | Cài trong `.venv` |

Không cần đăng nhập tài khoản để chạy static validation, compile hoặc Python tests. Để chạy indicator/EA
trên chart, terminal cần dữ liệu lịch sử của symbol/timeframe.

## 2. Tìm data folder

Trong MT5: **File → Open Data Folder**. Đường dẫn thường là:

```text
%APPDATA%\MetaQuotes\Terminal\<instance-hash>\
```

Bên trong có `MQL5\Indicators`, `MQL5\Experts`, `MQL5\Include`, `MQL5\Scripts`, `MQL5\Files`.

Không copy `accounts.dat`, `servers.dat`, `origin.txt` hoặc bất kỳ file phiên nào vào repo.

## 3. Copy file

Giữ nguyên cấu trúc tương đối vì source include bằng `../Include/...`.

| Trong repo | Đích |
|---|---|
| `mt5/Include/PinePort/WonderwhalesContract.mqh` | `MQL5\Include\PinePort\WonderwhalesContract.mqh` |
| `mt5/Include/LabLogger.mqh` | `MQL5\Include\LabLogger.mqh` |
| `mt5/Indicators/PinePort/Wonderwhales.mq5` | `MQL5\Indicators\PinePort\Wonderwhales.mq5` |
| `mt5/Experts/PineSignalLabEA.mq5` | `MQL5\Experts\PineSignalLabEA.mq5` |
| `mt5/Scripts/WonderwhalesContractTests.mq5` | `MQL5\Scripts\WonderwhalesContractTests.mq5` |

Sau khi copy, mở MetaEditor và refresh Navigator nếu file chưa xuất hiện.

## 4. Compile

Thứ tự khuyến nghị: contract (được include tự động) → indicator → test script → EA.

### Trong MetaEditor

1. Mở từng file.
2. `F7`.
3. Đọc tab **Errors** và **Warnings**; phải là `0 errors, 0 warnings`.

### Bằng script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1
```

Script compile cả ba file, lưu log vào `reports\build\`, đọc log UTF-16 và chỉ exit 0 khi cả ba đạt
0 error/0 warning. Không tin exit code của MetaEditor.

## 5. Kiểm tra contract (36 vector)

1. Kéo `WonderwhalesContractTests` từ Navigator vào một chart bất kỳ.
2. Chọn OK. Script chạy một lần, không đọc thị trường, không giao dịch.
3. Tab **Experts** phải có:

```text
TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0
```

Nếu có `FAIL`, ghi lại ID (A1…E6) và giá trị thực. Không sửa test để che lỗi.

## 6. Gắn indicator

1. Mở chart symbol/timeframe đã chốt.
2. Kéo `PinePort\Wonderwhales` vào chart.
3. Giữ input mặc định hoặc nhập đúng bộ 13 input.
4. Kiểm tra:
   - PSAR line.
   - Mũi tên BUY/SELL chỉ ở nến đã đóng.
   - Không nhấp nháy trong nến đang chạy.
5. Đổi mode `SAR` → `EMA` → `SAR_EMA` → `SAR_EMA_ATR`; tín hiệu phải đổi theo gate.

## 7. Gắn EA và đọc CSV

1. Kéo `PineSignalLabEA` vào cùng chart.
2. Bật **Algo Trading** chỉ để EA chạy OnTick; EA không gửi lệnh.
3. Tab **Experts**:
   - `event=init ... input_hash=...`
   - Không có lỗi lặp `indicator_create_failed`, `copy_time_failed`, `buffer_copy_failed`.
   - Khi có tín hiệu: `event=signal signal_id=... bar_open=... confirmed_at=...`.
4. CSV: `MQL5\Files\pine_signal_log.csv` (hoặc tên trong `InpOutputFile`).

Header:

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,signal_id,side,sar_dir,psar,fast,slow,atr_pct,input_hash
```

Kiểm tra:

- Mỗi `bar_open_time` chỉ một dòng.
- `confirmed_at = bar_open_time + timeframe`.
- `sar_dir` = 1 cho BUY, -1 cho SELL.
- Khởi động lại EA không ghi trùng bar cuối.

## 8. Chạy Python tests

```powershell
.venv\Scripts\python.exe -m pytest python\tests\test_pine_parity.py -q
.venv\Scripts\python.exe -m pytest -q
```

## 9. So sánh với Pine

Xem [`PINE_PARITY_Wonderwhales.md`](PINE_PARITY_Wonderwhales.md).

```powershell
.venv\Scripts\python.exe scripts\compare_pine_exports.py `
  --pine reports\pine_parity\pine_reference.csv `
  --mql5 reports\pine_parity\pine_signal_log.csv `
  --out-dir reports\pine_parity `
  --mql5-offset-minutes 180
```

`180` là ví dụ cho server GMT+3. Phải đổi theo server thực tế; EA ghi giờ server, Pine export dùng UTC.

Không có CSV reference thật thì ghi `BLOCKED`; không tạo CSV giả.

## 10. Tái lập một lần chạy

Ghi lại:

- Contract version và `input_hash` trong log init.
- Symbol, timeframe, khoảng ngày.
- 13 input (mode, PSAR, EMA, ATR, volume, RSI, BB).
- Terminal build và MetaEditor build.
- Đường dẫn CSV/log và SHA256 nếu cần.

## 11. Giới hạn và rollback

- Không có execution, không có P&L, không có backtest chiến lược.
- EA chỉ đọc `shift=1`; tín hiệu có thể trễ tối đa một tick của nến kế tiếp.
- `confirmOnClose=false` không được port.
- Nếu cần rollback: dùng package version trước trong `reports\packages\` hoặc `git checkout <commit>`
  sau khi đã commit thay đổi hiện tại. Không dùng `git reset --hard` khi còn thay đổi chưa commit.
