# Đặc tả ba EA mô phỏng

## A. GridLabEA

### Mục đích

Nghiên cứu cách lưới vị thế ảo hoạt động khi giá đi ngang, biến động và xu hướng kéo dài. Không mô phỏng vô hạn; mọi lớp đều bị chặn bằng hard cap.

### Inputs tối thiểu

- `InpExecutionMode = SIMULATION_ONLY` (không được đổi sang live).
- `InpGridSpacingMode = FIXED_POINTS | ATR_MULTIPLE`.
- `InpGridSpacingPoints > 0`.
- `InpATRPeriod >= 2`, `InpATRMultiplier > 0` khi dùng ATR.
- `InpMaxGridLevels >= 1`.
- `InpBaseVirtualVolume > 0`.
- `InpVolumeMultiplier >= 1`; nếu multiplier lớn hơn 1, vẫn phải áp dụng `InpMaxLevelVirtualVolume` và `InpMaxVirtualExposure`.
- `InpExitMode = LEVEL | BASKET`.
- `InpBasketTarget` và `InpBasketStop` theo đơn vị được ghi rõ.
- Các giới hạn RiskGuard.

### Logic

1. Kiểm tra dữ liệu, spread và RiskGuard.
2. Tính khoảng cách grid theo fixed points hoặc ATR.
3. Khi điều kiện mô phỏng đạt, kiểm tra level count/exposure trước khi thêm một virtual level.
4. Cập nhật giá vốn, floating P&L và costs.
5. Áp dụng exit theo mức hoặc basket target/stop.
6. Khi chạm max loss/drawdown/exposure, chặn thêm level và chuyển `HALTED` theo cấu hình.

### Ca stress bắt buộc

- Giá dao động quanh một biên hẹp.
- Xu hướng đi một chiều liên tục.
- Spread tăng đột biến.
- Gap qua nhiều mức grid.
- Đạt đúng `MaxGridLevels` và `MaxVirtualExposure`.

## B. DCALabEA

### Mục đích

Nghiên cứu tác động của các lần thêm vị thế ảo theo khoảng giá hoặc thời gian. Không được bình quân vô hạn và không được tự tăng giới hạn sau chuỗi thua.

### Inputs tối thiểu

- `InpDcaTriggerMode = PRICE_DISTANCE | BAR_INTERVAL`.
- `InpDcaDistancePoints > 0` hoặc `InpBarsBetweenAdds >= 1`.
- `InpMaxDcaAdds >= 0` (0 nghĩa là không cho add, không có nghĩa là vô hạn).
- `InpBaseVirtualVolume`, `InpAddVolumeMultiplier` và `InpMaxVirtualExposure`.
- `InpBasketExitMode`, `InpBasketTarget`, `InpBasketStop`.
- `InpMaxDrawdownPct`, `InpMaxDailyLossPct`, `InpMaxSpreadPoints`.

### Logic

- Tính giá vốn bình quân theo volume ảo.
- Mỗi lần muốn add phải kiểm tra số lần add, exposure, drawdown, daily loss, spread và dữ liệu.
- Khi chạm cap, không add thêm; ghi lý do chặn và áp dụng chính sách stop/exit mô phỏng.
- Không giả định rằng giá sẽ hồi về giá vốn.

### Ca stress bắt buộc

- Giá đi ngược vị thế liên tục.
- Nhiều trigger xảy ra trong một cây nến hoặc tick burst.
- Spread mở rộng; thiếu dữ liệu; gap qua trigger.
- Chạm giới hạn add đúng tại biên.

## C. RunnerTrailingLabEA — một vị thế ảo, trailing stop

### Mục đích

Nghiên cứu cách giữ một vị thế ảo khi diễn biến còn thuận lợi và nâng/dời stop theo quy tắc. “Để lãi chạy” không có nghĩa lợi nhuận vô hạn; trailing stop không loại bỏ gap/slippage.

### Inputs tối thiểu

- `InpSide = LONG | SHORT` hoặc chỉ log tín hiệu.
- `InpInitialStopPoints > 0`.
- `InpBreakEvenEnabled`, `InpBreakEvenTriggerPoints`, `InpBreakEvenOffsetPoints`.
- `InpTrailingMode = FIXED_POINTS | ATR_MULTIPLE`.
- `InpTrailingDistancePoints > 0` hoặc `InpATRPeriod` + `InpATRMultiplier`.
- `InpUpdateOnClosedBarOnly` để kiểm soát cách cập nhật trong test.
- `InpMaxHoldingBars` tùy chọn.

### Luật đơn điệu

- LONG: `newSL >= oldSL`; chỉ chấp nhận nếu cải thiện mức bảo vệ và hợp lệ theo logic mô phỏng.
- SHORT: `newSL <= oldSL`; chỉ chấp nhận nếu cải thiện mức bảo vệ và hợp lệ theo logic mô phỏng.
- Không bao giờ nới SL đi ngược để trì hoãn việc ghi nhận lỗ.
- Nếu giá gap qua SL, mô hình chi phí phải ghi nhận giả định fill/slippage thay vì giả vờ fill chính xác ở SL.

### Ca test bắt buộc

- Long/short cùng chiều có lợi, giá đảo chiều về trailing stop.
- Giá không đạt ngưỡng break-even.
- SL candidate không hợp lệ hoặc không cải thiện mức bảo vệ.
- Gap qua stop.
- ATR chưa đủ bars; dữ liệu thiếu hoặc spread vượt ngưỡng.
