# Grid — bounded grid demo

**EA demo:** `mt5/Experts/GridDemoEA.mq5` · **magic** `25004001` · **nhãn** `NOT_RUN` (phiên demo/tester
của EA demo chưa từng chạy). Nguồn chưng cất:
[`../99-archive/MT5_EA_Lab_V2/STRATEGIES/GRID_EA.md`](../99-archive/MT5_EA_Lab_V2/STRATEGIES/GRID_EA.md).

## 1. Chiến lược

Lưới một chiều **có chặn cứng**: tầng đầu mở theo hướng cấu hình (`InpGridSide`) khi RiskGuard cho phép;
mỗi bar mới (hoặc mỗi tick khi đang có giỏ) xét thêm tầng ở cách `spacing` so với entry xa nhất
(BUY: thấp hơn, SELL: cao hơn) — fixed points hoặc ATR × hệ số. Volume tầng *n* =
`min(InpBaseVolume × InpVolumeMultiplier^(n−1), InpMaxLevelVolume)`; chặn hoàn toàn khi vượt số tầng,
volume tầng hoặc tổng exposure (không chia nhỏ). Thoát theo giỏ: TP = entry bình quân ±
`InpBasketTargetPoints`, SL giỏ = entry bình quân ∓ `InpBasketStopPoints` (**bắt buộc > 0** — không có
chế độ gồng vô hạn); tuỳ chọn LEVEL mode đóng từng tầng đạt lãi. Không có tín hiệu thị trường — đây là
công cụ nghiên cứu cấu trúc lưới, không phải chiến lược hoàn chỉnh.

## 2. Cấu trúc code

| File | Vai trò |
|---|---|
| `mt5/Experts/GridDemoEA.mq5` | EA demo: lưới thật qua guard, SL/TP giỏ trên mọi chân |
| `mt5/Include/Exec/ExecDemoCommon.mqh` | Lớp chung bot giỏ: đọc giỏ theo magic, SL/TP tuyệt đối, kill switch |
| `mt5/Include/Sim/SimGrid.mqh` | Toán lưới thuần (spacing, tầng, cap) — cùng luật với `GridLabEA` |
| `mt5/Include/Sim/SimRiskGuard.mqh`, `SimLogger.mqh` | Guard rủi ro và journal CSV 18 cột |
| `mt5/Experts/GridLabEA.mq5` | EA mô phỏng cùng luật (vị thế ảo, preset `configs/sim/grid_lab.json`) |

## 3. Bảng input

| Nhóm | Input (tên hiện tại) | Giá trị mặc định | Tên chuẩn (phase C) |
|---|---|---|---|
| Demo execution | `InpEnableExecution` | `true` | `InpEnableExecution` |
| | `InpAllowedSymbols` | `"XAUUSD"` | `InpAllowedSymbols` |
| | `InpMagicNumber` | `25004001` | `InpMagicNumber` |
| | `InpMaxSlippagePoints` | `30` | `InpMaxSlippagePoints` |
| | `InpKillSwitchFile` | `"GRID_DEMO_STOP.txt"` | `InpKillSwitchFile` |
| | `InpCloseOnKillSwitch` | `true` | `InpCloseOnKillSwitch` |
| Journal | `InpEnableLog` | `true` | `InpEnableLog` |
| | `InpLogFile` | `"grid_demo.csv"` | `InpLogFile` |
| | `InpDebug` | `false` | `InpDebug` |
| Grid | `InpGridSide` | `GRID_DEMO_LONG` | giữ |
| | `InpSpacingMode` | `SIM_GRID_FIXED_POINTS` | giữ |
| | `InpSpacingPoints` | 300.0 | giữ |
| | `InpAtrPeriod` / `InpAtrMultiplier` | 14 / 1.0 | giữ |
| | `InpMaxGridLevels` | 5 | giữ |
| | `InpBaseVolume` | 0.01 | giữ |
| | `InpVolumeMultiplier` | 1.50 | giữ |
| | `InpMaxLevelVolume` | 0.10 | giữ |
| Exit | `InpExitMode` | `GRID_DEMO_EXIT_BASKET` | giữ |
| | `InpLevelTargetPoints` | 300.0 | giữ |
| | `InpBasketTargetPoints` | 600.0 | giữ |
| | `InpBasketStopPoints` | 900.0 | giữ |
| RiskGuard | `InpMaxSpreadPoints` | 50.0 | `InpMaxSpreadPoints` |
| | `InpMaxExposure` | 0.50 | `InpMaxExposure` |
| | `InpMaxBasketLossPct` | 2.0 | giữ |
| | `InpMaxDailyLossPct` | 2.0 | giữ |
| | `InpMaxDrawdownPct` | 5.0 | giữ |
| | `InpMaxConsecutiveLosses` | 3 | giữ |
| | `InpHaltOnBreach` | `true` | giữ |

Gap so chuẩn (xem thiết kế §9): nhóm `Demo execution`/`Journal`/`RiskGuard`/`Exit` sẽ được đổi tên thành
`01 Execution`/`04 Journal and state`/`02 Risk`/`03 Stops`+`06 Strategy` (phase C); **thiếu**
`InpRiskPercent`/`InpMaxPositions`/`InpCooldownMinutes` (phase C: thêm — `InpMaxPositions` = số tầng tối đa,
hoặc ghi rõ `N/A` có lý do).

## 4. Preset và magic

- Preset JSON: [`configs/demo/grid_demo.json`](../../configs/demo/grid_demo.json) — `DEMO_ONLY`,
  `allow_live_trading=false`, `InpEnableExecution=true`, symbol `XAUUSDm`, timeframe M15; preset đặt
  trần chặt hơn code: `InpBaseVolume=0.01`, `InpMaxLevelVolume=0.04`, `InpMaxExposure=0.10`.
- Preset `.set`: [`docs/20-operations/presets/grid_demo.set`](../20-operations/presets/grid_demo.set).
- Kill switch: `GRID_DEMO_STOP.txt` trong `MQL5/Files`.
- Sim: `mt5/Experts/GridLabEA.mq5` (vị thế ảo), preset `configs/sim/grid_lab.json`.

## 5. Bằng chứng

Nhãn: **`NOT_RUN`** — chưa có journal demo hay tester run nào của `GridDemoEA` (§64.7: tester run đã
chuẩn bị nhưng bị hoá vì terminal đang mở; §66: mọi phiên demo của bot mới `NOT_RUN`).

- Bằng chứng hiện có là của **EA mô phỏng** `GridLabEA` (không phải EA demo) — §41, 2026-10-28:
  `grid_baseline` ACTIVE, 24 052 level / 17 581 basket, net +1 355.49, DD 1.13%;
  `grid_conservative_stress` ACTIVE, net +422.91; `grid_edge_single_level` HALTED, net −496.85.
- ADR 0004 (§64): phạm vi demo được mở cho Grid/DCA, code + preset + validator xanh, compile 0/0 —
  đó là `ALLOWED` về phạm vi, **không** phải "đã chạy".
- Bằng chứng mô phỏng lưu ở `reports/build/tester-reports/grid_*/` (gitignored); chi tiết
  [`../PROGRESS.md`](../PROGRESS.md) §41, §64.

## 6. Giới hạn / quirk đã biết

- Net dương của baseline mô phỏng đến từ mô hình mở/đóng level liên tục 9 tháng với contract size 1 và
  spread giả định — **không kết luận lợi nhuận**.
- Gap có thể vượt stop: cap không bảo đảm lỗ tối đa; giỏ một chiều lỗ lớn khi trend mạnh.
- Không tín hiệu vào lệnh: tầng đầu mở theo chiều cấu hình — công cụ nghiên cứu, không phải chiến lược.
- Trần exposure khác tên giữa hai chế độ: `GridLabEA` dùng `InpMaxVirtualExposure`, `GridDemoEA` dùng
  `InpMaxExposure` — đọc đúng input của EA đang chạy.
- Preset demo đặt trần chặt hơn mặc định code (`0.04`/`0.10` so với `0.10`/`0.50`) — đọc preset, đừng
  đọc default, khi ước lượng kích thước lưới.
- LEVEL mode không đặt TP riêng trong portfolio; đóng theo ngưỡng lãi tại tick.
- Chưa đối chiếu Python bounded-basket simulator với EA trên cùng chuỗi tick.
