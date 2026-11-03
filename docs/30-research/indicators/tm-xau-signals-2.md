# TM XAU Signals 2 — Spec, Repaint Audit và Buffer Contract

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `INDICATOR_SPEC_TMXAUSignals2.md`, `REPAINT_AUDIT_TMXAUSignals2.md`, `BUFFER_CONTRACT_TMXAUSignals2.md`.

Nội dung:
1. Indicator Spec — TM XAU Signals 2 (Pine v6)
2. Repaint Audit — TM XAU Signals 2 (Pine v6)
3. Buffer Contract — TM XAU Signals 2 (Pine v6 → MQL5)

---
## Indicator Spec — TM XAU Signals 2 (Pine v6)

- **Phase:** 1 — Đặc tả thuật toán trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `PORTABLE_WITH_DIFFERENCES` (xem §13, §14)
- **Nguồn:** [`dist/TM XAU Signals 2.pine`](../../../tm-trading/pine/dist/TM%20XAU%20Signals%202.pine)
  (indicator, 1.383 dòng, 118 input). Chỉ đọc, không sửa.
- **Nguyên tắc:** SIMULATION_ONLY. Port chỉ tín hiệu trên nến đã đóng; không alert/webhook,
  không execution, không đọc tài khoản.

### 1. Phạm vi

| Port | Không port |
|---|---|
| L0 config tín hiệu (nhóm toggle ảnh hưởng điểm/gate) | Dashboard 2×23 (L11) |
| L1 core: ATR/ATR%, VSA volume, RelVol, OBV, EMA 20/50/200, pivot, swing, session | `label`/`box`/`line`/`plotshape` trang trí |
| L2 market structure: BOS, CHoCH, MSS, HH/HL/LH/LL, retest, failed breakout, cont, pull | Trendline 2 điểm (chỉ vẽ + touch counter) |
| L3 liquidity: PD/PW/Session HL, equal HL, sweep | `alertcondition` + webhook JSON |
| L4 zones: S/R, FVG, OB (chỉ phần ảnh hưởng điểm) | `payloadMode`, màu, `show*`, `dashSize` |
| L5 candle patterns: pin, engulfing, displacement+volume, rejection | `x2_vol_purWin` + `x2_timCount` (chết, không dùng) |
| L6 indicators: RSI/MACD/DMI-ADX/BBW/ATR%/RelVol/OBV/VWAP/day range | `x2_isAsia/isLondon/isNy` (chết, không dùng) |
| L7 MTF context (H4/D/W/M) + setup (H1/M15) + veto | `x2_showEma`, `x2_showVol`, `x2_showVwap` (chỉ vẽ) |
| L8 scoring 11 nhóm + quality | |
| L9 risk plan (R) + gate (MTF/cooldown/day/score/dir) | |
| L10 state machine + thống kê | |
| L12 event ring 50 (kind/dir/srcBar/srcTime/tf/confirmed/level) | |

### 2. Layer map (theo source)

| Layer | Nội dung | Dòng |
|---|---|---:|
| SHARED | `f_sessionOk`, `f_vsaColor/Name`, `f_clamp`, `f_fmtPx`, `f_isNewDay`, `f_ts/f_sym`, `f_sessAsia/London/Ny/Name`, `SrZone + f_addZone/f_near*` | 4–102 |
| L0 | 118 input | 106–298 |
| L1 | ATR/ATR%, volume RMA + VSA + TIM, RelVol, OBV + slope, EMA stack, candle metrics, pivot, swing, session | 300–372 |
| L2 | `X2Event` ring, structure state, pivots → BOS/CHoCH/MSS, HH/HL, retest, failed breakout, cont/pull, event push, labels | 373–548 |
| L3 | PDH/PDL, PWH/PWL, session HL, equal HL, sweep, level lines, trendline | 549–730 |
| L4 | S/R zones, FVG, OB, zone boxes, near-zone flags | 731–844 |
| L5 | Pin, Engulfing, Displacement+volume, Rejection, `cp_score` | 845–885 |
| L6 | RSI/MACD/DMI, ATR regime/BBW, RelVol/OBV/VSA, VWAP/day range, trend score | 886–932 |
| L7 | Context TF + Setup TF (`request.security` `[1]` + lookahead_on) | 933–949 |
| L8 | 11 nhóm trọng số, `score100`, `dir`, quality, MTF gate | 950–985 |
| L9 | `X2Plan`, gate cuối, `x2_signal` | 986–1046 |
| L10 | Position lifecycle, thống kê, event flags | 1047–1167 |
| L11 | Plot/label/box/dashboard | 1168–1336 |
| L12 | alertcondition + webhook JSON | 1337–1376 |

### 3. L1 — Core

- `ATR = ta.atr(atrLen)`, `ATR% = ATR/close*100`.
- Volume: `vol = nz(volume)`; `volMA = ta.rma(vol, volMaLen)`;
  `volRatio = volMA>0 ? vol/volMA : 0`; `bucket = f_vsaName(...)` theo
  `spikeR/rVH/rH/rN/rL` (so sánh `>=`, thứ tự từ cao xuống).
- `isTimRaw = volMA>0 && vol >= volMA*spikeR`; `isTim = isTimRaw && volEvtOk`, với
  `volEvtOk = (volMin<=0 || vol>=volMin) && sessionOk(volSess, volTz)`.
- `timCount = math.sum(isTim, purWin)` — **chết** (không dùng ở đâu khác).
- `relVol = vol/SMA(vol, rvLen)` (0 nếu SMA ≤ 0/na).
- `OBV` thủ công: `obv += close>close[1] ? vol : close<close[1] ? -vol : 0` (khởi tạo 0);
  `obvSlope = obv - nz(obv[obvLen])` qua cửa sổ mảng `obvLen+2` (warm-up: `nz(na)=0` → slope = obv).
- `emaF/M/S = ta.ema(close, emaFast/Mid/Slow)`; `stackBull = F>M>S`, `stackBear = F<M<S`.
- Candle: `body=|close-open|`, `range=max(high-low,mintick)`, `hiWick=high-max(c,o)`,
  `loWick=min(c,o)-low`, `bullBar/bearBar`;
  `dispBull = body>=dispAtr*ATR && hiWick<body*0.3` (bear đối xứng).
- Pivot: `ta.pivothigh/low(high/low, ms_swLen, ms_swLen)` — xác nhận tại `bar_index`,
  giá trị tại `high[swLen]`.
- `swingLo = ta.lowest(low, slSwing)`, `swingHi = ta.highest(high, slSwing)`.
- Session (giờ `sessTz`, mặc định NY): Asia 17:00–02:00, London 02:00–10:00, NY 07:00–15:00;
  `overlap = London && NY`;
  `sessScore = overlap?1.0 : NY?0.8 : London?0.6 : Asia?0.2 : 0.0`.

### 4. L2 — Market structure

State: `lastHigh/prevHigh/lastHighBar`, `lastLow/prevLow/lastLowBar`, `trend` (1/-1/0),
`brkLevel/brkDir/brkBar` (không reset theo nến).

Khi pivot high xác nhận (`newH = high[swLen]`, `newHBar = bar_index-swLen`):

1. Nếu đã có `lastHigh`:
   - `trend<=0 && close>lastHigh` → **BOS up**, `trend=1`, `brk=lastHigh`, `brkDir=1`, `brkBar=newHBar`.
   - `trend<0 && newH>lastHigh` → **CHoCH up**, `trend=1`, cùng brk.
   - `prevHigh = lastHigh`.
2. `lastHigh = newH`, `lastHighBar = newHBar`.

Pivot low đối xứng (BOS/CHoCH down).

- **MSS**: `(BOS up || CHoCH up) && dispBull` → MSS up (down đối xứng). Lưu ý: BOS+CHoCH
  cùng nến có thể cùng true; điều kiện MSS chỉ cần một trong hai.
- **HH/HL/LH/LL**: so `high[swLen]` với `prevHigh`, `low[swLen]` với `prevLow` tại nến xác nhận.
- **Retest**: `retestOn && brkDir==1 && bar_index-brkBar<=retestBars && low<=brkLevel+retestTol*ATR
  && close>brkLevel` (bear đối xứng).
- **Failed breakout**: `failOn && brkDir==-1 && bar_index-brkBar<=failBars && close>brkLevel`
  (bear đối xứng).
- **Continuation**: `contOn && trend==1 && isHH` / `trend==-1 && isLL`.
- **Pullback**: `pullOn && trend==1 && low<=emaM && close>emaM` (bear đối xứng).
- **Event ring** `X2Event[50]`: mỗi sự kiện `{kind, dir, srcBar, srcTime, tf, confirmed, level}`;
  push khi `okConfirmed` (chỉ ring, không ảnh hưởng score). Thứ tự push trong một nến:
  BOS → CHoCH → MSS → RETEST → FAILBRK → CONT → PULL; SWEEP push sau ở L3.
  `srcBar` = `lastHighBar/lastLowBar` (BOS/CHoCH/MSS/CONT), `bar_index` (RETEST/FAILBRK/PULL).
- **Labels** BOS/CHoCH/MSS/RT/FAIL chỉ vẽ (L11), không ảnh hưởng điểm.

### 5. L3 — Liquidity

- `PDH/PDL = request.security(sym, "D", high[1]/low[1], lookahead_on)`;
  `PWH/PWL` tương tự với "W". So sánh với `na` luôn false.
- Session HL: reset khi **tên phiên đổi** (và tên mới khác `-`), mở rộng trong phiên;
  tên `-` (15:00–17:00) **không reset** → giữ mức phiên trước.
- Equal HL: `|high[swLen]-prevHigh| <= atr*eqTol` (low đối xứng).
- **Sweep bull**: `low < PD/ PW/ SessionLo/ prevLow` và `close` trở lại trên mức
  (mỗi nguồn có toggle `pdOn/pwOn/sessOn`; nhánh equal low dùng `prevLow`). Bear đối xứng.
  Event level khi push: bull `max(PDL, nz(sessLo, PDL))`, bear `min(PDH, nz(sessHi, PDH))`
  — **không nhất thiết** là mức vừa bị sweep (quirk Q4).
- **Quan hệ thứ tự**: session HL được cập nhật trước sweep và đã gồm high/low nến hiện tại,
  nên nhánh sweep session chỉ bật khi tên phiên `-` (dùng mức phiên trước) — giữ nguyên.
- **Trendline 2 điểm**: 2 pivot gần nhất mỗi phía, `slope`, giá trị tại bar, touch counter.
  Chỉ dùng cho vẽ/dashboard → **không port** (D10).

### 6. L4 — Zones

- **S/R**: pivot `srLeft/srRight`; thêm zone khi pivot xác nhận. Merge nếu
  `|mid - px| < atr*srWidth` (tăng `touches`, **không** đổi top/bot/side). Zone mới
  `top=px+half`, `bot=px-half`, `half=atr*srWidth*0.5`. Xoá zone `broken` (chỉ có thể ở block
  `barstate.islast`), giới hạn `srMax`.
- `nearSupport/f_nearSupport(zones, atrArg)`: tồn tại zone support chưa broken với
  `low >= bot - atrArg*0.3 && low <= top + atrArg*0.3`; resistance đối xứng với `high`.
  (Ngưỡng gọi từ score truyền **ATR đầy đủ** → cửa sổ thực `±0.3·ATR`.)
- **FVG**: bull khi `low > high[2] && low-high[2] >= fvgMinAtr*ATR`; bear đối xứng với `low[2]`.
  Push rồi `shift` khi vượt `fvgMax`. Dead khi `bar_index-srcBar > fvgLife`, hoặc bull `close<bot`,
  bear `close>top`.
- **OB**: bull khi `dispBull && close[1]<open[1]`; bear khi `dispBear && close[1]>open[1]`;
  vùng = body nến trước; giới hạn `obMax`; dead khi close xuyên vùng.
- `nearFvgBull/Bear`: FVG/OB chưa dead, khoảng cách `0.3*ATR` (bull dùng `low`, bear `high`).

### 7. L5 — Candles

| Pattern | Công thức | Điểm |
|---|---|---:|
| Pin bull | `bullBar && loWick >= pinRatio*body` | +1 |
| Engulf bull | `bullBar && close[1]<open[1] && close>=open[1] && open<=close[1] && body>=prevBody` | +1 |
| Displacement | `dispBull && bullBar && vol >= spikeR*volMA` | +1.2 |
| Rejection | `hiWick>=range*0.55 && loWick<=range*0.15 && bullBar` | +0.8 |

- Bear đối xứng. Không có volume veto / engulf streak (khác PA MTF).
- `cpScore = cpBull>cpBear ? min(1,cpBull/3) : cpBear>cpBull ? -min(1,cpBear/3) : 0`.
- `cpBull` tối đa 4.0 (1+1+1.2+0.8) → clamp 1.0.

### 8. L6–L8 — Indicators, Scoring

- RSI score: `<os → +1`, `>ob → -1`, else 0. MACD score: crossover +1, crossunder −1,
  hist>0 +0.5, hist<0 −0.5. DMI score: `ADX>=adxMin` → `DI+>DI- ? +1 : -1`, else 0.
  `gMom = (rsi+macd+dmi)/3`.
- Volatility: `atrMa=SMA(ATR,20)`; regime `ATR>1.2*MA?1 : ATR<0.8*MA?0 : 0.5`;
  `BBW=(up-lo)/mid*100`; `expand=BBW>SMA(BBW,bbLen)`;
  `volScore=expand ? (close>open?0.5:-0.5) : 0`.
- Volume: `relVolScore` (±1 nếu `relVol>=rvMin`), `obvScore` (±1 theo slope), `vsaScore`
  (±1 nếu TIM theo hướng nến); trung bình 3.
- Location: `vwapScore ±1`; `dayRange=(close-PDL)/(PDH-PDL)*2-1` (0 nếu PDH<=PDL);
  `location=(vwapScore+clamp(dayRange,-1,1))/2`.
- Trend: stack → ±1; nếu không stack nhưng `close>emaF>emaM` → +0.5 (đối xứng −0.5).
- MTF: `ctxDir/setupDir = close>EMA ? 1 : -1` (0 nếu EMA na); `gMtf=(ctxDir+setupDir)/2`.
- 11 nhóm:
  - trend = trendScore
  - struct = `(bosUp||chochUp||mssUp)?1 : (bosDown||chochDown||mssDown)?-1 : trend*0.5`
  - liq = `sweep?±1 : retest?±0.7 : 0`
  - loc = locationScore
  - sr = `nearSupport?1 : nearResistance?-1 : nearFvgBull&&!nearFvgBear?1 : nearFvgBear&&!nearFvgBull?-1 : 0`
  - candle = cpScore
  - volume = volumeScore
  - volatility = `atrRegime*(close>=open?1:-1)*0.5 + volScore*0.5`
  - momentum = momScore
  - session = `sessScore*(close>=open?1:-1)`
  - mtf = gMtf
- Trọng số: trend 15, struct 15, liq 12, loc 8, sr 10, candle 10, volume 8,
  volatility 7, momentum 7, session 4, mtf 4 (tổng 100, cấu hình được).
  `raw = clamp(Σ w_i g_i / Σ w_i, -1, 1)`; `score100 = round(50 + raw*50)`; `dir=sign(raw)`.
- Quality: `<=noTrade NO TRADE`, `<=weak WEAK`, `<=setup SETUP`, `<=strong STRONG`, else `A+`.
- MTF gate:
  `okSetup = !htfFilter || setupDir==0 || setupDir==dir`;
  `htfVeto = htfVetoOn && ctxDir!=0 && dir!=0 && ctxDir!=dir`; `okMtf = okSetup && !htfVeto`.

### 9. L9 — Risk plan & gate

`f_buildX2Plan(dir)`:

```text
pad   = ATR*slPadAtr
swing = dir==1 ? nz(swingLo, low) : nz(swingHi, high)
sDist = (entry-swing)+pad  hoặc (swing-entry)+pad
aDist = ATR*slAtrMul
base  = (aDist+sDist)/2
dist  = clamp(nz(base,aDist), ATR*slMinAtr, max(ATR*slMaxAtr, ATR*slMinAtr))
sl    = entry - dir*dist ; risk = dist
rr2m  = max(rr2, rr1) ; rr3m = max(rr3, rr2m)
valid = ATR>0 && dir!=0 && dist>0 && sl đúng phía && (rrMin<=0 || rr1>=rrMin)
tp_i  = entry + dir*rr_i*risk
```

- Gate: `signal = plan.valid && okMtf && okCool && okDay && okScore && okDir`, với
  `okCool = barsSince>=coolBars`, `okDay = dayCount<maxDay`, `okScore = score100>noTrade`,
  `okDir = dir!=0`. `okBar` (nến đã đóng) gate entry.
- `barsSince` khởi tạo 999999, `+1` mỗi nến; reset 0 khi entry. `dayCount` reset đầu ngày mới
  (trước khi mở lệnh), `+1` khi entry.

### 10. L10 — State machine

Thứ tự cố định mỗi nến:

1. **Deferred reset** (nếu `needReset`): xoá toàn bộ pos.
2. **Quản lý vị thế mở**: `t1 = stage<1 ? tp1 : na`, `t2 = stage<2 ? tp2 : na`,
   `t3 = stage<3 ? tp3 : na`.
   - `hitSl && (hit1||hit2||hit3)` → loss; `hitSl` → loss (hai nhánh trùng kết quả — quirk Q8).
   - `hit3` → TP3, stage 3, **đóng**, win.
   - `hit2` → TP2, stage 2 (không đóng).
   - `hit1` → TP1, stage 1 (không đóng).
   - Quá **300 nến** (`posBars>300`) → đóng, không win/loss.
   - Khi đóng: `trades++`, ghi `entry/sl/dir/bar/exit/R`; `exit = evSl?sl : evTp==3?tp3 :
     evTp==2?tp2 : tp1` (**timeout dùng tp1** — quirk Q9); `needReset=true`.
3. **Mở lệnh mới** nếu `okBar && signal && posDir==0`: gán plan, `evEntry`, `dayCount++`,
   `barsSince=0`, `posBars=0`, `posStage=0`, `posBar=bar_index`.
4. `posBars++` nếu đang mở, không phải nến entry, không reset.

### 11. Khác biệt Pine → MQL5 (D1–D12)

| # | Chủ đề | Pine | MQL5 port |
|---|---|---|---|
| D1 | Bar policy | `barstate.isconfirmed` (input có thể tắt) | Luôn chỉ nến đã đóng; bỏ `confirmOnly` |
| D2 | Timezone phiên | tên tz (`Asia/Ho_Chi_Minh`, `America/New_York`) + DST | Offset phút cố định (`srvOffsetMin`, `mktOffsetMin`, `volSessOffsetMin`); chỉnh khi DST đổi |
| D3 | PDH/PDL/PWH/PWL | D/W bar theo timezone sàn | Tổng hợp từ nến chart theo ngày/tuần **server** (tuần bắt đầu thứ Hai) |
| D4 | MTF EMA | `request.security(expr[1], lookahead_on)` | `CopyRates` TF cao, EMA trên nến đã đóng, map `closeTime <= chart bar open time` |
| D5 | S/R zone `broken` | Chỉ set trong block `barstate.islast` | Không set trong replay (giữ hành vi lịch sử) |
| D6 | VWAP | `ta.vwap(close)` anchor phiên sàn | Cumulative theo volume, reset đầu ngày server |
| D7 | `time("W")` | Tuần theo sàn | Tuần thứ Hai theo server |
| D8 | Dashboard/line/box/label | Có | `NOT_PORTED` (viz-only) |
| D9 | Alert/webhook | `alertcondition` + JSON | `NOT_PORTED` (không alert trong port) |
| D10 | Trendline 2 điểm, `timCount`, `isAsia/isLondon/isNy` | Vẽ/dashboard hoặc chết | Bỏ (không ảnh hưởng điểm) |
| D11 | Session Hi/Lo | Reset theo tên phiên | Cùng quy tắc, giờ tính từ offset cố định |
| D12 | Volume | `volume` của sàn | `tick_volume` (MT5 không có volume thật cho FX); ghi rõ trong contract |

### 12. Warm-up

- EMA slow cần `emaSlow` nến; ATR cần `atrLen`; ATR MA cần thêm 20; RSI cần `rsiLen+1`;
  MACD hist cần `macdSlow+macdSig-1`; DMI/ADX cần `dmiLen+dmiSmooth-1`; BBW cần `bbLen` +
  `bbLen` cho SMA; PDH/PDL cần trọn ngày server trước; PWH/PWL cần trọn tuần trước;
  MTF cần `ctxLen/setupLen` nến TF cao.
- Trước warm-up: giá trị na → so sánh false, score có thể lệch; indicator ghi EMPTY/0 và
  replay bắt đầu từ nến đủ dữ liệu tối thiểu (`x2_maxBars` để giới hạn debug).

### 13. Trạng thái port

| Hạng mục | Trạng thái |
|---|---|
| Spec | tài liệu này |
| Repaint audit | `REPAINT_AUDIT_TMXAUSignals2.md` |
| Buffer contract | `BUFFER_CONTRACT_TMXAUSignals2.md` |
| Indicator | `mt5/Indicators/PinePort/TMXAUSignals2.mq5` |
| Contract tests | `mt5/Scripts/TMXAUSignals2ContractTests.mq5` — **PASS 107/107** (MT5, 2026-10-28) |
| EA hỗ trợ | `NOT_IMPLEMENTED` |
| Parity | `BLOCKED` — chưa có CSV Pine |
| Runtime | Contract test PASS; indicator gắn chart/plot chưa xác minh |

## Repaint Audit — TM XAU Signals 2 (Pine v6)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — phân tích tĩnh trên source Pine; chưa chạy TradingView
  Bar Replay, chưa tạo alert, chưa chạy Strategy Tester. Các kết luận phụ thuộc runtime đánh dấu
  `PENDING` ở §15.
- **Nguồn:** [`dist/TM XAU Signals 2.pine`](file:///D:/Applications/tm-trading/pine/dist/TM%20XAU%20Signals%202.pine)
  (1.383 dòng, indicator, 118 input). Không file Pine nào bị sửa.
- **Đặc tả nền:** `INDICATOR_SPEC_TMXAUSignals2.md`.
- **Nguyên tắc:** SIMULATION_ONLY. Port chỉ tín hiệu trên nến đã đóng; không alert, không webhook,
  không execution, không đọc tài khoản.

### 1. Định nghĩa repaint

| Mã | Hiện tượng | Ảnh hưởng |
|---|---|---|
| RP1 | Marker/trạng thái xuất hiện trên nến đang chạy rồi biến mất trước khi đóng | Tín hiệu “ma”, dashboard nhấp nháy |
| RP2 | Giá trị của nến **đã đóng** thay đổi khi có nến mới hoặc khi tải lại chart | Không thể parity/backtest |
| RP3 | Alert phát trước khi nến đóng | Vào lệnh trên dữ liệu chưa xong |
| RP4 | SL/TP của strategy thay đổi trong nến và áp ngược lại chính nến đó | Fill không có thật |
| RP5 | Hai lần chạy cùng input cho lịch sử khác nhau | Không dùng được làm reference |

TM XAU Signals 2 là **indicator** (không có strategy sibling trong inventory), nên RP4 chỉ tồn tại ở
mức mô phỏng nội bộ của state machine (L10). RP1 xuất hiện ở mọi thành phần tính trên nến realtime
(score, plan, pivot, zone). RP2/RP5 tồn tại thật ở block S/R `broken` (§7) và ở event ring nếu nến
từng là “last bar” (§6).

### 2. Bản đồ phụ thuộc dữ liệu

```
open/high/low/close/time + syminfo.mintick + volume
  ├─ ta.atr(atrLen)                            -> atr, atrPct
  ├─ ta.rma(volume, volMaLen) / ta.sma(volume) -> VSA bucket, volRatio, relVol
  ├─ OBV thủ công + cửa sổ mảng obvLen+2       -> obvSlope
  ├─ ta.ema(close, 20/50/200)                  -> stack, gTrend
  ├─ ta.pivothigh/low(ms_swLen, ms_swLen)      -> structure, trendline, eq HL
  ├─ ta.pivot*(sr_left, sr_right)              -> S/R zones
  ├─ ta.lowest/highest(slSwing)                -> swingLo/Hi (SL)
  ├─ ta.rsi / ta.macd / ta.dmi / ta.bb         -> momentum, BBW
  ├─ ta.vwap(close)                            -> location score
  ├─ request.security(D/W, high[1], lookahead_on)   -> PDH/PDL/PWH/PWL
  ├─ request.security(ctx/setup TF, ema[1], lookahead_on) -> MTF bias
  ├─ var arrays: events(50), S/R(30), FVG(50), OB(50), OBV window(obvLen+2)
  ├─ var state: structure, brk, session HL, session name, day/week OHLC,
  │             VWAP accumulator, dayCount/barsSince, position + counters
  └─ barstate.islast + x2_showViz/x2_showPriceZones/x2_sr_showOn
        -> block S/R broken (MUTATE STATE — xem §7)
```

Không có `request.security_lower_tf`, không offset âm, không dùng dữ liệu tương lai ngoài hai
nhóm `request.security` ở trên. Pivot là **độ trễ cấu trúc**, không phải repaint.

### 3. Cổng confirmed-bar

```pine
x2_confirmOnly  = input.bool(true, ...)                        // dòng 111
x2_okConfirmed  = not x2_confirmOnly or barstate.isconfirmed    // dòng 424
x2_okBar        = x2_confirmOnly ? barstate.isconfirmed : true  // dòng 1039
x2_signal       = x2_plan.valid and x2_okFilter                 // dòng 1045
```

**Được gate bởi `x2_okConfirmed`:** chỉ việc đẩy event vào ring 50 (BOS/CHoCH/MSS/RETEST/FAILBRK/
CONT/PULL/SWEEP) tại dòng 498–525 và 589–592.

**Được gate bởi `x2_okBar`:** mở vị thế mới (dòng 1150) và webhook `alert()` (dòng 1359–1375).

**Không được gate** (tính trên nến realtime):

| Thành phần | Dòng | Hệ quả |
|---|---|---|
| Toàn bộ L1–L8: ATR, volume, OBV, EMA, pivot, structure, zone, candle, score | 300–985 | Dashboard/score nhấp nháy giữa nến (RP1) |
| `x2_signal` (biến) | 1045 | Có thể true giữa nến nhưng entry chưa xảy ra |
| Block S/R `broken` + `f_nearSupport` sau đó | 799–812, 961 | **Mutate state và đổi score trên nến cuối** (§7) |
| Hit TP/SL của state machine | 1100–1139 | Có thể bật giữa nến; cuối nến chốt theo high/low |
| `alertcondition` TP/SL/entry | 1354–1357 | Có thể phát giữa nến (RP3) |
| `f_pushEvent` bên trong vẫn ghi `barstate.isconfirmed` | 498–525 | Ring chỉ nhận event khi `okConfirmed`; giá trị `confirmed` trong payload có thể false nếu input tắt |

Pine rollback `var` về đầu nến realtime mỗi tick nên **kết quả cuối nến vẫn tất định** với dữ liệu
đã đóng — trừ block S/R ở §7, nơi kết quả phụ thuộc việc nến đó từng là “last bar” hay chưa.

**Kết luận:** `confirmOnly = false` không port (D1). MQL5 chỉ tính trên nến đóng.

### 4. MTF và PD/PW — `request.security`

```pine
x2_ctxEma   = request.security(syminfo.tickerid, x2_ctxTf,
                ta.ema(close, x2_ctxLen)[1], lookahead = barmerge.lookahead_on)   // 941
x2_setupEma = request.security(syminfo.tickerid, x2_setupTf,
                ta.ema(close, x2_setupLen)[1], lookahead = barmerge.lookahead_on) // 944
x2_pdh = request.security(syminfo.tickerid, "D", high[1], lookahead = barmerge.lookahead_on) // 556
x2_pdl = request.security(syminfo.tickerid, "D", low[1],  lookahead = barmerge.lookahead_on) // 557
x2_pwh = request.security(syminfo.tickerid, "W", high[1], lookahead = barmerge.lookahead_on) // 558
x2_pwl = request.security(syminfo.tickerid, "W", low[1],  lookahead = barmerge.lookahead_on) // 559
```

`lookahead_on` đi kèm `[1]` nên giá trị dùng là bar HTF/D/W **đã đóng trước bar hiện tại**, không
phải bar đang hình thành. Không có RP2/RP3 từ nhóm này.

Quy tắc port cho MTF (P3): với nến chart mở tại `Tj`, chọn bar HTF `k` gần nhất có
`close_time[k] <= Tj`, tính EMA trên chuỗi close HTF đã đóng, seed SMA(`len`) giống Pine.
Nếu chưa đủ `len` bar HTF → `EMPTY_VALUE` (Pine `na`). Ghi kèm `htf_bar_close_time` khi parity.

PDH/PDL/PWH/PWL (P4): tổng hợp từ nến chart theo **ngày/tuần server**; tuần bắt đầu thứ Hai.
Pine dùng ngày/tuần theo timezone sàn của TradingView → có thể lệch một nến biên (D3).
Với chart TF = D, `high[1]` của Pine tương đương high của ngày server trước.

### 5. Session, VWAP, mốc ngày/tuần

- Session name (dòng 562–565): Asia 17:00–02:00, London 02:00–10:00, NY 07:00–15:00 theo
  `x2_sessTz` (mặc định America/New_York). `x2_sessName` có thể là `London/NY` khi overlap.
- `x2_sessHi/Lo` reset khi **tên phiên đổi** và tên mới khác `-`; mở rộng trong phiên.
  Khi tên là `-` (15:00–17:00), biến **không reset về na** → sweep/score vẫn dùng mức session cũ
  cho đến phiên kế tiếp. Port giữ nguyên (P7).
- Hệ quả thứ tự (dòng 567–587): session HL được cập nhật **trước** sweep và đã bao gồm
  high/low của chính nến hiện tại, nên `low < x2_sessLo` / `high > x2_sessHi` **không thể
  đúng trong phiên**. Nhánh sweep session chỉ có thể bật khi tên phiên là `-`, dùng mức cũ
  của phiên trước. Port giữ nguyên (contract Q4; test F5/F6).
- `f_nearSupport/Resistance` nhân thêm hằng số **0.3** vào tham số ATR: score truyền `ATR`
  → tolerance thực `0.3·ATR` (contract Q1; test K3/K4).
- `x2_dayCount` reset bằng `f_isNewDay()` (dòng 1036–1037) — ngày theo sàn.
- `x2_vwap = ta.vwap(close)` (dòng 924) — anchor phiên của symbol, cumulative volume-weighted.
- Trendline touch counters (dòng 701–704) chỉ dùng cho dashboard; không tham gia score.
  Không port (D10).

Port dùng offset phút cố định (`mktOffsetMin` cho phiên, `srvOffsetMin` cho ngày/tuần server,
`volSessOffsetMin` cho volume session) và VWAP reset đầu ngày server (D2/D6/D7). Người dùng phải
chỉnh offset khi DST đổi.

### 6. Pivot, structure, event ring

- `ta.pivothigh/low(high/low, ms_swLen, ms_swLen)` (dòng 361–362) xác nhận tại `bar_index`; giá
  trị nằm ở `high[ms_swLen]`; `*Bar = bar_index - ms_swLen`. Trên nến realtime, pivot có thể
  xuất hiện/biến mất khi high/low hiện tại thay đổi → RP1 hiển thị, nhưng tại close thì chốt.
- Pivot S/R dùng `sr_left/sr_right` (mặc định 10/10), độc lập với `ms_swLen`.
- BOS/CHoCH là **edge flag** reset mỗi nến (dòng 417–422); `x2_trend` là state.
  MSS = (BOS || CHoCH) + displacement cùng nến.
- `x2_brkLevel/brkDir/brkBar` là state **không reset**; retest/fail có thể bật lại trên nhiều nến
  trong cửa sổ `retestBars/failBars` → event ring có thể nhận nhiều RETEST/FAILBRK liên tiếp.
  Port giữ nguyên (test F3/F4).
- Event ring 50 (dòng 390–395) là **state**, và `srcBar` của BOS/CHoCH/MSS/CONT là bar của pivot
  nguồn, không phải bar hiện tại. Ring bị giới hạn 50 → event cũ bị `shift`.
- Thứ tự push trong nến: BOS → CHoCH → MSS → RETEST → FAILBRK → CONT → PULL (dòng 498–525),
  sau đó SWEEP (589–592). Trong cùng nến có thể có cả BOS và MSS; dashboard chỉ hiển thị event
  **cuối ring** (dòng 1281–1285), port expose `lastEvent` là event cuối được push trong nến.
- Alert EVENT chỉ phát khi `e2.srcBar != x2_lastEvtBar` (dòng 1370–1375), tức dedupe theo
  `srcBar`. Đây là logic alert-only, không port.

### 7. S/R zone — block `barstate.islast` mutate state (trọng tâm)

#### 7.1 Bằng chứng

```pine
// dòng 797–812
var array<box> x2_zoneBoxes = array.new<box>()
if barstate.islast and x2_showViz and x2_showPriceZones
    for bx in x2_zoneBoxes
        box.delete(bx)
    array.clear(x2_zoneBoxes)
    if x2_sr_showOn
        for z in sr_zones
            if z.side == 1 and close < z.bot
                z.broken := true
            if z.side == -1 and close > z.top
                z.broken := true
            ...
```

`sr_zones` là `var array<SrZone>` shared. `z.broken := true` chỉ chạy khi
`barstate.islast && x2_showViz && x2_showPriceZones && x2_sr_showOn`. `f_nearSupport` ở dòng 961
đọc `z.broken`, nên hành vi score phụ thuộc **nến nào từng là last bar**.

#### 7.2 Hệ quả

- Trên chart live: nến hiện tại (last) có thể đánh dấu zone broken **trước khi đóng**; nếu giá
  quay lại, tick sau `close` đổi và điều kiện có thể hết đúng, nhưng `broken` **không được gỡ**
  (chỉ có một chiều). Đây là RP2 thật: zone broken vĩnh viễn sau lần chạm đầu.
- Khi tải lại chart hoặc Bar Replay chạy lại từ đầu, các nến giữa lịch sử **không phải last**
  → không bao giờ set broken; kết quả lịch sử khác với kết quả live (RP5).
- Trong replay của MQL5 (mỗi nến đều được xử lý như nến đã đóng), nếu port set broken mỗi nến
  thì score lịch sử sẽ **khác** Pine lịch sử (nơi zone không bao giờ broken). Nếu không set thì
  khớp Pine lịch sử nhưng khác Pine live.

#### 7.3 Quyết định port

Giữ **hành vi lịch sử** (P5): trong replay, `X2NearSupport/X2NearResistance` chỉ đọc `broken`
nhưng engine **không set** `broken` (trừ khi có API debug riêng). Hệ quả: zone support/resistance
có thể “sống” mãi trong cửa sổ `srMax`; đây là hành vi Pine khi chạy Bar Replay từ đầu, và là
reference duy nhất có thể parity. Ghi rõ trong contract Q2 và test K5/K6.

### 8. State machine — thứ tự và edge case

```pine
// 1086–1097 deferred reset
// 1100–1147 manage open position
if hitSl and (hit1 or hit2 or hit3)   // 1112  -> loss
else if hitSl                          // 1117  -> loss (nhánh trùng)
else if hit3                           // 1122  -> TP3, close, win
else if hit2                           // 1128  -> stage 2
else if hit1                           // 1131  -> stage 1
if not closed and x2_posBars > 300     // 1135  -> timeout
// 1150–1163 open new position
// 1165–1166 posBars += 1
```

- **Ưu tiên SL**: nếu trong cùng nến vừa chạm SL vừa chạm TP → **loss** (dòng 1112).
- **Ưu tiên TP3 > TP2 > TP1** khi nhiều TP cùng chạm (không có SL).
- **TP2/TP1 không đóng vị thế**, chỉ tăng `posStage`; TP1 có thể bị bỏ qua nếu TP2 chạm trước
  trong cùng nến (stage nhảy 0→2). TP1 sau đó không còn được xét (`stage<1` false).
- **Timeout** dùng `posBars > 300` tại đầu khối quản lý; vì `posBars` tăng ở cuối nến, timeout
  thực tế sau 302 nến kể từ nến entry (contract Q9).
- **Exit price khi timeout** rơi vào nhánh `tp1` (dòng 1145) — quirk, port giữ nguyên (test M7).
- **Không thể entry và TP/SL cùng nến**: khối quản lý chạy trước khối mở lệnh (1100 vs 1150).
- **Entry bị chặn khi `posDir != 0`** (1150); sau khi đóng, `needReset` xử lý ở **nến sau**
  (1086), nên nến đóng lệnh không thể mở lệnh mới — kể cả khi signal true.
- **Không có TP/SL intrabar chính xác thứ tự**: chỉ dùng high/low của nến; nến vừa chạm TP vừa
  chạm SL được xử lý là SL (bi quan). Đây là mô phỏng bar-close, không phải tick.

### 9. Quirk risk plan — default có thể không có tín hiệu

- `rrMin` mặc định 1.5, `rr1` mặc định 1.0 → `rrOk = rrMin<=0 || rr1>=rrMin` = **false**.
  Với input mặc định, `plan.valid` luôn false ⇒ **không có entry**. Đây là hành vi Pine, port giữ
  nguyên; test L3/L4 kiểm tra cả hai trường hợp `rr1 < rrMin` (invalid) và `rr1 >= rrMin`.
- `x2_plan.entry = close` của nến tín hiệu; `x2_posEntry` lưu nguyên, không cộng slippage.
- `swing` dùng `nz(swingLo, low)` / `nz(swingHi, high)`; trong MQL5 fallback `low/high` khi
  `swingLo/Hi` EMPTY.
- `dist = clamp(nz(base, aDist), min, max)`; nếu `base` EMPTY (không thể vì aDist hữu hạn khi
  ATR>0) → dùng `aDist`.

### 10. Kịch bản intrabar

| Kịch bản | Pine | Port |
|---|---|---|
| Nến realtime đổi high/low | score/plan/pivot đổi liên tục (RP1) | Không tính nến live; chỉ nến đóng |
| Nến vừa chạm SL vừa chạm TP | `hitSl && (hit1\|\|hit2\|\|hit3)` → loss | Cùng công thức, test M5 |
| Nến chạm TP3 và TP2 | TP3 thắng, đóng, win | Cùng, test M4 |
| Nến chạm TP2 rồi TP1 | stage=2, không đóng | Cùng, test M3 |
| Nến entry rồi giá chạm SL ngay | Không xét SL cùng nến | Cùng (khối quản lý trước entry), test M1 |
| Đóng lệnh hôm nay, signal lại cùng nến | Không mở (posDir!=0 đến hết nến) | Cùng, test M8 |
| Timeout | `posBars>300`, exit=tp1 | Cùng, test M7 |
| `dayCount` đạt `maxDay` | Chặn entry đến hết ngày server | Cùng, test L5 |

### 11. Alert và webhook

- `alertcondition` LONG/SHORT/TP/SL (dòng 1354–1357) và `alert()` JSON ENTRY/TAKE_PROFIT/STOP_LOSS/
  EVENT (1359–1375) **không port** (D9). Contract chỉ expose event/state buffer để EA tự quyết định.
- Nếu sau này cần parity alert: payload ENTRY có `side/price/sl/tps/score/quality/atr`; EVENT có
  `kind/dir/ts/bar/tf/confirmed/level`. `ts` là `str.format_time(time,...,"UTC")` của **nến hiện
  tại**, không phải `srcTime` của event; `bar` là `srcBar`. Ghi nhận để tránh nhầm khi đối chiếu.

### 12. Strategy sibling

Inventory hiện tại **không có** file strategy tương ứng cho TM XAU Signals 2 (chỉ có
`TM Indicator Strategy Lab 2.pine` là indicator khác). Không port execution. Nếu sau này có bản
strategy, phải audit riêng: thứ tự fill, pyramiding, thoát lệnh theo TP từng phần.

### 13. Timestamp contract

- `X2Event.srcTime` là `time` của nến **hiện tại** khi push (không phải nến pivot nguồn), trừ khi
  event lấy `srcBar` từ pivot. Port expose cả `lastEventSrcBar` và `lastEventSrcTime`; `srcTime`
  = `bar.time` của nến push.
- `bar_open_time` dùng trong CSV/parity là thời gian mở nến chart (MT5 `time[]`).
- MTF EMA không expose timestamp bar HTF trong buffer; khi parity cần log riêng
  (`htfCloseTime`) từ indicator — xem §15.

### 14. Chính sách MQL5

| Quyết định | Nội dung |
|---|---|
| P1 | Chỉ xử lý nến `j <= rates_total-2`; nến live để trống |
| P2 | Bỏ `confirmOnly`; luôn confirmed |
| P3 | MTF map theo `closeTime <= bar.openTime`; EMA seed SMA |
| P4 | PD/PW tổng hợp theo ngày/tuần server; tuần bắt đầu thứ Hai |
| P5 | Không set S/R `broken` trong replay (hành vi lịch sử Pine) |
| P6 | Volume = `tick_volume`; ghi rõ trong contract |
| P7 | Session HL giữ mức cũ khi tên phiên `-` |
| P8 | VWAP reset đầu ngày server |
| P9 | Không port trendline, dashboard, alert |
| P10 | Replay toàn bộ mỗi lần có nến mới để dựng lại `var` state |

### 15. Kế hoạch xác minh thủ công (TradingView)

| # | Kiểm tra | Kỳ vọng | Trạng thái |
|---|---|---|---|
| E1 | Chạy Bar Replay 300 nến, ghi event ring | Không có event nào đổi sau khi nến đóng | `PENDING` |
| E2 | Chart M15, ghi PDH/PDL tại 00:00 sàn | Khớp high/low ngày trước | `PENDING` |
| E3 | PWH/PWL tại đầu tuần | Khớp high/low tuần trước, tuần bắt đầu thứ Hai | `PENDING` |
| E4 | MTF EMA tại nến HTF đóng đúng giờ mở nến chart | Không dùng bar HTF đang hình thành | `PENDING` |
| E5 | 15:00–17:00 NY | `sessName = "-"`, sweep session dùng mức cũ | `PENDING` |
| E6 | Tải lại chart vs Bar Replay | Xác nhận zone `broken` khác nhau (RP2/RP5) | `PENDING` |
| E7 | Nến chạm SL và TP cùng lúc | Kết quả loss | `PENDING` |
| E8 | Nến TP3 | Đóng, `wins++`, `evClose` | `PENDING` |
| E9 | Timeout 302 nến | `exit=tp1`, không win/loss | `PENDING` |
| E10 | Entry khi đang mở lệnh | Không entry mới | `PENDING` |
| E11 | Volume session 08:00–16:00 Asia/Ho_Chi_Minh | TIM chỉ trong phiên | `PENDING` |
| E12 | `rr1=1.0, rrMin=1.5` | Không có entry (plan invalid) | `PENDING` |

### 16. Risk register

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Bar-close simulation khác tick-level (SL trước TP) | Cao | Ghi rõ; test M5; không hứa parity fill |
| S/R `broken` khác giữa live và replay | Cao | P5 + contract Q2; parity phải chạy cùng chế độ replay |
| Offset DST sai → session/PDH lệch | Trung bình | Input offset; tài liệu yêu cầu chỉnh khi DST |
| `tick_volume` khác `volume` của TradingView | Trung bình | Ghi contract; parity dùng cùng nguồn volume |
| MTF map lệch biên `closeTime == openTime` | Trung bình | Test E4; dùng `<=` |
| Quirk `rrMin > rr1` làm không có tín hiệu | Trung bình | Test L3/L4; tài liệu cảnh báo |
| State machine không có partial TP thực | Thấp | Chỉ mô phỏng stage; EA tự quyết |

### 17. Gate 2 — tiêu chí

- [x] Spec đầy đủ L0–L12, có layer map + line numbers.
- [x] Xác định cổng confirmed và các thành phần không gate.
- [x] Xác định RP2/RP5 ở S/R `broken`; quyết định P5.
- [x] Liệt kê quirk: session gap, sweep level, rrMin, SL/TP priority, timeout exit, event order.
- [x] Kế hoạch E1–E12 (chưa chạy).
- [ ] E1–E12 có kết quả thật từ TradingView (chưa).
- [ ] CSV reference từ Pine cho parity (chưa).

### 18. Câu hỏi còn mở

1. Có cần expose `sr_zones` broken theo chế độ “live” (set mỗi nến) như option debug không?
   Mặc định: không (P5).
2. `x2_maxBars` của TradingView (`max_bars_back=1000`) ảnh hưởng cửa sổ S/R/OBV thế nào khi
   chart dài? Port replay từ đầu nến, không giới hạn 1000; cần xác nhận khi parity.
3. `timeframe.period` trong `X2Event.tf` là string Pine (`"15"`, `"60"`, `"D"`); buffer contract
   dùng enum TF của MT5 — cần map khi parity.
4. `x2_sessTz` mặc định NY nhưng `x2_vol_tz` mặc định Asia/Ho_Chi_Minh — hai đồng hồ khác nhau
   trong cùng indicator. Port tách thành `mktOffsetMin` và `volSessOffsetMin`; cần xác nhận người
   dùng muốn giữ tách biệt.

## Buffer Contract — TM XAU Signals 2 (Pine v6 → MQL5)

- **Phase:** 3 — Hợp đồng buffer và test vector trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4`
- **Nguồn:** `INDICATOR_SPEC_TMXAUSignals2.md`,
  `REPAINT_AUDIT_TMXAUSignals2.md`,
  [`dist/TM XAU Signals 2.pine`](../../../tm-trading/pine/dist/TM%20XAU%20Signals%202.pine)
  (1.383 dòng, 118 input — chỉ đọc).
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không `OrderSend`, không `CTrade`, không đọc tài
  khoản, không alert/webhook, không `WebRequest`, không file I/O trong indicator.

### 1. Phạm vi

1. Input của `mt5/Indicators/PinePort/TMXAUSignals2.mq5` (**90 input**).
2. **153 buffer**: **13 buffer render** (index 0..12) + **140 buffer hợp đồng** (index 13..152)
   cho EA/audit/parity.
3. Bar policy: chỉ nến đã đóng; replay toàn bộ lịch sử mỗi nến.
4. Cách EA đọc buffer, dedupe, ghi CSV (EA hỗ trợ: `NOT_IMPLEMENTED`).
5. **105 test vector** cho logic thuần trong `TMXAUSignals2Contract.mqh`.

Không định nghĩa: execution, sizing, commission, alert, dashboard, trendline vẽ. Repo không
port các phần đó.

### 2. Chính sách kế thừa Phase 2

| Mã | Chính sách | Thể hiện |
|---|---|---|
| P1 | State chỉ mutate trên nến đóng; replay toàn bộ khi `rates_total` đổi | §7 |
| P2 | EA đọc `shift = 1`; không có input `shift = 0` | §12 |
| P3 | Không port `confirmOnly = false`; không có input confirm | §3 |
| P4 | MTF: bar HTF đã đóng gần nhất có `close_time <= chart **open** time` | §9.4 |
| P5 | S/R: cold replay, **không bao giờ** đánh `broken`; không phụ thuộc toggle hiển thị | §9.1 |
| P6 | Pivot strict hai phía, xác nhận tại `c + len`, giá trị tại `[len]` | §9.2 |
| P7 | Session theo offset phút cố định; PDH/PDL/PWH/PWL theo ngày/tuần **server** | §9.3 |
| P8 | Event ring 50 giữ nguyên thứ tự push Pine; không dedupe trong ring | §9.2 |
| P9 | Risk/TP: giữ nguyên công thức Pine và **default `rr1 = 1.0 < rrMin = 1.5`** | §10.4 |
| P10 | Không port alert, webhook, dashboard, trendline, nến tô màu | — |
| P11 | `EMPTY_VALUE` cho `na`; enum số cho quality/bucket/session/close/block/event | §4 |
| P12 | Không port `show*`, màu, `zoneLen`, `dashSize`, label/box/line | §3 |
| P13 | Không "sửa" quirk Pine (session `-`, `math.max(na,x)`, TP2 nhảy stage, timeout exit = TP1) | §16 |

### 3. Input contract (90)

Bỏ 34 input hiển thị/chết: `confirmOnly`, `payloadMode`, `ms_bosOn/chochOn/mssOn`,
`liq_sweepOn` (chỉ label), `liq_tlOn/tlTol/tlMaxDev` (trendline không port), `sr_showOn`,
`fvg_showOn`, `ob_showOn`, `vol_showMA`, `vol_purWin` (chết), `vol_sess`/`vol_tz` (thay bằng
3 input phút), `sessTz` (thay bằng offset), `showViz`, `cBull/cBear`,
`showSig/showHit/showZone/zoneLen/showEma/showPd/showPw/showSess/showPriceZones/showTl/showVwap/showVol/showDash/dashSize`.

#### 3.1 Nhóm thời gian (MQL5-only, 6)

| # | Input | Kiểu | Default | Ghi chú |
|---:|---|---|---:|---|
| 1 | `InpSrvOffsetMin` | int | 180 | Offset server → UTC (phút, dương = đông). Exness thường +120/+180 |
| 2 | `InpMktOffsetMin` | int | −300 | Offset UTC → giờ thị trường (NY = −300, DST = −240) |
| 3 | `InpVolSessOffsetMin` | int | 420 | Offset UTC → múi giờ phiên volume (HCM = +420) |
| 4 | `InpVolSessStartMin` | int | 480 | 08:00 theo múi giờ phiên volume (thay `vol_sess`) |
| 5 | `InpVolSessEndMin` | int | 960 | 16:00 |
| 6 | `InpMaxBars` | int | 0 | 0 = toàn bộ; > 0 giới hạn replay để debug |

Giờ thị trường = `serverTime − InpSrvOffsetMin·60 + InpMktOffsetMin·60`.

Giờ phiên volume = `serverTime − InpSrvOffsetMin·60 + InpVolSessOffsetMin·60`.

Ngày/tuần server dùng trực tiếp `time[j]` (không cộng offset). Người dùng chỉnh offset khi DST
đổi (D2).

#### 3.2 Nhóm logic (84)

| # | Input | Kiểu | Default | Clamp |
|---:|---|---|---:|---|
| 7 | `InpSwingLen` | int | 5 | 2..20 |
| 8 | `InpRetestOn` | bool | true | — |
| 9 | `InpRetestBars` | int | 10 | 1..100 |
| 10 | `InpRetestTolAtr` | double | 0.5 | ≥ 0 |
| 11 | `InpFailOn` | bool | true | — |
| 12 | `InpFailBars` | int | 5 | 1..50 |
| 13 | `InpContOn` | bool | true | — |
| 14 | `InpPullOn` | bool | true | — |
| 15 | `InpEqTolAtr` | double | 0.05 | ≥ 0 |
| 16 | `InpPdOn` | bool | true | — |
| 17 | `InpPwOn` | bool | false | — |
| 18 | `InpSessOn` | bool | true | — |
| 19 | `InpSrLeft` | int | 10 | 2..50 |
| 20 | `InpSrRight` | int | 10 | 2..50 |
| 21 | `InpSrWidthAtr` | double | 0.5 | ≥ 0.05 |
| 22 | `InpSrMax` | int | 8 | 1..30 |
| 23 | `InpFvgMinAtr` | double | 0.3 | ≥ 0.05 |
| 24 | `InpFvgMax` | int | 20 | 1..50 |
| 25 | `InpFvgLife` | int | 100 | 10..500 |
| 26 | `InpObMax` | int | 20 | 1..50 |
| 27 | `InpPinRatio` | double | 2.0 | ≥ 1.0 |
| 28 | `InpEngulfOn` | bool | true | — |
| 29 | `InpPinOn` | bool | true | — |
| 30 | `InpDispOn` | bool | true | — |
| 31 | `InpDispAtr` | double | 1.5 | ≥ 0.5 |
| 32 | `InpRejOn` | bool | true | — |
| 33 | `InpEmaFast` | int | 20 | 2..500 |
| 34 | `InpEmaMid` | int | 50 | 5..500 |
| 35 | `InpEmaSlow` | int | 200 | 10..500 |
| 36 | `InpAtrLen` | int | 14 | 1..200 |
| 37 | `InpRsiLen` | int | 14 | 2..200 |
| 38 | `InpRsiOb` | double | 70 | 50..99 |
| 39 | `InpRsiOs` | double | 30 | 1..50 |
| 40 | `InpMacdFast` | int | 12 | 2..200 |
| 41 | `InpMacdSlow` | int | 26 | 5..200 |
| 42 | `InpMacdSignal` | int | 9 | 1..200 |
| 43 | `InpDmiLen` | int | 14 | 2..200 |
| 44 | `InpDmiSmooth` | int | 14 | 2..200 |
| 45 | `InpAdxMin` | double | 20 | 0..100 |
| 46 | `InpBbLen` | int | 20 | 2..200 |
| 47 | `InpBbMult` | double | 2.0 | ≥ 0.5 |
| 48 | `InpRvLen` | int | 20 | 2..200 |
| 49 | `InpRvMin` | double | 1.2 | ≥ 0.5 |
| 50 | `InpObvLen` | int | 20 | 2..200 |
| 51 | `InpVolMaLen` | int | 20 | 5..100 |
| 52 | `InpVolSpikeR` | double | 2.2 | ≥ 1.5 |
| 53 | `InpVolRVH` | double | 1.8 | ≥ 1.0 |
| 54 | `InpVolRH` | double | 1.2 | ≥ 0.8 |
| 55 | `InpVolRN` | double | 0.8 | ≥ 0.4 |
| 56 | `InpVolRL` | double | 0.4 | ≥ 0.1 |
| 57 | `InpVolMin` | double | 0.0 | ≥ 0; 0 = tắt |
| 58 | `InpVolSessOn` | bool | false | — |
| 59 | `InpCtxTf` | enum `ENUM_TIMEFRAMES` | `PERIOD_D1` | chỉ H4/D1/W1/MN1 |
| 60 | `InpCtxLen` | int | 200 | 10..500 |
| 61 | `InpSetupTf` | enum `ENUM_TIMEFRAMES` | `PERIOD_H1` | chỉ M15/H1 |
| 62 | `InpSetupLen` | int | 50 | 5..500 |
| 63 | `InpHtfFilter` | bool | true | — |
| 64 | `InpHtfVetoOn` | bool | true | — |
| 65 | `InpWTrend` | double | 15 | ≥ 0 |
| 66 | `InpWStruct` | double | 15 | ≥ 0 |
| 67 | `InpWLiq` | double | 12 | ≥ 0 |
| 68 | `InpWLoc` | double | 8 | ≥ 0 |
| 69 | `InpWSr` | double | 10 | ≥ 0 |
| 70 | `InpWCandle` | double | 10 | ≥ 0 |
| 71 | `InpWVol` | double | 8 | ≥ 0 |
| 72 | `InpWAtr` | double | 7 | ≥ 0 |
| 73 | `InpWMom` | double | 7 | ≥ 0 |
| 74 | `InpWSess` | double | 4 | ≥ 0 |
| 75 | `InpWMtf` | double | 4 | ≥ 0 |
| 76 | `InpScrNoTrade` | int | 49 | 0..99 |
| 77 | `InpScrWeak` | int | 64 | 1..99 |
| 78 | `InpScrSetup` | int | 74 | 1..99 |
| 79 | `InpScrStrong` | int | 84 | 1..99 |
| 80 | `InpSlAtrMul` | double | 1.5 | ≥ 0.1 |
| 81 | `InpSlSwing` | int | 10 | 2..100 |
| 82 | `InpSlPadAtr` | double | 0.2 | ≥ 0 |
| 83 | `InpSlMinAtr` | double | 0.5 | ≥ 0.1 |
| 84 | `InpSlMaxAtr` | double | 3.0 | ≥ 0.5 |
| 85 | `InpRr1` | double | 1.0 | ≥ 0.1 |
| 86 | `InpRr2` | double | 2.0 | ≥ 0.1 |
| 87 | `InpRr3` | double | 3.0 | ≥ 0.1 |
| 88 | `InpRrMin` | double | 1.5 | ≥ 0 |
| 89 | `InpMaxDay` | int | 3 | ≥ 1 |
| 90 | `InpCoolBars` | int | 10 | ≥ 0 |

Bảng trên đánh số 1..90 gồm cả 6 input thời gian ở §3.1 (7..90 là 84 input logic).

### 4. Enum

```cpp
#define X2_CONTRACT_VERSION "1.0.0"
#define X2_PLOT_BUFFERS      13
#define X2_CONTRACT_BUFFERS 140
#define X2_TOTAL_BUFFERS    153
#define X2_CONTRACT_FIRST    13
#define X2_MAX_SR            30
#define X2_MAX_FVG           50
#define X2_MAX_OB            50
#define X2_MAX_EVT           50
#define X2_OBV_MAX          202   // InpObvLen tối đa 200 + 2

enum ENUM_X2_QUALITY { X2_Q_NOTRADE=0, X2_Q_WEAK=1, X2_Q_SETUP=2,
                       X2_Q_STRONG=3, X2_Q_APLUS=4 };
enum ENUM_X2_BUCKET  { X2_BUCKET_VERYLOW=0, X2_BUCKET_LOW=1, X2_BUCKET_NORMAL=2,
                       X2_BUCKET_HIGH=3, X2_BUCKET_VERYHIGH=4, X2_BUCKET_TIM=5 };
enum ENUM_X2_SESSION { X2_SESS_NONE=0, X2_SESS_ASIA=1, X2_SESS_LONDON=2,
                       X2_SESS_NY=3, X2_SESS_LONDON_NY=4 };
enum ENUM_X2_CLOSE   { X2_CLOSE_NONE=0, X2_CLOSE_SL=1, X2_CLOSE_TP3=2,
                       X2_CLOSE_TIMEOUT=3 };
enum ENUM_X2_BLOCK   { X2_BLOCK_NONE=0, X2_BLOCK_PLAN_INVALID=1, X2_BLOCK_MTF_FILTER=2,
                       X2_BLOCK_HTF_VETO=3, X2_BLOCK_COOLDOWN=4, X2_BLOCK_DAY_LIMIT=5,
                       X2_BLOCK_SCORE=6, X2_BLOCK_DIR=7 };
enum ENUM_X2_EVENT   { X2_EVT_NONE=0, X2_EVT_BOS=1, X2_EVT_CHOCH=2, X2_EVT_MSS=3,
                       X2_EVT_RETEST=4, X2_EVT_FAILBRK=5, X2_EVT_CONT=6,
                       X2_EVT_PULL=7, X2_EVT_SWEEP=8 };
```

`X2_BLOCK_DIR` không bao giờ được báo vì `dir == 0` luôn làm `plan.valid = false`
(`dirOk`); block thực tế là `PLAN_INVALID` (Q7). Giữ enum để test parity công thức.

### 5. Signal ID

| ID | Ý nghĩa | Buffer | Trigger | Loại |
|---|---|---|---|---|
| `X2_LONG` | Signal long đã qua mọi gate (`sig` + `dir == 1`) | 35 | `sig && dir==1` | Edge |
| `X2_SHORT` | Signal short (`sig` + `dir == -1`) | 35 | `sig && dir==-1` | Edge |
| `X2_ENTRY` | Vị thế được adopt | 37 | `evEntry` | Edge |
| `X2_TP1` | Chạm TP1 (không đóng) | 38 | `evTp == 1` | Edge |
| `X2_TP2` | Chạm TP2 (không đóng) | 38 | `evTp == 2` | Edge |
| `X2_TP3` | Chạm TP3 (đóng, win) | 38 | `evTp == 3` | Edge |
| `X2_SL` | Chạm SL (đóng, loss) | 39 | `evSl` | Edge |
| `X2_CLOSE` | Đóng vị thế (mọi lý do) | 40 | `evClose` | Edge |

Chỉ có một buffer `SIG` (35) + `DIR` (14): EA suy ra LONG/SHORT bằng `SIG=1 && DIR=±1`.
`EV_TP` là số nguyên 0..3 trên một buffer duy nhất (khác PA tách 3 buffer).

### 6. Buffer

`#property indicator_buffers 153`, `#property indicator_plots 13`; plot `i` map buffer `i`
(0..12). Buffer 13..152 là `INDICATOR_CALCULATIONS`.

#### 6.1 Render buffers 0..12 (DATA, ngoài hợp đồng EA)

| # | Tên | Giá trị | Thiếu | Kiểu vẽ |
|---:|---|---|---|---|
| 0 | `PLOT_EMA_FAST` | `emaF` | `EMPTY_VALUE` | Line |
| 1 | `PLOT_EMA_MID` | `emaM` | `EMPTY_VALUE` | Line |
| 2 | `PLOT_EMA_SLOW` | `emaS` | `EMPTY_VALUE` | Line |
| 3 | `PLOT_VWAP` | `vwap` | `EMPTY_VALUE` | Line (linebr) |
| 4 | `PLOT_VOLUME` | `tick_volume` | 0 | Histogram |
| 5 | `PLOT_VOLUME_MA` | `volMA` | `EMPTY_VALUE` | Line |
| 6 | `PLOT_LONG_ENTRY` | `low` nến `evEntry && posDir==1` | `EMPTY_VALUE` | Arrow 233 |
| 7 | `PLOT_SHORT_ENTRY` | `high` nến `evEntry && posDir==-1` | `EMPTY_VALUE` | Arrow 234 |
| 8 | `PLOT_HIT_TP` | `high` nến `evTp > 0` | `EMPTY_VALUE` | Arrow 159 |
| 9 | `PLOT_HIT_SL` | `low` nến `evSl` | `EMPTY_VALUE` | Arrow 251 |
| 10 | `PLOT_ACTIVE_SL` | `posDir!=0 ? posSl : EMPTY` | `EMPTY_VALUE` | Line |
| 11 | `PLOT_ACTIVE_TP1` | `posDir!=0 ? posTp1 : EMPTY` | `EMPTY_VALUE` | Line |
| 12 | `PLOT_ACTIVE_TP2` | `posDir!=0 ? posTp2 : EMPTY` | `EMPTY_VALUE` | Line |

EMA/VWAP/volume luôn vẽ, không gate `showEma/showVwap/showVol` (D8). Không vẽ TP3
(contract buffer 33), không vẽ box/label/dashboard/trendline/FVG/OB (P12).

#### 6.2 Contract buffers 13..152 (140)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA dùng |
|---:|---|---|---|---|---|---|
| 13 | `SCORE100` | `round(50 + raw*50)` | 0..100 | — | Bar | audit |
| 14 | `DIR` | Hướng điểm | −1/0/1 | 0 | Bar | **có** |
| 15 | `QUALITY` | `ENUM_X2_QUALITY` | 0..4 | 0 | Bar | audit |
| 16 | `RAW_SCORE` | `clamp(wSum/wTotal,−1,1)` | −1..1 | 0 | Bar | audit |
| 17 | `G_TREND` | Nhóm trend | −1..1 | 0 | Bar | audit |
| 18 | `G_STRUCT` | Nhóm structure | −1..1 | 0 | Bar | audit |
| 19 | `G_LIQ` | Nhóm liquidity | −1..1 | 0 | Bar | audit |
| 20 | `G_LOC` | Nhóm location | −1..1 | 0 | Bar | audit |
| 21 | `G_SR` | Nhóm S/R+FVG+OB | −1..1 | 0 | Bar | audit |
| 22 | `G_CANDLE` | Nhóm candle | −1..1 | 0 | Bar | audit |
| 23 | `G_VOLUME` | Nhóm volume | −1..1 | 0 | Bar | audit |
| 24 | `G_VOL` | Nhóm volatility | −1..1 | 0 | Bar | audit |
| 25 | `G_MOM` | Nhóm momentum | −1..1 | 0 | Bar | audit |
| 26 | `G_SESS` | Nhóm session | −1..1 | 0 | Bar | audit |
| 27 | `G_MTF` | Nhóm MTF | −1..1 | 0 | Bar | audit |
| 28 | `PLAN_VALID` | `plan.valid` | 0/1 | 0 | Bar | **có** |
| 29 | `ENTRY` | `plan.entry` (= `close`) | giá | — | Bar | **có** |
| 30 | `SL` | `plan.sl` | giá | `EMPTY_VALUE` | Bar | **có** |
| 31 | `TP1` | `plan.tp1` | giá | `EMPTY_VALUE` | Bar | **có** |
| 32 | `TP2` | `plan.tp2` | giá | `EMPTY_VALUE` | Bar | **có** |
| 33 | `TP3` | `plan.tp3` | giá | `EMPTY_VALUE` | Bar | **có** |
| 34 | `RISK` | `plan.risk` | > 0 | `EMPTY_VALUE` | Bar | **có** |
| 35 | `SIG` | `x2_signal` | 0/1 | 0 | Edge | **có** |
| 36 | `BLOCK` | Lý do chặn đầu tiên | 0..7 | 0 | Bar | audit |
| 37 | `EV_ENTRY` | Adopt vị thế | 0/1 | 0 | Edge | **có** |
| 38 | `EV_TP` | TP đã chạm | 0..3 | 0 | Edge | **có** |
| 39 | `EV_SL` | SL chạm (đóng) | 0/1 | 0 | Edge | **có** |
| 40 | `EV_CLOSE` | Đóng vị thế | 0/1 | 0 | Edge | **có** |
| 41 | `CLOSE_REASON` | `ENUM_X2_CLOSE` | 0..3 | 0 | Bar | audit |
| 42 | `POS_DIR` | Hướng vị thế | −1/0/1 | 0 | State | **có** |
| 43 | `POS_ENTRY` | `posEntry` | giá | `EMPTY_VALUE` | State | **có** |
| 44 | `POS_SL` | `posSl` | giá | `EMPTY_VALUE` | State | **có** |
| 45 | `POS_TP1` | `posTp1` | giá | `EMPTY_VALUE` | State | **có** |
| 46 | `POS_TP2` | `posTp2` | giá | `EMPTY_VALUE` | State | **có** |
| 47 | `POS_TP3` | `posTp3` | giá | `EMPTY_VALUE` | State | **có** |
| 48 | `POS_RISK` | `posRisk` | giá | `EMPTY_VALUE` | State | audit |
| 49 | `POS_STAGE` | TP đã chạm | 0..3 | 0 | State | **có** |
| 50 | `POS_BARS` | Số nến giữ lệnh | ≥ 0 | 0 | State | audit |
| 51 | `POS_BAR` | `bar_index` lúc entry | ≥ 0 | −1 | State | audit |
| 52 | `DAY_COUNT` | Số lệnh trong ngày server | ≥ 0 | 0 | State | audit |
| 53 | `BARS_SINCE` | Cooldown counter | ≥ 0 | 0 | State | audit |
| 54 | `TRADES` | Tổng trade đã đóng | ≥ 0 | 0 | State | audit |
| 55 | `WINS` | Trade win (TP3) | ≥ 0 | 0 | State | audit |
| 56 | `LOSSES` | Trade loss (SL) | ≥ 0 | 0 | State | audit |
| 57 | `X_ENTRY` | Entry trade đóng gần nhất | giá | `EMPTY_VALUE` | State | audit |
| 58 | `X_SL` | SL trade đóng gần nhất | giá | `EMPTY_VALUE` | State | audit |
| 59 | `X_DIR` | Hướng trade đóng gần nhất | −1/0/1 | 0 | State | audit |
| 60 | `X_BAR` | Bar entry trade đóng gần nhất | ≥ 0 | −1 | State | audit |
| 61 | `X_EXIT` | Giá thoát (`exit` quirk Q9) | giá | `EMPTY_VALUE` | State | audit |
| 62 | `X_R` | R đạt được | giá trị | `EMPTY_VALUE` | State | audit |
| 63 | `TREND` | `trend` | −1/0/1 | 0 | Bar | audit |
| 64 | `BOS_UP` | BOS bull nến này | 0/1 | 0 | Bar | audit |
| 65 | `BOS_DOWN` | BOS bear | 0/1 | 0 | Bar | audit |
| 66 | `CHOCH_UP` | CHoCH bull | 0/1 | 0 | Bar | audit |
| 67 | `CHOCH_DOWN` | CHoCH bear | 0/1 | 0 | Bar | audit |
| 68 | `MSS_UP` | MSS bull | 0/1 | 0 | Bar | audit |
| 69 | `MSS_DOWN` | MSS bear | 0/1 | 0 | Bar | audit |
| 70 | `RETEST_UP` | Retest bull | 0/1 | 0 | Bar | audit |
| 71 | `RETEST_DOWN` | Retest bear | 0/1 | 0 | Bar | audit |
| 72 | `FAIL_UP` | Failed breakout bull | 0/1 | 0 | Bar | audit |
| 73 | `FAIL_DOWN` | Failed breakout bear | 0/1 | 0 | Bar | audit |
| 74 | `SWEEP_UP` | Liquidity sweep bull | 0/1 | 0 | Bar | audit |
| 75 | `SWEEP_DOWN` | Liquidity sweep bear | 0/1 | 0 | Bar | audit |
| 76 | `HH` | Higher high | 0/1 | 0 | Bar | audit |
| 77 | `HL` | Higher low | 0/1 | 0 | Bar | audit |
| 78 | `LH` | Lower high | 0/1 | 0 | Bar | audit |
| 79 | `LL` | Lower low | 0/1 | 0 | Bar | audit |
| 80 | `CONT_UP` | Continuation bull | 0/1 | 0 | Bar | audit |
| 81 | `CONT_DOWN` | Continuation bear | 0/1 | 0 | Bar | audit |
| 82 | `PULL_UP` | Pullback bull | 0/1 | 0 | Bar | audit |
| 83 | `PULL_DOWN` | Pullback bear | 0/1 | 0 | Bar | audit |
| 84 | `EQ_HI` | Equal high | 0/1 | 0 | Bar | audit |
| 85 | `EQ_LO` | Equal low | 0/1 | 0 | Bar | audit |
| 86 | `BRK_LEVEL` | Level bị phá gần nhất | giá | `EMPTY_VALUE` | State | audit |
| 87 | `BRK_DIR` | Hướng phá | −1/0/1 | 0 | State | audit |
| 88 | `CP_BULL` | Tổng điểm nến bull | 0..4 | 0 | Bar | audit |
| 89 | `CP_BEAR` | Tổng điểm nến bear | 0..4 | 0 | Bar | audit |
| 90 | `CANDLE_SCORE` | `cpScore` | −1..1 | 0 | Bar | audit |
| 91 | `PIN_BULL` | Pin bull | 0/1 | 0 | Bar | audit |
| 92 | `PIN_BEAR` | Pin bear | 0/1 | 0 | Bar | audit |
| 93 | `ENG_BULL` | Engulf bull | 0/1 | 0 | Bar | audit |
| 94 | `ENG_BEAR` | Engulf bear | 0/1 | 0 | Bar | audit |
| 95 | `DISP_BULL` | Displacement bull (không volume) | 0/1 | 0 | Bar | audit |
| 96 | `DISP_BEAR` | Displacement bear | 0/1 | 0 | Bar | audit |
| 97 | `DISP_BULL_V` | Displacement bull + volume spike | 0/1 | 0 | Bar | audit |
| 98 | `DISP_BEAR_V` | Displacement bear + volume spike | 0/1 | 0 | Bar | audit |
| 99 | `REJ_BULL` | Rejection bull | 0/1 | 0 | Bar | audit |
| 100 | `REJ_BEAR` | Rejection bear | 0/1 | 0 | Bar | audit |
| 101 | `ATR` | ATR (Wilder) | > 0 | `EMPTY_VALUE` | Bar | **có** |
| 102 | `ATR_PCT` | `atr/close*100` | > 0 | `EMPTY_VALUE` | Bar | audit |
| 103 | `ATR_MA` | `SMA(atr, 20)` (hard-coded 20) | > 0 | `EMPTY_VALUE` | Bar | audit |
| 104 | `ATR_REGIME` | 0/0.5/1 | 0..1 | 0.5 | Bar | audit |
| 105 | `RSI` | RSI | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 106 | `MACD_HIST` | MACD histogram | giá | `EMPTY_VALUE` | Bar | audit |
| 107 | `ADX` | ADX | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 108 | `DI_PLUS` | DI+ | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 109 | `DI_MINUS` | DI− | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 110 | `BB_WIDTH` | `(up−lo)/mid*100` | ≥ 0 | `EMPTY_VALUE` | Bar | audit |
| 111 | `BB_WIDTH_MA` | `SMA(bbWidth, bbLen)` | ≥ 0 | `EMPTY_VALUE` | Bar | audit |
| 112 | `BB_EXPAND` | `bbWidth > bbWidthMA` | 0/1 | 0 | Bar | audit |
| 113 | `VOL_RATIO` | `vol/volMA` | ≥ 0 | 0 | Bar | audit |
| 114 | `VOL_BUCKET` | `ENUM_X2_BUCKET` | 0..5 | 0 | Bar | audit |
| 115 | `IS_TIM` | Volume đột biến có hiệu lực | 0/1 | 0 | Bar | audit |
| 116 | `REL_VOL` | `vol/SMA(vol,rvLen)` | ≥ 0 | 0 | Bar | audit |
| 117 | `OBV_SLOPE` | `obv − obv[lag]` | giá trị | 0 | Bar | audit |
| 118 | `VWAP` | VWAP ngày server | giá | `EMPTY_VALUE` | Bar | audit |
| 119 | `PDH` | High ngày server trước | giá | `EMPTY_VALUE` | Bar | audit |
| 120 | `PDL` | Low ngày server trước | giá | `EMPTY_VALUE` | Bar | audit |
| 121 | `PWH` | High tuần server trước | giá | `EMPTY_VALUE` | Bar | audit |
| 122 | `PWL` | Low tuần server trước | giá | `EMPTY_VALUE` | Bar | audit |
| 123 | `DAY_RANGE` | Vị trí trong range ngày | −n..n | 0 | Bar | audit |
| 124 | `LOCATION_SCORE` | `(vwapScore+clamp(dayRange))/2` | −1..1 | 0 | Bar | audit |
| 125 | `VOLUME_SCORE` | Trung bình 3 score volume | −1..1 | 0 | Bar | audit |
| 126 | `MOM_SCORE` | Trung bình RSI/MACD/DMI | −1..1 | 0 | Bar | audit |
| 127 | `TREND_SCORE` | `x2_trendScore` | −1..1 | 0 | Bar | audit |
| 128 | `SESS_SCORE` | `x2_sessScore` | 0..1 | 0 | Bar | audit |
| 129 | `SESS_NAME` | `ENUM_X2_SESSION` | 0..4 | 0 | Bar | audit |
| 130 | `SESS_HI` | Session high | giá | `EMPTY_VALUE` | State | audit |
| 131 | `SESS_LO` | Session low | giá | `EMPTY_VALUE` | State | audit |
| 132 | `MTF_CTX_DIR` | Bias context TF | −1/0/1 | 0 | Bar | audit |
| 133 | `MTF_SETUP_DIR` | Bias setup TF | −1/0/1 | 0 | Bar | audit |
| 134 | `OK_SETUP` | `x2_okSetup` | 0/1 | 0 | Bar | audit |
| 135 | `HTF_VETO` | `x2_htfVeto` (giá trị thực) | 0/1 | 0 | Bar | audit |
| 136 | `SWING_LO` | `lowest(low, slSwing)` | giá | `EMPTY_VALUE` | Bar | audit |
| 137 | `SWING_HI` | `highest(high, slSwing)` | giá | `EMPTY_VALUE` | Bar | audit |
| 138 | `LAST_HIGH` | Pivot high gần nhất (state) | giá | `EMPTY_VALUE` | State | audit |
| 139 | `LAST_LOW` | Pivot low gần nhất (state) | giá | `EMPTY_VALUE` | State | audit |
| 140 | `NEAR_SUPPORT` | `f_nearSupport(zones, atr)` | 0/1 | 0 | Bar | audit |
| 141 | `NEAR_RESISTANCE` | `f_nearResistance(zones, atr)` | 0/1 | 0 | Bar | audit |
| 142 | `NEAR_FVG_BULL` | Gần FVG/OB bull | 0/1 | 0 | Bar | audit |
| 143 | `NEAR_FVG_BEAR` | Gần FVG/OB bear | 0/1 | 0 | Bar | audit |
| 144 | `SR_COUNT` | Số S/R zone | 0..30 | 0 | State | audit |
| 145 | `FVG_COUNT` | Số FVG | 0..50 | 0 | State | audit |
| 146 | `OB_COUNT` | Số OB | 0..50 | 0 | State | audit |
| 147 | `EVT_KIND` | Event cuối ring | 0..8 | 0 | State | **có** |
| 148 | `EVT_DIR` | Hướng event cuối | −1/0/1 | 0 | State | **có** |
| 149 | `EVT_SRC_BAR` | `srcBar` event cuối | ≥ 0 | −1 | State | audit |
| 150 | `EVT_SRC_TIME` | `srcTime` event cuối | datetime | 0 | State | audit |
| 151 | `EVT_LEVEL` | `level` event cuối | giá | `EMPTY_VALUE` | State | **có** |
| 152 | `EVT_COUNT` | Kích thước ring | 0..50 | 0 | State | audit |

Quy ước:

- Buffer edge (`SIG`, `EV_*`) = `0.0` trên nến không có sự kiện; **không** dùng `EMPTY_VALUE`.
  Riêng `EV_TP` là 0..3, `EVT_LEVEL` có thể `EMPTY_VALUE` (Q5).
- `ENTRY/SL/TP1/TP2/TP3/RISK` là **plan của chính nến đó**, không phải state vị thế.
  Pine luôn gọi `f_buildX2Plan(x2_dir)` kể cả khi `dir = 0` hoặc plan invalid:
  - `ENTRY` luôn = `close` (kể cả khi không có tín hiệu) → EA **phải** gate `PLAN_VALID`.
  - Khi ATR hợp lệ và `dir = 0`: `SL = ENTRY`, `TP1..TP3 = ENTRY`, `RISK = dist > 0`.
  - Khi ATR `na` (warm-up): `SL/TP1..3/RISK = EMPTY_VALUE`, `PLAN_VALID = 0`.
- `POS_*` là state vị thế đang mở; `EMPTY_VALUE`/0 khi `POS_DIR == 0`, **trừ** nến đóng lệnh:
  trong nến đó `POS_DIR` vẫn giữ hướng cũ và levels còn giá trị (deferred reset chạy nến sau).
- `EVT_*` là phần tử **cuối** của ring tại cuối nến; ring giữ tối đa 50 event (P8), không
  dedupe — event lặp (`RETEST` mỗi nến trong cửa sổ) vẫn vào ring.
- `X_*` chỉ đổi khi có trade đóng; giữ giá trị trade cuối qua các nến sau.
- `VOL_RATIO/REL_VOL` = 0 khi mẫu số `na`/≤ 0 (khớp Pine `0.0`).
- `ATR_REGIME` = 0.5 khi `atrMA` na (Pine ternary default).
- `SESS_HI/SESS_LO` giữ giá trị phiên trước trong khoảng `-` (15:00–17:00) và chỉ reset khi
  tên phiên đổi **và** tên mới khác `-` (Q4).
- Tại nến đang chạy (`j == rates_total-1`) toàn bộ buffer = 0/`EMPTY_VALUE`; EA đọc `shift=1`.

### 7. Bar policy và state

Mỗi lần `rates_total` thay đổi (nến mới), indicator **reset state và replay từ bar `fromBar`**
tới `rates_total-2`; trong cùng một nến trả `rates_total` ngay. Hệ quả:

- Mọi buffer của nến đã đóng là hàm thuần của dữ liệu đã đóng → không RP2.
- Không có state ẩn sống qua lần gọi; reload indicator cho cùng kết quả.
- Chi phí O(n) mỗi nến; zone/FVG/OB/event cap nhỏ.

`fromBar = InpMaxBars > 0 ? max(0, lastClosed − InpMaxBars + 1) : 0` (P1). Khi `fromBar > 0`,
state khởi tạo rỗng tại `fromBar` → **không** tái lập đúng lịch sử; chỉ dùng để debug.

#### 7.1 `X2EngineState`

```cpp
struct X2SrZone { double top, bot; int side, touches; bool broken; };
struct X2Fvg    { double top, bot; int srcBar, dir; bool dead; };
struct X2Ob     { double top, bot; int srcBar, dir; bool dead; };
struct X2Event  { int kind, dir, srcBar; datetime srcTime; bool confirmed; double level; };

struct X2EngineState
{
   // structure
   double lastHigh, prevHigh, lastLow, prevLow, brkLevel;
   int    lastHighBar, lastLowBar, trend, brkDir, brkBar;
   bool   hasLastHigh, hasLastLow, hasPrevHigh, hasPrevLow, hasBrk;
   // edge flags nến hiện tại
   bool   bosUp, bosDown, chochUp, chochDown, mssUp, mssDown;
   bool   retestBull, retestBear, failBull, failBear;
   bool   contBull, contBear, pullBull, pullBear;
   bool   sweepBull, sweepBear, isHH, isHL, isLH, isLL, eqHi, eqLo;
   // session
   double sessHi, sessLo; int sessPrev; bool hasSessHi, hasSessLo;
   // zones
   X2SrZone sr[X2_MAX_SR]; int srCount;
   X2Fvg    fvg[X2_MAX_FVG]; int fvgCount;
   X2Ob     ob[X2_MAX_OB]; int obCount;
   // OBV window
   double obv; double obvHist[X2_OBV_MAX]; int obvCount, obvBar;
   // day / week
   long   dayStamp, weekStamp;
   double curDayHi, curDayLo, curWeekHi, curWeekLo;
   double pdh, pdl, pwh, pwl; bool hasPd, hasPw;
   // VWAP
   long   vwapStamp; double vwapPV, vwapVol; bool hasVwap;
   // MACD prev
   double prevMacdHist; bool hasPrevMacd;
   // gating
   int dayCount, barsSince;
   // position
   int posDir, posStage, posBar, posBars;
   double posEntry, posSl, posTp1, posTp2, posTp3, posRisk;
   bool needReset;
   // trade đóng gần nhất
   double xEntry, xSl, xExit, xR; int xDir, xBar;
   // stats
   int trades, wins, losses;
   // event ring
   X2Event evt[X2_MAX_EVT]; int evtCount;
   // out của nến hiện tại
   bool evEntry, evSl, evClose; int evTp, closeReason;
};
```

`X2StateInit`: `trend = 0`, `brkDir = 0`, `barsSince = 999999`, `dayCount = 0`,
`dayStamp/weekStamp = -1`, `sessPrev = X2_SESS_NONE`, `vwapStamp = -1`, `posDir = 0`,
`posBars = 0`, `posStage = 0`, `posBar = -1`, `needReset = false`, `evtCount = 0`,
`has* = false`, `prevMacdHist = EMPTY_VALUE`, counters = 0, `xBar = -1`, `xDir = 0`.

#### 7.2 Series precompute (pass 1)

| Chuỗi | Công thức | Warm-up |
|---|---|---|
| `tr` | `max(h-l, \|h-c1\|, \|l-c1\|)`, bar 0 = `h-l` | bar 0 |
| `atr` | RMA(tr, `atrLen`) | `atrLen` |
| `atrMA` | SMA(atr, **20**) — hard-coded theo Pine | `atrLen+19` |
| `volMA` | RMA(vol, `volMaLen`) | `volMaLen` |
| `volSma` | SMA(vol, `rvLen`) | `rvLen` |
| `emaF/M/S` | EMA(close, len), seed SMA(len) | len |
| `swingLo/Hi` | rolling min(low)/max(high), `slSwing` | `slSwing` |
| `pivH/pivL` | strict `swingLen` hai phía; xác nhận tại `c`, giá trị `high[c-len]` | `2·swingLen+1` |
| `srPivH/srPivL` | strict `srLeft/srRight` | `srLeft+srRight+1` |
| `rsi` | Wilder RSI(`rsiLen`) | `rsiLen+1` |
| `macdHist` | EMA(f)−EMA(s), signal EMA, hist = macd−signal | `macdSlow+macdSignal-1` |
| `diPlus/diMinus/adx` | Wilder DMI(`dmiLen`), ADX RMA(`dmiSmooth`) | `dmiLen+dmiSmooth-1` |
| `bbMid/bbUp/bbLo` | SMA ± mult·**population** stdev | `bbLen` |
| `bbWidth` | `(up−lo)/mid*100` | `bbLen` |
| `bbWidthMA` | SMA(bbWidth, `bbLen`) | `2·bbLen-1` |
| `vwap` | Σ(close·vol)/Σvol, reset đầu ngày server | 1 bar có vol |
| `pdh/pdl` | high/low cả ngày server trước | 1 ngày đủ |
| `pwh/pwl` | high/low tuần server trước (thứ Hai) | 1 tuần đủ |
| `htfCtxEma/htfSetupEma` | EMA trên close HTF đã đóng | `ctxLen/setupLen` |
| `sessName` | `X2SessionName(minute)` theo offset thị trường | 1 bar |
| `volSessOk` | `!volSessOn \|\| InWindow(minuteVol, start, end)` | 1 bar |
| `dayStamp/weekStamp` | ngày/tuần server (tuần bắt đầu thứ Hai) | 1 bar |

`X2Bar` mang thêm OHLCV + `prevOpen/prevClose/prevHigh/prevLow` (EMPTY ở bar 0) +
`high2/low2` (EMPTY khi < 2 nến) để engine tính engulf/OB/FVG mà không cần offset series.

### 8. Engine pipeline (mỗi nến đóng, thứ tự bắt buộc)

```text
X2EngineStep(cfg, st, bar, barIndex, out):
  0. Reset edge flags nến hiện tại: bos*/choch*/mss*/retest*/fail*/cont*/pull*/
     sweep*/hh/hl/lh/ll/eq*, evEntry/evTp/evSl/evClose/closeReason.
  1. L1  volRatio, volBucket, isTim, relVol, obv += (close>prevClose?vol:...),
         obvSlope (window), body/range/wicks/bullBar/bearBar, dispBull/Bear, atrPct.
  2. L2  Pivot high (nếu pivH valid): BOS up / CHoCH up / prevHigh; lastHigh, lastHighBar.
         Pivot low (nếu pivL valid): BOS down / CHoCH down / prevLow; lastLow, lastLowBar.
         MSS = (bos||choch) & disp cùng phía.
         HH/HL/LH/LL từ pivH/pivL vs prev*, retest/fail/cont/pull.
         Push events theo thứ tự Pine: BOS → CHoCH → MSS → RETEST → FAILBRK →
         CONT → PULL.
  3. L3  PDH/PDL/PWH/PWL (bar), session HL update, eqThresh/eqHi/eqLo,
         sweepBull/Bear (PD → PW → session → equal), push SWEEP.
  4. L4  S/R add: pivot high (side −1) TRƯỚC, pivot low (side +1) SAU.
         FVG push bull/bear → shift nếu > max → đánh dead (life/close).
         OB push (disp + prev body) → shift nếu > max → đánh dead (close).
         nearFvgBull/Bear từ FVG + OB.
  5. L5  pin/engulf/dispV/rejection + cpBull/cpBear/cpScore.
  6. L6  rsiScore, macdScore (cross bằng hist vs prev), dmiScore, momScore,
         atrRegime, bbExpand, volScore, relVolScore, obvScore, vsaScore,
         volumeScore, vwapScore, dayRange, locationScore, trendScore.
  7. L7  ctxDir, setupDir, gMtfBias.
  8. L8  gTrend..gMtf, wTotal, wSum, rawScore, score100, dir, quality,
         okSetup, htfVeto, okMtf.
  9. L9  plan = X2BuildPlan(cfg, bar, dir); newDay → dayCount = 0;
         barsSince += 1; okCool/okDay/okScore/okDir/okFilter/signal; block.
 10. L10 deferred reset → manage position → open new → posBars++.
 11. out: gán toàn bộ trường ra nến (xem §6.2).
```

Thứ tự này khớp Pine: session HL cập nhật **trước** sweep; barsSince tăng **trước** gate;
dayCount reset **trước** gate nhưng **sau** plan; state machine chạy **sau** plan/gate.

`okBar` trong port luôn `true` vì engine chỉ chạy trên nến đóng (P3).

### 9. Chi tiết thuật toán

#### 9.1 S/R zones (P5)

- Thêm zone khi `ta.pivothigh(high, srLeft, srRight)` xác nhận: `px = high[srRight]`,
  `side = −1`; sau đó `ta.pivotlow`: `px = low[srRight]`, `side = +1` (đúng thứ tự Pine).
- `half = atr * srWidth * 0.5`; zone mới `{top = px+half, bot = px−half, side, touches=1, broken=false}`.
- **Merge**: nếu `|mid − px| < atr·srWidth` → `touches += 1`, **không** đổi top/bot/side (Q2).
- Xoá zone `broken` sau merge; `while size > srMax shift` (bỏ zone cũ nhất).
- `broken` chỉ được Pine set trong block `barstate.islast` (vẽ) → replay **không bao giờ** set
  (D5). `X2NearSupport/Resistance` vẫn kiểm `broken` (luôn false trong replay).
- `nearSupport`: tồn tại zone `side==1 && !broken` với
  `low >= bot − atr·0.3 && low <= top + atr·0.3`; resistance đối xứng với `high`.
  Caller truyền **ATR đầy đủ** (khác PA MTF truyền 0.35·ATR) → cửa sổ thực `±0.3·ATR`.

#### 9.2 Structure, event ring (P6, P8)

Pivot high xác nhận tại `c` (`pivH = high[c−swingLen]`, `newHBar = c−swingLen`):

```text
if hasLastHigh:
   if trend <= 0 and close > lastHigh:  BOS up;  trend=1; brkLevel=lastHigh; brkDir=1; brkBar=newHBar
   if trend <  0 and newH  > lastHigh:  CHoCH up; trend=1; brkLevel=lastHigh; brkDir=1; brkBar=newHBar
   prevHigh = lastHigh
lastHigh = newH; lastHighBar = newHBar
```

Pivot low đối xứng (`trend >= 0 && close < lastLow` → BOS down; `trend > 0 && newL < lastLow`
→ CHoCH down). Hai nhánh BOS và CHoCH có thể **cùng true** trong một nến (BOS đổi trend
trước, rồi điều kiện CHoCH `trend < 0` đã sai → thực tế CHoCH bị chặn khi BOS vừa đổi trend;
ghi rõ để test D2/D3).

- MSS: `(bosUp || chochUp) && dispBull` → `mssUp`; đối xứng bear.
- HH: `pivH valid && prevHigh valid && pivH > prevHigh`; LH `<`; HL/LL dùng `pivL` vs `prevLow`.
- Retest bull: `retestOn && brkDir==1 && hasBrk && barIndex−brkBar <= retestBars
  && low <= brkLevel + retestTol·ATR && close > brkLevel`; bear đối xứng.
- Fail bull: `failOn && brkDir==−1 && hasBrk && barIndex−brkBar <= failBars && close > brkLevel`.
- Cont bull: `contOn && trend==1 && isHH`; bear: `trend==−1 && isLL`.
- Pull bull: `pullOn && trend==1 && low <= emaM && close > emaM`; bear đối xứng.
- Event ring: push khi `evtCount < 50`, ngược lại shift rồi push (giữ 50 mới nhất).
  `srcBar`: BOS/CHoCH/MSS/CONT → `lastHighBar/lastLowBar`; RETEST/FAILBRK/PULL/SWEEP →
  `barIndex`. `srcTime` = `bar.time`; `confirmed` = true (port chỉ chạy nến đóng).
- Thứ tự push cố định: BOS → CHoCH → MSS → RETEST → FAILBRK → CONT → PULL → SWEEP.
- `level`: BOS/CHoCH/MSS/CONT → lastHigh/lastLow; RETEST/FAILBRK → brkLevel; PULL → emaM;
  SWEEP → `max(pdl, sessLo)` / `min(pdh, sessHi)` (Q5).

#### 9.3 Liquidity, session, PD/PW (P7)

- PDH/PDL = high/low **cả ngày server trước**; PWH/PWL = high/low **cả tuần server trước**
  (tuần bắt đầu thứ Hai, D3). Chưa đủ dữ liệu → EMPTY.
- Session name theo phút thị trường: Asia 1020..120 (wrap), London 120..600, NY 420..900;
  ưu tiên `London/NY` > `NY` > `London` > `Asia` > `-` (đúng `f_sessName`).
- Session score: overlap 1.0, NY 0.8, London 0.6, Asia 0.2, none 0.0.
- Session HL:
  ```text
  changed = (name != sessPrev)
  if changed && name != NONE:            sessHi = high; sessLo = low; hasSess = true
  else if name != NONE:                  sessHi = max(nz(sessHi,high), high)
                                         sessLo = min(nz(sessLo,low), low)
  if name != NONE:                       sessPrev = name
  ```
  Tên `-` **không** reset và **không** cập nhật `sessPrev` (Q4) → khi phiên lặp lại sau gap,
  `changed = false` → mức cũ tiếp tục mở rộng thay vì reset.
- Equal: `eqThresh = atr·eqTol`; `eqHi = pivH valid && prevHigh valid && |pivH−prevHigh| <= eqThresh`;
  `eqLo` đối xứng với `prevLow`.
- Sweep:
  ```text
  bull = (pdOn && low < pdl && close > pdl)
      or (pwOn && low < pwl && close > pwl)
      or (sessOn && hasSessLo && low < sessLo && close > sessLo)
      or (eqLo && pivL < prevLow && close > prevLow)
  bear = đối xứng (high, pdh/pwh/sessHi, eqHi && pivH > prevHigh && close < prevHigh)
  ```
  Nhánh equal dùng **giá pivot** (`pivL/pivH`), không dùng low/high hiện tại.
- Sweep event level (Q5): bull `hasPd ? max(pdl, hasSessLo ? sessLo : pdl) : EMPTY`;
  bear `hasPd ? min(pdh, hasSessHi ? sessHi : pdh) : EMPTY` (Pine `math.max(na,x) = na`).
- Session HL được cập nhật **trước** sweep và đã gồm high/low nến hiện tại → nhánh session
  chỉ có thể bật khi tên phiên `-` (dùng mức cũ của phiên trước) (Q3).

#### 9.4 MTF (P4)

- `ctxDir = close > ctxEma ? 1 : −1` nếu EMA hợp lệ, else 0 (Q6: bằng nhau → −1).
- `setupDir` tương tự; `gMtfBias = (ctxDir + setupDir)/2` (−1, −0.5, 0, 0.5, 1).
- Mapping: bar HTF `k` gần nhất có `close_time[k] <= chartOpenTime`; EMA trên close HTF đã
  đóng, seed SMA(`len`); chưa đủ `len` bar → EMPTY → dir 0.
- `okSetup = !htfFilter || setupDir==0 || setupDir==dir`.
- `htfVeto = htfVetoOn && ctxDir!=0 && dir!=0 && ctxDir != dir`.
- `okMtf = okSetup && !htfVeto`.

#### 9.5 FVG và OB

- FVG bull: `low > high[2] && (low − high[2]) >= fvgMinAtr·ATR` → push `{top=low, bot=high[2],
  srcBar=barIndex, dir=1}`. Bear: `high < low[2] && (low[2] − high) >= fvgMinAtr·ATR` →
  `{top=low[2], bot=high, dir=−1}`.
- Sau push: `if size > fvgMax shift` (tối đa 1 push/nến nên 1 shift đủ).
- Dead: `barIndex − srcBar > fvgLife`, hoặc bull `close < bot`, bear `close > top`.
- OB bull: `dispBull && prevClose < prevOpen`; bear: `dispBear && prevClose > prevOpen`.
  Vùng = body nến trước: `top = max(prevOpen, prevClose)`, `bot = min(...)`, `srcBar=barIndex−1`.
  `if size > obMax shift`. Dead: bull `close < bot`, bear `close > top`. **Không có** giới hạn tuổi.
- `nearFvgBull`: tồn tại FVG chưa dead với `low` trong `[bot−0.3ATR, top+0.3ATR]`, **hoặc**
  OB bull chưa dead tương tự; `nearFvgBear` dùng `high` với FVG bear/OB bear. Hai cờ độc lập.

#### 9.6 Candles

| Pattern | Công thức | Điểm |
|---|---|---:|
| Pin bull | `bullBar && loWick >= pinRatio·body` | +1 |
| Engulf bull | `bullBar && prevClose < prevOpen && close >= prevOpen && open <= prevClose && body >= prevBody` | +1 |
| Displacement | `dispBull && bullBar && vol >= spikeR·volMA` | +1.2 |
| Rejection bull | `hiWick >= range·0.55 && loWick <= range·0.15 && bullBar` | +0.8 |

- Bear đối xứng. `dispBull = body >= dispAtr·ATR && hiWick < body·0.3`
  (`dispBear`: `loWick < body·0.3`).
- Mỗi pattern có toggle `pinOn/engulfOn/dispOn/rejOn`; tắt → không cộng.
- `cpScore = cpBull > cpBear ? min(1, cpBull/3) : cpBear > cpBull ? −min(1, cpBear/3) : 0`.
- `cpBull` tối đa 4.0 (1 + 1 + 1.2 + 0.8) → clamp 1.0 **đạt được** (khác PA MTF).

#### 9.7 Indicators

- `rsiScore`: `< rsiOs → +1`, `> rsiOb → −1`, else 0 (na → 0).
- `macdScore`: `hist > 0 && prevHist <= 0` → +1; `hist < 0 && prevHist >= 0` → −1;
  else `hist > 0 → +0.5`, `hist < 0 → −0.5`, else 0 (`prev` na → không cross).
- `dmiScore`: `adx >= adxMin ? (di+ > di− ? +1 : −1) : 0` (na → 0).
- `momScore = (rsiScore + macdScore + dmiScore)/3`.
- `atrRegime`: `atr > atrMA·1.2 → 1`; `atr < atrMA·0.8 → 0`; else 0.5 (atrMA na → 0.5).
- `bbExpand = bbWidth > bbWidthMA` (na → false).
- `volScore = bbExpand ? (close > open ? 0.5 : −0.5) : 0` (close == open → −0.5).
- `relVolScore = relVol >= rvMin ? (close>open ? 1 : close<open ? −1 : 0) : 0`.
- `obvScore = slope > 0 ? 1 : slope < 0 ? −1 : 0`.
- `vsaScore = isTim ? (bullBar ? 1 : bearBar ? −1 : 0) : 0`.
- `volumeScore = (relVolScore + obvScore + vsaScore)/3`.
- `vwapScore = vwap valid ? (close>vwap ? 1 : close<vwap ? −1 : 0) : 0`.
- `dayRange = (hasPd && pdh > pdl) ? (close−pdl)/(pdh−pdl)·2 − 1 : 0`.
- `locationScore = (vwapScore + clamp(dayRange,−1,1))/2`.
- `trendScore = stackBull ? 1 : stackBear ? −1 : (close > emaF > emaM ? 0.5 : close < emaF < emaM ? −0.5 : 0)`.

### 10. Scoring, gate, plan

#### 10.1 11 nhóm

| Nhóm | Công thức |
|---|---|
| trend | `trendScore` |
| struct | `(bosUp‖chochUp‖mssUp) ? 1 : (bosDown‖chochDown‖mssDown) ? −1 : trend·0.5` |
| liq | `sweepBull ? 1 : sweepBear ? −1 : retestBull ? 0.7 : retestBear ? −0.7 : 0` |
| loc | `locationScore` |
| sr | `nearSupport ? 1 : nearResistance ? −1 : (nearFvgBull && !nearFvgBear) ? 1 : (nearFvgBear && !nearFvgBull) ? −1 : 0` |
| candle | `cpScore` |
| volume | `volumeScore` |
| volatility | `atrRegime·(close>=open?1:−1)·0.5 + volScore·0.5` |
| momentum | `momScore` |
| session | `sessScore·(close>=open?1:−1)` |
| mtf | `gMtfBias` |

`wTotal = Σ w`; `wSum = Σ w_i·g_i`; `raw = wTotal > 0 ? clamp(wSum/wTotal,−1,1) : 0`;
`score100 = round(50 + raw·50)`; `dir = raw>0?1 : raw<0?−1 : 0`.

Quality: `<= noTrade → NOTRADE(0)`, `<= weak → WEAK(1)`, `<= setup → SETUP(2)`,
`<= strong → STRONG(3)`, else `APLUS(4)`.

#### 10.2 Gate và BLOCK

```text
plan.valid = atrOk && dir != 0 && dist > 0 && sl đúng phía && (rrMin <= 0 || rr1 >= rrMin)
okCool  = barsSince >= coolBars
okDay   = dayCount < maxDay
okScore = score100 > noTrade
okDir   = dir != 0
okFilter = okMtf && okCool && okDay && okScore && okDir
signal  = plan.valid && okFilter
```

BLOCK (port-side, thứ tự ưu tiên cố định):

| Block | Điều kiện |
|---:|---|
| 0 NONE | `signal` |
| 1 PLAN_INVALID | `!plan.valid` |
| 2 MTF_FILTER | `!okSetup` |
| 3 HTF_VETO | `htfVeto` |
| 4 COOLDOWN | `!okCool` |
| 5 DAY_LIMIT | `!okDay` |
| 6 SCORE | `!okScore` |
| 7 DIR | `!okDir` (không đạt được — Q7) |

#### 10.3 Plan

```text
a      = ATR
entry  = close
pad    = a·slPadAtr
swing  = dir==1 ? nz(swingLo, low) : nz(swingHi, high)
sDist  = dir==1 ? (entry−swing)+pad : (swing−entry)+pad
aDist  = a·slAtrMul
base   = (aDist + sDist)·0.5
dist   = clamp(nz(base, aDist), a·slMinAtr, max(a·slMaxAtr, a·slMinAtr))
sl     = entry − dir·dist ; risk = dist
rr2m   = max(rr2, rr1) ; rr3m = max(rr3, rr2m)
tp_i   = entry + dir·rr_i·risk
```

ATR `na`/≤ 0 → `plan.valid = false`, `SL/TP/RISK = EMPTY_VALUE`. `ENTRY` luôn = `close`.

#### 10.4 Quirk rrMin mặc định (P9)

`rr1 = 1.0 < rrMin = 1.5` → `rrOk = false` → **không có signal nào với input mặc định**.
EA/backtest phải set `InpRr1 >= InpRrMin` hoặc `InpRrMin = 0`. Test vector K6/K7 phủ.

### 11. State machine

Thứ tự cố định mỗi nến:

1. **Deferred reset** (nếu `needReset`): xoá toàn bộ pos (`posDir=0`, `posBars=0`,
   `posStage=0`, levels EMPTY, `posBar=−1`, `needReset=false`).
2. **Quản lý vị thế mở** (`posDir != 0`):
   - `t1 = stage<1 ? tp1 : EMPTY`; `t2 = stage<2 ? tp2 : EMPTY`; `t3 = stage<3 ? tp3 : EMPTY`.
   - `hitSl` (long: `low <= posSl`; short: `high >= posSl`); `hitK` nếu `tK` hợp lệ và chạm.
   - `hitSl && (hit1||hit2||hit3)` → đóng, loss, `evSl`, `evClose`.
   - else `hitSl` → đóng, loss, `evSl`, `evClose` (hai nhánh trùng — Q8).
   - else `hit3` → `evTp=3`, stage 3, đóng, win, `evClose`.
   - else `hit2` → `evTp=2`, stage 2 (không đóng).
   - else `hit1` → `evTp=1`, stage 1 (không đóng).
   - Nếu chưa đóng và `posBars > 300` → đóng, timeout (không win/loss), `evClose`.
   - Khi đóng: `trades++`; ghi `xEntry/xSl/xDir/xBar`; `xExit = evSl ? posSl :
     evTp==3 ? posTp3 : evTp==2 ? posTp2 : posTp1` (**timeout dùng TP1** — Q9);
     `xR = (xExit − posEntry)·posDir / posRisk` nếu `posRisk > 0`; `needReset = true`.
3. **Mở lệnh mới** nếu `okBar && signal && posDir == 0`: gán plan, `evEntry`, `dayCount++`,
   `barsSince = 0`, `posBars = 0`, `posStage = 0`, `posBar = barIndex`.
4. `posBars++` nếu `posDir != 0 && !evEntry && !needReset`.

Hệ quả: nến vừa đóng lệnh **không** mở lệnh mới (Q10); nến đó buffer `POS_*` vẫn là vị thế cũ.

### 12. EA và CSV

- `iCustom(_Symbol, _Period, "PinePort\\TMXAUSignals2.mq5", <90 inputs>)`.
- Chờ `BarsCalculated(handle) >= Bars(_Symbol,_Period)`; đọc `shift = 1` cho mọi buffer.
- Gate bắt buộc:
  - `SIG=1` + `DIR≠0` + `PLAN_VALID=1` trước khi dùng tín hiệu.
  - `ENTRY/SL/TP1/TP2/TP3/RISK` chỉ dùng khi `PLAN_VALID=1`.
  - `POS_*` chỉ dùng khi `POS_DIR≠0`.
  - `EVT_KIND`/`EVT_LEVEL` chỉ dùng khi `EVT_COUNT>0`.
- Dedupe theo `(symbol, timeframe, bar_open_time, signal_id, evt_src_bar)`.
- Không suy diễn lại TP/SL từ giá; không `OrderSend`, `CTrade`, `AccountInfo*`, `WebRequest`,
  `Socket*`, `FileWrite*`.

CSV (khi EA hỗ trợ — hiện `NOT_IMPLEMENTED`):

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,signal_id,side,
entry,sl,tp1,tp2,tp3,risk,score100,dir,quality,block,atr,pos_dir,pos_stage,
plan_valid,evt_kind,evt_dir,evt_src_bar,input_hash
```

- `signal_id`: `X2_LONG`, `X2_SHORT`, `X2_ENTRY`, `X2_TP1`, `X2_TP2`, `X2_TP3`, `X2_SL`,
  `X2_CLOSE`.
- `side`: `BUY` cho `X2_LONG`, `SELL` cho `X2_SHORT`, `NONE` còn lại.
- `bar_open_time` = giờ mở nến server; `confirmed_at = bar_open_time + TF`;
  `detected_at` = tick đầu tiên EA đọc `shift=1`.
- `input_hash` = FNV-1a 32-bit trên `X2ConfigCanonical` + `X2_CONTRACT_VERSION`.

### 13. Hàm contract (header)

```cpp
// math / time
double X2Clamp(double v, double lo, double hi);
bool   X2IsEmpty(double v);
int    X2LocalMinute(datetime serverTime, int srvOffsetMin, int localOffsetMin);
bool   X2InWindow(int minute, int startMin, int endMin);
int    X2SessionName(int minute);
double X2SessionScore(int sessName);
bool   X2IsNewServerDay(datetime prev, datetime cur);
bool   X2IsNewServerWeek(datetime prev, datetime cur);
bool   X2IsClosedBar(int bar, int ratesTotal);

// series
double X2TrueRange(bool hasPrev, double h, double l, double prevClose);
void   X2BuildSma(const double &src[], int total, int len, double &out[]);
void   X2BuildEma(const double &src[], int total, int len, double &out[]);
void   X2BuildRma(const double &src[], int total, int len, double &out[]);
void   X2BuildAtr(const double &h[], const double &l[], const double &c[],
                  int total, int len, double &out[]);
void   X2BuildRsi(const double &c[], int total, int len, double &out[]);
void   X2BuildMacdHist(const double &c[], int total, int fast, int slow, int sig,
                       double &out[]);
void   X2BuildDmi(const double &h[], const double &l[], const double &c[], int total,
                  int len, int smooth, double &diP[], double &diM[], double &adx[]);
void   X2BuildBb(const double &c[], int total, int len, double mult,
                 double &mid[], double &up[], double &lo[]);
void   X2BuildVwap(const double &c[], const long &vol[], const datetime &t[],
                   int total, double &out[]);   // reset theo ngày server
double X2RollingMin(const double &src[], int total, int end, int len);
double X2RollingMax(const double &src[], int total, int end, int len);
int    X2MapHtfIndex(const datetime &htfCloseTime[], int count, datetime chartOpenTime);

// pivots
bool   X2PivotHighAt(const double &h[], int total, int bar, int left, int right, double &out);
bool   X2PivotLowAt(const double &l[], int total, int bar, int left, int right, double &out);

// volume / candle
int    X2VolBucket(double vol, double volMA, double rP, double rVH, double rH,
                   double rN, double rL);
double X2RelVolScore(double relVol, double rvMin, double close, double open);
double X2ObvScore(double slope);
double X2VsaScore(bool isTim, bool bull, bool bear);
double X2VolumeScore(double relVolScore, double obvScore, double vsaScore);
double X2AtrRegime(double atr, double atrMA);
double X2VolatilityScore(double atrRegime, bool bbExpand, double close, double open);

// indicators / groups
double X2RsiScore(double rsi, double os, double ob);
double X2MacdScore(double hist, bool hasPrev, double prevHist);
double X2DmiScore(double diP, double diM, double adx, double adxMin);
double X2MomScore(double rsiScore, double macdScore, double dmiScore);
double X2TrendScore(bool stackBull, bool stackBear, double close, double emaF, double emaM);
double X2DayRange(double close, bool hasPd, double pdh, double pdl);
double X2LocationScore(double vwapScore, double dayRange);
double X2GroupStruct(bool bosUp, bool chochUp, bool mssUp,
                     bool bosDown, bool chochDown, bool mssDown, int trend);
double X2GroupLiq(bool sweepBull, bool sweepBear, bool retestBull, bool retestBear);
double X2GroupSr(bool nearSup, bool nearRes, bool nearFvgBull, bool nearFvgBear);
double X2GroupSess(double sessScore, double close, double open);
double X2GroupVol(double atrRegime, double volScore, double close, double open);
double X2RawScore(double wSum, double wTotal);
int    X2Score100(double raw);
int    X2Quality(int score100, int noTrade, int weak, int setup, int strong);
bool   X2OkSetup(bool htfFilter, int setupDir, int dir);
bool   X2HtfVeto(bool htfVetoOn, int ctxDir, int dir);

// zones / events
void   X2ZoneAdd(X2EngineState &st, double px, int side, double atr,
                 double width, int maxZones);
bool   X2NearSupport(const X2EngineState &st, double low, double atrArg);
bool   X2NearResistance(const X2EngineState &st, double high, double atrArg);
void   X2PushEvent(X2EngineState &st, int kind, int dir, int srcBar,
                   datetime srcTime, double level);

// plan / engine
void   X2BuildPlan(const X2Config &cfg, const X2Bar &bar, int dir, X2Plan &plan);
void   X2StateInit(X2EngineState &st);
void   X2EngineStep(const X2Config &cfg, X2EngineState &st, const X2Bar &bar,
                    int barIndex, X2BarOut &out);

// config
uint   X2Fnv1a(const string text);
string X2ConfigCanonical(const X2Config &cfg);
uint   X2ConfigHash(const X2Config &cfg);
void   X2NormalizeConfig(X2Config &cfg);
```

`X2Bar` chứa: `time`, OHLCV, `prevOpen/prevClose/prevHigh/prevLow`, `high2/low2`,
`atr/atrMA/volMA/volSma`, `emaF/M/S`, `rsi/macdHist/diPlus/diMinus/adx`,
`bbMid/bbUp/bbLo/bbWidth/bbWidthMA`, `pivH/pivL` + valid, `srPivH/srPivL` + valid,
`swingLo/swingHi`, `htfCtxEma/htfSetupEma` + valid, `sessName`, `volSessOk`, `dayStamp`,
`vwap/pdh/pdl/pwh/pwl` + valid flags.

```cpp
struct X2Plan { bool valid; int dir; double entry, sl, tp1, tp2, tp3, risk, rr1; };
```

`X2ConfigCanonical` liệt kê **91 khóa** (version + 90 trường) theo đúng thứ tự §3 dạng
`key=value;` với số dùng `%.10g`; `X2ConfigHash` = FNV-1a 32-bit (offset basis `2166136261`,
prime `16777619`) trên `X2_CONTRACT_VERSION + "|" + canonical`.

### 14. Test vector (105)

Vector mô tả hành vi **kỳ vọng** cho contract tests Phase 4; chưa chạy. Giá trị số dùng để
khẳng định công thức, không phải kết quả runtime.

#### A. Math / time (6)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| A1 | `X2Clamp(1.5,0,1)`, `(−1,0,1)`, `(0.4,0,1)` | 1 / 0 / 0.4 |
| A2 | `X2InWindow(1140,1020,120)`; `(120,1020,120)`; `(119,1020,120)` | true / false / true |
| A3 | `X2InWindow(120,120,600)`; `(599,…)`; `(600,…)`; `(0,…)` | true / true / false / false |
| A4 | `X2InWindow(m,480,480)` mọi m | true (start==end = cả ngày) |
| A5 | `X2IsNewServerDay(Mon 23:59, Tue 00:00)`; `X2IsNewServerWeek(Sun 23:59, Mon 00:00)` | true / true; cùng ngày → false |
| A6 | `X2SessionName` tại 18:00 / 03:00 / 08:00 / 12:00 / 16:00 | ASIA(1) / LONDON(2) / LONDON_NY(4) / NY(3) / NONE(0); score 0.2/0.6/1.0/0.8/0.0 |

#### B. Volume / VSA / OBV (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| B1 | volMA 100, vol 220, ratio mặc định | bucket TIM(5), `isTim` true, `volRatio` 2.2 |
| B2 | vol 219 / 180 / 120 / 80 / 40 / 39 | VERYHIGH(4) / VERYHIGH(4) / HIGH(3) / NORMAL(2) / LOW(1) / VERYLOW(0) |
| B3 | volMA `na` | `volRatio` 0, bucket VERYLOW(0), `isTim` false |
| B4 | volMA 0, vol 0 | bucket **TIM(5)** (`0 >= 0`), `volRatio` 0, `isTim` false (Q1) |
| B5 | volMin 200, vol 195, volMA 50 | `isTimRaw` true nhưng `volEvtOk` false → `isTim` false |
| B6 | volSessOn true, window 480–960; phút 600 / 1000 | `isTim` true / false |
| B7 | relVol 1.19 và 1.20 với rvMin 1.2, close>open | score 0 / +1 |
| B8 | close 10,11,10,9; vol 10,10,20,30 (mỗi bar set `prevClose`) | OBV 0 → 10 → −10 → −40 |
| B9 | OBV len 1, close 10,11,10,11 vol 10 | slope 0 / 10 / −10 / 10 |
| B10 | OBV len 2, bar 0–1 | slope = obv (warm-up `nz(na)=0`: 0 / 10) |

#### C. Session (6)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| C1 | tên Asia→London, bar high 105 low 95 | sessHi 105, sessLo 95, sessPrev LONDON |
| C2 | tên London→`-`, bar high 110 low 90 | sessHi/Lo giữ nguyên, sessPrev LONDON |
| C3 | tiếp London, high 107, low 96 | sessHi 107, sessLo 95 |
| C4 | sau gap `-` trở lại London, high 100 low 95 (sessHi cũ 105) | **không** reset → sessHi 105 (Q4) |
| C5 | trong phiên, sessLo cập nhật = low 99 | sweep session `low < sessLo` false (Q3) |
| C6 | ngoài phiên `-`, sessLo cũ 190, low 189, close 191 | sweepBull nhánh session true; level = max(pdl, 190) |

#### D. Structure (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| D1 | trend 0, lastHigh 100, close 101, pivH | bosUp, trend 1, brkLevel 100, brkBar = newHBar |
| D2 | trend −1, lastHigh 100, close 100, newH 105 | chochUp, bosUp false |
| D3 | trend 0, lastHigh 100, close 99, newH 98 | bosUp/chochUp false; lastHigh 98 |
| D4 | trend 0, lastLow 90, close 89 | bosDown, trend −1 |
| D5 | trend 1, lastLow 90, close 91, newL 88 | chochDown, bosDown false |
| D6 | bosUp + dispBull / bosUp + !dispBull | mssUp true / false |
| D7 | prevHigh 100, pivH 101; prevLow 90, pivL 89 | isHH true, isLH false; isLL true |
| D8 | retestBars 10, diff 10 / 11; failBars 5, diff 5 / 6 | retestBull true / false; failBull true / false |

#### E. Event ring (5)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| E1 | push BOS bull level 100 srcBar 5 | ring 1; kind BOS(1), dir +1, level 100, srcBar 5, srcTime = bar.time |
| E2 | cùng nến BOS + MSS + PULL | phần tử cuối = PULL(7) |
| E3 | push 51 event | size 50; phần tử đầu = event thứ 2 |
| E4 | SWEEP bull, pdh/pdl 200/180, sessLo 190 | level 190; sessLo `na` → level 180 |
| E5 | RETEST bull | `srcBar = barIndex` (không phải brkBar); level = brkLevel |

#### F. Zones / FVG / OB (9)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| F1 | px 100, ATR 2, width 0.5 | top 100.5, bot 99.5, touches 1 |
| F2 | zone resistance mid 100; px 100.4, ATR 2, width 0.5 | merge, touches 2, side giữ −1 (Q2) |
| F3 | px 101 (`\|diff\|` = atr·width = 1) | không merge → 2 zone |
| F4 | srMax 2, thêm zone thứ 3 | size 2, zone cũ nhất bị bỏ |
| F5 | support 99.5–100.5, ATR 2: low 98.9 / 98.89 | nearSupport true / false |
| F6 | resistance 99.5–100.5, ATR 2: high 101.1 / 101.11 | nearResistance true / false |
| F7 | high[2] 100, low 101, ATR 2, minAtr 0.3; gap 0.5 | push {top 101, bot 100, dir 1}; gap 0.5 < 0.6 → không push |
| F8 | FVG bull, close < bot; FVG age > life | dead (cả hai điều kiện độc lập) |
| F9 | dispBull + prev body 99–100; close 98.9; low 99.5 | OB {top 100, bot 99, srcBar −1, dir 1}; dead khi close 98.9; nearFvgBull true khi low 99.5 |

#### G. Candles (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| G1 | bull, body 1, loWick 2.0 / 1.99 | bullPin true / false |
| G2 | bull engulf đủ điều kiện, body ≥ prevBody | bullEng true |
| G3 | dispBull + vol 220/volMA 100/spike 2.2; vol 219 | dispBullV true / false |
| G4 | hiWick 0.6·range, loWick 0.1·range / hiWick 0.5·range | bullRej true / false |
| G5 | pin 1 + engulf 1 + rejection 0.8 | cpBull 2.8, cpScore 0.933333 |
| G6 | disp toggle off | cpBull 1.8, cpScore 0.6 |
| G7 | cpBull 0, cpBear 1.0 | cpScore −0.333333 |
| G8 | cpBull 1.0, cpBear 1.0 | cpScore 0 |

#### H. Indicators (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| H1 | RSI 25 / 75 / 50 | +1 / −1 / 0 |
| H2 | hist 0.5 prev −0.2; hist 0.3 prev 0.1; hist −0.1 prev 0.05 | +1 / +0.5 / −1 |
| H3 | ADX 25 DI+>DI−; ADX 19; ADX 25 DI+<DI− | +1 / 0 / −1 |
| H4 | rsi +1, macd +0.5, dmi +1 | mom 0.833333 |
| H5 | ATR 13/MA 10; 12/10; 7/10; MA `na` | 1 / 0.5 / 0 / 0.5 |
| H6 | bbExpand, close<open; no expand | volScore −0.5 / 0 |
| H7 | 1,1,1 và 0,1,−1 | volumeScore 1 / 0 |
| H8 | dayRange close 120 / 110 / 100, PDH 120 PDL 100; PDH≤PDL | 1 / 0 / −1 / 0 |
| H9 | vwapScore 1, dayRange 0.4; dayRange 3 | location 0.7 / 1.0 |
| H10 | stackBull; close>F>M; close<F<M; other | 1 / 0.5 / −0.5 / 0 |

#### I. Scoring (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| I1 | mọi nhóm +1, weight mặc định | raw 1, score100 100, dir 1 |
| I2 | chỉ gTrend = 1 | raw 0.15, score100 58 |
| I3 | trend 1, không event, gStruct 0.5 | raw 0.075, score100 54 |
| I4 | sweepBull + retestBull; sweepBear + retestBull; chỉ retestBull | 1 / −1 / 0.7 |
| I5 | nearSupport + nearResistance; chỉ resistance; chỉ FVG bull; cả hai FVG | 1 / −1 / 1 / 0 |
| I6 | atrRegime 1, close≥open, volScore −0.5 | gVol 0.25 |
| I7 | sessScore 0.8, close<open | gSess −0.8 |
| I8 | score100 49/64/74/84/85; wTotal 0 | quality 0/1/2/3/4; raw 0, score 50, dir 0 |

#### J. MTF (5)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| J1 | chart open 12:00, H4 close 12:00 | chọn bar H4 08–12 (biên `<=`) |
| J2 | chart open 11:55 | chọn bar H4 04–08 |
| J3 | HTF bars < len+1 | EMA EMPTY → dir 0 |
| J4 | close == ctxEma | ctxDir −1 (không 0) (Q6) |
| J5 | htfFilter, setupDir +1, dir −1 | okSetup false |

#### K. Plan / gates (9)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| K1 | entry 100, ATR 2, swing 96, pad 0.4, atrMul 1.5 | dist 3.7, sl 96.3 |
| K2 | swing = entry 100 | sDist 0.4, base 1.7, dist 1.7 |
| K3 | swing 60, ATR 2, atrMul 1.5, maxAtr 3 | base 21.7 → dist 6 (clamp max) |
| K4 | ATR 2, atrMul 1.5, swing 99.9, pad 0, minAtr 0.5 | base 1.55; dist 1.55 (trong [1,6]) |
| K5 | dir 0 | plan.valid false |
| K6 | rr1 1.0, rrMin 1.5 | rrOk false, valid false (Q-default) |
| K7 | rr1 2.0, rrMin 1.5 | valid true (ATR/dir/sl hợp lệ) |
| K8 | entry 100, risk 2, rr 1/2/3; rr2 1.5 | TP 102/104/106; TP2 103 |
| K9 | barsSince 9/10 cool 10; dayCount 3/3; score100 49/50 | okCool false/true; okDay false; okScore false/true |

#### L. State (11)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| L1 | signal + flat | adopt: posDir, entry, evEntry, dayCount+1, barsSince 0, posBars 0, posStage 0 |
| L2 | long, high ≥ tp1, low > sl | evTp 1, stage 1, không đóng |
| L3 | stage 1, high ≥ tp2 | evTp 2, stage 2 |
| L4 | high ≥ tp3 | đóng, evTp 3 + evClose, wins+1, xExit tp3, xR 3 (entry 100, risk 2) |
| L5 | low ≤ sl | đóng, evSl + evClose, losses+1, xExit sl, xR −1 |
| L6 | cùng nến chạm TP1 và SL | loss, evTp 0, evSl true |
| L7 | stage 0, high ≥ tp2 (chưa từng TP1) | evTp 2, stage 2 (TP1 bị bỏ qua) |
| L8 | posBars 301, không chạm TP/SL | đóng timeout, xExit = tp1 (Q9), exit reason 3 |
| L9 | nến đóng lệnh có signal | không entry cùng nến; nến sau reset rồi mới entry (Q10) |
| L10 | signal khi đang mở | bỏ qua, không đổi pos/levels/counters |
| L11 | entry bar | posBars 0 trong nến entry; nến sau posBars 1 |

#### M. Config hash (3)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| M1 | canonical string | 91 khóa (version + 90 trường), thứ tự §3, ổn định |
| M2 | FNV-1a `"a"` / `"foobar"` | 0xE40C292C / 0xBF9CF968 |
| M3 | đổi 1 input / cấu hình trùng | hash đổi / hash trùng |

#### N. Bar policy / output (4)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| N1 | `j == rates_total-1` | mọi buffer 0/EMPTY, không chạy engine |
| N2 | warm-up ATR `na` | PLAN_VALID 0, ENTRY = close, SL/TP/RISK EMPTY, ATR_REGIME 0.5, MTF dir 0 |
| N3 | buffer ↔ plot | 13 plot map 0..12; contract 13..152 |
| N4 | replay 2 lần cùng dữ liệu | toàn bộ buffer giống nhau (deterministic) |

#### O. Normalize config (3)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| O1 | swingLen 1 / 25 | 2 / 20 |
| O2 | srMax 0 / 99 | 1 / 30 |
| O3 | scrWeak 0; volMaLen 1 | 1; 5 |

### 15. Validator và Gate 3

`scripts/validate_tmxau2.py` (static only, không compile, không chạy MT5, không tuyên bố parity)
kiểm tra:

| # | Check | Kỳ vọng |
|---:|---|---|
| V1 | Contract constants | `X2_PLOT_BUFFERS 13`, `X2_CONTRACT_BUFFERS 140`, `X2_TOTAL_BUFFERS 153` |
| V2 | `ENUM_X2_BUFFER` | 140 entry, giá trị 13..152 đúng một lần |
| V3 | Enum phụ | `ENUM_X2_QUALITY/BUCKET/SESSION/CLOSE/BLOCK/EVENT` đúng miền §4 |
| V4 | `X2_CONTRACT_VERSION` | `"1.0.0"` |
| V5 | Indicator | `indicator_buffers 153`, `indicator_plots 13`, include contract |
| V6 | Bind | 153 buffer, index 0..152 đúng một lần; 0..12 DATA, 13..152 CALCULATIONS |
| V7 | Closed bar | có `lastClosed = total - 2` và `j <= lastClosed` |
| V8 | Không confirm input | không khai báo input confirm |
| V9 | Input count | đúng 90 `input` |
| V10 | Test IDs | đủ A1..A6, B1..B10, C1..C6, D1..D8, E1..E5, F1..F9, G1..G8, H1..H10, I1..I8, J1..J5, K1..K9, L1..L11, M1..M3, N1..N4, O1..O3 |
| V11 | Marker | test script in `TEST\|RESULT\|ALL_PASS` |
| V12 | Docs | contract chứa `indicator_buffers 153`, `## 14. Test vector`, `NOT_IMPLEMENTED`, `BLOCKED` |
| V13 | Safety | không `OrderSend/CTrade/AccountInfo/WebRequest/Socket*/FileOpen/Alert/...` |
| V14 | No placeholder | không `TODO/FIXME/TBD/PLACEHOLDER` |

Gate 3:

| # | Tiêu chí | Trạng thái |
|---|---|---|
| C1 | Mọi buffer EA cần có index, miền, kiểu thiếu, loại | PASS |
| C2 | Bar policy và replay order khớp Phase 2 (P1/P5/P6) | PASS |
| C3 | Quirk nguồn ghi rõ, không "sửa" âm thầm | PASS (§16) |
| C4 | Test vector phủ helper + engine, có vector cho default-RR bug | PASS (105) |
| C5 | Không tuyên bố runtime/parity | PASS (`NOT_RUN` / `BLOCKED`) |
| C6 | Không sửa Pine nguồn | PASS |

**Kết luận:** contract đóng băng cho Phase 4. Runtime `NOT_RUN`; EA `NOT_IMPLEMENTED`;
parity `BLOCKED` (chưa có CSV Pine).

### 16. Hành vi nguồn phải giữ nguyên (Q1–Q10)

| ID | Quirk | Hệ quả port |
|---|---|---|
| Q1 | `f_vsaName` không guard `ma > 0` | `volMA == 0` → bucket **TIM** (dù `isTim` false); `volMA na` → VERYLOW |
| Q2 | Merge zone không kiểm tra `side` và không đổi top/bot | Resistance có thể bị hút vào support; thứ tự register quyết định |
| Q3 | Session HL cập nhật **trước** sweep và gồm high/low hiện tại | Nhánh sweep session không bật trong phiên; chỉ bật ngoài phiên (`-`) với mức cũ |
| Q4 | Tên `-` không reset và không cập nhật `sessPrev` | Phiên lặp lại sau gap **không** reset mức, tiếp tục mở rộng |
| Q5 | Sweep event level `math.max(pdl, nz(sessLo, pdl))` | `pdl` na → level **na** dù sessLo có giá trị; `EVT_LEVEL = EMPTY` |
| Q6 | `ctxDir/setupDir = close > ema ? 1 : −1` | `close == ema` → **−1**, không phải 0 |
| Q7 | `dir == 0` luôn làm `plan.valid = false` | BLOCK `DIR` không đạt được; báo `PLAN_INVALID` |
| Q8 | Hai nhánh `hitSl` trùng kết quả | SL ưu tiên hơn TP cùng nến; TP1+SL = loss |
| Q9 | Timeout đóng với `xExit = tp1` | `X_EXIT`/`X_R` theo TP1, không theo giá đóng |
| Q10 | Adoption chặn bởi `posDir == 0` + deferred reset | Không mở lệnh trên nến vừa đóng lệnh |

Ngoài ra:

- `barsSince` khởi tạo 999999 → nến đầu tiên luôn qua cooldown.
- `dayCount` reset đầu ngày server **trước** gate, tăng khi entry.
- Retest/fail dùng `brkLevel/brkBar` **không reset** theo nến → sự kiện lặp mỗi nến trong
  cửa sổ (ring nhận nhiều bản ghi; đúng Pine).
- `swingLo/Hi` (SL) dùng `slSwing`, tách khỏi `swingLen` (structure) và `srLeft/srRight` (zone).
- Chỉ số mặc định: `atrMA` dùng SMA 20 **hard-coded**, không có input.

### 17. Câu hỏi mở

1. Biên MTF `close_time == chart open` (P4) cần CSV xác nhận.
2. Pivot tie-breaking của `ta.pivothigh/low` trên plateau (bar có high bằng nhau) — cần CSV.
3. `ta.vwap` anchor phiên sàn vs reset ngày server (D6) — chênh lệch biên ngày cần đối chiếu.
4. Sweep nhánh equal-low dùng giá pivot chứ không dùng low hiện tại — cần CSV đếm tần suất.
5. Phiên H4/D không trùng biên giờ phiên (bar straddle) — port dùng phút mở nến, có thể lệch
   một nến biên; cần CSV trên M5/M15.
6. Symbol/timeframe chuẩn cho parity (XAUUSD M5 là ứng viên) — chưa chốt.
