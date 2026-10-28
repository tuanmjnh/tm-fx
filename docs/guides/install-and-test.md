# Cài đặt và kiểm thử — PinePort, Simulation và Lab

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `guide.md`, `PINEPORT_INSTALL_AND_TEST.md`, `SIM_INSTALL_AND_TEST.md`, `environment.md`.

Nội dung:
1. Chạy và kiểm chứng MT5 EA & AI Lab trên MetaTrader 5
2. Cài đặt và kiểm thử Wonderwhales PinePort
3. Track C — Cài đặt và kiểm thử EA mô phỏng (runner/grid/DCA)
4. Kiểm kê môi trường — Phase 0

---
## Chạy và kiểm chứng MT5 EA & AI Lab trên MetaTrader 5

- **Ngày:** 2026-10-28
- **Trạng thái:** signal-only, offline. Toàn bộ `.mq5` đã compile **0 errors, 0 warnings**; self-check
  `SimCoreTests`/`SimPlanTests`, 6 contract suite (547 check) và 13/15 scenario Strategy Tester đã chạy
  thật. Parity runtime, ONNX runtime và 2 scenario `plan_*` vẫn `BLOCKED`/`BLOCKED_PERFORMANCE`.
- **Cảnh báo:** không đăng nhập tài khoản live, không nhập mật khẩu/investor password/OTP/server, không
  gửi thông tin tài khoản cho agent. EA trong repo không có `OrderSend`/`CTrade`, không mở/đóng lệnh.
  **0 trade là kết quả đúng** khi chạy `LabSignalEA`.

Ranh giới thực thi: [`decisions/0002-execution-boundary.md`](../decisions/0002-execution-boundary.md).

### 1. Điều kiện

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

### 2. Đồng bộ file vào Data Folder

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

### 3. Compile trong MetaEditor

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
Data Folder. Chi tiết: `environment.md` mục 15.

### 4. Self-check signal engine

Trong MT5: `Ctrl+N` → **Scripts** → `LabSignalEngineTests`, kéo vào một chart bất kỳ, chọn OK.

Tab **Experts** kỳ vọng:

```text
TEST|SUMMARY|pass=... fail=0
TEST|RESULT|ALL_PASS
```

Không cần dữ liệu thị trường và không giao dịch.

### 5. Parity MQL5/Python

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

### 6. ONNX runtime trong MT5

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

### 7. Strategy Tester cho LabSignalEA

Chỉ làm bước này nếu terminal đã có dữ liệu lịch sử EURUSD M5 offline.

1. `Ctrl+R` → chọn Expert `LabSignalEA`.
2. Symbol `EURUSD`, timeframe `M5`, chọn khoảng ngày có dữ liệu.
3. Chạy, đọc tab **Journal** và **Experts**.
4. Kỳ vọng có `event=init`, `init_ok`, `signal_config`, `new_bar`, `signal`, `deinit`.
5. **0 trade là bình thường**: EA chỉ tạo tín hiệu, không có API giao dịch.

Nếu thiếu history, ghi rõ “Strategy Tester: chưa chạy do thiếu dữ liệu offline” và giữ trạng thái manual.
Không đăng nhập Exness live để tải history.

### 8. Gửi kết quả lại

Chỉ gửi log đã lược thông tin tài khoản:

- build terminal (Help → About hoặc dòng đầu Journal);
- kết quả compile từng file;
- kết quả self-check;
- `event=export_done ...` và exit code của `compare_signals.py`;
- 24 dòng `onnx_row=...` nếu chạy được ONNX;
- symbol/timeframe/date range nếu chạy Strategy Tester.

Không gửi account number, password, investor password, server, OTP hay token. Không commit `.ex5`, log,
model, `.sqlite`.

### 9. Lỗi thường gặp

| Hiện tượng | Việc cần làm |
|---|---|
| Không thấy EA/Script trong Navigator | Refresh Navigator hoặc khởi động lại MT5; kiểm tra đúng Data Folder |
| Compile báo thiếu include | Copy đủ `Indicators.mqh`, `SignalEngine.mqh`, `LabLogger.mqh` vào `MQL5\Include` |
| `LabSignalExport` báo `input_missing` | Copy `parity_ema_cross.csv` vào `Terminal\Common\Files`, không phải `MQL5\Files` |
| `OnnxCreate failed` | Ghi mã lỗi + build terminal; chưa kết luận tương thích ONNX |
| Strategy Tester không có history | Dừng; không đăng nhập broker chỉ để tải dữ liệu |
| Muốn thấy lệnh được đặt | Không thuộc phạm vi repo này; xem ADR 0002 |

## Cài đặt và kiểm thử Wonderwhales PinePort

- **Đối tượng:** indicator `Wonderwhales`, EA `PineSignalLabEA`, contract tests.
- **Nguyên tắc:** signal-only. Không có lệnh thật, không kết nối broker, không lưu credential.
- **Phiên bản contract:** `1.0.0`.

### 1. Yêu cầu

| Thành phần | Phiên bản đã kiểm tra | Ghi chú |
|---|---|---|
| Windows | 10.0.19045 x64 | |
| MetaTrader 5 | 5.0.0.6249 | Terminal + MetaEditor |
| Python | 3.11.9 | Dùng `.venv` của repo |
| pytest | 9.1.1 | Cài trong `.venv` |

Không cần đăng nhập tài khoản để chạy static validation, compile hoặc Python tests. Để chạy indicator/EA
trên chart, terminal cần dữ liệu lịch sử của symbol/timeframe.

### 2. Tìm data folder

Trong MT5: **File → Open Data Folder**. Đường dẫn thường là:

```text
%APPDATA%\MetaQuotes\Terminal\<instance-hash>\
```

Bên trong có `MQL5\Indicators`, `MQL5\Experts`, `MQL5\Include`, `MQL5\Scripts`, `MQL5\Files`.

Không copy `accounts.dat`, `servers.dat`, `origin.txt` hoặc bất kỳ file phiên nào vào repo.

### 3. Copy file

Giữ nguyên cấu trúc tương đối vì source include bằng `../Include/...`.

| Trong repo | Đích |
|---|---|
| `mt5/Include/PinePort/WonderwhalesContract.mqh` | `MQL5\Include\PinePort\WonderwhalesContract.mqh` |
| `mt5/Include/LabLogger.mqh` | `MQL5\Include\LabLogger.mqh` |
| `mt5/Indicators/PinePort/Wonderwhales.mq5` | `MQL5\Indicators\PinePort\Wonderwhales.mq5` |
| `mt5/Experts/PineSignalLabEA.mq5` | `MQL5\Experts\PineSignalLabEA.mq5` |
| `mt5/Scripts/WonderwhalesContractTests.mq5` | `MQL5\Scripts\WonderwhalesContractTests.mq5` |
| `mt5/Include/PinePort/LongKacoVSAContract.mqh` | `MQL5\Include\PinePort\LongKacoVSAContract.mqh` |
| `mt5/Indicators/PinePort/LongKacoVSA.mq5` | `MQL5\Indicators\PinePort\LongKacoVSA.mq5` |
| `mt5/Scripts/LongKacoVSAContractTests.mq5` | `MQL5\Scripts\LongKacoVSAContractTests.mq5` |
| `mt5/Include/PinePort/TMFusionZonesContract.mqh` | `MQL5\Include\PinePort\TMFusionZonesContract.mqh` |
| `mt5/Indicators/PinePort/TMFusionZones.mq5` | `MQL5\Indicators\PinePort\TMFusionZones.mq5` |
| `mt5/Scripts/TMFusionZonesContractTests.mq5` | `MQL5\Scripts\TMFusionZonesContractTests.mq5` |
| `mt5/Include/PinePort/PriceActionMTFContract.mqh` | `MQL5\Include\PinePort\PriceActionMTFContract.mqh` |
| `mt5/Indicators/PinePort/PriceActionMTF.mq5` | `MQL5\Indicators\PinePort\PriceActionMTF.mq5` |
| `mt5/Scripts/PriceActionMTFContractTests.mq5` | `MQL5\Scripts\PriceActionMTFContractTests.mq5` |
| `mt5/Include/PinePort/TMXAUSignals2Contract.mqh` | `MQL5\Include\PinePort\TMXAUSignals2Contract.mqh` |
| `mt5/Indicators/PinePort/TMXAUSignals2.mq5` | `MQL5\Indicators\PinePort\TMXAUSignals2.mq5` |
| `mt5/Scripts/TMXAUSignals2ContractTests.mq5` | `MQL5\Scripts\TMXAUSignals2ContractTests.mq5` |

LongKaco VSA, TM Fusion Zones, Price Action MTF và TM XAU Signals 2 mới ở Phase 4: indicator và test script
compile được; contract test đã chạy PASS trong Strategy Tester (47/82/120/107 check), nhưng EA chưa đọc
bốn indicator này. Không có hướng dẫn giao dịch cho chúng.

Sau khi copy, mở MetaEditor và refresh Navigator nếu file chưa xuất hiện.

Có thể để script làm bước copy:

```powershell
# Chỉ in kế hoạch, không ghi gì
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1

# Copy các file còn thiếu rồi compile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply

# Ghi đè file đích khác nội dung (chỉ khi bạn chắc chắn)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply -Force
```

Script tự tìm data folder dưới `%APPDATA%\MetaQuotes\Terminal`, bỏ qua file đích đã giống hệt, không ghi
đè file khác nội dung nếu thiếu `-Force`, không mở terminal và không đọc/ghi file tài khoản. Nếu có nhiều
data folder, truyền `-TerminalDataDir "<path chứa MQL5>"`.

### 4. Compile

Thứ tự khuyến nghị: contract (được include tự động) → indicator → test script → EA.

`deploy_pineport.ps1 -Apply` tự compile toàn bộ indicator/test script/EA sau khi copy. Nếu chỉ muốn copy,
thêm `-SkipCompile`.

#### Trong MetaEditor

1. Mở từng file.
2. `F7`.
3. Đọc tab **Errors** và **Warnings**; phải là `0 errors, 0 warnings`.

#### Bằng script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1
```

Script compile bảy file, lưu log vào `reports\build\`, đọc log UTF-16 và chỉ exit 0 khi cả bảy đạt
0 error/0 warning. Không tin exit code của MetaEditor.

### 5. Kiểm tra contract (36 + 47 + 82 + 119 + 105 + 155 vector)

1. Kéo `WonderwhalesContractTests` từ Navigator vào một chart bất kỳ.
2. Chọn OK. Script chạy một lần, không đọc thị trường, không giao dịch.
3. Tab **Experts** phải có:

```text
TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0
```

Lặp lại với `LongKacoVSAContractTests` (47 vector, `contract=1.0.0`), `TMFusionZonesContractTests`
(82 vector, `contract=1.0.0`), `PriceActionMTFContractTests` (119 vector, `contract=1.0.0`) và
`TMXAUSignals2ContractTests` (105 vector hợp đồng + 2 kiểm tra bổ sung → `pass=107`, `contract=1.0.0`) và
`TMIndicator2ContractTests` (155 vector, `contract=1.0.0`).
Nếu có `FAIL`, ghi lại ID và giá trị thực. Không sửa test để che lỗi.

### 6. Gắn indicator

1. Mở chart symbol/timeframe đã chốt.
2. Kéo `PinePort\Wonderwhales` vào chart.
3. Giữ input mặc định hoặc nhập đúng bộ 13 input.
4. Kiểm tra:
   - PSAR line.
   - Mũi tên BUY/SELL chỉ ở nến đã đóng.
   - Không nhấp nháy trong nến đang chạy.
5. Đổi mode `SAR` → `EMA` → `SAR_EMA` → `SAR_EMA_ATR`; tín hiệu phải đổi theo gate.

LongKaco VSA, TM Fusion Zones, Price Action MTF, TM XAU Signals 2 và TM Indicator 2: kéo
`PinePort\LongKacoVSA`, `PinePort\TMFusionZones`, `PinePort\PriceActionMTF`,
`PinePort\TMXAUSignals2` hoặc `PinePort\TMIndicator2` lên chart để kiểm tra marker/ribbon/zone/plan;
chúng không có EA giao dịch riêng và không có hướng dẫn giao dịch.

### 7. Gắn EA và đọc CSV

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

Audit tự động file CSV:

```powershell
.venv\Scripts\python.exe scripts\audit_signal_csv.py `
  --csv "C:\Users\<user>\AppData\Roaming\MetaQuotes\Terminal\<id>\MQL5\Files\pine_signal_log.csv" `
  --offset-minutes 180
```

Exit 0 = không phát hiện lỗi cấu trúc; 1 = có issue (in `kind=...`); 2 = file/không đọc được. Tool kiểm tra
thứ tự thời gian, căn timeframe, symbol/timeframe/mode/input_hash đồng nhất, giá rỗng, ATR% âm và
`detected_at >= confirmed_at`. Đây không phải kiểm tra parity.

#### 7.1 EA đa nguồn (`PineMultiSignalLabEA`)

1. Kéo `PineMultiSignalLabEA` lên chart; bật đúng nguồn cần log (`InpEnableWw`, `InpEnableLk`,
   `InpEnableFz`, `InpEnablePa`, `InpEnableX2`, `InpEnableTm2`). Mặc định chỉ WW bật.
2. CSV: `MQL5\Files\pine_multi_signal_log.csv`; mỗi dòng là một tín hiệu của một nguồn.
3. Header:

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,source,contract_version,signal_id,side,dir,score,entry,sl,tp1,tp2,tp3,reason,input_hash
```

4. Kiểm tra: mỗi cặp `(source, bar_open_time)` chỉ một dòng; `source` thuộc sáu tên đã chốt; khởi động
   lại EA không ghi trùng bar cuối của từng nguồn.

Audit:

```powershell
.venv\Scripts\python.exe scripts\audit_multi_signal_csv.py `
  --csv "C:\Users\<user>\AppData\Roaming\MetaQuotes\Terminal\<id>\MQL5\Files\pine_multi_signal_log.csv"
```

EA gọi `iCustom` **không truyền tham số**, nên indicator phải giữ input mặc định đã chốt trong contract.
TM Indicator 2 có 118 input, vượt giới hạn 63 tham số của `iCustom`, nên không thể override từ EA.

### 8. Chạy Python tests

```powershell
.venv\Scripts\python.exe -m pytest python\tests\test_pine_parity.py python\tests\test_signal_audit.py -q
.venv\Scripts\python.exe -m pytest python\tests\test_multi_signal_audit.py python\tests\test_multi_source_parity.py -q
.venv\Scripts\python.exe -m pytest -q
```

### 9. So sánh với Pine

Xem [`PINE_PARITY_Wonderwhales.md`](../indicators/parity.md).

```powershell
.venv\Scripts\python.exe scripts\compare_pine_exports.py `
  --pine reports\pine_parity\pine_reference.csv `
  --mql5 reports\pine_parity\pine_signal_log.csv `
  --out-dir reports\pine_parity `
  --mql5-offset-minutes 180
```

`180` là ví dụ cho server GMT+3. Phải đổi theo server thực tế; EA ghi giờ server, Pine export dùng UTC.

Không có CSV reference thật thì ghi `BLOCKED`; không tạo CSV giả.

#### 9.1 Parity đa nguồn

Xem [`PINE_PARITY_MULTI_SOURCE.md`](../indicators/parity.md).

```powershell
.venv\Scripts\python.exe scripts\compare_multi_signal_exports.py `
  --reference reports\multi_source_parity\pine_reference.csv `
  --mql5 "C:\Users\<user>\AppData\Roaming\MetaQuotes\Terminal\<id>\MQL5\Files\pine_multi_signal_log.csv" `
  --mql5-offset-minutes 180 `
  --out-dir reports\multi_source_parity
```

Exit 0 = match, 1 = mismatch, 2 = CSV/đối số lỗi, 3 = `BLOCKED` (thiếu một trong hai file). Báo cáo
theo từng nguồn nằm trong `multi_source_parity.json`.

### 10. Tái lập một lần chạy

Ghi lại:

- Contract version và `input_hash` trong log init.
- Symbol, timeframe, khoảng ngày.
- 13 input (mode, PSAR, EMA, ATR, volume, RSI, BB).
- Terminal build và MetaEditor build.
- Đường dẫn CSV/log và SHA256 nếu cần.

### 11. Giới hạn và rollback

- Không có execution, không có P&L, không có backtest chiến lược.
- EA chỉ đọc `shift=1`; tín hiệu có thể trễ tối đa một tick của nến kế tiếp.
- `confirmOnClose=false` không được port.
- Nếu cần rollback: dùng package version trước trong `reports\packages\` hoặc `git checkout <commit>`
  sau khi đã commit thay đổi hiện tại. Không dùng `git reset --hard` khi còn thay đổi chưa commit.

## Track C — Cài đặt và kiểm thử EA mô phỏng (runner/grid/DCA/plan/wonderwhales)

- **Đối tượng:** `RunnerTrailingLabEA`, `GridLabEA`, `DCALabEA`, `PinePlanSimEA`, `WonderwhalesSimEA`,
  `SimCoreTests`, `SimPlanTests` và preset trong `configs/sim/`.
- **Trạng thái 2026-10-28:** compile + static tests PASS; `SimCoreTests` 123/0 và `SimPlanTests` 39/0
  đã chạy thật trong MT5 (terminal chưa đăng nhập, chart `XAUUSDm,M1`); Strategy Tester `NOT_RUN`.
- **Nguyên tắc:** simulation-only. Không có API gửi lệnh, không kết nối broker, không lưu credential.
  Strategy Tester hiển thị **0 deal** là hành vi đúng.

### 1. Yêu cầu

| Thành phần | Đã kiểm tra | Ghi chú |
|---|---|---|
| Windows | 10.0.19045 x64 | |
| MetaTrader 5 + MetaEditor | 5.0.0.6249 (EXNESS) | Không cần đăng nhập để compile |
| Python | 3.11.9 trong `.venv` | Chỉ cho validator/test |
| pytest | 9.1.1 | |
| Lịch sử symbol | Người dùng tự tải | Thiếu history → `BLOCKED`, không thay synthetic |

### 2. Thiết lập một lần

```powershell
# Từ thư mục gốc repository
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# Kiểm tra môi trường (22 check, không đọc secret)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-environment.ps1
```

Kỳ vọng: `SUMMARY: checks=22 fail=0` và `ENVIRONMENT_OK`.

### 3. Validate preset trước khi nạp vào MT5

```powershell
.\.venv\Scripts\python.exe scripts\validate_sim_configs.py
```

Kỳ vọng: `SUMMARY: checked=6 fail=0` (5 preset + project, 15 scenario); snapshot ghi một lần vào
`reports\config-snapshots\` và lần sau báo `unchanged`. Validator từ chối `execution_mode` khác
`SIMULATION_ONLY`, `allow_live_trading != false`, input thiếu/thừa, khóa nhạy cảm và override scenario sai.

### 4. Copy source vào Data Folder

Trong MT5: **File → Open Data Folder**. Giữ nguyên cấu trúc tương đối vì source include `../Include/Sim/...`.

| Trong repo | Đích |
|---|---|
| `mt5/Include/Sim/*.mqh` (10 file) | `MQL5\Include\Sim\` |
| `mt5/Experts/RunnerTrailingLabEA.mq5` | `MQL5\Experts\RunnerTrailingLabEA.mq5` |
| `mt5/Experts/GridLabEA.mq5` | `MQL5\Experts\GridLabEA.mq5` |
| `mt5/Experts/DCALabEA.mq5` | `MQL5\Experts\DCALabEA.mq5` |
| `mt5/Experts/PinePlanSimEA.mq5` | `MQL5\Experts\PinePlanSimEA.mq5` |
| `mt5/Experts/WonderwhalesSimEA.mq5` | `MQL5\Experts\WonderwhalesSimEA.mq5` |
| `mt5/Scripts/SimCoreTests.mq5` | `MQL5\Scripts\SimCoreTests.mq5` |
| `mt5/Scripts/SimPlanTests.mq5` | `MQL5\Scripts\SimPlanTests.mq5` |

`PinePlanSimEA` còn cần ba contract header và ba indicator PinePort đã cài theo
[`mt5/README.md`](../../mt5/README.md) mục 9–14 (`Include\PinePort\*`, `Indicators\PinePort\*`).
`WonderwhalesSimEA` cần `Include\PinePort\WonderwhalesContract.mqh` và indicator
`Indicators\PinePort\Wonderwhales.ex5`; EA ghim symbol `XAUUSDm` qua `InpRequireSymbol`.

Copy thủ công; repo không có script tự động ghi vào thư mục MT5. Không copy `accounts.dat`,
`servers.dat`, `origin.txt` hoặc file phiên vào repo.

Sau khi copy, compile trong MetaEditor: mở từng `.mq5` → `F7` → tab Errors/Warnings phải là
`0 errors, 0 warnings`. Có thể compile bản trong repo trước bằng:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\*.mq5"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Scripts\SimCoreTests.mq5"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Scripts\SimPlanTests.mq5"
```

Lưu ý: build script compile bản trong repo và ghi log vào `reports\build\`; nó **không** copy `.ex5` sang
Data Folder và không mở terminal.

### 5. Chạy `SimCoreTests` (bắt buộc trước khi tin EA)

1. Kéo `SimCoreTests` từ Navigator vào một chart bất kỳ (không cần đúng symbol).
2. Chọn OK; script chạy một lần, không đọc thị trường, không ghi file.
3. Tab **Experts** phải có dòng cuối:

```text
TEST|RESULT|ALL_PASS|pass=123 fail=0|suite=sim_core
```

Nếu có `FAIL`, ghi lại ID và giá trị thực; không sửa test để che lỗi. Kết quả này kiểm tra portfolio,
risk guard, cost model, trailing, grid, DCA và logger bằng vector tự sinh.

Chạy thêm `SimPlanTests` trước khi dùng `PinePlanSimEA`; tab **Experts** phải có:

```text
TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan
```

Script này chỉ kiểm tra `SimPlan.mqh` (resolve side, validate plan, chọn/hit/fill target), không đọc
indicator hay thị trường.

Chạy `WonderwhalesContractTests` trước khi dùng `WonderwhalesSimEA`; tab **Experts** phải có:

```text
TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0
```

Script chỉ kiểm tra contract buffer/mode/hash của indicator Wonderwhales; không đọc thị trường.

### 6. Chạy EA

- Trên chart: kéo EA, nhập input theo bảng trong [`strategy-tester.md`](strategy-tester.md),
  bật **Algo Trading** chỉ để `OnTick` chạy. EA không gửi lệnh.
- Strategy Tester: `Ctrl+R`, chọn EA/symbol/period/khoảng ngày, dùng preset baseline rồi các override
  stress/edge. Quy trình đầy đủ, ma trận 15 scenario và template report:
  [`strategy-tester.md`](strategy-tester.md).

Mỗi lần chạy dùng `InpLogFile` riêng (logger ghi nối). Ví dụ:
`sim_runner_baseline_20261028.csv`.

### 7. Đọc CSV

Header cố định 18 cột:

```text
logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason
```

Đường dẫn:

- Chart thường: `MQL5\Files\<InpLogFile>`.
- Strategy Tester: sandbox của agent, thường
  `%APPDATA%\MetaQuotes\Terminal\<hash>\Tester\Agent-*\MQL5\Files\<InpLogFile>`.

Kiểm tra tối thiểu:

- Có `ENTRY`, ít nhất một `EXIT` hoặc `BASKET_*`, và đúng một `SUMMARY`.
- `config_hash` giống nhau trong toàn file và khớp snapshot đã dùng.
- Runner: SL long không giảm/short không tăng; trailing không nới stop.
- Grid: số tầng ≤ `InpMaxGridLevels`, tổng volume ≤ `InpMaxVirtualExposure`.
- DCA: số add ≤ `InpMaxDcaAdds`, tối đa một fill/bar, volume add = base × multiplier^n (clamp).
- Không có dòng vượt cap hoặc `HALTED` trái kỳ vọng.

### 8. Tự động và thủ công

| Hạng mục | Trạng thái | Cách xác minh |
|---|---|---|
| Validate preset/scenario | Tự động, PASS | `scripts\validate_sim_configs.py` |
| Compile 25 file `.mq5` | Tự động, PASS | `scripts\build-mql5.ps1` |
| Static scan API giao dịch/placeholder | Tự động, PASS | `scripts\validate-project.py` |
| Python tests (kể cả vector DCA/plan độc lập) | Tự động, PASS | `scripts\run-python-tests.ps1` |
| `SimCoreTests` trong MT5 | **PASS runtime** — `pass=123 fail=0` | Mục 5; log tab Experts 2026-10-28 18:36 |
| `SimPlanTests` trong MT5 | **PASS runtime** — `pass=39 fail=0` | Mục 5; log tab Experts 2026-10-28 18:41 |
| Strategy Tester 15 scenario | **PASS một phần** — 13/15 (`ww_*`, runner, grid, DCA) có SUMMARY; 2 `plan_*` `BLOCKED_PERFORMANCE` | `strategy-tester.md` §9 |
| Đọc/audit CSV thật | **PASS** — 13 CSV thật đã audit; DCA `adds=0` là bug reporting | Mục 7, `strategy-tester.md` §9 |
| Contract test 6 indicator | **PASS** — 6/6 suite, 547 check | `strategy-tester.md` §8 |

### 9. Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp | Hành động |
|---|---|---|
| `INIT_PARAMETERS_INCORRECT` | Input ngoài khoảng, exposure < base volume, stop/target ≤ 0 | Đọc dòng log lỗi trong Experts; sửa theo bảng preset |
| Không có file CSV | `InpEnableLog=false`, sai `InpLogFile`, tester sandbox khác | Bật log; tìm trong `Tester\Agent-*\MQL5\Files` |
| CSV trộn nhiều run | Logger append | Dùng tên file mới; không sửa file cũ |
| Không có entry | EMA chưa warmup, spread > cap, cooldown, guard chặn | Kiểm tra `BLOCKED` reason trong CSV |
| Grid/DCA không add | Chạm cap tầng/add/exposure hoặc một fill/bar | Đọc `BLOCKED` reason; không nới cap để “test đẹp” |
| Tester 0 deal | Đúng thiết kế simulation-only | Không coi là lỗi |
| Thiếu history | Chưa tải dữ liệu | Ghi `BLOCKED`; không đăng nhập broker chỉ để tải |

### 10. Tái lập và rollback

- Ghi lại: build MT5, symbol, period, model, date range, input đã dùng, `InpLogFile`, snapshot config và
  SHA256 của CSV.
- Package source hiện tại: `scripts\package-source.ps1 -Version <x.y.z>` tạo zip + manifest trong
  `reports\packages\` (không chứa `.ex5`, log, `.venv`, report).
- Rollback: dùng package/commit trước sau khi đã bảo toàn thay đổi hiện tại. Không `git reset --hard` khi
  còn file chưa commit.
- Không tuyên bố PASS runtime nếu chưa có CSV + kết quả `SimCoreTests` + report tester thật.

## Track C — PinePlanSimEA (W10)

- **Đối tượng:** `PinePlanSimEA`, `SimPlanTests`, preset `configs/sim/pine_plan_lab.json`.
- **Nguyên tắc:** EA đọc trade plan của indicator PinePort và mở **một vị thế ảo**; không gửi lệnh,
  không đọc tài khoản.
- **Trạng thái:** compile 0/0 và static test PASS; runtime trong MT5 `NOT_RUN`.

### 1. Điều kiện

| Thành phần | Yêu cầu |
|---|---|
| Indicator | `PriceActionMTF`, `TMXAUSignals2` hoặc `TMIndicator2` đã compile trong `MQL5\Indicators\PinePort\` |
| Contract header | `PriceActionMTFContract.mqh`, `TMXAUSignals2Contract.mqh`, `TMIndicator2Contract.mqh` trong `MQL5\Include\PinePort\` |
| Sim core | 10 file `MQL5\Include\Sim\*.mqh`, gồm `SimPlan.mqh` |
| Symbol/timeframe | Bất kỳ symbol có history; preset dùng `XAUUSD`/`M15` làm nhãn ngữ cảnh |

EA gọi `iCustom` **không truyền input**, nên indicator phải chạy được với default. Nếu indicator chưa
có trong Navigator, `OnInit` trả `INIT_FAILED` với `indicator_init_failed`.

### 2. Input

| Input | Giá trị baseline | Ghi chú |
|---|---|---|
| `InpSource` | `0` (PA) | `0` PA, `1` TM XAU Signals 2, `2` TM Indicator 2 |
| `InpInitialBalance` | 10000.0 | balance ảo |
| `InpVolume` | 1.0 | volume ảo mỗi lệnh |
| `InpEnableLog` | true | ghi CSV vào `MQL5\Files` |
| `InpLogFile` | `sim_plan_log.csv` | phải đổi tên mỗi lần chạy |
| `InpSideFilter` | `0` | `1` long-only, `-1` short-only |
| `InpTargetMode` | `0` (TP1) | `1` TP3 (fallback TP2/TP1), `2` chỉ SL |
| `InpMinStopPoints` | 5.0 | từ chối plan có SL quá gần |
| `InpMinTargetPoints` | 5.0 | từ chối plan có target quá gần |
| `InpMaxHoldingBars` | 0 | 0 = tắt |
| `InpBreakEvenEnabled` | false | bật thì trigger phải > 0 |
| `InpBreakEvenTriggerPoints` | 400.0 | |
| `InpBreakEvenOffsetPoints` | 0.0 | |
| `InpTrailEnabled` | false | trailing theo khoảng cố định |
| `InpTrailFixedPoints` | 300.0 | bật trailing thì phải > 0 |
| `InpMinStopPointsTrail` | 5.0 | khoảng tối thiểu tới giá |
| `InpCooldownBars` | 1 | chặn entry mới sau lệnh trước |
| `InpMaxSpreadPoints` | 50.0 | |
| `InpMaxVirtualExposure` | 1.0 | phải ≥ `InpVolume` |
| `InpMaxDailyLossPct` | 2.0 | 0 = tắt |
| `InpMaxDrawdownPct` | 5.0 | 0 = tắt |
| `InpHaltOnBreach` | false | breach thường chỉ chặn, không halt |
| `InpCommissionPerVolume` | 0.0 | tổng tiền mỗi fill |
| `InpSlippagePoints` | 0.0 | bất lợi mỗi fill |

Preset đầy đủ: [`configs/sim/pine_plan_lab.json`](../../configs/sim/pine_plan_lab.json). Validator đã
kiểm tra chéo exposure ≥ volume, breakeven/trail bật thì ngưỡng > 0.

### 3. Chạy

1. Copy source theo mục Track C và compile `PinePlanSimEA.mq5` + `SimPlanTests.mq5`.
2. Chạy `SimPlanTests` trước; kỳ vọng `pass=39 fail=0|suite=sim_plan`.
3. Kéo EA lên chart hoặc chạy Strategy Tester. Mỗi lần chạy dùng `InpLogFile` riêng.
4. Kiểm tra Journal có `LAB|INFO|plan|initialized`, `LAB|INFO|plan|simulation_only`, và không có
   `LAB|ERROR|plan`.

### 4. Đọc CSV và reason token

Header giống 18 cột của simulation core. Các dòng đặc thù:

| Event | Reason | Nghĩa |
|---|---|---|
| `INIT` | `SIMULATION_ONLY\|source=...\|config_hash=...` | khởi tạo, hash cấu hình |
| `ENTRY` | `PLAN_ENTRY\|source=...\|ref_entry=...\|risk=...\|spread_points=...` | fill ảo; `entry` là giá khớp, `ref_entry` chỉ trong reason |
| `RISK` | `PLAN_REJECTED\|reason=...\|source=...` | plan không hợp lệ |
| `RISK` | `ENTRY_BLOCKED\|reason=...\|state=...` | RiskGuard chặn |
| `EXIT` | `SL_HIT` / `SL_GAP\|gap_points=...` | stop thường hoặc gap |
| `EXIT` | `TARGET_HIT\|mode=TP1\|TP3\|NONE` | target, fill đúng target |
| `EXIT` | `MAX_HOLDING_BARS` | hết thời gian giữ |
| `SUMMARY` | `source=...\|entries=...\|rejected=...\|trades=...` | tổng kết cuối run |

Kiểm tra tối thiểu: `config_hash` giống nhau toàn file; SL luôn đúng phía entry; `entry` của lệnh khớp
không nhất thiết bằng `ref_entry`; không có `TARGET_HIT` với fill vượt target theo hướng có lợi.

### 5. Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp | Hành động |
|---|---|---|
| `indicator_init_failed` | Thiếu indicator/contract trong Data Folder | Cài đủ mục 1 và compile lại |
| Không có entry | Không có tín hiệu biên, `PLAN_VALID=0`, spread > cap, cooldown, guard chặn | Đọc reason `PLAN_REJECTED`/`ENTRY_BLOCKED` |
| Nhiều `plan_invalid` | Indicator đang trả plan rỗng hoặc chưa warmup | Chờ đủ bar; kiểm tra indicator trên chart |
| Không có CSV | Sai `InpLogFile` hoặc tester sandbox khác | Tìm trong `Tester\Agent-*\MQL5\Files` |
| Tester 0 deal | Đúng thiết kế simulation-only | Không coi là lỗi |

## Track C — WonderwhalesSimEA (XAUUSDm)

- **Đối tượng:** `WonderwhalesSimEA`, indicator `PinePort\Wonderwhales`, preset
  `configs/sim/wonderwhales_xauusdm.json`.
- **Nguyên tắc:** EA đọc tín hiệu buy/sell trên nến đã đóng và mở **một vị thế ảo**; không gửi lệnh,
  không đọc tài khoản.
- **Trạng thái:** compile 0/0 (repo và Data Folder); **Strategy Tester PASS 3/3 scenario `ww_*`** chạy
  headless trên `XAUUSDm` M15 ngày 2026-10-28 (không deal, không credential trong ini).

### 1. Điều kiện

| Thành phần | Yêu cầu |
|---|---|
| Indicator | `Wonderwhales.ex5` trong `MQL5\Indicators\PinePort\` |
| Contract header | `WonderwhalesContract.mqh` trong `MQL5\Include\PinePort\` |
| Sim core | 10 file `MQL5\Include\Sim\*.mqh` |
| Symbol/timeframe | `XAUUSDm` M15 hoặc M5; guard `InpRequireSymbol` từ chối symbol khác |
| History | Cần tối thiểu `InpWarmupBars + 5` bar; thiếu → EA chờ, không vào lệnh |

### 2. Input baseline

| Input | Giá trị | Ghi chú |
|---|---|---|
| `InpRequireSymbol` | `XAUUSDm` | chuỗi rỗng = tắt guard |
| `InpVolume` / `InpMaxVirtualExposure` | 0.1 / 0.1 | exposure phải ≥ volume |
| `InpLogFile` | `sim_wonderwhales_xauusdm.csv` | đổi tên mỗi lần chạy |
| `InpMode` | 0 | SAR; 1 EMA, 2 SAR+EMA, 3 SAR+EMA+ATR |
| `InpWarmupBars` | 300 | phải ≥ `InpEma200` |
| `InpStopMode` | 0 | 0 PSAR, 1 ATR%, 2 fixed |
| `InpFixedStopPoints` | 3000.0 | dùng cho mode fixed; `XAUUSDm` point 0.001 → 3.0 giá |
| `InpMinStopPoints` | 150.0 | khoảng SL tối thiểu; dưới ngưỡng → `STOP_REJECTED` |
| `InpExitOnFlip` | true | đóng khi tín hiệu đảo |
| `InpMaxHoldingBars` | 0 | 0 = tắt |
| `InpMaxSpreadPoints` | 600.0 | spread đo được ~260 point; 200 quá chặt và chặn mọi entry |

Preset đầy đủ và toàn bộ 35 input: [`configs/sim/wonderwhales_xauusdm.json`](../../configs/sim/wonderwhales_xauusdm.json).

### 3. Chạy

1. Copy EA + contract + indicator theo mục 4 và compile.
2. Chạy `WonderwhalesContractTests`; kỳ vọng `TEST|RESULT|ALL_PASS|pass=36 fail=0|contract=1.0.0`.
3. Kéo EA lên chart `XAUUSDm` hoặc chạy Strategy Tester M15/M5. Mỗi lần chạy dùng `InpLogFile` riêng.
4. Journal phải có `LAB|INFO|wonderwhales|initialized`, `LAB|INFO|wonderwhales|simulation_only`, và không
   có `LAB|ERROR|wonderwhales` trừ khi input cố ý sai.

Chạy headless (đã dùng thật): tạo `.set` từ preset + override, đặt trong `MQL5\Profiles\Tester\` (GUI
**Load** đọc `MQL5\Presets\`, còn tham số `ExpertParameters` của terminal headless chỉ đọc
`MQL5\Profiles\Tester\`), rồi gọi `terminal64.exe /config:<ini>` với `ShutdownTerminal=1`. CSV của agent
sandbox bị xoá đầu mỗi run — copy ngay sau khi tester kết thúc. Chi tiết lệnh: `strategy-tester.md` §9.

### 4. Đọc CSV và reason token

| Event | Reason | Nghĩa |
|---|---|---|
| `INIT` | `SIMULATION_ONLY\|config_hash=...\|indicator=...\|contract=...` | khởi tạo |
| `ENTRY` | `SIGNAL_WW_BUY` / `SIGNAL_WW_SELL` + `stop_mode=`, `distance_points=`, `risk=`, `spread_points=` | fill ảo |
| `RISK` | `ENTRY_BLOCKED\|reason=...` / `STOP_REJECTED\|distance_points=...\|min_points=...` | bị chặn |
| `EXIT` | `SL_HIT`, `SL_GAP\|gap_points=...`, `MAX_HOLDING_BARS`, `SIGNAL_FLIP` | thoát |
| `SUMMARY` | `trades=`, `wins=`, `losses=`, `flats=`, `net=`, `realized=`, `max_dd=` | tổng kết |

Kiểm tra tối thiểu: SL luôn đúng phía entry và cách fill ≥ `InpMinStopPoints`; không có entry khi
`Bars < InpWarmupBars + 5`; một vị thế ảo tại một thời điểm; không có deal thật.

### 5. Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp | Hành động |
|---|---|---|
| `symbol_guard_expected=...` | Chart không phải `XAUUSDm` | Đổi chart hoặc để trống `InpRequireSymbol` |
| `indicator_init_failed` | Thiếu `Wonderwhales.ex5`/contract | Cài đủ mục 1 và compile lại |
| Không có entry | Chưa đủ warmup, tín hiệu = 0, spread > cap, cooldown, guard chặn | Đọc reason `RISK` |
| Nhiều `STOP_REJECTED` | PSAR quá gần fill hoặc `InpMinStopPoints` quá cao | Giảm ngưỡng hoặc đổi `InpStopMode` |
| Không có CSV | Sai `InpLogFile` hoặc tester sandbox khác | Tìm trong `Tester\Agent-*\MQL5\Files` |

### 6. Kết quả chạy thật (2026-10-28)

`XAUUSDm` M15, 2026.01.05–2026.10.01, model "1 minute OHLC", deposit 10,000 USD, build 6249:

| Scenario | hash | Trades | W/L | Net (model) | Max DD | Blocks |
|---|---|---:|---|---:|---:|---|
| `ww_baseline` | `6E969FE1` | 869 | 318/551 | +26.97 | 0.85% | 0 |
| `ww_conservative_stress` | `69086031` | 787 | 276/511 | −7.50 | 0.46% | 139 (134 cooldown, 5 spread) |
| `ww_edge_atr_stop` | `C9EABF3B` | 795 | 390/405 | +24.96 | 0.88% | 0 |

CSV và report archived (gitignored) trong `reports/build/tester-reports/<scenario>/`. Con số theo contract
size 1 của model; không phải lot thật, không phải bằng chứng lợi nhuận, và tester hiển thị 0 deal là đúng.

## Kiểm kê môi trường — Phase 0

- **Ngày kiểm kê:** 2026-10-27
- **Phương pháp:** chỉ đọc thông tin phiên bản, danh sách thư mục và metadata file. Không cài phần mềm,
  không sửa PATH, không mở GUI, không kết nối tài khoản, không đọc nội dung file tài khoản.
- **Máy:** Windows 10.0.19045.6456 (64-bit)

### 1. Bảng kiểm kê

| Hạng mục | Kết quả | Trạng thái |
|---|---|---|
| Windows | 10.0.19045.6456 | PASS (roadmap khuyến nghị Windows 11; xem giới hạn) |
| Python | 3.11.9, cài user-scope (`%LOCALAPPDATA%\Programs\Python\Python311`) | PASS |
| Python launcher | `py -0p` chỉ có 3.11 (mặc định) | PASS |
| pip | 26.1.1 | PASS |
| Git | 2.53.0.windows.3 | PASS |
| Git repository | Ban đầu **không phải** Git repo; đã `git init -b main`, chưa commit | PASS (đã khởi tạo) |
| MT5 terminal | 5.0.0.6249, `C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe` | PASS (hiện diện) |
| MetaEditor | 5.0.0.6249, `C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe` | PASS (hiện diện) |
| MT5 Strategy Tester | `metatester64.exe` 5.0.0.6249 | PASS (hiện diện) |
| MT5 Data Folder | `%APPDATA%\MetaQuotes\Terminal\<terminal-id>` (ID cục bộ, không ghi vào repo) | PASS |
| `MQL5/Experts` | Tồn tại; chỉ có thư mục mặc định (`Advisors`, `Examples`, `Free Robots`) | PASS |
| Python venv | `.venv` tạo bằng Python 3.11.9, cài `requirements.txt` | Xem mục 3 |
| Pytest | Chạy smoke test trong `.venv` | Xem mục 3 |

Ghi chú: thư mục data của terminal chứa `accounts.dat`, `servers.dat`, `config/` và các file phiên.
Phase 0 chỉ liệt kê tên file/thư mục; **không đọc nội dung**, không sao chép vào repository. Các file này
nằm trong `.gitignore` để tránh commit nhầm.

### 2. Những gì chưa được xác minh

| Hạng mục | Lý do | Cách xác minh |
|---|---|---|
| Compile MQL5 | Đã compile Phase 1 bằng CLI: 0 errors, 0 warnings (xem mục 5) | Chạy lại trong MetaEditor GUI nếu cần xác nhận trực quan |
| Strategy Tester chạy EA | **Chưa chạy**; agent không điều khiển GUI | Người dùng: `Ctrl+R`, chọn EA/symbol/timeframe, xem Journal/Experts |
| Dữ liệu lịch sử của terminal | Không kiểm tra/không tải dữ liệu | Phase 1/3: xác nhận symbol và khoảng ngày có sẵn |
| ONNX runtime trong MT5 | Phase 8 chỉ compile EA; runtime **chưa chạy** | Chạy `LabOnnxInference` trong terminal và đối chiếu log với fixture |
| Kết nối broker/tài khoản | **Ngoài phạm vi, không được làm** | Không thực hiện |

### 3. Kết quả thiết lập Python (đã chạy thực tế)

Các lệnh dưới đây chạy trong `.venv` (Python 3.11.9) tại thư mục gốc repository.

| Lệnh | Kết quả thực tế |
|---|---|
| `py -3.11 -m venv .venv` | Tạo thành công |
| `.venv\Scripts\python.exe --version` | `Python 3.11.9` |
| `.venv\Scripts\python.exe -m pip --version` | `pip 24.0` |
| `.venv\Scripts\python.exe -m pip install --upgrade pip` | **Không hoàn tất**: tiến trình quay CPU, không có output sau khoảng 2 phút; đã dừng chủ động. Không ảnh hưởng cài dependency. |
| `.venv\Scripts\python.exe -m pip install -r requirements.txt` | Thành công: numpy 2.4.6, pandas 2.3.3, pyarrow 26.0.0, scikit-learn 1.9.1, matplotlib 3.11.2, PyYAML 6.0.3, pytest 9.1.1 (+ transitive deps) |
| `.venv\Scripts\python.exe -m pytest` | Phase 0: **11 passed**; Phase 3: **38 passed in 1.48s**; Phase 4: **62 passed in 1.67s**; Phase 5: **79 passed in 2.03s** (pytest 9.1.1, rootdir `tm-fx`, config `pyproject.toml`) |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests` | Exit code 0 |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| Import numpy/pandas/sklearn/matplotlib/pytest | Thành công; matplotlib cảnh báo không ghi được cache mặc định `%LOCALAPPDATA%\matplotlib` và tạo cache tạm trong repo |

Chi tiết đầy đủ, bao gồm lệnh và danh sách file: [`phase-reports/phase-0.md`](../phase-reports/phase-0.md).

#### Ghi chú môi trường

- Không chạy `.\.venv\Scripts\Activate.ps1`; các lệnh dùng trực tiếp interpreter trong `.venv` để tránh phụ
  thuộc Execution Policy. Người dùng có thể kích hoạt thủ công nếu PowerShell cho phép.
- Nếu cần dùng matplotlib ở phase sau, đặt cache vào thư mục ghi được, ví dụ trong phiên PowerShell:
  `$env:MPLCONFIGDIR = "$PWD\.venv\matplotlib-cache"`. Không cần thay đổi biến môi trường hệ thống.
  `run_backtest.py` tự dùng thư mục `.mplconfig` trong report dir khi tạo plot.
- Nâng cấp pip chỉ nên thực hiện khi cần; lần thử trong Phase 0 không hoàn tất nên baseline giữ pip 24.0.
- Trong Git Bash của môi trường kiểm thử, `TMP`/`TEMP` trỏ tới `/tmp` không hợp lệ với Python Windows, nên
  `tempfile.gettempdir()` rơi về thư mục hiện tại. Hệ quả: pip/pytest có thể tạo `pip-*`, `pytest-of-*`,
  `tmpsnub_*` ngay trong repo. Các mẫu này đã được thêm vào `.gitignore`; không phải dữ liệu dự án.

### 4. Quy trình xác minh MT5 thủ công (cho Phase 1)

1. Mở MT5. Dùng `File → Open Data Folder` (tên menu có thể khác theo ngôn ngữ/build).
2. Xác nhận data folder mở đúng terminal đang dùng. Không commit đường dẫn tuyệt đối hoặc terminal ID vào repo.
3. Copy/sync EA từ `mt5/Experts/` vào `<Data Folder>/MQL5/Experts/` (thao tác thủ công, không tự động).
4. Mở MetaEditor (`F4`), mở file `.mq5`, compile (`F7`). Ghi lại số warning/error thực tế.
5. Trong MT5, mở Strategy Tester (`Ctrl+R`), chọn EA, symbol, timeframe, khoảng ngày và chế độ visual
   nếu cần. Chạy và đọc tab Journal/Experts.
6. Không chọn tài khoản thật để chạy; chỉ dùng dữ liệu lịch sử/offline theo roadmap.
7. Ghi lại build terminal và kết quả vào báo cáo phase tương ứng.

Không tuyên bố đã compile hoặc backtest thành công nếu chưa thực hiện các bước trên và đọc kết quả thật.

### 5. Kết quả compile Phase 1 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:"...\mt5\Experts\LabSignalEA.mq5" /log:"...\mt5\compile.log"` | Exit code **1**; log: `Result: 0 errors, 0 warnings, 885 ms elapsed, cpu='X64 Regular'`; tạo `LabSignalEA.ex5` (19,574 bytes) |
| Đọc `compile.log` (UTF-16) | Include `..\Include\LabLogger.mqh` resolve đúng; không có error/warning |

MetaEditor CLI trong môi trường này trả exit code 1 dù biên dịch thành công. Quy tắc: luôn đọc nội dung
log, không kết luận chỉ từ exit code. Strategy Tester **chưa chạy**; quy trình thủ công ở mục 4 và
`mt5/README.md`. Chi tiết Phase 1: [`phase-reports/phase-1.md`](../phase-reports/phase-1.md).

### 6. Kết quả Python Phase 3 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install pyarrow` | Cài `pyarrow 26.0.0`; đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe -m pytest` | **38 passed in 1.48s** |
| `.venv\Scripts\python.exe scripts\validate_dataset.py python\tests\fixtures\synthetic_eurusd_m5.csv --symbol EURUSD --timeframe M5 --data-kind synthetic --out-dir reports\validation` | Exit code **0**; 6 rows, 0 errors, 1 warning (`synthetic_dataset`); ghi JSON + CSV thật |
| CLI trên file có timestamp trùng | Exit code **2**; 1 error (`duplicate_timestamps`); ghi JSON + CSV |

`pyarrow` cần cho Parquet; nếu môi trường khác thiếu package này, loader báo lỗi rõ và test Parquet
được skip. Chi tiết: [`phase-reports/phase-3.md`](../phase-reports/phase-3.md).

### 7. Kết quả Python Phase 4 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install --no-cache-dir PyYAML==6.0.3` | Cài `PyYAML 6.0.3`; đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe -m pytest -q` | **62 passed in 1.67s** |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code **0**; 8 bar, 1 trade, final equity 10,294.60, net profit 294.60; artifact JSON/CSV thật |
| CLI trên dataset có timestamp trùng | Exit code **2**; `status=invalid_data`, lỗi `duplicate_timestamps`; vẫn ghi validation report |
| CLI với config thiếu `strategy` | Exit code **1**; `config_error: config.strategy is required` |
| CLI với `outputs.plot: true` | Exit code **0**; tạo `equity.png` |

Artifact mẫu nằm ở `reports/backtests/demo-ema-cross-synthetic/` (gitignored). Chi tiết giả định mô phỏng:
[`testing-guide.md`](../reference/testing.md); báo cáo phase: [`phase-reports/phase-4.md`](../phase-reports/phase-4.md).

### 8. Kết quả Phase 5 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `MetaEditor64.exe /compile:...\LabSignalEngineTests.mq5` | Log: 0 errors, 0 warnings, 872 ms; `.ex5` 18,504 bytes; exit code 1 (hành vi CLI đã biết) |
| `MetaEditor64.exe /compile:...\LabSignalExport.mq5` | Log: 0 errors, 0 warnings, 959 ms; `.ex5` 22,906 bytes; exit code 1 |
| `.venv\Scripts\python.exe -m pytest -q` | **79 passed in 2.03s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `.venv\Scripts\python.exe scripts\export_python_signals.py` | Exit code **0**; 12 dòng: 1 BUY, 1 SELL, 7 HOLD, 3 UNKNOWN; ghi `reports/parity/parity_signals_python.csv` |
| `.venv\Scripts\python.exe scripts\compare_signals.py --mql5 reports\parity\parity_signals_python.csv --python reports\parity\parity_signals_python.csv --out-dir reports\parity\self_check` | Exit code **0**; 12/12 hàng, 0 mismatch; đây là self-comparison, không phải parity MQL5/Python |
| Comparator với bản copy bị sửa ở một numeric, một signal và một reason | Exit code **1**; 3 mismatch được liệt kê theo timestamp/field trong JSON + CSV |

`LabSignalExport.mq5` **chưa được chạy** trong terminal; chỉ compile. Không có file
`parity_signals_mql5.csv` thật trong repo. Vì vậy chưa có kết luận tương đương MQL5/Python. Quy trình thủ
công: [`parity.md`](../reference/parity.md); báo cáo phase: [`phase-reports/phase-5.md`](../phase-reports/phase-5.md).

### 9. Kết quả Phase 6 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **119 passed in 3.71s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| `scripts\run_backtest.py --config configs\backtest.example.yaml --out-dir reports\backtests\phase6-nostore-check` | Exit code **0**; 8 bar, 1 trade, final equity 10,294.60; layout cũ, không tạo DB |
| `scripts\run_backtest.py ... --store --db experiments\phase6-demo.sqlite --experiment-id phase6-demo-a` | Exit code **0**; row `completed`; artifact trong `reports\backtests\phase6-demo\phase6-demo-a` |
| Chạy lại cùng ID `phase6-demo-a` | Exit code **4**; `duplicate_experiment`; row và summary cũ không đổi |
| Run `phase6-demo-b` cùng config | Exit code **0**; cùng config hash `bcdcefd7…` và data fingerprint `10c84c2e…` |
| `scripts\compare_experiments.py --baseline phase6-demo-a --run phase6-demo-b` | Exit code **0**; `comparable`, delta bằng 0 cho mọi metric; 3 warning: dirty worktree ×2, synthetic data |
| Run `phase6-demo-alt` với commission 5.0 mỗi chiều | Exit code **0**; final equity 10,289.60; config hash `4486451d…` khác baseline |
| `scripts\compare_experiments.py --baseline phase6-demo-a --run phase6-demo-alt` | Exit code **1**; `not_comparable`, reason `config_hash_mismatch`; báo cáo vẫn được ghi |
| `scripts\run_backtest.py` với dataset timestamp trùng, `--store` | Exit code **2**; row `invalid_data`; artifact summary + validation JSON/CSV |
| `scripts\run_backtest.py` với dataset không tồn tại, `--store` | Exit code **1**; row `failed`, `data_fingerprint=null`, error `load_error: ...` |

Database demo: `experiments/phase6-demo.sqlite` (gitignored). Report so sánh:
`reports/comparisons/phase6-demo-a__vs__phase6-demo-b/` và
`reports/comparisons/phase6-demo-a__vs__phase6-demo-alt/` (gitignored). Mọi kết quả là synthetic và
worktree đang dirty, nên so sánh chỉ xác nhận cơ chế tái lập/metadata, không phải bằng chứng hiệu năng.
Chi tiết: [`experiment-store.md`](../reference/experiment-store.md); báo cáo phase:
[`phase-reports/phase-6.md`](../phase-reports/phase-6.md).

### 10. Kết quả Phase 7 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe scripts\generate_synthetic_ml_dataset.py` | Exit code **0**; 1.800 nến M5 EURUSD synthetic, seed 20261027 |
| `.venv\Scripts\python.exe scripts\train_ml_baseline.py --config configs\ml_baseline.example.yaml` | Exit code **0**; threshold 0.50; test ROC-AUC 0.5708, balanced accuracy 0.5584; ML lỗ -151.60 sau chi phí |
| `scripts\train_ml_baseline.py ... --store --db experiments\phase7-demo.sqlite --experiment-id phase7-demo-store` | Exit code **0**; row `completed`; 10 artifact có hash |
| Chạy lại cùng ID `phase7-demo-store` | Exit code **4**; `duplicate_experiment`; row/artifact cũ không đổi |
| `.venv\Scripts\python.exe -m pytest -q` | **143 passed in 8.55s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code **0** |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

`scikit-learn 1.9.1`, `numpy 2.4.6`, `pandas 2.3.3` đã có và được pin từ Phase 0; Phase 7 không cài
thêm dependency. Dataset/report ML nằm ở `datasets/samples/synthetic_ml_demo.csv` và
`reports/ml/demo-phase7-ml/` (report bị gitignore). Kết quả synthetic yếu, chiến lược ML lỗ sau chi phí
và kém buy & hold; không phải kết quả thị trường. Chi tiết: [`ml-baseline.md`](../reference/ml-baseline.md); báo cáo
phase: [`phase-reports/phase-7.md`](../phase-reports/phase-7.md).

Kết quả ONNX và giới hạn runtime MT5 được ghi ở mục 11.

### 11. Kết quả Phase 8 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pip install onnx==1.23.2 onnxruntime==1.31.1` | Cài trong venv: `onnx 1.23.2`, `onnxruntime 1.31.1` (+ protobuf 7.36.2, ml_dtypes 0.6.0, flatbuffers 25.12.19, typing_extensions 4.16.0); đã pin trong `requirements.txt` |
| `.venv\Scripts\python.exe scripts\export_onnx_model.py --model reports\ml\demo-phase7-ml\model.json --out-dir models\candidates\demo-phase7-ml --fixture python\tests\fixtures\onnx_feature_fixture.csv` | Exit code **0**; `model.onnx` 566 bytes, SHA-256 `a7ae4a25…64f9d3`; opset 13, IR 8; 24 hàng parity, max abs diff `4.673e-08`, mean `1.953e-08`, tolerance `1e-5` → PASS |
| `MetaEditor64.exe /compile:...\mt5\Experts\LabOnnxInference.mq5 /log:...\mt5\onnx.compile.log` | Log: **0 errors, 0 warnings**, 700 ms; `.ex5` 12,284 bytes; exit code 1 (hành vi CLI đã biết) |
| `.venv\Scripts\python.exe -m pytest -q` | **150 passed in 8.76s** |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

`onnx`/`onnxruntime` chỉ dùng cho export và kiểm chứng offline trong venv; không cài system-wide.
Artifact ONNX nằm ở `models/candidates/demo-phase7-ml/` (gitignored). EA **chưa chạy** trong MT5
terminal/Strategy Tester, nên ONNX Runtime trong MT5 và parity runtime vẫn chưa được xác minh; Phase 8
giữ `READY_FOR_MANUAL_VALIDATION`. Quy trình thủ công: [`onnx-inference.md`](../reference/onnx.md); báo cáo
phase: [`phase-reports/phase-8.md`](../phase-reports/phase-8.md).

### 12. Kết quả Phase 9 (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml` | Exit code **0**; backtest 1.800 bar, 49 trade, net +241,80; ML 299 test sample, ROC-AUC 0,5708, balanced accuracy 0,5584, ML net -151,60; báo cáo `reports\pipeline\demo-phase9\pipeline_report.md` |
| `.venv\Scripts\python.exe scripts\run_pipeline.py --config configs\pipeline.example.yaml --run-id demo-phase9-b` | Exit code **0**; metric backtest/ML, data SHA-256 và `model_sha256` khớp lần chạy đầu |
| Chạy lại `demo-phase9` | Exit code **4**; báo cáo cũ không đổi |
| `scripts\export_onnx_model.py --model ...\missing-model.json` | Exit code **1**; `input_error: model artifact not found`; không tạo artifact |
| `.venv\Scripts\python.exe -m pytest -q` | **155 passed in 11.28s** |
| Snapshot commit sạch: `pytest -q` | **155 passed in 12.69s** |
| Snapshot commit sạch: `run_pipeline.py --run-id clean-check` | Exit `0`; metric backtest/ML, data SHA-256 và `model_sha256` khớp `demo-phase9`; chạy lại exit `4` |
| Snapshot commit sạch: export ONNX từ model mới | Exit `0`; parity 24/24 PASS, max abs diff `4.673e-08`; ONNX SHA `a7ae4a25…64f9d3` |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

Database demo: `experiments/phase9-demo.sqlite` (gitignored), hai row `demo-phase9-backtest` và
`demo-phase9-ml` ở trạng thái `completed`. Report và database bị gitignore; bản sao báo cáo đã lược
đường dẫn nằm ở [`phase-reports/phase-9-sample-report.md`](../phase-reports/phase-9-sample-report.md).
Tái lập đã xác minh trên snapshot commit sạch tạm thời (116 file, commit `d3a9ea39…`, `git status`
rỗng); cần lặp lại ngắn sau commit chính thức để gắn với commit hash repository. Chi tiết:
[`end-to-end.md`](../reference/pipeline.md); báo cáo phase: [`phase-reports/phase-9.md`](../phase-reports/phase-9.md).

### 13. Kết quả trailing stop (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **170 passed in 15.13s** |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.trailing-synthetic.yaml` | Exit code **0**; 1.800 bar, 54 trade, 13 `trailing_stop`, 41 `opposite_signal`, final equity 10.175,60, net +175,60, max drawdown 251,40 |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code **0**; baseline không trailing giữ nguyên: 8 bar, 1 trade, net +294,60 |

Dữ liệu là synthetic; kết quả chỉ kiểm tra cơ chế, không phải hiệu năng thị trường. Chi tiết quy tắc và
giới hạn: [`trailing-stop.md`](../reference/trailing-stop.md).

### 14. Kết quả bounded DCA/grid (đã chạy thực tế)

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **198 passed in 11.26s** |
| `.venv\Scripts\python.exe scripts\run_basket_backtest.py --config configs\backtest.bounded-basket-synthetic.yaml` | Exit code **0**; 1.800 bar, 57 basket, 70 layer, final equity 9.858,43, net **-141,57**, max drawdown 145,39, exposure 0,6372, profit factor 0,1243, win rate 0,2857; exit 19 `basket_take_profit` / 38 `opposite_signal`; max layer 4/4, units 4.000/4.000, 15 `blocked_add_bars`, 1 basket chạm cap layer, lỗ basket tệ nhất 28,14, overshoot 0 |
| `.venv\Scripts\python.exe scripts\run_basket_backtest.py --config configs\backtest.bounded-grid-synthetic.yaml` | Exit code **0**; 1.800 bar, 60 basket, 83 layer, final equity 9.860,46, net **-139,54**, max drawdown 150,94, exposure 0,5161, profit factor 0,3761, win rate 0,3373; exit 2 `basket_loss_cap` / 25 `basket_take_profit` / 33 `opposite_signal`; max layer 3/3, units 6.000/6.000, 0 `blocked_add_bars`, 4 basket chạm cap layer, lỗ basket tệ nhất 20,000000000001123 với cap 20, overshoot 0 |
| `.venv\Scripts\python.exe scripts\run_backtest.py --config configs\backtest.example.yaml` | Exit code **0**; baseline không đổi: 8 bar, 1 trade, final equity 10.294,60, net +294,60 |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests scripts` | Exit code `0` |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |

Dữ liệu là synthetic; cả hai demo đều lỗ sau chi phí, chỉ kiểm tra cơ chế layer/cap chứ không phải hiệu
năng thị trường. Loss cap là lỗ ròng; demo grid cho thấy cap 20 giữ được lỗ thực tế ở mức 20,000000000001123
và `loss_cap_overshoot = 0`. Report nằm trong `reports/backtests/demo-bounded-dca-synthetic/` và
`reports/backtests/demo-bounded-grid-synthetic/` (gitignored). Chi tiết quy tắc, công thức và giới hạn:
[`bounded-basket.md`](../reference/bounded-basket.md).

### 15. Đồng bộ và compile trong MT5 EXNESS (2026-10-28)

- Data Folder: `%APPDATA%\MetaQuotes\Terminal\<terminal-id>\MQL5` (một terminal duy nhất có thư mục
  `MQL5` trên máy kiểm thử; ID cục bộ không ghi vào repo).
- Đã copy một lần theo yêu cầu người dùng: source `.mq5`, include `.mqh`, fixture ONNX và `model.onnx`
  vào `MQL5\Files`; `parity_ema_cross.csv` vào `Terminal\Common\Files` cho `LabSignalExport`. Không có
  script tự động hóa trong repo (ADR 0001); mọi lần sync sau vẫn thủ công.
- Compile bằng MetaEditor64 CLI: `LabSignalEA.mq5`, `LabOnnxInference.mq5`,
  `LabSignalEngineTests.mq5`, `LabSignalExport.mq5` → **0 errors, 0 warnings** cho cả bốn file; CLI trả
  exit `1` như hành vi đã biết. `.ex5` đã sinh trong Data Folder.
- **Chưa** đăng nhập tài khoản, chưa chạy script, chưa chạy Strategy Tester và chưa xác minh ONNX runtime;
  các bước thủ công tiếp theo ở `guide.md`.
- Không bật execution: `LabSignalEA` là signal-only, 0 trade là đúng; ranh giới này ghi ở
  [`decisions/0002-execution-boundary.md`](../decisions/0002-execution-boundary.md).
- Log compile nằm ở `reports/mt5/*.compile.log` (gitignored).

## Track C — PATrendRider XAU v1 (simulation-only)

- **Đối tượng:** `PATrendRiderXAUv1SimEA`, `TrendRiderContractTests`, preset
  `configs/sim/pa_trendrider_xau.json`, include `mt5/Include/TrendRider/*.mqh`.
- **Nguyên tắc:** EA phân tích nến đóng H1/M15/M5, mở **một vị thế ảo** trong bộ nhớ và ghi CSV; không
  gửi lệnh, không đọc tài khoản/broker, không lưu credential.
- **Đặc tả & báo cáo:** [`../PA_TrendRider_XAU_V1_Specification_Vietnamese.md`](../PA_TrendRider_XAU_V1_Specification_Vietnamese.md)
  và [`../PA_TrendRider_XAU_V1_Implementation_Vietnamese.md`](../PA_TrendRider_XAU_V1_Implementation_Vietnamese.md).

### 1. Kiểm tra tĩnh và compile

```powershell
.\.venv\Scripts\python.exe scripts\validate_trendrider.py
.\.venv\Scripts\python.exe scripts\validate_sim_configs.py
powershell -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\PATrendRider*"
```

### 2. Contract suite (bắt buộc trước khi tin EA)

1. Copy `mt5/Include/TrendRider/*.mqh` vào `MQL5\Include\TrendRider` trong Data Folder.
2. Tạo wrapper EA tạm từ `mt5/Scripts/TrendRiderContractTests.mq5` (đổi `OnStart` thành `OnTick` một
   lần, giữ `RunAllTests`), compile 0/0.
3. Chạy Strategy Tester XAUUSDm M1, 2026.01.05–2026.01.06; đọc tab Journal/Experts.
4. Kỳ vọng: `TEST|RESULT|ALL_PASS|pass=82 fail=0|suite=trendrider`.

Bằng chứng đã lưu: `reports/build/tester-reports/contract_trendrider/`.

### 3. Chạy EA headless

```powershell
python reports\build\tester-run\gen_trendrider_sets.py
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" `
  "/config:D:\Applications\tm-fx\reports\build\tester-run\pa_trendrider_baseline.ini"
```

- File `.set`/`.ini` sinh từ preset + override scenario; `InpResetStateOnInit=true` để mỗi lượt bắt đầu
  sạch (không đọc state cũ).
- Agent tester **xóa sandbox `MQL5\Files` ở đầu mỗi lượt chạy**. Copy CSV + state + report ra
  `reports/build/tester-reports/<scenario>/` ngay sau khi terminal thoát, trước khi chạy scenario kế.
- Report tester hiển thị **0 deal** là đúng; chỉ CSV mô phỏng có ENTRY/EXIT/SUMMARY.

### 4. Kiểm tra CSV tối thiểu

- 18 cột, đúng một `INIT` và một `SUMMARY`, `config_hash` không đổi.
- ENTRY/EXIT khớp cặp; BUY có `sl < entry`, SELL có `sl > entry`; `tp = 0`.
- Mọi dòng `TRAIL` chỉ siết SL (BUY tăng, SELL giảm).
- Tổng volume mỗi lệnh ≤ `InpMaxVirtualExposure`; không có entry khi state không phải
  `WAITING_FOR_SETUP`.
- Không có `OrderSend`/deal trong tester; nếu có, dừng ngay và điều tra.

### 5. Trạng thái runtime đã xác minh (2026-10-28)

| Hạng mục | Kết quả |
|---|---|
| Contract suite | **82/82 PASS** |
| Baseline `pa_trendrider_baseline` | 13 entry/13 exit, 2 thắng/11 thua, net mô phỏng −140.46, DD 1.75% |
| Cost stress `pa_trendrider_cost_stress` | 4 entry/4 exit, 0 thắng, net mô phỏng −37.28, DD 0.94% |
| Tester report | 0 deal (đúng thiết kế simulation-only) |

Không suy ra lợi nhuận hay độ sẵn sàng live từ hai lượt chạy ngắn này.
