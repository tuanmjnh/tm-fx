# LongKaco VSA — Spec, Repaint Audit và Buffer Contract

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `INDICATOR_SPEC_LongKacoVSA.md`, `REPAINT_AUDIT_LongKacoVSA.md`, `BUFFER_CONTRACT_LongKacoVSA.md`.

Nội dung:
1. Indicator Spec — LongKaco VSA
2. Repaint Audit — LongKaco VSA (Pine v6)
3. Buffer Contract — LongKaco VSA (Pine v6 → MQL5)

---
## Indicator Spec — LongKaco VSA

- **Nguồn Pine:** `D:\Applications\tm-trading\pine\dist\LongKaco VSA.pine` (681 dòng, read-only)
- **Nguồn execution tham chiếu:** `D:\Applications\tm-trading\pine\dist\LongKaco VSA Backtest.pine` (600 dòng)
- **Phụ bản:** `parts-longkaco-vsa/` (8 module, không compile độc lập)
- **Pine version:** 6 — `indicator(..., overlay = false, dynamic_requests = true, max_bars_back = 1000)`
- **Loại:** indicator, pane riêng (volume), **không** có `request.security`, **không** có `lookahead`
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (xem §9, §10)
- **License:** chưa thấy header license trong repo nguồn; chỉ dùng nội bộ, cần xác nhận quyền trước khi phân phối.

### 1. Mục tiêu tín hiệu

LongKaco VSA gắn nhãn 5 sự kiện VSA trên nến đã đóng:

| Nhóm | Sự kiện | Ý nghĩa |
|---|---|---|
| Chính | SV (Stopping Volume) | Volume đột biến khi giá đang chạy xuống tại vùng hỗ trợ, nến tăng → lực bán bị hấp thụ |
| Chính | BC (Buying Climax) | Volume đột biến khi giá đang chạy lên tại vùng kháng cự, nến có bóng trên dài → lực mua cạn |
| Xác nhận | ST LONG / ST SHORT | Retest vùng SV/BC bằng volume thấp, thân nến đúng chiều |
| Nhắc nhở | NS (No Supply) / ND (No Demand) | Volume rất thấp tại hỗ trợ/kháng cự, thân nến đúng chiều |
| Cảnh báo | NO SWEEP | Setup ST đủ điều kiện nhưng thiếu bar quét trước đó |
| Cảnh báo | CLX-E | Volume TIM xuất hiện khi setup đã đi ≥ `clxR` × R theo hướng có lợi |

Chỉ SV/BC bắt buộc đi qua cổng volume TIM (ratio ≥ `rP`). ST/NS/ND là lớp xác nhận/nhắc nhở.

### 2. Inputs (45)

#### 2.1 Chung & Volume

| Pine | Kiểu | Mặc định | Min/Max/Step | Ghi chú |
|---|---|---|---|---|
| `tm_confirmOnly` | bool | `true` | — | Chỉ phát tín hiệu khi nến đóng (`barstate.isconfirmed`) |
| `tm_i_len` | int | `20` | 5 / 100 | Cửa sổ Volume MA (Wilder RMA) |
| `tm_i_showMA` | bool | `true` | — | Hiển thị volume MA |
| `tm_i_rP` | float | `2.2` | 1.5 / — / 0.1 | Ngưỡng TIM (bucket cao nhất) |
| `tm_i_rVH` | float | `1.8` | 1.0 | VeryHigh |
| `tm_i_rH` | float | `1.2` | 0.8 | High |
| `tm_i_rN` | float | `0.8` | 0.4 | Normal |
| `tm_i_rL` | float | `0.4` | 0.1 | Low |
| `tm_i_purWin` | int | `20` | 5 / 100 | Cửa sổ đếm TIM trên dashboard |
| `tm_i_volMin` | float | `0.0` | 0 | Volume tối thiểu tuyệt đối (0 = tắt) |
| `tm_i_sessOn` | bool | `false` | — | Lọc phiên giao dịch |
| `tm_i_sess` | session | `"0800-1600"` | — | Phiên lọc |
| `tm_i_tz` | string | `"Asia/Ho_Chi_Minh"` | danh sách 8 tz | Múi giờ phiên |
| `tm_i_sessTz` | string | `"America/New_York"` | danh sách 5 tz | Múi giờ dashboard (không ảnh hưởng tín hiệu) |

#### 2.2 Sự kiện & Level

| Pine | Kiểu | Mặc định | Min/Max | Ghi chú |
|---|---|---|---|---|
| `tm_i_evtOn` | bool | `true` | — | Bật SV/BC/ST |
| `tm_i_quietOn` | bool | `true` | — | Bật NS/ND |
| `tm_i_run` | int | `5` | 1 / 50 | Số nến momentum (`close[run]`) |
| `tm_i_lvTol` | float | `0.5` | 0.1 | Độ rộng vùng H/T (× ATR) |
| `tm_i_lvFresh` | int | `60` | 10 / 500 | Số nến level còn hiệu lực |
| `tm_i_testR` | float | `1.2` | 0.3 / 2.0 | Ngưỡng "volume thấp" cho ST |
| `tm_i_retestT` | float | `1.0` | 0.2 | Bán kính retest (× ATR) |
| `tm_i_atrLen` | int | `14` | 2 / 100 | ATR |
| `tm_i_pivLen` | int | `20` | 5 / 100 | Pivot trái/phải |

#### 2.3 Chiến lược & Vào lệnh

| Pine | Kiểu | Mặc định | Options |
|---|---|---|---|
| `tm_i_signalMode` | string | `"VSA dao chieu"` | `VSA dao chieu`, `VSA loc + Wyckoff` |
| `tm_i_wyckoffEvent` | string | `"LPS"` | `Spring`, `SOS`, `LPS` |
| `tm_i_sosSpread` | float | `1.0` | Thân nến SOS/SOW (× ATR), min 0.2 |
| `tm_i_sosVol` | float | `1.2` | Volume SOS/SOW (× MA), min 0.5 |
| `tm_i_lpsTol` | float | `0.5` | Sai số vùng LPS/LPSY (× ATR) |
| `tm_i_entryMode` | string | `"Market (xac nhan ST)"` | `Market (xac nhan ST)`, `Limit (cuc tri SV/BC)` |
| `tm_i_tpMode` | string | `"Theo R (co dinh)"` | `Theo R (co dinh)`, `Pivot doi dien`, `Measured move (A-P1-1)` |

#### 2.4 Sweep / CLX-E / Hiển thị / Phí

| Pine | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `tm_i_sweepReq` | bool | `true` | Yêu cầu bar sweep trước ST |
| `tm_i_sweepWin` | int | `10` | Cửa sổ sweep (0 = không giới hạn) |
| `tm_i_clxOn` | bool | `true` | Chỉ điều khiển **text dashboard** (xem §9-D4) |
| `tm_i_clxR` | float | `1.5` | Khoảng cách tới entry (× R), min 0.5 |
| `tm_i_slBuf` | float | `0.5` | SL buffer (× ATR), min 0.1 |
| `tm_i_rrFb` | float | `2.0` | TP fallback (R) |
| `tm_i_feePct` | float | `0.05` | Phí mỗi chiều (%) |
| `tm_i_feeMaxR` | float | `0.15` | Cảnh báo phí/R |
| `tm_i_showViz` / `tm_i_showSig` / `tm_i_showVol` / `tm_i_dash` / `tm_i_pivOn` / `tm_i_lvlOn` / `tm_i_dashSize` | bool/string | `true`/`Small` | Thuần hiển thị |

### 3. Công thức

#### 3.1 Volume & bucket

```text
atr    = ta.atr(14)
vol    = nz(volume)                      // tick_volume trong MQL5
volMA  = ta.rma(vol, 20)                 // Wilder, seed = SMA(20)
ratio  = vol / volMA                     // 0 khi MA chưa có
purple = volMA > 0 and vol >= volMA * rP
quietST  = volMA > 0 and vol < volMA * testR and vol < volMA * rP and evtOk
quietLow = volMA > 0 and vol < volMA * rN and evtOk
evtOk  = (volMin <= 0 or vol >= volMin) and sessionOk
```

Bucket theo thứ tự giảm dần: `TIM` (≥ rP) → `VeryHigh` (≥ rVH) → `High` (≥ rH) →
`Normal` (≥ rN) → `Low` (≥ rL) → `VeryLow`.

#### 3.2 Level & momentum

```text
pLow   = ta.pivotlow(low, 20, 20)        // xác nhận tại bar + 20
pHigh  = ta.pivothigh(high, 20, 20)
lastPLow / lastPHigh: cập nhật tại bar XÁC NHẬN, lưu luôn bar hiện tại
lowFresh  = bar_index - plowBar  <= 60
highFresh = bar_index - phighBar <= 60
nearSup   = lowFresh  and low  <= lastPLow  + lvTol * atr
nearRes   = highFresh and high >= lastPHigh - lvTol * atr
runDown   = close < close[5]
runUp     = close > close[5]
```

`plowBar` là **bar xác nhận pivot**, không phải bar tạo pivot (Pine gán `bar_index` tại
bar nhận được giá trị pivot). Port MQL5 giữ đúng semantics này.

#### 3.3 Sự kiện

```text
SV = evtOn and okBar and purple and runDown and nearSup and high > low and close > open
BC = evtOn and okBar and purple and runUp   and nearRes and high > low
     and (high - close) >= 0.5 * (high - low)
NS = quietOn and okBar and quietLow and nearSup and close > open
ND = quietOn and okBar and quietLow and nearRes and close < open
```

Mỗi lần SV: `svBar = bar_index`, `svPx = low`. Mỗi lần BC: `bcBar = bar_index`,
`bcPx = high`. `svFresh/bcFresh` tính từ các bar này, cửa sổ `lvFresh`.

#### 3.4 Sweep gate (A-P0-1)

```text
sweepUpBar = hasSV and low < svPx  and close > svPx    // quét đáy rồi đóng lại trên
sweepDnBar = hasBC and high > bcPx and close < bcPx
sweepL = hasSV and lastSweepUpBar >= svBar and age <= sweepWin (0 = vô hạn)
sweepS = hasBC and lastSweepDnBar >= bcBar and age <= sweepWin
gateOn = sweepReq and not wyckoffMode
```

#### 3.5 ST (vào lệnh) và NO SWEEP

```text
stRawL = evtOn and okBar and (
           wyckoffMode ? (evLong  and svFresh)
                       : (svFresh and quietST and |low - svPx|  <= retestT*atr and close > open))
stRawS = evtOn and okBar and (
           wyckoffMode ? (evShort and bcFresh)
                       : (bcFresh and quietST and |high - bcPx| <= retestT*atr and close < open))

ST_LONG  = stRawL and (not gateOn or sweepL)
ST_SHORT = stRawS and (not gateOn or sweepS)
NO_SWEEP = gateOn and ((stRawL and not sweepL) or (stRawS and not sweepS))
```

#### 3.6 Wyckoff (chế độ `VSA loc + Wyckoff`)

```text
strongVol = vol >= volMA * sosVol
spread    = high - low

Spring = lowFresh  and low  < lastPLow  and close > lastPLow  and close > open
UTAD   = highFresh and high > lastPHigh and close < lastPHigh and close < open
SOS    = highFresh and close > lastPHigh and spread >= sosSpread*atr and strongVol and close > open
SOW    = lowFresh  and close < lastPLow  and spread >= sosSpread*atr and strongVol and close < open
LPS    = sosDone  and bar_index > sosBar  and low  > sosLow
         and low  <= sosLow  + lpsTol*atr and close > open
LPSY   = sowDone  and bar_index > sowBar  and high < sowHigh
         and high >= sowHigh - lpsTol*atr and close < open
```

`evLong/evShort` chọn theo input `wyckoffEvent`. Ở chế độ Wyckoff, cổng sweep bị tắt
vì Spring/UTAD đã là hành vi "phá vỡ rồi đóng cửa trở lại".

#### 3.7 Entry / SL / TP (lớp hiển thị + tham chiếu thực thi)

Tại bar ST LONG (và chỉ khi `risk > 0`):

```text
entry  = (entryMarket or wyckoff) ? close : svPx
sl     = (wyckoff ? low : svPx) - slBuf*atr
risk   = entry - sl
tpR    = entry + rrFb*risk
tpPv   = (lastPHigh valid and lastPHigh >= entry + risk) ? lastPHigh : tpR
mmUp   = lastPHigh - ta.lowest(low, run+1)
tpMM   = (highFresh and mmUp > risk) ? entry + mmUp : tpR
tp     = tpMode == "Theo R" ? tpR : tpMode == "MM" ? tpMM : tpPv
fill   = entryMarket
```

SHORT đối xứng: `sl = (wyckoff ? high : bcPx) + slBuf*atr`, `risk = sl - entry`,
`tpPv = lastPLow <= entry - risk ? lastPLow : tpR`, `mmDn = ta.highest(high, run+1) - lastPLow`.

Theo dõi sau bar tạo setup (`bar_index > lvlB`):

1. Nếu chưa khớp: LONG khớp khi `low <= entry`, SHORT khớp khi `high >= entry`.
2. Khi đã khớp: ưu tiên SL. LONG: `low <= sl` → SL, ngược lại `high >= tp` → TP.
   SHORT: `high >= sl` → SL, ngược lại `low <= tp` → TP.

#### 3.8 CLX-E

```text
reset mỗi khi có ST
nếu purple và setup chưa đóng và risk > 0:
    LONG  high >= entry + clxR*risk  → clxE = true
    SHORT low  <= entry - clxR*risk  → clxE = true
```

### 4. Thứ tự ưu tiên trên dashboard

Khi nhiều sự kiện cùng bar: `SV > BC > ST > NS > ND`. Dashboard còn hiển thị: bucket
volume, ratio, số TIM trong `purWin`, trạng thái sweep, khoảng cách tới target
(`clxMax`), phí/R, setup gần nhất và kết quả TP/SL.

### 5. Output Pine

- `plot` histogram volume (màu theo bucket) + volume MA.
- 7 `plotshape` sự kiện (SV, BC, ST LONG, ST SHORT, NS, ND, NO SWEEP) + 2 shape CLX-E.
- 2 đường pivot (H/T), 3 đường Entry/SL/TP + nhãn kết quả.
- Dashboard 15 dòng tại `barstate.islast`.
- 8 `alertcondition`: `LK VSA SV`, `BC`, `ST LONG`, `ST SHORT`, `NS`, `ND`, `NO SWEEP`, `CLX-E`.

### 6. Thời điểm xác nhận & timestamp

- `tm_okBar = confirmOnly ? barstate.isconfirmed : true`, mặc định **true**.
- Mọi sự kiện và mọi cập nhật state setup đều nằm sau `tm_okBar`; riêng CLX-E dùng
  `tm_isPurple` (đã gate `evtOk`) nhưng vẫn chỉ được tính trong vòng đời setup, và setup
  chỉ mở bởi ST (đã gate `okBar`).
- `barstate.islast` chỉ dùng cho dashboard — không ảnh hưởng tín hiệu.
- Không có `request.security`, không lookahead, không offset âm.
- Pivot có độ trễ cấu trúc `pivLen` bar (20 mặc định) — không phải repaint.

### 7. Warm-up

| Thành phần | Bar tối thiểu |
|---|---|
| ATR(14) | 14 (Wilder seed) |
| Volume RMA(20) | 20 |
| Pivot (20/20) | 40 để có pivot đầu tiên, +20 để xác nhận |
| Momentum `close[5]` | 6 |

Không phát tín hiệu trước khi `volMA` có giá trị; pivot chưa có → `lowFresh/highFresh` false.

### 8. Execution semantics (từ `LongKaco VSA Backtest.pine`, KHÔNG port)

Backtest dùng state `tm_lvlE/S/T` của indicator, thêm:

- `strategy.entry` market tại close bar ST (chế độ 1 lệnh) hoặc N lệnh limit quanh entry
  (pyramid `btPyr > 1`, lệch `(i-(N+1)/2) * btStep * ATR`, cùng SL/TP).
- `strategy.exit` stop/limit theo `tm_lvlS/T`; chế độ N=1 giữ ID `Long`/`Short` cũ.
- `pyramiding = 5`, `process_orders_on_close = true`, commission 0.05%/chiều.

Đây là logic tham chiếu để so sánh, **không phải** lệnh thật. Bản MQL5 chỉ phát tín hiệu
và buffer level; EA chỉ đọc/ghi log. Hai lỗi logic đã biết của bản Pine (cần tránh khi
port execution): (1) đổi ID entry khi bật pyramid làm `strategy.exit("VSA X")` không còn
khớp; (2) `strategy.close("Long")` không khớp `L1..Ln`. Bản dist hiện tại đã sửa cả hai
bằng cách tách nhánh `btMulti`, nhưng EA của repo này vẫn không port execution.

### 9. Khác biệt port MQL5 (dự kiến)

| ID | Khác biệt | Lý do / xử lý |
|---|---|---|
| D1 | `volume` Pine → `tick_volume` MQL5 | Forex/CFD không có volume thật; cùng quy ước Wonderwhales |
| D2 | Session tz dùng offset UTC cố định (`InpSessionUtcOffsetMin`) | MQL5 không có tz database; DST không tự áp dụng. Mặc định tắt nên parity mặc định không đổi |
| D3 | Pivot tie-breaking dùng `low[p] == min(window)` (cho phép bằng nhau) | Pine không tài liệu hóa tie; cần đối chiếu CSV để xác nhận |
| D4 | `tm_i_clxOn` trong Pine chỉ gate text dashboard, không gate `tm_clxE` | Port giữ nguyên: buffer CLX-E phát bất kể `clxOn`; input chỉ đổi màu/nhãn |
| D5 | Hiển thị: MQL5 pane riêng chỉ vẽ ratio + mũi tên sự kiện | Không cần dashboard/line/label cho mục tiêu EA; thay đổi thuần render |
| D6 | `entryMode`/`tpMode` là input của indicator trong Pine; EA MQL5 đọc buffer level | Buffer Entry/SL/TP tính theo cùng công thức, EA không tự suy diễn |
| D7 | `barstate.isconfirmed=false` không được port | Repaint theo thiết kế; MQL5 luôn dùng nến đã đóng |

### 10. Trạng thái port

| Hạng mục | Trạng thái |
|---|---|
| Spec | DONE (tài liệu này) |
| Repaint audit | `docs/indicators/longkaco-vsa.md` |
| Buffer contract | `docs/indicators/longkaco-vsa.md` |
| MQL5 indicator | `mt5/Indicators/PinePort/LongKacoVSA.mq5` |
| Contract tests | `mt5/Scripts/LongKacoVSAContractTests.mq5` (compile; **chưa chạy terminal**) |
| Pine vs MQL5 parity | `BLOCKED` — chưa có CSV export từ TradingView |
| Strategy Tester | `NOT_RUN` |

### 11. Blocker

1. Chưa có CSV reference từ Pine trên cùng symbol/timeframe/input → parity `BLOCKED`.
2. Chưa chạy indicator/EA trong terminal → runtime `NOT_RUN`.
3. License nguồn Pine chưa xác nhận.

## Repaint Audit — LongKaco VSA (Pine v6)

- **Phase:** 2 — Phân tích repainting và ngữ nghĩa tín hiệu
- **Ngày:** 2026-10-28
- **Trạng thái:** `STATIC_PASS_RUNTIME_PENDING` — phân tích tĩnh trên source Pine; chưa chạy TradingView Bar Replay,
  chưa tạo alert, chưa chạy backtest. Các kết luận phụ thuộc runtime TradingView đánh dấu `PENDING` ở §10.
- **Nguồn:** [`dist/LongKaco VSA.pine`](file:///D:/Applications/tm-trading/pine/dist/LongKaco%20VSA.pine) (681 dòng)
  và [`dist/LongKaco VSA Backtest.pine`](file:///D:/Applications/tm-trading/pine/dist/LongKaco%20VSA%20Backtest.pine)
  (600 dòng). Không file Pine nào bị sửa.
- **Đặc tả nền:** `INDICATOR_SPEC_LongKacoVSA.md`.

### 1. Định nghĩa repaint

| Mã | Hiện tượng | Ảnh hưởng |
|---|---|---|
| RP1 | Marker/sự kiện xuất hiện trên nến đang chạy rồi biến mất trước khi đóng | Tín hiệu “ma” trên chart |
| RP2 | Giá trị của nến **đã đóng** thay đổi khi có nến mới | Không thể parity/backtest |
| RP3 | Alert phát trước khi nến đóng | Vào lệnh trên dữ liệu chưa xong |
| RP4 | SL/TP của strategy thay đổi trong nến và áp ngược lại chính nến đó | Fill không có thật |
| RP5 | Hai lần chạy cùng input cho lịch sử khác nhau | Không dùng được làm reference |

### 2. Bản đồ phụ thuộc dữ liệu

Toàn bộ chuỗi là causal, chỉ dùng dữ liệu cùng nến và quá khứ:

```
open/high/low/close/volume
  ├─ ta.atr(14)                     -> tm_atr
  ├─ ta.rma(nz(volume), 20)         -> tm_volMA -> ratio/bucket/TIM
  ├─ ta.pivotlow(low, 20, 20)       -> tm_lastPLow + tm_plowBar (bar XÁC NHẬN)
  ├─ ta.pivothigh(high, 20, 20)     -> tm_lastPHigh + tm_phighBar
  ├─ close[run]                     -> tm_runDown / tm_runUp
  ├─ var state: svBar/svPx/bcBar/bcPx, sweepBl, sos/sow, lvl*, clxE
  └─ ta.highest/lowest(run + 1)     -> mmUp/mmDn (chỉ cho TP measured move)
```

Đã xác nhận **không** có: `request.security`, `request.security_lower_tf`, `lookahead`, offset âm,
mảng, vòng lặp, hay dữ liệu tương lai. Không có nguồn repaint ngoài timeframe/offset hiển thị.

Nguồn biến động duy nhất là **giá trị nến đang chạy**. Pivot là **độ trễ cấu trúc** (20 bar), không phải
repaint: pivot tại bar `p` chỉ được biết tại bar `p + 20`, và giá trị không bao giờ đổi sau đó với dữ liệu đã đóng.

### 3. Cổng confirmed-bar

```pine
tm_okBar = tm_confirmOnly ? barstate.isconfirmed : true   // dòng 186
tm_sigSV = tm_i_evtOn and tm_okBar and tm_isPurple and ... // dòng 293
tm_sigBC = tm_i_evtOn and tm_okBar and ...                 // dòng 294
tm_stRawL = tm_i_evtOn and tm_okBar and (...)              // dòng 357
tm_stRawS = ...                                            // dòng 358
tm_sigNS = tm_i_quietOn and tm_okBar and ...               // dòng 506
tm_sigND = tm_i_quietOn and tm_okBar and ...               // dòng 507
```

- `tm_confirmOnly` mặc định `true`.
- `barstate.isconfirmed` = `true` trên mọi nến lịch sử; trên nến realtime chỉ ở lần tính cuối trước khi đóng.
- Cổng áp cho **SV, BC, ST, NS, ND, NO SWEEP** (dẫn xuất từ ST).
- **Không** áp cho `tm_isPurple` (cờ volume), `tm_pur20`, `tm_eomRun`, `tm_lastPurBar`, `tm_sweepUpBar`,
  `tm_sweepDnBar`, và **`tm_clxE`** — xem §5.

Hệ quả:

| Chế độ | Nến lịch sử | Nến realtime |
|---|---|---|
| `confirmOnly = true` (default) | Sự kiện xuất hiện tại đúng nến, vĩnh viễn | Không có sự kiện cho tới tick cuối |
| `confirmOnly = false` | Vẫn y hệt (historical luôn confirmed) | Sự kiện bật/tắt theo tick → RP1, và lịch sử có thể khác những gì đã thấy → RP5 |

**Kết luận:** `confirmOnly = false` không thể chứng minh bằng backtest và **không được port** (P3). MQL5 chỉ
chạy chế độ nến đóng.

### 4. Ma trận repaint theo thành phần

| Thành phần | Nguồn | Trong nến đang chạy | Sau khi đóng | RP |
|---|---|---|---|---|
| `tm_atr`, `tm_volMA`, `tm_ratio` | `ta.*` | Thay đổi mỗi tick | Cố định | RP1 (hiển thị) |
| Pivot + `tm_plowBar/phighBar` | `ta.pivotlow/high` | Bar xác nhận chỉ xuất hiện khi đủ 20 bar phải; trên realtime có thể xuất hiện giữa nến | Cố định | Không (độ trễ cấu trúc) |
| `tm_svBar/svPx`, `tm_bcBar/bcPx` | `if tm_sigSV/BC` (gated) | Không đổi | Cố định | Không |
| `tm_sweepUpBl/DnBl` | **không gate** | Có thể cập nhật trên nến đang chạy | Cố định | Ảnh hưởng ST trong nến (đã gate) → không RP1 |
| `tm_sigSV/BC/ST/NS/ND` | gated | Luôn `false` | Cố định | Không |
| `tm_noSweep` | từ ST raw (gated) | Luôn `false` | Cố định | Không |
| `tm_clxE` | **không gate** | Có thể bật giữa nến | Giữ nguyên | **RP1 + RP3** |
| `tm_lvlE/S/T` | `if tm_sigST*` (gated) | Không đổi | Cố định | Không |
| Fill/TP/SL tracking | high/low nến | Chạy trên nến đang chạy nếu setup đã tồn tại | Cố định | RP4 (chỉ mô tả) |
| Dashboard | `barstate.islast` | Cập nhật liên tục | n/a | Không phải tín hiệu |
| `alertcondition` | các biến trên | Theo điều kiện | n/a | RP3 cho CLX-E |
| Strategy entry/exit | signal + equity | Có thể hành động trong nến | Fill cuối | RP4, không RP2 |

Không thành phần nào **tính lại giá trị của nến đã đóng** (RP2) khi `confirmOnly = true`. State `var` chỉ
ghi một lần cho mỗi nến đã đóng; vì lịch sử luôn confirmed, chuỗi sự kiện lịch sử là tất định.

### 5. CLX-E — ngoại lệ có chủ đích

```pine
var bool tm_clxE = false
if tm_sigST
    tm_clxE := false
if tm_isPurple and not tm_lvlDone and not na(tm_lvlE) and not na(tm_lvlRisk) and tm_lvlRisk > 0.0
    if tm_lvlDir == 1 and high >= tm_lvlE + tm_i_clxR * tm_lvlRisk
        tm_clxE := true
    ...
```

Ba đặc điểm quan trọng:

1. **Không gate `tm_okBar`** → trên nến realtime, CLX-E có thể bật giữa nến (RP1) và alertcondition
   `LK VSA CLX-E` có thể phát trước khi đóng nến (RP3).
2. **Là state chốt, không phải edge event.** Một khi bật, `tm_clxE` giữ `true` trên mọi nến tiếp theo cho tới
   lần ST kế tiếp. `plotshape` vẽ X trên **từng nến** trong trạng thái đó; `alertcondition` cũng đúng liên tục.
   Nó **không** tự reset khi setup chạm TP/SL.
3. **`tm_i_clxOn` không điều khiển tín hiệu.** Input này chỉ dùng trong `tm_clxDash` (dashboard) và 2
   `plotshape`. `alertcondition` dùng thẳng `tm_clxE`.

Port MQL5 giữ nguyên semantics (D4: buffer CLX-E là state, không phải edge) nhưng **gate theo nến đóng**
để không tạo RP1/RP3 mới (P4). EA phải tự edge-detect nếu muốn một sự kiện duy nhất.

### 6. Kịch bản intrabar

**S1 — Volume vượt TIM rồi tụt trước khi đóng, gate on.** `purple` bật/tắt; SV/BC/ST đều gated → không tín hiệu.
Volume cuối nến quyết định lịch sử. **Không repaint.**

**S2 — SV xuất hiện ở tick cuối, gate on.** `tm_okBar = true` ở tick cuối; SV ghi `svBar/svPx`. Nến sau state
đã có, `svFresh` đúng. **Edge event, không lặp** (vì `purple` chỉ đúng ở bar đó; các bar sau volume thường hạ).

**S3 — Sweep bar xuất hiện trên nến đang chạy rồi close quay lại sai phía.** `tm_sweepUpBar` (không gate) có
thể bật giữa nến; nếu close cuối không > `svPx`, lần tính lại cuối cùng đặt false. ST trong cùng nến bị gate
bởi `tm_okBar` nên **không** vào lệnh. Khi đóng nến, trạng thái sweep cuối cùng được chốt. **Không RP2.**

**S4 — CLX-E bật giữa nến rồi giá đóng cửa dưới ngưỡng.** `tm_clxE` vẫn `true` vì điều kiện đã từng đúng và
không có reset. Đây là **RP1 có thật trong Pine**; port MQL5 chỉ chốt trạng thái theo nến đóng.

**S5 — Setup đã tạo, nến sau chạm cả SL và TP.** Thứ tự Pine: kiểm tra SL trước, `else if` TP → **SL thắng**.
Port MQL5 giữ đúng thứ tự (test F3).

**S6 — Entry limit chưa khớp nhưng giá đã chạm TP.** Pine chỉ xét TP/SL khi `tm_lvlFill` → không ghi nhận TP.
Port giữ nguyên (không bỏ qua bước fill).

**S7 — Pivot mới xuất hiện trong lúc setup mở.** `tm_lvlT` đã chốt; pivot mới chỉ ảnh hưởng setup kế tiếp.
Không repaint setup đang mở.

**S8 — `confirmOnly = false`.** Trên realtime, SV/BC/ST có thể nhấp nháy; lịch sử vẫn “đẹp”. **RP1 + RP5.**
Không port (P3).

### 7. Hành vi alert

| Alert | Điều kiện | Gate | Đánh giá |
|---|---|---|---|
| SV / BC | `tm_sigSV` / `tm_sigBC` | Có | An toàn với gate on |
| ST LONG / ST SHORT | `tm_sigSTl` / `tm_sigSTs` | Có | An toàn |
| NS / ND | `tm_sigNS` / `tm_sigND` | Có | An toàn |
| NO SWEEP | `tm_noSweep` (từ ST raw) | Có | An toàn |
| CLX-E | `tm_clxE` | **Không** | RP3; alert lặp mỗi nến khi state còn bật |

Alert không phụ thuộc input hiển thị (`tm_i_showViz`, `tm_i_showSig`, `tm_i_clxOn`). Tắt shape **không**
tắt alert.

### 8. Hành vi strategy (chỉ mô tả, không port)

Header: `pyramiding = 5`, `calc_on_order_fills = true`, `process_orders_on_close = true`, commission 0.05%/chiều,
slippage 0. Entry/exit dùng thẳng `tm_lvlE/S/T` của indicator — không tính lại tín hiệu, nên backtest và
indicator không lệch nhau.

- Chế độ 1 lệnh: `strategy.entry("Long"/"Short")` market tại close bar ST, `strategy.exit("VSA X")`.
- Chế độ pyramid: N lệnh limit `L1..Ln`/`S1..Sn`, lệch `(i-(N+1)/2) * btStep * ATR`; exit riêng từng ID.
- `strategy.exit` chỉ gửi khi `not tm_lvlDone`; nến entry không bị exit kiểm tra cùng nến (`lvlB == bar_index`).

**RP4 (chỉ nếu port execution):** fill/exit được Pine mô phỏng theo broker emulator; với
`process_orders_on_close=true`, lệnh market khớp tại close nến tín hiệu. Không được coi đây là mô hình fill
chuẩn. Repo này **không** port execution.

### 9. Timestamp contract

| Trường | Định nghĩa | Ví dụ M5 |
|---|---|---|
| `bar_open_time` | Thời gian mở nến theo giờ server | `2026.10.27 20:50` |
| `signal_bar` | Nến mà điều kiện đúng | nến `20:50` |
| `confirmed_at` | `bar_open_time + TF` | `20:55:00` |
| `detected_at` | Tick đầu tiên EA đọc buffer `shift=1` | `20:55:00 … 20:59:59` |
| `signal_id` | `SV`, `BC`, `ST_LONG`, `ST_SHORT`, `NS`, `ND`, `NO_SWEEP`, `CLX_E` | — |

Join parity theo `bar_open_time`, **không** theo `detected_at`.

### 10. Chính sách MQL5

| Mã | Quyết định | Lý do |
|---|---|---|
| P1 | Chỉ tính sự kiện khi `j < rates_total-1` (nến đóng) | Loại RP1/RP3 ở nguồn |
| P2 | EA đọc `shift = 1`; không có input `shift = 0` | Khớp roadmap |
| P3 | **Không port** `confirmOnly = false` | Repaint theo thiết kế, không parity được |
| P4 | CLX-E: buffer phản ánh **state**, chỉ ghi trên nến đóng | Giữ semantics Pine, tránh RP1 mới; EA edge-detect |
| P5 | Sweep state cập nhật theo bar như Pine nhưng chỉ ảnh hưởng bar sau | Tương đương lịch sử |
| P6 | Pivot: xác nhận tại `bar_index`, freshness tính từ bar xác nhận | Khớp Pine (`tm_plowBar := bar_index`) |
| P7 | `risk <= 0` → không tạo setup | Khớp `if rk1 > 0` |
| P8 | Fill trước, rồi SL trước TP trong cùng nến | Khớp thứ tự Pine |
| P9 | Không port strategy entry/exit, equity sizing | Signal-only |
| P10 | Session dùng offset UTC cố định, không DST | MQL5 không có tz database; mặc định tắt (D2 spec) |

### 11. Kế hoạch xác minh thủ công (TradingView)

| # | Bước | Kỳ vọng | Trạng thái |
|---|---|---|---|
| E1 | LK VSA, XAUUSD M5, `confirmOnly=true`, Bar Replay từng tick | Không nhãn trước tick cuối; nhãn giữ nguyên khi replay tiếp | `PENDING` |
| E2 | Cùng cấu hình, `confirmOnly=false` | Ghi lại các nhãn xuất hiện rồi mất; đếm | `PENDING` |
| E3 | Alert CLX-E “Once Per Bar” khi setup mở | Ghi nhận alert lặp mỗi nến khi state còn bật | `PENDING` |
| E4 | Alert ST LONG/ST SHORT với gate on | Không phát trước đóng nến | `PENDING` |
| E5 | Bar Replay, một setup chạm cả SL và TP trong một nến | Xác nhận SL được ghi trước | `PENDING` |
| E6 | Setup limit chưa khớp, giá chạm TP | Dashboard không ghi TP | `PENDING` |
| E7 | Pivot mới trong lúc setup mở | Entry/SL/TP không đổi | `PENDING` |
| E8 | `sweepReq=false` vs `true` trên cùng dữ liệu | Đếm số ST bị chặn bởi NO SWEEP | `PENDING` |

### 12. Risk register

| ID | Phát hiện | Mức | Xử lý |
|---|---|---|---|
| R1 | `confirmOnly=false` repaint, không phát hiện được bằng backtest | Cao | P3 |
| R2 | CLX-E không gate + là state chốt | Cao | P4; EA edge-detect; ghi D4 |
| R3 | Alert CLX-E lặp mỗi nến | Trung bình | Không port alert; CSV ghi edge |
| R4 | Pivot tie-breaking không được Pine tài liệu hóa | Trung bình | D3; đối chiếu CSV parity |
| R5 | Session tz/DST khác MQL5 | Thấp (mặc định tắt) | D2 |
| R6 | Strategy pyramid ID/exit phức tạp | Cao nếu port execution | Không port execution |
| R7 | Volume Pine vs tick_volume | Trung bình | D1; ghi rõ khi parity |

### 13. Gate 2 — tiêu chí

| # | Tiêu chí | Trạng thái |
|---|---|---|
| B1 | Trả lời đủ câu hỏi repaint của roadmap Phase 2 | PASS |
| B2 | Timestamp + confirmed state cho từng signal | PASS |
| B3 | Ma trận repaint theo thành phần | PASS |
| B4 | Chính sách MQL5 không âm thầm đổi logic | PASS |
| B5 | Không tuyên bố đã kiểm chứng runtime TradingView | PASS (E1–E8 `PENDING`) |
| B6 | Không sửa Pine | PASS |

**Kết luận:** Gate 2 đạt ở mức phân tích tĩnh. Các kết luận phụ thuộc runtime (E1–E8) vẫn `PENDING` và không
được dùng làm bằng chứng parity/backtest.

### 14. Câu hỏi còn mở

1. Pine `ta.pivotlow/high` xử lý tie (hai đáy bằng nhau) thế nào? (R4/E-parity)
2. Alert CLX-E thực tế phát mỗi nến hay chỉ một lần theo cài đặt “Once Per Bar”? (E3)
3. `confirmOnly=false` có bao giờ cho lịch sử khác `true`? (E2)
4. Symbol/timeframe/timezone chuẩn cho parity vẫn chưa chốt.

## Buffer Contract — LongKaco VSA (Pine v6 → MQL5)

- **Phase:** 3 — Đặc tả thuật toán và hợp đồng buffer trước khi port
- **Ngày:** 2026-10-28
- **Trạng thái:** `CONTRACT_FROZEN_FOR_PHASE4`
- **Nguồn:** `INDICATOR_SPEC_LongKacoVSA.md`,
  `REPAINT_AUDIT_LongKacoVSA.md`
- **Nguyên tắc bất biến:** SIMULATION_ONLY. Không API gửi lệnh, không đọc tài khoản, không alert, không WebRequest.

### 1. Phạm vi

1. Input của `MQL5/Indicators/PinePort/LongKacoVSA.mq5`.
2. **21 buffer hợp đồng** (index 8..28) cho EA + **8 buffer render** (index 0..7).
3. Bar policy: chỉ nến đã đóng; tín hiệu là edge trừ CLX-E là state.
4. Cách EA đọc buffer, chống trùng, ghi CSV.
5. 47 test vector tổng hợp cho logic thuần trong `LongKacoVSAContract.mqh`.

Không định nghĩa: execution, sizing, SL/TP engine, alert. Repo không port các phần đó.

### 2. Chính sách kế thừa Phase 2

| Mã | Chính sách | Thể hiện |
|---|---|---|
| P1 | Sự kiện chỉ trên nến đóng | Tại `j == rates_total-1`, mọi buffer sự kiện = `0.0` |
| P2 | EA đọc `shift = 1` | Mục 10 |
| P3 | Không port `confirmOnly = false` | Không có input; ghi D7 spec |
| P4 | CLX-E là **state**, gate theo nến đóng | Buffer 15 giữ `1.0` tới lần ST kế tiếp |
| P5 | Sweep state theo bar như Pine | Chỉ ảnh hưởng bar sau, không đổi lịch sử |
| P6 | Freshness pivot tính từ **bar xác nhận** | `plowBar` = `bar_index` khi nhận pivot |
| P7 | `risk <= 0` không tạo setup | `LkSetupLong/Short` trả `false` |
| P8 | Fill trước; SL trước TP | `LkTrackSetup` |

### 3. Input contract

| # | Input MQL5 | Kiểu | Default | Clamp (Pine min/max) |
|---:|---|---|---:|---|
| 1 | `InpSignalMode` | enum | `LK_SIGNAL_VSA` | 0 VSA, 1 Wyckoff |
| 2 | `InpWyckoffEvent` | enum | `LK_WYCKOFF_LPS` | Spring / SOS / LPS |
| 3 | `InpEntryMode` | enum | `LK_ENTRY_MARKET` | Market / Limit |
| 4 | `InpTpMode` | enum | `LK_TP_R` | R / Pivot / MM |
| 5 | `InpLen` | int | 20 | 5..100 |
| 6 | `InpRP` | double | 2.2 | ≥ 1.5 |
| 7 | `InpRVH` | double | 1.8 | ≥ 1.0 |
| 8 | `InpRH` | double | 1.2 | ≥ 0.8 |
| 9 | `InpRN` | double | 0.8 | ≥ 0.4 |
| 10 | `InpRL` | double | 0.4 | ≥ 0.1 |
| 11 | `InpPurWin` | int | 20 | 5..100 |
| 12 | `InpVolMin` | double | 0.0 | ≥ 0 |
| 13 | `InpEvtOn` | bool | true | — |
| 14 | `InpQuietOn` | bool | true | — |
| 15 | `InpRun` | int | 5 | 1..50 |
| 16 | `InpLvTol` | double | 0.5 | ≥ 0.1 |
| 17 | `InpLvFresh` | int | 60 | 10..500 |
| 18 | `InpTestR` | double | 1.2 | 0.3..2.0 |
| 19 | `InpRetestT` | double | 1.0 | ≥ 0.2 |
| 20 | `InpAtrLen` | int | 14 | 2..100 |
| 21 | `InpPivLen` | int | 20 | 5..100 |
| 22 | `InpSosSpread` | double | 1.0 | ≥ 0.2 |
| 23 | `InpSosVol` | double | 1.2 | ≥ 0.5 |
| 24 | `InpLpsTol` | double | 0.5 | ≥ 0.1 |
| 25 | `InpSweepReq` | bool | true | — |
| 26 | `InpSweepWin` | int | 10 | 0..100 |
| 27 | `InpClxOn` | bool | true | **dashboard-only** (D4) |
| 28 | `InpClxR` | double | 1.5 | ≥ 0.5 |
| 29 | `InpSlBuf` | double | 0.5 | ≥ 0.1 |
| 30 | `InpRrFb` | double | 2.0 | ≥ 0.5 |
| 31 | `InpFeePct` | double | 0.05 | ≥ 0 |
| 32 | `InpFeeMaxR` | double | 0.15 | ≥ 0.01 |
| 33 | `InpSessionOn` | bool | false | — |
| 34 | `InpSession` | string | `"0800-1600"` | `HHMM-HHMM` |
| 35 | `InpSessionUtcOffsetMin` | int | 420 | −720..840 |

Không port: `tm_confirmOnly` (D7), `tm_i_show*`, `tm_i_dash*`, `tm_i_pivOn`, `tm_i_lvlOn`,
`tm_i_sessTz` (chỉ dashboard). Session dùng offset cố định thay vì tên tz (D2).

### 4. Signal ID

| ID | Side | Buffer | Trigger | Ghi chú |
|---|---|---|---|---|
| `SV` | BUY | 8 | `sig_sv` | Volume TIM + giá chạy xuống + gần hỗ trợ + nến tăng |
| `BC` | SELL | 9 | `sig_bc` | Volume TIM + giá chạy lên + gần kháng cự + bóng trên ≥ 50% |
| `ST_LONG` | BUY | 10 | `st_l` | Retest SV volume thấp + sweep gate |
| `ST_SHORT` | SELL | 11 | `st_s` | Retest BC volume thấp + sweep gate |
| `NS` | BUY | 12 | `sig_ns` | No Supply |
| `ND` | SELL | 13 | `sig_nd` | No Demand |
| `NO_SWEEP` | — | 14 | `no_sweep` | Setup đủ điều kiện nhưng thiếu sweep (blocked, không phải entry) |
| `CLX_E` | — | 15 | `clx_e` | **State** cảnh báo chốt; EA phải edge-detect |

### 5. Buffer

`indicator_buffers = 29`, `indicator_plots = 8`; plot `i` map buffer `i` (0..7).

#### 5.1 Render buffers 0..7 (DATA, không thuộc hợp đồng EA)

| # | Tên | Giá trị | Thiếu |
|---:|---|---|---|
| 0 | `PLOT_SV` | `low` bar SV | `EMPTY_VALUE` |
| 1 | `PLOT_BC` | `high` bar BC | `EMPTY_VALUE` |
| 2 | `PLOT_ST_LONG` | `low` bar STL | `EMPTY_VALUE` |
| 3 | `PLOT_ST_SHORT` | `high` bar STS | `EMPTY_VALUE` |
| 4 | `PLOT_NS` | `low` bar NS | `EMPTY_VALUE` |
| 5 | `PLOT_ND` | `high` bar ND | `EMPTY_VALUE` |
| 6 | `PLOT_NO_SWEEP` | `high` bar NO SWEEP | `EMPTY_VALUE` |
| 7 | `PLOT_CLX_E` | `high` (dir 1) / `low` (dir −1) | `EMPTY_VALUE` |

#### 5.2 Contract buffers 8..28

| # | Tên | Ý nghĩa | Miền | Thiếu | Loại | EA dùng |
|---:|---|---|---|---|---|---|
| 8 | `SV` | Sự kiện Stopping Volume | 0/1 | 0 | CALC | **có** |
| 9 | `BC` | Sự kiện Buying Climax | 0/1 | 0 | CALC | **có** |
| 10 | `ST_LONG` | Setup test mua | 0/1 | 0 | CALC | **có** |
| 11 | `ST_SHORT` | Setup test bán | 0/1 | 0 | CALC | **có** |
| 12 | `NS` | No Supply | 0/1 | 0 | CALC | **có** |
| 13 | `ND` | No Demand | 0/1 | 0 | CALC | **có** |
| 14 | `NO_SWEEP` | ST raw bị chặn bởi sweep gate | 0/1 | 0 | CALC | debug |
| 15 | `CLX_E` | State climax tại target (giữ tới ST kế) | 0/1 | 0 | CALC | **có (edge)** |
| 16 | `TIM_BAR` | Nến có volume TIM sau `evtOk` | 0/1 | 0 | CALC | debug |
| 17 | `VOL_RATIO` | `vol / volMA` | ≥ 0 | 0 | CALC | debug |
| 18 | `VOL_MA` | Wilder RMA volume | > 0 | `EMPTY_VALUE` | CALC | debug |
| 19 | `ATR` | Pine ATR (RMA của TR) | > 0 | `EMPTY_VALUE` | CALC | debug |
| 20 | `PIV_LOW` | Pivot low gần nhất | giá | `EMPTY_VALUE` | CALC | debug |
| 21 | `PIV_HIGH` | Pivot high gần nhất | giá | `EMPTY_VALUE` | CALC | debug |
| 22 | `ENTRY` | Entry setup gần nhất | giá | `EMPTY_VALUE` | CALC | **có** |
| 23 | `SL` | Stop loss setup gần nhất | giá | `EMPTY_VALUE` | CALC | **có** |
| 24 | `TP` | Take profit setup gần nhất | giá | `EMPTY_VALUE` | CALC | **có** |
| 25 | `DIR` | Hướng setup | −1/0/1 | 0 | CALC | **có** |
| 26 | `FILL` | Entry đã khớp | 0/1 | 0 | CALC | **có** |
| 27 | `RESULT` | Trạng thái setup | 0,1,2,3 | 0 | CALC | **có** |
| 28 | `LAST_EVENT` | Sự kiện ưu tiên gần nhất | 0..5 | 0 | CALC | debug |

`RESULT`: `0` = chưa có setup, `1` = đang mở, `2` = TP, `3` = SL.
`LAST_EVENT`: `0` none, `1` SV, `2` BC, `3` ST, `4` NS, `5` ND (đúng thứ tự ưu tiên Pine).

Quy ước:

- Buffer sự kiện = `0.0` trên mọi nến không có sự kiện; **không** dùng `EMPTY_VALUE`.
- `ENTRY/SL/TP/PIV_*` dùng `EMPTY_VALUE` khi chưa có; **không** dùng `0.0`.
- `CLX_E` là state: `1.0` trên mọi nến từ lúc bật tới lần ST kế tiếp, kể cả sau khi setup đóng.
  EA ghi CSV theo **edge** (`CLX_E == 1 && prev == 0`), không ghi lặp.
- Tại `j == rates_total-1` (nến đang chạy) toàn bộ buffer 8..28 giữ giá trị `0`/`EMPTY_VALUE` cho sự kiện;
  tuy nhiên EA chỉ đọc `shift=1` nên không phụ thuộc.

### 6. Bar policy và state

Indicator tính lại **toàn bộ lịch sử** khi `rates_total` thay đổi (nến mới) để state `var` của Pine được
tái lập tất định; trong cùng một nến chỉ trả `rates_total` mà không tính lại. Hệ quả:

- Mọi buffer của nến đã đóng là hàm thuần của dữ liệu đã đóng → không RP2.
- Không có state ẩn nào sống qua các lần gọi; reload indicator cho cùng kết quả.
- Chi phí O(n) mỗi nến, không phải mỗi tick.

Pine `var` tương ứng: `lastPLow/lastPHigh + bar`, `svBar/svPx`, `bcBar/bcPx`, `sweepUpBl/sweepDnBl`,
`sos*`, `sow*`, `lvlE/S/T/B/Dir/Fill/FillBar/Done/Res/Risk`, `clxE`, `lastEvt`. Tất cả là biến cục bộ
trong `OnCalculate`, khởi tạo lại mỗi lần tính.

### 7. Công thức setup (hàm thuần trong contract)

```text
LONG :
  market = entryMode == Market || signalMode == Wyckoff
  entry  = market ? close : svPx
  sl     = (wyckoff ? low : svPx) - slBuf * atr
  risk   = entry - sl                          // hợp lệ khi risk > 0
  tpR    = entry + rrFb * risk
  tpPv   = (pivHigh valid && pivHigh >= entry + risk) ? pivHigh : tpR
  tpMM   = (pivHigh fresh && mmUp > risk) ? entry + mmUp : tpR
SHORT : đối xứng với bcPx, high, pivLow, mmDn
```

`mmUp = lastPHigh - lowest(low, run+1)`, `mmDn = highest(high, run+1) - lastPLow`.

### 8. Fill / TP / SL

Chỉ xét khi `setup valid`, `!done`, `bar_index > lvlB`:

1. Nếu chưa fill: LONG `low <= entry`, SHORT `high >= entry` → fill.
2. Nếu đã fill: **SL trước** — LONG `low <= sl`; SHORT `high >= sl` → `RESULT=3`.
3. Ngược lại TP — LONG `high >= tp`; SHORT `low <= tp` → `RESULT=2`.

Cùng nến chạm cả hai → SL thắng. Không xét TP/SL trước khi fill.

### 9. CLX-E

```text
reset về false khi có ST (long hoặc short)
nếu TIM && setup mở && risk > 0:
    dir 1 : high >= entry + clxR*risk → true
    dir −1: low  <= entry - clxR*risk → true
```

Không phụ thuộc `clxOn` (giữ đúng Pine — D4). Không tự reset khi TP/SL.

### 10. EA đọc buffer

- `iCustom(_Symbol,_Period,"PinePort\\LongKacoVSA.mq5", <35 inputs>)`.
- Chờ `BarsCalculated(handle) >= Bars(_Symbol,_Period)`.
- `CopyBuffer(handle, LK_BUF_SV, 1, 1, v)` … cho từng ID EA hỗ trợ; `shift = 1` cố định.
- Dedupe theo `(symbol, timeframe, bar_open_time, signal_id)`; `NO_SWEEP` không phải entry nhưng vẫn ghi log
  để đối chiếu (nếu EA bật).
- `CLX_E` ghi theo edge (mục 5.2); `RESULT` chỉ dùng để đối chiếu, không phải tín hiệu.
- Không có `OrderSend`, `CTrade`, `AccountInfo*`, `WebRequest`, `Socket*`.

### 11. CSV (EA)

```
detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,signal_id,side,
dir,entry,sl,tp,vol_ratio,atr,input_hash
```

- `mode`: `VSA` / `WYCKOFF_SPRING` / `WYCKOFF_SOS` / `WYCKOFF_LPS`.
- `side`: `BUY` cho SV/ST_LONG/NS, `SELL` cho BC/ST_SHORT/ND, `NONE` cho NO_SWEEP/CLX_E.
- `entry/sl/tp` lấy buffer 22/23/24 cùng nến; rỗng = `EMPTY_VALUE`.
- `input_hash` = FNV-1a trên canonical string của `LkConfig` + version.

### 12. Test vector (47)

| Nhóm | # | Nội dung |
|---|---:|---|
| A bucket | 7 | Ngưỡng TIM/VH/H/N/L/VL và MA ≤ 0 → VL |
| B flags | 5 | purple, quietST, quietLow tại biên |
| C sweep | 5 | age −1, recent, quá hạn, win 0, cùng bar |
| D pivot | 6 | low/high, tie, biên trái, thiếu bar phải |
| E setup | 8 | R/pivot/MM/fallback long, limit, wyckoff, risk ≤ 0, short |
| F tracking | 6 | fill, SL, SL ưu tiên, TP, short SL, short TP |
| G clx | 4 | long/short trigger, chưa đạt, risk 0 |
| H misc | 6 | RMA, ratio, clamp, hash |

Chi tiết kỳ vọng nằm trong `mt5/Scripts/LongKacoVSAContractTests.mq5`. Chạy script trong MT5 terminal là
bước **thủ công**; compile không chứng minh test pass.

### 13. Trạng thái

| Hạng mục | Trạng thái |
|---|---|
| Contract | FROZEN |
| Header | `mt5/Include/PinePort/LongKacoVSAContract.mqh` |
| Indicator | `mt5/Indicators/PinePort/LongKacoVSA.mq5` |
| Contract tests | `mt5/Scripts/LongKacoVSAContractTests.mq5` — **chưa chạy** |
| EA hỗ trợ LongKaco | `NOT_IMPLEMENTED` (EA hiện chỉ đọc Wonderwhales) |
| Parity | `BLOCKED` — chưa có CSV Pine |
