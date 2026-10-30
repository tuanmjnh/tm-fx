# ADR 0005 — InfiniteRunner_XAU trở thành bot demo thứ tư (canonical EA riêng biệt)

- **Ngày:** 2026-10-30
- **Trạng thái:** Accepted (chủ dự án chấp thuận 2026-10-30 — "mở khóa toàn bộ project
  cho toàn bộ bot EA": đăng ký bot demo thứ tư, mở backtest + tài khoản demo); mục 3
  (preset fail-closed `false`) được sửa đổi bởi
  [ADR 0006](0006-demo-default-execution-enabled.md) — mặc định `true`
- **Mở rộng:** [ADR 0004](0004-all-bots-demo-execution.md) (ba EA demo) — ADR này thêm chiến
  lược **thứ tư**. Toàn bộ rào cản đỏ của ADR 0004 (chỉ demo/tester, không credential,
  một điểm gửi lệnh qua `ExecBroker`, SL/TP bắt buộc, dry-run mặc định, kill switch,
  audit CSV + `config_hash`) áp dụng nguyên vẹn cho bot mới. ADR 0002, ADR 0003 (mục
  không bị 0004 thay thế) vẫn nguyên hiệu lực.
- **Chi lệch tiến trình cần ghi nhận trung thực:** theo ADR 0003 mục 7, code chiến lược
  phải được viết **sau** khi ADR được chấp thuận. Trong phiên 2026-10-30, **hai agent song
  song** đã cùng triển khai Upgrade Pack `docs/v2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/`
  trước khi ADR có mặt, và hai luồng đã ghi đè lẫn nhau trên 2 file include dùng chung
  (`IRTypes.mqh`, `IRDirection.mqh`). Luồng "alt A" không thể khôi phục (repo chưa có commit
  nào) nên đã được **lưu trữ nguyên trạng** tại
  `archive/2026-10-30_InfiniteRunner_XAU_alt_A/` (kèm README giải thích). Chủ dự án đã
  quyết định lấy luồng còn lại làm canonical. Sai sót tiến trình này không lặp lại: mọi
  thay đổi phạm vi sau ADR 0005 vẫn phải đi theo quy tắc "ADR trước, code sau".

## Bối cảnh

- Nguồn V1: `github-demo/InfiniteRunner_XAU/InfiniteRunner_XAU.mq5` (giữ nguyên trạng,
  không bao giờ sửa) — một lệnh chạy liên tục, TP=0, kéo SL, quyết định trên **nến đang
  chạy** (`fastMA[0]`), vào lại lệnh tức thời sau khi thoát, lot cố định, không kiểm tra
  retcode, không kho rủi ro.
- Đặc tả nâng cấp: `INFINITERUNNER_XAU_REVIEW_AND_UPGRADE_SPEC.md` (sửa lỗi closed-bar,
  bộ xác định hướng MTF, lot theo rủi ro, BE/trailing tính từ R ban đầu không bị tính lại,
  kho ngày/drawdown/thua dây, state file, guard tài khoản thật).
- Chủ dự án (2026-10-30) đã chọn: canonical = **InfiniteRunnerXAUV2DemoEA** (luồng alt B),
  alt A lưu trữ, và yêu cầu soạn ADR 0005 trước khi tiếp tục sửa code.

## Quyết định (đã chấp thuận 2026-10-30)

1. **Bot demo thứ tư, EA demo riêng.**

   | Chiến lược | EA demo (mới) | EA mô phỏng | Magic demo |
   |---|---|---|---|
   | InfiniteRunner_XAU | `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` | chưa có (không bắt buộc) | `25006001` |

   - V1 không đổi, V1 không được compile lại thành EA giao dịch.
   - Chỉ **một** vị thế cùng lúc theo magic; không grid/DCA của bot này.

2. **Logic phiên bản V2 (nhờ spec của Upgrade Pack):**
   - Chỉ dùng dữ liệu **nến đã đóng**: EMA/ATR đọc qua `CopyBuffer(..., shift 1, ...)`,
     quyết định chiến lược chỉ vào **nến EntryTF mới**; tick chỉ phục vụ trailing/SL trong thời gian thực.
   - Hai chế độ xác định hướng: `IR_DIR_LEGACY_EMA` (parity V1 trên nến đóng, làm baseline
     A/B) và `IR_DIR_EMA_MTF` (H1 context + M15 xác nhận + M5 pullback-reclaim), mặc định
     `IR_DIR_EMA_MTF`; `NO_TRADE`/`REVERSAL_WATCH`/`*_BLOCKED` là quyết định hợp lệ, không
     ép vào lệnh.
   - Gate spread (points và tuỳ chọn tỉ lệ ATR), gate ATR bất thường, cooldown, giới hạn
     số lệnh/ngày, khoảng cách tối thiểu giữa các entry, cấm vào lại trong cùng nến.
   - Sizing: `IR_LOT_FIXED` hoặc `IR_LOT_RISK` theo % equity tại stop ban đầu, tính qua
     `ExecCalcProfit` (OrderCalcProfit), floor về volume step, kiểm tra lại rủi ro cuối,
     trần `InpMaxLots` + `SYMBOL_VOLUME_MAX`.
   - SL ban đầu: points cố định hoặc ATR×multiplier, tick-normalized, nằm trong band
     `[InpMinStopPoints, InpMaxStopPoints]`, tôn trọng `SYMBOL_TRADE_STOPS_LEVEL`. TP an toàn
     bắt buộc (`InpSafetyTpPoints`, mặc định 100000 points ≈ rất xa) — bot vẫn thoát bằng
     trailing SL (khác V1 TP=0), đáp ứng yêu cầu SL+TP bắt buộc của ADR 0004.
   - Break-even và trailing chỉ dựa trên **initial R lưu trong state**, không tính lại từ
     trailing; BUY SL chỉ tăng, SELL SL chỉ giảm, bước tối thiểu `InpTrailStepPts`; candidate
     vi phạm band/stop level bị từ chối chứ không bị kẹp lại.
   - Vị thế không có SL → chế độ an toàn: entry bị chặn, applied emergency SL rate-limit
     mỗi nến, ghi lý do.
   - Kho rủi ro: `DailyLossPct`, `DrawdownPct` (persisted, chỉ mở bằng `InpManualResetDrawdown`
     có ghi log), `MaxConsecutiveLosses`, max trades/day, cooldown, các ruột qua `CSimRiskGuard`.
   - State file `infinite_runner_demo_state.csv` (version + magic + R ban đầu + ledger),
     khôi phục/tái lập vị thế sau restart; conflict → safe mode, không entry.
   - Kill switch file riêng `INFINITE_RUNNER_DEMO_STOP.txt` (`MQL5/Files/`).
   - Audit: CSV `infinite_runner_demo.csv` + journal prefix `LAB|...|ir_v2|...`,
     `config_hash` ổn định từ tất cả input.

3. **Đường đỏ như ADR 0004 mục 3, không thêm không bớt.** EA không tự gọi
   `OrderSend`/`OrderCalcMargin`/`OrderCalcProfit`; mọi thứ đi qua `mt5/Include/Exec/*`.
   Không credential, không `WebRequest`/socket, không tài khoản real/contest
   (`ExecContextAllowed` → `INIT_FAILED`).

4. **Lưu trữ alt A đúng như đã quyết.** `archive/2026-10-30_InfiniteRunner_XAU_alt_A/`
      giữ `InfiniteRunnerXAUDemoEA.mq5`, `IRMarket.mqh`, `IRRisk.mqh`,
   `InfiniteRunnerContractTests.mq5`, `infinite_runner.py`, `test_infinite_runner.py`
   (không chạy trong CI/pytest nữa). Thành phần sáng giá của alt A (swing triggers,
   session windows, `IRSignalId`) có thể được nghiên cứu trong ADR sau nếu một ngày
   muốn thêm — không hợp nhất trong ADR này.

## Hệ quả cần làm sau khi Accepted (theo thứ tự)

1. Đăng ký trong `scripts/validate-project.py`: thêm `InfiniteRunnerXAUV2DemoEA.mq5` vào
   `EXEC_SOURCES` (miễn trừ API tài khoản cho EA demo), thêm mục `DEMO_EAS` với guard token
   `recursive_runner` → dùng token mô tả đúng: **`runner_trailing`** (một vị thế +
   trailing đơn điệu), kiểm tra preset demo của bot này như ba bot cũ.
2. `scripts/validate_demo_execution.py`: thêm EA + magic 25006001 vào bảng guard,
   kiểm tra khác biệt magic với ba bot cũ và probe `ExecDemoProbe`.
3. Preset fail-closed `configs/demo/infinite_runner_demo.json` (XAUUSDm M5/M15/H1,
   `InpEnableExecution=false`, `InpAllowedSymbols="XAUUSD"`, band SL 500–20000,
   `InpSafetyTpPoints=100000`).
4. `python/src/mt5_ea_ai_lab/sim_configs.py`: `EA_INPUTS` cho EA mới + `DEMO_EA_NAMES` +
   cross-checks.
5. `scripts/deploy_pineport.ps1`: thêm EA + 3 include `InfiniteRunner/*.mqh` vào pipeline
   copy+compile; biên dịch cho tới 0 error 0 warning; copy sang terminal data folder.
6. `python/tests/test_demo_execution.py`: kiểm preset fail-closed thứ ba (bản mẫu thứ tư) cho bot mới.
7. Tài liệu: `docs/guides/demo-execution.md` nâng lên bảng 4 bot; PROGRESS ghi §65+;
   nhãn `NOT_RUN` cho mọi kết quả chưa chạy thật; mọi hứa hẹn lợi nhuận vẫn là `UNPROVEN`.

## Ghi nhận thực hiện (2026-10-30)

Tất cả các bước trên đã hoàn tất trong phiên này: đăng ký validator (0 fail cả hai),
preset `configs/demo/infinite_runner_demo.json` fail-closed đầy đủ (kèm `InpMaxLots`),
EA_INPUTS + cross-checks trong `sim_configs.py`, pytest xanh, pipeline deploy cập nhật
trong `scripts/deploy_pineport.ps1`, scenario tester `infinite_runner_demo_exec.set/.ini`
(execution bật — chỉ dùng trong Strategy Tester / demo).

## Lưu ý hằng số

- Bot thứ tư đã Accepted: mọi thay đổi phạm vi tiếp theo trên InfiniteRunner vẫn phải
  đi theo quy tắc "ADR trước, code sau" (không lặp lại sai sót hai luồng song song
  đã ghi ở trên).
- Tài khoản **real/live vẫn bị cấm** theo ADR 0002/0004; việc cho phép real (nếu có)
  sẽ là một ADR riêng với kiến trúc hai chìa khóa, chỉ soạn sau khi có bằng chứng demo
  2–4 tuần.
- Không đời nào ghi trong tài liệu rằng EA đã chạy demo thật trước khi có bằng chứng
  (journal/CSV/deal history) — mọi bằng chứng sẽ được liệt kê đường dẫn kèm thời gian.
  Hiện trạng thái evidence của cả 4 bot vẫn là `NOT_RUN`; kết quả chiến lược `UNPROVEN`.
