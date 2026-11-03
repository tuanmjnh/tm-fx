# PATrendRider XAU v1

**Trạng thái tài liệu:** `CONFIRMED` từ source + runtime evidence  
**Cập nhật:** 2026-10-29  
**Symbol mục tiêu:** `XAUUSDm` (Exness)  
**Timeframe:** H1 (bias) / M15 (structure) / M5 (entry)  
**Entry point:** `PATrendRiderXAUv1SimEA` (mô phỏng), `PATrendRiderXAUv1DemoEA` (demo execution)

Tài liệu này thay thế phần `UNKNOWN` trong pack kế hoạch ban đầu. Mọi quy tắc dưới đây đọc trực tiếp từ code trong `mt5/Include/TrendRider/` và `mt5/Experts/PATrendRiderXAUv1*.mq5`.

---

## 1. Tệp và định danh

| Thành phần | Đường dẫn |
|---|---|
| Types/config | `mt5/Include/TrendRider/TRTypes.mqh`, `TRConfig.mqh` |
| Swing | `TRSwing.mqh` |
| Structure (BOS/CHoCH) | `TRStructure.mqh` |
| Trend merge | `TRTrend.mqh` |
| Pullback/confirmation | `TRPullback.mqh` |
| Signal decision | `TRSignal.mqh` |
| ATR/market data | `TRAtr.mqh`, `TRMarketData.mqh` |
| Risk/trailing/state | `TRRisk.mqh`, `TRTrailing.mqh`, `TRState.mqh` |
| Simulation EA | `mt5/Experts/PATrendRiderXAUv1SimEA.mq5` |
| Demo EA | `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` |
| Contract tests | `mt5/Scripts/TrendRiderContractTests.mq5` |
| Preset sim | `configs/sim/pa_trendrider_xau.json` |
| Preset demo | `configs/demo/pa_trendrider_xau_demo.json` |

Magic: sim `25001001`, demo `25002001`.

## 2. Luồng quyết định

```text
H1 closed bars ──► swing/chain ──► bias H1
M15 closed bars ─► swing/chain ──► bias M15
                                      │
                                      ▼
                            merge bias (strict)
                                      │
M5 closed bars ──► structure engine ──► BOS/CHoCH
                                      │
                                      ▼
                    regime priority (risk/spread/vol/reversal)
                                      │
                                      ▼
                 signal gate (bias + BOS + pullback + confirmation)
                                      │
                                      ▼
                    entry (SimEA: virtual | DemoEA: guarded order)
```

Mọi tính toán chỉ dùng **bar đã đóng**. Không có look-ahead, không repaint.

## 3. Swing detection

`TRSwing.mqh`:

- Fractal high/low với `left=2`, `right=2`.
- **Bất đẳng thức nghiêm ngặt** hai bên: nến bằng nhau (tie) bị loại, không chọn tùy ý.
- Swing chỉ tồn tại sau khi có `right` bar đã đóng bên phải → không repaint, không dùng tương lai.
- `confirm_time` = thời điểm đóng của bar bên phải — thời điểm sớm nhất có thể biết swing.
- Nến vừa là swing high vừa là swing low (inside/ambiguous) bị loại.

## 4. Cấu trúc: BOS/CHoCH

`TRStructure.mqh`:

### 4.1 Phân loại chain

- Lấy hai swing high gần nhất và hai swing low gần nhất.
- `delta = 0.05 × ATR` (`InpTrendMinDeltaAtr`).
- **Bullish:** `last_high > prev_high + delta` **và** `last_low > prev_low + delta`.
- **Bearish:** `last_high < prev_high − delta` **và** `last_low < prev_low − delta`.
- Còn lại: `ranging=true` (đủ swing nhưng không có chuỗi sạch).
- Thiếu swing: `valid=false`.

### 4.2 Buffer phá mức

```text
buffer = max(spread_price × 2.0, ATR × 0.10)
```

Hai hệ số là giả thuyết của đặc tả, không phải hằng số thị trường.

### 4.3 BOS

- Chỉ trên bar đã đóng.
- Bull BOS: `close > last_high + buffer`.
- Bear BOS: `close < last_low − buffer`.
- **Một lần cho mỗi swing**, dedupe bằng **thời gian swing** (không dùng index vì index dịch khi cửa sổ trượt).
- CHoCH được ưu tiên hơn BOS trên cùng bar.

### 4.4 CHoCH

- Bear CHoCH: chain bullish nhưng `close < last_low − buffer`.
- Bull CHoCH: chain bearish nhưng `close > last_high + buffer`.
- Kích hoạt `REVERSAL_WATCH`; tự clear khi chain flip sang hướng mới.
- Mỗi hướng chỉ đếm một lần cho tới khi clear.

## 5. Bias H1/M15

`TRTrend.mqh`:

| H1 | M15 | Kết quả |
|---|---|---|
| Bullish | Bullish | `TREND_UP`, valid |
| Bearish | Bearish | `TREND_DOWN`, valid |
| Ranging | Ranging | range, valid |
| Khác / thiếu dữ liệu | — | `UNKNOWN`, conflict hoặc insufficient |

Không có bias "một nửa". H1/M15 lệch nhau → **không vào lệnh**.

## 6. Regime priority

`TRResolveRegime` thứ tự 1→5:

1. `!data_ok` → `UNKNOWN`
2. `risk_locked` → `RISK_LOCKED`
3. `spread_blocked` → `SPREAD_BLOCKED`
4. `volatility_high` → `VOLATILITY_HIGH`
5. `reversal_watch` → `REVERSAL_WATCH`
6. Bias bullish → `TREND_UP`; bearish → `TREND_DOWN`
7. Còn lại → `RANGE`

Trạng thái bảo vệ **không** bị ghi đè bởi tín hiệu entry.

## 7. Entry

### 7.1 Điều kiện bắt buộc (theo thứ tự)

| # | Điều kiện | Reason code khi fail |
|---|---|---|
| 1 | `enabled` | `disabled` |
| 2 | `data_ok` | `data_invalid` |
| 3 | Không `risk_locked` | `risk_locked` |
| 4 | Không `spread_blocked` | `spread_blocked` |
| 5 | Không `volatility_high` | `volatility_high` |
| 6 | Không `reversal_watch` | `reversal_watch` |
| 7 | Bias valid | `bias_unknown` |
| 8 | Không conflict | `timeframe_conflict` |
| 9 | Không ranging | `regime_range` |
| 10 | Có BOS và side hợp lệ | `no_bos` |
| 11 | BOS cùng hướng bias | `bos_against_bias` |
| 12 | Có pullback window | `no_pullback` |
| 13 | Tuổi BOS ≤ 8 bar | `bos_too_old` |
| 14 | Zone hợp lệ | `zone_invalid` |
| 15 | Zone được chạm | `NO_PULLBACK` |
| 16 | Zone không bị vô hiệu | `ZONE_INVALIDATED` |
| 17 | Confirmation candle | `NO_CONFIRMATION` |

### 7.2 Retest zone

```text
level = mức swing bị phá (BOS level)
low   = level − 0.25 × ATR
high  = level + 0.25 × ATR
```

- Zone hợp lệ khi side ≠ NONE, level/ATR hữu hạn dương.
- **Touched:** bất kỳ bar nào trong cửa sổ có `low ≤ zone.high` và `high ≥ zone.low`.
- **Invalidated:** close vượt qua phía đối diện zone quá buffer:
  - BUY: `close < zone.low − buffer`
  - SELL: `close > zone.high + buffer`

### 7.3 Confirmation candle

Chỉ bar **đã đóng cuối cùng** được dùng:

- Range > 0.
- Body cùng chiều ≥ `0.5 × ATR`.
- Close nằm trong **25% ngoài** của range:
  - BUY: `(close − low) ≥ 0.75 × range`
  - SELL: `(high − close) ≥ 0.75 × range`

Nến zero-range không bao giờ confirm.

### 7.4 Signal age

`bars_since_bos = entry_count − pullback_start_index`; phải ≤ `InpMaxSignalAgeBars=8`.

## 8. Entry execution

### 8.1 SimEA

- Tạo vị thế ảo trong `CSimPortfolio`; không gọi API giao dịch.
- SL cấu trúc; không TP; thoát bằng SL, breakeven/trailing, hoặc reversal đã xác nhận.
- Journal `pa_trendrider_log.csv`.

### 8.2 DemoEA

- Chỉ khi `InpEnableExecution=true` và guard chain pass.
- SL = structure level ∓ `0.2 × ATR`, làm tròn tick.
- TP = fill ± `3R` (`InpTakeProfitR=3.0`).
- Volume theo risk 0.25% (xem [`../RISK_MODEL.md`](../RISK_MODEL.md)).
- Một vị thế; SL/TP bắt buộc; kiểm tra margin; gửi qua `ExecBroker`.
- Journal `pa_trendrider_demo.csv`; state `pa_trendrider_demo_state.csv`.

## 9. Quản lý vị thế

| Quy tắc | Giá trị |
|---|---|
| Break-even | 1R |
| Trailing start | 1.5R |
| ATR trailing | 1.2 × ATR |
| Structure trailing | Swing đối nghịch gần nhất |
| Cập nhật | Chỉ bar đã đóng |
| Monotonic | SL chỉ siết |
| Broker bỏ SL/TP | `ManageOpenPosition` sửa lại; nếu fail → đóng |
| Reversal | CHoCH + chain flip → `REVERSAL_WATCH` → đóng khi xác nhận |

R đo bằng SL ban đầu, không tính lại sau khi SL di chuyển.

## 10. Risk mặc định

| Tham số | Giá trị |
|---|---|
| Risk/lệnh | 0.25% equity |
| Max positions | 1 |
| Daily loss | 1% |
| Max drawdown | 8% (sticky) |
| Consecutive losses | 3 → cooldown 30 phút |
| Max spread | 600 points hoặc 0.25 × ATR |
| ATR bất thường | > 2.5 × median 100 bar |
| Signal age | 8 bar M5 |

Chi tiết: [`../RISK_MODEL.md`](../RISK_MODEL.md).

## 11. State machine

`TRState.mqh` — 11 trạng thái:

`INITIALIZING`, `READY`, `WAITING_FOR_SETUP`, `ENTRY_REQUESTED`, `POSITION_OPEN`, `REVERSAL_WATCH`, `CLOSE_FOR_REVERSAL`, `COOLDOWN`, `DAILY_LOCKED`, `DRAWDOWN_LOCKED`, `ERROR_SAFE_MODE`.

- Transition hợp lệ được định nghĩa tường minh; sai → `invalid_transition`.
- `ERROR_SAFE_MODE` chỉ về `READY` qua `ManualReset`.
- Kill switch → `ERROR_SAFE_MODE`.

## 12. Bằng chứng runtime

### 12.1 Contract tests

- `TrendRiderContractTests`: **82/82 PASS** (runtime, 2026-10-28/29).
- Bằng chứng: `reports/build/tester-reports/contract_trendrider/contract_TrendRider.htm`.

### 12.2 Strategy Tester — SimEA

| Scenario | Kết quả | Số liệu |
|---|---|---|
| `pa_trendrider_baseline` (5k) | 4 entry, 4 loss | net −36.72, balance 4 963.28, max DD 0.9312% |
| `pa_trendrider_baseline_10k` | 13 entry, 2 win / 11 loss | net −140.46, balance 9 859.53, max DD 1.7519% |
| `pa_trendrider_cost_stress` (5k) | 4 entry, 4 loss | net −37.28, balance 4 962.72, max DD 0.9410% |

Cấu hình baseline: `XAUUSDm`, M5, 2026.01.05 → 2026.03.05, deposit 5 000, leverage 1:100.
Lưu ý: ba khoảng test ngắn, một symbol, một bộ tham số. **Không** kết luận lợi nhuận.

### 12.3 Strategy Tester — DemoEA order path

`demo_exec_gui_20261029`: 61 189 dòng journal; **31 ENTRY / 31 EXIT**, 11 win / 20 loss, net **+53.72**, balance 5 053.72, DD **0.6530%**; 14 BUY / 17 SELL; volume tối đa 0.02; 31 ticket duy nhất; audit `PROBLEMS=0`.

- Tester dùng `InpEnableExecution=true`, khoảng 2026.01.01 → 2026.10.27, `config_hash=6B439450`.
- Tester là mô phỏng; **không** chứng minh broker demo nhận lệnh.

### 12.4 Broker demo

`ExecDemoProbe` trên demo `464140826`: BUY 0.01 `XAUUSDm`, `deal=2468899165` vào 4045.79 với SL 4042.79/TP 4048.79, đóng `deal=2468899168` tại 4045.55, `pnl=-0.24`, trong 103 ms. Đối soát ba nguồn.

### 12.5 DemoEA live

- `INIT mode=DEMO_EXECUTION|restored=1|equity≈4999.76|config_hash=6B439450|mql_trade_allowed=1`.
- `WAITING_FOR_SETUP`, regime `RANGE`, `bias_unknown`.
- **0 `ENTRY` do chính EA gửi** tính tới 2026-10-29. Đây là hành vi đúng của bộ lọc, không phải lỗi.
- Kỳ vọng từ dữ liệu tester: ~3.1 lệnh/tháng; khoảng chờ dài nhất quan sát được ~5.5 tuần.

### 12.6 Kill switch

File thật trên demo → `KILL kill_switch_file|entries_disabled` + `STATE ERROR_SAFE_MODE` trong 16 giây. Xem [`../EXECUTION_AND_SAFETY.md`](../EXECUTION_AND_SAFETY.md) mục 6.

## 13. Nhãn bằng chứng

| Nội dung | Nhãn | Nguồn |
|---|---|---|
| Swing, BOS, CHoCH, bias merge, entry gate | `CONFIRMED` | Code + contract tests |
| Sizing, SL/TP/trailing | `CONFIRMED` | Code + contract tests |
| Order path trong tester | `CONFIRMED` | CSV + audit + tester tabs |
| Broker demo nhận lệnh | `CONFIRMED` (một lệnh BUY) | Probe + History |
| DemoEA gửi ENTRY trên demo | `NOT_RUN` | 0 ENTRY tới 2026-10-29 |
| Lợi nhuận | `UNPROVEN` | Không có forward test đủ dài |
| Hành vi SELL trên broker thật | `UNKNOWN` | Probe chỉ BUY |
| Retcode từ chối theo giờ/freeze/requote | `UNKNOWN` | Chưa gặp |

## 14. Reason code thường gặp

| Code | Nghĩa | Xử lý |
|---|---|---|
| `bias_unknown` | H1/M15 thiếu swing hoặc lệch | Chờ; không nới gate |
| `timeframe_conflict` | H1/M15 khác hướng | Chờ |
| `regime_range` | Cả hai ranging | Chờ |
| `reversal_watch` | CHoCH đang active | Chờ chain flip |
| `spread_blocked` | Spread > 600 points hoặc > 0.25 ATR | Chờ spread hạ |
| `volatility_high` | ATR > 2.5 × median | Chờ |
| `no_pullback` | Chưa retest zone | Chờ |
| `NO_CONFIRMATION` | Nến chưa đủ body/close zone | Chờ bar sau |
| `ZONE_INVALIDATED` | Close xuyên zone | Bỏ setup |
| `bos_too_old` | Quá 8 bar | Bỏ setup |
| `lot_rejected` / `stop_rejected` | Sizing/SL không hợp lệ | Kiểm tra symbol/risk |
| `risk_locked` | Daily/DD/cooldown | Chờ hoặc review |

Phân bố thực tế trong tester 9 tháng: `bias_unknown` 47.71%, `reversal_watch` 29.56%, `regime_range` 13.21%, `bos_against_bias` 3.86%, entry hợp lệ 2.88%, `volatility_high` 1.52%.

## 15. Tái lập

```powershell
# Compile
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\PATrendRider*"

# Contract tests
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\contract_TrendRider.ini"

# SimEA tester
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\pa_trendrider_baseline.ini"

# DemoEA tester
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\pa_trendrider_demo_exec.ini"
```

Sau mỗi lần chạy, kiểm tra CSV SUMMARY và audit:

```powershell
.\.venv\Scripts\python.exe reports\build\tester-reports\demo_exec_gui_20261029\audit_exec_csv.py reports\build\tester-reports\demo_exec_gui_20261029\pa_trendrider_demo.csv
```

## 16. Giới hạn trung thực

- Không có kết luận lợi nhuận từ bất kỳ khoảng test nào.
- Tester không chứng minh broker nhận lệnh; probe chỉ chứng minh một lệnh BUY 0.01.
- Chưa có `ENTRY` thật từ DemoEA; chưa có SELL thật; chưa gặp retcode từ chối.
- Một symbol, một timeframe, một bộ tham số; kết quả không tổng quát hóa.
- Thay đổi bất kỳ input chiến lược nào cũng cần chạy lại contract + tester + ghi bằng chứng.
