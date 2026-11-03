# DCA — bounded DCA demo

**EA demo:** `mt5/Experts/DCADemoEA.mq5` · **magic** `25005001` · **nhãn** `NOT_RUN` (phiên demo/tester
của EA demo chưa từng chạy). Nguồn chưng cất:
[`../99-archive/MT5_EA_Lab_V2/STRATEGIES/DCA_EA.md`](../99-archive/MT5_EA_Lab_V2/STRATEGIES/DCA_EA.md).

## 1. Chiến lược

Bình quân giá **có chặn cứng**, hai kiểu trigger: **theo biến động** — giá đi đúng `InpDcaDistancePoints`
sát với entry cuối (BUY: `bid ≤ last_entry − distance`; SELL: `ask ≥ last_entry + distance`) — hoặc
**theo thời gian** — cách nhau ít nhất `InpBarsBetweenAdds` bar. Vị thế đầu không tính là add và luôn
dùng `InpBaseVolume`; lần add *n* có volume `min(InpBaseVolume × InpAddVolumeMultiplier^n, InpMaxAddVolume)`;
`InpMaxDcaAdds` chặn tổng số lần add (**0 = không add, không phải không giới hạn**). Thoát theo giỏ:
TP = entry bình quân ± `InpBasketTargetPoints`, SL giỏ = entry bình quân ∓ `InpBasketStopPoints`
(**bắt buộc > 0**); mỗi lần add phải qua RiskGuard thêm một lần; gap qua stop/target fill tại giá thị
trường + slippage.

## 2. Cấu trúc code

| File | Vai trò |
|---|---|
| `mt5/Experts/DCADemoEA.mq5` | EA demo: DCA thật qua guard, tối đa một add mỗi bar |
| `mt5/Include/Exec/ExecDemoCommon.mqh` | Lớp chung bot giỏ: đọc giỏ theo magic, SL/TP tuyệt đối, kill switch |
| `mt5/Include/Sim/SimDca.mqh` | Toán DCA thuần (trigger, volume add, cap) — cùng luật với `DCALabEA` |
| `mt5/Include/Sim/SimRiskGuard.mqh`, `SimLogger.mqh` | Guard rủi ro và journal CSV 18 cột |
| `mt5/Experts/DCALabEA.mq5` | EA mô phỏng cùng luật (vị thế ảo, preset `configs/sim/dca_lab.json`) |

## 3. Bảng input

| Nhóm | Input (tên hiện tại) | Giá trị mặc định | Tên chuẩn (phase C) |
|---|---|---|---|
| Demo execution | `InpEnableExecution` | `true` | `InpEnableExecution` |
| | `InpAllowedSymbols` | `"XAUUSD"` | `InpAllowedSymbols` |
| | `InpMagicNumber` | `25005001` | `InpMagicNumber` |
| | `InpMaxSlippagePoints` | `30` | `InpMaxSlippagePoints` |
| | `InpKillSwitchFile` | `"DCA_DEMO_STOP.txt"` | `InpKillSwitchFile` |
| | `InpCloseOnKillSwitch` | `true` | `InpCloseOnKillSwitch` |
| Journal | `InpEnableLog` | `true` | `InpEnableLog` |
| | `InpLogFile` | `"dca_demo.csv"` | `InpLogFile` |
| | `InpDebug` | `false` | `InpDebug` |
| DCA | `InpDcaSide` | `DCA_DEMO_LONG` | giữ |
| | `InpBaseVolume` | 0.01 | giữ |
| | `InpTriggerMode` | `SIM_DCA_PRICE_DISTANCE` | giữ |
| | `InpDcaDistancePoints` | 300.0 | giữ |
| | `InpBarsBetweenAdds` | 5 | giữ |
| | `InpMaxDcaAdds` | 3 | giữ |
| | `InpAddVolumeMultiplier` | 1.50 | giữ |
| | `InpMaxAddVolume` | 0.10 | giữ |
| Exit | `InpBasketTargetPoints` | 600.0 | giữ |
| | `InpBasketStopPoints` | 900.0 | giữ |
| RiskGuard | `InpMaxSpreadPoints` | 50.0 | `InpMaxSpreadPoints` |
| | `InpMaxExposure` | 0.50 | `InpMaxExposure` |
| | `InpMaxBasketLossPct` | 2.0 | giữ |
| | `InpMaxDailyLossPct` | 2.0 | giữ |
| | `InpMaxDrawdownPct` | 5.0 | giữ |
| | `InpMaxConsecutiveLosses` | 3 | giữ |
| | `InpHaltOnBreach` | `true` | giữ |

Gap so chuẩn (xem thiết kế §9): nhóm `Demo execution`/`Journal`/`RiskGuard`/`Exit` sẽ đổi thành
`01 Execution`/`04 Journal and state`/`02 Risk`/`03 Stops`+`06 Strategy` (phase C); **thiếu**
`InpRiskPercent`/`InpMaxPositions`/`InpCooldownMinutes` (phase C: thêm hoặc ghi rõ `N/A` có lý do).

## 4. Preset và magic

- Preset JSON: [`configs/demo/dca_demo.json`](../../configs/demo/dca_demo.json) — `DEMO_ONLY`,
  `allow_live_trading=false`, `InpEnableExecution=true`, symbol `XAUUSDm`, timeframe M15; preset đặt
  `InpBaseVolume=0.01`, `InpMaxAddVolume`/`InpMaxExposure` chặt hơn mặc định code.
- Preset `.set`: [`docs/20-operations/presets/dca_demo.set`](../20-operations/presets/dca_demo.set).
- Kill switch: `DCA_DEMO_STOP.txt` trong `MQL5/Files`.
- Sim: `mt5/Experts/DCALabEA.mq5` (vị thế ảo), preset `configs/sim/dca_lab.json`.

## 5. Bằng chứng

Nhãn: **`NOT_RUN`** — chưa có journal demo hay tester run nào của `DCADemoEA` (§64.7, §66: tương tự Grid).

- Bằng chứng hiện có là của **EA mô phỏng** `DCALabEA` — §41, 2026-10-28: cả bốn scenario
  (`dca_baseline` −497.06, `dca_conservative_stress` −200.06, `dca_edge_no_adds` và `dca_edge_bar_trigger`
  −496.85) đều HALTED bởi RiskGuard, DD 2–5%.
- Bug báo cáo `adds=0` (counter reset khi basket đóng) đã sửa ở §54 và chạy lại thật ngày 2026-10-29 (§56.2):
  `dca_baseline` mới ghi `adds=2|basket_adds=0`, hai dòng `DCA_ADD` volume 0.15 rồi 0.225 — xác nhận chỉ
  đổi báo cáo, không đổi hành vi giao dịch.
- ADR 0004 (§64): phạm vi demo mở cho DCA, validator + test xanh — `ALLOWED` về phạm vi, **không** "đã chạy".
- Bằng chứng mô phỏng: `reports/build/tester-reports/dca_*/` (gitignored); chi tiết
  [`../PROGRESS.md`](../PROGRESS.md) §41, §54, §56, §64.

## 6. Giới hạn / quirk đã biết

- Cả bốn scenario mô phỏng đều âm và bị guard dừng — hành vi của mô hình, **không kết luận lợi nhuận**.
- `adds=0` trong CSV cũ (2026-10-28) là bug reporting; số `adds` giữa run cũ và mới không so sánh trực tiếp.
- Hai scenario `dca_edge_*` cho kết quả giống hệt nhau và giống `grid_edge_single_level` — cần điều tra
  nếu dùng để kết luận về add/trigger.
- Gap có thể vượt stop basket; cap không bảo đảm lỗ tối đa.
- Không tín hiệu vào lệnh: entry đầu theo chiều cấu hình khi guard cho phép.
- Không mô phỏng partial fill, requote, spread biến động, swap; contract size = 1.
- Thiếu `InpRiskPercent`/`InpMaxPositions`/`InpCooldownMinutes` so với chuẩn phase C (gap đã ghi).
