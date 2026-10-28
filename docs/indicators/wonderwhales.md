# Wonderwhales — Spec, Repaint Audit và Buffer Contract

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `INDICATOR_SPEC_Wonderwhales.md`, `REPAINT_AUDIT_Wonderwhales.md`, `BUFFER_CONTRACT_Wonderwhales.md`.

Nội dung:
1. Indicator Spec — Wonderwhales (Pine v6 → MQL5)
2. Repaint Audit — Wonderwhales (Pine v6)
3. Buffer Contract — Wonderwhales (Pine v6 → MQL5)

---
## Indicator Spec — Wonderwhales (Pine v6 → MQL5)

- **Phase:** 1 — Kiểm kê và đặc tả (chưa port, chưa tạo EA)
- **Ngày:** 2026-10-28
- **Trạng thái chuyển đổi:** `PORTABLE_WITH_DIFFERENCES` (PWD)
- **Target đã chốt:** `Wonderwhales` — họ đơn giản nhất trong inventory: không `request.security`,
  không mảng, không vòng lặp, không pivot, không offset âm.
- **Source gốc (chỉ đọc):** `D:\Applications\tm-trading\pine` — không file nào bị sửa.

### 1. File tham chiếu và biến thể

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

### 2. Mục đích và vị trí hiển thị

- **Mục đích:** phát tín hiệu đảo chiều Parabolic SAR (mặc định), tùy chọn lọc bằng EMA 20/50 và ATR%,
  kèm VSA volume, RSI, EMA200, Bollinger Bands và HUD.
- **Indicator:** `overlay = false` → chạy ở pane phụ; các thành phần giá dùng `force_overlay = true`
  để vẽ đè lên chart giá.
- **Backtest strategy:** `overlay = true` → chạy trực tiếp trên chart giá.
- **Không phải:** bot giao dịch, không kết nối broker, không quản lý vốn thật. Khối strategy chỉ mô phỏng
  trong TradingView.

### 3. Inputs — indicator (37 input)

Nguồn: [`parts-wonderwhales/10_config.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/10_config.pine),
dòng 72–122 trong dist. Mọi input đều `display = display.none` ở indicator (không hiện trên status line).

#### 3.1 Parabolic SAR (dòng 72–74)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 1 | Initial Acceleration Factor | float | 0.02 | 0.001 / 0.005 | AF khởi tạo của PSAR |
| 2 | Increment | float | 0.02 | 0.001 / 0.005 | Bước tăng AF khi có extreme mới |
| 3 | Maximum Acceleration Factor | float | 0.2 | 0.01 / 0.05 | Trần AF |

Guard: `psarMaxSafe = math.max(ww_psarStart, ww_psarMax)` — nếu max < start thì dùng start.

#### 3.2 Signal Settings (dòng 77–79)

| # | Input | Kiểu | Default | Options | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 4 | Signal Mode | string | `Parabolic SAR Reversal` | 4 mode (mục 6) | Chọn nguồn tín hiệu |
| 5 | Confirm signals on bar close | bool | `true` | — | Chỉ chốt tín hiệu khi `barstate.isconfirmed` |
| 6 | Label Language | string | `EN (BUY/SELL)` | `EN (BUY/SELL)`, `CN (买/卖)` | Chữ trên label |

#### 3.3 Volume VSA — display (dòng 82–91)

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

#### 3.4 EMA filter (dòng 94–96)

| # | Input | Kiểu | Default | Min | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 17 | Fast EMA Length | int | 20 | 1 | EMA nhanh |
| 18 | Slow EMA Length | int | 50 | 2 | EMA chậm, phải > fast |
| 19 | Show Fast/Slow EMA Lines | bool | `false` | — | Vẽ EMA lên chart giá |

Guard: `fastEmaSafe = max(1, fast)`, `slowEmaSafe = max(fastSafe + 1, slow)`.

#### 3.5 ATR volatility filter (dòng 99–101)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 20 | ATR Length | int | 14 | 1 / — | Chu kỳ ATR |
| 21 | Minimum ATR as % of Price | float | 0.5 | 0.01 / 0.1 | Chặn tín hiệu khi ATR% thấp |
| 22 | Show Blocked Signals (Debug) | bool | `false` | — | Marker xám cho tín hiệu bị chặn |

Guard: `atrLenSafe = max(1, atr)`.

#### 3.6 Secondary indicators — display (dòng 104–108)

| # | Input | Kiểu | Default | Min / Step | Tooltip (tóm tắt) |
|---|---|---|---:|---|---|
| 23 | Show 200 EMA Baseline | bool | `false` | — | EMA200 |
| 24 | 200 EMA Length | int | 200 | 10 / — | Chu kỳ EMA200 |
| 25 | Show Bollinger Bands | bool | `false` | — | BB trên chart giá |
| 26 | BB Length | int | 20 | 1 / — | Chu kỳ BB |
| 27 | BB StdDev Multiplier | float | 2.0 | 0.1 / 0.1 | Hệ số độ lệch chuẩn |

Guard: `ema200Safe = max(10, len)`, `bbLenSafe = max(1, len)`.

#### 3.7 Visual settings (dòng 111–116)

| # | Input | Kiểu | Default | Options | Ghi chú |
|---|---|---|---:|---|---|
| 28 | Show SAR Trend Candles | bool | `true` | — | **Không dùng** trong indicator (chỉ dùng ở Overlay/Backtest) |
| 29 | Show Parabolic SAR | bool | `true` | — | Plot PSAR dạng cross |
| 30 | PSAR Color | color | `rgb(234, 91, 247)` | — | Màu PSAR |
| 31 | Show Buy/Sell Labels | bool | `true` | — | Bật/tắt label |
| 32 | Signal Icon Style | string | `Triangle` | `Triangle`, `Compact Label` | Hình thức label |
| 33 | Signal Size | string | `Tiny` | `Tiny`, `Small`, `Normal` | Kích thước label |

#### 3.8 HUD dashboard (dòng 119–122)

| # | Input | Kiểu | Default | Options | Ghi chú |
|---|---|---|---:|---|---|
| 34 | Show HUD Dashboard | bool | `false` | — | Bảng 2×7 |
| 35 | Dashboard Position | string | `Top Right` | 4 vị trí | Neo bảng |
| 36 | Dashboard Text Size | string | `Small` | `Tiny`, `Small`, `Normal` | Cỡ chữ |
| 37 | RSI Length for HUD | int | 14 | min 1 | Chu kỳ RSI |

### 4. Công thức (dùng chung cho indicator và backtest)

Nguồn: [`30_calc.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/30_calc.pine),
dist dòng 167–215.

#### 4.1 Parabolic SAR và trạng thái hướng

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

#### 4.2 VSA volume (display-only)

```pine
ww_vol      = nz(volume)
ww_volMa    = ta.sma(ww_vol, volMaLenSafe)
ww_volRatio = volMa > 0 and not na(volMa) ? ww_vol / ww_volMa : 0.0

ww_isClimaxVol = not na(volMa) and volMa > 0 and vol >= volMa * spikeRatio
ww_isHighVol   = not na(volMa) and volMa > 0 and vol >= volMa * highRatio
```

Bucket (thứ tự ưu tiên giảm dần): `>= 2.5×` = TIM (purple), `>= 2.0×` = VeryHigh (red),
`>= 1.5×` = High (orange), `>= 1.0×` = Normal (green), `>= 0.5×` = Low (blue), còn lại = VeryLow (silver).

#### 4.3 EMA

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

#### 4.4 ATR và ATR%

```pine
ww_atr          = ta.atr(atrLenSafe)
ww_atrPct       = close > 0 and not na(ww_atr) ? (ww_atr / close) * 100.0 : 0.0
ww_volatilityOk = ww_atrPct >= ww_minAtrPct
```

`ta.atr` dùng RMA/Wilder smoothing.

#### 4.5 RSI và Bollinger Bands (display-only)

```pine
ww_rsi = ta.rsi(close, rsiLenSafe)
ww_rsiOverbought = ww_rsi >= 70
ww_rsiOversold   = ww_rsi <= 30
ww_rsiBullish    = ww_rsi > 50          // không dùng trong logic tín hiệu

[ww_bbMid, ww_bbUpper, ww_bbLower] = ta.bb(close, bbLenSafe, ww_bbMult)
```

RSI và BB không tham gia bất kỳ điều kiện BUY/SELL nào.

### 5. Outputs — indicator

Nguồn: dist dòng 272–407.

#### 5.1 Plots (11)

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

#### 5.2 Shapes (27 `plotshape`)

- 1 climax marker (`ww_vsaShowMarkers and ww_isClimaxVol`).
- 6 BUY triangle + 6 SELL triangle (2 ngôn ngữ × 3 size).
- 6 BUY label + 6 SELL label (2 ngôn ngữ × 3 size).
- 2 blocked debug marker (BUY/SELL).
- Tất cả shape tín hiệu đều yêu cầu `ww_showLabels` và `ww_signal*`.

#### 5.3 Khác

- `barcolor(ww_vsaBarColor ? ww_volCol : na)` — mặc định tắt.
- `fill(p_bbUpper, p_bbLower)` — nền BB, chỉ khi `ww_showBb`.
- `table` HUD 2 cột × 7 hàng, tạo một lần khi `barstate.islast and ww_showDash`.
- `alertcondition` × 4: BUY, SELL, Any Signal, VSA Climax.
- `alert()` runtime × 2: BUY/SELL với `alert.freq_once_per_bar_close`.

### 6. Điều kiện tín hiệu

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

### 7. Biến thể Backtest — inputs và execution semantics

Nguồn: [`45_strategy_exec.pine`](file:///D:/Applications/tm-trading/pine/parts-wonderwhales/45_strategy_exec.pine),
dist dòng 273–471.

#### 7.1 Inputs bổ sung (13, tổng 50)

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

#### 7.2 Cấu hình strategy

`strategy(..., pyramiding = 0, calc_on_order_fills = true, calc_on_every_tick = true,
process_orders_on_close = true, initial_capital = 10000, commission_type = percent,
commission_value = 0.05, slippage = 0)`.

- Commission 0.05% mỗi chiều; slippage 0.
- `default_qty_type = percent_of_equity`, `default_qty_value = 100` — nhưng code truyền `qty` tường minh
  nên default này không có tác dụng.
- Không có swap, không có spread model tường minh (TradingView dùng dữ liệu broker của chart).

#### 7.3 Kích thước vị thế

```pine
ww_calcAtr = nz(ww_atr, ta.atr(14))     // fallback ATR(14) literal
if na(ww_calcAtr) or ww_calcAtr <= 0.0
    ww_calcAtr := close * 0.01          // fallback cuối

ww_stratQty = (ww_strat_pct / 100.0 * strategy.equity) / close
ww_stratQtyOk = ww_stratQty > 0.0 and not na(close) and close > 0.0
```

Đây là **số đơn vị tài sản cơ sở** (equity / giá), không phải lot. MT5 cần quy đổi qua contract size,
margin, leverage; không được copy nguyên con số.

#### 7.4 Entry

- Chỉ entry khi `strategy.position_size == 0` (không nhồi lệnh; `pyramiding = 0`).
- Điều kiện: `ww_strat_on and ww_stratQtyOk and ww_signalBuy and ww_allowLong and flat`.
- Giá tham chiếu: `close` của bar tín hiệu; do `process_orders_on_close = true`, lệnh market được khớp
  tại close bar đó.
- Không có stop/limit entry; không có trailing entry.

#### 7.5 Stop Loss (long; short đối xứng)

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

#### 7.6 Break-Even

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

#### 7.7 Exit modes

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

#### 7.8 Reset state

Khi `strategy.position_size == 0`, toàn bộ `ww_posEntry/Sl/Tp1/Tp2/Risk/Dir`, `ww_isBeActive`,
`ww_isLadder` được reset. Điều này xảy ra trước khối entry trong cùng lần tính.

#### 7.9 Fills và intrabar

- `process_orders_on_close = true`: market entry/close khớp tại close bar.
- `calc_on_every_tick = true` + `calc_on_order_fills = true`: script tính lại mỗi tick và sau mỗi fill;
  stop/limit của `strategy.exit` được cập nhật trong bar.
- Với OHLC modeling, thứ tự high/low trong bar là giả định của broker emulator. Nếu SL và TP cùng bị
  chạm trong một bar, kết quả phụ thuộc giả định đó — phải ghi rõ khi mô phỏng lại.
- `strategy.equity` dao động intrabar → `qty` cũng có thể đổi giữa các tick; giá trị cuối cùng tại close
  mới là giá trị dùng để khớp.

#### 7.10 Outputs bổ sung của Backtest

- 4 plot level: Entry, TP1, TP2, SL/BE (`style_linebr`, chỉ hiện khi có vị thế và `ww_strat_showLines`).
- `plotcandle` tô nến theo `ww_sarDir` khi `ww_showTrendCandles`.
- Không có `alertcondition`; chỉ có 2 `alert()` runtime giống indicator.

### 8. Phụ thuộc

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

### 9. Realtime, repaint và warm-up (sơ bộ — Phase 2 xác minh)

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

### 10. Khác biệt Pine → MQL5 dự kiến

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

### 11. Trạng thái portability

**`PORTABLE_WITH_DIFFERENCES`** — lý do:

- Toàn bộ signal core dùng indicator chuẩn, không MTF, không cấu trúc dữ liệu phức tạp → port được.
- Khác biệt bắt buộc: seed PSAR/EMA/ATR, volume type, fill timing, sizing, intrabar SL/TP, timezone.
- Khối strategy có 2 lỗi logic (Ladder + pyramiding, Ladder + Reversal) **không được port nguyên**.
- Không port phần HUD/table/label/color sang chỉ báo MQL5 trừ khi cần cho visual tester; ưu tiên buffer
  tín hiệu.

### 12. Signal ID và buffer contract (đã chốt ở Phase 3)

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

Draft buffer (đã chốt ở Phase 3 — xem `BUFFER_CONTRACT_Wonderwhales.md`
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

### 13. Câu hỏi mở và blocker

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

### 14. Việc tiếp theo

- **Phase 2:** hoàn tất — xem `REPAINT_AUDIT_Wonderwhales.md`.
- **Phase 3:** hoàn tất — buffer contract 18 kênh, input contract, test vector A–E tại
  `BUFFER_CONTRACT_Wonderwhales.md`.
- **Phase 4:** viết custom indicator MQL5 trong `MQL5/Indicators/PinePort/` khi được yêu cầu.
- **Phase 5:** `PineSignalLabEA.mq5` signal-only, không có API gửi lệnh.

Tham chiếu: [`pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md`](../pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md),
[`PINE_INVENTORY.md`](README.md), [`PROGRESS.md`](../PROGRESS.md).

## Repaint Audit — Wonderwhales (Pine v6)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu (chưa port MQL5)
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — kết luận dưới đây là **phân tích tĩnh** trên source Pine.
  Chưa chạy TradingView Bar Replay, chưa tạo alert thật, chưa chạy backtest. Mọi kết luận phụ thuộc hành vi
  runtime của TradingView được đánh dấu `PENDING` ở mục 10.
- **Nguồn:** [`dist/Wonderwhales.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales.pine) (415 dòng,
  SHA `0529d7b9…d61b9`) và
  [`dist/Wonderwhales Backtest.pine`](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine)
  (614 dòng, SHA `e7c15e1a…4910`). Không file Pine nào bị sửa.
- **Đặc tả nền:** `INDICATOR_SPEC_Wonderwhales.md`.

### 1. Định nghĩa “repaint” dùng trong audit

| Mã | Hiện tượng | Ảnh hưởng thực tế |
|---|---|---|
| RP1 | Marker/label xuất hiện trên nến đang chạy rồi biến mất trước khi nến đóng | Người xem chart thấy tín hiệu “ma” |
| RP2 | Giá trị tín hiệu của một nến **đã đóng** thay đổi khi có nến mới | Backtest/parity không tái lập được |
| RP3 | Alert phát trước khi nến đóng | Vào lệnh trên dữ liệu chưa hoàn tất |
| RP4 | Mức SL/TP/BE của strategy thay đổi trong nến và được áp ngược lại chính nến đó | Fill không có thật trong đời sống |
| RP5 | Kết quả lịch sử khác nhau giữa hai lần chạy cùng input | Không thể dùng làm reference parity |

Trọng tâm của Phase 2 là RP1/RP2/RP3 cho **signal**, và RP4 cho **strategy** (chỉ mô tả, không port).

### 2. Bản đồ phụ thuộc dữ liệu

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

### 3. Cổng confirmed-bar

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

### 4. Ma trận repaint theo thành phần

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

### 5. Kịch bản intrabar

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

### 6. Hành vi alert

| Cơ chế | Điều kiện | Tần suất | Đánh giá |
|---|---|---|---|
| `alertcondition(ww_signalBuy/Sell/Any)` — dòng 396–398 | Đã gate | Theo thiết lập trong hộp thoại alert | Với gate on, điều kiện chỉ đúng tại đóng nến; với gate off, “Once Per Bar” có thể phát intrabar (RP3) |
| `alert("...BUY", alert.freq_once_per_bar_close)` — dòng 404–406 | Đã gate | Một lần mỗi nến, tại đóng nến | `alert()` được gọi mỗi lần script tính; TradingView chỉ gửi ở lần tính cuối. Cần xác minh: nếu điều kiện đúng giữa nến nhưng sai lúc đóng, alert có bị huỷ hay vẫn gửi |
| `alertcondition(ww_isClimaxVol)` — dòng 401 | **Không gate** | Theo hộp thoại alert | Có thể phát intrabar; chỉ là cảnh báo VSA, không phải tín hiệu vào lệnh |

`alert()` dùng `alert.freq_once_per_bar_close` nên **không** tự tạo RP3 khi gate on; rủi ro còn lại là
hành vi huỷ alert khi điều kiện đổi trong nến (`PENDING` — kiểm tra E3).

Alert không phụ thuộc input hiển thị (`ww_showLabels`, `ww_showDebug`, màu sắc, ngôn ngữ). Tắt label
trên chart **không** tắt alert.

### 7. Hành vi strategy (chỉ mô tả, không port ở Phase 5)

Header: `pyramiding = 0`, `calc_on_order_fills = true`, `calc_on_every_tick = true`,
`process_orders_on_close = true`, commission 0.05%, slippage 0
([dòng 2](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L2)).

#### 7.1 Trạng thái và reset

`ww_posEntry/Sl/Tp1/Tp2/Risk/Dir/IsLadder/isBeActive` là `var`, reset về `na/0/false` khi
`strategy.position_size == 0` ([dòng 309–327](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L309)).
Vì reset chạy **trước** khối entry, nến vừa đóng vị thế sẽ không giữ level cũ. Đây là state máy trạng thái
tuần tự, không phải hàm thuần của nến.

#### 7.2 Entry

- Chỉ vào khi `strategy.position_size == 0` và `ww_signal*` đúng
  ([dòng 330–331](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L330)).
- Entry price dùng `close` của nến tín hiệu; qty = `pct/100 * strategy.equity / close`
  ([dòng 301](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L301)) → **phụ thuộc
  đường đi equity**, không tái lập được nếu equity khác.
- Với gate on + `process_orders_on_close`, lệnh được gửi tại nến tín hiệu và fill ở close nến đó.

#### 7.3 Exit và RP4

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

#### 7.4 Hai lỗi logic đã biết (không port mù)

1. **Ladder + `pyramiding = 0`:** hai `strategy.entry` cùng chiều (`Long1`, `Long2`) trên cùng nến có thể
   bị từ chối lệnh thứ hai. Hành vi thực tế `PENDING` (E6).
2. **Ladder + Reversal:** `strategy.close("Long")`
   ([dòng 423](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L423),
   [dòng 453](file:///D:/Applications/tm-trading/pine/dist/Wonderwhales%20Backtest.pine#L453)) không khớp
   entry ID `Long1/Long2` (`Short1/Short2`), nên có thể **không đóng vị thế**. `PENDING` (E7).

Hai lỗi này chỉ ảnh hưởng Phase 7+ nếu có port execution. Phase 4/5 (indicator + signal-only EA) không bị.

### 8. Timestamp contract

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

### 9. Chính sách MQL5 (quyết định cho Phase 3–5)

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

### 10. Kế hoạch xác minh thực nghiệm (thủ công, TradingView)

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

### 11. Findings và risk register

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

### 12. Gate 2 — tiêu chí nghiệm thu

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

### 13. Câu hỏi còn mở

1. `alert()` với `freq_once_per_bar_close` có bị huỷ khi điều kiện đúng giữa nến nhưng sai lúc đóng? (E3)
2. Exit có hiệu lực ngay nến entry khi `calc_on_order_fills = true`? (E5)
3. Hai entry ladder có cùng tồn tại với `pyramiding = 0`? (E6)
4. `strategy.close("Long")` có đóng `Long1/Long2`? (E7)
5. Nến PSAR hợp lệ đầu tiên trên từng symbol/timeframe là nến nào? Ảnh hưởng warm-up parity.
6. Symbol/timeframe chuẩn cho parity vẫn chưa chốt (blocker 9 của `PROGRESS.md`).

## Buffer Contract — Wonderwhales (Pine v6 → MQL5)

- **Phase:** 3 — Đặc tả thuật toán và hợp đồng buffer trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4` — chốt giao diện giữa custom indicator và EA
  signal-only. Chưa có mã MQL5, chưa compile.
- **Nguồn:** `INDICATOR_SPEC_Wonderwhales.md` và
  `REPAINT_AUDIT_Wonderwhales.md`.
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không có API gửi lệnh, không đọc tài khoản, không alert.

### 1. Phạm vi

Hợp đồng này định nghĩa:

1. Input của custom indicator `MQL5/Indicators/PinePort/Wonderwhales.mq5`.
2. 18 buffer, ý nghĩa, miền giá trị, giá trị thiếu, loại buffer.
3. Cách indicator chốt tín hiệu theo nến đã đóng.
4. Cách EA `PineSignalLabEA.mq5` đọc buffer, chống trùng và ghi CSV.
5. Test vector tổng hợp để kiểm tra logic thuần trước khi so với Pine.

Không định nghĩa: execution, sizing, SL/TP/BE/trailing, alert. Đó là phạm vi khác và đang `BLOCKED`.

### 2. Chính sách kế thừa từ Phase 2

| Mã | Chính sách | Thể hiện trong hợp đồng |
|---|---|---|
| P1 | Chỉ phát tín hiệu trên nến đã đóng | Buffer 3/4/6/7 = `0.0` tại index `rates_total-1` |
| P2 | EA chỉ đọc `shift = 1` | Mục 9; không có input đọc `shift = 0` |
| P3 | Không port `confirmOnClose = false` | Không có input tương ứng; ghi D16 |
| P4 | Tín hiệu là edge event | Công thức giữ `dir[1]` và `crossover` |
| P5 | Blocked không phải tín hiệu | Buffer 6/7 tách riêng; EA không dùng để vào lệnh |
| P9 | PSAR thiếu giá trị ≠ 0 | Buffer 0 = `EMPTY_VALUE`; `dir` giữ nguyên |
| P10 | `psar == close` là bearish | Dùng `<` nghiêm ngặt |

### 3. Input contract

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

### 4. Signal ID và reason

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

### 5. Hợp đồng 18 buffer

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

#### 5.1 Plot

| Plot | Buffer | Style | Màu | Ghi chú |
|---:|---:|---|---|---|
| 1 | 0 | `DRAW_LINE` | một màu cố định | Pine đổi màu theo `sarDir`; MQL5 một màu (D17) |
| 2 | 1 | `DRAW_ARROW`, code 233 | xanh | tại `low` của nến tín hiệu |
| 3 | 2 | `DRAW_ARROW`, code 234 | đỏ | tại `high` của nến tín hiệu |

Indicator chạy ở **chart window** (không phải separate window) vì PSAR là giá. Các giá trị oscillator
vẫn có trong buffer nhưng không vẽ. Đây là khác biệt hiển thị có chủ ý.

### 6. Giá trị thiếu và warm-up

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

### 7. Bar indexing và xác nhận

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

### 8. Hợp đồng EA đọc buffer

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

#### 8.1 CSV output

Ghi vào `MQL5/Files` (không phải `Common\Files`), một file mỗi lần chạy:

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,signal_id,side,sar_dir,psar,fast,slow,atr_pct,input_hash
```

- `detected_at`: `TimeCurrent()` tại tick phát hiện.
- `bar_open_time`: `iTime(_Symbol,_Period,1)`.
- `confirmed_at`: `bar_open_time + PeriodSeconds(_Period)`.
- `input_hash`: FNV-1a 32-bit trên chuỗi chuẩn hóa của 13 input + `warmup_bars`, 8 hex.
- Không ghi bid/ask, account, balance, hay bất kỳ trường tài khoản.

### 9. Test vector tổng hợp

Các vector dưới đây kiểm tra **logic thuần**, không phụ thuộc dữ liệu thị trường. Phase 4 sẽ cài chúng
trong `MQL5/Scripts/WonderwhalesContractTests.mq5` và gọi đúng các hàm mà indicator sử dụng, để test và
indicator không lệch nhau.

#### 9.1 Nhóm A — hướng PSAR và flip

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

#### 9.2 Nhóm B — mode và filter

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

#### 9.3 Nhóm C — cổng confirmed

| ID | confirmed | valid | blocked | → signal | → blocked_signal |
|---|---:|---:|---:|---:|---:|
| C1 | 1 | 1 | 0 | 1 | 0 |
| C2 | 0 | 1 | 0 | 0 | 0 |
| C3 | 0 | 0 | 1 | 0 | 0 |
| C4 | 1 | 0 | 1 | 0 | 1 |

#### 9.4 Nhóm D — EMA crossover

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

#### 9.5 Nhóm E — giá trị thiếu và nến đang chạy

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

### 10. Ngưỡng so sánh parity (đề xuất cho Phase 6)

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

### 11. Gate 3 — tiêu chí nghiệm thu

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

### 12. Điểm còn mở

1. Seed EMA/ATR/RSI/BB của MQL5 so với Pine: chỉ giải quyết bằng đo, không bằng giả định. Nếu lệch quá
   ngưỡng sau 300 bar, Phase 4 phải cài lại công thức thủ công.
2. `iSAR` có thể trả `0` thay vì `EMPTY_VALUE` ở những bar đầu; indicator phải chuẩn hóa `0`/`EMPTY_VALUE`
   thành “thiếu” nhưng **không** coi PSAR giá 0 là hợp lệ.
3. Volume: `tick_volume` là mặc định; nếu symbol có `real_volume = 0`, ghi rõ trong parity report.
4. Timezone: CSV dùng giờ server; Pine export có thể là giờ exchange. Chuẩn hóa ở Phase 6.
5. Chưa có reference CSV từ Pine → Phase 6 vẫn `BLOCKED`.
