# Simulation MQL5 — core, runner, grid, DCA, plan, wonderwhales, preset

> Tài liệu tổng hợp, giữ nguyên nội dung gốc; tiêu đề đã hạ một cấp để thống nhất một cây tài liệu. Nguồn: `sim-core.md`, `sim-runner.md`, `sim-grid.md`, `sim-dca.md`, `sim-presets.md` + mục PinePlanSimEA (W10) + mục WonderwhalesSimEA (2026-10-28).

Nội dung:
1. Simulation core (MQL5) — W1–W5
2. RunnerTrailingLabEA (simulation-only, W3)
3. GridLabEA (simulation-only, W4)
4. DCALabEA (simulation-only, W5)
5. Preset và validator fail-closed (W6)
6. PinePlanSimEA — EA mô phỏng theo trade plan (W10)
7. WonderwhalesSimEA — tín hiệu Wonderwhales trên XAUUSDm

---
## Simulation core (MQL5) — W1–W5

- **Phạm vi:** thư viện dùng chung cho năm EA mô phỏng Track C (`RunnerTrailingLabEA`, `GridLabEA`,
  `DCALabEA`, `PinePlanSimEA`, `WonderwhalesSimEA`). Chỉ tạo vị thế ảo trong bộ nhớ; không có API gửi
  lệnh, không đọc tài khoản.
- **Trạng thái:** compile `0 errors, 0 warnings`; `SimCoreTests` **PASS runtime 123/0** trong MT5 ngày
  2026-10-28; `SimPlanTests` **PASS runtime 39/0** cùng ngày.
- **Nguồn lộ trình:** [`MASTER_ROADMAP.md`](../MASTER_ROADMAP.md) mục W1–W5.

### 1. File

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimTypes.mqh` | `ENUM_SIM_SIDE`, tên side, FNV-1a 32-bit và helper fingerprint config |
| `mt5/Include/Sim/SimValidate.mqh` | Validate input số/nguyên với token lỗi ổn định |
| `mt5/Include/Sim/SimPortfolio.mqh` | `CSimPortfolio`: vị thế ảo, average entry, P&L, equity, drawdown |
| `mt5/Include/Sim/SimCostModel.mqh` | `CSimCostModel`: spread, commission, slippage, swap theo giả định khai báo |
| `mt5/Include/Sim/SimRiskGuard.mqh` | `CSimRiskGuard`: hard cap, cooldown, kill switch, `ACTIVE/BLOCKED/HALTED` |
| `mt5/Include/Sim/SimTrailing.mqh` | `SimTrailingEvaluate` (breakeven + trailing), helper stop-hit/gap thuần |
| `mt5/Include/Sim/SimGrid.mqh` | `SimGridPlanAdd` (level/volume/exposure cap), giá tầng, trigger, target/stop basket |
| `mt5/Include/Sim/SimDca.mqh` | `SimDcaPlanAdd` (add/volume/exposure cap), volume từng lần add, trigger giá/bar |
| `mt5/Include/Sim/SimPlan.mqh` | `SimPlanResolveSide`, `SimPlanValidate`, chọn/hit/fill target cho trade plan (W10) |
| `mt5/Include/Sim/SimLogger.mqh` | `SimLogRecord` + `CSimLogger`: CSV schema cố định trong `MQL5/Files` |
| `mt5/Scripts/SimCoreTests.mq5` | 123 test vector: portfolio, validate, hash, log, cost, risk, trailing, grid, DCA |
| `mt5/Scripts/SimPlanTests.mq5` | 39 test vector: resolve side, validate plan, chọn/hit/fill target |
| `python/tests/test_sim_core_source.py` | 12 test tĩnh: schema, placeholder, cấm API, FNV, test id, token ổn định |
| `python/tests/test_dca_vectors.py` | 4 test độc lập: average entry, P&L target/stop, commission của basket DCA |

Không có `OrderSend`, `OrderSendAsync`, `CTrade`, `MqlTradeRequest` hoặc hàm position/order nào.

### 2. Quy ước tính toán

- **Contract size = 1:** một đơn vị volume lãi/lỗ đúng một đơn vị tiền báo giá cho mỗi đơn vị giá.
  Đây là giả định mô phỏng, không phải thông số hợp đồng thật.
- **Commission là tổng tiền mỗi lần khớp** (tính theo volume), trừ ngay vào `balance` khi mở và khi đóng.
- `balance = initial_balance + realized_pnl`; `equity = balance + unrealized_pnl(price)`.
- **Một chiều tại một thời điểm:** mở side ngược chiều khi đang có vị thế trả `opposite_side_not_allowed`.
- **Drawdown** tính trên equity mô phỏng từ peak equity, đơn vị phần trăm.
- Giá không hợp lệ (NaN/inf/<=0) khi tính P&L trả 0 thay vì lan giá trị rác.
- **Partial close:** `CloseProfitableAtLeast` đóng các vị thế đạt ngưỡng lãi trên mỗi volume và giữ phần
  còn lại; commission tính trên volume đã đóng. `MinEntry`/`MaxEntry` trả entry thấp/cao nhất đang mở.
- Percent `0` nghĩa là **tắt** giới hạn, không phải "chặn tất cả".

### 3. Token lỗi ổn định

| Hàm | Token |
|---|---|
| `SimValidatePrice` | `price_must_be_finite_positive` |
| `SimValidateVolume` | `volume_must_be_finite_positive` |
| `SimValidateCommission` | `commission_must_be_finite_non_negative` |
| `SimValidateInitialBalance` | `initial_balance_must_be_finite_positive` |
| `SimValidateLevels` | `levels_must_be_between_1_and_1000` |
| `SimValidateMultiplier` | `multiplier_must_be_finite_and_at_least_one` |
| `SimValidatePercent` | `percent_must_be_finite_between_0_and_100` |
| `SimValidateSpreadPoints` | `spread_must_be_finite_non_negative` |
| `SimValidateWarmupBars` | `warmup_bars_must_be_non_negative` |
| `SimValidateSlippagePoints` | `slippage_must_be_finite_non_negative` |
| `SimValidatePoint` | `point_must_be_finite_positive` |
| `SimValidateFinite` / `SimValidateCount` | token do nơi gọi truyền vào, phải cố định |
| `CSimPortfolio::Open` | `portfolio_not_initialized`, `side_must_not_be_none`, `opposite_side_not_allowed`, `portfolio_resize_failed` |
| `CSimPortfolio::CloseAll` | `portfolio_not_initialized`, `no_open_positions` |

EA phải trả `INIT_PARAMETERS_INCORRECT` khi validate thất bại và log token, không tự sửa input.

### 4. Ví dụ tính tay (đã encode thành test)

#### P8 — một vị thế

Mở BUY 2.0 tại 1.2, balance 10000, commission 0 → average entry 1.2, exposure 2.0,
unrealized tại 1.25 = `(1.25 - 1.2) * 2 = 0.10`.

#### P9 — average entry theo volume

BUY 1.0 @ 1.1 và BUY 2.0 @ 1.0 → average = `(1.1*1 + 1.0*2) / 3 = 1.03333333`,
exposure 3.0, unrealized tại 1.05 = `0.05`. Đóng tại 1.05 → `realized_delta = +0.05`.

#### P11–P12 — commission và realized P&L

Mở BUY 1.0 @ 1.1, commission 2 → balance `9998`, realized `-2`.
Đóng @ 1.12, commission 3 → gross `+0.02`, `realized_delta = -2.98`, realized `-4.98`,
balance `9995.02`.

#### P16–P18 — drawdown

Balance 10000, BUY 1.0 @ 100.
Giá 90 → equity 9990, DD `0.1%`; giá 105 → peak 10005; giá 80 → equity 9980,
DD `(10005-9980)/10005*100 ≈ 0.2499%`.

#### P20–P22 — partial close

BUY 1.0 @ 1.0 và BUY 2.0 @ 0.9, giá 1.0, ngưỡng lãi 0.05/volume, commission 0.5/volume:
chỉ vị thế thứ hai đóng, gross `(1.0-0.9)*2 = 0.2`, commission `1.0`, `realized_delta = -0.8`,
còn 1 vị thế entry 1.0. Gọi lại → `no_matching_positions`. SELL 1.0 @ 1.0 và 1.0 @ 1.1 tại giá 0.9,
commission 0 → đóng cả hai, `realized_delta = 0.3`.

### 5. CostModel

`SimCostAssumptions` khai báo bốn giả định, không có giá trị "mặc định thị trường":

| Trường | Đơn vị | Validate |
|---|---|---|
| `point` | đơn vị giá / point | `point_must_be_finite_positive` |
| `commission_per_volume` | tiền tài khoản / 1.0 volume / fill | `commission_must_be_finite_non_negative` |
| `slippage_points` | point bất lợi mỗi fill | `slippage_must_be_finite_non_negative` |
| `swap_per_volume_day` | tiền tài khoản, âm = phí, dương = credit | `swap_must_be_finite` |

Công thức:

- `SpreadPrice(spread_points) = spread_points * point`
- `SpreadCost(volume, spread_points) = SpreadPrice * volume`
- `Commission(volume) = commission_per_volume * volume`
- `Swap(volume, days) = swap_per_volume_day * days * volume`
- `TotalCost = SpreadCost + Commission + Swap`
- `FillPrice(side, requested, extra_points)`:
  `BUY = requested + (slippage_points + extra_points) * point`,
  `SELL = requested - (slippage_points + extra_points) * point`.

Ví dụ C5–C10: `point=0.0001`, `commission=4`, `slippage=1`, `swap=-1.5`.
BUY 1.1 với spread 2 point → `1.1003`; SELL → `1.0997`; commission 2.5 volume → `10.0`;
swap 2 volume × 3 ngày → `-9.0`; tổng cost 2 volume, spread 20 point, 1 ngày → `5.004`.

Giới hạn: spread/slippage không đổi theo thời gian, không mô phỏng latency hay partial fill; swap chỉ
tính theo số ngày nguyên do nơi gọi truyền vào.

### 6. RiskGuard

`SimRiskLimits` (giá trị mặc định bảo thủ từ `SimRiskLimitsDefault()`):

| Cap | Ý nghĩa | Vi phạm |
|---|---|---|
| `max_spread_points` | spread tối đa; 0 = tắt | `spread_exceeded` |
| `max_virtual_positions` | số vị thế ảo tối đa | `max_virtual_positions_reached` |
| `max_grid_levels` | số tầng grid tối đa; 0 = EA không dùng grid | `max_grid_levels_reached` |
| `max_dca_adds` | số lần DCA tối đa; 0 = tắt kiểm tra (EA DCA tự chặn add) | `max_dca_adds_reached` |
| `max_virtual_exposure` | exposure tối đa; 0 = tắt | `max_virtual_exposure_reached` |
| `max_daily_loss_pct` | lỗ trong ngày theo equity đầu ngày; 0 = tắt | `daily_loss_limit_reached` |
| `max_drawdown_pct` | drawdown từ peak equity; 0 = tắt | `max_drawdown_reached` |
| `cooldown_bars` | số bar tối thiểu giữa hai entry | `cooldown_active` |
| `require_valid_price` | bắt buộc giá hợp lệ | `price_invalid` |
| `kill_switch` | chặn mọi entry | `kill_switch_active` |
| `halt_on_breach` | vi phạm cap thường → `HALTED` thay vì `BLOCKED` | — |

Thứ tự kiểm tra trong `Evaluate`:

1. Guard chưa init / kill switch / đang `HALTED` → giữ nguyên lý do halt.
2. `price_invalid`.
3. Daily loss và drawdown trên equity mô phỏng → **luôn `HALTED`**; equity đầu ngày hoặc peak <= 0
   → `day_start_equity_invalid` / `peak_equity_invalid`.
4. Spread.
5. Cooldown (chỉ khi đã có entry trước đó; `bar_time` lùi → coi như còn cooldown).
6. Số vị thế, số tầng, số lần DCA (chặn tại biên: `open >= max`).
7. Exposure: chặn khi `exposure + volume_to_add > max`; bằng đúng cap được phép.

Chính sách trạng thái:

- `ACTIVE` → entry được phép.
- `BLOCKED` → chỉ entry hiện tại bị chặn; guard vẫn `ACTIVE` để entry sau còn cơ hội.
- `HALTED` → chặn mọi entry tiếp theo cho đến khi gọi `Reset()`; không tự reset khi giá/equity hồi phục.
- `SetKillSwitch(false)` **không** tự resume guard đã halt; phải `Reset()` tường minh.
- `max_dca_adds = 0` tắt kiểm tra DCA ở guard (EA không dùng DCA); EA DCA phải tự chặn add khi input
  của nó bằng 0.
- `Reset()` xóa state, cooldown và bộ đếm; không đổi limits.

`Fingerprint()` gộp toàn bộ limits + `timeframe_seconds` để đưa vào config hash của EA.

### 7. Trailing (W3)

`SimTrailingEvaluate` là hàm thuần: caller truyền `side`, `entry`, `old_sl`, `price`, `distance`,
`breakeven_trigger`, `breakeven_offset`, `min_stop`. Không đọc indicator, không đọc tài khoản.

- RAW: LONG `price - distance`, SHORT `price + distance`; lưu vào `raw_candidate`.
- Breakeven chỉ bật khi `breakeven_trigger > 0` và profit (`price - entry` / `entry - price`) đạt trigger:
  LONG `candidate = max(candidate, entry + offset)`, SHORT `candidate = min(candidate, entry - offset)`.
- Từ chối `candidate_too_close` khi LONG `candidate > price - min_stop`, SHORT `candidate < price + min_stop`.
- Từ chối `not_improving` khi LONG `candidate <= old_sl`, SHORT `candidate >= old_sl`.
- Input không hợp lệ (side NONE, giá/distance <= 0, trigger/offset/min_stop âm) → `invalid_inputs`,
  `candidate_sl` giữ nguyên `old_sl`.

Hệ quả: SL long không bao giờ giảm, SL short không bao giờ tăng; breakeven chỉ kéo SL về phía entry và
không vượt quá `entry ± offset`.

Helper stop: long kích hoạt khi `bid <= sl`, short khi `ask >= sl`; fill là giá tệ hơn giữa SL và thị trường
(`min(bid, sl)` / `max(ask, sl)`), sau đó `FillPrice` cộng slippage bất lợi. Lệch quá nửa point được ghi
reason `SL_GAP|gap_points=...`.

Vector T1–T15 (BUY entry 1.1, SL 1.095, distance 0.004, trigger 0): giá 1.11 → 1.106; `old_sl` 1.107 →
`not_improving` và giữ 1.107; distance 0.0001 → `candidate_too_close`; trigger 0.01 → clamp 1.1; offset
0.001 → 1.101; SHORT entry 1.2, SL 1.205, giá 1.17, trigger 0.02 → clamp 1.2; gap long 1.09 và short 1.21
được phát hiện.

### 8. Grid (W4)

`SimGridPlanAdd(next_level, max_levels, base_volume, multiplier, max_level_volume, exposure, max_exposure)`
trả `allowed`, `volume`, `reason`; thứ tự kiểm tra:

1. `next_level < 1` → `grid_level_invalid`; `max_levels < 1` hoặc `next_level > max_levels` →
   `max_grid_levels_reached`.
2. base/multiplier/max_level_volume không hợp lệ (base <= 0, multiplier < 1, max level volume <= 0) →
   `grid_volume_invalid`.
3. `volume = min(base * multiplier^(level-1), max_level_volume)`.
4. exposure âm → `exposure_invalid`; cap <= 0 → `max_virtual_exposure_invalid`;
   `exposure + volume > max_exposure` → `max_virtual_exposure_reached` (chặn, **không** chia nhỏ volume).

Giá và trigger:

- `SimGridLevelPrice(side, anchor, spacing, level)`: BUY `anchor - spacing*level`, SELL `anchor + spacing*level`.
- `SimGridNextLevelPrice` = level 1 so với entry gần nhất.
- `SimGridTriggered`: BUY khi `bid <= last_entry - spacing`; SELL khi `ask >= last_entry + spacing`.
- `SimGridTargetHit` / `SimGridStopHit`: khoảng cách từ average entry; BUY dùng bid, SELL dùng ask.

Vector G1–G12: base 0.1, multiplier 2 → level 1 = 0.1, level 3 = 0.4; `max_level_volume=0.5` clamp level 4
về 0.5; exposure `0.9 + 0.1 = 1.0` được phép, `0.95 + 0.1` bị chặn; multiplier 0.5 → `grid_volume_invalid`;
BUY last 1.1 spacing 0.01 → 1.09 (trigger tại 1.09, không tại 1.0901); SELL → 1.11; target/stop biên
1.07/1.03 (BUY) và 1.03/1.07 (SELL); spacing 0 → không trigger và giá 0.

### 9. DCA (W5)

`SimDcaPlanAdd(dca_adds, max_dca_adds, base_volume, multiplier, max_add_volume, exposure, max_exposure)`
trả `allowed`, `volume`, `add_index`, `reason`; thứ tự kiểm tra:

1. `max_dca_adds < 0` → `max_dca_adds_invalid`; `dca_adds < 0` → `dca_adds_invalid`.
2. `dca_adds >= max_dca_adds` → `max_dca_adds_reached`; do đó `max_dca_adds = 0` chặn mọi add.
3. base/multiplier/max_add_volume không hợp lệ (base <= 0, multiplier < 1, max add volume <= 0) →
   `dca_volume_invalid`.
4. `volume = min(base * multiplier^add_index, max_add_volume)` với `add_index = dca_adds + 1`.
   Vị thế đầu không tính là add và luôn dùng `base`.
5. exposure âm → `exposure_invalid`; cap <= 0 → `max_virtual_exposure_invalid`;
   `exposure + volume > max_exposure` → `max_virtual_exposure_reached` (chặn, **không** chia nhỏ volume).

Trigger:

- `SimDcaPriceTriggered(side, last_entry, distance, bid, ask)`: BUY `bid <= last_entry - distance`;
  SELL `ask >= last_entry + distance`.
- `SimDcaBarTriggered(last_add_bar, bar_time, bars_between_adds, timeframe_seconds)`: cần
  `bar_time - last_add_bar >= bars * timeframe_seconds`; bar hiện tại hoặc bar lùi trả `false`.
- `SimDcaBarsSince` chỉ dùng để log; `SimDcaAddVolume` là công thức volume thuần.
- Target/stop basket dùng chung `SimGridTargetHit` / `SimGridStopHit` (vector G10–G12).

Vector D1–D19: base 0.1, multiplier 1.5 → add 1 = 0.15, add 3 = 0.3375; base 0.1, multiplier 2,
`max_add_volume = 0.15` clamp add 2 về 0.15; `max_dca_adds = 0` và `max_dca_adds = 1` với
`dca_adds = 1` đều trả `max_dca_adds_reached`; exposure `1.9 + 0.1 = 2.0` được phép,
`1.95 + 0.1` bị chặn; multiplier 0.5 → `dca_volume_invalid`; BUY last 1.1 distance 0.01 trigger tại
1.09 (không tại 1.0901), SELL tại 1.11; 3 bar H1 cần 10,800 giây. Basket average `1.082`
(0.10 @ 1.1000 + 0.15 @ 1.0700): đóng tại 1.112 → `+0.0075`, tại 1.032 → `-0.0125`; commission
0.5/volume → realized `-0.2425`.

### 10. Logger schema

Header cố định 18 cột (`SIM_LOG_HEADER`):

```text
logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,
price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason
```

- File mở bằng `FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI`, ghi header khi file rỗng, mỗi record một dòng
  `\r\n`, flush sau mỗi lần ghi.
- Định dạng: giá `%.8f`, volume/exposure/drawdown `%.4f`, equity `%.2f`, thời gian
  `yyyy.mm.dd hh:mi:ss`.
- `reason` không chứa dấu phẩy; dùng token hoa có gạch dưới (`MAX_LEVELS_REACHED`, `SPREAD_EXCEEDED`).
- Không ghi account, broker, credential hay bất kỳ định danh phiên.

### 11. Config fingerprint

FNV-1a 32-bit trên chuỗi canonical, in hex 8 ký tự hoa:

| Input | Hash |
|---|---|
| `abc` | `1A47E90B` |
| chuỗi rỗng | `811C9DC5` |
| `levels=3;` | theo `SimFormatFingerprintPartInt` |
| `mult=1.50;` | theo `SimFormatFingerprintPart("mult",1.5,2)` |

Helper chỉ dùng để nhận diện cấu hình, **không** dùng cho mục đích bảo mật.

### 12. Cách build và chạy

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Scripts\SimCoreTests.mq5" `
  /log:"D:\Applications\tm-fx\reports\build\SimCoreTests.log"
```

Đọc log UTF-16, dòng cuối phải là `Result: 0 errors, 0 warnings`. CLI có thể trả exit code 1 dù compile
thành công, nên log là nguồn xác nhận.

Chạy test vector: trong MT5 mở Scripts → `SimCoreTests` trên chart bất kỳ, xem tab Experts. Kết quả đúng:

```text
TEST|BEGIN|suite=sim_core|version=1.00
TEST|P1|PASS
...
TEST|RESULT|ALL_PASS|pass=123 fail=0|suite=sim_core
```

Nếu thiếu dòng `TEST|RESULT|ALL_PASS` → coi như `NOT_RUN`, không suy luận là pass.

### 13. Trạng thái thật

| Hạng mục | Trạng thái |
|---|---|
| Compile `SimCoreTests.mq5` | PASS — 0 errors, 0 warnings; `SimCoreTests.ex5` 73,646 bytes (byte size depends on the MetaEditor build; the log is authoritative) |
| Chạy test vector trong MT5 | **PASS** — `TEST|RESULT|ALL_PASS|pass=123 fail=0|suite=sim_core` ngày 2026-10-28 18:36 |
| Kiểm tra CSV logger trên file thật | PASS — CSV 18 cột của `WonderwhalesSimEA` (3 scenario) và `RunnerTrailingLabEA`/`GridLabEA`/`DCALabEA` (10 scenario) ngày 2026-10-28 |
| EA sử dụng core | `RunnerTrailingLabEA` 3/3, `GridLabEA` 3/3, `DCALabEA` 4/4 scenario chạy thật; `WonderwhalesSimEA` 3/3; `PinePlanSimEA` `BLOCKED_PERFORMANCE` (full kỳ không xong, diagnostic 1 tháng 0 entry) |

## RunnerTrailingLabEA (simulation-only, W3)

- **Mục tiêu:** nghiên cứu hành vi một vị thế ảo duy nhất khi giữ lệnh theo xu hướng và nâng SL theo
  breakeven + trailing, dùng nền tảng `mt5/Include/Sim/` của W1–W3.
- **Trạng thái:** compile `0 errors, 0 warnings`; chưa chạy trong MT5 (`NOT_RUN`).
- **Nguồn lộ trình:** [`MASTER_ROADMAP.md`](../MASTER_ROADMAP.md) mục W3; đặc tả:
  [`MT5_AI_Roadmaps/STRATEGY_SPEC_GRID_DCA_TRAILING.md`](../MT5_AI_Roadmaps/STRATEGY_SPEC_GRID_DCA_TRAILING.md)
  mục C.

### 1. An toàn

- Không có `OrderSend`, `OrderSendAsync`, `CTrade`, `MqlTradeRequest`, `PositionOpen/Close/Modify`.
  Chỉ mở/đóng vị thế ảo trong `CSimPortfolio` (bộ nhớ).
- Không đọc account, không kết nối broker, không lưu credential. Log đi vào `MQL5/Files`.
- `OnInit` fail-closed: input sai → log token và trả `INIT_PARAMETERS_INCORRECT`; không tự sửa input.

### 2. Input chính

| Nhóm | Input | Ý nghĩa |
|---|---|---|
| Simulation | `InpInitialBalance`, `InpVolume` | balance ảo, volume mỗi entry |
| Simulation | `InpEnableLog`, `InpLogFile`, `InpDebug` | logger CSV và debug print |
| Signal | `InpSideFilter` | `BOTH` / `LONG_ONLY` / `SHORT_ONLY` |
| Signal | `InpFastEma`, `InpSlowEma` | EMA trên bar đã đóng (bar 1 và bar 2) |
| Signal | `InpAtrPeriod` | ATR cho SL ban đầu và trailing ATR |
| Stops | `InpAtrSlMultiplier` | SL ban đầu = `ATR * multiplier` |
| Stops | `InpBreakEvenEnabled`, `InpBreakEvenTriggerPoints`, `InpBreakEvenOffsetPoints` | breakeven theo point lợi nhuận |
| Stops | `InpTrailMode` | `FIXED` hoặc `ATR` |
| Stops | `InpTrailFixedPoints`, `InpTrailAtrMultiplier` | khoảng trailing |
| Stops | `InpMinStopPoints` | SL candidate phải cách giá ít nhất bao nhiêu point |
| Stops | `InpUpdateOnClosedBarOnly` | chỉ cập nhật trailing khi sang bar mới |
| Stops | `InpMaxHoldingBars` | 0 = tắt; đóng theo giá thị trường khi đủ số bar |
| RiskGuard | `InpCooldownBars`, `InpMaxSpreadPoints`, `InpMaxVirtualExposure` | cooldown, spread, exposure |
| RiskGuard | `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpHaltOnBreach` | hard cap theo equity ảo |
| Costs | `InpCommissionPerVolume`, `InpSlippagePoints` | giả định chi phí, áp dụng mọi fill |

Preset mẫu: [`configs/sim/runner_trailing.json`](../../configs/sim/runner_trailing.json).

### 3. Luật chạy

1. Mỗi tick: cập nhật mid, equity đầu ngày, phát hiện bar mới.
2. Đang có vị thế: kiểm tra stop trước (long theo bid, short theo ask). Nếu gap qua SL, fill ở giá thị
   trường tệ hơn + slippage và reason `SL_GAP|gap_points=...`.
3. Nếu đang có vị thế và `InpMaxHoldingBars > 0`, đủ số bar kể từ bar entry → đóng tại `bid`/`ask` với
   reason `MAX_HOLDING_BARS`.
4. Cập nhật trailing qua `SimTrailingEvaluate`; chỉ nhận candidate cải thiện (long `>=`, short `<=`).
5. Không có vị thế và có bar mới: EMA cross bar 1 vs bar 2 tạo tín hiệu; áp `InpSideFilter`; hỏi
   `CSimRiskGuard`; fill bất lợi qua `CSimCostModel`; mở vị thế ảo với SL = ATR × multiplier.

### 4. Bất biến

- Tối đa một vị thế ảo; không mở thêm khi đang có lệnh.
- Long: SL mới không bao giờ thấp hơn SL cũ. Short: SL mới không bao giờ cao hơn SL cũ.
- Breakeven chỉ kéo SL về phía entry, không vượt quá `entry ± offset`; trigger 0 = tắt.
- Candidate quá gần giá (< `InpMinStopPoints`) bị từ chối với `candidate_too_close`.
- RiskGuard halt (daily loss/drawdown) chặn mọi entry cho tới khi EA khởi động lại; cap thường chỉ chặn
  một lần trừ khi `halt_on_breach=true`.
- Không mở vị thế mới ngay trên bar vừa đóng lệnh (`g_last_exit_bar`).

### 5. Log event

Schema 18 cột dùng chung mục **Simulation core** ở đầu tài liệu này. Event của runner:

| Event | Khi nào | Reason |
|---|---|---|
| `INIT` | `OnInit` thành công | `SIMULATION_ONLY\|config_hash=...` |
| `ENTRY` | mở vị thế ảo | `SIGNAL_EMA_CROSS\|risk=...\|spread_points=...` |
| `RISK` | tín hiệu bị chặn | `ENTRY_BLOCKED\|reason=...\|state=...`, `side_filter`, `atr_invalid`, `sl_invalid` |
| `TRAIL` | chấp nhận/nhận từ chối trên bar mới | `TRAIL_ACCEPTED\|old_sl=...\|candidate_sl=...`, `TRAIL_REJECTED\|reason=...` |
| `EXIT` | stop, max holding hoặc đóng | `SL_HIT`, `SL_GAP\|gap_points=...`, `MAX_HOLDING_BARS` + `bars=`, `pnl=`, `commission=` |
| `SUMMARY` | `OnDeinit` | `trades=...\|wins=...\|losses=...\|flats=...\|net=...` |

### 6. Build và chạy tay

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Experts\RunnerTrailingLabEA.mq5" `
  /log:"D:\Applications\tm-fx\reports\build\RunnerTrailingLabEA.log"
```

Đọc log UTF-16; dòng cuối phải là `Result: 0 errors, 0 warnings`. Chạy trong Strategy Tester (mode
"Every tick" hoặc "1 minute OHLC") trên symbol/timeframe bất kỳ, xem tab Experts và file CSV trong
`MQL5/Files`. Preset khởi điểm: `configs/sim/runner_trailing.json`.

### 7. Trạng thái thật

| Hạng mục | Trạng thái |
|---|---|
| Compile | PASS — 0 errors, 0 warnings; `RunnerTrailingLabEA.ex5` 52,622 bytes (byte size depends on the MetaEditor build) |
| Chạy trong MT5 | **PASS** — 3/3 scenario `runner_baseline`, `runner_conservative_stress`, `runner_edge_no_breakeven` ngày 2026-10-28; cả ba `HALTED` bởi RiskGuard |
| CSV thực tế | `reports/build/tester-reports/runner_*/` (54 / 36 / 70 trade) |
| So khớp với Python trailing simulator | Chưa làm — khác mô hình (Python dùng bar OHLC, EA dùng tick + EMA cross) |

### 8. Giới hạn đã biết

- Tín hiệu EMA cross chỉ để tạo luồng entry cho nghiên cứu trailing, không phải chiến lược đã tối ưu.
- SL ban đầu theo ATR; đặc tả cũng cho phép `InpInitialStopPoints`, biến thể đó chưa triển khai.
- Không mô phỏng partial fill, latency, requote, spread biến thiên; swap chưa dùng cho runner.
- Kết quả backtest không phải cam kết lợi nhuận; contract size = 1 là giả định mô phỏng.

## GridLabEA (simulation-only, W4)

- **Mục tiêu:** nghiên cứu lưới vị thế ảo có giới hạn cứng: số tầng, volume mỗi tầng và tổng exposure.
  Không mô phỏng lưới vô hạn, không gồng không giới hạn.
- **Trạng thái:** compile `0 errors, 0 warnings`; chưa chạy trong MT5 (`NOT_RUN`).
- **Nguồn lộ trình:** [`MASTER_ROADMAP.md`](../MASTER_ROADMAP.md) mục W4; đặc tả:
  [`MT5_AI_Roadmaps/STRATEGY_SPEC_GRID_DCA_TRAILING.md`](../MT5_AI_Roadmaps/STRATEGY_SPEC_GRID_DCA_TRAILING.md)
  mục A.

### 1. An toàn

- Không có `OrderSend`, `OrderSendAsync`, `CTrade`, `MqlTradeRequest`, `PositionOpen/Close/Modify`.
  Mọi tầng là vị thế ảo trong `CSimPortfolio`.
- Không đọc account, không kết nối broker, không lưu credential.
- `OnInit` fail-closed: input sai → log token + `INIT_PARAMETERS_INCORRECT`.
- `InpBasketStopPoints` bắt buộc > 0: không có cấu hình "gồng vô hạn".

### 2. Input chính

| Nhóm | Input | Ý nghĩa |
|---|---|---|
| Simulation | `InpInitialBalance`, `InpEnableLog`, `InpLogFile`, `InpDebug` | balance ảo và logger |
| Grid | `InpGridSide` | `GRID_LONG` / `GRID_SHORT`, một chiều cho cả basket |
| Grid | `InpSpacingMode` | `SIM_GRID_FIXED_POINTS` / `SIM_GRID_ATR_MULTIPLE` |
| Grid | `InpSpacingPoints` | khoảng cách tầng khi fixed |
| Grid | `InpAtrPeriod`, `InpAtrMultiplier` | khoảng cách tầng khi ATR |
| Grid | `InpMaxGridLevels` | tổng số tầng tối đa, gồm tầng đầu |
| Grid | `InpBaseVirtualVolume`, `InpVolumeMultiplier`, `InpMaxLevelVolume` | volume từng tầng và cap |
| Exit | `InpExitMode` | `GRID_EXIT_LEVEL` / `GRID_EXIT_BASKET` |
| Exit | `InpLevelTargetPoints` | chốt từng tầng khi lãi đủ điểm (LEVEL) |
| Exit | `InpBasketTargetPoints` | chốt cả basket theo giá vốn (BASKET) |
| Exit | `InpBasketStopPoints` | stop cả basket theo giá vốn, bắt buộc > 0 |
| RiskGuard | spread, exposure, daily loss, drawdown, halt policy | hard cap dùng chung |
| Costs | `InpCommissionPerVolume`, `InpSlippagePoints` | chi phí mô phỏng |

Preset mẫu: [`configs/sim/grid_lab.json`](../../configs/sim/grid_lab.json).

### 3. Luật chạy

1. Mỗi tick: cập nhật mid, equity đầu ngày, phát hiện bar mới, đọc spacing (fixed hoặc ATR bar 1).
2. Đang có basket: kiểm tra **basket stop** trước; nếu chạm, đóng toàn bộ tại giá thị trường bất lợi +
   slippage. Sau đó (BASKET mode) kiểm tra target theo giá vốn; (LEVEL mode) chốt các tầng đã đủ lãi.
3. Nếu còn vị thế và có spacing: xét thêm tầng. Một tick có thể thêm nhiều tầng nếu giá gap qua nhiều
   khoảng, nhưng vòng lặp bị chặn bởi `InpMaxGridLevels`, `InpMaxLevelVolume`, `InpMaxVirtualExposure`.
4. Không có vị thế và có bar mới: mở tầng 1 nếu RiskGuard cho phép; không mở lại trên đúng bar vừa đóng
   basket (`g_last_exit_bar`).

### 4. Công thức và cap

- Khoảng cách: `fixed = InpSpacingPoints * point`; `atr = ATR(bar 1) * InpAtrMultiplier`.
- Tầng tiếp theo: BUY `last_entry - spacing`, SELL `last_entry + spacing`, trong đó `last_entry` là entry
  thấp nhất (BUY) hoặc cao nhất (SELL) đang mở — sau khi chốt bớt tầng vẫn đúng.
- Volume tầng `n`: `base * multiplier^(n-1)`, sau đó `min(volume, InpMaxLevelVolume)`.
- Thêm tầng bị **chặn hoàn toàn** (không chia nhỏ) nếu `exposure + volume > InpMaxVirtualExposure`;
  reason `max_virtual_exposure_reached`.
- `n > InpMaxGridLevels` → `max_grid_levels_reached`, không mở.
- Guard dùng chung nhận `max_virtual_positions = max_grid_levels = InpMaxGridLevels` để không bao giờ
  vượt số tầng. Guard không tự nới cap.

Ví dụ G1–G7 (unit test): base 0.1, multiplier 2 → level 1 = 0.1, level 3 = 0.4; `max_level_volume=0.5`
clamp level 4 về 0.5; exposure 0.9 + 0.1 = 1.0 được phép, 0.95 + 0.1 bị chặn.

### 5. Exit

- **BASKET:** target/stop tính theo khoảng cách giá từ average entry (volume-weighted). Target mặc định
  600 point, stop 900 point.
- **LEVEL:** đóng các vị thế đã đạt `InpLevelTargetPoints` lãi trên mỗi volume; các tầng còn lại giữ
  nguyên và average entry được tính lại. Commission trừ theo volume của đúng các tầng đã đóng
  (`CSimPortfolio::CloseProfitableAtLeast`).
- Stop basket áp dụng cho cả hai mode; đây là chốt chặn cuối, không phụ thuộc target.
- Gap qua stop/target: fill ở giá thị trường hiện tại + slippage, không giả vờ khớp đúng mức.

### 6. Log event

Schema 18 cột dùng chung mục **Simulation core** ở đầu tài liệu này.

| Event | Reason |
|---|---|
| `INIT` | `SIMULATION_ONLY\|config_hash=...` |
| `ENTRY` | `GRID_ADD\|level=n\|trigger=...\|fill=...\|spacing=...` |
| `RISK` | `GRID_BLOCKED\|reason=...\|level=...\|state=...` (tối đa một lần/bar cho cap) |
| `EXIT` | `BASKET_TARGET`, `BASKET_STOP`, `LEVEL_TARGET\|closed=n` + `levels=`, `pnl=`, `commission=`, `realized=` |
| `SUMMARY` | `levels_opened=`, `closed=`, `baskets=`, `open=`, `realized=`, `max_dd=`, `blocks=`, `halted=` |

### 7. Build và chạy tay

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Experts\GridLabEA.mq5" `
  /log:"D:\Applications\tm-fx\reports\build\GridLabEA.log"
```

Dòng cuối log phải là `Result: 0 errors, 0 warnings`. Chạy Strategy Tester với preset
`configs/sim/grid_lab.json`, kiểm tra tab Experts và CSV `sim_grid_log.csv`.

### 8. Trạng thái thật

| Hạng mục | Trạng thái |
|---|---|
| Compile | PASS — 0 errors, 0 warnings; `GridLabEA.ex5` 51,590 bytes (byte size depends on the MetaEditor build) |
| Chạy trong MT5 | **PASS** — 3/3 scenario `grid_*` ngày 2026-10-28; baseline/stress `ACTIVE`, edge `HALTED` |
| CSV thực tế | `reports/build/tester-reports/grid_*/` |
| So khớp Python bounded-basket simulator | Chưa làm; mô hình Python dùng bar OHLC, EA dùng tick |

### 9. Giới hạn đã biết

- Không có tín hiệu vào lệnh: tầng 1 mở theo chiều `InpGridSide` ở bar mới đầu tiên khi guard cho phép.
  Đây là công cụ nghiên cứu cấu trúc lưới, không phải chiến lược hoàn chỉnh.
- LEVEL mode không đặt TP riêng trong portfolio; nó đóng theo ngưỡng lãi tại thời điểm tick.
- Không mô phỏng partial fill, requote, spread biến thiên, swap; contract size = 1 là giả định.
- Kết quả không phải cam kết lợi nhuận; grid có thể lỗ lớn khi xu hướng một chiều dù có cap.

## DCALabEA (simulation-only, W5)

- **Mục tiêu:** nghiên cứu các lần bổ sung vị thế ảo theo khoảng giá hoặc khoảng thời gian, với giới hạn
  cứng về số lần add, volume mỗi lần và tổng exposure. Không bình quân vô hạn.
- **Trạng thái:** compile `0 errors, 0 warnings`; chưa chạy trong MT5 (`NOT_RUN`).
- **Nguồn lộ trình:** [`MASTER_ROADMAP.md`](../MASTER_ROADMAP.md) mục W5; đặc tả:
  [`MT5_AI_Roadmaps/STRATEGY_SPEC_GRID_DCA_TRAILING.md`](../MT5_AI_Roadmaps/STRATEGY_SPEC_GRID_DCA_TRAILING.md)
  mục B.

### 1. An toàn

- Không có `OrderSend`, `OrderSendAsync`, `CTrade`, `MqlTradeRequest`, `PositionOpen/Close/Modify`.
  Vị thế đầu và mọi lần add là vị thế ảo trong `CSimPortfolio`.
- Không đọc account, không kết nối broker, không lưu credential.
- `OnInit` fail-closed: input sai → log token + `INIT_PARAMETERS_INCORRECT`.
- `InpMaxDcaAdds = 0` nghĩa là **không add lần nào**, không phải vô hạn.
- `InpBasketStopPoints` bắt buộc > 0: không có cấu hình "gồng vô hạn".

### 2. Input chính

| Nhóm | Input | Ý nghĩa |
|---|---|---|
| Simulation | `InpInitialBalance`, `InpEnableLog`, `InpLogFile`, `InpDebug` | balance ảo và logger |
| DCA | `InpDcaSide` | `DCA_LONG` / `DCA_SHORT`, một chiều cho cả basket |
| DCA | `InpBaseVirtualVolume` | volume vị thế đầu |
| DCA | `InpTriggerMode` | `SIM_DCA_PRICE_DISTANCE` / `SIM_DCA_BAR_INTERVAL` |
| DCA | `InpDcaDistancePoints` | khoảng giá tối thiểu từ lần fill cuối (price mode) |
| DCA | `InpBarsBetweenAdds` | số bar tối thiểu giữa hai lần fill (bar mode), >= 1 |
| DCA | `InpMaxDcaAdds` | số lần add tối đa, `0` = không add |
| DCA | `InpAddVolumeMultiplier`, `InpMaxAddVolume` | volume từng lần add và cap |
| Exit | `InpBasketTargetPoints` | chốt cả basket theo giá vốn, bắt buộc > 0 |
| Exit | `InpBasketStopPoints` | stop cả basket theo giá vốn, bắt buộc > 0 |
| RiskGuard | spread, exposure, daily loss, drawdown, halt policy | hard cap dùng chung |
| Costs | `InpCommissionPerVolume`, `InpSlippagePoints` | chi phí mô phỏng |

Preset mẫu: [`configs/sim/dca_lab.json`](../../configs/sim/dca_lab.json).

### 3. Luật chạy

1. Mỗi tick: cập nhật mid, equity đầu ngày, phát hiện bar mới.
2. Đang có basket: kiểm tra **basket stop** trước, rồi **basket target**, tính từ average entry; chạm thì
   đóng toàn bộ tại giá thị trường hiện tại + slippage.
3. Nếu còn vị thế: xét tối đa **một lần add mỗi bar** (tick burst không thể add nhiều lần trong cùng bar).
4. Không có vị thế và có bar mới: mở vị thế đầu nếu RiskGuard cho phép; không mở lại trên đúng bar vừa
   đóng basket (`g_last_exit_bar`).
5. Không có tín hiệu vào lệnh: vị thế đầu mở theo `InpDcaSide` — đây là công cụ nghiên cứu cấu trúc DCA.

### 4. Trigger và cap

- **Price mode:** BUY add khi `bid <= last_fill - distance`; SELL add khi `ask >= last_fill + distance`.
  `last_fill` là entry thấp nhất (BUY) / cao nhất (SELL) đang mở.
- **Bar mode:** add khi `bar_time - last_fill_bar >= InpBarsBetweenAdds` bar đầy đủ; bar hiện tại hoặc
  bar lùi không bao giờ trigger.
- Volume lần add thứ `n`: `base * multiplier^n`, sau đó `min(volume, InpMaxAddVolume)`.
  Vị thế đầu luôn dùng `base`, không tính là một lần add.
- `n > InpMaxDcaAdds` → `max_dca_adds_reached`, không add.
- Add bị **chặn hoàn toàn** (không chia nhỏ) nếu `exposure + volume > InpMaxVirtualExposure`;
  reason `max_virtual_exposure_reached`.
- Guard dùng chung nhận `max_dca_adds = InpMaxDcaAdds`, `max_virtual_positions = InpMaxDcaAdds + 1`,
  `max_grid_levels = 0`. Guard không tự nới cap; dai lỗ/drawdown vẫn luôn `HALTED`.

Ví dụ D1–D10 (unit test): base 0.1, multiplier 1.5 → add 1 = 0.15, add 3 = 0.3375; base 0.1,
multiplier 2, `max_add_volume = 0.15` clamp add 2 về 0.15; exposure 1.9 + 0.1 = 2.0 được phép,
1.95 + 0.1 bị chặn; `max_dca_adds = 0` chặn ngay cả khi chưa add lần nào.

### 5. Exit và P&L basket

- Target/stop tính theo khoảng cách giá từ average entry (volume-weighted), dùng chung hình học với grid
  (`SimGridTargetHit` / `SimGridStopHit`, vector G10–G12).
- Stop được kiểm tra trước target, nên một bar chạm cả hai không thể được tính theo hướng có lợi.
- Gap qua stop/target: fill ở giá thị trường hiện tại + slippage, không giả vờ khớp đúng mức.
- Cross-check D16–D19: BUY 0.10 @ 1.1000 + 0.15 @ 1.0700 → average 1.082, exposure 0.25.
  Đóng tại 1.112 → `realized_delta = +0.0075`; đóng tại 1.032 → `-0.0125`. Với commission
  commission 0.5/volume, đóng tại 1.112 → realized `-0.2425` (0.125 entry + 0.125 exit − 0.0075 gross).
  Cùng con số được tính độc lập bằng Python trong `python/tests/test_dca_vectors.py`.

### 6. Log event

Schema 18 cột dùng chung mục **Simulation core** ở đầu tài liệu này.

| Event | Reason |
|---|---|
| `INIT` | `SIMULATION_ONLY\|config_hash=...` |
| `ENTRY` | `DCA_ENTRY\|adds=0` hoặc `DCA_ADD\|add=n\|mode=...\|trigger=...\|bars_since=...\|distance=...` |
| `RISK` | `DCA_BLOCKED\|reason=...\|add=...\|mode=...` hoặc `...\|state=...` (tối đa một lần/bar cho cap) |
| `EXIT` | `BASKET_STOP` / `BASKET_TARGET` + `levels=`, `adds=`, `pnl=`, `commission=`, `realized=` |
| `SUMMARY` | `entries=`, `adds=`, `closed=`, `baskets=`, `open=`, `realized=`, `max_dd=`, `blocks=`, `halted=` |

### 7. Build và chạy tay

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Experts\DCALabEA.mq5" `
  /log:"D:\Applications\tm-fx\reports\build\DCALabEA.log"
```

Dòng cuối log phải là `Result: 0 errors, 0 warnings`. Chạy Strategy Tester với preset
`configs/sim/dca_lab.json`, kiểm tra tab Experts và CSV `sim_dca_log.csv`.

### 8. Trạng thái thật

| Hạng mục | Trạng thái |
|---|---|
| Compile | PASS — 0 errors, 0 warnings; `DCALabEA.ex5` 47,606 bytes (byte size depends on the MetaEditor build) |
| Chạy trong MT5 | **PASS** — 4/4 scenario `dca_*` ngày 2026-10-28; tất cả `HALTED` bởi RiskGuard; `SUMMARY adds=0` là lỗi báo cáo, CSV có 2 add ở `dca_baseline` |
| CSV thực tế | `reports/build/tester-reports/dca_*/` |
| Cross-check P&L Python | PASS — `python/tests/test_dca_vectors.py` (cùng vector D16–D19) |

### 9. Giới hạn đã biết

- Không có bộ lọc tín hiệu: vị thế đầu mở theo chiều input ở bar mới đầu tiên khi guard cho phép.
  Bộ lọc tín hiệu "chỉ để nghiên cứu" trong đặc tả chưa được thêm để cô lập hình học DCA.
- Không mô phỏng partial fill, requote, spread biến thiên, swap; contract size = 1 là giả định.
- Không có leverage/margin call; exposure là volume chuẩn hóa, không phải ký quỹ.
- Thêm vị thế khi giá đi ngược làm tăng rủi ro; cap chỉ giới hạn quy mô, không bảo đảm hòa vốn.
- Kết quả là mô phỏng, không phải cam kết lợi nhuận hay khuyến nghị giao dịch.

## Preset và validator fail-closed (W6)

- **Mục tiêu:** preset kiểm thử cho năm EA Track C và một cổng kiểm tra tĩnh từ chối cấu hình không phải
  mô phỏng hoặc có dấu hiệu tài khoản/broker trước khi nạp vào MT5.
- **Trạng thái:** validator exit 0 trên 6 file cấu hình (5 preset + project); pytest PASS; 13/15 scenario
  đã chạy thật, 2 scenario `plan_*` `BLOCKED_PERFORMANCE`.
- **Nguồn lộ trình:** [`MASTER_ROADMAP.md`](../MASTER_ROADMAP.md) mục W6.

### 1. File

| File | Nội dung |
|---|---|
| `configs/sim/runner_trailing.json` | Baseline `RunnerTrailingLabEA` |
| `configs/sim/grid_lab.json` | Baseline `GridLabEA` |
| `configs/sim/dca_lab.json` | Baseline `DCALabEA` |
| `configs/sim/pine_plan_lab.json` | Baseline `PinePlanSimEA` (nguồn Price Action MTF) |
| `configs/sim/wonderwhales_xauusdm.json` | Baseline `WonderwhalesSimEA` cho `XAUUSDm` |
| `configs/project.example.json` | Baseline + conservative stress + edge-case cho cả năm EA |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | Contract input từng EA, validate preset/project, snapshot |
| `scripts/validate_sim_configs.py` | CLI kiểm tra toàn bộ preset và scenario |
| `python/tests/test_sim_configs.py` | Test preset hợp lệ, fail-closed, cross-field, snapshot |

### 2. Schema preset

Mỗi preset là một JSON object với các trường bắt buộc:

| Trường | Ràng buộc |
|---|---|
| `schema_version` | `1` |
| `ea` | `RunnerTrailingLabEA`, `GridLabEA`, `DCALabEA`, `PinePlanSimEA` hoặc `WonderwhalesSimEA` |
| `version` | chuỗi khác rỗng |
| `execution_mode` | đúng `SIMULATION_ONLY` (phân biệt hoa thường) |
| `allow_live_trading` | `false` (boolean, không nhận `0`) |
| `inputs` | đúng bộ input của EA, không thiếu, không thừa |

Trường metadata được phép: `project`, `strategy`, `symbol`, `timeframe`, `description`, `enum_map`,
`assumptions`. `symbol`/`timeframe` chỉ là nhãn ngữ cảnh kiểm thử, **không** phải cấu hình broker và
không được EA đọc.

Mọi khóa khớp `login|password|passwd|investor|server|account|token|secret|credential|apikey|broker`
(ở top-level hoặc trong `inputs`) bị từ chối.

### 3. Kiểm tra giá trị

Validator phản chiếu `OnInit` của từng EA; EA vẫn là nguồn chân lý cuối cùng.

| EA | Cross-field bắt buộc |
|---|---|
| Runner | `InpSlowEma > InpFastEma`; breakeven bật → trigger > 0; trail fixed → fixed points > 0; trail ATR → ATR multiplier > 0; exposure ≥ volume |
| Grid | `InpMaxLevelVolume ≥ InpBaseVirtualVolume`; exposure ≥ base; fixed spacing > 0; ATR mode → period ≥ 2 và multiplier > 0; LEVEL mode → level target > 0; BASKET mode → basket target > 0; basket stop > 0 |
| DCA | `InpMaxAddVolume ≥ InpBaseVirtualVolume`; exposure ≥ base; price mode → distance > 0; bar mode → `InpBarsBetweenAdds ≥ 1`; `InpMaxDcaAdds` trong `[0, 1000]`; basket target/stop > 0 |
| PinePlan | exposure ≥ volume; breakeven bật → trigger > 0; trail bật → `InpTrailFixedPoints > 0` |
| Wonderwhales | `InpSlowEma > InpFastEma`; `InpEma200 > InpSlowEma`; `InpWarmupBars ≥ InpEma200`; `psar_start`/`psar_inc` ≤ `psar_max`; exposure ≥ volume |

Kiểm tra kiểu: boolean phải là boolean thật; enum phải là số nguyên trong tập cho phép; input số nguyên
không nhận `1.5`; volume/balance phải hữu hạn và dương; percent trong `[0, 100]`; commission/slippage ≥ 0.
`InpLogFile` không được chứa dấu phẩy vì reason/CSV dùng dấu phẩy làm phân cách.

### 4. Scenario

`configs/project.example.json` trỏ tới năm preset và định nghĩa 15 scenario. Override được merge lên
`inputs` của preset rồi validate lại toàn bộ, nên một override phá cap sẽ bị chặn.

| Scenario | EA | Mục đích |
|---|---|---|
| `runner_baseline` | Runner | cấu hình mặc định |
| `runner_conservative_stress` | Runner | volume/exposure một nửa, daily 1%, DD 2%, spread 20, cooldown 5 |
| `runner_edge_no_breakeven` | Runner | tắt breakeven, max holding 10 bar |
| `grid_baseline` | Grid | cấu hình mặc định |
| `grid_conservative_stress` | Grid | 3 tầng, base 0.05, exposure 0.4, daily 1%, DD 2% |
| `grid_edge_single_level` | Grid | 1 tầng (không add) |
| `dca_baseline` | DCA | cấu hình mặc định |
| `dca_conservative_stress` | DCA | 2 lần add, multiplier 1.2, exposure 0.3, target/stop 300/400 |
| `dca_edge_no_adds` | DCA | `InpMaxDcaAdds = 0` |
| `dca_edge_bar_trigger` | DCA | trigger theo bar, 10 bar giữa hai lần add |
| `plan_baseline` | PinePlan | nguồn Price Action MTF, TP1, filter hai chiều |
| `plan_edge_tp3_stop_only` | PinePlan | TP3, min stop/target 20 point, spread cap 20 |
| `ww_baseline` | Wonderwhales | cấu hình mặc định trên `XAUUSDm`, PSAR stop, exit on flip |
| `ww_conservative_stress` | Wonderwhales | volume/exposure 0.05, spread 100, daily 1%, DD 2%, cooldown 5, min stop 200 |
| `ww_edge_atr_stop` | Wonderwhales | ATR% stop ×3, tắt exit-on-flip, max holding 16 bar |

Đây là cấu hình kiểm thử, không phải khuyến nghị giao dịch.

### 5. Snapshot

- Mỗi cấu hình hợp lệ được ghi một lần vào `reports/config-snapshots/`.
- Tên file `<ea|project>-<FNV1a32>.json`; hash tính trên JSON canonical (sort key, không khoảng trắng).
- Nếu file đã tồn tại, validator **không ghi đè** và in `unchanged`.
- Snapshot chứa đúng nội dung cấu hình đã validate, không chứa thời gian chạy, account hay đường dẫn tuyệt đối.

### 6. Cách chạy

```powershell
D:\Applications\tm-fx\.venv\Scripts\python.exe scripts\validate_sim_configs.py
```

```text
PASS: dca_lab.json (ea=DCALabEA)
  snapshot: reports\config-snapshots\DCALabEA-2CF1CD9A.json (unchanged)
...
SUMMARY: checked=6 fail=0
```

Exit code: `0` tất cả pass, `1` có lỗi validate, `2` thiếu project root hoặc `configs/sim`.
`--no-snapshot` chỉ validate; `--root` và `--snapshot-dir` để chạy ngoài repo.

### 7. Trạng thái thật

| Hạng mục | Trạng thái |
|---|---|
| Validator trên 5 preset + project | PASS — `checked=6 fail=0` (presets=5, scenarios=15) |
| Snapshot | PASS — 6 file, chạy lại `unchanged` |
| pytest toàn bộ | PASS — xem số test trong [`PROGRESS.md`](../PROGRESS.md) |
| Nạp preset vào EA trong MT5 | PASS — toàn bộ 12 `sim_*` `.set` nạp headless qua `MQL5\Profiles\Tester` ngày 2026-10-28 |
| Strategy Tester | PASS 13/15 scenario — `ww_*` 3/3, `runner_*` 3/3, `grid_*` 3/3, `dca_*` 4/4; `plan_*` 2 `BLOCKED_PERFORMANCE` (mục 9.2 của guide) |

### 8. Giới hạn

- Validator là pre-flight tĩnh: không compile MQL5, không mở terminal, không chứng minh EA chạy đúng.
- Không kiểm tra kiểu dữ liệu thực tế khi dán tay vào tab Inputs của MT5; EA vẫn fail-closed tại `OnInit`.
- `symbol`/`timeframe` không được đối chiếu với chart đang chạy.
- Không có suy luận kết quả backtest từ cấu hình; mọi con số hiệu năng phải đến từ lần chạy thật.

## PinePlanSimEA — EA mô phỏng theo trade plan (W10)

- **Mục tiêu:** một EA mô phỏng duy nhất đọc **trade plan** của ba indicator PinePort
  (`PriceActionMTF`, `TMXAUSignals2`, `TMIndicator2`) và mở một vị thế ảo cho mỗi tín hiệu biên hợp lệ.
- **Trạng thái:** compile `0 errors, 0 warnings`; `SimPlanTests` **PASS runtime 39/0** (MT5, 2026-10-28);
  Strategy Tester `BLOCKED_PERFORMANCE` — full kỳ 9 tháng không xong sau ~13 phút do PriceActionMTF
  tính lại quá đắt; diagnostic 1 tháng xong 197 s với `entries=0`. Preset kiểm tra fail-closed PASS.
- **Nguồn lộ trình:** [`MASTER_ROADMAP.md`](../MASTER_ROADMAP.md) mục W10.

### 1. Vì sao chỉ ba nguồn

Ba indicator này cùng xuất một **plan tĩnh trên nến đã đóng**: `PLAN_VALID`, `DIR`, `ENTRY`, `SL`,
`TP1..3` và tín hiệu biên. Nhờ vậy EA chỉ cần một luật vào lệnh và một luật thoát.

Không đưa vào W10:

- **LongKaco VSA** dùng máy trạng thái `FILL`/`RESULT` (fill theo giá, không phải plan tĩnh).
- **TM Fusion Zones** dùng trạng thái `POS_SIDE`/adoption của vị thế trên chart.

Port hai nguồn này cần mô hình trạng thái riêng; gộp vào một EA plan chung sẽ tạo kết quả sai.

### 2. File

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimPlan.mqh` | `SimPlan`, `SimPlanResolveSide`, `SimPlanValidate`, chọn/hit/fill target — thuần, không indicator |
| `mt5/Experts/PinePlanSimEA.mq5` | Đọc buffer qua `iCustom`, vị thế ảo, RiskGuard, breakeven/trailing tùy chọn, CSV |
| `mt5/Scripts/SimPlanTests.mq5` | 39 vector: 7 resolve side, 19 validate, 13 target |
| `configs/sim/pine_plan_lab.json` | Preset baseline, `SIMULATION_ONLY`, `allow_live_trading=false` |
| `python/tests/test_plan_sim_source.py` | Test tĩnh: input ↔ schema, include, buffer constant, purity, marker suite |

Không có `OrderSend`, `CTrade`, `MqlTradeRequest` hay bất kỳ API position/order nào.

### 3. Buffer map

EA gọi `iCustom(_Symbol,_Period,"PinePort\\"+SourceName())` **không truyền input** (dùng default của
indicator) và đọc nến `shift=1` (nến đã đóng).

| Nguồn | `DIR` | `PLAN_VALID` | `ENTRY` | `SL` | `TP1` | `TP2` | `TP3` | Tín hiệu |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Price Action MTF | 13 | 17 | 18 | 19 | 20 | 21 | 22 | `SIG_LONG` 24, `SIG_SHORT` 25 |
| TM XAU Signals 2 | 14 | 28 | 29 | 30 | 31 | 32 | 33 | `SIG` 35 (một tín hiệu biên; side lấy từ `DIR`) |
| TM Indicator 2 | 20 | 42 | 45 | 47 | 48 | 49 | 50 | `SIGNAL` 59 (một tín hiệu biên; side lấy từ `DIR`) |

Quy ước tín hiệu:

- PA: `SIG_LONG==1` hoặc `SIG_SHORT==1`; cả hai cùng 1 là `ambiguous_signal`.
- X2/TM2: một buffer tín hiệu biên; `DIR` phải là `+1`/`-1` và khớp chiều.
- Chỉ xử lý khi có tín hiệu trên nến đã đóng; mỗi `bar_time` chỉ thử một lần
  (`g_last_signal_bar`).

### 4. Luật vào lệnh

Thứ tự kiểm tra và token ổn định (`SimPlanValidate`):

| # | Điều kiện | Token |
|---:|---|---|
| 1 | Không có tín hiệu | `no_signal` |
| 2 | `PLAN_VALID != 1` | `plan_invalid` |
| 3 | Side chưa xác định | `side_missing` |
| 4 | Bị filter long-only/short-only | `side_filtered` |
| 5 | `point` không hữu hạn hoặc ≤ 0 | `point_invalid` |
| 6 | `min_stop` / `min_target` âm hoặc không hữu hạn | `min_stop_invalid`, `min_target_invalid` |
| 7 | `entry` ≤ 0 / không hữu hạn | `entry_invalid` |
| 8 | `sl` ≤ 0 / không hữu hạn | `sl_missing` |
| 9 | SL sai phía entry | `sl_not_below_entry`, `sl_not_above_entry` |
| 10 | Khoảng SL < `InpMinStopPoints` | `stop_too_close` |
| 11 | TP không hữu hạn | `tp_not_finite` |
| 12 | TP sai phía entry | `tp_not_above_entry`, `tp_not_below_entry` |
| 13 | Target gần nhất < `InpMinTargetPoints` | `target_too_close` |

Sau khi plan hợp lệ, EA vẫn chạy `CSimRiskGuard` với spread, vị thế mở, exposure, daily loss và
drawdown. Lý do chặn được ghi `PLAN_REJECTED|reason=...|source=...` hoặc
`ENTRY_BLOCKED|reason=...|state=...`.

**Entry tham chiếu không phải entry khớp:** EA khớp tại `ask` (BUY) / `bid` (SELL) cộng slippage bất
lợi; `plan.entry` chỉ được ghi vào log dưới `ref_entry` để đối chiếu. SL/target giữ nguyên theo plan.

### 5. Luật thoát

- **SL trước, target sau** trong cùng một tick — thứ tự thận trọng khi giá chạm cả hai.
- SL: long hit khi `bid <= sl`, short khi `ask >= sl`; gap fill tại giá thị trường xấu hơn, ghi
  `SL_GAP|gap_points=...`.
- Target: long hit khi `bid >= target`, short khi `ask <= target`; **fill đúng bằng target**, không
  cộng gap có lợi. Ghi `TARGET_HIT|mode=TP1|TP3|NONE`.
- `InpTargetMode`: `TP1` dùng TP1; `TP3` dùng TP3, fallback TP2 rồi TP1; `NONE` chỉ có SL.
- `InpMaxHoldingBars > 0`: đóng tại giá thị trường sau đúng số bar, lý do `MAX_HOLDING_BARS`.
- Breakeven/trailing tùy chọn dùng chung `SimTrailingEvaluate`; chỉ cập nhật trên nến mới. Chế độ
  breakeven-only giữ khoảng cách stop hiện tại, không nới stop.
- Không có partial TP, không nhồi thêm vị thế, tối đa một vị thế ảo.

### 6. Test vector

`SimPlanTests` chạy một lần, không đọc thị trường, không ghi file. Kỳ vọng:

```text
TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan
```

Đã xác nhận thật trong MT5 ngày 2026-10-28 (`pass=39 fail=0`). Lần chạy đầu tiên phát hiện hai lỗi mà
compile không bắt được:

- `RunValidate` dùng `point=0.01` trong khi vector được thiết kế theo point 0.001 (V13 "0.5 point",
  V16 "10 points", V18 "30 points"), khiến 8 vector bị chặn ở `stop_too_close`/`target_too_close`.
  Đã sửa hằng số trong `SimPlanTests.mq5` thành 0.001.
- V18 đặt target đúng bằng ngưỡng 30 point; `1.13 - 1.1` trong double là `0.0299999...` nên bị từ chối.
  `SimPlanValidate` nay cộng dung sai `1e-9` (nhỏ hơn một point rất nhiều) vào hai phép so ngưỡng, để
  biên đúng ngưỡng được chấp nhận.

| Nhóm | ID | Nội dung |
|---|---|---|
| Resolve side | R1–R7 | long/short hợp lệ, xung đột DIR, thiếu DIR, hai tín hiệu, không tín hiệu |
| Validate | V1–V19 | plan hợp lệ, từng token lỗi, filter, min stop/target, target gần nhất |
| Target | T1–T13 | chọn TP1/TP3/NONE, fallback, hit theo bid/ask, fill = target |

### 7. Giới hạn đã biết

- `iCustom` dùng **default input** của indicator; muốn đổi cấu hình phải sửa default hoặc tạo EA riêng.
- Plan là ảnh chụp trên nến tín hiệu; EA không dựng lại logic indicator và không kiểm tra repaint.
- Không mô phỏng partial fill, slippage theo volume, swap, margin hay stop-out.
- Không chứng minh indicator và EA khớp Pine; parity vẫn `BLOCKED` cho tới khi có CSV reference.
- Chưa có kết quả runtime hay hiệu năng; không suy diễn từ compile/static test.

## WonderwhalesSimEA — tín hiệu Wonderwhales trên XAUUSDm (2026-10-28)

- **Mục tiêu:** dùng tín hiệu buy/sell của indicator `PinePort\Wonderwhales` để mở **một vị thế ảo** trên
  `XAUUSDm`, thoát theo SL / đảo tín hiệu / max holding. Chạy được trong Strategy Tester M15 hoặc M5,
  xuất CSV 18 cột. Không có API gửi lệnh.
- **Trạng thái:** compile `0 errors, 0 warnings` (cả trong repo và trong Data Folder MT5); 3 scenario
  Strategy Tester headless đã chạy thật trên `XAUUSDm` M15 ngày 2026-10-28 (baseline, conservative stress,
  edge ATR stop) — kết quả ở mục 8; preset + 3 scenario kiểm tra fail-closed PASS.
- **Nguồn:** yêu cầu người dùng 2026-10-28 (chỉ `XAUUSDm`), hợp đồng buffer ở
  [`docs/indicators/wonderwhales.md`](../indicators/wonderwhales.md) và
  `mt5/Include/PinePort/WonderwhalesContract.mqh`.

### 1. An toàn

- Không có `OrderSend`, `OrderSendAsync`, `CTrade`, `MqlTradeRequest` hay hàm position/order nào. Mọi vị
  thế là bản ghi trong `CSimPortfolio`.
- Không đọc account, không kết nối broker, không lưu credential.
- `OnInit` fail-closed: input sai → log token + `INIT_PARAMETERS_INCORRECT`.
- `InpRequireSymbol` mặc định `XAUUSDm`: chạy trên symbol khác bị từ chối tại `OnInit`. Đặt chuỗi rỗng
  để tắt guard khi cần thử symbol khác.

### 2. Input chính

| Nhóm | Input | Ý nghĩa |
|---|---|---|
| Simulation | `InpInitialBalance`, `InpVolume` | balance ảo, volume mỗi entry |
| Simulation | `InpEnableLog`, `InpLogFile`, `InpDebug` | logger CSV và debug print |
| Simulation | `InpRequireSymbol` | guard symbol, rỗng = chấp nhận mọi symbol |
| Signal | `InpMode` | `SAR`, `EMA`, `SAR_EMA`, `SAR_EMA_ATR` (truyền vào indicator) |
| Signal | `InpPsarStart/Inc/Max`, `InpFastEma`, `InpSlowEma`, `InpEma200` | tham số indicator |
| Signal | `InpAtrLen`, `InpMinAtrPct`, `InpVolMaLen`, `InpRsiLen`, `InpBbLen`, `InpBbMult` | tham số indicator |
| Signal | `InpWarmupBars` | số bar tối thiểu trước khi cho entry; phải ≥ `InpEma200` |
| Signal | `InpSideFilter` | `BOTH` / `LONG_ONLY` / `SHORT_ONLY` |
| Stops | `InpStopMode` | `PSAR` / `ATR_PCT` / `FIXED` |
| Stops | `InpAtrPctMultiplier` | dùng cho `ATR_PCT` |
| Stops | `InpFixedStopPoints` | dùng cho `FIXED` |
| Stops | `InpMinStopPoints` | SL phải cách fill ít nhất bao nhiêu point, nếu không thì không vào lệnh |
| Stops | `InpMaxHoldingBars`, `InpExitOnFlip` | 0 = tắt max holding; đóng khi tín hiệu đảo |
| RiskGuard | `InpCooldownBars`, `InpMaxSpreadPoints`, `InpMaxVirtualExposure` | cooldown, spread, exposure |
| RiskGuard | `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpHaltOnBreach` | hard cap theo equity ảo |
| Costs | `InpCommissionPerVolume`, `InpSlippagePoints` | giả định chi phí, áp dụng mọi fill |

Preset mẫu: [`configs/sim/wonderwhales_xauusdm.json`](../../configs/sim/wonderwhales_xauusdm.json).

### 3. Tín hiệu

EA gọi `iCustom(_Symbol,_Period,"PinePort\\Wonderwhales", ...)` với đúng 12 input của indicator và đọc
nến `shift=1` (nến đã đóng):

| Buffer | Hằng số | Dùng cho |
|---:|---|---|
| 0 | `WW_BUF_PSAR` | khoảng cách SL ở chế độ `PSAR` |
| 3 | `WW_BUF_BUY_SIGNAL` | tín hiệu mua (`> 0.5`) |
| 4 | `WW_BUF_SELL_SIGNAL` | tín hiệu bán (`> 0.5`) |
| 8 | `WW_BUF_ATR_PCT` | khoảng cách SL ở chế độ `ATR_PCT` |

Cả hai tín hiệu cùng bật → EA ưu tiên BUY và không kiểm tra xung đột; đây là hành vi đã biết, indicator
được kỳ vọng không phát cả hai trên cùng nến.

### 4. Luật chạy

1. Mỗi tick: cập nhật mid, equity đầu ngày, phát hiện bar mới. Bỏ qua khi
   `Bars < InpWarmupBars + 5`.
2. Đang có vị thế: kiểm tra **SL trước** (long theo bid, short theo ask); gap qua SL → fill giá thị
   trường tệ hơn + slippage, reason `SL_GAP|gap_points=...`.
3. Sau SL, trên bar mới: `InpMaxHoldingBars > 0` và đủ số bar → đóng tại `bid`/`ask`, reason
   `MAX_HOLDING_BARS`.
4. Sau đó, trên bar mới và `InpExitOnFlip=true`: tín hiệu ngược chiều trên nến đã đóng → đóng tại
   `bid`/`ask`, reason `SIGNAL_FLIP`.
5. Không có vị thế và có bar mới: đọc tín hiệu nến 1; áp `InpSideFilter`; hỏi `CSimRiskGuard`; fill bất
   lợi qua `CSimCostModel`; tính khoảng SL; nếu khoảng SL < `InpMinStopPoints` → log `STOP_REJECTED` và
   **không vào lệnh**; ngược lại mở vị thế ảo.
6. Không mở vị thế mới ngay trên bar vừa đóng lệnh (`g_last_exit_bar`).

### 5. Khoảng SL

| `InpStopMode` | Công thức | Ghi chú |
|---|---|---|
| `PSAR` (0) | `abs(fill - psar_bar1)` | PSAR nằm sai phía hoặc quá gần → bị `InpMinStopPoints` chặn |
| `ATR_PCT` (1) | `fill * (atr_pct / 100) * InpAtrPctMultiplier` | `atr_pct` là buffer 8 của indicator |
| `FIXED` (2) | `InpFixedStopPoints * point` | không phụ thuộc indicator |

SL long = `fill - distance`, short = `fill + distance`. Không đặt TP; EA không dùng trailing.

### 6. Log event

Schema 18 cột dùng chung mục **Simulation core**. Event của EA:

| Event | Khi nào | Reason |
|---|---|---|
| `INIT` | `OnInit` thành công | `SIMULATION_ONLY\|config_hash=...\|indicator=...\|contract=...` |
| `ENTRY` | mở vị thế ảo | `SIGNAL_WW_BUY`/`SIGNAL_WW_SELL` + `stop_mode=`, `distance_points=`, `risk=`, `spread_points=` |
| `RISK` | tín hiệu/stop bị chặn | `ENTRY_BLOCKED\|reason=...`, `STOP_REJECTED\|distance_points=...\|min_points=...`, `sl_invalid` |
| `EXIT` | SL, max holding, đảo tín hiệu | `SL_HIT`, `SL_GAP\|gap_points=...`, `MAX_HOLDING_BARS`, `SIGNAL_FLIP` + `bars=`, `pnl=`, `commission=` |
| `SUMMARY` | `OnDeinit` | `trades=`, `wins=`, `losses=`, `flats=`, `net=`, `realized=`, `max_dd=`, `blocks=`, `halted=` |

### 7. Build và chạy tay

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Experts\WonderwhalesSimEA.mq5" `
  /log:"D:\Applications\tm-fx\reports\build\WonderwhalesSimEA.log"
```

Dòng cuối log phải là `Result: 0 errors, 0 warnings`. Chạy Strategy Tester trên `XAUUSDm` M15 (hoặc M5)
với preset `configs/sim/wonderwhales_xauusdm.json`, kiểm tra tab Experts và CSV được khai báo trong
`InpLogFile`.

### 8. Trạng thái thật

| Hạng mục | Trạng thái |
|---|---|
| Compile trong repo | PASS — 0 errors, 0 warnings |
| Compile trong Data Folder MT5 | PASS — 0 errors, 0 warnings; `WonderwhalesSimEA.ex5` 57,522 bytes (2026-10-28) |
| Indicator `PinePort\Wonderwhales` đã cài | PASS — có `.ex5` trong `MQL5\Indicators\PinePort\` |
| Chạy trong MT5 / Strategy Tester | **PASS** — 3 scenario headless trên `XAUUSDm` M15, 2026.01.05–2026.10.01, model 1 phút OHLC, deposit 10,000 USD, build 6249 (bảng dưới) |
| CSV thực tế | PASS — `sim_ww_<scenario>.csv` 18 cột, archived trong `reports/build/tester-reports/` (gitignored) |
| So khớp Pine | `BLOCKED` — chưa có CSV reference |

| Scenario | config_hash | Trades | W/L | Net (đơn vị model) | Max DD | Blocks |
|---|---|---:|---|---:|---:|---|
| `ww_baseline` | `6E969FE1` | 869 | 318/551 | +26.97 | 0.85% | 0 |
| `ww_conservative_stress` | `69086031` | 787 | 276/511 | −7.50 | 0.46% | 139 (134 cooldown, 5 spread) |
| `ww_edge_atr_stop` | `C9EABF3B` | 795 | 390/405 | +24.96 | 0.88% | 0 |

Đọc bảng này đúng cách: P&L tính theo contract size 1 của model (không phải lot/contract 100 của broker),
Strategy Tester hiển thị 0 deal vì EA không gửi lệnh, và baseline/stress còn 1 vị thế ảo mở ở cuối kỳ
(870/869 và 788/787 entry/exit; edge cân bằng 795/795). Không suy ra lợi nhuận hay độ sẵn sàng giao dịch
thật từ các con số này.

### 9. Giới hạn đã biết

- Tín hiệu là ảnh chụp trên nến đã đóng; EA không kiểm tra repaint của indicator.
- Không mô phỏng partial fill, requote, spread biến thiên, swap hay margin.
- Contract size = 1 là giả định mô phỏng; P&L trong CSV không phải tiền broker.
- Calibration 2026-10-28: `XAUUSDm` có point 0.001, 3 chữ số, spread đo được ~260 point và contract size
  100. Vì vậy `InpFixedStopPoints` mặc định là 3000 (3.0 giá) và `InpMaxSpreadPoints` là 600; preset stress
  dùng 400. Đây là ngưỡng theo symbol thật, không phải tối ưu hiệu năng.
- Kết quả 3 scenario là một mẫu M15 trên dữ liệu demo Exness, một cấu hình chi phí giả định; không phải
  bằng chứng lợi nhuận và không mở rộng cho symbol/timeframe khác.
