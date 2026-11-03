# PA_TrendRider_XAU_V1

## Đặc tả kỹ thuật, roadmap triển khai và hướng dẫn AI lập trình EA MT5

-   **Tên dự án:** PA_TrendRider_XAU_V1
-   **Phiên bản tài liệu:** 1.0
-   **Nền tảng:** MetaTrader 5 (MT5), ngôn ngữ MQL5
-   **Thị trường mục tiêu:** XAUUSD (tên symbol phải cấu hình được, ví
    dụ `XAUUSD.a`, `GOLD`)
-   **Phong cách:** Price Action đa khung thời gian, theo xu hướng, vào
    lệnh pullback/retest
-   **Mục tiêu vốn thử nghiệm:** 1.000 đơn vị tiền tệ tài khoản (ví dụ
    USD)
-   **Trạng thái:** Đặc tả để triển khai và kiểm thử; chưa phải chiến
    lược đã chứng minh có lợi nhuận

> **Cảnh báo rủi ro:** Tài liệu này là đặc tả kỹ thuật, không phải
> khuyến nghị đầu tư hoặc cam kết lợi nhuận. Tham số ban đầu chỉ là giả
> thuyết cần kiểm thử. EA có thể thua lỗ, trượt giá, khớp lệnh khác dự
> kiến hoặc gặp lỗi kết nối. Bắt đầu trên Strategy Tester và tài khoản
> demo. Không sử dụng vốn thật cho đến khi đã đánh giá độc lập kết quả
> ngoài mẫu và vận hành demo.

------------------------------------------------------------------------

## Mục lục

1.  [Tầm nhìn và nguyên tắc thiết
    kế](#1-tầm-nhìn-và-nguyên-tắc-thiết-kế)
2.  [Phạm vi V1 và ngoài phạm vi](#2-phạm-vi-v1-và-ngoài-phạm-vi)
3.  [Cấu hình mặc định ban đầu](#3-cấu-hình-mặc-định-ban-đầu)
4.  [Kiến trúc đa khung thời gian](#4-kiến-trúc-đa-khung-thời-gian)
5.  [Định nghĩa cấu trúc Price
    Action](#5-định-nghĩa-cấu-trúc-price-action)
6.  [Bộ phân loại trạng thái thị
    trường](#6-bộ-phân-loại-trạng-thái-thị-trường)
7.  [Quy tắc vào lệnh](#7-quy-tắc-vào-lệnh)
8.  [Quản lý vốn và rủi ro](#8-quản-lý-vốn-và-rủi-ro)
9.  [SL, break-even và trailing không TP cố
    định](#9-sl-break-even-và-trailing-không-tp-cố-định)
10. [Quy trình đảo chiều](#10-quy-trình-đảo-chiều)
11. [Kiến trúc mã nguồn MQL5](#11-kiến-trúc-mã-nguồn-mql5)
12. [Luồng xử lý và trạng thái EA](#12-luồng-xử-lý-và-trạng-thái-ea)
13. [Yêu cầu kỹ thuật và an toàn giao
    dịch](#13-yêu-cầu-kỹ-thuật-và-an-toàn-giao-dịch)
14. [Logging, dữ liệu và báo cáo](#14-logging-dữ-liệu-và-báo-cáo)
15. [Kế hoạch kiểm thử](#15-kế-hoạch-kiểm-thử)
16. [Roadmap triển khai theo giai
    đoạn](#16-roadmap-triển-khai-theo-giai-đoạn)
17. [Tiêu chí nghiệm thu](#17-tiêu-chí-nghiệm-thu)
18. [Cấu hình đề xuất](#18-cấu-hình-đề-xuất)
19. [Prompt giao cho AI coding
    agent](#19-prompt-giao-cho-ai-coding-agent)
20. [Checklist vận hành demo](#20-checklist-vận-hành-demo)
21. [Giới hạn và rủi ro còn lại](#21-giới-hạn-và-rủi-ro-còn-lại)
22. [Tài liệu tham khảo](#22-tài-liệu-tham-khảo)

------------------------------------------------------------------------

## 1. Tầm nhìn và nguyên tắc thiết kế

### 1.1. Mục tiêu

Xây dựng EA MT5 có thể:

1.  Đọc cấu trúc giá XAUUSD trên nhiều khung thời gian.
2.  Nhận diện xu hướng bằng swing high/low, HH/HL, LH/LL, BOS và CHoCH.
3.  Đợi pullback/retest và tín hiệu nến đã đóng trước khi vào.
4.  Giữ lệnh thắng khi xu hướng còn hiệu lực bằng break-even và trailing
    stop.
5.  Không đặt Take Profit cố định; thoát bằng SL, trailing hoặc quy tắc
    đảo chiều đã xác nhận.
6.  Chỉ xét chiều mới sau khi vị thế cũ đã đóng hoàn tất.
7.  Tính khối lượng theo mức lỗ dự kiến tại SL, thông số symbol và chi
    phí.
8.  Ngừng mở lệnh khi chạm giới hạn rủi ro hoặc dữ liệu giao dịch không
    đáng tin cậy.
9.  Ghi log đủ để giải thích mọi quyết định và kiểm thử lại.
10. Chạy được trong Strategy Tester và tài khoản demo.

### 1.2. Triết lý

-   **Price Action là lõi:** cấu trúc giá quyết định thiên hướng và
    setup.
-   **Đa khung thời gian:** H1 cung cấp bối cảnh, M15 xác nhận cấu trúc,
    M5 tìm điểm vào.
-   **Chờ nến đóng:** không dùng nến chưa hoàn thành để xác nhận
    BOS/CHoCH hoặc tín hiệu vào.
-   **Không repaint:** swing chỉ trở thành swing hợp lệ sau khi đủ nến
    bên phải.
-   **Một vị thế tại một thời điểm:** V1 không mở chồng lệnh.
-   **Không TP cố định:** lệnh được quản lý bằng SL và trailing; điều
    này không đảm bảo tối đa hóa lợi nhuận.
-   **Không martingale/grid:** không tăng lot sau thua, không trung bình
    giá vào lệnh lỗ.
-   **An toàn hơn tín hiệu:** khi trạng thái không rõ, dữ liệu thiếu
    hoặc broker từ chối thao tác bảo vệ, ưu tiên không mở lệnh mới.
-   **Không tối ưu quá mức:** tham số phải được kiểm tra ngoài mẫu và
    qua stress test.

### 1.3. Điều không được hứa hẹn

Không được tuyên bố EA có lợi nhuận, win rate cao hoặc drawdown thấp nếu
chưa có kết quả thực nghiệm tái lập được. Backtest tốt không đảm bảo
hiệu quả tương lai.

------------------------------------------------------------------------

## 2. Phạm vi V1 và ngoài phạm vi

### 2.1. Bao gồm

-   Một symbol được cấu hình, mặc định XAUUSD.
-   Ba timeframe H1, M15, M5.
-   Swing detector kiểu fractal.
-   BOS, CHoCH, HH/HL, LH/LL.
-   Trend/range/reversal-watch/high-volatility state.
-   Pullback/retest entry.
-   Risk-based lot sizing.
-   Initial structural SL.
-   Break-even và trailing ATR/structure.
-   Một vị thế EA tại một thời điểm.
-   Daily-loss lock, equity drawdown lock, losing-streak pause,
    cooldown.
-   Magic number và kiểm soát vị thế theo symbol.
-   CSV logging.
-   Phục hồi trạng thái sau khởi động lại.
-   Strategy Tester, unit/logic tests và demo forward test.

### 2.2. Chưa bao gồm trong V1

-   Machine learning hoặc mô hình AI ra quyết định trực tiếp.
-   Tự tải lịch tin kinh tế từ dịch vụ ngoài.
-   Giao dịch nhiều symbol cùng lúc.
-   Tăng vị thế khi đang có lời (pyramiding).
-   Grid, martingale, hedge hai chiều.
-   Tối ưu tham số tự động không giới hạn.
-   Gửi lệnh qua dịch vụ bên ngoài hoặc MCP.
-   Cam kết lợi nhuận hoặc quản lý tài khoản thật tự động.

Có thể mở rộng sau khi V1 được kiểm chứng kỹ thuật và đánh giá rủi ro.

------------------------------------------------------------------------

## 3. Cấu hình mặc định ban đầu

Các thông số dưới đây là **điểm bắt đầu cho thử nghiệm**, không phải kết
quả tối ưu.

  -------------------------------------------------------------------------------
  Tham số                                 Giá trị khởi điểm Ý nghĩa
  ---------------------------- ---------------------------- ---------------------
  `InpSymbol`                    Symbol chart hoặc cấu hình Cho phép broker dùng
                                                            hậu tố khác nhau

  `InpTrendTF`                                           H1 Bối cảnh xu hướng

  `InpStructureTF`                                      M15 Xác nhận cấu trúc

  `InpEntryTF`                                           M5 Tìm setup vào lệnh

  `InpSwingLeft`                                          2 Số nến bên trái để
                                                            xác nhận swing

  `InpSwingRight`                                         2 Số nến bên phải để
                                                            xác nhận swing

  `InpRiskPercent`                                     0.25 Phần trăm equity rủi
                                                            ro dự kiến/lệnh

  `InpMaxPositions`                                       1 Vị thế EA đồng thời
                                                            tối đa

  `InpDailyLossLimitPct`                                1.0 Khóa mở lệnh theo lỗ
                                                            ngày

  `InpMaxDrawdownPct`                                   8.0 Khóa EA khi drawdown
                                                            từ đỉnh equity

  `InpMaxConsecutiveLosses`                               3 Số lệnh thua liên
                                                            tiếp trước khi nghỉ

  `InpCooldownMinutes`                                   30 Nghỉ sau lệnh thua

  `InpBreakEvenAtR`                                     1.0 Mốc kích hoạt xem xét
                                                            hòa vốn

  `InpTrailingStartR`                                   1.5 Mốc kích hoạt
                                                            trailing

  `InpATRPeriod`                                         14 Chu kỳ ATR

  `InpATRStopBuffer`                                    0.2 Buffer ATR ngoài
                                                            swing cho SL ban đầu

  `InpATRTrailingMultiplier`                            1.2 Khoảng trailing ATR

  `InpAbnormalATRRatio`                                 2.5 Ngưỡng ATR bất thường
                                                            so với nền

  `InpATRBaselineBars`                                  100 Số nến tính nền ATR

  `InpUseFixedTP`                                     false V1 không dùng TP cố
                                                            định

  `InpEnableTrading`                                   true Công tắc cho phép
                                                            giao dịch

  `InpMagicNumber`                   Giá trị riêng duy nhất Phân biệt lệnh của EA

  `InpLogLevel`                                        INFO Mức log
  -------------------------------------------------------------------------------

### 3.1. Tiền tệ tài khoản

Không giả định tài khoản luôn dùng USD. Nếu tiền tệ tài khoản khác USD,
các giới hạn tiền tệ được tính theo tiền tệ tài khoản. Hiển thị và log
phải ghi rõ đơn vị.

### 3.2. Ngưỡng spread

Không đặt một ngưỡng point chung cho mọi broker. Tạo hai điều kiện cấu
hình:

-   Spread tối đa tuyệt đối theo point hoặc đơn vị giá, được thiết lập
    sau khi khảo sát broker.
-   Spread tương đối với ATR M5, ví dụ không vượt một tỷ lệ cấu hình
    được của ATR.

Nếu chưa cấu hình ngưỡng spread hợp lệ, EA nên cảnh báo rõ và có thể
chặn giao dịch theo chế độ an toàn.

------------------------------------------------------------------------

## 4. Kiến trúc đa khung thời gian

### 4.1. H1 --- bối cảnh xu hướng

H1 xác định thiên hướng tổng thể từ cấu trúc swing đã xác nhận:

-   Uptrend: chuỗi HH và HL.
-   Downtrend: chuỗi LH và LL.
-   Neutral/range: cấu trúc không rõ hoặc hai phía mâu thuẫn.
-   Transition: cấu trúc có dấu hiệu chuyển trạng thái nhưng chưa đủ xác
    nhận.

Không dùng H1 làm tín hiệu vào trực tiếp.

### 4.2. M15 --- xác nhận cấu trúc

M15 xác nhận BOS, CHoCH và hướng ưu tiên. M15 là tầng quyết định xem EA
có nên tìm setup BUY hay SELL.

-   H1 tăng + M15 tăng: cho phép tìm BUY.
-   H1 giảm + M15 giảm: cho phép tìm SELL.
-   H1/M15 mâu thuẫn: mặc định không mở lệnh mới.
-   Có CHoCH ngược hướng: chuyển sang `REVERSAL_WATCH`, chờ xác nhận.

Có thể nghiên cứu một chế độ riêng cho xu hướng mới hình thành, nhưng
không bật mặc định trong V1.

### 4.3. M5 --- điểm vào

M5 tìm pullback/retest vào vùng cấu trúc và nến xác nhận. M5 không được
tự ý đảo hướng giao dịch khi H1/M15 chưa xác nhận.

### 4.4. Chống look-ahead

-   Mọi tín hiệu ra quyết định phải dùng nến đã đóng.
-   Không dùng swing trước khi đủ `InpSwingRight` nến đóng.
-   Khi kiểm thử lịch sử, tín hiệu chỉ được ghi nhận tại thời điểm nó
    thực sự có thể biết.
-   Không di chuyển tín hiệu về nến quá khứ sau khi swing được xác nhận.
-   Ghi `signal_time` và `confirmation_time` riêng nếu cần.

------------------------------------------------------------------------

## 5. Định nghĩa cấu trúc Price Action

### 5.1. Swing high/low

Với `Left = L`, `Right = R`:

Một nến tại vị trí `i` là swing high nếu high của nó lớn hơn các high
của L nến bên trái và R nến bên phải theo quy tắc đã thống nhất. Swing
low là quy tắc ngược lại.

Để tránh mơ hồ khi có các đỉnh bằng nhau, phải quy định cách xử lý tie
(ví dụ chọn swing gần nhất hoặc từ chối swing bằng nhau). Quy tắc này
cần được ghi trong unit tests.

Swing chỉ hợp lệ sau khi các nến bên phải đóng cửa. Với left/right = 2,
độ trễ xác nhận tối thiểu là hai nến của timeframe đó.

### 5.2. Buffer phá cấu trúc

Định nghĩa:

`break_buffer = max(spread_price * SpreadBufferMultiplier, ATR(timeframe) * ATRBreakBufferMultiplier)`

Giá trị khởi điểm có thể dùng: - `SpreadBufferMultiplier = 2.0` -
`ATRBreakBufferMultiplier = 0.10`

Đây là giả thuyết để kiểm thử, không phải hằng số thị trường.

### 5.3. BOS tăng

BOS tăng khi nến đã đóng thỏa:

`Close[1] > last_confirmed_swing_high + break_buffer`

BOS giảm khi:

`Close[1] < last_confirmed_swing_low - break_buffer`

`Close[1]` phải được định nghĩa rõ trong mã theo series indexing MQL5;
không được nhầm nến đang chạy với nến đã đóng.

### 5.4. HH/HL và LH/LL

-   HH: swing high mới cao hơn swing high trước theo ngưỡng có thể cấu
    hình.
-   HL: swing low mới cao hơn swing low trước.
-   LH: swing high mới thấp hơn swing high trước.
-   LL: swing low mới thấp hơn swing low trước.

Không chỉ dựa vào một swing đơn lẻ. `TrendClassifier` cần tối thiểu
chuỗi swing đủ để phân loại; nếu thiếu dữ liệu thì trả về `UNKNOWN`,
không tự suy diễn.

### 5.5. CHoCH

CHoCH là phá cấu trúc quan trọng ngược với xu hướng đang được phân loại.
Nó là cảnh báo chuyển trạng thái, không phải tín hiệu vào ngược hướng
tức thì.

Ví dụ xu hướng tăng: 1. Giá đóng cửa dưới swing low bảo vệ theo buffer.
2. Chuyển sang `REVERSAL_WATCH`. 3. Tạm ngừng setup BUY mới. 4. Chờ cấu
trúc giảm xác nhận theo điều kiện M15. 5. Chỉ sau khi xác nhận mới cho
phép quy trình đóng lệnh cũ và xét SELL.

Phải định nghĩa rõ "protected swing" là swing nào trong cấu trúc hiện
tại. Không thay đổi định nghĩa tùy ý sau khi xem kết quả.

### 5.6. Pullback/retest

Một setup pullback hợp lệ cần: 1. Hướng H1/M15 nhất quán. 2. Có
BOS/continuation event đã xác nhận. 3. Giá hồi về vùng cấu trúc được lưu
từ event đó. 4. Vùng chưa bị vô hiệu hóa. 5. Có nến M5 đóng cửa xác nhận
theo hướng giao dịch. 6. Spread, volatility và risk checks hợp lệ.

V1 nên chỉ triển khai một định nghĩa vùng retest đơn giản, có thể tái
lập. Không cố nhận dạng mọi vùng supply/demand hoặc order block trong
phiên bản đầu.

### 5.7. Nến xác nhận

Một ví dụ có thể kiểm thử: - BUY: nến tăng, thân nến ít nhất
`0.5 * ATR(M5)`, close nằm trong 25% phía trên của biên nến. - SELL: nến
giảm, thân nến ít nhất `0.5 * ATR(M5)`, close nằm trong 25% phía dưới
của biên nến.

Cần xác định cách xử lý nến có range bằng 0, ATR chưa sẵn sàng và nến
bất thường. Các ngưỡng này phải được kiểm thử độ nhạy, không mặc định là
tối ưu.

------------------------------------------------------------------------

## 6. Bộ phân loại trạng thái thị trường

Dùng enum rõ ràng, ví dụ:

``` mql5
enum MarketRegime
{
   REGIME_UNKNOWN,
   REGIME_TREND_UP,
   REGIME_TREND_DOWN,
   REGIME_RANGE,
   REGIME_REVERSAL_WATCH,
   REGIME_VOLATILITY_HIGH,
   REGIME_SPREAD_BLOCKED,
   REGIME_RISK_LOCKED
};
```

### 6.1. Quy tắc

**TREND_UP** - H1 có cấu trúc tăng hợp lệ. - M15 có cấu trúc tăng hợp
lệ. - Không có CHoCH giảm chưa giải quyết. - Các bộ lọc rủi ro cho phép
giao dịch.

**TREND_DOWN** - Điều kiện đối xứng của TREND_UP.

**RANGE** - Không có cấu trúc đủ rõ hoặc nhiều lần phá cấu trúc không
tiếp diễn. - Không mở lệnh trend-following.

**REVERSAL_WATCH** - Phát hiện CHoCH hoặc phá swing ngược hướng. - Tạm
ngừng entry mới theo hướng cũ; chưa tự động mở hướng mới.

**VOLATILITY_HIGH** - ATR M5 hiện tại vượt
`InpAbnormalATRRatio * median(ATR_M5, InpATRBaselineBars)`. - Không mở
lệnh mới trong V1 khi trạng thái này đang bật. - Quản lý vị thế đang mở
vẫn tiếp tục.

**SPREAD_BLOCKED** - Spread vượt ngưỡng cấu hình. - Không mở lệnh mới.

**RISK_LOCKED** - Giới hạn rủi ro bị kích hoạt. - Không mở lệnh mới cho
đến khi điều kiện reset hợp lệ.

### 6.2. Thứ tự ưu tiên

1.  Lỗi dữ liệu hoặc trạng thái không tin cậy.
2.  Risk lock.
3.  Spread/volatility block.
4.  Reversal watch.
5.  Trend classification.
6.  Entry setup.

Các trạng thái bảo vệ không được bị ghi đè bởi tín hiệu BUY/SELL.

------------------------------------------------------------------------

## 7. Quy tắc vào lệnh

### 7.1. BUY

Mở BUY chỉ khi tất cả điều kiện đúng:

1.  `InpEnableTrading == true`.
2.  Dữ liệu H1/M15/M5 đầy đủ và hợp lệ.
3.  H1 bias = bullish.
4.  M15 structure = bullish.
5.  Không có reversal watch chưa giải quyết.
6.  Một continuation BOS đã được xác nhận.
7.  Có pullback/retest hợp lệ.
8.  Nến M5 đã đóng xác nhận tiếp diễn.
9.  Spread và volatility trong giới hạn.
10. Không có vị thế EA hiện tại.
11. Không có yêu cầu giao dịch đang chờ.
12. Daily loss, drawdown, cooldown và losing-streak guards cho phép.
13. SL hợp lệ, khoảng SL nằm trong giới hạn cấu hình.
14. Lot hợp lệ và mức lỗ dự kiến không vượt risk budget.
15. Margin đủ.
16. Giá hiện tại chưa vượt xa điểm vào dự kiến theo ngưỡng
    slippage/deviation được cấu hình.

### 7.2. SELL

Áp dụng đối xứng các điều kiện BUY.

### 7.3. Không vào lệnh

Bỏ setup nếu: - Nến xác nhận đã quá cũ. - Vùng retest bị vô hiệu hóa. -
H1/M15 mâu thuẫn. - Spread hoặc ATR vượt giới hạn. - Không tính được
SL/lot đáng tin cậy. - Lot tối thiểu vượt mức rủi ro. - EA đang có vị
thế hoặc yêu cầu giao dịch chưa hoàn tất. - Đã chạm giới hạn lỗ hoặc EA
đang cooldown.

Mọi lần bỏ setup phải có reason code trong log.

------------------------------------------------------------------------

## 8. Quản lý vốn và rủi ro

### 8.1. Ngân sách rủi ro

`risk_money = current_equity * InpRiskPercent / 100`

Với equity = 1000 và risk = 0.25%, ngân sách lỗ dự kiến là 2.50 đơn vị
tiền tệ tài khoản.

Đây không phải khoản lỗ tối đa được đảm bảo; gap, slippage hoặc thị
trường nhanh có thể làm lỗ thực tế lớn hơn.

### 8.2. Tính lot

Không dùng công thức pip-value tự đoán cho XAUUSD.

Quy trình: 1. Tính entry và SL dự kiến. 2. Dùng `OrderCalcProfit()` để
tính lỗ của một lot từ entry tới SL trong tiền tệ tài khoản. 3. Lấy trị
tuyệt đối của mức lỗ. 4. Cộng cost buffer cấu hình nếu commission không
được tính trong phép tính đó. 5. Tính
`volume = risk_money / loss_per_lot`. 6. Làm tròn xuống theo
`SYMBOL_VOLUME_STEP`. 7. Kiểm tra min/max volume. 8. Tính lại mức lỗ dự
kiến ở volume cuối. 9. Nếu vượt risk budget thì giảm volume hoặc bỏ
lệnh. 10. Dùng `OrderCalcMargin()` để kiểm tra margin.

Nếu `OrderCalcProfit()` thất bại hoặc trả kết quả không hợp lệ, bỏ lệnh
và log lỗi.

### 8.3. Daily loss lock

Định nghĩa rõ: - `day_start_equity`: equity được chụp tại thời điểm bắt
đầu ngày theo timezone đã chọn. - `daily_loss`: cần thống nhất cách tính
từ realized P/L và floating P/L. Khuyến nghị dùng drawdown equity so với
day-start equity để bảo thủ. - Nếu daily loss đạt giới hạn, khóa entry
mới cho đến ngày giao dịch tiếp theo. - Vẫn quản lý SL và vị thế đang
mở. - Không reset khóa chỉ vì EA hoặc terminal khởi động lại.

Timezone và thời điểm đổi ngày phải cấu hình rõ; ưu tiên server time
broker để nhất quán với giao dịch.

### 8.4. Equity drawdown lock

Lưu peak equity theo chính sách đã định. Nếu drawdown từ peak đạt
ngưỡng, khóa entry mới. V1 nên yêu cầu reset thủ công sau khi đạt
drawdown lock, không tự động giao dịch lại chỉ vì sang ngày mới.

### 8.5. Losing streak và cooldown

-   Cập nhật từ deal đã đóng hoàn toàn, không dựa vào floating P/L.
-   Định nghĩa cách tính phí/commission/swap trong net result.
-   Sau N lệnh thua liên tiếp, đặt `cooldown_until`.
-   Persist timestamp và losing streak để không bị reset khi restart.

### 8.6. Giới hạn rủi ro tổng

Vì V1 chỉ giữ một vị thế EA, vẫn cần kiểm tra: - Vị thế thủ công trên
cùng symbol. - Vị thế từ EA khác. - Tài khoản netting, nơi lệnh cùng
symbol có thể gộp vào một vị thế.

Mặc định an toàn: nếu phát hiện vị thế cùng symbol không thuộc quyền
quản lý rõ ràng của EA và tài khoản netting có thể gộp lệnh, không mở
lệnh mới; log cảnh báo.

------------------------------------------------------------------------

## 9. SL, break-even và trailing không TP cố định

### 9.1. Initial SL

BUY: `initial_sl = confirmed_swing_low - InpATRStopBuffer * ATR_M5`

SELL: `initial_sl = confirmed_swing_high + InpATRStopBuffer * ATR_M5`

Nếu swing không hợp lệ, ATR chưa sẵn sàng, SL quá gần hoặc quá xa so với
giới hạn cấu hình thì bỏ lệnh.

### 9.2. R ban đầu

Lưu `initial_risk_price_distance` hoặc tốt hơn là mức lỗ tiền tệ ban đầu
đã ước lượng. Không được tính lại R từ SL đã trailing, vì như vậy mốc
+1R/+1.5R sẽ thay đổi sai lệch.

Lưu tối thiểu: - Ticket/identifier. - Entry price. - Initial SL. -
Initial risk distance. - Initial risk money. - Entry timestamp. - Hướng
giao dịch.

Phải khôi phục được dữ liệu này sau khi terminal restart; nếu không,
quản lý lệnh theo R có thể không đáng tin cậy. Khi thiếu trạng thái,
không được tự suy diễn một initial R sai.

### 9.3. Break-even

Khi lợi nhuận đạt `InpBreakEvenAtR`: - BUY: SL mục tiêu = entry + cost
buffer. - SELL: SL mục tiêu = entry - cost buffer. - Chỉ sửa nếu SL mới
hợp lệ và giảm rủi ro. - Không hạ SL BUY hoặc nâng SL SELL theo hướng
tăng rủi ro.

Cost buffer nên dựa trên spread, commission, swap dự kiến và cách tính
phí của broker; nếu không thể tính chính xác, ghi rõ phần chi phí chưa
được bao gồm.

### 9.4. Trailing ATR

BUY: `atr_candidate = Bid - InpATRTrailingMultiplier * ATR_M5`

SELL: `atr_candidate = Ask + InpATRTrailingMultiplier * ATR_M5`

Phải tính theo Bid/Ask đúng chiều và xác thực stop level/freeze level.

### 9.5. Trailing theo swing

BUY:
`structure_candidate = latest_confirmed_swing_low - structure_buffer`

SELL:
`structure_candidate = latest_confirmed_swing_high + structure_buffer`

Chỉ sử dụng swing đã xác nhận, không repaint.

### 9.6. Hợp nhất ứng viên SL

Định nghĩa quy tắc rõ ràng và kiểm thử:

-   BUY: chọn mức SL hợp lệ cao nhất trong các ứng viên trailing, nhưng
    vẫn nằm đủ xa dưới giá hiện tại theo yêu cầu broker.
-   SELL: chọn mức SL hợp lệ thấp nhất trong các ứng viên trailing,
    nhưng vẫn nằm đủ xa trên giá hiện tại theo yêu cầu broker.
-   Không bao giờ nới SL theo hướng tăng rủi ro.
-   Nếu không ứng viên nào hợp lệ, giữ SL hiện tại.
-   Không xóa SL hiện tại trước khi sửa thành công.
-   Nếu broker từ chối sửa, log retcode và thử lại theo giới hạn hợp lý,
    không spam request.

### 9.7. Không có TP cố định

`TP = 0` hoặc bỏ TP theo đúng API MQL5. Thoát lệnh bằng: - SL ban đầu. -
Break-even/trailing SL bị chạm. - Quy tắc đóng theo cấu trúc đảo chiều
đã xác nhận. - Quy trình đóng khẩn cấp được cấu hình rõ ràng.

Không được gọi đây là "lợi nhuận vô hạn". Giá có thể đảo chiều và trả
lại phần lớn lợi nhuận đang có trước khi trailing stop bị khớp.

### 9.8. Terminal/VPS

EA cần chạy để tiếp tục phân tích và cập nhật trailing. SL gần nhất đã
được broker chấp nhận thường được lưu phía server, nhưng khi
terminal/VPS ngừng hoạt động, EA không thể tiếp tục nâng SL hoặc xử lý
tín hiệu đảo chiều.

------------------------------------------------------------------------

## 10. Quy trình đảo chiều

Ví dụ đang có BUY:

1.  M15 xuất hiện CHoCH giảm: chuyển `REVERSAL_WATCH`.
2.  Chặn BUY mới.
3.  Không mở SELL ngay.
4.  Chờ xác nhận cấu trúc giảm theo tiêu chí đã định.
5.  Khi xác nhận, đặt trạng thái `CLOSE_FOR_REVERSAL`.
6.  Gửi yêu cầu đóng BUY.
7.  Chờ kết quả giao dịch và xác nhận vị thế đã đóng hoàn toàn.
8.  Nếu đóng thất bại, giữ trạng thái an toàn, retry có giới hạn hoặc
    yêu cầu can thiệp.
9.  Khi không còn vị thế EA, reset state liên quan đến vị thế.
10. Đợi setup SELL mới hợp lệ trên M5.
11. Tính risk/lot mới và thực hiện các guard trước khi gửi SELL.

SELL sang BUY dùng quy trình đối xứng.

Không mở vị thế ngược chiều trong cùng một chuỗi sự kiện chỉ vì đã gửi
lệnh đóng vị thế cũ. Phải xác nhận vị thế thực tế đã đóng.

------------------------------------------------------------------------

## 11. Kiến trúc mã nguồn MQL5

### 11.1. Cấu trúc thư mục

``` text
PA_TrendRider_XAU_V1/
├── PA_TrendRider_XAU_V1.mq5
├── Include/
│   ├── Config.mqh
│   ├── Types.mqh
│   ├── MarketData.mqh
│   ├── SwingDetector.mqh
│   ├── StructureAnalyzer.mqh
│   ├── TrendClassifier.mqh
│   ├── PullbackDetector.mqh
│   ├── SignalEngine.mqh
│   ├── RiskManager.mqh
│   ├── PositionManager.mqh
│   ├── TrailingManager.mqh
│   ├── ExecutionManager.mqh
│   ├── SessionFilter.mqh
│   ├── StateManager.mqh
│   └── Logger.mqh
├── Tests/
│   ├── TestSwingDetector.mq5
│   ├── TestStructureAnalyzer.mq5
│   ├── TestRiskManager.mq5
│   └── TestStateTransitions.mq5
├── Docs/
│   ├── STRATEGY_RULES.md
│   ├── TEST_PLAN.md
│   └── CHANGELOG.md
└── README.md
```

### 11.2. Trách nhiệm module

**Config** - Input parameters. - Kiểm tra tính hợp lệ. - Không để cấu
hình nguy hiểm âm hoặc vô lý.

**Types** - Enum trạng thái thị trường, tín hiệu, lỗi, reason codes. -
Struct cho swing, setup, position context, risk state.

**MarketData** - Đọc OHLC và indicator buffers. - Kiểm tra dữ liệu
thiếu, lỗi `CopyRates`, `CopyBuffer`. - Quản lý indicator handles.

**SwingDetector** - Tạo danh sách swing đã xác nhận. - Định nghĩa tie
handling. - Tránh repaint.

**StructureAnalyzer** - BOS/CHoCH. - HH/HL/LH/LL. - Protected swing. -
Lưu event theo thời gian để không đếm lặp cùng một event.

**TrendClassifier** - Hợp nhất H1 và M15. - Trả `UNKNOWN` khi thiếu dữ
liệu hoặc mâu thuẫn.

**PullbackDetector** - Tạo và theo dõi vùng retest. - Vô hiệu hóa setup
khi giá phá vùng hoặc quá thời gian.

**SignalEngine** - Kết hợp trạng thái và setup. - Không gửi lệnh trực
tiếp. - Trả signal kèm lý do và mức giá liên quan.

**RiskManager** - Risk budget. - Lot sizing. - Daily loss, equity
drawdown, losing streak, cooldown. - Margin và volume constraints.

**PositionManager** - Tìm vị thế thuộc EA. - Lưu initial R. - Theo dõi
trạng thái đóng/mở.

**TrailingManager** - Break-even. - ATR/structure trailing. - Kiểm tra
monotonic SL.

**ExecutionManager** - Gửi, sửa, đóng lệnh. - Kiểm tra retcode. - Ngăn
request trùng và xử lý retry.

**SessionFilter** - Spread. - Volatility. - Trading hours và manual news
blackout nếu bật.

**StateManager** - Persist/restore. - Version state schema. - Xử lý dữ
liệu lưu bị thiếu/hỏng theo fail-safe.

**Logger** - File CSV. - Mức log. - Reason codes. - Không ghi bí mật
hoặc thông tin tài khoản nhạy cảm không cần thiết.

### 11.3. Quy tắc phụ thuộc

-   `SignalEngine` không tự gửi lệnh.
-   `RiskManager` là cổng bắt buộc trước mỗi entry.
-   `ExecutionManager` là module duy nhất thực hiện trade requests.
-   `TrailingManager` không được làm giảm bảo vệ hiện tại.
-   `StateManager` không được bỏ qua risk lock.
-   Không module nào được phép tự mở lệnh khi trạng thái toàn cục là
    `RISK_LOCKED`.

------------------------------------------------------------------------

## 12. Luồng xử lý và trạng thái EA

### 12.1. OnInit

1.  Kiểm tra tài khoản và symbol.
2.  Kiểm tra cấu hình.
3.  Khởi tạo indicator handles.
4.  Kiểm tra đủ dữ liệu timeframe.
5.  Khôi phục risk state và position context.
6.  Đối chiếu trạng thái lưu với vị thế/deals thực tế.
7.  Nếu có mâu thuẫn quan trọng, disable entries và log.
8.  Chỉ bật giao dịch nếu tất cả kiểm tra an toàn qua.

### 12.2. OnTick

Thứ tự gợi ý:

1.  Kiểm tra trạng thái terminal/trade permission.
2.  Cập nhật trạng thái vị thế và thực hiện quản lý SL/trailing.
3.  Cập nhật các guard rủi ro.
4.  Chỉ chạy phân tích tín hiệu khi có nến mới ở timeframe liên quan.
5.  Cập nhật swing/structure/regime.
6.  Nếu có vị thế: không mở thêm; chỉ quản lý hoặc xử lý reversal.
7.  Nếu không có vị thế: kiểm tra toàn bộ entry conditions.
8.  Tính lot và kiểm tra margin.
9.  Kiểm tra lại giá/spread/risk ngay trước khi gửi.
10. Gửi một request và chờ kết quả.
11. Ghi log.

Không tính lại tín hiệu cấu trúc trên mọi tick nếu chưa có nến mới,
nhưng không được vì thế mà bỏ qua việc quản lý vị thế.

### 12.3. OnTradeTransaction

-   Xác nhận order/deal/position changes.
-   Cập nhật net P/L của lệnh đã đóng, bao gồm chi phí theo quy tắc đã
    chọn.
-   Cập nhật losing streak.
-   Cập nhật trạng thái cooldown.
-   Ghi log.
-   Không giả định một event duy nhất đại diện cho toàn bộ vòng đời giao
    dịch; đối chiếu order, deal và position khi cần.

### 12.4. State machine

Các trạng thái thực thi gợi ý:

``` text
INITIALIZING
READY
WAITING_FOR_SETUP
ENTRY_REQUESTED
POSITION_OPEN
REVERSAL_WATCH
CLOSE_FOR_REVERSAL
COOLDOWN
DAILY_LOCKED
DRAWDOWN_LOCKED
ERROR_SAFE_MODE
```

Chuyển trạng thái phải được định nghĩa rõ. Ví dụ: - `ENTRY_REQUESTED`
không được gửi lệnh mới lần nữa khi chưa có kết quả request. -
`CLOSE_FOR_REVERSAL` không được mở chiều mới trước khi vị thế cũ đóng. -
`ERROR_SAFE_MODE` chặn entry cho đến khi lỗi được giải quyết. -
`DRAWDOWN_LOCKED` yêu cầu reset có chủ ý.

------------------------------------------------------------------------

## 13. Yêu cầu kỹ thuật và an toàn giao dịch

### 13.1. MQL5 API

Ưu tiên dùng API chính thức: - `CopyRates()` - `CopyBuffer()` -
`iATR()` - `OrderCalcProfit()` - `OrderCalcMargin()` -
`SymbolInfoDouble()` - `SymbolInfoInteger()` - `PositionSelect()` và các
API position/deal/order phù hợp - `CTrade` hoặc request structures,
nhưng phải kiểm tra retcode thực tế

### 13.2. Symbol và tick size

Phải kiểm tra: - `SYMBOL_TRADE_TICK_SIZE` - `SYMBOL_TRADE_TICK_VALUE`
hoặc các thuộc tính tick value phù hợp - `SYMBOL_VOLUME_MIN` -
`SYMBOL_VOLUME_MAX` - `SYMBOL_VOLUME_STEP` -
`SYMBOL_TRADE_STOPS_LEVEL` - `SYMBOL_TRADE_FREEZE_LEVEL` -
`SYMBOL_TRADE_MODE` - Bid/Ask hiện tại - Symbol có được phép giao dịch
không

Không chỉ dùng `NormalizeDouble(price, _Digits)`; giá phải tuân thủ tick
size thực tế.

### 13.3. Netting và hedging

-   Phát hiện chế độ tài khoản.
-   Trên netting, vị thế cùng symbol có thể gộp; không giả định magic
    number luôn cô lập hoàn toàn vị thế theo cách giống hedging.
-   Nếu có vị thế thủ công hoặc EA khác trên cùng symbol và không thể
    quản lý an toàn, chặn entry.
-   Trên hedging, chỉ thao tác đúng ticket/position thuộc EA.

### 13.4. Stop/freeze levels

Trước khi sửa SL: - Xác minh SL mới nằm đúng phía của thị trường. - Kiểm
tra khoảng cách tối thiểu theo broker. - Kiểm tra freeze level. - Kiểm
tra tick size. - Nếu không hợp lệ, giữ SL hiện tại và ghi lý do.

### 13.5. Lỗi giao dịch

-   Mỗi request phải có timeout/retry policy hữu hạn.
-   Không retry lỗi vĩnh viễn như volume sai mà không sửa nguyên nhân.
-   Không spam request trên mọi tick.
-   Nếu SL bảo vệ bị mất hoặc trạng thái position không rõ, không mở
    lệnh mới và phát cảnh báo.
-   Không tự đóng tất cả vị thế tài khoản nếu không có quyền và quy tắc
    rõ ràng.

### 13.6. Khởi động lại

-   Lưu trạng thái risk lock, day-start equity, peak equity, losing
    streak, cooldown và initial R.
-   Version hóa dữ liệu lưu.
-   Khi restart, đối chiếu state với tài khoản.
-   Nếu dữ liệu không thể phục hồi an toàn, tắt entry và yêu cầu kiểm
    tra thủ công.

------------------------------------------------------------------------

## 14. Logging, dữ liệu và báo cáo

### 14.1. CSV trade log

Mỗi giao dịch nên có: - `timestamp` - `symbol` - `magic` - `timeframe` -
`signal_id` - `direction` - `regime_h1` - `regime_m15` -
`bos_or_choch` - `entry_reason` - `entry_price` - `initial_sl` -
`volume` - `risk_money_estimated` - `spread_at_entry` - `atr_m5` -
`order_ticket` - `deal_ticket` - `exit_time` - `exit_price` -
`exit_reason` - `gross_profit` - `commission` - `swap` - `net_profit` -
`mae` - `mfe`

### 14.2. Event log

Ghi các event: - Swing được xác nhận. - BOS/CHoCH. - Thay đổi regime. -
Setup được tạo/vô hiệu hóa. - Entry bị từ chối và reason code. -
Entry/close/modify request. - Retcode broker. - Trailing candidate và SL
cuối cùng. - Daily lock/drawdown lock. - State recovery.

### 14.3. Báo cáo backtest

Báo cáo phải gồm: - Net profit sau phí. - Gross profit/loss. - Profit
factor. - Expected payoff. - Max balance/equity drawdown. - Số lệnh. -
Win rate. - Average win/loss. - Longest losing streak. - Thời gian giữ
lệnh. - MAE/MFE. - Phân tích theo regime. - Phân tích theo
tháng/phiên. - Chi phí giao dịch. - Kết quả in-sample, validation và
out-of-sample. - Cấu hình, build/version và hash hoặc commit của mã được
test.

Không dùng ảnh chụp equity curve đơn lẻ thay cho dữ liệu báo cáo.

------------------------------------------------------------------------

## 15. Kế hoạch kiểm thử

### 15.1. Unit tests

**SwingDetector** - Swing high/low đơn giản. - Đỉnh bằng nhau. - Dữ liệu
thiếu. - Swing chỉ được xác nhận sau right bars. - Không repaint sau xác
nhận.

**StructureAnalyzer** - BOS tăng/giảm. - CHoCH. - Không lặp cùng một
event nhiều lần. - Protected swing. - Không có look-ahead.

**RiskManager** - Lot theo nhiều khoảng SL. - Lot min/step/max. - Tick
size khác Digits. - `OrderCalcProfit()` thất bại. - Minimum lot vượt
ngân sách. - Margin không đủ. - Daily loss lock. - Drawdown lock. -
Cooldown và losing streak.

**TrailingManager** - BUY SL chỉ tăng hoặc giữ nguyên. - SELL SL chỉ
giảm hoặc giữ nguyên. - Không xóa SL khi modify lỗi. - Stop/freeze
level. - Tick size. - Thiếu initial R sau restart.

**State machine** - Không gửi duplicate entry. - Không đảo chiều trước
khi đóng xong. - Không mở khi risk locked. - Không reset lock khi
restart. - Lỗi execution dẫn tới safe mode.

### 15.2. Backtest baseline

-   Dùng XAUUSD và đúng thông số broker mục tiêu.
-   Chọn `Every tick based on real ticks` nếu dữ liệu khả dụng.
-   Có spread/commission/swap phù hợp.
-   Ghi cấu hình và giai đoạn dữ liệu.
-   Không tối ưu tham số trong lượt baseline.
-   Kiểm tra log giao dịch với biểu đồ.

### 15.3. Chia dữ liệu

Dùng chia theo thời gian, ví dụ: - 60% giai đoạn phát triển. - 20%
validation. - 20% out-of-sample cuối cùng.

Tỷ lệ cụ thể có thể thay đổi theo độ dài và chất lượng dữ liệu. Tuyệt
đối không dùng giai đoạn out-of-sample cuối để lặp đi lặp lại việc chỉnh
tham số.

### 15.4. Stress tests

-   Spread tăng.
-   Commission tăng.
-   Slippage bất lợi.
-   ATR cao.
-   Giai đoạn sideway kéo dài.
-   Chuỗi thua.
-   Kết nối bị ngắt.
-   EA/terminal restart khi đang có lệnh.
-   Broker từ chối sửa SL.
-   Giá gap qua SL.
-   Thông số symbol khác nhau.

### 15.5. Đánh giá

Không có một Profit Factor hay win rate đơn lẻ nào chứng minh lợi nhuận
bền vững. Đánh giá cùng: - Max drawdown. - Số giao dịch đủ để diễn
giải. - Tính ổn định theo thời gian/regime. - Sensitivity của tham số. -
Chi phí và trượt giá. - Kết quả out-of-sample. - Forward test demo.

Nếu kết quả ngoài mẫu yếu hoặc chỉ tốt ở một bộ tham số rất hẹp, không
triển khai tài khoản thật; quay lại sửa giả thuyết và kiểm thử lại trên
một quy trình có kiểm soát.

------------------------------------------------------------------------

## 16. Roadmap triển khai theo giai đoạn

### Phase A --- Dữ liệu và swing

Deliverables: - `MarketData.mqh` - `SwingDetector.mqh` - Test dữ liệu và
swing - Visual debug trên chart

Acceptance: - Không repaint sau xác nhận. - Không sử dụng nến tương
lai. - Log đúng thời điểm swing có thể được biết.

### Phase B --- Structure và regime

Deliverables: - `StructureAnalyzer.mqh` - `TrendClassifier.mqh` - State
transitions - Test BOS/CHoCH

Acceptance: - Cùng dữ liệu đầu vào cho cùng kết quả. - Không lặp event
vô hạn. - Mâu thuẫn timeframe dẫn tới trạng thái an toàn.

### Phase C --- Pullback và signal

Deliverables: - `PullbackDetector.mqh` - `SignalEngine.mqh` - Lý do
vào/không vào lệnh

Acceptance: - Entry chỉ từ nến đóng. - Setup hết hạn/vô hiệu hóa đúng. -
Không gửi trade request từ SignalEngine.

### Phase D --- Risk và execution

Deliverables: - `RiskManager.mqh` - `ExecutionManager.mqh` - Volume/SL
calculations - Error/retry handling

Acceptance: - Lot dựa trên `OrderCalcProfit()`. - Volume làm tròn
xuống. - Bỏ lệnh nếu minimum lot vượt risk budget. - Không duplicate
request. - Mọi retcode được xử lý.

### Phase E --- Position và trailing

Deliverables: - `PositionManager.mqh` - `TrailingManager.mqh` -
Break-even - ATR/structure trailing - Reversal close sequence

Acceptance: - Không TP cố định. - SL không bao giờ nới theo hướng tăng
rủi ro. - Đóng lệnh cũ trước khi xét chiều mới. - Phục hồi initial R sau
restart hoặc fail-safe nếu không thể phục hồi.

### Phase F --- Risk locks và logging

Deliverables: - `StateManager.mqh` - `SessionFilter.mqh` -
`Logger.mqh` - CSV report

Acceptance: - Risk lock tồn tại sau restart. - Log giải thích được mọi
quyết định. - Lỗi state làm chặn entry.

### Phase G --- Integration và Strategy Tester

Deliverables: - EA compile được - Unit/logic test report - Baseline
backtest report - Hướng dẫn cài đặt

Acceptance: - Không có lỗi compile. - Các warning được giải quyết hoặc
giải thích. - Không có lỗi logic nghiêm trọng còn mở. - Kết quả test có
thể tái lập.

### Phase H --- Out-of-sample và demo

Deliverables: - Out-of-sample report - Stress test report - Demo
forward-test log

Acceptance: - Đạt tiêu chí rủi ro được đặt trước. - Không phát hiện lỗi
vận hành nghiêm trọng. - Không đưa vào tài khoản thật chỉ dựa trên một
giai đoạn backtest.

------------------------------------------------------------------------

## 17. Tiêu chí nghiệm thu

### 17.1. Bắt buộc về kỹ thuật

-   [ ] Compile trong MetaEditor.
-   [ ] Không dùng dữ liệu tương lai.
-   [ ] Swing không repaint sau xác nhận.
-   [ ] BOS/CHoCH có test.
-   [ ] Signal chỉ dùng nến đã đóng.
-   [ ] Lot sizing theo thông số symbol.
-   [ ] Có initial SL.
-   [ ] Không có fixed TP.
-   [ ] Trailing không nới SL.
-   [ ] Chỉ một vị thế EA.
-   [ ] Không mở chiều mới trước khi vị thế cũ đóng.
-   [ ] Có daily loss và drawdown lock.
-   [ ] State phục hồi sau restart.
-   [ ] Có logging và reason codes.
-   [ ] Có xử lý retcode và broker constraints.
-   [ ] Có hướng dẫn cấu hình symbol broker.

### 17.2. Bắt buộc về kiểm thử

-   [ ] Unit tests cho swing/structure/risk/trailing.
-   [ ] Baseline backtest.
-   [ ] Chi phí giao dịch được tính.
-   [ ] Chia dữ liệu theo thời gian.
-   [ ] Out-of-sample không dùng để tune.
-   [ ] Stress test spread/slippage.
-   [ ] Demo forward test.
-   [ ] Báo cáo có cấu hình và phiên bản mã.
-   [ ] Không có tuyên bố lợi nhuận thiếu bằng chứng.

### 17.3. Chỉ tiêu hiệu quả

Không đặt chỉ tiêu lợi nhuận bắt buộc trước khi có dữ liệu. Trước hết
phải đặt tiêu chí rủi ro và tính toàn vẹn kỹ thuật. Sau khi có baseline
mới xác định ngưỡng chấp nhận cho PF, drawdown, expected payoff và số
lệnh, đồng thời tránh tối ưu quá mức.

------------------------------------------------------------------------

## 18. Cấu hình đề xuất

Ví dụ cấu hình logic (tên biến có thể điều chỉnh khi triển khai):

``` ini
InpTrendTF=PERIOD_H1
InpStructureTF=PERIOD_M15
InpEntryTF=PERIOD_M5

InpSwingLeft=2
InpSwingRight=2
InpATRPeriod=14
InpATRStopBuffer=0.2
InpATRTrailingMultiplier=1.2
InpAbnormalATRRatio=2.5
InpATRBaselineBars=100

InpRiskPercent=0.25
InpMaxPositions=1
InpDailyLossLimitPct=1.0
InpMaxDrawdownPct=8.0
InpMaxConsecutiveLosses=3
InpCooldownMinutes=30

InpBreakEvenAtR=1.0
InpTrailingStartR=1.5
InpUseFixedTP=false

InpEnableTrading=true
InpMagicNumber=25001001
InpLogLevel=INFO
```

Đây là cấu hình minh họa, không phải file `.set` đã xác minh tương
thích. AI phải tạo danh sách input thực tế khớp với mã nguồn, kiểm tra
mọi giá trị và ghi rõ các ngưỡng broker-specific còn cần người dùng
thiết lập.

------------------------------------------------------------------------

## 19. Prompt giao cho AI coding agent

Sao chép prompt sau vào OpenCode hoặc coding agent. Yêu cầu agent đọc
toàn bộ tài liệu trước khi sửa mã.

### PROMPT

> Bạn là kỹ sư MQL5 cấp cao, chịu trách nhiệm triển khai EA
> `PA_TrendRider_XAU_V1` theo đặc tả trong file này.
>
> **Bắt buộc:** 1. Đọc toàn bộ đặc tả trước khi code. 2. Kiểm tra môi
> trường và xác nhận có MetaEditor/compiler hay không. Không được tuyên
> bố đã compile nếu chưa chạy compiler thật. 3. Triển khai theo Phase A
> đến H; không viết toàn bộ một lần mà không test. 4. Mỗi phase phải có
> danh sách file thay đổi, quyết định kỹ thuật, test đã chạy, kết quả và
> lỗi còn tồn tại. 5. Không tự ý thay đổi định nghĩa BOS/CHoCH, risk
> model hoặc reversal sequence mà không cập nhật tài liệu. 6. Không dùng
> dữ liệu tương lai; mọi signal dùng nến đã đóng. 7. Tính lot bằng
> `OrderCalcProfit()` và kiểm tra symbol constraints. 8. Không có fixed
> TP, martingale, grid hoặc averaging down. 9. Không mở chiều mới trước
> khi xác nhận vị thế cũ đã đóng. 10. Nếu state recovery không an toàn,
> chặn entry. 11. Không tạo kết quả backtest giả. Chỉ báo cáo kết quả
> thật đã chạy. 12. Tạo README tiếng Việt, test report, changelog và
> hướng dẫn cài đặt.
>
> **Quy trình làm việc:** - Bắt đầu bằng phân tích yêu cầu và lập
> implementation plan. - Triển khai SwingDetector và test trước. - Triển
> khai StructureAnalyzer/TrendClassifier và test. - Triển khai
> pullback/signal. - Triển khai risk/execution. - Triển khai
> position/trailing/reversal. - Tích hợp state manager, guards và
> logging. - Compile, xử lý lỗi, backtest và tạo báo cáo.
>
> **Khi hoàn thành**, cung cấp: - Danh sách file hoàn chỉnh. - Lệnh/cách
> compile. - Kết quả compile thực tế. - Các test đã chạy và kết quả. -
> Các giới hạn chưa giải quyết. - Cấu hình baseline. - Báo cáo backtest
> thực tế nếu có thể chạy.
>
> Không tuyên bố chiến lược có lợi nhuận nếu chưa có bằng chứng
> out-of-sample và demo đủ chất lượng.

------------------------------------------------------------------------

## 20. Checklist vận hành demo

Trước khi bật EA: - \[ \] Đúng symbol broker. - \[ \] Đúng tiền tệ tài
khoản và thông số hợp đồng. - \[ \] Đúng timeframe và dữ liệu lịch sử đã
tải đủ. - \[ \] Spread limit được cấu hình. - \[ \] Risk percentage được
xác minh. - \[ \] Magic number không trùng EA khác. - \[ \] Terminal cho
phép Algo Trading. - \[ \] EA có quyền giao dịch theo cấu hình tài
khoản. - \[ \] SL/volume constraints đã kiểm tra. - \[ \] Daily
loss/drawdown lock hoạt động. - \[ \] Log file được ghi. - \[ \] Đã thử
restart terminal khi có vị thế demo. - \[ \] Đã thử broker từ chối
modify SL trong môi trường test phù hợp. - \[ \] Đã thử
disconnect/reconnect. - \[ \] Đã kiểm tra EA không mở lệnh trùng. - \[
\] Có kế hoạch tắt EA và xử lý vị thế nếu có lỗi.

Trong demo, theo dõi tối thiểu đủ lâu để bao gồm nhiều trạng thái thị
trường; không chỉ dựa vào vài lệnh thắng đầu tiên.

------------------------------------------------------------------------

## 21. Giới hạn và rủi ro còn lại

1.  **Price Action có yếu tố thiết kế:** swing size, protected swing,
    vùng retest và xác nhận nến đều cần định nghĩa chặt chẽ. Các lựa
    chọn khác nhau có thể tạo kết quả rất khác nhau.
2.  **Độ trễ xác nhận:** swing kiểu fractal chỉ biết sau khi các nến bên
    phải đóng; đây là đánh đổi để giảm repaint.
3.  **Trailing có thể trả lại lợi nhuận:** không TP cố định không có
    nghĩa là lợi nhuận không giới hạn.
4.  **Chi phí giao dịch:** spread, commission, swap và slippage có thể
    làm mất lợi thế của chiến lược.
5.  **Sự khác nhau giữa broker:** XAUUSD có thể khác tick size, contract
    size, volume step và stop level.
6.  **Sự kiện bất thường:** gap, thanh khoản thấp hoặc biến động tin tức
    có thể khiến lỗ thực tế vượt mức dự kiến.
7.  **Backtest không đảm bảo tương lai:** hiệu quả ngoài mẫu và demo vẫn
    không đảm bảo kết quả tài khoản thật.
8.  **Restart và mạng:** trạng thái sai lệch sau restart hoặc lỗi kết
    nối có thể ảnh hưởng quản lý lệnh.
9.  **Độ phức tạp:** càng nhiều bộ lọc càng dễ overfit. V1 cần giữ quy
    tắc tối giản, có thể kiểm chứng.

------------------------------------------------------------------------

## 22. Tài liệu tham khảo

Luôn kiểm tra tài liệu chính thức theo phiên bản MT5/MQL5 hiện tại trước
khi triển khai:

-   MQL5 Reference: https://www.mql5.com/en/docs
-   `OrderCalcProfit`:
    https://www.mql5.com/en/docs/trading/ordercalcprofit
-   `OrderCalcMargin`:
    https://www.mql5.com/en/docs/trading/ordercalcmargin
-   `CopyRates`: https://www.mql5.com/en/docs/series/copyrates
-   `CopyBuffer`: https://www.mql5.com/en/docs/series/copybuffer
-   `OnTradeTransaction`:
    https://www.mql5.com/en/docs/event_handlers/ontradetransaction
-   MetaTrader 5 Strategy Tester:
    https://www.metatrader5.com/en/terminal/help/algotrading/testing

------------------------------------------------------------------------

## Kết luận

`PA_TrendRider_XAU_V1` cần được xây dựng như một hệ thống có thể giải
thích và kiểm thử: xác định cấu trúc giá, chờ pullback, quản lý vị thế
bằng SL/trailing, và chỉ đảo chiều sau khi có xác nhận. Ưu tiên đầu tiên
là tính đúng của dữ liệu, quản lý rủi ro, và trạng thái giao dịch; ưu
tiên sau đó mới là tối ưu hiệu suất.

**Trình tự đúng:** đặc tả → triển khai module → unit test → compile →
baseline backtest → out-of-sample → stress test → demo forward test.
Không bỏ qua các bước này chỉ để sớm có một EA chạy được.
