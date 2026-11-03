# InfiniteRunner XAU V3 — Nâng cấp trailing, risk và quy trình tối ưu

- **EA nguồn:** `InfiniteRunnerXAUV3DemoEA.mq5`
- **Phiên bản:** 3.00
- **Nền tảng:** MetaTrader 5 / MQL5
- **Symbol mục tiêu:** XAUUSD (cần kiểm tra đúng hậu tố và thông số contract của broker)
- **Khung mặc định:** Entry M5, quản lý cấu trúc M15
- **Trạng thái:** Bản nâng cấp kỹ thuật để backtest; chưa được xác nhận có lợi nhuận.

> **Cảnh báo:** Không có bộ trailing nào bảo đảm lợi nhuận. V3 thay đổi cách quản lý SL theo hướng giữ lệnh chạy theo xu hướng lâu hơn, nhưng có thể làm giảm tỷ lệ thắng hoặc trả lại một phần lợi nhuận mở. Chỉ đánh giá bằng Strategy Tester, dữ liệu real ticks, chi phí giao dịch thực tế và forward test demo. Không chạy tài khoản thật.

---

## 1. Vấn đề của V2 và lý do nâng cấp

Triệu chứng bạn mô tả là winrate cao nhưng PnL cuối kỳ âm: nhiều lệnh chốt lời nhỏ hoặc hòa vốn, trong khi một lệnh quay đầu chạm SL ban đầu có thể xóa lợi nhuận của nhiều lệnh thắng.

Đây là vấn đề **kỳ vọng lợi nhuận (expectancy)** chứ không chỉ là winrate. Ví dụ minh họa:

- 80% lệnh thắng trung bình `+0.20R`.
- 20% lệnh thua trung bình `-1.00R`.
- Expectancy = `0.8 × 0.20 - 0.2 × 1.00 = -0.04R/lệnh`, chưa tính spread, commission và swap.

Trong V2, `ManageTrailing()` kiểm tra Break-even, rồi Step Trailing, sau đó mới tới Fixed/ATR Trailing. Khi Step Trailing tạo candidate, phần Fixed/ATR bị bỏ qua. Vì vậy một nấc khóa lời nhỏ có thể trở thành phương án duy nhất được xét, dù mức trailing khác có thể bảo vệ tốt hơn hoặc phù hợp với xu hướng hơn.

V2 cũng có các mặc định dễ gây hiểu nhầm:

- `InpLotMode = IR_LOT_FIXED`: EA dùng lot cố định `0.01`, không dùng `InpRiskPercent` để tính lot.
- `InpEnableStepTrailing = true`: khóa SL theo các nấc points.
- `InpEnableExecution = true`: mặc định bật gửi lệnh trong môi trường được guard cho phép.
- `InpBreakEvenTriggerR = 0`: Break-even tắt mặc định.

V3 thay đổi các điểm trên, nhưng **giữ nguyên bộ quyết định vào lệnh V2** để có thể so sánh riêng hiệu quả của việc quản lý lệnh.

## 2. Các thay đổi chính trong V3

### 2.1. Structure Trailing trên M15

Khi lệnh đạt ít nhất `1.0R`, EA bắt đầu kiểm tra cấu trúc M15. SL chỉ được đề xuất sau khi có swing đã xác nhận:

- Lệnh BUY: tìm swing low đã hình thành sau thời điểm mở lệnh, đặt SL dưới swing low một khoảng đệm ATR.
- Lệnh SELL: tìm swing high đã hình thành sau thời điểm mở lệnh, đặt SL trên swing high một khoảng đệm ATR.
- Pivot phải có số nến xác nhận ở cả hai phía. Mặc định `2` nến mỗi phía.
- Chỉ dùng nến đã đóng; không lấy giá trị từ nến M15 đang chạy.
- Chỉ đánh giá trailing một lần khi xuất hiện nến mới trên `InpStructureTF`.
- SL không bao giờ nới lỏng: BUY chỉ được nâng SL, SELL chỉ được hạ SL.

Công thức buffer:

```text
BUY  candidate SL = confirmed swing low  - M15 ATR × buffer multiplier
SELL candidate SL = confirmed swing high + M15 ATR × buffer multiplier
```

Mục đích là đặt SL sau cấu trúc giá thay vì kéo SL quá sát theo từng dao động ngắn. Đây không phải bảo đảm rằng mỗi swing đều là hỗ trợ/kháng cự tốt.

### 2.2. Chọn candidate SL tốt nhất

Các phương án có thể tạo SL gồm:

1. Break-even.
2. Structure trailing.
3. Step trailing (tùy chọn).
4. Fixed/ATR classic trailing (tùy chọn).

V3 kiểm tra từng candidate với điều kiện broker, stop-level, khoảng cách cấu hình và nguyên tắc monotonic. Sau đó:

- BUY: chọn candidate hợp lệ cao nhất.
- SELL: chọn candidate hợp lệ thấp nhất.

Một candidate không hợp lệ không còn chặn các candidate khác. Đây là sửa đổi quan trọng so với thứ tự ưu tiên cứng ở V2.

### 2.3. Break-even trễ hơn

Mặc định V3 đặt `InpBreakEvenTriggerR = 1.5`. Ý tưởng là không vội kéo SL về entry khi lệnh mới có một nhịp lợi nhuận nhỏ. Khi đạt +1.5R, EA có thể khóa gần hòa vốn cộng buffer; nếu Structure Trailing tạo được SL bảo vệ tốt hơn thì candidate cấu trúc được chọn.

Đây chỉ là bộ tham số khởi đầu để kiểm thử. Nên so sánh ba cấu hình `0R (off)`, `1.0R`, `1.5R`; không mặc định rằng 1.5R sẽ luôn tốt hơn.

### 2.4. Risk-based lot là mặc định

`InpLotMode = IR_LOT_RISK`, `InpRiskPercent = 0.25`.

EA tính khoản lỗ giả định từ entry đến initial SL bằng `OrderCalcProfit` thông qua `ExecCalcProfit`, sau đó làm tròn volume xuống theo volume step và kiểm tra lại rủi ro. Nếu lot tối thiểu của broker đã vượt ngân sách rủi ro, EA bỏ qua lệnh thay vì tự nâng lot.

Với equity 1.000 USD, risk 0.25% tương ứng ngân sách lỗ dự kiến khoảng 2.50 USD cho một lệnh trước các sai khác do trượt giá, gap hoặc khớp lệnh. Đây không phải giới hạn lỗ tuyệt đối.

### 2.5. An toàn khi khởi chạy

`InpEnableExecution = false` mặc định. Trạng thái này không gửi lệnh. Để backtest đủ vòng đời lệnh trong Strategy Tester, cần bật `InpEnableExecution = true` trong Tester; chỉ bật gửi lệnh trên tài khoản demo khi đã kiểm tra. Hard guard hiện có trong EA vẫn phải được giữ nguyên; V3 không được thiết kế để chạy tài khoản real.

## 3. Bảng tham số mặc định V3

| Nhóm | Tham số | Mặc định | Ý nghĩa |
|---|---|---:|---|
| Execution | `InpEnableExecution` | `false` | Không gửi lệnh mặc định |
| Entry | `InpDirectionMode` | `IR_DIR_LEGACY_EMA` | Giữ logic vào lệnh V2 để so sánh công bằng |
| Entry | `InpEntryTF` | M5 | Khung quyết định tín hiệu |
| Risk | `InpLotMode` | `IR_LOT_RISK` | Tính lot theo rủi ro |
| Risk | `InpRiskPercent` | 0.25% | Rủi ro danh nghĩa mỗi lệnh |
| Risk | `InpMaxLots` | 0.20 | Trần volume |
| Risk | `InpMaxDailyLossPct` | 1.0% | Khóa khi lỗ trong ngày vượt ngưỡng |
| Risk | `InpMaxDrawdownPct` | 8.0% | Khóa drawdown từ equity peak |
| Risk | `InpMaxConsecutiveLosses` | 3 | Ngưỡng chuỗi lệnh thua |
| Initial SL | `InpSlMode` | `IR_SL_FIXED` | Giữ kiểu initial SL của V2 để so sánh |
| Initial SL | `InpInitialSlPoints` | 5000 | Khoảng SL theo point của broker |
| BE | `InpBreakEvenTriggerR` | 1.5R | Chỉ bắt đầu bảo vệ BE khi đạt 1.5R |
| Structure | `InpEnableStructureTrailing` | `true` | Bật trailing theo swing |
| Structure | `InpStructureTF` | M15 | Khung phát hiện swing và ATR buffer |
| Structure | `InpSwingLookback` | 80 | Số nến đã đóng dùng tìm swing |
| Structure | `InpSwingConfirmBars` | 2 | Số nến xác nhận mỗi bên pivot |
| Structure | `InpStructureStartR` | 1.0R | Bắt đầu structure trailing từ 1R |
| Structure | `InpStructureBufferAtr` | 0.25 | Buffer = 0.25 × ATR M15 |
| Classic | `InpEnableClassicTrailing` | `false` | Tắt fixed/ATR trailing cũ |
| Step | `InpEnableStepTrailing` | `false` | Tắt khóa lời theo nấc |
| Safety TP | `InpSafetyTpPoints` | 100000 | TP rất xa theo contract hiện có |

### Lưu ý về points của XAUUSD

Không được hiểu `1000 points` luôn bằng 1 USD. Giá trị point phụ thuộc số chữ số và cấu hình symbol của broker. Ví dụ symbol có `SYMBOL_POINT = 0.001` thì 1000 points tương đương 1.000 đơn vị giá; nếu `SYMBOL_POINT = 0.01` thì tương đương 10.00 đơn vị giá. Cần kiểm tra `Digits`, `Point`, `Tick size`, contract size, volume min/step và stop level trước khi tối ưu.

## 4. Quy trình backtest nên làm

### Giai đoạn A — kiểm tra đúng logic và cấu hình

1. Sao lưu V2 và file state/log cũ.
2. Đặt `InfiniteRunnerXAUV3DemoEA.mq5` vào cùng vị trí thư mục EA V2 để các đường dẫn include tương đối `../Include/...` tiếp tục đúng.
3. Mở MetaEditor, compile và xử lý lỗi include/API trước khi chạy.
4. Kiểm tra đúng symbol XAUUSD của broker, timeframe M5, dữ liệu H1/M15/M5 và thông số point/tick.
5. Dùng Strategy Tester với **Every tick based on real ticks** nếu broker cung cấp dữ liệu phù hợp.
6. Bật `InpEnableExecution=true` trong Strategy Tester để EA thực sự mở/đóng lệnh trong mô phỏng. Khi chạy live terminal, chỉ sử dụng tài khoản demo và giữ hard guard.

### Giai đoạn B — so sánh riêng exit, không đổi entry

Không đổi EMA, EntryTF, bộ lọc spread, initial SL, ngày dữ liệu hoặc risk giữa các lượt so sánh.

| Run | Cấu hình exit | Mục tiêu |
|---|---|---|
| A | V2 nguyên bản | Baseline |
| B | V3 Structure M15, BE 1.5R, classic off, step off | Đo hiệu quả swing trailing |
| C | Như B, BE = 1.0R | Kiểm tra khóa rủi ro sớm hơn |
| D | Như B, BE = 0 (off) | Xem cấu trúc có tự quản lý đủ không |
| E | Như B, swing confirm = 3, buffer ATR = 0.35 | Swing chậm hơn, ít nhạy hơn |
| F | Như B, start = 1.2R, buffer ATR = 0.25 | Chỉ trail sau khi lệnh đi xa hơn |

Mỗi lượt phải dùng cùng một giai đoạn dữ liệu. Không lấy kết quả đẹp nhất của một đoạn ngắn rồi kết luận bot đã tối ưu.

### Giai đoạn C — đánh giá entry riêng

Sau khi chọn được nhóm exit ổn định, mới so sánh `IR_DIR_LEGACY_EMA` với `IR_DIR_EMA_MTF`. Không đổi entry và trailing trong cùng lượt thử nghiệm đầu tiên, nếu không sẽ không biết yếu tố nào tạo ra khác biệt.

### Chỉ số cần so sánh

| Chỉ số | Điều cần quan sát |
|---|---|
| Net profit | Lợi nhuận ròng sau commission, swap và spread |
| Profit Factor | Tổng gross profit / gross loss; không nhìn riêng chỉ số này |
| Expectancy (R/trade) | Lợi nhuận kỳ vọng trên mỗi lệnh tính theo initial risk |
| Average win / average loss | Xác định lệnh thắng có đủ lớn so với lệnh thua |
| Max equity drawdown | Mức sụt giảm vốn lớn nhất |
| MFE / MAE | Lệnh từng đi thuận/ngược bao xa trước khi đóng |
| Win rate | Chỉ là một chỉ số, không dùng độc lập |
| Trade count | Cần đủ số lệnh để tránh kết luận từ mẫu quá nhỏ |
| Monthly/regime split | Xem hiệu quả theo tháng và giai đoạn trend/range |
| Exit reason | Initial SL, BE, structure SL, safety TP, manual/kill/halt |

Một cấu hình tốt hơn nên cải thiện expectancy và drawdown ngoài mẫu, không chỉ tăng winrate. Chia dữ liệu theo thời gian: giai đoạn đầu để phát triển, giai đoạn tiếp theo để kiểm chứng ngoài mẫu; sau đó forward test demo. Tránh tối ưu đồng thời quá nhiều tham số.

## 5. Điều V3 chưa làm và giới hạn cần lưu ý

### 5.1. Chưa có partial close

V3 hiện vẫn quản lý một vị thế nguyên khối (runner). Tôi chưa thêm đóng 30–50% ở 1.5R vì file được cung cấp chỉ có EA chính, chưa có `ExecBroker.mqh`. EA yêu cầu mọi lệnh đi qua lớp ExecBroker/ExecGuard; không nên đoán chữ ký hàm partial-close hoặc bỏ qua lớp kiểm soát đó. Nếu muốn thêm partial-profit an toàn, cần rà đúng API đóng một phần, volume step/minimum, trạng thái netting/hedging và cách cập nhật `g_pos_volume` / state.

### 5.2. Safety TP vẫn còn

Mã V2 có contract bắt buộc gắn một safety TP rất xa (`ADR 0004`). V3 giữ nguyên ràng buộc đó và giữ `InpSafetyTpPoints=100000`. Vì thế đây chưa phải lệnh không TP tuyệt đối; đó là một mức thoát dự phòng ở xa. Chỉ có thể chuyển sang `TP=0` sau khi kiểm tra `ExecBroker.mqh`, guard, order validation và broker. Không tự xóa safety TP trong mỗi EA khi chưa biết lớp execution có cho phép hay không.

### 5.3. Chưa thay đổi thuật toán vào lệnh

Mặc định vẫn là Legacy EMA để bảo đảm so sánh exit. V3 chưa triển khai BOS/CHoCH hoặc Price Action entry. Nếu muốn chuyển EA sang PA_TrendRider, đó là một nhánh nâng cấp riêng vì thay đổi thuật toán vào lệnh sẽ làm kết quả backtest không còn so sánh trực tiếp với V2.

### 5.4. Chưa thể xác nhận compile ở môi trường này

File upload hiện có chỉ gồm `InfiniteRunnerXAUV2DemoEA.mq5`; các include tương đối như `../Include/Exec/ExecBroker.mqh`, `SimRiskGuard.mqh`, `IRTypes.mqh`, `IRDirection.mqh` và `IRTrailing.mqh` chưa được cung cấp, đồng thời không có MetaEditor compiler trong môi trường xử lý. Vì vậy source V3 đã được kiểm tra cấu trúc và cân bằng dấu ngoặc ở mức tĩnh, nhưng **chưa được compile hoặc chạy Strategy Tester**. Cần compile trong đúng cây project gốc trước khi sử dụng.

## 6. Lưu ý về state file và nâng cấp từ V2

- Dùng `InpStateFile` riêng cho V3, ví dụ `infinite_runner_demo_state_v3.csv`, để tránh EA V3 đọc state do V2 tạo ra.
- Dùng log riêng, ví dụ `infinite_runner_demo_v3.csv`, để không trộn kết quả V2 và V3.
- Không bật `InpResetStateOnInit` khi còn vị thế đang mở. Trước khi thay phiên bản EA, kiểm tra account và đảm bảo không có runner của V2 bị bỏ quên.
- Giữ `InpMagicNumber` khác nếu muốn chạy song song V2 và V3 trên demo; không chạy hai EA cùng magic/symbol.
- EA có kill-switch file. Kiểm tra thư mục Files của MT5 và xóa/tắt file kill-switch chỉ khi chủ động muốn khởi động lại thử nghiệm.

## 7. Khuyến nghị cấu hình thử nghiệm đầu tiên

Bắt đầu với các giá trị mặc định của V3, giữ nguyên entry V2, risk 0.25%, initial SL 5000 points và Structure M15. Sau đó chạy các biến thể BE `0 / 1.0 / 1.5R` theo bảng ở trên.

Nếu tester vẫn cho thấy một số lệnh có MFE rất lớn nhưng lợi nhuận thực nhận nhỏ, hãy kiểm tra log `SL_UPDATE` và MFE/MAE trước khi giảm buffer ATR. Nếu lệnh thường quay từ +1R hoặc +1.5R về initial SL trước khi xuất hiện pivot M15, đây là dấu hiệu cần thử BE sớm hơn hoặc thêm một lớp partial-profit — không nên giải quyết bằng cách tăng Step Trailing thật sát.

**Kết luận:** V3 là một bản thử nghiệm quản lý lệnh theo xu hướng có kiểm soát hơn, không phải “preset chắc thắng”. Bước tiếp theo có giá trị nhất là compile trên cây project đầy đủ, chạy cùng dữ liệu V2/V3, rồi dùng report và CSV log để chọn tham số dựa trên expectancy, drawdown và khả năng giữ runner.
