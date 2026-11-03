# TM Indicator 2 — Spec, Repaint Audit và Buffer Contract

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `INDICATOR_SPEC_TMIndicator2.md`, `REPAINT_AUDIT_TMIndicator2.md`, `BUFFER_CONTRACT_TMIndicator2.md`.

Nội dung:
1. Indicator Spec — TM Indicator 2 (Pine v6, v2.1.0)
2. Repaint Audit — TM Indicator 2 (Pine v6, v2.1.0)
3. Buffer Contract — TM Indicator 2 (Pine v6 → MQL5)

---
## Indicator Spec — TM Indicator 2 (Pine v6, v2.1.0)

- **Phase:** 1 — Đặc tả thuật toán trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `PORTABLE_WITH_DIFFERENCES` (xem §13, §14)
- **Nguồn:** [`dist/TM Indicator 2.pine`](../../../tm-trading/pine/dist/TM%20Indicator%202.pine)
  (indicator, 2.243 dòng, 151 input khai báo, version 2.1.0, build 2026-10-27). Chỉ đọc, không sửa.
- **Nguyên tắc:** SIMULATION_ONLY. Port chỉ tín hiệu/trạng thái trên nến đã đóng; không webhook,
  không execution, không đọc tài khoản, không đặt lệnh.

### 1. Phạm vi

| Port | Không port |
|---|---|
| L0 input ảnh hưởng điểm/gate/risk (nhóm 1–13) | Nhóm 14 hiển thị (màu, size, dashboard mode) |
| L2 regime classifier (ADX, BBW percentile, EMA slope) | Dashboard Compact/Advanced (L9 §7) |
| L3 structure, session, S/R, FVG, OB, trendline state | `label`/`box`/`line`/`plotshape` trang trí |
| L4 momentum/volume/OBV/VWAP/overextension | Webhook JSON + `alert()` (L10) |
| L5 MTF context/setup, PD/PW, BTC leader, weekend | `request.security` cross-symbol (xem D8) |
| L6 obstacle/room-to-left gate + 6 eligibility gates | Profile `Asset Mode = Auto` suy luận symbol (xem D9) |
| L7 scoring 2.1 hai phía + regime weighting + ablation | |
| L7b entry modes A/B/C | |
| L8 plan builder + sizing + state machine 5 stage | |
| L9 event ring + lifecycle counters + statistics | |
| L10 JSON schema (đọc để đối chiếu field, không phát webhook) | |

### 2. Layer map (theo source)

| Layer | Nội dung | Dòng |
|---|---|---:|
| SHARED | `f_sessionOk`, `f_vsaColor/Name`, `f_clamp`, `f_isNewDay`, `f_sess*`, `SrZone + f_addZone/f_near*`, `f_tmClamp/LongPart/ShortPart/SideScore/ScoreLevel/MinLevel`, reason labels | 3–198 |
| L0 | 151 input (14 nhóm) | 240–436 |
| L1 | Types: `TMEvent`, `MarketRegime`, `GateStatus`, `TMPlan2`, `FvgZone`, `ObZone`; exit/stage constants | 438–529 |
| L2 | ATR/ATR%, BB(20,2), BBW percentile/squeeze, DMI, EMA slope, regime classifier, volScore | 531–593 |
| L3 | candle metrics, event ring, swings/trend, BOS/CHoCH/MSS, retest/fail, HH/LL/pull, labels, session HL, EQH/EQL, trendline, S/R, FVG, OB | 595–873 |
| L4 | EMA stack trend score, RSI/MACD, VSA+RelVol+OBV, anchored VWAP, overextension | 875–933 |
| L5 | TF hierarchy, 4 symbol MTF requests + BTC leader + weekend filter | 935–1001 |
| L6 | nearest barrier/obstacle, `f_evaluateGates` | 1003–1123 |
| L7 | group scores, regime weights, ablation A–E, side scores, direction margin | 1125–1238 |
| L7b | modes A/B/C + selection + mode gate | 1240–1325 |
| L8 | plan builder, counters, gates, event flags, state machine, statistics | 1327–1758 |
| L9 | markers, boxes/lines, liquidity lines, trendline, price zones, plots, dashboard | 1760–2164 |
| L10 | webhook JSON + alertcondition | 2166–2236 |

### 3. L0 — Input (151)

| Nhóm | Số input | Ghi chú |
|---|---:|---|
| General & Mode | 2 | `confirmOnly` (mặc định true), `payloadMode` |
| Asset Profile & Inter-market | 7 | `assetMode`, `cryptoSessionNeutral`, `minVolCheck`, `weekendFilter`, `btcLeaderOn`, `btcTicker`, `btcImpulseAtr` |
| Smart Entry Execution | 4 | `entryMode`, `limitSource`, `limitCancelBars`, `limitCancelOnTp1` |
| Entry Modes A/B/C | 6 | `modeFilterOn`, `modeA/B/C_on`, `modeSweepBars`, `modePullTol`, `modeRangeTol` |
| Dynamic Management | 8 | auto-BE, BE offset, trailing on/type/distance, time-decay, stagnant/tmax bars |
| Eligibility Gates | 6 | regime, mtf, obstacle, overext, circuit, risk |
| Market Regime | 4 | ADX trending/chop, BBW lookback, squeeze percentile |
| Obstacle & Overextension | 3 | obstacle buffer, max extension ATR, max candle ATR |
| Session | 1 | timezone (mặc định America/New_York) |
| Market Structure | 10 | swing, BOS/CHoCH/MSS/retest/fail/cont/pull toggles + windows |
| Liquidity & Zones | 17 | sweep/PD/PW/session/trendline toggles, S/R width/max, FVG, OB |
| Indicators & MTF | 21 | EMA/ATR/RSI/MACD/DMI/ADX, ctx/setup TF + lengths, htf filter/veto |
| Volume & VSA | 7 | RMA length, ratios, relVol min |
| Scoring Weights & Thresholds | 21 | 11 weight, 4 threshold, `minQuality`, `scoreMargin`, `ablationMode` |
| Risk & Targets + Futures | 16 | SL/TP/RR, maxDay, coolBars, equity/risk%/maxLev/MMR/fee/maxLosses |
| Display | 21 | không port |

MQL5 port dự kiến chỉ khai báo các input thuộc nhóm 1–13 (khoảng 130); nhóm 14 bị bỏ và ghi rõ
trong buffer contract (§3 của contract).

### 4. L1 — Types và hằng số

- `TMEvent{kind, dir, srcTime, srcBar, tf, confirmed, level}`; ring tối đa 50.
- `MarketRegime{code, trendDir, name, adx, bbwPct, isSqueeze}`; `code` 1 = TRENDING, 0 = RANGING,
  −1 = CHOPPY_SQUEEZE.
- `GateStatus{regimeOk, mtfOk, btcOk, obstacleOk, overextOk, circuitOk, allPassed, blockReason, blockMask}`.
- `TMPlan2{valid, dir, orderType, entry, limitPrice, sl, tp1, tp2, tp3, risk, evalRR, posSize,
  notional, effLev, marginReq, liqPrice, netRR, evalTarget, reason}`.
- `FvgZone/ObZone{top, bot, side, barIdx, mitigated}`.
- Exit: NONE 0, SL 1, TP1 2, TP2 3, TP3 4, BREAKEVEN 5, TRAIL 6, TIMEDECAY 7, TIMEOUT 8,
  CANCEL_TIMEOUT 9, CANCEL_MISSED 10.
- Stage: IDLE 0, PENDING_LIMIT 1, OPEN 2, TP1_BE 3, TP2_TRAIL 4.

### 5. L2 — Regime và volatility

```
ATR      = ta.atr(atrLen)
ATR%     = close > 0 ? ATR/close*100 : 0
BB       = SMA(close,20) ± 2*stdev(close,20)
BBW      = basis > 0 ? (upper-lower)/basis*100 : 0
BBW%rank = hi>lo ? (BBW - lowest(BBW,bbwLen))/(hi-lo)*100 : 50
isSqueeze= BBW%rank <= squeezePct
bbExpand = BBW > SMA(BBW,20)
ADX/DMI  = ta.dmi(dmiLen,14)
slope20  = (EMA20 - EMA20[3])/(3*ATR)
slope50  = (EMA50 - EMA50[5])/(5*ATR)
emaBull  = close>EMA20 and EMA20>EMA50 and slope20>0.03
emaBear  = close<EMA20 and EMA20<EMA50 and slope20<-0.03
```

`f_classifyRegime`:

1. `ADX >= adxTrending and (emaBull or emaBear) and not isSqueeze` → code 1, trendDir ±1.
2. else `ADX < adxChop or (isSqueeze and |slope20| < 0.05)` → code −1, trendDir 0.
3. else → code 0, trendDir 0.

`volScore = bbExpand ? +1 : isSqueeze ? −1 : 0` (không tham gia điểm hướng).

### 6. L3 — Structure, session, zones

#### 6.1 Candle

```
body    = |close-open|
range   = max(high-low, mintick)
hiWick  = high - max(close,open)
loWick  = min(close,open) - low
dispBull= body >= 1.5*ATR and hiWick < body*0.3
dispBear= body >= 1.5*ATR and loWick < body*0.3
bullPin = close>open and loWick >= 2*body
bullEng = bull bar and prev bear and close>=prevOpen and open<=prevClose and body>=prevBody
bullRej = hiWick >= range*0.55 and loWick <= range*0.15 and bull bar
cpBull  = pin + eng + 1.2*disp + 0.8*rej
cpScore = sign theo bên lớn hơn, min(1, cp/3)
```

#### 6.2 Swing/trend/structure

- Pivot strict `tm_ms_swLen` trái và phải; giá trị `high[swLen]`/`low[swLen]` tại bar xác nhận.
- Mỗi pivot mới: `prevHigh := swingHi; swingHi := high[swLen]` (tương tự low).
- Trend ±1 khi cả high và low swing tăng/giảm so với cặp trước.
- `crossOverHi = ta.crossover(close, swingHi)`; BOS up khi trend 1; CHoCH up khi trend −1;
  MSS = CHoCH + displacement cùng chiều.
- Event ring push theo thứ tự BOS → CHoCH → MSS.
- Retest: trong `[1, retestBars]` sau break, low ≤ level + tol*ATR và close > level (bull).
- Fail: trong `failBars`, close vượt level ± 0.3*ATR ngược hướng.
- Continuation: pivot mới HH/LL so với `prevHigh/prevLow`.
- Pullback: low ≤ EMA50 và close > EMA50 (bull).

#### 6.3 Session và liquidity

- Phiên theo timezone input: Asia 17:00–02:00, London 02:00–10:00, NY 07:00–15:00.
- `sessHi/sessLo` reset khi tên phiên đổi và tên ≠ `-`; cập nhật trước khi phát hiện sweep.
- PDH/PDL, PWH/PWL qua `request.security(..., [high[1], low[1]], lookahead_on)`.
- Sweep bull: low xuyên PDL/PWL/session low/equal-low rồi close quay lại trên mức.
- Event level sweep = `max(pdl, nz(sessLo,pdl))` / `min(pdh, nz(sessHi,pdh))` (giữ nguyên quirk).

#### 6.4 Zones

- S/R: pivot 10/10 → `f_addZone(px, side, ATR, width, maxZone)`; merge nếu `|mid−px| < ATR*width`,
  touches+1, không đổi side/top/bot; xoá zone broken; cắt còn `maxZone` (bỏ cũ nhất).
- Near support: `low ∈ [bot−0.3ATR, top+0.3ATR]`; near resistance tương tự với high.
- FVG bull: `low > high[2] and low−high[2] >= minAtr*ATR`; zone `{top=low, bot=high[2]}`;
  mitigated khi `low <= bot` hoặc quá `fvgLife`.
- OB bull: displacement bull + nến trước bear → `{top=open[1], bot=close[1], barIdx−1}`;
  mitigated khi `low <= bot` hoặc quá `obLife`.
- Giá limit gần nhất: FVG bull lấy midpoint cao nhất; FVG bear midpoint thấp nhất; OB bull top cao
  nhất; OB bear bot thấp nhất.

#### 6.5 Trendline 2 điểm

- Lưu 2 pivot low gần nhất và 2 pivot high gần nhất; slope theo bar; `at` tại bar hiện tại.
- Touch counter tăng khi `|low−tlUpAt| <= tlTol*ATR` (high cho downtrend).
- Chỉ dùng hiển thị và thống kê; không tham gia điểm/gate.

### 7. L4 — Momentum, volume, VWAP, overextension

```
EMA F/M/S = ta.ema(close, emaFast/Mid/Slow)
trendScore= stack bull ? +1 : stack bear ? −1 : close>F ? +0.4 : close<F ? −0.4 : 0
rsiScore  = RSI<os ? +1 : RSI>ob ? −1 : (RSI−50)/20
macdScore = hist>0 ? (hist>hist[1] ? +1 : +0.5) : (hist<hist[1] ? −1 : −0.5)
momScore  = clamp(rsiScore*0.4 + macdScore*0.6, −1, 1)
volMA     = ta.rma(nz(volume), volMaLen)
relVol    = volMA>0 ? vol/volMA : 0
volSma20  = ta.sma(vol,20)
obvSlope  = obv − nz(obv[10])
volumeScore = clamp(
  (isTim ? 1 : relVol>=rvMin ? 0.7 : 0) * (close>=open ? 1 : −1) * 0.6
  + (obvSlope>0 ? 1 : obvSlope<0 ? −1 : 0) * 0.4, −1, 1)
vwapScore = clamp((close−vwap)/nz(ATR, close*0.01), −1, 1)
extEma    = |close−EMA_F|/ATR
extCandle = (high−low)/ATR
isOverextended = extEma > maxExtAtr or extCandle > maxCandleAtr
```

VWAP neo theo ngày server: reset `cumVol/cumVwap` khi `ta.change(time("D")) != 0`, cộng
`vol*hlc3` mỗi nến.

### 8. L5 — MTF và inter-market

- Hierarchy: `sec(chart) <= sec(setup) <= sec(ctx)`.
- Context tuple: `[close[1], high[1], low[1], ema(close,ctxLen)[1], rsi(close,14)[1]]` với
  `lookahead_on`.
- Setup tuple: tương tự với `setupLen`.
- `ctxDir/setupDir = close>ema ? 1 : close<ema ? −1 : 0`; `gMtfBias = (ctxDir+setupDir)/2`.
- PD/PW daily/weekly như trên; `dayRange = (close−PDL)/(PDH−PDL)*2 − 1` nếu PDH>PDL.
- BTC leader: request cross-symbol `close[1], ema20[1], rsi14[1], atr14[1]`; chặn LONG nếu
  `btcClose < btcEma − impulse*btcAtr or btcRsi < 32`; chặn SHORT nếu ngược lại (>68).
- Weekend: crypto + cuối tuần + (`volRatio<0.8` hoặc `ATR%<0.6`) → `weekendBlocked`.

### 9. L6 — Obstacle và gates

#### 9.1 Obstacle (room-to-left)

- Quét S/R chưa broken và OB chưa mitigated: resistance gần nhất `bot > close`, support gần nhất
  `top < close`.
- PDH/PWH/PDL/PWL chỉ tính khi cách close ≥ `0.3*ATR`.
- `estDistTp1 = nz(ATR, close*0.01) * slAtrMul * rr1`.
- Chặn LONG nếu `distToRes < estDistTp1 * obstacleBuffer`; SHORT tương tự với support.
- FVG **không** là obstacle (quirk v2.1).

#### 9.2 Sáu gate + reason code

| Gate | Điều kiện chặn | Code |
|---|---|---|
| Regime | code −1; hoặc RANGING và mua nửa trên / bán nửa dưới range | `BLOCKED_REGIME` |
| MTF | setup filter ngược hướng; hoặc context veto ngược hướng | `BLOCKED_MTF` |
| BTC | LONG khi BTC dump / SHORT khi BTC pump | `BTC_DUMPING_VETO` / `BTC_PUMPING_VETO` |
| Obstacle | thiếu room tới TP1 | `BLOCKED_OBSTACLE` |
| Overextension | chỉ khi entry mode = Market cố định | `BLOCKED_OVEREXTENSION` |
| Circuit | weekend low-liquidity | `BLOCKED_LIQUIDITY` |

`rsn` giữ blocker ưu tiên đầu tiên; `mask` ghép mọi blocker.

### 10. L7 — Scoring 2.1

#### 10.1 Nhóm có hướng [−1, +1]

| Nhóm | Công thức |
|---|---|
| Trend | `trendScore` |
| Struct | BOS/CHoCH/MSS up +1; down −1; else `trend*0.5` |
| Liq | sweep bull +1; bear −1; retest bull +0.7; bear −0.7 |
| Loc | `vwapScore` |
| SR | near support +1; near resistance −1; chỉ FVG bull +0.8; bear −0.8 |
| Candle | `cpScore` |
| Volume | `volumeScore` |
| Mom | `momScore` |
| Session | `(close>=open?1:−1) * (cryptoSessionNeutral?0:0.5)` |
| MTF | `gMtfBias` |

#### 10.2 Regime weighting

| Regime | Hệ số |
|---|---|
| TRENDING | trend ×1.30, struct ×1.25, mom ×1.20, sr ×0.60 |
| RANGING | trend ×0.60, sr ×1.30, liq ×1.30, loc ×1.20 |
| CHOPPY | trend ×0.50, struct ×0.50, mom ×0.50 |

#### 10.3 Ablation A–E

| Code | Bật thêm |
|---|---|
| A | struct, loc, sr, liq, candle |
| B | + trend, momentum |
| C | + volume |
| D | + session, MTF |
| E | full |

#### 10.4 Hai phía và chọn hướng

```
wDir = Σ weight đang bật
longScore  = round(100 * clamp(Σ w*max(f,0)/wDir, 0, 1))
shortScore = round(100 * clamp(Σ w*max(−f,0)/wDir, 0, 1))
longMinOk  = longScore > scr_noTrade
shortMinOk = shortScore > scr_noTrade
gap        = |longScore − shortScore|
directionCode = NO_DIRECTION nếu cả hai fail
              | AMBIGUOUS_SETUP nếu cả hai pass và gap < scoreMargin
              | OK
dir        = OK ? (longScore>=shortScore ? 1 : −1) : 0
score100   = score của phía được chọn (hoặc max hai phía khi dir=0)
qualityLevel = dir==0 ? 0 : level(score100)
```

Quirk: `round` của Pine là ties away from zero; `quality` bị ép `NO TRADE` khi `dir == 0`.

### 11. L7b — Entry modes

| Mode | Điều kiện | Hướng |
|---|---|---|
| A Trend Pullback | regime trending, MTF không ngược, giá chạm EMA/FVG/OB trong `pullTol*ATR`, nến xác nhận cùng hướng | `regime.trendDir` |
| B Sweep Reversal | sweep còn mới trong `sweepBars`, nến pin/engulf/rejection, close vượt lại swept extreme | theo sweep |
| C Range Reversion | RANGING, range > ATR, giá ở biên trong `rangeTol*ATR`, nến xác nhận đảo chiều | ngược biên |

Ưu tiên A > B > C; `modeGateOk = not modeFilterOn or (modeReady and modeDir == dir)`.
Mode không cộng điểm, chỉ là gate.

### 12. L8 — Plan và state machine

#### 12.1 Plan

```
ordType = strict limit ? LIMIT : auto ? (overextended ? LIMIT : MARKET) : MARKET
limitPx = source FVG/OB/EMA, kẹp: buy ≤ close−mintick, sell ≥ close+mintick
entry   = LIMIT ? limitPx : close
pad     = ATR*slPadAtr
swing   = dir==1 ? nz(swingLo,low) : nz(swingHi,high)
sDist   = |entry−swing| + pad
aDist   = ATR*slAtrMul
dist    = clamp((aDist+sDist)/2, ATR*minAtr, ATR*maxAtr)
sl      = entry − dir*dist; risk = dist
r2      = max(rr2, rr1+0.5); r3 = max(rr3, r2+1.0)
tp1/2/3 = entry + dir*r*risk
evalRR  = r2; rrOk = rrMin<=0 or evalRR>=rrMin
```

Position sizing: `riskUsd = equity*risk%/100`; `posSize = riskUsd/dist`; `notional = posSize*entry`;
`effLev = notional/equity`; `marginReq = notional/maxLev`;
`liqLong = entry*(1 − 1/max(effLev,1) + MMR)`, `liqShort = entry*(1 + 1/lev − MMR)`.
Fee: `fee = notional*feeSlip%/100`; `netRR = (evalRR*riskUsd − fee)/(riskUsd + fee)`.
Plan valid khi ATR, dir, SL, TP, RR, leverage (≤ maxLev*1.05), liq, net RR đều đạt.

#### 12.2 Eligibility

```
okBar = confirmOnly ? barstate.isconfirmed : true
tradeEligible = okDir and okQuality and gates.allPassed and modeGateOk
                and barsSince>=coolBars and dayCount<maxDay
                and consecLosses<maxLosses and stage==IDLE
signal = okBar and tradeEligible and plan.valid
```

`barsSince += 1` mỗi nến, reset 0 khi entry; `dayCount/consecLosses` reset đầu ngày server.

#### 12.3 State machine

- PENDING_LIMIT: tăng `posBars`; fill khi low ≤ limit (long) / high ≥ limit (short) → OPEN,
  `posBar = bar_index`, `posBars = 0`. Huỷ nếu chạm TP1 trước khi fill (`CANCEL_MISSED`) hoặc quá
  `limitCancelBars` (`CANCEL_TIMEOUT`).
- OPEN/TP1_BE/TP2_TRAIL: tăng `posBars`; tính `maxFavR`.
- Fill bar: không tính TP (tránh lạc quan); SL vẫn tính.
- SL ưu tiên khi cùng nến chạm SL và TP.
- TP1 → stage TP1_BE, auto-BE dời SL về `entry + dir*ATR*beOffsetAtr`.
- TP2 → stage TP2_TRAIL, SL = TP1, trailing `high[1] − dist*ATR` (long, ngược lại short).
- TP3 → đóng, realized `0.4*rr1 + 0.4*rr2 + 0.2*rr3`.
- Time-decay: stage OPEN, `posBars >= stagnantBars`, `maxFavR < 0.3`, ADX < trending → đóng theo close.
- Timeout: `posBars >= maxHoldBars` → đóng theo close.
- Đóng → `needReset` deferred sang nến sau; entry mới chỉ khi stage IDLE.

### 13. Khác biệt port MQL5 dự kiến (D1–D10)

| ID | Pine | MQL5 | Lý do |
|---|---|---|---|
| D1 | `barstate.isconfirmed` | replay `j <= rates_total-2` | Cùng semantics, MT5 không có barstate |
| D2 | `var` state xuyên nến | state struct replay từ bar 0 mỗi nến mới | Deterministic, tránh state rò rỉ |
| D3 | `volume` | `tick_volume` (hoặc real volume nếu có) | MT5 symbol khác nguồn volume |
| D4 | `time(timeframe, session, tz)` | phút server + offset input | MT5 không có timezone IANA |
| D5 | `request.security(..., [1], lookahead_on)` | `CopyRates` HTF, map close-time ≤ chart open | Không có security trong MQL5 |
| D6 | 151 input, có input màu/timeframe/string | giữ nhóm 1–13; TF dùng `ENUM_TIMEFRAMES`; bỏ nhóm display | MQL5 input hẹp hơn |
| D7 | `label/box/line` và dashboard | plot buffer + object tối thiểu hoặc bỏ | Không cần cho EA/parity |
| D8 | BTC leader cross-symbol | chỉ bật khi `InpBtcSymbol` khác rỗng và có dữ liệu; nếu thiếu → gate pass | Không tự kết nối symbol ngoài |
| D9 | `assetMode = Auto` suy luận từ symbol | map symbol→profile qua input, mặc định Custom | MT5 symbol naming khác |
| D10 | `str.format_time`, webhook JSON | không port; EA/CSV dùng schema riêng | Không phát alert/webhook |

### 14. Câu hỏi mở

1. `ta.stdev` Pine dùng population stdev; cần xác nhận với dữ liệu thật khi parity.
2. `ta.dmi` Pine smoothing RMA; cần đối chiếu ADX/DI với MT5 `iADX`.
3. Volume: XAU/forex tick volume khác Pine crypto volume — cần chốt nguồn khi parity.
4. `request.security` cross-symbol BTC leader cần symbol tồn tại trong Market Watch; nếu thiếu,
   MQL5 trả EMPTY và gate pass (ghi rõ).
5. Timezone phiên: Pine dùng IANA; MQL5 dùng offset phút — cần input offset và kiểm tra DST.
6. `bar_index` của Pine là index tuyệt đối; MQL5 `j` là index mảng — mọi cửa sổ bar phải dùng
   hiệu số, không dùng giá trị tuyệt đối.

### 15. Trạng thái

- Spec: `PASS` (tài liệu).
- Repaint audit: xem `REPAINT_AUDIT_TMIndicator2.md`.
- Buffer contract: có (contract `1.0.0`, buffer 16–241).
- MQL5 code: `mt5/Indicators/PinePort/TMIndicator2.mq5`, compile 0/0.
- Runtime/parity: contract test **PASS 155/155** (2026-10-28); indicator gắn chart chưa xác minh;
  parity `BLOCKED`.

## Repaint Audit — TM Indicator 2 (Pine v6, v2.1.0)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — phân tích tĩnh trên source Pine; chưa chạy TradingView
  Bar Replay, chưa tạo alert, chưa chạy Strategy Tester. Các kết luận phụ thuộc runtime đánh dấu
  `PENDING` ở §14.
- **Nguồn:** [`dist/TM Indicator 2.pine`](file:///D:/Applications/tm-trading/pine/dist/TM%20Indicator%202.pine)
  (2.243 dòng, indicator v2.1.0, 151 input). Chỉ đọc, không sửa file Pine.
- **Đặc tả nền:** `INDICATOR_SPEC_TMIndicator2.md`.
- **Nguyên tắc:** SIMULATION_ONLY. Port chỉ tín hiệu/trạng thái trên nến đã đóng; không alert, không
  webhook, không execution, không đọc tài khoản.

### 1. Định nghĩa repaint

| Mã | Hiện tượng | Ảnh hưởng |
|---|---|---|
| RP1 | Marker/trạng thái xuất hiện trên nến đang chạy rồi biến mất trước khi đóng | Tín hiệu “ma”, dashboard nhấp nháy |
| RP2 | Giá trị của nến **đã đóng** thay đổi khi có nến mới hoặc khi tải lại chart | Không thể parity/backtest |
| RP3 | Alert phát trước khi nến đóng | Vào lệnh trên dữ liệu chưa xong |
| RP4 | SL/TP thay đổi trong nến và áp ngược lại chính nến đó | Fill không có thật |
| RP5 | Hai lần chạy cùng input cho lịch sử khác nhau | Không dùng được làm reference |

TM Indicator 2 là **indicator**. Trong inventory có sibling `TM Indicator Strategy Lab 2.pine`
(strategy, `calc_on_order_fills = true`), nhưng **không port execution** (§11). RP4 vì vậy chỉ tồn tại
ở mức mô phỏng state machine nội bộ (L8). RP1 có ở mọi thành phần tính trên nến realtime (score,
gate, plan, pivot, zone). RP2/RP5 **không tìm thấy** trong đường tính điểm/gate: các mảng state
(`tm_fvgs`, `tm_obs`, `sr_zones`, `tm_evtBuf`) chỉ được **commit ở bar-close** và block vẽ không
mutate state. Khác với TM XAU Signals 2, phần `barstate.islast` ở đây **chỉ vẽ** (§7).

### 2. Bản đồ phụ thuộc dữ liệu

```
open/high/low/close/hlc3/time + dayofweek
  ├─ ta.atr(14)                                   -> tm_atr, tm_atrPct           (536–537)
  ├─ ta.ema(close, 20/50/200) + slope 3/5         -> stack, regime, mode        (556–562)
  ├─ ta.bb(20,2) + lowest/highest(bbwLen)         -> BBW percentile, squeeze    (546–550)
  ├─ ta.dmi(14,14)                                -> ADX/DI, regime             (553)
  ├─ volume -> ta.rma(volume,20) / ta.sma(20)     -> VSA, relVol                (897–905)
  ├─ OBV thủ công + obv[10]                       -> obvSlope                   (908–911)
  ├─ ta.macd(12,26,9) / ta.rsi(14)                -> momScore                   (890–894)
  ├─ ta.pivothigh/low(5,5)                        -> swing, trend, BOS/CHoCH,   (638–676)
  │                                                  retest/fail, eq HL, trendline
  ├─ ta.pivothigh/low(10,10)                      -> S/R zones                  (804–809)
  ├─ request.security x5 (ctx/setup/D/W/BTC)      -> MTF, PD/PW, BTC veto       (947–996)
  ├─ var arrays: events(50), sr_zones(8), fvgs(20), obs(15)
  ├─ var state: swing/prev, trend, break, sweep memory, session HL,
  │             VWAP accumulators, dayCount/barsSince/consecLosses,
  │             pos stage/entry/sl/tps/bars/maxFavR, lifecycle + stats
  └─ barstate.islast -> zone boxes (chỉ vẽ, không mutate state)               (1937–1965)
```

Không có `request.security_lower_tf`, không offset âm, không đọc dữ liệu tương lai ngoài 5 lời gọi
`request.security` ở §4. Pivot là **độ trễ cấu trúc** (10 nến với S/R), không phải repaint.

### 3. Cổng confirmed-bar

```pine
tm_confirmOnly = input.bool(true, "Chi tin hieu nen da dong (no-repaint)")   // 245
tm_okBar       = tm_confirmOnly ? barstate.isconfirmed : true                // 1478
tm_signal      = tm_okBar and tm_tradeEligible and tm_riskEligible           // 1487
```

**Được gate bởi `tm_okBar`:**

| Thành phần | Dòng |
|---|---|
| `tm_signal` (điều kiện mở vị thế) | 1487 |
| Candidate / Eligible counters | 1513–1521 |
| Mở vị thế mới | 1728 |
| `alert()` ENTRY/PENDING/FILLED/BE/TP/SL/TIME_EXIT/CANCEL | 2204–2226 |
| Alert EVENT (kèm `barstate.isconfirmed`) | 2229–2235 |

**Không được gate** (tính trên nến realtime):

| Thành phần | Dòng | Hệ quả |
|---|---|---|
| Toàn bộ L1–L8: ATR, EMA, regime, structure, zone, scoring | 536–1238 | Dashboard/score/gate nhấp nháy giữa nến (RP1) |
| `tm_plan2` + 6 gate | 1426, 1476 | Plan/blocker đổi liên tục trong nến |
| Quản lý PENDING_LIMIT (fill/cancel) | 1569–1591 | Có thể fill/cancel giữa nến |
| Quản lý OPEN/TP1/TP2 (SL/TP/trail/decay/timeout) | 1594–1725 | Có thể đóng vị thế giữa nến; cuối nến chốt theo high/low |
| `alertcondition` TP/SL/TP1/TP2/BE | 2195–2202 | **Có thể phát giữa nến** dù `confirmOnly = true` (RP3) |
| Event push BOS/CHoCH/MSS/SWEEP | 679–689, 979–983 | Push mọi tick, chỉ ghi cờ `confirmed`; ring 50 |

Pine v6 rollback `var` (kể cả array) về trạng thái đầu nến realtime khi tick mới đến, nên **giá trị
cuối nến là tất định** với dữ liệu đã đóng. Hai ngoại lệ cần xác minh runtime:

1. Event ring có thể nhận event trùng trong nến nếu môi trường không rollback array đúng (E1).
2. `alertcondition` TP/SL không đi qua `tm_okBar`, nên alert có thể phát trước khi nến đóng (E7).

**Kết luận:** `confirmOnly = false` không port (P2). MQL5 chỉ tính trên nến đóng; mọi event/entry
đều là bar-close. Alert/webhook không port (P9).

### 4. MTF, PD/PW và BTC — năm `request.security`

| # | Dòng | TF | Biểu thức | Dùng cho |
|---|---|---|---|---|
| 1 | 947 | `tm_ctxTf` (mặc định `D`) | `close[1]`, `high[1]`, `low[1]`, `ema(close,tm_ctxLen)[1]`, `rsi(close,14)[1]` | `tm_ctxDir`, `tm_gMtfBias`, veto |
| 2 | 951 | `tm_setupTf` (mặc định `60`) | như trên với `tm_setupLen` | `tm_setupDir`, filter |
| 3 | 958 | `D` | `high[1]`, `low[1]` | PDH/PDL, sweep, obstacle, dayRange |
| 4 | 962 | `W` | `high[1]`, `low[1]` | PWH/PWL, sweep, obstacle |
| 5 | 989 | `tm_btcTicker` (mặc định `BINANCE:BTCUSDT.P`), TF chart | `close[1]`, `ema20[1]`, `rsi14[1]`, `atr14[1]` | BTC leader veto |

`lookahead_on` luôn đi kèm `[1]` ⇒ giá trị dùng là bar HTF/D/W **đã đóng trước bar hiện tại**; không
có RP2/RP3 từ nhóm này. `dynamic_requests = true` (dòng 2) cho phép ticker/TF động; MQL5 không có
cơ chế tương đương nên TF/symbol là input cố định.

Quy tắc port (P3):

- Với nến chart mở tại `Tj`, chọn bar HTF `k` gần nhất có `close_time[k] <= Tj`; tính EMA/RSI/ATR
  trên chuỗi HTF đã đóng; seed SMA(`len`) như Pine; thiếu bar → `EMPTY_VALUE` (Pine `na`).
- `tm_tfHierarchyOk = sec(chart) <= sec(setup) <= sec(ctx)` (940–943). Trên chart D, setup H1 và
  ctx D vi phạm điều kiện ⇒ `ctxDir = setupDir = 0`, `gMtfBias = 0`; port giữ nguyên.
- PDH/PDL, PWH/PWL tổng hợp từ nến chart theo ngày/tuần server; tuần bắt đầu thứ Hai (P4).
- BTC leader: chỉ bật khi `InpBtcSymbol` khác rỗng **và** symbol có dữ liệu; nếu thiếu →
  `tm_needBtcLeader = false` (gate pass). Không tự thêm symbol vào Market Watch (P8).

### 5. Session, VWAP, mốc ngày/tuần

- `tm_sessTz` mặc định `America/New_York` (302); cửa sổ Asia 17:00–02:00, London 02:00–10:00,
  NY 07:00–15:00 (43–50). Tên phiên ưu tiên `London/NY > New York > London > Asia > "-"` (52–53).
- `tm_sessHi/Lo` (748–759): reset khi tên phiên đổi **và** tên mới khác `-`; khi tên là `-`
  (15:00–17:00 NY) biến **không reset** → dùng mức cũ cho đến phiên kế tiếp. Port giữ nguyên.
- Thứ tự cập nhật: session HL được cập nhật **trước** sweep (752–757 so với 965–966) và đã bao gồm
  high/low của chính nến hiện tại, nên nhánh sweep session (`low < tm_sessLo`, `high > tm_sessHi`)
  **không thể đúng trong phiên có tên**; chỉ có thể bật khi tên phiên là `-`, dùng mức cũ. Port giữ
  nguyên (quirk, test tương ứng ở contract).
- Sweep dùng thêm PDH/PDL, PWH/PWL và equal HL tại `low[tm_ms_swLen]` / `high[tm_ms_swLen]`
  (965–966); mức sweep được ghi nhớ trong `tm_lastSweepBullPx/BearPx` + bar (971–983) cho Mode B.
- VWAP (915–927): accumulator `tm_cumVol`, `tm_cumVwap` reset bằng `f_isNewDay()` =
  `ta.change(time("D")) != 0`. Trên nến đầu tiên `ta.change` trả `na` (falsy) nên nhánh `else` chạy
  và accumulator bắt đầu từ volume nến đầu; port coi nến đầu là ngày mới (P7). VWAP dùng `hlc3`,
  không phải `close`.
- `tm_isWeekend` theo `dayofweek` của sàn; chỉ chặn khi symbol là crypto **và** `volRatio < 0.8`
  hoặc `atrPct < 0.6` (999–1001). Port map crypto qua input profile, không suy luận tên symbol (P11).
- `tm_dayCount` reset bằng `f_isNewDay()` (1452–1454); `tm_barsSince` tăng mỗi nến và reset khi mở
  vị thế (1450, 1744).

Port dùng offset phút cố định (`mktOffsetMin`, `srvOffsetMin`) thay IANA timezone (D4). Người dùng
phải chỉnh offset khi DST đổi; tài liệu runtime ghi rõ.

### 6. Pivot, structure, event ring

- `ta.pivothigh/low(high/low, tm_ms_swLen, tm_ms_swLen)` với mặc định 5 (638–639): xác nhận tại
  `bar_index`, giá trị nằm ở `high[5]`/`low[5]`, `tm_hiBar/loBar = bar_index - 5` (648–656).
  Trên nến realtime pivot có thể xuất hiện/biến mất khi high/low hiện tại đổi → RP1 hiển thị; tại
  close thì chốt (trễ cấu trúc 5 nến).
- `tm_trend` chỉ đổi khi **cả** swing high và swing low dịch cùng chiều (659–663); một swing đơn lẻ
  không đổi trend.
- BOS/CHoCH là edge flag qua `ta.crossover/under` (666–673); MSS = CHoCH + displacement cùng nến
  (675–676). `tm_lastBreakLvl/Bar/Dir` giữ qua các nến cho retest/failed breakout (692–699).
- Event ring 50 là state; `f_pushEvent` push rồi `shift` khi vượt 50 (630–635). Chỉ có **bốn loại
  event** được push: BOS, CHoCH, MSS (679–689) và SWEEP (979–983). RETEST/FAIL/CONT/PULL chỉ là
  boolean dùng cho score/label, **không vào ring**. Thứ tự push trong nến: BOS → CHoCH → MSS → SWEEP;
  một nến có thể có nhiều event. `srcBar` là `bar_index` của nến push (không phải bar pivot),
  `srcTime = time`.
- Cờ `confirmed` trong event lấy trực tiếp `barstate.isconfirmed`; ring vẫn nhận event khi
  `confirmOnly = true` nhưng nến chưa đóng — đây là lý do alert EVENT lọc thêm `barstate.isconfirmed`
  (2229) và dedupe theo `srcBar` (2230–2235). Engine không dedupe; port expose event cuối nến.
- Ring có thể chứa event “nháp” nếu array không rollback (E1). Port replay từ đầu nến nên chỉ push
  một lần cho mỗi nến đã đóng.

### 7. Shared state, zone GC và mutation

#### 7.1 FVG / Order Block — mitigation một chiều, mỗi nến

```pine
for g in tm_fvgs                       // 825–831
    if bar_index - g.barIdx > tm_fvg_life
        g.mitigated := true
    if g.side == 1 and low <= g.bot
        g.mitigated := true
    if g.side == -1 and high >= g.top
        g.mitigated := true
```

`tm_fvgs` và `tm_obs` (843–863) là `var array` shared; mitigation chạy **mọi nến**, không phụ thuộc
`barstate.islast`. Trong replay, chuỗi này tất định; trong live, giá trị cuối nến cũng tất định nhờ
rollback. Mitigation là một chiều: zone đã mitigated **không được gỡ** (đúng ý đồ — zone bị xâm phạm
thì chết). Port giữ nguyên; test cần kiểm tra thứ tự mitigation trong cùng nến (giá chạm zone trước
khi hết life hay ngược lại đều dẫn đến `mitigated = true`).

`tm_nearFvgBullPx/BearPx` và `tm_nearObBullPx/BearPx` (833–873) chỉ đọc zone chưa mitigated, dùng cho
limit entry. Không có state mutation ngoài mitigation.

#### 7.2 S/R `broken` — dead field

`f_addZone` (73–88) có nhánh `if z2.broken → array.remove`, và `f_nearSupport/Resistance` (90–102)
lọc `not z.broken`. Nhưng **toàn source không có lệnh gán `.broken := true`** (chỉ khởi tạo
`SrZone.new(..., false)` tại 82). Vì vậy:

- `broken` luôn `false`; nhánh remove và filter là dead code.
- Không có RP2/RP5 từ S/R (khác TM XAU Signals 2, nơi `broken` bị set trong block `barstate.islast`).

Port giữ field `broken` trong struct để parity cấu trúc nhưng không bao giờ set; ghi rõ trong contract.

#### 7.3 Zone box GC — chỉ vẽ

```pine
if barstate.islast and tm_showViz and tm_showPriceZones   // 1937
    for bx in tm_zoneBoxes
        box.delete(bx)
    array.clear(tm_zoneBoxes)
    ...
```

Block này **chỉ** xoá/tạo `box`, đọc `z.broken`, `g.mitigated`, `o.mitigated`; không gán lại state
tính toán. `barstate.islast` không ảnh hưởng score/gate/plan/state machine. Port bỏ toàn bộ (P9);
không cần mô phỏng GC.

#### 7.4 Trendline và touch counter

Trendline 2 điểm (766–801) và `tm_tlLoTouch/HiTouch` chỉ phục vụ dashboard; không tham gia score,
gate hay plan. Không port (P9). Việc reset counter khi có pivot mới (778–789) là quirk hiển thị,
không ảnh hưởng tín hiệu.

### 8. State machine — thứ tự và edge case

Thứ tự trong một nến (L8):

```pine
if tm_needReset                // 1550  (1) deferred reset từ nến trước
if tm_posStage == PENDING      // 1569  (2) fill / cancel limit
if tm_posStage >= OPEN         // 1594  (3) SL/TP/BE/trail/decay/timeout
if tm_okBar and tm_signal ...  // 1728  (4) mở vị thế mới
```

- **Deferred reset:** đóng vị thế đặt `tm_needReset := true` (1725); reset chạy đầu nến **kế tiếp**
  (1550–1566). Nến đóng lệnh vẫn ở stage cũ nên **không thể mở lệnh mới cùng nến** (1728 yêu cầu
  `IDLE`). Từ nến sau mới có thể entry lại.
- **PENDING_LIMIT:** tăng `posBars` mỗi nến (1570); fill khi `low <= limit` (long) / `high >= limit`
  (short) (1572). Limit được tạo ở cuối nến tín hiệu nên **fill sớm nhất là nến kế tiếp** (khối 2
  chạy trước khối 4). Huỷ nếu chạm TP1 trước khi fill (`CANCEL_MISSED`, 1582–1586) hoặc
  `posBars >= tm_limitCancelBars` mặc định 5 (1587–1591). Cancel cũng cần reset deferred ⇒ không
  entry lại cùng nến.
- **Fill bar:** khi limit fill, stage → OPEN, `posBar = bar_index`, `posBars = 0` (1576–1580); sau đó
  khối (3) **chạy ngay trong cùng nến** vì stage đã ≥ OPEN. Vì vậy fill bar:
  - SL **được** kiểm tra (an toàn, giả định xấu nhất);
  - TP bị **chặn** bởi `tm_fillBar` (`hit1/hit2/hit3` đều `not tm_fillBar`, 1608–1612) vì không có
    dữ liệu intrabar để biết limit fill trước hay sau lúc chạm TP;
  - `maxFavR` vẫn cập nhật (1597–1598).
- **Market entry:** khối (4) mở ở `close` nến tín hiệu; khối (3) đã chạy trước đó nên **không** xét
  SL/TP trên nến entry. SL bắt đầu từ nến kế tiếp — đây là gap risk của mô phỏng bar-close, không
  phải repaint.
- **Ưu tiên SL:** nếu cùng nến chạm cả SL và TP → loss (`hitSl and hitAnyTp`, 1624), kể cả khi đang
  TP1_BE/TP2_TRAIL (thì ghi BE/TRAIL, realized 0.4·rr1 hoặc 0.4·rr1+0.4·rr2 trừ fee).
- **Ưu tiên TP3 > TP2 > TP1** khi không có SL (1665–1685). Chạm TP2 và TP1 cùng nến → chỉ TP2 xử lý
  (stage nhảy TP2_TRAIL, SL = TP1); TP1 không chạy nhánh BE. Quirk, port giữ nguyên.
- **Auto-BE:** TP1 → `tm_posSl := entry + dir*ATR*beOffsetAtr` (mặc định 0.05 ATR), chỉ khi
  `tm_autoBeOn` (1683–1685).
- **Trailing:** chỉ ở TP2_TRAIL; `trailLvl` dùng `high[1]`/`low[1]` (nến trước) ± `trailDistAtr·ATR`
  (1688–1690) ⇒ không lookahead. SL chỉ siết, không nới.
- **Time-decay:** stage OPEN, `posBars >= tm_stagnantBars` (15), `maxFavR < 0.3`, `ADX < 22` →
  đóng theo `close` (1693–1705). **Timeout:** `posBars >= tm_maxHoldBars` (300) → đóng theo `close`
  (1708–1719). Cả hai dùng `close` nến hiện tại, không dùng giá TP/SL.
- **Một vị thế tại một thời điểm:** entry chỉ khi `IDLE`; strategy sibling đặt `pyramiding = 0`.
- **Thống kê:** `tm_statTp1Hits` chỉ tăng khi stage OPEN, có TP chạm và không SL cùng nến (1617);
  đóng lệnh tăng `statTotalTrades/statClosedN`, cộng realized R (1721–1725).

### 9. Scoring, gate và tính tất định

- `f_tmSideScore` = `math.round(100 * clamp(weighted/totalWeight, 0, 1))` (130–131). MQL5 dùng
  `MathRound` (ties away from zero) và double; cần test các giá trị .5 (contract sẽ có vector).
- Hai phía độc lập: `longScore` từ `max(f,0)`, `shortScore` từ `max(-f,0)`; cùng trọng số/threshold
  (1208–1212). Không có “signed quality score” kiểu v2.0.
- Chọn hướng (1215–1220): một phía phải `> 49`; nếu cả hai `> 49` và `gap < 8` →
  `AMBIGUOUS_SETUP`; ngược lại `OK`. Quality tối thiểu `SETUP` (mặc định) ⇒ score của phía được
  chọn phải `> 64` (level 2). Khác quirk `rr1 < rrMin` của TM XAU Signals 2, default ở đây có
  `rr2 = 2.0 ≥ rrMin = 1.5` nên **không bị khoá sẵn**; tuy nhiên `netRR` sau phí 0.08% vẫn có thể
  chặn khi ATR quá nhỏ so với giá (risk distance nhỏ ⇒ fee/risk lớn) — cần test vector cho cả hai.
- Regime (569–589): TRENDING khi `ADX ≥ 22` + EMA aligned + không squeeze; CHOPPY khi
  `ADX < 18` hoặc squeeze + `|slope20| < 0.05`; còn lại RANGING. Regime chỉ đổi trọng số, không đổi
  dấu feature (1171–1184).
- Ablation A–E (1191–1203) chỉ tắt feature, không tắt gate — đúng chủ đích an toàn.
- 6 gate (1058–1123) chạy trước plan; obstacle dùng `close` hiện tại, ATR hiện tại, S/R + OB + PD/PW
  (FVG **cố ý** không tính, 1019–1022). Gate order và reason-code mask ổn định (1509).
- Mode gate A/B/C (1259–1325) chọn mode theo regime/sweep/range; mode B dùng cửa sổ
  `tm_modeSweepBars` (mặc định 3) và giá sweep đã lưu; mode C mặc định tắt. Ưu tiên A > B > C.
- Toàn bộ score/gate/plan là hàm của dữ liệu đã đóng + state; không đọc `barstate.islast` hay
  object vẽ ⇒ replay tất định (P10).

### 10. Kịch bản intrabar

| Kịch bản | Pine | Port |
|---|---|---|
| Nến realtime đổi high/low | score/gate/plan/pivot đổi liên tục (RP1) | Không tính nến live; chỉ nến đóng |
| Limit fill rồi giá chạm TP ngay trong nến | TP bị chặn (`tm_fillBar`), SL vẫn xét | Cùng công thức, test vector |
| Limit fill rồi giá chạm SL trong nến | SL thắng, loss | Cùng |
| Market entry rồi giá chạm SL trong nến entry | Không xét SL (khối 3 trước khối 4) | Cùng |
| Nến chạm SL và TP | SL thắng | Cùng |
| Nến chạm TP2 và TP1 | TP2 xử lý, stage trail, SL = TP1 | Cùng |
| Nến chạm TP3 | Đóng, realized 0.4/0.4/0.2 | Cùng |
| Đóng lệnh hôm nay, signal lại cùng nến | Không entry (stage chưa reset) | Cùng |
| Timeout | `posBars ≥ 300`, exit theo close | Cùng |
| Time-decay | `posBars ≥ 15`, maxFavR < 0.3, ADX < 22, exit close | Cùng |
| `dayCount` đạt `maxDay` (4) | Chặn entry đến hết ngày server | Cùng |
| Circuit breaker 3 lỗi liên tiếp | Chặn entry đến hết ngày (reset theo ngày) | Cùng |

### 11. Alert, webhook và strategy sibling

- `alertcondition` (2195–2202) và `alert()` JSON `tm2.signal.v2.1` (2204–2235) **không port** (P9).
  Contract chỉ expose score/dir/quality/gate/plan/state/event để EA tự quyết định.
- Lưu ý: `alertcondition` TP/SL **không** đi qua `tm_okBar`; có thể phát giữa nến. Alert EVENT có
  lọc `barstate.isconfirmed` và dedupe theo `srcBar` (2229–2235). Nếu sau này cần parity alert, phải
  tái tạo đúng hai tầng lọc này.
- Payload JSON dùng `sig_id = "TM2_" + ticker + "_" + tf + "_" + time + "_" + L/S`,
  `score_side`, `long_score`, `short_score`, `score_gap`, `score_meta`, `direction_code`, `status`,
  `top_block_reason`, `blockers`, `eval_target`, `rr`, `net_rr`, `atr`, `pos_size`, `notional`,
  `eff_lev`, `liq`. Chỉ đọc để đối chiếu field; không phát webhook.
- Sibling `TM Indicator Strategy Lab 2.pine` là strategy cùng engine nhưng đặt
  `calc_on_order_fills = true`, `process_orders_on_close = false`, `pyramiding = 0`; fill của nó là
  intrabar và **không thể** khớp với port bar-close. Không port execution; nếu cần parity với
  strategy phải audit riêng (thứ tự fill, commission 0.06%, slippage 1 tick).

### 12. Timestamp contract

- `TMEvent.srcBar` = `bar_index` của nến push (không phải bar pivot nguồn), `srcTime` = `time` của
  nến push, `tf` = `timeframe.period` dạng string Pine (`"15"`, `"60"`, `"D"`, `"W"`).
- `tm_posSigId` dùng `time` nến tín hiệu; port expose `signalBarTime` riêng, không tái tạo chuỗi ID.
- CSV/parity dùng `bar_open_time` = `time[]` của MT5. MTF không expose timestamp bar HTF trong
  buffer; khi parity cần log `htfCloseTime` từ indicator (E4).
- `tm_posBar` là `bar_index` tuyệt đối của Pine; MQL5 dùng `j` mảng — mọi so sánh `fillBar` phải là
  so sánh index trong cùng replay, không dùng giá trị tuyệt đối (P10).

### 13. Chính sách MQL5

| Quyết định | Nội dung |
|---|---|
| P1 | Chỉ xử lý nến `j <= rates_total-2`; nến live để trống |
| P2 | Bỏ `confirmOnly`; luôn confirmed (bar-close) |
| P3 | MTF qua `CopyRates`, chọn `close_time <= bar.openTime`; EMA/RSI/ATR seed SMA/RMA như Pine |
| P4 | PD/PW tổng hợp theo ngày/tuần server; tuần bắt đầu thứ Hai |
| P5 | S/R `broken` luôn false; không set trong replay (dead field) |
| P6 | Volume = `tick_volume` (real volume nếu symbol có) — ghi trong contract |
| P7 | VWAP reset đầu ngày server; nến đầu tiên là ngày mới |
| P8 | BTC leader tùy chọn; thiếu symbol/dữ liệu → gate pass, không tự thêm symbol |
| P9 | Không port trendline, label/box/line, dashboard, alert, webhook |
| P10 | Replay toàn bộ từ bar 0 mỗi lần có nến mới để dựng lại `var` state |
| P11 | Asset profile là input tường minh; không suy luận từ tên symbol |

### 14. Kế hoạch xác minh thủ công (TradingView)

| # | Kiểm tra | Kỳ vọng | Trạng thái |
|---|---|---|---|
| E1 | Bar Replay 300 nến, theo dõi event ring | Không có event trùng/đổi sau khi nến đóng | `PENDING` |
| E2 | Chart M15, PDH/PDL tại 00:00 sàn | Khớp high/low ngày trước | `PENDING` |
| E3 | PWH/PWL đầu tuần | Khớp high/low tuần trước, tuần bắt đầu thứ Hai | `PENDING` |
| E4 | MTF ctx D / setup H1 tại bar HTF đóng | Không dùng bar đang hình thành; ghi `htfCloseTime` | `PENDING` |
| E5 | 15:00–17:00 NY | `sessName = "-"`, session HL giữ mức cũ | `PENDING` |
| E6 | Limit fill bar chạm TP | Không tính TP; SL vẫn tính | `PENDING` |
| E7 | `confirmOnly = true`, nến chạm TP | `alertcondition` TP có thể phát trước close (xác nhận RP3) | `PENDING` |
| E8 | Nến chạm SL và TP | Kết quả loss | `PENDING` |
| E9 | Nến chạm TP2 + TP1 | Stage trail, SL = TP1, không BE | `PENDING` |
| E10 | Timeout 300 nến | Đóng theo close, `evTimeout` | `PENDING` |
| E11 | Time-decay 15 nến, maxFavR < 0.3, ADX < 22 | Đóng theo close | `PENDING` |
| E12 | Chart D (ctx D, setup H1) | `tfHierarchyOk = false`, MTF bias = 0 | `PENDING` |
| E13 | BTC symbol thiếu dữ liệu | Gate BTC pass, không lỗi runtime | `PENDING` |
| E14 | Default config (score > 64, gap ≥ 8) | Có tín hiệu khi đủ điều kiện (không bị khoá như XAU2) | `PENDING` |

### 15. Risk register

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Bar-close simulation khác fill intrabar của strategy sibling | Cao | Không port execution; tài liệu cảnh báo; parity riêng nếu cần |
| `alertcondition` TP/SL phát giữa nến (RP3) | Trung bình | Không port alert; EA chỉ đọc buffer nến đóng |
| Offset DST sai → session/PDH/VWAP lệch | Trung bình | Input offset; tài liệu yêu cầu chỉnh khi DST |
| `tick_volume` khác `volume` của TradingView | Trung bình | Ghi contract; parity dùng cùng nguồn volume |
| MTF map lệch biên `close_time == openTime` | Trung bình | Dùng `<=`; test E4 |
| BTC symbol không tồn tại trong MT5 | Trung bình | P8: tắt gate, không lỗi; test E13 |
| EMA/RSI/ATR seed khác (SMA/RMA) | Trung bình | Port đúng seed; vector test warm-up |
| `max_bars_back = 1000` giới hạn cửa sổ Pine | Thấp | Replay từ bar 0; ghi nhận khác biệt khi parity |
| Rounding `MathRound` vs Pine `math.round` | Thấp | Vector test giá trị .5 |

### 16. Gate 2 — tiêu chí

- [x] Spec đầy đủ L0–L10, layer map + line numbers.
- [x] Xác định cổng confirmed và các thành phần không gate.
- [x] Xác định 5 `request.security`, quy tắc closed-bar, cross-symbol.
- [x] Xác định state mutation: FVG/OB mitigation, S/R `broken` dead, box GC read-only.
- [x] Liệt kê quirk: session gap, sweep session, fill-bar TP suppression, SL precedence,
  TP2/TP1 same-bar, deferred reset, timeout/time-decay.
- [x] Kế hoạch E1–E14 (chưa chạy).
- [ ] E1–E14 có kết quả thật từ TradingView (chưa).
- [ ] CSV reference từ Pine cho parity (chưa).

### 17. Câu hỏi còn mở

1. Array rollback của Pine v6 có thực sự loại bỏ event “nháp” trong nến realtime không? Cần E1 xác
   nhận trước khi thiết kế buffer event.
2. `ta.dmi` của Pine và `iADX` của MT5 khác smoothing/khởi tạo — cần vector đối chiếu trước khi
   khoá contract.
3. `ta.stdev` trong `ta.bb` là population stdev; MT5 `iBands` dùng cách tính khác — cần xác nhận
   BBW percentile khi parity.
4. Chart D với `ctxTf = D`: `tfHierarchyOk = false` làm MTF trung tính; đây là hành vi mong muốn
   hay cần đổi default cho chart D? (Port giữ nguyên; ghi trong hướng dẫn.)
5. Volume nguồn nào dùng cho XAU/forex trong MT5 (tick vs real)? Cần chốt khi parity.
6. `max_bars_back = 1000` ảnh hưởng cửa sổ S/R/OBV thế nào trên chart dài? Port replay từ bar 0;
   cần so sánh khi có CSV.

## Buffer Contract — TM Indicator 2 (Pine v6 → MQL5)

- **Phase:** 3 — Hợp đồng buffer và test vector trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4`
- **Nguồn:** `INDICATOR_SPEC_TMIndicator2.md`,
  `REPAINT_AUDIT_TMIndicator2.md`,
  [`dist/TM Indicator 2.pine`](../../../tm-trading/pine/dist/TM%20Indicator%202.pine)
  (2.243 dòng, 151 input, v2.1.0 — chỉ đọc).
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không `OrderSend`, không `CTrade`, không đọc tài
  khoản, không alert/webhook, không `WebRequest`, không file I/O trong indicator.

### 1. Phạm vi

1. Input của `mt5/Indicators/PinePort/TMIndicator2.mq5` (**118 input**: 113 port từ Pine +
   5 input MQL5-only).
2. **242 buffer**: **16 buffer render** (index 0..15) + **226 buffer hợp đồng** (index 16..241)
   cho EA/audit/parity.
3. Bar policy: chỉ nến đã đóng; replay toàn bộ lịch sử mỗi nến.
4. Cách EA đọc buffer, dedupe, ghi CSV (EA hỗ trợ: `NOT_IMPLEMENTED`).
5. **155 test vector** cho logic thuần trong `TMIndicator2Contract.mqh`.

Không định nghĩa: execution, sizing thật, commission, alert, dashboard, trendline, label/box/
table. Repo không port các phần đó.

### 2. Chính sách kế thừa Phase 2

| Mã | Chính sách | Thể hiện |
|---|---|---|
| P1 | State chỉ mutate trên nến đóng; replay toàn bộ khi `rates_total` đổi | §7 |
| P2 | EA đọc `shift = 1`; không có input `shift = 0` | §10 |
| P3 | Không port `confirmOnly = false`; không có input confirm | §3.3 |
| P4 | MTF: bar HTF đã đóng gần nhất có `close_time <= chart **open** time` | §9.7 |
| P5 | S/R: cold replay, **không bao giờ** đánh `broken`; không phụ thuộc toggle hiển thị | §9.4 |
| P6 | Pivot strict hai phía, xác nhận tại `c + len`, giá trị tại `[len]` | §9.2 |
| P7 | Session theo offset phút cố định; PDH/PDL/PWH/PWL theo ngày/tuần **server** | §9.3 |
| P8 | Event ring 50 giữ nguyên thứ tự push Pine; không dedupe trong ring | §9.2 |
| P9 | Không port alert/webhook/dashboard/trendline/visual | — |
| P10 | `EMPTY_VALUE` cho `na`; enum số cho quality/regime/mode/order/stage/exit/reason/event | §4 |
| P11 | Volume = `tick_volume` | §9.6 |
| P12 | Không port 38 input hiển thị/chết; thay `sessTz`/`btcTicker` bằng input MQL5 | §3 |
| P13 | Không "sửa" quirk Pine (fill-bar, TP1 counter, BE label, session `-`, thứ tự reason) | §14 |
| P14 | Warm-up: chỉ báo chưa đủ → group `EMPTY` → side score `EMPTY`, `NO_DIRECTION`, không plan | §9.8, P2 |

### 3. Input contract (118)

151 input Pine → **113 port** + 5 input MQL5-only. Bỏ 38 input:
`confirmOnly`, `payloadMode`, `minVolCheck` (chết), `gate_mtf` (chết), `w_atr` (chết),
`adxMin` (dashboard), `sl_swing` (chết), `trailType` (chết), `liq_sweepOn` (label),
`liq_tlOn`/`liq_tlTol`/`liq_tlMaxDev` (trendline), `sr_showOn`, `fvg_showOn`, `ob_showOn`,
`vol_showMA`, `sessTz` (thay offset), `btcTicker` (thay `InpBtcSymbol`), `showViz`, `cBull`,
`cBear`, `showSig`, `showHit`, `showZone`, `zoneLen`, `showEma`, `showPd`, `showPw`, `showSess`,
`showPriceZones`, `showTl`, `showMsLabels`, `showSweepLabels`, `showVwap`, `showVol`, `showDash`,
`dashSize`, `dashMode`.

#### 3.1 Nhóm MQL5-only (5)

| # | Input | Kiểu | Default | Ghi chú |
|---:|---|---|---:|---|
| 1 | `InpSrvOffsetMin` | int | 180 | Offset server → UTC (phút) |
| 2 | `InpMktOffsetMin` | int | −300 | Offset UTC → giờ phiên NY (DST = −240) |
| 3 | `InpMaxBars` | int | 0 | 0 = toàn bộ; > 0 giới hạn replay để debug |
| 4 | `InpBtcSymbol` | string | `""` | Rỗng → BTC neutral (không veto) |
| 5 | `InpAssetIsCrypto` | bool | false | Bổ sung cho `syminfo.type == crypto` |

Giờ thị trường = `serverTime − InpSrvOffsetMin·60 + InpMktOffsetMin·60`. Ngày/tuần server dùng
trực tiếp `time[j]`.

#### 3.2 Nhóm logic port từ Pine (113)

| # | Input | Kiểu | Default | Clamp |
|---:|---|---|---:|---|
| 6 | `InpAssetMode` | enum `ENUM_TM2_ASSET` | 0 Auto | 0..6 |
| 7 | `InpCryptoSessNeutral` | bool | true | — |
| 8 | `InpWeekendFilter` | bool | true | — |
| 9 | `InpBtcLeaderOn` | bool | true | — |
| 10 | `InpBtcImpulseAtr` | double | 1.5 | ≥ 0.5 |
| 11 | `InpEntryMode` | enum `ENUM_TM2_ENTRY_MODE` | 2 Auto | 0..2 |
| 12 | `InpLimitSource` | enum `ENUM_TM2_LIMIT_SOURCE` | 0 FVG50 | 0..2 |
| 13 | `InpLimitCancelBars` | int | 5 | 1..20 |
| 14 | `InpLimitCancelOnTp1` | bool | true | — |
| 15 | `InpModeFilterOn` | bool | true | — |
| 16 | `InpModeAOn` | bool | true | — |
| 17 | `InpModeBOn` | bool | true | — |
| 18 | `InpModeCOn` | bool | false | — |
| 19 | `InpModeSweepBars` | int | 3 | 1..20 |
| 20 | `InpModePullTol` | double | 0.35 | ≥ 0.05 |
| 21 | `InpModeRangeTol` | double | 0.35 | ≥ 0.05 |
| 22 | `InpAutoBeOn` | bool | true | — |
| 23 | `InpBeOffsetAtr` | double | 0.05 | ≥ 0 |
| 24 | `InpTrailOn` | bool | true | — |
| 25 | `InpTrailDistAtr` | double | 1.5 | ≥ 0.5 |
| 26 | `InpTimeDecayOn` | bool | true | — |
| 27 | `InpStagnantBars` | int | 15 | 5..60 |
| 28 | `InpMaxHoldBars` | int | 300 | 10..2000 |
| 29 | `InpGateRegime` | bool | true | — |
| 30 | `InpGateObstacle` | bool | true | — |
| 31 | `InpGateOverext` | bool | true | — |
| 32 | `InpGateCircuit` | bool | true | — |
| 33 | `InpGateRisk` | bool | true | — |
| 34 | `InpRegimeAdxTrending` | double | 22 | 10..50 |
| 35 | `InpRegimeAdxChop` | double | 18 | 5..30 |
| 36 | `InpRegimeBbwLen` | int | 100 | 20..300 |
| 37 | `InpRegimeBbwSqueezePct` | double | 20 | 5..50 |
| 38 | `InpObstacleBuffer` | double | 0.7 | 0.3..2.0 |
| 39 | `InpMaxExtAtr` | double | 2.2 | ≥ 1.0 |
| 40 | `InpMaxCandleAtr` | double | 2.5 | ≥ 1.0 |
| 41 | `InpMsSwingLen` | int | 5 | 2..20 |
| 42 | `InpMsBosOn` | bool | true | — |
| 43 | `InpMsChochOn` | bool | true | — |
| 44 | `InpMsMssOn` | bool | true | — |
| 45 | `InpMsRetestOn` | bool | true | — |
| 46 | `InpMsRetestBars` | int | 10 | 1..100 |
| 47 | `InpMsRetestTolAtr` | double | 0.5 | ≥ 0 |
| 48 | `InpMsFailOn` | bool | true | — |
| 49 | `InpMsFailBars` | int | 5 | 1..50 |
| 50 | `InpMsContOn` | bool | true | — |
| 51 | `InpMsPullOn` | bool | true | — |
| 52 | `InpLiqPdOn` | bool | true | — |
| 53 | `InpLiqPwOn` | bool | false | — |
| 54 | `InpLiqSessOn` | bool | true | — |
| 55 | `InpSrWidthAtr` | double | 0.5 | ≥ 0.05 |
| 56 | `InpSrMax` | int | 8 | 1..20 |
| 57 | `InpFvgMinAtr` | double | 0.3 | ≥ 0.05 |
| 58 | `InpFvgMax` | int | 20 | 1..50 |
| 59 | `InpFvgLife` | int | 100 | 10..500 |
| 60 | `InpObMax` | int | 15 | 1..30 |
| 61 | `InpObLife` | int | 150 | 10..300 |
| 62 | `InpEmaFast` | int | 20 | 2..500 |
| 63 | `InpEmaMid` | int | 50 | 5..500 |
| 64 | `InpEmaSlow` | int | 200 | 10..500 |
| 65 | `InpAtrLen` | int | 14 | 1..200 |
| 66 | `InpRsiLen` | int | 14 | 2..200 |
| 67 | `InpRsiOb` | double | 70 | 50..99 |
| 68 | `InpRsiOs` | double | 30 | 1..50 |
| 69 | `InpMacdFast` | int | 12 | 2..200 |
| 70 | `InpMacdSlow` | int | 26 | 5..200 |
| 71 | `InpMacdSignal` | int | 9 | 1..200 |
| 72 | `InpDmiLen` | int | 14 | 2..200 |
| 73 | `InpCtxTf` | `ENUM_TIMEFRAMES` | `PERIOD_D1` | H1/H4/D1/W1/MN1 |
| 74 | `InpCtxLen` | int | 200 | 10..500 |
| 75 | `InpSetupTf` | `ENUM_TIMEFRAMES` | `PERIOD_H1` | M15/M30/H1/H4 |
| 76 | `InpSetupLen` | int | 50 | 5..500 |
| 77 | `InpHtfFilter` | bool | true | — |
| 78 | `InpHtfVetoOn` | bool | true | — |
| 79 | `InpVolMaLen` | int | 20 | 5..100 |
| 80 | `InpVolSpikeR` | double | 2.2 | ≥ 1.5 |
| 81 | `InpVolRVH` | double | 1.8 | ≥ 1.0 |
| 82 | `InpVolRH` | double | 1.2 | ≥ 0.8 |
| 83 | `InpVolRN` | double | 0.8 | ≥ 0.4 |
| 84 | `InpVolRL` | double | 0.4 | ≥ 0.1 |
| 85 | `InpRvMin` | double | 1.2 | ≥ 0.5 |
| 86 | `InpWTrend` | double | 15 | ≥ 0 |
| 87 | `InpWStruct` | double | 15 | ≥ 0 |
| 88 | `InpWLiq` | double | 12 | ≥ 0 |
| 89 | `InpWLoc` | double | 8 | ≥ 0 |
| 90 | `InpWSr` | double | 10 | ≥ 0 |
| 91 | `InpWCandle` | double | 10 | ≥ 0 |
| 92 | `InpWVol` | double | 8 | ≥ 0 |
| 93 | `InpWMom` | double | 7 | ≥ 0 |
| 94 | `InpWSess` | double | 4 | ≥ 0 |
| 95 | `InpWMtf` | double | 4 | ≥ 0 |
| 96 | `InpScrNoTrade` | int | 49 | 0..99 |
| 97 | `InpScrWeak` | int | 64 | 1..99 |
| 98 | `InpScrSetup` | int | 74 | 1..99 |
| 99 | `InpScrStrong` | int | 84 | 1..99 |
| 100 | `InpMinQuality` | enum `ENUM_TM2_MINQ` | 2 SETUP | 1..4 |
| 101 | `InpScoreMargin` | int | 8 | 0..50 |
| 102 | `InpAblation` | enum `ENUM_TM2_ABLATION` | 5 E | 1..5 |
| 103 | `InpSlAtrMul` | double | 1.5 | ≥ 0.1 |
| 104 | `InpSlPadAtr` | double | 0.2 | ≥ 0 |
| 105 | `InpSlMinAtr` | double | 0.5 | ≥ 0.1 |
| 106 | `InpSlMaxAtr` | double | 3.0 | ≥ 0.5 |
| 107 | `InpRr1` | double | 1.0 | ≥ 0.5 |
| 108 | `InpRr2` | double | 2.0 | ≥ 1.0 |
| 109 | `InpRr3` | double | 3.0 | ≥ 1.5 |
| 110 | `InpRrMin` | double | 1.5 | ≥ 0 |
| 111 | `InpMaxDay` | int | 4 | ≥ 1 |
| 112 | `InpCoolBars` | int | 8 | ≥ 0 |
| 113 | `InpRiskEquity` | double | 10000 | ≥ 100 |
| 114 | `InpRiskPct` | double | 1.0 | 0.1..10 |
| 115 | `InpRiskMaxLev` | double | 20 | 1..125 |
| 116 | `InpRiskMmr` | double | 0.005 | 0.001..0.05 |
| 117 | `InpRiskFeeSlipPct` | double | 0.08 | 0..1 |
| 118 | `InpRiskMaxLosses` | int | 3 | 1..10 |

Hằng số nội bộ (không input): `TM2_SR_PIV = 10` (`ta.pivot*(10,10)`), `TM2_DMI_SMOOTH = 14`,
`TM2_BB_LEN = 20`, `TM2_BB_MULT = 2.0`, `TM2_BBW_MA = 20` (SMA cho `bbExpand`),
`TM2_VOL_SMA = 20` (RelVol), `TM2_OBV_LAG = 10`, `TM2_EVT_MAX = 50`,
`TM2_MACD` dùng EMA seed SMA, `TM2_STDEV` population.

### 4. Enum và hằng số

```cpp
#define TM2_CONTRACT_VERSION   "1.0.0"
#define TM2_PLOT_BUFFERS       16
#define TM2_CONTRACT_BUFFERS   226
#define TM2_TOTAL_BUFFERS      242
#define TM2_CONTRACT_FIRST     16
#define TM2_MAX_SR             20
#define TM2_MAX_FVG            50
#define TM2_MAX_OB             30
#define TM2_MAX_EVT            50
#define TM2_OBV_MAX            12

enum ENUM_TM2_ASSET  { TM2_ASSET_AUTO=0, TM2_ASSET_XAU=1, TM2_ASSET_BTC=2,
                       TM2_ASSET_ETH=3, TM2_ASSET_LIQ_ALT=4,
                       TM2_ASSET_HIGH_RISK=5, TM2_ASSET_CUSTOM=6 };
enum ENUM_TM2_ENTRY_MODE   { TM2_ENTRY_MARKET=0, TM2_ENTRY_LIMIT_STRICT=1,
                             TM2_ENTRY_AUTO=2 };
enum ENUM_TM2_LIMIT_SOURCE { TM2_LIMIT_FVG50=0, TM2_LIMIT_OB_EDGE=1,
                             TM2_LIMIT_EMA_FAST=2 };
enum ENUM_TM2_QUALITY { TM2_Q_NOTRADE=0, TM2_Q_WEAK=1, TM2_Q_SETUP=2,
                        TM2_Q_STRONG=3, TM2_Q_APLUS=4 };
enum ENUM_TM2_MINQ   { TM2_MINQ_WEAK=1, TM2_MINQ_SETUP=2,
                       TM2_MINQ_STRONG=3, TM2_MINQ_APLUS=4 };
enum ENUM_TM2_ABLATION { TM2_ABL_A=1, TM2_ABL_B=2, TM2_ABL_C=3,
                         TM2_ABL_D=4, TM2_ABL_E=5 };
enum ENUM_TM2_DIRCODE { TM2_DIRCODE_OK=0, TM2_DIRCODE_NONE=1,
                        TM2_DIRCODE_AMBIG=2 };
enum ENUM_TM2_REGIME  { TM2_REGIME_CHOP=-1, TM2_REGIME_RANGE=0,
                        TM2_REGIME_TREND=1 };
enum ENUM_TM2_SESSION { TM2_SESS_NONE=0, TM2_SESS_ASIA=1, TM2_SESS_LONDON=2,
                        TM2_SESS_NY=3, TM2_SESS_LONDON_NY=4 };
enum ENUM_TM2_BUCKET  { TM2_BUCKET_VERYLOW=0, TM2_BUCKET_LOW=1,
                        TM2_BUCKET_NORMAL=2, TM2_BUCKET_HIGH=3,
                        TM2_BUCKET_VERYHIGH=4, TM2_BUCKET_TIM=5 };
enum ENUM_TM2_EVENT   { TM2_EVT_NONE=0, TM2_EVT_BOS=1, TM2_EVT_CHOCH=2,
                        TM2_EVT_MSS=3, TM2_EVT_SWEEP=4 };
enum ENUM_TM2_MODE    { TM2_MODE_NONE=0, TM2_MODE_A=1, TM2_MODE_B=2,
                        TM2_MODE_C=3 };
enum ENUM_TM2_ORDER   { TM2_ORDER_NONE=0, TM2_ORDER_MARKET=1,
                        TM2_ORDER_LIMIT=2 };
enum ENUM_TM2_STAGE   { TM2_STAGE_IDLE=0, TM2_STAGE_PENDING=1,
                        TM2_STAGE_OPEN=2, TM2_STAGE_TP1_BE=3,
                        TM2_STAGE_TP2_TRAIL=4 };
enum ENUM_TM2_CLOSE   { TM2_X_NONE=0, TM2_X_SL=1, TM2_X_TP1=2, TM2_X_TP2=3,
                        TM2_X_TP3=4, TM2_X_BREAKEVEN=5, TM2_X_TRAIL=6,
                        TM2_X_TIMEDECAY=7, TM2_X_TIMEOUT=8,
                        TM2_X_CANCEL_TIMEOUT=9, TM2_X_CANCEL_MISSED=10 };

enum ENUM_TM2_REASON
{
   TM2_R_OK=0,
   TM2_R_NO_SETUP=1,
   TM2_R_NO_DIRECTION=2,
   TM2_R_AMBIGUOUS=3,
   TM2_R_WAIT_CONFIRMATION=4,
   TM2_R_WAIT_PULLBACK=5,
   TM2_R_BLOCK_SCORE_LONG=6,
   TM2_R_BLOCK_SCORE_SHORT=7,
   TM2_R_BLOCK_MTF=8,
   TM2_R_BLOCK_REGIME=9,
   TM2_R_BLOCK_LIQUIDITY=10,
   TM2_R_BLOCK_OBSTACLE=11,
   TM2_R_BLOCK_OVEREXT=12,
   TM2_R_BLOCK_NO_ATR=13,
   TM2_R_BLOCK_BAD_SL=14,
   TM2_R_BLOCK_BAD_TP=15,
   TM2_R_BLOCK_RR=16,
   TM2_R_BLOCK_NET_RR=17,
   TM2_R_BLOCK_MAX_LEV=18,
   TM2_R_BLOCK_LIQUIDATION=19,
   TM2_R_BLOCK_COOLDOWN=20,
   TM2_R_BLOCK_DAILY_LIMIT=21,
   TM2_R_BLOCK_CIRCUIT=22,
   TM2_R_BLOCK_POSITION_OPEN=23,
   TM2_R_BTC_DUMPING=24,
   TM2_R_BTC_PUMPING=25,
   TM2_R_MODE_DISABLED=26,
   TM2_R_MODE_REGIME_MISMATCH=27,
   TM2_R_MODE_INVALIDATED=28,
   TM2_R_MODE_A_PULLBACK=29,
   TM2_R_MODE_B_SWEEP=30,
   TM2_R_MODE_C_RANGE=31
};
```

`PLAN_REASON` dùng trực tiếp `ENUM_TM2_REASON`: `VALID = TM2_R_OK`, `NO_DIRECTION`,
`BLOCK_NO_ATR`, `BLOCK_BAD_SL`, `BLOCK_BAD_TP`, `BLOCK_RR`, `BLOCK_MAX_LEV`,
`BLOCK_LIQUIDATION`, `BLOCK_NET_RR`.

`MODE_DISABLED` và `MODE_REGIME_MISMATCH` có trong bảng label Pine nhưng **không bao giờ** được
`tm_modeReason` phát (filter off trả `OK`); giữ enum để đủ bộ mã.

### 5. Signal ID

| ID | Ý nghĩa | Buffer trigger | Loại |
|---|---|---|---|
| `TM2_LONG` | Signal long đã qua mọi gate + plan | 59 `SIGNAL` + 20 `DIR=1` | Edge |
| `TM2_SHORT` | Signal short | 59 + 20 `DIR=−1` | Edge |
| `TM2_LIMIT` | Limit pending được tạo | 63 `EV_PENDING` | Edge |
| `TM2_FILL` | Limit khớp | 64 `EV_FILLED` | Edge |
| `TM2_TP1/2/3` | Chạm TP1/TP2/TP3 | 66 `EV_TP` = 1/2/3 | Edge |
| `TM2_SL` | Chạm SL (đóng) | 67 `EV_SL` | Edge |
| `TM2_BE` | Auto break-even | 68 `EV_BE` | Edge |
| `TM2_TRAIL` | Trailing cập nhật tại TP2 | 69 `EV_TRAIL` | Edge |
| `TM2_TIMEOUT` | Timeout | 70 `EV_TIMEOUT` | Edge |
| `TM2_DECAY` | Time-decay exit | 71 `EV_DECAY` | Edge |
| `TM2_CLOSE` | Đóng vị thế (mọi lý do) | 72 `EV_CLOSE` | Edge |
| `TM2_CANCEL` | Huỷ limit | 65 `EV_CANCEL` + 73 | Edge |

EA suy ra side từ `SIGNAL=1` + `DIR=±1`; mọi tín hiệu vào lệnh phải kèm `PLAN_VALID=1`.

### 6. Buffer

`#property indicator_buffers 242`, `#property indicator_plots 16`; plot `i` map buffer `i`
(0..15). Buffer 16..241 là `INDICATOR_CALCULATIONS`.

#### 6.1 Render buffers 0..15 (DATA, ngoài hợp đồng EA)

| # | Tên | Giá trị | Thiếu | Kiểu vẽ |
|---:|---|---|---|---|
| 0 | `PLOT_EMA_FAST` | `emaF` | `EMPTY_VALUE` | Line |
| 1 | `PLOT_EMA_MID` | `emaM` | `EMPTY_VALUE` | Line |
| 2 | `PLOT_EMA_SLOW` | `emaS` | `EMPTY_VALUE` | Line |
| 3 | `PLOT_ATR` | `atr` | `EMPTY_VALUE` | `DRAW_NONE` (xem ghi chú) |
| 4 | `PLOT_VWAP` | `vwap` | `EMPTY_VALUE` | Line |
| 5 | `PLOT_VOLUME` | `tick_volume` | 0 | Histogram |
| 6 | `PLOT_LONG_ENTRY` | `low` nến `EV_ENTRY && POS_DIR==1` | `EMPTY_VALUE` | Arrow 233 |
| 7 | `PLOT_SHORT_ENTRY` | `high` nến `EV_ENTRY && POS_DIR==-1` | `EMPTY_VALUE` | Arrow 234 |
| 8 | `PLOT_HIT_TP` | `high` nến `EV_TP>0` | `EMPTY_VALUE` | Arrow 159 |
| 9 | `PLOT_HIT_SL` | `low` nến `EV_SL` | `EMPTY_VALUE` | Arrow 251 |
| 10 | `PLOT_ACTIVE_SL` | `POS_DIR!=0 ? POS_SL : EMPTY` | `EMPTY_VALUE` | Line |
| 11 | `PLOT_ACTIVE_TP1` | `POS_DIR!=0 ? POS_TP1 : EMPTY` | `EMPTY_VALUE` | Line |
| 12 | `PLOT_ACTIVE_TP2` | `POS_DIR!=0 ? POS_TP2 : EMPTY` | `EMPTY_VALUE` | Line |
| 13 | `PLOT_ACTIVE_TP3` | `POS_DIR!=0 ? POS_TP3 : EMPTY` | `EMPTY_VALUE` | Line |
| 14 | `PLOT_ACTIVE_LIMIT` | `POS_STAGE==1 ? POS_LIMIT : EMPTY` | `EMPTY_VALUE` | Line |
| 15 | `PLOT_SCORE100` | `SCORE100` | `EMPTY_VALUE` | `DRAW_NONE` (xem ghi chú) |

EMA/ATR/VWAP/volume luôn vẽ, không gate `show*` (P12). Không vẽ box/label/dashboard/
trendline/zone (P9).

**Ghi chú triển khai (deviation D1 — MQL5).** MQL5 chỉ cho một cửa sổ phụ cho mỗi
indicator và mọi `SetIndexBuffer` phải nằm trong indicator đó, nên `PLOT_ATR` (#3)
và `PLOT_SCORE100` (#15) — hai plot Pine nằm ở pane riêng — được khai báo
`DRAW_NONE`. Buffer vẫn được bind và ghi đầy đủ giá trị (buffer 18 `SCORE100` là
bản hợp đồng của #15), chỉ không render. Muốn xem chúng thì mở một instance thứ
hai của indicator trên chart phụ (nếu cần), hoặc đọc buffer 18/171 (`ATR`).

#### 6.2 Contract buffers 16..241 (226)

Quy ước: cột **Thiếu** là giá trị khi `na`/không áp dụng. Giá = `EMPTY_VALUE`; enum/cờ = 0.
**EA** = buffer EA được phép dùng trực tiếp.

##### A. Điểm, hướng, chất lượng (14)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 16 | `LONG_SCORE` | `f_tmSideScore` phía LONG | 0..100 | `EMPTY` | Bar | **có** |
| 17 | `SHORT_SCORE` | Điểm phía SHORT | 0..100 | `EMPTY` | Bar | **có** |
| 18 | `SCORE100` | Điểm phía được chọn (hoặc max khi dir 0) | 0..100 | `EMPTY` | Bar | **có** |
| 19 | `SCORE_GAP` | `abs(LONG−SHORT)` | 0..100 | `EMPTY` | Bar | audit |
| 20 | `DIR` | Hướng chọn | −1/0/1 | 0 | Bar | **có** |
| 21 | `DIRECTION_CODE` | `ENUM_TM2_DIRCODE` | 0..2 | 0 | Bar | **có** |
| 22 | `QUALITY` | `ENUM_TM2_QUALITY` | 0..4 | 0 | Bar | **có** |
| 23 | `QUALITY_LEVEL` | Cấp 0..4 | 0..4 | 0 | Bar | audit |
| 24 | `MIN_REQ_LEVEL` | `f_tmMinLevel(InpMinQuality)` | 1..4 | 0 | Bar | audit |
| 25 | `OK_QUALITY` | `level >= minReq` | 0/1 | 0 | Bar | audit |
| 26 | `SCORE_BLOCK` | `ENUM_TM2_REASON` của score/direction | 0..7 | 0 | Bar | **có** |
| 27 | `ABLATION_CODE` | 1..5 | 1..5 | 0 | Bar | audit |
| 28 | `W_DIR_TOTAL` | Tổng weight directional hiệu dụng | ≥ 0 | 0 | Bar | audit |
| 29 | `LONG_WEIGHTED` | `Σ w · max(g,0)` | ≥ 0 | `EMPTY` | Bar | audit |

##### B. Gate và block (12)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 30 | `GATE_REGIME` | Gate 1 pass | 0/1 | 1 | Bar | audit |
| 31 | `GATE_MTF` | Gate 2 pass (setup + veto) | 0/1 | 1 | Bar | audit |
| 32 | `GATE_BTC` | BTC leader pass | 0/1 | 1 | Bar | audit |
| 33 | `GATE_OBSTACLE` | Gate 3 pass | 0/1 | 1 | Bar | audit |
| 34 | `GATE_OVEREXT` | Gate 4 pass | 0/1 | 1 | Bar | audit |
| 35 | `GATE_CIRCUIT` | Gate 5 pass (weekend/liquidity) | 0/1 | 1 | Bar | audit |
| 36 | `GATE_ALL` | `allPassed` | 0/1 | 0 | Bar | **có** |
| 37 | `GATE_TOP_REASON` | `rsn` đầu tiên | `ENUM_TM2_REASON` | 0 | Bar | audit |
| 38 | `NO_TRADE_REASON` | Chuỗi ưu tiên đầy đủ | `ENUM_TM2_REASON` | 0 | Bar | **có** |
| 39 | `OK_COOL` | `BARS_SINCE >= InpCoolBars` | 0/1 | 0 | Bar | audit |
| 40 | `OK_DAY` | `DAY_COUNT < InpMaxDay` | 0/1 | 0 | Bar | audit |
| 41 | `OK_CIRCUIT` | `CONSEC_LOSSES < InpRiskMaxLosses` | 0/1 | 0 | Bar | audit |

##### C. Plan (17)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 42 | `PLAN_VALID` | `plan.valid` | 0/1 | 0 | Bar | **có** |
| 43 | `PLAN_REASON` | `ENUM_TM2_REASON` | 0..19 | 0 | Bar | **có** |
| 44 | `ORDER_TYPE` | `ENUM_TM2_ORDER` | 0..2 | 0 | Bar | **có** |
| 45 | `ENTRY` | `plan.entry` (limit hoặc close) | giá | `EMPTY` | Bar | **có** |
| 46 | `LIMIT` | `plan.limitPrice` | giá | `EMPTY` | Bar | audit |
| 47 | `SL` | `plan.sl` | giá | `EMPTY` | Bar | **có** |
| 48 | `TP1` | `plan.tp1` | giá | `EMPTY` | Bar | **có** |
| 49 | `TP2` | `plan.tp2` | giá | `EMPTY` | Bar | **có** |
| 50 | `TP3` | `plan.tp3` | giá | `EMPTY` | Bar | **có** |
| 51 | `RISK` | `plan.risk` | > 0 | `EMPTY` | Bar | **có** |
| 52 | `EVAL_RR` | `r2` (RR kiểm tra tại TP2) | ≥ 0 | `EMPTY` | Bar | audit |
| 53 | `POS_SIZE` | `riskUsd / dist` | ≥ 0 | `EMPTY` | Bar | audit |
| 54 | `NOTIONAL` | `posSize * entry` | ≥ 0 | `EMPTY` | Bar | audit |
| 55 | `EFF_LEV` | `notional / equity` | ≥ 0 | `EMPTY` | Bar | audit |
| 56 | `MARGIN_REQ` | `notional / maxLev` | ≥ 0 | `EMPTY` | Bar | audit |
| 57 | `LIQ_PRICE` | Giá thanh lý ước tính | giá | `EMPTY` | Bar | audit |
| 58 | `NET_RR` | `netProfit / netRisk` | giá trị | `EMPTY` | Bar | audit |

##### D. Signal, event flags (16)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 59 | `SIGNAL` | `tradeEligible && plan.valid` | 0/1 | 0 | Edge | **có** |
| 60 | `CANDIDATE` | Candidate rising edge | 0/1 | 0 | Edge | audit |
| 61 | `ELIGIBLE` | Eligible rising edge | 0/1 | 0 | Edge | audit |
| 62 | `EV_ENTRY` | Market entry mở | 0/1 | 0 | Edge | **có** |
| 63 | `EV_PENDING` | Limit pending tạo | 0/1 | 0 | Edge | **có** |
| 64 | `EV_FILLED` | Limit khớp | 0/1 | 0 | Edge | **có** |
| 65 | `EV_CANCEL` | Limit huỷ | 0/1 | 0 | Edge | **có** |
| 66 | `EV_TP` | TP chạm | 0..3 | 0 | Edge | **có** |
| 67 | `EV_SL` | SL chạm | 0/1 | 0 | Edge | **có** |
| 68 | `EV_BE` | Auto BE | 0/1 | 0 | Edge | **có** |
| 69 | `EV_TRAIL` | Trail cập nhật | 0/1 | 0 | Edge | audit |
| 70 | `EV_TIMEOUT` | Timeout | 0/1 | 0 | Edge | **có** |
| 71 | `EV_DECAY` | Time-decay | 0/1 | 0 | Edge | **có** |
| 72 | `EV_CLOSE` | Đóng vị thế | 0/1 | 0 | Edge | **có** |
| 73 | `CANCEL_REASON` | `ENUM_TM2_CLOSE` 9/10 | 0/9/10 | 0 | Bar | audit |
| 74 | `CLOSE_REASON` | `ENUM_TM2_CLOSE` | 0..8 | 0 | Bar | **có** |

##### E. Vị thế (14)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 75 | `POS_DIR` | Hướng vị thế | −1/0/1 | 0 | State | **có** |
| 76 | `POS_STAGE` | `ENUM_TM2_STAGE` | 0..4 | 0 | State | **có** |
| 77 | `POS_ORDER_TYPE` | `ENUM_TM2_ORDER` | 0..2 | 0 | State | audit |
| 78 | `POS_MODE` | `ENUM_TM2_MODE` | 0..3 | 0 | State | audit |
| 79 | `POS_ENTRY` | Giá entry | giá | `EMPTY` | State | **có** |
| 80 | `POS_LIMIT` | Giá limit | giá | `EMPTY` | State | audit |
| 81 | `POS_SL` | SL hiện tại | giá | `EMPTY` | State | **có** |
| 82 | `POS_TP1` | TP1 | giá | `EMPTY` | State | **có** |
| 83 | `POS_TP2` | TP2 | giá | `EMPTY` | State | **có** |
| 84 | `POS_TP3` | TP3 | giá | `EMPTY` | State | **có** |
| 85 | `POS_RISK` | Risk ban đầu | giá | `EMPTY` | State | audit |
| 86 | `POS_BARS` | Số nến giữ/pending | ≥ 0 | 0 | State | audit |
| 87 | `POS_BAR` | `bar_index` entry/fill | ≥ 0 | −1 | State | audit |
| 88 | `POS_MAXFAVR` | Max favorable R | giá trị | 0 | State | audit |

##### F. Counter (16)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 89 | `DAY_COUNT` | Lệnh trong ngày server | ≥ 0 | 0 | State | audit |
| 90 | `BARS_SINCE` | Cooldown | ≥ 0 | 0 | State | audit |
| 91 | `CONSEC_LOSSES` | Chuỗi thua | ≥ 0 | 0 | State | audit |
| 92 | `TRADES` | Trade đã đóng | ≥ 0 | 0 | State | audit |
| 93 | `TP1_HITS` | Số trade chạm TP (counter Pine) | ≥ 0 | 0 | State | audit |
| 94 | `NET_WINS` | Net win | ≥ 0 | 0 | State | audit |
| 95 | `BE_SAVES` | Thoát BE | ≥ 0 | 0 | State | audit |
| 96 | `FULL_LOSSES` | Thua full | ≥ 0 | 0 | State | audit |
| 97 | `TIMEOUTS` | Timeout | ≥ 0 | 0 | State | audit |
| 98 | `DECAYS` | Time-decay | ≥ 0 | 0 | State | audit |
| 99 | `REALIZED_R_SUM` | Tổng R | giá trị | 0 | State | audit |
| 100 | `CANDIDATES` | Funnel candidate | ≥ 0 | 0 | State | audit |
| 101 | `ELIGIBLE_N` | Funnel eligible | ≥ 0 | 0 | State | audit |
| 102 | `PENDING_N` | Funnel pending | ≥ 0 | 0 | State | audit |
| 103 | `FILLED_N` | Funnel filled | ≥ 0 | 0 | State | audit |
| 104 | `CLOSED_N` | Funnel closed | ≥ 0 | 0 | State | audit |

##### G. Trade đóng gần nhất (8)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 105 | `X_DIR` | Hướng trade cuối | −1/0/1 | 0 | State | audit |
| 106 | `X_ENTRY` | Entry | giá | `EMPTY` | State | audit |
| 107 | `X_SL` | SL lúc đóng | giá | `EMPTY` | State | audit |
| 108 | `X_EXIT` | Giá thoát hiệu dụng | giá | `EMPTY` | State | audit |
| 109 | `X_R` | R thực nhận | giá trị | `EMPTY` | State | audit |
| 110 | `X_REASON` | `ENUM_TM2_CLOSE` | 0..10 | 0 | State | audit |
| 111 | `X_BAR` | Bar entry | ≥ 0 | −1 | State | audit |
| 112 | `X_STAGE` | Stage cao nhất đạt được | 0..4 | 0 | State | audit |

##### H. Regime (8)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 113 | `REGIME_CODE` | `ENUM_TM2_REGIME` | −1..1 | 0 | Bar | **có** |
| 114 | `REGIME_DIR` | Trend dir | −1/0/1 | 0 | Bar | audit |
| 115 | `REGIME_ADX` | ADX | 0..100 | `EMPTY` | Bar | audit |
| 116 | `REGIME_BBW_PCT` | Percentile BBW | 0..100 | 50 | Bar | audit |
| 117 | `IS_SQUEEZE` | `bbwPct <= squeezePct` | 0/1 | 0 | Bar | audit |
| 118 | `BB_WIDTH` | `(up−lo)/mid*100` | ≥ 0 | `EMPTY` | Bar | audit |
| 119 | `BB_WIDTH_MA` | `SMA(bbWidth,20)` | ≥ 0 | `EMPTY` | Bar | audit |
| 120 | `BB_EXPAND` | `bbWidth > bbWidthMA` | 0/1 | 0 | Bar | audit |

##### I. Structure (26)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 121 | `TREND` | Trend state | −1/0/1 | 0 | State | audit |
| 122 | `BOS_UP` | BOS bull nến này | 0/1 | 0 | Bar | audit |
| 123 | `BOS_DN` | BOS bear | 0/1 | 0 | Bar | audit |
| 124 | `CHOCH_UP` | CHoCH bull | 0/1 | 0 | Bar | audit |
| 125 | `CHOCH_DN` | CHoCH bear | 0/1 | 0 | Bar | audit |
| 126 | `MSS_UP` | MSS bull | 0/1 | 0 | Bar | audit |
| 127 | `MSS_DN` | MSS bear | 0/1 | 0 | Bar | audit |
| 128 | `RETEST_UP` | Retest bull | 0/1 | 0 | Bar | audit |
| 129 | `RETEST_DN` | Retest bear | 0/1 | 0 | Bar | audit |
| 130 | `FAIL_UP` | Failed breakout bull | 0/1 | 0 | Bar | audit |
| 131 | `FAIL_DN` | Failed breakout bear | 0/1 | 0 | Bar | audit |
| 132 | `CONT_UP` | Continuation bull | 0/1 | 0 | Bar | audit |
| 133 | `CONT_DN` | Continuation bear | 0/1 | 0 | Bar | audit |
| 134 | `PULL_UP` | Pullback bull | 0/1 | 0 | Bar | audit |
| 135 | `PULL_DN` | Pullback bear | 0/1 | 0 | Bar | audit |
| 136 | `HH` | Higher high | 0/1 | 0 | Bar | audit |
| 137 | `LL` | Lower low | 0/1 | 0 | Bar | audit |
| 138 | `EQ_HI` | Equal high | 0/1 | 0 | Bar | audit |
| 139 | `EQ_LO` | Equal low | 0/1 | 0 | Bar | audit |
| 140 | `SWING_HI` | Swing high gần nhất | giá | `EMPTY` | State | audit |
| 141 | `SWING_LO` | Swing low gần nhất | giá | `EMPTY` | State | audit |
| 142 | `PREV_HIGH` | Swing high trước | giá | `EMPTY` | State | audit |
| 143 | `PREV_LOW` | Swing low trước | giá | `EMPTY` | State | audit |
| 144 | `BRK_LEVEL` | Level phá gần nhất | giá | `EMPTY` | State | audit |
| 145 | `BRK_DIR` | Hướng phá | −1/0/1 | 0 | State | audit |
| 146 | `BRK_BAR` | Bar phá | ≥ 0 | −1 | State | audit |

##### J. Event ring và sweep memory (10)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 147 | `EVT_KIND` | Event cuối ring | 0..4 | 0 | State | **có** |
| 148 | `EVT_DIR` | Hướng event cuối | −1/0/1 | 0 | State | **có** |
| 149 | `EVT_SRC_BAR` | `srcBar` | ≥ 0 | −1 | State | audit |
| 150 | `EVT_SRC_TIME` | `datetime` | — | 0 | State | audit |
| 151 | `EVT_LEVEL` | `level` | giá | `EMPTY` | State | **có** |
| 152 | `EVT_COUNT` | Kích thước ring | 0..50 | 0 | State | audit |
| 153 | `LAST_SWEEP_BULL_BAR` | Bar sweep bull gần nhất | ≥ 0 | −1 | State | audit |
| 154 | `LAST_SWEEP_BULL_PX` | Low sweep bull | giá | `EMPTY` | State | audit |
| 155 | `LAST_SWEEP_BEAR_BAR` | Bar sweep bear | ≥ 0 | −1 | State | audit |
| 156 | `LAST_SWEEP_BEAR_PX` | High sweep bear | giá | `EMPTY` | State | audit |

##### K. Candle / overextension (14)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 157 | `CP_BULL` | Điểm nến bull | 0..4 | 0 | Bar | audit |
| 158 | `CP_BEAR` | Điểm nến bear | 0..4 | 0 | Bar | audit |
| 159 | `CANDLE_SCORE` | `cpScore` | −1..1 | 0 | Bar | audit |
| 160 | `PIN_BULL` | Pin bull | 0/1 | 0 | Bar | audit |
| 161 | `PIN_BEAR` | Pin bear | 0/1 | 0 | Bar | audit |
| 162 | `ENG_BULL` | Engulf bull | 0/1 | 0 | Bar | audit |
| 163 | `ENG_BEAR` | Engulf bear | 0/1 | 0 | Bar | audit |
| 164 | `DISP_BULL` | Displacement bull | 0/1 | 0 | Bar | audit |
| 165 | `DISP_BEAR` | Displacement bear | 0/1 | 0 | Bar | audit |
| 166 | `REJ_BULL` | Rejection bull | 0/1 | 0 | Bar | audit |
| 167 | `REJ_BEAR` | Rejection bear | 0/1 | 0 | Bar | audit |
| 168 | `IS_OVEREXT` | `extEma > maxExt \|\| extCandle > maxCandle` | 0/1 | 0 | Bar | audit |
| 169 | `EXT_EMA_ATR` | `\|close−emaF\|/atr` | ≥ 0 | 0 | Bar | audit |
| 170 | `EXT_CANDLE_ATR` | `(high−low)/atr` | ≥ 0 | 1 | Bar | audit |

##### L. Indicator (11)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 171 | `ATR` | ATR Wilder | > 0 | `EMPTY` | Bar | **có** |
| 172 | `ATR_PCT` | `atr/close*100` | ≥ 0 | 0 | Bar | audit |
| 173 | `RSI` | RSI | 0..100 | `EMPTY` | Bar | audit |
| 174 | `MACD_HIST` | Histogram | giá trị | `EMPTY` | Bar | audit |
| 175 | `ADX` | ADX | 0..100 | `EMPTY` | Bar | audit |
| 176 | `DI_PLUS` | DI+ | 0..100 | `EMPTY` | Bar | audit |
| 177 | `DI_MINUS` | DI− | 0..100 | `EMPTY` | Bar | audit |
| 178 | `EMA_SLOPE20` | `(emaF−emaF[3])/(3·atr)` | giá trị | 0 | Bar | audit |
| 179 | `EMA_BULL` | `close>F>M && slope>0.03` | 0/1 | 0 | Bar | audit |
| 180 | `EMA_BEAR` | Đối xứng | 0/1 | 0 | Bar | audit |
| 181 | `ATR_SAFE` | `nz(atr, close*0.01)` | > 0 | `EMPTY` | Bar | audit |

##### M. Volume (8)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 182 | `VOL` | `tick_volume` | ≥ 0 | 0 | Bar | audit |
| 183 | `VOL_MA` | RMA(vol, volMaLen) | ≥ 0 | `EMPTY` | Bar | audit |
| 184 | `VOL_RATIO` | `vol/volMA` | ≥ 0 | 0 | Bar | audit |
| 185 | `VOL_BUCKET` | `ENUM_TM2_BUCKET` | 0..5 | 0 | Bar | audit |
| 186 | `IS_TIM` | Volume đột biến hợp lệ | 0/1 | 0 | Bar | audit |
| 187 | `REL_VOL` | `vol/SMA(vol,20)` | ≥ 0 | 0 | Bar | audit |
| 188 | `OBV` | OBV state | giá trị | 0 | State | audit |
| 189 | `OBV_SLOPE` | `obv − nz(obv[10])` | giá trị | 0 | Bar | audit |

##### N. Vị trí và session (10)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 190 | `VWAP` | VWAP reset ngày server | giá | `EMPTY` | Bar | audit |
| 191 | `VWAP_SCORE` | `clamp((close−vwap)/atrSafe)` | −1..1 | 0 | Bar | audit |
| 192 | `PDH` | High ngày server trước | giá | `EMPTY` | Bar | audit |
| 193 | `PDL` | Low ngày trước | giá | `EMPTY` | Bar | audit |
| 194 | `PWH` | High tuần trước | giá | `EMPTY` | Bar | audit |
| 195 | `PWL` | Low tuần trước | giá | `EMPTY` | Bar | audit |
| 196 | `DAY_RANGE` | `(close−pdl)/(pdh−pdl)*2−1` | giá trị | 0 | Bar | audit |
| 197 | `SESS_NAME` | `ENUM_TM2_SESSION` | 0..4 | 0 | Bar | audit |
| 198 | `SESS_HI` | Session high state | giá | `EMPTY` | State | audit |
| 199 | `SESS_LO` | Session low state | giá | `EMPTY` | State | audit |

##### O. Zone, FVG, OB (15)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 200 | `NEAR_SUP` | `f_nearSupport` | 0/1 | 0 | Bar | audit |
| 201 | `NEAR_RES` | `f_nearResistance` | 0/1 | 0 | Bar | audit |
| 202 | `NEAR_FVG_BULL` | Có FVG bull active | 0/1 | 0 | Bar | audit |
| 203 | `NEAR_FVG_BEAR` | Có FVG bear active | 0/1 | 0 | Bar | audit |
| 204 | `NEAR_OB_BULL` | Có OB bull active | 0/1 | 0 | Bar | audit |
| 205 | `NEAR_OB_BEAR` | Có OB bear active | 0/1 | 0 | Bar | audit |
| 206 | `SR_COUNT` | Số S/R zone | 0..20 | 0 | State | audit |
| 207 | `FVG_COUNT` | Số FVG | 0..50 | 0 | State | audit |
| 208 | `OB_COUNT` | Số OB | 0..30 | 0 | State | audit |
| 209 | `NEAREST_RES` | Kháng cự gần nhất > close | giá | `EMPTY` | Bar | audit |
| 210 | `NEAREST_SUP` | Hỗ trợ gần nhất < close | giá | `EMPTY` | Bar | audit |
| 211 | `FVG_BULL_PX` | Mid FVG bull cao nhất | giá | `EMPTY` | Bar | audit |
| 212 | `FVG_BEAR_PX` | Mid FVG bear thấp nhất | giá | `EMPTY` | Bar | audit |
| 213 | `OB_BULL_PX` | Top OB bull cao nhất | giá | `EMPTY` | Bar | audit |
| 214 | `OB_BEAR_PX` | Bot OB bear thấp nhất | giá | `EMPTY` | Bar | audit |

##### P. MTF / liên thị trường (9)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 215 | `MTF_CTX_DIR` | Bias context TF | −1/0/1 | 0 | Bar | audit |
| 216 | `MTF_SETUP_DIR` | Bias setup TF | −1/0/1 | 0 | Bar | audit |
| 217 | `MTF_CTX_EMA` | Context EMA đã đóng | giá | `EMPTY` | Bar | audit |
| 218 | `MTF_SETUP_EMA` | Setup EMA đã đóng | giá | `EMPTY` | Bar | audit |
| 219 | `MTF_BIAS` | `(ctx+setup)/2` | −1..1 | 0 | Bar | audit |
| 220 | `MTF_HIER_OK` | Chart ≤ Setup ≤ Context | 0/1 | 0 | Bar | audit |
| 221 | `BTC_DUMP` | BTC xả mạnh | 0/1 | 0 | Bar | audit |
| 222 | `BTC_PUMP` | BTC bơm mạnh | 0/1 | 0 | Bar | audit |
| 223 | `WEEKEND_BLOCK` | Filter thanh khoản cuối tuần | 0/1 | 0 | Bar | audit |

##### Q. Entry mode (8)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 224 | `MODE_DIR` | Hướng mode | −1/0/1 | 0 | Bar | audit |
| 225 | `ACTIVE_MODE` | `ENUM_TM2_MODE` | 0..3 | 0 | Bar | **có** |
| 226 | `MODE_READY` | Có mode active | 0/1 | 0 | Bar | audit |
| 227 | `MODE_GATE_OK` | `!filter \|\| ready&&match` | 0/1 | 0 | Bar | **có** |
| 228 | `MODE_REASON` | `ENUM_TM2_REASON` | 0..31 | 0 | Bar | **có** |
| 229 | `MODE_B_INVALID_LONG` | Mode B invalid long | 0/1 | 0 | Bar | audit |
| 230 | `MODE_B_INVALID_SHORT` | Mode B invalid short | 0/1 | 0 | Bar | audit |
| 231 | `MODE_C_BOX_OK` | Range box hợp lệ | 0/1 | 0 | Bar | audit |

##### R. Group score (10)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA |
|---:|---|---|---|---|---|---|
| 232 | `G_TREND` | Trend stack | −1..1 | `EMPTY` | Bar | audit |
| 233 | `G_STRUCT` | Structure | −1..1 | 0 | Bar | audit |
| 234 | `G_LIQ` | Liquidity | −1..1 | 0 | Bar | audit |
| 235 | `G_LOC` | Location (VWAP) | −1..1 | 0 | Bar | audit |
| 236 | `G_SR` | S/R + FVG | −1..1 | 0 | Bar | audit |
| 237 | `G_CANDLE` | Candle | −1..1 | 0 | Bar | audit |
| 238 | `G_VOLUME` | Volume | −1..1 | `EMPTY` | Bar | audit |
| 239 | `G_MOM` | Momentum | −1..1 | `EMPTY` | Bar | audit |
| 240 | `G_SESS` | Session | −0.5/0/0.5 | 0 | Bar | audit |
| 241 | `G_MTF` | MTF | −1..1 | 0 | Bar | audit |

Quy ước chung:

- Buffer edge (`SIGNAL`, `EV_*`) = `0.0` trên nến không có sự kiện; **không** dùng `EMPTY_VALUE`.
  `EV_TP` là 0..3; `CANCEL_REASON` là 0/9/10.
- `ENTRY/SL/TP1/TP2/TP3/RISK` là **plan của chính nến đó**, không phải state vị thế.
  Pine luôn gọi `f_buildTMPlan2(tm_dir)` kể cả khi `dir = 0` hoặc plan invalid:
  - `ORDER_TYPE` vẫn được chọn theo `InpEntryMode` + overextension.
  - Khi ATR hợp lệ và `dir = 0`: `SL = TP1 = TP2 = TP3 = ENTRY`, `RISK = dist > 0`,
    `LIQ_PRICE = EMPTY` (công thức chỉ định nghĩa cho dir ±1).
  - Khi `InpEntryMode` chọn LIMIT nhưng `dir = 0`: `LIMIT = EMPTY`, `ENTRY = close`.
  - Khi ATR `na`: `ENTRY` = close (market) hoặc `EMPTY` (limit), các mức còn lại `EMPTY`,
    `PLAN_VALID = 0`, `PLAN_REASON = BLOCK_NO_ATR`.
- `POS_*` là state vị thế đang mở/pending; `EMPTY`/0 khi `POS_STAGE == IDLE`, **trừ** nến đóng
  lệnh: trong nến đó stage/dir/levels vẫn giữ giá trị cũ (deferred reset chạy nến sau).
- `EVT_*` là phần tử **cuối** ring tại cuối nến; ring giữ tối đa 50 event (P8), không dedupe.
- `X_*` chỉ đổi khi có trade đóng; `X_STAGE` = stage cao nhất đạt được trong trade.
- `VOL_RATIO/REL_VOL` = 0 khi mẫu số `na`/≤ 0. `REGIME_BBW_PCT` = 50 khi range BBW = 0.
- `SESS_HI/SESS_LO` giữ mức cũ trong gap 15:00–17:00 và khi quay lại **cùng tên phiên** (Q5).
- Warm-up: `LONG_SCORE/SHORT_SCORE/SCORE100/SCORE_GAP/LONG_WEIGHTED/G_TREND/G_VOLUME/G_MOM`
  = `EMPTY_VALUE`; `DIRECTION_CODE = NO_DIRECTION`; `DIR = 0`; `QUALITY = NO TRADE`;
  `PLAN_VALID = 0` (P14).
- Tại nến đang chạy (`j == rates_total−1`) toàn bộ buffer = 0/`EMPTY_VALUE`; EA đọc `shift=1`.

### 7. Bar policy và state

Mỗi lần `rates_total` thay đổi, indicator reset state và replay từ `fromBar` tới
`rates_total-2`; trong cùng nến trả `rates_total` ngay. Mọi buffer của nến đã đóng là hàm thuần
của dữ liệu đã đóng (P1).

`fromBar = InpMaxBars > 0 ? max(0, lastClosed − InpMaxBars + 1) : 0`. Khi `fromBar > 0`, state
khởi tạo rỗng tại `fromBar` → không tái lập đúng lịch sử; chỉ dùng để debug.

#### 7.1 `TM2EngineState`

```cpp
struct TM2SrZone { double top, bot; int side, touches; bool broken; };
struct TM2Fvg    { double top, bot; int srcBar, side; bool dead; };
struct TM2Ob     { double top, bot; int srcBar, side; bool dead; };
struct TM2Event  { int kind, dir, srcBar; datetime srcTime; bool confirmed; double level; };

struct TM2EngineState
{
   // structure
   double swingHi, swingLo, prevHigh, prevLow, brkLevel;
   int    hiBar, loBar, trend, brkBar, brkDir;
   bool   hasSwingHi, hasSwingLo, hasPrevHigh, hasPrevLow, hasBrk;
   // edge flags nến hiện tại
   bool   bosUp, bosDown, chochUp, chochDown, mssUp, mssDown;
   bool   retestBull, retestBear, failBull, failBear;
   bool   contBull, contBear, pullBull, pullBear;
   bool   isHH, isLL, eqHi, eqLo;
   // session
   double sessHi, sessLo; int sessPrev; bool hasSessHi, hasSessLo;
   // zones
   TM2SrZone sr[TM2_MAX_SR]; int srCount;
   TM2Fvg    fvg[TM2_MAX_FVG]; int fvgCount;
   TM2Ob     ob[TM2_MAX_OB];   int obCount;
   // event ring + sweep memory
   TM2Event evt[TM2_MAX_EVT]; int evtCount;
   int   lastSweepBullBar, lastSweepBearBar;
   double lastSweepBullPx, lastSweepBearPx;
   // volume / vwap
   double obv; double obvHist[TM2_OBV_MAX]; int obvCount;
   double vwapPV, vwapVol; long dayStamp;
   double pdh, pdl, pwh, pwl; bool hasPd, hasPw;
   // day clock
   int dayCount, barsSince, consecLosses;
   // position
   int posStage, posDir, posBars, posBar, posMode;
   int posOrderType; double posEntry, posLimit, posSl, posTp1, posTp2, posTp3, posRisk;
   double posMaxFavR; bool needReset;
   // last closed
   double xEntry, xSl, xTp1, xTp2, xTp3, xExit, xR;
   int xDir, xBar, xReason, xStage;
   // stats
   int trades, tp1Hits, netWins, beSaves, fullLosses, timeouts, decays;
   int candidates, eligibleN, pendingN, filledN, closedN;
   double realizedRSum;
   bool prevCandidate, prevEligible;
   // out nến hiện tại
   bool evEntry, evPending, evFilled, evCancel, evSl, evBe, evTrail;
   bool evTimeout, evDecay, evClose;
   int  evTp, exitReason, cancelReason;
   double realizedR;
};
```

`TM2StateInit`: `trend = 0`, `brkDir = 0`, `barsSince = 999999`, `dayCount = 0`,
`consecLosses = 0`, `dayStamp = -1`, `sessPrev = TM2_SESS_NONE`, `posStage = IDLE`,
`posDir = 0`, `posBar = -1`, `posBars = 0`, `needReset = false`, `xBar = -1`, `xDir = 0`,
`xStage = 0`, counters = 0, `evtCount = 0`, `srCount/fvgCount/obCount/obvCount = 0`,
`has* = false`, `lastSweep*Bar = -1`, `posMode = 0`, `posOrderType = 0`.

#### 7.2 Series precompute (pass 1)

| Chuỗi | Công thức | Warm-up |
|---|---|---|
| `tr` | `max(h−l, \|h−c1\|, \|l−c1\|)`, bar 0 = `h−l` | bar 0 |
| `atr` | RMA(tr, `atrLen`) | `atrLen` |
| `bbMid/up/lo` | SMA20 ± 2·stdev20 (population) | 20 |
| `bbWidth` | `(up−lo)/mid*100`, mid ≤ 0 → 0 | 20 |
| `bbWidthMA` | SMA(bbWidth, **20**) | 39 |
| `bbwPct` | percentile trong `bbwLen`; range 0 → 50 | `bbwLen` |
| `diPlus/diMinus/adx` | Wilder DMI(`dmiLen`), ADX RMA(**14**) | `dmiLen+13` |
| `emaF/M/S` | EMA(close, len), seed SMA(len) | len |
| `emaSlope20` | `(emaF−emaF[3])/(3·atr)` | `emaFast+3` |
| `rsi` | Wilder RSI(`rsiLen`) | `rsiLen+1` |
| `macdHist` | EMA(f)−EMA(s), signal EMA(sig), hist = line−signal | `macdSlow+macdSig−1` |
| `volMA` | RMA(vol, `volMaLen`) | `volMaLen` |
| `volSma20` | SMA(vol, 20) | 20 |
| `vwap` | Σ(hlc3·vol)/Σvol, reset đầu ngày server | 1 bar |
| `pdh/pdl` | high/low ngày server trước | 1 ngày |
| `pwh/pwl` | high/low tuần server trước (thứ Hai) | 1 tuần |
| `pivH/pivL` | strict `msSwingLen`; xác nhận tại `c`, giá trị `high[c−len]` | `2·len+1` |
| `srPivH/srPivL` | strict 10/10 | 21 |
| `htfCtxEma/htfSetupEma` | EMA trên close HTF đã đóng (P4) | `ctxLen/setupLen` |
| `sessName` | `TM2SessionName(localMinute)` | 1 bar |
| `dayStamp/weekStamp` | ngày/tuần server (tuần bắt đầu thứ Hai) | 1 bar |
| `btcClose/btcEma/btcRsi/btcAtr` | symbol `InpBtcSymbol`, chart TF, `shift=1` | đủ len hoặc neutral |

`TM2Bar` mang: `time`, OHLCV, `prevOpen/prevClose/prevHigh/prevLow`, `high2/low2`,
`atr/atrPct/atrSafe`, `emaF/M/S`, `rsi/macdHist/diPlus/diMinus/adx`,
`bbMid/up/lo/width/widthMA/bbwPct/isSqueeze/bbExpand`,
`pivH/pivL` + valid, `srPivH/srPivL` + valid, `swingLo/swingHi` + valid,
`htfCtxEma/htfSetupEma` + valid, `ctxDir/setupDir`, `sessName`, `sessHi/sessLo` + valid,
`pdh/pdl/pwh/pwl` + valid, `dayStamp`, `btc*` + valid.

### 8. Engine pipeline (mỗi nến đóng, thứ tự bắt buộc)

```text
TM2EngineStep(cfg, st, bar, barIndex, out):
  0. Reset edge flags nến hiện tại: bos*/choch*/mss*/retest*/fail*/cont*/pull*/hh/ll/eq*/ev*.
  1. L2  bbWidth/bbwPct/isSqueeze/bbExpand, DMI, emaSlope20, emaBull/emaBear,
         classifyRegime; volScore.
  2. L3  candle metrics, disp/pin/engulf/rejection, cpScore.
  3. Structure: pivot high → prevHigh, swingHi, hiBar; pivot low → prevLow, swingLo, loBar;
         trend update; BOS/CHoCH/MSS; push event BOS → CHoCH → MSS.
         Retest/fail/cont/pull/HH/LL/eq.
  4. Session: sessName, reset/extend sessHi/Lo (TRƯỚC sweep).
  5. Zones: S/R pivot high (side −1) rồi pivot low (side +1); FVG push/dead; OB push/dead;
         near FVG / near OB px.
  6. L4  EMA stack/trendScore; RSI/MACD/momScore; vol/volMA/ratio/bucket/isTim/relVol;
         OBV/slope/volumeScore; VWAP/vwapScore; extEma/extCandle/overext.
  7. L5  PD/PW (bar), sweepBull/Bear, push SWEEP, sweep memory; MTF dirs/bias;
         BTC dump/pump; weekend.
  8. L6  nearestRes/Sup, obstacle blocked, evaluateGates(tm_dir).
  9. L7  groups, effective weights, ablation, side scores, direction, quality, scoreBlock.
 10. L7b modes A/B/C → activeMode, modeDir, modeReady, modeGateOk, modeReason.
 11. L8  plan = buildPlan(dir); new day → dayCount=0, consecLosses=0; barsSince += 1;
         okCool/okDay/okCircuit/okPosition; tradeEligible; riskEligible; signal;
         block mask; candidate/eligible counters.
 12. L10 deferred reset → manage PENDING → manage OPEN → open new position.
 13. out: gán toàn bộ trường ra nến (xem §6.2).
```

Thứ tự khớp Pine: session HL cập nhật **trước** sweep; `barsSince` tăng **trước** gate;
`dayCount` reset **trước** gate nhưng **sau** plan; state machine chạy **sau** plan/gate.
`okBar` trong port luôn `true` vì engine chỉ chạy trên nến đóng (P3).

### 9. Chi tiết thuật toán

#### 9.1 Regime

```text
if adx >= adxTrending && (emaUp || emaDn) && !squeeze:
    code = 1; dir = emaUp ? 1 : -1
else if adx < adxChop || (squeeze && |slope20| < 0.05):
    code = -1; dir = 0
else:
    code = 0; dir = 0
```

`emaUp = close > emaF && emaF > emaM && slope20 > 0.03`; `emaDn` đối xứng.
`volScore = bbExpand ? 1 : isSqueeze ? −1 : 0` (expand ưu tiên).

#### 9.2 Structure, event ring (P6, P8)

- Pivot high `ta.pivothigh(high, len, len)` xác nhận tại `c`; giá trị `high[c−len]`;
  `prevHigh := swingHi`, `swingHi := high[c−len]`, `hiBar := c−len`.
- Pivot low đối xứng.
- Trend đổi khi cả 4 swing có giá trị: HH+HL → 1; LH+LL → −1; mixed → giữ nguyên.
- BOS up: `crossover(close, swingHi) && trend == 1`; BOS down: `crossunder(close, swingLo) && trend == −1`.
- CHoCH up: `crossover && trend == −1`; CHoCH down: `crossunder && trend == 1`.
- MSS = CHoCH cùng phía **và** displacement cùng phía (không phải BOS).
- Retest: `1 <= bar − brkBar <= retestBars`, tolerance `retestTol·atr`, close đúng phía level.
- Fail: `bar − brkBar <= failBars`, close vượt quá level ± `0.3·atr`.
- HH/LL: `high[c−len] > prevHigh` / `low[c−len] < prevLow`.
- EQ: `|high[c−len] − prevHigh| <= 0.05·atr` (và tương ứng low).
- Event ring: chỉ **BOS, CHoCH, MSS, SWEEP**; tối đa 50, `shift` khi vượt.
  `srcBar = bar_index`, `srcTime = time` của nến push, `level = swingHi/swingLo` (BOS/CHoCH/MSS).
- Thứ tự push trong nến: BOS → CHoCH → MSS → SWEEP.

#### 9.3 Session, PD/PW (P7)

- Phiên theo giờ thị trường: Asia 17:00–02:00, London 02:00–10:00, NY 07:00–15:00.
- Tên: London/NY > New York > London > Asia > `-`.
- Nếu tên đổi **và** tên mới khác `-`: `sessHi = high`, `sessLo = low`.
  Nếu tên không đổi hoặc quay lại cùng tên: mở rộng `max/min` với high/low hiện tại.
  Tên `-`: không reset, không cập nhật, `sessPrev` giữ nguyên.
- Vì session HL cập nhật **trước** sweep và đã gồm high/low hiện tại, nhánh sweep session
  không thể đúng trong phiên; chỉ đúng khi tên `-` với mức cũ (Q5).
- PDH/PDL/PWH/PWL: tổng hợp từ nến chart theo ngày/tuần server; PWH/PWL luôn tồn tại.
- Sweep bull: `(pdOn && low<PDL && close>PDL) || (pwOn && low<PWL && close>PWL) ||
  (sessOn && low<sessLo && close>sessLo) || (eqLo && low[len]<prevLow && close>prevLow)`.
  Sweep bear đối xứng.
- Sweep event level: bull `max(PDL, nz(sessLo, PDL))`; bear `min(PDH, nz(sessHi, PDH))`.
  `PDL na` → level `EMPTY` (Q7).
- Sweep memory: lưu `bar` và `low/high` của lần sweep gần nhất để Mode B dùng.

#### 9.4 S/R, FVG, OB, obstacle (P5)

- S/R: pivot 10/10; `half = atr·srWidth·0.5`; zone `{top=px+half, bot=px−half, side, touches=1}`.
  Merge nếu `|mid − px| < atr·srWidth` → `touches++`, **không** đổi top/bot/side.
  `broken` không bao giờ được set trong replay; xoá broken; `while size > srMax shift`.
- Near support: tồn tại zone `side==1 && !broken` với `low >= bot−0.3·atr && low <= top+0.3·atr`;
  resistance đối xứng với `high`.
- FVG bull: `low > high[2] && (low−high[2]) >= fvgMinAtr·atr` → `{top=low, bot=high[2]}`;
  bear: `high < low[2] && (low[2]−high) >= ...` → `{top=low[2], bot=high}`.
  Giới hạn `fvgMax`; chết khi `bar−srcBar > fvgLife` hoặc giá xuyên qua (một chiều).
- OB bull: `dispBull && close[1] < open[1]` → `{top=open[1], bot=close[1], srcBar=bar−1, side=1}`;
  bear đối xứng. Giới hạn `obMax`; chết khi quá `obLife` hoặc giá xuyên.
- `fvgBullPx` = mid của FVG bull active có **top cao nhất**; `fvgBearPx` = mid của FVG bear
  active có **bot thấp nhất**. `obBullPx` = top cao nhất; `obBearPx` = bot thấp nhất.
- Obstacle: quét S/R active (`side −1 && bot > close` → res; `side 1 && top < close` → sup),
  rồi OB active tương tự, rồi PDH/PDL/PWH/PWL nếu khoảng cách `>= 0.3·atr`.
  **FVG không** tham gia obstacle (Pine cố ý).
- `estDistTp1 = atrSafe·slAtrMul·rr1`; long bị chặn nếu `distToRes < estDistTp1·obstacleBuffer`;
  short đối xứng với `distToSup`.

#### 9.5 Candle và overextension

- `body=|c−o|`, `range=max(h−l, mintick)`, `hiWick=h−max(c,o)`, `loWick=min(c,o)−l`.
- Displacement: `body >= 1.5·atr && hiWick < 0.3·body` (bull); bear đối xứng.
- Pin: bull `c>o && loWick >= 2·body`; bear đối xứng.
- Engulf: bull `c>o && close[1]<open[1] && c>=open[1] && o<=close[1] && body>=prevBody`.
- Rejection: bull `hiWick>=0.55·range && loWick<=0.15·range && c>o`.
- `cpBull/PtBear` cộng 1.0 pin, 1.0 engulf, 1.2 displacement, 0.8 rejection;
  `cpScore = ±min(1, cp/3)` (dấu theo bên lớn hơn; bằng nhau → 0).
- `extEma = |close−emaF|/atr` (atr ≤ 0 → 0); `extCandle = (h−l)/atr` (atr ≤ 0 → 1).
- `isOverextended = extEma > maxExtAtr || extCandle > maxCandleAtr`.

#### 9.6 Indicator, volume, VWAP (P11)

- `rsiScore = rsi<os ? 1 : rsi>ob ? −1 : (rsi−50)/20`.
- `macdScore = hist>0 ? (hist>hist[1] ? 1 : 0.5) : (hist<hist[1] ? −1 : −0.5)`.
- `momScore = clamp(0.4·rsiScore + 0.6·macdScore, −1, 1)`.
- `trendScore = stackBull ? 1 : stackBear ? −1 : close>emaF ? 0.4 : close<emaF ? −0.4 : 0`.
- `volMA = RMA(vol, volMaLen)`, `volRatio = volMA>0 ? vol/volMA : 0`.
- Bucket `f_vsaName` (không guard `ma>0`): `vol >= ma·rP` → TIM; ...; `na` → VERYLOW.
- `isTim = volMA>0 && vol >= volMA·spikeR`.
- `relVol = volSma20>0 ? vol/volSma20 : 0`.
- `obv += close>close[1] ? vol : close<close[1] ? −vol : 0` (bar 0 = 0);
  `obvSlope = obv − nz(obv[10])`.
- `volumeScore = clamp((isTim ? 1 : relVol>=rvMin ? 0.7 : 0)·(close>=open?1:−1)·0.6
  + obvScore·0.4, −1, 1)`.
- VWAP: `hlc3`; reset khi `f_isNewDay()` (bar đầu ngày = chính nó). `vwapScore =
  vwapOk ? clamp((close−vwap)/nz(atr, close·0.01), −1, 1) : 0`.
- `dayRange = pdh>pdl ? (close−pdl)/(pdh−pdl)·2−1 : 0`.

#### 9.7 MTF, BTC, weekend (P4)

- Hierarchy: `secChart <= secSetup <= secCtx` (giây).
- Với mỗi TF: chọn bar HTF đã đóng gần nhất có `close_time <= chartOpen`; bias
  `close > ema ? 1 : close < ema ? −1 : 0` → **bằng nhau = 0** (Q1).
- Hierarchy sai → cả hai bias 0, bias tổng 0.
- `btcNeed = btcLeaderOn && !btcSelf && assetMode ∈ {AUTO, ETH, LIQ_ALT, HIGH_RISK}`.
  `btcSelf` = `_Symbol` chứa `"BTC"`.
- `btcDump = btcNeed && btcClose < btcEma − impulse·btcAtr || btcRsi < 32` (khi đủ dữ liệu);
  `btcPump` đối xứng với `> + impulse·atr` hoặc `rsi > 68`.
- BTC thiếu dữ liệu/symbol rỗng → `btcDump = btcPump = false` (neutral).
- `isCrypto = InpAssetIsCrypto || assetMode ∈ {BTC,ETH,LIQ_ALT,HIGH_RISK} || _Symbol chứa "USDT"`.
- `weekendBlocked = weekendFilter && isCrypto && (Sat||Sun) && (volRatio<0.8 || atrPct<0.6)`.

#### 9.8 Scoring 2.1 và ablation

Group (signed, −1..1):

```text
gTrend  = trendScore
gStruct = (bosUp||chochUp||mssUp) ? 1 : (bosDown||chochDown||mssDown) ? −1 : trend·0.5
gLiq    = sweepBull ? 1 : sweepBear ? −1 : retestBull ? 0.7 : retestBear ? −0.7 : 0
gLoc    = vwapScore
gSr     = nearSup ? 1 : nearRes ? −1 : fvgBullPx!=na ? 0.8 : fvgBearPx!=na ? −0.8 : 0
gCandle = cpScore
gVolume = volumeScore
gMom    = momScore
gSess   = (close>=open ? 1 : −1) · (cryptoSessNeutral ? 0 : 0.5)
gMtf    = (ctxDir + setupDir)/2   (hierarchy sai → 0)
```

`gSr` **không** dùng OB (Q3). Regime chỉ đổi weight, không đổi dấu:

| Regime | trend | struct | liq | loc | sr | mom |
|---|---:|---:|---:|---:|---:|---:|
| TRENDING | ×1.30 | ×1.25 | ×1 | ×1 | ×0.60 | ×1.20 |
| RANGING | ×0.60 | ×1 | ×1.30 | ×1.20 | ×1.30 | ×1 |
| CHOPPY | ×0.50 | ×0.50 | ×1 | ×1 | ×1 | ×0.50 |

Ablation (sau regime weight):

| Code | Trend | Struct | Liq | Loc | Sr | Candle | Vol | Mom | Sess | Mtf |
|---|---|---|---|---|---|---|---|---|---|---|
| A | 0 | ✓ | ✓ | ✓ | ✓ | ✓ | 0 | 0 | 0 | 0 |
| B | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 0 | ✓ | 0 | 0 |
| C | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 0 | 0 |
| D | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| E | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

`wDirTotal = Σ weight hiệu dụng`; `LONG = round(100·clamp(Σw·max(g,0)/wDirTotal,0,1))`;
SHORT với `max(−g,0)`. Nếu group enabled = `EMPTY` → side score `EMPTY` (P14).

- `longMinOk = LONG > scrNoTrade`; `shortMinOk = SHORT > scrNoTrade` (strict).
- `directionCode = !(longMinOk||shortMinOk) ? NO_DIRECTION :
  (longMinOk && shortMinOk && gap < margin) ? AMBIGUOUS : OK`.
- `candidateDir = longMinOk && LONG >= SHORT ? 1 : shortMinOk && SHORT > LONG ? −1 : 0`.
- `DIR = code==OK ? candidateDir : 0`; `SCORE100 = DIR==1 ? LONG : DIR==−1 ? SHORT : max(LONG,SHORT)`.
- `QUALITY`: code != OK → NO TRADE/level 0; ngược lại level theo
  `score<=noTrade→0, <=weak→1, <=setup→2, <=strong→3, else 4`.
- `scoreBlock = code != OK ? code : !okQuality ? (DIR==1 ? BLOCK_SCORE_LONG : DIR==−1 ?
  BLOCK_SCORE_SHORT : NO_DIRECTION) : OK`.

#### 9.9 Entry mode A/B/C

```text
modeADir = regime.code==1 ? regime.dir : 0
modeAMtfOk = dir==1 ? ctxDir>=0 && setupDir>=0 : dir==−1 ? ctxDir<=0 && setupDir<=0 : false
pullLong  = low <= emaF+pbTol || (fvgBullPx && low <= fvgBullPx+pbTol) ||
            (obBullPx && low <= obBullPx+pbTol)
confirmLong = close>open && close >= emaF−pbTol
readyLong = modeAOn && modeADir==1 && mtfOk && pullLong && confirmLong
```

Mode B: `sweepAge = lastSweepBullBar>=0 ? bar−lastSweepBullBar : 999999`;
`fresh = age <= modeSweepBars && px!=na`; `confirm = pin||engulf||rejection`;
`readyLong = modeBOn && fresh && confirm && close > sweepPx`;
`invalidLong = modeBOn && fresh && close < sweepPx − 0.1·atrSafe`.
Mode C: `boxOk = regime==0 && res && sup && (res−sup) > atrSafe`;
`nearSup = boxOk && close <= sup+rgTol && close >= sup−atrSafe`;
`readyLong = modeCOn && nearSup && confirmBull && close>open`.

Chọn mode ưu tiên A > B > C; `modeDir`/`activeMode` theo nhánh đầu tiên đúng.
`modeGateOk = !modeFilterOn || (modeReady && modeDir == DIR)`.
`modeReason`: ready → MODE_A/B/C; B invalid → MODE_INVALIDATED; còn điều kiện chờ →
WAIT_CONFIRMATION; `modeADir != 0` → WAIT_PULLBACK; else NO_SETUP; filter off → OK.

#### 9.10 Eligibility gate

| Gate | Điều kiện block |
|---|---|
| Regime | code == −1; hoặc code == 0 và đủ 2 barrier và (dir 1 && close > mid \|\| dir −1 && close < mid) |
| MTF | `setupOk = !htfFilter \|\| !hierarchy \|\| setupDir==0 \|\| setupDir==dir`; `veto = htfVetoOn && hierarchy && ctxDir!=0 && ctxDir!=dir` |
| BTC | long && btcDump; short && btcPump |
| Obstacle | long `distToRes < estTp1·buffer`; short `distToSup < estTp1·buffer` |
| Overext | `gateOverext && isOverextended && entryMode==MARKET` |
| Circuit | `weekendBlocked` (reason LIQUIDITY) |
| Other | `okCool`, `okDay`, `okCircuit`, `okPosition` |

`rsn` giữ blocker đầu tiên theo thứ tự: regime → MTF → BTC → obstacle → overext → liquidity.
`mask` giữ tất cả theo đúng thứ tự đó (dạng bitmask trong MQL5, không phải chuỗi).
`GATE_TOP_REASON` = `rsn`; `NO_TRADE_REASON` theo chuỗi: scoreBlock → regime → MTF → BTC →
obstacle → overext → mode → cool → day → circuit → position → plan → OK. **Liquidity không
xuất hiện** trong chuỗi này (Q9).

`tradeEligible = okDir && okQuality && gateAll && modeGateOk && okCool && okDay && okCircuit &&
okPosition`; `riskEligible = plan.valid`; `SIGNAL = tradeEligible && riskEligible`.
`CANDIDATE`/`ELIGIBLE` là **rising edge** của `scoreBlock==OK && okDir` và
`tradeEligible && riskEligible`.

#### 9.11 Plan, sizing, net RR

```text
ordType: Market → MARKET; Strict → LIMIT; Auto → overext ? LIMIT : MARKET
limPx: dir 1  = source==FVG ? fvgBullPx : source==OB ? obBullPx : emaF; min(px, close−mintick)
       dir −1 = source==FVG ? fvgBearPx : source==OB ? obBearPx : emaF; max(px, close+mintick)
entry = ordType==LIMIT ? limPx : close
pad   = atr·slPadAtr
swing = dir==1 ? nz(swingLo, low) : nz(swingHi, high)
sDist = dir==1 ? entry−swing+pad : swing−entry+pad
aDist = atr·slAtrMul
dist  = clamp(nz((aDist+sDist)/2, aDist), atr·slMinAtr, atr·slMaxAtr)
sl    = entry − dir·dist;  risk = dist
r1=rr1; r2=max(rr2,r1+0.5); r3=max(rr3,r2+1)
tp1=entry+dir·r1·risk; tp2=entry+dir·r2·risk; tp3=entry+dir·r3·risk; evalRR=r2
```

- `rrOk = rrMin<=0 || r2>=rrMin`; `slOk = dist>0 && đúng phía`; `tpOk = thứ tự strict`.
- `riskUsd = equity·riskPct/100`; `pos = dist>0 ? riskUsd/dist : 0`; `notional = pos·entry`;
  `effLev = equity>0 ? notional/equity : 0`; `marginReq = maxLev>0 ? notional/maxLev : notional`.
- `levForLiq = max(effLev,1)`; `liqLong = entry·max(0, 1 − 1/levForLiq + mmr)`;
  `liqShort = entry·(1 + 1/levForLiq − mmr)`; dir 0 → `EMPTY`.
- `liqOk = !gateRisk || (dir==1 ? sl>liq : sl<liq)`; `levOk = !gateRisk || maxLev<=0 ||
  effLev <= maxLev·1.05`.
- `fee = notional·feePct/100`; `netProfit = r2·riskUsd − fee`; `netRisk = riskUsd + fee`;
  `netRR = netRisk>0 ? netProfit/netRisk : r2`; `netRrOk = rrMin<=0 || netRR>=rrMin`.
- Reason ưu tiên: `NO_ATR → NO_DIRECTION → BAD_SL → BAD_TP → RR → MAX_LEV → LIQUIDATION →
  NET_RR → VALID`; `valid =` tất cả điều kiện trên.
- Nếu `slMinAtr > slMaxAtr` sau normalize (không swap), `clamp` trả `lo` → `dist =
  atr·slMinAtr` (Q11). `BAD_SL`/`BAD_TP` gần như không đạt được với input hợp lệ (Q11).

**Ví dụ số** (ATR 10, entry 2000, swingLow 1985, pad 0.2, atrMul 1.5, rr 1/2/3, equity
10.000, risk 1%, maxLev 20, mmr 0.005, fee 0.08%):

`aDist 15`, `sDist 17`, `base 16`, `dist 16`, `SL 1984`, `TP 2016/2032/2048`,
`pos 6.25`, `notional 12.500`, `effLev 1.25`, `margin 625`, `liq 410`,
`fee 10`, `netRR 190/110 = 1.727273`.

#### 9.12 State machine

Thứ tự trong nến: **deferred reset → PENDING → OPEN → new entry**; sau đó `posBars` của
entry mới giữ 0.

- **Deferred reset**: nếu `needReset` → stage IDLE, dir 0, xoá levels/mode, `posBars 0`,
  `posBar na`, `posMaxFavR 0`, `exitReason NONE`.
- **PENDING**: `posBars++`; fill nếu `low <= posLimit` (long) / `high >= posLimit` (short)
  → stage OPEN, `posEntry = posLimit`, `posBar = bar`, `posBars 0`, `EV_FILLED`, `FILLED_N++`.
  Ngược lại nếu `cancelOnTp1 && high >= tp1` (long) → `CANCEL_MISSED`;
  nếu `posBars >= cancelBars` → `CANCEL_TIMEOUT`; cả hai đặt `EV_CANCEL`, `needReset`.
- **OPEN/TP1_BE/TP2_TRAIL**: `posBars++`; `curFavR = dir==1 ? (high−entry)/risk :
  (entry−low)/risk`; `posMaxFavR = max(...)`.
  `t1` chỉ xét khi stage < TP1_BE; `t2` chỉ khi stage < TP2_TRAIL; `t3` luôn.
  `fillBar = posBar == bar`; `hitSl` luôn xét; `hit1/2/3 = !fillBar && ...`.
- Nếu `hitSl && hitAnyTp` → đóng theo nhánh SL; nếu chỉ `hitSl` → nhánh SL.
  Stage OPEN → SL/−1R; TP1_BE → BREAKEVEN `0.4·rr1 − feePct·2/100`;
  TP2_TRAIL → TRAIL `0.4·rr1 + 0.4·rr2 − feePct·2/100`.
- `hit3` → đóng TP3, `R = 0.4·rr1 + 0.4·rr2 + 0.2·rr3` (không trừ fee — Q10).
- `hit2` → stage TP2_TRAIL, `posSl = posTp1`, `EV_TRAIL`; sau đó nếu `trailOn`:
  `trailLvl = dir==1 ? high[1] − trailDist·atr : low[1] + trailDist·atr`;
  `posSl = max/min(posSl, trailLvl)` (dùng high/low **nến trước** — Q8).
- `hit1` → stage TP1_BE; nếu `autoBeOn`: `posSl = entry + dir·atr·beOffset`, `EV_BE`.
- Time-decay: `!closed && timeDecayOn && stage==OPEN && posBars >= stagnantBars &&
  posMaxFavR < 0.3 && adx < adxTrending` → đóng, `R = (close−entry)·dir/risk`, `EV_DECAY`.
- Timeout: `!closed && posBars >= maxHoldBars` → đóng, cùng công thức R, `EV_TIMEOUT`.
- Khi đóng: `TRADES++`, `CLOSED_N++`, `REALIZED_R_SUM += R`, `needReset = true`;
  `posStage`/`posDir` vẫn giữ đến hết nến (Q12).
- TP1 counter: `hitAnyTp && stage==OPEN && !hitSl` → `TP1_HITS++` (kể cả TP2/TP3 trực tiếp — Q6).
- Entry mới: chỉ khi `SIGNAL && stage==IDLE`; copy plan vào state; `dayCount++`,
  `barsSince = 0`, `posBars = 0`, `posBar = bar`, `posMaxFavR = 0`, `exitReason NONE`.
  MARKET → stage OPEN, `EV_ENTRY`, `FILLED_N++`; LIMIT → stage PENDING, `EV_PENDING`,
  `PENDING_N++`.
- `posMode` lưu `activeMode`; `X_*` copy tại thời điểm đóng (trước reset nến sau).

### 10. EA và CSV

- `iCustom(_Symbol, _Period, "PinePort\\TMIndicator2.mq5", <118 inputs>)`.
- Chờ `BarsCalculated(handle) >= Bars(_Symbol,_Period)`; đọc `shift = 1` cho mọi buffer.
- Gate bắt buộc:
  - `SIGNAL=1` + `DIR≠0` + `PLAN_VALID=1` trước khi dùng tín hiệu.
  - `ENTRY/SL/TP1/TP2/TP3/RISK` chỉ dùng khi `PLAN_VALID=1`; `ORDER_TYPE` quyết định
    market/limit.
  - `POS_*` chỉ dùng khi `POS_STAGE≠0`; `POS_SL` có thể đã đổi do BE/trail.
  - `EVT_KIND`/`EVT_LEVEL` chỉ dùng khi `EVT_COUNT>0`.
- Dedupe theo `(symbol, timeframe, bar_open_time, signal_id, evt_src_bar)`.
- Không suy diễn lại TP/SL từ giá; không `OrderSend`, `CTrade`, `AccountInfo*`, `WebRequest`,
  `Socket*`, `FileWrite*`.

CSV (khi EA hỗ trợ — hiện `NOT_IMPLEMENTED`):

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,signal_id,side,order_type,
entry,limit,sl,tp1,tp2,tp3,risk,long_score,short_score,score100,quality,direction_code,
plan_valid,plan_reason,top_reason,mode,regime,pos_dir,pos_stage,
evt_kind,evt_dir,evt_src_bar,evt_level,input_hash
```

- `signal_id`: `TM2_LONG`, `TM2_SHORT`, `TM2_LIMIT`, `TM2_FILL`, `TM2_TP1`, `TM2_TP2`,
  `TM2_TP3`, `TM2_SL`, `TM2_BE`, `TM2_TRAIL`, `TM2_TIMEOUT`, `TM2_DECAY`, `TM2_CLOSE`,
  `TM2_CANCEL`.
- `side`: `BUY` cho `TM2_LONG`, `SELL` cho `TM2_SHORT`, `NONE` còn lại.
- `confirmed_at = bar_open_time + PeriodSeconds(_Period)`;
  `detected_at` = tick đầu tiên EA đọc `shift=1`.
- `input_hash` = FNV-1a 32-bit trên `TM2ConfigCanonical` + `TM2_CONTRACT_VERSION`.

### 11. Hàm contract (header)

```cpp
// math / time / config
double TM2Clamp(double v, double lo, double hi);
bool   TM2IsEmpty(double v);
int    TM2LocalMinute(datetime serverTime, int srvOffsetMin, int mktOffsetMin);
bool   TM2InWindow(int minute, int startMin, int endMin);
int    TM2SessionName(int minute);
double TM2SessionComponent(bool closeUp, bool cryptoSessNeutral);
bool   TM2IsNewServerDay(datetime prev, datetime cur);
bool   TM2IsNewServerWeek(datetime prev, datetime cur);
bool   TM2IsClosedBar(int bar, int ratesTotal);
bool   TM2IsCrypto(const TM2Config &cfg, const string symbol);
bool   TM2NeedBtcLeader(const TM2Config &cfg, const string symbol);
uint   TM2Fnv1a(const string text);
string TM2ConfigCanonical(const TM2Config &cfg);
uint   TM2ConfigHash(const TM2Config &cfg);
void   TM2NormalizeConfig(TM2Config &cfg);

// series
double TM2TrueRange(bool hasPrev, double h, double l, double prevClose);
void   TM2BuildSma(const double &src[], int total, int len, double &out[]);
void   TM2BuildEma(const double &src[], int total, int len, double &out[]);
void   TM2BuildRma(const double &src[], int total, int len, double &out[]);
void   TM2BuildAtr(const double &h[], const double &l[], const double &c[],
                   int total, int len, double &out[]);
void   TM2BuildRsi(const double &c[], int total, int len, double &out[]);
void   TM2BuildMacdHist(const double &c[], int total, int fast, int slow, int sig,
                        double &out[]);
void   TM2BuildDmi(const double &h[], const double &l[], const double &c[], int total,
                   int len, int smooth, double &diP[], double &diM[], double &adx[]);
void   TM2BuildBb(const double &c[], int total, int len, double mult,
                  double &mid[], double &up[], double &lo[]);
void   TM2BuildBbWidthPct(const double &width[], int total, int len, double &out[]);
void   TM2BuildVwap(const double &c[], const double &h[], const double &l[],
                    const long &vol[], const datetime &t[], int total,
                    int srvOffsetMin, double &out[]);
double TM2RollingMin(const double &src[], int total, int end, int len);
double TM2RollingMax(const double &src[], int total, int end, int len);
int    TM2MapHtfIndex(const datetime &htfCloseTime[], int count, datetime chartOpen);
double TM2HtfBias(double close, double ema, bool hasData);
bool   TM2MtfHierarchyOk(int chartSec, int setupSec, int ctxSec);
bool   TM2WeekendBlocked(const TM2Config &cfg, bool isCrypto, bool isWeekend,
                         double volRatio, double atrPct);

// pivots / zones
bool   TM2PivotHighAt(const double &h[], int total, int bar, int left, int right, double &out);
bool   TM2PivotLowAt(const double &l[], int total, int bar, int left, int right, double &out);
void   TM2ZoneAdd(TM2EngineState &st, double px, int side, double atr,
                  double width, int maxZones);
bool   TM2NearSupport(const TM2EngineState &st, double low, double atr);
bool   TM2NearResistance(const TM2EngineState &st, double high, double atr);
void   TM2PushEvent(TM2EngineState &st, int kind, int dir, int srcBar,
                    datetime srcTime, double level);

// candle / volume / indicators
double TM2CandleScore(bool pinBull, bool engBull, bool dispBull, bool rejBull,
                      bool pinBear, bool engBear, bool dispBear, bool rejBear);
int    TM2VolBucket(double vol, double volMA, double rP, double rVH,
                    double rH, double rN, double rL);
double TM2VolumeScore(bool isTim, double relVol, double rvMin,
                      double close, double open, double obvSlope, bool agg);
double TM2RsiScore(double rsi, double os, double ob);
double TM2MacdScore(double hist, bool hasPrev, double prevHist);
double TM2MomScore(double rsiScore, double macdScore);
double TM2TrendScore(bool stackBull, bool stackBear, double close, double emaF);
double TM2VwapScore(bool vwapOk, double close, double vwap, double atr);
double TM2DayRange(double close, bool hasPd, double pdh, double pdl);
double TM2ExtEma(double close, double emaF, double atr);
double TM2ExtCandle(double high, double low, double atr);
bool   TM2IsOverextended(double extEma, double extCandle,
                         double maxExtAtr, double maxCandleAtr);

// regime / scoring
void   TM2ClassifyRegime(double adx, bool squeeze, double slope20,
                         bool emaUp, bool emaDn, double bbwPct,
                         const TM2Config &cfg, int &code, int &dir);
void   TM2EffectiveWeights(const TM2Config &cfg, int regimeCode,
                           double &w[TM2_GROUP_COUNT]);
void   TM2AblationAdjust(double &w[TM2_GROUP_COUNT], int ablationCode);
double TM2LongPart(double v);
double TM2ShortPart(double v);
int    TM2SideScore(double weighted, double totalWeight);
void   TM2SideScores(const double &g[], const double &w[], int count,
                     int &longScore, int &shortScore, double &total);
int    TM2ScoreLevel(int score, int noTrade, int weak, int setup, int strong);
int    TM2MinLevel(int minQuality);
int    TM2DirectionCode(int longScore, int shortScore, int noTrade, int margin);
int    TM2CandidateDir(int longScore, int shortScore, int noTrade);
int    TM2ScoreBlock(int dirCode, int dir, bool okQuality);

// modes / gates / plan
bool   TM2ModeAPull(bool longSide, double low, double high, double emaF,
                    double pbTol, bool hasFvg, double fvgPx,
                    bool hasOb, double obPx);
bool   TM2ModeAConfirm(bool longSide, double open, double close, double emaF, double pbTol);
bool   TM2ModeBReady(bool longSide, int sweepAge, int sweepBars, bool hasPx,
                     bool confirm, double close, double sweepPx);
bool   TM2ModeBInvalid(bool longSide, int sweepAge, int sweepBars, bool hasPx,
                       double close, double sweepPx, double atrSafe);
bool   TM2ModeCReady(bool longSide, bool boxOk, double close, double res, double sup,
                     double rgTol, double atrSafe, bool confirm, double open);
void   TM2SelectMode(const TM2ModeInput &in, int &modeDir, int &activeMode);
int    TM2ModeReason(const TM2ModeInput &in, bool filterOn, int modeReady);
void   TM2EvaluateGates(const TM2Config &cfg, const TM2Bar &bar,
                        const TM2EngineState &st, int dir, TM2GateStatus &out);
bool   TM2ObstacleBlocked(bool longSide, bool hasDist, double dist,
                          double estTp1, double buffer);
void   TM2BuildPlan(const TM2Config &cfg, const TM2Bar &bar,
                    const TM2EngineState &st, int dir, TM2Plan &plan);

// engine
void   TM2StateInit(TM2EngineState &st);
void   TM2EngineStep(const TM2Config &cfg, TM2EngineState &st, const TM2Bar &bar,
                     int barIndex, TM2BarOut &out);
```

```cpp
struct TM2Plan
{
   bool valid; int dir, orderType;       // ENUM_TM2_ORDER
   double entry, limit, sl, tp1, tp2, tp3, risk, evalRR;
   double posSize, notional, effLev, marginReq, liqPrice, netRR;
   int reason;                           // ENUM_TM2_REASON
};
```

Ghi chú D2 (khớp header đã compile): `TM2BuildDmi` nhận thêm `smooth` (Pine
`ta.dmi(len, 14)` — hằng `TM2_DMI_SMOOTH`); `TM2SessionComponent(closeUp,
cryptoSessNeutral)` thay cho `TM2SessionScore(sessName)` vì Pine tính thành phần
phiên từ hướng nến chứ không từ tên phiên; `TM2AblationAdjust` chỉnh weight **sau**
`TM2EffectiveWeights` (ablation D tắt nhóm, E giữ nguyên) thay vì dựng lại bảng
weight riêng. Hành vi tổng hợp của engine không đổi so với §9. Thêm hai helper
thuần để test contract: `TM2MtfHierarchyOk` (`secChart <= secSetup <= secCtx`) và
`TM2WeekendBlocked` (`weekendFilter && isCrypto && isWeekend && (volRatio<0.8 ||
atrPct<0.6)`); indicator dùng chính hai helper này nên vector I2/I3/E8 kiểm tra
được ở mức header. Engine tự ép `ctxDir`/`setupDir` về 0 khi `!bar.mtfHierOk`
(mode A và buffer MTF), khớp Pine `tm_tfHierarchyOk ? ... : 0`.

`TM2ConfigCanonical` liệt kê **119 khóa** (version + 118 trường) theo đúng thứ tự §3 dạng
`key=value;` với số dùng `%.10g`; `TM2ConfigHash` = FNV-1a 32-bit (offset basis `2166136261`,
prime `16777619`) trên `TM2_CONTRACT_VERSION + "|" + canonical`.

### 12. Test vector (155)

Vector mô tả hành vi **kỳ vọng** cho contract tests Phase 4; chưa chạy. Giá trị số dùng để
khẳng định công thức, không phải kết quả runtime.

#### A. Math / config / time (6)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| A1 | `TM2Clamp(1.5,0,1)`, `(−1,0,1)`, `(0.4,0,1)` | 1 / 0 / 0.4 |
| A2 | server 12:00, srv 180, mkt −300 | `TM2LocalMinute` = 240 (04:00) |
| A3 | minute 1080 / 180 / 480 / 720 / 960 | session ASIA(1) / LONDON(2) / LONDON_NY(4) / NY(3) / NONE(0) |
| A4 | `TM2IsNewServerDay(23:59→00:00)`; `TM2IsNewServerWeek(Sun→Mon)` | true / true; cùng ngày false |
| A5 | push 51 event vào ring 50 | size 50; phần tử đầu = event thứ 2 |
| A6 | FNV-1a `"a"` / `"foobar"`; canonical | `0xE40C292C` / `0xBF9CF968`; 119 khóa theo thứ tự §3 |

#### B. Regime (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| B1 | ADX 25, emaUp, không squeeze | code 1, dir 1 |
| B2 | ADX 25, emaDn, không squeeze | code 1, dir −1 |
| B3 | ADX 25, emaUp, squeeze, slope 0.02 | code −1 |
| B4 | ADX 25, emaUp, squeeze, slope 0.20 | code 0 (squeeze chặn trend, slope lớn) |
| B5 | ADX 17, không EMA | code −1 |
| B6 | ADX 18, không EMA, không squeeze | code 0 (chop strict `<18`) |
| B7 | ADX 22, emaUp, không squeeze | code 1 (`>=22`) |
| B8 | weight totals trend/range/chop; volScore | 98.65 / 95.2 / 74.5; expand → 1, squeeze → −1, none → 0 |

#### C. Candle / overextension (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| C1 | O100 C104 H106 L99 | body 4, range 7, hiWick 2, loWick 1, bull |
| C2 | body 4, ATR 2, hiWick 1 / 1.2 | dispBull true / false |
| C3 | bull body 2, loWick 4 / 3.99 | bullPin true / false |
| C4 | prev 105→100, cur 99→106, body 7 | bullEng true; cur open 100.1 → false |
| C5 | range 10, hiWick 5.5, loWick 1.5 / hiWick 5.49 | bullRej true / false |
| C6 | pin 1 + eng 1 + rej 0.8 | cpBull 2.8, cpScore 0.933333 |
| C7 | cpBull 0, cpBear 2.8 | cpScore −0.933333 |
| C8 | cpBull = cpBear 1 | cpScore 0; extEma 2.0 với close 2020/ema 2000/atr 10; overext tại 2.3 |

#### D. Structure (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| D1 | trend 1, swingHi 100, close 99→101 | bosUp true |
| D2 | trend 0, cross 100 lên | BOS và CHoCH đều false |
| D3 | trend −1, cross 100 lên | chochUp true, bosUp false |
| D4 | trend −1, swingLo 90, close 91→89 | bosDown true |
| D5 | trend 1, cross 90 xuống | chochDown true |
| D6 | trend 0, cross 90 xuống | cả hai false |
| D7 | chochUp + dispBull / không disp | mssUp true / false |
| D8 | swingHi 105>100, swingLo 95>90 / 95<100 | trend 1 / −1; mixed giữ nguyên 0 |
| D9 | brkBar 10, bar 12, retestBars 10, tol 0.5·atr 2 | low 100.9 close 101 → true; bar 10 hoặc 21 → false |
| D10 | fail level 100, ATR 2; HH/EQ | close 99.3 → fail true, 99.4 false; pivH 105 vs 100 → isHH true; EQ khi diff ≤ 0.1 |

#### E. Liquidity / session (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| E1 | PDL 180, low 179, close 181, pdOn | sweepBull true |
| E2 | PWL 180, low 179, close 181, pwOn off / on | false / true |
| E3 | sessLo 190 (tên `-`), low 189, close 191 | sweepBull true; level `max(PDL,190)`; trong phiên low<sessLo false |
| E4 | PDH 200, high 201, close 199 | sweepBear true |
| E5 | eqLo, low[len] 89 < prevLow 90, close 91 / 89.5 | true / false |
| E6 | Asia 105/95 → London 110/90 → `-` 120/80 → London 100/96 | 110/90 → giữ 110/90 → giữ 110/90 (không reset) |
| E7 | sweepBull bar 10, px 95; bar 12 / 14, window 3 | age 2 fresh true; age 4 false |
| E8 | weekend, crypto, volRatio 0.7/0.8, atrPct 0.6 | true / false (điều kiện `<`) |

#### F. Zones / FVG / OB / obstacle (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| F1 | px 100, ATR 2, width 0.5 | top 100.5, bot 99.5, touches 1 |
| F2 | zone mid 100, px 100.9 | merge, touches 2, side/top/bot giữ nguyên |
| F3 | px 101 (diff = atr·width = 1) | không merge → 2 zone |
| F4 | srMax 2, thêm zone thứ 3 | size 2, zone cũ nhất bị bỏ |
| F5 | support 99.5–100.5, ATR 2, low 98.9 / 98.89 | near true / false |
| F6 | resistance 99.5–100.5, high 101.1 / 101.11 | near true / false |
| F7 | low 101, high[2] 100, ATR 2, minAtr 0.3; low 100.59 | push {top 101, bot 100}; gap 0.59 không push |
| F8 | FVG age 101 > life 100; bull low ≤ bot | dead (hai điều kiện độc lập) |
| F9 | dispBull + prev O100 C99; low 99 | OB {top 100, bot 99, srcBar bar−1}; dead khi low ≤ 99; bull OB top cao nhất |
| F10 | SR res bot 101, OB res bot 100.5, PDH 100.2, ATR 2 | nearestRes 100.5 (PDH < 0.6 loại); nearestSup 99 từ SR |

#### G. Volume / VWAP / OBV (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| G1 | volMA 100, vol 221, spike 2.2 | ratio 2.21, bucket TIM(5), isTim true |
| G2 | vol 219.99 | bucket VERYHIGH(4), isTim false |
| G3 | vol 180 | bucket VERYHIGH (`>=1.8`) |
| G4 | volMA 0, vol 100 | ratio 0, bucket TIM (`100>=0`), isTim false |
| G5 | volMA na | ratio 0, bucket VERYLOW(0) |
| G6 | relVol 1.19 / 1.20, rvMin 1.2 | hạng 0 / 0.7 |
| G7 | isTim bull obv+1 / isTim bear obv−1 / relVol 1.2 bull obv 0 | volumeScore 1 / −1 / 0.42 |
| G8 | closes 10,11,10,9; vol 10,20,30,40 | OBV 0, 20, −10, −50; slope −50 (obv[10] na → 0) |
| G9 | new day vol 10 hlc3 100; next vol 30 hlc3 102 | vwap 100 → 101.5; new day reset 110 |
| G10 | close 101, vwap 100, ATR 2 / ATR na close 100 | 0.5 / 0.990099; close 90 → −1 |

> G1 dùng `vol=221, spike=2.2` thay cho `220`: trong double, `100.0*2.2 = 220.00000000000003`
> nên giá trị `220` không còn đúng biên `>=`. G10 với ATR na dùng `denom=close*0.01=1.01` →
> `1/1.01 = 0.990099`, không phải 1.0.

#### H. Indicators (9)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| H1 | RSI 25 / 75 / 50 / 60 | +1 / −1 / 0 / 0.5 |
| H2 | MACD hist (0.5,−0.2) / (0.3,0.1) / (0.1,0.3) / (−0.1,0.05) / (−0.1,−0.3) | 1 / 1 / 0.5 / −1 / −0.5 |
| H3 | rsi +1, macd +0.5 / rsi −1, macd −1 | mom 0.7 / −1 |
| H4 | stack bull / stack bear / close>emaF / close<emaF / bằng | 1 / −1 / 0.4 / −0.4 / 0 |
| H5 | emaF 102, emaF[3] 100.8, atr 2 | slope 0.2; slope 0.03 → emaBull false (strict) |
| H6 | close 110>F105>M100, slope 0.2 / 0.02 | emaBull true / false |
| H7 | close 2020, emaF 2000, atr 10 | extEma 2.0 |
| H8 | range 24 / 26, atr 10 | extCandle 2.4 / 2.6; overext tại 2.6 |
| H9 | atr 10 close 2000; atr na; close 0 | atrPct 0.5 / 0 / 0 |

#### I. MTF / BTC / weekend (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| I1 | close 110/90/100, ema 100 | dir 1 / −1 / **0** (bằng nhau — Q1) |
| I2 | chart M15, setup H1, ctx D1; chart D1, setup H1 | hierarchy true / false |
| I3 | hierarchy false | hai dir 0, bias 0 |
| I4 | (1,1) / (1,−1) / (−1,−1) | bias 1 / 0 / −1 |
| I5 | htfFilter off; setupDir 0; mismatch; hierarchy false | setupOk true / true / false / true |
| I6 | ctxDir −1, dir 1, veto on / off / ctx 0 | veto true / false / false |
| I7 | BTC close 98, ema 100, atr 1; rsi 31 | dump true (cả hai điều kiện); long alt block |
| I8 | leader off / symbol rỗng / BTC self | btcDump và btcPump false (neutral) |

#### J. Group score (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| J1 | bosUp; chochDown; không event trend 1 / −1 / 0 | 1 / −1 / 0.5 / −0.5 / 0 |
| J2 | sweepBull; sweepBear; retestBull; retestBear | 1 / −1 / 0.7 / −0.7 |
| J3 | nearSup + nearRes; chỉ res; chỉ FVG bull; chỉ FVG bear; none | 1 / −1 / 0.8 / −0.8 / 0 |
| J4 | neutral true; neutral false bull; bear | 0 / 0.5 / −0.5 |
| J5 | bias 1 / 0 / −1 | gMtf 1 / 0 / −1 |
| J6 | trendScore các nhánh | khớp H4 |
| J7 | vwapScore 0.5 / −3 | 0.5 / −1 |
| J8 | cpScore 0.933333 / −0.933333 | khớp C6/C7 |
| J9 | volumeScore các nhánh | khớp G7 |
| J10 | momScore 0.7 / −1 | khớp H3 |

#### K. Side score / direction / quality (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| K1 | base weight E, mọi group +1 trừ sess 0 | LONG 96, SHORT 0, gap 96, dir 1, quality A+ |
| K2 | mọi group −1 trừ sess 0 | LONG 0, SHORT 96, dir −1 |
| K3 | như K1 + sess 0.5 (neutral off) | LONG 98 |
| K4 | mọi group 0 | 0/0, NO_DIRECTION, quality NO TRADE |
| K5 | LONG 60, SHORT 55, margin 8 | AMBIGUOUS, dir 0, quality NO TRADE |
| K6 | LONG 60, SHORT 52 | gap 8 → OK, dir 1 |
| K7 | LONG 49, SHORT 45 | cả hai `<=49` → NO_DIRECTION |
| K8 | LONG 65, SHORT 65 | AMBIGUOUS |
| K9 | score 49/50/64/65/74/75/84/85 | level 0/1/1/2/2/3/3/4 |
| K10 | min SETUP, level 1; code AMBIGUOUS score 90; OK level 1 dir 1 | block SCORE_LONG; quality NO TRADE; block AMBIGUOUS |

#### L. Entry modes (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| L1 | trending bull, MTF ≥0, low ≤ emaF+tol, close>open≥emaF−tol | mode A ready long |
| L2 | như L1, ctxDir −1 | A không ready |
| L3 | low > emaF+tol, không FVG/OB | pull false |
| L4 | sweep bull age 2, pin bull, close > sweepPx | B ready long |
| L5 | age 4, window 3 | B không ready |
| L6 | close < sweepPx − 0.1·atr | B invalid long |
| L7 | ranging box, close gần sup, pin bull, modeC on / off | ready long / không |
| L8 | A và B cùng ready long | activeMode A (ưu tiên) |
| L9 | modeDir 1, DIR −1; filter off | gate false / true |
| L10 | ready A; B invalid; await; mode NONE + `emaF` na | MODE_A_PULLBACK / MODE_INVALIDATED / WAIT_CONFIRMATION / NO_SETUP |

#### M. Gates / eligibility (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| M1 | regime −1; gate on / off | blocked / pass |
| M2 | ranging, res 110 sup 90, close 101 / 99; thiếu sup | blocked / pass / pass |
| M3 | htfFilter, setupDir 1, dir −1 | GATE_MTF false, reason BLOCKED_MTF |
| M4 | ctxDir −1, dir 1, veto on | GATE_MTF false |
| M5 | estTp1 15, buffer 0.7, dist 10 / 10.5 | blocked / pass (strict `<`) |
| M6 | overext, entry Market / Auto / Strict | blocked / pass / pass |
| M7 | weekendBlocked | GATE_CIRCUIT false, reason BLOCKED_LIQUIDITY |
| M8 | btcDump, dir 1 | GATE_BTC false, reason BTC_DUMPING_VETO |
| M9 | regime + MTF cùng fail | GATE_TOP_REASON = BLOCKED_REGIME; mask cả hai |
| M10 | tất cả pass | GATE_ALL 1, reason OK |

#### N. Plan / risk / sizing (12)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| N1 | ATR 10, entry 2000, swing 1985, pad 0.2, atrMul 1.5 | dist 16, SL 1984, TP 2016/2032/2048, pos 6.25, notional 12500, lev 1.25, margin 625, liq 410 |
| N2 | rr1 2, rr2 2, rr3 3, risk 16 | r2 2.5, r3 3.5; TP 2032/2040/2056 |
| N3 | atr 10, atrMul 0.1, swing=entry, pad 0 | base 0.5 → clamp min → dist 5 |
| N4 | swing 1900, entry 2000, pad 0 | base 57.5 → clamp max → dist 30 |
| N5 | dir 0, ATR 10, close 2000 | SL=TP1..3=2000, RISK 13.5, LIQ EMPTY, valid false, NO_DIRECTION |
| N6 | ATR na | ENTRY close, SL/TP/RISK/LIQ EMPTY, reason BLOCKED_NO_ATR |
| N7 | N1 + fee 0.5% | netRR 0.846154 → BLOCKED_NET_RR |
| N8 | equity 10000, risk 10%, dist 0.75, entry 2000 | effLev 266.7 → BLOCKED_MAX_LEV |
| N9 | equity 10000, risk 10%, dist 10, entry 2000, mmr 0.05, maxLev 20 | effLev 20, liq 2000 > SL 1990 → BLOCKED_LIQUIDATION_RISK |
| N10 | N1 fee 0 / fee 0.08 | netRR 2.0 / 1.727273 |
| N11 | Market; Auto + overext, FVG 1990; FVG 2005, mintick 0.01 | entry close; LIMIT 1990; LIMIT 1999.99 |
| N12 | ATR na + dir 0; dir 0; rrMin 5; fee 0.5% | NO_ATR / NO_DIRECTION / RR / NET_RR (ưu tiên đúng) |

#### O. State machine (16)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| O1 | signal + idle, MARKET | stage OPEN, entry=plan, posBars 0, dayCount+1, barsSince 0, EV_ENTRY, FILLED_N+1 |
| O2 | signal + idle, LIMIT | stage PENDING, EV_PENDING, dayCount+1, FILLED_N không đổi |
| O3 | pending, low ≤ limit | fill tại limit, stage OPEN, posBar=current, EV_FILLED, FILLED_N+1; nến fill chạy luôn nhánh open nên `posBars=1` (Pine: `posBars:=0` rồi `>=OPEN` cộng 1 — vector gốc ghi 0 là sai) |
| O4 | pending posBars 5, cancelBars 5 | CANCEL_TIMEOUT, EV_CANCEL, needReset |
| O5 | pending, high ≥ TP1 trước khi fill | CANCEL_MISSED |
| O6 | fill bar, low ≤ SL và high ≥ TP1 | loss theo SL, EV_TP 0 (TP bị chặn trên fill bar) |
| O7 | stage OPEN, high ≥ TP1, low > SL | stage TP1_BE, EV_TP 1, EV_BE, SL = entry+0.05·ATR, TP1_HITS+1 |
| O8 | stage TP1_BE, high ≥ TP2 | stage TP2_TRAIL, SL = TP1, EV_TP 2, EV_TRAIL; trail `high[1]−1.5·atr` nếu cao hơn |
| O9 | stage 4, high ≥ TP3 | đóng, TP3, R 1.8, NET_WINS+1 |
| O10 | stage OPEN, low ≤ SL | đóng, R −1, FULL_LOSSES+1, CONSEC+1 |
| O11 | stage TP1_BE, low ≤ SL | BREAKEVEN, R 0.3984, BE_SAVES+1, NET_WINS+1, CONSEC 0 |
| O12 | stage TP2_TRAIL, low ≤ SL | TRAIL, R 1.1984, NET_WINS+1 |
| O13 | cùng nến SL + TP | nhánh SL thắng |
| O14 | stage OPEN, posBars 15, maxFavR 0.2, ADX 21, close 1996 | TIMEDECAY, R −0.25, DECAYS+1 |
| O15 | nến đóng lệnh có signal | không entry cùng nến; nến kế tiếp xử lý reset (vẫn chưa entry vì `okPosition` tính trước reset); nến sau đó mới entry được |
| O16 | entry bar / nến sau; pending counter | entry MARKET: posBars 0 → 1; pending +1 mỗi nến; nến fill kết thúc ở posBars 1 (reset 0 trong nhánh pending rồi nhánh open +1) |

#### P. Output / bar policy / config (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| P1 | `j == rates_total−1` | mọi buffer 0/EMPTY, không chạy engine |
| P2 | warm-up ATR/RSI/MACD chưa đủ | score EMPTY, NO_DIRECTION, PLAN_VALID 0, reason NO_ATR |
| P3 | replay 2 lần cùng dữ liệu | toàn bộ buffer giống nhau |
| P4 | buffer ↔ plot | 16 plot map 0..15; contract 16..241 |
| P5 | `na` → buffer | giá = EMPTY; enum/cờ = 0; EV/edge = 0 |
| P6 | default config | neutral session → gSess 0; modeC off; modeFilter on; plan default valid (rr2 2 ≥ rrMin 1.5) |
| P7 | normalize swingLen 1/25; srMax 0/99; fvgMax 0/99; maxDay 0 | 2/20; 1/20; 1/50; 1 |
| P8 | cancel reason | TIMEOUT 9, MISSED 10; `CLOSE_REASON` 0..8 |
| P9 | event ring | chỉ 4 kind; cap 50; không dedupe |
| P10 | event timestamp | `srcTime = bar.time` khi push, `srcBar = bar_index`, không phải bar pivot |

### 13. Validator và Gate 3

`scripts/validate_tmind2.py` (static only, không compile, không chạy MT5, không tuyên bố parity)
kiểm tra:

| # | Check | Kỳ vọng |
|---:|---|---|
| V1 | Contract constants | `16/226/242/16`, max zone/FVG/OB/event |
| V2 | `ENUM_TM2_BUFFER` | 226 entry, giá trị 16..241 đúng một lần |
| V3 | Enum phụ | asset/entry/limit/quality/dircode/regime/session/reason/mode/order/stage/close/event/bucket |
| V4 | `TM2_CONTRACT_VERSION` | `"1.0.0"` |
| V5 | Indicator | `indicator_buffers 242`, `indicator_plots 16`, include contract |
| V6 | Bind | 242 buffer, index 0..241 đúng một lần; 0..15 DATA, 16..241 CALCULATIONS |
| V7 | Closed bar | `lastClosed = total - 2` và `j <= lastClosed` |
| V8 | Không confirm input | không khai báo input confirm |
| V9 | Input count | đúng 118 `input` |
| V10 | Test IDs | đủ A1..A6, B1..B8, C1..C8, D1..D10, E1..E8, F1..F10, G1..G10, H1..H9, I1..I8, J1..J10, K1..K10, L1..L10, M1..M10, N1..N12, O1..O16, P1..P10 |
| V11 | Marker | test script in `TEST\|RESULT\|ALL_PASS` |
| V12 | Docs | contract chứa `indicator_buffers 242`, `## 12. Test vector`, `NOT_IMPLEMENTED`, `BLOCKED` |
| V13 | Safety | không `OrderSend/CTrade/AccountInfo/WebRequest/Socket*/FileOpen/Alert/...` |
| V14 | No placeholder | không `TODO/FIXME/TBD/PLACEHOLDER` |

Gate 3:

| # | Tiêu chí | Trạng thái |
|---|---|---|
| C1 | Mọi buffer EA cần có index, miền, kiểu thiếu, loại | PASS |
| C2 | Bar policy và replay order khớp Phase 2 (P1/P5/P6) | PASS |
| C3 | Quirk nguồn ghi rõ, không "sửa" âm thầm | PASS (§14) |
| C4 | Test vector phủ helper + engine + plan + state machine | PASS (155) |
| C5 | Không tuyên bố runtime/parity | PASS (`NOT_RUN` / `BLOCKED`) |
| C6 | Không sửa Pine nguồn | PASS |
| C7 | Input chết/hiển thị được loại bỏ hoặc ghi rõ | PASS (§3) |

**Kết luận:** contract đóng băng cho Phase 4. Runtime `NOT_RUN`; EA `NOT_IMPLEMENTED`;
parity `BLOCKED` (chưa có CSV Pine).

#### Bằng chứng Phase 4 (2026-10-28)

| Hạng mục | Kết quả quan sát |
|---|---|
| `TMIndicator2.mq5` (MetaEditor CLI) | 0 errors, 0 warnings; `.ex5` 140.596 byte |
| `TMIndicator2ContractTests.mq5` | 0 errors, 0 warnings; `.ex5` 130.042 byte |
| `scripts/build_pineport.ps1` | `BUILD_OK: 13 source(s) compiled with 0 errors and 0 warnings` |
| `scripts/validate_tmind2.py` | `VALIDATION_OK: pass=44 fail=0` |
| Chạy 155 vector trong terminal | **PASS 155/155** (2026-10-28) |
| Parity Pine-vs-MQL5 | `BLOCKED` |

Compile và validator tĩnh không chứng minh vector pass; cần chạy script trong MT5 để xác nhận.


### 14. Hành vi nguồn phải giữ nguyên (Q1–Q16)

| ID | Quirk | Hệ quả port |
|---|---|---|
| Q1 | `ctxDir/setupDir = close>ema ? 1 : close<ema ? −1 : 0` (ternary ba nhánh) | `close == ema` → **0**; hierarchy sai → cả hai 0 |
| Q2 | Gate regime RANGING chỉ block khi có **cả** res và sup | Thiếu một barrier → không block |
| Q3 | `gSr` dùng near S/R + FVG, **không** dùng OB | OB không đóng góp điểm S/R |
| Q4 | `gSess` nhân `cryptoSessNeutral ? 0 : 0.5`; default neutral true | Group session = 0 mặc định, luôn làm loãng cả hai phía |
| Q5 | Session HL cập nhật trước sweep; `-` không reset/không đổi `sessPrev` | Sweep session chỉ đúng ngoài phiên với mức cũ; quay lại cùng phiên không reset |
| Q6 | `TP1_HITS` tăng khi bất kỳ TP nào chạm lúc stage OPEN | TP2/TP3 trực tiếp vẫn tính là "TP1 hit" |
| Q7 | Sweep event level `max(PDL, nz(sessLo, PDL))` | PDL `na` → level `EMPTY` dù sessLo có giá trị |
| Q8 | Trail dùng `high[1]`/`low[1]`; TP2 đặt SL = TP1 vô điều kiện | SL có thể nhảy về TP1 dù autoBE off; trail trễ một nến |
| Q9 | `NO_TRADE_REASON` không có nhánh liquidity | Weekend block có thể hiện reason `OK` trong khi `SIGNAL=0` |
| Q10 | TP3 R = `0.4rr1+0.4rr2+0.2rr3` không trừ fee | BE/TRAIL trừ fee, TP3 thì không |
| Q11 | `BAD_SL`/`BAD_TP` gần như không đạt được; `slMin > slMax` → clamp trả `lo` | Chỉ là mã dự phòng; không "sửa" công thức |
| Q12 | Deferred reset sau khi đóng/huỷ | Nến đóng vẫn giữ POS_*; nến sau reset rồi mới có thể entry |
| Q13 | `tm_signal` không có gate bar trong replay; `CANDIDATE/ELIGIBLE` là rising edge | Counter chỉ tăng khi trạng thái chuyển false→true |
| Q14 | Fill bar: TP bị chặn, SL vẫn xét | Nến limit khớp có thể loss ngay, không thể win ngay |
| Q15 | Liquidation chỉ chặn khi `mmr >= 1/effLev` | Với default mmr 0.005/maxLev 20 không đạt được; test N9 dùng mmr 0.05 |
| Q16 | Nến có `SIGNAL` vẫn có thể bị chặn bởi `POS_STAGE != IDLE` | Signal là điều kiện cần, không đủ để entry |

Ngoài ra:

- `barsSince` khởi tạo 999999 → nến đầu luôn qua cooldown.
- `dayCount` reset đầu ngày server **trước** gate, tăng khi entry (cả limit pending).
- `consecLosses` reset đầu ngày và khi TP3/BE/TRAIL/decay-timeout có R>0.
- Retest/fail dùng `brkLevel/brkBar` không reset theo nến → có thể lặp trong cửa sổ.
- `swingLo/Hi` (SL) là pivot structure `msSwingLen`, không phải rolling min/max.
- `bbwPct`/`bbWidthMA` dùng cửa sổ riêng; `bbWidthMA` hard-coded 20.
- Volume = `tick_volume`; TradingView `volume` trên forex cũng là tick volume nhưng số liệu
  có thể lệch nhà cung cấp (P11).
- Không port `tm_emaSlope50`, trendline touch counters, dashboard, alert.

### 15. Câu hỏi mở

1. Biên MTF `close_time == chart open` (P4) cần CSV xác nhận.
2. `ta.stdev` population vs sample trong `ta.bb` — port dùng population; cần CSV đối chiếu.
3. `ta.dmi(len, 14)` smoothing và seed cần CSV xác nhận khi parity.
4. Nguồn BTC (`InpBtcSymbol`) trong Strategy Tester: symbol phải có history; nếu thiếu, port
   neutral — cần chốt có nên fail-fast hay không.
5. PWH/PWL tham gia obstacle dù `InpLiqPwOn = false` (Q5 mở rộng) — có nên thêm toggle MQL5
   hay giữ nguyên Pine?
6. Mode C chưa được validate OOS; giữ default off.
7. Warm-up `EMPTY` cho score (P14) khác Pine ở mức buffer (Pine `na`), nhưng quan sát hướng/
   signal tương đương; cần CSV những nến đầu để xác nhận.
8. Timeframe/symbol parity chuẩn (XAUUSD M15 là ứng viên) — chưa chốt.
