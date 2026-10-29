# Internal release checklist — MT5 EA & AI Lab

- **Ngày:** 2026-10-29 (bổ sung scope demo execution theo ADR 0003)
- **Phạm vi:** bản nghiên cứu offline (Phase 0–9 + trailing stop + bounded DCA/grid + 5 EA mô phỏng) và
  **demo execution có guardrail** (`PATrendRiderXAUv1DemoEA`). Không phải sản phẩm giao dịch; không có
  execution trên tài khoản real/live.
- **Quy tắc:** không release nếu bất kỳ mục “Bắt buộc” nào chưa đạt. Mục “Thủ công” có thể để mở nhưng
  phải ghi rõ trạng thái trong báo cáo.

> **Lưu ý (2026-10-29):** các con số trong checklist này là lần đóng gói **0.10.0** — 30 source `.mq5`
> compile 0/0, `validate-project.py checks=14`, `validate_sim_configs.py checked=7` (6 preset, 17 scenario),
> `validate_trendrider.py checks=7`, `validate_demo_execution.py checks=8`, pytest 371 passed. Bằng chứng
> chi tiết và nhật ký phiên demo thật nằm ở [`../PROGRESS.md`](../PROGRESS.md) §42–§43; **bằng chứng đường
> `OrderSend` trong Strategy Tester, kill switch bằng file thật và quy trình reset safe mode nằm ở §44;
> bằng chứng máy chủ demo thật khớp lệnh qua `ExecDemoProbe` nằm ở §45; automation giám sát journal demo
> (`watch_demo_journal.py`) nằm ở §46**.
> Chiến lược `WonderwhalesSimEA` và 12 scenario Strategy Tester cũ vẫn giữ nguyên kết quả.

## 1. Bắt buộc

| # | Kiểm tra | Cách xác minh | Trạng thái |
|---|---|---|---|
| 1 | Test Python xanh | `.\.venv\Scripts\python.exe -m pytest -q` | Đạt: 371 passed |
| 2 | Không lỗi cú pháp | `python -m compileall -q python/src python/tests scripts` | Đạt: exit 0 |
| 3 | Dependency nhất quán | `python -m pip check` | Đạt: no broken requirements |
| 4 | Execution chỉ trong scope demo | `validate-project.py` + `validate_demo_execution.py`: trading API chỉ nằm trong `mt5/Include/Exec/*`, `PATrendRiderXAUv1DemoEA`, `ExecGuardTests.mq5` và `ExecDemoProbe.mq5` | Đạt: 0 API ngoài scope; guard test compile 0/0 |
| 5 | Không có secret/credential | Không có `.env`, token, password, `accounts.dat`, `servers.dat` trong repo | Đạt: kiểm tra thủ công |
| 6 | Không kết nối broker | Không có login/`WebRequest`/socket; `AccountInfo*` chỉ đọc trade-mode trong guard demo | Đạt: mã nguồn |
| 7 | Pipeline end-to-end chạy được | `scripts\run_pipeline.py --config configs\pipeline.example.yaml` | Đạt: exit 0, báo cáo demo |
| 8 | Fail-safe dữ liệu/model | Test pipeline + ONNX missing model | Đạt: exit 1/2/4, không ghi đè |
| 9 | Kết quả gắn nhãn demo/synthetic | `pipeline_report.md` có mục Demo + Limitations | Đạt |
| 10 | Tài liệu giới hạn rõ | `docs/reference/risk.md`, `docs/reference/pipeline.md` | Đạt |
| 11 | Artifact không bị commit nhầm | `reports/`, `experiments/`, `models/candidates/`, `.ex5`, `.onnx` gitignored | Đạt |
| 12 | Không quảng bá hiệu năng | Không có claim lợi nhuận/live trong README/docs | Đạt |
| 13 | Bounded DCA/grid chạy và cap quan sát được | `scripts\run_basket_backtest.py` với hai config mẫu | Đạt: exit 0; DCA 57 basket/cap layer 4, grid loss cap 20 với `loss_cap_overshoot` 0 |
| 14 | Ranh giới execution được ghi nhận | `docs/decisions/0003-demo-execution-scope.md`, `docs/guides/demo-execution.md`, README, AGENTS.md | Đạt: ADR Accepted; guide nêu demo-only, dry-run, kill switch, 0 trade là đúng |
| 15 | Không có credential/account ID trong docs/log | Review `git diff` và log MT5 trước commit | Đạt: log compile không chứa account/server |
| 16 | Preset Track C fail-closed | `scripts\validate_sim_configs.py` | Đạt: checked=7 fail=0 (6 preset, 17 scenario); snapshot bất biến |
| 16b | Preset demo fail-closed | `scripts\validate_demo_execution.py` | Đạt: checks=8 fail=0; DEMO_ONLY, `InpEnableExecution=false`, TP bắt buộc, magic tách khỏi bản mô phỏng; check `demo order probe` buộc `ExecDemoProbe` giữ `InpConfirm=false`, gọi lệnh qua `ExecBroker` chứ không `OrderSend`, từ chối tester và đọc `MQL_TRADE_ALLOWED` |
| 16c | Guard contract test | Compile + chạy `mt5\Scripts\ExecGuardTests.mq5` | Compile 0/0; **runtime PASS** 2026-10-29 (xem mục 10) |
| 16d | Broker acceptance probe | Compile + chạy `mt5\Scripts\ExecDemoProbe.mq5` trên demo thật | Compile 0/0 (cả trong data folder); **runtime PASS** 2026-10-29 (xem mục 16) |
| 16e | Journal watcher chỉ đọc | `scripts\validate_demo_execution.py` check `demo journal watcher`; `pytest -q python/tests/test_watch_demo_journal.py` | Đạt: 13 test; cấm mọi trading API, `EXPECTED_HEADER` phải bằng `SIM_LOG_HEADER`, alert chỉ trên event DemoEA thật sự phát, checkpoint dưới `reports/` |
| 17 | Build MQL5 toàn bộ | `scripts\build-mql5.ps1` | Đạt: 30 source, 0 errors, 0 warnings (2026-10-29) |
| 18 | Static scan toàn project | `scripts\validate-project.py` | Đạt: checks=14 fail=0; 62 source không có API giao dịch ngoài scope/placeholder |
| 19 | Package source loại artifact | `scripts\package-source.ps1 -Version <x.y.z>` | Đạt: không có `.venv`, `.ex5`, log, report trong zip; manifest SHA256 |

## 2. Thủ công (ghi trạng thái, không chặn bản nghiên cứu)

| # | Kiểm tra | Trạng thái |
|---|---|---|
| 1 | Compile 30 file `.mq5` | Đạt 2026-10-29 bằng `scripts\build-mql5.ps1` với MetaEditor bản Exness: 0 errors/0 warnings; MetaEditor CLI trả exit 1 dù thành công (đọc log, không đọc exit code) |
| 2 | MT5 Strategy Tester cho `LabSignalEA` | Chưa chạy; kỳ vọng 0 trade vì EA signal-only |
| 3 | `LabSignalExport` + parity MQL5/Python | Chưa chạy MQL5 export |
| 4 | `LabOnnxInference` + parity runtime ONNX | Chưa chạy; compile 0/0 |
| 5 | Tái lập sau checkout commit sạch | Đã xác minh snapshot Phase 9 (2026-10-28): 155 test pass, metric/data SHA/model SHA khớp, duplicate exit `4`, ONNX parity PASS. Trailing stop + bounded DCA/grid + Track C (324 test) chưa lặp lại trên commit sạch; chờ commit chính thức |
| 6 | `SimCoreTests` trong MT5 | **PASS** 2026-10-28: `TEST|RESULT|ALL_PASS|pass=123 fail=0|suite=sim_core` (tab Experts, terminal EXNESS chưa đăng nhập) |
| 6b | `SimPlanTests` trong MT5 | **PASS** 2026-10-28: `TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan`; lần chạy đầu phát hiện 8 vector sai đơn vị point và 1 lỗi biên số thực, đã sửa `SimPlanTests.mq5` + `SimPlan.mqh` rồi chạy lại |
| 7 | Strategy Tester cho 4 EA mô phỏng (12 scenario) | **PASS một phần** 2026-10-28: 10/10 scenario runner/grid/DCA có SUMMARY; 2 `plan_*` `BLOCKED_PERFORMANCE` (1 tháng chẩn đoán 197 s, 0 entry) |
| 8 | CSV thật của runner/grid/DCA/plan | Có CSV thật cho 10 scenario (archived, gitignored); DCA `adds=0` là bug reporting, CSV chứng minh 2 add |
| 9 | Contract test 6 indicator trong Strategy Tester | **PASS 6/6** (547 check) 2026-10-28; 3 bug implementation đã sửa |
| 10 | `ExecGuardTests` trong MetaEditor | **PASS** 2026-10-29: `TEST\|BEGIN\|suite=execguard` → `TEST\|G1..G51\|PASS` → `TEST\|RESULT\|ALL_PASS\|pass=51 fail=0\|suite=execguard` (log `MQL5\Logs\20261029.log`, chạy như script trên chart XAUUSDm,M5). Script là synthetic: không gọi `OrderSend`, không đọc thông tin tài khoản — nên PASS này chứng minh **ma trận guard**, không chứng minh đường gửi lệnh thật của `ExecBroker.mqh` |
| 11 | Dry-run `PATrendRiderXAUv1DemoEA` trên demo | **PASS** 2026-10-29 trên demo `464140826` (Exness-MT5Trial17, hedge): `INIT mode=DRY_RUN`, một `RISK ENTRY_BLOCKED reason=bias_unknown`, `SUMMARY entries=0 exits=0 net=0.00`, tab Trade trống. Lưu ý: dry-run không khởi tạo được khi nút Algo Trading của terminal tắt (`scope_rejected|terminal_trade_disabled`) |
| 12 | Demo execution một phiên có giám sát | **PASS (armed, 0 entry)** 2026-10-29: `InpEnableExecution=true`, `INIT mode=DEMO_EXECUTION config_hash=6B439450` trên chart `XAUUSDm,M5`. `OnInit` chỉ thành công khi `ExecContextAllowed` pass (`ACCOUNT_TRADE_MODE_DEMO` + `ACCOUNT_TRADE_ALLOWED` + `TERMINAL_TRADE_ALLOWED`) rồi `ExecSymbolAllowed`/`ExecSymbolTradable` pass — nên INIT là bằng chứng tài khoản demo và quyền giao dịch đang mở. EA ghi `BOS tf=M5 event=BOS_BEAR` rồi `RISK ENTRY_BLOCKED reason=bias_unknown\|regime=RANGE` mỗi bar M5 đóng: **sống, chặn đúng luật, chưa có `ENTRY`**. Không suy diễn gì từ 0 entry |
| 13 | Đường gửi lệnh `ExecBroker.mqh` có bằng chứng runtime | **PASS (Strategy Tester)** 2026-10-29: 31 `ENTRY` đều `ORDER_FILLED\|order=N\|deal=N\|ok\|done`, 34 `TRAIL`, 31 `EXIT` (30 `broker_close` + 1 `CLOSE_REQUEST\|deal=61`), `SUMMARY entries=31 exits=31 wins=11 losses=20 net=53.72 drawdown_pct=0.6530`, 61 189 dòng journal, đối soát khớp tab Backtest (`Total Trades 31`/`Total Deals 62`) và tab Journal (`final balance 5053.72 USD`). Xem §44 |
| 14 | Audit tĩnh CSV của phiên execution | **PASS** `python audit_exec_csv.py pa_trendrider_demo.csv` → `PROBLEMS=0` (SL/TP đúng phía, TP = entry ± 3·risk trong 0.01, một vị thế, `TRAIL` chỉ siết SL, `config_hash` không đổi, ENTRY phải mang `ORDER_FILLED`) |
| 15 | Kill switch bằng file thật | **PASS** 2026-10-29 trên demo thật: tạo `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt` → trong 16 s journal ghi `KILL kill_switch_file\|entries_disabled` + `STATE to=ERROR_SAFE_MODE\|reason=kill_switch`. Phát hiện quan trọng: **xoá file là chưa đủ** — `OnDeinit` ghi `ERROR_SAFE_MODE` vào state file trước khi `OnInit` đọc lại; quy trình reset ở `guides/demo-execution.md` §5.1, đã xác nhận khôi phục về `state=WAITING_FOR_SETUP` |
| 16 | Broker demo thật chấp nhận lệnh | **PASS** 2026-10-29 qua `mt5\Scripts\ExecDemoProbe.mq5` trên demo `464140826`, chart `XAUUSDm,M5`: lần `InpConfirm=false` ghi `PROBE\|DRY\|all_guards_pass\|no_order_sent`; lần `InpConfirm=true` ghi `PROBE\|OPEN\|order=2762481907\|deal=2468899165\|price=4045.79\|sl=4042.79\|tp=4048.79\|ok\|done` → `PROBE\|CLOSE\|deal=2468899168\|price=4045.55` → `PROBE\|DONE\|deals=2\|pnl=-0.24\|balance=4999.76`. Đối soát ba nguồn (log script, tab Trade, tab History của server) khớp; −0.24 = đúng spread 240 points trên 0.01 lot. Probe từ chối chạy trong tester và đòi `MQL_TRADE_ALLOWED`, nên đây là bằng chứng **server**, không phải bằng chứng mã. Xem §45 |
| 16a | DemoEA có `ENTRY` thật trên demo | **CHƯA XẢY RA** — phiên `mode=DEMO_EXECUTION` vẫn `ENTRY_BLOCKED reason=bias_unknown\|regime_range`; 0 entry là kết quả hợp lệ của bộ lọc regime (§44.3: ~3.1 lệnh/tháng, khoảng chờ dài nhất ~5.5 tuần). Không nới gate chiến lược chỉ để tạo ra lệnh |
| 17 | Automation giám sát journal demo | **PASS (reader)** 2026-10-29: `scripts\watch_demo_journal.py` quét đủ 79 sự kiện (`RISK=50`, `KILL=1` lịch sử, **`ENTRY=0`**), tail bắt đúng 4 bar mới rồi im lặng ở lần chạy kế tiếp, `--watch --interval 60 --timeout 12` dừng sau 12,2 s. Exit `1` do `KILL` lịch sử, exit `0` khi chỉ có `ENTRY_BLOCKED`. Chưa bật lịch chạy định kỳ — xem §46 |

## 3. Trước khi commit/tag

1. Review `git status`; chỉ stage file nguồn/config/docs, không stage report/database/model.
2. Kiểm tra `git diff` không chứa đường dẫn tuyệt đối, terminal ID, account ID hay secret.
3. Chạy lại mục 1.1–1.3 sau thay đổi cuối.
4. Commit Phase 0–9, trailing stop, bounded DCA/grid, Track C W1–W9 và ADR 0002; ghi commit hash vào báo
   cáo phase nếu cần.
5. Sau commit, lặp lại tái lập trên commit sạch theo `docs/reference/pipeline.md` mục 7; snapshot sạch đã đạt
   ngày 2026-10-28, chỉ cần xác nhận lại với commit hash chính thức và cập nhật checklist này.
6. Backup `experiments/*.sqlite` và `reports/` nếu cần lưu kết quả lâu dài (gitignored).

## 4. Không được làm khi release

- Không bật execution ngoài `PATrendRiderXAUv1DemoEA`; không thêm `OrderSend`/`CTrade` vào EA mô phỏng
  hay module khác. Không mở đường live/real dưới bất kỳ tên nào.
- Không kết nối broker, không đăng nhập, không lưu credential; `AccountInfo*` chỉ được đọc trade-mode
  trong `ExecGuard` path.
- Không thêm bot live/grid/DCA chạy tài khoản thật dưới danh nghĩa “chạy trên MT5”. Demo execution có
  guardrail theo ADR 0003; live vẫn cần ADR mới.
- Không thêm script tự động copy/sync file vào MT5 Data Folder; sync là thao tác thủ công có tài liệu.
- Không commit mật khẩu, investor password, OTP, token hay file phiên.
- Không tuyên bố compile/backtest/parity/ONNX runtime thành công nếu chưa có log/kết quả thật.
- Không biến kết quả synthetic thành cam kết hiệu năng.
