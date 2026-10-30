# PROMPT — Upgrade InfiniteRunner_XAU.mq5 to V2

Bạn là Senior MQL5 Engineer và Quant QA Engineer. Nhiệm vụ là nâng cấp source hiện có `InfiniteRunner_XAU.mq5` theo đặc tả `INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md`.

## 0. Nguyên tắc bắt buộc

1. Đọc toàn bộ source `.mq5` và đặc tả trước khi sửa.
2. Giữ source gốc nguyên vẹn; tạo `InfiniteRunner_XAU_V2.mq5` và thư mục/module mới. Không ghi đè V1.
3. Mặc định chỉ chạy Strategy Tester và tài khoản DEMO. Thêm hard guard từ chối lệnh nếu terminal đang ở tài khoản REAL. Không tạo tùy chọn bypass guard trong cấu hình thông thường.
4. Không tuyên bố đã compile/test nếu chưa thực sự chạy MetaEditor/compiler/Strategy Tester. Nếu môi trường agent không có MT5/MetaEditor, ghi `BLOCKED` và đưa lệnh/hướng dẫn người dùng chạy thủ công.
5. Không đưa ra lời hứa “lợi nhuận vô cực”, “tối ưu chắc chắn” hoặc win rate bảo đảm. Không chọn cấu hình chỉ vì net profit cao.
6. Không dùng nến đang chạy (`shift 0`) cho quyết định Direction/Entry. Quản lý SL theo tick có thể đọc tick mới nhất, nhưng tín hiệu chiến lược phải dựa trên nến đã đóng.
7. Không tự ý thay đổi semantics mà không cập nhật docs, tests và changelog.
8. Không gửi lệnh trùng; không mở lại ngay sau khi vị thế đóng trừ khi có trigger mới ở nến EntryTF mới và cooldown/guards đều đạt.
9. Không xóa SL cũ trước khi SL mới được broker chấp nhận. Không bao giờ nới SL theo hướng tăng rủi ro.
10. Mọi open/modify/close cần kiểm tra `CTrade` bool return VÀ `ResultRetcode()` / `ResultRetcodeDescription()`.

## 1. Phase 0 — Kiểm kê trước khi code

- Đọc `InfiniteRunner_XAU.mq5` và `INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md`.
- Xác nhận MetaEditor/terminal có sẵn không, phiên bản compiler nếu có, cấu trúc thư mục, Git status.
- Ghi lại chính xác V1 đang làm gì và xác nhận các phát hiện trong review.
- Tạo `Docs/IMPLEMENTATION_PLAN.md`, `Docs/PROGRESS.md`, `Docs/CHANGELOG.md`.
- Chưa sửa thuật toán trong phase này.

## 2. Phase 1 — Tạo V2 skeleton và broker compatibility

- Tạo `InfiniteRunner_XAU_V2.mq5` cùng module Include độc lập.
- Inputs có group rõ ràng: General, Direction, Entry, Risk, Initial SL, Trailing, Broker Filters, Logging.
- Validate inputs trong OnInit; từ chối giá trị âm/không hợp lệ.
- Đọc point, digits, tick size, volume min/max/step, stops/freeze level, trade mode từ symbol runtime.
- Detect account mode netting/hedging.
- Hard block tài khoản REAL; tester được phép mô phỏng. Demo guard phải được test.

## 3. Phase 2 — Direction Engine (ưu tiên cao nhất)

Triển khai `DIR_EMA_MTF` trước:

- H1 trend context, M15 confirmation, M5 pullback/reclaim trigger.
- Tất cả EMA/close/slope decisions dùng bars đã đóng; tạo helper đọc chính xác shift 1 và shift 2.
- H1/M15 bullish align mới xét BUY; bearish align mới xét SELL.
- MTF conflict, missing bars, invalid buffers hoặc no fresh M5 trigger => `NO_TRADE`.
- Tạo reason codes; in log và hiển thị panel.
- Giữ `DIR_LEGACY_EMA` để làm baseline so sánh, nhưng cũng chỉ dùng nến đóng.
- Tạo interface `DIR_PA_MTF`; chỉ triển khai sau khi có tests swing/BOS/CHoCH và không được giả vờ đây là PA mode nếu mới chỉ gọi EMA.

## 4. Phase 3 — Entry and re-entry control

- Chỉ xét entry khi phát hiện nến mới của EntryTF.
- Mỗi signal ID chỉ xử lý một lần.
- Chặn duplicate request và entry khi position khác đang tồn tại trên cùng symbol mà EA không quản lý an toàn.
- Thêm cooldown sau exit, max trades/day, min bars between entries.
- Không auto re-entry chỉ vì EA đang flat và EMA fast vẫn nằm trên/dưới EMA slow.

## 5. Phase 4 — RiskManager

- Thêm FIXED_LOT và RISK_PERCENT; mặc định nghiên cứu RISK_PERCENT.
- Tính loss dự kiến bằng `OrderCalcProfit()` cho 1 lot từ entry đến SL; quy đổi bằng deposit currency.
- Làm tròn volume xuống theo `SYMBOL_VOLUME_STEP`; kiểm tra min/max/max configured; tính lại risk sau rounding.
- Nếu minimum lot vượt risk budget hoặc OrderCalcProfit/OrderCalcMargin fail: bỏ lệnh và ghi reason.
- Thêm daily equity loss lock, peak-equity drawdown lock, consecutive losses, cooldown, max exposure và max trades/day.
- Persist risk state bằng Global Variables/file có namespace account+symbol+magic; version hóa state.
- Không reset drawdown lock khi restart hoặc đổi ngày. Reset cần thao tác rõ ràng và log.

## 6. Phase 5 — Initial SL and TrailingManager

- Hỗ trợ FIXED_POINTS, ATR và STRUCTURE initial SL modes.
- Có min/max stop distance và broker constraints.
- Break-even trigger theo initial R được lưu khi entry; không tính lại initial R từ SL đã dời.
- Trailing modes: fixed distance, ATR, swing/structure, hybrid.
- BUY: SL chỉ được tăng hoặc giữ nguyên. SELL: SL chỉ được giảm hoặc giữ nguyên.
- Làm tròn theo tick size; kiểm tra stops/freeze levels trước modify.
- Rate-limit retries; log retcode; không spam modify trên mọi tick.
- Nếu position không có SL hoặc initial state không phục hồi được, chuyển safe mode/cảnh báo, không tự suy đoán initial R.

## 7. Phase 6 — Execution and state recovery

- Chỉ `ExecutionManager` được gọi CTrade Buy/Sell/PositionModify/PositionClose.
- Kiểm tra terminal/account/symbol permissions, market tick, spread, trade mode, margin, volume và stop validity ngay trước request.
- Kiểm tra bool result và server retcode; handle requote, market closed, invalid stops, invalid volume, no money theo từng nhóm lỗi.
- Retry có giới hạn, backoff/cooldown; không retry lỗi vĩnh viễn khi chưa sửa nguyên nhân.
- `OnTradeTransaction` cập nhật closed-deal P/L, commissions, swap, fees, loss streak và event logs.
- OnInit reconcile persisted state với vị thế/orders/deals; state conflict => entries disabled.
- Test netting/hedging và nhiều EA trên cùng symbol.

## 8. Phase 7 — Filters and observability

- Spread absolute + relative to ATR.
- Abnormal ATR/volatility block.
- Optional trading-session filter dùng server time.
- Chart panel: direction, H1/M15 bias, M5 trigger, spread, ATR, risk state, position, initial R, current SL, reason code.
- CSV logs cho từng quyết định và mọi trade request/server retcode.

## 9. Phase 8 — Tests, Strategy Tester, demo

- Tạo unit/logic tests cho direction, entry timing, risk sizing, monotonic trailing, risk locks, restart recovery.
- Baseline test không optimization trước.
- Strategy Tester: ưu tiên Every tick based on real ticks nếu data khả dụng; cấu hình đúng symbol, date range, spread/commission/swap.
- Phân chia dữ liệu theo thời gian: development, validation, final out-of-sample. Không dùng final OOS lặp đi lặp lại để tune.
- Stress tests: spread/commission/slippage tăng, ATR cao, range kéo dài, gap, losing streak, broker reject SL, restart/disconnect.
- Chạy demo forward test sau khi baseline compile/test đạt. Không dùng kết quả demo ngắn hoặc vài lệnh để kết luận chiến lược hiệu quả.

## 10. Quy tắc đánh giá / optimization

Không optimize riêng net profit hoặc win rate. Báo cáo tối thiểu:
- Net profit sau chi phí, gross profit/loss.
- Max balance/equity drawdown.
- Profit factor, expected payoff, recovery factor.
- Trade count, win/loss distribution, losing streak.
- MAE/MFE, giveback từ peak floating profit.
- Theo tháng và market regime.
- Sensitivity quanh tham số được chọn.
- OOS + demo forward log.

Lưu mỗi experiment với config snapshot, source commit/hash, symbol, data range, tester model, cost assumptions và report. Không ghi đè run cũ.

## 11. Scripts and documentation phải tạo

Tạo scripts có kiểm tra lỗi và không giả vờ có compiler:

- `scripts/check-environment.ps1` — kiểm tra MT5/MetaEditor/Python paths và in rõ FOUND/MISSING.
- `scripts/build-mql5.ps1` — gọi MetaEditor compiler nếu tìm thấy; kiểm tra exit code và log; nếu không có compiler thì exit non-zero với thông báo rõ.
- `scripts/run-python-tests.ps1` — chạy test harness Python nếu có.
- `scripts/package-release.ps1` — đóng gói source/docs/config/report mẫu nhưng không chứa credential.
- `scripts/validate-inputs.py` — kiểm tra preset/config ngoài terminal.

Docs:
- `README.md` tiếng Việt.
- `Docs/INSTALL.md` cài MT5/MetaEditor, copy EA, compile, test.
- `Docs/INPUTS_REFERENCE.md` giải thích tất cả inputs và đơn vị.
- `Docs/DIRECTION_RULES.md` mô tả BUY/SELL/NO TRADE bằng ví dụ có timestamp.
- `Docs/RISK_CONTROLS.md` giải thích từng risk guard và reset.
- `Docs/STRATEGY_TESTER.md` cách chạy test và lưu preset/report.
- `Docs/DEMO_FORWARD_TEST.md` cấu hình và kiểm tra trên demo, không dùng tài khoản REAL.
- `Docs/TROUBLESHOOTING.md` lỗi compile, invalid stops, invalid volume, trade retcode, symbol suffix, missing history.

## 12. GitHub research (không mò mẫm từ đầu)

Trước khi tự viết module phổ biến, research GitHub và nguồn chính thức:

- Tìm EA MQL5 có cấu trúc module tốt, risk sizing, trailing và state recovery.
- Tìm ví dụ MQL5 chuẩn về `CTrade`, `OrderCalcProfit`, `OrderCalcMargin`, stops/freeze/tick-size.
- Tìm framework/test harness MQL5 nếu phù hợp.
- Với mỗi repository: ghi URL, commit hash/date checked, license, activity, file/class tham khảo, test evidence, security concerns, phần có thể tái sử dụng và phần không dùng.
- Không copy repo toàn bộ khi chưa xem license; không đưa GPL code vào project license khác nếu chưa đánh giá tương thích.
- Không tin kết quả lợi nhuận trong README/ảnh chụp; tự chạy lại test với cùng assumptions.
- Nếu GitHub connector chưa kết nối, dùng nguồn public có thể truy cập; ghi rõ phạm vi research. Không yêu cầu người dùng cung cấp token hoặc credential.

## 13. Deliverables mỗi phase

Sau mỗi phase, cập nhật `Docs/PROGRESS.md` và báo cáo:

1. Phase status: PASS / FAIL / BLOCKED.
2. File đã tạo/sửa.
3. Lý do kỹ thuật và các quyết định đã chọn.
4. Tests/commands đã chạy, output thực tế.
5. Lỗi còn lại và rủi ro chưa xử lý.
6. Tiêu chí nghiệm thu đã đạt/chưa đạt.
7. Hướng dẫn thao tác thủ công nếu MT5/MetaEditor không có trong môi trường agent.

Chỉ chuyển phase khi phase hiện tại có acceptance rõ ràng. Không tuyên bố V2 hoàn thành khi chưa compile bằng MetaEditor và chưa có Strategy Tester report thực tế.

## 14. Lệnh bắt đầu

Bắt đầu **Phase 0 — source/environment audit**. Chỉ kiểm kê, lập implementation plan và ghi nhận baseline; chưa viết code giao dịch. Dừng lại sau Phase 0 và trình bày báo cáo để người dùng duyệt trước khi tiếp tục.
