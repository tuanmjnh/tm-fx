# Chạy và kiểm chứng MT5 EA & AI Lab trên MetaTrader 5

- **Ngày:** 2026-10-28
- **Trạng thái:** signal-only, offline. Bốn file MQL5 đã compile **0 errors, 0 warnings** trong Data Folder
  của MT5 EXNESS; self-check, parity runtime, ONNX runtime và Strategy Tester **chưa chạy**.
- **Cảnh báo:** không đăng nhập tài khoản live, không nhập mật khẩu/investor password/OTP/server, không
  gửi thông tin tài khoản cho agent. EA trong repo không có `OrderSend`/`CTrade`, không mở/đóng lệnh.
  **0 trade là kết quả đúng** khi chạy `LabSignalEA`.

Ranh giới thực thi: [`decisions/0002-execution-boundary.md`](decisions/0002-execution-boundary.md).

## 1. Điều kiện

- MetaTrader 5 EXNESS đã cài; `MetaEditor64.exe` nằm trong thư mục cài đặt.
- Repository tại `D:\Applications\tm-fx`; Python venv đã có dependency.
- Chỉ dùng dữ liệu lịch sử offline đã có trong terminal. Không đăng nhập Exness chỉ để tải history.
- Không commit `.ex5`, log, model, report hay database.

Kiểm tra nhanh Python:

```powershell
cd D:\Applications\tm-fx
.\.venv\Scripts\python.exe -m pytest -q
```

Kỳ vọng hiện tại: `198 passed`.

## 2. Đồng bộ file vào Data Folder

Trong MT5: **File → Open Data Folder**. Có thể tìm Data Folder bằng PowerShell:

```powershell
$data = (Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" -Directory |
  Where-Object { Test-Path (Join-Path $_.FullName "MQL5") } |
  Select-Object -First 1).FullName
$data
```

Kiểm tra `$data` đúng là terminal EXNESS, rồi copy:

```powershell
Copy-Item D:\Applications\tm-fx\mt5\Experts\*.mq5  "$data\MQL5\Experts\"  -Force
Copy-Item D:\Applications\tm-fx\mt5\Include\*.mqh  "$data\MQL5\Include\"  -Force
Copy-Item D:\Applications\tm-fx\mt5\Scripts\*.mq5  "$data\MQL5\Scripts\"  -Force
Copy-Item D:\Applications\tm-fx\mt5\Files\*.csv    "$data\MQL5\Files\"    -Force
Copy-Item D:\Applications\tm-fx\models\candidates\demo-phase7-ml\model.onnx `
  "$data\MQL5\Files\model.onnx" -Force
```

Fixture parity dùng thư mục chung, không phải `MQL5\Files`:

```powershell
$common = "$env:APPDATA\MetaQuotes\Terminal\Common\Files"
New-Item -ItemType Directory -Force -Path $common | Out-Null
Copy-Item D:\Applications\tm-fx\datasets\samples\parity_ema_cross.csv $common -Force
```

Nếu `model.onnx` không còn, export lại:

```powershell
cd D:\Applications\tm-fx
.\.venv\Scripts\python.exe scripts\export_onnx_model.py `
  --model reports\ml\demo-phase7-ml\model.json `
  --out-dir models\candidates\demo-phase7-ml `
  --fixture python\tests\fixtures\onnx_feature_fixture.csv
```

## 3. Compile trong MetaEditor

Mở MetaEditor bằng `F4`, lần lượt mở và bấm `F7`:

1. `LabSignalEA.mq5`
2. `LabSignalEngineTests.mq5`
3. `LabSignalExport.mq5`
4. `LabOnnxInference.mq5`

Kỳ vọng: **0 errors, 0 warnings** cho cả bốn file.

Có thể compile bằng CLI; phải đọc log vì MetaEditor CLI trong môi trường này trả exit `1` dù compile
thành công:

```powershell
$me = "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe"
$out = "D:\Applications\tm-fx\reports\mt5"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$p = Start-Process -FilePath $me `
  -ArgumentList "/compile:$data\MQL5\Experts\LabSignalEA.mq5","/log:$out\LabSignalEA.compile.log" `
  -Wait -PassThru
Get-Content "$out\LabSignalEA.compile.log" -Encoding Unicode | Select-Object -Last 1
```

Kết quả đã xác minh ngày 2026-10-28: cả bốn log ghi `Result: 0 errors, 0 warnings`; `.ex5` đã sinh trong
Data Folder. Chi tiết: [`environment.md`](environment.md) mục 15.

## 4. Self-check signal engine

Trong MT5: `Ctrl+N` → **Scripts** → `LabSignalEngineTests`, kéo vào một chart bất kỳ, chọn OK.

Tab **Experts** kỳ vọng:

```text
TEST|SUMMARY|pass=... fail=0
TEST|RESULT|ALL_PASS
```

Không cần dữ liệu thị trường và không giao dịch.

## 5. Parity MQL5/Python

1. Đảm bảo `parity_ema_cross.csv` đã nằm trong `Terminal\Common\Files`.
2. Kéo `LabSignalExport` vào chart, giữ input mặc định:
   - `InpFastPeriod = 2`
   - `InpSlowPeriod = 3`
   - `InpAllowLong = true`
   - `InpAllowShort = true`
   - input `parity_ema_cross.csv`, output `parity_signals_mql5.csv`
3. Tab Experts kỳ vọng:

```text
event=export_done rows=12 buy=1 sell=1 hold=7 unknown=3
```

4. Copy output về repo và so sánh:

```powershell
Copy-Item "$common\parity_signals_mql5.csv" `
  D:\Applications\tm-fx\reports\parity\parity_signals_mql5.csv -Force
cd D:\Applications\tm-fx
.\.venv\Scripts\python.exe scripts\export_python_signals.py
.\.venv\Scripts\python.exe scripts\compare_signals.py `
  --mql5 reports\parity\parity_signals_mql5.csv `
  --python reports\parity\parity_signals_python.csv `
  --out-dir reports\parity\mql5_vs_python `
  --tolerance 1e-9
```

Kỳ vọng exit `0`, toàn bộ 12 hàng khớp; báo cáo nằm trong `reports\parity\mql5_vs_python\`.

## 6. ONNX runtime trong MT5

Đảm bảo `model.onnx` và `onnx_feature_fixture.csv` đã nằm trong `MQL5\Files`.

Kéo `LabOnnxInference` vào chart, chọn OK. Không cần bật Algo Trading vì EA chỉ chạy trong `OnInit`;
`OnTick()` rỗng.

Tab Experts kỳ vọng 24 dòng:

```text
onnx_row=0 probability=...
...
onnx_row=23 probability=...
```

So sánh với cột `expected_probability` trong `python\tests\fixtures\onnx_feature_fixture.csv`, tolerance
`1e-5`. Nếu `OnnxCreate`, `OnnxSetInputShape` hoặc `OnnxRun` lỗi: ghi lại mã lỗi và build terminal, không
tự tạo workaround. Khi đó Phase 8 vẫn giữ `READY_FOR_MANUAL_VALIDATION`.

## 7. Strategy Tester cho LabSignalEA

Chỉ làm bước này nếu terminal đã có dữ liệu lịch sử EURUSD M5 offline.

1. `Ctrl+R` → chọn Expert `LabSignalEA`.
2. Symbol `EURUSD`, timeframe `M5`, chọn khoảng ngày có dữ liệu.
3. Chạy, đọc tab **Journal** và **Experts**.
4. Kỳ vọng có `event=init`, `init_ok`, `signal_config`, `new_bar`, `signal`, `deinit`.
5. **0 trade là bình thường**: EA chỉ tạo tín hiệu, không có API giao dịch.

Nếu thiếu history, ghi rõ “Strategy Tester: chưa chạy do thiếu dữ liệu offline” và giữ trạng thái manual.
Không đăng nhập Exness live để tải history.

## 8. Gửi kết quả lại

Chỉ gửi log đã lược thông tin tài khoản:

- build terminal (Help → About hoặc dòng đầu Journal);
- kết quả compile từng file;
- kết quả self-check;
- `event=export_done ...` và exit code của `compare_signals.py`;
- 24 dòng `onnx_row=...` nếu chạy được ONNX;
- symbol/timeframe/date range nếu chạy Strategy Tester.

Không gửi account number, password, investor password, server, OTP hay token. Không commit `.ex5`, log,
model, `.sqlite`.

## 9. Lỗi thường gặp

| Hiện tượng | Việc cần làm |
|---|---|
| Không thấy EA/Script trong Navigator | Refresh Navigator hoặc khởi động lại MT5; kiểm tra đúng Data Folder |
| Compile báo thiếu include | Copy đủ `Indicators.mqh`, `SignalEngine.mqh`, `LabLogger.mqh` vào `MQL5\Include` |
| `LabSignalExport` báo `input_missing` | Copy `parity_ema_cross.csv` vào `Terminal\Common\Files`, không phải `MQL5\Files` |
| `OnnxCreate failed` | Ghi mã lỗi + build terminal; chưa kết luận tương thích ONNX |
| Strategy Tester không có history | Dừng; không đăng nhập broker chỉ để tải dữ liệu |
| Muốn thấy lệnh được đặt | Không thuộc phạm vi repo này; xem ADR 0002 |
