# V2 Failure Audit — vì sao AI làm theo mà project không chạy được

**Nguồn rà soát:** `MT5_EA_Lab_v2/README.md`, `ROADMAP_MT5_EA_LAB_V2.md`, `PROMPT_AI_IMPLEMENT_MT5_EA_LAB_V2.md`, source `InfiniteRunnerXAUV2DemoEA.mq5`, source `InfiniteRunner_XAU.mq5`, và `PA_TrendRider_XAU_V1_Specification_Vietnamese.md`.

## 1. Nhóm lỗi ở quy trình AI

### 1.1 Prompt yêu cầu dừng sau Phase 0

Prompt V2 ghi: “Chỉ hoàn thành Phase 0 rồi dừng để báo cáo”. Nếu người dùng chỉ dán prompt một lần, agent có thể hoàn thành inventory rồi dừng đúng yêu cầu; nó chưa được yêu cầu tiếp tục build các EA.

**Sửa trong V3:** prompt phải yêu cầu chạy end-to-end; checkpoint sau mỗi phase nhưng tự tiếp tục phase tiếp theo nếu không có blocker cần user decision.

### 1.2 Yêu cầu AI không thực hiện execution và chỉ tạo docs/config

Prompt V2 yêu cầu không đặt/sửa/đóng lệnh khi AI đang làm và ở demo phase chỉ tạo docs/config, người dùng tự chạy. Đây là quy tắc điều khiển hành động của coding agent, nhưng V2 chưa mô tả rõ sự khác biệt giữa:

- EA được viết để gửi trade requests trong Strategy Tester;
- EA có thể được người dùng attach và chủ động test trên demo;
- AI agent không được tự điều khiển terminal/tài khoản.

**Sửa trong V3:** phân tách run modes; tester trading simulation được implement rõ; demo code path có demo account guard; AI agent chỉ build/test code và không tự bật tài khoản.

## 2. Nhóm thiếu source/dependencies

### 2.1 Project V2 chủ yếu là tài liệu

Trong gói V2 đã kiểm tra có README, roadmap, prompt, research và docs; không có source hoàn chỉnh cho GridEA/DCAEA hoặc thư viện core.

**Hậu quả:** AI phải tự dựng phần lớn implementation dù tài liệu nói “research rồi tái sử dụng”; tài liệu không thể biên dịch.

### 2.2 PATrendRiderXAUv1 thiếu source EA gốc

Input có đặc tả `PA_TrendRider_XAU_V1_Specification_Vietnamese.md`, nhưng chưa có source `.mq5/.mqh` của bot gốc. Đặc tả kỹ thuật có thể làm cơ sở triển khai một bản mới theo spec, nhưng không chứng minh được parity với bot gốc.

**Sửa trong V3:** cho phép build `PATrendRiderXAUv1_SpecBuild` dựa trên spec; nếu sau đó có source gốc thì tạo adapter/port và regression compare. Ghi rõ source-parity status.

### 2.3 InfiniteRunner V2 thiếu 8 include dependencies

Source được cung cấp include:

- `../Include/Exec/ExecBroker.mqh`
- `../Include/Sim/SimTypes.mqh`
- `../Include/Sim/SimValidate.mqh`
- `../Include/Sim/SimRiskGuard.mqh`
- `../Include/Sim/SimLogger.mqh`
- `../Include/InfiniteRunner/IRTypes.mqh`
- `../Include/InfiniteRunner/IRDirection.mqh`
- `../Include/InfiniteRunner/IRTrailing.mqh`

Các file trên chưa có trong gói source được nhận. Vì vậy chỉ có `.mq5` không đủ để compile. Không thể xác nhận các logic ẩn trong các include.

## 3. Nhóm thiết kế làm zero-trade khó chẩn đoán

### 3.1 Các ràng buộc V2 hard-code trong `ValidateInputs`

Source `InfiniteRunnerXAUV2DemoEA.mq5` có các điều kiện:

- `InpMaxPositions` bắt buộc đúng 1 (`max_positions_must_be_one`).
- `InpMaxTradesPerDay` bắt buộc từ 1 trở lên; không có semantics `0 = OFF`.
- `InpMaxSpreadPoints` bắt buộc dương; không thể tắt spread points filter bằng 0.
- `InpRiskPercent` phải nằm trên 0 và không vượt 10 khi chọn risk mode.
- `InpSafetyTpPoints` phải ít nhất bằng `InpMinStopPoints`.
- `InpMaxLots` phải dương.

Một số giới hạn có lý do quản trị rủi ro, nhưng validation quá cứng làm profile diagnostic khó cấu hình. V3 phải tách “filter OFF” khỏi “giá trị input sai”.

### 3.2 Default filters có thể chặn entry

V2 defaults gồm EMA MTF; H1/M15/M5; cooldown 30 phút; min 3 bars; max 50 trades/day; max spread 600 points; abnormal ATR ratio 2.5; max positions 1; risk 0.25%; max lots 0.20; daily loss 1%; equity DD 8%; 3 consecutive losses; initial SL 5000 points; min/max stop 500/20000; mandatory safety TP 100000 points.

Mỗi điều kiện có thể hợp lý riêng trong một profile, nhưng khi nhiều điều kiện cùng bật, xác suất zero-trade tăng. Thêm nữa, XAUUSD contract/point/tick và spread phải được đọc từ symbol thật; không được mặc định mọi hậu tố/symbol có cùng contract.

### 3.3 Risk sizing có thể từ chối lot tối thiểu

`SizePosition()` tính lỗ 1 lot bằng `OrderCalcProfit`, tính volume từ risk budget rồi floor theo volume step. Nếu volume tính ra thấp hơn `SYMBOL_VOLUME_MIN`, nó trả `min_lot_over_budget` và không vào lệnh.

Đây là hành vi bảo vệ hợp lệ, không nên bypass trong demo. Nhưng V3 cần diagnostic profile/test giải thích chính xác. Trong Strategy Tester có thể dùng preset fixed-volume nhỏ, hữu hạn, để kiểm tra execution pipeline riêng; phải ghi rõ đây là smoke/diagnostic, không đại diện risk profile.

### 3.4 Nhiều điều kiện dữ liệu trả về im lặng

V2 `OnTick()` return sớm nếu Bars dưới warmup; MTF history chưa đủ; Bid/Ask sai. `RefreshMarketData()` có thể fail do `CopyBuffer` chưa đủ bars. Nếu không có panel/counters đầy đủ, tester có thể kết thúc với 0 trades mà user không biết đang ở `WAITING_FOR_DATA`, `NO_SIGNAL` hay `BLOCKED_BY_FILTER`.

### 3.5 TP bảo vệ xa mâu thuẫn mục tiêu Runner

V2 yêu cầu `InpSafetyTpPoints` bắt buộc và tạo `tp_price` bằng safety distance. Điều này khác với yêu cầu Runner không dùng fixed TP. V3 cần `TP_MODE=NONE/FIXED/ATR/BASKET` theo chiến lược, và `NONE` hợp lệ nếu strategy spec chọn runner trailing.

### 3.6 State management có điểm chưa hoàn chỉnh

- `InpResetStateOnInit` được khai báo nhưng không thấy được sử dụng trong source được cung cấp.
- `ReadStateFile()` chỉ đặt `restored=true` khi đọc thành công; do đó nhánh `if(restored && !state_ok)` sau lời gọi không thể bắt được trường hợp hàm trả false.
- Các file state phải được kiểm tra đủ key/version/magic và ghi rõ state missing/corrupt/version mismatch.

V3 cần có parser trả enum trạng thái rõ ràng, không dùng hai biến bool có logic mâu thuẫn.

## 4. Nhóm thiếu build/test evidence

- Không có source đầy đủ để compile cả ba bot.
- Không có `.set` presets thực tế khớp với input code.
- Không có compile logs của từng EA.
- Không có Strategy Tester reports/reproducible settings.
- Không có zero-trade report.
- Scripts folder trong gói V2 không có scripts thực thi.

Vì vậy, V2 chưa đủ điều kiện gọi là project runnable.

## 5. Những gì V3 phải làm khác

1. Mỗi bot source riêng, build/test độc lập.
2. Có SmokeTestEA để xác minh terminal/compiler/tester pipeline trước strategy.
3. Có presets `diagnostic_loose`, `baseline`, `risk_stress`, `demo_guarded`.
4. Filters có ON/OFF rõ nghĩa; không dùng input `0` mơ hồ.
5. Không bỏ technical invariants hoặc giới hạn exposure hữu hạn.
6. Log toàn bộ stage counters và first blocker.
7. Không yêu cầu tất cả source user phải có mới làm phần core.
8. Prompt V3 yêu cầu thực thi các phase tuần tự, không dừng sau inventory.
