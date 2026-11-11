# Demo execution — InfiniteRunner XAU v2

- **Phạm vi:** chạy bot demo duy nhất `InfiniteRunnerXAUV2DemoEA` trên **tài khoản demo** hoặc Strategy
  Tester. Không áp dụng cho tài khoản real/contest.
- **Quyết định:** [`../90-decisions/0004-all-bots-demo-execution.md`](../90-decisions/0004-all-bots-demo-execution.md),
  [`../90-decisions/0005-infiniterunner-xau-demo-bot.md`](../90-decisions/0005-infiniterunner-xau-demo-bot.md)
  và [`../90-decisions/0006-demo-default-execution-enabled.md`](../90-decisions/0006-demo-default-execution-enabled.md)
  (ADR 0002 và phần còn lại của ADR 0003 vẫn hiệu lực).
- **Trạng thái bằng chứng:** mã nguồn compile 0/0, static gate xanh và contract test guard chạy được;
  kết quả giao dịch demo chỉ được ghi nhận sau khi EA chạy thật và journal được kiểm tra. Không có kết quả
  nào trong tài liệu này là cam kết lợi nhuận.

> EA demo **bật execution mặc định** (ADR 0006: `InpEnableExecution=true` ở cả code và preset).
> Nó gửi lệnh ngay khi có setup hợp lệ và chỉ trên tài khoản demo. Muốn phiên đối chiếu không
> gửi lệnh, đặt `InpEnableExecution=false` (dry-run) trong hộp input. Không có cờ live, không đăng nhập hộ,
> không lưu mật khẩu.

| Chiến lược | EA demo | Preset | Kill switch | Ghi chú |
|---|---|---|---|---|
| InfiniteRunner_XAU | `InfiniteRunnerXAUV2DemoEA` | `configs/demo/infinite_runner_demo.json` | `INFINITE_RUNNER_DEMO_STOP.txt` | một vị thế runner, TP an toàn xa bắt buộc `InpSafetyTpPoints`, trail đơn điệu từ R ban đầu |

Magic: InfiniteRunner `25006001` (probe `25002002`) — không chạm vị thế của chương trình khác.

Preset ship với `InpEnableExecution=true` (ADR 0006 — bot chạy ngay trên demo). Muốn dry-run đối chiếu thì
đặt `InpEnableExecution=false` — đó là chế độ có chủ đích, không còn là mặc định. Ranh giới phạm vi khác
không đổi: chỉ demo/tester.

## 1. Ranh giới an toàn

| Hạng mục | Quy tắc |
|---|---|
| Tài khoản | Chỉ `ACCOUNT_TRADE_MODE_DEMO` hoặc Strategy Tester. Real/contest → `INIT_FAILED`. |
| Dry-run | `InpEnableExecution=true` mặc định (ADR 0006); đặt `false` cho phiên đối chiếu không gửi lệnh (ghi quyết định, không gửi lệnh). |
| Số vị thế | Một vị thế theo `InpMagicNumber` (`InpMaxPositions=1`). |
| SL/TP | Bắt buộc trên **mọi** lệnh (stop loss và take profit). SL trong band `[InpMinStopPoints, InpMaxStopPoints]` normalize theo tick; take profit an toàn xa = entry ± `InpSafetyTpPoints` — không có input nào tắt được take profit. |
| Khối lượng | Tính từ tick size/tick value và ngân sách rủi ro (`ExecCalcProfit` khi `InpLotMode=1`), làm tròn xuống volume step, chặn bởi `InpMaxLots`. |
| Khóa rủi ro | Daily loss (`InpMaxDailyLossPct`), drawdown (`InpMaxDrawdownPct`, persist qua state file), chuỗi thua (`InpMaxConsecutiveLosses`). Vi phạm → đóng vị thế/ngừng vào lệnh; `InpHaltOnBreach=true` buộc dời lại. |
| Kill switch | Tạo file kill switch trong `MQL5/Files` → đóng vị thế (`InpCloseOnKillSwitch=true`) và ngừng vào lệnh tới khi khởi động lại. |
| Cấm | Martingale/grid/DCA, hedging, `WebRequest`, socket, đọc/ghi credential, tài khoản live. |

Giới hạn cứng mà không có input nào nới được: tài khoản phải là demo/tester, mọi lệnh phải có SL và TP, và
mọi lệnh đi qua `ExecBroker.mqh` (điểm gửi lệnh duy nhất).

## 2. Điều kiện trước khi chạy

1. Terminal MT5 đăng nhập **tài khoản demo** (tự đăng nhập bằng tay; không đưa mật khẩu cho agent).
2. Symbol khớp `InpAllowedSymbols` (mặc định tiền tố `XAUUSD`, chấp nhận `XAUUSDm`).
3. **Algo Trading** bật trong terminal và trong EA properties.
4. Preset: [`../../configs/demo/infinite_runner_demo.json`](../../configs/demo/infinite_runner_demo.json).
5. Static gate xanh:

```powershell
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
```

## 3. Biên dịch và triển khai

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  -Filter "Experts\InfiniteRunnerXAUV2DemoEA.mq5" -LogDir "reports\build-demo"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  -Filter "Scripts\ExecGuardTests.mq5" -LogDir "reports\build-demo"
```

Đường dẫn MetaEditor phụ thuộc vào bản cài đặt; kiểm tra bằng `scripts\check-environment.ps1` trước khi chạy.

Thay vì copy tay, dùng deploy script cho toàn bộ cây nguồn (nó copy `Include\Sim`, `Include\Exec`,
`Include\InfiniteRunner` và compile mọi `.mq5` liên quan — bao gồm `InfiniteRunnerXAUV2DemoEA`, script test
`IRCoreTests` và các include `IRTypes`/`IRDirection`/`IRTrailing`/`IRRisk`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply
```

Chạy `ExecGuardTests` trong MetaEditor để xác nhận guard matrix trước khi gắn EA lên chart. Nếu MT5 đang
mở, nhấn phải chuột vào node trong Navigator → **Refresh** để nạp `.ex5` vừa compile.

## 4. Chạy InfiniteRunner demo (ADR 0005)

Runner quyết định theo **nến đã đóng** với mô hình ba khung `InpH1TF` (bối cảnh H1) →
`InpM15TF` (cấu trúc M15) → `InpEntryTF` (vào lệnh M5), hoặc chế độ đối chiếu `InpDirectionMode=0` (EMA
parity kiểu V1). Preset mặc định: `InpDirectionMode=0`, `InpEntryTF=M5`, SL cố định 5000 điểm, TP an toàn
xa 100000 điểm, trail cố định 2500 điểm sau khi lợi nhuận vượt `InpTrailStartPts=3000`. Chuỗi thua
(`InpMaxConsecutiveLosses=3`) **không còn khoá vĩnh viễn**: sau `InpLossStreakCooldownMinutes` (mặc định
240 phút) bot tự xoá chuỗi và vào lại (đặt `0` = khoá vĩnh viễn, không khuyến nghị). Trước khi gắn EA lên
chart, chạy `Scripts > IRCoreTests` và kỳ vọng `TEST|RESULT|ALL_PASS|pass=N fail=0|ir=1`.

1. **Transform đúng chart**: `XAUUSDm`, khung chart đề nghị **M5** (khớp `InpEntryTF`; logic đọc tự ba khung
   input, không phụ thuộc khung chart).
2. **(Tuỳ chọn) Dry-run một phiên** với `InpEnableExecution=false` (preset mặc định là `true` —
   ADR 0006): xem dòng `INIT` trong `infinite_runner_demo.csv` (mode/symbols/magic/safety_tp) và các dòng
   `DECISION|…` mỗi bar M5 đã đóng.
3. **Chẩn đoán `NO_TRADE` đúng cách** — dry-run không vào lệnh là bình thường, đọc `reason` trong
   `DECISION|…|NO_TRADE` / `BLOCKED|…`:

| Reason trong CSV `DECISION`/`BLOCKED` | Nghĩa | Ghi chú điều chỉnh |
|---|---|---|
| `direction_ambiguous` / `bias_unknown` | H1/M15 chưa cùng hướng — bộ lọc chọn lọc của mô hình MTF | Đặc trưng chiến lược; tần suất NO_TRADE cao là kỳ vọng, không phải lỗi |
| `cooldown_active` / `min_bars` / `max_trades_per_day` | Khoảng cách vào lệnh | Tăng `InpCooldownMinutes`/`InpMaxTradesPerDay` nếu dẫn chứng hợp lệ |
| `spread_blocked` | Spread vượt `InpMaxSpreadPoints=600` (kiểm luôn `InpMaxSpreadAtrRatio` nếu >0) | Mặc định 600 đã mở rộng; đọc `spread=` trong CSV |
| `atr_abnormal` | ATR vượt `InpAbnormalAtrRatio` × baseline | Bộ lọc biến động; giữ nguyên trừ khi hiểu rõ |
| `risk_locked:daily_loss` / `max_drawdown` / `consecutive_losses` | Khoá rủi ro đã chạm trần | Không nới để "cho có lệnh"; riêng chuỗi thua tự hồi phục sau `InpLossStreakCooldownMinutes` |
| `kill_switch_active` | File kill switch còn tồn tại | Xoá file theo §5.1 |
| `timeframe_order_invalid` (OnInit) | `InpH1TF ≤ InpM15TF ≤ InpEntryTF` | Sắp lại H1 > M15 > M5 |

4. **Phiên enabled là mặc định** (ADR 0006): với `InpEnableExecution=true` (preset mặc định),
   journal phải in `INIT|mode=DEMO_EXECUTION` với `config_hash` riêng. Lệnh thật được gửi qua `ExecBroker`;
   mỗi `ENTRY` kèm `sl` (trong band) + `tp` xa bắt buộc, `retcode=done`.
5. Kiểm tra sau khi có lệnh: **đúng một** vị thế theo magic `25006001`; mọi lệnh có `sl≠0` và `tp≠0`;
   dòng `SL_UPDATE` chỉ được **thắt chặt** (SL BUY chỉ tăng, SELL chỉ giảm — trail đơn điệu từ R ban đầu,
   không tính lại); `EXIT` có `pnl` và `consecutive_losses`.
6. Dừng: tạo `MQL5\Files\INFINITE_RUNNER_DEMO_STOP.txt` (nội dung bất kỳ) hoặc gỡ EA. Kill switch đóng
   runner ngay và chốt tới khi khởi động lại; State file `infinite_runner_demo_state.csv` giữ
   `dd_locked`/ledger qua các lần nạp (reset dùng `InpResetStateOnInit=true` rồi phải trả về `false`).

**Backtest bằng Strategy Tester**: sinh `.set` từ preset bằng `scripts\tester\run_tester.ps1` rồi copy vào
`MQL5\Profiles\Tester\`. `.set` bật `InpEnableExecution=true`; preset JSON cũng mặc định `true`
(ADR 0006) nên demo chạy tay không cần thao tác gì thêm.

## 5. Kill switch và dừng khẩn cấp

- Tạo file `MQL5\Files\INFINITE_RUNNER_DEMO_STOP.txt` (nội dung bất kỳ). Tick kế tiếp EA đóng vị thế của
  mình, ghi `HALT_EXIT`, và không vào lệnh mới.
- Có thể gỡ EA khỏi chart hoặc tắt Algo Trading; EA chỉ quản lý vị thế có magic của nó.

### 5.1 Chạy lại sau kill switch — quy trình reset

**Xoá file là chưa đủ.** Hai lớp chốt phải gỡ theo thứ tự:

1. Cờ kill switch trong bộ nhớ chốt cứng đến khi `OnInit` chạy lại.
2. `OnDeinit` luôn gọi ghi state *trước* khi `OnInit` đọc lại, nên khoá an toàn sống sót qua
   `infinite_runner_demo_state.csv`.

Cách chuẩn (đây là input cố ý dành cho operator):

1. Xoá `MQL5\Files\INFINITE_RUNNER_DEMO_STOP.txt`.
2. Mở hộp thoại input của EA trên chart, đặt `InpResetStateOnInit=true` (chỉ đổi input cũng làm EA
   `OnDeinit`/`OnInit` lại — không cần thao tác gì thêm).
3. Xác nhận dòng `INIT` mới trong `infinite_runner_demo.csv` với `restored=0`.
4. Đặt `InpResetStateOnInit=false` để giữ daily lock / drawdown lock qua các lần khởi động sau.

Bước 4 quan trọng: `InpResetStateOnInit=true` làm mất `day_start`, `peak`, `cooldown_until` và `dd_locked`
của ngày hiện tại, tức xoá luôn các khoá rủi ro trong ngày.

## 6. Nhật ký và kiểm chứng

CSV `infinite_runner_demo.csv` dùng schema 18 cột của `SimLogger`. Tên event **đúng như mã phát ra**:

| Event | Ý nghĩa |
|---|---|
| `INIT` | Chế độ (`DRY_RUN`/`DEMO_EXECUTION`), state, `restored`, symbol, magic, TP an toàn, `config_hash`, `mql_trade_allowed` |
| `DECISION` | Quyết định mỗi nến đã đóng: hướng, reason (`NO_TRADE`/…) |
| `BLOCKED` | Entry bị chặn kèm reason ổn định |
| `ENTRY` | Lệnh khớp: `order=N\|deal=N\|ok\|done`, entry/SL/TP, `risk_money` |
| `DRY_RUN` | Tín hiệu hợp lệ nhưng `InpEnableExecution=false` — không gửi lệnh |
| `SL_UPDATE` | Dời SL (break-even + trailing); chỉ được siết, không được nới |
| `EMERGENCY_SL` | Đặt lại SL khẩn cấp khi vị thế thiếu SL |
| `EXIT` | Đóng vị thế kèm P&L và lý do |
| `ADOPT` | Nhận vị thế đang mở của magic vào sổ kế toán EA |
| `HALT` / `HALT_EXIT` | Khoá rủi ro kích hoạt kèm `reason=` / đóng vị thế khi halt |
| `ERROR` | Lỗi runtime (quote không hợp lệ, gửi lệnh fail, …) |
| `SUMMARY` | Tổng hợp cuối phiên: entries/exits/wins/losses/net/drawdown/ledger/kill_switch |

Reason token cố định (guard): `not_demo_account`, `account_trade_disabled`, `terminal_trade_disabled`,
`symbol_not_allowed`, `symbol_trade_disabled`, `symbol_close_only`, `kill_switch_active`, `dry_run`,
`take_profit_invalid`, `stop_below_broker_level`, `risk_budget_exceeded`, `free_margin_insufficient`.

### 6.1 Kiểm chứng broker demo chấp nhận lệnh — `ExecDemoProbe`

`ExecGuardTests` là test synthetic, còn Strategy Tester thì `ExecContextAllowed` trả `true` sớm
(`state.tester`), nên **cả hai không chứng minh server nhận lệnh**. Muốn có bằng chứng đó, chạy
`mt5\Scripts\ExecDemoProbe.mq5` (deploy cùng `scripts\deploy_pineport.ps1`).

Các bước:

1. Bảo đảm chart đang mở trên **tài khoản demo**, không có
   `MQL5\Files\INFINITE_RUNNER_DEMO_STOP.txt`.
2. Navigator → Scripts → double-click `ExecDemoProbe` với `InpConfirm=false` (mặc định). Tab Experts phải in
   `PROBE|READY|…` rồi `PROBE|DRY|all_guards_pass|no_order_sent|set_InpConfirm_to_send`. Không có dòng
   `DRY` nào nghĩa là một guard đã chặn — đọc `PROBE|FAIL|<stage>|<reason>` rồi sửa nguyên nhân, đừng gửi lệnh.
3. Chỉ khi muốn có bằng chứng khớp lệnh thật: mở lại script, bật `InpConfirm=true` ở tab Inputs rồi OK.
   Probe gửi **đúng một** lệnh 0.01 có SL/TP, in `PROBE|OPEN`, `PROBE|POSITION`, rồi đóng ngay và in
   `PROBE|CLOSE`, `PROBE|DONE`.
4. Lưu bằng chứng: `MQL5\Logs\<date>.log` (UTF-16) và đối soát với tab **History** của chính terminal.

Probe dùng magic `25002002`, tách khỏi `25006001` của EA, nên không tạo `ENTRY` giả trong journal. Một lệnh
được chấp nhận **không** nghĩa là chiến lược sinh lời; nó chỉ đóng khoảng trống "server có khớp lệnh hay không".

### 6.2 Giám sát journal và báo `ENTRY` thật — `watch_demo_journal.py`

`scripts\watch_demo_journal.py` đọc file `MQL5\Files\infinite_runner_demo.csv`, ghi nhớ checkpoint byte và
chỉ in các dòng mới. Nó **chỉ đọc**: không mở MT5, không gọi trading API, không ghi vào `MQL5\Files`;
checkpoint nằm ở `reports\demo-watch\`.

```powershell
.venv\Scripts\python.exe scripts\watch_demo_journal.py            # tail: chỉ in dòng mới từ lần chạy trước
.venv\Scripts\python.exe scripts\watch_demo_journal.py --reset --from-start   # quét toàn bộ lịch sử
.venv\Scripts\python.exe scripts\watch_demo_journal.py --watch --interval 60 --timeout 3600 --stop-on-alert
```

Event báo alert: `ENTRY`, `EXIT`, `TRAIL`, `CLOSE_REQUEST`, `ADOPT`, `SYNC` (nhóm `ORDER`) và `KILL`,
`ERROR`, `STATE_ERROR`, `RESET` (nhóm `FAULT`). `DECISION`, `BLOCKED`, `INIT`, `SUMMARY` chỉ vào tổng hợp,
không phải alert. Watcher in `WATCH|FAULT|kill_switch_file_present` nếu
`INFINITE_RUNNER_DEMO_STOP.txt` còn tồn tại, và `WATCH|NOTE|journal_stale` nếu file không được ghi hơn 2 giờ.

Exit code: `0` không alert, `1` có alert (dùng cho cron/thông báo), `2` không tìm thấy journal hoặc schema
không đủ 18 cột.

Alert `ENTRY` cần được đối soát với tab **History** trước khi ghi nhận là bằng chứng — cùng nguyên tắc với §6.1.

## 7. Cách đọc kết quả đúng

- **Dry-run không có lệnh là đúng.** **Demo có 0 entry cũng có thể đúng** khi không có setup.
- Chỉ ghi `PASS` cho một phiên khi journal cho thấy guardrail hoạt động (entry có SL/TP, một vị thế, block
  reason đúng) — không dựa vào số lãi/lỗ.
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
| `take_profit_invalid` | TP tính ra sai phía giá | Kiểm tra entry/SL và `InpSafetyTpPoints` |
| State file còn khoá an toàn dù đã xoá file kill switch | `OnDeinit` ghi lại trước `OnInit` đọc | Làm theo §5.1 (`InpResetStateOnInit=true` rồi trả về `false`) |
| EA chạy bình thường nhưng không bao giờ có `ENTRY` | H1/M15 chưa cùng hướng — `bias_unknown`/`direction_ambiguous` chiếm phần lớn bar | Đúng thiết kế; đọc `DECISION` trong CSV |

## 9. Gỡ bỏ

- Gỡ EA demo khỏi chart, xoá state/log demo nếu muốn replay sạch.
- Mọi thay đổi cho phép tài khoản real phải có ADR mới được chủ dự án chấp thuận trước khi viết code.
