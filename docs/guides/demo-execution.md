# Demo execution — PATrendRider, Grid, DCA và InfiniteRunner

- **Phạm vi:** chạy **cả bốn bot** (`PATrendRiderXAUv1`, `Grid`, `DCA`, `InfiniteRunner_XAU`) trên
  **tài khoản demo** hoặc Strategy Tester. Không áp dụng cho tài khoản real/contest.
- **Quyết định:** [`../decisions/0004-all-bots-demo-execution.md`](../decisions/0004-all-bots-demo-execution.md)
  và [`../decisions/0005-infiniterunner-xau-demo-bot.md`](../decisions/0005-infiniterunner-xau-demo-bot.md)
  (ADR 0005 thêm bot thứ tư; ADR 0002 và phần còn lại của ADR 0003 vẫn hiệu lực).
- **Trạng thái bằng chứng:** mã nguồn compile 0/0, static gate xanh và contract test guard chạy được;
  kết quả giao dịch demo chỉ được ghi nhận sau khi EA chạy thật và journal được kiểm tra. Không có kết quả
  nào trong tài liệu này là cam kết lợi nhuận.

> EA demo **bật execution mặc định** (ADR 0006: `InpEnableExecution=true` ở cả code và preset).
> Nó gửi lệnh ngay khi có setup hợp lệ và chỉ trên tài khoản demo. Muốn phiên đối chiếu không
> gửi lệnh, đặt `InpEnableExecution=false` trong hộp input. Không có cờ live, không đăng nhập hộ,
> không lưu mật khẩu.

| Chiến lược | EA demo | Preset | Kill switch | Ghi chú |
|---|---|---|---|---|
| PATrendRiderXAUv1 | `PATrendRiderXAUv1DemoEA` | `configs/demo/pa_trendrider_xau_demo.json` | `PA_TREND_RIDER_DEMO_STOP.txt` | một vị thế, TP theo `InpTakeProfitR` |
| Grid | `GridDemoEA` | `configs/demo/grid_demo.json` | `GRID_DEMO_STOP.txt` | tối đa `InpMaxGridLevels` tầng, SL/TP giỏ |
| DCA | `DCADemoEA` | `configs/demo/dca_demo.json` | `DCA_DEMO_STOP.txt` | tối đa `InpMaxDcaAdds` lần add, SL/TP giỏ |
| InfiniteRunner_XAU | `InfiniteRunnerXAUV2DemoEA` | `configs/demo/infinite_runner_demo.json` | `INFINITE_RUNNER_DEMO_STOP.txt` | một vị thế runner, TP an toàn xa bắt buộc `InpSafetyTpPoints`, trail đơn điệu từ R ban đầu |

Magic spacing: TrendRider `25002001`, Grid `25004001`, DCA `25005001`, InfiniteRunner `25006001`
(probe `25002002`) — không bot nào chạm vị thế của bot khác.

Preset nào cũng ship với `InpEnableExecution=true` (ADR 0006 — bot chạy ngay trên demo). Muốn
dry-run đối chiếu thì đặt `InpEnableExecution=false` — đó là chế độ có chủ đích, không còn là
mặc định. Ranh giới phạm vi khác không đổi: chỉ demo/tester.

## 1. Ranh giới an toàn

| Hạng mục | Quy tắc (cả bốn bot) |
|---|---|
| Tài khoản | Chỉ `ACCOUNT_TRADE_MODE_DEMO` hoặc Strategy Tester. Real/contest → `INIT_FAILED`. |
| Dry-run | `InpEnableExecution=true` mặc định (ADR 0006); đặt `false` cho phiên đối chiếu không gửi lệnh (ghi quyết định, không gửi lệnh). |
| Số vị thế | TrendRider/Runner: một vị thế theo `InpMagicNumber`. Grid/DCA: một **giỏ** theo magic, bị chặn bởi `InpMaxGridLevels` / `InpMaxDcaAdds`. |
| SL/TP | Bắt buộc trên **mọi** lệnh (stop loss và take profit). TrendRider: take profit = entry ± R × `InpTakeProfitR`. Grid/DCA: SL/TP tính từ giá vào bình quân, đặt cùng một mức giá tuyệt đối lên mọi chân và cập nhật lại sau mỗi lần thêm. Runner: SL trong band `[InpMinStopPoints, InpMaxStopPoints]` normalize theo tick, TP an toàn xa = entry ± `InpSafetyTpPoints` — không có input nào tắt được take profit. |
| Khối lượng | TrendRider/Runner: tính từ tick size/tick value và ngân sách rủi ro (`ExecCalcProfit` cho Runner khi `InpLotMode=1`), làm tròn xuống volume step, chặn bởi `InpMaxLots` / `InpMaxVirtualExposure`. Grid/DCA: `base × multiplier^n` nhưng luôn bị chặn bởi trần mỗi chân và `InpMaxExposure`; normalize theo volume step, dưới lot tối thiểu → từ chối. |
| Ngân sách lỗ giỏ | Grid/DCA: `InpMaxBasketLossPct` chặn lệnh thêm nếu lỗ của cả giỏ tại stop vượt % equity. |
| Khóa rủi ro | Daily loss (`InpMaxDailyLossPct`), drawdown (`InpMaxDrawdownPct`, persist qua state file), chuỗi thua (`InpMaxConsecutiveLosses`). Vi phạm → đóng vị thế/giỏ và ngừng vào lệnh; runner dời lại khi `InpHaltOnBreach=true`. |
| Kill switch | Tạo file kill switch trong `MQL5/Files` → đóng vị thế/giỏ (`InpCloseOnKillSwitch=true`) và ngừng vào lệnh tới khi khởi động lại. |
| Cấm | Martingale/grid/DCA **vô hạn**, hedging, `WebRequest`, socket, đọc/ghi credential, tài khoản live. |

Giới hạn cứng mà không có input nào nới được: tài khoản phải là demo/tester, mọi lệnh phải có SL và TP,
số tầng/add và tổng exposure luôn hữu hạn, và mọi lệnh đi qua `ExecBroker.mqh` (điểm gửi lệnh duy nhất).

## 2. Điều kiện trước khi chạy

1. Terminal MT5 đăng nhập **tài khoản demo** (tự đăng nhập bằng tay; không đưa mật khẩu cho agent).
2. Symbol khớp `InpAllowedSymbols` (mặc định tiền tố `XAUUSD`, chấp nhận `XAUUSDm`).
3. **Algo Trading** bật trong terminal và trong EA properties.
4. Preset (chọn theo bot):
   [`../../configs/demo/pa_trendrider_xau_demo.json`](../../configs/demo/pa_trendrider_xau_demo.json),
   [`../../configs/demo/grid_demo.json`](../../configs/demo/grid_demo.json),
   [`../../configs/demo/dca_demo.json`](../../configs/demo/dca_demo.json),
   [`../../configs/demo/infinite_runner_demo.json`](../../configs/demo/infinite_runner_demo.json).
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
`Include\Exec`, `Include\InfiniteRunner` và compile mọi `.mq5` liên quan — bao gồm
`InfiniteRunnerXAUV2DemoEA` và ba include `IRTypes`/`IRDirection`/`IRTrailing`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply
```

Chạy `ExecGuardTests` trong MetaEditor để xác nhận guard matrix trước khi gắn EA lên chart. Nếu MT5 đang
mở, nhấn phải chuột vào node trong Navigator → **Refresh** để nạp `.ex5` vừa compile.

## 4. Quy trình khuyến nghị (dry-run đối chiếu trước — có chủ đích)

1. **Dry-run là có chủ đích từ ADR 0006**: mặc định preset là `InpEnableExecution=true`. Muốn
   phiên không lệnh, đặt `InpEnableExecution=false` trong hộp input **trước** khi gắn. Chart có thể là
   H1: logic không đổi vì EA tự lấy dữ liệu theo `InpTrendTF`/`InpStructureTF`/`InpEntryTF` và phát
   hiện bar mới theo `InpEntryTF`, không theo timeframe của chart.
2. Bật **Algo Trading** của terminal trước khi gắn. Guard cần `TERMINAL_TRADE_ALLOWED` nên khi nút này
   tắt, EA từ chối khởi tạo kể cả ở chế độ dry-run và in
   `scope_rejected|terminal_trade_disabled` (hành vi fail-closed, không phải lỗi).
3. Kiểm tra journal có các dòng `INIT` (mode/symbols/magic/tp_r) và `DRY_RUN` kèm reason.
4. Đối chiếu: không có lệnh nào xuất hiện trong tab Trade/History.
5. Khi dry-run sạch, đặt lại `InpEnableExecution=true` cho phiên demo có giám sát. Đổi input xong thì
   EA tự khởi tạo lại; `INIT` mới phải in `mode=DEMO_EXECUTION` và `config_hash` khác bản dry-run.
6. Nếu không cần đối chiếu dry-run: gắn preset mặc định (enabled) và theo dõi journal + CSV ngay từ
   phiên đầu — đây là chế độ vận hành bình thường theo ADR 0006.

Muốn đọc log CSV trong khi EA vẫn chạy, `SimLogger` mở file với `FILE_SHARE_READ`; nếu bỏ cờ đó thì tool
bên ngoài không tail được file ("Device or resource busy").

### 4.1 Khởi động EA bằng terminal startup config (không cần gắn tay)

Khi không thao tác được chuột trên terminal (máy từ xa, phiên không người), MT5 vẫn gắn được EA ngay khi
khởi động bằng section `[StartUp]` của file cấu hình truyền qua `/config:` — đây là cơ chế chính thức của
terminal, không phải workaround:

```ini
[Experts]
AllowDllImport=0
AllowLiveTrading=1
Enabled=1
Account=0
Profile=0
Chart=0
Api=0

[StartUp]
Expert=PATrendRiderXAUv1DemoEA
ExpertParameters=pa_trendrider_demo_live.set
Symbol=XAUUSDm
Period=M5
```

- `Expert` là tên file trong `MQL5\Experts` (không cần đuôi `.ex5`); `ExpertParameters` là preset trong
  `MQL5\Presets`. Preset phải sinh từ
  [`../../configs/demo/pa_trendrider_xau_demo.json`](../../configs/demo/pa_trendrider_xau_demo.json) với
  `InpEnableExecution=true`, `InpResetStateOnInit=false`; giữ nguyên `InpLogFile`/`InpStateFile` nếu muốn
  nối tiếp journal và ledger đang có.
- `Enabled=1` là nút **Algo Trading**; `AllowLiveTrading=1` là quyền giao dịch cấp cho EA được nạp lúc
  khởi động. Dòng `INIT` ghi thêm `mql_trade_allowed=1|0` (từ 2026-10-29); nếu là `0` thì terminal chưa
  cấp quyền và lệnh đầu tiên sẽ bị chặn với `OrderSend` error 10027 — xem
  [`../reference/risk.md`](../reference/risk.md).
- File cấu hình chỉ chứa input chiến lược và cờ quyền; **không** chứa login/password/server. Terminal vẫn
  dùng phiên đăng nhập đã lưu; đăng nhập lại là thao tác tay, agent không điền hộ.

Kiểm chứng sau khi khởi động (2026-10-29, build 6292):

```text
Startup  successfully initialized from start config "...\startup.ini"
Experts  expert PATrendRiderXAUv1DemoEA (XAUUSDm,M5) loaded successfully
MQL5     47 inputs read from expert 'PATrendRiderXAUv1DemoEA' set file "...\pa_trendrider_demo_live.set"
```

rồi dòng `INIT` trong `pa_trendrider_demo.csv` phải là `mode=DEMO_EXECUTION` với `config_hash=6B439450`
và `restored=1` khi state file còn nguyên. Nếu thấy `mode=DRY_RUN` thì preset không được nạp — dừng lại,
kiểm tra đường dẫn `MQL5\Presets` và tên key trong `.set`, không sửa mặc định của EA.

### 4.2 Panel trạng thái trên chart

EA vẽ panel bằng `Comment()` ở góc trên trái chart
([`../../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5:1155`](../../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1155))
để thấy ngay EA còn sống và đang bị chặn bởi đâu, không cần mở CSV. Dạng hiển thị (giá trị đổi theo bar):

```text
PATrendRiderXAUv1DemoEA  DEMO_EXECUTION  magic=25002001
XAUUSDm PERIOD_H1/PERIOD_M15/PERIOD_M5  spread=<pts> pts  atr=<atr>  equity=<equity>
state=<STATE>  regime=<REGIME>  bias=<bias_reason>
bar=<server time bar M5 gần nhất>  block=<lý do chặn>
position=<none|BUY/SELL vol @ entry|sl|tp>  entries=<n>  exits=<n>  dd=<%>  kill=<0|1>
```

- Dòng 1: chế độ (`DRY_RUN`/`DEMO_EXECUTION`) và magic — kiểm nhanh preset có nạp đúng không.
- Dòng 3–4 lặp lại `state`, `regime`, `bias` và lý do chặn của bar vừa đóng. `block` nhận `none`,
  `ENTRY_BLOCKED|reason=…` (từ signal engine), `position_open`, hoặc `state|<STATE>` khi state machine
  từ chối vào lệnh.
- **`bar=` là bằng chứng sống**: panel cập nhật trong `AnalyseClosedBar`, tức mỗi lần đóng bar của
  `InpEntryTF` (M5), không phải mỗi tick. CSV có thể đứng yên nhiều bar do dedup (`REGIME` chỉ ghi khi
  regime đổi, `ENTRY_BLOCKED` chỉ ghi khi lý do đổi — §6), nhưng `bar=` vẫn nhảy. Ngay sau `OnInit`
  panel hiện `bias=waiting_first_bar` cho tới bar đầu tiên.
- Panel chỉ để hiển thị: `Comment()` không gửi lệnh, không đọc/ghi file, và `OnDeinit` xoá panel bằng
  `Comment("")` nên khi gỡ EA panel biến mất. EA dùng `Comment()` chứ không tạo chart object, nên không
  để lại object rác trong chart profile.
- `Comment()` luôn bắt đầu ở góc trên trái vùng chart và **bỏ các dòng trống đầu chuỗi** (đã thử thêm
  ba `\n`: panel không dịch xuống), nên dòng đầu của panel nằm đè lên nhãn `XAUUSDm,M5` do terminal vẽ
  cùng góc. Chấp nhận đánh đổi này thay vì tạo chart object; phần chữ của panel vẫn đọc được.

### 4.3 Chạy Grid và DCA demo (ADR 0004)

Hai bot này không có panel trên chart; bằng chứng nằm ở CSV + journal. Trình tự khuyến nghị cho mỗi bot:

1. **Transform** đúng chart: `XAUUSDm`. Grid/DCA quyết định theo bar của chart (`Period()`), nên M15 là
   cấu hình preset; đổi timeframe là đổi cấu hình và đổi `config_hash`.
2. Kiểm tra Algo Trading đã bật và preset đã nạp: preset mặc định `InpEnableExecution=true` (ADR 0006);
   `InpMagicNumber`
   khác nhau giữa Grid (`25004001`), DCA (`25005001`) và TrendRider (`25002001`).
3. **(Tuỳ chọn) Dry-run một phiên**: đặt `InpEnableExecution=false`, xem journal
   `LAB|INFO|grid_demo|initialized` (hoặc `dca_demo`) và các dòng `DRY_RUN|would_open|…` trong CSV. Nếu
   không thấy `would_open` thì chưa có setup, không phải lỗi.
4. **Phiên enabled là mặc định** (ADR 0006): với `InpEnableExecution=true`, journal phải in
   `initialized|mode=DEMO_EXECUTION|hash=<config_hash>|execution_enabled=1`. Lệnh thật được gửi
   qua `ExecBroker`; mỗi `ENTRY` trong CSV kèm `retcode=done`.
5. Kiểm tra sau khi có lệnh: `sl` và `tp` khác 0 trên **mọi** chân; `entry` của giỏ = bình quân có trọng
   số; `EXIT` có `legs`, `closed`, `pnl` và `consecutive_losses`.
6. Dừng: tạo file kill switch tương ứng trong `MQL5\Files`, hoặc gỡ EA. Kill switch đóng giỏ ngay
   (`CloseBasket("KILL_SWITCH")`) và chốt tới khi khởi động lại.

Giới hạn cần theo dõi khi chạy thật:

| Triệu chứng trong CSV/journal | Nghĩa | Xử lý |
|---|---|---|
| `BLOCKED|plan|max_grid_levels_reached` / `max_dca_adds_reached` | Đã chạm trần tầng/add | Bình thường; giỏ chờ SL/TP |
| `BLOCKED|basket_loss_budget|loss=…|budget=…` | Lệnh thêm sẽ vượt `InpMaxBasketLossPct` | Bình thường; là rào chắn rủi ro |
| `BLOCKED|risk|max_virtual_exposure_reached` | Đã chạm `InpMaxExposure` | Bình thường |
| `BLOCKED|volume_below_broker_minimum` | Volume sau khi normalize < lot tối thiểu | Tăng `InpBaseVolume` |
| `stops_invalid_against_broker_level` | Khoảng cách SL/TP < stop level của broker | Tăng `InpBasketStopPoints`/`InpBasketTargetPoints` |
| `HALT|halt_reason=daily_loss_limit_reached` / `max_drawdown_reached` | Chạm trần equity | EA đã đóng giỏ; chỉ chạy lại sau khi khởi động lại |
| `ERROR|…|order_failed|rejected|…` | Broker từ chối | Đọc `retcode` trong token, kiểm tra symbol/margin |

### 4.4 Chạy InfiniteRunner demo (ADR 0005)

Runner quyết định theo **nến đã đóng** với mô hình ba khung `InpH1TF` (bối cảnh H1) →
`InpM15TF` (cấu trúc M15) → `InpEntryTF` (vào lệnh M5), hoặc chế độ đối chiếu
`InpDirectionMode=0` (EMA parity kiểu V1). Preset mặc định: `InpDirectionMode=1`,
`InpEntryTF=M5`, SL cố định 5000 điểm (≈ $5.00 cỡ lot 0.01 theo contract Exness XAUUSDm),
TP an toàn xa 100000 điểm, trail cố định 2500 điểm sau khi lợi nhuận vượt `InpTrailStartPts=3000`.

1. **Transform đúng chart**: `XAUUSDm`, khung chart đề nghị **M5** (khớp `InpEntryTF`; logic
   đọc tự ba khung input, không phụ thuộc khung chart).
2. **(Tuỳ chọn) Dry-run một phiên** với `InpEnableExecution=false` (preset mặc định là `true` —
   ADR 0006): xem dòng `INIT` trong `infinite_runner_demo.csv` (mode/symbols/magic/safety_tp) và các dòng
   `DECISION|…` mỗi bar M5 đã đóng.
3. **Chẩn đoán `NO_TRADE` đúng cách** — dry-run không vào lệnh là bình thường, đọc lý_do trong
   `DECISION|…|NO_TRADE` / `BLOCKED|…`:

| Reason trong CSV `DECISION`/`BLOCKED` | Nghĩa | Ghi chú điều chỉnh |
|---|---|---|
| `direction_ambiguous` / `bias_unknown` | H1/M15 chưa cùng hướng — bộ lọc chọn lọc của mô hình MTF | Đặc trưng chiến lược; tần suất NO_TRADE cao là kỳ vọng, không phải lỗi |
| `cooldown_active` / `min_bars` / `max_trades_per_day` | Khoảng cách vào lệnh | Tăng `InpCooldownMinutes`/`InpMaxTradesPerDay` nếu dẫn chứng hợp lệ |
| `spread_blocked` | Spread vượt `InpMaxSpreadPoints=600` (kiểm luôn `InpMaxSpreadAtrRatio` nếu >0) | Mặc định 600 đã mở rộng; Exness XAUUSDm thường ~150–300 pts — nếu vẫn chặn, đọc `spread=` trong CSV |
| `atr_abnormal` | ATR vượt `InpAbnormalAtrRatio` × baseline | Bộ lọc biến động; giữ nguyên trừ khi hiểu rõ |
| `risk_locked:daily_loss` / `max_drawdown` / `consecutive_losses` | Khoá rủi ro đã chạm trần | Khối bảo hiểm — không nới để "cho có lệnh" |
| `kill_switch_active` | File kill switch còn tồn tại | Xoá file theo §5.1 |
| `timeframe_order_invalid` (OnInit) | `InpH1TF ≤ InpM15TF ≤ InpEntryTF` | Sắp lại H1 > M15 > M5 |

4. **Phiên enabled là mặc định** (ADR 0006): với `InpEnableExecution=true` (preset mặc định),
   journal phải in `INIT|mode=DEMO_EXECUTION` với `config_hash` riêng. Lệnh thật được gửi
   qua `ExecBroker`; mỗi `ENTRY` kèm `sl` (trong band) + `tp` xa bắt buộc, `retcode=done`.
5. Kiểm tra sau khi có lệnh: **đúng một** vị thế theo magic `25006001`; mọi lệnh có `sl≠0` và
   `tp≠0`; dòng `TRAIL` chỉ được **thắt chặt** (SL BUY chỉ tăng, SELL chỉ giảm — trail đơn điệu
   từ R ban đầu, không tính lại); `EXIT` có `pnl` và `consecutive_losses`.
6. Dừng: tạo `MQL5\Files\INFINITE_RUNNER_DEMO_STOP.txt` (nội dung bất kỳ) hoặc gỡ EA. Kill switch
   đóng runner ngay và chốt tới khi khởi động lại; State file `infinite_runner_demo_state.csv`
   giữ `dd_locked`/ledger qua các lần nạp (reset dùng `InpResetStateOnInit=true` rồi phải trả
   về `false`, cùng mẹo §5.1).

**Backtest bằng Strategy Tester**: hai tệp đã sinh sẵn —
`reports\build\tester-sets\infinite_runner_demo_exec.set` (copy vào `MQL5\Profiles\Tester\`)
và `reports\build\tester-run\infinite_runner_demo_exec.ini`.
`.set` này bật `InpEnableExecution=true` với `InpLogFile=sim_ir_demo_exec.csv`; preset JSON
cũng mặc định `true` (ADR 0006) nên demo chạy tay không cần thao tác gì thêm.

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
| `INIT` | Chế độ (`DRY_RUN`/`DEMO_EXECUTION`), `state`, `restored`, symbol, magic, TP R, `config_hash`, `mql_trade_allowed` |
| `REGIME` | Chỉ ghi khi regime đổi: `regime`, `bias`, `h1`, `m15`, `vol`, `spread_block`, `risk_lock` |
| `RISK` | `side`, `price`, `atr` khi vào lệnh; `ENTRY_BLOCKED\|reason=…` khi bị chặn (chỉ ghi khi reason đổi) |
| `BOS` | Break-of-structure trên `M5`/`M15` |
| `ENTRY` | Lệnh khớp: `ORDER_FILLED\|order=N\|deal=N\|ok\|done`, entry/SL/TP, `risk_money` |
| `DRY_RUN` | Tín hiệu hợp lệ nhưng `InpEnableExecution=false` — không gửi lệnh |
| `TRAIL` | Dời SL (break-even + trailing); chỉ được siết, không được nới |
| `EXIT` | Đóng vị thế kèm P&L và lý do (`broker_close`, `reversal_*`, `kill_switch`) |
| `CLOSE_REQUEST` | EA chủ động gửi lệnh đóng (kèm `deal=N\|ok\|done`) |
| `STATE` | `to=…\|reason=…\|transitions=N` |
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

### 6.2 Giám sát journal và báo `ENTRY` thật — `watch_demo_journal.py`

Goal còn lại là bắt được **`ENTRY` do chính DemoEA gửi**. `scripts\watch_demo_journal.py` đọc file
`MQL5\Files\pa_trendrider_demo.csv`, ghi nhớ checkpoint byte và chỉ in các dòng mới. Nó **chỉ đọc**: không
mở MT5, không gọi trading API, không ghi vào `MQL5\Files`; checkpoint nằm ở `reports\demo-watch\`.

```powershell
.venv\Scripts\python.exe scripts\watch_demo_journal.py            # tail: chỉ in dòng mới từ lần chạy trước
.venv\Scripts\python.exe scripts\watch_demo_journal.py --reset --from-start   # quét toàn bộ lịch sử
.venv\Scripts\python.exe scripts\watch_demo_journal.py --watch --interval 60 --timeout 3600 --stop-on-alert
```

| Cờ | Ý nghĩa |
|---|---|
| `--csv` | Đường dẫn CSV tường minh (mặc định tự tìm mọi `...\Terminal\*\MQL5\Files\pa_trendrider_demo.csv`; có 2 file là nó **dừng** và yêu cầu `--csv`, không đoán) |
| `--from-start` / `--reset` | Lần đầu đọc từ đầu file / xóa checkpoint trước |
| `--watch --interval N` | Poll mỗi N giây |
| `--timeout N` | Dừng sau N giây; `--stop-on-alert` dừng ngay khi có lệnh/lỗi |
| `--quiet` | Chỉ in dòng alert |

Event báo alert: `ENTRY`, `EXIT`, `TRAIL`, `CLOSE_REQUEST`, `ADOPT`, `SYNC` (nhóm `ORDER`) và `KILL`,
`ERROR`, `STATE_ERROR`, `RESET` (nhóm `FAULT`). `RISK|ENTRY_BLOCKED`, `BOS`, `REGIME`, `INIT`, `STATE`,
`SUMMARY` chỉ vào tổng hợp, không phải alert.

Exit code: `0` không alert, `1` có alert (dùng cho cron/thông báo), `2` không tìm thấy journal hoặc schema
không đủ 18 cột. Ngoài ra watcher in `WATCH|FAULT|kill_switch_file_present` nếu
`PA_TREND_RIDER_DEMO_STOP.txt` còn tồn tại, và `WATCH|NOTE|journal_stale` nếu file không được ghi hơn 2 giờ.

Kết quả chạy thật ngày 2026-10-29 trên demo `464140826` (bốn bar mới từ checkpoint, chưa có `ENTRY`):

```
WATCH|RISK|2026.10.29 06:25:00|2026.10.29 06:20:00|ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE|state=WAITING_FOR_SETUP|spread_points=240.0|atr=4.36707143
WATCH|SUMMARY|events=4|RISK=4
WATCH|BLOCKED|reason=bias_unknown=4
```

`--watch --interval 60 --timeout 12` dừng đúng sau 12 giây và bắt được bar `06:45:00` vừa ghi.

Lưu ý:

- Timestamp trong journal là **giờ server (UTC)**; giờ local cộng thêm 7 giờ.
- Watcher không làm cho EA dễ vào lệnh hơn. `reason=bias_unknown` / `regime_range` là bộ lọc của chiến
  lược; khi nào regime chuyển `TREND` và bias xác định thì `ENTRY` mới xuất hiện.
- Alert `ENTRY` cần được đối soát với tab **History** trước khi ghi nhận là bằng chứng — cùng nguyên tắc
  với §6.1.

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
| `LAB\|ERROR\|trendrider_demo\|state_write_failed` | State file không ghi được (read-only / đĩa đầy) | EA vẫn chạy và chỉ mất persist; bỏ read-only hoặc kiểm tra đĩa, vì lần nạp lại sau sẽ khởi động sạch |

## 9. Gỡ bỏ / quay lại mô phỏng

- Gỡ EA demo khỏi chart, xoá state/log demo nếu muốn replay sạch.
- EA mô phỏng (`PATrendRiderXAUv1SimEA`) không thay đổi và vẫn là đường chạy offline/Strategy Tester.
- Mọi thay đổi cho phép tài khoản real phải có ADR mới được chủ dự án chấp thuận trước khi viết code.
