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

Quy tắc tín hiệu, warm-up và reason code: [`docs/strategy-signal-spec.md`](../docs/strategy-signal-spec.md).

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

**Chưa có kết quả Strategy Tester trong repo.** Compile thành công không chứng minh EA chạy đúng ở
runtime; trạng thái Phase 1 vì vậy là `READY_FOR_MANUAL_VALIDATION`.

### Chạy self-check của signal engine

1. Sync `mt5/Scripts/LabSignalEngineTests.mq5` vào `<Data Folder>/MQL5/Scripts/` cùng các file trong
   `MQL5/Include/`.
2. Compile trong MetaEditor (`F7`), xác nhận 0 errors/0 warnings.
3. Kéo script vào một chart bất kỳ và chọn OK. Script chạy một lần, không giao dịch.
4. Đọc tab **Experts**: kỳ vọng `TEST|RESULT|ALL_PASS` và `fail=0`.
5. Ghi kết quả thật (pass/fail) vào báo cáo Phase 2.

Script **chưa được chạy** trong quá trình phát triển; chỉ mới compile.

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
   `scripts\compare_signals.py` theo [`docs/parity.md`](../docs/parity.md).

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

1. Export model bằng `scripts\export_onnx_model.py` (xem [`docs/onnx-inference.md`](../docs/onnx-inference.md)).
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

Chi tiết: [`docs/BUFFER_CONTRACT_Wonderwhales.md`](../docs/BUFFER_CONTRACT_Wonderwhales.md).

### Compile

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_pineport.ps1
```

Script đọc log UTF-16 và chỉ PASS khi cả ba file `0 errors, 0 warnings`; không tin exit code MetaEditor.

### Chạy

1. Sync 4 file PinePort + `LabLogger.mqh` vào data folder, giữ cấu trúc.
2. Compile indicator trước, rồi test script, rồi EA.
3. Gắn indicator lên chart; kiểm tra chỉ có tín hiệu ở nến đã đóng.
4. Gắn `PineSignalLabEA`; đọc `MQL5/Files/pine_signal_log.csv`.
5. Chạy `WonderwhalesContractTests`; kỳ vọng `TEST|RESULT|ALL_PASS|pass=36 fail=0`.

Hướng dẫn đầy đủ: [`docs/PINEPORT_INSTALL_AND_TEST.md`](../docs/PINEPORT_INSTALL_AND_TEST.md).

### Giới hạn

- `confirmOnClose=false` không được port (D16).
- EA chỉ đọc `shift=1`; không có alert native, không có execution.
- 36 vector mới **compile**, chưa chạy; indicator/EA chưa chạy runtime; parity `BLOCKED`.
- Không dùng log/CSV để tuyên bố lợi nhuận hay tương thích broker.
