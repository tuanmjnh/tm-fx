# DCA EA — bounded virtual DCA

**Trạng thái:** `SIMULATION_ONLY`  
**Entry point:** `mt5/Experts/DCALabEA.mq5`  
**Preset:** `configs/sim/dca_lab.json`  
**Demo execution:** `ALLOWED` (ADR 0004) — EA demo `mt5/Experts/DCADemoEA.mq5`, preset `configs/demo/dca_demo.json`, kill switch `DCA_DEMO_STOP.txt`. Phiên demo thật: `NOT_RUN` (chưa có journal).

## 1. Mục tiêu

Nghiên cứu các lần bổ sung vị thế **ảo** theo khoảng giá hoặc khoảng thời gian, với giới hạn cứng về số lần add, volume mỗi lần và tổng exposure. Không bình quân vô hạn, không martingale mặc định.

## 2. An toàn

- Không có API gửi lệnh; mọi vị thế là ảo trong `CSimPortfolio`.
- Không đọc account, không kết nối broker, không credential.
- `OnInit` fail-closed.
- `InpBasketStopPoints` bắt buộc > 0.
- `InpMaxDcaAdds = 0` nghĩa là **không add**, không phải không giới hạn.

## 3. Quy tắc

### 3.1 Trigger

- **Theo giá:** BUY khi `bid ≤ last_entry − InpDcaDistancePoints`; SELL khi `ask ≥ last_entry + InpDcaDistancePoints`.
- **Theo thời gian:** cần `bar_time − last_add_bar ≥ InpBarsBetweenAdds × timeframe_seconds`. Bar hiện tại hoặc bar lùi trả `false`.

### 3.2 Volume và cap

```text
add_index = dca_adds + 1
volume    = min(base × multiplier^add_index, InpMaxAddVolume)
```

Vị thế đầu không tính là add và luôn dùng `base`.

Thứ tự kiểm tra:

1. `max_dca_adds < 0` → `max_dca_adds_invalid`
2. `dca_adds < 0` → `dca_adds_invalid`
3. `dca_adds ≥ max_dca_adds` → `max_dca_adds_reached`
4. base ≤ 0, multiplier < 1, max add volume ≤ 0 → `dca_volume_invalid`
5. exposure + volume > cap → `max_virtual_exposure_reached` — **chặn hoàn toàn**, không chia nhỏ

Preset: base 0.10, multiplier 1.50, max add volume 1.00, max adds 3, max exposure 2.0.

### 3.3 Exit

- Basket target `InpBasketTargetPoints=600` theo average entry.
- Basket stop `InpBasketStopPoints=900` bắt buộc.
- Gap qua stop/target: fill tại giá thị trường + slippage.

## 4. RiskGuard

| Guard | Giá trị preset |
|---|---|
| Spread | 600 points |
| Max virtual exposure | 2.0 |
| Daily loss | 2% |
| Max drawdown | 5% |
| Halt on breach | `false` |
| Commission | 0.0 |
| Slippage | 0.0 |

Mỗi add phải qua guard lại một lần. Khi mất dữ liệu, spread vượt ngưỡng, margin không đạt, daily loss hoặc drawdown bật → **không add**.

## 5. Kết quả Strategy Tester

Cấu hình: `XAUUSDm`, M15, 2026.01.05 → 2026.10.01, deposit 10 000, leverage 1:100, model 1-min OHLC.

| Scenario | Kết luận | Số liệu |
|---|---|---|
| `dca_baseline` | `HALTED` | 11 012 basket, net **−497.06**, max DD **5.0023%**, 6 581 block |
| `dca_conservative_stress` | `HALTED` | 6 098 basket, net **−200.06**, max DD **2.0006%**, 11 497 block |
| `dca_edge_no_adds` | `HALTED` | 11 018 basket, net **−496.85**, max DD **5.0003%**, 6 575 block |
| `dca_edge_bar_trigger` | `HALTED` | 11 018 basket, net **−496.85**, max DD **5.0003%**, 6 575 block |

Bằng chứng: `reports/build/tester-reports/dca_*/`.

**Bug báo cáo `adds=0` — đã sửa trong code (2026-10-29):** `SUMMARY` của các scenario chạy ngày 2026-10-28 ghi `adds=0` dù CSV có `ENTRY` nối basket với volume 0.15 rồi 0.225. Nguyên nhân: counter `g_dca_adds` bị reset khi basket đóng. Code hiện thêm `g_total_adds` cộng dồn toàn run và SUMMARY có thêm trường `basket_adds`; `adds` giờ là tổng cộng dồn, `basket_adds` là số add của basket đang mở. CSV cũ **không** được ghi lại, nên số `adds=0` trong `reports/build/tester-reports/dca_*` vẫn là bằng chứng lịch sử.

Trạng thái kiểm chứng: compile `0 errors, 0 warnings`; test hồi quy tĩnh trong `python/tests/test_sim_core_source.py` PASS; **runtime PASS** (2026-10-29, `dca_baseline` chạy lại sau khi đóng terminal demo): SUMMARY mới là `entries=11012|adds=2|basket_adds=0|closed=11014|baskets=11012|open=0|realized=-497.06|max_dd=5.0023|blocks=6581|halted=HALTED`, có 2 dòng `DCA_ADD` (`add=1` vol 0.15; `add=2` vol 0.225). Các số còn lại trùng run 2026-10-28, xác nhận thay đổi chỉ ở báo cáo. Bằng chứng `reports/build/tester-reports/dca_baseline/`.

**Không kết luận lợi nhuận.** Cả bốn scenario đều âm và bị guard dừng; đây là hành vi của mô hình, không phải khuyến nghị chạy.

## 6. Giới hạn

- Không có tín hiệu vào lệnh; entry đầu theo chiều cấu hình khi guard cho phép.
- Không mô phỏng partial fill, requote, spread biến thiên, swap; contract size = 1.
- Không có margin/leverage/stop-out.
- Cap không bảo đảm lỗ tối đa; gap có thể vượt stop.
- `adds=0` trong CSV cũ là bug reporting đã sửa; run 2026-10-29 ghi `adds=2` tổng cộng dồn và `basket_adds=0` khi basket cuối đã đóng.
- Hai scenario `dca_edge_*` cho kết quả giống nhau và giống `grid_edge_single_level`; cần điều tra nếu dùng để kết luận về add/trigger.

## 7. Demo execution — ALLOWED (ADR 0004)

ADR 0004 (2026-10-30) đã thay câu "không martingale, không grid, không DCA trong phạm vi demo execution đầu tiên" của ADR 0003 điểm 3: mọi bot được execution đầy đủ trên tài khoản demo. DCA demo vẫn bị chặn cứng ở: tài khoản demo/tester, SL/TP bắt buộc trên mọi lệnh, `InpMaxDcaAdds`, `InpMaxAddVolume`, `InpMaxExposure`, `InpMaxBasketLossPct`, kill switch và điểm gửi lệnh duy nhất `ExecBroker.mqh`.

Vì vậy:

- EA demo DCA: `mt5/Experts/DCADemoEA.mq5`; preset `configs/demo/dca_demo.json` (`InpEnableExecution=false`, `DEMO_ONLY`).
- Phiên demo thật: `NOT_RUN` — chưa có journal và tester cho `DCADemoEA` chưa chạy.
- Rào chắn cứng: tài khoản demo/tester, SL/TP bắt buộc, `InpMaxDcaAdds`, `InpMaxAddVolume`, `InpMaxExposure`, `InpMaxBasketLossPct`, kill switch `DCA_DEMO_STOP.txt`, điểm gửi lệnh duy nhất `ExecBroker.mqh`.

Xem [`../DECISIONS_REQUIRED.md`](../DECISIONS_REQUIRED.md).

## 8. Tái lập

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 -Filter "Experts\DCA*"
& "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe" /config:"D:\Applications\tm-fx\reports\build\tester-run\dca_baseline.ini"
```

## 9. Liên kết

- Code: [`../../../mt5/Experts/DCALabEA.mq5`](../../../mt5/Experts/DCALabEA.mq5), [`../../../mt5/Include/Sim/SimDca.mqh`](../../../mt5/Include/Sim/SimDca.mqh)
- Chi tiết mô phỏng: [`../../reference/simulation.md`](../../reference/simulation.md) mục 9, `DCALabEA`
- Preset: [`../../../configs/sim/dca_lab.json`](../../../configs/sim/dca_lab.json)
- ADR: [`../../decisions/0003-demo-execution-scope.md`](../../decisions/0003-demo-execution-scope.md)
- Quyết định cần thiết: [`../DECISIONS_REQUIRED.md`](../DECISIONS_REQUIRED.md)
