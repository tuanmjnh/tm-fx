# Mô hình rủi ro

**Phạm vi:** PATrendRider SimEA/DemoEA; Grid/DCA ở phần cap mô phỏng.  
**Nguyên tắc:** mọi giới hạn là **bộ ngắt**, không phải cam kết lỗ tối đa. Gap, slippage, spread mở rộng và lỗi terminal có thể vượt giới hạn.

## 1. Position sizing (PATrendRider)

Công thức trong `mt5/Include/TrendRider/TRRisk.mqh`:

```text
risk_money        = equity × risk_percent / 100
loss_per_lot      = |entry − sl| / tick_size × tick_value
round_trip_comm   = 2 × commission_per_volume
total_per_lot     = loss_per_lot + round_trip_comm
raw_volume        = risk_money / total_per_lot
volume            = floor(raw_volume / volume_step) × volume_step
```

Sau đó:

1. Cap ở `volume_max`.
2. Nếu `volume < volume_min` → từ chối (`min_volume_exceeds_risk`), **không** làm tròn lên.
3. Nếu `volume × total_per_lot > risk_money` → từ chối (`expected_loss_exceeds_budget`).
4. Kiểm tra margin bằng `ExecMarginRequired` trước khi gửi (DemoEA).
5. Ghi `risk_money`, `expected_loss`, `loss_per_lot` vào journal.

Mặc định: `risk_percent=0.25`, `commission_per_volume=0.0`. Với XAUUSDm (point 0.001, 3 digits, tick value 0.1/lot/tick), lot được làm tròn xuống theo `SYMBOL_VOLUME_STEP`.

## 2. Stop loss (PATrendRider)

- SL đặt tại swing cấu trúc gần nhất ± buffer `0.2 × ATR`:
  - BUY: `sl = structure_level − 0.2 × ATR`
  - SELL: `sl = structure_level + 0.2 × ATR`
- Làm tròn theo tick size.
- Hợp lệ khi:
  - `0.5 × ATR ≤ |entry − sl| ≤ 4.0 × ATR`
  - khoảng cách ≥ `SYMBOL_TRADE_STOPS_LEVEL`
  - SL/TP thỏa `ExecStopsRespectBroker` (stops level + freeze level)
- Không hợp lệ → block entry với `stop_too_tight`, `stop_too_wide`, `stop_below_broker_level`.

## 3. Take profit và trailing

| Quy tắc | Giá trị | Ghi chú |
|---|---|---|
| TP | `entry ± 3R` | Bắt buộc; `InpTakeProfitR > 0` |
| Break-even | 1R | Dời SL về entry |
| Trailing start | 1.5R | Bắt đầu trail |
| ATR trailing | `price ∓ 1.2 × ATR` | Chỉ khi tốt hơn SL hiện tại |
| Structure trailing | Swing đối nghịch gần nhất | Nếu tốt hơn candidate |
| Cập nhật | Chỉ trên bar đã đóng | `InpUpdateOnClosedBarOnly=true` |
| Monotonic | SL chỉ siết, không nới | `TRTrailingEvaluate` từ chối candidate không tốt hơn |
| Khoảng cách tối thiểu | `min_stop` | Tránh trail quá sát giá |

`R` được đo bằng khoảng cách SL ban đầu và **không** tính lại sau khi SL di chuyển.

## 4. Account-level locks (PATrendRider)

Ledger `TRRiskLedger` đọc balance/equity tài khoản (không chỉ P&L của EA).

| Lock | Điều kiện | Hành vi | Reset |
|---|---|---|---|
| Daily loss | `equity ≤ day_start × (1 − 1%)` | Block entry mới | Sang ngày server mới |
| Drawdown | `equity ≤ peak × (1 − 8%)` | Block entry mới; **sticky** | Chỉ `ManualResetDrawdown` hoặc xóa state |
| Streak | 3 lỗ liên tiếp | Cooldown 30 phút | Hết cooldown hoặc có lệnh thắng |
| Cooldown | `now < cooldown_until` | Block entry mới | Hết thời gian |

Thứ tự ưu tiên trong `EntryBlock`: drawdown → daily loss → cooldown. Lý do được ghi vào journal.

**Quan trọng:** ledger theo tài khoản. Một lệnh do probe hoặc EA khác gây lỗ cũng làm tăng drawdown của DemoEA. Đây là hành vi đúng nhưng phải nhớ khi đọc số.

## 5. State machine

Các trạng thái trong `TRState.mqh`:

```text
INITIALIZING → READY → WAITING_FOR_SETUP → ENTRY_REQUESTED → POSITION_OPEN
                                                     ↘ REVERSAL_WATCH → CLOSE_FOR_REVERSAL
READY/WAITING/POSITION → COOLDOWN / DAILY_LOCKED / DRAWDOWN_LOCKED / ERROR_SAFE_MODE
```

- Trạng thái bảo vệ (`DAILY_LOCKED`, `DRAWDOWN_LOCKED`, `ERROR_SAFE_MODE`) **không** bị ghi đè bởi tín hiệu entry.
- `ERROR_SAFE_MODE` chỉ về `READY` qua `ManualReset`.
- Kill switch đưa state sang `ERROR_SAFE_MODE` và chốt cứng tới khi restart.
- Transition không hợp lệ bị từ chối và ghi `invalid_transition`.

## 6. Kill switch

- File: `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt`.
- Khi tồn tại:
  - EA đóng vị thế đang mở (nếu có).
  - Khóa entry (`g_kill_switch` chốt tới khi `OnInit` chạy lại).
  - Ghi `KILL kill_switch_file|entries_disabled`.
- **Xóa file là chưa đủ:** `OnDeinit` đã ghi state `ERROR_SAFE_MODE`; lần init sau sẽ khôi phục state đó. Phải reset state file (hoặc dùng `InpResetStateOnInit`) sau khi đã review.
- Bằng chứng: PROGRESS §44.4 (file thật, 16 giây).

## 7. Grid/DCA caps (mô phỏng)

| Giới hạn | Grid | DCA |
|---|---|---|
| Số level/add | `InpMaxGridLevels=5` | `InpMaxDcaAdds=3` (`0` = không add) |
| Volume mỗi level/add | `base × 1.5^(n−1)`, cap `1.0` | `base × 1.5^n`, cap `1.0` |
| Exposure | `InpMaxVirtualExposure=2.0` | `2.0` |
| Spread | `InpMaxSpreadPoints` (preset 600) | 600 |
| Daily loss | 2% | 2% |
| Drawdown | 5% | 5% |
| Basket stop | `InpBasketStopPoints=900` (bắt buộc) | 900 (bắt buộc) |
| Add bị chặn | Không partial fill | Không partial fill |

Add chỉ xảy ra khi qua toàn bộ guard. Khi exposure + volume vượt cap, add bị **chặn**, không cắt bớt volume.

## 8. Giới hạn trung thực

- **Không mô hình hóa margin call/stop-out** trong simulation; equity là mô hình, không phải equity broker.
- **Contract size = 1** trong simulation; P&L không dùng để suy ra lot thật.
- **SL-first** khi cùng bar; OHLC không cho biết thứ tự intrabar thật.
- **Gap/slippage** có thể làm lỗ vượt cap; grid/DCA chỉ báo `loss_cap_overshoot` nếu có.
- **Daily/drawdown lock** tính trên equity tại thời điểm tick/bar, không phải mọi tick.
- **Kill switch** là guard phần mềm; không chống được terminal tắt, mất kết nối hoặc broker từ chối.
- **Không có kết luận lợi nhuận** từ bất kỳ con số nào trong tài liệu này.

## 9. Liên kết

- Code: [`../../mt5/Include/TrendRider/TRRisk.mqh`](../../mt5/Include/TrendRider/TRRisk.mqh), [`../../mt5/Include/TrendRider/TRTrailing.mqh`](../../mt5/Include/TrendRider/TRTrailing.mqh), [`../../mt5/Include/TrendRider/TRState.mqh`](../../mt5/Include/TrendRider/TRState.mqh)
- Guard: [`../../mt5/Include/Exec/ExecGuard.mqh`](../../mt5/Include/Exec/ExecGuard.mqh)
- Rủi ro đầy đủ: [`../reference/risk.md`](../reference/risk.md)
- ADR: [`../decisions/0003-demo-execution-scope.md`](../decisions/0003-demo-execution-scope.md)
