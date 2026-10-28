# Pine Inventory và MQL5 Compatibility

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `PINE_INVENTORY.md`, `PINE_MQL5_COMPATIBILITY.md`.

Nội dung:
1. Pine Inventory — Phase 0/1
2. Pine ↔ MQL5 compatibility — Wonderwhales

---
## Pine Inventory — Phase 0/1

- **Ngày:** 2026-10-28 (Phase 1 cập nhật cùng ngày)
- **Source root:** `D:\Applications\tm-trading\pine` (repo `tm-trading`, HEAD `3db2929`, nhánh `main`)
- **Trạng thái source:** chỉ đọc. Không file Pine nào bị sửa, đổi tên hay copy vào repo này.
- **Số file:** 86 file `.pine`
  - 12 file build hoàn chỉnh trong `dist/`
  - 70 file module trong 6 thư mục `parts-*`
  - 4 file helper trong `shared/`
- **Pine version:** mọi file dist và header khai báo `//@version=6`. Các file parts không khai báo version
  riêng; chúng được ghép vào header qua marker `{{DECL}}` / `{{SHARED}}`.
- **License:** không tìm thấy header license/copyright rõ ràng trong 86 file. Cần người dùng xác nhận
  quyền sử dụng trước khi phân phối; inventory này chỉ phục vụ port nội bộ.

### 1. Cách đọc inventory

Trạng thái khả thi ban đầu (Phase 0, chưa phải kết luận port):

| Mã | Nghĩa |
|---|---|
| `PWD` | `PORTABLE_WITH_DIFFERENCES` — có source đầy đủ, có thể port nhưng chắc chắn có khác biệt MTF/execution |
| `NP` | `NOT_PORTABLE_AS_IS` — fragment/helper, không compile độc lập; chỉ port như một phần của target |
| `BLOCKED` | `BLOCKED_NEEDS_INPUT` — thiếu source/dữ liệu quyết định |

Không file nào `BLOCKED` vì thiếu source. Blocker cấp dự án là **chọn target** và **reference export**
(Phase 6), ghi ở mục 6.

### 2. File build hoàn chỉnh — `dist/`

Đây là các target nên đọc khi port; `parts-*` chỉ là reference/nguồn ghép.

| File | Title | Loại | Inputs | Dòng | `request.security` | `barstate` | lookahead | `strategy.entry` | alertcondition | Trạng thái |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| `LongKaco VSA Backtest.pine` | LongKaco VSA Backtest | strategy | 49 | 600 | 0 | 1 | 0 | 5 | 8 | PWD |
| `LongKaco VSA.pine` | LongKaco VSA | indicator | 45 | 681 | 0 | 5 | 0 | 0 | 8 | PWD |
| `Price Action MTF Backtest.pine` | Price Action MTF Backtest | strategy | 147 | 1826 | 8 | 24 | 14 | 2 | 6 | PWD |
| `Price Action MTF.pine` | Price Action MTF | indicator | 144 | 1801 | 8 | 24 | 14 | 0 | 6 | PWD |
| `TM Fusion Zones Backtest.pine` | TM Fusion Zones Backtest | strategy | 58 | 1065 | 1 | 3 | 1 | 2 | 5 | PWD |
| `TM Fusion Zones.pine` | TM Fusion Zones | indicator | 55 | 1035 | 1 | 3 | 1 | 0 | 5 | PWD |
| `TM Indicator 2.pine` | TM Indicator 2 | indicator | 151 | 2243 | 6 | 12 | 10 | 0 | 8 | PWD |
| `TM Indicator Strategy Lab 2.pine` | TM Indicator Strategy Lab 2 | strategy | 155 | 2330 | 6 | 12 | 10 | 16 | 0 | PWD |
| `TM XAU Signals 2.pine` | TM XAU Signals 2 | indicator | 118 | 1383 | 8 | 23 | 14 | 0 | 4 | PWD |
| `Wonderwhales Backtest.pine` | Wonderwhales Backtest | strategy | 50 | 614 | 0 | 3 | 0 | 6 | 0 | PWD (spec, execution) |
| `Wonderwhales Overlay.pine` | Wonderwhales Overlay | indicator | 37 | 417 | 0 | 3 | 0 | 0 | 4 | PWD (render-only) |
| `Wonderwhales.pine` | Wonderwhales | indicator | 37 | 415 | 0 | 3 | 0 | 0 | 4 | PWD (spec, reference) |

Ghi chú:

- **Target Phase 1 đã chốt: Wonderwhales.** Spec tại [`INDICATOR_SPEC_Wonderwhales.md`](wonderwhales.md).
- `Wonderwhales.pine` là **reference signal**. `Wonderwhales Overlay.pine` giống hệt phần tính toán/tín hiệu;
  chỉ khác `overlay`, bỏ 2 plot volume và thêm `plotcandle` tô nến. Không chọn Overlay làm reference.
- `Wonderwhales Backtest.pine` là reference cho **execution semantics** (entry/SL/TP/BE/trailing/ladder),
  không phải lệnh thật. Spec ghi rõ 2 lỗi logic không được port mù: Ladder + `pyramiding=0` và
  Ladder + Reversal (`strategy.close("Long")` không khớp entry ID `Long1/Long2`).
- `TM XAU Signals 2.pine` chỉ có indicator, **không có strategy**. Muốn thành EA phải thiết kế thêm lớp
  entry/exit; không được tự suy diễn từ phần hiển thị.
- 5 file `*Backtest.pine` / `Strategy Lab 2` chứa `strategy.entry`; đây là logic tham chiếu, **không phải**
  lệnh thật và không được chuyển thành API gửi lệnh trong MQL5.

### 3. Module nguồn — `parts-*`

Tất cả file dưới đây là fragment, trạng thái `NP`. Số dòng lấy từ file thực tế.

#### 3.1 `parts-tm` — TM Indicator 2 & Strategy Lab 2, v2.1.0 (14 file)

| Module | Dòng | Vai trò theo tên |
|---|---:|---|
| `00_header.pine` | 44 | Header, marker `{{DECL}}`/`{{SHARED}}`, mô tả kiến trúc v2.1 |
| `01_inputs_and_profiles.pine` | 198 | Input và profile (151 input trong bản dist) |
| `02_types_and_state_defs.pine` | 93 | UDT/state definitions |
| `03_regime_and_volatility.pine` | 64 | Regime classifier, volatility |
| `04_structure_pa_liquidity.pine` | 280 | Structure, price action, liquidity |
| `05_momentum_volume_extension.pine` | 60 | Momentum/volume/extension |
| `06_mtf_and_intermarket_tuple.pine` | 68 | MTF tuple + intermarket |
| `07_obstacle_and_gates.pine` | 122 | Obstacle/room-to-left gate |
| `08_adaptive_scoring_engine.pine` | 115 | Scoring thích ứng |
| `08b_entry_modes.pine` | 87 | Entry mode A/B/C |
| `09_plan_and_state_machine.pine` | 434 | Plan + state machine |
| `10_visuals_and_dashboard.pine` | 405 | Dashboard/visual |
| `11_alerts.pine` | 73 | Alert JSON |
| `11_strategy_exec.pine` | 97 | Strategy execution (16 `strategy.entry`) |

#### 3.2 `parts-fusion-zones` — TM Fusion Zones, v1.0.0 (12 file)

| Module | Dòng | Vai trò theo tên |
|---|---:|---|
| `00_header.pine` | 13 | Header + marker |
| `10_config.pine` | 78 | Input/config |
| `20_core.pine` | 92 | Core calculations |
| `30_ribbon.pine` | 44 | Trend ribbon |
| `40_zones.pine` | 148 | Supply/demand zones |
| `50_structure.pine` | 101 | Market structure |
| `60_setups.pine` | 53 | 3 entry setups |
| `70_scoring_risk.pine` | 129 | Scoring + risk gate |
| `80_state.pine` | 111 | State/lifecycle |
| `90_strategy_exec.pine` | 31 | Strategy execution (2 entry) |
| `95_viz.pine` | 172 | Visual/dashboard |
| `99_alerts.pine` | 37 | Alerts |

#### 3.3 `parts-price-action-mtf` — Price Action MTF, v1.0.0 (14 file)

| Module | Dòng | Vai trò theo tên |
|---|---:|---|
| `00_header.pine` | 47 | Header, layer map L0–L12 |
| `10_config.pine` | 227 | Input/config (144 input trong dist) |
| `20_core.pine` | 73 | ATR/VSA/EMA/session core |
| `30_structure.pine` | 391 | Swing/BOS/CHoCH/MSS + UDT |
| `40_liquidity.pine` | 185 | PDH/PDL, sweep, trendline |
| `50_zones.pine` | 119 | S/R, FVG, order block |
| `60_candle.pine` | 85 | Candle patterns |
| `70_indicators.pine` | 49 | RSI/MACD/DMI/BBW/VWAP |
| `75_mtf.pine` | 17 | MTF context/setup |
| `80_scoring_risk.pine` | 155 | Scoring + risk |
| `90_state.pine` | 121 | Position lifecycle |
| `91_strategy.pine` | 31 | Strategy execution (2 entry) |
| `95_viz.pine` | 187 | Dashboard |
| `99_alerts.pine` | 42 | Alerts |

#### 3.4 `parts-longkaco-vsa` — LongKaco VSA (8 file)

| Module | Dòng | Vai trò theo tên |
|---|---:|---|
| `00_header.pine` | 4 | Header + marker |
| `10_inputs.pine` | 107 | Input (41 input trong parts) |
| `20_volume.pine` | 42 | VSA volume |
| `30_levels.pine` | 66 | Levels |
| `40_events.pine` | 228 | Event detection |
| `50_strategy.pine` | 67 | Strategy execution (5 entry) |
| `60_viz.pine` | 148 | Visual |
| `70_alerts.pine` | 13 | Alerts |

#### 3.5 `parts-wonderwhales` — Wonderwhales, v1.2.0 (9 file)

| Module | Dòng | Vai trò theo tên |
|---|---:|---|
| `00_header.pine` | 15 | Header + marker |
| `10_config.pine` | 58 | Input/config (37 input trong dist) |
| `20_core.pine` | 39 | Core |
| `30_calc.pine` | 54 | Calculations |
| `40_signals.pine` | 51 | PSAR/VSA signals |
| `45_strategy_exec.pine` | 207 | Strategy execution (6 entry) |
| `50_viz.pine` | 84 | Visual |
| `60_dashboard.pine` | 49 | HUD |
| `70_alerts.pine` | 20 | Alerts |

#### 3.6 `parts-xau` — TM XAU Signals 2, v2.0.0 (13 file)

| Module | Dòng | Vai trò theo tên |
|---|---:|---|
| `00_header.pine` | 43 | Header, layer map L0–L12 |
| `10_config.pine` | 157 | Input/config (118 input trong dist) |
| `20_core.pine` | 73 | ATR/VSA/EMA/session core |
| `30_structure.pine` | 176 | Structure |
| `40_liquidity.pine` | 182 | Liquidity |
| `50_zones.pine` | 114 | S/R, FVG, OB |
| `60_candle.pine` | 41 | Candle patterns |
| `70_indicators.pine` | 47 | Indicator nhóm |
| `75_mtf.pine` | 17 | MTF |
| `80_scoring_risk.pine` | 97 | Scoring + risk |
| `90_state.pine` | 121 | State |
| `95_viz.pine` | 169 | Dashboard |
| `99_alerts.pine` | 40 | Alerts |

**Không có module strategy** trong `parts-xau`; dist XAU chỉ là indicator.

### 4. Shared helpers — `shared/` (4 file, `NP`)

| File | Dòng | Nội dung |
|---|---:|---|
| `common.pine` | 52 | Session filter, VSA color/name, clamp, format, timestamp, session windows |
| `sess-inputs.pine` | 17 | Input phiên |
| `tm-signal-quality.pine` | 96 | Signal quality helper |
| `zones.pine` | 49 | Zone helper (7 `array.*`, 4 vòng lặp) |

### 5. Ma trận phụ thuộc và rủi ro repaint (sơ bộ)

| Nhóm | `request.security` | `barstate` | lookahead | array | vòng lặp | Rủi ro chính |
|---|---:|---:|---:|---:|---:|---|
| Price Action MTF | 8 | 24 | 14 | 120 | 18 | MTF + array + pivot; cần audit lookahead/confirmed bar |
| TM XAU Signals 2 | 8 | 23 | 14 | 41 | 13 | MTF + array; không có strategy layer |
| TM Indicator 2 / Strategy Lab 2 | 6 | 12 | 10 | 35 | 15 | State machine lớn, nhiều input, MTF |
| TM Fusion Zones | 1 | 3 | 1 | 36 | 9 | Zones/array; ít MTF hơn |
| LongKaco VSA | 0 | 5 | 0 | 0 | 4 | Đơn giản hơn; VSA/levels |
| Wonderwhales | 0 | 3 | 0 | 0 | 0 | Đơn giản nhất; PSAR + VSA |

Kiểm tra thêm trên bản dist:

- `request.security_lower_tf`: **0** ở cả 12 file.
- `barstate.isrealtime`: **0** ở cả 12 file.
- `barstate.islast`: 1–4 lần tùy file (dùng cho dashboard/last bar).
- `barstate.isconfirmed`: 1–22 lần; cần xác minh đây là gate thật cho tín hiệu, không chỉ cho label.
- `calc_on_every_tick=1` chỉ có ở `Wonderwhales Backtest.pine`; các file còn lại không bật.
- `process_orders_on_close=1` ở 5 file backtest; đây là hành vi TradingView, không tự động đúng trong
  MQL5 và không được chuyển thành execution thật.
- Không file nào dùng `request.security_lower_tf`, nên chưa thấy phụ thuộc LTF trực tiếp.

**Kết luận:** chưa thể tuyên bố file nào không repaint. Phase 2 phải kiểm tra từng tín hiệu với
`barstate.isconfirmed`, thời điểm bar đóng, `lookahead`, và MTF alignment trước khi port.

### 6. Blocker cấp dự án

1. ~~**Chưa chọn target.**~~ **Đã giải quyết 2026-10-28:** chọn Wonderwhales; spec Phase 1 đã tạo.
2. **Chưa có reference export từ Pine.** Comparator và test đã có; parity thật `BLOCKED` cho đến khi có
   CSV trên cùng symbol/timeframe/timezone/input. Cần người dùng export; không được tạo CSV giả.
3. **License chưa xác nhận.** Không thấy header license; cần xác nhận quyền sử dụng trước khi phân phối.
4. ~~**Bản trùng Wonderwhales.**~~ **Đã giải quyết:** `Wonderwhales.pine` là reference signal;
   `Wonderwhales Overlay.pine` chỉ khác phần render.
5. **XAU thiếu strategy layer.** Không được tự tạo entry/exit rồi gọi đó là “port Pine”.
6. **Hành vi Pine chưa kiểm chứng.** Ladder + `pyramiding=0`, Ladder + Reversal và fill timing cần test
   trên TradingView trước khi port execution; không chặn contract tín hiệu gate-on ở Phase 3.
7. **Symbol/timeframe chuẩn chưa chốt.** Ảnh hưởng trực tiếp đến parity ở Phase 6.
8. **Runtime TradingView chưa kiểm chứng.** E1–E8 của audit repaint đều `PENDING` (alert, exit nến entry,
   ladder). Không suy ra kết quả từ tài liệu.
9. **Runtime MQL5 chưa kiểm chứng.** Indicator và EA mới chỉ compile; 36 vector Wonderwhales, 47 vector
   LongKaco VSA, 82 vector TM Fusion Zones và 119 vector Price Action MTF chưa chạy trong terminal. Không
   tuyên bố PASS runtime.

### 7. Trạng thái Phase 1–6

- **Script đã đặc tả:** Wonderwhales (indicator + Backtest variant).
- **File:** [`INDICATOR_SPEC_Wonderwhales.md`](wonderwhales.md),
  [`REPAINT_AUDIT_Wonderwhales.md`](wonderwhales.md),
  [`BUFFER_CONTRACT_Wonderwhales.md`](wonderwhales.md),
  [`PINE_PARITY_Wonderwhales.md`](parity.md),
  `PINE_MQL5_COMPATIBILITY.md`.
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` cho chế độ `confirmOnClose = true`;
  `confirmOnClose = false` là `NOT_PORTED` (repaint theo thiết kế).
- **Đã ghi:** 37 input indicator + 13 input strategy; 11 plot; 27 shape; 4 alertcondition; 2 `alert()`;
  HUD table; toàn bộ công thức PSAR/VSA/EMA/ATR/RSI/BB; 4 signal mode; execution semantics; warm-up;
  repaint matrix; timestamp contract; 10 chính sách MQL5; 18 khác biệt Pine→MQL5 (D1–D18); signal ID và
  buffer contract 18 kênh đã chốt.
- **Phase 4:** `WonderwhalesContract.mqh`, `Wonderwhales.mq5`, `WonderwhalesContractTests.mq5`; compile
  0 error/0 warning. 36 vector **chưa chạy**.
- **Phase 5:** `PineSignalLabEA.mq5`; compile 0 error/0 warning; chưa chạy runtime.
- **Phase 6:** comparator `scripts/compare_pine_exports.py` + 25 unit test + 10 audit CSV test pass; parity
  thật `BLOCKED`
  vì chưa có CSV reference từ Pine.
- **Chưa làm:** không chạy indicator/EA trong terminal, không Strategy Tester, không backtest, không chạy
  TradingView.
- **Phase 7:** Strategy Tester thủ công; `BLOCKED` cho tới khi có môi trường và dữ liệu.

#### 7.1 LongKaco VSA — Phase 1–4

- **Nguồn:** `dist/LongKaco VSA.pine` (indicator, 681 dòng, 45 input) và
  `dist/LongKaco VSA Backtest.pine` (strategy, 600 dòng). Không sửa source.
- **Tài liệu:** [`INDICATOR_SPEC_LongKacoVSA.md`](longkaco-vsa.md),
  [`REPAINT_AUDIT_LongKacoVSA.md`](longkaco-vsa.md),
  [`BUFFER_CONTRACT_LongKacoVSA.md`](longkaco-vsa.md).
- **Contract:** 35 input; 29 buffer = 8 render (plot 0–7) + 21 contract (8–28); 47 test vector.
- **Code:** `mt5/Include/PinePort/LongKacoVSAContract.mqh`, `mt5/Indicators/PinePort/LongKacoVSA.mq5`,
  `mt5/Scripts/LongKacoVSAContractTests.mq5`; compile 0 error/0 warning (36.104 và 18.988 byte).
- **Validator:** `scripts/validate_longkaco.py` pass=29 fail=0.
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (D1–D7 trong spec); tín hiệu chỉ trên nến đã đóng.
- **Chưa làm:** 47 vector `NOT_RUN`; EA `NOT_IMPLEMENTED`; parity `BLOCKED`; Strategy Tester `NOT_RUN`.

#### 7.2 TM Fusion Zones — Phase 1–4

- **Nguồn:** `dist/TM Fusion Zones.pine` (indicator, Pine v6, 40 input). Không sửa source.
- **Tài liệu:** [`INDICATOR_SPEC_TMFusionZones.md`](tm-fusion-zones.md),
  [`REPAINT_AUDIT_TMFusionZones.md`](tm-fusion-zones.md),
  [`BUFFER_CONTRACT_TMFusionZones.md`](tm-fusion-zones.md).
- **Contract:** 40 input; 33 buffer = 10 render (plot 0–9) + 23 contract (10–32); 82 test vector.
- **Code:** `mt5/Include/PinePort/TMFusionZonesContract.mqh`, `mt5/Indicators/PinePort/TMFusionZones.mq5`,
  `mt5/Scripts/TMFusionZonesContractTests.mq5`; compile 0 error/0 warning (54.334 và 61.512 byte).
- **Validator:** `scripts/validate_tmfz.py` pass=34 fail=0.
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (D1–D7 trong spec); tín hiệu chỉ trên nến đã đóng.
- **Chưa làm:** 82 vector `NOT_RUN`; EA `NOT_IMPLEMENTED`; parity `BLOCKED`; Strategy Tester `NOT_RUN`.

#### 7.3 Price Action MTF — Phase 1–4

- **Nguồn:** `dist/Price Action MTF.pine` (indicator, Pine v6, 1801 dòng, 144 input khai báo; 115 input được
  port). Không sửa source.
- **Tài liệu:** [`INDICATOR_SPEC_PriceActionMTF.md`](price-action-mtf.md),
  [`REPAINT_AUDIT_PriceActionMTF.md`](price-action-mtf.md),
  [`BUFFER_CONTRACT_PriceActionMTF.md`](price-action-mtf.md).
- **Contract:** 115 input + 4 input thời gian; 107 buffer = 12 render (plot 0–11) + 95 contract (12–106);
  119 test vector.
- **Code:** `mt5/Include/PinePort/PriceActionMTFContract.mqh`, `mt5/Indicators/PinePort/PriceActionMTF.mq5`,
  `mt5/Scripts/PriceActionMTFContractTests.mq5`; compile 0 error/0 warning (111.728 và 114.290 byte).
- **Validator:** `scripts/validate_pamtf.py` pass=34 fail=0.
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (D1–D10 + Q1–Q10 trong contract); tín hiệu chỉ trên nến
  đã đóng.
- **Chưa làm:** 119 vector `NOT_RUN`; EA `NOT_IMPLEMENTED`; parity `BLOCKED`; Strategy Tester `NOT_RUN`.

#### 7.4 TM XAU Signals 2 — Phase 1–4

- **Nguồn:** `dist/TM XAU Signals 2.pine` (indicator, Pine v6, 1383 dòng, 90 input được port). Không sửa
  source.
- **Tài liệu:** [`INDICATOR_SPEC_TMXAUSignals2.md`](tm-xau-signals-2.md),
  [`REPAINT_AUDIT_TMXAUSignals2.md`](tm-xau-signals-2.md),
  [`BUFFER_CONTRACT_TMXAUSignals2.md`](tm-xau-signals-2.md).
- **Contract:** 90 input; 153 buffer = 13 render (plot 0–12) + 140 contract (13–152); 105 test vector.
- **Code:** `mt5/Include/PinePort/TMXAUSignals2Contract.mqh`, `mt5/Indicators/PinePort/TMXAUSignals2.mq5`,
  `mt5/Scripts/TMXAUSignals2ContractTests.mq5`; compile 0 error/0 warning (97.680 và 76.838 byte).
- **Validator:** `scripts/validate_tmxau2.py` pass=31 fail=0.
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (Q1–Q10 trong contract §16); tín hiệu chỉ trên nến đã
  đóng; mặc định `rr1=1.0 < rrMin=1.5` nên không phát tín hiệu nếu giữ nguyên input.
- **Chưa làm:** 105 vector `NOT_RUN`; EA `NOT_IMPLEMENTED`; parity `BLOCKED`; Strategy Tester `NOT_RUN`.

#### 7.5 TM Indicator 2 — Phase 1–4

- **Nguồn:** `dist/TM Indicator 2.pine` (indicator, Pine v6, 2243 dòng, 151 input, v2.1.0). Không sửa
  source.
- **Tài liệu:** [`INDICATOR_SPEC_TMIndicator2.md`](tm-indicator-2.md),
  [`REPAINT_AUDIT_TMIndicator2.md`](tm-indicator-2.md),
  [`BUFFER_CONTRACT_TMIndicator2.md`](tm-indicator-2.md).
- **Hợp đồng buffer:** `CONTRACT_FROZEN_FOR_PHASE4`; 118 input (113 ported + 5 MQL5-only), 242 buffer
  (16 render 0..15 + 226 contract 16..241), `ENUM_TM2_REASON` 0..31, 155 test vector A–P.
- **Code:** `mt5/Include/PinePort/TMIndicator2Contract.mqh`, `mt5/Indicators/PinePort/TMIndicator2.mq5`,
  `mt5/Scripts/TMIndicator2ContractTests.mq5`; compile 0 error/0 warning (140.596 và 130.042 byte);
  bind 16 DATA + 226 CALCULATIONS.
- **Validator:** `scripts/validate_tmind2.py` pass=44 fail=0.
- **Trạng thái port:** `PORTABLE_WITH_DIFFERENCES` (D1–D10 trong spec §13); tín hiệu chỉ trên nến đã
  đóng; có strategy sibling `TM Indicator Strategy Lab 2.pine` nhưng không port execution.
- **Điểm audit:** fill-bar chặn TP nhưng vẫn xét SL; SL ưu tiên khi cùng nến chạm TP; S/R `broken` là
  dead field; `barstate.islast` chỉ vẽ box, không mutate state.
- **Chưa làm:** 155 vector `NOT_RUN`; EA `NOT_IMPLEMENTED`; parity `BLOCKED`; Strategy Tester `NOT_RUN`.

#### 7.6 Phase 5 — EA tín hiệu đa nguồn (sáu indicator)

- **Code:** `mt5/Experts/PineMultiSignalLabEA.mq5` (666 dòng; compile 0 error/0 warning) đọc cả sáu
  indicator tại `shift=1` bằng `iCustom` với input mặc định, ghi
  `MQL5/Files/pine_multi_signal_log.csv` (18 cột); toggle bật/tắt từng nguồn.
- **Buffer tín hiệu:** WW `BUY/SELL_SIGNAL`; LK `FILL` + `DIR`; FZ `SIGNAL_LONG/SHORT`;
  PA `SIG_LONG/SHORT`; X2 `SIG` + `DIR`; TM2 `SIGNAL` + `DIR`.
- **Audit:** `python/src/mt5_ea_ai_lab/evaluation/multi_signal_audit.py`,
  `scripts/audit_multi_signal_csv.py`, `python/tests/test_multi_signal_audit.py` (11 test pass).
- **Bằng chứng:** `scripts/build_pineport.ps1` → `BUILD_OK: 14 source(s) compiled with 0 errors and
  0 warnings`; không có API giao dịch trong EA.
- **Giới hạn:** `iCustom` tối đa 63 tham số nên EA không truyền input cho TM Indicator 2 (118 input);
  `input_hash` chỉ hash `source|version|defaults`.
- **Chưa làm:** EA `NOT_RUN` trong terminal; chưa sinh CSV thật; parity `BLOCKED`.

#### 7.7 Phase 6 — Parity đa nguồn

- **Code:** `python/src/mt5_ea_ai_lab/evaluation/multi_source_parity.py` +
  `scripts/compare_multi_signal_exports.py`; ghép theo `(source, bar_open_time, symbol, timeframe)`,
  so `signal_id`/`side`/`dir` chính xác, `score` tolerance `1e-6`, giá `1e-8`; báo cáo theo từng nguồn.
- **Tests:** `python/tests/test_multi_source_parity.py` — 21 test pass.
- **Tài liệu:** [`PINE_PARITY_MULTI_SOURCE.md`](parity.md); CLI trả exit 3 và in
  `parity=BLOCKED` khi thiếu CSV reference thay vì tạo dữ liệu giả.
- **Chưa làm:** chưa có CSV reference thật từ Pine; comparator `NOT_RUN` trên dữ liệu thật.

Tham chiếu roadmap: [`pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md`](../pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md).

## Pine ↔ MQL5 compatibility — Wonderwhales

Tài liệu này liệt kê các khác biệt đã biết giữa Pine gốc và bản MQL5 trong repo. Không có khác biệt nào
được coi là "đã kiểm chứng runtime" nếu chưa có log/CSV thật.

- **Pine nguồn:** `D:\Applications\tm-trading\pine\dist\Wonderwhales.pine` (read-only).
- **Chiến lược tham chiếu:** `Wonderwhales Backtest.pine` (chỉ đọc để hiểu execution; **không port**).
- **MQL5:** `mt5/Indicators/PinePort/Wonderwhales.mq5`, `mt5/Experts/PineSignalLabEA.mq5`.
- **Contract:** [`BUFFER_CONTRACT_Wonderwhales.md`](wonderwhales.md).

### 1. Bảng khác biệt

| # | Chủ đề | Pine | MQL5 | Ảnh hưởng | Trạng thái |
|---|---|---|---|---|---|
| D1 | PSAR | `ta.sar(start, inc, max)` | `iSAR(symbol, tf, step, max)` | Giá trị có thể lệch ở bar đầu | Chấp nhận; so từ warm-up |
| D2 | EMA seed | Seed bằng giá trị đầu | `iMA(MODE_EMA)` seed khác | Lệch nhỏ tắt dần | Warm-up 300 bar |
| D3 | ATR | Wilder/RMA | `iATR` Wilder | Có thể lệch vài bar đầu | Warm-up |
| D4 | RSI | Wilder | `iRSI` Wilder | Display-only | Không chặn tín hiệu |
| D5 | Bollinger | SMA + population stdev | `iBands` | Display-only | Không chặn tín hiệu |
| D6 | Volume | `volume` của sàn | `tick_volume` | VSA chỉ hiển thị, không gate | Ghi rõ |
| D7 | Fill timing | `process_orders_on_close` | Không có execution | Không port | N/A |
| D8 | Sizing | Equity / close | Không có execution | Không port | N/A |
| D9 | Intrabar SL/TP | Broker emulator | Không có execution | Không port | N/A |
| D10 | Ladder | 2 entry cùng bar, `pyramiding=0` | Không có execution | Hai lỗi Pine đã biết | Không port |
| D11 | Reversal | `strategy.close("Long")` | Không có execution | Không port | N/A |
| D12 | Commission | 0.05%/chiều | Không có execution | Không port | N/A |
| D13 | Timezone | UTC/exchange | Server time broker | Ảnh hưởng timestamp CSV | Chuẩn hóa UTC khi so |
| D14 | History | `max_bars_back=1000` | History terminal | Có thể thiếu bar | Kiểm tra `BarsCalculated` |
| D15 | Alerts | `freq_once_per_bar_close` | Không có alert native | Không port | EA chống trùng theo bar |
| D16 | `confirmOnClose=false` | Marker bật/tắt trong nến | **Không port** | Tránh repaint không kiểm chứng | Chỉ hỗ trợ confirmed |
| D17 | Render | Chart window, nhiều plot | 3 plot + 15 buffer ẩn | Khác giao diện | Chấp nhận |
| D18 | Volume SMA | `ta.sma(volume, len)` | Tự cộng `tick_volume` | Display-only | Chấp nhận |

### 2. Điểm giữ nguyên có chủ đích

- `sar_dir`: PSAR `< close` là bull; `== close` là bear (so sánh nghiêm ngặt).
- Flip chỉ khi `dir` đổi từ `-1` sang `1` hoặc ngược lại; `dir_prev = 0` không tạo flip.
- EMA cross dùng `prev <=` và `now >` (cross up), `prev >=` và `now <` (cross down).
- Mode gate:
  - `SAR`: raw flip.
  - `EMA`: EMA cross.
  - `SAR_EMA`: flip + EMA trend cùng chiều.
  - `SAR_EMA_ATR`: flip + EMA trend + `atr_pct >= min_atr_pct`.
- Tín hiệu chỉ phát trên nến đã đóng; buffer tín hiệu tại nến đang chạy = 0.
- `blocked` là chẩn đoán, không phải tín hiệu.
- Missing value: PSAR/EMA/RSI/BB/Volume MA = `EMPTY_VALUE`; ATR%/Volume ratio = `0.0`.

### 3. Khác biệt về dữ liệu và độ chính xác

- EA ghi `psar`, `fast`, `slow` với 8 chữ số thập phân; `atr_pct` với 10 chữ số.
- Pine export có thể dùng độ chính xác đầy đủ; comparator mặc định `1e-8` cho giá và `1e-6` cho ATR%.
- Nếu broker dùng ít chữ số hoặc giá trị PSAR được làm tròn theo tick, tolerance cần ghi rõ trong báo cáo.
- Volume khác nguồn (tick vs real) có thể làm `VOL_RATIO` khác; trường này không tham gia tín hiệu.

### 4. Điều chưa được kiểm chứng

| Hạng mục | Trạng thái |
|---|---|
| 36 test vector hợp đồng | Đã compile; **chưa chạy** |
| Indicator trong MT5 (buffer, iCustom) | **Chưa chạy** |
| EA runtime (log, CSV, dedupe) | **Chưa chạy** |
| Strategy Tester / backtest | **Chưa chạy**; không có execution |
| Parity Pine-vs-MQL5 | `BLOCKED` — thiếu CSV reference |
| Hành vi Pine runtime E1–E8 | `PENDING` |

### 5. Quy tắc cập nhật

Khi phát hiện khác biệt mới:

1. Thêm dòng vào bảng trên với ID tiếp theo.
2. Ghi rõ ảnh hưởng tới tín hiệu hay chỉ hiển thị.
3. Nếu ảnh hưởng tín hiệu, cập nhật contract và test vector trước khi sửa code.
4. Không nới tolerance hoặc sửa Pine để che khác biệt.
