# Roadmap chi tiết — MT5 EA Lab: Grid, DCA, Runner Trailing

## 0. Mục tiêu và ranh giới

Xây dựng dự án độc lập cho MetaTrader 5, ưu tiên MQL5 để có thể compile và chạy EA trong Strategy Tester. Python dùng để kiểm tra cấu hình, phân tích báo cáo và kiểm thử logic độc lập.

**Ba EA mô phỏng cần xây dựng:**

1. `GridLabEA.mq5`: mô phỏng grid có giới hạn mức và tổng mức phơi nhiễm.
2. `DCALabEA.mq5`: mô phỏng các lần bổ sung DCA có giới hạn, không bình quân vô hạn.
3. `RunnerTrailingLabEA.mq5`: mô phỏng một vị thế, hòa vốn và trailing stop; mục tiêu là để lợi nhuận chạy khi điều kiện còn phù hợp, không hứa hẹn lợi nhuận “vô cực”.

Tất cả EA trong roadmap này là **SIMULATION_ONLY**: mô hình hóa vị thế ảo và kết quả trên dữ liệu tester, không gửi lệnh broker. Không triển khai adapter live, không có nút bật live, không dùng `CTrade`, `OrderSend`, `OrderSendAsync`, `MqlTradeRequest` hay các API đặt/sửa/đóng lệnh thật. Không thêm hướng dẫn đăng nhập môi giới hoặc bật giao dịch bằng tiền thật.

## 1. Công nghệ

- Windows 11.
- MetaTrader 5 Desktop cùng MetaEditor 5 để biên dịch và Strategy Tester để chạy mô phỏng.
- MQL5 cho các EA mô phỏng, tham số `input`, nhật ký và kiểm tra điều kiện.
- Python 3.11 64-bit cho validator, phân tích kết quả và unit tests.
- pytest, pandas, NumPy, matplotlib. Chỉ bổ sung scikit-learn khi phase AI nghiên cứu được duyệt.
- Git để quản lý phiên bản.

## 2. Nguyên tắc kiến trúc

- Tách `Signal/Strategy`, `VirtualPortfolio`, `RiskGuard`, `CostModel`, `Logger`.
- Không gọi API gửi lệnh thật ở bất kỳ nhánh code nào.
- Một bộ `RiskGuard` dùng chung tiêu chuẩn giới hạn cho tất cả chiến lược.
- Mọi chiến lược đều có `MaxLevels`, `MaxVirtualExposure`, `MaxDrawdownPct`, `MaxDailyLossPct`, `MaxSpreadPoints` và công tắc dừng mô phỏng.
- Mặc định an toàn; không tự động nới giới hạn khi hết vốn mô phỏng hoặc tới giới hạn thua lỗ.
- Không tối ưu trên tập kiểm tra cuối cùng; giữ nguyên tập out-of-sample.
- Log có cấu trúc, có phiên bản strategy/config và timestamp.

## 3. Các phase và tiêu chí nghiệm thu

### Phase 0 — Khảo sát môi trường và khởi tạo repository

**Việc làm**
- Kiểm tra Git, Python, MetaEditor path và quyền ghi vào thư mục dự án.
- Đọc cấu trúc repo trước khi sửa; không ghi đè file người dùng chưa commit.
- Khởi tạo README, config mẫu và checklist.

**Nghiệm thu**
- Có `docs/INSTALL_AND_TEST.md` và `docs/ARCHITECTURE.md`.
- Script kiểm tra môi trường chạy được, báo lỗi cụ thể khi thiếu công cụ.
- Không có code giao dịch thật.

### Phase 1 — Dựng nền tảng kiểm thử

**Việc làm**
- Tạo hàm chuẩn hóa input và kiểm tra `OnInit`.
- Tạo logger dạng CSV/TSV hoặc log journal có schema cố định.
- Tạo `VirtualPosition`/`VirtualPortfolio` chỉ tính toán trong bộ nhớ.
- Viết Python schema validator, unit-test runner và report directory.

**Nghiệm thu**
- Các input sai (âm, NaN, mức tối đa bằng 0, mức tối đa thấp hơn mức cơ sở) bị từ chối rõ ràng.
- Test tự động qua; chưa mô phỏng chiến lược phức tạp.

### Phase 2 — Core RiskGuard và CostModel

**RiskGuard cần kiểm tra**
- Mức spread mô phỏng tối đa.
- Giới hạn số vị thế ảo/tầng grid/lần DCA.
- Giới hạn tổng exposure ảo, daily loss, drawdown.
- Cooldown và khung giờ mô phỏng.
- Dữ liệu giá lỗi/stale hoặc chỉ báo chưa sẵn sàng.
- Kill switch: chuyển sang `HALTED`, ngừng tạo vị thế ảo mới và ghi rõ lý do.

**CostModel**
- Mô phỏng spread, commission, swap nếu có input dữ liệu hợp lệ và slippage giả lập.
- Ghi riêng giả định và nguồn dữ liệu; không tuyên bố mô phỏng khớp lệnh chính xác như broker.

**Nghiệm thu**
- Unit test cho từng giới hạn.
- Các giới hạn không bị bỏ qua bởi chiến lược con.
- Drawdown và daily loss tính bằng equity mô phỏng, không chỉ dựa vào vị thế đã đóng.

### Phase 3 — `RunnerTrailingLabEA.mq5`

**Tính năng mô phỏng**
- Tối đa một vị thế ảo.
- Input hướng long/short hoặc chế độ chỉ log tín hiệu; không tự động gửi lệnh thật.
- SL ban đầu mô phỏng; điều kiện hòa vốn; trailing cố định hoặc ATR.
- Với vị thế long, SL chỉ được giữ nguyên hoặc nâng lên; với short, SL chỉ được giữ nguyên hoặc hạ xuống.
- Ghi mọi lần đề xuất cập nhật SL, lý do và mức SL trước/sau.
- Có chế độ giả lập gap/slippage để minh họa việc stop không đảm bảo khớp đúng giá.

**Nghiệm thu**
- Test đơn điệu của trailing stop cho long/short.
- SL không được đặt sai phía so với giá theo quy tắc mô phỏng.
- Không được xóa SL hoặc nới SL để che lỗ.

### Phase 4 — `GridLabEA.mq5`

**Tính năng mô phỏng**
- Khoảng grid cố định hoặc dựa trên ATR.
- Lựa chọn hướng mô phỏng, spacing, số tầng tối đa, volume ảo cơ sở và hệ số tăng (mặc định 1.0; nếu bật hệ số tăng phải chịu hard cap).
- Chốt lời từng mức hoặc mục tiêu basket mô phỏng.
- Thoát khẩn cấp theo drawdown/exposure; dừng tạo tầng khi đạt cap.
- Log từng tầng: giá kích hoạt giả lập, kích thước ảo, exposure cộng dồn và lý do mở/đóng.

**Nghiệm thu**
- Không bao giờ vượt `MaxGridLevels` hay `MaxVirtualExposure`.
- Tính cả vị thế đã vào nhưng chưa đóng trong exposure.
- Backtest có spread, chi phí giả lập và kiểm thử giai đoạn xu hướng mạnh một chiều.

### Phase 5 — `DCALabEA.mq5`

**Tính năng mô phỏng**
- DCA theo khoảng giá hoặc khoảng thời gian; tùy chọn bộ lọc tín hiệu chỉ để nghiên cứu.
- Hard cap số lần bổ sung, tổng exposure và tổng drawdown.
- Tính giá vốn trung bình ảo, P&L basket, ngưỡng dừng và điều kiện thoát.
- Không dùng “gồng vô hạn”, không tự tăng giới hạn sau khi lỗ.

**Nghiệm thu**
- Không thêm vị thế ảo khi chạm bất kỳ hard cap nào.
- Test với giá tiếp tục đi ngược liên tục; RiskGuard phải chặn bổ sung vượt cap.
- P&L basket khớp phép tính độc lập bằng Python trên bộ test nhỏ.

### Phase 6 — Hệ thống preset và cấu hình

- Tất cả tham số quan trọng xuất hiện thành `input` MQL5, có chú thích đơn vị.
- Tạo preset kiểm thử riêng theo strategy/symbol/timeframe, không nhúng sẵn thông tin tài khoản.
- Tạo `configs/project.example.json`; validator chỉ nhận `execution_mode=SIMULATION_ONLY` và `allow_live_trading=false`.
- Lưu snapshot config vào mỗi báo cáo; không ghi đè kết quả cũ.

**Nghiệm thu**: có ví dụ cấu hình baseline, conservative stress, và edge-case test; đây là cấu hình kiểm thử, không phải khuyến nghị giao dịch.

### Phase 7 — Script build/test/report

- `check-environment.ps1`: kiểm tra Python, pytest, MetaEditor path và folder.
- `build-mql5.ps1`: compile tất cả EA `.mq5`, lưu log riêng từng file và trả exit code khác 0 khi lỗi.
- `run-python-tests.ps1`: chạy pytest và lưu kết quả.
- `validate-project.py`: xác thực config và quét nguồn MQL5 nhằm chặn API gửi lệnh thật.
- `package-source.ps1`: đóng gói docs/source/script/config, loại `.venv`, raw datasets và log nhạy cảm.
- Báo cáo tổng hợp compile, test, file log và những bước cần thao tác thủ công trong Strategy Tester.

**Nghiệm thu**: script không được báo build thành công nếu MetaEditor không chạy hoặc không có log hợp lệ.

### Phase 8 — Backtest và stress testing trong MT5

- Chạy mỗi EA trong Strategy Tester, bắt đầu visual mode để kiểm tra logic.
- Thử các chế độ dữ liệu phù hợp; ưu tiên real ticks khi có sẵn và tài nguyên cho phép.
- Lưu khoảng thời gian, timeframe, symbol, spread/cost assumptions, model mode và thông số vào báo cáo.
- Kiểm tra giai đoạn sideway, trend một chiều, biến động cao, spread lớn và gap.
- Dùng forward/out-of-sample; không lựa chọn mô hình chỉ bằng lợi nhuận cao nhất.

**Nghiệm thu**: mỗi chiến lược có report, logs, test case, giới hạn đã đạt/chạm và danh sách rủi ro còn tồn tại.

### Phase 9 — Báo cáo và bàn giao

- Báo cáo P&L mô phỏng, max drawdown, exposure peak, số tầng tối đa, chi phí ước lượng, số lần bị RiskGuard chặn và thời gian ở trạng thái HALTED.
- Tạo hướng dẫn cài đặt, build, chọn EA trong Strategy Tester, nạp preset, xem Journal và khắc phục lỗi.
- README chỉ rõ phần nào đã xác minh tự động, phần nào cần xác minh trong giao diện MT5.

**Nghiệm thu cuối**
- Tất cả Python tests pass.
- Tất cả `.mq5` compile thành công trong MetaEditor khả dụng.
- Validator pass; không có API gửi lệnh thật trong source.
- Hướng dẫn có thể làm lại từ môi trường sạch.

## 4. Quy trình AI coding agent

1. Đọc toàn bộ roadmap/prompt/docs trước khi sửa.
2. Kiểm tra repository, Git status và tool availability.
3. Chỉ triển khai một phase mỗi lượt.
4. Trước khi kết thúc phase: chạy formatter/linter nếu đã cài, Python tests, config validator và compile nếu MetaEditor có sẵn.
5. Cập nhật `docs/PROGRESS.md`, ghi rõ test chạy được và test bị block.
6. Không bịa kết quả hoặc giả vờ đã chạy Strategy Tester nếu chưa thật sự mở/kiểm tra được MT5.
7. Không tự chuyển sang phase tiếp nếu chưa báo cáo nghiệm thu.

## 5. Lưu ý

Grid và DCA có thể tích lũy rủi ro đáng kể trong xu hướng kéo dài; trailing stop cũng không thể bảo đảm thoát ở đúng mức khi có gap hoặc độ trượt giá. Chỉ số trong backtest là kết quả mô phỏng, không phải cam kết lợi nhuận hoặc hiệu quả trong tương lai.
