# PA_TrendRider_XAU_V1 — Bản triển khai mô phỏng và báo cáo kiểm thử

Tài liệu này mô tả bản triển khai **simulation-only** của đặc tả
[`PA_TrendRider_XAU_V1_Specification_Vietnamese.md`](PA_TrendRider_XAU_V1_Specification_Vietnamese.md),
cách chạy lại, kết quả kiểm thử thật trong MT5 và các khác biệt bắt buộc so với đặc tả.

> **Ranh giới thực thi:** EA chỉ tạo **vị thế ảo trong bộ nhớ** (`CSimPortfolio`) và ghi CSV.
> Không có `OrderSend`, `CTrade`, API position/order/account, không kết nối broker và không lưu
> credential. Strategy Tester hiển thị **0 deal** là đúng theo thiết kế; kết quả mô phỏng nằm trong
> CSV. Xem [`decisions/0002-execution-boundary.md`](decisions/0002-execution-boundary.md).

## 1. Phạm vi

| Hạng mục | Trạng thái |
|---|---|
| Phân tích cấu trúc H1/M15/M5, BOS/CHoCH, bias, regime | **PASS** (82 vector contract + chạy thật) |
| Pullback/retest + nến xác nhận M5 | **PASS** (contract + chạy thật) |
| Risk 0.25%, lot theo tick size/value, daily/DD/streak lock | **PASS** (contract + chạy thật) |
| Một vị thế ảo, SL cấu trúc, BE 1R, trailing ATR + cấu trúc | **PASS** (contract + chạy thật) |
| State machine + persistence (ledger, vị thế) | **PASS** (compile + chạy thật ghi/đọc file) |
| Strategy Tester baseline + cost stress trên `XAUUSDm` M5 | **PASS** (chạy thật, CSV lưu trong `reports/build/tester-reports/`) |
| Gửi lệnh thật / demo forward test | **BLOCKED** theo `0002-execution-boundary.md` |
| OrderCalcProfit/Margin, kiểm tra margin, netting/hedging thật | **BLOCKED** — API bị cấm trong repo |
| Out-of-sample dài hạn, tối ưu tham số | **NOT_RUN** — ngoài phạm vi lượt này |

## 2. Kiến trúc mã nguồn

```text
mt5/Include/TrendRider/
├── TRTypes.mqh        enum, struct bar/swing, tên trạng thái
├── TRConfig.mqh       tham số + validate fail-closed + fingerprint
├── TRSwing.mqh        fractal swing left/right, chống tie, chỉ sau right nến
├── TRStructure.mqh    BOS/CHoCH, dedupe theo thời gian swing, protected swing
├── TRTrend.mqh        ghép bias H1/M15, regime theo thứ tự ưu tiên
├── TRPullback.mqh     vùng retest, nến xác nhận
├── TRSignal.mqh       quyết định entry + reason code
├── TRAtr.mqh          ATR/median ATR deterministic từ nến đóng
├── TRRisk.mqh         lot theo tick, stop band, ledger daily/DD/streak/cooldown
├── TRTrailing.mqh     BE và trailing, chỉ cải thiện SL
├── TRState.mqh        state machine + serialize/deserialize
└── TRMarketData.mqh   đọc nến đã đóng, symbol spec, spread
mt5/Experts/PATrendRiderXAUv1SimEA.mq5     EA mô phỏng
mt5/Scripts/TrendRiderContractTests.mq5    82 vector kiểm thử
```

Module thuần (trừ `TRMarketData`) không gọi API thị trường, nên kiểm thử được bằng vector tổng hợp.
EA chỉ dùng `CopyRates`, `iTime`, `SymbolInfoDouble/Integer` và file CSV/state.

## 3. Luồng xử lý

1. `OnInit`: validate input → symbol spec → cost model → portfolio (contract size) → logger →
   restore state (nếu có) → `READY` → `WAITING_FOR_SETUP`.
2. `OnTick`: cập nhật equity/peak → kiểm tra SL (mỗi tick) → xác nhận reversal (M15) → chỉ phân tích
   khi `iTime(entry TF, 0)` đổi (nến M5 vừa đóng).
3. Phân tích nến đóng: nạp H1/M15/M5 (`start_pos=1`), ATR từng khung, median ATR M5, spread →
   cập nhật engine cấu trúc → bias/regime → guard rủi ro → trailing → tín hiệu entry.
4. Entry: BOS cùng bias + retest + nến xác nhận → SL cấu trúc (`swing low/high ± 0.2×ATR`) → kiểm tra
   stop band/broker level → lot → exposure → mở vị thế ảo → `POSITION_OPEN`.
5. Exit: SL/ trailing (kể cả gap) hoặc `REVERSAL_CONFIRMED` sau CHoCH M15 và cấu trúc M15 đảo chiều.
6. `OnDeinit`: ghi SUMMARY và state; không có lệnh nào được gửi.

## 4. Cấu hình mặc định

Preset: [`configs/sim/pa_trendrider_xau.json`](../configs/sim/pa_trendrider_xau.json).

| Nhóm | Giá trị |
|---|---|
| Khung | H1 / M15 / M5, 300/300/400 nến đóng |
| Swing | left = 2, right = 2, buffer = max(spread×2, ATR×0.10) |
| Bias/regime | HH/HL & LH/LL với delta ≥ 0.05×ATR; ưu tiên risk → spread → volatility → reversal → trend |
| Entry | retest ±0.25×ATR, thân nến ≥ 0.5×ATR, close trong 25% biên, tuổi BOS ≤ 8 nến |
| Risk | 0.25%/lệnh, 1 vị thế, daily 1%, DD 8% (sticky), 3 lệnh thua → nghỉ 30 phút |
| Stop | SL cấu trúc ±0.2×ATR; BE 1R; trail từ 1.5R, ATR×1.2; SL chỉ siết |
| Bộ lọc | ATR > 2.5×median (100 nến) → chặn; spread > 600 điểm hoặc > 0.25×ATR → chặn |
| Chi phí | commission/lot/lần khớp, slippage điểm bất lợi; swap = 0 trong preset |

## 5. Khác biệt bắt buộc so với đặc tả

1. **Không dùng `OrderCalcProfit`/`OrderCalcMargin`.** Lot tính từ
   `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_TRADE_TICK_VALUE`, volume step; không kiểm tra margin vì không có
   lệnh thật. Commission khứ hồi được cộng vào ngân sách rủi ro.
2. **Không có broker/account API.** Không đọc currency, trade mode, netting/hedging; không đối chiếu
   vị thế thật khi restart. `currency=assumed_account` được ghi trong log.
3. **Không có TP cố định.** Thoát bằng SL cấu trúc, BE/trailing hoặc reversal đã xác nhận.
4. **Break-even tại entry, chưa cộng cost buffer.** Đặc tả cho phép ghi rõ phần chi phí chưa bao gồm;
   commission/swap không được dời BE.
5. **P&L mô phỏng dùng contract size 100** (XAUUSDm). `CSimPortfolio.InitWithContractSize` là phần mở
   rộng tương thích ngược của core; `Init(balance)` cũ vẫn giữ contract size 1.
6. **State được lưu/khôi phục** (ledger + vị thế ảo) nhưng không thể đối chiếu với broker. Nếu file
   state hỏng, EA chuyển `ERROR_SAFE_MODE` và tắt entry thay vì suy diễn.
7. **Không có session filter** (không nằm trong yêu cầu bắt buộc V1 của đặc tả).
8. **Kết quả tester 0 deal.** Chỉ CSV mô phỏng có P&L; đây là bằng chứng duy nhất, không phải báo cáo
   lãi/lỗ của tài khoản.

## 6. Kiểm thử đã chạy thật

### 6.1 Contract suite

| Suite | Số vector | Kết quả | Bằng chứng |
|---|---|---|---|
| `TrendRiderContractTests` | 82 | **82/82 PASS** | `reports/build/tester-reports/contract_trendrider/test_output.txt` |
| `SimCoreTests` (gồm P23/P24 contract size) | 125 | **125/125 PASS** | log tester 2026-10-28 |
| Compile EA (repo + Data Folder) | — | **0 errors, 0 warnings** | `reports/build/trendrider/` |

Vector bao phủ: swing/tie/độ trễ xác nhận, BOS/CHoCH không lặp, dedupe khi cửa sổ trượt (B9), bias và
regime ưu tiên, retest/confirmation, reason code, lot min/step/max/commission, stop band + broker level,
daily/DD/streak/cooldown, serialize ledger, BE/trailing đơn điệu, state transition, ATR/median.

### 6.2 Strategy Tester

Điều kiện chung: `XAUUSDm`, chart M5, model *1 minute OHLC*, 2026-01-05 → 2026-03-05, deposit
**5 000 USD** cho cả hai scenario, leverage 1:100, không tối ưu tham số.

| Scenario | Entry | Exit | Win/Loss | Net mô phỏng | Max DD | Ghi chú |
|---|---|---|---|---|---|---|
| `pa_trendrider_baseline` | 4 | 4 | 0 / 4 | **−36.72** | 0.93% | spread 160–360 điểm; 6 lần cooldown; 22 setup bị `lot_rejected` |
| `pa_trendrider_cost_stress` | 4 | 4 | 0 / 4 | **−37.28** | 0.94% | commission 5/lot, slippage 20 điểm, spread cap 400; 60 lần chặn spread |

- Cả 8 exit đều là `SL_GAP` (gap nhỏ do tick 1 phút); không có TP. Có 1 lần trailing break-even
  (`profit_r≈1.0`) và 0 lần daily/DD lock.
- Audit CSV: 18 cột, ENTRY/EXIT khớp cặp, không có vị thế mở cuối kỳ, BUY có SL < entry, `tp=0`,
  trailing chỉ siết SL.
- Chạy lại baseline cho **cùng kết quả tuyệt đối**: 4 lệnh, net −36.72, `config_hash=5935E19B`,
  SHA256 CSV `557ef758…f717c`.
- **Vì sao ít lệnh hơn bản 10 000 USD:** với 5 000 USD và risk 0.25% (12.50 USD), lot tối thiểu 0.01 chỉ
  chịu được stop tới ~12.5 USD; 22 setup có stop xa hơn bị EA từ chối đúng với
  `lot_rejected|min_volume_exceeds_risk`. Bản 10 000 USD (risk 25 USD) chạy 13 lệnh. Đây là thay đổi do
  giới hạn lot, không phải do tín hiệu.
- **Diễn giải trung thực:** đây là baseline của một giả thuyết chưa tối ưu, lỗ nhẹ trong mẫu 2 tháng;
  không đủ để kết luận chiến lược tốt hay xấu, càng không phải khuyến nghị giao dịch.

### 6.3 Lỗi phát hiện qua chạy thật và đã sửa

| Lỗi | Triệu chứng | Sửa |
|---|---|---|
| Dedupe BOS theo index | Cùng một swing phát lại BOS khi cửa sổ trượt (BOS 3423 → 952 sau sửa) | So sánh `swing.time`, thêm vector B9 |
| BOS treo vô hạn | ~10 700 dòng chặn entry, setup không hết hạn | Xóa BOS khi `bos_too_old` hoặc `ZONE_INVALIDATED` |
| Tiền tố log lặp | `ENTRY_BLOCKED|reason=ENTRY_BLOCKED|reason=...` | Chuẩn hóa reason trong `LogEntryBlocked` |
| `TRLoadClosedBars` lệch 1 nến | Bỏ nến đóng mới nhất | Đọc đủ `copied` nến, kiểm tra `iTime(...,1)` mỗi lần nạp |

### 6.4 Áp lực rủi ro đã biết

Với balance 5 000 USD và risk 0.25% (12.50 USD), lot tối thiểu 0.01 của XAUUSDm lỗ đúng bằng khoảng
cách stop tính bằng USD (0.01 lot × contract 100). Stop ATR/cấu trúc thường 7–12 USD nên phần lớn
khớp, nhưng stop rộng hơn 12.5 USD bị **từ chối đúng** với `lot_rejected|min_volume_exceeds_risk`
(22 lần trong mẫu). Với 1 000 USD (risk 2.50 USD) gần như mọi setup bị chặn; bản 10 000 USD
(risk 25 USD) chạy 13 lệnh.

Đây là xung đột giữa đặc tả (risk 0.25%) và giới hạn lot của broker, cần quyết định sản phẩm riêng:
tăng balance, tăng risk percent, hoặc chấp nhận bỏ tín hiệu. Không được hạ chuẩn lot hay bỏ kiểm tra
risk để che xung đột này.

## 7. Chạy lại

```powershell
# 1) Compile toàn bộ nguồn MQL5 (0 lỗi/0 cảnh báo mới được coi là PASS)
powershell -ExecutionPolicy Bypass -File scripts\build-mql5.ps1

# 2) Kiểm tra tĩnh + preset
.\.venv\Scripts\python.exe scripts\validate_trendrider.py
.\.venv\Scripts\python.exe scripts\validate_sim_configs.py
.\.venv\Scripts\python.exe -m pytest

# 3) Deploy EA + include vào Data Folder rồi compile trong Data Folder
#    (dùng cùng thư mục MQL5\Include\Sim và MQL5\Include\TrendRider)

# 4) Sinh .set/.ini và chạy headless
python reports\build\tester-run\gen_trendrider_sets.py
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" `
  "/config:D:\Applications\tm-fx\reports\build\tester-run\pa_trendrider_baseline.ini"
```

> **Quan trọng:** agent của Strategy Tester xóa sạch `MQL5\Files` trong sandbox ở đầu mỗi lượt test.
> Phải copy CSV/state ra `reports/build/tester-reports/` **ngay sau khi lượt chạy kết thúc**, trước khi
> chạy scenario tiếp theo. Trong MT5 thật, file nằm ở
> `MQL5\Files\<tên file>` của Data Folder.

## 8. Tiêu chí nghiệm thu (đối chiếu mục 17 của đặc tả)

| Tiêu chí | Trạng thái |
|---|---|
| Compile MetaEditor | **PASS** (0/0, repo + Data Folder) |
| Không dùng dữ liệu tương lai; swing không repaint | **PASS** thiết kế + contract (chỉ nến đóng, `start_pos=1`) |
| BOS/CHoCH có test | **PASS** (B1–B9) |
| Lot theo thông số symbol, làm tròn xuống | **PASS** (R3–R7; thay `OrderCalcProfit` bằng tick metrics) |
| SL ban đầu, không TP cố định | **PASS** |
| Trailing không nới SL | **PASS** (L1–L6 + audit CSV) |
| Một vị thế, không đảo chiều trước khi đóng | **PASS** (state machine + audit) |
| Daily loss + drawdown lock, phục hồi sau restart | **PASS** (ledger + contract R13–R19; restore có fail-safe) |
| Log + reason code | **PASS** (CSV 18 cột, 332 dòng REGIME, reason chi tiết) |
| Retcode/broker constraints | **BLOCKED** — không có lệnh thật để nhận retcode; đã có stop level/tick |
| Baseline + chi phí + stress spread/slippage | **PASS** (2 scenario chạy thật) |
| Chia dữ liệu in-sample/validation/out-of-sample | **NOT_RUN** |
| Demo forward test | **BLOCKED** theo quyết định 0002 |
| Không tuyên bố lợi nhuận thiếu bằng chứng | **PASS** — báo cáo nêu rõ lỗ và giới hạn mẫu |

## 9. Giới hạn và bước tiếp theo

- Mẫu 2 tháng, một symbol, model 1-minute OHLC: chưa đủ kết luận thống kê; cần chia 60/20/20 và
  chạy out-of-sample **một lần** trước khi xem xét bất kỳ thay đổi tham số nào.
- Chưa mô phỏng swap, gap cuối tuần, spread biến động theo phiên; nên bổ sung vào cost model có test.
- Chưa có cảnh báo/khóa khi mất kết nối hoặc terminal restart giữa lệnh thật (không áp dụng cho mô
  phỏng).
- Muốn tiến tới demo execution phải mở scope mới theo `docs/decisions/0002-execution-boundary.md`,
  với credential do người dùng quản lý và không nằm trong repo này.
