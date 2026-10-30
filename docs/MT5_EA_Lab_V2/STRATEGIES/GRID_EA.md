# Grid EA — bounded virtual grid

**Trạng thái:** `SIMULATION_ONLY`  
**Entry point:** `mt5/Experts/GridLabEA.mq5`  
**Preset:** `configs/sim/grid_lab.json`  
**Demo execution:** `ALLOWED` (ADR 0004) — EA demo `mt5/Experts/GridDemoEA.mq5`, preset `configs/demo/grid_demo.json`, kill switch `GRID_DEMO_STOP.txt`. Phiên demo thật: `NOT_RUN` (chưa có journal).

## 1. Mục tiêu

Nghiên cứu lưới vị thế **ảo** có giới hạn cứng về số tầng, volume mỗi tầng và tổng exposure. Không lưới vô hạn, không gồng không giới hạn, không gửi lệnh.

## 2. An toàn

- Không có `OrderSend`, `OrderSendAsync`, `CTrade`, `MqlTradeRequest`, `PositionOpen/Close/Modify`.
- Mọi tầng là vị thế ảo trong `CSimPortfolio`.
- Không đọc account, không kết nối broker, không lưu credential.
- `OnInit` fail-closed: input sai → log token + `INIT_PARAMETERS_INCORRECT`.
- `InpBasketStopPoints` bắt buộc > 0 — không có cấu hình "gồng vô hạn".

## 3. Quy tắc

### 3.1 Hướng và khoảng cách

- Một chiều cho cả basket: `GRID_LONG` hoặc `GRID_SHORT`.
- Spacing:
  - Fixed: `InpSpacingPoints × point`
  - ATR: `ATR(bar 1) × InpAtrMultiplier`
- Tầng tiếp theo:
  - BUY: `last_entry − spacing`
  - SELL: `last_entry + spacing`
- `last_entry` là entry thấp nhất (BUY) / cao nhất (SELL) đang mở.

### 3.2 Volume và cap

```text
volume(level n) = min(base × multiplier^(n−1), InpMaxLevelVolume)
```

Thứ tự kiểm tra:

1. `level < 1` → `grid_level_invalid`
2. `level > InpMaxGridLevels` → `max_grid_levels_reached`
3. base ≤ 0, multiplier < 1, max level volume ≤ 0 → `grid_volume_invalid`
4. exposure + volume > `InpMaxVirtualExposure` → `max_virtual_exposure_reached` — **chặn hoàn toàn**, không chia nhỏ volume

Preset: base 0.10, multiplier 1.50, max level volume 1.00, max levels 5, max exposure 2.0.

### 3.3 Exit

- **BASKET mode:** target/stop theo average entry (volume-weighted).
  - Target `InpBasketTargetPoints=600`
  - Stop `InpBasketStopPoints=900` (bắt buộc)
- **LEVEL mode:** đóng các tầng đã đạt `InpLevelTargetPoints=300` lãi; average entry tính lại.
- Stop basket áp dụng cho cả hai mode.
- Gap qua stop/target: fill tại giá thị trường + slippage, không giả vờ khớp đúng mức.

### 3.4 Vòng chạy

1. Mỗi tick: cập nhật mid, equity đầu ngày, phát hiện bar mới, đọc spacing.
2. Đang có basket: kiểm tra **stop trước**, rồi target (BASKET) hoặc chốt tầng đủ lãi (LEVEL).
3. Còn vị thế + có spacing: xét thêm tầng; một tick có thể thêm nhiều tầng nếu gap, nhưng luôn bị chặn bởi level/volume/exposure cap.
4. Không có vị thế + bar mới: mở tầng 1 nếu RiskGuard cho phép; không mở lại trên đúng bar vừa đóng basket.

## 4. RiskGuard

| Guard | Giá trị preset |
|---|---|
| Spread | 600 points |
| Max virtual exposure | 2.0 |
| Daily loss | 2% |
| Max drawdown | 5% |
| Halt on breach | `false` (ghi nhận, không tự dừng) |
| Commission | 0.0 |
| Slippage | 0.0 |

Guard dùng chung nhận `max_virtual_positions = InpMaxGridLevels` để không vượt số tầng. Guard không tự nới cap.

## 5. Log

Schema 18 cột dùng chung. Event: `INIT`, `ENTRY`, `RISK`, `EXIT`, `SUMMARY`.

Ví dụ `SUMMARY`:

```text
levels_opened=24052|closed=24052|baskets=17581|open=0|realized=1355.49|max_dd=1.1301|blocks=12|halted=ACTIVE
```

## 6. Kết quả Strategy Tester

Cấu hình: `XAUUSDm`, M15, 2026.01.05 → 2026.10.01, deposit 10 000, leverage 1:100, model 1-min OHLC, build 6249 (lần chạy 2026-10-28).

| Scenario | Kết luận | Số liệu |
|---|---|---|
| `grid_baseline` | `ACTIVE` | 24 052 level, 17 581 basket, net **+1 355.49**, max DD **1.1301%**, 12 block |
| `grid_conservative_stress` | `ACTIVE` | 22 916 level, 17 513 basket, net **+422.91**, max DD **0.2911%**, 80 block |
| `grid_edge_single_level` | `HALTED` | 11 018 level/basket, net **−496.85**, max DD **5.0003%**, 6 575 block |

Bằng chứng: `reports/build/tester-reports/grid_*/`.

**Không kết luận lợi nhuận.** Net dương của baseline đến từ mô hình mở/đóng level liên tục trong 9 tháng với contract size 1 và spread giả định; không phải kết quả giao dịch thật. Grid một chiều có thể lỗ lớn khi trend mạnh dù có cap.

## 7. Giới hạn

- Không có tín hiệu vào lệnh: tầng 1 mở theo chiều cấu hình ở bar mới đầu tiên khi guard cho phép. Đây là công cụ nghiên cứu cấu trúc lưới, không phải chiến lược hoàn chỉnh.
- LEVEL mode không đặt TP riêng trong portfolio; đóng theo ngưỡng lãi tại tick.
- Không mô phỏng partial fill, requote, spread biến thiên, swap; contract size = 1 là giả định.
- Không có margin/leverage/stop-out.
- Cap không bảo đảm lỗ tối đa; gap có thể vượt stop.
- Chưa đối chiếu Python bounded-basket simulator với EA trên cùng chuỗi tick.

## 8. Demo execution

**Đã được phép (ADR 0004).** EA demo là `mt5/Experts/GridDemoEA.mq5`, preset `configs/demo/grid_demo.json`, kill switch `GRID_DEMO_STOP.txt`. Rào chắn cứng: tài khoản demo/tester, SL/TP bắt buộc trên mọi lệnh, `InpMaxGridLevels` (1..50), `InpMaxLevelVolume`, `InpMaxExposure`, `InpMaxBasketLossPct`, `InpMaxConsecutiveLosses`, kill switch. Phiên demo thật: `NOT_RUN` (chưa có journal).

Không attach `GridLabEA` vào tài khoản thật để "thử".

## 9. Tái lập

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\Grid*"
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\grid_baseline.ini"
```

Kiểm tra `sim_grid_log.csv` và `tester_grid_baseline.htm`.

## 10. Liên kết

- Code: [`../../../mt5/Experts/GridLabEA.mq5`](../../../mt5/Experts/GridLabEA.mq5), [`../../../mt5/Include/Sim/SimGrid.mqh`](../../../mt5/Include/Sim/SimGrid.mqh)
- Chi tiết mô phỏng: [`../../reference/simulation.md`](../../reference/simulation.md) mục 8, `GridLabEA`
- Preset: [`../../../configs/sim/grid_lab.json`](../../../configs/sim/grid_lab.json)
- Quyết định cần thiết: [`../DECISIONS_REQUIRED.md`](../DECISIONS_REQUIRED.md)
