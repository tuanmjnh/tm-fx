# TM Fusion Zones — Spec, Repaint Audit và Buffer Contract

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `INDICATOR_SPEC_TMFusionZones.md`, `REPAINT_AUDIT_TMFusionZones.md`, `BUFFER_CONTRACT_TMFusionZones.md`.

Nội dung:
1. Indicator Spec — TM Fusion Zones
2. Repaint Audit — TM Fusion Zones (Pine v6)
3. Buffer Contract — TM Fusion Zones (Pine v6 → MQL5)

---
## Indicator Spec — TM Fusion Zones

- **Nguồn Pine:** `D:\Applications\tm-trading\pine\dist\TM Fusion Zones.pine` (1.035 dòng, read-only)
- **Nguồn execution tham chiếu:** `D:\Applications\tm-trading\pine\dist\TM Fusion Zones Backtest.pine` (1.065 dòng)
- **Phụ bản:** `parts-fusion-zones/` (12 module, không compile độc lập)
- **Pine version:** 6 — `indicator(..., overlay = true, dynamic_requests = true, max_bars_back = 1000)`
- **Cross-timeframe:** 1 `request.security(..., ta.ema(close, len), gaps_off, lookahead_off)`
- **Loại:** indicator overlay; không có `strategy.*` trong bản indicator
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (xem §9, §10)
- **License:** chưa thấy header license trong repo nguồn; chỉ dùng nội bộ, cần xác nhận quyền trước khi phân phối.

### 1. Mục tiêu tín hiệu

TM Fusion Zones là một engine giao dịch theo xu hướng, ghép 6 lớp:

| Lớp | Thành phần | Vai trò |
|---|---|---|
| 1 | Trend Ribbon (2 MA + slope) | Bộ lọc hướng và độ mạnh xu hướng |
| 2 | Dynamic Zones (pivot supply/demand) | Vùng phản ứng, SL reference, TP đối diện |
| 3 | Market Structure | Swing, BOS, CHoCH, liquidity sweep, PDH/PDL |
| 4 | Candle confirmation | Pinbar, engulfing, momentum bar |
| 5 | MTF Context | EMA HTF làm bias |
| 6 | Scoring + Risk Gate + State machine | Chấm điểm 0–100, SL/TP, cooldown, thống kê TP/SL |

Tín hiệu cuối cùng chỉ có hai: `fz_signalLong` / `fz_signalShort`. Mọi thứ khác là bộ lọc,
tham số risk, hoặc hiển thị.

### 2. Inputs (55)

Trong 55 input, **39 input ảnh hưởng tín hiệu** và **16 input chỉ hiển thị / alert**.
Ba điểm cần lưu ý ngay:

- `fz_ms_show` **không được dùng ở bất kỳ đâu** trong source (dead input).
- `fz_scr_setup` **không được dùng ở bất kỳ đâu** (dead input; chỉ `fz_scr_noTrade` và
  `fz_scr_strong` được dùng).
- `fz_payloadMode` chỉ có tác dụng phân biệt `"Off"`; `"Full"` và `"Slim"` cho payload giống hệt nhau.

#### 2.1 Chung & Asset Profile

| Pine | Kiểu | Mặc định | Min/Max | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_confirmOnly` | bool | `true` | — | Có (gate `barstate.isconfirmed`) |
| `fz_payloadMode` | string | `"Full"` | `Full`, `Slim`, `Off` | Không (chỉ webhook; Full = Slim) |
| `fz_assetMode` | string | `"Auto"` | `Auto`, `XAU`, `BTC`, `ETH`, `Crypto Other`, `Custom` | Có (hệ số volatility) |

#### 2.2 Trend Ribbon

| Pine | Kiểu | Mặc định | Min/Max | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_rb_show` | bool | `false` | — | Không (render) |
| `fz_rb_type` | string | `"EMA"` | `EMA`, `SMA`, `HMA` | Có |
| `fz_rb_fast` | int | `20` | 2 / 200 | Có |
| `fz_rb_slow` | int | `50` | 5 / 500 | Có |
| `fz_rb_filter` | bool | `true` | — | Có |

#### 2.3 Dynamic Zones

| Pine | Kiểu | Mặc định | Min/Max | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_zn_show` | bool | `true` | — | Không (render) |
| `fz_zn_swLen` | int | `7` | 2 / 50 | Có |
| `fz_zn_widthAtr` | float | `0.5` | ≥ 0.1, step 0.05 | Có |
| `fz_zn_max` | int | `10` | 2 / 30 | Có |

#### 2.4 Structure & Liquidity

| Pine | Kiểu | Mặc định | Min/Max | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_ms_show` | bool | `true` | — | **Không — dead input** |
| `fz_ms_swLen` | int | `5` | 2 / 20 | Có |
| `fz_ms_sweepOn` | bool | `true` | — | Có (swing sweep) |
| `fz_ms_pdOn` | bool | `true` | — | Có (PDH/PDL sweep) — dù tên là “hiển thị” |

#### 2.5 Entry Setups

| Pine | Kiểu | Mặc định | Min/Max | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_setup_pullback` | bool | `true` | — | Có |
| `fz_setup_sweep` | bool | `true` | — | Có |
| `fz_setup_range` | bool | `false` | — | Có |
| `fz_pull_tol` | float | `0.4` | ≥ 0.1, step 0.05 | Có |
| `fz_sweep_confBars` | int | `3` | 1 / 10 | Có |

#### 2.6 MTF Context

| Pine | Kiểu | Mặc định | Options | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_mtf_on` | bool | `true` | — | Có |
| `fz_mtf_tf` | timeframe | `"240"` | `60`, `240`, `D`, `W` | Có |
| `fz_mtf_len` | int | `100` | 10 / 500 | Có |

#### 2.7 Scoring

| Pine | Kiểu | Mặc định | Min/Max | Ảnh hưởng tín hiệu |
|---|---|---|---|---|
| `fz_w_trend` | float | `25.0` | ≥ 0 | Có |
| `fz_w_zone` | float | `25.0` | ≥ 0 | Có |
| `fz_w_struct` | float | `20.0` | ≥ 0 | Có |
| `fz_w_candle` | float | `15.0` | ≥ 0 | Có |
| `fz_w_mtf` | float | `15.0` | ≥ 0 | Có |
| `fz_scr_noTrade` | int | `49` | 0 / 99 | Có |
| `fz_scr_setup` | int | `65` | 1 / 99 | **Không — dead input** |
| `fz_scr_strong` | int | `78` | 1 / 99 | Không (màu dashboard) |
| `fz_scoreMargin` | int | `8` | 0 / 50 | Có |

#### 2.8 Risk & TP/SL

| Pine | Kiểu | Mặc định | Min/Max | Options | Ảnh hưởng tín hiệu |
|---|---|---|---|---|---|
| `fz_sl_mode` | string | `"Zone / Swing"` | — | `Zone / Swing`, `ATR Multiplier` | Có |
| `fz_tp_mode` | string | `"Opposing Zone / RR"` | — | `Opposing Zone / RR`, `Fixed RR` | Có |
| `fz_sl_atrMul` | float | `1.5` | ≥ 0.5, step 0.1 | — | Có |
| `fz_sl_padAtr` | float | `0.2` | ≥ 0.05, step 0.05 | — | Có |
| `fz_sl_minAtr` | float | `0.5` | ≥ 0.2, step 0.1 | — | Có |
| `fz_sl_maxAtr` | float | `3.5` | ≥ 1.0, step 0.1 | — | Có |
| `fz_rr1` | float | `1.0` | ≥ 0.5, step 0.1 | — | Có |
| `fz_rr2` | float | `2.0` | ≥ 1.0, step 0.1 | — | Có |
| `fz_rr3` | float | `3.0` | ≥ 1.5, step 0.1 | — | Có |
| `fz_rrMin` | float | `1.5` | ≥ 0.5, step 0.1 | — | Có (so với input `rr2`, xem §3.11) |
| `fz_obstacleGate` | bool | `true` | — | — | Có |
| `fz_coolBars` | int | `8` | ≥ 0 | — | Có |

#### 2.9 Display

| Pine | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `fz_showViz` | bool | `true` | Master visual |
| `fz_cBull` / `fz_cBear` | color | `#089981` / `#f23645` | Màu |
| `fz_showSig` / `fz_showTargets` / `fz_showHit` | bool | `true` | Render |
| `fz_showDash` | bool | `true` | Dashboard |
| `fz_dashMode` | string | `"Compact"` | `Compact`, `Advanced` |
| `fz_dashSize` | string | `"Small"` | `Tiny`, `Small`, `Normal` |
| `fz_sessTz` | string | `"America/New_York"` | Chỉ dashboard (session label) |

### 3. Công thức

#### 3.1 Core

```text
atr14   = ta.atr(14)                      // Wilder, seed SMA(14)
atrSafe = max(atr14, syminfo.mintick * 2)

assetVolMult (Auto):
  ticker chứa "XAU" hoặc "GOLD"  -> 1.10, effAsset = XAU
  ticker chứa "BTC"              -> 1.25, effAsset = BTC
  ticker chứa "ETH"              -> 1.20, effAsset = ETH
  syminfo.type == "crypto"       -> 1.35, effAsset = Crypto Other
  còn lại                        -> 1.00, effAsset = Custom
assetMode khác Auto: effAsset = assetMode; XAU/BTC/ETH/Crypto Other áp hệ số tương ứng,
Custom giữ 1.00.
```

`atrSafe` là mẫu số của mọi ngưỡng ATR; với mintick > 0 nó không bao giờ bằng 0.

#### 3.2 Regime (ADX 14 + Choppiness 14)

```text
tr      = ta.tr(true)                     // true range, bar đầu dùng high-low
dmPos   = (change(high) > 0 and change(high) > -change(low))
          ? max(change(high), 0) : 0
dmNeg   = (-change(low) > 0 and -change(low) > change(high))
          ? max(-change(low), 0) : 0
trSm    = ta.rma(tr, 14)
rmaPos  = ta.rma(dmPos, 14)
rmaNeg  = ta.rma(dmNeg, 14)
diPos   = trSm > 0 ? 100 * rmaPos / trSm : 0
diNeg   = trSm > 0 ? 100 * rmaNeg / trSm : 0
dx      = (diPos + diNeg) > 0 ? 100 * |diPos - diNeg| / (diPos + diNeg) : 0
adx     = ta.rma(dx, 14)

sumTr   = math.sum(tr, 14)
diff    = ta.highest(high, 14) - ta.lowest(low, 14)
chop    = (diff > 0 and sumTr > 0)
          ? 100 * log10(sumTr / diff) / log10(14)
          : 50

nếu adx >= 23 và chop <= 56   -> "Trending"
ngược lại nếu chop >= 58 hoặc adx < 18 -> "Range"
ngược lại                     -> "Transitional"
```

Chú ý: comment trong source ghi ngưỡng 23/55, 60/20 nhưng **code dùng 23/56, 58/18**.
Port bám code, không bám comment.

#### 3.3 Trend Ribbon

```text
maFast = f_calcMa(close, rb_fast, rb_type)
maSlow = f_calcMa(close, rb_slow, rb_type)

f_calcMa: SMA = ta.sma; HMA = ta.hma; EMA = ta.ema (mặc định EMA)
bull   = maFast > maSlow
bear   = maFast < maSlow
fastUp = change(maFast) > 0;  slowUp = change(maSlow) > 0
strongBull = bull and fastUp and slowUp
strongBear = bear and fastDn and slowDn
spread     = |maFast - maSlow|
spreadAtr  = spread / atrSafe
expanding  = spread > spread[1]
top = max(maFast, maSlow); bot = min(maFast, maSlow)
tolPx = pull_tol * atrSafe
priceInRibbonLong  = low <= top + tolPx and high >= bot - tolPx
priceInRibbonShort = high >= bot - tolPx and low <= top + tolPx   // BIỂU THỨC Y HỆT
trendLongOk  = not rb_filter or bull
trendShortOk = not rb_filter or bear
```

`priceInRibbonLong` và `priceInRibbonShort` là **cùng một điều kiện** (giao hoán), nên
proximity ribbon không phân biệt long/short. Port giữ nguyên.

#### 3.4 Dynamic Zones

```text
halfWidth = atrSafe * zn_widthAtr * 0.5
ph = ta.pivothigh(high, zn_swLen, zn_swLen)   // xác nhận tại bar + swLen
pl = ta.pivotlow(low,  zn_swLen, zn_swLen)

// 1. Đăng ký supply từ pivot high (side = -1)
nếu chưa có supply zone chưa broken nào có |mid - ph| <= atrSafe * zn_widthAtr:
    top = max(z.top, ph + halfWidth); bot = min(z.bot, ph - halfWidth); touches += 1
    (merge vào zone đầu tiên khớp, quét từ index 0)
ngược lại:
    push FzZone(top = ph + halfWidth, bot = ph - halfWidth, side = -1,
                touches = 1, broken = false, startBar = bar_index - zn_swLen)

// 2. Đăng ký demand từ pivot low (side = +1), đối xứng

// 3. Cập nhật touch / break trên MỌI zone chưa broken
demand: close < bot                  -> broken = true
        ngược lại nếu low <= top và high >= bot:
            nếu low[1] > top         -> touches += 1
supply: close > top                  -> broken = true
        ngược lại nếu high >= bot và low <= top:
            nếu high[1] < bot        -> touches += 1

// 4. Xoá mọi zone broken; sau đó while size > zn_max: shift (bỏ zone cũ nhất)

// 5. Tương tác nến hiện tại (±0.2 ATR)
demand: low <= top + 0.2*atrSafe và high >= bot - 0.2*atrSafe
        -> inDemandZone = true; demandZoneBot = z.bot; demandZoneTop = z.top
supply: high >= bot - 0.2*atrSafe và low <= top + 0.2*atrSafe
        -> inSupplyZone = true; supplyZoneTop = z.top; supplyZoneBot = z.bot
```

Thứ tự rất quan trọng: zone mới đăng ký **có thể bị break ngay trong cùng nến** vì bước
3 chạy sau bước 1–2. Nếu nhiều zone cùng thỏa, zone **cuối** trong mảng ghi đè biến
`demandZoneBot/demandZoneTop` (và tương tự cho supply). `inDemandZone` và `inSupplyZone`
có thể cùng `true`.

Zone mới lấy `startBar = bar_index - swLen` (bar tạo pivot, không phải bar xác nhận).
Merge **không** đổi `startBar`, chỉ mở rộng top/bot và tăng `touches`.

#### 3.5 Nearest opposing zone

```text
long : duyệt supply chưa broken có bot > close; chọn bot gần nhất
short: duyệt demand chưa broken có top < close; chọn top gần nhất
không có -> na (khoảng cách sentinel 1e9)
```

#### 3.6 Market structure, sweep, PDH/PDL

```text
msPH = ta.pivothigh(high, ms_swLen, ms_swLen)
msPL = ta.pivotlow(low,  ms_swLen, ms_swLen)
khi có pivot high: prevSwH = swH; swH = msPH; swHBar = bar_index - ms_swLen
khi có pivot low : prevSwL = swL; swL = msPL; swLBar = bar_index - ms_swLen

bosBull = not na(swH) and close > swH and close[1] <= swH
bosBear = not na(swL) and close < swL and close[1] >= swL
msTrend: 1 / -1; nếu bosBull và trend == -1 -> chochBull = true, trend = 1
                  nếu bosBear và trend ==  1 -> chochBear = true, trend = -1

swpBullSw = ms_sweepOn and not na(swL) and low < swL and close > swL
swpBearSw = ms_sweepOn and not na(swH) and high > swH and close < swH

newDay = ta.change(time("D")) != 0
khi newDay: pdh = curDayH; pdl = curDayL; curDayH = high; curDayL = low
ngược lại : curDayH = max(curDayH, high); curDayL = min(curDayL, low)

swpBullPd = ms_pdOn and not na(pdl) and low < pdl and close > pdl
swpBearPd = ms_pdOn and not na(pdh) and high > pdh and close < pdh
swpBull   = swpBullSw or swpBullPd
swpBear   = swpBearSw or swpBearPd
```

`prevSwH/prevSwL` được ghi nhưng **không được dùng** trong tính toán tín hiệu (dead state).
`msTrend` chỉ dùng để phát hiện CHoCH.

#### 3.7 Nến xác nhận

```text
body      = |close - open|
rng       = max(high - low, mintick)
upperWick = high - max(close, open)
lowerWick = min(close, open) - low

pinBull = lowerWick >= 2*body and close >= low + 0.5*rng
pinBear = upperWick >= 2*body and close <= high - 0.5*rng

engulfBull = close > open and close[1] < open[1]
             and close >= open[1] and open <= close[1]
engulfBear = close < open and close[1] > open[1]
             and close <= open[1] and open >= close[1]

momBull = close > open and body >= 0.55*rng
momBear = close < open and body >= 0.55*rng

candleBull = pinBull or engulfBull or momBull
candleBear = pinBear or engulfBear or momBear
```

#### 3.8 MTF context

```text
htfEma = mtf_on
         ? request.security(syminfo.tickerid, mtf_tf,
                            ta.ema(close, mtf_len), gaps_off, lookahead_off)
         : na
htfBull = not mtf_on or na(htfEma) or close >= htfEma
htfBear = not mtf_on or na(htfEma) or close <= htfEma
```

Quan trọng: khi `mtf_on = true` nhưng EMA chưa có (warm-up), **cả `htfBull` và `htfBear`
đều true**. Khi `close == htfEma`, cả hai cũng true. Điều này làm `mtfFact = 1.0` cho cả
hai hướng trong giai đoạn đầu và tại điểm bằng nhau.

#### 3.9 Setups và ưu tiên

```text
s1_long  = setup_pullback and trendLongOk and htfBull
           and (priceInRibbonLong or inDemandZone)
           and candleBull and close >= rb_bot
s1_short = setup_pullback and trendShortOk and htfBear
           and (priceInRibbonShort or inSupplyZone)
           and candleBear and close <= rb_top

barsSinceBullSweep = ta.barssince(swpBull)
barsSinceBearSweep = ta.barssince(swpBear)
sweepLongWindow  = not na(barsSinceBullSweep) and barsSinceBullSweep <= sweep_confBars
sweepShortWindow = not na(barsSinceBearSweep) and barsSinceBearSweep <= sweep_confBars

s2_long  = setup_sweep and sweepLongWindow
           and (swpBull or candleBull) and (close > open or pinBull)
s2_short = setup_sweep and sweepShortWindow
           and (swpBear or candleBear) and (close < open or pinBear)

s3_long  = setup_range and isRanging and inDemandZone and candleBull
s3_short = setup_range and isRanging and inSupplyZone and candleBear
```

`ta.barssince` trả `0` trên chính nến sweep và `na` nếu chưa từng có sweep.

Ưu tiên mỗi hướng: **Sweep (s2) > Pullback (s1) > Range (s3)**. `longSetupDetected` và
`shortSetupDetected` độc lập nhau; cả hai có thể true trong cùng nến.

#### 3.10 Scoring

```text
long factors:
  trend  = strongBull ? 1.00 : bull ? 0.75 : 0
  zone   = inDemandZone ? 1.00 : priceInRibbonLong ? 0.70 : 0
  struct = chochBull ? 1.00 : swpBull ? 0.90 : bosBull ? 0.75 : 0
  candle = (engulfBull or pinBull) ? 1.00 : candleBull ? 0.70 : 0
  mtf    = htfBull ? 1.00 : 0

short factors: đối xứng với strongBear/bear, inSupplyZone/priceInRibbonShort,
               chochBear/swpBear/bosBear, engulfBear/pinBear, htfBear

rawLong  = sum(long.factor  * weight)
rawShort = sum(short.factor * weight)
sumW     = w_trend + w_zone + w_struct + w_candle + w_mtf

score = sumW > 0 ? round(raw / sumW * 100) : 0
```

`math.round` của Pine làm tròn nửa lên (với số dương). Điểm là số nguyên 0–100.

#### 3.11 Risk: SL, TP, gates

```text
coolOk = (bar_index - lastSignalBar) >= coolBars      // lastSignalBar khởi tạo -999

LONG:
  rawSl = demandZoneBot nếu có, ngược lại swL nếu có, ngược lại close - sl_atrMul*atrSafe
  sl = sl_mode == "Zone / Swing"
       ? rawSl - sl_padAtr*atrSafe*assetVolMult
       : close - sl_atrMul*atrSafe*assetVolMult
  riskDist = clamp(close - sl, sl_minAtr*atrSafe, sl_maxAtr*atrSafe)
  sl       = close - riskDist
  tp1 = close + riskDist*rr1; tp2 = close + riskDist*rr2; tp3 = close + riskDist*rr3
  opp = tp_mode == "Opposing Zone / RR" ? nearestSupplyBotAbove(close) : na
  nếu opp có và opp > close + riskDist*0.8:
      tp1 = min(close + riskDist*rr1, opp)
      tp2 = opp
      tp3 = opp + riskDist

SHORT: đối xứng
  rawSl = supplyZoneTop / swH / close + sl_atrMul*atrSafe
  sl    = rawSl + pad (Zone/Swing) hoặc close + sl_atrMul*atrSafe*mult
  riskDist = clamp(sl - close, minAtr, maxAtr); sl = close + riskDist
  tp1/2/3 = close - riskDist*rr1/2/3
  opp = nearestDemandTopBelow(close)
  nếu opp < close - riskDist*0.8:
      tp1 = max(close - riskDist*rr1, opp); tp2 = opp; tp3 = opp - riskDist
```

Hệ quả cần port đúng:

- Nếu `rawSl` nằm **sai phía** close (ví dụ demand zone bot > close), `riskDist` âm bị
  clamp lên `sl_minAtr*atrSafe`; SL bị đặt lại theo close, không dùng rawSl.
- Khi opp nằm trong khoảng 0.8R–1.0R, `tp1 == tp2 == opp`.
- Khi `tp_mode = "Fixed RR"`, không có điều chỉnh opp; TP thuần RR.

Thứ tự gate (chỉ ghi lý do **đầu tiên** cho mỗi hướng):

1. **Obstacle** (`obstacleGate = true`):
   `distToSupply < (tp1Long - close) * 0.92` → `"Opposing Supply < TP1"`;
   `distToDemand < (close - tp1Short) * 0.92` → `"Opposing Demand < TP1"`.
2. **RR**: `rr2 < rrMin` → `"RR2 < Min RR"` cho cả hai hướng. Đây là so sánh **input
   `rr2`** với `rrMin`, không phải RR tính được của lệnh.
3. **Cooldown**: `not coolOk` → `"Cooldown Active"`.
4. **Score margin**: chỉ khi cả `longSetupDetected` và `shortSetupDetected`;
   `|longScore - shortScore| < scoreMargin` → `"Score Margin Low"` cho cả hai.
5. **Score threshold**: `longScore <= scr_noTrade` → `"Score <= NoTrade"` (tương tự short).

#### 3.12 Eligibility và loại trừ

```text
longEligible  = longSetupDetected  and longScore  > scr_noTrade
                and longBlockReason  == "" and isConfirmed
shortEligible = shortSetupDetected and shortScore > scr_noTrade
                and shortBlockReason == "" and isConfirmed

nếu cả hai eligible:
    longScore >= shortScore -> shortEligible = false, shortBlockReason = "Long Score Won"
    ngược lại               -> longEligible  = false, longBlockReason  = "Short Score Won"

signalLong  = longEligible
signalShort = shortEligible
nếu signalLong hoặc signalShort: lastSignalBar = bar_index
```

Hoà điểm → LONG thắng (`>=`).

#### 3.13 State machine

```text
state: posSide (0/1/-1), posBar, posEntry, posSl, posTp1/2/3,
       posTp1Hit/2Hit/3Hit, posScore, posSetup
counters: cntSignals, cntWins, cntLosses, cntLongs, cntShorts
hit flags mỗi nến: hitTp1, hitTp2, hitTp3, hitSl

LONG đang mở:
  nếu chưa hit TP1 và high >= posTp1 -> posTp1Hit = true, hitTp1 = true
  nếu chưa hit TP2 và high >= posTp2 -> posTp2Hit = true, hitTp2 = true
  nếu chưa hit TP3 và high >= posTp3 -> posTp3Hit = true, hitTp3 = true,
                                        posSide = 0, cntWins += 1
  nếu low <= posSl và posSide != 0   -> hitSl = true, posSide = 0,
                                        cntWins += posTp1Hit ? 1 : 0,
                                        cntLosses += posTp1Hit ? 0 : 1

SHORT đang mở: đối xứng (low <= tp, high >= sl)

sau đó, nếu signalLong:
    posSide = 1; posBar = bar_index; posEntry = close;
    posSl/Tp1/Tp2/Tp3 = fz_slLong/fz_tp1Long/...;
    hit flags = false; posScore = int(longScore); posSetup = longSetupType;
    cntSignals += 1; cntLongs += 1
ngược lại nếu signalShort: đối xứng
```

Các điểm phải port chính xác:

1. **Exit được kiểm tra trước adoption.** Một nến có thể vừa đóng trade cũ vừa mở trade mới.
2. **TP3 đóng vị thế và tính win**; nếu TP3 chạm trong cùng nến, TP1/TP2 cũng được đánh
   dấu (vì các `if` độc lập và tp3 > tp2 > tp1 với long). SL sau đó bị bỏ qua vì
   `posSide == 0`; `hitSl` không bật.
3. **SL sau TP1 tính win**, sau TP2 cũng win (vì TP1 đã hit). Không có break-even.
4. **Adoption ghi đè vị thế đang mở mà không đóng/tính kết quả trade cũ.** Đây là hành vi
   Pine; xem risk register.
5. `posEntry` là `close` của nến tín hiệu, không phải giá fill thực tế.

### 4. Thứ tự thực thi trên một nến

Port MQL5 phải giữ đúng thứ tự dưới đây (mỗi nến đóng):

1. ATR, asset profile, ADX/Chop/regime.
2. Ribbon (MA, bull/bear, strong, spread, proximity, trend ok).
3. Zone: đăng ký supply → đăng ký demand → touch/break toàn bộ → xoá broken → trim
   quá `zn_max` → tính `inDemand/inSupply` và các mức zone bot/top.
4. Structure: pivot, BOS/CHoCH, swing sweep, PDH/PDL, candle patterns.
5. MTF EMA và `htfBull/htfBear`.
6. Setups s1/s2/s3 và gộp ưu tiên s2 > s1 > s3.
7. Score long/short.
8. Risk long/short (SL, TP, opp zone).
9. Gates theo thứ tự obstacle → RR → cooldown → margin → no-trade.
10. Eligibility + mutual exclusivity; cập nhật `lastSignalBar`.
11. State exits (TP1/TP2/TP3/SL) trên vị thế hiện tại.
12. Adoption tín hiệu mới.

### 5. Output Pine

- 2 `plot` ribbon + `fill` cloud.
- Box supply/demand (chỉ vẽ trên `barstate.islast`, tối đa 300 bar về trước).
- 2 `plotshape` signal, 3 `plotshape` hit (TP1/TP2/SL; **không có shape TP3**).
- 3 `plot` level đang mở: Active SL / TP1 / TP2 (không plot TP3).
- 4 `line` + 4 `label` Entry/SL/TP1/TP2 (không có TP3).
- Dashboard Compact 8 dòng / Advanced 13 dòng tại `barstate.islast`.
- 5 `alertcondition`: LONG, SHORT, TAKE PROFIT (TP1), TP2 HIT, STOP LOSS.
- Webhook `alert()` cho ENTRY long/short, TAKE_PROFIT level 1/2, STOP_LOSS; chỉ khi
  `payloadMode != "Off"` và `isConfirmed`.

### 6. Thời điểm xác nhận & timestamp

- `fz_isConfirmed = not confirmOnly or barstate.isconfirmed`; mặc định `confirmOnly = true`.
- Gate confirmed chỉ áp cho **eligibility** (`longEligible/shortEligible`) và webhook
  `fz_canAlert`. Setups, score, zone, structure, hit flags và counters **không** được gate.
- `barstate.islast` chỉ dùng cho dashboard/box/line/label.
- `request.security` dùng `lookahead_off`; xem audit repaint cho ngữ nghĩa HTF.
- Pivot có độ trễ cấu trúc `swLen` bar (7 cho zone, 5 cho structure) — không phải repaint.

| Trường | Định nghĩa |
|---|---|
| `bar_open_time` | Thời gian mở nến chart (giờ server) |
| `signal_bar` | Nến đóng phát `signalLong/signalShort` |
| `confirmed_at` | `bar_open_time + timeframe` |
| `detected_at` | Tick đầu tiên EA đọc buffer `shift = 1` |
| `signal_id` | `FZ_LONG`, `FZ_SHORT`, `FZ_TP1`, `FZ_TP2`, `FZ_TP3`, `FZ_SL` |

Join parity theo `bar_open_time`, không theo `detected_at`.

### 7. Warm-up

| Thành phần | Bar tối thiểu | Ghi chú |
|---|---|---|
| ATR(14) | 14 | RMA seed SMA |
| ADX(14) trên RMA(14) | 27 | dx đầu tiên ở bar 14, ADX cần 14 dx |
| Choppiness(14) | 14 | sum/highest/lowest |
| Ribbon EMA fast/slow | 20 / 50 | EMA seed SMA |
| Ribbon HMA | ~ fast/slow + round(sqrt(len)) | WMA lồng |
| Zone pivot (7/7) | 14 để có pivot đầu, xác nhận tại bar 14 | `startBar = bar - 7` |
| Structure pivot (5/5) | 10 | |
| MTF EMA(100) | 100 bar HTF | trước đó `htfEma = na` → cả bull/bear true |
| `ta.barssince` | cần 1 sweep trước | trước đó `na` → không có s2 |

Không có ngưỡng "đủ nến" toàn cục; các lớp bật dần khi dữ liệu sẵn sàng. Buffer phải dùng
`EMPTY_VALUE` khi chưa có giá trị, không ghi 0 giả.

### 8. Execution semantics (từ `TM Fusion Zones Backtest.pine`, KHÔNG port)

Header: `pyramiding = 0`, `calc_on_order_fills = true`, `process_orders_on_close = true`,
`initial_capital = 10000`, `default_qty_type = percent_of_equity`, `default_qty_value = 100`,
commission 0.05%/chiều, slippage 0.

- Entry: chỉ khi `strategy.position_size == 0`, theo `signalLong/Short`, lọc
  `fz_strat_dir` (Long+Short / Long Only / Short Only), qty = `fz_strat_pct/100 * equity / close`.
- Exit: `strategy.exit(stop = fz_posSl, limit = fz_posTp2)` — **TP2**, không phải TP3.
- `fz_strat_on` mặc định true; `fz_strat_pct` mặc định 100.

Ba khác biệt nghiêm trọng giữa indicator state và strategy (không được port mù):

1. Indicator **adoption ghi đè** vị thế đang mở; strategy **không vào** khi đang có vị thế
   (`position_size == 0`). Hai bên lệch trade ngay khi có tín hiệu mới trong lúc mở lệnh.
2. Strategy đọc `fz_posSl`/`fz_posTp2` của **indicator state**. Nếu indicator adopt tín hiệu
   mới trong lúc strategy còn giữ vị thế cũ, SL/TP của vị thế cũ bị **đổi sang mức của
   tín hiệu mới** — có thể đặt stop sai phía và đóng lệnh ngay.
3. Indicator coi **TP3** là kết thúc trade và tính win; strategy thoát ở **TP2**. Thống kê
   win/loss của indicator không phải kết quả backtest của strategy.

Vì vậy repo này chỉ port tín hiệu + level + state để audit; **không** port entry/exit,
equity sizing, commission hay bất kỳ lệnh thật nào.

### 9. Khác biệt port MQL5 (dự kiến)

| ID | Khác biệt | Lý do / xử lý |
|---|---|---|
| D1 | MTF: Pine `request.security` (forming HTF bar) → MQL5 chọn HTF bar đã đóng gần nhất có `close_time <= chart bar close_time` | Deterministic, không dùng HTF bar đang chạy; biên đúng lúc HTF đóng cần đối chiếu CSV |
| D2 | `ta.change(time("D"))` (exchange day) → MQL5 dùng ngày theo giờ server | Không có exchange calendar; ảnh hưởng PDH/PDL; mặc định vẫn lệch ở broker UTC+2/+3 |
| D3 | Asset auto-detect: Pine dùng `syminfo.type == "crypto"`; MQL5 không có metadata tương đương | Chỉ nhận diện qua tên symbol (XAU/GOLD/BTC/ETH), còn lại `Custom`; cho phép override input |
| D4 | Pivot tie: port chọn **strict** (high[c] > mọi high trong cửa sổ; low[c] < mọi low) | Pine không tài liệu hóa tie; strict tránh pivot trùng trên plateau; cần CSV xác nhận |
| D5 | `confirmOnly = false` không port | Repaint theo thiết kế; MQL5 luôn tính trên nến đóng |
| D6 | Zone/structure/state chỉ mutate trên nến đóng, full-history recompute | Tránh state bẩn do tick trong nến; tương đương kết quả cuối nến của Pine |
| D7 | Setup/block/regime là chuỗi trong Pine → mã số enum trong buffer | EA dễ đọc; ánh xạ 1–1, ghi trong buffer contract |
| D8 | Không port dashboard, box, line, label, màu, session label | Thuần hiển thị; không ảnh hưởng tín hiệu |
| D9 | Không port `alert()` / `alertcondition` / webhook JSON | EA đọc buffer; tránh phụ thuộc TradingView |
| D10 | Không port `confirmOnly=false`, strategy, equity, commission | Signal-only, mô phỏng |
| D11 | `priceInRibbonShort` giống hệt `priceInRibbonLong` | Giữ nguyên bug/biểu thức Pine, không “sửa” |
| D12 | `ms_show` và `scr_setup` là dead input; `payloadMode Full/Slim` giống nhau | Không đưa vào MQL5; ghi nhận để không kỳ vọng parity theo các input này |

### 10. Trạng thái port

| Hạng mục | Trạng thái |
|---|---|
| Spec | DONE (tài liệu này) |
| Repaint audit | `docs/indicators/tm-fusion-zones.md` |
| Buffer contract | `docs/indicators/tm-fusion-zones.md` |
| MQL5 indicator | `mt5/Indicators/PinePort/TMFusionZones.mq5` |
| Contract tests | `mt5/Scripts/TMFusionZonesContractTests.mq5` — **PASS 82/82** (MT5, 2026-10-28) |
| Pine vs MQL5 parity | `BLOCKED` — chưa có CSV export từ TradingView |
| Strategy Tester | Contract test PASS trong tester; indicator gắn chart/plot chưa xác minh |
| EA support | `NOT_IMPLEMENTED` — EA hiện chỉ đọc Wonderwhales |

### 11. Blocker

1. Chưa có CSV reference từ Pine trên cùng symbol/timeframe/input → parity `BLOCKED`.
2. Contract tests đã PASS; indicator gắn chart chưa chạy runtime.
3. Chưa chốt quy ước MTF tại biên HTF và pivot tie → cần CSV đối chiếu.
4. License nguồn Pine chưa xác nhận.
5. EA đa indicator chưa được thiết kế; TM FZ hiện chỉ có indicator + contract tests.

## Repaint Audit — TM Fusion Zones (Pine v6)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — phân tích tĩnh trên source Pine; chưa chạy TradingView
  Bar Replay, chưa tạo alert, chưa chạy backtest. Các kết luận phụ thuộc runtime đánh dấu `PENDING` ở §13.
- **Nguồn:** [`dist/TM Fusion Zones.pine`](file:///D:/Applications/tm-trading/pine/dist/TM%20Fusion%20Zones.pine)
  (1.035 dòng) và [`dist/TM Fusion Zones Backtest.pine`](file:///D:/Applications/tm-trading/pine/dist/TM%20Fusion%20Zones%20Backtest.pine)
  (1.065 dòng). Không file Pine nào bị sửa.
- **Đặc tả nền:** `INDICATOR_SPEC_TMFusionZones.md`.

### 1. Định nghĩa repaint

| Mã | Hiện tượng | Ảnh hưởng |
|---|---|---|
| RP1 | Marker/trạng thái xuất hiện trên nến đang chạy rồi biến mất trước khi đóng | Tín hiệu “ma”, dashboard nhấp nháy |
| RP2 | Giá trị của nến **đã đóng** thay đổi khi có nến mới | Không thể parity/backtest |
| RP3 | Alert phát trước khi nến đóng | Vào lệnh trên dữ liệu chưa xong |
| RP4 | SL/TP của strategy thay đổi trong nến và áp ngược lại chính nến đó | Fill không có thật |
| RP5 | Hai lần chạy cùng input cho lịch sử khác nhau | Không dùng được làm reference |

### 2. Bản đồ phụ thuộc dữ liệu

```
open/high/low/close (+ time, symbol, mintick, syminfo.type)
  ├─ ta.atr(14)                         -> atrSafe
  ├─ ta.tr / change(high|low) / RMA(14) -> ADX
  ├─ math.sum(tr,14) / highest / lowest -> Choppiness
  ├─ ta.sma|hma|ema(close, fast|slow)   -> ribbon, slope, spread
  ├─ ta.pivothigh/low(7,7)              -> zone registration (bar xác nhận)
  ├─ var array<FzZone>                  -> top/bot/touches/broken/startBar
  ├─ ta.pivothigh/low(5,5)              -> swing, BOS/CHoCH
  ├─ ta.change(time("D"))               -> PDH/PDL
  ├─ ta.barssince(swpBull|swpBear)      -> s2 window
  ├─ request.security(HTF, ema(100))    -> htfEma  ← nguồn ngoại lai duy nhất
  ├─ var state: posSide/posBar/levels/hit flags/lastSignalBar/counters
  └─ barstate.islast                    -> dashboard, box, line, label (không tín hiệu)
```

Không có `request.security_lower_tf`, không offset âm, không mảng dữ liệu tương lai ngoài
`request.security` ở trên. Pivot là **độ trễ cấu trúc**, không phải repaint.

### 3. Cổng confirmed-bar

```pine
fz_isConfirmed = not fz_confirmOnly or barstate.isconfirmed      // dòng 147
longEligible   = longSetupDetected and ... and fz_isConfirmed     // dòng 691
shortEligible  = shortSetupDetected and ... and fz_isConfirmed    // dòng 692
fz_canAlert    = fz_payloadMode != "Off" and fz_isConfirmed       // dòng 1002
```

`confirmOnly` mặc định `true`.

**Được gate:** `signalLong`, `signalShort`, webhook `alert()`.

**Không được gate** (vẫn tính trên nến realtime):

| Thành phần | Dòng | Hệ quả |
|---|---|---|
| Đăng ký/merge/break/touch zone | 302–365 | Zone có thể đổi trạng thái giữa nến (RP1 hiển thị) |
| `inDemandZone/inSupplyZone`, zone bot/top | 368–388 | Dùng cho setup/score/risk, đổi giữa nến |
| BOS/CHoCH, sweep, PDH/PDL | 441–496 | Đổi giữa nến |
| Setup `s1/s2/s3`, `longSetupDetected` | 533–578 | Có thể true giữa nến nhưng chưa thành signal |
| Score long/short | 586–605 | Đổi giữa nến |
| SL/TP candidate | 614–645 | Đổi giữa nến |
| Gates + block reason | 648–688 | Đổi giữa nến |
| `lastSignalBar` | 706–707 | Chỉ cập nhật khi signal (đã gate) |
| Hit flags + counters + state | 741–818 | **Không gate** → có thể cập nhật giữa nến |
| `alertcondition` TP1/TP2/SL | 1007–1009 | Có thể phát giữa nến (RP3) |

Pine rollback state `var` về đầu nến realtime mỗi tick, nên **kết quả cuối nến** vẫn tất định
với dữ liệu đã đóng. Rủi ro là hiển thị/alert giữa nến, không phải RP2 trên lịch sử — trừ
thành phần MTF ở §4.

**Kết luận:** `confirmOnly = false` không port (P3). MQL5 chỉ tính trên nến đóng.

### 4. MTF — nguồn repaint chính

```pine
fz_htfEma := request.security(syminfo.tickerid, fz_mtf_tf,
              ta.ema(close, fz_mtf_len), barmerge.gaps_off, barmerge.lookahead_off)
```

`lookahead_off` ngăn dùng **bar HTF tương lai**, nhưng không làm giá trị HTF đứng yên trong
suốt bar HTF đang chạy:

- Trên nến chart realtime nằm trong một bar HTF đang hình thành, `fz_htfEma` phản ánh EMA
  của bar HTF đó tại tick hiện tại. Giá trị này thay đổi đến khi bar HTF đóng.
- Trên lịch sử, Pine tính lại theo dữ liệu đã đóng. Cách gán giá trị HTF cho các nến chart
  nằm trong cùng một bar HTF là điểm khác biệt đã được TradingView ghi nhận cho
  `request.security` + `lookahead_off`: giá trị “đúng” của bar HTF chỉ biết tại lúc đóng,
  nên biểu đồ lịch sử có thể khác những gì đã thấy realtime → **RP1 + RP5**.
- `gaps_off` giữ giá trị HTF cuối cùng và carry-forward giữa các lần cập nhật.

Ảnh hưởng tín hiệu: `htfBull/htfBear` tham gia **setup s1** (pullback) và **score MTF**.
Sai một bar HTF có thể bật/tắt s1 và đổi score vài điểm → đổi eligibility.

#### 4.1 Quy tắc port

Với nến chart `j` có thời điểm đóng `Tj`:

1. Chọn bar HTF `k` gần nhất có `close_time[k] <= Tj`.
2. `htfEma[j] = EMA(close_HTF, len)` tính trên chuỗi HTF đã đóng, seed SMA(len) giống Pine.
3. Nếu chưa đủ `len` bar HTF → `EMPTY_VALUE` (Pine `na`), và `htfBull = htfBear = true`.

Biên `close_time == Tj`: port dùng `<=` (bao gồm bar HTF vừa đóng cùng lúc). Pine có thể
không tính bar đó trong lần evaluate cuối của nến chart → **khác biệt biên, cần CSV xác nhận**.

Không dùng `iMA` trên chart TF, không dùng bar HTF đang chạy, không suy ra HTF EMA từ close
của chart. HTF EMA phải tính trên close của bar HTF.

### 5. Zone engine — state phức tạp nhất

`var array<FzZone> fz_zones` được mutate mỗi nến theo thứ tự:

1. Pivot high xác nhận → merge vào supply đầu tiên trong khoảng `atrSafe*widthAtr` hoặc push mới.
2. Pivot low xác nhận → merge/push demand.
3. Duyệt toàn mảng: break theo close, touch theo `low[1]/high[1]`.
4. Xoá zone broken.
5. `while size > zn_max: shift` (bỏ zone cũ nhất, kể cả chưa broken).
6. Tính `inDemand/inSupply` và mức bot/top với dung sai ±0.2 ATR.

Các điểm tất định:

- Pivot chỉ xuất hiện tại **bar xác nhận** `c + swLen`; `startBar = c`.
- Zone mới **có thể bị break ngay trong nến đăng ký** (bước 3 chạy sau bước 1–2).
- Merge quét từ index 0, dừng ở match đầu tiên; mở rộng top/bot, `touches += 1`,
  **không đổi `startBar`**.
- Break là vĩnh viễn trong cùng vòng đời zone: zone bị xoá, không “hồi sinh”.
- Touch chỉ tăng khi nến trước **hoàn toàn ngoài** zone (`low[1] > top` cho demand,
  `high[1] < bot` cho supply) và nến hiện tại chạm/vào zone. Giá nằm trong zone nhiều nến
  không tăng touch liên tục.
- Nhiều zone cùng chạm → zone **cuối** trong mảng ghi đè `demandZoneBot/Top`
  (và `supplyZoneTop/Bot`). `inDemand` và `inSupply` có thể cùng true.
- `halfWidth` và ngưỡng merge dùng `atrSafe` của **nến hiện tại**; trên realtime ATR đổi
  giữa nến → zone width/merge có thể nhấp nháy (RP1), nhưng cuối nến tất định.

Rủi ro realtime: các mutation zone **không gate** `fz_isConfirmed`. Nhờ rollback của Pine,
trạng thái cuối nến vẫn được tính lại từ state đầu nến, nên không bị “kẹt” zone broken giữa
nến. MQL5 **không có rollback** — nếu mutate state trên nến đang chạy, zone sẽ bị hỏng vĩnh
viễn. Vì vậy port chỉ replay trên nến đóng và recompute toàn bộ lịch sử (P1/P6).

### 6. Structure & PDH/PDL

- Pivot swing 5/5 xác nhận tại `c + 5`; `swHBar/swLBar = c`.
- BOS dùng `close` và `close[1]`; CHoCH là **edge flag** (bool cục bộ reset mỗi nến), còn
  `msTrend` là state.
- `prevSwH/prevSwL` được ghi nhưng không dùng — dead state.
- PDH/PDL: `ta.change(time("D")) != 0` xác định nến đầu ngày; khi đó `pdh/pdl` nhận
  running high/low của ngày trước, rồi reset. Trên realtime, running high/low đổi giữa nến
  nhưng cuối nến chốt.
- MQL5 không có exchange calendar → dùng ngày server (D2). Với broker UTC+2/+3, mốc ngày
  lệch so với timestamp exchange của TradingView → PDH/PDL và sweep PD khác.

### 7. State machine — thứ tự và edge case

```pine
if fz_posSide == 1
    if not fz_posTp1Hit and high >= fz_posTp1 -> ...
    if not fz_posTp2Hit and high >= fz_posTp2 -> ...
    if not fz_posTp3Hit and high >= fz_posTp3 -> đóng, win
    if low <= fz_posSl and fz_posSide != 0   -> đóng, win nếu TP1 đã hit
...
if fz_signalLong  -> adopt long
else if fz_signalShort -> adopt short
```

Các kết luận:

1. **Exit chạy trước adoption.** Cùng một nến có thể đóng trade cũ và mở trade mới tại close.
2. **TP3 thắng SL trong cùng nến.** Sau TP3, `posSide = 0` nên điều kiện SL bị chặn;
   `hitSl` không bật, nhưng `hitTp1/hitTp2` đã bật nếu giá chạm các mức đó.
3. **TP1 + SL cùng nến:** cả `hitTp1` và `hitSl` đều true; trade được tính **win**.
   Đây là lạc quan có chủ đích của Pine, không phải bug port.
4. **Adoption ghi đè vị thế đang mở** mà không đóng/tính kết quả trade cũ. Trade cũ biến
   mất khỏi thống kê. Đây là hành vi Pine (R4).
5. **Hit flags không gate confirmed.** Trên realtime có thể bật giữa nến; cuối nến chốt
   theo high/low cuối. `alertcondition` có thể phát giữa nến (RP3).
6. **Không kiểm tra hit trên chính nến entry** vì exit block nằm trước adoption. Nến entry
   không thể tự chạm TP/SL — tương đương tinh thần `process_orders_on_close`.
7. Counters: `cntWins` tăng khi TP3 hoặc SL-sau-TP1; `cntLosses` khi SL không có TP1.
   Không có break-even, không trừ counter khi adoption ghi đè.

### 8. Kịch bản intrabar

**S1 — Setup/score đúng giữa nến rồi sai lúc đóng.** `longSetupDetected`/score nhấp nháy trên
dashboard, nhưng `longEligible` gate confirmed → không signal. **RP1 hiển thị, không RP2.**

**S2 — Signal đúng ở tick cuối.** Adoption ghi entry = close, không kiểm tra TP/SL cùng nến.
Nến sau mới bắt đầu theo dõi. **Không repaint.**

**S3 — Long mở, nến chạm TP1 giữa nến rồi đóng dưới TP1.** `posTp1Hit` là `var`, được commit
`true` ở cuối nến. Sau đó SL → tính win. Port giữ nguyên trên nến đóng.

**S4 — Long mở, nến chạm TP3 và SL.** TP3 thắng, `hitSl = false`, win +1. Port đúng thứ tự.

**S5 — Long mở, nến chạm TP1 và SL.** `hitTp1 = true`, `hitSl = true`, win +1. Hai alert
`alertcondition` có thể cùng phát.

**S6 — Đang long, có signal short.** Exit long (nếu chạm) chạy trước; sau đó short được adopt.
Nếu long chưa chạm gì, nó bị **ghi đè im lặng**, không tính loss. Counters: signals +1,
shorts +1, long cũ không có kết quả.

**S7 — Đang long, có signal long mới.** Entry/SL/TP/hit flags bị reset theo tín hiệu mới;
trade cũ không được tính. Đây là re-entry im lặng.

**S8 — Bar HTF đóng giữa nến chart.** `htfEma` đổi tại tick đó; nến chart đóng sau đó dùng
giá trị mới. Lịch sử có thể đã dùng giá trị cũ cho các nến trước trong cùng bar HTF →
**RP1/RP5 tiềm năng**. Đây là lý do D1 và E-plan ở §13.

**S9 — Pivot xác nhận trên nến realtime.** Zone được đăng ký/merge/break giữa nến; cuối nến
rollback + tính lại. MQL5 chỉ đăng ký ở nến đóng. Không RP2.

**S10 — `confirmOnly = false`.** Signal có thể bật/tắt giữa nến (RP1) và lịch sử có thể khác
những gì đã thấy (RP5). Không port (P3).

### 9. Hành vi alert

| Alert | Điều kiện | Gate | Đánh giá |
|---|---|---|---|
| `TM FZ LONG` / `SHORT` | `signalLong/Short` | eligibility đã gate confirmed | An toàn với `confirmOnly=true` |
| `TM FZ TAKE PROFIT` (TP1) | `hitTp1` | **không gate** | RP3; alertcondition có thể phát giữa nến |
| `TM FZ TP2 HIT` | `hitTp2` | **không gate** | RP3 |
| `TM FZ STOP LOSS` | `hitSl` | **không gate** | RP3 |
| Webhook ENTRY | `fz_canAlert and signal` | có gate | An toàn |
| Webhook TP/SL | `fz_canAlert and hit` | có gate | An toàn, nhưng phụ thuộc hit flag cuối nến |
| TP3 | — | — | **Không có alertcondition/plotshape TP3**; chỉ đóng state |

`alertcondition` không phụ thuộc input hiển thị; tắt shape không tắt alert. `payloadMode`
chỉ phân biệt `Off`; `Full` và `Slim` tạo payload giống hệt (dead distinction). Webhook JSON
chưa được kiểm chứng runtime.

### 10. Hành vi strategy (chỉ mô tả, không port)

Header: `pyramiding = 0`, `calc_on_order_fills = true`, `process_orders_on_close = true`,
equity 10.000, `percent_of_equity` 100, commission 0.05%/chiều, slippage 0.

- Entry chỉ khi `strategy.position_size == 0`, qty = `strat_pct/100 * equity / close`.
- Exit `stop = fz_posSl`, `limit = fz_posTp2` (**TP2**, không phải TP3).

Ba lệch pha với indicator state (R5):

1. Indicator adopt tín hiệu mới bất kể đang mở lệnh; strategy bỏ qua tín hiệu khi đang có vị thế.
2. Strategy đọc `fz_posSl/fz_posTp2` của indicator state. Khi indicator adopt tín hiệu mới
   trong lúc strategy còn giữ lệnh cũ, stop/limit của lệnh cũ bị đổi sang mức của tín hiệu
   mới — có thể đặt stop sai phía và đóng lệnh ngay.
3. Indicator kết thúc trade ở TP3; strategy thoát ở TP2. Thống kê indicator ≠ kết quả backtest.

**RP4** chỉ xuất hiện nếu port execution. Repo này không port entry/exit/equity/commission.

### 11. Timestamp contract

| Trường | Định nghĩa | Ví dụ M5 |
|---|---|---|
| `bar_open_time` | Thời gian mở nến theo giờ server | `2026.10.27 20:50` |
| `signal_bar` | Nến đóng phát signal | nến `20:50` |
| `confirmed_at` | `bar_open_time + TF` | `20:55:00` |
| `detected_at` | Tick đầu tiên EA đọc buffer `shift=1` | `20:55:00 … 20:59:59` |
| `signal_id` | `FZ_LONG`, `FZ_SHORT`, `FZ_TP1`, `FZ_TP2`, `FZ_TP3`, `FZ_SL` | — |

Join parity theo `bar_open_time`, không theo `detected_at`. Với MTF, ghi kèm
`htf_bar_close_time` đã dùng để tái lập mapping.

### 12. Chính sách MQL5

| Mã | Quyết định | Lý do |
|---|---|---|
| P1 | Chỉ mutate state trên nến đóng (`j < rates_total-1`); full-history recompute khi `rates_total` đổi | Loại RP1/RP2; Pine rollback không có trong MQL5 |
| P2 | EA đọc `shift = 1`; không có input `shift = 0` | Khớp roadmap |
| P3 | **Không port** `confirmOnly = false` | Repaint theo thiết kế |
| P4 | MTF: bar HTF đã đóng gần nhất, `close_time <= chart close`; EMA seed SMA | Deterministic; biên `==` cần CSV xác nhận |
| P5 | Pivot strict hai phía; xác nhận tại `c + len`; `startBar = c` | Tránh pivot trùng plateau; D4 |
| P6 | Replay zone đúng thứ tự: register → break/touch → cleanup → trim → interaction | Khớp Pine; zone mới có thể break cùng nến |
| P7 | Ngày PDH/PDL theo giờ server | Không có exchange calendar; D2 |
| P8 | State: exits trước adoption; TP1→TP2→TP3→SL; SL bỏ qua nếu TP3 đã đóng; SL sau TP1 = win | Khớp Pine |
| P9 | Adoption ghi đè không tính trade cũ; counters đúng Pine | Không “sửa” hành vi nguồn |
| P10 | Không port alert, webhook, strategy, equity, commission | Signal-only |
| P11 | `EMPTY_VALUE` cho `na`; enum số cho setup/block/regime | Hợp đồng buffer rõ ràng |
| P12 | Không port dashboard/box/line/label/ribbon fill | Thuần hiển thị |

### 13. Kế hoạch xác minh thủ công (TradingView)

| # | Bước | Kỳ vọng | Trạng thái |
|---|---|---|---|
| E1 | FZ, XAUUSD M5, mặc định, Bar Replay từng tick | Signal chỉ xuất hiện ở tick cuối nến; không biến mất khi replay tiếp | `PENDING` |
| E2 | Ghi log `htfEma`/`htfBull` theo từng nến chart trong một bar H4, so với EMA H4 đã đóng | Xác định Pine dùng bar HTF đang chạy hay đã đóng; chốt quy tắc biên `<=` vs `<` | `PENDING` |
| E3 | Đang long, nến chạm TP1 rồi SL | Xác nhận `posTp1Hit` giữ true, trade tính win, cả hai alert cùng phát | `PENDING` |
| E4 | Đang long, nến chạm TP3 và SL | Xác nhận TP3 thắng, không có SL alert | `PENDING` |
| E5 | Có signal mới khi đang mở lệnh | Xác nhận indicator adopt/ghi đè; strategy không vào thêm | `PENDING` |
| E6 | Bật/tắt `ms_pdOn` trên cùng dữ liệu | Đếm chênh lệch s2 do PD sweep | `PENDING` |
| E7 | Đổi `sl_mode` Zone/Swing vs ATR; đổi `tp_mode` | Xác nhận SL/TP và các nhánh opp zone | `PENDING` |
| E8 | `confirmOnly=false` | Ghi nhận signal nhấp nháy; đối chiếu lịch sử | `PENDING` |
| E9 | Export CSV các cột signal/score/setup/SL/TP/posSide/regime | Làm reference parity cho MQL5 | `PENDING` |

### 14. Risk register

| ID | Phát hiện | Mức | Xử lý |
|---|---|---|---|
| R1 | `request.security` + `lookahead_off` vẫn có thể khác lịch sử/realtime khi bar HTF đang chạy | Cao | P4; E2; ghi `htf_bar_close_time` khi parity |
| R2 | Zone engine mutate mỗi nến, không gate confirmed | Cao | P1/P6; MQL5 chỉ replay nến đóng |
| R3 | Hit flags/alertcondition không gate → alert giữa nến | Trung bình | P10; EA đọc nến đóng |
| R4 | Adoption ghi đè vị thế mở, trade cũ không được tính | Cao (thống kê) | P9; ghi rõ trong spec; không dùng stats làm parity |
| R5 | Backtest đổi SL/TP lệnh cũ theo tín hiệu mới; exit TP2 vs TP3 | Cao nếu dùng backtest | Không port execution; không dùng backtest làm reference |
| R6 | Pivot tie-breaking không được Pine tài liệu hóa | Trung bình | P5 strict; đối chiếu CSV (E9) |
| R7 | Ngày server vs exchange day → PDH/PDL lệch | Trung bình | P7; test vector D; ghi rõ khi parity |
| R8 | `priceInRibbonShort` trùng `Long`; `ms_show`/`scr_setup` dead; `Full=Slim` | Thấp | Giữ nguyên; D11/D12; không kỳ vọng parity theo input chết |
| R9 | TP1 == TP2 khi opp zone nằm trong 0.8R–1R | Trung bình | Port đúng; test vector J |
| R10 | `rr2 < rrMin` so sánh input, không phải RR tính được | Thấp | Port đúng; ghi chú spec §3.11 |

### 15. Gate 2 — tiêu chí

| # | Tiêu chí | Trạng thái |
|---|---|---|
| B1 | Trả lời đủ câu hỏi repaint của roadmap Phase 2 | PASS |
| B2 | Timestamp + confirmed state cho từng signal | PASS |
| B3 | Ma trận repaint theo thành phần | PASS |
| B4 | Chính sách MQL5 không âm thầm đổi logic | PASS |
| B5 | Không tuyên bố đã kiểm chứng runtime TradingView | PASS (E1–E9 `PENDING`) |
| B6 | Không sửa Pine | PASS |

**Kết luận:** Gate 2 đạt ở mức phân tích tĩnh. Các kết luận phụ thuộc runtime (đặc biệt MTF
E2 và CSV E9) vẫn `PENDING`, không được dùng làm bằng chứng parity/backtest.

### 16. Câu hỏi còn mở

1. Pine gán giá trị HTF cho nến chart cuối cùng trong một bar HTF theo quy tắc nào? (E2/R1)
2. `ta.pivothigh/low` xử lý plateau/tie ra sao? (R6/E9)
3. Có nên thêm buffer `HTF_BAR_CLOSE_TIME` để audit mapping MTF? (cân nhắc ở buffer contract)
4. Symbol/timeframe/timezone chuẩn cho parity vẫn chưa chốt (XAUUSD M5 là ứng viên).

## Buffer Contract — TM Fusion Zones (Pine v6 → MQL5)

- **Phase:** 3 — Đặc tả thuật toán và hợp đồng buffer trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4`
- **Nguồn:** `INDICATOR_SPEC_TMFusionZones.md`,
  `REPAINT_AUDIT_TMFusionZones.md`
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không API gửi lệnh, không đọc tài khoản, không alert,
  không WebRequest, không file I/O trong indicator.

### 1. Phạm vi

1. Input của `MQL5/Indicators/PinePort/TMFusionZones.mq5`.
2. **23 buffer hợp đồng** (index 10..32) cho EA/audit + **10 buffer render** (index 0..9).
3. Bar policy: chỉ nến đã đóng; replay toàn bộ lịch sử mỗi nến.
4. Cách EA đọc buffer, chống trùng, ghi CSV (khi EA hỗ trợ — hiện `NOT_IMPLEMENTED`).
5. 82 test vector cho logic thuần trong `TMFusionZonesContract.mqh`.

Không định nghĩa: execution, sizing, commission, alert. Repo không port các phần đó.

### 2. Chính sách kế thừa Phase 2

| Mã | Chính sách | Thể hiện |
|---|---|---|
| P1 | State chỉ mutate trên nến đóng | `j == rates_total-1` không chạy engine; buffer sự kiện = 0 |
| P2 | EA đọc `shift = 1` | Mục 11 |
| P3 | Không port `confirmOnly = false` | Không có input |
| P4 | MTF: bar HTF đã đóng gần nhất, `close_time <= chart close` | `FzMapHtfIndex` |
| P5 | Pivot strict hai phía, xác nhận tại `c + len` | `FzPivotHighAt/LowAt` |
| P6 | Replay zone đúng thứ tự register → break/touch → cleanup → trim → interaction | `FzEngineStep` |
| P7 | Ngày PDH/PDL theo giờ server | `FzIsNewServerDay` |
| P8 | Exits trước adoption; TP1→TP2→TP3→SL | `FzStateStep` |
| P9 | Adoption ghi đè không tính trade cũ | `FzStateStep` |
| P10 | Không port alert/strategy/equity | Không có API giao dịch |

### 3. Input contract (40)

Không port 15 input hiển thị/alert: `payloadMode`, `rb_show`, `zn_show`, `ms_show` (dead),
`showViz`, `cBull`, `cBear`, `showSig`, `showTargets`, `showHit`, `showDash`, `dashMode`,
`dashSize`, `sessTz`, `scr_setup` (dead), `scr_strong`. Không port `confirmOnly` (luôn true).

| # | Input MQL5 | Kiểu | Default | Clamp / Options |
|---:|---|---|---:|---|
| 1 | `InpAssetMode` | enum `ENUM_FZ_ASSET` | `FZ_ASSET_AUTO` | Auto/XAU/BTC/ETH/Crypto Other/Custom |
| 2 | `InpCustomVolMult` | double | 1.0 | 0.5..3.0; chỉ dùng khi `Custom` (mở rộng D3) |
| 3 | `InpRibbonType` | enum `ENUM_FZ_MA` | `FZ_MA_EMA` | EMA/SMA/HMA |
| 4 | `InpRibbonFast` | int | 20 | 2..200 |
| 5 | `InpRibbonSlow` | int | 50 | 5..500 |
| 6 | `InpRibbonFilter` | bool | true | — |
| 7 | `InpZonePivotLen` | int | 7 | 2..50 |
| 8 | `InpZoneWidthAtr` | double | 0.5 | ≥ 0.1 |
| 9 | `InpZoneMax` | int | 10 | 2..30 |
| 10 | `InpStructPivotLen` | int | 5 | 2..20 |
| 11 | `InpSweepOn` | bool | true | — |
| 12 | `InpPdOn` | bool | true | — |
| 13 | `InpSetupPullback` | bool | true | — |
| 14 | `InpSetupSweep` | bool | true | — |
| 15 | `InpSetupRange` | bool | false | — |
| 16 | `InpPullTol` | double | 0.4 | ≥ 0.1 |
| 17 | `InpSweepConfBars` | int | 3 | 1..10 |
| 18 | `InpMtfOn` | bool | true | — |
| 19 | `InpMtfTf` | enum `ENUM_FZ_HTF` | `FZ_HTF_H4` | H1/H4/D1/W1 |
| 20 | `InpMtfLen` | int | 100 | 10..500 |
| 21 | `InpWTrend` | double | 25.0 | ≥ 0 |
| 22 | `InpWZone` | double | 25.0 | ≥ 0 |
| 23 | `InpWStruct` | double | 20.0 | ≥ 0 |
| 24 | `InpWCandle` | double | 15.0 | ≥ 0 |
| 25 | `InpWMtf` | double | 15.0 | ≥ 0 |
| 26 | `InpScrNoTrade` | int | 49 | 0..99 |
| 27 | `InpScoreMargin` | int | 8 | 0..50 |
| 28 | `InpSlMode` | enum `ENUM_FZ_SL_MODE` | `FZ_SL_ZONE_SWING` | Zone/Swing, ATR |
| 29 | `InpTpMode` | enum `ENUM_FZ_TP_MODE` | `FZ_TP_OPPOSING` | Opposing/RR, Fixed RR |
| 30 | `InpSlAtrMul` | double | 1.5 | ≥ 0.5 |
| 31 | `InpSlPadAtr` | double | 0.2 | ≥ 0.05 |
| 32 | `InpSlMinAtr` | double | 0.5 | ≥ 0.2 |
| 33 | `InpSlMaxAtr` | double | 3.5 | ≥ 1.0 |
| 34 | `InpRr1` | double | 1.0 | ≥ 0.5 |
| 35 | `InpRr2` | double | 2.0 | ≥ 1.0 |
| 36 | `InpRr3` | double | 3.0 | ≥ 1.5 |
| 37 | `InpRrMin` | double | 1.5 | ≥ 0.5 |
| 38 | `InpObstacleGate` | bool | true | — |
| 39 | `InpCoolBars` | int | 8 | ≥ 0 |
| 40 | `InpMaxBars` | int | 0 | 0 = toàn bộ; > 0 giới hạn replay để debug |

`InpMaxBars` là tiện ích debug, không có trong Pine; mặc định 0 giữ hành vi đầy đủ.

### 4. Enum

```cpp
enum ENUM_FZ_MA      { FZ_MA_EMA=0, FZ_MA_SMA=1, FZ_MA_HMA=2 };
enum ENUM_FZ_SL_MODE { FZ_SL_ZONE_SWING=0, FZ_SL_ATR=1 };
enum ENUM_FZ_TP_MODE { FZ_TP_OPPOSING=0, FZ_TP_FIXED_RR=1 };
enum ENUM_FZ_ASSET   { FZ_ASSET_AUTO=0, FZ_ASSET_XAU=1, FZ_ASSET_BTC=2,
                       FZ_ASSET_ETH=3, FZ_ASSET_CRYPTO_OTHER=4, FZ_ASSET_CUSTOM=5 };
enum ENUM_FZ_HTF     { FZ_HTF_H1=0, FZ_HTF_H4=1, FZ_HTF_D1=2, FZ_HTF_W1=3 };
enum ENUM_FZ_SETUP   { FZ_SETUP_NONE=0, FZ_SETUP_PULLBACK=1, FZ_SETUP_SWEEP=2, FZ_SETUP_RANGE=3 };
enum ENUM_FZ_BLOCK   { FZ_BLOCK_NONE=0, FZ_BLOCK_OPPOSING_ZONE=1, FZ_BLOCK_RR_MIN=2,
                       FZ_BLOCK_COOLDOWN=3, FZ_BLOCK_SCORE_MARGIN=4,
                       FZ_BLOCK_SCORE_NOTRADE=5, FZ_BLOCK_OPPOSITE_WON=6 };
enum ENUM_FZ_REGIME  { FZ_REGIME_RANGE=0, FZ_REGIME_TRANSITIONAL=1, FZ_REGIME_TRENDING=2 };
```

`SETUP` mã 2 (SWEEP) có ưu tiên cao nhất, rồi 1 (PULLBACK), rồi 3 (RANGE). Thứ tự enum
không phải thứ tự ưu tiên.

### 5. Signal ID và loại buffer

| ID | Side | Buffer | Trigger | Loại |
|---|---|---|---|---|
| `FZ_LONG` | BUY | 10 | `signalLong` | Edge |
| `FZ_SHORT` | SELL | 11 | `signalShort` | Edge |
| `FZ_TP1` | — | 22 | `hitTp1` | Edge |
| `FZ_TP2` | — | 23 | `hitTp2` | Edge |
| `FZ_TP3` | — | 24 | `hitTp3` | Edge |
| `FZ_SL` | — | 25 | `hitSl` | Edge |

Hit flags là edge thật (Pine dùng `var posTpXHit` để chặn lặp), không phải state lặp.

### 6. Buffer

`#property indicator_buffers 33`, `#property indicator_plots 10`; plot `i` map buffer `i` (0..9).

#### 6.1 Render buffers 0..9 (DATA, ngoài hợp đồng EA)

| # | Tên | Giá trị | Thiếu | Kiểu vẽ |
|---:|---|---|---|---|
| 0 | `PLOT_RIBBON_FAST` | `maFast` | `EMPTY_VALUE` | Line |
| 1 | `PLOT_RIBBON_SLOW` | `maSlow` | `EMPTY_VALUE` | Line |
| 2 | `PLOT_LONG_SIGNAL` | `low` nến signal long | `EMPTY_VALUE` | Arrow 233 |
| 3 | `PLOT_SHORT_SIGNAL` | `high` nến signal short | `EMPTY_VALUE` | Arrow 234 |
| 4 | `PLOT_HIT_TP1` | `high` nến hit TP1 | `EMPTY_VALUE` | Arrow 159 |
| 5 | `PLOT_HIT_TP2` | `high` nến hit TP2 | `EMPTY_VALUE` | Arrow 159 |
| 6 | `PLOT_HIT_SL` | `low` nến hit SL | `EMPTY_VALUE` | Arrow 251 |
| 7 | `PLOT_ACTIVE_SL` | `posSide != 0 ? posSl : EMPTY` | `EMPTY_VALUE` | Line |
| 8 | `PLOT_ACTIVE_TP1` | `posSide != 0 ? posTp1 : EMPTY` | `EMPTY_VALUE` | Line |
| 9 | `PLOT_ACTIVE_TP2` | `posSide != 0 ? posTp2 : EMPTY` | `EMPTY_VALUE` | Line |

Ribbon luôn được vẽ (không gate `rb_show`/`showViz`) — khác biệt hiển thị D8. Active levels
gate theo `posSide` đúng Pine. Không có plot TP3 (Pine không có).

#### 6.2 Contract buffers 10..32

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA dùng |
|---:|---|---|---|---|---|---|
| 10 | `SIGNAL_LONG` | Tín hiệu long đã qua mọi gate | 0/1 | 0 | Edge | **có** |
| 11 | `SIGNAL_SHORT` | Tín hiệu short đã qua mọi gate | 0/1 | 0 | Edge | **có** |
| 12 | `SCORE_LONG` | Điểm long đã round | 0..100 | 0 | Bar | audit |
| 13 | `SCORE_SHORT` | Điểm short đã round | 0..100 | 0 | Bar | audit |
| 14 | `SETUP_LONG` | Setup long phát hiện (chưa gate) | 0..3 | 0 | Bar | audit |
| 15 | `SETUP_SHORT` | Setup short phát hiện (chưa gate) | 0..3 | 0 | Bar | audit |
| 16 | `ENTRY` | `posEntry` của trade được adopt gần nhất | giá | `EMPTY_VALUE` | State | **có** |
| 17 | `SL` | `posSl` | giá | `EMPTY_VALUE` | State | **có** |
| 18 | `TP1` | `posTp1` | giá | `EMPTY_VALUE` | State | **có** |
| 19 | `TP2` | `posTp2` | giá | `EMPTY_VALUE` | State | **có** |
| 20 | `TP3` | `posTp3` | giá | `EMPTY_VALUE` | State | **có** |
| 21 | `POS_SIDE` | Vị thế sau adoption | −1/0/1 | 0 | State | **có** |
| 22 | `HIT_TP1` | TP1 chạm lần đầu | 0/1 | 0 | Edge | **có** |
| 23 | `HIT_TP2` | TP2 chạm lần đầu | 0/1 | 0 | Edge | **có** |
| 24 | `HIT_TP3` | TP3 chạm lần đầu | 0/1 | 0 | Edge | **có** |
| 25 | `HIT_SL` | SL chạm | 0/1 | 0 | Edge | **có** |
| 26 | `HTF_EMA` | EMA HTF đã đóng gần nhất | giá | `EMPTY_VALUE` | Bar | audit |
| 27 | `ATR` | `atrSafe = max(ATR14, mintick*2)` | > 0 | `EMPTY_VALUE` | Bar | **có** |
| 28 | `REGIME` | Regime | 0..2 | 1 | Bar | audit |
| 29 | `IN_DEMAND` | Nến tương tác demand zone | 0/1 | 0 | Bar | audit |
| 30 | `IN_SUPPLY` | Nến tương tác supply zone | 0/1 | 0 | Bar | audit |
| 31 | `BLOCK_LONG` | Lý do chặn long đầu tiên | 0..6 | 0 | Bar | audit |
| 32 | `BLOCK_SHORT` | Lý do chặn short đầu tiên | 0..6 | 0 | Bar | audit |

Quy ước:

- Buffer sự kiện = `0.0` trên mọi nến không có sự kiện; **không** dùng `EMPTY_VALUE`.
- `ENTRY/SL/TP1/TP2/TP3` là **state của trade được adopt gần nhất** (đúng `var fz_pos*` của
  Pine), tồn tại qua các nến flat cho tới lần adopt kế tiếp. **EA phải gate bằng `POS_SIDE`**.
- `HIT_TP3` có buffer dù Pine không vẽ shape/alert TP3; state Pine vẫn theo dõi `posTp3Hit`.
- `REGIME` mặc định `TRANSITIONAL` khi chưa đủ dữ liệu (Pine khởi tạo `"Neutral"` nhưng
  code gán `"Transitional"` trong nhánh else ngay bar đầu; xem test D4).
- `HTF_EMA` = `EMPTY_VALUE` khi `mtf_on=false` hoặc chưa đủ EMA; khi đó `htfBull = htfBear = true`.
- `BLOCK_*` chỉ là lý do **đầu tiên** theo thứ tự obstacle → RR → cooldown → margin → noTrade;
  nếu bị loại do đối thủ thắng thì mã `OPPOSITE_WON`.
- Tại nến đang chạy (`j == rates_total-1`) toàn bộ buffer = 0/`EMPTY_VALUE`; EA đọc `shift=1`.

### 7. Bar policy và state

Mỗi lần `rates_total` thay đổi (nến mới), indicator **reset state và replay từ bar 0** tới
`rates_total-2`. Trong cùng một nến, trả `rates_total` ngay. Hệ quả:

- Mọi buffer của nến đã đóng là hàm thuần của dữ liệu đã đóng → không RP2.
- Không có state ẩn sống qua lần gọi; reload indicator cho cùng kết quả.
- Chi phí O(n × (zone + pivot)) mỗi nến; zone cap 64, pivot len ≤ 50 → chấp nhận được.

State replay gồm:

```text
zones[64] + zoneCount
swH/swL + bar + prevSwH/prevSwL + msTrend
curDayH/curDayL/pdh/pdl + hasDay
prevOpen/prevHigh/prevLow/prevClose + hasPrev
lastBullSweepBar/lastBearSweepBar (-1 = chưa có)
lastSignalBar (-999)
posSide/posBar/posEntry/posSl/posTp1/posTp2/posTp3/posTp1Hit/posTp2Hit/posTp3Hit
posScore/posSetup
cntSignals/cntWins/cntLosses/cntLongs/cntShorts
```

Series được tính trước (pass 1): ATR14, ADX14, Chop14, `maFast`, `maSlow`, `htfEma`, pivot
zone (7/7), pivot structure (5/5). Pass 2 gọi `FzEngineStep` cho từng nến đóng.

### 8. Engine pipeline (mỗi nến đóng)

```text
FzEngineStep(cfg, state, bar, barIndex, out):
  1. atrSafe = bar.atr (EMPTY nếu chưa đủ ATR)
  2. Zone:
       nếu atrSafe valid và bar.znPh valid -> FzZoneRegister(side=-1, ...)
       nếu atrSafe valid và bar.znPl valid -> FzZoneRegister(side=+1, ...)
       FzZoneUpdate(state, high, low, close, prevHigh, prevLow, hasPrev)
       FzZoneCleanup(state, cfg.znMax)
       FzZoneInteract(...) -> inDemand/inSupply + bot/top (last wins)
  3. Structure:
       nếu bar.msPh valid -> prevSwH=swH; swH=msPh; swHBar=barIndex-msLen
       nếu bar.msPl valid -> prevSwL=swL; swL=msPl; swLBar=barIndex-msLen
       bosBull/bosBear (dùng prevClose, hasPrev)
       choch + msTrend
       swing sweeps (cfg.sweepOn)
       PDH/PDL update (server day) + PD sweeps (cfg.pdOn)
  4. Candles: pin/engulf/momentum (dùng prevOpen/prevClose, hasPrev)
  5. MTF: htfBull/htfBear từ bar.htfEma/htfValid
  6. Setups s1/s2/s3, priority s2 > s1 > s3
  7. Score long/short
  8. Risk long/short (SL, TP, opp zone)
  9. Gates + eligibility + mutual exclusivity; cập nhật lastSignalBar
 10. FzStateStep(exits -> adoption)
 11. Cập nhật prevOpen/High/Low/Close + hasPrev
```

`prev*` được cập nhật **cuối** nến để các điều kiện `[1]` dùng đúng nến trước.

### 9. Zone replay

```text
FzZoneRegister(side, pivot, atr, widthAtr, halfWidth, startBar):
  quét i = 0..count-1, zone cùng side, !broken, |mid - pivot| <= atr*widthAtr:
      top = max(top, pivot + halfWidth); bot = min(bot, pivot - halfWidth); touches++
      return (chỉ match đầu tiên)
  nếu không match và count < 64:
      push { top=pivot+halfWidth, bot=pivot-halfWidth, side, touches=1, broken=false, startBar }

FzZoneUpdate(high, low, close, prevHigh, prevLow, hasPrev):
  demand: close < bot -> broken
          else nếu low <= top && high >= bot && hasPrev && prevLow > top -> touches++
  supply: close > top -> broken
          else nếu high >= bot && low <= top && hasPrev && prevHigh < bot -> touches++

FzZoneCleanup(maxZones):
  compact bỏ broken (giữ thứ tự)
  while count > maxZones: xoá phần tử 0 (shift)

FzZoneInteract(high, low, atr):
  demand: low <= top + 0.2*atr && high >= bot - 0.2*atr -> inDemand=true; demandBot=bot; demandTop=top
  supply: high >= bot - 0.2*atr && low <= top + 0.2*atr -> inSupply=true; supplyTop=top; supplyBot=bot
  (zone sau ghi đè zone trước)
```

Thứ tự bắt buộc: register (supply trước, demand sau) → update → cleanup → trim → interact.
Zone mới có thể bị break ngay trong nến đăng ký.

`startBar = barIndex - znPivotLen`; merge không đổi `startBar`.

### 10. MTF mapping

`FzMapHtfIndex(htfCloseTime[], htfCount, chartCloseTime)` trả index HTF lớn nhất có
`htfCloseTime[k] <= chartCloseTime`, hoặc −1.

- `chartCloseTime = time[j] + PeriodSeconds(_Period)`.
- `htfCloseTime[k] = htfTime[k] + PeriodSeconds(htfTf)`.
- HTF rates lấy bằng `CopyRates(_Symbol, htfTf, 0, N, rates)`; loại bar đang chạy bằng điều
  kiện close time; không dùng `iMA`/`iBarShift` để tránh phụ thuộc handle.
- EMA HTF: seed `SMA(len)` trên close HTF, sau đó `alpha = 2/(len+1)`.
- Nếu `CopyRates` thất bại, thiếu bar, hoặc EMA chưa đủ → `EMPTY_VALUE` và
  `htfBull = htfBear = true` (đúng Pine `na`).

Biên `==`: dùng `<=` (bao gồm bar HTF vừa đóng cùng lúc). Đây là lựa chọn port; xem R1/E2.

### 11. EA đọc buffer

- `iCustom(_Symbol, _Period, "PinePort\\TMFusionZones.mq5", <40 inputs>)`.
- Chờ `BarsCalculated(handle) >= Bars(_Symbol,_Period)`.
- Đọc `shift = 1` cố định: `CopyBuffer(handle, FZ_BUF_SIGNAL_LONG, 1, 1, v)` …
- Dedupe theo `(symbol, timeframe, bar_open_time, signal_id)`.
- Hit flags đọc cùng nến với signal; không suy diễn lại TP/SL từ giá.
- `POS_SIDE` phải đọc cùng nến để gate `ENTRY/SL/TP1/TP2/TP3` (vì level là state bền).
- Không có `OrderSend`, `CTrade`, `AccountInfo*`, `WebRequest`, `Socket*`, `FileWrite*`.

### 12. CSV (EA — tương lai)

```
detected_at,bar_open_time,confirmed_at,symbol,timeframe,signal_id,side,
entry,sl,tp1,tp2,tp3,score,setup,regime,atr,pos_side,htf_ema,input_hash
```

- `side`: `BUY` cho `FZ_LONG`, `SELL` cho `FZ_SHORT`, `NONE` cho hit.
- `setup`: `NONE/PULLBACK/SWEEP/RANGE`; `regime`: `RANGE/TRANSITIONAL/TRENDING`.
- `input_hash` = FNV-1a 32-bit trên canonical string của `FzConfig` + `FZ_CONTRACT_VERSION`.

EA hiện chỉ đọc Wonderwhales; TM FZ EA support `NOT_IMPLEMENTED`.

### 13. Hàm contract (header)

```cpp
// math / series
double  FzClamp(double v, double lo, double hi);
bool    FzIsNa(double v);
double  FzAtrSafe(double atr, double tickSize);
double  FzTr(bool hasPrev, double high, double low, double prevClose);
double  FzSmaAt(const double &src[], int total, int end, int len);
double  FzWmaAt(const double &src[], int total, int end, int len);
double  FzEmaStep(double prev, double src, int len);
double  FzEmaAt(const double &src[], int total, int end, int len);
void    FzBuildWmaSeries(const double &src[], int total, int len, double &out[]);
void    FzBuildMaSeries(const double &src[], int total, int len, int maType,
                        double &out[]);
double  FzMaAt(const double &src[], int total, int end, int len, int maType);
void    FzBuildRmaSeries(const double &src[], int total, int len, double &out[]);
void    FzBuildAtrSeries(const double &high[], const double &low[],
                         const double &close[], int total, int len, double &out[]);
void    FzBuildAdxSeries(const double &high[], const double &low[],
                         const double &close[], int total, int len, double &out[]);
void    FzBuildChopSeries(const double &high[], const double &low[],
                          const double &close[], int total, int len, double &out[]);
int     FzMapHtfIndex(const datetime &htfCloseTime[], int count,
                      datetime chartCloseTime);

// pivot
bool    FzPivotHighAt(const double &high[], int total, int bar, int len, double &out);
bool    FzPivotLowAt(const double &low[], int total, int bar, int len, double &out);

// asset
int     FzResolveAsset(int mode, const string &symbol);
double  FzAssetVolMult(int effAsset, double customMult);

// regime
int     FzRegime(double adx, double chop);

// zones
void    FzZoneRegister(FzEngineState &st, int side, double pivot,
                       double atr, double widthAtr, double halfWidth, int startBar);
void    FzZoneUpdate(FzEngineState &st, double high, double low, double close,
                     double prevHigh, double prevLow, bool hasPrev);
void    FzZoneCleanup(FzEngineState &st, int maxZones);
void    FzZoneInteract(const FzEngineState &st, double high, double low, double atr,
                       bool &inDemand, bool &inSupply,
                       double &demandBot, double &demandTop,
                       double &supplyTop, double &supplyBot);
bool    FzNearestOpposingLevel(const FzEngineState &st, bool isLong, double close,
                               double &level, double &dist);

// score / risk / gates
double  FzScoreLong(const FzConfig &cfg, bool strongBull, bool bull,
                    bool inDemand, bool priceInRibbon, bool chochBull,
                    bool swpBull, bool bosBull, bool engulfOrPin,
                    bool candleBull, bool htfBull);
double  FzScoreShort(...);   // đối xứng
bool    FzRiskLong(const FzConfig &cfg, double close, double atr, double assetMult,
                   bool hasDemand, double demandBot, bool hasSwing, double swL,
                   bool hasOpp, double oppLevel,
                   double &sl, double &tp1, double &tp2, double &tp3, double &riskDist);
bool    FzRiskShort(...);    // đối xứng
void    FzGates(const FzConfig &cfg, double close,
                double tp1Long, double tp1Short,
                bool hasSupply, double distSupply, bool hasDemand, double distDemand,
                bool longSetup, bool shortSetup, double longScore, double shortScore,
                bool coolOk, int &blockLong, int &blockShort);
void    FzEligibility(const FzConfig &cfg, bool isConfirmed, bool longSetup,
                      bool shortSetup, double longScore, double shortScore,
                      int &blockLong, int &blockShort,
                      bool &sigLong, bool &sigShort);

// state
void    FzStateInit(FzEngineState &st);
void    FzStateStep(FzEngineState &st, int barIndex, const FzBar &bar,
                    bool sigLong, bool sigShort,
                    double slL, double tp1L, double tp2L, double tp3L,
                    int scoreL, int setupL, double slS, double tp1S, double tp2S,
                    double tp3S, int scoreS, int setupS, FzBarOut &out);
bool    FzEngineStep(const FzConfig &cfg, FzEngineState &st, const FzBar &bar,
                     int barIndex, FzBarOut &out);

// MTF / config
int     FzMapHtfIndex(const datetime &htfCloseTime[], int count, datetime chartCloseTime);
string  FzConfigCanonical(const FzConfig &cfg);
uint    FzConfigHash(const FzConfig &cfg);
```

### 14. Test vector (82)

| Nhóm | # | Nội dung |
|---|---:|---|
| A Core | 5 | clamp dưới/trên/trong; ATR floor; asset mult + auto-detect |
| B MA | 5 | SMA; EMA seed + update; WMA; HMA; dispatch + na |
| C Series | 6 | RMA seed/update; TR bar đầu; ATR chain; ADX warm-up; chop invalid → 50 |
| D Regime | 4 | Trending biên 23/56; Range chop 58; Range ADX 17.9; Transitional |
| E Ribbon | 5 | bull; bear + strong; expanding; proximity long == short; filter off + top/bot |
| F Zones | 9 | register supply/demand; merge; new ngoài width; break demand/supply; touch ngoài→vào; trim; interaction last-wins; break cùng nến |
| G Structure | 5 | pivot strict; plateau; BOS bull/bear; CHoCH; sweep swing + PD gate |
| H Candles | 4 | pin bull/bear; engulf bull/bear; momentum; rng floor |
| I MTF | 5 | biên `<=`; giữa HTF; thiếu HTF/off → both true; close == ema; EMA thiếu |
| J Setups | 5 | s1 long/short; s2 bar 0 + biên; s2 ngoài cửa sổ; s3; priority s2 > s1 > s3 |
| K Scoring | 5 | max 100; factor lẻ; mtf 0; sumW 0 → 0; round |
| L Risk | 7 | zone SL; swing fallback; ATR fallback; clamp min/max; rawSl sai phía; opp adjust; short + fixed RR |
| M Gates | 7 | obstacle; RR; cooldown biên; margin; noTrade biên; first reason; mutual tie long / short wins |
| N State | 8 | TP1; TP2; TP3; SL loss; SL sau TP1 win; TP3 + SL; TP1 + SL; adoption override + không hit nến entry |
| O Config | 2 | hash ổn định; hash đổi khi input đổi |

Chi tiết kỳ vọng nằm trong `mt5/Scripts/TMFusionZonesContractTests.mq5`. Chạy script trong
MT5 terminal là bước **thủ công**; compile không chứng minh test pass.

### 15. Trạng thái

| Hạng mục | Trạng thái |
|---|---|
| Contract | FROZEN |
| Header | `mt5/Include/PinePort/TMFusionZonesContract.mqh` |
| Indicator | `mt5/Indicators/PinePort/TMFusionZones.mq5` |
| Contract tests | `mt5/Scripts/TMFusionZonesContractTests.mq5` — **PASS 82/82** (2026-10-28) |
| EA hỗ trợ TM FZ | `NOT_IMPLEMENTED` |
| Parity | `BLOCKED` — chưa có CSV Pine |
| Runtime | `NOT_RUN` |
