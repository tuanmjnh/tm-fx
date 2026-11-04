# Xử lý sự cố — bot "im re" và "0 trade"

Mọi kết luận về sự cố phải kèm **reason code** và **dòng log** trích ra được. Tài liệu này chưng cất từ
bộ V2 (`TROUBLESHOOTING.md`) và V3 (`ZERO_TRADE_DIAGNOSTICS.md`, `NO_TRADE_DIAGNOSIS_TEMPLATE.md`) —
bản gốc chỉ đọc nằm trong `99-archive/`; các sự cố 2026-10-30 / 2026-11-03 có nguồn là
[`../PROGRESS.md`](../PROGRESS.md) §66–§69.

Đối tượng đọc: người vận hành bot demo và agent chạy tester headless. Mục tiêu: xác định đúng
**giai đoạn nào trong pipeline** chặn, không phải tìm cách cho bot vào lệnh.

## 1. Nguyên tắc

- **Không nới gate** để "cho có lệnh": không sửa ngưỡng spread/ATR/bias, không hạ SL/TP, không tắt
  guard, không đổi logic để qua checklist.
- **Không đổi input mặc định** để tạo giao dịch. `InpEnableExecution=false` là dry-run có chủ đích
  (ADR 0006), không phải lỗi; ngược lại cũng không tự bật cờ để ép bot vào lệnh.
- Mọi kết luận phải kèm reason code và dòng log. "Chạy được trên máy tôi" không phải bằng chứng;
  chuẩn bằng chứng xem [evidence.md](evidence.md).
- 0 trade **thường không phải lỗi**: bộ lọc (bias/regime/spread) chặn entry là hành vi đúng thiết kế.
  Số liệu thật V2: `bias_unknown` 47.71%, `reversal_watch` 29.56%, `regime_range` 13.21%,
  `bos_against_bias` 3.86%, entry hợp lệ 2.88% — phần lớn thời gian bot đứng ngoài lệnh là bình thường.
- Guard fail-closed là đúng: khi không chắc (không phải demo/tester, trade bị tắt, state không đọc
  được), EA từ chối chạy. Việc của chẩn đoán là hiểu guard vì sao từ chối, không phải bỏ lệnh kiểm.
- Không credential vào file/log/chat; không tự bật Algo Trading hộ người dùng; không sửa vị thế tay
  trên terminal rồi coi đó là kết quả của EA.

## 2. Pipeline 10 bước khi 0 trade

Cây quyết định này chép nguyên thứ tự từ `ZERO_TRADE_DIAGNOSTICS.md` §5 (V3). Đi từ trên xuống; bước
đầu tiên trả lời "không" chính là nơi chặn. Không được trả lời gộp bằng một câu "không có tín hiệu".

1. `OnInit` successful? If not, inspect first fatal config/dependency/handle error.
2. `OnTick` counter increasing? If not, wrong tester symbol/period/test date or EA not receiving ticks.
3. History ready? Inspect `BarsCalculated`, `CopyRates`, `CopyBuffer`, synchronization and warm-up progress.
4. Direction produces LONG/SHORT at least once? If no, run indicator/bias unit tests and check timeframe/shift/indexing.
5. Entry setup appears? If no, inspect pullback/retest/candle logic and signal bar timestamps.
6. Filters pass? If no, disable one optional filter at a time in `diagnostic_loose` and record the difference.
7. Sizing passes? Inspect risk budget vs symbol minimum volume; do not silently round up.
8. Margin and order precheck pass? Inspect margin mode, filling, stop level, tick size, volume step.
9. Request sent? If yes, inspect actual retcode/result and reconcile deal/position.
10. If request never sent, log exact preceding stage; no broad "no trade" explanation.

### Stage và reason code

Mỗi stage có counter và nhóm reason code riêng. Bảng rút gọn từ `ZERO_TRADE_DIAGNOSTICS.md` §2:

| Stage | Counter | Reason code ví dụ |
|---|---|---|
| Runtime | `run_mode_ok` / `run_mode_blocked` | `TESTER_MODE`, `DEMO_MODE`, `ACCOUNT_NOT_DEMO`, `TRADE_NOT_ALLOWED` |
| Data readiness | `data_ready` / `data_wait` | `HISTORY_NOT_SYNCED`, `BARS_INSUFFICIENT`, `COPYRATES_SHORT`, `COPYBUFFER_SHORT` |
| Bar clock | `bars_seen` / `bars_processed` | `NO_NEW_BAR`, `BAR_TIME_INVALID` |
| Direction | `buy_bias` / `sell_bias` / `neutral` | `H1_BEAR`, `MTF_CONFLICT`, `EMA_NOT_ALIGNED`, `PA_STRUCTURE_UNKNOWN` |
| Setup | `setup_buy` / `setup_sell` / `setup_none` | `NO_PULLBACK`, `NO_RETEST`, `CANDLE_NOT_CONFIRMED`, `SETUP_EXPIRED` |
| Filter | đếm theo từng filter | `SPREAD_FILTER`, `SESSION_FILTER`, `ATR_FILTER`, `COOLDOWN`, `MAX_TRADES_DAY` |
| Risk sizing | `sizing_pass` / `sizing_block` | `MIN_LOT_OVER_BUDGET`, `INVALID_TICK_VALUE`, `INVALID_STOP_DISTANCE`, `MAX_LOTS_CAP` |
| Margin | `margin_pass` / `margin_block` | `ORDER_CALC_MARGIN_FAILED`, `INSUFFICIENT_MARGIN` |
| Request precheck | `ordercheck_pass` / `ordercheck_block` | `INVALID_FILLING`, `INVALID_STOPS`, `SYMBOL_CLOSE_ONLY`, `VOLUME_STEP_INVALID` |
| Send result | `request_sent` / `request_rejected` | retcode thật của server + mô tả |
| Confirmation | `deal_confirmed` / `position_confirmed` | `NO_DEAL_AFTER_REQUEST`, `POSITION_RECONCILE_MISMATCH` |

Kết luận phải ghi đúng stage + reason, ví dụ `filter|reason=bias_unknown` — không ghi chung chung
"bot không chạy". Nếu lệnh đã gửi nhưng bị broker từ chối, retcode thật (`invalid stops`,
`invalid volume`, `no money`, …) là bằng chứng: sửa phía EA/test (sizing, stop distance, risk budget),
không sửa tay trên terminal.

### Đọc log ở đâu

- Journal của EA demo thật: `MQL5\Files\<InpLogFile>` trong Data Folder của terminal (UTF-16LE — mở
  bằng editor hỗ trợ UTF-16, hoặc chuyển encoding trước khi grep).
- Log terminal: `MQL5\Logs\<yyyymmdd>.log` (UTF-16LE).
- Tester chạy trong sandbox riêng: `%APPDATA%\MetaQuotes\Tester\<hash>\Agent-127.0.0.1-3000\MQL5\Files`
  chứa CSV mà EA ghi; mỗi lần chạy có thể tạo thư mục agent mới — đừng chỉ nhìn `Tester\logs`.
- Report `.htm`/`.png` của tester nằm ở thư mục gốc Data Folder; `run_tester.ps1` tự gom vào
  `reports/build/tester-reports/<scenario>/`.

## 3. Bảy nguyên nhân đã gặp thật

Bảng cột yêu cầu: triệu chứng | cách xác nhận | cách sửa | nguồn. Cả bảy đều gặp thật trong repo,
không có dòng nào là suy đoán.

| # | Nguyên nhân | Triệu chứng | Xác nhận | Cách sửa | Nguồn |
|---|---|---|---|---|---|
| 1 | Dry-run: `InpEnableExecution=false` | Không có lệnh nào, không có block risk | Journal **không có dòng `ENTRY`**, panel ghi `DRY_RUN` | Nếu đây là phiên đối chiếu có chủ đích thì giữ nguyên; nếu muốn chạy thật, đặt `true` ở preset/chart (ghi quyết định) | ADR 0006; PROGRESS §66.4 |
| 2 | File kill switch còn tồn tại | EA mở vào `ERROR_SAFE_MODE`, không vào lệnh | Log `HALT\|reason=kill_switch` | Đóng EA, xoá file `<BOT>_DEMO_STOP.txt` trong `MQL5\Files\`, khởi động lại | `../90-decisions/0004-all-bots-demo-execution.md`; PROGRESS §44.4 |
| 3 | Halt phục hồi từ state file (`restored=1`) | EA chạy nhưng đã `HALTED` ngay từ đầu phiên | Dòng `INIT` có `restored=1` và `state=HALTED` | Xoá/reset state file `*_state.csv` trong `MQL5\Files\` trước phiên sạch (`InpResetStateOnInit`) | PROGRESS §69.4 |
| 4 | Filter chặn entry (spread/bias/regime/ATR) | Không ENTRY nhưng có dòng `RISK` | Log `RISK ENTRY_BLOCKED\|reason=...` (ví dụ `bias_unknown`, `regime_range`) | **Không sửa.** Đây là kết quả đúng của bộ lọc; ghi reason code và chờ cấu trúc thị trường | PROGRESS §52.4 |
| 5 | Tester headless: `MQL_TESTER=0` → `context_denied\|reason=terminal_trade_disabled` | Tester headless khởi động xong nhưng không có report, không lệnh | Journal ghi `LAB\|ERROR\|...\|context_denied\|reason=terminal_trade_disabled` → `INIT_FAILED` | Đã sửa 2026-10-30: EA demo nhận diện tester thêm bằng tên tài khoản `"Strategy Tester"` (guard không đổi). Dùng bản build ≥ fix đó | PROGRESS §68.1 |
| 6 | EA nhận vị thế lạc cùng magic → `InpMaxPositions` đầy | EA có setup hợp lệ nhưng không vào lệnh, không có block rõ | `ExecFindOwnPosition` thấy position, `g_have_pos=true` ngay sau init | Chưa có fix xác nhận: dọn vị thế lạc trên terminal, xoá state file, **chạy lại để lấy bằng chứng** | Chẩn đoán 2026-11-03 (**chưa chạy lại**, `NOT_RUN`) |
| 7 | `.set` không copy vào `MQL5\Profiles\Tester\` → tester dùng input mặc định | Tester chạy xong nhưng kết quả lệch hẳn kỳ vọng | Journal ghi **tên log mặc định** (ví dụ `wonderwhales_demo.csv` thay vì `sim_ww_demo_exec.csv`), `config_hash` khác lần chạy trước | Copy `.set` vào `MQL5\Profiles\Tester\` trước khi chạy; xoá CSV cũ trong sandbox agent để không đọc nhầm output cũ | PROGRESS §69.4 |

Ghi chú nguyên nhân #6: đây mới là **giả thuyết có quan sát đi kèm** — EA thấy position cùng magic
nên `InpMaxPositions=1` coi slot đã đầy. Việc đóng vị thế lạc trên chart demo, xoá state file
`infinite_runner_demo_state.csv` và chạy lại tester **chưa thực hiện**, nên nguyên nhân này vẫn ở
trạng thái `NOT_RUN`. Không viết nó thành "đã xác nhận" cho tới khi có lần chạy lại.

Ghi chú nguyên nhân #1 và #4: cả hai là **kết quả đúng**, không phải sự cố. Dry-run 0 trade là mục
đích của chế độ; filter block là điều kiện thiết kế. Chỉ khi cùng lúc (a) chế độ chạy đúng, (b) preset
đã nạp, (c) không có block nào mà vẫn không ENTRY thì mới nghi nguyên nhân khác (6, hoặc stage dữ liệu
ở mục 2).

### Các lớp sự cố khác đã gặp thật (rút gọn từ V2)

Chưa đầy đủ như bảy nguyên nhân chính, nhưng từng xảy ra và có cách xử lý:

- **MetaEditor trả exit code 1 dù compile thành công** — đọc dòng cuối log: `Result: 0 errors,
  0 warnings` và có `.ex5` là thành công; exit code 1 không phải lỗi.
- **EA compile vào Data Folder khác terminal đang chạy** — so `<Data Folder>` (File → Open Data
  Folder) với thư mục đã copy; sai chỗ thì EA không xuất hiện trong Navigator. Refresh Navigator.
- **`invalid stops` / `invalid volume` / `no money` từ broker** — `ExecStopsRespectBroker` và
  `ExecNormalizeVolume` phải chặn trước khi gửi; nếu vẫn lọt thì đó là bug cần test mới, không phải
  việc nới stop hay tăng đòn bẩy.
- **DCA báo `adds=0` dù có add** — đã sửa 2026-10-29: `g_total_adds` cộng dồn, SUMMARY có
  `adds=` (tổng) và `basket_adds=` (basket hiện tại). CSV cũ ghi `adds=0` là bằng chứng lịch sử,
  không sửa lại.
- **Journal có `state=state=...`** — đã sửa 2026-10-29; file state cũ vẫn đọc được (parser lấy phần
  sau dấu `=` đầu tiên).
- **MT5 chỉ chạy một instance** — nếu terminal demo đang mở, `terminal64.exe /config:...` không mở
  thêm tester; đóng terminal trước hoặc dùng bản cài riêng cho tester.
- **Sai phiên bản MT5** — kiểm
  `(Get-Item "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe").VersionInfo.FileVersion`;
  build đang dùng là 6292 (tài liệu cũ ghi 6249 là số cũ).

## 4. Checklist trước khi kết luận "0 trade"

Không kết luận "0 trade đúng/không đúng" khi thiếu một trong sáu dòng dưới đây; mỗi dòng yêu cầu một
bằng chứng cụ thể (file log/CSV thật, đúng đường dẫn trong `reports/build/`):

1. **Dòng `INIT`** — kèm `config_hash`, `restored=`, `mql_trade_allowed=`; xác nhận EA nạp đúng preset
   và đúng quyền giao dịch. `config_hash` khác lần chạy trước là dấu hiệu nguyên nhân #7.
2. **Bằng chứng preset đã nạp** — tên log trong journal khớp `InpLogFile` của preset (không phải tên
   mặc định của EA), và `.set` đã nằm trong `MQL5\Profiles\Tester\`.
3. **Số tick/bar đã xử lý** — `Bars:` và `Ticks:` trong report `.htm` khớp kỳ test đã chọn; nếu khác,
   dữ liệu/history chưa sẵn sàng (stage 3 của pipeline).
4. **Đếm block theo reason** — tách các dòng `RISK ENTRY_BLOCKED|reason=...` trong CSV; ghi % của từng
   reason thay vì gộp thành "bị chặn".
5. **Xác nhận chế độ chạy** — panel/journal ghi `DRY_RUN` hay `DEMO_EXECUTION`; dry-run 0 trade không
   phải sự cố.
6. **Report thật của đúng lần chạy này** — file `.htm` + `.csv` trong `reports/build/tester-reports/<scenario>/`;
   không trích output cũ của scenario khác (tester agent tạo thư mục riêng mỗi lần chạy).

### Mẫu ghi nhận chẩn đoán (từ `NO_TRADE_DIAGNOSIS_TEMPLATE.md`)

Điền mẫu này cho mỗi lần chẩn đoán 0 trade; thiếu ô nào thì chẩn đoán chưa hoàn tất:

```text
EA/version:                Source commit/hash:
Symbol/TF/date range:      Tester model:
Preset/config hash:        Runtime mode:
Init state:                Total ticks:
Bars processed:            Data ready / not ready:
BUY signals / SELL signals / FLAT:
Setup candidates:          Filter pass/block counts:
Risk/sizing blocks:        Margin/order-check blocks:
Requests sent/accepted/rejected:
Deals/positions confirmed:
First blocking stage:      First blocking reason:
Evidence/log path:         Corrective test (one filter changed at a time):
```

## 5. Regression test bắt buộc

Mỗi nguyên nhân ở mục 3 phải có một test/kiểm tra tạo **đúng một blocker** và assert **đúng reason
code** — không test dàn trải nhiều guard cùng lúc, không assert mơ hồ kiểu "không crash":

| # | Test phải tạo | Assert đúng |
|---|---|---|
| 1 | Preset/chart với `InpEnableExecution=false` | journal `mode=DRY_RUN`, 0 dòng `ENTRY`, 0 lời gọi lệnh |
| 2 | Tạo file `<BOT>_DEMO_STOP.txt` rồi init | `HALT\|reason=kill_switch`, không vào lệnh |
| 3 | State file ghi `state=HALTED` trước init | `INIT` đọc lại `restored=1` + `state=HALTED`, không vào lệnh tới khi reset |
| 4 | Tắt từng optional filter một | đúng counter/reason của filter đó thay đổi, các invariant guard còn nguyên |
| 5 | Chạy tester headless (`MQL_TESTER=0`) | EA đi qua guard: journal `mode=DEMO_EXECUTION` thay vì `INIT_FAILED` |
| 6 | Chèn position cùng magic trước init | `g_have_pos=true`, log ghi rõ lý do từ chối entry — **chưa có**, làm khi xác nhận chẩn đoán |
| 7 | Chạy tester thiếu `.set` trong `MQL5\Profiles\Tester\` | journal dùng tên log mặc định / `config_hash` lệch — phát hiện sớm, chưa tự động hoá |

Quy tắc thêm test:

- Một test mà blocker nhiều hơn một hoặc reason code sai thì **test sai**, không phải EA sai.
- Tắt một optional filter chỉ được thay đổi counter của filter đó; không được vì vậy bypass invariant
  khác (SL/TP bắt buộc, cap volume, giới hạn magic).
- Khi sửa code cho một nguyên nhân mới, thêm test của nguyên nhân đó vào **cùng một commit**; không
  sửa hành vi mà không có test khoá lại hành vi mới.
- Bằng chứng của lần sửa là log chạy test thật, lưu theo quy ước ở [evidence.md](evidence.md) — không
  ghi "PASS" mà không có output.
