# InfiniteRunner_XAU — Source Review & Upgrade Specification

**Tài liệu:** Đánh giá source hiện tại và đặc tả nâng cấp  
**Source được kiểm tra:** `InfiniteRunner_XAU.mq5` (164 dòng, version 1.00)  
**Mục tiêu:** Nâng cấp bộ xác định hướng, kiểm soát rủi ro, quản lý trailing SL, khả năng phục hồi và kiểm thử.  
**Phạm vi vận hành:** MetaTrader 5 Strategy Tester và tài khoản DEMO được xác minh. Không bật giao dịch tài khoản tiền thật.

> Đây là đặc tả kỹ thuật để kiểm thử, không phải cam kết lợi nhuận hoặc khuyến nghị giao dịch. Không có cách nào bảo đảm “gồng dương vô cực”; trailing chỉ cố gắng bảo vệ một phần lợi nhuận và có thể bị trượt giá/gap.

---

## 1. Source hiện tại đang làm gì?

EA hiện có một chiến lược rất gọn:

- Tạo hai EMA trên timeframe của chart: EMA nhanh mặc định 21 và EMA chậm mặc định 50.
- Nếu không có vị thế cùng symbol + magic number, bot kiểm tra spread rồi mở một lệnh.
- EMA nhanh >= EMA chậm thì BUY; ngược lại SELL.
- Lot cố định mặc định 0.01.
- SL ban đầu cố định 5.000 points; TP = 0.
- Khi lời đạt 3.000 points, bot bắt đầu trailing cách giá 2.500 points, mỗi lần dịch tối thiểu 500 points.
- Khi có vị thế, bot chỉ chạy `ManageTrailingStop()` và không phân tích tín hiệu mới.
- Khi vị thế đóng, tick tiếp theo có thể mở lệnh mới nếu spread cho phép.

### 1.1. Điểm có thể giữ lại

- Ý tưởng một vị thế EA tại một thời điểm.
- Không đặt TP cố định.
- Trailing SL chỉ dịch chuyển theo hướng bảo vệ tốt hơn.
- Magic number để nhận diện vị thế của EA.
- Tham số có thể cấu hình qua Inputs.

### 1.2. Vấn đề cần sửa trước khi tăng tính năng

| Mức | Phát hiện từ source | Hệ quả có thể xảy ra | Yêu cầu sửa |
|---|---|---|---|
| Critical | `CopyBuffer(..., 0, 0, 2, ...)` và dùng `fastMA[0]`, `slowMA[0]` | Dùng EMA của nến đang chạy; hướng có thể đổi trong nến | Chỉ dùng nến đã đóng cho quyết định, kiểm thử shift/index rõ ràng |
| High | So sánh EMA nhanh/chậm, không phát hiện crossover hay cấu trúc xu hướng | EMA nằm trên/dưới nhau lâu không có nghĩa là có điểm vào mới tốt | Xây Direction Engine và Entry Trigger riêng |
| High | Khi vị thế đóng, bot có thể vào lại ngay tick kế tiếp | Dễ lặp vào lệnh sau SL trong cùng điều kiện thị trường | Chỉ xét entry ở nến EntryTF mới, có cooldown và chống lặp signal ID |
| High | Lot cố định | Rủi ro tiền thay đổi theo khoảng SL và đặc tính symbol | Risk-based sizing bằng `OrderCalcProfit()`; bỏ lệnh nếu volume tối thiểu vượt ngân sách |
| High | Chỉ giới hạn spread bằng `SYMBOL_SPREAD` points | Ngưỡng 300 points không cùng ý nghĩa giữa các cấu hình digits/point | Đọc Bid/Ask, point, tick size; có cả spread tuyệt đối và spread/ATR |
| High | Không kiểm tra retcode sau `Buy`, `Sell`, `PositionModify` | Hàm trả `true` không đồng nghĩa server đã thực hiện thành công | Kiểm tra `ResultRetcode()` và `ResultRetcodeDescription()` |
| High | Chuẩn hóa SL bằng `_Digits` | Có thể không đúng bước giá `SYMBOL_TRADE_TICK_SIZE` | Làm tròn theo tick size và kiểm tra stops/freeze level |
| High | Không có daily loss/equity drawdown/loss-streak lock | Có thể giao dịch tiếp trong chuỗi thua hoặc lúc điều kiện xấu | Thêm RiskManager và persistent lock |
| Medium | Không kiểm tra ATR/regime/giờ giao dịch | Có thể liên tục vào lệnh lúc biến động bất thường hoặc sideway | Thêm volatility/session filters tùy chọn |
| Medium | Không có state persistence | Restart có thể làm mất cooldown/peak equity/initial-R nếu bổ sung sau này | Lưu và phục hồi state có version, đối chiếu với position/deals thực tế |
| Medium | Không xử lý rõ tài khoản netting/hedging và vị thế khác cùng symbol | Có thể can thiệp vào vị thế không thuộc bot trên tài khoản netting | Detect account mode; chặn nếu không thể cô lập quyền quản lý |
| Medium | Không ghi log lý do bỏ setup và kết quả server | Khó tìm lỗi và tái lập backtest | Event log + CSV trade log + reason codes |

### 1.3. Cảnh báo riêng về “gồng dương vô cực”

- TP = 0 chỉ có nghĩa không đặt Take Profit cố định.
- Trailing SL không thể bảo đảm giữ toàn bộ lợi nhuận đang hiển thị.
- Khi terminal/VPS ngừng chạy, SL cuối cùng đã được server chấp nhận vẫn có thể tồn tại, nhưng EA không thể tiếp tục tính và nâng SL.
- Gap, spread widening, slippage, freeze level và broker rejection có thể làm giá đóng khác mức SL dự kiến.
- Nếu SL hiện tại bằng 0, EA phải coi đó là trạng thái bảo vệ bị thiếu; không được tùy tiện đặt một SL mới ở phía gây tăng rủi ro chỉ vì đã đạt điều kiện trailing.

---

## 2. Mục tiêu phiên bản V2

1. Xác định `BUY_ALLOWED`, `SELL_ALLOWED`, `NO_TRADE`, `REVERSAL_WATCH` với reason code.
2. Chỉ quyết định từ nến đã đóng; không look-ahead và không dùng tín hiệu repaint.
3. Một vị thế EA tối đa trên symbol trong phiên bản đầu.
4. Risk-based lot sizing, giới hạn khối lượng và kiểm tra margin.
5. SL ban đầu theo ATR hoặc cấu trúc; giữ fixed-points làm tùy chọn tương thích cũ.
6. Break-even và trailing ATR/structure có tính đơn điệu: BUY SL chỉ tăng; SELL SL chỉ giảm.
7. Daily loss, equity drawdown, losing-streak, cooldown, spread và volatility guards.
8. Không tự tái vào lệnh ngay sau khi vị thế đóng; cần tín hiệu mới trên nến EntryTF mới.
9. Persist/restore state sau restart; fail-safe nếu state không thể phục hồi.
10. Backtest có thể tái lập và chạy forward test trên DEMO.

## 3. Kiến trúc module đề xuất

```text
InfiniteRunner_XAU_V2.mq5
Include/
  Config.mqh
  Types.mqh
  MarketData.mqh
  DirectionEngine.mqh
  EntrySignalEngine.mqh
  RiskManager.mqh
  PositionManager.mqh
  TrailingManager.mqh
  ExecutionManager.mqh
  StateManager.mqh
  SessionFilter.mqh
  Logger.mqh
Tests/
  TestDirection.mq5
  TestRiskSizing.mq5
  TestTrailingMonotonic.mq5
  TestStateRecovery.mq5
Docs/
  STRATEGY_RULES.md
  INPUTS_REFERENCE.md
  TEST_PLAN.md
  DEMO_SETUP.md
  CHANGELOG.md
Reports/
```

**Nguyên tắc phụ thuộc:**

- `DirectionEngine` chỉ phân loại xu hướng; không gửi lệnh.
- `EntrySignalEngine` chỉ tạo signal + reason; không gửi lệnh.
- `RiskManager` là cổng bắt buộc trước entry.
- `ExecutionManager` là module duy nhất gửi/sửa/đóng trade request.
- `TrailingManager` tuyệt đối không nới SL theo hướng tăng rủi ro.
- `StateManager` không được xóa risk lock khi restart.

---

## 4. Direction Engine — phần ưu tiên số 1

### 4.1. Các kết quả chuẩn hóa

```text
BUY_ALLOWED
SELL_ALLOWED
NO_TRADE
REVERSAL_WATCH
DATA_NOT_READY
RISK_BLOCKED
SPREAD_BLOCKED
VOLATILITY_BLOCKED
```

Mỗi quyết định cần log: `decision_time`, timeframe, EMA values/slope, price close, structure state (nếu bật), regime, lý do cho phép hoặc chặn.

### 4.2. Chế độ xác định hướng

Tạo enum input `InpDirectionMode`:

- `DIR_EMA_MTF`: chế độ cơ bản để triển khai đầu tiên.
- `DIR_PA_MTF`: adapter cho bộ Price Action; chỉ bật khi source/logic PA được cung cấp và đã viết test tương đương.
- `DIR_LEGACY_EMA`: chế độ đối chiếu với logic cũ; chỉ dùng làm baseline, chuyển sang nến đóng.

Không được tuyên bố đã triển khai `DIR_PA_MTF` nếu chưa có code và unit test cho swing/BOS/CHoCH.

### 4.3. DIR_EMA_MTF — định nghĩa khởi điểm để kiểm thử

Timeframe mặc định theo cấu trúc của PA TrendRider spec:

- H1: bối cảnh chính.
- M15: xác nhận hướng.
- M5: trigger vào lệnh.

BUY bias:

1. H1 EMA fast > EMA slow trên nến H1 đã đóng.
2. EMA fast H1 có slope dương theo số nến lookback cấu hình; EMA slow không dốc xuống mạnh.
3. M15 EMA fast > EMA slow trên nến M15 đã đóng và slope không giảm.
4. M5 có trigger pullback/reclaim trên nến đã đóng: nến trước ở dưới/gần EMA fast, nến xác nhận đóng trở lại phía trên EMA fast và đóng phía trên EMA slow.
5. Spread, ATR regime, risk guard và cooldown đều cho phép.

SELL bias là điều kiện đối xứng.

Nếu H1 và M15 bất đồng, dữ liệu thiếu, EMA chưa đủ bars, hoặc M5 không có trigger mới thì `NO_TRADE`. Không được ép chọn BUY/SELL chỉ để bot luôn có lệnh.

Các ngưỡng slope, khoảng cách EMA, pullback tolerance phải là inputs có kiểm soát và được kiểm thử độ nhạy; không gán nhãn “tối ưu” trước khi có kết quả ngoài mẫu.

### 4.4. DIR_PA_MTF — adapter cho Price Action

Có thể dùng bộ quy tắc `PA_TrendRider_XAU_V1` đã cung cấp:

- H1: HH/HL hoặc LH/LL để xác định bias.
- M15: BOS/CHoCH xác nhận cấu trúc.
- M5: pullback/retest và nến xác nhận.
- Swing chỉ hợp lệ sau đủ nến bên phải; mọi tín hiệu phải ghi thời điểm xác nhận thật.
- Nếu H1/M15 mâu thuẫn hoặc CHoCH chưa giải quyết thì không mở entry mới.

Không gộp âm thầm hai chiến lược thành một. Giữ PA mode và EMA mode riêng để so sánh được.

---

## 5. Risk Management — tham số cấu hình cần có

Các giá trị bên dưới chỉ là **baseline nghiên cứu**, được tham khảo từ PA TrendRider spec đã có; không phải thông số tối ưu hay bảo đảm phù hợp với mọi tài khoản/symbol.

| Input | Baseline nghiên cứu | Ghi chú |
|---|---:|---|
| `InpLotMode` | RISK_PERCENT | Có thêm FIXED_LOT để so sánh |
| `InpRiskPercent` | 0.25% equity/lệnh | Không dùng nếu OrderCalcProfit lỗi |
| `InpMaxDailyLossPct` | 1.0% | Tính theo equity so với đầu ngày server |
| `InpMaxEquityDrawdownPct` | 8.0% | Từ peak equity đã lưu; khóa tới khi reset chủ động |
| `InpMaxConsecutiveLosses` | 3 | Net P/L gồm commission/swap/fee theo định nghĩa |
| `InpCooldownMinutes` | 30 | Sau chuỗi thua; có thể thêm cooldown sau mọi exit |
| `InpMaxPositions` | 1 | V1/V2 runner ban đầu |
| `InpMaxSpreadPoints` | broker-specific | Không mặc định 300 points cho mọi symbol |
| `InpMaxSpreadAtrRatio` | cấu hình được | Chặn spread tương đối lớn so với ATR |
| `InpAbnormalATRRatio` | 2.5 | So với baseline ATR; chỉ là baseline test |
| `InpMaxLots` | broker/user config | Luôn kiểm tra min/max/step |
| `InpMaxTradesPerDay` | configurable | Chống overtrading |
| `InpMinBarsBetweenEntries` | >= 1 | Chống lặp tín hiệu |
| `InpEnableSessionFilter` | false | Nếu bật, dùng server time và ghi timezone |

### 5.1. Tính khối lượng

Không ước lượng pip-value/contract size bằng hằng số XAUUSD. Quy trình bắt buộc:

1. Tính entry price và initial SL.
2. Gọi `OrderCalcProfit()` với volume 1.0 để lấy mức lỗ ước lượng bằng tiền tệ tài khoản.
3. Tính risk budget = equity × risk percent.
4. Chia risk budget cho loss-per-lot; làm tròn xuống theo `SYMBOL_VOLUME_STEP`.
5. Kiểm tra `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, giới hạn volume cấu hình.
6. Tính lại loss ở volume cuối; nếu vượt risk budget hoặc volume tối thiểu đã vượt ngân sách thì bỏ lệnh.
7. Kiểm tra margin bằng `OrderCalcMargin()`.

### 5.2. Risk lock

- Daily loss lock chặn entry mới nhưng vẫn tiếp tục quản lý vị thế đang mở.
- Equity DD lock từ peak equity cần được persist; không tự reset khi terminal restart hoặc sang ngày mới.
- Losing-streak và cooldown phải lấy từ deal đã đóng, tính net profit theo quy tắc rõ ràng.
- Có cơ chế reset thủ công có log; không có nút reset tự động theo tick.
- Lỗi dữ liệu/state hoặc không xác minh được quyền quản lý vị thế => safe mode, chặn entry.

---

## 6. SL và Profit Protection

### 6.1. Initial SL modes

- `SL_FIXED_POINTS`: tương thích với source cũ nhưng phải dựa trên point/tick size thực tế của symbol.
- `SL_ATR`: khoảng cách = ATR(M5 đã đóng) × multiplier.
- `SL_STRUCTURE`: BUY dưới swing low đã xác nhận; SELL trên swing high đã xác nhận, có buffer.

Có min/max stop distance. Nếu stop vượt giới hạn, quá gần broker stop level hoặc tính toán lỗi thì bỏ entry; không âm thầm thay bằng một SL bất hợp lý.

### 6.2. Break-even

- Dùng initial risk cố định được lưu tại thời điểm entry; không tính R lại theo SL đã trailing.
- Đến trigger R, tạo BE candidate cộng/trừ cost buffer có thể cấu hình.
- Chỉ cập nhật nếu candidate giảm rủi ro, đúng phía thị trường và broker cho phép.

### 6.3. Trailing modes

Tạo `InpTrailingMode`:

- `TRAIL_FIXED_DISTANCE` — tương thích logic hiện tại.
- `TRAIL_ATR` — theo ATR đã đóng.
- `TRAIL_SWING` — theo swing đã xác nhận.
- `TRAIL_HYBRID` — chọn candidate bảo vệ tốt hơn trong các ứng viên hợp lệ.

Các quy tắc bắt buộc:

- BUY: SL mới > SL cũ (theo step) hoặc giữ nguyên; không bao giờ giảm SL.
- SELL: SL mới < SL cũ (theo step) hoặc giữ nguyên; không bao giờ tăng SL.
- Nếu modify thất bại, giữ SL hiện tại, log retcode và không gửi request liên tục mỗi tick.
- Chuẩn hóa giá theo `SYMBOL_TRADE_TICK_SIZE`, kiểm tra `SYMBOL_TRADE_STOPS_LEVEL` và `SYMBOL_TRADE_FREEZE_LEVEL`.
- Không xóa SL hiện tại trước khi sửa SL mới thành công.
- Nếu đang có position nhưng SL = 0, phát cảnh báo mức nghiêm trọng, chặn entry mới và xử lý theo chính sách recovery đã test; không giả định position được bảo vệ.

---

## 7. Entry / Re-entry rules

- Chỉ tạo tín hiệu entry trên nến mới của EntryTF.
- Tín hiệu chỉ dùng các nến đã đóng (`shift >= 1`).
- Mỗi signal ID chỉ được xử lý một lần.
- Sau khi vị thế đóng, không tự động mở lại vì điều kiện EMA đơn giản vẫn đúng.
- Phải có trigger mới, spread/volatility/risk checks hợp lệ, cooldown hết hạn và không có request pending.
- Mặc định một vị thế EA tại một thời điểm.
- Không mở vị thế ngược hướng trước khi xác nhận vị thế cũ đã đóng hoàn toàn.
- Khi H1/M15 mâu thuẫn hoặc regime không rõ: NO_TRADE.

---

## 8. Broker / symbol compatibility

Không hardcode “XAUUSDm 3 digits” hoặc “1000 points = 1 USD”. Đọc thông số runtime:

- `SYMBOL_POINT`, `SYMBOL_DIGITS`, `SYMBOL_TRADE_TICK_SIZE`.
- `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_TRADE_TICK_VALUE_PROFIT`, `SYMBOL_TRADE_TICK_VALUE_LOSS` khi cần hiển thị.
- `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, `SYMBOL_VOLUME_STEP`, `SYMBOL_VOLUME_LIMIT`.
- `SYMBOL_TRADE_STOPS_LEVEL`, `SYMBOL_TRADE_FREEZE_LEVEL`.
- `SYMBOL_TRADE_MODE` và Bid/Ask từ tick hiện tại.
- Detect netting/hedging; không can thiệp vị thế thủ công/EA khác nếu không thể cô lập an toàn.

Symbol phải cấu hình được, không giả định duy nhất `XAUUSDm`; ví dụ `XAUUSD`, `XAUUSDm`, `GOLD` chỉ là ví dụ tên, phải xác minh từ Market Watch của terminal mục tiêu.

---

## 9. Logging và dashboard tối thiểu

### 9.1. Journal / CSV fields

`timestamp, symbol, timeframe, magic, signal_id, direction, direction_mode, h1_bias, m15_bias, m5_trigger, ema_fast, ema_slow, atr, spread_points, regime, decision, reason_code, entry, initial_sl, volume, risk_money, ticket, retcode, retcode_description, current_sl, sl_candidate, sl_update_result, exit_time, exit_reason, gross_profit, commission, swap, fee, net_profit, balance, equity, drawdown`.

### 9.2. Chart Comment/panel

Hiển thị:

- Direction: BUY / SELL / NO TRADE.
- H1/M15 bias.
- EntryTF trigger status.
- Spread, ATR/regime.
- Risk status: NORMAL / DAILY_LOCK / DD_LOCK / COOLDOWN.
- Current position, initial risk R, current SL, current floating P/L.
- Lý do gần nhất chặn entry.

Panel chỉ hiển thị thông tin; không dùng panel để bỏ qua risk guard.

---

## 10. Kế hoạch test bắt buộc

### Unit/logic tests

- Direction H1/M15 cùng hướng, ngược hướng và thiếu dữ liệu.
- EMA slope bằng 0/đổi dấu.
- M5 pullback reclaim BUY/SELL.
- Không dùng nến 0 cho signal.
- Không duplicate signal trong nhiều tick.
- Risk lot: min/step/max, OrderCalcProfit failure, minimum lot vượt ngân sách, margin fail.
- Daily loss, max DD, loss streak, cooldown và restart persistence.
- BUY SL không giảm; SELL SL không tăng.
- Tick size khác `_Point`, stop/freeze level, broker reject SL modify.
- Terminal restart khi có position; state thiếu/hỏng phải fail-safe.
- Netting/hedging và vị thế khác cùng symbol.

### Strategy Tester

- Baseline không optimization trước.
- Ưu tiên Every tick based on real ticks khi dữ liệu khả dụng.
- Ghi đúng symbol, timeframe, khoảng ngày, deposit, leverage, spread/commission/swap và model.
- Chia dữ liệu theo thời gian thành development / validation / final out-of-sample.
- Không dùng final out-of-sample để lặp lại tối ưu.
- Stress spread, commission, slippage, high ATR, range kéo dài, gap và chuỗi thua.

### Demo forward test

Chỉ cho phép demo account đã xác minh; kiểm tra reconnect, restart, SL modify reject, spread spike, market closed, duplicate order, risk locks và log. Thời gian test cần đủ để trải qua nhiều trạng thái thị trường; số ngày cố định không thay thế chất lượng mẫu.

---

## 11. Không tối ưu lợi nhuận theo một chỉ số

Không chọn cấu hình chỉ vì net profit hoặc win rate cao nhất. Bảng so sánh cần có:

- Net profit sau chi phí.
- Max equity drawdown và balance drawdown.
- Profit factor và expected payoff.
- Số lệnh, average win/loss, losing streak.
- Recovery factor/return-to-drawdown.
- MAE/MFE và tỷ lệ lợi nhuận bị trả lại.
- Độ ổn định theo tháng/regime.
- Sensitivity quanh bộ tham số tốt; tránh chỉ tốt ở một điểm hẹp.
- Out-of-sample và demo forward-test.

Tối ưu hóa phải có giới hạn số biến và khoảng tìm kiếm; lưu mọi run với config/hash/version. Nếu test ngoài mẫu yếu, quay lại thay đổi giả thuyết, không tiếp tục tune trên cùng tập cuối.

---

## 12. Tiêu chí nghiệm thu V2

- [ ] Compile không error trong MetaEditor; warnings được xử lý/giải thích.
- [ ] Không dùng nến chưa đóng cho hướng và entry.
- [ ] Có BUY/SELL/NO TRADE và reason code.
- [ ] Có MTF confirmation hoặc cấu hình strategy mode rõ ràng.
- [ ] Không tái vào lệnh ngay sau exit nếu chưa có signal mới.
- [ ] Risk-based lot được tính bằng OrderCalcProfit và volume step.
- [ ] Có SL initial và kiểm tra broker constraints.
- [ ] BUY SL monotonic tăng; SELL SL monotonic giảm.
- [ ] Kiểm tra retcode của mọi open/modify/close request.
- [ ] Daily loss, DD lock, loss streak và cooldown hoạt động.
- [ ] State phục hồi sau restart; lỗi state chuyển safe mode.
- [ ] Tương thích symbol suffix/tick size/volume rules.
- [ ] Không can thiệp position không thuộc EA.
- [ ] Có test report, baseline report, out-of-sample report và demo log.
- [ ] Không tuyên bố lợi nhuận tối ưu hoặc bảo đảm.

---

## 13. Tài liệu kỹ thuật tham khảo

- MQL5 `CTrade`: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade
- `CTrade::PositionModify` và yêu cầu kiểm tra retcode: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify
- `OrderCalcProfit`: https://www.mql5.com/en/docs/trading/ordercalcprofit
- Symbol stop/freeze/spread levels: https://www.mql5.com/en/book/automation/symbols/symbols_spreads_levels
- Symbol constants, tick size, volume constraints: https://www.mql5.com/en/docs/constant_indices
- MT5 Strategy Tester: https://www.metatrader5.com/en/terminal/help/algotrading/testing

---

## 14. Kết luận

InfiniteRunner_XAU V1 hiện là một EA EMA 2 đường + fixed lot + fixed SL + trailing. V2 cần ưu tiên sửa tính đúng của tín hiệu và an toàn trước, sau đó mới đánh giá hiệu quả. Thiết kế khuyến nghị: MTF Direction Engine (H1/M15) + M5 closed-bar trigger, risk sizing theo tiền tệ tài khoản, risk locks, trailing ATR/structure đơn điệu, chống re-entry tức thì, logging và state recovery. Chỉ đánh giá trong Strategy Tester và demo trước khi xem xét bất kỳ thay đổi vận hành nào.
