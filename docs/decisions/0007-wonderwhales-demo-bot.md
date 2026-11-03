# ADR 0007 — Wonderwhales trở thành bot demo thứ năm (EA demo riêng)

- **Ngày:** 2026-11-03
- **Trạng thái:** Accepted (chủ dự án yêu cầu 2026-11-03: *"dựa theo chỉ báo Wonderwhales, giúp mình sửa
  lại bot WonderwhalesSimEA để có thể chạy được trên cả test và demo"* — đây là sự chấp thuận mở rộng
  phạm vi theo ADR 0003 mục 7)
- **Mở rộng:** [ADR 0004](0004-all-bots-demo-execution.md) (ba EA demo) và
  [ADR 0005](0005-infiniterunner-xau-demo-bot.md) (EA demo thứ tư) — thêm chiến lược **thứ năm**.
  Toàn bộ rào cản đỏ của ADR 0004 — chỉ demo/tester, không credential, một điểm gửi lệnh qua
  `ExecBroker`, SL/TP bắt buộc, kill switch, audit CSV + `config_hash` — áp dụng nguyên vẹn.
  Mặc định `InpEnableExecution=true` theo [ADR 0006](0006-demo-default-execution-enabled.md).
  ADR 0002 và ADR 0003 (các mục không bị 0004 thay thế) vẫn nguyên hiệu lực.

## Bối cảnh

- `WonderwhalesSimEA` đã có đủ bằng chứng Strategy Tester (3 kịch bản `ww_baseline`,
  `ww_conservative_stress`, `ww_edge_atr_stop`, CSV ngày 2026-10-28) nhưng **chỉ tạo vị thế ảo**:
  file không include `Exec/*`, không có `InpEnableExecution`, không có kill switch riêng.
- ADR 0004 mục 1 quy định mỗi chiến lược có **một EA demo riêng biệt** và đã loại phương án "thêm cờ
  execution vào chính EA mô phỏng" (trộn hai chế độ làm bằng chứng khó tái lập và tăng rủi ro bật nhầm).
- Vì vậy yêu cầu "chạy được trên cả test và demo" được hiện thực bằng **hai file**: giữ
  `WonderwhalesSimEA` cho Tester mô phỏng, thêm `WonderwhalesDemoEA` cho Tester/demo có gửi lệnh thật
  qua guard. Không sửa `WonderwhalesSimEA`, không thêm cờ execution vào nó.

## Quyết định

1. **Bot demo thứ năm, EA demo riêng.**

   | Chiến lược | EA demo (mới) | EA mô phỏng (không đổi) | Magic demo |
   |---|---|---|---|
   | Wonderwhales | `mt5/Experts/WonderwhalesDemoEA.mq5` | `mt5/Experts/WonderwhalesSimEA.mq5` | `25007001` |

   - Tín hiệu lấy từ cùng indicator `PinePort\Wonderwhales` (hợp đồng buffer
     `WonderwhalesContract.mqh`, `WW_CONTRACT_VERSION`), không tự tính lại chỉ báo trong EA.
   - Một vị thế duy nhất theo magic; không grid, không DCA, không martingale.

2. **Logic giao dịch của EA demo:**
   - Quyết định vào lệnh chỉ trên **nến đã đóng** (`CopyBuffer(..., shift 1, ...)`), đúng như
     `WonderwhalesSimEA`.
   - Stop ban đầu theo một trong ba chế độ của bản mô phỏng: PSAR của nến tín hiệu, ATR% × multiplier,
     hoặc khoảng cách points cố định; có sàn `InpMinStopPoints` và kiểm tra stop level của broker.
   - **TP bắt buộc** `InpTakeProfitR` (R = khoảng cách entry→SL), kiểm tra `ExecTakeProfitValid`
     và `ExecStopsRespectBroker` trước khi gửi; mọi lệnh mang cả SL và TP.
   - Thoát theo tín hiệu đảo (`InpExitOnFlip`), SL/TP của broker, hoặc `InpMaxHoldingBars` nếu khác 0.
   - Volume tính từ `InpRiskPercent` trên equity, qua `ExecCalcProfit` từ entry tới SL, làm tròn xuống
     volume step, chặn trên bởi `InpMaxLots` và `SYMBOL_VOLUME_MAX`, từ chối nếu lot tối thiểu vượt
     ngân sách rủi ro; kiểm tra margin trước khi gửi.

3. **Guardrail bắt buộc (giống bốn EA demo trước):**
   - `ExecContextAllowed` chỉ chấp nhận `ACCOUNT_TRADE_MODE_DEMO` hoặc Strategy Tester; mọi trường hợp
     khác → `OnInit` trả `INIT_FAILED`, không chuyển sang mô phỏng ngầm.
   - `InpEnableExecution=true` mặc định (ADR 0006); `false` là dry-run có chủ đích để đối chiếu.
   - Allow-list ký tự `InpAllowedSymbols` (prefix) và magic riêng để không đụng lệnh của bot khác.
   - Kill switch riêng `InpKillSwitchFile` (`WONDERWHALES_DEMO_STOP.txt` trong `MQL5/Files`): file tồn
     tại → đóng vị thế (nếu bật `InpCloseOnKillSwitch`) và ngừng vào lệnh tới khi khởi động lại sau khi
     xoá file.
   - Halt theo equity thật: `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`,
     cooldown; halt thì đóng vị thế và dừng vào lệnh. Halt do **daily loss** là khoá theo ngày: sang
     ngày giao dịch mới EA tự mở khoá, ghi dòng `RESUME`, và tiếp tục vào lệnh; halt do **drawdown tối
     đa** hay kill switch vẫn dính cho tới khi operator khởi động lại (state file giữ cờ halt).
   - State file ghi peak equity / ngày / chuỗi thua / cờ halt để restart không "quên" ngân sách rủi ro;
     vị thế thật luôn được đối chiếu lại với broker khi khởi động.
   - Mọi quyết định và fill ghi CSV 18 cột (`SimLogger`) + `Print` với `config_hash` ổn định.

4. **Không credential, không đăng nhập.** Không đọc/ghi login, password, investor password, OTP, server
   hay token; không `WebRequest`, không socket, không dùng endpoint MCP cục bộ của broker. Operator tự
   đăng nhập terminal.

5. **EA mô phỏng và bằng chứng cũ không đổi.** `WonderwhalesSimEA` vẫn `SIMULATION_ONLY`; ba kịch bản
   Tester cũ vẫn hợp lệ và không bị trộn với journal demo (`wonderwhales_demo.csv`).

6. **Không quảng bá hiệu năng.** Kết quả demo/backtest không phải cam kết lợi nhuận. Trạng thái bằng
   chứng của bot này là `NOT_RUN` cho tới khi có journal/History thật của một phiên demo; lợi nhuận của
   chiến lược vẫn là `UNPROVEN`.

7. **Live/real vẫn cần scope mới.** Bất kỳ thay đổi nào cho phép tài khoản real phải có ADR khác, được
   chủ dự án chấp thuận trước khi viết code.

## Hệ quả

- `scripts/validate-project.py` và `scripts/validate_demo_execution.py` mở allow-list cho
  `mt5/Experts/WonderwhalesDemoEA.mq5` và preset `configs/demo/wonderwhales_demo.json`; mọi source khác
  vẫn bị chặn API lệnh.
- `python/src/mt5_ea_ai_lab/sim_configs.py` thêm `WonderwhalesDemoEA` vào `DEMO_EA_NAMES` với bộ input
  đầy đủ; preset phải `DEMO_ONLY`, `allow_live_trading=false`, `InpEnableExecution=true`.
- `scripts/deploy_pineport.ps1` deploy thêm EA mới; `reports/build/tester-run/` có thêm kịch bản
  `ww_demo_exec` để chứng minh đường gửi lệnh trong Strategy Tester.
- `docs/guides/demo-execution.md` và `docs/indicators/wonderwhales.md` mô tả bot thứ năm, cách chạy và
  cách đọc journal.
- Muốn chạy chiến lược này trên chart demo: gắn `WonderwhalesDemoEA` (không phải `WonderwhalesSimEA`)
  lên `XAUUSDm`; muốn backtest mô phỏng: dùng `WonderwhalesSimEA` như cũ.

## Phương án đã cân nhắc

- **Thêm `InpEnableExecution` vào `WonderwhalesSimEA`:** loại. Trái ADR 0004 mục 1 và phương án đã bị
  loại trong ADR 0004 (trộn mô phỏng với execution trong một file).
- **Đổi `WonderwhalesSimEA` thành EA demo duy nhất:** loại. Sẽ làm mất bằng chứng mô phỏng cũ và phá
  quy ước một EA một chế độ.
- **Cho EA demo tự gọi `OrderSend`:** loại. `ExecBroker` là điểm gửi lệnh duy nhất để static gate còn
  hiệu lực.
- **Cho phép tài khoản real:** loại tuyệt đối (ADR 0002/0003/0004).
