# Thư Mục Cấu Hình Bot (Configurations) — MT5 EA & AI Lab

Thư mục này chứa toàn bộ các file preset cấu hình chuẩn (`.set`) có chú thích đầy đủ bằng **tiếng Việt có dấu**, giải thích cặn kẽ từng thông số `input` cho các Expert Advisor (EA) trong dự án `tm-fx`.

---

## 1. Danh Sách Các File Cấu Hình

| Tên File | Dành Cho Bot | Chiến Lược & Đặc Điểm |
| :--- | :--- | :--- |
| [`infinite_runner_v2.set`](file:///docs/configurations/infinite_runner_v2.set) | `InfiniteRunnerXAUV2DemoEA.mq5` | **Trend Following & Runner**: Đã cấu hình `InpDirectionMode = 0` (Legacy EMA), `InpLotMode = 0` (0.01 lot), `InpBreakEvenTriggerR = 0.0` (trailing chạy sớm từ 3000 points / 3 USD), `InpCooldownMinutes = 0` (par với V1 giúp nắm trọn trend). |
| [`pa_trendrider_xau.set`](file:///docs/configurations/pa_trendrider_xau.set) | `PATrendRiderXAUv1DemoEA.mq5` | **Price Action Đa Khung Thời Gian**: H1 bias, M15 structure, M5 BOS/Pullback confirmation. 1 vị thế duy nhất, SL/TP theo cấu trúc, tỷ lệ R:R 1:3. |
| [`grid_demo.set`](file:///docs/configurations/grid_demo.set) | `GridDemoEA.mq5` | **Bounded Grid**: Lưới giá có chặn cận trên/dưới (`InpMaxGridLevels = 5`), trần volume per-level, basket SL/TP bảo vệ tài khoản, không gồng lỗ vô hạn. |
| [`dca_demo.set`](file:///docs/configurations/dca_demo.set) | `DCADemoEA.mq5` | **Bounded DCA**: Bình quân giá có kiểm soát rủi ro (`InpMaxDcaAdds = 3`), bắt buộc có basket stop loss, trần tổng exposure và drawdown cap. |

---

## 2. Hướng Dẫn Tải (Load) File Cấu Hình Trong MT5 Strategy Tester

Để sử dụng các file cấu hình `.set` này khi chạy backtest hoặc demo trong MetaTrader 5:

1. **Mở Strategy Tester trong MT5**:
   - Nhấn tổ hợp phím **`Ctrl + R`** trên bàn phím.
2. **Chọn EA và Cặp Tiền**:
   - Chọn Expert Advisor bạn muốn test (ví dụ: `InfiniteRunnerXAUV2DemoEA.ex5` hoặc `PATrendRiderXAUv1DemoEA.ex5`).
   - Symbol: `XAUUSDm` (hoặc `XAUUSD` tùy broker).
   - Timeframe: `M5` (hoặc `M15` theo chiến lược).
3. **Load Cấu Hình `.set`**:
   - Chuyển sang tab **Inputs** (Các tham số đầu vào).
   - Nhấp **chuột phải** vào bất kỳ vị trí nào trong bảng Inputs.
   - Chọn **Load** (hoặc **Tải thiết lập...**).
   - Chọn file `.set` tương ứng (Ví dụ: `infinite_runner_v2.set`). Các file này đã được tự động đồng bộ vào thư mục `MQL5/Profiles/Tester/` của MT5.
4. **Bắt Đầu Test**:
   - Nhấn nút **Start** để tiến hành kiểm thử.

---

## 3. Lưu Ý Đặc Biệt Về Môi Trường & Giới Hạn Thực Thi (Safety Boundary)

- **Chỉ Chạy Demo / Strategy Tester**: Theo quyết định thiết kế kiến trúc (`ADR 0003` và `ADR 0004`), tất cả các bot trong lab đều được lập trình với cơ chế bảo vệ nghiêm ngặt: **từ chối hoàn toàn tài khoản Real/Live** ngay tại hàm `OnInit()`.
- **Đơn Vị Point Trên Vàng (XAUUSD)**:
  - Trên các sàn như Exness, tài khoản tiêu chuẩn có 3 chữ số thập phân (`digits = 3`, ví dụ `2750.125`).
  - **1000 points = 1.0 USD** giá vàng. Do đó, 3000 points tương đương 3.0 USD di chuyển của giá vàng.
- **Trạng Thái Reset Khi Chạy Lại (InpResetStateOnInit)**:
  - Khi bắt đầu một đợt test mới, hãy bật `InpResetStateOnInit = true` để EA xóa các file trạng thái cũ (`*_state.csv`), đảm bảo bot không bị vướng các trạng thái khóa tạm thời (drawdown lock) từ phiên kiểm thử trước.
