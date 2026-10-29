# MT5 — Signal-only EA

Thư mục này chứa mã MQL5 của lab. **Không có lệnh giao dịch, không có kết nối tài khoản, không lưu
thông tin đăng nhập.** EA signal-only chỉ đọc dữ liệu nến và ghi log có cấu trúc; EA ONNX chỉ đọc fixture
và model để kiểm tra suy luận, không tạo tín hiệu giao dịch.

## 1. Cấu trúc và ánh xạ sang thư mục MQL5

Repo giữ mã nguồn tách khỏi data folder của terminal. Khi muốn chạy trong MT5, sync thủ công:

| Trong repo | Đích trong data folder |
|---|---|
| `mt5/Experts/LabSignalEA.mq5` | `<Data Folder>/MQL5/Experts/LabSignalEA.mq5` |
| `mt5/Include/LabLogger.mqh` | `<Data Folder>/MQL5/Include/LabLogger.mqh` |
| `mt5/Include/Indicators.mqh` | `<Data Folder>/MQL5/Include/Indicators.mqh` |
| `mt5/Include/SignalEngine.mqh` | `<Data Folder>/MQL5/Include/SignalEngine.mqh` |
| `mt5/Scripts/LabSignalEngineTests.mq5` | `<Data Folder>/MQL5/Scripts/LabSignalEngineTests.mq5` |
| `mt5/Scripts/LabSignalExport.mq5` | `<Data Folder>/MQL5/Scripts/LabSignalExport.mq5` |
| `mt5/Experts/LabOnnxInference.mq5` | `<Data Folder>/MQL5/Experts/LabOnnxInference.mq5` |
| `mt5/Files/onnx_feature_fixture.csv` | `<Data Folder>/MQL5/Files/onnx_feature_fixture.csv` |
| `models/candidates/demo-phase7-ml/model.onnx` | `<Data Folder>/MQL5/Files/model.onnx` |
| `mt5/Include/PinePort/WonderwhalesContract.mqh` | `<Data Folder>/MQL5/Include/PinePort/WonderwhalesContract.mqh` |
| `mt5/Indicators/PinePort/Wonderwhales.mq5` | `<Data Folder>/MQL5/Indicators/PinePort/Wonderwhales.mq5` |
| `mt5/Experts/PineSignalLabEA.mq5` | `<Data Folder>/MQL5/Experts/PineSignalLabEA.mq5` |
| `mt5/Scripts/WonderwhalesContractTests.mq5` | `<Data Folder>/MQL5/Scripts/WonderwhalesContractTests.mq5` |
| `mt5/Include/PinePort/LongKacoVSAContract.mqh` | `<Data Folder>/MQL5/Include/PinePort/LongKacoVSAContract.mqh` |
| `mt5/Indicators/PinePort/LongKacoVSA.mq5` | `<Data Folder>/MQL5/Indicators/PinePort/LongKacoVSA.mq5` |
| `mt5/Scripts/LongKacoVSAContractTests.mq5` | `<Data Folder>/MQL5/Scripts/LongKacoVSAContractTests.mq5` |
| `mt5/Include/PinePort/TMFusionZonesContract.mqh` | `<Data Folder>/MQL5/Include/PinePort/TMFusionZonesContract.mqh` |
| `mt5/Indicators/PinePort/TMFusionZones.mq5` | `<Data Folder>/MQL5/Indicators/PinePort/TMFusionZones.mq5` |
| `mt5/Scripts/TMFusionZonesContractTests.mq5` | `<Data Folder>/MQL5/Scripts/TMFusionZonesContractTests.mq5` |
| `mt5/Include/PinePort/PriceActionMTFContract.mqh` | `<Data Folder>/MQL5/Include/PinePort/PriceActionMTFContract.mqh` |
| `mt5/Indicators/PinePort/PriceActionMTF.mq5` | `<Data Folder>/MQL5/Indicators/PinePort/PriceActionMTF.mq5` |
| `mt5/Scripts/PriceActionMTFContractTests.mq5` | `<Data Folder>/MQL5/Scripts/PriceActionMTFContractTests.mq5` |
| `mt5/Include/PinePort/TMXAUSignals2Contract.mqh` | `<Data Folder>/MQL5/Include/PinePort/TMXAUSignals2Contract.mqh` |
| `mt5/Indicators/PinePort/TMXAUSignals2.mq5` | `<Data Folder>/MQL5/Indicators/PinePort/TMXAUSignals2.mq5` |
| `mt5/Scripts/TMXAUSignals2ContractTests.mq5` | `<Data Folder>/MQL5/Scripts/TMXAUSignals2ContractTests.mq5` |

EA và test script include bằng đường dẫn tương đối (`../Include/...`), nên **phải giữ nguyên cấu trúc
thư mục** `Experts/`, `Scripts/` và `Include/` khi copy.

Không copy/dùng `accounts.dat`, `servers.dat`, `origin.txt` hay bất kỳ file phiên nào vào repo.

## 2. Compile

### Trong MetaEditor (thủ công)

1. Mở MetaEditor (`F4` từ MT5, hoặc `MetaEditor64.exe`).
2. Mở `LabSignalEA.mq5` trong `MQL5/Experts/`.
3. `F7` để compile. Đọc tab **Errors** và **Warnings**.

### Bằng CLI (đã chạy trong quá trình phát triển)

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Experts\LabSignalEA.mq5" `
  /log:"D:\Applications\tm-fx\mt5\compile.log"
```

Kết quả thực tế ngày 2026-10-27 (build 5.0.0.6249):

| File | Log | Exit code | `.ex5` |
|---|---|---|---|
| `LabSignalEA.mq5` (Phase 1) | 0 errors, 0 warnings | 1 | 19,574 bytes |
| `LabSignalEA.mq5` (Phase 2) | 0 errors, 0 warnings, 982 ms | 1 | 26,566 bytes |
| `LabSignalEngineTests.mq5` (Phase 2) | 0 errors, 0 warnings, 941 ms | 1 | 18,122 bytes |
| `LabSignalEngineTests.mq5` (Phase 5, fixture 4-bar) | 0 errors, 0 warnings, 872 ms | 1 | 18,504 bytes |
| `LabSignalExport.mq5` (Phase 5) | 0 errors, 0 warnings, 959 ms | 1 | 22,906 bytes |
| `LabOnnxInference.mq5` (Phase 8) | 0 errors, 0 warnings, 700 ms | 1 | 12,284 bytes |

Tiến trình MetaEditor trả **exit code 1** dù log báo thành công. Đây là hành vi của CLI trong môi
trường này, không phải lỗi biên dịch; luôn đọc nội dung log thay vì chỉ tin exit code.

`compile.log` và `.ex5` là artifact, đã nằm trong `.gitignore`, không commit.

## 3. Định dạng log

Mỗi sự kiện là một dòng:

```
LAB|<server time>|<LEVEL>|<context>|event=<name> key=value ...
```

Ví dụ:

```
LAB|2026.10.27 21:00:00|INFO|LabSignalEA|event=init symbol=EURUSD timeframe=M5 digits=5 point=1e-05 tick_size=1e-05 bars=10000 tester=1 build=6249
LAB|2026.10.27 21:00:00|INFO|LabSignalEA|event=signal_config fast_period=8 slow_period=21 allow_long=1 allow_short=1 warmup_bars=22
LAB|2026.10.27 21:00:00|INFO|LabSignalEA|event=init_ok last_bar_open=2026.10.27 20:55 server_time=2026.10.27 21:00:00 utc_time=2026.10.27 18:00:00
LAB|2026.10.27 21:00:00|INFO|LabSignalEA|event=new_bar symbol=EURUSD timeframe=M5 bar_open=2026.10.27 20:50 open=1.08500 high=1.08540 low=1.08480 close=1.08520 tick_volume=123 spread_points=12 real_volume=0 bars=10001
LAB|2026.10.27 21:00:00|INFO|LabSignalEA|event=signal signal=HOLD reason=NO_CROSS symbol=EURUSD timeframe=M5 bar_open=2026.10.27 20:50 fast_prev=1.08510 slow_prev=1.08505 fast=1.08518 slow=1.08509 history=22
LAB|2026.10.27 21:05:00|INFO|LabSignalEA|event=deinit reason=1 reason_name=program ticks=57 closed_bars=1 invalid_bars=0
```

Các event hiện có:

| Event | Level | Ý nghĩa |
|---|---|---|
| `init` | INFO | Thông tin symbol/timeframe/digits/point/tick_size/bars/tester/build |
| `init_ok` | INFO | Đã đọc được nến hiện tại; log thời gian bar/server/UTC |
| `history_unavailable` | WARN | `Bars()` trả 0; EA chờ history thay vì fail |
| `copy_time_failed` | ERROR/WARN | `CopyTime` thất bại (init = ERROR, tick = WARN, chỉ log một lần) |
| `copy_rates_failed` | WARN | `CopyRates` trả < 2 nến; throttle theo bar hiện tại |
| `closed_bar_not_found` | WARN | Không tìm thấy nến cũ hơn bar hiện tại trong cửa sổ đã copy |
| `bar_invalid` | ERROR | OHLC không hợp lệ (NaN/Inf/≤0 hoặc high/low mâu thuẫn) |
| `new_bar` | INFO | Một nến vừa đóng; log OHLC, tick_volume, spread_points, real_volume |
| `signal_config` | INFO | Cấu hình EMA crossover và số nến warm-up |
| `signal` | INFO/WARN | Quyết định `BUY`/`SELL`/`HOLD`/`UNKNOWN`, reason code, EMA prev/now, history |
| `invalid_config` | ERROR | `fast_period >= slow_period` hoặc period `<= 0`; EA dừng init |
| `signal_skipped` | ERROR | Không cấp phát được mảng giá (hiếm) |
| `deinit` | INFO | Lý do deinit, tổng tick/nến đã log/nến invalid |

`event=tick` (DEBUG) chỉ xuất hiện khi input `InpLogEveryTick = true`.

Quy tắc tín hiệu, warm-up và reason code: [`docs/reference/strategy-signal-spec.md`](../docs/reference/strategy-signal-spec.md).

## 4. Input

| Input | Mặc định | Mô tả |
|---|---|---|
| `InpLogEveryTick` | `false` | Bật log DEBUG bid/ask mỗi tick (rất nhiễu, chỉ dùng khi debug) |
| `InpValidateClosedBar` | `true` | Kiểm tra OHLC của nến vừa đóng trước khi log |
| `InpFastPeriod` | `8` | Chu kỳ EMA nhanh; phải nhỏ hơn `InpSlowPeriod` |
| `InpSlowPeriod` | `21` | Chu kỳ EMA chậm; warm-up cần `slow + 1` nến đóng |
| `InpAllowLong` | `true` | Cho phép tín hiệu BUY |
| `InpAllowShort` | `true` | Cho phép tín hiệu SELL |

## 5. Chạy Strategy Tester (thủ công)

Agent không tự mở GUI Strategy Tester vì terminal có thể kết nối tài khoản broker. Các bước do người
dùng thực hiện:

1. Mở MT5, `Ctrl+R` để mở Strategy Tester.
2. Chọn Expert `LabSignalEA`, symbol (ví dụ `EURUSD`), timeframe `M5`.
3. Chọn khoảng ngày có dữ liệu lịch sử; ưu tiên chế độ không cần kết nối broker.
4. Chạy và đọc tab **Journal** và **Experts**. Log có prefix `LAB|`.
5. Xác nhận: có `event=init`, `event=init_ok`; khi sang nến mới có `event=new_bar`; khi dừng có
   `event=deinit`.
6. Ghi lại build terminal, symbol, timeframe, khoảng ngày và kết quả thật vào báo cáo phase.

**Đã có kết quả Strategy Tester thật (2026-10-29, build 6292):** `XAUUSDm` M5, 2026.09.01–2026.10.28,
model 1-minute OHLC, deposit 5 000 USD → 225 340 ticks, 11 285 bars, `BUY_OK=219`, `SELL_OK=212`,
`HOLD_NO_CROSS=10 854`, **0 trade**, balance cuối `5000.00 USD`. Chạy headless bằng
`reports/build/tester-run/lab_signal_ea_m5.ini` (file này bị gitignore) và lưu report ở
`reports/build/tester-reports/lab_signal_ea_m5/`. Trạng thái Phase 1: **PASS cho signal-only**.

### Chạy self-check của signal engine

1. Sync `mt5/Scripts/LabSignalEngineTests.mq5` vào `<Data Folder>/MQL5/Scripts/` cùng các file trong
   `MQL5/Include/`.
2. Compile trong MetaEditor (`F7`), xác nhận 0 errors/0 warnings.
3. Kéo script vào một chart bất kỳ và chọn OK. Script chạy một lần, không giao dịch.
4. Đọc tab **Experts**: kỳ vọng `TEST|RESULT|ALL_PASS` và `fail=0`.
5. Ghi kết quả thật (pass/fail) vào báo cáo Phase 2.

Script đã chạy thật ngày 2026-10-29 trên `XAUUSDm,H1`, build 6292: `TEST|SUMMARY|pass=53 fail=0` rồi
`TEST|RESULT|ALL_PASS` (log `MQL5\Logs\20261029.log`, 14:28:37).

## 6. Export tín hiệu cho parity (thủ công)

`LabSignalExport.mq5` đọc một CSV fixture từ `Common\Files`, đánh giá lại baseline EMA crossover cho từng
bar và ghi CSV để so sánh với Python. Script không đọc dữ liệu thị trường, không truy cập tài khoản và
không giao dịch.

| Input | Mặc định | Mô tả |
|---|---|---|
| `InpInputFile` | `parity_ema_cross.csv` | CSV trong `Common\Files`; cần cột `timestamp,symbol,timeframe,close` |
| `InpOutputFile` | `parity_signals_mql5.csv` | CSV output trong `Common\Files` |
| `InpFastPeriod` | `2` | Fast EMA period |
| `InpSlowPeriod` | `3` | Slow EMA period |
| `InpAllowLong` | `true` | Cho phép BUY |
| `InpAllowShort` | `true` | Cho phép SELL |

Quy trình:

1. Sync file `.mq5`/`.mqh` và compile như mục 2.
2. Copy `datasets/samples/parity_ema_cross.csv` vào
   `%APPDATA%\MetaQuotes\Terminal\Common\Files\parity_ema_cross.csv`.
3. Kéo `LabSignalExport` vào một chart bất kỳ, giữ input mặc định, chọn OK.
4. Đọc **Experts**: kỳ vọng `event=export_done rows=12 buy=1 sell=1 hold=7 unknown=3 ...`.
5. Copy `parity_signals_mql5.csv` về `reports\parity\` và chạy
   `scripts\compare_signals.py` theo [`docs/reference/parity.md`](../docs/reference/parity.md).

Script **chưa được chạy** trong terminal; chỉ mới compile. Vì vậy chưa có kết luận parity MQL5/Python.
Script từ chối file có ít hơn `slow_period + 1` dòng. CSV parser chỉ hỗ trợ file phân tách bằng dấu phẩy,
không có dấu phẩy trong field, header bắt buộc.

## 7. ONNX inference harness (thủ công)

`LabOnnxInference.mq5` chỉ kiểm tra `OnnxCreate`/`OnnxSetInputShape`/`OnnxRun` trên một fixture cố định.
EA **không** lấy dữ liệu thị trường, **không** tạo tín hiệu và **không** giao dịch; `OnTick()` rỗng.

| Input | Mặc định | Mô tả |
|---|---|---|
| `InpModelFile` | `model.onnx` | File trong `MQL5/Files` |
| `InpFeatureFile` | `onnx_feature_fixture.csv` | CSV 12 feature trong `MQL5/Files` |
| `InpFeatureCount` | `12` | Phải khớp model; sai sẽ fail init |
| `InpMaxRows` | `0` | `0` = đọc hết fixture |

Quy trình:

1. Export model bằng `scripts\export_onnx_model.py` (xem [`docs/reference/onnx.md`](../docs/reference/onnx.md)).
2. Copy `models/candidates/demo-phase7-ml/model.onnx` và `mt5/Files/onnx_feature_fixture.csv` vào
   `<Data Folder>/MQL5/Files/`.
3. Sync `mt5/Experts/LabOnnxInference.mq5` vào `<Data Folder>/MQL5/Experts/` và compile (`F7`).
4. Kéo EA vào một chart bất kỳ, chọn OK. Không cần chọn account/execution.
5. Đọc **Experts**: mỗi hàng in `onnx_row=<n> probability=<p>`; so sánh với `expected_probability` trong
   `python/tests/fixtures/onnx_feature_fixture.csv`, tolerance `1e-5`.
6. Nếu `OnnxCreate`/`OnnxSetInputShape`/`OnnxRun` lỗi, ghi mã lỗi + build terminal; **không** kết luận
   tương thích và không tạo workaround chưa xác minh.

EA **chưa được chạy** trong terminal; chỉ compile 0 errors/0 warnings. Vì vậy Phase 8 giữ
`READY_FOR_MANUAL_VALIDATION`.

## 8. An toàn và giới hạn

- Không có `OrderSend`, `OrderSendAsync`, `OrderModify`, `OrderDelete`, `PositionOpen`, `PositionClose`,
  `CTrade`, `CExpert` hay bất kỳ API execution nào.
- Không gọi `AccountInfo*`, không đăng nhập, không lưu credential.
- `LabSignalEA` và `LabSignalEngineTests` chỉ ghi journal. `LabSignalExport` chỉ đọc/ghi CSV trong
  `Common\Files`; không đọc dữ liệu thị trường và không ghi file ngoài thư mục đó.
- `LabOnnxInference` chỉ đọc `model.onnx` + fixture trong `MQL5\Files`, ghi journal; không ghi file, không
  đọc dữ liệu thị trường, không tạo tín hiệu.
- EA fail-closed với dữ liệu: nến không hợp lệ bị log `bar_invalid` và không được coi là tín hiệu.
- `CopyRates` có thể trả mảng theo thứ tự bất kỳ; EA chọn nến cũ hơn bar hiện tại lớn nhất thay vì giả
  định index.
- Chưa xử lý trường hợp symbol bị đổi giữa chừng hoặc history bị reload; các trường hợp này sẽ được
  xem xét ở phase sau nếu cần.

## 9. PinePort — Wonderwhales (signal-only)

Port từ Pine `Wonderwhales` sang MQL5, giữ đúng logic tín hiệu trên nến đã đóng. **Không port execution**
(entry/exit/SL/TP/ladder/reversal) và **không gửi lệnh**.

| Thành phần | Vai trò |
|---|---|
| `Include/PinePort/WonderwhalesContract.mqh` | Contract `1.0.0`: enum mode/buffer, pure helper, FNV-1a config hash |
| `Indicators/PinePort/Wonderwhales.mq5` | 18 buffer, 3 plot (PSAR, BUY, SELL), chỉ phát tín hiệu ở nến đã đóng |
| `Experts/PineSignalLabEA.mq5` | Đọc indicator tại `shift=1`, ghi journal + CSV, chống trùng theo `bar_open_time` |
| `Scripts/WonderwhalesContractTests.mq5` | 36 vector tổng hợp A–E; không đọc thị trường, không giao dịch |

### Buffer contract

| Index | Buffer | Missing |
|---|---|---|
| 0 | PSAR | `EMPTY_VALUE` |
| 1 / 2 | BUY / SELL marker (low/high) | `EMPTY_VALUE` |
| 3 / 4 | BUY / SELL signal | `0.0` |
| 5 | SAR direction (1/-1) | `0` |
| 6 / 7 | Blocked BUY / SELL | `0.0` |
| 8 | ATR% | `0.0` |
| 9 / 10 | Fast / slow EMA | `EMPTY_VALUE` |
| 11 | EMA200 | `EMPTY_VALUE` |
| 12 | RSI | `EMPTY_VALUE` |
| 13–15 | BB upper / mid / lower | `EMPTY_VALUE` |
| 16 / 17 | Volume MA / ratio | `EMPTY_VALUE` / `0.0` |

Chi tiết: [`docs/indicators/wonderwhales.md`](../docs/indicators/wonderwhales.md).

### Compile

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1
```

Script đọc log UTF-16 và chỉ PASS khi cả năm file `0 errors, 0 warnings`; không tin exit code MetaEditor.

### Chạy

1. Sync 4 file PinePort + `LabLogger.mqh` vào data folder, giữ cấu trúc.
2. Compile indicator trước, rồi test script, rồi EA.
3. Gắn indicator lên chart; kiểm tra chỉ có tín hiệu ở nến đã đóng.
4. Gắn `PineSignalLabEA`; đọc `MQL5/Files/pine_signal_log.csv`.
5. Chạy `WonderwhalesContractTests`; kỳ vọng `TEST|RESULT|ALL_PASS|pass=36 fail=0`.

Hướng dẫn đầy đủ: [`docs/guides/install-and-test.md`](../docs/guides/install-and-test.md).

### Giới hạn

- `confirmOnClose=false` không được port (D16).
- EA chỉ đọc `shift=1`; không có alert native, không có execution.
- Contract test 36 vector đã chạy **PASS 36/36** trong Strategy Tester (2026-10-28); parity `BLOCKED`.
- Indicator đã được `iCustom` nạp trong 3 lần chạy tester của `WonderwhalesSimEA` (có tín hiệu sinh ra),
  nhưng điều đó không thay thế contract test hay đối chiếu Pine.
- Không dùng log/CSV để tuyên bố lợi nhuận hay tương thích broker.

## 10. PinePort — LongKaco VSA (signal-only, Phase 4)

Port từ Pine `LongKaco VSA` sang MQL5. Chỉ tín hiệu trên nến đã đóng; **không port execution** và
**không gửi lệnh**. EA hiện **chưa** đọc indicator này (`NOT_IMPLEMENTED`).

| Thành phần | Vai trò |
|---|---|
| `Include/PinePort/LongKacoVSAContract.mqh` | Contract `1.0.0`: enum buffer 8–28, mode/event/result, pure helper, FNV-1a hash |
| `Indicators/PinePort/LongKacoVSA.mq5` | 29 buffer = 8 plot marker (0–7) + 21 contract buffer (8–28) |
| `Scripts/LongKacoVSAContractTests.mq5` | 47 vector tổng hợp A–H; không đọc thị trường, không giao dịch |

Buffer contract, signal ID và test vector: [`docs/indicators/longkaco-vsa.md`](../docs/indicators/longkaco-vsa.md).
Validator tĩnh: `scripts/validate_longkaco.py`.

### Giới hạn LongKaco

- Contract test 47 vector đã chạy **PASS 47/47** trong Strategy Tester (2026-10-28).
- EA chưa đọc LongKaco; chưa có CSV, chưa có parity (`BLOCKED`).
- Indicator chỉ vẽ marker tại nến đã đóng; `PSAR`/level không có trong contract này.
- Không dùng buffer `RESULT`/`FILL` để vào lệnh; chúng chỉ phục vụ đối chiếu.

## 11. PinePort — TM Fusion Zones (signal-only, Phase 4)

Port từ Pine `TM Fusion Zones` sang MQL5. Chỉ tín hiệu trên nến đã đóng; **không port execution** và
**không gửi lệnh**. EA hiện **chưa** đọc indicator này (`NOT_IMPLEMENTED`).

| Thành phần | Vai trò |
|---|---|
| `Include/PinePort/TMFusionZonesContract.mqh` | Contract `1.0.0`: enum buffer 10–32, regime/setup/block, pure helper, FNV-1a hash |
| `Indicators/PinePort/TMFusionZones.mq5` | 33 buffer = 10 plot (ribbon, signal, TP1/TP2/SL, level line) + 23 contract buffer (10–32) |
| `Scripts/TMFusionZonesContractTests.mq5` | 82 vector tổng hợp A–O; không đọc thị trường, không giao dịch, không ghi file |

Buffer contract, signal ID và test vector: [`docs/indicators/tm-fusion-zones.md`](../docs/indicators/tm-fusion-zones.md).
Validator tĩnh: `scripts/validate_tmfz.py`.

### Giới hạn TM Fusion Zones

- Contract test 82 vector đã chạy **PASS 82/82** trong Strategy Tester (2026-10-28).
- EA chưa đọc TM FZ; chưa có CSV, chưa có parity (`BLOCKED`).
- Zone/structure dùng pivot strict nên xác nhận trễ `pivotLen` nến — cấu trúc, không phải repaint.
- Không dùng buffer `RESULT`/`FILL` để vào lệnh; chúng chỉ phục vụ đối chiếu.

## 12. PinePort — Price Action MTF (signal-only, Phase 4)

Port từ Pine `Price Action MTF` sang MQL5. Chỉ tín hiệu trên nến đã đóng; **không port execution** và
**không gửi lệnh**. EA hiện **chưa** đọc indicator này (`NOT_IMPLEMENTED`).

| Thành phần | Vai trò |
|---|---|
| `Include/PinePort/PriceActionMTFContract.mqh` | Contract `1.0.0`: enum buffer 12–106, quality/regime/block, pure helper, FNV-1a hash |
| `Indicators/PinePort/PriceActionMTF.mq5` | 107 buffer = 12 plot (score, entry/SL/TP, signal, event) + 95 contract buffer (12–106) |
| `Scripts/PriceActionMTFContractTests.mq5` | 119 vector tổng hợp A–P; không đọc thị trường, không giao dịch, không ghi file |

Buffer contract, signal ID và test vector: [`docs/indicators/price-action-mtf.md`](../docs/indicators/price-action-mtf.md).
Validator tĩnh: `scripts/validate_pamtf.py`.

### Giới hạn Price Action MTF

- Contract test đã chạy **PASS 120/120 check** trong Strategy Tester (2026-10-28).
- EA chưa đọc PA MTF; chưa có CSV, chưa có parity (`BLOCKED`).
- MTF dùng `request.security(expr[1], lookahead_on)` như Pine; phụ thuộc dữ liệu HTF đã đóng.
- Không dùng buffer `SIG/EV` để vào lệnh; chúng chỉ phục vụ đối chiếu.

## 13. PinePort — TM XAU Signals 2 (signal-only, Phase 4)

Port từ Pine `TM XAU Signals 2` sang MQL5. Chỉ tín hiệu trên nến đã đóng; **không port execution** và
**không gửi lệnh**. EA hiện **chưa** đọc indicator này (`NOT_IMPLEMENTED`).

| Thành phần | Vai trò |
|---|---|
| `Include/PinePort/TMXAUSignals2Contract.mqh` | Contract `1.0.0`: enum buffer 13–152, quality/bucket/session/close/block/event, pure helper, FNV-1a hash |
| `Indicators/PinePort/TMXAUSignals2.mq5` | 153 buffer = 13 plot (EMA, VWAP, volume, entry, TP/SL, active lines) + 140 contract buffer (13–152) |
| `Scripts/TMXAUSignals2ContractTests.mq5` | 105 vector hợp đồng A–O (+2 kiểm tra bổ sung); không đọc thị trường, không giao dịch, không ghi file |

Buffer contract, signal ID và test vector: [`docs/indicators/tm-xau-signals-2.md`](../docs/indicators/tm-xau-signals-2.md).
Validator tĩnh: `scripts/validate_tmxau2.py`.

### Giới hạn TM XAU Signals 2

- Contract test đã chạy **PASS 107/107 check** trong Strategy Tester (2026-10-28).
- EA chưa đọc TM XAU2; chưa có CSV, chưa có parity (`BLOCKED`).
- Mặc định `rr1=1.0 < rrMin=1.5` (quirk nguồn) nên indicator không phát tín hiệu nếu giữ input mặc định.
- Không dùng buffer `SIG/ENTRY` để vào lệnh; chúng chỉ phục vụ đối chiếu.

## 14. PinePort — TM Indicator 2 (signal-only, Phase 4)

Port từ Pine `TM Indicator 2` v2.1.0 sang MQL5. Chỉ tín hiệu trên nến đã đóng; **không port execution** và
**không gửi lệnh**. EA hiện **chưa** đọc indicator này (`NOT_IMPLEMENTED`).

| Thành phần | Vai trò |
|---|---|
| `Include/PinePort/TMIndicator2Contract.mqh` | Contract `1.0.0`: enum buffer 16–241, regime/session/reason/mode/order/stage/close/event/bucket, pure helper, engine step, FNV-1a hash |
| `Indicators/PinePort/TMIndicator2.mq5` | 242 buffer = 16 plot (EMA, VWAP, volume, entry, TP/SL, active lines) + 226 contract buffer (16–241); 118 input |
| `Scripts/TMIndicator2ContractTests.mq5` | 155 vector hợp đồng A–P; không đọc thị trường, không giao dịch, không ghi file |

Buffer contract, signal ID và test vector: [`docs/indicators/tm-indicator-2.md`](../docs/indicators/tm-indicator-2.md).
Validator tĩnh: `scripts/validate_tmind2.py`.

### Giới hạn TM Indicator 2

- Contract test 155 vector đã chạy **PASS 155/155** trong Strategy Tester (2026-10-28).
- EA chưa đọc TM Indicator 2; chưa có CSV, chưa có parity (`BLOCKED`).
- Contract buffer 16–241 là `INDICATOR_CALCULATIONS`; chỉ 0–15 là plot.
- Không dùng buffer `ENTRY/SIG` để vào lệnh; chúng chỉ phục vụ đối chiếu.

## 15. PinePort — EA tín hiệu đa nguồn (Phase 5)

`PineMultiSignalLabEA.mq5` đọc cả sáu indicator PinePort tại `shift=1` (nến đã đóng), ghi một CSV thống
nhất và **không** có bất kỳ hàm giao dịch nào. EA cũ `PineSignalLabEA.mq5` vẫn giữ nguyên cho Wonderwhales.

| Nguồn | Input bật/tắt | Buffer đọc |
|---|---|---|
| Wonderwhales | `InpEnableWw` | `WW_BUF_BUY_SIGNAL`, `WW_BUF_SELL_SIGNAL`, `WW_BUF_SAR_DIR` |
| LongKacoVSA | `InpEnableLk` | `LK_BUF_FILL`, `LK_BUF_DIR`, `ENTRY/SL/TP` |
| TMFusionZones | `InpEnableFz` | `FZ_BUF_SIGNAL_LONG/SHORT`, `SCORE_*`, `ENTRY/SL/TP1..3` |
| PriceActionMTF | `InpEnablePa` | `PA_BUF_SIG_LONG/SHORT`, `SCORE100`, plan, `BLOCK` |
| TMXAUSignals2 | `InpEnableX2` | `X2_BUF_SIG`, `X2_BUF_DIR`, `SCORE100`, plan, `BLOCK` |
| TMIndicator2 | `InpEnableTm2` | `TM2_BUF_SIGNAL`, `TM2_BUF_DIR`, `SCORE100`, plan, `NO_TRADE_REASON` |

- CSV: `MQL5/Files/pine_multi_signal_log.csv` (đổi bằng `InpOutputFile`).
- Schema 18 cột: `detected_at,bar_open_time,confirmed_at,symbol,timeframe,source,contract_version,signal_id,side,dir,score,entry,sl,tp1,tp2,tp3,reason,input_hash`.
- Audit: `python scripts/audit_multi_signal_csv.py --csv <csv>`.
- Parity: `python scripts/compare_multi_signal_exports.py --reference <pine.csv> --mql5 <csv> --mql5-offset-minutes 180`
  (exit 3 = `BLOCKED` khi thiếu CSV reference; xem `docs/indicators/parity.md`).

### Giới hạn

- EA mới **compile**, chưa chạy trong terminal (`NOT_RUN`); chưa có CSV thật.
- `iCustom` giới hạn 63 tham số, nên EA gọi indicator **không truyền input** (dùng default). Muốn đổi
  cấu hình phải sửa default của indicator hoặc tạo EA riêng.
- `input_hash` là FNV-1a của `source|contract_version|indicator-defaults`, không phải hash cấu hình thật.
- Không dùng tín hiệu để vào lệnh; EA chỉ ghi log phục vụ đối chiếu.

## 16. Simulation core + Runner/Grid/DCA EAs (Track C, W1–W5)

Thư viện dùng chung cho các EA mô phỏng (`RunnerTrailingLabEA`, `GridLabEA`, `DCALabEA`,
`PinePlanSimEA`, `WonderwhalesSimEA`):

| File | Vai trò |
|---|---|
| `Include/Sim/SimTypes.mqh` | Side ảo, FNV-1a 32-bit, helper fingerprint config |
| `Include/Sim/SimValidate.mqh` | Validate price/volume/commission/levels/percent/spread/warmup/slippage |
| `Include/Sim/SimPortfolio.mqh` | Vị thế ảo trong bộ nhớ, average entry, equity, drawdown, partial close |
| `Include/Sim/SimCostModel.mqh` | Spread/commission/slippage/swap khai báo, `FillPrice` bất lợi |
| `Include/Sim/SimRiskGuard.mqh` | Hard cap, cooldown, kill switch, `ACTIVE/BLOCKED/HALTED` |
| `Include/Sim/SimTrailing.mqh` | Breakeven + trailing thuần, stop-hit/gap helper |
| `Include/Sim/SimGrid.mqh` | Cap tầng/volume/exposure, giá tầng, trigger, target/stop basket |
| `Include/Sim/SimDca.mqh` | Cap số lần add/volume/exposure, volume từng lần add, trigger giá/bar |
| `Include/Sim/SimLogger.mqh` | CSV 18 cột trong `MQL5/Files` |
| `Scripts/SimCoreTests.mq5` | 123 test vector tự sinh, chạy một lần trên chart bất kỳ |
| `Experts/RunnerTrailingLabEA.mq5` | Một vị thế ảo, EMA cross, ATR SL, breakeven/trailing, max holding |
| `Experts/GridLabEA.mq5` | Grid một chiều, volume multiplier có clamp, exit LEVEL/BASKET, basket stop bắt buộc |
| `Experts/DCALabEA.mq5` | DCA một chiều, trigger giá/bar, tối đa một fill mỗi bar, basket target/stop bắt buộc |
| `Experts/PinePlanSimEA.mq5` | Một vị thế ảo theo trade plan của PA/X2/TM2 |
| `Experts/WonderwhalesSimEA.mq5` | Một vị thế ảo từ tín hiệu Wonderwhales trên `XAUUSDm` |

- Compile hiện tại (2026-10-28, `scripts/build-mql5.ps1`): 0 errors, 0 warnings
  (`SimCoreTests.ex5` 73,646 bytes; `RunnerTrailingLabEA.ex5` 52,622 bytes;
  `GridLabEA.ex5` 51,590 bytes; `DCALabEA.ex5` 47,606 bytes). Byte size phụ thuộc
  bản MetaEditor/đường dẫn biên dịch; dòng `Result:` trong log là bằng chứng chính.
- Toolchain dùng chung: `scripts/check-environment.ps1`, `scripts/build-mql5.ps1`,
  `scripts/run-python-tests.ps1`, `scripts/validate-project.py`, `scripts/package-source.ps1`
  (chi tiết `docs/guides/toolchain.md`).
- Test vector runtime **PASS**: `SimCoreTests` `pass=123 fail=0` và `SimPlanTests` `pass=39 fail=0`
  (MT5, 2026-10-28).
- EA runtime **PASS một phần**: runner/grid/DCA đã chạy 10 scenario Strategy Tester (có SUMMARY);
  `plan_*` `BLOCKED_PERFORMANCE`. Preset mẫu `configs/sim/runner_trailing.json`,
  `configs/sim/grid_lab.json`, `configs/sim/dca_lab.json`, `configs/sim/pine_plan_lab.json`,
  `configs/sim/wonderwhales_xauusdm.json`; scenario baseline/stress/edge:
  `configs/project.example.json` (15 scenario).
- Kiểm tra fail-closed trước khi nạp preset: `python scripts/validate_sim_configs.py` (chi tiết
  `docs/reference/simulation.md`).
- Không có API giao dịch; `python/tests/test_sim_core_source.py` chặn hồi quy bằng cách quét token cấm
  trên toàn bộ `Include/Sim`, `Scripts/SimCoreTests.mq5` và `Experts/*.mq5`.
- P&L basket DCA có cross-check độc lập bằng Python: `python/tests/test_dca_vectors.py`.
- Chi tiết công thức, token lỗi và ví dụ tay: `docs/reference/simulation.md`; mỗi EA có mục riêng trong
  cùng tài liệu.
- Bàn giao Track C: cài đặt/kiểm thử `docs/guides/install-and-test.md`; Strategy Tester thủ công
  `docs/guides/strategy-tester.md`; toolchain `docs/guides/toolchain.md`. Cả 5 EA đều simulation-only:
  Strategy Tester hiển thị 0 deal là đúng.

## 17. PinePlanSimEA — vị thế ảo theo trade plan (Track C, W10)

`PinePlanSimEA.mq5` đọc plan của một trong ba indicator (`PriceActionMTF`, `TMXAUSignals2`,
`TMIndicator2`) qua `iCustom` và mở **một vị thế ảo** cho mỗi tín hiệu biên trên nến đã đóng.

| File | Vai trò |
|---|---|
| `Include/Sim/SimPlan.mqh` | Resolve side, validate plan (token ổn định), chọn/hit/fill target |
| `Experts/PinePlanSimEA.mq5` | Đọc buffer, `CSimRiskGuard`, breakeven/trailing tùy chọn, CSV |
| `Scripts/SimPlanTests.mq5` | 39 vector thuần: 7 resolve, 19 validate, 13 target |
| `../configs/sim/pine_plan_lab.json` | Preset baseline, `SIMULATION_ONLY` |

| Nguồn | `DIR` | `PLAN_VALID` | `ENTRY` | `SL` | `TP1..3` | Tín hiệu |
|---|---:|---:|---:|---:|---|---|
| Price Action MTF | 13 | 17 | 18 | 19 | 20–22 | `SIG_LONG` 24, `SIG_SHORT` 25 |
| TM XAU Signals 2 | 14 | 28 | 29 | 30 | 31–33 | `SIG` 35 + `DIR` |
| TM Indicator 2 | 20 | 42 | 45 | 47 | 48–50 | `SIGNAL` 59 + `DIR` |

- Compile: 0 errors, 0 warnings (`PinePlanSimEA.ex5` 59,326 bytes; `SimPlanTests.ex5` 15,892 bytes lần build
  gần nhất 2026-10-28). Byte size phụ thuộc MetaEditor/đường dẫn; dòng `Result:` là bằng chứng chính.
- Entry khớp tại `ask`/`bid` + slippage; `plan.entry` chỉ là `ref_entry` trong log. SL/target giữ nguyên
  theo plan; target fill đúng target, không credit gap có lợi; SL được kiểm trước target.
- Runtime: `SimPlanTests` PASS trong MT5 ngày 2026-10-28 (`TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan`).
  Lần chạy đầu phát hiện hằng số `point` sai trong test và lỗi biên số thực ở ngưỡng target; đã sửa
  `SimPlanTests.mq5` + `SimPlan.mqh` rồi chạy lại. EA trong Strategy Tester: 2 scenario `plan_*`
  `BLOCKED_PERFORMANCE` — 1 tháng chẩn đoán chạy 197 s với 0 entry; 9 tháng không xong trong ~13 phút
  (~O(n²) ở `PriceActionMTF`).
- Không đưa LongKaco VSA và TM Fusion Zones vào EA này: hai nguồn đó dùng máy trạng thái `FILL/RESULT`
  và `POS_SIDE`, không phải plan tĩnh.
- Chi tiết luật, token lỗi và giới hạn: `docs/reference/simulation.md` mục **PinePlanSimEA**; preset:
  `configs/sim/pine_plan_lab.json`.

## 18. WonderwhalesSimEA — vị thế ảo từ tín hiệu Wonderwhales (Track C, 2026-10-28)

`WonderwhalesSimEA.mq5` đọc tín hiệu buy/sell của `PinePort\Wonderwhales` tại `shift=1` (nến đã đóng) và
mở **một vị thế ảo** trên `XAUUSDm`. Không có API giao dịch.

| File | Vai trò |
|---|---|
| `Include/PinePort/WonderwhalesContract.mqh` | Buffer map + mode + hash dùng chung với indicator |
| `Experts/WonderwhalesSimEA.mq5` | Tín hiệu WW, SL PSAR/ATR%/fixed, exit-on-flip, max holding, CSV |
| `../configs/sim/wonderwhales_xauusdm.json` | Preset baseline, `SIMULATION_ONLY`, `InpRequireSymbol=XAUUSDm` |

| Buffer | Hằng số | Dùng cho |
|---:|---|---|
| 0 | `WW_BUF_PSAR` | khoảng SL chế độ PSAR |
| 3 / 4 | `WW_BUF_BUY_SIGNAL` / `WW_BUF_SELL_SIGNAL` | tín hiệu vào lệnh |
| 8 | `WW_BUF_ATR_PCT` | khoảng SL chế độ ATR% |

- Compile: 0 errors, 0 warnings trong repo và trong Data Folder MT5
  (`WonderwhalesSimEA.ex5` 57,522 bytes, 2026-10-28). Dòng `Result:` trong log là bằng chứng chính.
- Guard symbol: `InpRequireSymbol` khác rỗng và khác `_Symbol` → `INIT_PARAMETERS_INCORRECT`.
- Entry bị từ chối (`STOP_REJECTED`) nếu khoảng SL nhỏ hơn `InpMinStopPoints`; không nới stop để vào lệnh.
- Runtime: **PASS** 3 scenario Strategy Tester headless trên `XAUUSDm` M15 (2026-10-28) — baseline 869
  trades/+26.97; stress 787/−7.50; edge ATR 795/+24.96 (đơn vị model, contract size 1). Không suy ra
  lợi nhuận; parity Pine `BLOCKED`.
- Calibration: `XAUUSDm` point 0.001, spread ~260 point → `InpFixedStopPoints=3000`, `InpMaxSpreadPoints=600`
  (stress 400).
- Chi tiết: `docs/reference/simulation.md` mục **WonderwhalesSimEA**;
  indicator: `docs/indicators/wonderwhales.md`.
