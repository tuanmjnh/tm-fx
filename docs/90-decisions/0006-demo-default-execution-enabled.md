# ADR 0006 — Bot demo mặc định bật execution (sửa đổi ADR 0004/0005)

- **Ngày:** 2026-10-30
- **Trạng thái:** Accepted (chủ dự án yêu cầu 2026-10-30: "giúp mình thay đổi toàn bộ
  thiết kế mặc định luôn InpEnableExecution=true" — bot phải chạy demo ngay để đo
  tính hiệu quả; quyết định thứ hai trong cùng ngày sau "mở khóa toàn bộ project")
- **Sửa đổi:** [ADR 0004](0004-all-bots-demo-execution.md) mục "dry-run mặc định" và
  [ADR 0005](0005-infiniterunner-xau-demo-bot.md) mục 3 — mọi điều còn lại giữ nguyên.
- Ghi chú đánh số: kế hoạch "ADR 0006 Real execution" trong lộ trình 4 bước nhường số
  này cho sửa đổi hiện tại; ADR Real execution sau này sẽ là **0007** (kiến trúc hai
  chìa khóa — Proposed, chưa soạn).

## Bối cảnh

- ADR 0004 thiết kế fail-closed: `InpEnableExecution=false` là mặc định ở **code** và
  **preset**; muốn vào lệnh phải bật cờ tay. Lý do ban đầu: lần gắn đầu tiên không gửi
  lệnh, dry-run là an toàn mặc định.
- Sau khi bot thứ tư đăng ký, chủ dự án phải lặp lại thao tác bật cờ cho từng bot, từng
  phiên — cả trên tester lẫn demo — chỉ để đo hiệu quả chiến lược. Chi phí thủ tục này
  lớn hơn lợi ích cảnh báo vì mọi phiên đều có người giám sát.
- Ranh giới **real/live** không bị chạm tới: ADR 0002/0004 vẫn cấm tài khoản thật;
  `ExecContextAllowed` vẫn `INIT_FAILED` trên tài khoản real/contest.

## Quyết định

1. **Mặc định bật execution trên demo**: cả bốn EA demo khai báo
   `input bool InpEnableExecution=true` làm mặc định; các preset
   `configs/demo/{pa_trendrider_xau_demo,grid_demo,dca_demo,infinite_runner_demo}.json`
   ship `InpEnableExecution: true`; các file `.set` tester đã bật sẵn từ trước.
2. **Dry-run vẫn tồn tại như một chế độ có chủ đích**: đặt `InpEnableExecution=false`
   trên hộp input (hoặc một `.set` riêng) để chạy phiên đối chiếu không gửi lệnh.
   Dry-run không còn là mặc định — mặc định mới là "demo chạy thật".
3. **Mọi guard khác giữ nguyên**: chỉ demo/tester (`ACCOUNT_TRADE_MODE_DEMO` hoặc
   Strategy Tester, còn lại `INIT_FAILED`), SL/TP bắt buộc mọi lệnh, kill switch,
   kho ngày/drawdown/chuỗi thua, một điểm gửi lệnh `ExecBroker`, trần tầng/add/exposure,
   audit CSV + `config_hash`.
4. **Chấm dứt escalation Block → halt vĩnh viễn**: các EA demo truyền
   `limits.halt_on_breach=false` vào `SimRiskGuard` — guard chỉ tổng `Halt()` cho vi
   phạm equity thật (daily loss / drawdown / kill switch) và EA tự thăng cấp theo
   `InpHaltOnBreach`; một Block thông thường (spread, cooldown, trần tầng) chỉ Block.
   Bug thật đã gặp trong phiên này: `InfiniteRunnerXAUV2DemoEA` chết ngay tại setup
   đầu tiên (`halted|reason=volume_to_add_invalid`) vì gọi guard bằng volume 0 trước
   khi sizing — sửa bằng cách sizer trước rồi gọi guard với volume thật.
5. **Validator + pytest cập nhật theo**: các check trước đây ép `false` giờ ép mặc
   định `true` rõ ràng ở code và preset; kỷ luật bằng chứng `NOT_RUN`/`UNPROVEN` giữ
   nguyên.

## Hệ quả

- Gắn EA lên chart demo hoặc chạy tester → bot vào lệnh ngay khi có setup hợp lệ; chủ
  dự án đo được hiệu quả mà không cần bật cờ.
- Rủi ro được chủ dự án chấp nhận: **không còn điểm dừng mặc định trước lệnh đầu
  tiên** trên demo. Giám sát phiên (journal/CSV, kill switch) là trách nhiệm vận hành.
- Dry-run đối chiếu vẫn làm được như mục 2; hướng dẫn cập nhật theo mặc định mới.
- ADR 0002, 0003 (phần không bị thay), 0004 (trừ mặc định dry-run), 0005 (trừ mục 3)
  vẫn hiệu lực. Mọi thay đổi theo sau vẫn phải "ADR trước, code sau".
