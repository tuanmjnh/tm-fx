# Risk model và kiểm định

## 1. Các giới hạn hard cap

Mọi chiến lược phải dùng chung RiskGuard. Không dựa vào riêng strategy để tự kiểm soát rủi ro.

- `MaxSpreadPoints`: chặn trạng thái giá không phù hợp.
- `MaxVirtualPositions`: số vị thế ảo tối đa.
- `MaxGridLevels`: số tầng tối đa.
- `MaxDcaAdds`: số lần bổ sung tối đa.
- `MaxVirtualExposure`: tổng khối lượng ảo hoặc đại lượng phơi nhiễm chuẩn hóa.
- `MaxDailyLossPct`: giới hạn lỗ mô phỏng trong ngày.
- `MaxDrawdownPct`: giới hạn drawdown từ equity peak mô phỏng.
- `CooldownBars`: giảm lặp trigger quá dày.
- `RequireValidPrice/Indicators`: không dùng dữ liệu chưa sẵn sàng.
- `KillSwitch`: chặn tạo virtual position mới và ghi lý do.

Config phải nêu rõ phần trăm là theo equity đầu ngày, initial virtual balance hay peak equity. Không cho mỗi EA tự định nghĩa mẫu số khác nhau.

## 2. Metrics báo cáo

- Gross/net P&L mô phỏng và modeled costs.
- Maximum drawdown theo equity, không chỉ closed balance.
- Peak virtual exposure, peak number of positions/levels/additions.
- Số lần RiskGuard chặn; số bar ở `BLOCKED`/`HALTED`.
- Số trade ảo, average win/loss, expectancy; profit factor khi mẫu số có nghĩa.
- Kết quả theo thời gian và theo chế độ thị trường nếu có labels hợp lệ.

Không xếp hạng chiến lược chỉ theo tổng P&L. Báo cáo phải có cảnh báo về số mẫu, chi phí giả định, độ nhạy tham số và các giai đoạn kiểm thử.

## 3. Chia dữ liệu

- Chia theo thời gian, không shuffle ngẫu nhiên cho bài toán chuỗi thời gian.
- Dùng train/validation/test hoặc walk-forward.
- Không dùng out-of-sample test để tối ưu tham số.
- Không cho dữ liệu tương lai lọt vào indicator/features (look-ahead leakage).
- Lưu source revision + config hash + dữ liệu/phạm vi + modelling mode cho mỗi run.

## 4. Stress scenarios

1. Sideways/range.
2. Trend kéo dài một chiều chống lại vị thế.
3. Volatility tăng mạnh.
4. Spread widen và cost sensitivity.
5. Gap qua stop/target hoặc nhiều grid levels.
6. Thiếu bars, timestamp bất thường, indicator chưa warm up.
7. Exposure/daily loss/drawdown đạt ngưỡng đúng tại biên.
8. Giả định slippage thấp/trung bình/cao — chỉ là kịch bản kiểm thử, không phải dự báo thực tế.

## 5. Test cases bắt buộc

- Long trailing SL không giảm; short trailing SL không tăng.
- Grid không vượt max levels/exposure dù nhiều trigger cùng lúc.
- DCA không add khi `MaxDcaAdds` hoặc risk cap đã đạt.
- Kill switch chặn mọi entry virtual tiếp theo.
- P&L, weighted average entry và costs khớp các ví dụ tính toán bằng tay/Python.
- Config ngoài `SIMULATION_ONLY` bị validator từ chối.
- Source MQL5 bị từ chối khi phát hiện trade request APIs.
- Rerun cùng dữ liệu/config tạo kết quả có thể tái lập trong giới hạn của modelling mode.

## 6. Cảnh báo diễn giải

Backtest không mô phỏng hoàn hảo spread biến đổi, gap, slippage, latency, khối lượng khớp, thay đổi điều kiện sản phẩm hoặc mọi hành vi server. Grid/DCA có thể tạo ra chuỗi vị thế lớn; trailing stop không bảo đảm fill tại mức stop. Báo cáo phải gọi kết quả là **mô phỏng**, không phải cam kết hiệu quả hay lời khuyên giao dịch.
