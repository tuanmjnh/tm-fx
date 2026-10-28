# Price Action MTF — Spec, Repaint Audit và Buffer Contract

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `INDICATOR_SPEC_PriceActionMTF.md`, `REPAINT_AUDIT_PriceActionMTF.md`, `BUFFER_CONTRACT_PriceActionMTF.md`.

Nội dung:
1. Indicator Spec — Price Action MTF (Pine v6)
2. Repaint Audit — Price Action MTF (Pine v6)
3. Buffer Contract — Price Action MTF (Pine v6 → MQL5)

---
## Indicator Spec — Price Action MTF (Pine v6)

- **Phase:** 1 — Đặc tả thuật toán trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `PORTABLE_WITH_DIFFERENCES` (xem §10, §11)
- **Nguồn:** [`dist/Price Action MTF.pine`](../../../tm-trading/pine/dist/Price%20Action%20MTF.pine) (indicator, 1801
  dòng, 144 input) và [`dist/Price Action MTF Backtest.pine`](../../../tm-trading/pine/dist/Price%20Action%20MTF%20Backtest.pine)
  (strategy, 1826 dòng). Chỉ đọc, không sửa. Parts: `pine/parts-price-action-mtf/` (14 module).
- **Nguyên tắc:** SIMULATION_ONLY. Porth chỉ tín hiệu trên nến đã đóng; indicator không có API giao dịch,
  không đọc tài khoản, không file I/O, không alert/webhook.

### 1. Phạm vi

| Port | Không port |
|---|---|
| L0 config tín hiệu (nhóm toggle ảnh hưởng điểm/gate) | Dashboard table (L11) |
| L1 core: ATR, VSA volume, RelVol, OBV, EMA 20/50/200, pivot, session | Label/box/line trang trí (BOS/CHoCH/Sweep/TP/SL, zone boxes) |
| L2 market structure + pattern giá (DT/DB/HST/HSN) | Alert `alertcondition` + webhook JSON |
| L3 liquidity: PD/PW/Session HL, equal HL, sweep, trendline 2 điểm | `payloadMode`, màu, `show*`, `dashSize` |
| L4 zones: S/R, FVG, OB (chỉ phần ảnh hưởng điểm) | Nến VSA tô màu 6 bucket trên chart |
| L5 candle patterns + volume veto + engulfing streak | `pa_cfBars` (input chết, không dùng trong Pine) |
| L6 indicators: RSI/MACD/DMI-ADX/BB-ATR%/RelVol/OBV/VWAP | `pa_vol_purWin` + `pa_timCount` (chết, không dùng) |
| L7 MTF context/setup + veto | `zoneLen`, `pa_liq_tlTol/MaxDev` (chỉ vẽ) |
| L8 scoring 11 nhóm + confluence 0–3 + regime gate | |
| L9 risk plan (R / measured move) + gate | |
| L10 state machine + thống kê | |

### 2. Layer map (theo source)

| Layer | Nội dung | Dòng |
|---|---|---:|
| SHARED | `f_sessionOk`, `f_vsaColor/Name`, `f_clamp`, `f_fmtPx`, `f_isNewDay`, `f_ts/f_sym`, `f_sessAsia/London/Ny/Name`, `SrZone + f_addZone/f_near*` | 4–102 |
| L0 | 144 input | 147–372 |
| L1 | ATR/ATR%, volume RMA + VSA + TIM, RelVol, OBV + slope, EMA stack, candle metrics, pivot, swing, session | 374–446 |
| L2 | PaEvent, structure state, pivots → BOS/CHoCH/MSS, HH/HL, retest, failed breakout, pattern DT/DB/H&S, cont/pull | 447–836 |
| L3 | PDH/PDL, PWH/PWL, session HL, equal HL, sweep, trendline | 838–1022 |
| L4 | S/R zones, FVG, OB, near-zone flags | 1023–1141 |
| L5 | Pin/Engulf/Displacement/Rejection/IB/Doji/3S-3C + veto + streak + `cp_score` | 1142–1226 |
| L6 | RSI/MACD/DMI + ATR regime/BBW + RelVol/OBV/VSA + VWAP/day range + trend score | 1227–1275 |
| L7 | Context TF + Setup TF (request.security `[1]` + lookahead_on) | 1276–1291 |
| L8 | 11 nhóm trọng số, `score100`, `dir`, quality, MTF gate, regime gate, confluence 0–3 | 1293–1370 |
| L9 | `PaPlan`, gate cuối, `pa_signal` | 1372–1447 |
| L10 | Position lifecycle, thống kê, event flags | 1448–1568 |
| L11 | Plot/label/box/dashboard | 1569–1751 |
| L12 | alertcondition + webhook JSON | 1753–1793 |

### 3. L1 — Core

- `ATR = ta.atr(atrLen)`, `ATR% = ATR/close*100`.
- Volume: `vol = nz(volume)`; `volMA = ta.rma(vol, volMaLen)`;
  `volRatio = volMA>0 ? vol/volMA : 0`; `bucket = TIM/VeryHigh/High/Normal/Low/VeryLow`
  theo `spikeR/rVH/rH/rN/rL` (so sánh `>=`, thứ tự từ cao xuống).
- `isTim = volMA>0 && vol >= volMA*spikeR && volEvtOk`, với
  `volEvtOk = (volMin<=0 || vol>=volMin) && sessionOk(volSess)`.
- `relVol = vol/SMA(vol, rvLen)` (0 nếu SMA ≤ 0/na).
- `OBV[0]=0`, cộng/trừ volume theo `close` so `close[1]`; `obvSlope = obv - nz(obv[lag])` với
  `lag = obvLen` (nguồn: array window `obvLen+2`; khi chưa đủ lịch sử `nz(na)=0` →
  `slope = obv`, giữ nguyên hành vi warm-up này).
- `emaF/M/S = ta.ema(close, 20/50/200)`; stack bull/bear theo thứ tự.
- Candle metrics: `body=|close-open|`, `range=max(high-low,mintick)`, `hiWick=high-max(c,o)`,
  `loWick=min(c,o)-low`, `dispBull = body>=dispAtr*ATR && hiWick<body*0.3` (bear đối xứng).
- Pivot: `ta.pivothigh/low(high/low, swLen, swLen)` — strict hai phía, xác nhận tại `bar_index`,
  giá trị tại `high[swLen]`.
- `swingLo = ta.lowest(low, slSwing)`, `swingHi = ta.highest(high, slSwing)`.
- Session (giờ NY): Asia 17:00–02:00, London 02:00–10:00, NY 07:00–15:00;
  `sessScore = overlap?1.0 : ny?0.8 : london?0.6 : asia?0.2 : 0.0`.

### 4. L2 — Market structure

State: `lastHigh/prevHigh/lastHighBar`, `lastLow/prevLow/lastLowBar`, `trend` (1/-1/0),
`brkLevel/brkDir/brkBar`.

Khi pivot high xác nhận (`newH = high[swLen]`, `newHBar = bar_index-swLen`):

1. Nếu đã có `lastHigh`:
   - `trend<=0 && close>lastHigh` → **BOS up**, `trend=1`, `brk=lastHigh`, `brkDir=1`, `brkBar=newHBar`.
   - `trend<0 && newH>lastHigh` → **CHoCH up**, `trend=1`, cùng brk.
   - `prevHigh = lastHigh`.
2. `lastHigh = newH`, `lastHighBar = newHBar`.

Pivot low đối xứng (BOS/CHoCH down).

- **MSS**: `BOS up && dispBull` → MSS up; `CHoCH up && dispBull` → MSS up (và down đối xứng).
- **HH/HL/LH/LL**: so `high[swLen]` với `prevHigh`, `low[swLen]` với `prevLow` tại nến xác nhận.
- **Retest**: `retestOn && brkDir==1 && bar_index-brkBar<=retestBars && low<=brkLevel+retestTol*ATR
  && close>brkLevel` (bear đối xứng).
- **Failed breakout**: `failOn && brkDir==-1 && bar_index-brkBar<=failBars && close>brkLevel`
  (bear đối xứng).
- **Continuation**: `trend==1 && isHH` / `trend==-1 && isLL`.
- **Pullback**: `trend==1 && low<=emaM && close>emaM` / `trend==-1 && high>=emaM && close<emaM`.

#### 4.1 Pattern giá (B-P0-1)

Lưu 4 pivot cao/thấp gần nhất (`hiPx/hiBar`, `loPx/loBar`) và buffer 1200 nến
(`pa_lowBuf/pa_highBuf`) để tính neckline.

- **Double Top**: 2 pivot cao liên tiếp trong band `±patBand*ATR`, `bar_index-b1<=patMaxBars`,
  neckline = low thấp nhất **giữa** hai pivot (không tính 2 đầu).
- **H&S Top**: pivot cao thứ 2 `>= pivot thứ nhất * patHsRatio`; neckline như trên.
- **Double Bottom / H&S Bottom**: đối xứng (neckline = high cao nhất giữa hai pivot;
  H&S bottom yêu cầu `l2 <= l1/patHsRatio`).
- Chân thứ 3 của H&S: khi có pivot mới gần bằng vai thứ nhất (`inBand`) → gán `c/cBar`.
- **Signal chỉ khi phá neckline**: DT/HST `close<neck && close[1]>=neck`;
  DB/HSN `close>neck && close[1]<=neck`, với `bar_index>bBar`. Ghi `broken/brkBar`.
- `patHeight = |close - patNeck|` khi có signal, trong đó `patNeck` = neckline của pattern
  **cuối cùng chưa bị phá** (Pine quirk: không nhất thiết là pattern vừa phá). `pa_patHeight`
  là `var`, chỉ gán khi có signal và **giữ nguyên** đến signal kế tiếp (có thể là chiều cao cũ
  nhiều nến trước).
- Event `PATTERN` được đẩy trước các event structure khác.

### 5. L3 — Liquidity

- `PDH/PDL = request.security(sym, "D", high[1]/low[1], lookahead_on)` (nến D trước, không repaint);
  `PWH/PWL` tương tự với "W".
- Session HL reset khi tên phiên đổi (Asia → London → London/NY → NY), mở rộng trong phiên.
- Equal high/low: `|high[swLen]-prevHigh| <= atr*eqTol` (low đối xứng).
- **Sweep bull**: `low < PD/ PW/ SessionLo/ prevLow` và `close` trở lại trên mức
  (mỗi nguồn có toggle `pdOn/pwOn/sessOn`; nhánh equal low dùng `prevLow`). Bear đối xứng.
- Trendline 2 điểm: 2 pivot gần nhất mỗi phía, `slope=(y2-y1)/(x2-x1)`, giá trị tại bar hiện tại
  `at = y1 + slope*(bar_index-x1)`; chỉ dùng cho confluence (không vẽ trong port).

### 6. L4 — Zones

- **S/R**: pivot `srLeft/srRight`; thêm zone khi có pivot. Merge nếu
  `|mid - px| < atr*srWidth` (tăng `touches`, **không** đổi top/bot/side). Zone mới
  `top=px+half`, `bot=px-half`, `half=atr*srWidth*0.5`. Xoá zone `broken`, giới hạn `srMax`.
  Pine chỉ set `broken` trong block `barstate.islast` (viz) → **trong lịch sử zone không bao giờ
  bị đánh dấu broken**; port giữ nguyên hành vi này (xem D5).
- `nearSupport(zones, atrArg)`: tồn tại zone support chưa broken với
  `low >= bot - atrArg*0.3 && low <= top + atrArg*0.3`; resistance đối xứng với `high`.
- **FVG**: bull khi `low > high[2] && low-high[2] >= fvgMinAtr*ATR`; bear đối xứng với `low[2]`.
  Giới hạn `fvgMax`. Dead khi `bar_index-srcBar > fvgLife`, hoặc bull `close<bot`, bear `close>top`.
- **OB**: bull khi `dispBull && close[1]<open[1]`; bear khi `dispBear && close[1]>open[1]`;
  vùng = body nến trước; giới hạn `obMax`; dead khi quá 200 nến hoặc close xuyên vùng.
- `nearFvgBull/Bear`: FVG/OB chưa dead với khoảng cách `0.3*ATR` (bull dùng `low`, bear dùng `high`).

### 7. L5 — Candles

| Pattern | Công thức | Điểm |
|---|---|---:|
| Pin bull | `bullBar && loWick >= pinRatio*body` | +1 × veto |
| Engulf bull | `bullBar && close[1]<open[1] && close>=open[1] && open<=close[1] && body>=prevBody && body>=strongBody*range` | +1 (+streak) × veto |
| Displacement | `dispBull && bullBar && vol>=spikeR*volMA` | +1.2 |
| Rejection | `hiWick>=range*0.55 && loWick<=range*0.15 && bullBar` | +0.8 |
| Inside bar break | `high[1]<=high[2] && low[1]>=low[2] && close>high[1]` | +0.8 |
| Doji | `body<=dojiMax*range`; bull nếu `loWick>hiWick && close>=open` | +0.5 |
| 3 Soldiers | 3 nến tăng, close tăng dần, 3 body >= strongBody*range | +1.2 |

- Bear đối xứng. **Volume veto** (B-P1-1): `mul = volVetoOn ? (volRatio>=vetoR?1.0:0.4) : 1.0`,
  áp cho pin/engulf.
- **Engulfing streak** (B-P1-4): đếm liên tiếp; khi `streak>=streakMin` cộng `streakAdd` vào mỗi
  engulfing (chỉ hiển thị + điểm nhẹ, không alert riêng).
- `cpScore = cpBull>cpBear ? min(1,cpBull/3) : cpBear>cpBull ? -min(1,cpBear/3) : 0`.

### 8. L6–L8 — Indicators, Scoring

- RSI score: `<os → +1`, `>ob → -1`, else 0. MACD score: cross over +1, cross under −1,
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
- MTF: `ctxDir/setupDir = close>EMA ? 1 : -1` (0 nếu EMA na).
  `okSetup = !htfFilter || setupDir==0 || setupDir==dir`;
  `htfVeto = htfVetoOn && ctxDir!=0 && dir!=0 && ctxDir!=dir`; `okMtf = okSetup && !htfVeto`.
- 11 nhóm và trọng số: trend 15, struct 15, liq 12, loc 8, sr 10, candle 10, volume 8,
  volatility 7, momentum 7, session 4, mtf 4 (tổng 100, cấu hình được).
  `raw = clamp(Σ w_i g_i / Σ w_i, -1, 1)`; `score100 = round(50 + raw*50)`; `dir=sign(raw)`.
- Quality: `<=noTrade NO TRADE`, `<=weak WEAK`, `<=setup SETUP`, `<=strong STRONG`, else `A+`.
- **Regime gate** (B-P1-2): `BBW percentile` trong `regBbwLen`; squeeze nếu `<= regBbwSqueeze`.
  `TRENDING` khi `ADX>=regAdxTrend && !squeeze`; `CHOPPY` khi `ADX<regAdxChop` hoặc
  `squeeze && |emaF-emaM|<0.1*ATR`; else `RANGING`.
  `okRegime = !regOn || TRENDING || (RANGING && nearRangeEdge)`.
- **Confluence 0–3** (B-P0-3): (1) trend khung lớn đúng chiều (`ctxDir`, fallback `setupDir`);
  (2) giá tại level: S/R (tol `cfLevelTol`), FVG, PD/PW/Session, trendline, hoặc sweep;
  (3) nến/pattern xác nhận cùng chiều. Alert setup chỉ khi 3/3 (`cfRequire3`).

### 9. L9–L10 — Risk & state

`f_buildPaPlan(dir)`:

```text
pad   = ATR*slPadAtr
swing = dir==1 ? swingLo : swingHi          (nz về low/high)
sDist = (entry-swing)+pad  hoặc (swing-entry)+pad
aDist = ATR*slAtrMul
base  = (aDist+sDist)/2
dist  = clamp(nz(base,aDist), ATR*slMinAtr, max(ATR*slMaxAtr, ATR*slMinAtr))
sl    = entry - dir*dist ; risk = dist
valid = ATR>0 && dir!=0 && dist>0 && sl đúng phía && (rrMin<=0 || rr1>=rrMin)
```

- TP mode `Theo R`: tp_i = entry + dir*mxrr_i*risk với `rr1`, `rr2=max(rr2,rr1)`,
  `rr3=max(rr3,rr2)`.
- TP mode `Measured move`: `mm = patHeight>0 ? patHeight : |lastHigh-lastLow|` (nếu có);
  tp = entry ± mm*{0.5,1,1.5}; nếu `mm<=0` và `tpMmFallback` → TP theo R; nếu không fallback →
  tp = na (plan vẫn có thể valid).
- Gate cuối: `signal = plan.valid && okMtf && okCool && okDay && okScore && okDir &&
  okConfluence && okRegime`, trong đó `okBar` = nến đã đóng (port luôn bật).

State machine (thứ tự cố định mỗi nến):

1. Deferred reset (nếu `needReset`).
2. Nếu đang mở: xét `hitSl`, `hit1..hit3`. **Ưu tiên SL**: `hitSl && (hit1||hit2||hit3)` → loss;
   `hitSl` → loss; `hit3` → win + đóng; `hit2` → stage 2; `hit1` → stage 1.
   Quá 300 nến → đóng (không win/loss).
   Khi đóng: `trades++`, ghi `entry/sl/dir/bar/exit/R`, `needReset=true`.
   `exit = evSl?sl : evTp==3?tp3 : evTp==2?tp2 : tp1` (Pine quirk: timeout dùng tp1).
3. Mở lệnh mới nếu `okBar && signal && posDir==0`: gán plan, `evEntry`, `dayCount++`, `barsSince=0`.
4. `posBars++` nếu đang mở, không phải nến entry, không reset.
- `barsSince++` mỗi nến ở đầu engine; reset 0 khi entry.
- `dayCount` reset khi sang ngày mới (trước khi mở lệnh).

Event ring 50: `PATTERN`, `BOS`, `CHoCH`, `MSS`, `RETEST`, `FAILBRK`, `CONT`, `PULL`, `SWEEP`
(mỗi event có `kind/dir/srcBar/level/confirmed`). Thứ tự đẩy trong một nến:
PATTERN → BOS → CHoCH → MSS → RETEST → FAILBRK → CONT → PULL → SWEEP.

### 10. Khác biệt Pine → MQL5 (D1–D12)

| # | Chủ đề | Pine | MQL5 port |
|---|---|---|---|
| D1 | Bar policy | `barstate.isconfirmed` (input có thể tắt) | Luôn chỉ nến đã đóng; bỏ `confirmOnly` |
| D2 | Timezone phiên | tên tz (`Asia/Ho_Chi_Minh`, `America/New_York`) + DST | Offset phút cố định (`srvOffsetMin`, `mktOffsetMin`, `volSessOffsetMin`); người dùng chỉnh khi DST đổi |
| D3 | PDH/PDL/PWH/PWL | D/W bar theo timezone sàn | Tổng hợp từ nến chart theo ngày/tuần **server** (tuần bắt đầu thứ Hai) |
| D4 | MTF EMA | `request.security(expr[1], lookahead_on)` | `CopyRates` TF cao, EMA trên nến đã đóng, map `closeTime <= chart bar open time` |
| D5 | S/R zone `broken` | Chỉ set trong block `barstate.islast` | Không set trong replay (giữ hành vi lịch sử); hiển thị có thể tự kiểm tra |
| D6 | VWAP | `ta.vwap(close)` anchor phiên sàn | Cumulative theo volume, reset đầu ngày server |
| D7 | `time("W")` | Tuần theo sàn | Tuần thứ Hai theo server |
| D8 | Dashboard/line/box/label | Có | `NOT_PORTED` (viz-only) |
| D9 | Alert/webhook | `alertcondition` + JSON | `NOT_PORTED` (không alert trong port) |
| D10 | Input chết | `pa_cfBars`, `pa_vol_purWin/timCount`, `pa_liq_tlTol/MaxDev` | Bỏ (không ảnh hưởng điểm) |
| D11 | Session Hi/Lo | Reset theo tên phiên NY | Cùng quy tắc, nhưng giờ tính từ offset cố định |
| D12 | Volume | `volume` của sàn | `tick_volume` (MT5 không có volume thật cho FX); ghi rõ trong contract |

### 11. Warm-up

- EMA slow cần `emaSlow` nến; RSI cần `rsiLen+1`; MACD hist cần `macdS+macdSig-1`;
  DMI/ADX cần `dmiLen+dmiSmooth-1`; BBW percentile cần `bbLen+regBbwLen`; PDH/PDL cần trọn
  ngày trước; PWH/PWL cần trọn tuần trước; MTF cần `ctxLen/setupLen` nến TF cao.
- Trước warm-up: các giá trị na → so sánh false, score có thể lệch; indicator ghi 0/EMPTY và
  replay bắt đầu từ nến đủ dữ liệu tối thiểu (`PaWarmupBars`).

### 12. Trạng thái port

| Hạng mục | Trạng thái |
|---|---|
| Spec | tài liệu này |
| Repaint audit | `REPAINT_AUDIT_PriceActionMTF.md` |
| Buffer contract | `BUFFER_CONTRACT_PriceActionMTF.md` |
| Indicator | `mt5/Indicators/PinePort/PriceActionMTF.mq5` |
| Contract tests | `mt5/Scripts/PriceActionMTFContractTests.mq5` — **PASS 120/120** (MT5, 2026-10-28) |
| EA hỗ trợ | `NOT_IMPLEMENTED` |
| Parity | `BLOCKED` — chưa có CSV Pine |
| Runtime | Contract test PASS; indicator gắn chart/plot chưa xác minh |

## Repaint Audit — Price Action MTF (Pine v6)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — phân tích tĩnh trên source Pine; chưa chạy TradingView
  Bar Replay, chưa tạo alert, chưa chạy Strategy Tester. Các kết luận phụ thuộc runtime đánh dấu
  `PENDING` ở §14.
- **Nguồn:** [`dist/Price Action MTF.pine`](file:///D:/Applications/tm-trading/pine/dist/Price%20Action%20MTF.pine)
  (1.801 dòng, indicator), [`dist/Price Action MTF Backtest.pine`](file:///D:/Applications/tm-trading/pine/dist/Price%20Action%20MTF%20Backtest.pine)
  (1.826 dòng, strategy) và `pine/parts-price-action-mtf/` (14 module). Không file Pine nào bị sửa.
- **Đặc tả nền:** `INDICATOR_SPEC_PriceActionMTF.md`.
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

Trong PA MTF, RP1 xuất hiện ở mọi thành phần tính trên nến realtime (score, plan, zone, pivot).
Điểm khác biệt so với ba indicator trước là **RP2/RP5 thật sự tồn tại** ở block S/R `broken`
(§7), không chỉ là hiển thị.

### 2. Bản đồ phụ thuộc dữ liệu

```
open/high/low/close/time + syminfo.mintick + volume
  ├─ ta.atr(rsi|atrLen)                        -> atr, atrPct
  ├─ ta.rma(volume, volMaLen) / ta.sma(volume) -> VSA bucket, volRatio, relVol
  ├─ OBV thủ công + cửa sổ mảng obvLen+2       -> obvSlope
  ├─ ta.ema(close, 20/50/200)                  -> stack, gScore trend
  ├─ ta.pivothigh/low(swLen, swLen)            -> structure, pattern, trendline
  ├─ ta.lowest/highest(swing)                  -> swingLo/Hi (SL)
  ├─ ta.rsi / ta.macd / ta.dmi / ta.bb         -> momentum, BBW
  ├─ ta.vwap(close)                            -> location score
  ├─ request.security(D/W, high[1], lookahead_on)   -> PDH/PDL/PWH/PWL
  ├─ request.security(ctx/setup TF, ema[1], lookahead_on) -> MTF bias
  ├─ var arrays: events(50), patterns(30), low/high buffer(1200),
  │             S/R zones(8), FVG(20), OB(20), pivot history(4)
  ├─ var state: structure, brk, trendline, session HL, engulf streak,
  │             dayCount/barsSince, position + counters
  └─ barstate.islast + pa_showViz/pa_showPriceZones/pa_sr_showOn
        -> block S/R broken (MUTATE STATE — xem §7)
```

Không có `request.security_lower_tf`, không offset âm, không dùng dữ liệu tương lai ngoài hai
nhóm `request.security` ở trên. Pivot là **độ trễ cấu trúc**, không phải repaint.

### 3. Cổng confirmed-bar

```pine
pa_confirmOnly  = input.bool(true, ...)                 // dòng 152
pa_okConfirmed  = not pa_confirmOnly or barstate.isconfirmed // dòng 498
pa_okBar        = pa_confirmOnly ? barstate.isconfirmed : true // dòng 1440
pa_signal       = pa_plan.valid and pa_okFilter          // dòng 1446
```

**Được gate bởi `pa_okConfirmed`:** chỉ việc đẩy event vào ring 50 (PATTERN, BOS, CHoCH, MSS,
RETEST, FAILBRK, CONT, PULL, SWEEP) tại dòng 769–814 và 878–881.

**Được gate bởi `pa_okBar`:** mở vị thế mới (dòng 1551) và webhook `alert()` (dòng 1777–1793).

**Không được gate** (tính trên nến realtime):

| Thành phần | Dòng | Hệ quả |
|---|---|---|
| Toàn bộ L1–L8: ATR, volume, OBV, EMA, pivot, structure, pattern, zone, candle, score | 374–1370 | Dashboard/score nhấp nháy giữa nến (RP1) |
| `pa_signal` (biến) | 1446 | Có thể true giữa nến nhưng entry chưa xảy ra |
| Block S/R `broken` + `f_nearSupport` sau đó | 1093–1101, 1304 | **Mutate state và đổi score trên nến cuối** (§7) |
| Hit TP/SL của state machine | 1501–1536 | Có thể bật giữa nến; cuối nến chốt theo high/low |
| `alertcondition` TP/SL/pattern | 1773–1775 | Có thể phát giữa nến (RP3) |

Pine rollback `var` về đầu nến realtime mỗi tick nên **kết quả cuối nến vẫn tất định** với dữ liệu
đã đóng — trừ block S/R ở §7, nơi kết quả phụ thuộc việc nến đó từng là “last bar” hay chưa.

**Kết luận:** `confirmOnly = false` không port (P2). MQL5 chỉ tính trên nến đóng.

### 4. MTF và PD/PW — `request.security`

```pine
pa_ctxEma   = request.security(syminfo.tickerid, pa_ctxTf,
                ta.ema(close, pa_ctxLen)[1], lookahead = barmerge.lookahead_on)   // 1284
pa_setupEma = request.security(syminfo.tickerid, pa_setupTf,
                ta.ema(close, pa_setupLen)[1], lookahead = barmerge.lookahead_on) // 1287
pa_pdh = request.security(syminfo.tickerid, "D", high[1], lookahead = barmerge.lookahead_on) // 845
pa_pdl = request.security(syminfo.tickerid, "D", low[1],  lookahead = barmerge.lookahead_on) // 846
pa_pwh = request.security(syminfo.tickerid, "W", high[1], lookahead = barmerge.lookahead_on) // 847
pa_pwl = request.security(syminfo.tickerid, "W", low[1],  lookahead = barmerge.lookahead_on) // 848
```

Đây là idiom **non-repainting**: `lookahead_on` đi kèm `[1]` nên giá trị dùng là bar HTF/D/W
**đã đóng trước bar hiện tại**, không phải bar đang hình thành. Không có RP2/RP3 từ nhóm này.

Quy tắc port cho MTF (P3): với nến chart mở tại `Tj`, chọn bar HTF `k` gần nhất có
`close_time[k] <= Tj`, tính EMA trên chuỗi close HTF đã đóng, seed SMA(`len`) giống Pine.
Nếu chưa đủ `len` bar HTF → `EMPTY_VALUE` (Pine `na`). Ghi kèm `htf_bar_close_time` khi parity.

PDH/PDL/PWH/PWL (P4): tổng hợp từ nến chart theo **ngày/tuần server**; tuần bắt đầu thứ Hai.
Pine dùng ngày/tuần theo timezone sàn của TradingView → có thể lệch một nến biên (D3).
Với chart TF = D, `high[1]` của Pine tương đương high của ngày server trước.

Biên `close_time == Tj` và biên ngày/tuần cần CSV xác nhận (E2/E3).

### 5. Session, VWAP, mốc ngày/tuần

- Session name (dòng 851–867): Asia 17:00–02:00, London 02:00–10:00, NY 07:00–15:00 theo
  `pa_sessTz` (mặc định America/New_York). `pa_sessName` có thể là `London/NY` khi overlap.
- `pa_sessHi/Lo` reset khi **tên phiên đổi** và tên mới khác `-`; mở rộng trong phiên.
  Khi tên là `-` (15:00–17:00), biến **không reset về na** → sweep/confluence vẫn dùng mức
  session cũ cho đến phiên kế tiếp. Đây là hành vi Pine, port giữ nguyên (P7).
- Hệ quả thứ tự (dòng 856–876): session HL được cập nhật **trước** sweep và đã bao gồm
  high/low của chính nến hiện tại, nên `low < pa_sessLo` / `high > pa_sessHi` **không thể
  đúng trong phiên**. Nhánh sweep session chỉ có thể bật khi tên phiên là `-`, dùng mức cũ
  của phiên trước. Port giữ nguyên (xem contract Q3; test F7/F8).
- Tương tự, `f_nearSupport/Resistance` nhân thêm hằng số **0.3** vào tham số ATR: regime
  truyền `0.35·ATR` → tolerance thực `0.105·ATR`; confluence truyền `cfLevelTol·ATR` →
  `0.15·ATR` (contract Q1; test K5/K7).
- `pa_dayCount` reset bằng `ta.change(time("D"))` (dòng 1437–1438) — ngày theo sàn.
- `pa_vwap = ta.vwap(close)` (dòng 1267) — anchor phiên của symbol, cumulative volume-weighted.
- Trendline touch counters (dòng 991–994) chỉ dùng cho dashboard; không tham gia score hay
  confluence (confluence dùng `pa_tlUpAt/pa_tlDnAt`, dòng 1355–1360). Không cần port counters.

Port dùng offset phút cố định (`mktOffsetMin` cho phiên, `srvOffsetMin` cho ngày/tuần server,
`volSessOffsetMin` cho volume session) và VWAP reset đầu ngày server (D2/D6/D7). Người dùng phải
chỉnh offset khi DST đổi. Không có cách khác trong MQL5 để tái lập timezone sàn.

### 6. Pivot, structure, pattern

- `ta.pivothigh/low(high/low, swLen, swLen)` (dòng 435–436) xác nhận tại `bar_index`; giá trị
  nằm ở `high[swLen]`/`low[swLen]`; `*Bar = bar_index - swLen`. Trên nến realtime, pivot có thể
  xuất hiện/biến mất khi high/low hiện tại thay đổi → RP1 hiển thị, nhưng tại close thì chốt.
- Pivot S/R dùng `srLeft/srRight` (mặc định 10/10), độc lập với `swLen` của structure.
- BOS/CHoCH là **edge flag** reset mỗi nến (dòng 485–494); `pa_trend` là state. MSS = BOS/CHoCH
  + displacement cùng nến.
- Pattern DT/DB/HST/HSN chỉ phát tín hiệu khi **phá neckline** (`close` so `close[1]`), không dự
  đoán. Neckline lấy từ buffer 1200 nến, không dùng offset series sâu (tránh RE10143).
- `pa_patHeight` (dòng 766–767) dùng `pa_patNeck` = neckline của **pattern cuối chưa bị phá**,
  không nhất thiết là pattern vừa phá. Vì vậy `patHeight` có thể bằng 0 ngay sau khi có signal;
  TP measured-move có thể rơi vào fallback. Port giữ nguyên (P8).
- `pa_pattern` ring 30, pivot history 4. Pattern cũ bị `shift` khi vượt 30, kể cả chưa broken.
- Các bước này chỉ dùng dữ liệu đã đóng; không repaint trên lịch sử.

### 7. S/R zone — block `barstate.islast` mutate state (trọng tâm)

#### 7.1 Bằng chứng

```pine
// dòng 1031–1034: đăng ký zone
if not na(ta.pivothigh(high, pa_sr_left, pa_sr_right))
    f_addZone(sr_zones, high[pa_sr_right], -1, pa_atr, pa_sr_width, pa_sr_maxZone)
if not na(ta.pivotlow(low, pa_sr_left, pa_sr_right))
    f_addZone(sr_zones, low[pa_sr_right],  1, pa_atr, pa_sr_width, pa_sr_maxZone)

// dòng 1093–1107: CHỈ trên bar cuối, và CHỈ khi 3 toggle hiển thị bật
if barstate.islast and pa_showViz and pa_showPriceZones
    if pa_sr_showOn
        for z in sr_zones
            if z.side == 1 and close < z.bot
                z.broken := true
            if z.side == -1 and close > z.top
                z.broken := true
```

`f_addZone` (shared, dòng 64–84) xoá zone `broken` ở **mỗi lần gọi**, tức ở nến kế tiếp có pivot.
`f_nearSupport/f_nearResistance` (dòng 86–100) bỏ qua zone `broken`.

Block 1093 nằm **trước** phần scoring (1304, 1343, 1349–1366) trong cùng một lần chạy. Vì vậy
trên nến cuối:

1. Zone bị đánh `broken` theo `close` hiện tại.
2. `pa_gSr`, `pa_nearRangeEdge`, `pa_cfLevelBull/Bear` nhìn thấy zone đã broken → loại chúng.
3. `pa_score100`, `pa_dir`, `pa_plan`, `pa_signal` được tính từ trạng thái đã loại đó.
4. Nến sau, `f_addZone` xoá các zone broken khỏi mảng.

Khi tải lại chart, mọi nến cũ đều có `barstate.islast = false`, nên **không nến nào bị đánh
broken**. Kết quả là giá trị đã commit cho nến cuối khi chạy live khác giá trị tính lại sau khi
reload → **RP2 + RP5 thật sự**, không chỉ RP1.

#### 7.2 Hệ quả

- Tín hiệu entry trên nến cuối khi live có thể dùng score đã loại zone broken; sau reload cùng
  nến đó có thể có score khác, thậm chí mất `pa_signal`.
- Mảng `sr_zones` live bị mất zone broken ở nến kế tiếp; mảng cold giữ lại. Vì `f_addZone` merge
  theo **mọi zone còn trong mảng**, việc mất/giữ zone còn làm thay đổi `touches`, thứ tự trim
  `srMax`, và kết quả merge của các nến sau → sai lệch kéo dài, không tự khép lại.
- Block này phụ thuộc **input hiển thị**: `pa_showViz`, `pa_showPriceZones`, `pa_sr_showOn`
  (mặc định đều `true`). Tắt hiển thị sẽ đổi logic tín hiệu. Đây là coupling display→signal
  không mong muốn của Pine.
- Không có alert nào bị ảnh hưởng trực tiếp ngoài `pa_signal`/`pa_evEntry`; nhưng entry marker,
  dashboard và webhook đều đọc cùng score.

#### 7.3 Quyết định port

Port tái lập **cold replay** (P5): không bao giờ đánh `broken`, không phụ thuộc toggle hiển thị.
Lý do:

1. Đây là giá trị TradingView hiển thị sau khi tải lại và là giá trị một CSV lịch sử sẽ chứa.
2. MQL5 không có rollback và recompute toàn bộ history mỗi nến; không thể tái lập chuỗi
   “mỗi nến từng là last bar” mà không lưu state live bên ngoài indicator.
3. Tách display khỏi logic là điều kiện cần để EA đọc buffer ổn định.

Hệ quả: port **không** tái lập được alert live trong trường hợp zone bị phá đúng nến cuối.
Đây là sai lệch có chủ đích, ghi ở D5 và R1; runtime E4 đo mức độ. Nếu người dùng muốn hành vi
“S/R bị phá thì loại” đúng đắn về giao dịch, cần một input mới (không có trong Pine) và một
phiên bản contract khác — không thực hiện trong port này.

### 8. State machine — thứ tự và edge case

Thứ tự mỗi nến (dòng 1487–1567):

1. Deferred reset nếu `pa_needReset`.
2. Nếu `pa_posDir != 0`: xét `hitSl`, `hit1..hit3`.
3. Mở vị thế mới nếu `pa_okBar && pa_signal && pa_posDir == 0`.
4. `pa_posBars += 1` nếu đang mở, không phải nến entry, không reset.

Các kết luận:

1. **Exit chạy trước entry.** Nến đóng vị thế không thể mở vị thế mới vì reset bị deferred và
   entry yêu cầu `posDir == 0`; entry sớm nhất là nến kế tiếp.
2. **SL ưu tiên tuyệt đối.** `hitSl && (hit1||hit2||hit3)` → loss; nhánh này đứng trước `hit3`.
   Khác TM Fusion Zones: **TP3 không thắng SL** khi cả hai cùng chạm.
3. **TP1/TP2 không đóng vị thế**, chỉ tăng `pa_posStage`; `hit2` được xét trước `hit1` nên nến
   chạm cả TP1 và TP2 ghi nhận TP2.
4. **Timeout 300 nến** (`pa_posBars > 300`) đóng vị thế, `trades++` nhưng **không** tăng wins/
   losses. `pa_evTp = 0`, `pa_evSl = false` → `pa_xExit = pa_posTp1` (quirk Pine). Exit này không
   phải giá thị trường; chỉ dùng thống kê/parity, không dùng P&L.
5. **Không adoption.** PA MTF chỉ mở khi `posDir == 0`; tín hiệu mới trong lúc mở bị bỏ qua.
   Sau khi đóng, tín hiệu phải còn hiệu lực ở nến kế tiếp mới vào được.
6. **Hit flags không gate confirmed.** Trên realtime có thể bật giữa nến; cuối nến chốt theo
   high/low cuối. `alertcondition` TP/SL có thể phát giữa nến (RP3).
7. **Không kiểm tra hit trên nến entry** vì exit block đứng trước entry block. Nến entry không
   thể tự chạm TP/SL — tương đương tinh thần `process_orders_on_close`.
8. **Counters:** `trades` tăng mọi lần đóng; `wins` chỉ khi TP3; `losses` chỉ khi SL. Tổng
   wins+losses có thể nhỏ hơn trades.
9. **`pa_dayCount`** reset đầu ngày trước entry; entry tăng 1. Vị thế mở qua ngày mới không bị
   đóng, nhưng dayCount về 0.
10. **`pa_barsSince`** tăng đầu mỗi nến, entry đặt 0; cooldown tính từ entry gần nhất, không
    phải từ lần đóng.

### 9. Quirk risk plan — default không có tín hiệu

```pine
pa_rr1   = input.float(1.0, ...)   // dòng 304
pa_rrMin = input.float(1.5, ...)   // dòng 307
rrOk     = pa_rrMin <= 0.0 or pa_rr1 >= pa_rrMin   // dòng 1407
valid    = atrOk and dirOk and slOk and rrOk        // dòng 1408
```

Với **input mặc định**, `1.0 >= 1.5` sai → `plan.valid = false` → `pa_signal = false` vĩnh viễn.
Indicator mặc định **không bao giờ vào lệnh**, dù score/regime/confluence đạt. Đây là lỗi cấu
hình của source, không phải lỗi port. Port giữ nguyên công thức (P9); test/vector và hướng dẫn
runtime phải dùng `rr1 >= rrMin` (ví dụ `rr1 = 2.0`) hoặc `rrMin = 0` mới thấy tín hiệu.

Các quirk risk khác:

- `sl` luôn bị clamp trong `[slMinAtr, slMaxAtr]*ATR`; `slOk` chỉ kiểm tra đúng phía, không kiểm
  tra `dist` so với swing.
- `rr2 = max(rr2, rr1)`, `rr3 = max(rr3, rr2)` — input thấp hơn bị kéo lên, không báo lỗi.
- `valid` không yêu cầu TP khác na. Ở TP measured-move, nếu `mmDist <= 0` và fallback tắt, plan
  vẫn valid với `tp1..tp3 = na`; state machine sẽ không bao giờ chạm TP, chỉ SL/timeout.
- `pa_patHeight` có thể 0 (§6) → measured-move rơi vào fallback hoặc na.

### 10. Kịch bản intrabar

**S1 — Score đổi giữa nến.** ATR/close/volume đổi → score, quality, dir, plan nhấp nháy trên
dashboard; entry chỉ ở close (okBar) → **RP1 hiển thị, không RP3 cho entry**.

**S2 — `pa_signal` true giữa nến rồi false lúc đóng.** Không entry. Không có trạng thái rác vì
plan không được lưu. **Không repaint.**

**S3 — Entry tại close, nến sau chạm TP1 rồi đóng dưới TP1.** `pa_posStage` là `var`, commit 1 ở
cuối nến; sau đó SL → loss (vì hitSl ưu tiên). Port giữ nguyên trên nến đóng.

**S4 — Nến chạm TP3 và SL.** Nhánh `hitSl && hit3` thắng → loss, không phải win. Port đúng thứ tự.

**S5 — Nến chạm TP1 và SL.** Loss (khác TM FZ). Port đúng.

**S6 — Nến timeout 300.** Đóng, `trades++`, không win/loss, `xExit = tp1`. Port đúng.

**S7 — Đang mở, có tín hiệu mới.** Bị bỏ qua; không adoption, không reset. Port đúng.

**S8 — Nến cuối phá S/R zone.** Block 1093 đánh broken trước scoring → score/signal live khác
cold. Sau reload, cùng nến có thể mất signal. **RP2/RP5 thật.** Port chọn cold (P5). E4.

**S9 — Pivot xác nhận trên nến realtime.** Structure/zone/pattern có thể đổi giữa nến; cuối nến
chốt. MQL5 chỉ xử lý nến đóng. **Không RP2.**

**S10 — Bar HTF đóng giữa nến chart.** Với `[1] + lookahead_on`, giá trị MTF chỉ đổi khi bar HTF
kế tiếp đóng, tức tại biên; không dùng bar đang chạy. **Không RP1/RP5** nếu mapping P3 đúng.
E2 xác nhận biên.

**S11 — `confirmOnly = false`.** Entry/event có thể xảy ra giữa nến và history có thể khác sau
reload. Không port (P2).

### 11. Alert và webhook

| Alert | Điều kiện | Gate | Đánh giá |
|---|---|---|---|
| `PA MTF LONG` / `SHORT` | `pa_evEntry` + dir | entry đã gate `okBar` | An toàn với `confirmOnly=true` |
| `PA MTF SETUP` | `pa_evEntry && confluence == 3` | như trên | An toàn |
| `PA MTF PATTERN` | `pa_patSignal` | **không gate** | RP3: close có thể vượt neckline rồi rút |
| `PA MTF TAKE PROFIT` | `pa_evTp > 0` | **không gate** | RP3: hit có thể xảy ra giữa nến |
| `PA MTF STOP LOSS` | `pa_evSl` | **không gate** | RP3 |
| Webhook ENTRY/TP/SL | `pa_okBar && pa_doSend && ...` | có gate | Chỉ phát ở close, nhưng đọc hit flag cuối nến |
| Webhook EVENT | `pa_okBar && pa_doSend && isconfirmed` | có gate | Dùng ring event; ổn |

`alertcondition` không phụ thuộc toggle hiển thị (khác block S/R). `payloadMode` chỉ phân biệt
`Off`; `Full` và `Slim` tạo cùng payload. Không port alert/webhook (P10).

### 12. Strategy sibling (chỉ mô tả, không port)

Header Backtest: `pyramiding=0`, `calc_on_order_fills=true`, `process_orders_on_close=true`,
equity 10.000, 100% equity, commission 0.05%/chiều, slippage 0.

- Entry khi `strategy.position_size == 0`, `pa_okBar && pa_signal`, đúng hướng cho phép.
- Exit `stop = pa_posSl`, `limit = pa_posTp2` (dòng 1594/1597) — **TP2**, không phải TP3.
- Indicator đóng virtual position ở TP3 hoặc timeout; strategy thoát ở TP2 → thống kê indicator
  ≠ kết quả backtest.
- Indicator không adoption khi đang mở, nhưng strategy có thể flat sớm hơn indicator (TP2) và bị
  chặn entry mới cho đến khi indicator reset. Hai state machine không đồng bộ.

**RP4** chỉ xuất hiện nếu port execution. Repo này không port entry/exit/equity/commission.
Không dùng kết quả Backtest.pine làm reference parity.

### 13. Timestamp contract

| Trường | Định nghĩa | Ví dụ M5 |
|---|---|---|
| `bar_open_time` | Thời gian mở nến theo giờ server | `2026.10.27 20:50` |
| `signal_bar` | Nến đóng phát signal/entry | nến `20:50` |
| `confirmed_at` | `bar_open_time + TF` | `20:55:00` |
| `detected_at` | Tick đầu tiên EA đọc buffer `shift=1` | `20:55:00 … 20:59:59` |
| `exit_bar` | Nến chạm TP/SL/timeout | nến `21:20` |
| `signal_id` | `PA_LONG`, `PA_SHORT`, `PA_TP1/2/3`, `PA_SL`, `PA_TIMEOUT` | — |

Join parity theo `bar_open_time`; với MTF ghi thêm `htf_bar_close_time` (context và setup) để tái
lập mapping. Hit TP/SL chỉ biết theo bar, không theo tick; không dùng `detected_at` làm join key.

### 14. Chính sách MQL5

| Mã | Quyết định | Lý do |
|---|---|---|
| P1 | Chỉ mutate state trên nến đóng; full-history recompute khi `rates_total` đổi | Loại RP1/RP2; MQL5 không có rollback |
| P2 | **Không port** `confirmOnly = false` | Repaint theo thiết kế |
| P3 | MTF: bar đã đóng gần nhất `close_time <= chart bar open`, EMA seed SMA | Khớp idiom `[1] + lookahead_on`; E2 |
| P4 | PD/PW: tổng hợp ngày/tuần server, tuần bắt đầu thứ Hai | Không có exchange calendar; D3 |
| P5 | S/R: **cold replay**, không đánh `broken`, không phụ thuộc toggle hiển thị | RP2/RP5 của Pine; §7 |
| P6 | Pivot strict hai phía; xác nhận tại `c + len`, giá trị tại `[len]` | Khớp `ta.pivot*`; tránh plateau |
| P7 | Session HL: reset khi tên phiên đổi; **giữ mức cũ khi tên `-`** | Khớp Pine; sweep/confluence |
| P8 | Pattern: neckline từ buffer 1200; `patHeight` theo pattern cuối chưa phá | Khớp Pine; quirk TP |
| P9 | Risk: giữ nguyên công thức và **default `rr1=1.0 < rrMin=1.5`** | Không sửa hành vi nguồn; §9 |
| P10 | Không port alert, webhook, strategy, equity, commission | Signal-only |
| P11 | `EMPTY_VALUE` cho `na`; enum số cho quality/regime/bucket/stage | Hợp đồng buffer rõ ràng |
| P12 | Không port dashboard/label/box/line/badge; chỉ buffer tín hiệu | Thuần hiển thị |
| P13 | Chỉ dùng `tick_volume` | MT5 không có volume thật cho FX; D12 |

### 15. Kế hoạch xác minh thủ công (TradingView)

| # | Bước | Kỳ vọng | Trạng thái |
|---|---|---|---|
| E1 | F5 PA MTF (XAUUSD M5), để mặc định, Bar Replay từng tick | Không entry mặc định vì `rr1 < rrMin`; xác nhận score/quality vẫn cập nhật | `PENDING` |
| E2 | Đặt `rr1=2.0`, replay; ghi `ctxEma/setupEma` theo nến chart trong một bar D/H1 | Xác nhận mapping bar đã đóng và biên `close_time <= Tj` | `PENDING` |
| E3 | Ghi PDH/PDL/PWH/PWL qua biên ngày/tuần server | Chốt quy tắc biên và lệch timezone sàn vs server | `PENDING` |
| E4 | Tạo zone S/R bị phá đúng nến cuối; so score/signal trước và sau reload | Đo RP2; xác nhận cold replay khớp giá trị sau reload | `PENDING` |
| E5 | Đang long, nến chạm TP1 rồi SL; nến chạm TP3 và SL | Xác nhận SL ưu tiên, loss; TP3+SL = loss | `PENDING` |
| E6 | Đang long, timeout 300 nến | Xác nhận đóng, trades+1, wins/losses không đổi, `xExit=tp1` | `PENDING` |
| E7 | Bật/tắt `pa_showViz` trên cùng dữ liệu | Đo thay đổi score do block S/R broken (chứng minh coupling) | `PENDING` |
| E8 | Đổi `pa_sessTz` và offset; kiểm tra session HL + sweep | Xác nhận mức session cũ còn dùng khi tên `-` | `PENDING` |
| E9 | TP measured-move với pattern vừa phá nhưng `patNeck` là pattern khác | Xác nhận `patHeight` có thể 0 → fallback/na | `PENDING` |
| E10 | Export CSV: score/dir/quality/plan/events/pos/regime/confluence | Làm reference parity cho MQL5 | `PENDING` |

### 16. Risk register

| ID | Phát hiện | Mức | Xử lý |
|---|---|---|---|
| R1 | Block S/R `broken` chỉ ở `barstate.islast` → history live ≠ reload; display toggle đổi logic | **Cao** | P5; E4/E7; ghi rõ không tái lập live |
| R2 | Default `rr1=1.0 < rrMin=1.5` → không có signal mặc định | **Cao** | P9; E1; hướng dẫn runtime dùng `rr1>=rrMin` |
| R3 | Hit TP/SL và `alertcondition` không gate confirmed | Trung bình | P10; EA đọc nến đóng |
| R4 | Strategy thoát TP2, indicator TP3/timeout → stats khác backtest | Cao nếu dùng backtest | Không port execution; không dùng làm reference |
| R5 | `patHeight` lấy pattern cuối chưa phá → measured-move sai/0 | Trung bình | P8; E9; test vector |
| R6 | Timezone sàn vs server → PD/PW/dayCount/VWAP lệch | Trung bình | P3/P4/P7; D2–D7; E3 |
| R7 | Session HL giữ mức cũ khi tên `-` | Thấp | P7; giữ nguyên; test vector |
| R8 | `pa_timCount`, `pa_cfBars`, `pa_evClose`, `pa_liq_tlTol/MaxDev`, touch counters chết hoặc viz-only | Thấp | Bỏ input chết; không kỳ vọng parity theo chúng |
| R9 | `math.round` tại biên .5 và sai số floating point có thể lệch 1 điểm score | Trung bình | Test vector; ghi nhận khi parity |
| R10 | EMA/ATR/RSI/DMI seed phụ thuộc điểm bắt đầu history | Trung bình | Full-history replay; warm-up EXCLUDE khỏi parity |

### 17. Gate 2 — tiêu chí

| # | Tiêu chí | Trạng thái |
|---|---|---|
| B1 | Trả lời đủ câu hỏi repaint của roadmap Phase 2 | PASS |
| B2 | Timestamp + confirmed state cho từng signal | PASS |
| B3 | Ma trận repaint theo thành phần | PASS |
| B4 | Chính sách MQL5 không âm thầm đổi logic | PASS (P5/P9 là sai lệch có chủ đích, đã ghi) |
| B5 | Không tuyên bố đã kiểm chứng runtime TradingView | PASS (E1–E10 `PENDING`) |
| B6 | Không sửa Pine | PASS |

**Kết luận:** Gate 2 đạt ở mức phân tích tĩnh. Hai phát hiện phải chuyển sang Phase 3/4:
block S/R `broken` (R1) và default RR vô hiệu (R2). Không được dùng E1–E10 làm bằng chứng parity
khi chưa chạy.

### 18. Câu hỏi còn mở

1. Block S/R `broken` có thực sự tạo RP2 trên TradingView khi reload, hay Pine giữ nguyên giá trị
   đã commit? (E4)
2. `ta.vwap(close)` anchor chính xác theo session nào của symbol XAUUSD/forex? (E3)
3. `ta.pivothigh/low` xử lý plateau/tie thế nào? (R6/E10)
4. Có nên thêm buffer `HTF_BAR_CLOSE_TIME` và `CLOSE_REASON` (TP3/SL/TIMEOUT) vào contract?
   (cân nhắc ở Phase 3)
5. Symbol/timeframe/timezone chuẩn cho parity vẫn chưa chốt (XAUUSD M5 là ứng viên).

## Buffer Contract — Price Action MTF (Pine v6 → MQL5)

- **Phase:** 3 — Hợp đồng buffer và test vector trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4`
- **Nguồn:** `INDICATOR_SPEC_PriceActionMTF.md`,
  `REPAINT_AUDIT_PriceActionMTF.md`
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không `OrderSend`, không `CTrade`, không đọc tài
  khoản, không alert/webhook, không `WebRequest`, không file I/O trong indicator.

### 1. Phạm vi

1. Input của `mt5/Indicators/PinePort/PriceActionMTF.mq5` (115 input).
2. **95 buffer hợp đồng** (index 12..106) cho EA/audit + **12 buffer render** (index 0..11).
3. Bar policy: chỉ nến đã đóng; replay toàn bộ lịch sử mỗi nến.
4. Cách EA đọc buffer, dedupe, ghi CSV (EA hỗ trợ: `NOT_IMPLEMENTED`).
5. 119 test vector cho logic thuần trong `PriceActionMTFContract.mqh`.

Không định nghĩa: execution, sizing, commission, alert, dashboard. Repo không port các phần đó.

### 2. Chính sách kế thừa Phase 2

| Mã | Chính sách | Thể hiện trong contract |
|---|---|---|
| P1 | State chỉ mutate trên nến đóng; replay toàn bộ khi `rates_total` đổi | §7 |
| P2 | EA đọc `shift = 1`; không có input `shift = 0` | §12 |
| P3 | Không port `confirmOnly = false`; không có input confirm | §3 |
| P4 | MTF: bar HTF đã đóng gần nhất có `close_time <= chart **open** time` | §9.4 |
| P5 | S/R: cold replay, **không bao giờ** đánh `broken`; không phụ thuộc toggle hiển thị | §9.1 |
| P6 | Pivot strict hai phía, xác nhận tại `c + len`, giá trị tại `[len]` | §9.2 |
| P7 | Session theo offset phút cố định; PDH/PDL/PWH/PWL theo ngày/tuần **server** | §9.3 |
| P8 | Pattern: neckline từ buffer 1200 nến; `patHeight` theo pattern cuối chưa phá, tồn tại qua nến | §9.5 |
| P9 | Risk/TP: giữ nguyên công thức và **default `rr1=1.0 < rrMin=1.5`** | §10.4 |
| P10 | Không port alert, webhook, strategy, equity, commission | — |
| P11 | `EMPTY_VALUE` cho `na`; enum số cho quality/regime/bucket/session/block | §6 |
| P12 | Không port dashboard/box/label/ribbon/line trang trí | §6.1 |
| P13 | Không "sửa" quirk Pine (SL ưu tiên, timeout exit = TP1, session sweep, OBV warm-up) | §11 |

### 3. Input contract (115)

Không port 35 input hiển thị/chết: `confirmOnly`, `payloadMode`, `ms_bosOn/chochOn/mssOn`,
`liq_sweepOn`, `liq_tlOn/tlTol/tlMaxDev`, `sr_showOn`, `fvg_showOn`, `ob_showOn`,
`vol_showMA`, `vol_purWin` (chết), `vol_sess`/`vol_tz` (thay bằng 2 input phút),
`sessTz` (thay bằng offset), `showViz`, `cBull/cBear`, `showSig/showHit/showZone/zoneLen`,
`showEma/showPd/showPw/showSess/showPriceZones/showTl/showVwap/showVol/showDash/dashSize`,
`cfBars` (chết).

#### 3.1 Nhóm thời gian (MQL5-only)

| # | Input | Kiểu | Default | Ghi chú |
|---:|---|---|---:|---|
| 1 | `InpSrvOffsetMin` | int | 180 | Offset server → UTC (phút, dương = đông). Exness thường +120/+180 |
| 2 | `InpMktOffsetMin` | int | −300 | Offset UTC → giờ thị trường (NY = −300/−240 khi DST) |
| 3 | `InpVolSessOffsetMin` | int | 420 | Offset UTC → múi giờ phiên volume (HCM = +420) |
| 4 | `InpMaxBars` | int | 0 | 0 = toàn bộ; > 0 giới hạn replay để debug |

Giờ thị trường = `serverTime − InpSrvOffsetMin·60 + InpMktOffsetMin·60`.
Giờ phiên volume = `serverTime − InpSrvOffsetMin·60 + InpVolSessOffsetMin·60`.
Ngày/tuần server dùng trực tiếp `time[j]` (không cộng offset). Người dùng chỉnh offset khi DST đổi (D2).

#### 3.2 Nhóm logic (Pine 1:1)

| # | Input | Kiểu | Default | Clamp / Options |
|---:|---|---|---:|---|
| 5 | `InpSwingLen` | int | 5 | 2..20 |
| 6 | `InpRetestOn` | bool | true | — |
| 7 | `InpRetestBars` | int | 10 | 1..100 |
| 8 | `InpRetestTolAtr` | double | 0.5 | ≥ 0 |
| 9 | `InpFailOn` | bool | true | — |
| 10 | `InpFailBars` | int | 5 | 1..50 |
| 11 | `InpContOn` | bool | true | — |
| 12 | `InpPullOn` | bool | true | — |
| 13 | `InpEqTolAtr` | double | 0.05 | ≥ 0 |
| 14 | `InpPdOn` | bool | true | — |
| 15 | `InpPwOn` | bool | false | — |
| 16 | `InpSessOn` | bool | true | — |
| 17 | `InpSrLeft` | int | 10 | 2..50 |
| 18 | `InpSrRight` | int | 10 | 2..50 |
| 19 | `InpSrWidthAtr` | double | 0.5 | ≥ 0.05 |
| 20 | `InpSrMax` | int | 8 | 1..30 |
| 21 | `InpFvgMinAtr` | double | 0.3 | ≥ 0.05 |
| 22 | `InpFvgMax` | int | 20 | 1..50 |
| 23 | `InpFvgLife` | int | 100 | 10..500 |
| 24 | `InpObMax` | int | 20 | 1..50 |
| 25 | `InpPinRatio` | double | 2.0 | ≥ 1.0 |
| 26 | `InpEngulfOn` | bool | true | — |
| 27 | `InpPinOn` | bool | true | — |
| 28 | `InpDispOn` | bool | true | — |
| 29 | `InpDispAtr` | double | 1.5 | ≥ 0.5 |
| 30 | `InpRejOn` | bool | true | — |
| 31 | `InpIbOn` | bool | true | — |
| 32 | `InpDojiOn` | bool | true | — |
| 33 | `InpDojiMax` | double | 0.10 | 0.01..0.5 |
| 34 | `InpSoldOn` | bool | true | — |
| 35 | `InpStrongBody` | double | 0.50 | 0.1..0.95 |
| 36 | `InpVolVetoOn` | bool | true | — |
| 37 | `InpVolVetoR` | double | 1.2 | ≥ 0.5 |
| 38 | `InpStreakOn` | bool | true | — |
| 39 | `InpStreakMin` | int | 2 | 2..5 |
| 40 | `InpStreakAdd` | double | 0.5 | 0..2 |
| 41 | `InpEmaFast` | int | 20 | 2..500 |
| 42 | `InpEmaMid` | int | 50 | 5..500 |
| 43 | `InpEmaSlow` | int | 200 | 10..500 |
| 44 | `InpAtrLen` | int | 14 | 1..200 |
| 45 | `InpRsiLen` | int | 14 | 2..200 |
| 46 | `InpRsiOb` | double | 70 | 50..99 |
| 47 | `InpRsiOs` | double | 30 | 1..50 |
| 48 | `InpMacdFast` | int | 12 | 2..200 |
| 49 | `InpMacdSlow` | int | 26 | 5..200 |
| 50 | `InpMacdSignal` | int | 9 | 1..200 |
| 51 | `InpDmiLen` | int | 14 | 2..200 |
| 52 | `InpDmiSmooth` | int | 14 | 2..200 |
| 53 | `InpAdxMin` | double | 20 | 0..100 |
| 54 | `InpBbLen` | int | 20 | 2..200 |
| 55 | `InpBbMult` | double | 2.0 | ≥ 0.5 |
| 56 | `InpRvLen` | int | 20 | 2..200 |
| 57 | `InpRvMin` | double | 1.2 | ≥ 0.5 |
| 58 | `InpObvLen` | int | 20 | 2..200 |
| 59 | `InpVolMaLen` | int | 20 | 5..100 |
| 60 | `InpVolSpikeR` | double | 2.2 | ≥ 1.5 |
| 61 | `InpVolRVH` | double | 1.8 | ≥ 1.0 |
| 62 | `InpVolRH` | double | 1.2 | ≥ 0.8 |
| 63 | `InpVolRN` | double | 0.8 | ≥ 0.4 |
| 64 | `InpVolRL` | double | 0.4 | ≥ 0.1 |
| 65 | `InpVolMin` | double | 0.0 | ≥ 0; 0 = tắt |
| 66 | `InpVolSessOn` | bool | false | — |
| 67 | `InpVolSessStartMin` | int | 480 | 0..1439 |
| 68 | `InpVolSessEndMin` | int | 960 | 0..1439 |
| 69 | `InpCtxTf` | enum `ENUM_TIMEFRAMES` | `PERIOD_D1` | chỉ H4/D1/W1/MN1 |
| 70 | `InpCtxLen` | int | 200 | 10..500 |
| 71 | `InpSetupTf` | enum `ENUM_TIMEFRAMES` | `PERIOD_H1` | chỉ M15/H1 |
| 72 | `InpSetupLen` | int | 50 | 5..500 |
| 73 | `InpHtfFilter` | bool | true | — |
| 74 | `InpHtfVetoOn` | bool | true | — |
| 75 | `InpWTrend` | double | 15 | ≥ 0 |
| 76 | `InpWStruct` | double | 15 | ≥ 0 |
| 77 | `InpWLiq` | double | 12 | ≥ 0 |
| 78 | `InpWLoc` | double | 8 | ≥ 0 |
| 79 | `InpWSr` | double | 10 | ≥ 0 |
| 80 | `InpWCandle` | double | 10 | ≥ 0 |
| 81 | `InpWVol` | double | 8 | ≥ 0 |
| 82 | `InpWAtr` | double | 7 | ≥ 0 |
| 83 | `InpWMom` | double | 7 | ≥ 0 |
| 84 | `InpWSess` | double | 4 | ≥ 0 |
| 85 | `InpWMtf` | double | 4 | ≥ 0 |
| 86 | `InpScrNoTrade` | int | 49 | 0..99 |
| 87 | `InpScrWeak` | int | 64 | 1..99 |
| 88 | `InpScrSetup` | int | 74 | 1..99 |
| 89 | `InpScrStrong` | int | 84 | 1..99 |
| 90 | `InpSlAtrMul` | double | 1.5 | ≥ 0.1 |
| 91 | `InpSlSwing` | int | 10 | 2..100 |
| 92 | `InpSlPadAtr` | double | 0.2 | ≥ 0 |
| 93 | `InpSlMinAtr` | double | 0.5 | ≥ 0.1 |
| 94 | `InpSlMaxAtr` | double | 3.0 | ≥ 0.5 |
| 95 | `InpRr1` | double | 1.0 | ≥ 0.1 |
| 96 | `InpRr2` | double | 2.0 | ≥ 0.1 |
| 97 | `InpRr3` | double | 3.0 | ≥ 0.1 |
| 98 | `InpRrMin` | double | 1.5 | ≥ 0 |
| 99 | `InpMaxDay` | int | 3 | ≥ 1 |
| 100 | `InpCoolBars` | int | 10 | ≥ 0 |
| 101 | `InpTpMode` | enum `ENUM_PA_TP_MODE` | `PA_TP_R` | R / Measured move |
| 102 | `InpTpMmFallback` | bool | true | — |
| 103 | `InpRegOn` | bool | true | — |
| 104 | `InpRegAdxTrend` | double | 25 | 5..60 |
| 105 | `InpRegAdxChop` | double | 18 | 5..60 |
| 106 | `InpRegBbwLen` | int | 100 | 20..500 |
| 107 | `InpRegBbwSqueeze` | double | 20 | 1..60 |
| 108 | `InpRegRangeEdge` | double | 0.35 | 0..2 |
| 109 | `InpPatOn` | bool | true | — |
| 110 | `InpPatBandAtr` | double | 0.5 | 0.1..3.0 |
| 111 | `InpPatMaxBars` | int | 200 | 20..1000 |
| 112 | `InpHsRatio` | double | 1.2 | 1.0..3.0 |
| 113 | `InpCfOn` | bool | true | — |
| 114 | `InpCfLevelTolAtr` | double | 0.5 | 0.1..3.0 |
| 115 | `InpCfRequire3` | bool | true | — |

Ràng buộc init (fail-fast trong `OnInit`): `InpCtxTf ∈ {H4,D1,W1,MN1}`,
`InpSetupTf ∈ {M15,H1}`, `InpEmaFast < InpEmaMid < InpEmaSlow` không bắt buộc (Pine không ép),
`InpSrMax ≤ 30`, `InpFvgMax ≤ 50`, `InpObMax ≤ 50`, `InpPatMaxBars ≤ 1000`.

### 4. Enum

```cpp
enum ENUM_PA_TP_MODE { PA_TP_R = 0, PA_TP_MM = 1 };

enum ENUM_PA_QUALITY { PA_Q_NOTRADE=0, PA_Q_WEAK=1, PA_Q_SETUP=2,
                       PA_Q_STRONG=3, PA_Q_APLUS=4 };
enum ENUM_PA_REGIME  { PA_REG_RANGING=0, PA_REG_TRENDING=1, PA_REG_CHOPPY=2 };
enum ENUM_PA_PATTERN { PA_PAT_NONE=0, PA_PAT_DT=1, PA_PAT_DB=2,
                       PA_PAT_HST=3, PA_PAT_HSN=4 };
enum ENUM_PA_BUCKET  { PA_BUCKET_VERYLOW=0, PA_BUCKET_LOW=1, PA_BUCKET_NORMAL=2,
                       PA_BUCKET_HIGH=3, PA_BUCKET_VERYHIGH=4, PA_BUCKET_TIM=5 };
enum ENUM_PA_SESSION { PA_SESS_NONE=0, PA_SESS_ASIA=1, PA_SESS_LONDON=2,
                       PA_SESS_NY=3, PA_SESS_LONDON_NY=4 };
enum ENUM_PA_CLOSE   { PA_CLOSE_NONE=0, PA_CLOSE_TP3=1, PA_CLOSE_SL=2,
                       PA_CLOSE_TIMEOUT=3 };
enum ENUM_PA_BLOCK   { PA_BLOCK_NONE=0, PA_BLOCK_PLAN_INVALID=1, PA_BLOCK_MTF_FILTER=2,
                       PA_BLOCK_HTF_VETO=3, PA_BLOCK_COOLDOWN=4, PA_BLOCK_DAY_LIMIT=5,
                       PA_BLOCK_SCORE=6, PA_BLOCK_DIR=7, PA_BLOCK_CONFLUENCE=8,
                       PA_BLOCK_REGIME=9 };
```

Chú ý: `PA_TP_MM` chỉ có nghĩa "Measured move", không phải "multi-timeframe".

### 5. Signal ID và loại buffer

| ID | Ý nghĩa | Buffer | Trigger | Loại |
|---|---|---|---|---|
| `PA_LONG` | Tín hiệu long đã qua mọi gate | 24 | `sigLong` | Edge |
| `PA_SHORT` | Tín hiệu short đã qua mọi gate | 25 | `sigShort` | Edge |
| `PA_ENTRY` | Vị thế được adopt | 27 | `evEntry` | Edge |
| `PA_TP1` | Chạm TP1 lần đầu | 28 | `evTp1` | Edge |
| `PA_TP2` | Chạm TP2 lần đầu | 29 | `evTp2` | Edge |
| `PA_TP3` | Chạm TP3 (đóng, win) | 30 | `evTp3` | Edge |
| `PA_SL` | Chạm SL (đóng, loss) | 31 | `evSl` | Edge |
| `PA_CLOSE` | Đóng vị thế (mọi lý do) | 32 | `evClose` | Edge |

`PA_LONG/PA_SHORT` **khác** `PA_ENTRY`: tín hiệu có thể xuất hiện khi đang mở vị thế
(`posDir != 0`) và bị bỏ qua ở bước adopt (§11). `PA_ENTRY` chỉ khi `posDir == 0`.

### 6. Buffer

`#property indicator_buffers 107`, `#property indicator_plots 12`; plot `i` map buffer `i`
(0..11). Buffer 12..106 là `INDICATOR_CALCULATIONS`.

#### 6.1 Render buffers 0..11 (DATA, ngoài hợp đồng EA)

| # | Tên | Giá trị | Thiếu | Kiểu vẽ |
|---:|---|---|---|---|
| 0 | `PLOT_EMA_FAST` | `emaF` | `EMPTY_VALUE` | Line |
| 1 | `PLOT_EMA_MID` | `emaM` | `EMPTY_VALUE` | Line |
| 2 | `PLOT_EMA_SLOW` | `emaS` | `EMPTY_VALUE` | Line |
| 3 | `PLOT_VWAP` | `vwap` | `EMPTY_VALUE` | Line |
| 4 | `PLOT_VOLUME` | `tick_volume` | 0 | Histogram |
| 5 | `PLOT_VOLUME_MA` | `volMA` | `EMPTY_VALUE` | Line |
| 6 | `PLOT_LONG_ENTRY` | `low` nến `evEntry && posDir==1` | `EMPTY_VALUE` | Arrow 233 |
| 7 | `PLOT_SHORT_ENTRY` | `high` nến `evEntry && posDir==-1` | `EMPTY_VALUE` | Arrow 234 |
| 8 | `PLOT_HIT_TP` | `high` nến `evTp1/2/3` | `EMPTY_VALUE` | Arrow 159 |
| 9 | `PLOT_HIT_SL` | `low` nến `evSl` | `EMPTY_VALUE` | Arrow 251 |
| 10 | `PLOT_ACTIVE_SL` | `posDir!=0 ? posSl : EMPTY` | `EMPTY_VALUE` | Line |
| 11 | `PLOT_ACTIVE_TP1` | `posDir!=0 ? posTp1 : EMPTY` | `EMPTY_VALUE` | Line |

EMA/VWAP/volume luôn vẽ, không gate `showEma/showVwap/showVol` (D8). Không vẽ TP2/TP3
(contract buffer 21/22). Không vẽ box/label/dashboard/trendline (P12).

#### 6.2 Contract buffers 12..106 (95)

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA dùng |
|---:|---|---|---|---|---|---|
| 12 | `SCORE100` | `round(50 + raw*50)` | 0..100 | — | Bar | audit |
| 13 | `DIR` | Hướng điểm | −1/0/1 | 0 | Bar | **có** |
| 14 | `QUALITY` | `ENUM_PA_QUALITY` | 0..4 | 0 | Bar | audit |
| 15 | `CONFLUENCE` | `cf1+cf2+cf3` | 0..3 | 0 | Bar | audit |
| 16 | `REGIME` | `ENUM_PA_REGIME` | 0..2 | 0 | Bar | audit |
| 17 | `PLAN_VALID` | `plan.valid` | 0/1 | 0 | Bar | **có** |
| 18 | `ENTRY` | `plan.entry` (= `close`) | giá | — | Bar | **có** |
| 19 | `SL` | `plan.sl` | giá | `EMPTY_VALUE` | Bar | **có** |
| 20 | `TP1` | `plan.tp1` | giá | `EMPTY_VALUE` | Bar | **có** |
| 21 | `TP2` | `plan.tp2` | giá | `EMPTY_VALUE` | Bar | **có** |
| 22 | `TP3` | `plan.tp3` | giá | `EMPTY_VALUE` | Bar | **có** |
| 23 | `RISK` | `plan.risk` (khoảng cách SL) | > 0 | `EMPTY_VALUE` | Bar | **có** |
| 24 | `SIG_LONG` | `sigLong` | 0/1 | 0 | Edge | **có** |
| 25 | `SIG_SHORT` | `sigShort` | 0/1 | 0 | Edge | **có** |
| 26 | `BLOCK` | Lý do chặn đầu tiên | 0..9 | 0 | Bar | audit |
| 27 | `EV_ENTRY` | Adopt vị thế | 0/1 | 0 | Edge | **có** |
| 28 | `EV_TP1` | TP1 chạm | 0/1 | 0 | Edge | **có** |
| 29 | `EV_TP2` | TP2 chạm | 0/1 | 0 | Edge | **có** |
| 30 | `EV_TP3` | TP3 chạm (đóng) | 0/1 | 0 | Edge | **có** |
| 31 | `EV_SL` | SL chạm (đóng) | 0/1 | 0 | Edge | **có** |
| 32 | `EV_CLOSE` | Đóng vị thế | 0/1 | 0 | Edge | **có** |
| 33 | `CLOSE_REASON` | `ENUM_PA_CLOSE` | 0..3 | 0 | Bar | audit |
| 34 | `POS_DIR` | Hướng vị thế | −1/0/1 | 0 | State | **có** |
| 35 | `POS_ENTRY` | `posEntry` | giá | `EMPTY_VALUE` | State | **có** |
| 36 | `POS_SL` | `posSl` | giá | `EMPTY_VALUE` | State | **có** |
| 37 | `POS_TP1` | `posTp1` | giá | `EMPTY_VALUE` | State | **có** |
| 38 | `POS_TP2` | `posTp2` | giá | `EMPTY_VALUE` | State | **có** |
| 39 | `POS_TP3` | `posTp3` | giá | `EMPTY_VALUE` | State | **có** |
| 40 | `POS_RISK` | `posRisk` | giá | `EMPTY_VALUE` | State | audit |
| 41 | `POS_STAGE` | TP đã chạm | 0..3 | 0 | State | **có** |
| 42 | `POS_BARS` | Số nến giữ lệnh | ≥ 0 | 0 | State | audit |
| 43 | `DAY_COUNT` | Số lệnh trong ngày | ≥ 0 | 0 | State | audit |
| 44 | `BARS_SINCE` | Cooldown counter | ≥ 0 | 0 | State | audit |
| 45 | `TRADES` | Tổng trade đã đóng | ≥ 0 | 0 | State | audit |
| 46 | `WINS` | Trade win (TP3) | ≥ 0 | 0 | State | audit |
| 47 | `LOSSES` | Trade loss (SL) | ≥ 0 | 0 | State | audit |
| 48 | `TREND` | `pa_trend` | −1/0/1 | 0 | Bar | audit |
| 49 | `BOS_UP` | BOS bull nến này | 0/1 | 0 | Bar | audit |
| 50 | `BOS_DOWN` | BOS bear | 0/1 | 0 | Bar | audit |
| 51 | `CHOCH_UP` | CHoCH bull | 0/1 | 0 | Bar | audit |
| 52 | `CHOCH_DOWN` | CHoCH bear | 0/1 | 0 | Bar | audit |
| 53 | `MSS_UP` | MSS bull | 0/1 | 0 | Bar | audit |
| 54 | `MSS_DOWN` | MSS bear | 0/1 | 0 | Bar | audit |
| 55 | `RETEST_UP` | Retest bull | 0/1 | 0 | Bar | audit |
| 56 | `RETEST_DOWN` | Retest bear | 0/1 | 0 | Bar | audit |
| 57 | `FAIL_UP` | Failed breakout bull | 0/1 | 0 | Bar | audit |
| 58 | `FAIL_DOWN` | Failed breakout bear | 0/1 | 0 | Bar | audit |
| 59 | `SWEEP_UP` | Liquidity sweep bull | 0/1 | 0 | Bar | audit |
| 60 | `SWEEP_DOWN` | Liquidity sweep bear | 0/1 | 0 | Bar | audit |
| 61 | `HH` | Higher high | 0/1 | 0 | Bar | audit |
| 62 | `HL` | Higher low | 0/1 | 0 | Bar | audit |
| 63 | `LH` | Lower high | 0/1 | 0 | Bar | audit |
| 64 | `LL` | Lower low | 0/1 | 0 | Bar | audit |
| 65 | `CONT_UP` | Continuation bull | 0/1 | 0 | Bar | audit |
| 66 | `CONT_DOWN` | Continuation bear | 0/1 | 0 | Bar | audit |
| 67 | `PULL_UP` | Pullback bull | 0/1 | 0 | Bar | audit |
| 68 | `PULL_DOWN` | Pullback bear | 0/1 | 0 | Bar | audit |
| 69 | `PATTERN` | Pattern vừa phá neckline | 0..4 | 0 | Bar | audit |
| 70 | `PATTERN_DIR` | Hướng pattern | −1/0/1 | 0 | Bar | audit |
| 71 | `PATTERN_HEIGHT` | `patHeight` tồn tại | ≥ 0 | 0 | State | audit |
| 72 | `CANDLE_SCORE` | `cpScore` | −1..1 | 0 | Bar | audit |
| 73 | `ATR` | `atr` (Wilder) | > 0 | `EMPTY_VALUE` | Bar | **có** |
| 74 | `ATR_PCT` | `atr/close*100` | > 0 | `EMPTY_VALUE` | Bar | audit |
| 75 | `RSI` | RSI | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 76 | `MACD_HIST` | MACD histogram | giá | `EMPTY_VALUE` | Bar | audit |
| 77 | `ADX` | ADX | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 78 | `DI_PLUS` | DI+ | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 79 | `DI_MINUS` | DI− | 0..100 | `EMPTY_VALUE` | Bar | audit |
| 80 | `BB_WIDTH` | BBW `%` | ≥ 0 | `EMPTY_VALUE` | Bar | audit |
| 81 | `VOL_RATIO` | `vol/volMA` | ≥ 0 | 0 | Bar | audit |
| 82 | `REL_VOL` | `vol/SMA(vol,rvLen)` | ≥ 0 | 0 | Bar | audit |
| 83 | `OBV_SLOPE` | `obv − obv[lag]` | giá trị | 0 | Bar | audit |
| 84 | `VWAP` | VWAP phiên | giá | `EMPTY_VALUE` | Bar | audit |
| 85 | `PDH` | High ngày trước | giá | `EMPTY_VALUE` | Bar | audit |
| 86 | `PDL` | Low ngày trước | giá | `EMPTY_VALUE` | Bar | audit |
| 87 | `PWH` | High tuần trước | giá | `EMPTY_VALUE` | Bar | audit |
| 88 | `PWL` | Low tuần trước | giá | `EMPTY_VALUE` | Bar | audit |
| 89 | `SESS_HI` | Session high | giá | `EMPTY_VALUE` | Bar | audit |
| 90 | `SESS_LO` | Session low | giá | `EMPTY_VALUE` | Bar | audit |
| 91 | `VOL_BUCKET` | VSA bucket | 0..5 | 0 | Bar | audit |
| 92 | `SESS_NAME` | Phiên hiện tại | 0..4 | 0 | Bar | audit |
| 93 | `MTF_CTX_DIR` | Bias context TF | −1/0/1 | 0 | Bar | audit |
| 94 | `MTF_SETUP_DIR` | Bias setup TF | −1/0/1 | 0 | Bar | audit |
| 95 | `HTF_VETO` | Veto đang bật (giá trị thực) | 0/1 | 0 | Bar | audit |
| 96 | `CF1` | Trend khung lớn đúng chiều | 0/1 | 0 | Bar | audit |
| 97 | `CF2` | Giá tại level | 0/1 | 0 | Bar | audit |
| 98 | `CF3` | Nến xác nhận | 0/1 | 0 | Bar | audit |
| 99 | `NEAR_SUPPORT` | `f_nearSupport(zones, atr)` | 0/1 | 0 | Bar | audit |
| 100 | `NEAR_RESISTANCE` | `f_nearResistance(zones, atr)` | 0/1 | 0 | Bar | audit |
| 101 | `NEAR_FVG_BULL` | Gần FVG/OB bull | 0/1 | 0 | Bar | audit |
| 102 | `NEAR_FVG_BEAR` | Gần FVG/OB bear | 0/1 | 0 | Bar | audit |
| 103 | `SWING_LO` | `lowest(low, slSwing)` | giá | `EMPTY_VALUE` | Bar | audit |
| 104 | `SWING_HI` | `highest(high, slSwing)` | giá | `EMPTY_VALUE` | Bar | audit |
| 105 | `LAST_HIGH` | Pivot high gần nhất | giá | `EMPTY_VALUE` | State | audit |
| 106 | `LAST_LOW` | Pivot low gần nhất | giá | `EMPTY_VALUE` | State | audit |

Quy ước:

- Buffer edge = `0.0` trên nến không có sự kiện; **không** dùng `EMPTY_VALUE`.
- `ENTRY/SL/TP1/TP2/TP3/RISK` là **plan của chính nến đó**, không phải state vị thế.
  Pine luôn gọi `f_buildPaPlan(pa_dir)` kể cả khi `dir = 0` hoặc plan invalid:
  - `ENTRY` luôn = `close` (kể cả khi không có tín hiệu) → EA **phải** gate `PLAN_VALID`.
  - Khi `dir = 0` và TP mode R, `TP1..TP3` = `entry + 0*rr*risk` = **entry** (không EMPTY).
  - Khi TP mode MM, thiếu `mmDist` và `InpTpMmFallback=false` → `TP1..TP3 = EMPTY_VALUE`
    nhưng plan vẫn có thể `valid` (§10.4).
- `POS_*` là state của vị thế đang mở; `EMPTY_VALUE` khi `POS_DIR == 0`, **trừ** nến đóng
  lệnh: trong nến đó `POS_DIR` vẫn giữ hướng cũ và levels còn giá trị, vì deferred reset chạy
  ở nến sau (§11.1).
- `PATTERN_HEIGHT` khởi tạo `0.0` và chỉ đổi khi có pattern break → có thể mang giá trị cũ
  nhiều nến trước (§9.5).
- `VOL_RATIO/REL_VOL` = 0 khi mẫu số chưa có/≤ 0 (khớp Pine `0.0`).
- `POS_BARS` đếm số nến giữ lệnh, không tính nến entry (§11.4).
- Tại nến đang chạy (`j == rates_total-1`) toàn bộ buffer = 0/`EMPTY_VALUE`; EA đọc `shift=1`.

### 7. Bar policy và state

Mỗi lần `rates_total` thay đổi (nến mới), indicator **reset state và replay từ bar 0** tới
`rates_total-2`. Trong cùng một nến, trả `rates_total` ngay. Hệ quả:

- Mọi buffer của nến đã đóng là hàm thuần của dữ liệu đã đóng → không RP2.
- Không có state ẩn sống qua lần gọi; reload indicator cho cùng kết quả.
- Chi phí O(n) mỗi nến; pattern/zone/FVG/OB cap nhỏ, neckline dùng mảng trực tiếp.

#### 7.1 `PaEngineState`

```cpp
#define PA_MAX_SR   30
#define PA_MAX_FVG  50
#define PA_MAX_OB   50
#define PA_MAX_PAT  30
#define PA_PIV_HIST 4
#define PA_OBV_MAX  202   // InpObvLen tối đa 200 + 2

struct PaSrZone  { double top, bot; int side, touches; bool broken; };
struct PaFvg     { double top, bot; int srcBar, dir; bool dead; };
struct PaOb      { double top, bot; int srcBar, dir; bool dead; };
struct PaPattern { int kind, dir; double a, b, c, neck; int aBar, bBar, cBar;
                   bool broken; int brkBar; };

struct PaEngineState
{
   // structure
   double lastHigh, prevHigh, lastLow, prevLow, brkLevel;
   int    lastHighBar, lastLowBar, trend, brkDir, brkBar;
   bool   hasLastHigh, hasLastLow, hasPrevHigh, hasPrevLow, hasBrk;
   // trendline pivots (2 mỗi phía)
   double tl1Lo, tl2Lo, tl1Hi, tl2Hi;
   int    tl1LoB, tl2LoB, tl1HiB, tl2HiB;
   bool   hasTl1Lo, hasTl2Lo, hasTl1Hi, hasTl2Hi;
   // session
   double sessHi, sessLo; int sessPrev; bool hasSessHi, hasSessLo;
   // patterns
   PaPattern pats[PA_MAX_PAT]; int patCount;
   double hiPx[PA_PIV_HIST], loPx[PA_PIV_HIST];
   int    hiBar[PA_PIV_HIST], loBar[PA_PIV_HIST], hiCount, loCount;
   double patHeight;                     // var, khởi tạo 0.0
   // zones
   PaSrZone sr[PA_MAX_SR]; int srCount;
   PaFvg    fvg[PA_MAX_FVG]; int fvgCount;
   PaOb     ob[PA_MAX_OB]; int obCount;
   // candle streak
   int engulfStreak;
   // OBV window
   double obv; double obvHist[PA_OBV_MAX]; int obvCount, obvBar;
   // day / week
   int dayStamp, weekStamp; double curDayHi, curDayLo, curWeekHi, curWeekLo;
   double pdh, pdl, pwh, pwl; bool hasPd, hasPw;
   // VWAP
   int vwapStamp; double vwapPV, vwapVol; bool hasVwap;
   // gating
   int dayCount, barsSince;
   // position
   int posDir, posStage, posBar, posBars;
   double posEntry, posSl, posTp1, posTp2, posTp3, posRisk;
   bool needReset;
   // last closed trade
   double xEntry, xSl, xExit, xR; int xDir, xBar;
   // stats
   int trades, wins, losses;
   // out events của nến hiện tại
   bool evEntry, evTp1, evTp2, evTp3, evSl, evClose; int closeReason;
};
```

`PaStateInit` gán: `trend=0`, `patHeight=0`, `barsSince=999999`, `dayCount=0`,
`dayStamp/weekStamp = -1`, `sessPrev=-1`, `posDir=0`, `posBars=0`, `needReset=false`,
counters = 0, `has* = false`.

#### 7.2 Series precompute (pass 1)

Các chuỗi sau tính một lần trên toàn bộ `rates_total` (giá trị tại mỗi bar đóng):

| Chuỗi | Công thức | Warm-up |
|---|---|---|
| `tr` | `max(h-l, |h-c1|, |l-c1|)`, bar 0 = `h-l` | bar 0 |
| `atr` | RMA(tr, `atrLen`) | `atrLen` |
| `volMA` | RMA(vol, `volMaLen`) | `volMaLen` |
| `volSma` | SMA(vol, `rvLen`) | `rvLen` |
| `emaF/M/S` | EMA(close, len), seed SMA(len) | len |
| `swingLo/Hi` | rolling min(low)/max(high), `slSwing` | `slSwing` |
| `pivH/pivL` | strict `swingLen` hai phía; xác nhận tại `c`, giá trị `high[c-len]` | `2·swingLen+1` |
| `srPivH/srPivL` | strict `srLeft/srRight` | `srLeft+srRight+1` |
| `rsi` | Wilder RSI(`rsiLen`) | `rsiLen+1` |
| `macdHist` | EMA(f)-EMA(s), signal EMA | `macdSlow+macdSignal-1` |
| `diPlus/diMinus/adx` | Wilder DMI(`dmiLen`), ADX RMA(`dmiSmooth`) | `dmiLen+dmiSmooth-1` |
| `bbMid/bbUp/bbLo` | SMA ± mult·**population** stdev | `bbLen` |
| `bbWidth` | `(up-lo)/mid*100` | `bbLen` |
| `bbWidthMA` | SMA(bbWidth, `bbLen`) | `2·bbLen-1` |
| `atrMA` | SMA(atr, 20) | `atrLen+19` |
| `vwap` | Σ(c·vol)/Σvol, reset đầu ngày server | 1 bar có vol |
| `pdh/pdl` | high/low cả ngày server trước | 1 ngày đủ |
| `pwh/pwl` | high/low tuần server trước (thứ Hai) | 1 tuần đủ |
| `htfCtxEma/htfSetupEma` | EMA trên close HTF đã đóng | `ctxLen/setupLen` |

`bbwPct` (percentile BBW) tính trong pass 2 bằng deque rolling min/max `regBbwLen` (O(1)
amortized), không cần mảng phụ.

### 8. Engine pipeline (mỗi nến đóng, thứ tự bắt buộc)

```text
PaEngineStep(cfg, st, bar, barIndex, out):
  0. Reset edge flags: bos*/choch*/mss*/retest*/fail*/cont*/pull*/sweep*/hh/hl/lh/ll,
     evEntry/evTp1/evTp2/evTp3/evSl/evClose, closeReason, patSignal.
  1. L1  volRatio, volBucket, isTim, relVol, obv (cộng dồn), obvSlope, candle metrics,
         dispBull/Bear, sessName, sessScore, atrPct
  2. L2  pivot processing (BOS/CHoCH, prev*), MSS, HH/HL/LH/LL, retest, fail,
         pattern history + detect + shoulder-3 + trim, neckline break, patNeck/kind/dir,
         patHeight, cont, pull
  3. L3  session HL update, equal hi/lo, sweep (PD → PW → session → equal),
         trendline pivot shift + tlUpAt/tlDnAt
  4. L4  S/R add (pivot high side -1 trước, pivot low side +1 sau),
         FVG push (bull trước, bear sau) → trim → dead,
         OB push (bull trước, bear sau) → trim → dead, nearFvg flags
  5. L5  pin, engulf, dispV, rej, IB, doji, 3S/3C, volVeto, streak, cpScore
  6. L6  rsiScore, macdScore, dmiScore, momScore, atrRegime, bb expand, volScore,
         volumeScore, vwapScore, dayRange, locationScore, trendScore
  7. L7  ctxDir, setupDir, gMtfBias
  8. L8  11 group → raw → score100/dir/quality; okSetup/htfVeto/okMtf;
         bbwPct → regime → nearRangeEdge → okRegime;
         cf1/cf2/cf3 → confluence → okConfluence
  9. L9  plan, day reset (trước gate), barsSince++, gates, block, signal
 10. L10 state machine: deferred reset → exits → accounting → entry (chỉ khi flat)
 11. Ghi out; cập nhật state phụ (lastHigh/Low, sessPrev, x*, counters)
```

Thứ tự nội bộ bắt buộc:

- MSS sau BOS/CHoCH, trước HH/HL (dùng `dispBull/Bear` của cùng nến).
- Equal hi/lo dùng `prevHigh/prevLow` **đã cập nhật** bởi pivot của cùng nến.
- Sweep chạy sau session HL update (quan trọng, xem Q3 §16).
- S/R register thứ tự high → low; mỗi lần register đều purge zone `broken` (không bao giờ có
  trong port) và trim `srMax`.
- FVG/OB: push trước, trim sau, dead-mark sau cùng; near flags quét **sau** dead-mark.
- Pattern: push pivot vào history → detect → shoulder-3 → trim 30 → break loop → patNeck →
  patHeight.
- `barsSince` tăng **trước** gate; reset 0 khi entry (cuối nến).
- Deferred reset chạy **trước** mọi xử lý vị thế trong nến (bước 0b), không phải đầu nến kế
  tiếp về mặt code — xem §11.1.

### 9. Chi tiết thuật toán

#### 9.1 S/R zones (P5)

```text
PaZoneAdd(px, side, atr, width, maxZones):
  half = atr*width*0.5
  for i = 0..count-1:
      if |(top+bot)/2 − px| < atr*width:      // KHÔNG kiểm tra side
          touches += 1; return               // không đổi top/bot/side
  if count < PA_MAX_SR: push {top=px+half, bot=px-half, side, touches=1, broken=false}
  compact bỏ broken (port: không bao giờ có)
  while count > maxZones: shift()
```

- Merge **không** kiểm tra `side` → pivot resistance có thể bị hút vào zone support đứng
  trước (quirk Pine, Q4). Thứ tự register quyết định kết quả.
- `broken` chỉ được set trong block `barstate.islast` của Pine, phụ thuộc 3 toggle hiển thị →
  RP2/RP5. Port **không** set broken (P5), nên zone chỉ bị loại bởi `srMax`.
- `f_nearSupport(zones, atrArg)`: tồn tại zone `side==1`, `!broken`,
  `low >= bot − atrArg*0.3 && low <= top + atrArg*0.3`. `f_nearResistance` đối xứng với
  `high`, `side==-1`.
- **Hệ số 0.3 bên trong hàm là cố định**, không phải input: caller truyền `atr*0.35`
  (regime) hoặc `atr*cfLevelTol` (confluence) → tolerance thực tế là `0.105·ATR` và
  `0.15·ATR` (Q1).

#### 9.2 Structure

- Pivot strict: `pivH` khi `high[c] > max(high[c−len..c−1])` và `> max(high[c+1..c+len])`
  (tương đương `ta.pivothigh(high, len, len)`); xác nhận tại bar `c`, giá trị `high[c−len]`,
  `bar = c−len`.
- Khi có pivot high mới, `lastHigh` cũ:
  - `trend <= 0 && close > lastHigh` → BOS up; set `trend=1`, `brkLevel=lastHigh`,
    `brkDir=1`, `brkBar=newHBar`.
  - `trend < 0 && newH > lastHigh` → CHoCH up; cùng cách set.
  - Luôn `prevHigh = lastHigh` trước khi gán `lastHigh = newH`.
- Pivot low đối xứng (`trend >= 0 && close < lastLow` → BOS down;
  `trend > 0 && newL < lastLow` → CHoCH down).
- MSS: `(bosUp||chochUp) && dispBull` → `mssUp`; đối xứng bear.
- HH/LH dùng `high[swingLen]` vs `prevHigh`; HL/LL dùng `low[swingLen]` vs `prevLow`.
- Retest: `brkDir==1 && barIndex−brkBar <= retestBars && low <= brkLevel + retestTol*ATR
  && close > brkLevel`; bear đối xứng.
- Fail: `brkDir==-1 && barIndex−brkBar <= failBars && close > brkLevel` (bull);
  bear đối xứng (`brkDir==1 && close < brkLevel`).
- Cont: `trend==1 && HH` (bull) / `trend==-1 && LL` (bear).
- Pull: `trend==1 && low <= emaM && close > emaM` (bull) / bear đối xứng.

#### 9.3 Liquidity

- `PDH/PDL` = high/low của **ngày server trước**; `PWH/PWL` = tuần server trước (thứ Hai).
- Session (giờ thị trường): Asia `[17:00,02:00)`, London `[02:00,10:00)`,
  NY `[07:00,15:00)`; name ưu tiên `London/NY` → `NY` → `London` → `Asia` → `-`.
- `sessHi/Lo`:
  ```text
  changed = (name != sessPrev)
  if changed && name != NONE:   sessHi=high; sessLo=low
  else if name != NONE:         sessHi=max(sessHi,high); sessLo=min(sessLo,low)
  if name != NONE:              sessPrev=name
  ```
  Khi `name == NONE`, cả mức và `sessPrev` giữ nguyên (Q3).
- Equal high: `pivH && prevHigh valid && |high[swingLen] − prevHigh| <= eqTol*ATR`.
- Sweep bull = OR của 4 nhánh, theo thứ tự PD → PW → session → equal:
  ```text
  sweepBull = (pdOn  && low < pdl && close > pdl)
           || (pwOn  && low < pwl && close > pwl)
           || (sessOn && sessLo valid && low < sessLo && close > sessLo)
           || (eqLo  && low[swingLen] < prevLow && close > prevLow)
  sweepBear = (pdOn  && high > pdh && close < pdh)
           || (pwOn  && high > pwh && close < pwh)
           || (sessOn && sessHi valid && high > sessHi && close < sessHi)
           || (eqHi  && high[swingLen] > prevHigh && close < prevHigh)
  ```
- Trendline: 2 pivot gần nhất mỗi phía; `slope=(y2−y1)/(b2−b1)`; giá trị tại bar hiện tại
  `y1 + slope·(barIndex−b1)`; chỉ dùng cho confluence. Touch counters bỏ (viz-only).

#### 9.4 MTF mapping (P4)

```text
chartOpenTime = time[j]
k = max{ i : htfCloseTime[i] <= chartOpenTime },  htfCloseTime[i] = htfTime[i] + PeriodSeconds(htfTf)
nếu không có k → EMPTY_VALUE
```

- Dùng **open time** của nến chart (KHÔNG phải close time). Khác contract TM Fusion Zones
  (nguồn đó dùng `lookahead_off` không `[1]` → close time). PA dùng `[1] + lookahead_on`:
  tại nến chart thuộc bar HTF `n`, giá trị là bar `n−1` đã đóng, tức `close_{n−1} <= open_j`.
- `ctxDir = (close > ctxEma) ? 1 : -1` khi EMA valid, ngược lại 0. **Bằng nhau → −1**
  (Pine không có nhánh `==`), Q6.
- `setupDir` tương tự. `gMtfBias = (ctxDir + setupDir)/2`.
- `okSetup = !htfFilter || setupDir == 0 || setupDir == dir`;
  `htfVeto = htfVetoOn && ctxDir != 0 && dir != 0 && ctxDir != dir`;
  `okMtf = okSetup && !htfVeto`.
- EMA HTF: seed `SMA(len)` trên close HTF đã đóng, sau đó `alpha = 2/(len+1)`.
- `CopyRates(_Symbol, tf, 0, N, rates)`; loại bar đang chạy bằng close time. Không dùng
  `iMA`/`iBarShift`.
- Nếu `CopyRates` lỗi/thiếu bar → cả hai EMA coi như invalid → dir 0 (không phải bull+bear).

#### 9.5 Pattern (P8)

- History 4 pivot mỗi phía; buffer low/high 1200 nến (dùng mảng `low[]/high[]` trực tiếp,
  bounds-check; tương đương vì `fresh2` ≤ `patMaxBars` ≤ 1000 < 1200).
- DT: 2 pivot high cuối trong band `|h1−h2| <= patBand*ATR`, `barIndex−b1 <= patMaxBars`,
  neckline = low thấp nhất giữa `b1` và `b2` (không tính 2 đầu).
- HST: điều kiện DT + `h2 >= h1*hsRatio`, cùng neckline.
- DB/HSN đối xứng (neckline = high cao nhất giữa 2 pivot; HSN yêu cầu `l2 <= l1/hsRatio`).
- Shoulder 3: khi có ≥3 pivot và `|h1−h3| <= band` → gán `c/cBar` cho **mọi** HST còn
  `c==0` (không kiểm tra liên quan pattern); HSN tương tự.
- Trim pattern > 30 → shift.
- Break: `!broken && barIndex > bBar` và
  `(DT|HST) close < neck && close[1] >= neck`, `(DB|HSN) close > neck && close[1] <= neck`.
  Nhiều pattern có thể break cùng nến; cờ `dtBrk/dbBrk/hsTopBrk/hsBotBrk` OR.
- `patNeck/patKind/patDir` reset mỗi nến, lấy từ **pattern cuối trong mảng** nếu chưa broken.
- `patHeight = |close − patNeck|` chỉ khi có break và `patNeck` valid; là `var` → giữ nguyên
  đến lần gán kế tiếp (Q5).
- Pattern dir: DT/HST → bear; DB/HSN → bull.

#### 9.6 Zones phụ (FVG/OB)

- FVG bull: `low > high[2] && (low−high[2]) >= fvgMinAtr*ATR`; push `{top=low, bot=high[2],
  srcBar=barIndex, dir=1}`. FVG bear: `high < low[2] && (low[2]−high) >= fvgMinAtr*ATR`;
  push `{top=low[2], bot=high, dir=-1}`.
- Push bull trước bear; trim `> fvgMax` bằng shift; dead nếu `barIndex−srcBar > fvgLife`
  hoặc `(dir==1 && close < bot)` hoặc `(dir==-1 && close > top)`.
- OB bull: `dispBull && close[1] < open[1]` → `{top=max(open1,close1), bot=min(open1,close1),
  srcBar=barIndex−1, dir=1}`; bear đối xứng. Trim `obMax`; dead nếu quá 200 nến hoặc close
  xuyên vùng.
- `nearFvgBull`: FVG !dead và `low ∈ [bot−0.3ATR, top+0.3ATR]`, HOẶC OB dir=1 !dead tương tự.
  `nearFvgBear` dùng `high` và OB dir=−1.

### 10. Scoring, gate, plan

#### 10.1 Nhóm điểm (11 nhóm)

```text
gTrend  = trendScore
gStruct = (bosUp||chochUp||mssUp) ? 1 : (bosDown||chochDown||mssDown) ? -1 : trend*0.5
gLiq    = sweepBull ? 1 : sweepBear ? -1 : retestBull ? 0.7 : retestBear ? -0.7 : 0
gLoc    = locationScore
gSr     = nearSupport ? 1 : nearResistance ? -1
          : (nearFvgBull && !nearFvgBear) ? 1 : (nearFvgBear && !nearFvgBull) ? -1 : 0
gCandle = cpScore
gVolume = (relVolScore + obvScore + vsaScore)/3
gVol    = atrRegime*(close>=open?1:-1)*0.5 + volScore*0.5
gMom    = (rsiScore + macdScore + dmiScore)/3
gSess   = sessScore*(close>=open?1:-1)
gMtf    = (ctxDir + setupDir)/2
raw     = wTotal > 0 ? clamp(Σ w_i·g_i / wTotal, -1, 1) : 0
score100= round(50 + raw*50)          // math.round: nửa .5 ra xa 0
dir     = raw>0 ? 1 : raw<0 ? -1 : 0
```

`rsiScore`: `<os → +1`, `>ob → −1`, else 0.
`macdScore`: cross over +1, cross under −1, hist>0 +0.5, hist<0 −0.5, else 0.
`dmiScore`: `adx >= adxMin ? (diPlus > diMinus ? +1 : −1) : 0`.
`atrRegime`: `atr > atrMA*1.2 ? 1 : atr < atrMA*0.8 ? 0 : 0.5` (invalid → 0.5).
`volScore`: `bbWidth > bbWidthMA ? (close>open ? 0.5 : −0.5) : 0`.
`relVolScore`: `relVol >= rvMin ? (close>open ? 1 : close<open ? −1 : 0) : 0`.
`obvScore`: slope>0 +1, <0 −1, else 0.
`vsaScore`: `isTim ? (bullBar ? 1 : bearBar ? −1 : 0) : 0`.
`vwapScore`: `close>vwap ? 1 : close<vwap ? −1 : 0` (vwap invalid → 0).
`dayRange`: `pdh>pdl ? (close−pdl)/(pdh−pdl)*2−1 : 0`; `locationScore=(vwapScore+clamp(dayRange,−1,1))/2`.
`trendScore`: stack bull +1, stack bear −1, `close>emaF>emaM` +0.5, `close<emaF<emaM` −0.5, else 0.

Quality theo thứ tự `<=` : `noTrade` → 0, `weak` → 1, `setup` → 2, `strong` → 3, else 4.

#### 10.2 Regime

```text
bbwPct  = (bbwHigh − bbwLow) > 0 ? (bbw − bbwLow)/(bbwHigh − bbwLow)*100 : 50
squeeze = bbwPct <= regBbwSqueeze
regime  = TRENDING if adx >= regAdxTrend && !squeeze
        = CHOPPY   if adx < regAdxChop || (squeeze && |emaF−emaM| < 0.1*atr)
        = RANGING  otherwise
nearRangeEdge = nearSupport(atr*regRangeEdge) || nearResistance(atr*regRangeEdge)
             || (pdOn && (|close−pdl| <= regRangeEdge*atr || |close−pdh| <= regRangeEdge*atr))
okRegime = !regOn || regime==TRENDING || (regime==RANGING && nearRangeEdge)
```

#### 10.3 Confluence

```text
cf1 = dir==1 ? (ctxDir==1 || (ctxDir==0 && setupDir==1))
    : dir==-1 ? (ctxDir==-1 || (ctxDir==0 && setupDir==-1)) : false
cf2 = dir==1 ? (nearSupport(atr*cfLevelTol) || nearFvgBull
             || (pdOn && |low−pdl| <= cfLevelTol*atr)
             || (pwOn && |low−pwl| <= cfLevelTol*atr)
             || (sessOn && sessLo valid && |low−sessLo| <= cfLevelTol*atr)
             || tlUpOk && |low−tlUpAt| <= cfLevelTol*atr
             || sweepBull)
    : dir==-1 ? (đối xứng với high, pwh, sessHi, tlDnAt, sweepBear) : false
cf3 = dir==1 ? (cpScore>0 || patSigDir==bull || bosUp || mssUp || bullPin || bullEng
             || ibBull || 3Soldiers)
    : dir==-1 ? (đối xứng) : false
confluence = cf1+cf2+cf3
okConfluence = !cfOn || !cfRequire3 || confluence >= 3
```

#### 10.4 Risk plan (P9)

```text
entry = close ; a = atr
atrOk = a valid && a > 0
swing = dir==1 ? swingLo : swingHi          (nz → low/high)
pad   = a*slPadAtr
sDist = dir==1 ? (entry−swing)+pad : (swing−entry)+pad
aDist = a*slAtrMul
base  = (aDist + sDist)/2
dist  = clamp(nz(base,aDist), a*slMinAtr, max(a*slMaxAtr, a*slMinAtr))
sl    = entry − dir*dist ; risk = dist
rr2   = max(rr2, rr1) ; rr3 = max(rr3, rr2)
dirOk = dir != 0
slOk  = dist > 0 && (dir==1 ? sl < entry : sl > entry)
rrOk  = rrMin <= 0 || rr1 >= rrMin
valid = atrOk && dirOk && slOk && rrOk
```

TP mode R: `tp_i = entry + dir*rr_i*risk`.
TP mode MM:
```text
mmDist = patHeight > 0 ? patHeight
       : (lastHigh valid && lastLow valid) ? |lastHigh−lastLow| : 0
nếu mmDist > 0:  tp = entry + dir*{0.5, 1, 1.5}*mmDist
else nếu fallback: tp theo R
else: tp1..tp3 = EMPTY (plan vẫn có thể valid)
```

**Default `rr1 = 1.0 < rrMin = 1.5` → `valid = false` trên mọi nến** khi chưa đổi input
(Q2/R2). Đây là hành vi nguồn, không sửa.

#### 10.5 Gates và block

```text
barsSince += 1
nếu ngày server mới: dayCount = 0
okCool   = barsSince >= coolBars
okDay    = dayCount < maxDay
okScore  = score100 > scrNoTrade
okDir    = dir != 0
okFilter = okMtf && okCool && okDay && okScore && okDir && okConfluence && okRegime
signal   = plan.valid && okFilter
sigLong  = signal && dir == 1 ; sigShort = signal && dir == -1
```

Block (lý do đầu tiên, đúng thứ tự):

| Mã | Điều kiện |
|---:|---|
| 0 `NONE` | `signal` |
| 1 `PLAN_INVALID` | `!plan.valid` |
| 2 `MTF_FILTER` | `!okSetup` |
| 3 `HTF_VETO` | `htfVeto` |
| 4 `COOLDOWN` | `!okCool` |
| 5 `DAY_LIMIT` | `!okDay` |
| 6 `SCORE` | `!okScore` |
| 7 `DIR` | `!okDir` |
| 8 `CONFLUENCE` | `!okConfluence` |
| 9 `REGIME` | `!okRegime` |

### 11. State machine (P10 + quirk)

#### 11.1 Thứ tự mỗi nến

```text
1. Deferred reset (nếu needReset): needReset=false; posDir=0; posBars=0; posStage=0;
   posEntry/posSl/posTp1/posTp2/posTp3/posRisk=EMPTY; posBar=-1
2. Nếu posDir != 0:
     isUp = posDir==1
     t1 = posStage < 1 ? posTp1 : EMPTY ; t2 = posStage < 2 ? posTp2 : EMPTY
     t3 = posStage < 3 ? posTp3 : EMPTY
     hitSl = isUp ? low <= posSl : high >= posSl
     hit1  = t1 valid && (isUp ? high >= t1 : low <= t1)     (tương tự hit2, hit3)
     if hitSl && (hit1||hit2||hit3) -> close, evSl, losses+1
     else if hitSl                 -> close, evSl, losses+1
     else if hit3                  -> evTp3, stage=3, close, wins+1
     else if hit2                  -> evTp2, stage=2
     else if hit1                  -> evTp1, stage=1
     if !closed && posBars > 300   -> close (evClose, không win/loss)
     if closed:
        trades += 1
        xEntry=posEntry; xSl=posSl; xDir=posDir; xBar=posBar
        xExit = evSl ? posSl : (evTp==3 ? posTp3 : evTp==2 ? posTp2 : posTp1)
        xR    = posRisk>0 ? (xExit−posEntry)*posDir/posRisk : EMPTY
        needReset = true
3. Nếu okBar && signal && posDir == 0:
     posDir=plan.dir; posEntry..posRisk = plan; posBars=0; posStage=0; posBar=barIndex
     evEntry=true; dayCount += 1; barsSince = 0
4. Nếu posDir != 0 && !evEntry && !needReset: posBars += 1
```

Kết luận bắt buộc:

1. **Exit trước adoption**; nhưng adoption bị chặn bởi `posDir == 0` (khác TM FZ).
2. Nến đóng lệnh **không** được mở lệnh mới: `needReset` đặt ở bước 2, `posDir` vẫn khác 0
   khi tới bước 3 → entry bị chặn; reset chạy ở nến sau (Q7).
3. **SL thắng TP** khi cùng nến: `hitSl && hit1` → loss, `evTp` không bật; stage giữ nguyên.
4. TP3 đóng ngay, win; SL sau TP1 **vẫn là loss** (khác TM FZ).
5. Timeout `posBars > 300` (tức 301): đóng, `xExit = tp1` do `evTp == 0` → quirk Q8.
6. Tín hiệu khi đang mở lệnh bị **bỏ qua im lặng** (không ghi đè, không tính trade cũ).
7. Counters chỉ đổi khi đóng: win = TP3; loss = SL (dù đã TP1/TP2).

### 12. EA và CSV

- `iCustom(_Symbol, _Period, "PinePort\\PriceActionMTF.mq5", <115 inputs>)`.
- Chờ `BarsCalculated(handle) >= Bars(_Symbol,_Period)`.
- Đọc `shift = 1` cố định cho mọi buffer.
- Gate bắt buộc:
  - `PA_LONG`/`PA_SHORT`: đọc thêm `PLAN_VALID=1` (Pine đã đảm bảo, nhưng EA phải kiểm).
  - `ENTRY/SL/TP1/TP2/TP3`: chỉ dùng khi `PLAN_VALID=1` (buffer vẫn có giá trị khi invalid).
  - `POS_*`: chỉ dùng khi `POS_DIR != 0`.
- Dedupe theo `(symbol, timeframe, bar_open_time, signal_id)`.
- Không suy diễn lại TP/SL từ giá; không `OrderSend`, `CTrade`, `AccountInfo*`, `WebRequest`,
  `Socket*`, `FileWrite*`.

CSV (khi EA hỗ trợ — hiện `NOT_IMPLEMENTED`):

```text
detected_at,bar_open_time,confirmed_at,symbol,timeframe,signal_id,side,
entry,sl,tp1,tp2,tp3,risk,score100,dir,quality,confluence,regime,block,
atr,pos_dir,pos_stage,plan_valid,input_hash
```

- `signal_id`: `PA_LONG`, `PA_SHORT`, `PA_ENTRY`, `PA_TP1`, `PA_TP2`, `PA_TP3`, `PA_SL`,
  `PA_CLOSE`.
- `side`: `BUY` cho `PA_LONG`, `SELL` cho `PA_SHORT`, `NONE` cho phần còn lại.
- `bar_open_time` = giờ mở nến server; `confirmed_at = bar_open_time + TF`;
  `detected_at` = tick đầu tiên EA đọc `shift=1`.
- `input_hash` = FNV-1a 32-bit trên canonical string `PaConfigCanonical` +
  `PA_CONTRACT_VERSION`.

### 13. Hàm contract (header)

```cpp
// math / series
double PaClamp(double v, double lo, double hi);
bool   PaIsEmpty(double v);
double PaTrueRange(bool hasPrev, double h, double l, double prevClose);
void   PaBuildSma(const double &src[], int total, int len, double &out[]);
void   PaBuildEma(const double &src[], int total, int len, double &out[]);
void   PaBuildRma(const double &src[], int total, int len, double &out[]);
void   PaBuildAtr(const double &h[], const double &l[], const double &c[],
                  int total, int len, double &out[]);
void   PaBuildRsi(const double &c[], int total, int len, double &out[]);
void   PaBuildMacdHist(const double &c[], int total, int fast, int slow, int sig,
                       double &out[]);
void   PaBuildDmi(const double &h[], const double &l[], const double &c[], int total,
                  int len, int smooth, double &diP[], double &diM[], double &adx[]);
void   PaBuildBb(const double &c[], int total, int len, double mult,
                 double &mid[], double &up[], double &lo[]);
void   PaBuildVwap(const double &h[], const double &l[], const double &c[],
                   const long &vol[], const datetime &t[], int total, int srvDayOffMin,
                   double &out[]);
double PaRollingMin(const double &src[], int total, int end, int len);
double PaRollingMax(const double &src[], int total, int end, int len);
int    PaMapHtfIndex(const datetime &htfCloseTime[], int count, datetime chartOpenTime);

// pivots
bool PaPivotHighAt(const double &h[], int total, int bar, int left, int right, double &out);
bool PaPivotLowAt(const double &l[], int total, int bar, int left, int right, double &out);
double PaNeckMinLow(const double &l[], int total, int aBar, int bBar);
double PaNeckMaxHigh(const double &h[], int total, int aBar, int bBar);

// time
int  PaMinuteOfDay(datetime t, int offsetMin);
bool PaInWindow(int minute, int startMin, int endMin);
int  PaSessionName(datetime serverTime, int srvOffsetMin, int mktOffsetMin);
double PaSessionScore(int sessName);
bool PaIsNewServerDay(datetime prev, datetime cur);
bool PaIsNewServerWeek(datetime prev, datetime cur);
bool PaIsClosedBar(int bar, int ratesTotal);

// zones
void PaZoneAdd(PaEngineState &st, double px, int side, double atr, double width, int maxZones);
bool PaNearSupport(const PaEngineState &st, double low, double atrArg);
bool PaNearResistance(const PaEngineState &st, double high, double atrArg);

// scoring / plan
double PaRsiScore(double rsi, double ob, double os);
double PaMacdScore(double macdHist, bool hasPrev, double prevMacdHist);
double PaDmiScore(double diP, double diM, double adx, double adxMin);
double PaMomScore(double close, double vwap, double dayRange);
double PaAtrRegime(bool atrValid, double atr, double atrMA);
double PaVolumeScore(double volume, double volMA, double ratio,
                     double hi, double redHi, double redN, double redLo);
double PaLocationScore(double close, double vwap, double pdh, double pdl, bool hasPd);
int    PaQuality(int score100, int noTrade, int weak, int setup, int strong);
int    PaRegime(bool adxValid, double adx, bool squeeze, double emaF, double emaM,
                double atr, double adxTrend, double adxChop);
double PaPlanDistance(double atr, double entry, double swing, int dir,
                      double atrMul, double padAtr, double minAtr, double maxAtr);
void   PaBuildPlan(const PaConfig &cfg, const PaBar &bar, int dir,
                   bool hasLastHigh, double lastHigh, bool hasLastLow, double lastLow,
                   double patHeight, PaPlan &plan);

// engine
void PaStateInit(PaEngineState &st);
void PaEngineStep(const PaConfig &cfg, PaEngineState &st, const PaBar &bar,
                  int barIndex, PaBarOut &out);

// config
uint   PaFnv1a(const string text);
string PaConfigCanonical(const PaConfig &cfg);
uint   PaConfigHash(const PaConfig &cfg);
```

`PaBar` chứa các chuỗi đã precompute (§7.2) + OHLCV + `pivH/pivL` + `srPivH/srPivL` +
`htfCtxEma/htfSetupEma` + `sessName/sessScore` + `vwap/pdh/pdl/pwh/pwl/swingLo/Hi` +
`pivNeckLow/pivNeckHigh` (neckline pattern, do indicator tính từ pass 1).

`PaPlan`:

```cpp
struct PaPlan { bool valid; int dir; double entry, sl, tp1, tp2, tp3, risk, rr1; };
```

`PaConfigCanonical` liệt kê 116 khóa (version + 115 trường logic) theo đúng thứ tự §3.2 dạng
`key=value;` với số dùng `%.10g`; `PaConfigHash` = FNV-1a 32-bit (offset basis `2166136261`,
prime `16777619`) trên chuỗi `PA_CONTRACT_VERSION + "|" + canonical`.

### 14. Test vector (119)

Vector mô tả hành vi **kỳ vọng** cho contract tests Phase 4; chưa chạy. Giá trị số dùng để
khẳng định công thức, không phải kết quả runtime.

#### A. Math / time (5)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| A1 | `PaClamp(1.5,0,1)`, `(-1,0,1)`, `(0.4,0,1)` | 1 / 0 / 0.4 |
| A2 | `PaInWindow(1140, 1020, 120)` (17:00–02:00) | true; `(120,1020,120)` false; `(119,1020,120)` true |
| A3 | `PaInWindow(120, 120, 600)` (02:00–10:00) | true; `(599,...)` true; `(600,...)` false |
| A4 | `PaInWindow(m, 480, 480)` | true mọi m (start==end = cả ngày) |
| A5 | `PaIsNewServerDay(Mon 23:59, Tue 00:00)`; `PaIsNewServerWeek(Sun, Mon)` | true / true |

#### B. Series (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| B1 | SMA len 3 trên 1,2,3,4 | 2.0 tại i=2; 3.0 tại i=3 |
| B2 | EMA len 3 seed 1,2,3 rồi 4 | seed 2.0; 3.0 |
| B3 | EMA len 2 seed 10,20 rồi 30 | 15.0; 25.0 |
| B4 | RMA len 3 trên 1,2,3 rồi 4 | 2.0; 2.666667 |
| B5 | ATR len 2, TR 2,2,4 | seed 2.0; sau TR 4 → 3.0 |
| B6 | RSI len 2, close 1,2,3,2 | 100.0 tại i=2; 50.0 tại i=3 |
| B7 | MACD fast2/slow3/sig2, close tăng đều | hist > 0; cross over khi đổi dốc |
| B8 | DMI len2/smooth2, chuỗi tăng đều | diPlus > diMinus; adx tăng > 20 |
| B9 | BB len3 close 1,2,3 mult 2 | mid 2; stdev 0.816497; width 163.29932% |
| B10 | OBV vol 10, close 10,11,10 | 0 → 10 → 0; slope len2 tại i=3 (obv 10) = 0; OBV warm-up slope = obv (B10b) |

#### C. Pivot (5)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| C1 | high 10,12,11 len1 | pivot 12 tại bar 1, xác nhận bar 2 |
| C2 | high 10,12,12,11 len1 | không pivot (plateau, strict hai phía) |
| C3 | pivot xác nhận tại `c`; giá trị `high[c−len]`; `bar=c−len` | đúng cả 3 |
| C4 | low 10,8,9 len1 | pivot 8 tại bar 1 |
| C5 | `srLeft=2, srRight=1` tách khỏi `swingLen=5` | zone pivot xác nhận khác structure pivot |

#### D. Structure (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| D1 | trend 0, lastHigh 100, close 101 | bosUp, trend 1, brkLevel 100 |
| D2 | trend −1, lastHigh 100, close 100 ≤ lastHigh, pivot newH 105 | chochUp, không bosUp (BOS cần close > lastHigh) |
| D3 | trend 0, lastLow 90, close 89 | bosDown, trend −1 |
| D4 | bosUp + dispBull cùng nến | mssUp |
| D5 | lastHigh 100; pivot mới 101 rồi 99 | HH (101 > 100) / LH (99 < 100) |
| D6 | brkDir 1, 5 nến sau, low ≤ brk+0.5ATR, close > brk | retestBull |
| D7 | brkDir −1, close > brk trong failBars | failBull |
| D8 | trend 1 + HH → contBull; low ≤ emaM & close > emaM → pullBull | cả hai true |

#### E. Pattern (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| E1 | 2 pivot high 100 / 100.5, ATR 2, band 0.5 | DT (|diff| ≤ 1) |
| E2 | DT neck 99, close 98.5, close[1] 99.5 | break bear, PATTERN=DT |
| E3 | 2 pivot low 100/100.5, neck high nhất giữa | DB, break bull |
| E4 | h1 100, h2 121, hsRatio 1.2 | HST |
| E5 | l1 100, l2 83 (≤ 100/1.2) | HSN |
| E6 | h1 100, h3 100.4 trong band | gán `c/cBar` cho HST còn trống |
| E7 | neckline giữa b1=5,b2=9, low giữa = 2, hai đầu = 1 | neck 2 (không tính đầu mút) |
| E8 | break với patNeck 110, close 100 | h1 và patternHeight = 0: close 100 < neck 110 nên không phải break; xem §4.1/§6/§9.5 |

#### F. Liquidity (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| F1 | ngày server trước high 200/low 180 | pdh/pdl = 200/180 |
| F2 | tuần server trước (thứ Hai) high/low | pwh/pwl đúng |
| F3 | session đổi Asia → London | sessHi/Lo reset về high/low hiện tại |
| F4 | name chuyển `-` | sessHi/Lo và sessPrev giữ nguyên |
| F5 | |high[sw]−prevHigh| ≤ 0.05·ATR | eqHi |
| F6 | low < pdl, close > pdl | sweepBull |
| F7 | trong phiên, low < sessLo (sessLo đã gồm low) | sweepBull nhánh session **false** (Q3) |
| F8 | ngoài phiên `-`, sessLo=190 cũ, low 189, close 191 | nhánh session **true** |

#### G. Zones (9)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| G1 | px 100, ATR 2, width 0.5 | top 100.5, bot 99.5 |
| G2 | zone support mid 100; register resistance 100.4 | merge (|diff| 0.4 < 1), side giữ support, touches 2 |
| G3 | merge không đổi top/bot | top/bot zone cũ |
| G4 | srMax 2, thêm zone thứ 3 | zone cũ nhất bị shift |
| G5 | low = bot − 0.3·ATR − ε | nearSupport false; ε ngược lại true |
| G6 | high trong dải zone side −1 | nearResistance true |
| G7 | low > high[2] + 0.3·ATR | FVG bull top=low, bot=high[2] |
| G8 | FVG bull, close < bot | dead |
| G9 | dispBull + close[1]<open[1]; OB top/bot = body nến trước; low gần OB 0.3ATR | nearFvgBull true |

#### H. Candles (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| H1 | bull bar, loWick ≥ 2·body | bullPin |
| H2 | engulf đủ điều kiện body ≥ strongBody·range | bullEng |
| H3 | dispBull + vol ≥ 2.2·volMA | dispBullV, +1.2 |
| H4 | hiWick ≥ 0.55·range, loWick ≤ 0.15·range, bull | +0.8 |
| H5 | nến trước inside, close > high[1] | ibBull +0.8 |
| H6 | body ≤ 0.10·range, loWick > hiWick, close ≥ open | dojiBull +0.5 |
| H7 | 3 nến tăng, body mạnh, close tăng dần | 3Soldiers +1.2 |
| H8 | volRatio 1.0, volVetoOn | pin/engulf × 0.4 |
| H9 | 2 engulf liên tiếp, streakMin 2, add 0.5 | nến thứ 2 được 1.5 |
| H10 | cpBull 2.2 (disp 1.2 + pin 1.0), cpBear 0 | cpScore = 0.733333 (chia 3); thêm streak 2.0 → cap 1.0 |

#### I. Indicators / scoring (9)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| I1 | RSI 25 / 75 / 50 | +1 / −1 / 0 |
| I2 | MACD cross over; hist > 0 | +1; +0.5 |
| I3 | ADX 19; ADX 25 & DI+>DI− | 0; +1 |
| I4 | rsi +1, macd +0.5, dmi +1 | mom 0.833333 |
| I5 | ATR 13/MA 10; ATR 12/MA 10; ATR 7/MA 10 | 1 / 0.5 / 0 |
| I6 | bbExpand, close < open | volScore −0.5 |
| I7 | relVolScore 1, obvScore 1, vsaScore 1 | volumeScore 1 |
| I8 | vwapScore 1, dayRange 0.4 | location 0.7 |
| I9 | trend = 1 ở tất cả nhóm, weights default | raw 1, score100 100; chỉ gTrend=1 | raw 0.15, score100 58 |

#### J. MTF (8)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| J1 | chart open 12:00, H4 close 12:00 | chọn bar H4 08–12 (biên `<=`) |
| J2 | chart open 11:55 | chọn bar H4 04–08 (không dùng 08–12) |
| J3 | HTF bars < len+1 | EMA EMPTY → dir 0 |
| J4 | close == ctxEma | ctxDir −1 (không 0) |
| J5 | htfFilter, setupDir +1, dir −1 | okSetup false |
| J6 | vetoOn, ctxDir +1, dir −1 | htfVeto true, okMtf false |
| J7 | ctxDir 0, setupDir −1 | gMtfBias −0.5; htfFilter off → okSetup true |
| J8 | setupDir 0 | okSetup true |

#### K. Regime / confluence (7)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| K1 | adx 26, không squeeze | TRENDING |
| K2 | adx 17 | CHOPPY |
| K3 | adx 20, squeeze, |emaF−emaM| < 0.1ATR | CHOPPY |
| K4 | adx 20, không squeeze/chop | RANGING |
| K5 | low = bot − 0.104·ATR (zone) | nearRangeEdge true; 0.106·ATR → false |
| K6 | dir +1, ctxDir +1 | cf1 true |
| K7 | dir +1, zone support 99..101 (ATR 2, width 0.5); low 100.8 rồi 101.4 | cf2 true / false; confluence 2 + require3 → block 8 |

#### L. Plan / gates (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| L1 | entry 100, ATR 2, swing 96, pad tuyệt đối 0.4 (= ATR·padAtr, padAtr 0.2), atrMul 1.5 | dist 3.7, sl 96.3 |
| L2 | atrMul 1.0, swing = entry, ATR 1, min 0.8 | dist 0.8 (clamp min) |
| L3 | swing rất xa | dist = maxAtr·ATR |
| L4 | dir 0 | valid false |
| L5 | rr1 1.0, rrMin 1.5 | rrOk false, valid false |
| L6 | rr1 2.0, rrMin 1.5 | rrOk true |
| L7 | R mode entry 100, risk 2, rr 1/2/3 | tp 102/104/106 |
| L8 | MM patHeight 6 | tp +3/+6/+9 |
| L9 | MM patHeight 0, |lastHigh−lastLow| 4 | mm 4; cả hai 0 + fallback → TP theo R |
| L10 | MM no-fallback, mm 0 | plan valid có thể true, tp1..3 EMPTY |

#### M. State (10)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| M1 | signal + flat | posDir set, entry=close, dayCount+1, barsSince 0, evEntry |
| M2 | high ≥ tp1 | evTp1, stage 1 |
| M3 | stage 1, high ≥ tp2 | evTp2, stage 2 |
| M4 | high ≥ tp3 | đóng, wins+1, evTp3+evClose, xExit=tp3 |
| M5 | low ≤ sl, chưa TP | đóng, losses+1, evSl+evClose |
| M6 | cùng nến chạm TP1 và SL | loss, evTp1 false, stage 0 |
| M7 | posBars 301, không chạm | đóng, trades+1, wins/losses không đổi |
| M8 | timeout | xExit = tp1 (quirk) |
| M9 | nến đóng lệnh có signal | không entry cùng nến; nến sau reset rồi mới entry |
| M10 | signal khi đang mở | bỏ qua, không đổi pos/levels/counters |

#### N. Gates / counters (5)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| N1 | barsSince 9/10, coolBars 10 | false / true |
| N2 | dayCount 3, maxDay 3 | okDay false |
| N3 | sang ngày server mới | dayCount 0 trước gate |
| N4 | plan invalid + mọi gate fail | BLOCK = 1 |
| N5 | score100 49 / 50 | okScore false / true |

#### O. Config hash (3)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| O1 | canonical string | 116 khóa (version + 115 trường), thứ tự §3.2, ổn định |
| O2 | FNV-1a "a" / "foobar" | 0xE40C292C / 0xBF9CF968 |
| O3 | đổi 1 input | hash đổi; cấu hình trùng → hash trùng |

#### P. Output / bar policy (4)

| ID | Nội dung | Kỳ vọng |
|---|---|---|
| P1 | `j == rates_total-1` | mọi buffer 0/EMPTY, không chạy engine |
| P2 | warm-up: ATR invalid | score100 51, PLAN_VALID 0, ENTRY=close, SL/TP EMPTY |
| P3 | volMA invalid | VOL_BUCKET 0 (VeryLow), VOL_RATIO 0, isTim false |
| P4 | buffer i ↔ plot i | 12 plot map 0..11; contract 12..106 |

### 15. Validator và Gate 3

`scripts/validate_pamtf.py` (static only, không compile, không chạy MT5, không tuyên bố parity)
kiểm tra:

| # | Check | Kỳ vọng |
|---:|---|---|
| V1 | Contract constants | `PA_PLOT_BUFFERS 12`, `PA_CONTRACT_BUFFERS 95`, `PA_TOTAL_BUFFERS 107` |
| V2 | `ENUM_PA_BUFFER` | 95 entry, giá trị 12..106 đúng một lần |
| V3 | Enum phụ | `ENUM_PA_TP_MODE/QUALITY/REGIME/PATTERN/BUCKET/SESSION/CLOSE/BLOCK` đúng miền §4 |
| V4 | `PA_CONTRACT_VERSION` | `"1.0.0"` |
| V5 | Indicator | `indicator_buffers 107`, `indicator_plots 12`, include contract |
| V6 | Bind | 107 buffer, index 0..106 đúng một lần; 0..11 DATA, 12..106 CALCULATIONS |
| V7 | Closed bar | có `lastClosed = total - 2` và `j <= lastClosed` |
| V8 | Không confirm input | không khai báo input confirm |
| V9 | Input count | đúng 115 `input` |
| V10 | Test IDs | đủ A1..A5, B1..B10, C1..C5, D1..D8, E1..E8, F1..F8, G1..G9, H1..H10, I1..I9, J1..J8, K1..K7, L1..L10, M1..M10, N1..N5, O1..O3, P1..P4 |
| V11 | Marker | test script in `TEST|RESULT|ALL_PASS` |
| V12 | Docs | contract chứa `indicator_buffers 107`, `## 14. Test vector`, `NOT_IMPLEMENTED`, `BLOCKED` |
| V13 | Safety | không `OrderSend/CTrade/AccountInfo/WebRequest/Socket*/FileOpen/Alert/...` |
| V14 | No placeholder | không `TODO/FIXME/TBD/PLACEHOLDER` |

Gate 3 criteria:

| # | Tiêu chí | Trạng thái |
|---|---|---|
| C1 | Mọi buffer EA cần có index, miền, kiểu thiếu, loại (edge/state/bar) | PASS |
| C2 | Bar policy và replay order khớp Phase 2 (P1/P5/P6/P8) | PASS |
| C3 | Quirk nguồn được ghi rõ, không "sửa" âm thầm | PASS (§16) |
| C4 | Test vector phủ toàn bộ helper + engine, có vector cho default-RR bug | PASS (119) |
| C5 | Không tuyên bố runtime/parity | PASS (`NOT_RUN` / `BLOCKED`) |
| C6 | Không sửa Pine nguồn | PASS |

**Kết luận:** contract đóng băng cho Phase 4. Trạng thái runtime: `NOT_RUN`; EA: `NOT_IMPLEMENTED`;
parity: `BLOCKED` (chưa có CSV Pine, E1–E10 `PENDING`).

### 16. Hành vi nguồn phải giữ nguyên (Q1–Q10)

| ID | Quirk | Hệ quả port |
|---|---|---|
| Q1 | `f_nearSupport/Resistance` nhân thêm **0.3** bên trong | Tolerance zone thực tế = `atrArg·0.3`; regime 0.105·ATR, confluence 0.15·ATR, gộp score 0.3·ATR |
| Q2 | Default `rr1=1.0 < rrMin=1.5` | Không có signal với input mặc định; EA/test phải set `InpRr1 >= InpRrMin` hoặc `InpRrMin = 0` |
| Q3 | Session HL cập nhật **trước** sweep và gồm high/low hiện tại | Nhánh sweep session không bao giờ bật trong phiên; chỉ bật ngoài phiên (`-`) với mức cũ |
| Q4 | Merge zone không kiểm tra `side` | Resistance có thể bị hút vào support; thứ tự register quyết định |
| Q5 | `patHeight` là `var`, lấy neckline pattern **cuối chưa phá** | TP measured-move có thể dùng chiều cao pattern khác hoặc giữ giá trị cũ |
| Q6 | `ctxDir/setupDir = close > ema ? 1 : -1` | `close == ema` → **−1**, không phải 0 |
| Q7 | Adoption chặn bởi `posDir == 0` + deferred reset | Không mở lệnh mới trên nến vừa đóng lệnh |
| Q8 | Timeout đóng với `xExit = tp1` | `PA_CLOSE` timeout có `xR` theo TP1, không theo giá đóng |
| Q9 | SL ưu tiên hơn TP khi cùng nến | TP1+SL = loss, không phải win (khác TM FZ) |
| Q10 | OBV slope warm-up `nz(na)=0`; bucket khi volMA na = VeryLow; veto ×0.4 khi volRatio 0 | Giữ nguyên để parity lịch sử |

Ngoài ra:

- BLOCK `NONE` chỉ khi `signal`; nếu `plan.valid = false` luôn báo `PLAN_INVALID` trước mọi gate.
- `barsSince` khởi tạo 999999 → nến đầu tiên luôn qua cooldown.
- `dayCount` tăng khi entry, kể cả entry trên nến SL/timeout trước đó (miễn `posDir == 0`).

### 17. Câu hỏi mở

1. Biên MTF `close_time == chart open` (P4) cần CSV xác nhận — E2 `PENDING`.
2. Pivot tie-breaking của `ta.pivothigh/low` trên plateau — E9 `PENDING`.
3. Session sweep ngoài phiên (Q3) có xuất hiện trong dữ liệu thực không — cần CSV đếm.
4. `ta.vwap` anchor phiên sàn vs reset ngày server (D6) — chênh lệch biên ngày cần E3.
5. Symbol/timeframe chuẩn cho parity (XAUUSD M5 là ứng viên) — chưa chốt.
