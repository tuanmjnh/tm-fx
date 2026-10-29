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
  mình, ghi `KILL`, chuyển `ERROR_SAFE_MODE` và không vào lệnh mới. Đã kiểm bằng file thật trên tài
  khoản demo ngày 2026-10-29 — journal trả `KILL` + `STATE to=ERROR_SAFE_MODE` trong 16 giây
  (xem [`../PROGRESS.md`](../PROGRESS.md) §44.4).
- Có thể gỡ EA khỏi chart hoặc tắt Algo Trading; EA chỉ quản lý vị thế có magic của nó.

### 5.1 Chạy lại sau kill switch — quy trình reset

**Xoá file là chưa đủ.** Hai lớp chốt phải gỡ theo thứ tự:

1. `g_kill_switch` chốt cứng đến khi `OnInit` chạy lại (`if(g_kill_switch) return;`).
2. `OnDeinit` luôn gọi `WriteStateFile()` *trước* khi `OnInit` đọc lại, nên `ERROR_SAFE_MODE` sống sót
   qua `pa_trendrider_demo_state.csv` và bản nạp lại vẫn ra `state=ERROR_SAFE_MODE|restored=1`.

Cách chuẩn (đây là input cố ý dành cho operator):

1. Xoá `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt`.
2. Mở hộp thoại input của EA trên chart, đặt `InpResetStateOnInit=true` (chỉ đổi input cũng làm EA
   `OnDeinit`/`OnInit` lại — không cần thao tác gì thêm).
3. Xác nhận `INIT ... state=WAITING_FOR_SETUP|restored=0` trong `pa_trendrider_demo.csv`.
4. Đặt `InpResetStateOnInit=false` để giữ daily lock / drawdown lock qua các lần khởi động sau.

Bước 4 quan trọng: `InpResetStateOnInit=true` làm mất `day_start`, `peak`, `cooldown_until` và
`dd_locked` của ngày hiện tại, tức xoá luôn các khoá rủi ro trong ngày.

Nếu không có quyền mở hộp thoại input (giám sát từ xa), con đường tương đương ở mức file là chặn
`WriteStateFile` trong đúng một lần nạp lại: thay state file bằng một file rỗng có thuộc tính
*read-only*, đổi timeframe để EA nạp lại (`FileOpen(FILE_WRITE)` fail — EA chỉ in
`LAB|ERROR|trendrider_demo|state_write_failed`, không chuyển sang safe mode), rồi bỏ read-only và
xoá file rỗng để EA tự viết lại state đúng. Đã dùng cách này ngày 2026-10-29 và ghi lại ở
§44.5. Ưu tiên cách input; cách file chỉ là phương án dự phòng và để lại một khoảng thời gian
không persist state.

## 6. Nhật ký và kiểm chứng

CSV `pa_trendrider_demo.csv` dùng schema 18 cột của `SimLogger`. Tên event **đúng như mã phát ra**:

| Event | Ý nghĩa |
|---|---|
| `INIT` | Chế độ (`DRY_RUN`/`DEMO_EXECUTION`), `state`, `restored`, symbol, magic, TP R, `config_hash` |
| `REGIME` | Chỉ ghi khi regime đổi: `regime`, `bias`, `h1`, `m15`, `vol`, `spread_block`, `risk_lock` |
| `RISK` | `side`, `price`, `atr` khi vào lệnh; `ENTRY_BLOCKED|reason=…` khi bị chặn (chỉ ghi khi reason đổi) |
| `BOS` | Break-of-structure trên `M5`/`M15` |
| `ENTRY` | Lệnh khớp: `ORDER_FILLED|order=N|deal=N|ok|done`, entry/SL/TP, `risk_money` |
| `DRY_RUN` | Tín hiệu hợp lệ nhưng `InpEnableExecution=false` — không gửi lệnh |
| `TRAIL` | Dời SL (break-even + trailing); chỉ được siết, không được nới |
| `EXIT` | Đóng vị thế kèm P&L và lý do (`broker_close`, `reversal_*`, `kill_switch`) |
| `CLOSE_REQUEST` | EA chủ động gửi lệnh đóng (kèm `deal=N|ok|done`) |
| `STATE` | `to=…|reason=…|transitions=N` |
| `STATE_ERROR` | Transition bị từ chối — state không đổi |
| `KILL` | Kill switch kích hoạt, `entries_disabled` |
| `ERROR` | Lỗi runtime (quote không hợp lệ, gửi lệnh fail, …) |
| `ADOPT` / `SYNC` | Nhận vị thế đang mở của magic vào sổ kế toán EA / ticket đổi |
| `RESET` | `InpManualResetDrawdown` mở khoá drawdown |
| `SUMMARY` | Tổng hợp cuối phiên: entries/exits/wins/losses/net/drawdown/ledger/kill_switch |

Reason token cố định: `not_demo_account`, `account_trade_disabled`, `terminal_trade_disabled`,
`symbol_not_allowed`, `symbol_trade_disabled`, `symbol_close_only`, `kill_switch_active`, `dry_run`,
`take_profit_invalid`, `stop_below_broker_level`, `risk_budget_exceeded`, `free_margin_insufficient`.
Token chặn của chiến lược (`RISK|ENTRY_BLOCKED`) nằm ở một nhóm khác: `bias_unknown`, `regime_range`,
`reversal_watch`, `bos_against_bias`, `no_pullback`, `bos_too_old`, `volatility_high`,
`spread_blocked`, `risk_locked`, `lot_rejected`, `stop_rejected`.

### 6.1 Kiểm chứng broker demo chấp nhận lệnh — `ExecDemoProbe`

`ExecGuardTests` là test synthetic, còn Strategy Tester thì `ExecContextAllowed` trả `true` sớm
(`state.tester`), nên **cả hai không chứng minh server Exness nhận lệnh**. Muốn có bằng chứng đó, chạy
`mt5\Scripts\ExecDemoProbe.mq5` (deploy cùng `scripts\deploy_pineport.ps1`).

Các bước:

1. Bảo đảm chart đang mở là `XAUUSDm` trên **tài khoản demo**, không có
   `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt`.
2. Navigator → Scripts → double-click `ExecDemoProbe` với `InpConfirm=false` (mặc định). Tab Experts phải in:
   ```
   PROBE|READY|symbol=…|digits=…|volume=0.01|magic=25002002|stops_level=…|confirm=0
   PROBE|DRY|all_guards_pass|no_order_sent|set_InpConfirm_to_send
   ```
   Không có dòng `DRY` nào nghĩa là một guard đã chặn — đọc `PROBE|FAIL|<stage>|<reason>` rồi sửa nguyên
   nhân, đừng gửi lệnh.
3. Chỉ khi muốn có bằng chứng khớp lệnh thật: mở lại script, bật `InpConfirm=true` ở tab Inputs rồi OK.
   Probe gửi **đúng một** lệnh 0.01 có SL/TP, in `PROBE|OPEN`, `PROBE|POSITION`, rồi đóng ngay và in
   `PROBE|CLOSE`, `PROBE|DONE`.
4. Lưu bằng chứng: `MQL5\Logs\<date>.log` (UTF-16) và đối soát với tab **History** của chính terminal.

Kết quả mẫu đã đạt ngày 2026-10-29 (demo `464140826`):

```
PROBE|OPEN|order=2762481907|deal=2468899165|price=4045.79|volume=0.01|sl=4042.79|tp=4048.79|ok|done
PROBE|CLOSE|order=2762481909|deal=2468899168|price=4045.55|ok|done
PROBE|DONE|position=2762481907|deals=2|pnl=-0.24|balance=4999.76
```

Lưu ý:

- Probe dùng magic `25002002`, tách khỏi `25002001` của DemoEA, nên không tạo `ENTRY` giả trong
  `pa_trendrider_demo.csv`. Nhưng ledger của EA đọc **balance tài khoản**, vì vậy `drawdown_pct` trong
  dòng `RISK` sẽ phản ánh phần lỗ của probe trong vài tick kế tiếp — bình thường, không phải tín hiệu.
- Probe từ chối chạy trong Strategy Tester và từ chối khi `MQL_TRADE_ALLOWED` tắt.
- Một lệnh được chấp nhận **không** nghĩa là chiến lược sinh lời; nó chỉ đóng khoảng trống "server có
  khớp lệnh hay không".

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
| `INIT ... state=ERROR_SAFE_MODE` lặp lại dù đã xoá file kill switch | State file còn khoá an toàn và `OnDeinit` ghi lại trước `OnInit` đọc | Làm theo §5.1 (`InpResetStateOnInit=true` rồi trả về `false`) |
| EA chạy bình thường, journal đều, nhưng không bao giờ có `ENTRY` | H1/M15 chưa cùng hướng — `bias_unknown`/`regime_range` chiếm ~90% bar | Đúng thiết kế. Trong dữ liệu tester chỉ ~24% số bar ở regime trend, trung bình ~3.1 lệnh/tháng |
| `LAB|ERROR|trendrider_demo|state_write_failed` | State file không ghi được (read-only / đĩa đầy) | EA vẫn chạy và chỉ mất persist; bỏ read-only hoặc kiểm tra đĩa, vì lần nạp lại sau sẽ khởi động sạch |

## 9. Gỡ bỏ / quay lại mô phỏng

- Gỡ EA demo khỏi chart, xoá state/log demo nếu muốn replay sạch.
- EA mô phỏng (`PATrendRiderXAUv1SimEA`) không thay đổi và vẫn là đường chạy offline/Strategy Tester.
- Mọi thay đổi cho phép tài khoản real phải có ADR mới được chủ dự án chấp thuận trước khi viết code.
