# Demo execution — PATrendRider XAU v1

- **Phạm vi:** chạy EA TrendRider trên **tài khoản demo** hoặc Strategy Tester. Không áp dụng cho tài
  khoản real/contest.
- **Quyết định:** [`../decisions/0003-demo-execution-scope.md`](../decisions/0003-demo-execution-scope.md)
  (thay thế một phần ADR 0002).
- **Trạng thái bằng chứng:** mã nguồn compile 0/0 và contract test guard chạy được; kết quả giao dịch demo
  chỉ được ghi nhận sau khi EA chạy thật và journal được kiểm tra. Không có kết quả nào trong tài liệu này
  là cam kết lợi nhuận.

> EA demo là **dry-run mặc định**. Nó chỉ gửi lệnh khi `InpEnableExecution=true` và chỉ trên tài khoản
> demo. Không có cờ live, không đăng nhập hộ, không lưu mật khẩu.

## 1. Ranh giới an toàn

| Hạng mục | Quy tắc |
|---|---|
| Tài khoản | Chỉ `ACCOUNT_TRADE_MODE_DEMO` hoặc Strategy Tester. Real/contest → `INIT_FAILED`. |
| Dry-run | `InpEnableExecution=false` (mặc định): ghi quyết định, không gửi lệnh. |
| Số vị thế | Một vị thế theo `InpMagicNumber`; EA không mở vị thế thứ hai. |
| SL/TP | Bắt buộc. Take profit (TP) = entry ± R × `InpTakeProfitR`; broker thiếu SL/TP thì EA sửa một lần rồi đóng. |
| Khối lượng | Tính từ tick size/tick value và ngân sách rủi ro, làm tròn xuống volume step; lot tối thiểu vượt ngân sách → từ chối. |
| Khóa rủi ro | Daily loss, drawdown, chuỗi thua và cooldown dùng chung ledger Track C. |
| Kill switch | Tạo `PA_TREND_RIDER_DEMO_STOP.txt` trong `MQL5/Files` → đóng vị thế và ngừng vào lệnh. |
| Cấm | Martingale, grid, DCA, hedging, `WebRequest`, socket, đọc/ghi credential. |

## 2. Điều kiện trước khi chạy

1. Terminal MT5 đăng nhập **tài khoản demo** (tự đăng nhập bằng tay; không đưa mật khẩu cho agent).
2. Symbol khớp `InpAllowedSymbols` (mặc định tiền tố `XAUUSD`, chấp nhận `XAUUSDm`).
3. **Algo Trading** bật trong terminal và trong EA properties.
4. Preset: [`../../configs/demo/pa_trendrider_xau_demo.json`](../../configs/demo/pa_trendrider_xau_demo.json).
5. Static gate xanh:

```powershell
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
```

## 3. Biên dịch và triển khai

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  -Filter "Experts\PATrendRiderXAUv1DemoEA.mq5" -LogDir "reports\build-demo"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  -Filter "Scripts\ExecGuardTests.mq5" -LogDir "reports\build-demo"
```

Đường dẫn MetaEditor phụ thuộc vào bản cài đặt. Sau khi cài lại MT5 của Exness, bản cũ
`C:\Program Files\MetaTrader 5\MetaEditor64.exe` không còn tồn tại; kiểm tra bằng
`scripts\check-environment.ps1` (script này đã dò cả hai vị trí) trước khi chạy lệnh trên.

Thay vì copy tay, dùng deploy script cho toàn bộ cây nguồn (nó copy `Include\Sim`, `Include\TrendRider`,
`Include\Exec` và compile mọi `.mq5` liên quan):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply
```

Chạy `ExecGuardTests` trong MetaEditor để xác nhận guard matrix trước khi gắn EA lên chart. Nếu MT5 đang
mở, nhấn phải chuột vào node trong Navigator → **Refresh** để nạp `.ex5` vừa compile.

## 4. Chạy dry-run trước

1. Gắn EA lên chart `XAUUSDm`, giữ `InpEnableExecution=false`. Chart có thể là H1: logic không đổi vì
   EA tự lấy dữ liệu theo `InpTrendTF`/`InpStructureTF`/`InpEntryTF` và phát hiện bar mới theo
   `InpEntryTF`, không theo timeframe của chart.
2. Bật **Algo Trading** của terminal trước khi gắn. Guard cần `TERMINAL_TRADE_ALLOWED` nên khi nút này
   tắt, EA từ chối khởi tạo kể cả ở chế độ dry-run và in
   `scope_rejected|terminal_trade_disabled` (hành vi fail-closed, không phải lỗi).
3. Kiểm tra journal có các dòng `INIT` (mode/symbols/magic/tp_r) và `DRY_RUN` kèm reason.
4. Đối chiếu: không có lệnh nào xuất hiện trong tab Trade/History.
5. Chỉ khi dry-run sạch, đặt `InpEnableExecution=true` cho một phiên demo có giám sát. Đổi input xong thì
   EA tự khởi tạo lại; `INIT` mới phải in `mode=DEMO_EXECUTION` và `config_hash` khác bản dry-run.

Muốn đọc log CSV trong khi EA vẫn chạy, `SimLogger` mở file với `FILE_SHARE_READ`; nếu bỏ cờ đó thì tool
bên ngoài không tail được file ("Device or resource busy").

## 5. Kill switch và dừng khẩn cấp

- Tạo file `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt` (nội dung bất kỳ). Tick kế tiếp EA đóng vị thế của
  mình, ghi `KILL_SWITCH`, chuyển `ERROR_SAFE_MODE` và không vào lệnh mới.
- Xoá file rồi khởi động lại EA để chạy lại.
- Có thể gỡ EA khỏi chart hoặc tắt Algo Trading; EA chỉ quản lý vị thế có magic của nó.

## 6. Nhật ký và kiểm chứng

CSV `pa_trendrider_demo.csv` dùng schema 18 cột của `SimLogger`. Các event chính:

| Event | Ý nghĩa |
|---|---|
| `INIT` | Chế độ (dry-run/live-disabled), symbol, magic, TP R |
| `DRY_RUN` | Tín hiệu hợp lệ nhưng chưa bật gửi lệnh |
| `ENTRY` | Lệnh demo đã khớp: order, deal, ticket, entry/SL/TP |
| `BLOCKED` | Lý do từ chối vào lệnh (reason token) |
| `TRAIL` / `BREAKEVEN` | Dời SL theo cấu trúc/ATR |
| `EXIT` | Đóng vị thế kèm P&L và lý do |
| `KILL_SWITCH` | Kill switch được kích hoạt |
| `SUMMARY` | Tổng hợp cuối phiên |

Reason token cố định: `not_demo_account`, `account_trade_disabled`, `terminal_trade_disabled`,
`symbol_not_allowed`, `symbol_trade_disabled`, `symbol_close_only`, `kill_switch_active`, `dry_run`,
`take_profit_invalid`, `stop_below_broker_level`, `risk_budget_exceeded`, `free_margin_insufficient`.

## 7. Cách đọc kết quả đúng

- **Dry-run không có lệnh là đúng.** **Demo có 0 entry cũng có thể đúng** khi không có setup.
- Chỉ ghi `PASS` cho một phiên khi journal cho thấy guardrail hoạt động (entry có SL/TP, một vị thế,
  block reason đúng) — không dựa vào số lãi/lỗ.
- Kết quả demo **không** chứng minh chiến lược có lợi nhuận và **không** phải điều kiện để chạy live.
- Nếu chưa chạy thật, giữ `NOT_RUN`/`BLOCKED`; không suy diễn kết quả từ compile hoặc backtest.

## 8. Xử lý sự cố

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `INIT_FAILED` + `not_demo_account` | Đang đăng nhập real/contest | Đăng nhập tài khoản demo |
| `account_trade_disabled` | Tài khoản bị cấm giao dịch | Kiểm tra với broker demo |
| `terminal_trade_disabled` | Algo Trading tắt | Bật Algo Trading |
| `symbol_not_allowed` | Symbol không khớp allow-list | Thêm tiền tố đúng vào `InpAllowedSymbols` |
| `symbol_trade_disabled` / `symbol_close_only` | Symbol bị tắt/close-only | Chọn symbol khác hoặc chờ broker mở |
| `risk_budget_exceeded` | Lot tối thiểu vượt ngân sách | Tăng vốn demo hoặc nới `InpRiskPercent` trong giới hạn |
| `free_margin_insufficient` | Không đủ margin | Giảm risk hoặc nạp thêm vốn demo |
| `stop_below_broker_level` | SL/TP quá sát giá | Kiểm tra `SYMBOL_TRADE_STOPS_LEVEL` |
| `take_profit_invalid` | TP tính ra sai phía giá | Kiểm tra entry/SL và `InpTakeProfitR` |

## 9. Gỡ bỏ / quay lại mô phỏng

- Gỡ EA demo khỏi chart, xoá state/log demo nếu muốn replay sạch.
- EA mô phỏng (`PATrendRiderXAUv1SimEA`) không thay đổi và vẫn là đường chạy offline/Strategy Tester.
- Mọi thay đổi cho phép tài khoản real phải có ADR mới được chủ dự án chấp thuận trước khi viết code.
