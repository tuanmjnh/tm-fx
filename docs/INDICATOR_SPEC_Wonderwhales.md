# Indicator Spec — Wonderwhales (Pine v6 → MQL5)

- **Phase:** 1 — Kiểm kê và đặc tả (chưa port, chưa tạo EA)
- **Ngày:** 2026-10-28
- **Trạng thái chuyển đổi:** `PORTABLE_WITH_DIFFERENCES` (PWD)
- **Target đã chốt:** `Wonderwhales` — họ đơn giản nhất trong inventory: không `request.security`,
  không mảng, không vòng lặp, không pivot, không offset âm.
- **Source gốc (chỉ đọc):** `D:\Applications\tm-trading\pine` — không file nào bị sửa.

## 1. File tham chiếu và biến thể

| Vai trò | File | Loại | Dòng | SHA-256 (rút gọn) |
|---|---|---|---:|---|
| **Reference signal** | [`dist/Wonderwhales.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales.pine) | `indicator()`, overlay = false | 415 | `0529d7b9…d61b9` |
| Biến thể hiển thị | [`dist/Wonderwhales Overlay.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Overlay.pine) | `indicator()`, overlay = true | 417 | `75131c44…51ff` |
| **Reference execution** | [`dist/Wonderwhales Backtest.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine) | `strategy()`, overlay = true | 614 | `e7c15e1a…4910` |

Kết luận sau khi diff hai bản indicator:

- Phần tính toán và tín hiệu **giống hệt** (cùng dòng, cùng công thức).
- `Wonderwhales Overlay.pine` khác đúng 3 điểm: `overlay = true`, bỏ 2 plot volume ở pane phụ, thêm
  `plotcandle` tô nến theo `ww_sarDir`, và metadata. **Không** khác tín hiệu.
- Vì vậy `Wonderwhales.pine` là reference cho signal; `Overlay` chỉ là biến thể render.
- `Wonderwhales Backtest.pine` = indicator + khối strategy execution (`45_strategy_exec.pine`). Đây là
  **nguồn tham chiếu hành vi backtest**, không phải lệnh thật và không được port thành API gửi lệnh.

Metadata chung: Pine `//@version=6`, script version `1.2.0`, build `2026-10-27T12:32:33Z`,
`max_labels_count = 500`, `max_lines_count = 500`, `max_bars_back = 1000`.

**License:** không có header license/copyright trong file. Chỉ dùng nội bộ để nghiên cứu/port; cần người
dùng xác nhận quyền sử dụng trước khi phân phối.

## 2. Mục đích và vị trí hiển thị

- **Mục đích:** phát tín hiệu đảo chiều Parabolic SAR (mặc định), tùy chọn lọc bằng EMA 20/50 và ATR%,
  kèm VSA volume, RSI, EMA200, Bollinger Bands và HUD.
- **Indicator:** `overlay = false` → chạy ở pane phụ; các thành phần giá dùng `force_overlay = true`
  để vẽ đè lên chart giá.
- **Backtest strategy:** `overlay = true` → chạy trực tiếp trên chart giá.
- **Không phải:** bot giao dịch, không kết nối broker, không quản lý vốn thật. Khối strategy chỉ mô phỏng
  trong TradingView.

## 3. Inputs — indicator (37 input)

Nguồn: [`parts-wonderwhales/10_config.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/10_config.pine),
dòng 72–122 trong dist. Mọi input đều `display = display.none` ở indicator (không hiện trên status line).

### 3.1 Parabolic SAR (dòng 72–74)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 1 | Initial Acceleration Factor | float | 0.02 | 0.001 / 0.005 | AF khởi tạo của PSAR |
| 2 | Increment | float | 0.02 | 0.001 / 0.005 | Bước tăng AF khi có extreme mới |
| 3 | Maximum Acceleration Factor | float | 0.2 | 0.01 / 0.05 | Trần AF |

Guard: `psarMaxSafe = math.max(ww_psarStart, ww_psarMax)` — nếu max < start thì dùng start.

### 3.2 Signal Settings (dòng 77–79)

| # | Input | Kiểu | Default | Options | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 4 | Signal Mode | string | `Parabolic SAR Reversal` | 4 mode (mục 6) | Chọn nguồn tín hiệu |
| 5 | Confirm signals on bar close | bool | `true` | — | Chỉ chốt tín hiệu khi `barstate.isconfirmed` |
| 6 | Label Language | string | `EN (BUY/SELL)` | `EN (BUY/SELL)`, `CN (买/卖)` | Chữ trên label |

### 3.3 Volume VSA — display (dòng 82–91)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 7 | Show VSA Volume Pane | bool | `true` | — | Vẽ histogram volume |
| 8 | Show Volume MA Line | bool | `true` | — | Vẽ SMA volume |
| 9 | Color Bars by VSA Volume | bool | `false` | — | Tô nến theo 6 bucket |
| 10 | Show VSA Climax Markers | bool | `false` | — | Marker tại volume climax |
| 11 | Volume MA Length | int | 20 | 1 / — | Chu kỳ SMA volume |
| 12 | Climax / Spike Ratio | float | 2.5 | 1.0 / 0.1 | Ngưỡng tím |
| 13 | Very High Ratio | float | 2.0 | 1.0 / 0.1 | Ngưỡng đỏ |
| 14 | High Ratio | float | 1.5 | 1.0 / 0.1 | Ngưỡng cam |
| 15 | Normal Ratio | float | 1.0 | 0.5 / 0.1 | Ngưỡng xanh lá |
| 16 | Low Ratio | float | 0.5 | 0.1 / 0.1 | Ngưỡng xanh dương; dưới nữa là bạc |

Guard: `volMaLenSafe = math.max(1, ww_volMaLen)`.

**VSA chỉ để hiển thị.** Không mode tín hiệu nào dùng volume làm cổng. `ww_isClimaxVol` chỉ dùng cho
marker và alert phụ.

### 3.4 EMA filter (dòng 94–96)

| # | Input | Kiểu | Default | Min | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 17 | Fast EMA Length | int | 20 | 1 | EMA nhanh |
| 18 | Slow EMA Length | int | 50 | 2 | EMA chậm, phải > fast |
| 19 | Show Fast/Slow EMA Lines | bool | `false` | — | Vẽ EMA lên chart giá |

Guard: `fastEmaSafe = max(1, fast)`, `slowEmaSafe = max(fastSafe + 1, slow)`.

### 3.5 ATR volatility filter (dòng 99–101)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 20 | ATR Length | int | 14 | 1 / — | Chu kỳ ATR |
| 21 | Minimum ATR as % of Price | float | 0.5 | 0.01 / 0.1 | Chặn tín hiệu khi ATR% thấp |
| 22 | Show Blocked Signals (Debug) | bool | `false` | — | Marker xám cho tín hiệu bị chặn |

Guard: `atrLenSafe = max(1, atr)`.

### 3.6 Secondary indicators — display (dòng 104–108)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 23 | Show 200 EMA Baseline | bool | `false` | — | EMA200 |
| 24 | 200 EMA Length | int | 200 | 10 / — | Chu kỳ EMA200 |
| 25 | Show Bollinger Bands | bool | `false` | — | BB trên chart giá |
| 26 | BB Length | int | 20 | 1 / — | Chu kỳ BB |
| 27 | BB StdDev Multiplier | float | 2.0 | 0.1 / 0.1 | Hệ số độ lệch chuẩn |

Guard: `ema200Safe = max(10, len)`, `bbLenSafe = max(1, len)`.

### 3.7 Visual settings (dòng 111–116)

| # | Input | Kiểu | Default | Options | Ghi chú |
|---|---|---|---:|---|---|
| 28 | Show SAR Trend Candles | bool | `true` | — | **Không dùng** trong indicator (chỉ dùng ở Overlay/Backtest) |
| 29 | Show Parabolic SAR | bool | `true` | — | Plot PSAR dạng cross |
| 30 | PSAR Color | color | `rgb(234, 91, 247)` | — | Màu PSAR |
| 31 | Show Buy/Sell Labels | bool | `true` | — | Bật/tắt label |
| 32 | Signal Icon Style | string | `Triangle` | `Triangle`, `Compact Label` | Hình thức label |
| 33 | Signal Size | string | `Tiny` | `Tiny`, `Small`, `Normal` | Kích thước label |

### 3.8 HUD dashboard (dòng 119–122)

| # | Input | Kiểu | Default | Options | Ghi chú |
|---|---|---|---:|---|---|
| 34 | Show HUD Dashboard | bool | `false` | — | Bảng 2×7 |
| 35 | Dashboard Position | string | `Top Right` | 4 vị trí | Neo bảng |
| 36 | Dashboard Text Size | string | `Small` | `Tiny`, `Small`, `Normal` | Cỡ chữ |
| 37 | RSI Length for HUD | int | 14 | min 1 | Chu kỳ RSI |

## 4. Công thức (dùng chung cho indicator và backtest)

Nguồn: [`30_calc.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/30_calc.pine),
dist dòng 167–215.

### 4.1 Parabolic SAR và trạng thái hướng

```pine
ww_psar = ta.sar(ww_psarStart, ww_psarInc, psarMaxSafe)

var int ww_sarDir = 0
if not na(ww_psar)
    ww_sarDir := ww_psar < close ? 1 : -1

ww_sarBull = ww_sarDir == 1      // SAR dưới close
ww_sarBear = ww_sarDir == -1     // SAR trên close (hoặc bằng)

ww_buyFlip  = ww_sarBull and ww_sarDir[1] == -1
ww_sellFlip = ww_sarBear and ww_sarDir[1] == 1
```

Điểm quan trọng để port đúng:

1. Hướng **không** đọc từ việc `ta.sar` tự đảo; nó được suy ra mỗi bar bằng so sánh `psar < close`.
2. `ww_sarDir` là biến `var` giữ giá trị cũ khi `psar` còn `na` (warm-up).
3. Flip là **edge detection** trên `ww_sarDir`, không phải “điều kiện còn đúng”. Mỗi lần đảo chỉ phát 1 bar.
4. Bar đầu tiên có PSAR: `ww_sarDir[1]` là 0/na nên **không** phát flip.
5. Nếu `psar == close`, hướng là `-1` (nhánh false của ternary).

### 4.2 VSA volume (display-only)

```pine
ww_vol      = nz(volume)
ww_volMa    = ta.sma(ww_vol, volMaLenSafe)
ww_volRatio = volMa > 0 and not na(volMa) ? ww_vol / ww_volMa : 0.0

ww_isClimaxVol = not na(volMa) and volMa > 0 and vol >= volMa * spikeRatio
ww_isHighVol   = not na(volMa) and volMa > 0 and vol >= volMa * highRatio
```

Bucket (thứ tự ưu tiên giảm dần): `>= 2.5×` = TIM (purple), `>= 2.0×` = VeryHigh (red),
`>= 1.5×` = High (orange), `>= 1.0×` = Normal (green), `>= 0.5×` = Low (blue), còn lại = VeryLow (silver).

### 4.3 EMA

```pine
ww_fastEma = ta.ema(close, fastEmaSafe)
ww_slowEma = ta.ema(close, slowEmaSafe)
ww_emaBull = ww_fastEma > ww_slowEma
ww_emaBear = ww_fastEma < ww_slowEma
ww_emaBuyCross  = ta.crossover(ww_fastEma, ww_slowEma)
ww_emaSellCross = ta.crossunder(ww_fastEma, ww_slowEma)
ww_ema200 = ta.ema(close, ema200Safe)
ww_aboveEma200 = close > ww_ema200
```

`ta.crossover(a, b)` = `a[1] <= b[1] and a > b`; `ta.crossunder` = `a[1] >= b[1] and a < b`.
Cả hai yêu cầu giá trị previous không `na`.

### 4.4 ATR và ATR%

```pine
ww_atr          = ta.atr(atrLenSafe)
ww_atrPct       = close > 0 and not na(ww_atr) ? (ww_atr / close) * 100.0 : 0.0
ww_volatilityOk = ww_atrPct >= ww_minAtrPct
```

`ta.atr` dùng RMA/Wilder smoothing.

### 4.5 RSI và Bollinger Bands (display-only)

```pine
ww_rsi = ta.rsi(close, rsiLenSafe)
ww_rsiOverbought = ww_rsi >= 70
ww_rsiOversold   = ww_rsi <= 30
ww_rsiBullish    = ww_rsi > 50          // không dùng trong logic tín hiệu

[ww_bbMid, ww_bbUpper, ww_bbLower] = ta.bb(close, bbLenSafe, ww_bbMult)
```

RSI và BB không tham gia bất kỳ điều kiện BUY/SELL nào.

## 5. Outputs — indicator

Nguồn: dist dòng 272–407.

### 5.1 Plots (11)

| Plot | Nguồn | Điều kiện hiển thị | Ghi chú |
|---|---|---|---|
| VSA Volume | `ww_vol` | `ww_showVol` | `style_columns`, `format.volume`, màu theo bucket |
| Volume MA | `ww_volMa` | `ww_showVolMa` | Xanh lá |
| Parabolic SAR | `ww_psar` | `ww_showPsar` | Cross, `force_overlay` |
| BUY Status | `1.0/0.0` | luôn | `status_line` |
| SELL Status | `1.0/0.0` | luôn | `status_line` |
| Fast EMA | `ww_fastEma` | `ww_showEma` | `force_overlay` |
| Slow EMA | `ww_slowEma` | `ww_showEma` | `force_overlay` |
| 200 EMA | `ww_ema200` | `ww_showEma200` | `force_overlay` |
| BB Upper | `ww_bbUpper` | `ww_showBb` | `force_overlay` |
| BB Basis | `ww_bbMid` | `ww_showBb` | `force_overlay` |
| BB Lower | `ww_bbLower` | `ww_showBb` | `force_overlay` |

### 5.2 Shapes (27 `plotshape`)

- 1 climax marker (`ww_vsaShowMarkers and ww_isClimaxVol`).
- 6 BUY triangle + 6 SELL triangle (2 ngôn ngữ × 3 size).
- 6 BUY label + 6 SELL label (2 ngôn ngữ × 3 size).
- 2 blocked debug marker (BUY/SELL).
- Tất cả shape tín hiệu đều yêu cầu `ww_showLabels` và `ww_signal*`.

### 5.3 Khác

- `barcolor(ww_vsaBarColor ? ww_volCol : na)` — mặc định tắt.
- `fill(p_bbUpper, p_bbLower)` — nền BB, chỉ khi `ww_showBb`.
- `table` HUD 2 cột × 7 hàng, tạo một lần khi `barstate.islast and ww_showDash`.
- `alertcondition` × 4: BUY, SELL, Any Signal, VSA Climax.
- `alert()` runtime × 2: BUY/SELL với `alert.freq_once_per_bar_close`.

## 6. Điều kiện tín hiệu

Nguồn: [`40_signals.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/40_signals.pine),
dist dòng 222–266.

| Mode | `rawBuy` | `rawSell` | `validBuy` | `validSell` |
|---|---|---|---|---|
| `Parabolic SAR Reversal` (default) | `ww_buyFlip` | `ww_sellFlip` | `rawBuy` | `rawSell` |
| `EMA Crossover` | `ww_emaBuyCross` | `ww_emaSellCross` | `rawBuy` | `rawSell` |
| `SAR + EMA Trend Filter` | `ww_buyFlip` | `ww_sellFlip` | `rawBuy and ww_emaBull` | `rawSell and ww_emaBear` |
| `SAR + EMA + ATR Filter` | `ww_buyFlip` | `ww_sellFlip` | `rawBuy and emaBull and atrOk` | `rawSell and emaBear and atrOk` |

Cổng xác nhận nến:

```pine
ww_barConfirmed = not ww_confirmOnClose or barstate.isconfirmed
ww_signalBuy    = ww_validBuy and ww_barConfirmed
ww_signalSell   = ww_validSell and ww_barConfirmed
```

Blocked (chỉ để debug):

- `SAR + EMA Trend Filter`: `blockedBuy = rawBuy and not emaBull`, `blockedSell = rawSell and not emaBear`.
- `SAR + EMA + ATR Filter`: `blockedBuy = rawBuy and not (emaBull and atrOk)`, tương tự cho sell.
- Blocked cũng bị gate bởi `ww_barConfirmed`.

**Không có tín hiệu EXIT/HOLD độc lập trong indicator.** Exit chỉ tồn tại trong Backtest strategy.

Hệ quả edge/level:

- Tín hiệu là **một bar duy nhất** tại thời điểm flip/cross, không giữ `true` nhiều bar.
- BUY và SELL không thể đồng thời `true` trong cùng mode (PSAR flip loại trừ nhau; EMA cross loại trừ nhau).
- Với `ww_confirmOnClose = false`, tín hiệu có thể xuất hiện rồi biến mất trong bar đang chạy (repaint).
  Đây là hành vi của input, không phải lỗi; mặc định an toàn là `true`.

## 7. Biến thể Backtest — inputs và execution semantics

Nguồn: [`45_strategy_exec.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/45_strategy_exec.pine),
dist dòng 273–471.

### 7.1 Inputs bổ sung (13, tổng 50)

| # | Input | Kiểu | Default | Min / Options | Nhóm |
|---|---|---|---:|---|---|
| 38 | Enable Auto Strategy Trading | bool | `true` | — | Strategy |
| 39 | Trade Direction | string | `Long + Short` | Long+Short / Long Only / Short Only | Strategy |
| 40 | Exit Strategy | string | `TP / SL + Auto Break-Even` | 4 mode | Strategy |
| 41 | Stop Loss Model | string | `ATR Multiplier` | ATR / PSAR Dot / Swing | Risk & Exits |
| 42 | SL ATR Multiplier | float | 1.5 | 0.5 / step 0.1 | Risk & Exits |
| 43 | Swing Lookback (Bars) | int | 5 | 2–50 | Risk & Exits |
| 44 | Take Profit 1 R:R | float | 1.5 | 0.5 / step 0.1 | Risk & Exits |
| 45 | Take Profit 2 R:R (Ladder) | float | 3.0 | 1.0 / step 0.2 | Risk & Exits |
| 46 | Enable Auto Break-Even | bool | `true` | — | Break-Even |
| 47 | Break-Even Trigger | string | `At 1.0 R:R Profit` | 3 mode | Break-Even |
| 48 | Break-Even Buffer (× ATR) | float | 0.05 | 0.0 / step 0.05 | Break-Even |
| 49 | Position Sizing (% Equity) | float | 100.0 | 1–100 / step 5 | Sizing & Display |
| 50 | Show Active TP/SL/BE Lines | bool | `true` | — | Sizing & Display |

### 7.2 Cấu hình strategy

`strategy(..., pyramiding = 0, calc_on_order_fills = true, calc_on_every_tick = true,
process_orders_on_close = true, initial_capital = 10000, commission_type = percent,
commission_value = 0.05, slippage = 0)`.

- Commission 0.05% mỗi chiều; slippage 0.
- `default_qty_type = percent_of_equity`, `default_qty_value = 100` — nhưng code truyền `qty` tường minh
  nên default này không có tác dụng.
- Không có swap, không có spread model tường minh (TradingView dùng dữ liệu broker của chart).

### 7.3 Kích thước vị thế

```pine
ww_calcAtr = nz(ww_atr, ta.atr(14))     // fallback ATR(14) literal
if na(ww_calcAtr) or ww_calcAtr <= 0.0
    ww_calcAtr := close * 0.01          // fallback cuối

ww_stratQty = (ww_strat_pct / 100.0 * strategy.equity) / close
ww_stratQtyOk = ww_stratQty > 0.0 and not na(close) and close > 0.0
```

Đây là **số đơn vị tài sản cơ sở** (equity / giá), không phải lot. MT5 cần quy đổi qua contract size,
margin, leverage; không được copy nguyên con số.

### 7.4 Entry

- Chỉ entry khi `strategy.position_size == 0` (không nhồi lệnh; `pyramiding = 0`).
- Điều kiện: `ww_strat_on and ww_stratQtyOk and ww_signalBuy and ww_allowLong and flat`.
- Giá tham chiếu: `close` của bar tín hiệu; do `process_orders_on_close = true`, lệnh market được khớp
  tại close bar đó.
- Không có stop/limit entry; không có trailing entry.

### 7.5 Stop Loss (long; short đối xứng)

| Model | Long SL | Ghi chú |
|---|---|---|
| ATR Multiplier | `close − slAtrMul × ATR` | Mặc định |
| Parabolic SAR Dot | `psar` nếu `psar < close`, ngược lại fallback ATR | Không dùng PSAR ở phía sai |
| Swing High/Low | `lowest(low, swingLen) − 0.2 × ATR` | Bao gồm low của bar hiện tại |

Sau đó:

```pine
risk = entry − rawSl
if na(risk) or risk <= 0:
    risk = slAtrMul × ATR
    rawSl = entry − risk
tp1 = entry + rr1 × risk
tp2 = entry + rr2 × risk
```

Short: `rawSl = close + …`; `risk = rawSl − entry`; `tp1/tp2 = entry − rrN × risk`.

### 7.6 Break-Even

Kích hoạt một lần (`ww_isBeActive` latch) khi giá chạm ngưỡng:

| Trigger | Long threshold | Short threshold |
|---|---|---|
| At 1.0 R:R Profit | `entry + risk` | `entry − risk` |
| At 50% TP1 Progress | `entry + 0.5 × (tp1 − entry)` | `entry − 0.5 × (entry − tp1)` |
| At 1.0× ATR Profit | `entry + ATR` | `entry − ATR` |

- Long: điều kiện `high >= threshold`; SL mới = `entry + beOffsetAtr × ATR`, rồi `SL = max(SL, beSl)`.
- Short: điều kiện `low <= threshold`; SL mới = `entry − beOffsetAtr × ATR`, rồi `SL = min(SL, beSl)`.
- Buffer mặc định 0.05×ATR nhằm bù phí/slippage.
- BE không hạ SL nếu SL hiện tại đã tốt hơn.

### 7.7 Exit modes

| Mode | Cơ chế | SL/TP có hiệu lực? | Ghi chú |
|---|---|---|---|
| `TP / SL + Auto Break-Even` (default) | 1 `strategy.exit` với `stop` + `limit = tp1` | Có | BE dời stop |
| `Ladder 50/50 (TP1 BE + TP2)` | 2 entry `Long1/Long2` (50/50), 2 exit riêng: TP1/TP2, SL chung | Có | Xem cảnh báo bên dưới |
| `Trailing SAR` | SL cập nhật `max(SL, psar)` long / `min(SL, psar)` short; vẫn có limit TP1 | Có | Trail mỗi bar |
| `Reversal (SAR Flip)` | `strategy.close("Long"/"Short")` khi có tín hiệu ngược | **Không** | Không đặt stop/limit; BE/trailing có tính nhưng không được dùng |

Cảnh báo cần xác minh (không được port mù):

1. **Ladder + `pyramiding = 0`.** Hai entry cùng chiều trong cùng bar; theo semantics TradingView,
   `pyramiding = 0` chỉ cho một entry mỗi chiều. Leg thứ hai có thể bị từ chối. Cần kiểm chứng thực nghiệm
   trước khi đặc tả 2 leg.
2. **Ladder + Reversal.** Reversal gọi `strategy.close("Long")`, nhưng entry ID là `Long1`/`Long2`.
   Lệnh close sẽ không tìm thấy entry tương ứng → vị thế không đóng. Đây là lỗi logic của bản Pine,
   không phải hành vi cần tái tạo.
3. **Reversal bỏ qua risk.** Khi chọn Reversal, SL/TP/BE/trailing không được gửi; vị thế chỉ đóng khi
   flip ngược. Mô tả UI “Only close position on opposite SAR flip” khớp, nhưng không có bảo vệ rủi ro.
4. **Mô tả Ladder sai một phần.** Tooltip nói “move remaining 50% SL to Entry” sau TP1; code thực tế dời
   SL theo **BE trigger riêng**, không phải khi TP1 hit.
5. **Stop không bảo vệ bar entry.** Entry khớp tại close bar N; stop/limit của `strategy.exit` chỉ có
   hiệu lực từ bar kế tiếp. Biến động trong chính bar entry (trước close) và gap đầu bar N+1 không được
   bảo vệ trong mô phỏng. MQL5 phải ghi rõ giả định này nếu mô phỏng lại execution.

### 7.8 Reset state

Khi `strategy.position_size == 0`, toàn bộ `ww_posEntry/Sl/Tp1/Tp2/Risk/Dir`, `ww_isBeActive`,
`ww_isLadder` được reset. Điều này xảy ra trước khối entry trong cùng lần tính.

### 7.9 Fills và intrabar

- `process_orders_on_close = true`: market entry/close khớp tại close bar.
- `calc_on_every_tick = true` + `calc_on_order_fills = true`: script tính lại mỗi tick và sau mỗi fill;
  stop/limit của `strategy.exit` được cập nhật trong bar.
- Với OHLC modeling, thứ tự high/low trong bar là giả định của broker emulator. Nếu SL và TP cùng bị
  chạm trong một bar, kết quả phụ thuộc giả định đó — phải ghi rõ khi mô phỏng lại.
- `strategy.equity` dao động intrabar → `qty` cũng có thể đổi giữa các tick; giá trị cuối cùng tại close
  mới là giá trị dùng để khớp.

### 7.10 Outputs bổ sung của Backtest

- 4 plot level: Entry, TP1, TP2, SL/BE (`style_linebr`, chỉ hiện khi có vị thế và `ww_strat_showLines`).
- `plotcandle` tô nến theo `ww_sarDir` khi `ww_showTrendCandles`.
- Không có `alertcondition`; chỉ có 2 `alert()` runtime giống indicator.

## 8. Phụ thuộc

| Nhóm | Sử dụng | Ghi chú port |
|---|---|---|
| `ta.sar` | PSAR | Cần parity test với `iSAR` |
| `ta.sma` | Volume MA | Chỉ display |
| `ta.ema` | Fast/Slow/200 | Seed khác MT5 |
| `ta.crossover/crossunder` | EMA mode | Có thể tự viết edge detection |
| `ta.atr` | ATR, ATR% | Wilder/RMA |
| `ta.rsi` | HUD | Display |
| `ta.bb` | BB | Display |
| `ta.lowest/highest` | Swing SL | Backtest only |
| `math.max/min` | Guards, SL | Trực tiếp |
| `barstate.isconfirmed` | Signal gate | Map sang “bar đã đóng” |
| `barstate.islast` | HUD | Map sang lần tính cuối |
| `var` | `sarDir`, trade state | Map sang static/global |
| `volume` | VSA | MT5: `tick_volume` gần nhất; `real_volume` thường 0 |
| `time(timeframe.period, session, tz)` | Helper session | **Không dùng** trong logic |
| `str.*`, `table.*`, `color.*` | Text/HUD | Không cần cho signal |

Không có: `request.security`, `request.security_lower_tf`, mảng, vòng lặp, pivot/fractal, offset âm,
external library, `lookahead`.

Hàm khai báo nhưng không dùng trong logic: `f_sessionOk`, `f_sessAsia/London/Ny/Name`, `f_isNewDay`,
`f_clamp`, `f_fmtPx`, `f_ts`, `f_sym`. Biến không dùng cho quyết định: `ww_showTrendCandles` (indicator),
`ww_isHighVol`, `ww_rsiBullish`, `ww_posDir` (backtest).

## 9. Realtime, repaint và warm-up (sơ bộ — Phase 2 xác minh)

| Thành phần | Có thể đổi trong bar? | Mặc định | Ghi chú |
|---|---|---|---|
| `ww_signalBuy/Sell` | Có nếu `confirmOnClose=false` | Chỉ confirmed | `barstate.isconfirmed` |
| `ww_sarDir` / flip | Có intrabar (close đổi phía SAR) | Chốt ở close | Cần test dao động intrabar |
| PSAR dots | Có intrabar | — | Display |
| EMA/ATR/RSI/BB | Có intrabar | — | Chỉ ảnh hưởng signal khi confirmed |
| VSA volume | Có intrabar | — | Display; volume chốt ở close |
| HUD | Chỉ last bar | — | `barstate.islast` |
| Strategy levels | Có intrabar | — | BE/trailing cập nhật |
| Alerts | `freq_once_per_bar_close` | — | Không phụ thuộc input confirm |

Warm-up tối thiểu:

- PSAR: cần ≥ 2 bar để có giá trị; flip cần thêm 1 bar previous → tín hiệu sớm nhất khoảng bar thứ 3.
- ATR(14): có giá trị đầy đủ sau ~15 bar (Wilder).
- EMA(50): có giá trị từ bar đầu nhưng chỉ ổn định sau ~3–5× chu kỳ.
- SMA(20) volume: đủ sau 20 bar.
- RSI(14): ~15 bar; BB(20): 20 bar.
- EMA200: cần ~200 bar để có ý nghĩa; BB/RSI/EMA200 chỉ display.
- Backtest swing SL: cần `swingLen` bar.

Đề xuất cho EA Phase 5: không đánh giá tín hiệu trước `max(warmup) + 2` bar; mặc định dùng
300 bar warm-up để đồng nhất với Pine khi so sánh.

## 10. Khác biệt Pine → MQL5 dự kiến

| # | Chủ đề | Pine | MQL5 / MT5 | Quyết định Phase 3 |
|---|---|---|---|---|
| D1 | PSAR | `ta.sar(start, inc, max)` | `iSAR(symbol, tf, step, max, price)` | So khớp từng bar; ghi rõ bar đầu |
| D2 | EMA seed | Seed bằng giá trị đầu | `iMA` seed khác | Parity test; có thể tự cài EMA |
| D3 | ATR | Wilder/RMA | `iATR` Wilder | So khớp warm-up |
| D4 | RSI | Wilder | `iRSI` Wilder | Display, tolerance rộng |
| D5 | BB | SMA + population stdev | `iBands` | Display |
| D6 | Volume | Volume sàn (forex = tick) | `tick_volume` / `real_volume` | Chọn `tick_volume`; VSA không phải gate |
| D7 | Fill timing | Close bar do `process_orders_on_close` | Next tick / next bar open | Signal-only EA log theo confirmed bar; mô phỏng ghi rõ giả định |
| D8 | Sizing | Equity / close (đơn vị tài sản) | Lot × contract size × margin | Không port nguyên; dùng virtual portfolio |
| D9 | Intrabar SL/TP | Broker emulator, OHLC path | Tick hoặc OHLC tùy modeling | Ghi rõ tie-break |
| D10 | Ladder | 2 entry cùng bar, `pyramiding=0` | Partial position | Chờ xác minh Pine; nếu không hợp lệ, đặc tả 1 vị thế + 2 TP |
| D11 | Reversal | `strategy.close("Long")` | Close toàn bộ vị thế | Sửa lỗi ID; không tái tạo lỗi |
| D12 | Commission | 0.05% mỗi chiều | Commission/swap/ spread | Mô phỏng riêng, không thuộc indicator |
| D13 | Timezone | UTC/exchange time | Server time broker | Chuẩn hóa timestamp khi so sánh |
| D14 | History | `max_bars_back=1000` | Giới hạn history terminal | Warm-up 300 bar; kiểm tra `BarsCalculated` |
| D15 | Alerts | `freq_once_per_bar_close` | Không có alert native | EA tự chống trùng theo bar time |
| D16 | `confirmOnClose = false` | Tín hiệu bật/tắt trong nến (RP1) | Không port; chỉ hỗ trợ chế độ confirmed | Ghi nhận là `NOT_PORTED`, không âm thầm đổi logic |
| D17 | Render | Pane phụ + PSAR đổi màu + 27 shape + HUD | Chart window, 3 plot, PSAR một màu | Chỉ giữ PSAR + 2 mũi tên; oscillator vẫn có trong buffer |
| D18 | Volume MA | `ta.sma(volume, n)` | SMA thủ công trên `tick_volume` | Không có `iMA` cho volume; tính từ `MqlRates` |

## 11. Trạng thái portability

**`PORTABLE_WITH_DIFFERENCES`** — lý do:

- Toàn bộ signal core dùng indicator chuẩn, không MTF, không cấu trúc dữ liệu phức tạp → port được.
- Khác biệt bắt buộc: seed PSAR/EMA/ATR, volume type, fill timing, sizing, intrabar SL/TP, timezone.
- Khối strategy có 2 lỗi logic (Ladder + pyramiding, Ladder + Reversal) **không được port nguyên**.
- Không port phần HUD/table/label/color sang chỉ báo MQL5 trừ khi cần cho visual tester; ưu tiên buffer
  tín hiệu.

## 12. Signal ID và buffer contract (đã chốt ở Phase 3)

| Signal ID | Điều kiện | Bar policy |
|---|---|---|
| `WW_BUY_SAR_FLIP` | `buyFlip` | Confirmed bar |
| `WW_SELL_SAR_FLIP` | `sellFlip` | Confirmed bar |
| `WW_BUY_EMA_CROSS` | `emaBuyCross` | Confirmed bar |
| `WW_SELL_EMA_CROSS` | `emaSellCross` | Confirmed bar |
| `WW_BUY_SAR_EMA` | `buyFlip and emaBull` | Confirmed bar |
| `WW_SELL_SAR_EMA` | `sellFlip and emaBear` | Confirmed bar |
| `WW_BUY_SAR_EMA_ATR` | `buyFlip and emaBull and atrOk` | Confirmed bar |
| `WW_SELL_SAR_EMA_ATR` | `sellFlip and emaBear and atrOk` | Confirmed bar |
| `WW_BLOCKED_BUY` | raw buy bị chặn bởi EMA/ATR | Confirmed bar |
| `WW_BLOCKED_SELL` | raw sell bị chặn bởi EMA/ATR | Confirmed bar |

Draft buffer (đã chốt ở Phase 3 — xem [`BUFFER_CONTRACT_Wonderwhales.md`](BUFFER_CONTRACT_Wonderwhales.md)
cho định nghĩa đầy đủ, missing value và test vector):

| Buffer | Nội dung | Giá trị thiếu | Plot |
|---:|---|---|---|
| 0 | PSAR | `EMPTY_VALUE` | line |
| 1 | BUY marker (giá `low` của nến tín hiệu) | `EMPTY_VALUE` | arrow |
| 2 | SELL marker (giá `high` của nến tín hiệu) | `EMPTY_VALUE` | arrow |
| 3 | BUY signal (1/0, chỉ nến đã đóng) | `0` | — |
| 4 | SELL signal (1/0, chỉ nến đã đóng) | `0` | — |
| 5 | SAR direction (+1/−1/0) | `0` | — |
| 6 | Blocked BUY (1/0) | `0` | — |
| 7 | Blocked SELL (1/0) | `0` | — |
| 8 | ATR% | `0` (đúng theo Pine) | — |
| 9 | Fast EMA | `EMPTY_VALUE` | — |
| 10 | Slow EMA | `EMPTY_VALUE` | — |
| 11 | EMA200 | `EMPTY_VALUE` | — |
| 12 | RSI | `EMPTY_VALUE` | — |
| 13 | BB upper | `EMPTY_VALUE` | — |
| 14 | BB middle | `EMPTY_VALUE` | — |
| 15 | BB lower | `EMPTY_VALUE` | — |
| 16 | Volume MA | `EMPTY_VALUE` | — |
| 17 | Volume ratio | `0` | — |

Buffer 3/4/6/7 **luôn** `0` tại nến đang chạy (`j == rates_total-1`); EA chỉ đọc `shift = 1`. Không dùng
`0` làm đại diện missing cho PSAR/EMA/RSI/BB/Volume MA; dùng `EMPTY_VALUE`. `0` là giá trị hợp lệ của
`SAR_DIR`, `ATR_PCT`, `VOL_RATIO` và các buffer tín hiệu.

## 13. Câu hỏi mở và blocker

1. **License:** cần xác nhận quyền sử dụng source trước khi phân phối. Hiện chỉ port nội bộ.
2. **Reference CSV (Phase 6):** chưa có export từ Pine. Cần người dùng xuất dữ liệu trên cùng
   symbol/timeframe/timezone/input (gợi ý: dùng Data Window hoặc export chart data cho các plot
   `BUY Status`, `SELL Status`, PSAR, EMA, ATR%, RSI). Chưa có → comparison là `BLOCKED`.
3. **Symbol/timeframe chuẩn:** chưa chốt (XAUUSD? EURUSD? M5? H1?). Ảnh hưởng trực tiếp đến parity.
4. **Pyramiding + Ladder:** cần kiểm chứng trên TradingView xem leg thứ hai có khớp không.
5. **Ladder + Reversal:** cần quyết định hành vi đúng (đóng cả 2 leg? chỉ leg 1?) — không port lỗi.
6. **Phạm vi port:** Phase 5 EA là signal-only theo roadmap. Có cần port toàn bộ execution semantics
   (BE/trailing/ladder) vào một module mô phỏng riêng, hay chỉ giữ làm tài liệu tham chiếu?
7. **Volume type:** `tick_volume` là lựa chọn đề xuất; cần xác nhận dữ liệu broker có `real_volume`.
8. **Backtest hay indicator là chuẩn:** tín hiệu giống nhau, nhưng nếu người dùng dùng Backtest làm chuẩn
   thì cần đối chiếu thêm thời điểm fill.

## 14. Việc tiếp theo

- **Phase 2:** hoàn tất — xem [`REPAINT_AUDIT_Wonderwhales.md`](REPAINT_AUDIT_Wonderwhales.md).
- **Phase 3:** hoàn tất — buffer contract 18 kênh, input contract, test vector A–E tại
  [`BUFFER_CONTRACT_Wonderwhales.md`](BUFFER_CONTRACT_Wonderwhales.md).
- **Phase 4:** viết custom indicator MQL5 trong `MQL5/Indicators/PinePort/` khi được yêu cầu.
- **Phase 5:** `PineSignalLabEA.mq5` signal-only, không có API gửi lệnh.

Tham chiếu: [`pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md`](pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md),
[`PINE_INVENTORY.md`](PINE_INVENTORY.md), [`PROGRESS.md`](PROGRESS.md).
