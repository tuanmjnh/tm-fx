# Buffer Contract — Wonderwhales (Pine v6 → MQL5)

- **Phase:** 3 — Đặc tả thuật toán và hợp đồng buffer trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4` — chốt giao diện giữa custom indicator và EA
  signal-only. Chưa có mã MQL5, chưa compile.
- **Nguồn:** [`INDICATOR_SPEC_Wonderwhales.md`](INDICATOR_SPEC_Wonderwhales.md) và
  [`REPAINT_AUDIT_Wonderwhales.md`](REPAINT_AUDIT_Wonderwhales.md).
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không có API gửi lệnh, không đọc tài khoản, không alert.

## 1. Phạm vi

Hợp đồng này định nghĩa:

1. Input của custom indicator `MQL5/Indicators/PinePort/Wonderwhales.mq5`.
2. 18 buffer, ý nghĩa, miền giá trị, giá trị thiếu, loại buffer.
3. Cách indicator chốt tín hiệu theo nến đã đóng.
4. Cách EA `PineSignalLabEA.mq5` đọc buffer, chống trùng và ghi CSV.
5. Test vector tổng hợp để kiểm tra logic thuần trước khi so với Pine.

Không định nghĩa: execution, sizing, SL/TP/BE/trailing, alert. Đó là phạm vi khác và đang `BLOCKED`.

## 2. Chính sách kế thừa từ Phase 2

| Mã | Chính sách | Thể hiện trong hợp đồng |
|---|---|---|
| P1 | Chỉ phát tín hiệu trên nến đã đóng | Buffer 3/4/6/7 = `0.0` tại index `rates_total-1` |
| P2 | EA chỉ đọc `shift = 1` | Mục 9; không có input đọc `shift = 0` |
| P3 | Không port `confirmOnClose = false` | Không có input tương ứng; ghi D16 |
| P4 | Tín hiệu là edge event | Công thức giữ `dir[1]` và `crossover` |
| P5 | Blocked không phải tín hiệu | Buffer 6/7 tách riêng; EA không dùng để vào lệnh |
| P9 | PSAR thiếu giá trị ≠ 0 | Buffer 0 = `EMPTY_VALUE`; `dir` giữ nguyên |
| P10 | `psar == close` là bearish | Dùng `<` nghiêm ngặt |

## 3. Input contract

Tên, kiểu, default và **clamp** phải khớp Pine. Clamp lấy từ
[`Wonderwhales.pine:129–142`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales.pine#L129).

| # | Input MQL5 | Kiểu | Default | Min | Clamp / ghi chú |
|---:|---|---|---:|---:|---|
| 1 | `InpMode` | enum | `MODE_SAR` | — | 0 SAR, 1 EMA, 2 SAR+EMA, 3 SAR+EMA+ATR |
| 2 | `InpPsarStart` | double | 0.02 | 0.001 | truyền thẳng |
| 3 | `InpPsarInc` | double | 0.02 | 0.001 | truyền thẳng |
| 4 | `InpPsarMax` | double | 0.20 | 0.01 | `max(InpPsarStart, InpPsarMax)` |
| 5 | `InpFastEma` | int | 20 | 1 | `max(1, x)` |
| 6 | `InpSlowEma` | int | 50 | 2 | `max(fastSafe + 1, x)` |
| 7 | `InpEma200` | int | 200 | 10 | `max(10, x)` |
| 8 | `InpAtrLen` | int | 14 | 1 | `max(1, x)` |
| 9 | `InpMinAtrPct` | double | 0.5 | 0.01 | truyền thẳng |
| 10 | `InpVolMaLen` | int | 20 | 1 | `max(1, x)` |
| 11 | `InpRsiLen` | int | 14 | 1 | `max(1, x)` |
| 12 | `InpBbLen` | int | 20 | 1 | `max(1, x)` |
| 13 | `InpBbMult` | double | 2.0 | 0.1 | truyền thẳng |

Không có input `confirmOnClose`, `allowLong/Short`, màu sắc, label, HUD, VSA threshold. Lý do:

- `confirmOnClose` → D16 (không port).
- `allowLong/Short` là input của **strategy**, không có trong indicator Pine.
- Màu/label/HUD/VSA chỉ là render; MQL5 chỉ vẽ PSAR + 2 mũi tên (D17).
- VSA threshold không ảnh hưởng tín hiệu; `VOL_MA`/`VOL_RATIO` vẫn xuất để đối chiếu.

Giá áp dụng cố định là `close` (Pine dùng `close` cho EMA/RSI/BB/ATR%; PSAR dùng high/low nội bộ).

## 4. Signal ID và reason

Mode là input nên tại một thời điểm chỉ một cặp ID khả dụng. EA suy ra ID từ mode, không cần buffer
riêng.

| Mode | BUY ID | SELL ID | Trigger |
|---:|---|---|---|
| 0 | `WW_BUY_SAR_FLIP` | `WW_SELL_SAR_FLIP` | `buyFlip` / `sellFlip` |
| 1 | `WW_BUY_EMA_CROSS` | `WW_SELL_EMA_CROSS` | `emaBuyCross` / `emaSellCross` |
| 2 | `WW_BUY_SAR_EMA` | `WW_SELL_SAR_EMA` | flip + `emaBull` / `emaBear` |
| 3 | `WW_BUY_SAR_EMA_ATR` | `WW_SELL_SAR_EMA_ATR` | flip + EMA + `atrOk` |

Giá trị log:

- `signal=BUY|SELL`, `signal_id=<ID ở trên>`.
- `reason=BLOCKED_FILTER` cho buffer 6/7; kèm `fast`, `slow`, `atr_pct` để chẩn đoán.
- `reason=NO_SIGNAL` khi cả 4 buffer tín hiệu đều `0`.

Không có signal ID cho “điều kiện còn đúng”: tín hiệu chỉ tồn tại đúng một nến.

## 5. Hợp đồng 18 buffer

Index cố định. `0` = nến cũ nhất (non-series), `rates_total-1` = nến hiện tại.

| # | Tên | Ý nghĩa | Miền giá trị | Thiếu | Loại | Plot | EA dùng |
|---:|---|---|---|---|---|---|---|
| 0 | `PSAR` | Parabolic SAR | giá > 0 | `EMPTY_VALUE` | DATA | line | không (debug) |
| 1 | `BUY_MARKER` | Giá đặt mũi tên BUY | `low` của nến tín hiệu | `EMPTY_VALUE` | DATA | arrow 233 | không |
| 2 | `SELL_MARKER` | Giá đặt mũi tên SELL | `high` của nến tín hiệu | `EMPTY_VALUE` | DATA | arrow 234 | không |
| 3 | `BUY_SIGNAL` | Tín hiệu BUY đã xác nhận | `0.0` / `1.0` | `0.0` | CALC | — | **có** |
| 4 | `SELL_SIGNAL` | Tín hiệu SELL đã xác nhận | `0.0` / `1.0` | `0.0` | CALC | — | **có** |
| 5 | `SAR_DIR` | Hướng PSAR | `-1`, `0`, `1` | `0` | CALC | — | debug |
| 6 | `BLOCKED_BUY` | Raw BUY bị filter chặn | `0.0` / `1.0` | `0.0` | CALC | — | debug |
| 7 | `BLOCKED_SELL` | Raw SELL bị filter chặn | `0.0` / `1.0` | `0.0` | CALC | — | debug |
| 8 | `ATR_PCT` | `(ATR / close) * 100` | ≥ 0 | `0.0` | CALC | — | debug |
| 9 | `FAST_EMA` | EMA nhanh | giá > 0 | `EMPTY_VALUE` | CALC | — | debug |
| 10 | `SLOW_EMA` | EMA chậm | giá > 0 | `EMPTY_VALUE` | CALC | — | debug |
| 11 | `EMA200` | EMA 200 | giá > 0 | `EMPTY_VALUE` | CALC | — | không |
| 12 | `RSI` | RSI | 0–100 | `EMPTY_VALUE` | CALC | — | không |
| 13 | `BB_UPPER` | Bollinger upper | giá | `EMPTY_VALUE` | CALC | — | không |
| 14 | `BB_MID` | Bollinger middle | giá | `EMPTY_VALUE` | CALC | — | không |
| 15 | `BB_LOWER` | Bollinger lower | giá | `EMPTY_VALUE` | CALC | — | không |
| 16 | `VOL_MA` | SMA của `tick_volume` | ≥ 0 | `EMPTY_VALUE` | CALC | — | không |
| 17 | `VOL_RATIO` | `volume / VOL_MA`, 0 nếu MA thiếu/≤ 0 | ≥ 0 | `0.0` | CALC | — | không |

Quy ước:

- `indicator_buffers = 18`, `indicator_plots = 3`; plot 1–3 map buffer 0–2.
- Buffer 0–2 là `INDICATOR_DATA`; 3–17 là `INDICATOR_CALCULATIONS`.
- `PLOT_EMPTY_VALUE` của buffer 0/1/2 = `EMPTY_VALUE`.
- Không dùng `0` cho PSAR/EMA/RSI/BB/VOL_MA; `0` là giá trị hợp lệ của `SAR_DIR`, `ATR_PCT`,
  `VOL_RATIO`, signal và blocked.
- Buffer 8 theo đúng Pine: khi ATR `na` thì `atrPct = 0.0`. Khi đó `atrOk = 0 >= minAtrPct` → false
  vì `minAtrPct > 0`. Không thay bằng `EMPTY_VALUE`.
- Buffer 17 theo đúng Pine: khi MA `na` hoặc `<= 0` thì `0.0`.

### 5.1 Plot

| Plot | Buffer | Style | Màu | Ghi chú |
|---:|---:|---|---|---|
| 1 | 0 | `DRAW_LINE` | một màu cố định | Pine đổi màu theo `sarDir`; MQL5 một màu (D17) |
| 2 | 1 | `DRAW_ARROW`, code 233 | xanh | tại `low` của nến tín hiệu |
| 3 | 2 | `DRAW_ARROW`, code 234 | đỏ | tại `high` của nến tín hiệu |

Indicator chạy ở **chart window** (không phải separate window) vì PSAR là giá. Các giá trị oscillator
vẫn có trong buffer nhưng không vẽ. Đây là khác biệt hiển thị có chủ ý.

## 6. Giá trị thiếu và warm-up

| Thành phần | Có giá trị khi | Trước đó |
|---|---|---|
| `PSAR` | `iSAR` trả giá hợp lệ | `EMPTY_VALUE`, `dir` giữ nguyên |
| `FAST_EMA` | đủ `fastSafe` bar | `EMPTY_VALUE` |
| `SLOW_EMA` | đủ `slowSafe` bar | `EMPTY_VALUE` |
| `EMA200` | đủ `ema200Safe` bar | `EMPTY_VALUE` |
| `ATR_PCT` | `iATR` hợp lệ | `0.0` |
| `RSI` | đủ `rsiSafe` bar | `EMPTY_VALUE` |
| `BB_*` | đủ `bbSafe` bar | `EMPTY_VALUE` |
| `VOL_MA` | đủ `volMaLenSafe` bar | `EMPTY_VALUE` |
| `VOL_RATIO` | `VOL_MA` hợp lệ và > 0 | `0.0` |

Tín hiệu:

- Mode 0/2/3 cần ít nhất **2 bar PSAR hợp lệ** (bar đầu không thể flip vì `dir[1] = 0`).
- Mode 1 cần `slowSafe + 1` bar đóng.
- Mode 3 cần thêm `atrSafe + 1` bar.
- Mọi so sánh với giá trị thiếu trả `false`, không được coi là `0`.

EA mặc định bỏ qua `warmup_bars = 300` đầu tiên (>= mọi ngưỡng trên với default). Con số này là input
của EA, ghi vào CSV để tái lập.

## 7. Bar indexing và xác nhận

Trong `OnCalculate`:

```text
confirmed(j) = (j < rates_total - 1)
```

- Với `j == rates_total - 1` (nến đang chạy), buffer 3/4/6/7 ghi `0.0`, bất kể điều kiện.
- Khi nến mới xuất hiện, index cũ trở thành `j < rates_total - 1` và được tính lại một lần với giá trị
  cuối cùng; từ đó không đổi.
- Buffer 0/1/2 tại nến đang chạy: PSAR có thể được ghi giá trị tạm (để vẽ), nhưng marker 1/2 = `EMPTY_VALUE`
  vì phụ thuộc tín hiệu. PSAR tạm không ảnh hưởng EA (EA không đọc buffer 0).
- `ArraySetAsSeries` không dùng cho buffer; index 0 = cũ nhất.

Hệ quả thời gian: tín hiệu của nến T xuất hiện trên chart tại tick đầu tiên của nến T+1, cùng vị trí
hình học với Pine (Pine hiện tại tick cuối của T). Sai lệch thời gian ≤ 1 tick, không đổi `bar_open_time`.

## 8. Hợp đồng EA đọc buffer

```text
handle = iCustom(_Symbol, _Period, "PinePort\\Wonderwhales",
                 InpMode, InpPsarStart, InpPsarInc, InpPsarMax,
                 InpFastEma, InpSlowEma, InpEma200,
                 InpAtrLen, InpMinAtrPct,
                 InpVolMaLen, InpRsiLen, InpBbLen, InpBbMult);
```

Thứ tự tham số phải khớp tuyệt đối với `OnInit` của indicator. Thay đổi thứ tự là breaking change; phải
tăng `CONTRACT_VERSION`.

Đọc:

1. Nếu `BarsCalculated(handle) < rates_total` → bỏ qua tick, thử lại; log một lần mỗi nến.
2. `CopyBuffer(handle, 3, 1, 1, buy)` và buffer 4 tại `shift = 1`.
3. Nếu copy lỗi → log `copy_buffer_failed`, không suy diễn tín hiệu.
4. Nếu `buy[0] == 1.0` hoặc `sell[0] == 1.0`:
   - `bar_open_time` = thời gian mở nến `shift = 1`.
   - Khóa dedupe `(symbol, timeframe, bar_open_time, signal_id)`.
   - Nếu khóa đã xử lý → bỏ qua.
5. Không đọc buffer 6/7 để tạo sự kiện tín hiệu; chỉ log debug nếu input bật.

Không có input cho phép đọc `shift = 0`. Không có chế độ intrabar.

### 8.1 CSV output

Ghi vào `MQL5/Files` (không phải `Common\Files`), một file mỗi lần chạy:

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,signal_id,side,sar_dir,psar,fast,slow,atr_pct,input_hash
```

- `detected_at`: `TimeCurrent()` tại tick phát hiện.
- `bar_open_time`: `iTime(_Symbol,_Period,1)`.
- `confirmed_at`: `bar_open_time + PeriodSeconds(_Period)`.
- `input_hash`: FNV-1a 32-bit trên chuỗi chuẩn hóa của 13 input + `warmup_bars`, 8 hex.
- Không ghi bid/ask, account, balance, hay bất kỳ trường tài khoản.

## 9. Test vector tổng hợp

Các vector dưới đây kiểm tra **logic thuần**, không phụ thuộc dữ liệu thị trường. Phase 4 sẽ cài chúng
trong `MQL5/Scripts/WonderwhalesContractTests.mq5` và gọi đúng các hàm mà indicator sử dụng, để test và
indicator không lệch nhau.

### 9.1 Nhóm A — hướng PSAR và flip

Đầu vào: `valid`, `psar`, `close`, `dir_prev`. Đầu ra: `dir`, `buy_flip`, `sell_flip`.

| ID | valid | psar | close | dir_prev | → dir | buy | sell |
|---|---|---:|---:|---:|---:|---:|---:|
| A1 | 1 | 99.0 | 100.0 | 0 | 1 | 0 | 0 |
| A2 | 1 | 99.0 | 100.0 | −1 | 1 | 1 | 0 |
| A3 | 1 | 101.0 | 100.0 | 1 | −1 | 0 | 1 |
| A4 | 1 | 100.0 | 100.0 | 1 | −1 | 0 | 1 |
| A5 | 1 | 100.0 | 100.0 | −1 | −1 | 0 | 0 |
| A6 | 1 | 101.0 | 100.0 | −1 | −1 | 0 | 0 |
| A7 | 1 | 99.0 | 100.0 | 1 | 1 | 0 | 0 |
| A8 | 0 | 0.0 | 100.0 | 1 | 1 | 0 | 0 |
| A9 | 0 | 0.0 | 100.0 | 0 | 0 | 0 | 0 |

### 9.2 Nhóm B — mode và filter

`t_buy`/`t_sell` là trigger thô của mode (flip hoặc crossover). Đầu ra: `valid_*`, `blocked_*`.

| ID | mode | t_buy | t_sell | ema_bull | ema_bear | atr_ok | valid_buy | valid_sell | blk_buy | blk_sell |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| B1 | 0 | 1 | 0 | – | – | – | 1 | 0 | 0 | 0 |
| B2 | 1 | 1 | 0 | – | – | – | 1 | 0 | 0 | 0 |
| B3 | 2 | 1 | 0 | 0 | 0 | – | 0 | 0 | 1 | 0 |
| B4 | 2 | 1 | 0 | 1 | 0 | – | 1 | 0 | 0 | 0 |
| B5 | 3 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 0 |
| B6 | 3 | 1 | 0 | 1 | 0 | 1 | 1 | 0 | 0 | 0 |
| B7 | 2 | 0 | 1 | 0 | 0 | – | 0 | 0 | 0 | 1 |
| B8 | 2 | 0 | 1 | 0 | 1 | – | 0 | 1 | 0 | 0 |
| B9 | 0 | 0 | 0 | – | – | – | 0 | 0 | 0 | 0 |
| B10 | 3 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 1 |

### 9.3 Nhóm C — cổng confirmed

| ID | confirmed | valid | blocked | → signal | → blocked_signal |
|---|---:|---:|---:|---:|---:|
| C1 | 1 | 1 | 0 | 1 | 0 |
| C2 | 0 | 1 | 0 | 0 | 0 |
| C3 | 0 | 0 | 1 | 0 | 0 |
| C4 | 1 | 0 | 1 | 0 | 1 |

### 9.4 Nhóm D — EMA crossover

Đầu vào `fast_prev`, `slow_prev`, `fast`, `slow`; `valid = false` nghĩa là một trong hai EMA thiếu.

| ID | f_prev | s_prev | f_now | s_now | valid | → up | → down |
|---|---:|---:|---:|---:|---|---:|---:|
| D1 | 1.0 | 1.0 | 1.1 | 1.0 | 1 | 1 | 0 |
| D2 | 1.0 | 1.0 | 1.0 | 1.0 | 1 | 0 | 0 |
| D3 | 1.1 | 1.0 | 1.0 | 1.0 | 1 | 0 | 0 |
| D4 | 1.1 | 1.0 | 0.9 | 1.0 | 1 | 0 | 1 |
| D5 | 1.0 | 1.0 | 0.9 | 1.0 | 1 | 0 | 1 |
| D6 | 0.9 | 1.0 | 1.01 | 1.0 | 1 | 1 | 0 |
| D7 | – | – | 1.0 | 1.0 | 0 | 0 | 0 |

### 9.5 Nhóm E — giá trị thiếu và nến đang chạy

| ID | Tình huống | Kỳ vọng |
|---|---|---|
| E1 | ATR `na` | `ATR_PCT = 0.0`; `atrOk = false` |
| E2 | `VOL_MA` `na` | `VOL_RATIO = 0.0` |
| E3 | FAST/SLOW EMA `na` | buffer = `EMPTY_VALUE`; `emaBull = emaBear = false` |
| E4 | `j == rates_total - 1` | buffer 3/4/6/7 = `0.0` dù điều kiện đúng |
| E5 | PSAR `na` sau khi đã có giá trị | buffer 0 = `EMPTY_VALUE`; `dir` giữ giá trị trước |
| E6 | `psar == close` | `dir = -1`; flip SELL nếu `dir_prev = 1` (trùng A4) |

Tiêu chí: toàn bộ vector A–E phải PASS trước khi so với Pine. Nếu một vector FAIL, sửa logic — không
sửa kỳ vọng — trừ khi phát hiện kỳ vọng sai so với Pine; khi đó ghi lý do vào báo cáo phase.

## 10. Ngưỡng so sánh parity (đề xuất cho Phase 6)

| Trường | Kiểu so sánh | Ngưỡng |
|---|---|---|
| `BUY_SIGNAL`, `SELL_SIGNAL`, `BLOCKED_*` | khớp chính xác | 0 sai |
| `SAR_DIR` | khớp chính xác | 0 sai |
| `PSAR`, `FAST_EMA`, `SLOW_EMA`, `EMA200` | tương đối | `abs(a-b) <= 1e-8 * max(1, abs(b))` |
| `ATR_PCT`, `RSI`, `BB_*`, `VOL_RATIO` | tương đối | `abs(a-b) <= 1e-6 * max(1, abs(b))` |
| `bar_open_time` | khớp chính xác sau chuẩn hóa timezone | 0 sai |

Chỉ so từ bar `>= warmup_bars` để loại khác biệt seed EMA/ATR/RSI. Mọi mismatch tín hiệu phải được báo
cả `bar_open_time` và giá trị các buffer phụ để chẩn đoán. Nếu mismatch nằm sát ngưỡng `minAtrPct` trong
`1e-9`, báo riêng là `near_threshold`, không tự động coi là lỗi.

## 11. Gate 3 — tiêu chí nghiệm thu

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B20 | Có bảng signal ID, trigger, bar policy, output cho từng mode | PASS | Mục 4, 5 |
| B21 | Buffer contract đầy đủ, có missing value và warm-up | PASS | Mục 5, 6 |
| B22 | Timestamp/confirmed khớp Phase 2 | PASS | Mục 7, 8 |
| B23 | Test vector tổng hợp cho logic thuần | PASS | Mục 9: 9 + 10 + 4 + 7 + 6 vector |
| B24 | Không tạo MQL5/EA, không sửa Pine | PASS | Chỉ tài liệu |
| B25 | Không tuyên bố parity/compile | PASS | Parity vẫn `BLOCKED` |

**Kết luận:** contract đã đủ để viết indicator ở Phase 4. Chưa có bằng chứng runtime; mọi tuyên bố
“khớp Pine” vẫn `BLOCKED` cho tới Phase 6.

## 12. Điểm còn mở

1. Seed EMA/ATR/RSI/BB của MQL5 so với Pine: chỉ giải quyết bằng đo, không bằng giả định. Nếu lệch quá
   ngưỡng sau 300 bar, Phase 4 phải cài lại công thức thủ công.
2. `iSAR` có thể trả `0` thay vì `EMPTY_VALUE` ở những bar đầu; indicator phải chuẩn hóa `0`/`EMPTY_VALUE`
   thành “thiếu” nhưng **không** coi PSAR giá 0 là hợp lệ.
3. Volume: `tick_volume` là mặc định; nếu symbol có `real_volume = 0`, ghi rõ trong parity report.
4. Timezone: CSV dùng giờ server; Pine export có thể là giờ exchange. Chuẩn hóa ở Phase 6.
5. Chưa có reference CSV từ Pine → Phase 6 vẫn `BLOCKED`.
