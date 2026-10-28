# Repaint Audit — Wonderwhales (Pine v6)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu (chưa port MQL5)
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — kết luận dưới đây là **phân tích tĩnh** trên source Pine.
  Chưa chạy TradingView Bar Replay, chưa tạo alert thật, chưa chạy backtest. Mọi kết luận phụ thuộc hành vi
  runtime của TradingView được đánh dấu `PENDING` ở mục 10.
- **Nguồn:** [`dist/Wonderwhales.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales.pine) (415 dòng,
  SHA `0529d7b9…d61b9`) và
  [`dist/Wonderwhales Backtest.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine)
  (614 dòng, SHA `e7c15e1a…4910`). Không file Pine nào bị sửa.
- **Đặc tả nền:** [`INDICATOR_SPEC_Wonderwhales.md`](INDICATOR_SPEC_Wonderwhales.md).

## 1. Định nghĩa “repaint” dùng trong audit

| Mã | Hiện tượng | Ảnh hưởng thực tế |
|---|---|---|
| RP1 | Marker/label xuất hiện trên nến đang chạy rồi biến mất trước khi nến đóng | Người xem chart thấy tín hiệu “ma” |
| RP2 | Giá trị tín hiệu của một nến **đã đóng** thay đổi khi có nến mới | Backtest/parity không tái lập được |
| RP3 | Alert phát trước khi nến đóng | Vào lệnh trên dữ liệu chưa hoàn tất |
| RP4 | Mức SL/TP/BE của strategy thay đổi trong nến và được áp ngược lại chính nến đó | Fill không có thật trong đời sống |
| RP5 | Kết quả lịch sử khác nhau giữa hai lần chạy cùng input | Không thể dùng làm reference parity |

Trọng tâm của Phase 2 là RP1/RP2/RP3 cho **signal**, và RP4 cho **strategy** (chỉ mô tả, không port).

## 2. Bản đồ phụ thuộc dữ liệu

Toàn bộ chuỗi tính toán là causal, chỉ dùng dữ liệu cùng nến và quá khứ:

```
close, high, low, volume
  ├─ ta.sar(start, inc, max)        -> ww_psar            (đệ quy nội bộ)
  │    └─ var int ww_sarDir          -> ww_sarDir[1] so sánh -> ww_buyFlip / ww_sellFlip
  ├─ ta.ema(close, fast/slow/200)   -> ww_fastEma, ww_slowEma, ww_ema200
  │    └─ ta.crossover/crossunder   -> ww_emaBuyCross / ww_emaSellCross
  ├─ ta.atr(len)                    -> ww_atr -> ww_atrPct -> ww_volatilityOk
  ├─ ta.rsi(close, len)             -> ww_rsi (chỉ hiển thị)
  ├─ ta.bb(close, len, mult)        -> ww_bb* (chỉ hiển thị)
  └─ volume -> ta.sma                -> ww_volMa / ww_volRatio / ww_isClimaxVol (chỉ hiển thị + 1 alert)
```

Đã xác nhận **không** có: `request.security`, `request.security_lower_tf`, `lookahead`, offset âm,
mảng, vòng lặp, pivot/fractal, hay điều kiện cần nến tương lai. Vì vậy không có nguồn repaint từ dữ liệu
ngoài timeframe hoặc từ offset hiển thị.

Nguồn biến động duy nhất là **giá trị nến đang chạy** đi vào `close/high/low/volume`, và `ta.sar` là hàm
đệ quy nên giá trị PSAR của nến hiện tại thay đổi theo từng tick.

## 3. Cổng confirmed-bar

```pine
ww_barConfirmed = not ww_confirmOnClose or barstate.isconfirmed   // dòng 261
ww_signalBuy         = ww_validBuy and ww_barConfirmed             // dòng 263
ww_signalSell        = ww_validSell and ww_barConfirmed            // dòng 264
ww_signalBlockedBuy  = ww_blockedBuy and ww_barConfirmed           // dòng 265
ww_signalBlockedSell = ww_blockedSell and ww_barConfirmed          // dòng 266
```

- Input `ww_confirmOnClose` mặc định `true`, `display = display.none`
  ([dòng 78](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales.pine#L78)).
- `barstate.isconfirmed` = `true` trên **mọi nến lịch sử**, và trên nến realtime chỉ ở lần tính cuối cùng
  trước khi nến đóng. Đây là điểm quyết định toàn bộ audit.
- Cổng này áp cho **cả marker, cả `plot` status-line, cả 3 `alertcondition` tín hiệu, cả `alert()`**.
  Nó **không** áp cho `alertcondition(ww_isClimaxVol)` (dòng 401) vì VSA climax là cảnh báo hiển thị,
  không phải tín hiệu vào lệnh.

Hệ quả trực tiếp:

| Chế độ | Nến lịch sử | Nến realtime đang chạy |
|---|---|---|
| `confirmOnClose = true` (default) | Tín hiệu xuất hiện đúng tại nến có flip, vĩnh viễn | `ww_signalBuy = false` cho tới tick cuối; chỉ hiện khi nến đóng |
| `confirmOnClose = false` | Vẫn tính như nhau (vì `barstate.isconfirmed` luôn true) | Tín hiệu có thể bật/tắt theo từng tick → RP1 |

**Kết luận quan trọng:** chế độ `false` **không thể** được chứng minh bằng backtest. Trên lịch sử,
`barstate.isconfirmed` luôn `true`, nên backtest luôn cho tín hiệu “đẹp” tại nến flip, trong khi realtime
marker có thể nhấp nháy và biến mất. Đây là RP5 ở mức logic, không phải lỗi dữ liệu.

## 4. Ma trận repaint theo thành phần

| Thành phần | Nguồn | Trong nến đang chạy | Sau khi nến đóng | RP |
|---|---|---|---|---|
| `ww_psar` | `ta.sar` | Thay đổi mỗi tick | Cố định, không tính lại | RP1 (hiển thị) |
| `ww_sarDir` | `psar < close`, biến `var` | Có thể đổi dấu nhiều lần | Cố định | RP1 |
| `ww_buyFlip` / `ww_sellFlip` | `dir` và `dir[1]` | Bật/tắt theo `dir` hiện tại; `dir[1]` ổn định | Cố định | RP1 |
| EMA / ATR / RSI / BB / SMA | `ta.*` trên close/volume | Thay đổi | Cố định | RP1 |
| `ww_validBuy` / `ww_validSell` | mode + filter | Thay đổi | Cố định | RP1 |
| `ww_signalBuy` / `ww_signalSell` | `valid AND gate` | `false` nếu gate on; bật/tắt nếu gate off | Cố định | RP1 (chỉ gate off) |
| Marker `plotshape` | `ww_signal*` + input hiển thị | Theo signal | Cố định | RP1 |
| `plot(... status_line)` | `ww_signal*` | Theo signal | Cố định | RP1 |
| HUD table | `barstate.islast` | Cập nhật liên tục | n/a | Không phải tín hiệu |
| `alertcondition` tín hiệu | `ww_signal*` | Phụ thuộc tần suất alert | n/a | RP3 nếu đặt “Once Per Bar” + gate off |
| `alert()` | `ww_signal*` + `freq_once_per_bar_close` | Bị hoãn tới đóng nến | n/a | Thấp (xem mục 6) |
| `alertcondition(ww_isClimaxVol)` | `ww_isClimaxVol` | **Không gate** | n/a | RP3 có thể xảy ra |
| Entry/exit strategy | signal + position + equity | Có thể hành động trong nến | Fill là cuối cùng | RP4 (mức giá), không RP2 |
| SL/TP/BE lines | state + high/low + PSAR | Di chuyển trong nến | Không phải lịch sử tín hiệu | RP4 |

Không có thành phần nào **tính lại giá trị của nến đã đóng** (RP2) trong indicator. `ta.*` của Pine là
causal và `var` chỉ ghi lịch sử một lần cho mỗi nến đã đóng. Vì vậy với `confirmOnClose = true`, chuỗi
tín hiệu lịch sử là tất định.

## 5. Kịch bản intrabar

**S1 — PSAR flip trong nến rồi flip ngược trước khi đóng, gate on.**
`ww_sarDir` đổi `-1 → 1 → -1`. `ww_validBuy` bật rồi tắt; `ww_barConfirmed = false` suốt nến, nên
`ww_signalBuy` luôn `false`. Khi đóng nến, `dir` giữ `-1`, không có tín hiệu. **Không repaint, không tín hiệu.**

**S2 — PSAR flip ở tick cuối, gate on.**
`ww_sarDir` đổi `-1 → 1`; tại tick cuối `barstate.isconfirmed = true` → `ww_signalBuy = true`. Marker hiện
đúng một lần tại nến đó; nến sau `dir[1] = 1` nên `buyFlip` không lặp. **Tín hiệu edge, không lặp.**

**S3 — Cùng dữ liệu, gate off.**
Marker có thể hiện giữa nến rồi biến mất khi giá đóng cửa trở lại dưới PSAR. Lịch sử (backtest) vẫn vẽ
marker tại nến đó, vì trên lịch sử `isconfirmed = true` và `dir` cuối cùng là `1` nếu close cuối > PSAR.
Nếu close cuối < PSAR thì lịch sử **không** có marker, còn người xem realtime đã thấy marker. **RP1 + RP5.**

**S4 — Nến đầu tiên có PSAR hợp lệ.**
`ww_sarDir` khởi tạo `0` ([dòng 171](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales.pine#L171)).
Nếu PSAR hợp lệ và `psar < close`, `dir = 1`, nhưng `dir[1] = 0`, nên `ww_buyFlip = false`. Tương tự cho
SELL. **Không có tín hiệu ở nến PSAR hợp lệ đầu tiên.** Đây là warm-up bắt buộc, không phải bug.

**S5 — PSAR `na` kéo dài.**
Khối `if not na(ww_psar)` không chạy, `dir` giữ giá trị cũ (hoặc `0`). Nếu PSAR `na` ở đầu chuỗi, không
có flip. Nếu PSAR `na` giữa chuỗi (dữ liệu thiếu), `dir` đứng yên và flip kế tiếp so với giá trị cũ — cần
 map đúng sang MQL5 (`EMPTY_VALUE` phải được coi là `na`, **không** phải `0.0`).

**S6 — `psar == close`.**
Ternary là `psar < close ? 1 : -1` → bằng nhau được tính là **bearish** (`-1`). Port phải giữ đúng dấu
`<` và nhánh else, không dùng `<=`.

**S7 — EMA crossover khi EMA còn `na`.**
`ta.crossover(a, b)` yêu cầu `a[1] <= b[1]` và `a > b`. Trong warm-up EMA `na` → `false`. Port MQL5 phải
trả `false` khi chưa đủ bar, không được coi `na` là `0`.

**S8 — Flip xảy ra nhưng filter chặn (mode 3/4).**
`ww_validBuy = false`, `ww_blockedBuy = true`; marker xám chỉ hiện khi `ww_showDebug = true`. Không có
tín hiệu, không alert tín hiệu. Đây là “blocked”, không phải “chưa xảy ra”; EA không được biến nó thành
tín hiệu trễ ở nến sau.

## 6. Hành vi alert

| Cơ chế | Điều kiện | Tần suất | Đánh giá |
|---|---|---|---|
| `alertcondition(ww_signalBuy/Sell/Any)` — dòng 396–398 | Đã gate | Theo thiết lập trong hộp thoại alert | Với gate on, điều kiện chỉ đúng tại đóng nến; với gate off, “Once Per Bar” có thể phát intrabar (RP3) |
| `alert("...BUY", alert.freq_once_per_bar_close)` — dòng 404–406 | Đã gate | Một lần mỗi nến, tại đóng nến | `alert()` được gọi mỗi lần script tính; TradingView chỉ gửi ở lần tính cuối. Cần xác minh: nếu điều kiện đúng giữa nến nhưng sai lúc đóng, alert có bị huỷ hay vẫn gửi |
| `alertcondition(ww_isClimaxVol)` — dòng 401 | **Không gate** | Theo hộp thoại alert | Có thể phát intrabar; chỉ là cảnh báo VSA, không phải tín hiệu vào lệnh |

`alert()` dùng `alert.freq_once_per_bar_close` nên **không** tự tạo RP3 khi gate on; rủi ro còn lại là
hành vi huỷ alert khi điều kiện đổi trong nến (`PENDING` — kiểm tra E3).

Alert không phụ thuộc input hiển thị (`ww_showLabels`, `ww_showDebug`, màu sắc, ngôn ngữ). Tắt label
trên chart **không** tắt alert.

## 7. Hành vi strategy (chỉ mô tả, không port ở Phase 5)

Header: `pyramiding = 0`, `calc_on_order_fills = true`, `calc_on_every_tick = true`,
`process_orders_on_close = true`, commission 0.05%, slippage 0
([dòng 2](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L2)).

### 7.1 Trạng thái và reset

`ww_posEntry/Sl/Tp1/Tp2/Risk/Dir/IsLadder/isBeActive` là `var`, reset về `na/0/false` khi
`strategy.position_size == 0` ([dòng 309–327](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L309)).
Vì reset chạy **trước** khối entry, nến vừa đóng vị thế sẽ không giữ level cũ. Đây là state máy trạng thái
tuần tự, không phải hàm thuần của nến.

### 7.2 Entry

- Chỉ vào khi `strategy.position_size == 0` và `ww_signal*` đúng
  ([dòng 330–331](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L330)).
- Entry price dùng `close` của nến tín hiệu; qty = `pct/100 * strategy.equity / close`
  ([dòng 301](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L301)) → **phụ thuộc
  đường đi equity**, không tái lập được nếu equity khác.
- Với gate on + `process_orders_on_close`, lệnh được gửi tại nến tín hiệu và fill ở close nến đó.

### 7.3 Exit và RP4

- SL/TP tính từ `close`, `ww_calcAtr`, swing high/low tại nến tín hiệu.
- BE dùng `high`/`low` của nến hiện tại để kích hoạt rồi dời SL trong **cùng nến**
  ([dòng 411–414](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L411)). Đây là
  dạng RP4: mức SL mới có thể được áp cho chính nến đã tạo ra tín hiệu kích hoạt, dù về mặt thời gian mức
  đó chỉ tồn tại sau thời điểm giá chạm ngưỡng. TradingView broker emulator xử lý thứ tự này theo cách
  riêng; **không được** coi là mô hình fill chuẩn khi port.
- `Trailing SAR` cập nhật `ww_posSl` mỗi nến theo `ww_psar`, cũng có thể dời stop trong nến.
- Khối exit chỉ chạy khi `position_size > 0` (long) hoặc `< 0` (short). Câu hỏi mở: với
  `calc_on_order_fills = true`, sau khi entry fill tại close, script có tính lại **trong cùng nến** và gửi
  exit luôn không? Hai giả thuyết:
  - H1: có → SL/TP có hiệu lực ngay tại nến entry.
  - H2: không → nến entry không được bảo vệ, SL/TP chỉ có từ nến sau.
  Cần kiểm tra E5. Không được chọn một giả thuyết mà không có bằng chứng.

### 7.4 Hai lỗi logic đã biết (không port mù)

1. **Ladder + `pyramiding = 0`:** hai `strategy.entry` cùng chiều (`Long1`, `Long2`) trên cùng nến có thể
   bị từ chối lệnh thứ hai. Hành vi thực tế `PENDING` (E6).
2. **Ladder + Reversal:** `strategy.close("Long")`
   ([dòng 423](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L423),
   [dòng 453](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L453)) không khớp
   entry ID `Long1/Long2` (`Short1/Short2`), nên có thể **không đóng vị thế**. `PENDING` (E7).

Hai lỗi này chỉ ảnh hưởng Phase 7+ nếu có port execution. Phase 4/5 (indicator + signal-only EA) không bị.

## 8. Timestamp contract

Định nghĩa dùng thống nhất cho MQL5 và comparator:

| Trường | Định nghĩa | Ví dụ (M5) |
|---|---|---|
| `bar_open_time` | Thời gian mở nến, theo giờ server | `2026.10.27 20:50` |
| `bar_close_time` | `bar_open_time + TF` | `2026.10.27 20:55` |
| `signal_bar` | Nến mà điều kiện flip đúng | nến `20:50` |
| `confirmed_at` | Thời điểm tín hiệu trở nên bất biến = `bar_close_time` | `20:55:00` |
| `detected_at` | Thời điểm EA đọc được (tick đầu tiên của nến sau) | `20:55:00…20:59:59` |
| `signal_id` | `BUY` hoặc `SELL`; một tín hiệu duy nhất cho mỗi cặp `(symbol, tf, bar_open_time, signal_id)` | — |

Quy ước: **timestamp của tín hiệu là `bar_open_time`**, không phải thời điểm phát hiện. Mọi báo cáo parity
phải dùng `bar_open_time` để join; nếu join theo `detected_at` sẽ lệch một nến.

Trễ tối đa của EA: một tick trong nến kế tiếp. Nếu symbol không có tick (thị trường đóng), EA không phản
ứng cho tới tick kế tiếp — phải log `detected_at` thực tế để phân biệt “trễ do thiết kế” với “trễ do thiếu
dữ liệu”.

## 9. Chính sách MQL5 (quyết định cho Phase 3–5)

| Mã | Quyết định | Lý do |
|---|---|---|
| P1 | Indicator chỉ phát tín hiệu trên **nến đã đóng**; tại index `j == rates_total-1`, buffer tín hiệu = `0.0` | Loại RP1/RP2 ở nguồn; khi nến mới xuất hiện, index cũ được tính lại với `j < rates_total-1` và chốt giá trị |
| P2 | EA chỉ đọc `shift = 1`; không có input đọc `shift = 0` | Loại RP3; khớp mặc định roadmap |
| P3 | **Không port** `confirmOnClose = false` | Chế độ đó repaint theo thiết kế; port sẽ tạo RP1 và không thể parity. Ghi thành khác biệt D16 ở Phase 3, không âm thầm đổi logic |
| P4 | Tín hiệu là **edge event**, không phải “điều kiện còn đúng” | `buyFlip`/`sellFlip`/`crossover` đều là chuyển trạng thái; MQL5 giữ nguyên cấu trúc, không đổi thành so sánh mức |
| P5 | `blockedBuy/blockedSell` là debug, EA bỏ qua | Không phải tín hiệu; tránh biến blocked thành entry trễ |
| P6 | Dedupe theo `(symbol, timeframe, bar_open_time, signal_id)` + chốt `last_processed_bar_time` | Một sự kiện mỗi nến, kể cả khi EA nhận nhiều tick hoặc bị reload |
| P7 | Không alert/notification; chỉ journal + CSV trong `MQL5/Files` | Không có API thông báo, không phụ thuộc dịch vụ ngoài |
| P8 | Không port SL/TP/BE/trailing/equity sizing | EA Phase 5 là signal-only; execution là phase riêng, cần mô hình fill riêng |
| P9 | PSAR `EMPTY_VALUE`/`0` của MQL5 phải map thành “chưa có giá trị” và giữ `dir` cũ | Khớp nhánh `if not na(ww_psar)` của Pine |
| P10 | So sánh dấu dùng `<` nghiêm ngặt; bằng nhau → bearish | Khớp ternary dòng 173 |

## 10. Kế hoạch xác minh thực nghiệm (thủ công, TradingView)

Agent không mở TradingView và không tạo alert thật. Người dùng thực hiện và ghi kết quả vào bảng dưới.
Không đánh dấu PASS nếu chưa có quan sát.

| # | Bước | Kỳ vọng | Trạng thái |
|---|---|---|---|
| E1 | `Wonderwhales.pine`, EURUSD M5, `confirmOnClose = true`, Bar Replay từng tick | Không marker trước tick cuối; marker xuất hiện tại đóng nến và giữ nguyên khi replay tiếp | `PENDING` |
| E2 | Cùng cấu hình, `confirmOnClose = false`, Bar Replay | Ghi lại các nến có marker xuất hiện rồi mất; đếm số lần | `PENDING` |
| E3 | Alert “Wonderwhales BUY”, tần suất “Once Per Bar” + gate on; sau đó gate off | Gate on: không phát trước đóng nến. Gate off: ghi nhận có/không phát intrabar; kiểm tra `alert()` có bị huỷ khi điều kiện sai lúc đóng | `PENDING` |
| E4 | Backtest variant, gate on vs gate off trên cùng khoảng dữ liệu | Gate on: mọi entry tại close nến tín hiệu. Gate off: danh sách trade **giống hệt** gate on (vì lịch sử luôn confirmed) — nếu khác, ghi lại | `PENDING` |
| E5 | Backtest, một trade bất kỳ, xem thời điểm SL/TP đầu tiên so với nến entry | Xác định H1 hay H2 ở mục 7.3 | `PENDING` |
| E6 | Ladder + `pyramiding = 0`, một tín hiệu | Kiểm tra có 1 hay 2 entry được chấp nhận | `PENDING` |
| E7 | Ladder + `Reversal (SAR Flip)` | Kiểm tra vị thế có thực sự đóng khi flip ngược | `PENDING` |
| E8 | Bar Replay, nến PSAR hợp lệ đầu tiên | Không có marker BUY/SELL tại nến đó | `PENDING` |

Khi có kết quả, cập nhật cột trạng thái thành `PASS`/`FAIL` kèm symbol, timeframe, khoảng thời gian và
build/ngày của TradingView. Không suy diễn kết quả từ tài liệu thay cho quan sát.

## 11. Findings và risk register

| ID | Phát hiện | Mức | Xử lý |
|---|---|---|---|
| R1 | `confirmOnClose = false` repaint theo thiết kế và không thể phát hiện bằng backtest | Cao | P3: không port; ghi thành khác biệt |
| R2 | PSAR/`ww_sarDir` thay đổi trong nến | Trung bình | P1/P2: chỉ phát trên nến đóng |
| R3 | `alertcondition(VSA climax)` không gate | Thấp | Không port alert; VSA chỉ hiển thị |
| R4 | BE/trailing dời SL trong nến và có thể được áp ngược cho chính nến đó | Cao (nếu port execution) | P8: không port ở Phase 5; nếu port sau, mô hình fill riêng |
| R5 | Chưa rõ exit có hiệu lực ngay nến entry (`calc_on_order_fills`) | Trung bình | E5; không giả định |
| R6 | Ladder + `pyramiding = 0` có thể mất một nửa vị thế | Cao (nếu port execution) | E6; không port mù |
| R7 | Ladder + Reversal có thể không đóng được vị thế | Cao (nếu port execution) | E7; không port mù |
| R8 | Qty phụ thuộc `strategy.equity` → đường đi | Trung bình | Chỉ ảnh hưởng backtest; ghi rõ khi so sánh |
| R9 | Tín hiệu đầu tiên bị bỏ qua do `dir[1] = 0` | Thấp | Giữ nguyên; ghi vào warm-up contract |
| R10 | `psar == close` xếp vào bearish | Thấp | P10; test vector biên |

Không có phát hiện nào cho thấy tín hiệu **lịch sử** thay đổi sau khi nến đóng khi `confirmOnClose = true`.
Đó là điều kiện cần để Phase 3 chốt contract.

## 12. Gate 2 — tiêu chí nghiệm thu

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B14 | Trả lời đủ 7 câu hỏi bắt buộc của roadmap Phase 2 | PASS | Mục 2–5 |
| B15 | Định nghĩa timestamp và confirmed state cho từng signal | PASS | Mục 8 |
| B16 | Ma trận repaint theo thành phần | PASS | Mục 4 |
| B17 | Chính sách MQL5 không âm thầm đổi logic Pine | PASS | P1–P10, đặc biệt P3 |
| B18 | Không tuyên bố đã kiểm chứng runtime TradingView | PASS | Toàn bộ E1–E8 `PENDING` |
| B19 | Không tạo MQL5/EA, không sửa Pine | PASS | Chỉ tạo tài liệu này |

**Kết luận:** Gate 2 đạt ở mức **phân tích tĩnh**. Các kết luận phụ thuộc broker emulator/alert runtime
(R4–R7) vẫn `PENDING` và không được dùng làm cơ sở cho parity hoặc cho tuyên bố backtest.

## 13. Câu hỏi còn mở

1. `alert()` với `freq_once_per_bar_close` có bị huỷ khi điều kiện đúng giữa nến nhưng sai lúc đóng? (E3)
2. Exit có hiệu lực ngay nến entry khi `calc_on_order_fills = true`? (E5)
3. Hai entry ladder có cùng tồn tại với `pyramiding = 0`? (E6)
4. `strategy.close("Long")` có đóng `Long1/Long2`? (E7)
5. Nến PSAR hợp lệ đầu tiên trên từng symbol/timeframe là nến nào? Ảnh hưởng warm-up parity.
6. Symbol/timeframe chuẩn cho parity vẫn chưa chốt (blocker 9 của `PROGRESS.md`).
