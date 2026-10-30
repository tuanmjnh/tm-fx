# MT5 EA Lab V3 — Project Rebuild Pack

**Mục tiêu:** xây dựng lại project MT5 EA theo hướng có mã nguồn thật, build được, kiểm thử được trong Strategy Tester và có đường chạy demo được kiểm soát. V3 thay thế các chỉ dẫn triển khai V2; tài liệu V2 cũ chỉ còn giá trị tham khảo/audit.

## Phạm vi chiến lược

1. **PATrendRiderXAUv1** — giữ nguyên logic nếu tìm thấy source gốc; nếu chỉ có đặc tả, có thể xây bản `SPEC_REIMPLEMENTATION` nhưng tuyệt đối không gọi đó là bản gốc tương đương.
2. **GridEA** — EA độc lập, cấu hình khoảng cách/layer/thoát rổ, giới hạn exposure có thể điều chỉnh.
3. **DCAEA** — EA độc lập; phân biệt DCA theo thời gian với averaging-in theo biến động giá.
4. **InfiniteRunner XAU** — source V1/V2 hiện có được đưa vào vùng legacy để audit và quyết định migrate; không được lấy nó thay cho ba bot cốt lõi.
5. **Pine indicator adapter** — module tùy chọn sau khi core đã build/test được; không làm phụ thuộc bắt buộc cho ba bot cốt lõi.
6. **AI/ML** — chỉ backlog; không triển khai trong V3 hiện tại.

## Các chế độ chạy

- `SIGNAL_DIAGNOSTIC`: tính tín hiệu, hiển thị BUY/SELL/NO_TRADE và lý do; không gửi yêu cầu giao dịch.
- `STRATEGY_TESTER`: cho phép EA gửi yêu cầu giao dịch **bên trong MT5 Strategy Tester**, nơi MT5 mô phỏng khớp lệnh trên dữ liệu lịch sử.
- `DEMO_EXECUTION`: chỉ chạy khi runtime xác minh chính xác tài khoản là DEMO và người vận hành chủ động bật chế độ này. Mọi chế độ tài khoản khác hoặc không xác định được phải bị từ chối. Không có REAL/LIVE mode.

AI coding agent không được tự đăng nhập, bật Algo Trading hoặc tự chạy bot trên tài khoản broker. Agent phải tạo code, compile/test khi môi trường local cho phép và cung cấp hướng dẫn; người vận hành tự chủ động thực hiện bước forward-test demo.

## Nguyên tắc sửa lỗi V2

- Không dừng ở Phase 0. Khi được giao triển khai V3, AI phải thực hiện lần lượt các phase độc lập, lưu tiến độ và tiếp tục phần không bị blocker.
- Không yêu cầu đủ mọi bot mới cho phép build. Mỗi EA có thể build/test độc lập.
- Không để filter chiến lược bắt buộc cứng. Filter phải có `Enable...` và cấu hình rõ.
- Phải có `ZERO_TRADE_DIAGNOSTICS`: chỉ ra chính xác pipeline bị chặn ở đâu.
- Không có vị thế/layer/volume vô hạn. Giới hạn chiến lược được điều chỉnh trong biên hợp lệ; kiểm tra kỹ thuật và chốt rủi ro cốt lõi không được bypass.
- Mỗi build/backtest phải ghi bằng chứng thực tế. Không tự tạo kết quả.

## Nguồn đầu vào đã được đưa vào gói

- `inputs/legacy_sources/InfiniteRunner_XAU.mq5`
- `inputs/legacy_sources/InfiniteRunnerXAUV2DemoEA.mq5`
- `inputs/specifications/PA_TrendRider_XAU_V1_Specification_Vietnamese.md`
- `inputs/legacy_docs/STRATEGY_SPEC_GRID_DCA_TRAILING.md`
- `inputs/legacy_docs/ROADMAP_GRID_DCA_TRAILING_SIMULATION.md`
- `inputs/legacy_docs/GITHUB_OPEN_SOURCE_RESEARCH.md`

**Thiếu source quan trọng:** GridEA/DCAEA chưa có mã `.mq5` hoàn chỉnh; `PATrendRiderXAUv1` hiện có đặc tả nhưng chưa có source EA gốc trong các file đã nhận; InfiniteRunner V2 tham chiếu các file `.mqh` chưa có trong gói. Xem `docs/SOURCE_INVENTORY.md`.

## Bắt đầu

1. Giải nén gói và mở thư mục `MT5_EA_Lab_V3_Project` trong VS Code/IDE.
2. Đọc `ROADMAP_MT5_EA_LAB_V3.md` và `PROMPT_AI_IMPLEMENT_V3.md`.
3. Giao AI thực hiện full roadmap; không dùng lại prompt V2 yêu cầu dừng sau Phase 0.
4. AI phải chạy `scripts/check-environment.ps1`, `scripts/validate-project.ps1`, rồi compile các entry-point đã có bằng MetaEditor.
5. Với EA đã compile: chạy Strategy Tester từng EA, ghi report và `NO_TRADE_DIAGNOSIS.md` nếu số giao dịch bằng 0.
6. Chỉ sau khi build/test hoàn chỉnh mới đọc `docs/INSTALL_BUILD_BACKTEST_DEMO.md` để thực hiện kiểm thử demo một cách chủ động.

## Tài liệu chính

- `ROADMAP_MT5_EA_LAB_V3.md` — roadmap và phase/acceptance.
- `PROMPT_AI_IMPLEMENT_V3.md` — prompt giao AI coding agent.
- `docs/V2_FAILURE_AUDIT.md` — audit nguyên nhân V2.
- `docs/ARCHITECTURE.md` — kiến trúc project.
- `docs/CONFIGURATION_MATRIX.md` — input nào có thể bật/tắt/điều chỉnh.
- `docs/ZERO_TRADE_DIAGNOSTICS.md` — quy trình tìm nguyên nhân không có lệnh.
- `docs/INSTALL_BUILD_BACKTEST_DEMO.md` — build/test và forward-test demo.
- `docs/SOURCE_INVENTORY.md` — file có/thiếu và tình trạng xác minh.
- `research/GITHUB_RESEARCH_PROCESS.md` — quy trình audit mã nguồn mở.

## Trạng thái

Đây là **project specification + bootstrap scripts + source inputs**, chưa phải các EA V3 hoàn chỉnh. Chỉ đánh dấu PASS khi source được triển khai, MetaEditor compile và Strategy Tester thực sự chạy.
