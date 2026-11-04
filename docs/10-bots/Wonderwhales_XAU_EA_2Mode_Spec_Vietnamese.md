# WONDERWHALES XAU — ĐẶC TẢ CHUẨN HÓA EA HAI CHẾ ĐỘ
**Phiên bản tài liệu:** 2.2  
**Nền tảng:** MetaTrader 5 / MQL5  
**Sản phẩm ưu tiên:** XAUUSD / XAUUSDm  
**Mục tiêu:** Bảo toàn vốn trước, kiểm soát rủi ro và trailing SL có quy tắc; chưa giả định EA có lợi nhuận.

---

## 0. Trạng thái và phạm vi tài liệu

Tài liệu này là đặc tả kỹ thuật nâng cấp EA Wonderwhales thành một EA có hai chế độ giao dịch độc lập:

1. **SCALP M1–M5–M15:** giao dịch ngắn, SL/TP ngắn, ưu tiên chi phí giao dịch thấp và bảo vệ vốn.
2. **SWING H1–D1–W1:** giao dịch theo xu hướng lớn, SL/TP rộng hơn, giữ lệnh lâu hơn và chỉ dời SL về hòa vốn khi cấu trúc/lợi nhuận đủ xác nhận.

### Những gì đã được kiểm tra từ tài liệu nguồn

- Pine Script `Wonderwhales.pine` là indicator Pine Script v6, phiên bản 1.2.0.
- Logic tín hiệu chính có các lựa chọn:
  - Parabolic SAR Reversal.
  - EMA Crossover.
  - SAR + EMA Trend Filter.
  - SAR + EMA + ATR Filter.
- Tín hiệu BUY/SELL xuất hiện khi hướng PSAR chuyển trạng thái; tùy chọn xác nhận nến đóng đang mặc định bật.
- EMA 20/50 và EMA200 có thể làm bộ lọc xu hướng.
- ATR% có thể làm bộ lọc biến động.
- VSA Volume, RSI và Bollinger Bands chủ yếu đang được tính để hiển thị/dashboard; trong logic tín hiệu của Pine hiện tại, chúng không phải điều kiện bắt buộc để tạo BUY/SELL.
- Tài liệu `wonderwhales.md` mô tả EA demo hiện tại dùng `iCustom`, đọc tín hiệu tại `shift=1`, có một vị thế theo magic, có SL/TP bắt buộc và chưa có BE/trailing trong v1.
- Kết quả tester được ghi nhận trong tài liệu nguồn: 41 giao dịch, 11 thắng, 30 thua, net -625.72 trong khoảng 2026-01-05 đến 2026-01-15 trên XAUUSDm M15; đã chạm daily-loss và max-drawdown guard. Trạng thái đang là `UNPROVEN`; parity Pine ↔ MQL5 chưa được xác nhận.

### Giới hạn hiện tại

Chưa có các file triển khai MT5 sau trong gói đính kèm hiện tại:

- `mt5/Experts/WonderwhalesDemoEA.mq5`
- `mt5/Include/PinePort/WonderwhalesContract.mqh`
- `mt5/Indicators/PinePort/Wonderwhales.mq5`
- `mt5/Include/Exec/ExecGuard.mqh`
- `mt5/Include/Exec/ExecBroker.mqh`
- `mt5/Include/Sim/SimRiskGuard.mqh`
- `mt5/Include/Sim/SimLogger.mqh`

Do đó, tài liệu này **không tuyên bố đã sửa/compile EA**. Không được tự đoán số buffer, kiểu dữ liệu, thứ tự buffer hoặc API trong các file còn thiếu. Khi triển khai phải mở mã nguồn thật và xác minh contract trước.

### Thay đổi gần nhất

- **2026-11-04 — phiên bản 2.1:** **bỏ hạn mức số lệnh/ngày** cho cả hai chế độ. `Scalp_ToiDaLenhMoiNgay`
  và `Swing_ToiDaLenhMoiNgay` mặc định `0` (**không giới hạn**). Số lệnh vẫn bị chặn **gián tiếp** bởi
  các guard: lỗ tối đa ngày/tuần, drawdown, chuỗi thua liên tiếp, thời gian nghỉ sau lệnh thua, spread,
  và giới hạn một vị thế đồng thời — không còn bị chặn bởi một bộ đếm lệnh cứng.
- **2026-11-04 — phiên bản 2.1:** thêm mục **"Trailing SL cho Scalp — quy tắc đưa SL theo"** (§2.1) và hai
  input thử nghiệm `BatTrailingBuoc` / `BuocTrailing_Points` (§6.6); làm rõ thứ tự ứng viên SL và các
  quy tắc không nới SL, tính R từ initial SL, khoảng cách sửa SL tối thiểu.
- **2026-11-04 — phiên bản 2.2 (chốt S1–S4):**
  - **S1 — một magic.** Dùng **một magic duy nhất `25008001`** cho cả bot; Scalp và Swing là hai chiến
    lược *bên trong cùng một bot*. **Mode của từng lệnh được lưu trong state lúc vào lệnh**, không phụ
    thuộc `CheDoGiaoDich` đang chọn khi EA khởi động lại.
  - **S2 — cổng parity.** Parity Pine↔MT5 là **điều kiện chặn mở lệnh**: chưa đạt parity thì không vào
    lệnh; kết quả giao dịch khi bỏ qua parity **không** phải kết quả chiến lược hợp lệ (xem §5.4).
  - **S3 — mặc định.** `CheDoGiaoDich=SCALP_M1_M5_M15` + `BatGuiLenh=true` (theo ADR 0006) +
    `ChiGiaoDichTaiKhoanDemo=true` (chặn tài khoản thật).
  - **S4 — nhật ký.** Giữ **nguyên hợp đồng 18 cột** mà watcher/validator đang dùng; dữ liệu mở rộng
    (MAE/MFE, R, loại trailing, EMA/PSAR từng khung) ghi vào **file telemetry riêng** (xem §9).

---

# 1. Nguyên tắc thiết kế

## 1.1. Thứ tự ưu tiên

1. Không để một lệnh thua xóa lợi nhuận của nhiều lệnh thắng.
2. Không tăng lot để gỡ lỗ.
3. Không grid, không DCA, không martingale, không nhồi lệnh khi đang âm.
4. Luôn đặt SL bảo vệ ngay khi mở vị thế.
5. Khối lượng phải tính theo số tiền có thể mất tại SL, không dùng lot cố định làm mặc định.
6. Không dời SL ra xa hơn để “cho lệnh thở”.
7. Chỉ dùng tín hiệu của nến đã đóng (`shift=1`).
8. Không mở lệnh mới khi spread, rủi ro ngày/tuần hoặc trạng thái tài khoản không đạt yêu cầu.
9. Mặc định chạy quan sát/mô phỏng hoặc demo; không bật giao dịch tài khoản thật.
10. Chỉ đánh giá kết quả bằng dữ liệu ngoài mẫu và forward demo, không dựa riêng vào winrate.

## 1.2. Mô hình chạy

Một EA duy nhất có input `CheDoGiaoDich`:

- `CHI_BAO_TIN_HIEU`: chỉ tính tín hiệu và ghi log, không gửi lệnh.
- `SCALP_M1_M5_M15`: chỉ chạy chiến lược Scalping.
- `SWING_H1_D1_W1`: chỉ chạy chiến lược Swing.

**Mặc định:** `CheDoGiaoDich=SCALP_M1_M5_M15`, `BatGuiLenh=true`, `ChiGiaoDichTaiKhoanDemo=true`.

- `BatGuiLenh=true` theo ADR 0006 (EA demo mặc định **bật** execution); **chặn tài khoản real** bởi
  `ChiGiaoDichTaiKhoanDemo=true` (mọi tài khoản không phải demo/tester → `INIT_FAILED`).
- `CHI_BAO_TIN_HIEU` vẫn là chế độ chọn được để **quan sát tín hiệu** trên chart, nhưng **không phải**
  mặc định (đó là dry-run có chủ đích, tương đương `BatGuiLenh=false`).
- **Cổng parity** (xem §5.4): parity Pine↔MT5 chưa đạt → **chặn mở lệnh** ở cả Scalp và Swing.

Không chạy đồng thời Scalp và Swing trên cùng tài khoản trong giai đoạn đầu. Sau khi hai chế độ đã được kiểm định riêng, mới nghiên cứu chạy đồng thời với ngân sách rủi ro tổng hợp.

---

# 2. Định nghĩa hai phương pháp giao dịch

## 2.1. Chế độ A — SCALP M1 / M5 / M15

### Mục tiêu

Bắt các nhịp ngắn theo hướng xu hướng chính trong ngày. Không cố bắt đỉnh/đáy lớn. Mỗi lệnh phải có SL rõ ràng và TP vừa phải.

### Phân công timeframe

| Khung | Vai trò | Điều kiện chính |
|---|---|---|
| M15 | Bộ lọc xu hướng | EMA20/EMA50 và vị trí giá so với EMA200; xác định chỉ ưu tiên BUY hay SELL |
| M5 | Khung setup | Wonderwhales PSAR flip theo hướng M15; EMA20/50 không ngược xu hướng |
| M1 | Khung kích hoạt | Chờ nến đóng và xác nhận động lượng/PSAR theo hướng setup M5 |

Không được lấy tín hiệu M1 độc lập để giao dịch ngược M15. M1 chỉ là khung kích hoạt, không phải bộ quyết định xu hướng.

### Quy tắc BUY đề xuất

1. M15: EMA20 > EMA50 và giá đóng cửa nằm trên EMA200.
2. M5: PSAR chuyển từ phía trên giá xuống dưới giá trên nến đã đóng; EMA20 không thấp hơn EMA50.
3. M1: xác nhận BUY trên nến đã đóng; không mua nếu giá đã chạy quá xa khỏi vùng setup.
4. Spread đạt điều kiện.
5. SL cấu trúc hợp lệ và khối lượng tính ra không vượt ngân sách rủi ro.
6. Không có vị thế hoặc lệnh chờ khác do EA quản lý trên XAUUSD.

### Quy tắc SELL

Đảo ngược các điều kiện BUY:

1. M15: EMA20 < EMA50 và giá đóng cửa nằm dưới EMA200.
2. M5: PSAR flip xuống hướng SELL trên nến đã đóng; EMA20 không cao hơn EMA50.
3. M1: xác nhận SELL trên nến đã đóng.
4. Tất cả kiểm tra spread, SL, khối lượng và giới hạn rủi ro đều đạt.

### SL ban đầu cho Scalp

Ưu tiên SL theo cấu trúc giá, không đặt một khoảng points cố định cho mọi thời điểm:

- BUY: dưới swing low M5 đã xác nhận gần nhất, cộng buffer theo ATR M5.
- SELL: trên swing high M5 đã xác nhận gần nhất, cộng buffer theo ATR M5.
- Buffer khởi điểm đề xuất: `0.20 × ATR(M5)`.
- Nếu không tìm được swing hợp lệ, có thể dùng `1.2 × ATR(M5)` làm phương án dự phòng.
- Không vào lệnh nếu SL quá rộng so với ngưỡng tối đa hoặc quá gần khiến broker không chấp nhận.
- Không tự động kéo SL lại gần chỉ để tăng lot.

Thông số thử nghiệm ban đầu:
- SL dự phòng: `1.2 × ATR(M5)`.
- TP: `1.5R`.
- R là khoảng cách từ giá vào lệnh đến SL ban đầu.
- Nếu vùng cản gần nhất khiến RR thực tế thấp hơn `1.2R`, bỏ qua giao dịch.

### Break-even và trailing cho Scalp

| Điều kiện | Hành động |
|---|---|
| Lệnh chưa đạt +1.0R | Giữ SL ban đầu; không trailing sát |
| Đạt +1.0R và nến M5 đóng cùng hướng | Dời SL về Entry + chi phí dự kiến đối với BUY; Entry - chi phí đối với SELL |
| Đạt +1.3R | Cho phép trailing cấu trúc M5 hoặc PSAR M5 |
| Có swing mới được xác nhận | Chỉ dời SL theo swing mới, không dời theo swing chưa hoàn tất |
| Tín hiệu PSAR ngược chiều M5 đã đóng | Có thể thoát sớm nếu bật tùy chọn; phải kiểm thử riêng |

Không dùng Step Trailing quá sát theo từng tick. Không dời SL về Entry ngay khi lệnh vừa xanh một chút. Đây là điểm quan trọng để tránh tình trạng nhiều lệnh bị hòa vốn quá sớm nhưng lệnh thua vẫn mất đủ SL.

### Trailing SL cho Scalp — quy tắc "đưa SL theo" (chi tiết)

Mục tiêu: sau khi lệnh đã có lợi nhuận, **dời SL theo giá** để khóa lợi nhuận — nhưng **không bao giờ nới SL**
và không siết quá sát làm lệnh hòa vốn quá sớm.

**Thứ tự ứng viên SL (tính tất cả, chọn mức bảo vệ tốt nhất — theo quy tắc chung §4):**

| Ưu tiên | Ứng viên | Điều kiện kích hoạt | Mức SL đề xuất cho BUY | Mặc định |
|---|---|---|---|---|
| 1 | Hòa vốn (BE) | Đạt `Scalp_KichHoatBE_R` = 1.0R và nến M5 đóng cùng hướng | `Entry + buffer chi phí` | Bật |
| 2 | Trailing cấu trúc (swing M5) | Đạt `Scalp_KichHoatTrailing_R` = 1.3R | `swing low M5 đã xác nhận − Scalp_BufferSwing_ATR × ATR(M5)` | Bật |
| 3 | Trailing PSAR M5 | Đạt 1.3R và `BatTrailingPSAR=true` | `PSAR(M5) của nến đã đóng` | Tắt (nhánh thử nghiệm) |
| 4 | Trailing ATR M5 | Đạt 1.3R và `BatTrailingATR=true` | `Bid − Trailing_Buffer_ATR × ATR(M5)` | Tắt (nhánh thử nghiệm) |
| 5 | Trailing bước (step) | Đạt 1.3R và `BatTrailingBuoc=true` | `SL cũ + BuocTrailing_Points` | Tắt (nhánh thử nghiệm) |

SELL đảo dấu tương ứng (SL trên các mức đối xứng).

**Quy tắc bắt buộc:**

1. BUY: SL mới chỉ được **tăng**; SELL: SL mới chỉ được **giảm**. Không nới SL trong bất kỳ trường hợp nào.
2. Mọi ứng viên SL lấy từ **nến M5 đã đóng** (`shift ≥ 1`); không dùng PSAR/swing của nến đang chạy.
3. R dùng để kích hoạt luôn tính từ **initial SL** đã lưu — **không** tính lại theo SL đã trailing.
4. Chỉ gửi yêu cầu sửa SL khi mức mới cải thiện ít nhất `KhoangCachToiThieuSuaSL_Points` (mặc định 50)
   so với SL hiện tại, để tránh sửa liên tục.
5. Mọi mức SL mới phải qua kiểm tra stop level / freeze level / tick size / khoảng cách spread của broker.
6. Nếu broker từ chối sửa, **giữ SL cũ**, ghi mã lỗi; không tuyên bố đã bảo vệ thành công.
7. Không sửa TP ngoài ý muốn khi đang gửi yêu cầu sửa SL.
8. Không bật đồng thời nhiều cơ chế step/PSAR/ATR khi chưa so sánh riêng từng nhánh (xem §10 giai đoạn 3).

**Cảnh báo về step trailing quá sát:** XAUUSD nhiễu ngắn hạn; step trailing nhỏ dễ bị quét sớm làm giảm
Average Win. Giai đoạn đầu **chỉ dùng BE + trailing cấu trúc**; các nhánh step/PSAR/ATR mở riêng từng lượt
backtest và so sánh với phương án "không trailing" (xem §4.4), không bật tất cả cùng lúc.

> Ghi chú triển khai: tên input trong mã nguồn sẽ dùng quy ước dự án (`Inp` + PascalCase, token tiếng Anh)
> theo `docs/10-bots/input-convention.md`; các tên trong tài liệu này là nhãn thiết kế.

### TP cho Scalp

- Mặc định: `1.5R`.
- Có thể kiểm thử riêng `1.2R`, `1.5R`, `1.8R`.
- Không tối ưu hàng chục mức cùng lúc.
- Trong giai đoạn đầu không dùng partial close để giảm độ phức tạp; sau khi có thống kê mới thử đóng một phần tại `1R` hoặc `1.2R`.

### Giới hạn giao dịch Scalp

- **Không giới hạn số lệnh/ngày.** Số lệnh bị chặn gián tiếp bởi risk guard (lỗ ngày/tuần, drawdown,
  chuỗi thua, thời gian nghỉ sau lệnh thua, spread) chứ không bởi một hạn mức đếm lệnh cứng.
- Một vị thế tại một thời điểm.
- Nghỉ ít nhất 20 phút sau một lệnh thua.
- Không mở lệnh mới nếu spread vượt ngưỡng hoặc spread lớn hơn 10% khoảng SL dự kiến.
- Tạm dừng nếu có 2 lệnh thua liên tiếp trong ngày.
- Tránh thời điểm rollover và thời điểm spread giãn bất thường.
- Bộ lọc phiên London/New York là tùy chọn; chỉ bật sau khi xác minh múi giờ server broker. Không hard-code giờ Việt Nam thành giờ server.

---

## 2.2. Chế độ B — SWING H1 / D1 / W1

### Mục tiêu

Giao dịch theo xu hướng chính kéo dài nhiều giờ hoặc nhiều ngày. Ít lệnh hơn Scalp, SL xa hơn nhưng lot nhỏ hơn tương ứng. Không dùng lot giống Scalp.

### Phân công timeframe

| Khung | Vai trò | Điều kiện chính |
|---|---|---|
| W1 | Xu hướng nền | EMA20/EMA50 và vị trí giá; xác định thiên hướng chính |
| D1 | Setup | EMA20/EMA50, EMA200, vùng cấu trúc hỗ trợ/kháng cự |
| H1 | Kích hoạt và quản lý | Wonderwhales PSAR flip cùng hướng W1/D1; kiểm tra nến đóng |

### Quy tắc BUY đề xuất

1. W1: EMA20 > EMA50 và giá đóng cửa W1 không nằm dưới EMA50.
2. D1: EMA20 > EMA50; ưu tiên giá nằm trên EMA200.
3. D1 không có vùng kháng cự lớn quá gần khiến RR không đủ.
4. H1: PSAR flip BUY trên nến đóng.
5. SL đặt dưới swing low H1 đã xác nhận gần nhất hoặc dưới vùng cấu trúc D1 phù hợp, có buffer ATR.
6. TP được xác định theo vùng kháng cự D1 tiếp theo hoặc theo R; bỏ qua lệnh nếu RR dự kiến không đạt tối thiểu.
7. Không BUY nếu W1 và D1 xung đột rõ ràng.

### Quy tắc SELL

Đảo ngược logic BUY:

1. W1: EMA20 < EMA50.
2. D1: EMA20 < EMA50; ưu tiên giá nằm dưới EMA200.
3. Xác định vùng hỗ trợ D1 tiếp theo.
4. H1 PSAR flip SELL trên nến đóng.
5. SL trên swing high H1 đã xác nhận hoặc vùng cấu trúc hợp lý.
6. TP ở vùng hỗ trợ D1 hoặc theo R.
7. Không SELL khi W1/D1 xung đột rõ ràng.

### SL ban đầu cho Swing

- Ưu tiên đặt sau swing H1 đã xác nhận, buffer `0.30 × ATR(H1)`.
- Nếu swing H1 quá gần hoặc không hợp lệ, dùng `2.0 × ATR(H1)` làm phương án dự phòng.
- Nếu cấu trúc D1 cho thấy điểm vô hiệu hóa nằm xa hơn, có thể dùng mức D1; khi đó phải tính lại volume theo đúng khoảng SL.
- Không cắt SL tùy tiện để đạt RR đẹp.
- Không vào lệnh nếu SL rộng đến mức volume tối thiểu của broker vượt ngân sách rủi ro.

### TP cho Swing

- Mặc định thử nghiệm: `2.5R`.
- TP cấu trúc: vùng hỗ trợ/kháng cự D1 gần nhất.
- Nếu vùng cấu trúc cho RR dưới `1.8R`, bỏ qua lệnh.
- Nếu dùng TP cấu trúc, không được đặt TP vượt qua vùng cản chỉ vì muốn đạt 2.5R.
- Có thể thử partial close 30–50% tại `1.5R` trong một nhánh backtest riêng; không bật mặc định ngay.

### Break-even và trailing cho Swing

| Điều kiện | Hành động |
|---|---|
| Dưới +1.0R | Giữ SL ban đầu; không dời SL về Entry |
| Đạt +1.2R và nến H1 đóng xác nhận cùng hướng | Dời SL về Entry cộng chi phí dự kiến (BUY) hoặc trừ chi phí (SELL) |
| Đạt +1.5R | Cho phép trailing theo swing H1 đã xác nhận |
| Xuất hiện swing H1 mới cùng hướng | Dời SL sau swing mới + buffer ATR |
| PSAR H1 đảo chiều trên nến đóng | Chỉ thoát theo tín hiệu đảo chiều nếu tùy chọn được bật |
| Giá chạm TP | Đóng theo TP broker |

Với Swing, không nên dời SL theo mỗi thay đổi PSAR trong nến đang chạy. Chỉ sử dụng PSAR/swing của nến H1 đã đóng. SL luôn chỉ được siết theo hướng có lợi.

---

# 3. Quản lý rủi ro — ưu tiên bảo toàn vốn

Các mức dưới đây là **mức khởi đầu thận trọng để kiểm thử**, không phải mức bảo đảm an toàn hay lợi nhuận.

## 3.1. Risk theo từng chế độ

Với vốn tham chiếu 1,000 USD đã trao đổi trước đây:

| Thông số | Scalp | Swing |
|---|---:|---:|
| Rủi ro mỗi lệnh | 0.15% | 0.25% |
| Số tiền rủi ro tham chiếu trên 1,000 USD | 1.50 USD | 2.50 USD |
| TP ban đầu để test | 1.5R | 2.5R |
| Số lệnh tối đa/ngày | Không giới hạn | Không giới hạn |
| Vị thế đồng thời | 1 | 1 |

Trong giai đoạn đầu nên chạy **một chế độ tại một thời điểm**. Không cộng hai ngân sách 0.15% và 0.25% thành quyền rủi ro mặc định.

Không nâng risk lên 0.5–1% chỉ vì winrate backtest cao. Chỉ xem xét tăng risk sau khi có forward test đủ dài, expectancy dương sau phí và drawdown nằm trong giới hạn.

## 3.2. Giới hạn tài khoản

| Giới hạn | Giá trị khởi điểm | Hành động |
|---|---:|---|
| Lỗ tối đa trong ngày | 1.0% Equity đầu ngày | Dừng mở lệnh mới đến ngày tiếp theo |
| Lỗ tối đa trong tuần | 2.0% Equity đầu tuần | Dừng đến tuần tiếp theo và yêu cầu kiểm tra |
| Drawdown từ đỉnh Equity | 5.0% | Khóa EA, yêu cầu người vận hành kiểm tra và reset thủ công |
| Lệnh thua liên tiếp | 2 Scalp / 2 Swing | Tạm dừng chế độ tương ứng |
| Vị thế đồng thời | 1 | Từ chối lệnh mới |
| Giao dịch thật | Tắt mặc định | Chỉ demo trong giai đoạn kiểm chứng |

Phải định nghĩa rõ:
- Daily loss được tính từ equity đầu ngày theo thời gian server broker.
- Weekly loss được tính từ equity đầu tuần theo thời gian server broker.
- Max drawdown được tính từ High-Water Mark của equity đã lưu bền vững.
- Phí commission, swap và floating P/L phải được tính trong risk guard.
- Khởi động lại MT5 không được làm mất trạng thái halt.
- Daily halt có thể tự mở lại vào ngày server mới; weekly halt mở lại đầu tuần server; max drawdown halt cần reset thủ công.

## 3.3. Tính khối lượng

Không sử dụng `InpLots=0.01` làm phương pháp tính lot mặc định.

Quy trình bắt buộc:

1. Tính giá vào lệnh dự kiến.
2. Tính SL theo cấu trúc/ATR.
3. Dùng `OrderCalcProfit()` để ước lượng tiền lỗ nếu mở 1 lot và giá chạm SL.
4. `TienRuiRoChoPhep = Equity × TyLeRuiRo / 100`.
5. `KhoiLuongTho = TienRuiRoChoPhep / abs(LossForOneLot)`.
6. Làm tròn volume **xuống** theo `SYMBOL_VOLUME_STEP`.
7. Kiểm tra `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, free margin và giới hạn exposure.
8. Nếu volume sau khi làm tròn nhỏ hơn volume tối thiểu, hoặc volume tối thiểu làm risk vượt ngân sách, **bỏ qua giao dịch**. Tuyệt đối không làm tròn lên để ép vào lệnh.

Phải tính lại risk sau khi chuẩn hóa SL theo tick size và sau khi kiểm tra `SYMBOL_TRADE_STOPS_LEVEL` / `SYMBOL_TRADE_FREEZE_LEVEL`.

## 3.4. Spread và chi phí

- Có ngưỡng spread tối đa theo points để chặn spread bất thường.
- Đồng thời kiểm tra `Spread / StopDistance`; mặc định không vào nếu spread lớn hơn 10% khoảng SL dự kiến.
- Tính commission dự kiến nếu broker cung cấp dữ liệu; cộng buffer chi phí vào mức hòa vốn.
- Không dùng một ngưỡng points chung cho mọi broker. XAUUSD, XAUUSDm có thể khác digits, contract size, tick size, tick value và spread.
- Khi khởi động, log ra symbol, digits, point, tick size, tick value, contract size, volume min/step/max, stop level và spread thực tế.

---

# 4. Quy tắc trailing SL chuẩn hóa

## 4.1. Nguyên tắc chung

1. SL ban đầu phải được đặt cùng lúc mở lệnh hoặc xử lý khẩn cấp nếu broker từ chối.
2. Mọi mức SL mới đều phải tốt hơn mức SL cũ.
3. BUY: SL mới chỉ được tăng.
4. SELL: SL mới chỉ được giảm.
5. Không để Step Trailing, ATR Trailing, PSAR Trailing và Structure Trailing ghi đè lẫn nhau theo thứ tự gọi.
6. Tính tất cả ứng viên SL, lọc điều kiện broker, chọn ứng viên bảo vệ tốt nhất.
7. Chỉ sửa lệnh khi mức SL mới cải thiện đủ khoảng tối thiểu để tránh gửi sửa lệnh liên tục.
8. Không sửa TP ngoài ý muốn khi gửi yêu cầu sửa SL.
9. Nếu broker từ chối sửa SL, giữ nguyên SL cũ, ghi mã lỗi và không tuyên bố đã bảo vệ thành công.

## 4.2. Thứ tự quản lý

Mỗi tick hoặc mỗi nến quản lý:

1. Kiểm tra kill switch và risk lock.
2. Xác định R từ SL ban đầu đã lưu, không lấy SL đã trailing làm R mới.
3. Kiểm tra điều kiện Break-even.
4. Tính Structure/PSAR/ATR trailing nếu đã đạt ngưỡng kích hoạt.
5. Kiểm tra stop level, freeze level, tick size và khoảng cách spread.
6. Chọn mức SL tốt nhất:
   - BUY: mức SL hợp lệ cao nhất nhưng vẫn thấp hơn giá hiện tại theo broker rule.
   - SELL: mức SL hợp lệ thấp nhất nhưng vẫn cao hơn giá hiện tại theo broker rule.
7. Chỉ gửi một yêu cầu sửa SL nếu có cải thiện.
8. Ghi log: SL cũ, SL đề xuất, lý do, R hiện tại, kết quả broker.

## 4.3. Hòa vốn có tính chi phí

Không đặt SL đúng bằng Entry một cách máy móc.

- BUY: Entry + buffer chi phí.
- SELL: Entry - buffer chi phí.
- Buffer phải xét commission dự kiến, spread và một khoản trượt giá hợp lý.
- Nếu không thể ước lượng commission chính xác, cho phép cấu hình buffer theo points và ghi rõ đây chỉ là ước lượng.
- Chỉ áp dụng sau khi đạt R và điều kiện nến đóng đã được xác nhận.

## 4.4. Không dùng trailing quá sát

Không kích hoạt trailing ngay khi lệnh vừa có lợi nhuận nhỏ. XAUUSD có nhiễu ngắn hạn; trailing sát dễ làm giảm Average Win. Cần so sánh:
- Không trailing, chỉ TP/SL.
- Break-even có xác nhận.
- Structure trailing.
- PSAR trailing.
- Partial close + runner.

Không bật tất cả cùng lúc ngay từ đầu.

---

# 5. Chuẩn hóa tín hiệu Wonderwhales

## 5.1. Giữ nguyên indicator làm nguồn tín hiệu

Không viết lại công thức PSAR trong EA nếu đã có indicator MT5 port. EA phải gọi indicator bằng `iCustom` và đọc theo contract được định nghĩa trong `WonderwhalesContract.mqh`.

Bắt buộc:
- Xác minh phiên bản contract.
- Xác minh thứ tự và kiểu dữ liệu của toàn bộ buffer.
- Xác minh BUY/SELL buffer với một vài timestamp cụ thể.
- Đọc `shift=1`, không dùng nến hiện tại `shift=0`.
- Không tự suy đoán buffer index.
- Có kiểm tra `BarsCalculated()` và `CopyBuffer()` trả đủ dữ liệu.
- Nếu indicator chưa sẵn sàng hoặc buffer trả `EMPTY_VALUE`, không giao dịch.

## 5.2. Chế độ tín hiệu khởi đầu

Đề xuất dùng `SAR + EMA Trend Filter` làm lựa chọn mặc định để kiểm thử, không dùng pure SAR reversal làm mặc định giao dịch thật.

Lý do:
- Pure SAR có thể tạo nhiều tín hiệu đảo chiều trong vùng sideway.
- EMA20/50 giúp loại một phần tín hiệu ngược hướng động lượng.
- EMA200 được dùng làm bộ lọc xu hướng lớn hơn, đặc biệt ở Swing.
- ATR% chỉ nên là bộ lọc tùy chọn sau khi hiệu chỉnh theo timeframe; không bê ngưỡng 0.5% dùng chung cho M1, M5, M15, H1, D1, W1.

Không được mặc định RSI, Bollinger hoặc VSA là bộ lọc giao dịch nếu EA/indicator port chưa thực hiện chúng trong signal contract.

## 5.3. VSA Volume

Trên Forex/CFD vàng, volume thường là tick volume từ broker, không phải volume tập trung toàn thị trường.

Vì vậy:
- VSA mặc định chỉ hiển thị/log.
- Chưa dùng VSA để chặn lệnh trong cấu hình mặc định.
- Có thể tạo nhánh kiểm thử riêng: chỉ cho phép entry nếu volume ratio vượt một ngưỡng.
- Đánh giá riêng từng broker vì tick volume có thể khác nhau.

## 5.4. Cổng parity bắt buộc (chặn mở lệnh)

Parity Pine ↔ MT5 là **điều kiện tiên quyết để giao dịch**, không phải hạng mục tùy chọn:

- Khi parity **chưa đạt** (chưa có CSV tham chiếu Pine, hoặc lệch quá dung sai): EA **chặn mọi entry**
  ở cả Scalp và Swing (một dạng halt), ghi `reason=parity_blocked`.
- Vẫn được phép làm (để xác minh hạ tầng): compile, kết nối indicator, kiểm tra `CopyBuffer`, tính
  SL/TP/volume, chạy cơ chế quản lý rủi ro và ghi log.
- **Kết quả giao dịch thu được khi bỏ qua parity KHÔNG phải kết quả chiến lược hợp lệ** — không dùng để
  đánh giá lợi nhuận hay kết luận bot tốt/xấu.
- Cờ `BatParity` mặc định bật; chỉ tắt tạm khi có lý do rõ ràng và **không** dùng để sinh kết quả chiến lược.

---

# 6. Bộ input tiếng Việt

Quy ước:
- Tên biến nội bộ dùng tiếng Việt không dấu để tránh vấn đề tương thích compiler.
- Tên nhóm `input group`, enum và comment/tooltip hiển thị dùng tiếng Việt có dấu.
- Không dùng tên tiếng Anh khó hiểu trên cửa sổ Inputs.
- Không đổi tên các input cũ nếu việc đó làm hỏng preset `.set`; cần migration hoặc tạo preset mới.

## 6.1. Nhóm `00 - Chế độ và an toàn`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `CheDoGiaoDich` | `SCALP_M1_M5_M15` | Chọn chỉ báo tín hiệu / Scalp / Swing (mặc định SCALP) |
| `BatGuiLenh` | `true` | Cho phép EA gửi lệnh (ADR 0006: mặc định bật) |
| `ChiGiaoDichTaiKhoanDemo` | `true` | Chặn tài khoản real (bắt buộc) |
| `MaGiaoDichDuocPhep` | `"XAUUSD;XAUUSDm"` | Danh sách symbol được phép; sửa đúng theo broker |
| `Magic` | `25008001` | **Một magic cho cả bot** (Scalp và Swing dùng chung); mode từng lệnh lưu trong state |
| `SoLenhDongThoiToiDa` | `1` | Giới hạn vị thế |
| `BatNutDungKhanCap` | `true` | Dùng file kill switch |
| `TenFileDungKhanCap` | `"WONDERWHALES_XAU_2MODE_DEMO_STOP.txt"` | Tên file dừng khẩn cấp |

## 6.2. Nhóm `01 - Tín hiệu Wonderwhales`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `CheDoTinHieu` | `SAR_EMA` | PSAR thuần / EMA Cross / SAR+EMA / SAR+EMA+ATR |
| `XacNhanNenDong` | `true` | Chỉ dùng tín hiệu nến đã đóng |
| `PSAR_BuocDau` | `0.02` | Hệ số ban đầu PSAR |
| `PSAR_BuocTang` | `0.02` | Hệ số tăng PSAR |
| `PSAR_GioiHanToiDa` | `0.20` | Hệ số tối đa PSAR |
| `EMA_Nhanh` | `20` | Chu kỳ EMA nhanh |
| `EMA_Cham` | `50` | Chu kỳ EMA chậm |
| `EMA_XuHuongDai` | `200` | EMA xu hướng lớn |
| `ATR_ChuKy` | `14` | Chu kỳ ATR |
| `BatLocATR` | `false` | Bật/tắt lọc biến động; cần hiệu chỉnh riêng từng timeframe |
| `BatLocVSA` | `false` | Mặc định không chặn lệnh bằng VSA |

## 6.3. Nhóm `02 - Chiến lược Scalp M1 M5 M15`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `Scalp_KhungXuHuong` | `PERIOD_M15` | Khung định hướng |
| `Scalp_KhungSetup` | `PERIOD_M5` | Khung hình thành setup |
| `Scalp_KhungVaoLenh` | `PERIOD_M1` | Khung xác nhận vào lệnh |
| `Scalp_DungXacNhanM1` | `true` | Có yêu cầu xác nhận M1 |
| `Scalp_RR_MucTieu` | `1.5` | TP theo R |
| `Scalp_SL_ATR_DuPhong` | `1.2` | SL dự phòng theo ATR M5 |
| `Scalp_BufferSwing_ATR` | `0.20` | Đệm ngoài swing |
| `Scalp_KichHoatBE_R` | `1.0` | Ngưỡng hòa vốn |
| `Scalp_KichHoatTrailing_R` | `1.3` | Ngưỡng trailing |
| `Scalp_ToiDaLenhMoiNgay` | `0` | Giới hạn số lệnh/ngày; `0` = không giới hạn |
| `Scalp_ThoiGianNghiSauLenhThua_Phut` | `20` | Thời gian nghỉ sau lệnh thua |
| `Scalp_ToiDaSpread_TrenSL` | `10.0` | Spread tối đa tính theo % khoảng SL |

## 6.4. Nhóm `03 - Chiến lược Swing H1 D1 W1`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `Swing_KhungXuHuongNen` | `PERIOD_W1` | Khung xu hướng nền |
| `Swing_KhungSetup` | `PERIOD_D1` | Khung setup |
| `Swing_KhungVaoLenh` | `PERIOD_H1` | Khung kích hoạt |
| `Swing_RR_MucTieu` | `2.5` | TP theo R |
| `Swing_RR_ToiThieu` | `1.8` | RR tối thiểu để được vào |
| `Swing_SL_ATR_DuPhong` | `2.0` | SL dự phòng theo ATR H1 |
| `Swing_BufferSwing_ATR` | `0.30` | Đệm ngoài swing |
| `Swing_KichHoatBE_R` | `1.2` | Ngưỡng hòa vốn |
| `Swing_KichHoatTrailing_R` | `1.5` | Ngưỡng trailing |
| `Swing_ToiDaLenhMoiNgay` | `0` | Giới hạn số lệnh mới mỗi ngày; `0` = không giới hạn |
| `Swing_ThoatKhiPSARDaoChieu` | `false` | Tùy chọn thoát khi PSAR đảo chiều H1 |

## 6.5. Nhóm `04 - Quản lý vốn`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---:|---|
| `Scalp_RuiRoMoiLenh_PhanTram` | `0.15` | Rủi ro Scalp theo Equity (%) |
| `Swing_RuiRoMoiLenh_PhanTram` | `0.25` | Rủi ro Swing theo Equity (%) |
| `GioiHanKhoiLuongToiDa` | `0.10` | Chặn volume tối đa; không thay thế tính risk |
| `DungNeuLotToiThieuVuotRisk` | `true` | Bỏ qua nếu min lot vượt ngân sách |
| `LoToiDaTrongNgay_PhanTram` | `1.0` | Khóa giao dịch trong ngày |
| `LoToiDaTrongTuan_PhanTram` | `2.0` | Khóa giao dịch trong tuần |
| `DrawdownToiDa_PhanTram` | `5.0` | Khóa cứng, cần reset thủ công |
| `SoLenhThuaLienTiepToiDa` | `2` | Tạm dừng sau chuỗi thua |
| `TinhRiskTrenEquity` | `true` | Tính ngân sách theo Equity |
| `KhongTangLotKhiThua` | `true` | Cấm tăng lot để gỡ lỗ |

## 6.6. Nhóm `05 - Break-even và Trailing SL`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `BatHoaVon` | `true` | Cho phép dời SL về hòa vốn |
| `HoaVon_CongBuChiPhi` | `true` | Cộng spread/commission/slippage buffer |
| `BatTrailingCauTruc` | `true` | Trailing theo swing đã xác nhận |
| `BatTrailingPSAR` | `false` | Nhánh thử nghiệm PSAR trailing |
| `BatTrailingATR` | `false` | Nhánh thử nghiệm ATR trailing |
| `BatTrailingBuoc` | `false` | Nhánh thử nghiệm trailing theo bước (points) |
| `BuocTrailing_Points` | `300` | Khoảng cách mỗi bước trailing (chỉ áp dụng khi bật step) |
| `SoNenXacNhanSwing` | `2` | Số nến mỗi phía để xác nhận swing |
| `Trailing_Buffer_ATR` | `0.25` | Đệm ATR cho trailing cấu trúc |
| `KhoangCachToiThieuSuaSL_Points` | `50` | Hạn chế sửa SL quá thường xuyên |
| `ChiTrailingSauNenDong` | `true` | Chỉ trailing khi nến quản lý đã đóng |

## 6.7. Nhóm `06 - Bộ lọc thị trường`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `SpreadToiDa_Points` | Theo broker | Ngưỡng points tuyệt đối; phải hiệu chỉnh |
| `SpreadToiDa_PhanTramKhoangSL` | `10.0` | Ngưỡng spread theo SL |
| `BoQuaKhiATRQuaThap` | `false` | Tắt mặc định cho đến khi kiểm thử |
| `LocPhienGiaoDich` | `false` | Bật sau khi kiểm tra múi giờ server |
| `KhungGioServer` | `"00:00-23:59"` | Khung giờ theo server, không phải giờ Việt Nam |

## 6.8. Nhóm `07 - Nhật ký và giám sát`

| Tên input đề xuất | Mặc định | Ý nghĩa |
|---|---|---|
| `BatGhiNhatKy` | `true` | Ghi CSV **18 cột** (giữ nguyên hợp đồng với watcher/validator) |
| `BatBangThongTin` | `true` | Hiện trạng thái trên chart |
| `MucChiTietLog` | `THONG_TIN` | Lỗi / thông tin / debug |
| `BatTelemetry` | `true` | Ghi **file telemetry riêng** cho dữ liệu mở rộng (xem §9) |
| `TenFileTelemetry` | `"wonderwhales_xau_2mode_telemetry.csv"` | File telemetry, tách khỏi hợp đồng 18 cột |
| `BatParity` | `true` | Cổng parity bắt buộc — chặn entry khi chưa đạt parity (§5.4) |
| `LuuTrangThaiRuiRo` | `true` | Lưu daily/weekly halt và High-Water Mark |
| `DatLaiTrangThaiThuCong` | `false` | Chỉ bật theo quy trình reset an toàn |

---

# 7. Quy trình vào lệnh và quản lý lệnh

## 7.1. Luồng xử lý chung

1. Kiểm tra terminal, tài khoản, symbol và trading permission.
2. Kiểm tra kill switch.
3. Nạp/kiểm tra indicator handle.
4. Kiểm tra đủ số nến và `BarsCalculated`.
5. Đọc tín hiệu các timeframe tại nến đã đóng.
6. Xác định bias của chiến lược.
7. Kiểm tra spread và điều kiện thị trường.
8. Tính Entry, SL, TP.
9. Tính volume bằng `OrderCalcProfit`.
10. Kiểm tra daily/weekly/max DD, số vị thế đồng thời và **cổng parity** — **không còn hạn mức số
    lệnh/ngày** (số lệnh chỉ bị chặn gián tiếp qua guard).
11. Gửi lệnh qua một điểm thực thi duy nhất.
12. Xác minh retcode và position thực tế sau khi gửi.
13. Lưu initial SL, initial risk R, mode, magic, ticket/identifier và thời điểm vào.
14. Quản lý hòa vốn/trailing theo chế độ.
15. Ghi kết quả đóng lệnh và lý do thoát.

## 7.2. Quản lý initial R

Khi mở lệnh, lưu `InitialRiskPrice = abs(Entry - InitialSL)` và không thay đổi giá trị này sau khi SL được trailing.

`CurrentR`:
- BUY: `(Bid - Entry) / InitialRiskPrice`.
- SELL: `(Entry - Ask) / InitialRiskPrice`.

Nên tính R theo giá có thể đóng vị thế, không dùng giá giữa nếu làm sai lệch điều kiện kích hoạt.

Không được tính lại R theo SL mới sau khi hòa vốn/trailing. Nếu làm vậy, ngưỡng kích hoạt sẽ thay đổi sai.

## 7.3. Khôi phục trạng thái sau restart

- Lưu trạng thái theo `POSITION_IDENTIFIER`/ticket phù hợp.
- Lưu initial SL và initial R.
- **Lưu `mode` tại thời điểm vào lệnh** cho từng vị thế; khi khôi phục phải quản lý theo mode đã lưu,
  **không** theo `CheDoGiaoDich` đang chọn trên Inputs (Inputs có thể đã đổi sau khi restart).
- Khi EA khởi động lại, đọc vị thế đang mở và khôi phục state.
- Nếu không tìm được initial SL/state an toàn, không tự đoán. Ghi cảnh báo và áp dụng chính sách bảo vệ đã định nghĩa; không tự mở lệnh mới.
- Không được để trạng thái daily/weekly halt mất sau khi restart.

---

# 8. Kiến trúc mã đề xuất

```text
mt5/
  Experts/
    WonderwhalesXAU2ModeEA.mq5

  Indicators/
    PinePort/
      Wonderwhales.mq5

  Include/
    PinePort/
      WonderwhalesContract.mqh

    Strategy/
      WWScalpStrategy.mqh
      WWSwingStrategy.mqh
      WWSignalReader.mqh
      WWMarketRegime.mqh

    Risk/
      WWRiskSizer.mqh
      WWRiskGuard.mqh
      WWExposureGuard.mqh

    Management/
      WWInitialStop.mqh
      WWBreakEven.mqh
      WWStructureTrailing.mqh
      WWTrailingCoordinator.mqh
      WWExitManager.mqh

    Exec/
      ExecGuard.mqh
      ExecBroker.mqh

    Sim/
      SimRiskGuard.mqh
      SimLogger.mqh
```

### Trách nhiệm

- `WWSignalReader`: chỉ đọc buffer, không tự tạo lại tín hiệu.
- `WWScalpStrategy`: chỉ quản lý logic M15/M5/M1.
- `WWSwingStrategy`: chỉ quản lý logic W1/D1/H1.
- `WWRiskSizer`: tính lot theo tiền lỗ dự kiến.
- `WWRiskGuard`: daily/weekly/max drawdown/consecutive loss.
- `WWInitialStop`: xác định SL ban đầu.
- `WWBreakEven`: hòa vốn có buffer chi phí.
- `WWStructureTrailing`: trailing swing đã xác nhận.
- `WWTrailingCoordinator`: tổng hợp mọi ứng viên SL và chọn mức tốt nhất.
- `ExecBroker`: điểm gửi/sửa/đóng lệnh duy nhất.
- `SimLogger`: journal mô phỏng riêng, không trộn với demo execution.

Không để hai strategy tự gửi lệnh qua nhiều API khác nhau. Tất cả phải đi qua cùng một execution guard.

---

# 9. Nhật ký cần có để biết EA lãi/lỗ vì điều gì

CSV nên có tối thiểu:

- Timestamp server.
- Symbol, mode, timeframe.
- Magic, ticket, position identifier.
- Hướng BUY/SELL.
- Giá entry, initial SL, TP.
- Initial risk bằng tiền và bằng giá.
- Volume.
- Spread lúc vào.
- Commission, swap.
- Tín hiệu PSAR/EMA từng timeframe.
- Giá trị EMA20/50/200, ATR.
- R hiện tại.
- SL cũ, SL mới, loại trailing.
- Lý do đóng: SL / TP / BE / Structure Trail / PSAR Flip / Risk Halt / Manual.
- P/L tiền, P/L theo R.
- MAE, MFE nếu có thể ghi nhận.

Không chỉ ghi `WIN` hoặc `LOSS`. Cần phân biệt:
- Lệnh chạm BE.
- Lệnh trailing lời nhỏ.
- Lệnh đạt TP.
- Lệnh mất full SL.
- Lệnh đóng bởi tín hiệu đảo chiều.

### 9.1. Hai file: journal 18 cột + telemetry riêng (chốt S4)

- **Journal chính giữ nguyên hợp đồng 18 cột** mà `scripts/watch_demo_journal.py` và
  `scripts/validate_demo_execution.py` đang parse — không mở rộng schema này.
- **Các trường mở rộng ghi vào một file telemetry riêng** (`TenFileTelemetry`), tối thiểu gồm:
  MAE, MFE, R hiện tại, loại trailing đã kích hoạt (BE / structure / PSAR / ATR / step), giá trị
  EMA20/50/200, ATR và trạng thái PSAR **theo từng khung**, và mode của lệnh.
- Hai file nối với nhau bằng `position identifier` (và `magic`); telemetry **không** thay thế journal,
  chỉ bổ sung để phân tích vì sao lãi/lỗ.

---

# 10. Kế hoạch kiểm thử

## Giai đoạn 1 — Xác minh tín hiệu

- Compile indicator MT5 và EA.
- Kiểm tra buffer contract.
- Đối chiếu ít nhất 100 timestamp BUY/SELL giữa Pine và MT5.
- Chỉ đối chiếu nến đã đóng.
- Không chạy optimization khi parity chưa đạt.

## Giai đoạn 2 — Kiểm thử Scalp và Swing riêng biệt

Không trộn kết quả.

### Scalp
- Symbol thực tế của broker.
- M1/M5/M15 đúng mapping.
- Every tick based on real ticks nếu dữ liệu có sẵn.
- Tính spread, commission, swap, slippage.
- Chạy tối thiểu 2 năm dữ liệu nếu broker cung cấp đủ chất lượng.
- Chia dữ liệu thành giai đoạn phát triển và giai đoạn ngoài mẫu.

### Swing
- Dùng W1/D1/H1.
- Dữ liệu phải đủ dài để có nhiều chu kỳ tăng/giảm và đi ngang.
- Không chỉ đánh giá trong một xu hướng thuận lợi.
- Kiểm tra các vị thế giữ qua đêm, cuối tuần, swap và gap.

## Giai đoạn 3 — So sánh trailing

Giữ nguyên tín hiệu và risk trong từng lượt test. Chỉ thay đổi một biến nhóm:

A. SL + TP cố định, không BE/trailing.  
B. BE có xác nhận, không trailing.  
C. BE + Structure Trailing.  
D. BE + PSAR Trailing.  
E. Partial close + Runner (chỉ thử sau khi A–D có kết quả).

Không thay EMA, PSAR, ATR, risk và trailing cùng một lượt.

## Giai đoạn 4 — Tiêu chí đánh giá

Cần xem:

- Net Profit sau phí.
- Profit Factor.
- Expectancy theo R.
- Average Win / Average Loss.
- Winrate.
- Max Equity Drawdown.
- Recovery Factor.
- Số lệnh.
- Chuỗi thua dài nhất.
- Tỷ lệ lệnh bị BE.
- Tỷ lệ lệnh đạt 1R, 1.5R, 2R, 2.5R.
- MFE/MAE.
- Tỷ lệ lợi nhuận đã có nhưng bị trả lại trước khi đóng.
- Kết quả riêng theo tháng và theo chế độ thị trường.

Một cấu hình có winrate cao nhưng Expectancy âm vẫn phải loại.

Công thức:

`Expectancy = WinRate × AverageWin(R) - LossRate × AverageLoss(R) - AverageTradingCost(R)`

Không chọn cấu hình chỉ vì Net Profit cao nhất trong một khoảng dữ liệu ngắn.

## Giai đoạn 5 — Forward demo

- Chạy Scalp demo riêng.
- Chạy Swing demo riêng.
- Không bật real trading trong giai đoạn này.
- Ghi lại khác biệt giữa tester và demo: spread, slippage, requote, execution delay, swap.
- Chỉ xem xét tài khoản thật sau khi có đủ mẫu forward và người vận hành kiểm tra thủ công.

---

# 11. Cấu hình khởi điểm đề xuất cho người mới

Đây là preset bảo thủ để bắt đầu kiểm thử, không phải cấu hình đảm bảo lợi nhuận.

## Preset 1 — Quan sát tín hiệu (dry-run có chủ đích)

```ini
CheDoGiaoDich=CHI_BAO_TIN_HIEU
BatGuiLenh=false
ChiGiaoDichTaiKhoanDemo=true
XacNhanNenDong=true
```

Dùng để kiểm tra tín hiệu trên chart trước.

> Đây là **override `BatGuiLenh=false` có chủ đích** (dry-run), **không phải mặc định** của EA. Mặc định
> là Preset 2 — SCALP, execution bật, chỉ tài khoản demo. Mặc định vẫn phải vượt **cổng parity** (§5.4)
> mới vào lệnh.

## Preset 2 — Scalp Demo

```ini
CheDoGiaoDich=SCALP_M1_M5_M15
BatGuiLenh=true
ChiGiaoDichTaiKhoanDemo=true
Scalp_RuiRoMoiLenh_PhanTram=0.15
Scalp_RR_MucTieu=1.5
Scalp_KichHoatBE_R=1.0
Scalp_KichHoatTrailing_R=1.3
Scalp_ToiDaLenhMoiNgay=0
LoToiDaTrongNgay_PhanTram=1.0
LoToiDaTrongTuan_PhanTram=2.0
DrawdownToiDa_PhanTram=5.0
```

Chạy demo trước; không tự tăng lot khi có vài lệnh thắng liên tiếp.

## Preset 3 — Swing Demo

```ini
CheDoGiaoDich=SWING_H1_D1_W1
BatGuiLenh=true
ChiGiaoDichTaiKhoanDemo=true
Swing_RuiRoMoiLenh_PhanTram=0.25
Swing_RR_MucTieu=2.5
Swing_RR_ToiThieu=1.8
Swing_KichHoatBE_R=1.2
Swing_KichHoatTrailing_R=1.5
Swing_ToiDaLenhMoiNgay=0
LoToiDaTrongNgay_PhanTram=1.0
LoToiDaTrongTuan_PhanTram=2.0
DrawdownToiDa_PhanTram=5.0
```

Không chạy đồng thời Preset Scalp và Swing trên cùng tài khoản trong giai đoạn đầu.

---

# 12. Những điểm không được tự ý thay đổi khi triển khai

1. Không đổi công thức PSAR của indicator gốc.
2. Không đoán buffer index.
3. Không dùng shift 0 cho tín hiệu giao dịch.
4. Không bỏ qua spread, commission, swap.
5. Không làm tròn volume lên min lot nếu vượt risk.
6. Không cho phép SL lùi xa hơn.
7. Không bật martingale/grid/DCA.
8. Không tự động tăng risk sau chuỗi thắng.
9. Không gộp số liệu Scalp và Swing thành một kết quả.
10. Không gắn nhãn `PROVEN` khi chưa có forward demo và kiểm thử ngoài mẫu.
11. Không mặc định VSA tick volume là volume tập trung của thị trường vàng.
12. Không cho phép tài khoản real khi `ChiGiaoDichTaiKhoanDemo=true`.
13. Không xóa risk lock chỉ vì EA/terminal khởi động lại.
14. Không tuyên bố đã compile/chạy tester khi chưa có log xác thực.
15. **Không tạo magic thứ hai.** Chỉ một magic `25008001` cho cả bot; Scalp/Swing phân biệt bằng `mode`
    lưu trong state, không bằng magic.
16. **Không giao dịch khi parity chưa đạt.** Cổng parity (§5.4) chặn entry; không hạ cờ parity để có
    thêm kết quả chiến lược.
17. **Không mở rộng schema journal 18 cột.** Dữ liệu phụ ghi file telemetry riêng (§9.1).
18. **Không quản lý vị thế khôi phục theo mode đang chọn trên Inputs** — luôn theo mode đã lưu lúc vào lệnh.

---

# 13. Checklist nghiệm thu cho AI Coding Agent

- [ ] Đã đọc toàn bộ EA và Include hiện tại.
- [ ] Đã đọc `WonderwhalesContract.mqh`.
- [ ] Đã xác minh buffer count, buffer index, kiểu dữ liệu.
- [ ] Đã kiểm tra indicator handle và CopyBuffer.
- [ ] Scalp dùng đúng M15 bias, M5 setup, M1 trigger.
- [ ] Swing dùng đúng W1 bias, D1 setup, H1 trigger.
- [ ] Tất cả signal đọc nến đã đóng.
- [ ] **Một magic `25008001` cho cả bot**; Scalp/Swing phân biệt bằng `mode` lưu trong state lúc vào lệnh.
- [ ] Mặc định chỉ chạy một mode (mặc định `SCALP`).
- [ ] **Cổng parity chặn entry** khi parity Pine↔MT5 chưa đạt.
- [ ] Volume tính theo OrderCalcProfit.
- [ ] Min lot vượt risk thì skip.
- [ ] SL được đặt ngay khi mở lệnh.
- [ ] Initial R được lưu độc lập với SL trailing.
- [ ] Break-even tính buffer chi phí.
- [ ] Trailing chỉ siết SL, không nới SL.
- [ ] Trailing coordinator chọn mức SL tốt nhất.
- [ ] Broker stop/freeze/tick-size được kiểm tra.
- [ ] Daily, weekly, max DD guard được lưu bền vững.
- [ ] Kill switch hoạt động.
- [ ] Execution retcode được xác minh.
- [ ] CSV (18 cột) ghi đầy đủ lý do vào/ra; **file telemetry riêng** ghi các trường mở rộng (§9.1).
- [ ] Compile 0 errors, 0 warnings.
- [ ] Đã chạy Strategy Tester riêng cho Scalp.
- [ ] Đã chạy Strategy Tester riêng cho Swing.
- [ ] Đã có parity test Pine ↔ MT5.
- [ ] Chưa bật giao dịch real.

---

# 14. Kết luận và khuyến nghị cho người mới

Với mục tiêu bảo toàn vốn và vốn tham chiếu 1,000 USD:

1. Bắt đầu bằng quan sát: đặt `CheDoGiaoDich=CHI_BAO_TIN_HIEU` (hoặc `BatGuiLenh=false`) để xem tín
   hiệu — đây là bước quan sát **có chủ đích**; nhớ mặc định của EA là `SCALP` với execution bật trên demo.
2. Kiểm tra parity Pine ↔ MT5 trước khi tin vào tín hiệu EA.
3. Chỉ chạy **một chế độ demo tại một thời điểm**.
4. Đề nghị kiểm định Scalp trước vì thời gian quan sát mỗi giao dịch ngắn hơn; nhưng không mặc định Scalp sẽ tốt hơn Swing.
5. Giữ risk ở mức thấp; nếu min lot broker khiến risk vượt ngân sách thì không giao dịch.
6. Không đặt mục tiêu winrate thật cao. Mục tiêu là Expectancy dương sau phí và drawdown chịu được.
7. Không tối ưu tham số chỉ để làm đẹp kết quả của giai đoạn backtest đã xem.

**Đề xuất cá nhân về cách học:** trước tiên hãy dùng chế độ chỉ báo và xem 20–30 tín hiệu đã đóng trên chart; ghi lại lý do một tín hiệu đạt/không đạt điều kiện. Sau đó mới chạy demo tự động. Đừng vội bật cả Scalp và Swing, vì khi mới bắt đầu sẽ rất khó biết lệnh nào đang tạo lợi nhuận hoặc gây drawdown.

**Trạng thái tài liệu:** `DESIGN_READY / IMPLEMENTATION_BLOCKED_BY_MISSING_MQL5_SOURCE_FILES`  
Tài liệu này là chỉ dẫn triển khai và kiểm thử, không phải bằng chứng EA đã được lập trình, compile hoặc có lợi nhuận.
