# ADR 0009 — Wonderwhales XAU 2-mode trở thành bot demo thứ sáu

- **Ngày:** 2026-11-04
- **Trạng thái:** Accepted (chủ dự án chốt S1–S4 ngày 2026-11-04 và yêu cầu *"tự động làm đến khi xong"*;
  đây là sự chấp thuận mở rộng phạm vi theo ADR 0003 mục 7)
- **Mở rộng:** [ADR 0004](0004-all-bots-demo-execution.md) (mọi bot có EA demo) và
  [ADR 0007](0007-wonderwhales-demo-bot.md) (bot Wonderwhales thứ năm) — thêm chiến lược **thứ sáu**.
  Toàn bộ rào cản đỏ của ADR 0004 — chỉ demo/tester, không credential, một điểm gửi lệnh qua
  `ExecBroker`, SL/TP bắt buộc, kill switch, audit CSV + `config_hash` — áp dụng nguyên vẹn.
  Mặc định `InpEnableExecution=true` theo [ADR 0006](0006-demo-default-execution-enabled.md).
  ADR 0002 và ADR 0003 (các mục không bị 0004 thay thế) vẫn nguyên hiệu lực.

## Bối cảnh

- Đặc tả [`../10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md`](../10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md)
  (v2.2) yêu cầu một EA Wonderwhales XAU **hai chế độ**: Scalp (M15/M5/M1) và Swing (W1/D1/H1), bảo toàn
  vốn trước, SL/TP bắt buộc, break-even/trailing có quy tắc, risk guard ngày/tuần/drawdown.
- Bản v1 (`WonderwhalesDemoEA`, ADR 0007) chỉ có một chế độ tín hiệu, **chưa** có BE/trailing và chưa có
  chế độ Scalp/Swing. Nâng cấp v1 tại chỗ sẽ trộn hai hành vi vào một file và phá bằng chứng cũ.
- ADR 0004 mục 1 quy định **mỗi chiến lược có một EA demo riêng**; đặc tả §8 đề xuất module hoá.
- Chủ dự án chốt **S1–S4**: một magic; parity chặn entry; mặc định Scalp + execution bật + demo-only;
  journal 18 cột giữ nguyên, dữ liệu mở rộng ghi file telemetry riêng.

## Quyết định

1. **Bot demo thứ sáu, EA demo riêng.**

   | Chiến lược | EA demo (mới) | EA giữ nguyên | Magic demo |
   |---|---|---|---|
   | Wonderwhales XAU 2-mode | `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | `WonderwhalesDemoEA` (v1, 25007001), `WonderwhalesSimEA` | `25008001` |

   - Tín hiệu lấy từ cùng indicator `PinePort\Wonderwhales` (hợp đồng `WonderwhalesContract.mqh`),
     **không** tự tính lại PSAR/EMA/ATR trong EA.
   - Một vị thế duy nhất theo magic; không grid, không DCA, không martingale.

2. **Hai chế độ trong một bot, một magic (S1).** `InpTradingMode` = `WW2_SIGNAL_ONLY` | `WW2_SCALP` |
   `WW2_SWING` (mặc định `WW2_SCALP`). Scalp và Swing là hai chiến lược *bên trong cùng một bot*; **mode
   của từng vị thế được lưu trong state lúc vào lệnh** (`pos_mode`) và khi khôi phục EA quản lý theo mode
   đã lưu, **không** theo `InpTradingMode` hiện tại. Không có magic thứ hai.

3. **Cổng parity bắt buộc (S2).** Khi parity Pine ↔ MT5 chưa được chứng minh, `InpRequireParity=true`
   **chặn mọi entry** (`reason=parity_blocked`). Kết quả giao dịch thu được khi bỏ parity **không** phải
   kết quả chiến lược hợp lệ.

4. **Logic giao dịch:**
   - Quyết định vào lệnh chỉ trên **nến đã đóng** (`shift=1`).
   - Scalp: M15 EMA20/50 + giá so EMA200 làm bias; M5 PSAR flip cùng bias; M1 xác nhận.
   - Swing: W1 bias; D1 đồng thuận (ưu tiên EMA200); H1 PSAR flip.
   - SL ban đầu = swing đã xác nhận (M5 cho Scalp, H1 cho Swing) + buffer ATR; fallback `×ATR`; sàn
     `InpMinStopPoints`, trần `InpMaxStopPoints`, tôn trọng stop level của broker.
   - **TP bắt buộc** `InpTakeProfitR`; chế độ SWING đòi `InpTakeProfitR ≥ InpSwingRrMin`.
   - Break-even (có buffer chi phí) + trailing cấu trúc/PSAR/ATR/step qua `WW2TrailingCoordinator`: tính
     mọi ứng viên SL, **chỉ siết** (BUY tăng, SELL giảm) ít nhất `InpMinTrailStepPoints`; R luôn từ SL ban
     đầu đã lưu.
   - Volume tính từ `InpRiskPercent` trên equity qua `ExecCalcProfit`, làm tròn **xuống** theo volume step,
     chặn trên bởi `InpMaxExposure` và `SYMBOL_VOLUME_MAX`; min-lot vượt ngân sách → **bỏ qua**, không làm
     tròn lên.

5. **Guardrail bắt buộc (giống các EA demo trước, cộng thêm):**
   - `ExecContextAllowed` chỉ chấp nhận `ACCOUNT_TRADE_MODE_DEMO` hoặc Strategy Tester; khác → `INIT_FAILED`.
   - `InpDemoOnly` **bắt buộc `true`** — đặt `false` làm `OnInit` trả `INIT_PARAMETERS_INCORRECT`.
   - `InpEnableExecution=true` mặc định (ADR 0006); `false` là dry-run có chủ đích.
   - Allow-list `InpAllowedSymbols`; kill switch riêng `InpKillSwitchFile`
     (`WONDERWHALES_XAU_2MODE_DEMO_STOP.txt`).
   - Halt theo equity thật: `InpMaxDailyLossPct`, `InpMaxWeeklyLossPct`, `InpMaxDrawdownPct`,
     `InpMaxConsecutiveLosses`, cooldown. Halt do **daily/weekly loss** tự mở khoá sang ngày/tuần server
     mới; halt do **max drawdown** hay kill switch dính tới khi operator khởi động lại (state giữ cờ).
   - State file ghi peak/day/week equity, chuỗi thua, cờ halt, và context vị thế **kèm `pos_mode`**; vị thế
     thật luôn được đối chiếu lại với broker khi khởi động.

6. **Nhật ký (S4).** Journal chính giữ **hợp đồng 18 cột** (`SimLogger`, `SIM_LOG_HEADER`) — không mở rộng
   schema. Trường mở rộng (R, SL, lý do trailing, EMA/PSAR/ATR từng khung) ghi **file telemetry riêng**
   (`InpTelemetryFile`), nối với journal bằng ticket.

7. **Per-mode values đến từ preset.** Engine dùng một bộ input dùng chung (`InpRiskPercent`,
   `InpTakeProfitR`, `InpBreakEvenTriggerR`, `InpTrailTriggerR`, `InpMinTrailStepPoints`,
   `InpCooldownMinutes`); giá trị riêng của Scalp/Swing do preset đặt — một chế độ chạy tại một thời điểm
   (spec §1.2).

8. **Không credential, không đăng nhập, không quảng bá hiệu năng.** Trạng thái bằng chứng `NOT_RUN` cho
   tới khi có journal/History thật; lợi nhuận `UNPROVEN`. Live/real vẫn cần ADR mới.

## Hệ quả

- `scripts/validate-project.py` và `scripts/validate_demo_execution.py` mở allow-list cho
  `mt5/Experts/WonderwhalesXAU2ModeEA.mq5`, các module `mt5/Include/Wonderwhales/*.mqh` và preset
  `configs/demo/wonderwhales_xau_2mode_demo.json`; mọi source khác vẫn bị chặn API lệnh.
- `python/src/mt5_ea_ai_lab/sim_configs.py` thêm `WonderwhalesXAU2ModeEA` vào `DEMO_EA_NAMES` với bộ input
  đầy đủ; preset phải `DEMO_ONLY`, `allow_live_trading=false`, `InpEnableExecution=true`,
  `InpRequireParity=true`.
- `scripts/deploy_pineport.ps1` deploy thêm EA, tree include mới và script test `WW2CoreTests.mq5`.
- `docs/10-bots/README.md` (16 EA) + trang `docs/10-bots/wonderwhales-2mode.md` mô tả bot; ADR index cập nhật.

## Phương án đã cân nhắc

- **Nâng cấp `WonderwhalesDemoEA` tại chỗ:** loại. Trộn hai chế độ vào một file và phá bằng chứng v1; trái
  quy ước một chiến lược một EA.
- **Hai magic (Scalp/Swing riêng):** loại theo S1. Quy ước dự án là một magic một bot; phân biệt bằng mode
  lưu trong state.
- **Chạy Scalp + Swing đồng thời:** loại ở giai đoạn này (spec §1.2); chỉ nghiên cứu sau khi hai chế độ đã
  được kiểm định riêng.
- **Cho parity là track song song:** loại theo S2. Tín hiệu chưa đối chiếu thì chưa giao dịch.
- **Mở rộng schema journal lên >18 cột:** loại theo S4. Watcher/validator đang parse schema 18 cột.
- **Cho phép tài khoản real:** loại tuyệt đối (ADR 0002/0003/0004).
