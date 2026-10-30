# ADR 0004 — Mọi bot được execution đầy đủ trên tài khoản demo

- **Ngày:** 2026-10-30
- **Trạng thái:** Accepted (chủ dự án chấp thuận 2026-10-30); **được sửa đổi bởi
  [ADR 0006](0006-demo-default-execution-enabled.md)** — mặc định `InpEnableExecution=true`
  (không còn dry-run mặc định)
- **Thay thế một phần:** [ADR 0003](0003-demo-execution-scope.md) mục 1 (danh sách nguồn được phép) và
  mục 3 (câu "Không martingale, không grid, không DCA trong phạm vi demo execution đầu tiên").
  ADR 0003 mục 2, 4, 5, 6 vẫn nguyên hiệu lực. ADR 0002 (không tài khoản live, không credential, không
  hứa hẹn lợi nhuận) vẫn nguyên hiệu lực.
- **Bối cảnh:** ADR 0003 mở execution demo nhưng giới hạn ở **một** EA (`PATrendRiderXAUv1DemoEA`) và
  cấm grid/DCA. Chủ dự án yêu cầu: *"cập nhật lại tính ràng buộc cho toàn dự án, tất cả các bot đều có
  thể chạy toàn quyền trên tài khoản demo"*. ADR 0003 mục 7 đã quy định mọi thay đổi phạm vi phải có ADR
  mới được chủ dự án chấp thuận **trước khi viết code**; yêu cầu này chính là sự chấp thuận đó.

## Quyết định

1. **Ba chiến lược, ba EA demo riêng.** Cả ba bot (`PATrendRiderXAUv1`, `Grid`, `DCA`) được phép gửi
   lệnh thật trên tài khoản **demo**. Mỗi bot có một EA demo **riêng biệt**, không trộn cờ execution vào
   EA mô phỏng:

   | Chiến lược | EA demo | EA mô phỏng (không đổi) |
   |---|---|---|
   | PATrendRiderXAUv1 | `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` | `PATrendRiderXAUv1SimEA.mq5` |
   | Grid | `mt5/Experts/GridDemoEA.mq5` | `GridLabEA.mq5` |
   | DCA | `mt5/Experts/DCADemoEA.mq5` | `DCALabEA.mq5` |

2. **"Toàn quyền trên demo" nghĩa là gì.** Trên tài khoản demo hoặc trong Strategy Tester, operator được
   tự do bật execution cho cả ba bot, chạy nhiều bot cùng lúc (mỗi bot một `magic` riêng), không giới hạn
   số phiên. Không còn điều kiện "một EA duy nhất" hay "không grid/DCA" nào trong tài liệu hay validator.

3. **Đường đỏ không thay đổi (hard-enforced trong code, không chỉ là tài liệu):**
   - **Chỉ demo/tester.** `ExecGuard.ExecContextAllowed` chấp nhận `ACCOUNT_TRADE_MODE_DEMO` hoặc
     `MQL_TESTER`; mọi trường hợp khác → `OnInit` trả `INIT_FAILED`, không chuyển sang mô phỏng ngầm.
     Tài khoản real/contest vẫn bị cấm tuyệt đối (ADR 0002, ADR 0003 mục 2).
   - **Không credential, không đăng nhập.** Không đọc/ghi login, password, investor password, OTP, server,
     token; không `WebRequest`, không socket. Operator tự đăng nhập terminal.
   - **Một điểm gửi lệnh.** Mọi API gửi lệnh chỉ nằm trong `mt5/Include/Exec/ExecBroker.mqh`. EA demo gọi
     `ExecBroker`, không tự gọi `OrderSend`/`OrderCalcMargin`.
   - **SL và TP bắt buộc** trên mọi lệnh vào (`ExecTakeProfitValid` + `ExecStopsRespectBroker`).
   - **Dry-run là mặc định, fail-closed.** `InpEnableExecution=false` ở cả code lẫn preset
     `configs/demo/*.json`; static validator bắt buộc điều đó. "Toàn quyền trên demo" nghĩa là **không
     còn rào cản nào khác**: chỉ cần đặt `InpEnableExecution=true` (một input, hoặc một file `.set`) là
     bot vào lệnh thật trên demo. Không có cờ "live".
   - **Trần rủi ro cứng**, mỗi bot tự giữ sổ (ledger) riêng theo `magic`:
     số tầng/add tối đa, volume mỗi lần, tổng exposure, `RiskPercent` mỗi entry,
     `DailyLossLimitPct`, `MaxDrawdownPct`, `MaxConsecutiveLosses`, cooldown, khoảng cách stop tối thiểu,
     stop level của broker, kiểm tra margin trước khi gửi.
   - **Kill switch:** file trong `MQL5/Files/` (`LAB_DEMO_STOP.txt` dùng chung, cộng file riêng mỗi bot).
     File tồn tại → EA đóng vị thế của mình và ngừng vào lệnh cho tới khi khởi động lại sau khi xoá file.
   - **Audit:** mọi quyết định và mọi fill ghi CSV + journal kèm `config_hash` ổn định.

4. **Không grid/DCA vô hạn.** Grid bị chặn bởi `InpMaxGridLevels` + trần volume mỗi tầng + tổng exposure.
   DCA bị chặn bởi `InpMaxDcaAdds` + trần volume mỗi add + tổng exposure. **Không martingale vô hạn**:
   volume tầng/add luôn bị chặn trên bởi trần tuyệt đối, và guard khóa thì không mở thêm.
   Basket luôn có SL/TP bắt buộc theo giá vào bình quân.

5. **EA mô phỏng và bằng chứng cũ không đổi.** `GridLabEA`/`DCALabEA`/`PATrendRiderXAUv1SimEA` vẫn thuần
   vị thế ảo. Bằng chứng Strategy Tester cũ vẫn hợp lệ và được ghi nhãn riêng (`sim_*`), không trộn với
   kết quả EA demo.

6. **Không quảng bá hiệu năng.** Kết quả demo/backtest không phải cam kết lợi nhuận. Khi chưa có phiên
   demo thật, mọi tài liệu phải ghi `NOT_RUN`; không được viết "đã chạy demo" nếu chưa có journal.

7. **Live/real vẫn cần scope mới.** Bất kỳ thay đổi nào cho phép tài khoản real phải có ADR khác, được
   chủ dự án chấp thuận trước khi viết code.

## Hệ quả

- `scripts/validate-project.py`: allow-list nguồn exec mở rộng cho `GridDemoEA.mq5`, `DCADemoEA.mq5` (và
  các include/test đi kèm). Mọi source khác vẫn bị chặn API lệnh.
- `scripts/validate_demo_execution.py`: kiểm tra guardrail cho **cả ba** EA demo (demo-gate, dry-run
  default, kill switch, trần grid/add, SL/TP bắt buộc, một điểm gửi lệnh).
- `configs/demo/`: thêm preset `grid_demo.json`, `dca_demo.json` (`execution_mode: DEMO_ONLY`,
  `allow_live_trading: false`).
- Tài liệu vận hành: `docs/guides/demo-execution.md` mở rộng cho ba bot.
- Trạng thái `BLOCKED_PENDING_ADR` cho Grid/DCA demo được **gỡ** khỏi `docs/v2/*`, `docs/README.md`,
  `docs/MASTER_ROADMAP.md`; thay bằng `ALLOWED` + nhãn bằng chứng thật (`NOT_RUN` tới khi có phiên demo).
- `AGENTS.md` cập nhật: đường thực thi là ba EA demo trên `mt5/Include/Exec/*`, không còn câu
  "never use grid/DCA/martingale".

## Phương án đã cân nhắc

- **Thêm cờ execution vào chính EA mô phỏng:** loại (giữ nguyên lý do ADR 0003: trộn hai chế độ làm bằng
  chứng khó tái lập và tăng rủi ro bật nhầm).
- **Cho EA demo tự gọi `OrderSend` thay vì `ExecBroker`:** loại. Một điểm gửi lệnh duy nhất là điều kiện
  để static gate còn hiệu lực.
- **Đặt `InpEnableExecution=true` làm mặc định code:** loại. Attach nhầm EA lên chart demo sẽ vào lệnh
  ngay khi mở terminal; giữ mặc định dry-run và bật trong preset.
- **Cho phép tài khoản real:** loại tuyệt đối (ADR 0002/0003).
