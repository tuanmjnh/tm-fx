# Phase progress — MT5 EA Lab & Pine → MT5

- **Ngày:** 2026-10-28
- **Phạm vi:** Phase 0 (audit môi trường + inventory), Phase 1–6 và Phase 8–9 Track B cho Wonderwhales;
  Phase 1–4 Track B cho LongKaco VSA, TM Fusion Zones và Price Action MTF (spec, audit, contract, indicator,
  test script). Đã compile cả chín file MQL5 và chạy Python tests. **Chưa chạy** test script MQL5,
  indicator/EA runtime, Strategy Tester hoặc parity thật.
- **Nguồn roadmap:** [`archive/v1/mt5-ea-ai-simulation-pack/ROADMAP_MT5_EA_LAB.md`](archive/v1/mt5-ea-ai-simulation-pack/ROADMAP_MT5_EA_LAB.md)
  và [`archive/v1/pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md`](archive/v1/pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md).
  *(2026-10-29: bộ tài liệu v1 đã chuyển vào `docs/archive/v1/`; bộ hiện hành ở [`v2/`](v2/README.md).)*
- **Ranh giới:** SIMULATION_ONLY. Không có `OrderSend`, `CTrade`, `MqlTradeRequest` hoặc API gửi lệnh thật.
  *(Cập nhật 2026-10-29: ADR 0003 thay điều khoản này **riêng cho tài khoản demo / Strategy Tester** —
  xem §43–§46. Live/real vẫn bị cấm, simulation EAs vẫn SIMULATION_ONLY.)*

## 1. Trạng thái tổng hợp

> **Ghi chú (2026-10-29):** các ô `NOT_RUN` / `chưa chạy` trong bảng dưới là **snapshot tại thời điểm viết
> dòng đó**, không phải trạng thái hiện tại. Ma trận runtime đầy đủ, có ngày chạy và số check, nằm ở **§47**.

| Track | Phase | Trạng thái | Bằng chứng chính |
|---|---|---|---|
| A. MT5 EA Lab (Grid/DCA/Runner) | Phase 0 | PASS (có cảnh báo đã ghi) | Env check exit 0; validator exit 0; docs nền có sẵn |
| B. Pine → MT5 | Phase 0 | PASS | Inventory 86 file Pine; không sửa source gốc |
| B. Pine → MT5 | Phase 1 (Wonderwhales) | PASS (spec xong; parity còn BLOCKED) | [`INDICATOR_SPEC_Wonderwhales.md`](indicators/wonderwhales.md); 37+13 input, 4 mode, execution semantics |
| B. Pine → MT5 | Phase 2 (Wonderwhales) | PASS (tĩnh); runtime `PENDING` | [`REPAINT_AUDIT_Wonderwhales.md`](indicators/wonderwhales.md); 10 chính sách MQL5, 8 test thủ công chưa chạy |
| B. Pine → MT5 | Phase 3 (Wonderwhales) | PASS (contract đã chốt) | [`BUFFER_CONTRACT_Wonderwhales.md`](indicators/wonderwhales.md); 18 buffer, 13 input, 36 test vector |
| B. Pine → MT5 | Phase 4 (Wonderwhales) | PASS (compile); vector `NOT_RUN` | `Wonderwhales.mq5` + `WonderwhalesContract.mqh` + `WonderwhalesContractTests.mq5`; 0 error/0 warning |
| B. Pine → MT5 | Phase 5 (Wonderwhales) | PASS (compile); runtime `NOT_RUN` | `PineSignalLabEA.mq5`; 0 error/0 warning; không có API giao dịch |
| B. Pine → MT5 | Phase 6 (Wonderwhales) | PASS (comparator/tests); parity `BLOCKED` | 25 comparator test + 10 audit CSV test pass; cần CSV reference thật |
| B. Pine → MT5 | Phase 8 (Wonderwhales) | PASS | `validate_pineport.py` pass=32; build 5 file 0/0; package có hash |
| B. Pine → MT5 | Phase 9 (Wonderwhales) | PASS (docs) | Compatibility, test plan, install/test; Phase 7 vẫn `BLOCKED` |
| B. Pine → MT5 | Phase 1–3 (LongKaco VSA) | PASS (tĩnh) | Spec + repaint audit + buffer contract; 35 input, 29 buffer (8 plot + 21 contract), 47 test vector |
| B. Pine → MT5 | Phase 4 (LongKaco VSA) | PASS (compile); vector `NOT_RUN` | `LongKacoVSA.mq5` + `LongKacoVSAContract.mqh` + `LongKacoVSAContractTests.mq5`; 0 error/0 warning |
| B. Pine → MT5 | Phase 5–6 (LongKaco VSA) | EA `PASS (compile)`; runtime `NOT_RUN`; parity `BLOCKED` | `PineMultiSignalLabEA.mq5` đọc `LK_BUF_FILL/DIR`; comparator Phase 6 sẵn sàng; chưa có CSV reference từ Pine |
| B. Pine → MT5 | Phase 1–3 (TM Fusion Zones) | PASS (tĩnh) | Spec + repaint audit + buffer contract; 40 input, 33 buffer (10 plot + 23 contract), 82 test vector |
| B. Pine → MT5 | Phase 4 (TM Fusion Zones) | PASS (compile); vector `NOT_RUN` | `TMFusionZones.mq5` + `TMFusionZonesContract.mqh` + `TMFusionZonesContractTests.mq5`; 0 error/0 warning |
| B. Pine → MT5 | Phase 5–6 (TM Fusion Zones) | EA `PASS (compile)`; runtime `NOT_RUN`; parity `BLOCKED` | `PineMultiSignalLabEA.mq5` đọc `FZ_BUF_SIGNAL_LONG/SHORT`; comparator Phase 6 sẵn sàng; chưa có CSV reference từ Pine |
| B. Pine → MT5 | Phase 1–3 (Price Action MTF) | PASS (tĩnh) | Spec + repaint audit + buffer contract; 115 input, 107 buffer (12 plot + 95 contract), 119 test vector |
| B. Pine → MT5 | Phase 4 (Price Action MTF) | PASS (compile); vector `NOT_RUN` | `PriceActionMTF.mq5` + `PriceActionMTFContract.mqh` + `PriceActionMTFContractTests.mq5`; 0 error/0 warning |
| B. Pine → MT5 | Phase 5–6 (Price Action MTF) | EA `PASS (compile)`; runtime `NOT_RUN`; parity `BLOCKED` | `PineMultiSignalLabEA.mq5` đọc `PA_BUF_SIG_LONG/SHORT`; comparator Phase 6 sẵn sàng; chưa có CSV reference từ Pine |
| B. Pine → MT5 | Phase 1–3 (TM XAU Signals 2) | PASS (tĩnh) | Spec + repaint audit + buffer contract; 90 input, 153 buffer (13 plot + 140 contract), 105 test vector |
| B. Pine → MT5 | Phase 4 (TM XAU Signals 2) | PASS (compile); vector `NOT_RUN` | `TMXAUSignals2.mq5` + `TMXAUSignals2Contract.mqh` + `TMXAUSignals2ContractTests.mq5`; 0 error/0 warning; `validate_tmxau2.py` pass=31 |
| B. Pine → MT5 | Phase 5–6 (TM XAU Signals 2) | EA `PASS (compile)`; runtime `NOT_RUN`; parity `BLOCKED` | `PineMultiSignalLabEA.mq5` đọc `X2_BUF_SIG/DIR`; comparator Phase 6 sẵn sàng; chưa có CSV reference từ Pine |
| B. Pine → MT5 | Phase 1–3 (TM Indicator 2) | PASS (tĩnh) | Spec + repaint audit + buffer contract; 118 input, 242 buffer (16 plot + 226 contract), 155 test vector |
| B. Pine → MT5 | Phase 4 (TM Indicator 2) | PASS (compile); vector `NOT_RUN` | `TMIndicator2.mq5` + `TMIndicator2Contract.mqh` + `TMIndicator2ContractTests.mq5`; 0 error/0 warning; `validate_tmind2.py` pass=44 |
| B. Pine → MT5 | Phase 5–6 (TM Indicator 2) | EA `PASS (compile)`; runtime `NOT_RUN`; parity `BLOCKED` | `PineMultiSignalLabEA.mq5` đọc `TM2_BUF_SIGNAL/DIR`; comparator Phase 6 sẵn sàng; chưa có CSV reference từ Pine |
| B. Pine → MT5 | Phase 6 (đa nguồn) | PASS (comparator/tests); parity `BLOCKED` | `multi_source_parity.py` + `compare_multi_signal_exports.py` + 21 test; exit 3 = `BLOCKED` khi thiếu CSV |
| C. Simulation MQL5 | W1–W7, W9, W10 PASS + WonderwhalesSimEA; W8 PASS một phần (3/15) | PASS (compile + tests tĩnh); self-check `SimCoreTests` 123/0 + `SimPlanTests` 39/0 PASS runtime; 3 scenario WW chạy Strategy Tester thật | `SimDca` + `SimPlan` + 5 EA; 123 + 39 vector; `build-mql5.ps1` 25 source 0/0; pytest 328 pass; preset checked=6 (5 preset + project); 3/15 scenario có report + CSV, 12 `NOT_RUN` |
| A. MT5 EA Lab | Phase 1–9 + trailing + bounded DCA/grid | PASS (tests) | Backtester, store, ML/ONNX, trailing và bounded có test; toàn bộ pytest 328 pass |

## 2. Môi trường đã kiểm tra

| Thành phần | Kết quả | Ghi chú |
|---|---|---|
| OS | Windows 10.0.19045 x64 | Roadmap ghi Windows 11; không chặn Phase 0 |
| Python | 3.11.9 | Dùng venv `D:\Applications\tm-fx\.venv` |
| pytest | 9.1.1 | Chạy trong venv của `tm-fx` |
| PowerShell | 5.1.19041.6456 | Chạy được script `.ps1` |
| MetaEditor | 5.0.0.6249 | `C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe` |
| MT5 terminal | 5.0.0.6249 | `C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe` |
| Quyền ghi | Có | Project root, `docs/`, `reports/` đều ghi được |
| `tm-fx` Git | `b29665e first commit`, nhánh `main` | Working tree có 110 mục thay đổi/untracked; hai pack đang untracked |
| `tm-trading` Git | `3db2929`, nhánh `main` | Working tree dirty; **chỉ đọc**, không sửa |

Không đọc hoặc ghi thông tin tài khoản môi giới, credential hay dữ liệu phiên.

## 3. Lệnh đã chạy và kết quả thật

| Lệnh | Exit | Kết quả quan sát |
|---|---|---|
| `git status --short` (tm-fx, tm-trading) | 0 | Ghi nhận thay đổi; pack mới untracked; không ghi đè |
| `.venv/Scripts/python.exe --version` | 0 | `Python 3.11.9` |
| `.venv/Scripts/python.exe -m pytest --version` | 0 | `pytest 9.1.1` |
| `powershell check-environment.ps1 -ProjectRoot . -MetaEditorPath ...` | 0 | OK `docs`, `scripts`, `configs`, `MQL5/Experts/MT5EALab`, `python/tests`, `reports`; cảnh báo `pytest not found globally` (venv dùng thay thế) |
| `validate-project.py --config configs/project.example.json` | 0 | `PASS: simulation-only config validated; scanned 0 MQL5 source file(s)` — scan chưa có giá trị vì chưa có `.mq5` |
| `.venv/Scripts/python.exe -m pytest python/tests -q` (pack) | 5 | `no tests ran` — đúng hiện trạng Phase 0, chưa có test |
| Quét API gửi lệnh trong `docs/mt5-ea-ai-simulation-pack/MQL5/` | 1 (không match) | Pack chưa có `.mq5`/`.mqh`; scan Phase 0 là vacuous |
| Quét Pine trong `D:\Applications\tm-trading\pine` | 0 | 86 file `.pine`; 12 dist + 70 parts + 4 shared |
| Quét license trong Pine | không match | Không thấy header license/copyright rõ ràng |
| Quét secret trong hai pack | 0 | Không có `.env`, key, `accounts.dat`, `servers.dat`; chỉ có câu chính sách |
| `sha256sum` 3 file Wonderwhales dist | 0 | `Wonderwhales` `0529d7b9…`, `Overlay` `75131c44…`, `Backtest` `e7c15e1a…` |
| `wc -l` 3 file Wonderwhales dist | 0 | 415 / 417 / 614 dòng |
| `diff -u Wonderwhales.pine "Wonderwhales Overlay.pine"` | 1 (có khác biệt) | Chỉ 3 nhóm khác: header overlay, thêm `plotcandle`, bỏ 2 plot volume, metadata; signal code giống hệt |
| Đếm input/output/dist | 0 | Indicator: 37 input, 27 `plotshape`, 11 plot, 4 `alertcondition`, 2 `alert()`. Backtest: 50 input |
| Quét dependency Wonderwhales | 0 | `request.security` 0, `array.*` 0, vòng lặp 0 ở cả indicator và Backtest |
| Kiểm tra link Markdown 3 docs | 0 | `checked 19 local links in 3 files` → PASS |
| Quét API gửi lệnh trong spec mới | không match | 0 `OrderSend`/`CTrade`/`MqlTradeRequest` |
| Kiểm tra file MQL5 mới | 0 | Không tạo file `.mq5/.mqh` nào trong lượt này; file hiện có thuộc Track A từ trước |
| `stat` mtime 3 file Wonderwhales | 0 | Mtime 2026-10-26/27, không đổi trong lượt này |
| `grep` gate/alert trong `Wonderwhales.pine` | 0 | Xác nhận `ww_barConfirmed` dòng 261–266; 4 `alertcondition` dòng 396–401; 2 `alert()` dòng 404–407 |
| `grep` execution trong `Wonderwhales Backtest.pine` | 0 | Header dòng 2 (`pyramiding=0`, `calc_on_every_tick`, `calc_on_order_fills`, `process_orders_on_close`); state dòng 309–327; entry 330–398; exit 400–458 |
| Đọc dòng 160–270 (indicator) và 270–465 (strategy) | — | Xác nhận công thức, thứ tự reset → entry → exit, 2 lỗi ladder |
| Link check `REPAINT_AUDIT_Wonderwhales.md` | 0 | `checked 12 local links in 1 file(s); missing=0` |
| Quét API gửi lệnh trong audit doc | không match | Chỉ trích dẫn Pine `strategy.*`/`alert()`; không có MQL5, không có API broker |
| Kiểm tra file MQL5 mới (Phase 2) | 0 | Không tạo `.mq5`/`.mqh`; không compile |
| Đọc input/clamp trong `Wonderwhales.pine` 72–142 | — | Chốt default: PSAR 0.02/0.02/0.2; EMA 20/50/200; ATR 14; ATR% 0.5; vol 20; RSI 14; BB 20/2.0 |
| Link check 5 docs sau Phase 3 | 0 | `checked 40 local links in 5 files; missing=0` |
| Đếm test vector Phase 3 | — | A=9, B=10, C=4, D=7, E=6 → 36 vector |
| Quét API gửi lệnh trong 3 docs Phase 1–3 | không match | Chỉ trích dẫn Pine `strategy.*`; không có MQL5, không có API broker |
| Kiểm tra file MQL5 mới (Phase 3) | 0 | Không tạo `.mq5`/`.mqh`; không compile |
| MetaEditor compile `Indicators/PinePort/Wonderwhales.mq5` | 1 (exit code) | Log UTF-16: `Result: 0 errors, 0 warnings, 981 ms elapsed`; `.ex5` 22.256 byte |
| MetaEditor compile `Scripts/WonderwhalesContractTests.mq5` | 1 (exit code) | Log UTF-16: `Result: 0 errors, 0 warnings, 780 ms elapsed`; `.ex5` 12.846 byte |
| MetaEditor compile `Experts/PineSignalLabEA.mq5` | 1 (exit code) | Log UTF-16: `Result: 0 errors, 0 warnings, 1024 ms elapsed`; `.ex5` 29.950 byte; tự thêm `tester_indicator "PinePort\Wonderwhales"` |
| Quét `OrderSend\|CTrade\|MqlTradeRequest\|PositionOpen\|WebRequest\|Socket\|Password` trong 4 file nguồn mới | 1 (không match) | `forbidden-api-scan: no matches` |
| `pytest python/tests/test_pine_parity.py -q` | 0 | `25 passed in 4.17s` |
| `pytest python/tests/test_signal_audit.py -q` | 0 | `10 passed in 3.51s` |
| `pytest -q` (toàn repo) | 0 | `233 passed in 12.70s` |
| `python scripts/validate_pineport.py` | 0 | `VALIDATION_OK: pass=32 fail=0` |
| `powershell build_pineport.ps1` | 0 | 3 file compile `0 errors, 0 warnings`; log tại `reports/build/` |
| `powershell deploy_pineport.ps1 -Apply` | 0 | Copy 4 file mới + compile 3 file `0 errors, 0 warnings` vào data folder MT5; không mở terminal |
| `powershell package_pineport.ps1` | 0 | 27 file; zip `wonderwhales-pineport-v1.0.0-20261028-105703.zip`; SHA256 `400945cb…` |
| Link check Markdown (tracked files, local + tương đối) | 0 | `checked 164 local links in 59 files; missing=0` |
| Chạy `WonderwhalesContractTests.ex5` | **chưa chạy** | Cần MT5 terminal và chart; không tuyên bố 36/36 PASS — **superseded 2026-10-28: 36/0 PASS qua wrapper Strategy Tester, xem §40 và §47** |
| Strategy Tester / backtest | **chưa chạy** | Không có EA execution; Phase 7 `BLOCKED` |

## 4. Acceptance criteria — Track A (MT5 EA Lab)

| # | Tiêu chí Phase 0 | Trạng thái | Ghi chú |
|---|---|---|---|
| A1 | Có `docs/guides/install-and-test.md` và `docs/reference/architecture.md` | PASS | Có trong pack, nội dung đầy đủ |
| A2 | Script kiểm tra môi trường chạy được, báo lỗi cụ thể khi thiếu | PASS | Exit 0; cảnh báo pytest toàn cục được ghi lại |
| A3 | Không có code giao dịch thật | PASS | 0 file MQL5; validator và grep không thấy API cấm |
| A4 | README, config mẫu, checklist được khởi tạo | PASS | README + `project.example.json` có sẵn; checklist là mục 4 này + `docs/PROGRESS.md` của pack |
| A5 | Không ghi đè thay đổi chưa commit | PASS | Chỉ thêm/sửa tài liệu tiến độ; không chạm source người dùng |

**Kết luận Track A:** Phase 0 PASS, nhưng chất lượng bằng chứng còn giới hạn vì chưa có EA và chưa có
test. Compile/backtest **chưa chạy** và không được tuyên bố thành công.

## 5. Acceptance criteria — Track B (Pine → MT5)

| # | Tiêu chí Phase 0 | Trạng thái | Ghi chú |
|---|---|---|---|
| B1 | Kiểm tra Git, nhánh, thay đổi chưa commit | PASS | `tm-trading` dirty; chỉ đọc |
| B2 | Inventory Pine có đường dẫn rõ ràng | PASS | [`PINE_INVENTORY.md`](indicators/README.md): 86 file |
| B3 | Không sửa source Pine gốc | PASS | Không có thao tác ghi vào `tm-trading/pine` |
| B4 | Phát hiện MT5/MetaEditor | PASS | 5.0.0.6249, đường dẫn xác định |
| B5 | Ghi runtime và fixture mẫu | PASS | Runtime ở mục 2; chưa có fixture Pine reference |
| B6 | Tạo `docs/PROGRESS.md` | PASS | File này |
| Gate 0 | Inventory đầy đủ, không đổi source, thiếu gì ghi rõ | PASS | Blocker còn mở ở mục 14 |

## 6. Phase 1 — Wonderwhales (Track B)

**Mục tiêu:** đặc tả Pine trước khi port, không viết MQL5, không tạo EA.

**Đã kiểm tra:**

- `dist/Wonderwhales.pine` (indicator, 415 dòng), `dist/Wonderwhales Overlay.pine` (417 dòng),
  `dist/Wonderwhales Backtest.pine` (strategy, 614 dòng).
- Toàn bộ module nguồn `parts-wonderwhales/*` (9 file) và phần shared helpers trong dist.
- Không có `request.security`, `request.security_lower_tf`, mảng, vòng lặp, pivot, offset âm, lookahead.

**Files created/modified:**

- Tạo [`INDICATOR_SPEC_Wonderwhales.md`](indicators/wonderwhales.md).
- Cập nhật [`PINE_INVENTORY.md`](indicators/README.md): target/reference đã chốt, trạng thái 3 file,
  blocker 1 và 4 đóng, thêm mục 7.
- Cập nhật file này (`PROGRESS.md`).

**Nội dung spec đã ghi:**

- 37 input indicator + 13 input strategy (default/min/max/step/group).
- 11 plot, 27 `plotshape`, `barcolor`, `fill`, HUD table, 4 `alertcondition`, 2 `alert()`.
- Công thức PSAR, VSA, EMA, ATR/ATR%, RSI, BB và các guard.
- 4 signal mode + cổng `barstate.isconfirmed` + blocked signal.
- Execution semantics của Backtest: sizing, entry, 3 SL model, TP1/TP2, 3 BE trigger, 4 exit mode,
  trailing SAR, reset state, fill/intrabar.
- Warm-up, repaint sơ bộ, 15 khác biệt Pine→MQL5, signal ID + buffer contract draft.
- 2 lỗi logic của bản Pine **không được port mù**: Ladder + `pyramiding=0`, Ladder + Reversal.

**Acceptance — Gate 1 (Track B):**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B7 | Mỗi script có inventory, input/output, dependency, trạng thái port | PASS | Spec bao phủ indicator + biến thể render + strategy |
| B8 | Điều kiện BUY/SELL/EXIT/HOLD được đặc tả | PASS | 4 mode; EXIT chỉ có trong Backtest |
| B9 | Repaint và confirmed-bar policy được mô tả | PASS | Phase 2 hoàn tất phần tĩnh; runtime E1–E8 `PENDING` |
| B10 | Câu hỏi/blocker cụ thể | PASS | Mục 13 của spec: 8 mục |
| B11 | Không tạo MQL5/EA trong Phase 1 | PASS | 0 file mới |
| B12 | Không sửa source Pine | PASS | Chỉ đọc; mtime không đổi |
| B13 | Không tuyên bố compile/backtest | PASS | Không chạy compile/backtest |

**Kết luận:** Phase 1 PASS. Parity Pine-vs-MQL5 vẫn `BLOCKED` vì chưa có reference CSV; đây là blocker
của Phase 6, không phải của Phase 1.

## 7. Phase 2 — Repaint audit (Track B)

**Mục tiêu:** xác định tín hiệu có repaint không, chốt timestamp/confirmed state, và quyết định chính sách
MQL5 trước khi viết contract. Không viết MQL5, không chạy TradingView, không backtest.

**Files created/modified:**

- Tạo [`REPAINT_AUDIT_Wonderwhales.md`](indicators/wonderwhales.md) (13 mục).
- Cập nhật file này (`PROGRESS.md`).

**Kết luận tĩnh:**

- Không có `request.security`, `lookahead`, offset âm, mảng, vòng lặp, pivot. Chuỗi tính toán causal.
- Gate `ww_barConfirmed` (dòng 261–266) áp cho marker, status-line và toàn bộ alert tín hiệu; **không** áp
  cho `alertcondition(ww_isClimaxVol)`.
- `confirmOnClose = true` (default): tín hiệu chỉ chốt tại đóng nến; **không** repaint lịch sử.
- `confirmOnClose = false`: marker bật/tắt trong nến (RP1). Backtest không phát hiện được vì lịch sử luôn
  `barstate.isconfirmed = true` → quyết định **không port** chế độ này (P3, sẽ ghi thành khác biệt D16).
- Nến PSAR hợp lệ đầu tiên không thể flip (`ww_sarDir` khởi tạo `0`, `dir[1] = 0`) → không tín hiệu.
- `psar == close` được xếp bearish (`<` nghiêm ngặt); port phải giữ đúng.
- Strategy: BE/trailing dời SL trong nến và có thể được áp ngược cho chính nến kích hoạt (RP4); exit có
  hiệu lực ngay nến entry hay không vẫn `PENDING`; hai lỗi ladder đã biết vẫn `PENDING`.
- Timestamp contract: `bar_open_time` là khóa; `confirmed_at = bar_open_time + TF`; EA đọc `shift=1`,
  trễ tối đa một tick của nến kế tiếp.

**Chính sách MQL5 đã chốt:** P1–P10 trong audit (chỉ phát trên nến đóng, EA `shift=1`, không port
intrabar, edge event, dedupe theo bar time + signal ID, không alert, không port execution).

**Acceptance — Gate 2 (Track B):**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B14 | Trả lời đủ 7 câu hỏi bắt buộc của roadmap | PASS | Audit mục 2–5 |
| B15 | Định nghĩa timestamp và confirmed state | PASS | Audit mục 8 |
| B16 | Ma trận repaint theo thành phần | PASS | Audit mục 4 |
| B17 | Không âm thầm đổi logic Pine | PASS | P1–P10; P3 ghi rõ khác biệt |
| B18 | Không tuyên bố kiểm chứng runtime | PASS | E1–E8 đều `PENDING` |
| B19 | Không tạo MQL5/EA, không sửa Pine | PASS | 0 file source mới |

**Kết luận:** Phase 2 PASS ở mức phân tích tĩnh. Xác minh runtime TradingView (E1–E8) và parity vẫn
`PENDING`/`BLOCKED`; không được dùng audit này để tuyên bố backtest đúng.

## 8. Phase 3 — Buffer contract và test vector (Track B)

**Mục tiêu:** chốt giao diện indicator ↔ EA trước khi viết mã, gồm input, buffer, missing value, warm-up,
timestamp và vector kiểm tra logic. Không viết MQL5.

**Files created/modified:**

- Tạo [`BUFFER_CONTRACT_Wonderwhales.md`](indicators/wonderwhales.md) (12 mục).
- Cập nhật [`INDICATOR_SPEC_Wonderwhales.md`](indicators/wonderwhales.md): bảng buffer draft thay bằng
  contract 18 kênh; thêm D16–D18; cập nhật việc tiếp theo.
- Cập nhật file này (`PROGRESS.md`).

**Nội dung đã chốt:**

- 13 input indicator, default/clamp khớp Pine dòng 129–142; không có `confirmOnClose` (D16).
- Signal ID theo 4 mode; EA suy ra ID từ mode; blocked là `BLOCKED_FILTER`, không phải tín hiệu.
- 18 buffer: 0 PSAR, 1/2 marker, 3/4 signal, 5 dir, 6/7 blocked, 8 ATR%, 9/10 EMA, 11 EMA200, 12 RSI,
  13–15 BB, 16/17 volume MA/ratio.
- Buffer 3/4/6/7 = 0 tại nến đang chạy; EA chỉ đọc `shift = 1`; dedupe theo bar time + signal ID.
- Missing: `EMPTY_VALUE` cho PSAR/EMA/RSI/BB/Volume MA; `0.0` cho ATR%/VOL_RATIO theo đúng Pine.
- 36 test vector tổng hợp (A–E) kiểm tra dir/flip, mode gate, confirmed gate, crossover, missing.
- Ngưỡng parity đề xuất: signal/dir chính xác; giá `1e-8`; oscillator `1e-6`; so từ bar 300.
- CSV EA: `detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,signal_id,side,sar_dir,psar,fast,slow,atr_pct,input_hash`.

**Acceptance — Gate 3 (Track B):**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B20 | Bảng signal ID/trigger/bar policy/output cho từng mode | PASS | Contract mục 4–5 |
| B21 | Buffer contract có missing value và warm-up | PASS | Contract mục 5–6 |
| B22 | Timestamp/confirmed khớp Phase 2 | PASS | Contract mục 7–8 |
| B23 | Test vector tổng hợp cho logic thuần | PASS | 36 vector, chưa chạy |
| B24 | Không tạo MQL5/EA, không sửa Pine | PASS | 0 file source mới |
| B25 | Không tuyên bố parity/compile | PASS | Parity `BLOCKED` |

**Kết luận:** Phase 3 PASS. Contract đủ để viết indicator ở Phase 4. Vector **chưa chạy**; chỉ trở thành
bằng chứng sau khi script MQL5 thực thi và PASS.

## 9. Phase 4 — Custom indicator MQL5 (Track B)

**Mục tiêu:** hiện thực contract 18 buffer bằng MQL5, compile được, có test vector tổng hợp. Không tạo EA,
không execution.

**Files created:**

- [`mt5/Include/PinePort/WonderwhalesContract.mqh`](../mt5/Include/PinePort/WonderwhalesContract.mqh):
  contract `1.0.0`, enum mode 0–3, enum buffer 0–17, struct input/output, chuẩn hóa input, dir/flip,
  EMA cross, ATR%, volume ratio, mode gate, FNV-1a hash.
- [`mt5/Indicators/PinePort/Wonderwhales.mq5`](../mt5/Indicators/PinePort/Wonderwhales.mq5):
  chart window, 18 buffer, 3 plot (PSAR line, BUY/SELL arrow), 13 input, 7 handle
  (`iSAR`, 3× `iMA`, `iATR`, `iRSI`, `iBands`).
- [`mt5/Scripts/WonderwhalesContractTests.mq5`](../mt5/Scripts/WonderwhalesContractTests.mq5):
  36 vector A–E, không đọc thị trường, không ghi file, không giao dịch.

**Quyết định kỹ thuật:**

- Chỉ tính lại từ `prev_calculated - 2`; buffer tín hiệu tại nến đang chạy = 0.
- `confirmed = j < rates_total - 1`; không có input `confirmOnClose` (D16).
- `psar_valid = finite && > 0`; `dir_prev = 0` ở bar đầu; `psar == close` là bear.
- EMA readiness theo index và period; ATR% = 0 khi ATR chưa sẵn sàng hoặc close ≤ 0.
- `iBands`: buffer 0 → mid, 1 → upper, 2 → lower.
- Volume MA tự cộng `tick_volume` (D18), không dùng `iMA` trên volume.
- Trả `0` nếu `rates_total < 3` hoặc `BarsCalculated < rates_total`.

**Bằng chứng compile:**

```text
Result: 0 errors, 0 warnings, 981 ms elapsed, cpu='X64 Regular'   (indicator)
Result: 0 errors, 0 warnings, 780 ms elapsed                       (contract tests)
```

`.ex5`: indicator ~22 KB, tests ~13 KB. Quét API giao dịch: không match.

**Acceptance — Gate 4:**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B26 | Spec/input/buffer được đặc tả trước khi code | PASS | Contract Phase 3 |
| B27 | Indicator hiện thực đủ 18 buffer và 3 plot | PASS | Static validator |
| B28 | Compile 0 error/0 warning | PASS | Log đã đọc |
| B29 | Mapping `iCustom`/buffer khớp contract | PASS | `shift=1`, buffer 3/4/5 |
| B30 | Test vector có sẵn và chạy được | **COMPILED_NOT_RUN** | 36 vector chưa thực thi |
| B31 | Không có API giao dịch/broker | PASS | Scan sạch |
| B32 | Parity Pine-vs-MQL5 | `BLOCKED` | Thiếu reference CSV |

**Kết luận:** Phase 4 PASS ở mức source + compile. Runtime và test vector chưa chạy; không được coi là
indicator đã hoạt động đúng trong terminal.

## 10. Phase 5 — Signal-only EA (Track B)

**Mục tiêu:** EA đọc indicator tại `shift=1`, ghi tín hiệu một lần cho mỗi nến, không giao dịch.

**File created:** [`mt5/Experts/PineSignalLabEA.mq5`](../mt5/Experts/PineSignalLabEA.mq5).

**Hành vi:**

- 13 input contract + `InpWarmupBars` (mặc định 300) + `InpOutputFile` + `InpLogDebug`.
- `iCustom(_Symbol,_Period,"PinePort\\Wonderwhales", ...)` với đúng 13 tham số.
- Chỉ xử lý khi `Bars > warmup + 1` và `BarsCalculated >= rates_total`.
- Đọc buffer 3 (BUY), 4 (SELL), 5 (dir), 0 (PSAR), 9/10 (EMA), 8 (ATR%) tại `shift=1`.
- Bỏ qua nếu cả hai phía = 0; log lỗi và bỏ qua nếu cả hai = 1.
- Dedupe theo `bar_open_time` đọc từ CSV cuối khi khởi động; ghi `detected_at`, `bar_open_time`,
  `confirmed_at`, symbol, timeframe, mode, signal ID, side, dir, PSAR, EMA, ATR%, input hash.
- Journal `LAB|...|event=signal`; không alert, không order, không account API.
- Giá ghi 8 chữ số; ATR% ghi 10 chữ số để comparator dùng tolerance `1e-8`/`1e-6`.

**Compile:**

```text
Result: 0 errors, 0 warnings, 1024 ms elapsed, cpu='X64 Regular'
```

MetaEditor tự thêm `tester_indicator "PinePort\Wonderwhales"` do `iCustom`.

**Acceptance — Gate 5:**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B33 | EA chỉ signal-only, không API giao dịch | PASS | Scan sạch |
| B34 | Đọc `shift=1`, không đọc nến đang chạy | PASS | Static |
| B35 | Dedupe theo bar time + signal ID | PASS (code) | Runtime chưa chạy |
| B36 | CSV đúng 14 cột và timestamp contract | PASS | Header + `confirmed_at` |
| B37 | Compile 0 error/0 warning | PASS | Log đã đọc |
| B38 | Runtime log/CSV không trùng | **NOT_RUN** | Cần terminal |

**Kết luận:** Phase 5 PASS ở mức source + compile. Chưa có bằng chứng EA chạy đúng trong MT5.

## 11. Phase 6 — Pine vs MQL5 comparator (Track B)

**Mục tiêu:** so CSV Pine thật với CSV EA, báo mismatch theo trường, không tạo dữ liệu giả.

**Files created:**

- [`scripts/compare_pine_exports.py`](../scripts/compare_pine_exports.py): CLI.
- [`python/src/mt5_ea_ai_lab/evaluation/pine_parity.py`](../python/src/mt5_ea_ai_lab/evaluation/pine_parity.py):
  load/validate/compare/report.
- [`python/tests/test_pine_parity.py`](../python/tests/test_pine_parity.py): 25 test.
- [`docs/indicators/parity.md`](indicators/parity.md): schema, quy trình, giới hạn.

**Đã kiểm tra:**

- Schema bắt buộc 10 cột + optional `confirmed_at`, `input_hash`, `mode`, `detected_at`.
- Khóa `(bar_open_time, symbol, timeframe)` sau chuẩn hóa UTC; khóa trùng là lỗi.
- `signal_id`/`side`/`sar_dir` chính xác; 8 signal ID; side và dir phải nhất quán.
- `psar`/`fast`/`slow` tolerance `1e-8`; `atr_pct` tolerance `1e-6`; NaN một phía là mismatch.
- `confirmed_at` kiểm tra cho M1–H12; D1/W1/MN1 bỏ qua vì session gap.
- `--start` và `--warmup-bars` + `--bar-times`; filter rỗng là lỗi, không PASS giả.
- Offset server: `--mql5-offset-minutes` (GMT+3 = 180) và `--pine-offset-minutes`; EA ghi giờ server.
- Exit 0/1/2; report JSON + CSV trong `--out-dir`.
- 25 test pass, gồm CLI exit codes, offset server và các lỗi schema.

**Acceptance — Gate 6:**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B39 | Cùng symbol/timeframe/timezone/input | **BLOCKED** | Cần người dùng chốt và export |
| B40 | Reference CSV thật từ Pine | **BLOCKED** | Không tạo CSV giả |
| B41 | Comparator so timestamp/signal/số/NaN | PASS | 25 test |
| B42 | Tolerance và warm-up được nêu rõ | PASS | `1e-8`, `1e-6`, bar 300 |
| B43 | Báo missing bar/session/repaint | PARTIAL | Có missing row; session/repaint do người dùng phân loại |
| B44 | Không tuyên bố parity khi chưa chạy | PASS | Trạng thái `BLOCKED` |

**Kết luận:** Phase 6 chỉ PASS phần công cụ. Parity thật `BLOCKED`; không có kết quả Pine-vs-MQL5.

## 12. Phase 8 — Scripts hỗ trợ build/test (Track B)

**Files created:**

- [`scripts/build_pineport.ps1`](../scripts/build_pineport.ps1): compile 3 file, đọc log UTF-16, chỉ PASS
  khi `0 errors, 0 warnings`, exit 0/1/2.
- [`scripts/validate_pineport.py`](../scripts/validate_pineport.py): kiểm tra file, contract, buffer, plot,
  `iCustom`, CSV header, 36 test ID, API cấm, placeholder.
- [`scripts/package_pineport.ps1`](../scripts/package_pineport.ps1): đóng gói allow-list 27 file, manifest
  SHA256, chặn `.ex5`/log/secret.

**Kết quả thật:**

```text
VALIDATION_OK: pass=32 fail=0
BUILD_OK: 3 source(s) compiled with 0 errors and 0 warnings.
PACKAGE_OK: reports/packages/wonderwhales-pineport-v1.0.0-20261028-105703.zip
PACKAGE_FILES: 27
PACKAGE_SHA256: 400945cb911e3574cbbc2a1179090ca6e35aa18c0b70ad6f36388aa27d5a7980
```

Roadmap gọi comparator là `compare-indicator-exports.py`; repo dùng `compare_pine_exports.py` với cùng
mục đích. Không tạo bản trùng.

**Acceptance — Gate 8:**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B45 | Build script không tin exit code MetaEditor | PASS | Đọc log |
| B46 | Validator bắt lỗi cấu trúc/API cấm | PASS | 32 check |
| B47 | Package loại artifact/secret | PASS | Allow-list 27 file |
| B48 | Không báo PASS cho bước chưa chạy | PASS | Runtime vẫn `NOT_RUN` |

**Kết luận:** Phase 8 PASS. Script không thay thế test runtime.

## 13. Phase 9 — Docs và trạng thái Phase 7 (Track B)

**Files created:**

- [`docs/indicators/README.md`](indicators/README.md): D1–D18, điểm giữ nguyên, dữ liệu,
  điều chưa kiểm chứng.
- [`docs/reference/testing.md`](reference/testing.md): T1–T8, lệnh, trạng thái từng lớp.
- [`docs/guides/install-and-test.md`](guides/install-and-test.md): copy file, compile, gắn
  indicator/EA, CSV, comparator, tái lập, rollback.
- [`mt5/README.md`](../mt5/README.md): thêm mapping PinePort và mục 9.

**Phase 7 — Strategy Tester:** `BLOCKED`. Không có execution, không có dữ liệu/khoảng ngày chuẩn, và
chưa chạy terminal. Hướng dẫn thủ công nằm trong `TEST_PLAN.md` mục 8.

**Acceptance — Gate 9:**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B49 | Hướng dẫn cài đặt/compile/chạy | PASS | Install doc |
| B50 | Buffer, `iCustom`, missing history, CSV | PASS | Install + README |
| B51 | Cách chạy Python tests/comparator | PASS | Test plan |
| B52 | Cách tái lập và rollback | PASS | Install doc mục 10–11 |
| B53 | Không tuyên bố backtest/lợi nhuận | PASS | Phase 7 `BLOCKED` |

**Kết luận:** Phase 9 PASS phần tài liệu. Phase 7 vẫn mở.

## 14. Blocker và rủi ro còn mở

1. ~~**Chưa chọn script đích để port.**~~ **Đã giải quyết 2026-10-28:** chọn Wonderwhales.
2. **Chưa có reference CSV từ Pine.** So sánh Pine-vs-MQL5 (Phase 6) là `BLOCKED` cho đến khi có export
   hợp lệ trên cùng symbol/timeframe/input. Không được tạo CSV giả.
3. **License chưa rõ.** Không thấy header license trong 86 file. Chỉ dùng nội bộ/port khi người dùng xác
   nhận quyền sử dụng; không phân phối source Pine.
4. **Vị trí project chưa chốt.** Hai pack vẫn nằm trong `tm-fx/docs/` và untracked. Code PinePort đã ở
   `tm-fx/mt5` và `tm-fx/python`; nếu muốn phân phối, nên tách repo trước.
5. **Pack thiếu venv riêng.** `tm-fx` đã có `.venv` dùng cho test; pack vẫn fallback Python toàn cục.
   PinePort scripts dùng `.venv` của repo, không phụ thuộc pack.
6. ~~**Rủi ro exit code MetaEditor.**~~ **Đã xử lý cho PinePort:** `build_pineport.ps1` đọc log UTF-16 và
   chỉ PASS khi `Result: 0 errors, 0 warnings`; không tin exit code.
7. ~~**Chưa có custom indicator/EA.**~~ **Đã tạo và compile** indicator, test script và EA signal-only.
   Đổi thành: **runtime MQL5 chưa chạy** — chưa có bằng chứng indicator vẽ đúng, EA ghi đúng, hay
   36 vector pass trong terminal.
8. **Hành vi Pine chưa kiểm chứng.** Ladder + `pyramiding=0`, Ladder + Reversal, fill timing và intrabar
   stop/limit cần test trên TradingView trước khi port execution; **không** chặn contract tín hiệu.
9. **Symbol/timeframe chuẩn chưa chốt.** Ảnh hưởng trực tiếp đến parity và warm-up ở Phase 6.
10. **Runtime TradingView chưa kiểm chứng.** E1–E8 của audit (alert huỷ giữa nến, exit nến entry, ladder
    entry/close) đều `PENDING`; không được suy ra kết quả từ tài liệu.
11. **Test vector chưa chạy.** Wonderwhales 36 vector, LongKaco VSA 47 vector, TM Fusion Zones 82 vector và
    Price Action MTF 119 vector đã compile; chưa có log `ALL_PASS` từ terminal.
12. **Parity thật `BLOCKED`.** Comparator đã test bằng dữ liệu tổng hợp, nhưng chưa có CSV reference từ
    Pine. Không được dùng unit test thay parity.
13. **Strategy Tester chưa chạy.** Không có execution nên không có P&L; mọi kết quả backtest đều
    `NOT_RUN`, không được diễn giải thành hiệu suất.
14. **EA chưa hỗ trợ LongKaco, TM FZ hay PA MTF.** `PineSignalLabEA.mq5` chỉ đọc buffer Wonderwhales; ba
    indicator còn lại ở trạng thái `NOT_IMPLEMENTED` cho Phase 5. Không được nói EA đã chạy các indicator này.

## 15. Việc được phép làm ở lượt sau

- Track A: đã hoàn tất Phase 1–9 cùng trailing stop và bounded DCA/grid; không còn phase mở trong
  roadmap lab. Không thêm execution thật.
- Track B: chạy `WonderwhalesContractTests`, `LongKacoVSAContractTests`, `TMFusionZonesContractTests` và
  `PriceActionMTFContractTests` trong MT5, ghi log `ALL_PASS` hoặc lỗi cụ thể; gắn indicator và EA lên
  chart, kiểm tra CSV/dedupe; chạy Strategy Tester thủ công. File đã được deploy và compile vào data folder
  hiện tại bằng `scripts/deploy_pineport.ps1` (lượt deploy gần nhất chưa gồm LongKaco/TM FZ/PA MTF; chạy lại
  `-Apply` trước khi test).
- Track B: khi người dùng cung cấp CSV reference từ Pine, chốt symbol/timeframe/input và chạy
  `compare_pine_exports.py`; lưu report thật, không tạo dữ liệu giả.
- Không thêm execution, không kết nối broker, không lưu credential.

EA theo yêu cầu “tạo bot từ logic Pine” hiện là **signal-only**. Không có execution cho đến khi có quyết
định riêng, hợp đồng execution, và kiểm chứng runtime/parity.

## 16. Runtime readiness tooling — 2026-10-28

**Mục tiêu:** giảm thao tác tay trước Phase 7, không thay thế runtime test.

| Công cụ | Chức năng | Bằng chứng |
|---|---|---|
| [`scripts/deploy_pineport.ps1`](../scripts/deploy_pineport.ps1) | Tìm data folder MT5, dry-run mặc định; `-Apply` copy 5 file, bỏ qua file khác nội dung trừ khi `-Force`; compile và đọc log UTF-16; không mở terminal, không đọc file tài khoản | Dry-run PASS; `-Apply` tạo 4 file (`LabLogger.mqh` đã giống hệt); compile 3/3 `0 errors, 0 warnings` (MetaEditor CLI exit 1) |
| [`scripts/audit_signal_csv.py`](../scripts/audit_signal_csv.py) | Audit CSV EA: thứ tự, căn timeframe, đồng nhất symbol/timeframe/mode/input_hash, giá rỗng, ATR% âm, `detected_at >= confirmed_at`; exit 0/1/2 | 10 pytest pass; dùng chung loader với comparator |
| [`python/src/mt5_ea_ai_lab/evaluation/signal_audit.py`](../python/src/mt5_ea_ai_lab/evaluation/signal_audit.py) | Logic audit, tái sử dụng `load_pine_parity_csv` | — |

**Đã chạy:** deploy + compile vào data folder `53785E09...`; toàn bộ pytest `233 passed`; validator
`pass=32 fail=0`.

**Chưa chạy:** T3 (36 vector), T5 (indicator trên chart), T6 (EA ghi CSV), T7 (Strategy Tester). Vẫn là
`NOT_RUN`; audit CSV chỉ có giá trị sau khi EA thực sự ghi file. Parity vẫn `BLOCKED`.

## 17. LongKaco VSA — Phase 1–4 (Track B) — 2026-10-28

**Nguồn đọc:** [`dist/LongKaco VSA.pine`](../../tm-trading/pine/dist/LongKaco%20VSA.pine) (indicator, 681
dòng, 45 input) và [`dist/LongKaco VSA Backtest.pine`](../../tm-trading/pine/dist/LongKaco%20VSA%20Backtest.pine)
(600 dòng) — chỉ đọc, không sửa. Chọn LongKaco VSA vì không dùng `request.security`, không lookahead,
không mảng/vòng lặp phụ thuộc tương lai.

**Tài liệu:**

- [`INDICATOR_SPEC_LongKacoVSA.md`](indicators/longkaco-vsa.md): công thức volume/RMA, bucket, pivot,
  SV/BC/ST/NS/ND, sweep gate, Wyckoff Spring/SOS/LPS, setup entry/SL/TP, CLX-E, warm-up, D1–D7.
- [`REPAINT_AUDIT_LongKacoVSA.md`](indicators/longkaco-vsa.md): `STATIC_PASS_RUNTIME_PENDING`; pivot lag là
  cấu trúc chứ không phải repaint; CLX-E là state chốt, không phải edge; E1–E8 `PENDING`.
- [`BUFFER_CONTRACT_LongKacoVSA.md`](indicators/longkaco-vsa.md): 35 input, signal ID, 8 render buffer
  (0–7) + 21 contract buffer (8–28), `indicator_buffers = 29`, `indicator_plots = 8`, 47 test vector.

**Code và bằng chứng compile (MetaEditor CLI exit 1, log UTF-16 là chuẩn):**

| File | Kết quả | `.ex5` |
|---|---|---|
| `mt5/Indicators/PinePort/LongKacoVSA.mq5` | 0 errors, 0 warnings | 36.104 byte |
| `mt5/Scripts/LongKacoVSAContractTests.mq5` | 0 errors, 0 warnings | 18.988 byte |
| `mt5/Include/PinePort/LongKacoVSAContract.mqh` | header, không compile riêng | — |

- `scripts/validate_longkaco.py`: `VALIDATION_OK: pass=29 fail=0` (buffer enum 8–28, 29 binding, 8 DATA +
  21 CALC, closed-bar gate, 47 test ID, không API giao dịch/file).
- `scripts/build_pineport.ps1`: `BUILD_OK: 5 source(s)` — Wonderwhales và EA vẫn 0/0 sau khi thêm LongKaco.
- Deploy/package script đã thêm LongKaco vào allow-list (chưa chạy `-Apply` lại trong lượt này).

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Chạy `LongKacoVSAContractTests.ex5` (47 vector) | `NOT_RUN` — cần MT5 terminal |
| Indicator trên chart (marker/không repaint) | `NOT_RUN` |
| EA đọc LongKaco | `NOT_IMPLEMENTED` — EA hiện chỉ đọc Wonderwhales |
| Parity Pine-vs-MQL5 | `BLOCKED` — chưa có CSV reference |
| Strategy Tester / backtest | `NOT_RUN` — không có execution |

**Kết luận:** Phase 1–4 của LongKaco VSA PASS ở mức tài liệu + compile tĩnh. Không có tuyên bố runtime,
parity hay hiệu suất. Compile không chứng minh 47 vector pass.

## 18. TM Fusion Zones — Phase 1–4 (Track B) — 2026-10-28

**Nguồn đọc:** [`dist/TM Fusion Zones.pine`](../../tm-trading/pine/dist/TM%20Fusion%20Zones.pine) (indicator,
Pine v6) — chỉ đọc, không sửa. Chọn TM Fusion Zones vì toàn bộ state nằm trong `var` UDT (zones, structure,
trade tracking) và không có execution; MTF đọc qua `request.security(..., lookahead_off)`.

**Tài liệu:**

- [`INDICATOR_SPEC_TMFusionZones.md`](indicators/tm-fusion-zones.md): ATR/ADX/Choppiness, ngưỡng regime
  lấy từ code, ribbon đôi, zone engine, market structure, PDH/PDL, candle, MTF, setup, scoring, risk,
  gates, eligibility, state machine, D1–D7.
- [`REPAINT_AUDIT_TMFusionZones.md`](indicators/tm-fusion-zones.md): `STATIC_PASS_RUNTIME_PENDING`;
  pivot/zone là cấu trúc chứ không repaint; E1–E8 `PENDING`.
- [`BUFFER_CONTRACT_TMFusionZones.md`](indicators/tm-fusion-zones.md): 40 input, enum, 10 render buffer
  (0–9) + 23 contract buffer (10–32), `indicator_buffers 33`, `indicator_plots 10`, 82 test vector.

**Code và bằng chứng compile (MetaEditor CLI exit 1, log UTF-16 là chuẩn):**

| File | Kết quả | `.ex5` |
|---|---|---|
| `mt5/Indicators/PinePort/TMFusionZones.mq5` | 0 errors, 0 warnings | 54.334 byte |
| `mt5/Scripts/TMFusionZonesContractTests.mq5` | 0 errors, 0 warnings | 61.512 byte |
| `mt5/Include/PinePort/TMFusionZonesContract.mqh` | header, không compile riêng | — |

- `scripts/validate_tmfz.py`: `VALIDATION_OK: pass=34 fail=0` (enum 10–32, 33 binding, 10 DATA + 23 CALC,
  closed-bar replay, 40 input, 82 test ID, không API giao dịch/file).
- `scripts/build_pineport.ps1`: `BUILD_OK: 7 source(s)` — Wonderwhales, LongKaco và EA vẫn 0/0 sau khi thêm TM FZ.
- Deploy/package script đã thêm TM FZ vào allow-list (chưa chạy `-Apply` lại trong lượt này).

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Chạy `TMFusionZonesContractTests.ex5` (82 vector) | `NOT_RUN` — cần MT5 terminal |
| Indicator trên chart (ribbon/zone/không repaint) | `NOT_RUN` |
| EA đọc TM FZ | `NOT_IMPLEMENTED` — EA hiện chỉ đọc Wonderwhales |
| Parity Pine-vs-MQL5 | `BLOCKED` — chưa có CSV reference |
| Strategy Tester / backtest | `NOT_RUN` — không có execution |

**Kết luận:** Phase 1–4 của TM Fusion Zones PASS ở mức tài liệu + compile tĩnh. Không có tuyên bố runtime,
parity hay hiệu suất. Compile không chứng minh 82 vector pass.

## 19. Price Action MTF — Phase 1–4 (Track B) — 2026-10-28

**Nguồn đọc:** [`dist/Price Action MTF.pine`](../../tm-trading/pine/dist/Price%20Action%20MTF.pine) (indicator,
Pine v6, 1801 dòng, 144 input khai báo) — chỉ đọc, không sửa. 115 input được port; 35 input hiển thị/chết bị
port bỏ (ghi rõ trong contract §3). MTF đọc qua `request.security(expr[1], lookahead_on)` giống Pine.

**Tài liệu:**

- [`INDICATOR_SPEC_PriceActionMTF.md`](indicators/price-action-mtf.md): cấu trúc swing/pivot, BOS/CHoCH,
  retest/fail/continuation/pullback, thanh khoản, zone/FVG/OB, candle, indicator scores, MTF, scoring 11 nhóm,
  gate, plan/SL/TP, state machine, D1–D10.
- [`REPAINT_AUDIT_PriceActionMTF.md`](indicators/price-action-mtf.md): `STATIC_PASS_RUNTIME_PENDING`;
  closed-bar replay, không dùng nến đang chạy; E1–E10 `PENDING`.
- [`BUFFER_CONTRACT_PriceActionMTF.md`](indicators/price-action-mtf.md): 115 input + 4 input thời gian,
  12 render buffer (0–11) + 95 contract buffer (12–106), `indicator_buffers 107`, `indicator_plots 12`,
  119 test vector, quirk Q1–Q10.

**Code và bằng chứng compile (MetaEditor CLI exit 1, log UTF-16 là chuẩn):**

| File | Kết quả | `.ex5` |
|---|---|---|
| `mt5/Indicators/PinePort/PriceActionMTF.mq5` | 0 errors, 0 warnings | 111.728 byte |
| `mt5/Scripts/PriceActionMTFContractTests.mq5` | 0 errors, 0 warnings | 114.290 byte |
| `mt5/Include/PinePort/PriceActionMTFContract.mqh` | header, không compile riêng | — |

- `scripts/validate_pamtf.py`: `VALIDATION_OK: pass=34 fail=0` (enum 12–106, 107 binding, 12 DATA + 95 CALC,
  closed-bar replay, 115 input, 119 test ID, không API giao dịch/file).
- `scripts/build_pineport.ps1`: `BUILD_OK: 9 source(s)` — Wonderwhales, LongKaco, TM FZ và EA vẫn 0/0.
- Deploy/package script đã thêm PA MTF vào allow-list (chưa chạy `-Apply` lại trong lượt này).
- Header dùng tiền tố `pb*`/`pb2*` cho snapshot nến trước để không trùng `prevHigh/prevLow` của cấu trúc.

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Chạy `PriceActionMTFContractTests.ex5` (119 vector) | `NOT_RUN` — cần MT5 terminal |
| Indicator trên chart (zone/plan/không repaint) | `NOT_RUN` |
| EA đọc PA MTF | `NOT_IMPLEMENTED` — EA hiện chỉ đọc Wonderwhales |
| Parity Pine-vs-MQL5 | `BLOCKED` — chưa có CSV reference |
| Strategy Tester / backtest | `NOT_RUN` — không có execution |

**Kết luận:** Phase 1–4 của Price Action MTF PASS ở mức tài liệu + compile tĩnh. Không có tuyên bố runtime,
parity hay hiệu suất. Compile không chứng minh 119 vector pass.

## 20. TM XAU Signals 2 — Phase 1–4 (Track B) — 2026-10-28

**Nguồn đọc:** [`dist/TM XAU Signals 2.pine`](../../tm-trading/pine/dist/TM%20XAU%20Signals%202.pine)
(indicator, Pine v6, 1383 dòng, 90 input được port) — chỉ đọc, không sửa. Contract v1.0.0 đóng băng 153
buffer (13 plot + 140 contract), 90 input, 105 test vector.

**Tài liệu:**

- [`INDICATOR_SPEC_TMXAUSignals2.md`](indicators/tm-xau-signals-2.md): cấu trúc, thanh khoản, zone/FVG/OB,
  candle, indicator, scoring 11 nhóm, gate, plan/SL/TP, state machine TP 3 tầng.
- [`REPAINT_AUDIT_TMXAUSignals2.md`](indicators/tm-xau-signals-2.md): `STATIC_PASS_RUNTIME_PENDING`;
  replay chỉ nến đã đóng.
- [`BUFFER_CONTRACT_TMXAUSignals2.md`](indicators/tm-xau-signals-2.md): 90 input, 153 buffer,
  105 test vector, quirk Q1–Q10.

**Code và bằng chứng compile (MetaEditor CLI, log UTF-16):**

| File | Kết quả | `.ex5` |
|---|---|---|
| `mt5/Indicators/PinePort/TMXAUSignals2.mq5` | 0 errors, 0 warnings | 97.680 byte |
| `mt5/Scripts/TMXAUSignals2ContractTests.mq5` | 0 errors, 0 warnings | 76.838 byte |
| `mt5/Include/PinePort/TMXAUSignals2Contract.mqh` | header, không compile riêng | — |

- `scripts/validate_tmxau2.py`: `VALIDATION_OK: pass=31 fail=0` (V1–V14: enum 13–152, 153 binding,
  13 DATA + 140 CALC, closed-bar replay, 90 input, 105 test ID, không API giao dịch/file).
- `scripts/build_pineport.ps1`: `BUILD_OK: 11 source(s) compiled with 0 errors and 0 warnings` (bao gồm
  TM XAU2; các indicator/EA cũ vẫn 0/0).
- `scripts/deploy_pineport.ps1`, `package_pineport.ps1`: đã thêm TM XAU2 vào allow-list (chưa chạy
  `-Apply`/package trong lượt này).

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Chạy `TMXAUSignals2ContractTests.ex5` (105 vector) | `NOT_RUN` — cần MT5 terminal |
| Indicator trên chart | `NOT_RUN` |
| EA đọc TM XAU2 | `NOT_IMPLEMENTED` — EA hiện chỉ đọc Wonderwhales |
| Parity Pine-vs-MQL5 | `BLOCKED` — chưa có CSV reference |
| Strategy Tester / backtest | `NOT_RUN` — không có execution |

**Kết luận:** Phase 1–4 của TM XAU Signals 2 PASS ở mức tài liệu + compile tĩnh. Không có tuyên bố runtime,
parity hay hiệu suất. Compile không chứng minh 105 vector pass.

## 21. TM Indicator 2 — Phase 1–4 (Track B) — 2026-10-28

**Nguồn đọc:** [`dist/TM Indicator 2.pine`](../../tm-trading/pine/dist/TM%20Indicator%202.pine)
(indicator, Pine v6, 2243 dòng, 151 input, v2.1.0) — chỉ đọc, không sửa.

**Tài liệu:**

- [`INDICATOR_SPEC_TMIndicator2.md`](indicators/tm-indicator-2.md): L0–L10, regime classifier,
  structure/session/zone, momentum/volume/VWAP, 5 `request.security`, obstacle + 6 gate, scoring 2.1
  hai phía, entry mode A/B/C, plan + state machine 5 stage, D1–D10.
- [`REPAINT_AUDIT_TMIndicator2.md`](indicators/tm-indicator-2.md): `STATIC_PASS_RUNTIME_PENDING`;
  confirmed-bar gate, fill-bar TP suppression, SL precedence, FVG/OB mitigation, S/R `broken` dead,
  box GC read-only, E1–E14.
- [`BUFFER_CONTRACT_TMIndicator2.md`](indicators/tm-indicator-2.md): `CONTRACT_FROZEN_FOR_PHASE4`;
  118 input (113 ported + 5 MQL5-only), 242 buffer (16 render 0..15 + 226 contract 16..241),
  `ENUM_TM2_REASON` 0..31, state struct + 13-step pipeline, 60+ helper signature, 155 test vector
  (A6 B8 C8 D10 E8 F10 G10 H9 I8 J10 K10 L10 M10 N12 O16 P10), validator V1–V14, quirk Q1–Q16.

**Code và bằng chứng compile (MetaEditor CLI, log UTF-16):**

| File | Kết quả | `.ex5` |
|---|---|---|
| `mt5/Indicators/PinePort/TMIndicator2.mq5` | 0 errors, 0 warnings | 140.596 byte |
| `mt5/Scripts/TMIndicator2ContractTests.mq5` | 0 errors, 0 warnings | 130.042 byte |
| `mt5/Include/PinePort/TMIndicator2Contract.mqh` | header, không compile riêng | — |

- Indicator bind 242 buffer: 0..15 `INDICATOR_DATA` (16 plot) và 16..241 `INDICATOR_CALCULATIONS`;
  replay chỉ nến đã đóng.
- `scripts/validate_tmind2.py`: `VALIDATION_OK: pass=44 fail=0` (V1–V14: enum 16–241, 242 binding,
  16 DATA + 226 CALC, closed-bar replay, 118 input, 155 test ID, không API giao dịch/file).
- `scripts/build_pineport.ps1`: `BUILD_OK: 13 source(s) compiled with 0 errors and 0 warnings`
  (bao gồm TM Indicator 2; các indicator/EA cũ vẫn 0/0).
- `scripts/deploy_pineport.ps1`, `package_pineport.ps1`: đã thêm TM Indicator 2 (contract, indicator,
  tests, spec/audit/contract docs, validator) vào allow-list; chưa chạy `-Apply`/package trong lượt này.

**Ghi chú vector đã hiệu chỉnh:**

- G2 dùng `vol = 219` (kiểu `long` trong MQL5) thay vì 219.99 của tài liệu; bucket vẫn VERYHIGH và
  `isTim = false` với `volRatio 2.19`.
- H9 chỉ khẳng định `atrPct` truyền thẳng từ bar; công thức `atr/close*100` nằm trong indicator và
  chưa được kiểm chứng bằng test vector.
- B8 giữ nguyên công thức `volumeScore` "chết" của Pine (dead branch) để không âm thầm sửa nguồn.

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Chạy `TMIndicator2ContractTests.ex5` (155 vector) | `NOT_RUN` — cần MT5 terminal |
| Indicator trên chart | `NOT_RUN` |
| EA đọc TM Indicator 2 | `PASS (compile)` — `PineMultiSignalLabEA.mq5`, runtime `NOT_RUN` |
| Parity Pine-vs-MQL5 | `BLOCKED` — chưa có CSV reference |
| Strategy Tester / backtest | `NOT_RUN` — không có execution |

**Kết luận:** Phase 1–4 của TM Indicator 2 PASS ở mức tài liệu + compile tĩnh. Không có tuyên bố runtime,
parity hay hiệu suất. Compile không chứng minh 155 vector pass.

## 22. Phase 5 — EA tín hiệu đa nguồn (Track B) — 2026-10-28

**Mục tiêu:** một EA `SIGNAL_ONLY` đọc cả sáu indicator PinePort đã port, ghi CSV thống nhất để audit.
Không `OrderSend`, không `CTrade`, không truy cập tài khoản, không gửi lệnh.

**Code:**

| File | Vai trò | Kết quả |
|---|---|---|
| `mt5/Experts/PineMultiSignalLabEA.mq5` | Đọc 6 indicator tại `shift=1`, ghi `MQL5/Files/pine_multi_signal_log.csv` | 0 errors, 0 warnings; `.ex5` 34.514 byte |
| `python/src/mt5_ea_ai_lab/evaluation/multi_signal_audit.py` | Audit cấu trúc CSV thống nhất | 11 unit test pass |
| `scripts/audit_multi_signal_csv.py` | CLI audit | chưa chạy với CSV thật |
| `python/tests/test_multi_signal_audit.py` | Test schema, dedupe, side/dir/score, thời gian | `11 passed` |

**Nguồn tín hiệu đọc từ buffer:**

| Nguồn | Buffer tín hiệu | Ghi chú |
|---|---|---|
| Wonderwhales | `WW_BUF_BUY_SIGNAL` + `WW_BUF_SELL_SIGNAL` | `iCustom` không truyền tham số → dùng input mặc định của indicator |
| LongKacoVSA | `LK_BUF_FILL` + `LK_BUF_DIR` | `FILL` là sự kiện entry đã khớp trong state machine |
| TMFusionZones | `FZ_BUF_SIGNAL_LONG` + `FZ_BUF_SIGNAL_SHORT` | kèm `SCORE_*`, `ENTRY/SL/TP1..3` |
| PriceActionMTF | `PA_BUF_SIG_LONG` + `PA_BUF_SIG_SHORT` | kèm `SCORE100`, plan, `BLOCK` |
| TMXAUSignals2 | `X2_BUF_SIG` + `X2_BUF_DIR` | kèm `SCORE100`, plan, `BLOCK` |
| TMIndicator2 | `TM2_BUF_SIGNAL` + `TM2_BUF_DIR` | kèm `SCORE100`, plan, `NO_TRADE_REASON` |

**CSV schema (18 cột):**
`detected_at,bar_open_time,confirmed_at,symbol,timeframe,source,contract_version,signal_id,side,dir,score,entry,sl,tp1,tp2,tp3,reason,input_hash`.

- Chống trùng theo cặp `(source, bar_open_time)`; khi khởi động lại, EA đọc CSV để lấy mốc bar cuối
  của từng nguồn.
- `input_hash` là FNV-1a của `source|contract_version|indicator-defaults` (không phải hash cấu hình
  thật, vì EA không truyền tham số).
- Giới hạn `iCustom` 63 tham số: TM Indicator 2 có 118 input nên EA chỉ gọi với 0 tham số; muốn đổi
  cấu hình phải sửa default của indicator hoặc thêm EA riêng.
- `#include` cả sáu contract header để dùng tên buffer; compile 0/0 xác nhận không xung đột.

**Bằng chứng compile/build:**

- `scripts/build_pineport.ps1`: `BUILD_OK: 14 source(s) compiled with 0 errors and 0 warnings`.
- Quét API giao dịch trong EA: không có `OrderSend`/`CTrade`/`MqlTrade*`/`AccountInfo`/`WebSocket`.
- `pytest python/tests -q`: `244 passed` (233 cũ + 11 audit mới).
- Sáu validator PinePort: `32/29/34/34/31/44` pass, 0 fail.
- `scripts/package_pineport.ps1`: `PACKAGE_OK`, 66 file, SHA-256
  `a1ada12cb95d563f7c73da1f4b8c8d8612ed083c16af3bc86516cdab15872d82` (bản package tại thời điểm
  Phase 5); zip chứa EA, audit module, CLI audit và test.

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Chạy `PineSignalLabEA` / `PineMultiSignalLabEA` trong terminal | `NOT_RUN` |
| Sinh CSV thật và chạy `audit_multi_signal_csv.py` | `NOT_RUN` |
| Indicator đọc đúng buffer khi chạy runtime | `NOT_RUN` |
| Parity Pine-vs-MQL5 | `BLOCKED` — chưa có CSV reference |
| Strategy Tester / backtest | `NOT_RUN` — không có execution |

**Kết luận:** Phase 5 PASS ở mức code + compile tĩnh. EA chưa chạy, chưa có CSV thật; không tuyên bố
runtime, parity hay hiệu suất.



## 23. Phase 6 — Comparator parity đa nguồn (Track B) — 2026-10-28

**Mục tiêu:** có công cụ so CSV reference do Pine xuất với CSV của `PineMultiSignalLabEA` trên cùng
schema 18 cột, ghép theo `(source, bar_open_time, symbol, timeframe)`.

**Code:**

| File | Vai trò | Kết quả |
|---|---|---|
| `python/src/mt5_ea_ai_lab/evaluation/multi_source_parity.py` | Loader + comparator + report | tái dùng parse/format của `pine_parity` |
| `scripts/compare_multi_signal_exports.py` | CLI | exit 0 match / 1 mismatch / 2 invalid / 3 `BLOCKED` |
| `python/tests/test_multi_source_parity.py` | 21 unit test | `21 passed` |
| `docs/indicators/parity.md` | Schema, quy tắc, exit code | parity thật `BLOCKED` |

**Bằng chứng build:**

- `pytest python/tests -q`: `265 passed` (244 cũ + 21 parity; số liệu tại thời điểm Phase 6).
- CLI thiếu reference: in `parity=BLOCKED reason=reference_file_missing`, exit 3, không tạo report.
- `scripts/package_pineport.ps1`: `PACKAGE_OK`, 70 file, SHA-256
  `2806197524e0c5e360921ec44837972ef584d2cdd933444a1a5e51f18d9703ee`; zip chứa module, CLI, test
  và tài liệu parity đa nguồn.

**Quy tắc đã kiểm bằng test:**

- Khóa ngoài: thiếu một phía → `missing_in_mql5` / `missing_in_reference`.
- `signal_id`, `side`, `dir` khớp chính xác; `score` tolerance `1e-6`; giá tolerance `1e-8`.
- Một phía trống giá → `nan_mismatch`; cả hai trống → bỏ qua.
- `contract_version`, `reason`, `input_hash` chỉ so khi cả hai file đều có cột.
- `confirmed_at` (nếu có) phải bằng `bar_open_time + timeframe`.
- Offset server (GMT+3 = 180) quy về UTC trước khi ghép.
- Thiếu file reference/CSV MQL5 → CLI in `parity=BLOCKED` và trả exit 3, không tạo report.

**Chưa làm / trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| CSV reference thật từ Pine cho 6 indicator | `BLOCKED` — chưa có, không được bịa |
| Chạy comparator trên dữ liệu thật | `NOT_RUN` |
| Sinh CSV MQL5 bằng EA trong terminal | `NOT_RUN` |
| Phân tích warm-up / repaint / intrabar | `NOT_RUN` — cần dữ liệu thật |

**Kết luận:** Phase 6 PASS ở mức công cụ + unit test. Parity dữ liệu thật vẫn `BLOCKED`; không có
kết luận nào về việc MQL5 khớp Pine khi chưa có CSV reference.

## 24. Lộ trình tổng hợp từ `docs/MT5_AI_Roadmaps` — 2026-10-28

**Nguồn:** đã đọc toàn bộ 10 file trong `docs/MT5_AI_Roadmaps/` (3 roadmap, 3 prompt, strategy spec,
risk/validation, install/test, index) và đối chiếu cây mã nguồn.

**Kết luận kiểm kê:**

| Track | Trạng thái code | Việc còn lại |
|---|---|---|
| A. MT5 EA & AI Lab | Phase 0–9 + trailing/bounded (Python) `DONE` | Dữ liệu MT5 thật `BLOCKED`; Strategy Tester `NOT_RUN` |
| B. Pine → MT5 | 6 indicator + 2 EA + comparator `DONE (compile/tests)` | Runtime `NOT_RUN`; parity `BLOCKED` (thiếu CSV Pine) |
| C. Simulation Grid/DCA/Runner | 3 EA + core + preset/validator + toolchain `DONE (compile/tests)` | Strategy Tester `NOT_RUN` |

**Lộ trình thực hiện tuần tự:** xem [`MASTER_ROADMAP.md`](MASTER_ROADMAP.md).

| ID | Nội dung | Trạng thái |
|---|---|---|
| W1 | Nền tảng simulation MQL5 (portfolio, logger, input) | `READY_FOR_MANUAL_VALIDATION` — compile 0/0; vector `NOT_RUN` |
| W2 | `RiskGuard` + `CostModel` dùng chung | `READY_FOR_MANUAL_VALIDATION` — compile 0/0; vector `NOT_RUN` |
| W3 | `RunnerTrailingLabEA.mq5` | `READY_FOR_MANUAL_VALIDATION` — compile 0/0; runtime `NOT_RUN` |
| W4 | `GridLabEA.mq5` | `READY_FOR_MANUAL_VALIDATION` — compile 0/0; runtime `NOT_RUN` |
| W5 | `DCALabEA.mq5` | `READY_FOR_MANUAL_VALIDATION` — compile 0/0; runtime `NOT_RUN` |
| W6 | Preset/config + validator fail-closed | `PASS` — `validate_sim_configs.py` checked=4 fail=0; snapshot 4 file |
| W7 | Script root: check/build/test/validate/package | `PASS` — env checks=22 fail=0; build 22 source 0/0; validate-project checks=9 fail=0; package 234 file |
| W8 | Strategy Tester thủ công | `NOT_RUN` — hướng dẫn + template có; 0/10 scenario có report |
| W9 | Bàn giao docs | `PASS` — README, `SIM_INSTALL_AND_TEST`, strategy tester, risk, release checklist, PROGRESS |

**Bước kế tiếp:** W1 — tạo `mt5/Include/Sim/` và script test nền tảng, compile 0/0, chưa chạm EA.

> Cập nhật 2026-10-28: W1–W7 và W9 đã xong; W8 (Strategy Tester) vẫn `NOT_RUN` vì cần thao tác MT5 thủ công.

## 25. W1 — Nền tảng simulation MQL5 (Track C) — 2026-10-28

**Mục tiêu:** thư viện dùng chung cho ba EA mô phỏng trước khi viết chiến lược: types/hash, validate input,
portfolio vị thế ảo, logger CSV schema cố định.

**File thêm:**

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimTypes.mqh` | `ENUM_SIM_SIDE`, `SimSideName`, FNV-1a 32-bit, helper fingerprint |
| `mt5/Include/Sim/SimValidate.mqh` | 10 validator với token lỗi ổn định |
| `mt5/Include/Sim/SimPortfolio.mqh` | `CSimPortfolio` + `SimPortfolioSnapshot` |
| `mt5/Include/Sim/SimLogger.mqh` | `SimLogRecord`, `SimFormatLogLine`, `CSimLogger` |
| `mt5/Scripts/SimCoreTests.mq5` | 41 test vector tự sinh, không dùng dữ liệu thị trường |
| `python/tests/test_sim_core_source.py` | 5 test: schema 18 cột, placeholder, cấm API giao dịch, FNV vector, test id |
| `docs/reference/simulation.md` | Quy ước tính toán, token lỗi, ví dụ tay, schema, cách chạy |

**Bằng chứng build:**

- `MetaEditor64.exe /compile:...SimCoreTests.mq5`: log UTF-16
  `Result: 0 errors, 0 warnings, 1436 ms elapsed`; `SimCoreTests.ex5` 30,662 bytes.
- CLI trả exit code 1 dù log báo thành công (hành vi đã biết của MetaEditor); log là nguồn xác nhận.
- `pytest python/tests -q`: `270 passed` (265 cũ + 5 source tests).

**Vector đã encode (chưa chạy trong MT5):**

| Nhóm | Nội dung |
|---|---|
| P1–P10 | Init, side NONE, giá/volume/commission âm, chưa init, average entry `3.1/3.0`, close delta `+0.05` |
| P11–P15 | Commission khi mở/đóng, realized `-4.98`, close rỗng, side ngược chiều, reset sau close |
| P16–P19 | Equity 9990/10005/9980, drawdown `0.1%` và `≈0.2499%`, snapshot |
| V1–V11 | Biên của price, volume, commission, balance, levels 1/1000, multiplier, percent, spread, warmup, slippage |
| H1–H6 | `abc=1A47E90B`, rỗng `811C9DC5`, không trùng, format fingerprint |
| L1–L5 | Header 18 cột, dòng 18 trường, nội dung, tên side, reason rỗng |

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Compile | PASS — 0 errors, 0 warnings |
| Chạy `SimCoreTests` trong MT5 | `NOT_RUN` — cần terminal; chưa có dòng `TEST\|RESULT\|ALL_PASS` |
| Ghi/đọc CSV logger trong `MQL5/Files` | `NOT_RUN` — cần môi trường MT5 |
| Python đọc CSV mẫu | Thay bằng test tĩnh schema + cấm API; chưa có CSV runtime để đọc |

**Kết luận:** W1 `READY_FOR_MANUAL_VALIDATION`. Compile và test tĩnh PASS; toàn bộ hành vi runtime phải
xác nhận bằng cách chạy script trong MT5, không suy diễn từ compile.

## 26. W2 — RiskGuard + CostModel dùng chung (Track C) — 2026-10-28

**Mục tiêu:** một nơi duy nhất định nghĩa hard cap và chi phí mô phỏng để ba EA không tự đặt lại giới hạn.

**File thêm/sửa:**

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimCostModel.mqh` | `SimCostAssumptions`, `CSimCostModel`: spread/commission/slippage/swap, `FillPrice`, fingerprint |
| `mt5/Include/Sim/SimRiskGuard.mqh` | `SimRiskLimits/Context/Decision/Snapshot`, `CSimRiskGuard` với `ACTIVE/BLOCKED/HALTED` |
| `mt5/Include/Sim/SimValidate.mqh` | Thêm `SimValidatePoint`, `SimValidateFinite`, `SimValidateCount` |
| `mt5/Scripts/SimCoreTests.mq5` | Thêm C1–C12 (cost) và R1–R20 (risk); tổng 73 vector |
| `python/tests/test_sim_core_source.py` | Thêm test token risk/cost ổn định; tổng 7 test |
| `docs/reference/simulation.md` | Công thức cost, bảng cap, thứ tự kiểm tra, chính sách state |

**Bằng chứng build:**

- Compile `SimCoreTests.mq5`: `Result: 0 errors, 0 warnings, 1742 ms elapsed`;
  `SimCoreTests.ex5` 56,884 bytes.
- `pytest python/tests -q`: `272 passed` (265 Phase 6 + 7 sim-core).

**Chính sách đã encode:**

- Daily loss và drawdown tính trên equity mô phỏng, vi phạm → `HALTED` vĩnh viễn cho tới `Reset()`.
- Cap thường (spread, positions, grid, DCA, exposure, cooldown) → `BLOCKED` một lần; nếu
  `halt_on_breach=true` → `HALTED`.
- `SetKillSwitch(false)` không tự resume; `Reset()` mới resume.
- `0` ở spread/exposure/daily/drawdown/dca = tắt kiểm tra; EA DCA tự chặn add khi input của nó bằng 0.
- Chặn tại biên: `open >= max` cho số lượng; `exposure + volume > max` cho exposure (bằng cap được phép).
- Cost tách riêng spread/commission/slippage/swap, `FillPrice` luôn bất lợi cho vị thế.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Compile | PASS — 0 errors, 0 warnings |
| Chạy C1–C12, R1–R20 trong MT5 | `NOT_RUN` — cần terminal |
| EA dùng guard/cost | Chưa có — W3–W5 |
| Đối chiếu cost với report Strategy Tester | `NOT_RUN` — cần backtest thật |

**Kết luận:** W2 `READY_FOR_MANUAL_VALIDATION`. Logic cap/cost có test tự sinh và test tĩnh; chưa có
bằng chứng runtime.

## 27. W3 — RunnerTrailingLabEA (Track C) — 2026-10-28

**Mục tiêu:** EA mô phỏng một vị thế ảo duy nhất với SL ban đầu, breakeven và trailing, dùng đúng
`CSimPortfolio`/`CSimCostModel`/`CSimRiskGuard`/`CSimLogger` của W1–W2; không có API gửi lệnh.

**File thêm/sửa:**

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimTrailing.mqh` | `SimTrailingInputs/Result`, `SimTrailingEvaluate` (breakeven theo point + trailing), `SimStopHit/FillPrice/Gapped` |
| `mt5/Experts/RunnerTrailingLabEA.mq5` | EMA cross entry, side filter, ATR initial SL, breakeven/trailing, max holding bars, RiskGuard, CSV log |
| `mt5/Scripts/SimCoreTests.mq5` | Thêm T1–T15 (trailing, stop, gap); tổng 88 vector |
| `configs/sim/runner_trailing.json` | Preset mẫu khớp input EA, `SIMULATION_ONLY`, `allow_live_trading=false` |
| `docs/reference/simulation.md` | Input, luật chạy, bất biến, event log, cách chạy tay, giới hạn |
| `python/tests/test_sim_core_source.py` | Scan thêm toàn bộ `mt5/Experts/*.mq5`; test token trailing; tổng 8 test |

**Bằng chứng build:**

- Compile `SimCoreTests.mq5`: `Result: 0 errors, 0 warnings, 1946 ms elapsed`;
  `SimCoreTests.ex5` 61,006 bytes.
- Compile `RunnerTrailingLabEA.mq5`: `Result: 0 errors, 0 warnings, 1291 ms elapsed`;
  `RunnerTrailingLabEA.ex5` 53,302 bytes.
- `pytest python/tests -q`: `273 passed` (272 W2 + test token trailing).
- Không có `OrderSend`, `CTrade`, `MqlTradeRequest` trong bất kỳ `.mq5` nào của `mt5/Experts` (test tĩnh).

**Bất biến đã encode:**

- `SimTrailingEvaluate` chỉ nhận candidate cải thiện: long `candidate > old_sl`, short `candidate < old_sl`;
  từ chối `not_improving` và `candidate_too_close`.
- Breakeven bật khi profit >= `breakeven_trigger`; clamp về `entry ± breakeven_offset`, không vượt entry.
- Gap qua SL: fill theo `min(bid, sl)` / `max(ask, sl)` rồi cộng slippage bất lợi; reason `SL_GAP`.
- EA chặn mọi entry khi RiskGuard `HALTED`; side filter và `InpMaxHoldingBars` có hiệu lực.
- `InpUpdateOnClosedBarOnly=true` chỉ cập nhật trailing khi sang bar mới.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Compile core + EA | PASS — 0 errors, 0 warnings |
| Chạy T1–T15 trong MT5 | `NOT_RUN` — cần terminal |
| Chạy EA trong Strategy Tester | `NOT_RUN` — cần terminal + dữ liệu lịch sử |
| CSV runtime | `NOT_RUN` |
| So khớp Python trailing simulator | Chưa làm; mô hình khác (Python dùng bar OHLC, EA dùng tick) |

**Bước thủ công:** mở MT5 → Strategy Tester → chọn `RunnerTrailingLabEA`, preset
`configs/sim/runner_trailing.json` → chạy ít nhất một kịch bản tăng/giảm/gap → kiểm tra tab Experts có
`LAB|INFO|runner|initialized` và CSV có đủ event `INIT/ENTRY/TRAIL/EXIT/SUMMARY`.

**Kết luận:** W3 `READY_FOR_MANUAL_VALIDATION`. Logic trailing có test vector thuần và compile sạch; toàn
bộ hành vi runtime vẫn là `NOT_RUN` cho tới khi chạy trong MT5.

**Bước kế tiếp:** W4 — `GridLabEA.mq5`.

## 28. W4 — GridLabEA (Track C) — 2026-10-28

**Mục tiêu:** lưới vị thế ảo một chiều có cap cứng về số tầng, volume từng tầng và tổng exposure; có
basket stop bắt buộc để không "gồng vô hạn".

**File thêm/sửa:**

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimGrid.mqh` | `SimGridPlanAdd`, `SimGridLevelPrice/NextLevelPrice`, `SimGridTriggered`, `SimGridTargetHit/StopHit` |
| `mt5/Include/Sim/SimPortfolio.mqh` | Thêm `CloseProfitableAtLeast` (đóng từng phần), `MinEntry`, `MaxEntry` |
| `mt5/Experts/GridLabEA.mq5` | Grid fixed/ATR, volume multiplier + clamp, exit LEVEL/BASKET, RiskGuard, CSV log |
| `mt5/Scripts/SimCoreTests.mq5` | Thêm P20–P22 (partial close), R21 (DCA cap 0), G1–G12; tổng 104 vector |
| `configs/sim/grid_lab.json` | Preset mẫu `SIMULATION_ONLY`, `allow_live_trading=false` |
| `docs/reference/simulation.md` | Input, luật, công thức cap, exit, event log, trạng thái |
| `python/tests/test_sim_core_source.py` | Test token grid + partial close; tổng 10 test |

**Bug phát hiện và sửa:** `CSimRiskGuard` chặn mọi entry khi `max_dca_adds=0` (`ctx.dca_adds >= 0` luôn
đúng), nghĩa là `RunnerTrailingLabEA` sẽ không bao giờ vào lệnh lúc runtime. Đã đổi thành chỉ kiểm tra khi
`max_dca_adds > 0`; thêm R21 để khóa hành vi "0 = tắt kiểm tra DCA"; EA DCA sẽ tự chặn add khi input 0.

**Bằng chứng build:**

- Compile `SimCoreTests.mq5`: `Result: 0 errors, 0 warnings, 2074 ms elapsed`;
  `SimCoreTests.ex5` 66,844 bytes.
- Compile `GridLabEA.mq5`: `Result: 0 errors, 0 warnings, 1588 ms elapsed`;
  `GridLabEA.ex5` 52,626 bytes.
- `pytest python/tests -q`: `275 passed` (273 W3 + 2 test token grid/partial close).

**Cap đã encode:**

- Số tầng: `next_level > InpMaxGridLevels` → `max_grid_levels_reached`; guard cũng đặt
  `max_virtual_positions = max_grid_levels = InpMaxGridLevels`.
- Volume tầng: `min(base * multiplier^(n-1), InpMaxLevelVolume)`.
- Exposure: `exposure + volume > InpMaxVirtualExposure` → chặn add, không chia nhỏ volume.
- `InpBasketStopPoints > 0` bắt buộc; target basket/level phải > 0 theo mode.
- Không mở tầng mới trên đúng bar vừa đóng basket.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Compile core + grid EA | PASS — 0 errors, 0 warnings |
| Chạy P20–P22, R21, G1–G12 trong MT5 | `NOT_RUN` — cần terminal |
| Chạy EA trong Strategy Tester | `NOT_RUN` — cần terminal + dữ liệu lịch sử |
| CSV runtime | `NOT_RUN` |
| So khớp Python bounded-basket simulator | Chưa làm; mô hình khác (bar OHLC vs tick) |

**Bước thủ công:** MT5 → Strategy Tester → `GridLabEA` + preset `configs/sim/grid_lab.json` → chạy kịch bản
đi ngang, xu hướng một chiều, gap; xác nhận CSV có `GRID_ADD` đúng thứ tự level và `GRID_BLOCKED` khi chạm
cap; không có dòng nào vượt `InpMaxGridLevels`/`InpMaxVirtualExposure`.

**Kết luận:** W4 `READY_FOR_MANUAL_VALIDATION`. Cap logic có unit test thuần và compile sạch; runtime vẫn
`NOT_RUN`.

**Bước kế tiếp:** W5 — `DCALabEA.mq5`.

## 29. W5 — DCALabEA (Track C) — 2026-10-28

**Mục tiêu:** các lần bổ sung vị thế ảo có cap cứng theo khoảng giá hoặc khoảng thời gian; không bình quân
vô hạn, không tự nới cap sau chuỗi thua, basket stop bắt buộc.

**File thêm/sửa:**

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimDca.mqh` | `SimDcaPlanAdd`, `SimDcaAddVolume`, trigger giá/bar, `SimDcaBarsSince` |
| `mt5/Experts/DCALabEA.mq5` | DCA price/bar trigger, một fill mỗi bar, basket target/stop, RiskGuard, CSV log |
| `mt5/Scripts/SimCoreTests.mq5` | Thêm D1–D19 (plan, trigger, basket P&L); tổng 123 vector |
| `configs/sim/dca_lab.json` | Preset mẫu `SIMULATION_ONLY`, `allow_live_trading=false` |
| `docs/reference/simulation.md` | Input, luật chạy, trigger/cap, exit, event log, trạng thái |
| `docs/reference/simulation.md` | Thêm mục 9 DCA, renumber Logger/Fingerprint/Build/Status, 123 vector, 12 test tĩnh |
| `python/tests/test_sim_core_source.py` | Thêm test token DCA + test EA giữ `max_dca_adds=0`; tổng 12 test |
| `python/tests/test_dca_vectors.py` | 4 test tính độc lập average entry, P&L target/stop, commission, đối chiếu literal vector MQL5 |

**Quyết định thiết kế:**

- Volume lần add thứ `n` = `base * multiplier^n`, clamp `InpMaxAddVolume`; vị thế đầu luôn dùng `base` và
  không tính là một lần add.
- `InpMaxDcaAdds = 0` → EA không add lần nào; guard nhận cùng giá trị và (sau R21) tắt kiểm tra DCA riêng,
  nên entry đầu vẫn mở được. EA tự chặn add trước khi gọi guard.
- Tối đa một fill mỗi bar: tick burst hoặc gap qua nhiều ngưỡng không thể add nhiều lần trong cùng bar.
- Guard nhận `max_virtual_positions = InpMaxDcaAdds + 1`, `max_grid_levels = 0`; exposure cap là lớp thứ hai
  sau `SimDcaPlanAdd`.
- Stop được kiểm tra trước target mỗi tick; stop/target bắt buộc > 0.

**Bằng chứng build:**

- Compile `SimCoreTests.mq5`: `Result: 0 errors, 0 warnings, 2239 ms elapsed`;
  `SimCoreTests.ex5` 73,288 bytes.
- Compile `DCALabEA.mq5`: `Result: 0 errors, 0 warnings, 1411 ms elapsed`;
  `DCALabEA.ex5` 47,120 bytes.
- `pytest python/tests -q`: `281 passed` (275 W4 + 2 test tĩnh DCA + 4 test vector DCA).

**Vector D1–D19 (tóm tắt):** base 0.1, mult 1.5 → add 1 = 0.15, add 3 = 0.3375; clamp add 2 từ 0.4 về 0.15;
`max_dca_adds` 0 và biên 1/1 đều `max_dca_adds_reached`; exposure `1.9+0.1=2.0` cho phép, `1.95+0.1` chặn;
trigger BUY 1.09 / SELL 1.11; bar 3×H1 = 10,800 giây; basket 0.10 @ 1.1000 + 0.15 @ 1.0700 → average 1.082,
target 1.112 = `+0.0075`, stop 1.032 = `-0.0125`, commission 0.5/volume → realized `-0.2425`.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Compile core + DCA EA | PASS — 0 errors, 0 warnings |
| Chạy D1–D19 trong MT5 | `NOT_RUN` — cần terminal |
| Chạy EA trong Strategy Tester | `NOT_RUN` — cần terminal + dữ liệu lịch sử |
| CSV runtime | `NOT_RUN` |
| P&L basket khớp Python | PASS — `python/tests/test_dca_vectors.py` (cùng vector D16–D19) |

**Bước thủ công:** MT5 → Strategy Tester → `DCALabEA` + preset `configs/sim/dca_lab.json` → chạy kịch bản
xu hướng một chiều, tick burst, gap và spread mở rộng; xác nhận CSV có `DCA_ADD` tăng dần, tối đa một dòng
mỗi bar, và `DCA_BLOCKED` với `max_dca_adds_reached`/`max_virtual_exposure_reached` khi chạm cap; không có
dòng nào vượt `InpMaxDcaAdds`/`InpMaxVirtualExposure`.

**Kết luận:** W5 `READY_FOR_MANUAL_VALIDATION`. Cap và trigger có unit test thuần, P&L basket có cross-check
Python; runtime vẫn `NOT_RUN`.

**Bước kế tiếp:** W6 — preset/config cho 3 EA và validator fail-closed.

## 30. W6 — Preset/config + validator fail-closed (Track C) — 2026-10-28

**Mục tiêu:** preset cho 3 EA, schema dự án gom preset + kịch bản test, và validator fail-closed chỉ nhận
`SIMULATION_ONLY`; snapshot config bất biến để report truy vết đúng cấu hình đã chạy.

**File:**

| File | Vai trò |
|---|---|
| `configs/sim/runner_trailing.json` | Preset Runner; thêm metadata `strategy/symbol/timeframe` |
| `configs/sim/grid_lab.json` | Preset Grid; thêm metadata tương tự |
| `configs/sim/dca_lab.json` | Preset DCA mới: side, trigger mode, base/add volume, basket target/stop |
| `configs/project.example.json` | 3 preset + 10 kịch bản (baseline/stress/edge cho từng EA) |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | DSL spec input + `validate_preset`, `validate_project`, `snapshot_path`, `write_snapshot` |
| `scripts/validate_sim_configs.py` | CLI quét preset + project, in PASS/FAIL và `SUMMARY: checked=N fail=M` |
| `python/tests/test_sim_configs.py` | 21 test: preset repo, fail-closed, khóa nhạy cảm, cross-field, scenario, snapshot |
| `docs/reference/simulation.md` | Schema, bảng cross-field, 10 kịch bản, chính sách snapshot, CLI |

**Quy tắc fail-closed:**

- `execution_mode` phải bằng đúng `SIMULATION_ONLY`; `allow_live_trading` phải là `false` (thiếu hoặc `true` đều fail).
- Top-level chỉ nhận `schema_version, ea, version, execution_mode, allow_live_trading, description,
  strategy, symbol, timeframe, inputs, enum_map, assumptions`; khóa lạ bị từ chối.
- Khóa khớp `login|password|passwd|investor|server|account|token|secret|credential|apikey|broker` bị từ chối ở
  mọi cấp, kể cả trong `inputs`.
- `inputs` phải khớp **đúng** tập input của EA tương ứng (thiếu/thừa đều fail); mỗi giá trị kiểm tra kiểu,
  khoảng, integer, exclusive-min theo spec phản chiếu `OnInit`.
- Cross-field: runner slow>fast, exposure≥volume, trail khoảng cách theo mode; grid volume/exposure≥base,
  spacing fixed>0, ATR period≥2 + mult>0, target>0 theo mode; DCA add/exposure≥base, price distance>0,
  bar count≥1, trigger mode hợp lệ.
- Project: `presets` phải map đủ 3 EA và trỏ đúng file tồn tại có `ea` khớp; scenario name khớp
  `[a-z0-9_]+`, không trùng; `overrides` phải là tập con input của EA và được merge rồi validate lại.

**10 kịch bản trong `configs/project.example.json`:**

| Kịch bản | EA | Trọng tâm |
|---|---|---|
| `runner_baseline` | Runner | Preset gốc |
| `runner_conservative_stress` | Runner | Volume/exposure/daily/dd/spread/cooldown chặt |
| `runner_edge_no_breakeven` | Runner | Tắt breakeven + `MaxHoldingBars=10` |
| `grid_baseline` | Grid | Preset gốc |
| `grid_conservative_stress` | Grid | 3 tầng, volume/exposure/risk chặt |
| `grid_edge_single_level` | Grid | `MaxGridLevels=1` |
| `dca_baseline` | DCA | Preset gốc |
| `dca_conservative_stress` | DCA | 2 add, mult 1.2, basket 300/400 |
| `dca_edge_no_adds` | DCA | `MaxDcaAdds=0` |
| `dca_edge_bar_trigger` | DCA | Trigger theo thời gian, 10 bar |

**Bằng chứng:**

- `.venv/Scripts/python.exe scripts/validate_sim_configs.py` →
  `SUMMARY: checked=4 fail=0`, exit 0.
- Snapshot sinh ra: `reports/config-snapshots/DCALabEA-2CF1CD9A.json`,
  `GridLabEA-996B8792.json`, `RunnerTrailingLabEA-3EC0E193.json`,
  `track-c-simulation-presets-A575EBD4.json`; chạy lại báo `(unchanged)` — nội dung bất biến, không ghi đè.
- `.venv/Scripts/python.exe -m pytest python/tests -q` → `302 passed`.
- Không có test nào nạp preset vào MT5; không có kết nối broker.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Validator preset + project | PASS — checked=4 fail=0 |
| Snapshot bất biến | PASS — 4 file, chạy lại `unchanged` |
| Fail-closed `execution_mode`/`allow_live_trading` | PASS — test parametrized |
| Nạp preset trong MT5 (`.set`/chart) | `NOT_RUN` — cần terminal |
| Strategy Tester theo 10 kịch bản | `NOT_RUN` — cần MT5 + dữ liệu lịch sử |

**Kết luận:** W6 PASS ở mức tĩnh (validator + test). Chưa có bằng chứng runtime.

**Bước kế tiếp:** W7 — script root dùng chung: check environment, build MQL5, chạy pytest, validate project,
package source.

## 31. W7 — Script root dùng chung (Track C) — 2026-10-28

**Mục tiêu:** một lớp script chung để kiểm tra môi trường, build toàn bộ MQL5, chạy pytest, validate tĩnh
toàn project và đóng gói source — tất cả offline, không mở terminal, không kết nối broker.

**File:**

| File | Vai trò |
|---|---|
| `scripts/check-environment.ps1` | 22 check: layout, Python ≥ 3.11, pytest, MetaEditor, quyền ghi `reports\`; không đọc nội dung file/secret |
| `scripts/build-mql5.ps1` | Tự tìm mọi `.mq5` dưới `mt5\`, xóa `.ex5` cũ, log riêng từng file, đọc dòng `Result:` |
| `scripts/run-python-tests.ps1` | Chọn venv, kiểm tra pytest, chạy từ root, giữ nguyên exit code |
| `scripts/validate-project.py` | Quét API giao dịch/broker, placeholder, layout Sim và preset trên toàn `mt5\` |
| `scripts/package-source.ps1` | Zip source + `MANIFEST.sha256`, loại `.venv`/cache/report/artifact, chặn secret |
| `python/tests/test_validate_project.py` | 6 test cho scanner/layout và một lần chạy validator trên repo thật |
| `python/tests/test_toolchain_scripts.py` | 6 test hợp đồng fail-closed của 5 script |
| `docs/guides/toolchain.md` | Cách chạy, exit code, quy tắc fail-closed, bằng chứng, giới hạn |

**Quy tắc fail-closed:**

- Build: thiếu log, thiếu `Result:`, errors/warnings > 0, hoặc không sinh `.ex5` đều fail dù CLI trả 0;
  ngược lại CLI trả 1 nhưng log 0/0 vẫn pass (MetaEditor hay trả 1 khi thành công).
- Validator: chặn `OrderSend*`, `CTrade`, `MqlTradeRequest/Result`, `Position*`, `Order*`, `WebRequest`,
  `Socket*`, `AccountInfo*`, `TerminalInfoString(TERMINAL_PASSWORD)` và include `Trade\*`/`Expert\*`;
  placeholder `TODO/FIXME/TBD/PLACEHOLDER/NOT_IMPLEMENTED` cũng fail.
- Package: chỉ lấy extension văn bản/source trong allow-list; loại theo segment (`.venv`, `__pycache__`,
  `.git`, `reports`, `data`, `models`, cache) và theo extension (`.ex5`, `.log`, `.zip`, `.onnx`, `.csv`,
  `.sqlite`, `.key`, `.pem`, ...); quét secret trước khi copy và dừng ngay nếu khớp.
- Không script nào chạy MT5, gọi `metatester64.exe`, đọc `accounts.dat`/`servers.dat` hay in biến môi trường.

**Bằng chứng chạy thật (2026-10-28):**

| Lệnh | Kết quả |
|---|---|
| `check-environment.ps1` | `SUMMARY: checks=22 fail=0`; `ENVIRONMENT_OK`; Python 3.11.9, pytest 9.1.1, MetaEditor 5.0.0.6249 |
| `build-mql5.ps1` | `BUILD_OK: 22 source(s) compiled with 0 errors and 0 warnings` |
| `run-python-tests.ps1` | `314 passed`; `TESTS_OK` |
| `validate-project.py` | `SUMMARY: checks=9 fail=0`; 40 source, 0 hit API/placeholder; 4 preset pass |
| `package-source.ps1 -Version 0.7.0` | 234 file; `PACKAGE_OK`; manifest 234 dòng; zip không có `.venv`/`.ex5`/log/report |
| `validate_sim_configs.py` | `SUMMARY: checked=4 fail=0` (snapshot `unchanged`) |

`.ex5` hiện tại: `SimCoreTests` 73,646; `RunnerTrailingLabEA` 52,622; `GridLabEA` 51,590; `DCALabEA`
47,606 byte. Byte size phụ thuộc bản MetaEditor/đường dẫn compile; dòng `Result:` trong log là bằng chứng
chính, nên các số trong báo cáo W1–W5 là ảnh chụp lịch sử.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| check environment | PASS — 22/22 |
| build toàn bộ MQL5 | PASS — 22/22, 0 errors, 0 warnings |
| pytest wrapper | PASS — 314 test |
| validate project (API/placeholder/preset) | PASS — checks=9 fail=0 |
| package source | PASS — 234 file, manifest SHA256 |
| Chạy script test/EA trong MT5 | `NOT_RUN` — cần thao tác thủ công |
| Strategy Tester | `NOT_RUN` — cần MT5 + dữ liệu lịch sử |

**Kết luận:** W7 PASS ở mức offline (compile + static + test + package). Không có bằng chứng runtime.

**Bước kế tiếp:** W8 — chạy Strategy Tester thủ công cho 3 EA theo 10 kịch bản; môi trường hiện tại không
tự chạy được nên sẽ ghi `NOT_RUN` kèm hướng dẫn, trừ khi có report thật do người dùng cung cấp.

## 32. W8 — Hướng dẫn Strategy Tester thủ công (Track C) — 2026-10-28

**Trạng thái: `NOT_RUN`.** Không có report Strategy Tester thật cho bất kỳ EA nào. Agent không mở terminal,
không điều khiển GUI, không chạy `metatester64.exe` và không đăng nhập tài khoản.

**Deliverable:**

| File | Nội dung |
|---|---|
| `docs/guides/strategy-tester.md` | Điều kiện, thông số tester, preset đầy đủ cho 3 EA, ma trận 10 scenario, invariant phải kiểm từ CSV, quy tắc PASS/FAIL/BLOCKED |
| `docs/guides/strategy-tester.md` | Template report: nhận dạng run, override, metric Results, bằng chứng CSV, 8 invariant, verdict |

**Điểm vận hành quan trọng:**

- EA simulation-only → tester hiển thị **0 deal** là đúng; bằng chứng nằm ở CSV và Journal.
- `SimLogger` mở file append, nên mỗi lần chạy phải dùng `InpLogFile` riêng.
- File CSV của tester nằm trong sandbox `Tester\Agent-*\MQL5\Files\`, không phải `MQL5\Files` của terminal chính.
- Thiếu history → `BLOCKED`; không đăng nhập broker chỉ để tải dữ liệu và không thay bằng synthetic.

**Trạng thái thật:**

| Hạng mục | Trạng thái |
|---|---|
| Hướng dẫn + template | PASS |
| `runner_baseline`, `runner_conservative_stress`, `runner_edge_no_breakeven` | `NOT_RUN` |
| `grid_baseline`, `grid_conservative_stress`, `grid_edge_single_level` | `NOT_RUN` |
| `dca_baseline`, `dca_conservative_stress`, `dca_edge_no_adds`, `dca_edge_bar_trigger` | `NOT_RUN` |
| Kết luận hiệu năng/P&L | Không có; chưa có report thật |

**Kết luận:** W8 `READY_FOR_MANUAL_VALIDATION` — tài liệu và template sẵn sàng, nhưng acceptance “có report
thật cho từng EA/kịch bản stress” chưa đạt và được ghi rõ là `NOT_RUN`.

**Bước kế tiếp:** W9 — bàn giao Track C: INSTALL_AND_TEST, risk, README, release checklist, PROGRESS.

## 33. W9 — Bàn giao Track C (docs, risk, checklist) — 2026-10-28

**Mục tiêu:** người khác có thể làm lại Track C từ môi trường sạch, phân biệt rõ phần tự động và phần thủ
công, không có tuyên bố runtime sai.

**File tạo/cập nhật:**

| File | Nội dung |
|---|---|
| `docs/guides/install-and-test.md` | Yêu cầu, setup, validate preset, copy/compile trong Data Folder, chạy `SimCoreTests`, chạy EA, đọc CSV, bảng tự động vs thủ công, troubleshooting, rollback |
| `docs/guides/strategy-tester.md` | Hướng dẫn Strategy Tester + preset đầy đủ + 10 scenario + invariant + pass criteria |
| `docs/guides/strategy-tester.md` | Template report để copy vào `reports/strategy-tester/` |
| `docs/guides/toolchain.md` | 5 script root, exit code, fail-closed, bằng chứng |
| `docs/reference/risk.md` | Thêm mục rủi ro Track C; sửa các câu cũ “chưa có MQL5/EA” và “4 file MQL5” |
| `docs/reference/release.md` | Cập nhật 314 test, 22 source, thêm mục preset/build/scan/package; thay mục Strategy Tester cũ; ghi manual `NOT_RUN` |
| `README.md` | Trạng thái Track C, 22 file `.mq5`, doc tree và link bàn giao; bỏ câu “không có MQL5/EA” |
| `mt5/README.md` | Link cài đặt/kiểm thử, Strategy Tester, toolchain; nhắc 0 deal |

**Phân loại tự động vs thủ công:**

| Việc | Trạng thái | Bằng chứng |
|---|---|---|
| Validate preset/scenario | Tự động, PASS | `validate_sim_configs.py` checked=4 fail=0 |
| Compile 22 `.mq5` | Tự động, PASS | `build-mql5.ps1` 0 errors/0 warnings |
| Static scan API/placeholder | Tự động, PASS | `validate-project.py` checks=9 fail=0 |
| Python tests | Tự động, PASS | 314 passed |
| `SimCoreTests` trong MT5 | **Thủ công, `NOT_RUN`** | Chưa có dòng `TEST\|RESULT\|ALL_PASS` thật |
| Strategy Tester 10 scenario | **Thủ công, `NOT_RUN`** | Chưa có report trong `reports/strategy-tester/` |
| Audit CSV thật | **Thủ công, `NOT_RUN`** | Chưa có CSV runtime |

**Kiểm tra lại sau khi cập nhật docs:**

- `scripts/check-environment.ps1` → `SUMMARY: checks=22 fail=0`.
- `scripts/validate-project.py` → `SUMMARY: checks=9 fail=0`.
- `scripts/run-python-tests.ps1` → 314 passed.
- `scripts/build-mql5.ps1` → 22 source, 0 errors, 0 warnings.
- `scripts/validate_sim_configs.py` → checked=4 fail=0, snapshot `unchanged`.
- `scripts/package-source.ps1 -Version 0.7.0` → 237 file, manifest SHA256; zip và hash in ở cuối mỗi lần chạy.

**Giới hạn bàn giao:**

- Chưa kiểm tra tái lập trên checkout commit sạch cho Track C vì các thay đổi chưa được commit. Khi commit,
  cần lặp lại: clone/checkout → venv → `run-python-tests.ps1` → `validate_sim_configs.py` → `build-mql5.ps1`.
- Không có số liệu P&L hay kết luận hiệu năng nào cho 3 EA; mọi kết quả runtime vẫn `NOT_RUN`.
- File CSV tester nằm trong sandbox agent và phải do người dùng thu thập; repo không tự đọc thư mục MT5.

**Kết luận:** W9 `READY_FOR_HANDOFF`. Track C hoàn tất phần offline (W1–W7, W9); W8 là hạng mục thủ công
`NOT_RUN` và được ghi rõ trong README, checklist, risk và hướng dẫn.

**Bước kế tiếp (khi có người chạy MT5):** chạy `SimCoreTests`, sau đó 10 scenario theo
`docs/guides/strategy-tester.md`, điền template và cập nhật trạng thái W8 từ `NOT_RUN` sang PASS/FAIL dựa trên
CSV thật.

## 34. W10 — PinePlanSimEA: EA mô phỏng theo trade plan — 2026-10-28

**Mục tiêu:** một EA mô phỏng duy nhất đọc trade plan của ba indicator PinePort (`PriceActionMTF`,
`TMXAUSignals2`, `TMIndicator2`) và mở một vị thế ảo cho mỗi tín hiệu biên hợp lệ. Không thêm API
giao dịch, không kết nối broker.

**Vì sao chỉ ba nguồn:** ba indicator cùng xuất plan tĩnh trên nến đã đóng (`PLAN_VALID`, `DIR`,
`ENTRY`, `SL`, `TP1..3`, tín hiệu biên). LongKaco VSA dùng máy trạng thái `FILL/RESULT`; TM Fusion
Zones dùng `POS_SIDE`/adoption. Gộp hai nguồn này vào EA plan chung sẽ tạo kết quả sai, nên để ngoài W10.

**Deliverable:**

| File | Nội dung |
|---|---|
| `mt5/Include/Sim/SimPlan.mqh` | `SimPlanResolveSide`, `SimPlanValidate`, `SimPlanTargetPrice/Hit/Fill` — thuần, không indicator |
| `mt5/Experts/PinePlanSimEA.mq5` | Đọc buffer qua `iCustom`, vị thế ảo, RiskGuard, breakeven/trailing tùy chọn, CSV 18 cột |
| `mt5/Scripts/SimPlanTests.mq5` | 39 vector: R1–R7 resolve, V1–V19 validate, T1–T13 target |
| `configs/sim/pine_plan_lab.json` | Preset baseline PA/TP1, `SIMULATION_ONLY`, `allow_live_trading=false` |
| `configs/project.example.json` | Thêm preset + `plan_baseline`, `plan_edge_tp3_stop_only` → 4 preset, 12 scenario |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | Schema `PinePlanSimEA`, cross-check exposure/BE/trail, enum source/filter/target |
| `python/tests/test_sim_configs.py` | Preset thứ 5 + test fail-closed cho plan |
| `python/tests/test_plan_sim_source.py` | 5 test tĩnh: input ↔ schema, include, buffer constant, purity, suite marker |

**Luật chính:**

- Side: PA dùng hai buffer `SIG_LONG`/`SIG_SHORT`; X2/TM2 dùng một tín hiệu biên + `DIR`.
  Hai tín hiệu cùng lúc → `ambiguous_signal`; `DIR` thiếu/lệch → `direction_missing`/`direction_conflict`.
- Validate plan theo thứ tự ổn định: `no_signal`, `plan_invalid`, `side_missing`, `side_filtered`,
  `point_invalid`, `min_stop_invalid`, `min_target_invalid`, `entry_invalid`, `sl_missing`,
  `sl_not_below_entry`/`sl_not_above_entry`, `stop_too_close`, `tp_not_finite`,
  `tp_not_above_entry`/`tp_not_below_entry`, `target_too_close`.
- Target gần nhất được dùng để kiểm `InpMinTargetPoints`; target mode `TP3` fallback TP2 rồi TP1;
  `NONE` chỉ có SL.
- Entry khớp tại ask/bid + slippage; `plan.entry` chỉ là `ref_entry`. SL kiểm trước target; target fill
  đúng target, không credit gap có lợi.
- Mỗi bar tín hiệu chỉ thử một lần; tối đa một vị thế ảo; RiskGuard chạy trước khi mở.

**Bằng chứng đã chạy:**

| Hạng mục | Trạng thái | Bằng chứng |
|---|---|---|
| Compile `PinePlanSimEA.mq5` | PASS | `reports/build-w10/Experts_PinePlanSimEA.mq5.log` → `Result: 0 errors, 0 warnings` |
| Compile `SimPlanTests.mq5` | PASS | `reports/build-w10/Scripts_SimPlanTests.mq5.log` → `Result: 0 errors, 0 warnings` |
| Compile toàn bộ | PASS | `build-mql5.ps1` → `BUILD_OK: 24 source(s) ..., 0 errors, 0 warnings` |
| Preset/validator | PASS | `validate_sim_configs.py` → `checked=5 fail=0`; snapshot PinePlan + project ghi mới |
| Static project scan | PASS | `validate-project.py` → `checks=10 fail=0` (43 source) |
| Python tests | PASS | `pytest -q` → `324 passed` |
| `SimPlanTests` trong MT5 | **PASS runtime** | `TEST\|RESULT\|ALL_PASS\|pass=39 fail=0\|suite=sim_plan` ngày 2026-10-28 18:41 (xem mục 37) |
| `PinePlanSimEA` trong Strategy Tester | **NOT_RUN** | Chưa có report/CSV runtime |

**Giới hạn:** iCustom dùng default input của indicator; plan có thể lỗi thời so với giá; không mô phỏng
partial fill/swap/margin; chưa có parity Pine; không có kết luận hiệu năng.

## 35. Hợp nhất tài liệu thành một bộ — 2026-10-28

**Vấn đề:** sau nhiều phase, `docs/` có nhiều file rời rạc trùng chủ đề (`sim-*`, `*-guide`,
`release-checklist`, `risk-and-limitations`, …), link chéo dễ lệch và khó kiểm tra.

**Cách làm:** backup `reports/backup-docs-20261028.zip`; gộp theo chủ đề với heading hạ một cấp để
giữ anchor; di chuyển file còn giá trị; xóa file đã gộp; dọn thư mục rỗng; thay tham chiếu đường dẫn
cũ bằng đường dẫn mới. Input pack (`MT5_AI_Roadmaps/`, `mt5-ea-ai-simulation-pack/`,
`pine-to-mt5-pack/`) giữ nguyên, không sửa.

**Kết quả:**

| Hạng mục | Số lượng |
|---|---:|
| File được gộp vào tài liệu đích | 12 |
| File được di chuyển vào cây mới | 13 |
| File rời rạc đã xóa sau khi gộp | 48 |

**Cây tài liệu mới:**

- `docs/README.md` — điểm vào duy nhất, bản đồ tài liệu, trạng thái và quy ước.
- `docs/guides/` — `install-and-test.md`, `strategy-tester.md`, `toolchain.md`.
- `docs/indicators/` — `README.md`, `parity.md` + 6 tài liệu indicator.
- `docs/reference/` — 14 tài liệu: architecture, strategy-signal-spec, simulation, trailing-stop,
  bounded-basket, testing, parity, risk, release, data-dictionary, experiment-store, ml-baseline,
  onnx, pipeline.
- `docs/` root còn roadmap, PROGRESS, prompt, decisions/, phase-reports/ và input pack.

**Kiểm tra sau hợp nhất:**

| Hạng mục | Kết quả |
|---|---|
| Markdown link nội bộ | `BROKEN 0` |
| Tham chiếu đường dẫn `docs/*.md` trong repo | `MISSING_TARGETS 0` |
| `validate-project.py` | `checks=10 fail=0`; bổ sung file bắt buộc mới và `PinePlanSimEA` |
| `validate_sim_configs.py` | `checked=5 fail=0` |
| `pytest -q` | `324 passed` |
| `build-mql5.ps1` | `24 source, 0 errors, 0 warnings` |

**Giới hạn:** hợp nhất không thay đổi nội dung kỹ thuật hay trạng thái runtime; mọi mục `NOT_RUN`/
`BLOCKED` vẫn giữ nguyên. Báo cáo phase lịch sử và input pack không được viết lại.

## 36. W12 — Kiểm tra toàn bộ và đóng gói — 2026-10-28

**Phạm vi:** chạy lại toàn bộ kiểm tra tự động sau W10 + hợp nhất docs; không chạy MT5, không kết nối
broker.

| Hạng mục | Kết quả | Bằng chứng |
|---|---|---|
| Compile toàn bộ `.mq5` | PASS | `build-mql5.ps1` → `BUILD_OK: 24 source(s) ..., 0 errors, 0 warnings` |
| Static scan API/placeholder | PASS | `validate-project.py` → `SUMMARY: checks=10 fail=0` (43 source) |
| Preset + scenario | PASS | `validate_sim_configs.py` → `SUMMARY: checked=5 fail=0`; snapshot lần đầu ghi mới, lần sau `unchanged` |
| Python test suite | PASS | `pytest -q` → `324 passed` trong 15.76s |
| Markdown link nội bộ | PASS | 243 link tương đối; `BROKEN 0` |
| Tham chiếu `docs/*.md` | PASS | `MISSING_TARGETS 0` |
| Đóng gói source | PASS | `package-source.ps1 -Version 0.8.0` → 220 file, zip + `MANIFEST.sha256` |

**Trạng thái runtime (cập nhật sau khi chạy thật trong MT5):**

| Hạng mục | Trạng thái |
|---|---|
| `SimCoreTests` (123 vector) | **PASS** — `pass=123 fail=0` ngày 2026-10-28 18:36 |
| `SimPlanTests` (39 vector) | **PASS** — `pass=39 fail=0` ngày 2026-10-28 18:41 (sau khi sửa 2 lỗi, xem mục 37) |
| 4 EA trong Strategy Tester (12 scenario) | **NOT_RUN** — chưa có report/CSV thật |
| Contract test của 6 indicator | **NOT_RUN** — cần chạy trong MT5 |
| Parity Pine/MQL5 | **BLOCKED** — thiếu CSV reference |

**Kết luận:** W10 và W11 hoàn tất phần tự động; W12 đã xác minh lại toàn bộ. Track C sẵn sàng cho
kiểm thử thủ công, không có tuyên bố hiệu năng hay sẵn sàng live. Không commit trong phiên này; người
dùng quyết định thời điểm commit.

**Bước kế tiếp (thủ công):**

1. Chạy 12 scenario Strategy Tester theo `docs/guides/strategy-tester.md`, lưu report + CSV.
2. Nếu có CSV Pine reference, chạy comparator parity và cập nhật `BLOCKED` → PASS/FAIL dựa trên số liệu thật.

## 37. Chạy self-check trong MT5 — 2026-10-28

**Mục tiêu:** chạy thật `SimCoreTests` và `SimPlanTests` trong terminal đang mở để xác nhận test suite,
thay vì chỉ dựa vào compile.

**Cách chạy:** terminal EXNESS đang mở nhưng **chưa đăng nhập** (log `authorization ... failed`), nên không
có thao tác tài khoản hay lệnh thật. Copy `mt5/Include/Sim/*.mqh` (10 file) và hai script vào Data Folder
`...\Terminal\53785E099C927DB68A545C249CDBCE06\MQL5\`, compile bằng MetaEditor CLI (`0 errors, 0 warnings`),
rồi chạy từ Navigator trên chart `XAUUSDm,M1` với "Allow Algo Trading" để trống. Script chạy một lần,
không đọc thị trường, không ghi file.

**Kết quả:**

| Script | Kết quả | Ghi chú |
|---|---|---|
| `SimCoreTests` | **PASS** `pass=123 fail=0` (18:36:55) | Khớp kỳ vọng, không cần sửa |
| `SimPlanTests` lần 1 | **FAIL** `pass=31 fail=8` (18:37:55) | V1, V2, V8, V14–V18 |
| `SimPlanTests` lần 2 | **FAIL** `pass=38 fail=1` (18:40:00) | Chỉ còn V18 |
| `SimPlanTests` lần 3 | **PASS** `pass=39 fail=0` (18:41:59) | Sau hai bản sửa |

**Lỗi tìm được và cách sửa:**

1. `SimPlanTests.RunValidate` dùng `point=0.01` trong khi vector thiết kế theo point 0.001 (V13 "0.5
   point", V16 "10 points", V18 "30 points"). Với point 0.01, các plan "valid" chỉ có stop 1 point nên bị
   chặn ở `stop_too_close` trước khi kiểm TP → 8 vector fail. Sửa hằng số thành `0.001`.
2. V18 đặt target đúng bằng ngưỡng 30 point; `1.13 - 1.1` trong double là `0.0299999...` nên bị coi là
   nhỏ hơn ngưỡng. Thêm dung sai `1e-9` vào hai phép so `stop_too_close`/`target_too_close` trong
   `SimPlan.mqh`, để biên đúng ngưỡng được chấp nhận (dung sai nhỏ hơn một point rất nhiều).

**Build lại:** `build-mql5.ps1 -Filter "Scripts\SimPlanTests.mq5"` và `"Experts\PinePlanSimEA.mq5"`,
cả hai `BUILD_OK: 1 source(s) ..., 0 errors, 0 warnings`.

**Bằng chứng:** ảnh tab Experts `reports/build/simplan-allpass.png` (crop
`reports/build/simplan-allpass-zoom3.png`), log compile `reports/build/simplan-tests-deploy3.log`.

**Chưa làm:** Strategy Tester cho 4 EA (0/12 scenario), contract test 6 indicator, parity Pine vẫn `BLOCKED`;
không có kết luận hiệu năng hay sẵn sàng live.

## 38. Package 0.8.1 sau hai bản sửa `SimPlan` — 2026-10-28

**Lý do:** package `v0.8.0` được tạo lúc 18:27, trước khi `SimPlanTests` chạy thật (18:37–18:41) và trước
hai bản sửa, nên zip 0.8.0 không khớp source hiện tại. 0.8.1 là bản khớp đúng source đã PASS self-check.

**Lệnh:** `powershell -ExecutionPolicy Bypass -File scripts\package-source.ps1 -Version 0.8.1`

**Kết quả:**

| Hạng mục | Giá trị |
|---|---|
| File | `reports/packages/mt5-ea-ai-lab-v0.8.1-<timestamp>.zip` (timestamp do script sinh) |
| Số file | 220 (MANIFEST 220 dòng), kèm `PACKAGE_INFO.txt` |
| SHA256 | in ra ở dòng `PACKAGE_SHA256` mỗi lần build; zip còn chứa `MANIFEST.sha256` để xác minh từng file |
| Quét secret | PASS — không dừng, không có file credential |
| Nội dung sửa | `mt5/Include/Sim/SimPlan.mqh` có `tolerance=1e-9`; `mt5/Scripts/SimPlanTests.mq5` dùng `point=0.001` (đã kiểm tra trực tiếp trong zip) |

**Không đổi:** vẫn không chứa `.ex5`, log, `reports`, dataset, model, `.venv` hay credential.

## 39. WonderwhalesSimEA — EA mô phỏng tín hiệu Wonderwhales trên XAUUSDm — 2026-10-28

**Yêu cầu:** dựa trên indicator Wonderwhales, tạo EA hỗ trợ backtest trên MT5, chỉ tập trung `XAUUSDm`.
Phạm vi được chấp nhận là **simulation-only**: EA mở vị thế ảo, không có API gửi lệnh thật.

**Đã tạo/sửa:**

| File | Nội dung |
|---|---|
| `mt5/Experts/WonderwhalesSimEA.mq5` | EA mới: đọc buffer WW tại `shift=1`, một vị thế ảo, SL PSAR/ATR%/fixed, exit-on-flip, max holding, RiskGuard, CSV 18 cột |
| `configs/sim/wonderwhales_xauusdm.json` | Preset `SIMULATION_ONLY`, `allow_live_trading=false`, 35 input khớp EA |
| `configs/project.example.json` | Thêm preset WW + 3 scenario: `ww_baseline`, `ww_conservative_stress`, `ww_edge_atr_stop` (tổng 15) |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | Registry input WW, kiểu `str_optional`, cross-check EMA/warmup/PSAR/exposure |
| `python/tests/test_sim_configs.py` | Thêm preset WW và 4 test (symbol guard, cross-check, enum) |
| `reports/build/tester-sets/ww_*.set` | 3 preset Strategy Tester, mỗi scenario một `InpLogFile` riêng |

**Bằng chứng chạy thật:**

| Lệnh | Kết quả |
|---|---|
| `build-mql5.ps1` (toàn repo) | 25 source, 0 errors, 0 warnings, `BUILD_OK` |
| MetaEditor CLI compile `WonderwhalesSimEA.mq5` (repo) | `Result: 0 errors, 0 warnings` |
| MetaEditor CLI compile trong Data Folder MT5 | `Result: 0 errors, 0 warnings`; `WonderwhalesSimEA.ex5` 57,968 bytes |
| Copy vào Data Folder | `MQL5\Experts\WonderwhalesSimEA.mq5`, 3 file `.set` trong `MQL5\Presets\` |
| `pytest -q` | `328 passed` |
| `validate-project.py` | `SUMMARY: checks=11 fail=0` |
| `validate_sim_configs.py` | `SUMMARY: checked=6 fail=0`; `presets=5 scenarios=15` |
| `package-source.ps1 -Version 0.8.2` | 222 file; zip + `MANIFEST.sha256` (không chứa `.ex5`, `.venv`, report, credential) |

**An toàn:** không có `OrderSend`, `CTrade`, `MqlTradeRequest` hay API position/order; không đọc account,
không lưu credential. `InpRequireSymbol=XAUUSDm` từ chối khởi tạo trên symbol khác.

**Chưa làm / `NOT_RUN`:** Strategy Tester cho 5 EA (0/15 scenario) và contract test 6 indicator vẫn cần
chạy thủ công; chưa có CSV runtime; parity Pine vẫn `BLOCKED`. Không có kết luận hiệu năng, lợi nhuận
hay sẵn sàng live.

> **Cập nhật (§40):** 3 scenario WW đã chạy thật, preset được calibration theo spec `XAUUSDm`, và EA được
> compile lại (`WonderwhalesSimEA.ex5` 57,522 bytes). Bảng bằng chứng ở trên là ảnh chụp trước đó.

## 40. Strategy Tester Wonderwhales — chạy thật và calibration `XAUUSDm` — 2026-10-28

**Bối cảnh:** người dùng đóng MT5 và yêu cầu chạy nốt Strategy Tester. Chạy headless bằng
`terminal64.exe /config:<ini>` (`ShutdownTerminal=1`), không nhập credential — terminal tự đăng nhập lại
tài khoản demo trên Exness-MT5Trial17.

**Phát hiện khi chạy lần đầu (1 tháng 09/2026):** cả 176 tín hiệu bị `ENTRY_BLOCKED|reason=spread_exceeded`.
Probe EA tạm (`ZZProbeSpread`, đã xoá sau khi dùng) in: `symbol=XAUUSDm|digits=3|point=0.00100000|
spread_int=260|ask_bid_points=260.00|stops_level=0|contract=100.00`. Nguyên nhân: `InpMaxSpreadPoints=200`
quá chặt so với spec thật. Không nới guard một cách tuỳ tiện; calibration theo số đo và ghi vào preset/docs.

**Thay đổi:**

| File | Nội dung |
|---|---|
| `mt5/Experts/WonderwhalesSimEA.mq5` | `InpFixedStopPoints` 300.0 → 3000.0; `InpMaxSpreadPoints` 200.0 → 600.0 |
| `configs/sim/wonderwhales_xauusdm.json` | Giá trị mặc định mới + `assumptions.symbol` ghi spec thật (3 digits, point 0.001, contract 100, spread ~260) |
| `configs/project.example.json` | `ww_conservative_stress` override spread 100 → 400 |
| `docs/guides/strategy-tester.md` | §4.5/§8 cập nhật; thêm §9 kết quả thật + ghi chú `Profiles\Tester` vs `Presets` |

**Thiết lập chạy:** `XAUUSDm` M15, 2026.01.05–2026.10.01, model "1 minute OHLC", deposit 10,000 USD,
leverage 1:100, build 6249, 17,595 bar M15 (1,053,473 tick). Mỗi scenario dùng `InpLogFile` riêng; `.set`
đặt trong `MQL5\Profiles\Tester\`.

**Kết quả thật:**

| Scenario | hash | Trades | W/L | Net (model) | Max DD | Blocks |
|---|---|---:|---|---:|---:|---|
| `ww_baseline` | `6E969FE1` | 869 | 318/551 | +26.97 | 0.85% | 0 |
| `ww_conservative_stress` | `69086031` | 787 | 276/511 | −7.50 | 0.46% | 139 (134 cooldown, 5 spread) |
| `ww_edge_atr_stop` | `C9EABF3B` | 795 | 390/405 | +24.96 | 0.88% | 0 |

**Audit CSV:** `config_hash` đồng nhất trong từng file; SL luôn đúng phía entry; entry/exit cân bằng ở
`ww_edge_atr_stop` (795/795) và lệch đúng 1 ở baseline/stress (870/869, 788/787 → còn 1 vị thế ảo mở cuối
kỳ); block reason khớp RiskGuard. CSV và report archived (gitignored) trong
`reports/build/tester-reports/<scenario>/`.

**Gate sau calibration (chạy lại toàn bộ):**

| Lệnh | Kết quả |
|---|---|
| `pytest -q` | `328 passed` |
| `compileall python/src python/tests scripts` | exit 0 |
| `validate-project.py` | `SUMMARY: checks=11 fail=0` |
| `validate_sim_configs.py` | `SUMMARY: checked=6 fail=0`; snapshot WW mới `C25B3983` (preset đổi giá trị), project `F458630D` |
| `build-mql5.ps1` | 25 source, 0 errors, 0 warnings, `BUILD_OK` |
| `package-source.ps1 -Version 0.8.3` | 222 file; sha256 `f772277f…572645`; không chứa `.ex5`, `.venv`, report, credential |

**Giới hạn:** P&L theo contract size 1 của model (broker contract 100); spread đo một thời điểm; một
symbol/timeframe/giai đoạn demo; tester hiển thị 0 deal vì EA không gửi lệnh. Không suy ra lợi nhuận,
lot thật hay độ sẵn sàng live. 12 scenario còn lại và contract test 6 indicator vẫn `NOT_RUN`; parity
Pine vẫn `BLOCKED`.

## 41. 12 scenario còn lại + 6 contract test — chạy thật — 2026-10-28

**Bối cảnh:** tiếp tục từ §40 theo yêu cầu "tự động làm lần lượt tất cả các mục còn lại". Chạy headless
`terminal64.exe /config:<ini>` như §40, không credential trong ini. `.set` stage trong repo rồi `cp` sang
`MQL5\Profiles\Tester\` (headless chỉ đọc thư mục này; GUI "Load" đọc `MQL5\Presets\`).

**Calibration spread cho 4 preset còn lại:** preset runner/grid/DCA/plan còn dùng `max_spread_points=200`
như WW trước calibration, trong khi spread đo thật của `XAUUSDm` là ~260 point → mọi entry sẽ bị chặn.
Đặt base **600**, stress **400** (stress chặt hơn base 200 point, vẫn trên spread đo), ghi vào preset JSON
và `reports/build/tester-sets/*.set`. Tester dùng chung `XAUUSDm` M15, 2026.01.05–2026.10.01, model 1-min
OHLC, deposit 10,000 USD, leverage 1:100, build 6249, 17,595 bar. Mỗi scenario một `InpLogFile` riêng.

**Kết quả 10/10 scenario còn chạy được (model units, contract size 1):**

| Scenario | Kết luận | Số liệu SUMMARY |
|---|---|---|
| `runner_baseline` | HALTED | 54 trades (5/49), net −467.63, DD 5.09%, 279 blocks |
| `runner_conservative_stress` | HALTED | 36 trades (3/33), net −192.06, DD 2.19%, 301 blocks |
| `runner_edge_no_breakeven` | HALTED | 70 trades (27/43), net −464.69, DD 5.12%, 263 blocks |
| `grid_baseline` | ACTIVE | 24,052 levels, 17,581 baskets, net +1,355.49, DD 1.13%, 12 blocks |
| `grid_conservative_stress` | ACTIVE | 22,916 levels, 17,513 baskets, net +422.91, DD 0.29%, 80 blocks |
| `grid_edge_single_level` | HALTED | 11,018 levels/baskets, net −496.85, DD 5.00%, 6,575 blocks |
| `dca_baseline` | HALTED | 11,012 baskets, net −497.06, DD 5.00%, 6,581 blocks |
| `dca_conservative_stress` | HALTED | 6,098 baskets, net −200.06, DD 2.00%, 11,497 blocks |
| `dca_edge_no_adds` | HALTED | 11,018 baskets, net −496.85, DD 5.00%, 6,575 blocks |
| `dca_edge_bar_trigger` | HALTED | 11,018 baskets, net −496.85, DD 5.00%, 6,575 blocks |

HALTED ở đây là RiskGuard dừng EA theo drawdown/ngày; ACTIVE là chạy hết kỳ không chạm guard. Không có
kết luận lợi nhuận: grid "dương" do mô hình mở/đóng level liên tục trong 9 tháng với contract size 1 và
spread giả định, chưa phải kết quả giao dịch thật.

**2 scenario plan — `BLOCKED_PERFORMANCE`:**

| Scenario | Trạng thái | Bằng chứng |
|---|---|---|
| `plan_baseline` | BLOCKED_PERFORMANCE | CSV chỉ có dòng `INIT`, không có `SUMMARY`; dừng sau ~13 phút chưa hết 9 tháng |
| `plan_edge_tp3_stop_only` | BLOCKED_PERFORMANCE | không sinh CSV trong thời gian chạy |

Chẩn đoán tách biệt 1 tháng (`diag_plan_1m`): chạy **197 s** và kết thúc sạch với
`source=PriceActionMTF|entries=0|rejected=0|trades=0|net=0.00`. Không phải treo, mà là chi phí tính toán:
`PinePlanSimEA` gọi `PriceActionMTF` với cấu trúc ~O(n²) trên mỗi bar (17,595 bar × 9 tháng), nên 9 tháng
không kịp trong cửa sổ chạy. Ghi nhận là giới hạn hiệu năng, không phải PASS/FAIL chiến lược; tối ưu
PriceActionMTF là việc riêng.

**Bug báo cáo DCA:** `SUMMARY` của `dca_baseline` ghi `adds=0`, nhưng CSV có 2 dòng `ENTRY` nối basket với
volume 0.15 rồi 0.225 → counter `adds` bị reset khi basket đóng, không phải EA không add. Đã đối chiếu CSV
và ghi nhận là bug reporting; **không sửa** trong phạm vi này (sửa sẽ đổi SUMMARY của 4 scenario vừa chạy).

**6 contract test indicator — lần chạy thật đầu tiên:** wrapper tạm `ZZContract_*` (rename `OnStart` →
`RunAllTests`, chạy một lần từ `OnTick` có guard) compile bằng MetaEditor CLI (`0 errors, 0 warnings` cho
cả 6) và chạy trong Strategy Tester trên `XAUUSDm` M1, 2026.01.05–01.06. Wrapper include
`../Include/PinePort/*.mqh` từ **bản deploy trong Data Folder**, nên phải copy header đã sửa sang đó trước
khi compile lại.

| Suite | Lần đầu | Sau sửa | Nguyên nhân lần đầu fail |
|---|---|---|---|
| `Wonderwhales` | 36/0 PASS | 36/0 PASS | — |
| `LongKacoVSA` | 45/2 FAIL | 47/0 PASS | biên float: `100.0*2.2 == 220.00000000000003` |
| `TMFusionZones` | 80/2 FAIL | 82/0 PASS | **bug**: RMA seed bỏ qua chuỗi na → ADX rỗng toàn bộ; K5 kỳ vọng sai (spec = 85) |
| `TMXAUSignals2` | 97/10 FAIL | 107/0 PASS | **bug**: FVG thiếu guard na + điều kiện gate chết; vector thiếu `prevClose`; biên float; config test sai |
| `PriceActionMTF` | 116/4 FAIL | 120/0 PASS | **bug**: EMA signal của MACD thiếu seed → hist rỗng; literal bị cắt; harness reset giá trị; bảng spec mâu thuẫn |
| `TMIndicator2` | 148/7 FAIL | 155/0 PASS | vector test dùng sai config/giá trị biên |

Tổng sau sửa: **547 check, 6/6 PASS**. Ba bug implementation thật được sửa trong
`TMFusionZonesContract.mqh` (seed RMA na-aware), `PriceActionMTFContract.mqh` (seed EMA signal) và
`TMXAUSignals2Contract.mqh` (guard na + gate FVG). Bằng chứng: `reports/build/contract-reports/results.txt`
cùng HTM/PNG từng suite. Wrapper và `.ini` tạm đã xoá khỏi `MQL5\Experts` và staging.

### 41.1 Gate sau toàn bộ thay đổi

| Lệnh | Kết quả |
|---|---|
| `pytest -q` | `328 passed` (16.07 s) |
| `compileall python/src python/tests scripts` | exit 0 |
| `validate-project.py` | `SUMMARY: checks=11 fail=0` |
| `validate_sim_configs.py` | `SUMMARY: checked=6 fail=0`; presets=5, scenarios=15; snapshot mới `PinePlanSimEA-B2FDB097`, `RunnerTrailingLabEA-D3165082`, `track-c-simulation-presets-85840B47`; WW `C25B3983` không đổi |
| `build-mql5.ps1` | 25 source, 0 errors, 0 warnings, `BUILD_OK` |
| `package-source.ps1 -Version 0.8.4` | `mt5-ea-ai-lab-v0.8.4-20261028-215649.zip`, 222 file; sha256 `ad141f25…c626083`; không chứa `.ex5`, `.venv`, report, credential |

**Giới hạn:** kết quả scenario là của model (contract size 1, spread giả định theo preset), một
symbol/timeframe/giai đoạn demo; EA không gửi lệnh nên tester hiển thị 0 deal. Không suy ra lợi nhuận,
lot thật hay độ sẵn sàng live. Parity Pine vẫn `BLOCKED`; indicator gắn chart và EA multi-source vẫn
`NOT_RUN`.


## 42. PA TrendRider XAU v1 — triển khai mô phỏng và kiểm thử thật — 2026-10-28

**Yêu cầu:** đọc `docs/PA_TrendRider_XAU_V1_Specification_Vietnamese.md`, lập kế hoạch, tự triển khai
và chạy test, tổng hợp kết quả.

**Cách hiểu phạm vi:** đặc tả mô tả EA dùng `OrderCalcProfit/Margin`, position/account API và demo
forward test. Repo bị ràng buộc simulation-only (`decisions/0002`), nên bản triển khai dùng vị thế ảo,
lot theo tick size/value và ghi rõ các mục live là `BLOCKED` thay vì giả lập API bị cấm.

### 42.1 Deliverable

| Hạng mục | File |
|---|---|
| 12 module chiến lược | `mt5/Include/TrendRider/TRTypes…TRMarketData.mqh` |
| EA mô phỏng | `mt5/Experts/PATrendRiderXAUv1SimEA.mq5` |
| Contract suite 82 vector | `mt5/Scripts/TrendRiderContractTests.mq5` |
| Preset + 2 scenario | `configs/sim/pa_trendrider_xau.json`, `configs/project.example.json` |
| Validator tĩnh + pytest | `scripts/validate_trendrider.py`, `python/tests/test_trendrider.py` |
| Tài liệu | `docs/PA_TrendRider_XAU_V1_Implementation_Vietnamese.md`, guide Track C |
| Bằng chứng chạy | `reports/build/tester-reports/{contract_trendrider,pa_trendrider_baseline,pa_trendrider_cost_stress}/` |

Core dùng chung được mở rộng tương thích ngược: `CSimPortfolio.InitWithContractSize` để P&L mô phỏng
XAUUSDm (contract 100) khớp lot tính theo tick; `Init(balance)` vẫn giữ contract size 1 cho các EA cũ.
Vector P23/P24 thêm vào `SimCoreTests`.

### 42.2 Kiểm thử và bằng chứng

| Lần chạy | Kết quả |
|---|---|
| Compile repo | 27 source, **0 errors, 0 warnings**, `BUILD_OK` |
| Compile Data Folder (EA + wrapper) | **0 errors, 0 warnings** |
| `TrendRiderContractTests` | **ALL_PASS pass=82 fail=0** (lần đầu 77/4 do vector sai; lần hai 80/1 do float floor; lần ba 81/1 do include cũ; lần bốn PASS) |
| `SimCoreTests` | **ALL_PASS pass=125 fail=0** (gồm contract size) |
| Baseline `XAUUSDm` M5 2026.01.05–03.05, deposit 5 000 | 4 entry/4 exit, 0 thắng/4 thua, net **−36.72**, DD **0.93%**, 6 lần cooldown, 22 setup `lot_rejected` |
| Cost stress (commission 5/lot, slippage 20 điểm, deposit 5 000) | 4 entry/4 exit, 0 thắng, net **−37.28**, DD **0.94%**, 60 lần chặn spread |
| Chạy lại baseline | Cùng `config_hash=5935E19B`, cùng 4 lệnh, cùng −36.72, CSV SHA256 trùng → tái lập được |
| Audit CSV | 18 cột; ENTRY/EXIT khớp; BUY SL<entry; `tp=0`; trail siết SL; 0 vị thế mở cuối kỳ |

Lỗi thật phát hiện và sửa trong quá trình chạy:

1. **BOS phát lại khi cửa sổ trượt** — dedupe theo index (index đổi khi thêm nến) → dedupe theo
   `swing.time`; BOS 3423 → 952, thêm vector B9.
2. **BOS treo vô hạn** — setup không hết hạn, ~10 700 dòng chặn → xóa BOS khi `bos_too_old` hoặc
   `ZONE_INVALIDATED`.
3. **Tiền tố reason lặp** `ENTRY_BLOCKED|reason=ENTRY_BLOCKED|reason=…` → chuẩn hóa.
4. **`TRLoadClosedBars` bỏ nến đóng mới nhất** → đọc đủ `copied` nến, kiểm tra khớp `iTime(...,1)`.

### 42.3 Gate cuối

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **341 passed** (14.69 s) |
| `compileall python/src python/tests scripts` | exit `0` |
| `scripts\validate-project.py` | `SUMMARY: checks=12 fail=0` |
| `scripts\validate_sim_configs.py --no-snapshot` | `SUMMARY: checked=7 fail=0`; 6 preset, 17 scenario |
| `scripts\validate_trendrider.py` | `SUMMARY: checks=7 fail=0` |
| `scripts\build-mql5.ps1` | 27 source, 0/0, `BUILD_OK` |

### 42.4 Giới hạn trung thực

- Mẫu 2 tháng, một symbol, model 1-minute OHLC, một bộ tham số chưa tối ưu; lỗ nhẹ **không** chứng minh
  chiến lược tốt/xấu và không phải khuyến nghị giao dịch.
- Không có OrderCalcProfit/Margin, margin check, netting/hedging, account currency, swap; tester hiển
  thị 0 deal. Out-of-sample, tối ưu tham số và demo forward test: `NOT_RUN`/`BLOCKED`.
- Balance 5 000 USD + risk 0.25% (12.50 USD) chỉ chịu được stop tới ~12.5 USD với lot tối thiểu 0.01
  của XAUUSDm; 22 setup rộng hơn bị EA từ chối đúng với `min_volume_exceeds_risk`. Đây là quyết định
  sản phẩm (balance/risk/lot), không được che bằng cách hạ chuẩn lot.
- Agent tester xóa sandbox `MQL5\Files` đầu mỗi lượt; CSV baseline lần đầu bị mất và phải chạy lại.
  Quy trình chuẩn từ nay: copy bằng chứng ngay sau khi terminal thoát.

### 42.5 Package

`package-source.ps1 -Version 0.9.1` → `mt5-ea-ai-lab-v0.9.1-20261029-081621.zip`, 241 file, 168 mục bị
loại (report, `.ex5`, cache, credential), SHA256 `a90d633e…65e3b8`. Zip không chứa CSV/report tester;
bằng chứng runtime nằm trong `reports/build/tester-reports/` (gitignored). Bản chạy 10 000 USD trước khi
hạ vốn được giữ ở `pa_trendrider_baseline_10k/` và `pa_trendrider_cost_stress_priordeposit/`.

## 43. ADR 0003 — demo execution có guardrail, cài lại MT5 và phiên demo thật đầu tiên — 2026-10-29

### 43.1 Thay đổi phạm vi

[`decisions/0003-demo-execution-scope.md`](decisions/0003-demo-execution-scope.md) thay mục 1/2/6 của
ADR 0002: đường duy nhất được gửi lệnh là `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` qua
`mt5/Include/Exec/*`, **chỉ** khi `ACCOUNT_TRADE_MODE_DEMO` (hoặc Strategy Tester) và
`InpEnableExecution=true`. Tài khoản real/live vẫn cấm và cần ADR mới; năm EA mô phỏng giữ nguyên
simulation-only. Policy được cập nhật đồng bộ ở `AGENTS.md`, `README.md`, `docs/README.md`,
`docs/reference/risk.md`, `docs/ROADMAP_MT5_EA_AI_LAB.md` và `docs/PROMPT_AI_IMPLEMENT_ROADMAP.md`.

### 43.2 Mã và validator mới

| Thành phần | Vai trò |
|---|---|
| `mt5/Include/Exec/ExecGuard.mqh` | `ExecContextAllowed`: demo/tester + `ACCOUNT_TRADE_ALLOWED` + `TERMINAL_TRADE_ALLOWED`, symbol allow-list, kill switch |
| `mt5/Include/Exec/ExecBroker.mqh` | Duyệt order/position theo magic, SL/TP bắt buộc, lot từ ngân sách rủi ro, sửa SL/TP một lần |
| `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` | Cùng engine TrendRider với bản mô phỏng; dry-run mặc định; journal 18 cột |
| `mt5/Scripts/ExecGuardTests.mq5` | Matrix guard (51 check) chạy trong MetaEditor |
| `configs/demo/pa_trendrider_xau_demo.json` | Preset `DEMO_ONLY`, `InpEnableExecution=false`, magic `25002001` tách khỏi bản sim |
| `scripts/validate_demo_execution.py` | Gate tĩnh: preset demo, cấu trúc EA, không có API ngoài scope |
| `scripts/validate-project.py` | `EXEC_SOURCES` allow-list: OrderSend/CTrade chỉ hợp lệ trong 4 file exec; `WebRequest`/socket/`AccountInfoString` cấm ở mọi nơi |

### 43.3 Cài lại MT5 và redeploy

App được cài lại nên hai thứ đổi: MetaEditor chuyển sang `C:\Program Files\MetaTrader 5 EXNESS\` và Data
Folder được tạo mới (`%APPDATA%\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06`) — cây `MQL5\` không
còn nguồn của dự án. Repo không bị ảnh hưởng.

`scripts/deploy_pineport.ps1` được mở rộng để một lệnh dựng lại toàn bộ: ngoài 22 file PinePort cũ, nó liệt
kê cả cây `Include\Sim`, `Include\TrendRider`, `Include\Exec` (enum theo thư mục để module mới không bị bỏ
sót) và thêm 12 target compile. Kết quả 2026-10-29: **56 file** được theo dõi, **25 target compile 0 errors
0 warnings**, `DEPLOY_OK`. Dry-run hiện tại báo `identical` cho cả 56 file. Docs dùng path cũ
(`docs/guides/demo-execution.md` §3, `docs/guides/install-and-test.md`) đã sửa sang bản Exness và ghi rõ
hãy chạy `scripts/check-environment.ps1` (script này dò cả hai vị trí).

Hai phát hiện runtime khi thao tác với terminal đang mở:

- Navigator không tự nạp `.ex5` mới; phải chuột vào node → **Refresh**.
- `SimLogger.Open` thiếu `FILE_SHARE_READ` khiến tool bên ngoài không đọc được CSV đang mở
  ("Device or resource busy"). Đã thêm cờ này trong `mt5/Include/Sim/SimLogger.mqh`; đây là thay đổi code
  duy nhất của giai đoạn, phục vụ giám sát phiên demo có người trông.

### 43.4 Gate sau cài lại

| Lệnh | Kết quả |
|---|---|
| `.venv\Scripts\python.exe -m pytest -q` | **358 passed** (15.15 s) |
| `scripts\validate-project.py` | `SUMMARY: checks=14 fail=0` (forbidden API + placeholder scan trên 62 source) |
| `scripts\validate_sim_configs.py --no-snapshot` | `SUMMARY: checked=7 fail=0`; 6 preset, 17 scenario |
| `scripts\validate_trendrider.py` | `SUMMARY: checks=7 fail=0` |
| `scripts\validate_demo_execution.py` | `SUMMARY: checks=6 fail=0` |
| `scripts\build-mql5.ps1` | **29 source, 0 errors, 0 warnings**, `BUILD_OK` |
| `scripts\deploy_pineport.ps1` | `DEPLOY_OK`; dry-run 56 file `identical`, 25 target 0/0 |
| `ExecGuardTests.mq5` chạy trong terminal | `TEST\|RESULT\|ALL_PASS\|pass=51 fail=0\|suite=execguard` |

Test mới trong `python/tests/test_validate_project.py` chứng minh allow-list đi đúng hai chiều: `OrderSend`
chỉ được phép trong `EXEC_SOURCES`, còn `WebRequest` vẫn bị chặn ngay cả trong file exec.

### 43.5 Phiên demo thật trên tài khoản 464140826

Tài khoản là **demo** (`Exness-MT5Trial17: Demo Account - Hedge`, balance 5 000 USD), xác nhận qua tiêu đề
cửa sổ terminal; không nhập hay lưu credential nào. Đây là bằng chứng runtime đầu tiên của đường demo —
trước đây mọi mục ở phần này là `NOT_RUN`.

1. **Dry-run** (`InpEnableExecution=false`, `config_hash=8A85E0D5`):
   `INIT mode=DRY_RUN state=WAITING_FOR_SETUP symbol=XAUUSDm magic=25002001 tp_r=3.00 equity=5000.00` →
   `REGIME regime=RANGE bias=timeframe_conflict h1=UNKNOWN m15=BEARISH` →
   `RISK ENTRY_BLOCKED reason=bias_unknown spread_points=240.0 atr=6.20042857` →
   `SUMMARY entries=0 exits=0 wins=0 losses=0 net=0.00 balance=5000.00 equity=5000.00 kill_switch=0`.
   Tab Trade trống — đúng hành vi.
2. **Guard fail-closed đã bắt thật**: lần gắn EA đầu tiên in
   `LAB|ERROR|trendrider_demo|scope_rejected|terminal_trade_disabled|this EA runs on demo or tester accounts only`
   và `initializing ... failed with code 1`, vì nút Algo Trading của terminal đang tắt. Bật nút đó thì EA
   khởi tạo bình thường. Hệ quả thực tế: **dry-run cũng cần Algo Trading bật**, vì guard kiểm
   `TERMINAL_TRADE_ALLOWED` trước khi xét chế độ dry-run.
3. **Execution** (`InpEnableExecution=true`, `config_hash=6B439450`): `INIT mode=DEMO_EXECUTION restored=1`
   rồi `REGIME regime=RANGE bias=range_both h1=UNKNOWN m15=UNKNOWN`. State file
   `pa_trendrider_demo_state.csv`: `ledger day_start=5000.00000000 peak=5000.00000000 streak=0 dd_locked=0`.
   Chưa có dòng `ENTRY`/`EXIT` nào.
4. **Tín hiệu runtime thật tiếp theo** (chart đã chuyển sang `XAUUSDm,M5`): `BOS tf=M5 event=BOS_BEAR`
   ngay sau đó `RISK SELL ENTRY_BLOCKED reason=regime_range regime=RANGE spread_points=240.0` — engine phát
   hiện break-of-structure và **chặn** vì H1/M15 vẫn `RANGE`, đúng luật "không vào lệnh trong vùng tích lũy".
5. **`ExecGuardTests` trong terminal**: `TEST|BEGIN|suite=execguard` → `TEST|G1..G51|PASS` →
   `TEST|RESULT|ALL_PASS|pass=51 fail=0|suite=execguard` (log `MQL5\Logs\20261029.log`, 09:32:46). Script là
   synthetic — nó chỉ gọi `ExecGuard` với dữ giả, không `OrderSend` — nên PASS này chứng minh ma trận guard,
   **không** chứng minh đường gửi lệnh thật của `ExecBroker.mqh`.

`RISK` chỉ ghi khi reason chặn đổi (`reason==g_last_block_reason` → return) và `REGIME` chỉ ghi khi regime
đổi, nên CSV đứng yên nhiều phút là **bình thường**, không phải EA treo; H1/M15 đang `UNKNOWN`/`RANGE` nên
chưa có setup hợp lệ.

### 43.6 Giới hạn trung thực

- Chưa có lệnh nào được gửi; phiên execution mới bắt đầu và **không** chứng minh chiến lược có lợi nhuận.
  0 entry là kết quả hợp lệ, không phải thành tích.
- `ExecGuardTests` đã chạy thật: `pass=51 fail=0` (2026-10-29). Vì script synthetic nên **đường `OrderSend`
  thật của `ExecBroker.mqh` vẫn chưa có bằng chứng runtime** — cần một `ENTRY` thật trên demo để đóng mục này.
- Kill switch (`PA_TREND_RIDER_DEMO_STOP.txt`) mới được kiểm ở mức token (`G46`), chưa thử bằng file thật.
- Chart gắn EA hiện là `XAUUSDm,M5` (trước đó `H1`); logic không phụ thuộc timeframe chart vì EA tự lấy
  H1/M15/M5 theo input và phát hiện bar mới theo `InpEntryTF`. Chuyển timeframe chỉ làm EA nạp lại.
- Một phiên demo, một symbol, một bộ tham số; kết quả chỉ có giá trị dry-run/giám sát, không phải điều kiện
  để chạy live.

### 43.7 Package

`package-source.ps1 -Version 0.10.0` → `mt5-ea-ai-lab-v0.10.0-20261029-091656.zip`, 250 file, 173 mục bị
loại (report, `.ex5`, cache, credential), SHA256 `d1b132d0…0d6398`.

---

## 44. Bằng chứng đường `OrderSend` thật + kill switch bằng file thật — 2026-10-29

§43 để lại hai khoảng trống: (a) `ExecGuardTests` synthetic nên đường gửi lệnh của
`mt5/Include/Exec/ExecBroker.mqh` chưa có bằng chứng runtime, và (b) kill switch mới thử ở mức token
(`G46`). Cả hai đã đóng bằng chạy thật.

### 44.1 Strategy Tester với `InpEnableExecution=true`

Bằng chứng lưu ở `reports/build/tester-reports/demo_exec_gui_20261029/` (`pa_trendrider_demo.csv`
18 281 641 byte, `pa_trendrider_demo_state.csv`, `audit_exec_csv.py`). Cấu hình: `XAUUSDm`, deposit
5 000, `config_hash=6B439450`, khoảng kiểm thử `2026.01.01 00:00` → `2026.10.27 23:59`,
**61 189 dòng journal**.

| Event | Số dòng | Ghi chú |
|---|---:|---|
| `INIT` / `SUMMARY` | 1 / 1 | một phiên khép kín |
| `REGIME` / `RISK` / `BOS` | 1 458 / 51 287 / 8 242 | chỉ ghi khi trạng thái/reason đổi |
| `ENTRY` | **31** | cả 31 đều `ORDER_FILLED\|order=N\|deal=N\|ok\|done` |
| `TRAIL` | 34 | chỉ siết SL (break-even + trailing) |
| `EXIT` | **31** | 30 `broker_close` (SL/TP broker khớp) + 1 `reversal_BEARISH` |
| `CLOSE_REQUEST` | 1 | EA chủ động đóng, `deal=61\|ok\|done` |
| `STATE` | 103 | chuỗi transition hợp lệ |

`SUMMARY`: `entries=31 exits=31 wins=11 losses=20 net=53.72 balance=5053.72 drawdown_pct=0.6530`.
14 BUY / 17 SELL, volume lớn nhất quan sát được 0.02, 31 order ticket duy nhất (không trùng).

Đối soát độc lập với chính tester: tab **Backtest** báo `Total Trades 31`, `Total Deals 62`,
`Total Net Profit 53.72`; **Journal** có `market buy 0.01 XAUUSDm sl: … tp: …`,
`deal #42 … done (based on order #42)`, `position modified [...]`, `stop loss triggered …`,
`final balance 5053.72 USD`, `Test passed in 0:34:57.563`. Ba nguồn (journal CSV, tab Backtest,
tab Journal) khớp nhau.

### 44.2 Audit tĩnh

`python audit_exec_csv.py pa_trendrider_demo.csv` → **`PROBLEMS=0`**. Kiểm tra: số ENTRY/EXIT khớp
`SUMMARY`; `config_hash` không đổi trong phiên; luôn ≤ 1 vị thế; `BUY: sl<entry<tp` và
`SELL: sl>entry>tp`; `tp == entry ± 3·risk` trong dung sai 0.01; `TRAIL` chỉ siết SL chứ không nới;
mọi `ENTRY` phải mang `ORDER_FILLED`.

### 44.3 Phân bố lý do chặn — vì sao demo thật chưa có lệnh

| reason | dòng | % |
|---|---:|---:|
| `bias_unknown` | 24 467 | 47.71 |
| `reversal_watch` | 15 161 | 29.56 |
| `regime_range` | 6 775 | 13.21 |
| `bos_against_bias` | 1 982 | 3.86 |
| (tín hiệu hợp lệ → `ENTRY`) | 1 478 | 2.88 |
| `volatility_high` | 777 | 1.52 |
| `no_pullback` / `bos_too_old` | 288 / 228 | 0.56 / 0.44 |
| `lot_rejected` / `stop_rejected` | 51 / 37 | 0.10 / 0.07 |
| `spread_blocked` / `risk_locked` | 22 / 21 | 0.04 |

Chỉ ~24% số bar ở regime `TREND_UP`/`TREND_DOWN` (171 + 176 / 1 458 dòng `REGIME`). Trung bình
**3.1 lệnh/tháng**, kỳ vọng chờ dài nhất trong dữ liệu là `2026.01.28 → 2026.03.06` (~5.5 tuần).
Đây là bộ lọc cố ý của spec ("không vào lệnh khi H1/M15 không cùng hướng"), không phải lỗi.

### 44.4 Kill switch bằng file thật — PASS

Tạo `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt` trên **chart demo thật**, journal ghi trong 16 giây:

```
2026.10.29 04:10:16 KILL  kill_switch_file|entries_disabled|file=PA_TREND_RIDER_DEMO_STOP.txt
2026.10.29 04:10:16 STATE to=ERROR_SAFE_MODE|reason=kill_switch|transitions=3
```

Hành vi cần biết: `g_kill_switch` chốt cứng đến khi `OnInit` chạy lại (`if(g_kill_switch) return;`),
và `OnDeinit` luôn ghi state ra đĩa trước `OnInit` đọc lại — nên **xoá file là chưa đủ**, EA vẫn
khởi động với `state=ERROR_SAFE_MODE` phục hồi từ `pa_trendrider_demo_state.csv`.

### 44.5 Khôi phục về trạng thái armed — PASS

Live demo `464140826`, chart `XAUUSDm,M5`, `InpEnableExecution=true`:

```
2026.10.29 04:28:00 INIT  mode=DEMO_EXECUTION|state=WAITING_FOR_SETUP|restored=1|symbol=XAUUSDm|allowed=XAUUSD|magic=25002001|tp_r=3.00|config_hash=6B439450
2026.10.29 04:28:00 RISK  ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE|state=WAITING_FOR_SETUP|spread_points=240.0|atr=3.12142857
```

`OnInit` chỉ trả về thành công khi `ExecContextAllowed` pass toàn bộ (`ACCOUNT_TRADE_MODE_DEMO` +
`ACCOUNT_TRADE_ALLOWED` + `TERMINAL_TRADE_ALLOWED`) rồi `ExecSymbolAllowed` và `ExecSymbolTradable`
pass — tức **INIT này là bằng chứng tài khoản demo, quyền giao dịch của tài khoản, Algo Trading của
terminal và symbol `XAUUSDm` đều đang mở**. Quy trình reset đã ghi lại ở
[`guides/demo-execution.md`](guides/demo-execution.md) §5.

### 44.6 Giới hạn trung thực

- **Tester không chứng minh broker demo chấp nhận lệnh.** `ExecContextAllowed` trả `true` ngay khi
  `state.tester` ([`ExecGuard.mqh`](../mt5/Include/Exec/ExecGuard.mqh) dòng 64-67) và khớp lệnh
  trong tester là mô phỏng. Bằng chứng 44.1 chứng minh *mã đường lệnh* chạy đúng, không phải *trả lời
  của broker Exness*. Một `ENTRY` thật trên demo vẫn chưa có.
- Phiên demo thật hiện tại 0 entry là **kết quả hợp lệ** của bộ lọc regime, không phải thành tích hay lỗi.
- Chưa xác nhận cờ "Allow Algo Trading" riêng của EA trên chart (`MQL_TRADE_ALLOWED`) — guard hiện không
  đọc cờ này; nếu nó tắt thì `OrderSend` sẽ fail lúc có tín hiệu chứ không fail lúc `INIT`.
- `WriteStateFile` viết dòng state thành `state=state=ERROR_SAFE_MODE;transitions=3` vì `Serialize()`
  đã tự thêm tiền tố `state=` ([`TRState.mqh`](../mt5/Include/TrendRider/TRState.mqh) dòng
  107-111) còn `FileWriteString` thêm một lần nữa. `RestoreStateFile` vẫn parse đúng nên **không đổi
  hành vi**; ghi nhận ở đây để lần refactor sau thống nhất với dòng `ledger=`.
- Không có bằng chứng nào ở §44 chứng minh chiến lược có lợi nhuận; +53.72/5 000 là một khoảng kiểm
  thử duy nhất, một symbol, một bộ tham số.

## 45. Broker demo thật chấp nhận lệnh qua `ExecBroker.mqh` — 2026-10-29

§44.6 để lại một khoảng trống duy nhất không thể đóng bằng Strategy Tester: chưa có bằng chứng
**máy chủ demo của Exness** đồng ý khớp một lệnh đi qua [`ExecBroker.mqh`](../mt5/Include/Exec/ExecBroker.mqh).
Lý do: `ExecContextAllowed` trả `true` ngay khi `state.tester` bật, nên tester chỉ chứng minh mã
đường lệnh, không chứng minh phản hồi của broker. Khoảng trống đó đã đóng bằng
`mt5/Scripts/ExecDemoProbe.mq5` — script một phát, dùng lại đúng guard chain của EA.

### 45.1 Thiết kế probe (và vì sao nó không thể tự gian lận)

| Cơ chế | Tác dụng |
|---|---|
| Từ chối chạy khi `MQLInfoInteger(MQL_TESTER)` | bằng chứng bắt buộc đến từ server thật, không từ bộ mô phỏng |
| Đòi `MQLInfoInteger(MQL_TRADE_ALLOWED)` | lấp đúng lỗ hổng §44.6 — guard của EA chưa đọc cờ này |
| `ExecContextAllowed` với `state.tester=false` | vẫn phải qua `ACCOUNT_TRADE_MODE_DEMO` + `ACCOUNT_TRADE_ALLOWED` + `TERMINAL_TRADE_ALLOWED` |
| `ExecSymbolAllowed` / `ExecSymbolTradable` / kill switch `FileIsExist` | cùng bộ lọc với DemoEA |
| `ExecTakeProfitValid` + `ExecStopsRespectBroker` + `ExecMarginRequired` trước khi gửi | không có lệnh nào ra khỏi mà thiếu SL/TP hợp lệ |
| `InpConfirm=false` mặc định | không gửi lệnh chỉ vì script được attach nhầm |
| magic `25002002` ≠ `25002001` | không đụng vị thế/state/journal của DemoEA |
| tự đóng vị thế ngay trong lần chạy | không để lại trạng thái treo |

Static gate đã siết các bất biến đó: `scripts/validate-project.py` và
`scripts/validate_demo_execution.py` (check mới `demo order probe`) buộc `InpConfirm=false`, buộc
probe gọi `ExecOpenMarket`/`ExecClosePosition` thay vì `OrderSend`, và buộc magic khác DemoEA.

### 45.2 Chạy thật trên demo `464140826` — PASS

Data folder `53785E099C927DB68A545C249CDBCE06`, chart `XAUUSDm,M5`, dịch trực tiếp trong data folder
`Result: 0 errors, 0 warnings`. Log thật trong `MQL5\Logs\20261029.log`:

```
12:18:52.730  PROBE|READY|symbol=XAUUSDm|digits=3|volume=0.01|magic=25002002|stops_level=0|confirm=0
12:18:52.730  PROBE|DRY|all_guards_pass|no_order_sent|set_InpConfirm_to_send
12:20:10.183  PROBE|READY|symbol=XAUUSDm|digits=3|volume=0.01|magic=25002002|stops_level=0|confirm=1
12:20:10.183  PROBE|MARGIN|required=20.23|free=5000.00
12:20:10.305  PROBE|OPEN|order=2762481907|deal=2468899165|price=4045.79|volume=0.01|sl=4042.79|tp=4048.79|ok|done
12:20:10.305  PROBE|POSITION|ticket=2762481907|open=4045.79|sl=4042.79|tp=4048.79|volume=0.01
12:20:10.408  PROBE|CLOSE|order=2762481909|deal=2468899168|price=4045.55|ok|done
12:20:10.408  PROBE|DONE|position=2762481907|deals=2|pnl=-0.24|balance=4999.76
```

Lần 1 (`InpConfirm=false`) đi hết chuỗi guard và **không gửi lệnh nào** — xác nhận dry-run vẫn là mặc
định an toàn. Lần 2 khớp lệnh thật, có SL/TP gắn ngay trong request, rồi đóng trong 103 ms.

Đối soát ba nguồn độc lập:

| Nguồn | Nội dung |
|---|---|
| Log script | `deal=2468899165` vào 4045.79, `deal=2468899168` ra 4045.55, `pnl=-0.24` |
| Tab Trade | `Balance: 4 999.76 USD`, danh sách vị thế trống → probe đã tự dọn |
| Tab History (server) | `xauusdm buy 0.01 4045.787 S/L 4042.787 T/P 4048.787 → 4045.547, Profit -0.24`; tổng `Balance: 4 999.76` |

−0.24 USD đúng bằng spread 240 points trên 0.01 lot (1 oz) — chi phí một vòng, không phải lỗi.
Bằng chứng gốc (log UTF-16, `.ex5` đã chạy, log compile, `SHA256SUMS`) ở
`reports/build/demo-exec-probe-20261029/` (gitignored).

### 45.3 Tác dụng phụ đã kiểm chứng: DemoEA không bị nhiễm

Journal `pa_trendrider_demo.csv` có **0 dòng** chứa magic `25002002`, state vẫn
`WAITING_FOR_SETUP|transitions=5|dd_locked=0`. Dòng `RISK` lúc `05:25:00` ghi
`balance=4999.76|drawdown_pct=0.0048` — tức ledger của EA **hạch toán cả phần lỗ −0.24 do probe gây
ra** vì nó đọc balance tài khoản, không chỉ balance của chính EA. Đây là hành vi đúng của một risk
ledger theo tài khoản, nhưng cần biết khi đọc `drawdown_pct` ngay sau khi chạy probe.

### 45.4 Giới hạn trung thực

- Một lệnh 0.01 được chấp nhận chứng minh **đường vận chuyển lệnh** (bảo mật phiên, symbol, khối
  lượng, SL/TP, filling mode, hedge mode), không chứng minh DemoEA sẽ luôn khớp lệnh khi có tín hiệu:
  retcode từ chối theo giờ, freeze, hay requite vẫn có thể xảy ra.
- Probe dùng `ORDER_TYPE_BUY` với SL dưới/TP trên; chiều SELL đi qua cùng `ExecOpenMarket` nhưng chưa
  có bằng chứng runtime trên server thật.
- Vẫn **chưa có `ENTRY` thật từ chính DemoEA** trên demo — đó là việc của §46 và cần tín hiệu
  hợp lệ, không phải cần thêm code.
- Không có bằng chứng nào ở đây chứng minh chiến lược có lợi nhuận, và execution live/real vẫn bị
  ADR 0003 cấm cho tới khi có ADR mới.

## 46. Automation giám sát journal demo — `watch_demo_journal.py` — 2026-10-29

§45 đóng khoảng trống "server có khớp lệnh hay không", nhưng **`ENTRY` do chính DemoEA gửi vẫn chưa có**.
Việc còn lại không phải sửa code tín hiệu mà là **có mặt khi tín hiệu xuất hiện**, nên thêm
`scripts/watch_demo_journal.py`: một reader theo dõi `MQL5\Files\pa_trendrider_demo.csv` và báo ngay khi
thấy dòng `ENTRY`.

### 46.1 Thiết kế

| Thành phần | Hành vi |
|---|---|
| Nguồn dữ liệu | Chỉ `pa_trendrider_demo.csv` (18 cột theo `SIM_LOG_HEADER`). Tự dò mọi `...\Terminal\*\MQL5\Files\`; nếu có **nhiều hơn một** file khớp thì **dừng** và yêu cầu `--csv` — không đoán bừa một terminal |
| Checkpoint | `reports\demo-watch\journal_checkpoint.json` lưu offset byte. Lần đầu mặc định bắt đầu ở **cuối file** (`--from-start` để quét lịch sử), nên không báo lại sự kiện cũ |
| Dòng chưa_complete | Chỉ tiêu thụ dòng kết thúc bằng `\r\n`; dòng EA đang viết dở bị giữ lại cho lần poll sau, offset không tiến |
| Alert `ORDER` | `ENTRY`, `EXIT`, `TRAIL`, `CLOSE_REQUEST`, `ADOPT`, `SYNC` |
| Alert `FAULT` | `KILL`, `ERROR`, `STATE_ERROR`, `RESET` |
| Không alert | `RISK\|ENTRY_BLOCKED`, `BOS`, `REGIME`, `INIT`, `STATE`, `SUMMARY` — chỉ vào tổng hợp và histogram block reason |
| Kill switch | `PA_TREND_RIDER_DEMO_STOP.txt` còn trong `MQL5\Files` → `WATCH\|FAULT\|kill_switch_file_present`, exit 1 |
| stale | File không được ghi > 2 giờ → `WATCH\|NOTE\|journal_stale` |
| Exit code | `0` không alert · `1` có alert (dùng cho chu kỳ giám sát) · `2` không có journal hoặc sai schema |
| Chế độ | một lần (mặc định), `--watch --interval N`, `--timeout N`, `--stop-on-alert`, `--quiet`, `--reset` |

Ranh giới: script là **Python thuần đọc file**. Không `OrderSend`, không `CPositionInfo`, không
`import MetaTrader5`, không mở MT5, không ghi gì vào `MQL5\Files` hay `MQL5\Experts`, không đọc credential.

### 46.2 Chạy thật trên demo `464140826`

Lần quét toàn bộ đầu tiên (`--reset --from-start`) đọc đúng 79 sự kiện và **không** có `ENTRY`/`EXIT`:

```
WATCH|SUMMARY|events=79|BOS=7|INIT=7|KILL=1|REGIME=7|RISK=50|STATE=1|SUMMARY=6
WATCH|BLOCKED|reason=bias_unknown=36|reason=regime_range=14
```

`KILL=1` là dòng lịch sử của phiên test kill switch 04:10:16 (đã reset ở §44), nên exit code là 1 —
watcher báo đúng, kể cả sự kiện cũ.

Chế độ tail sau đó chứng minh checkpoint hoạt động trên bar thật:

```
WATCH|RISK|2026.10.29 06:25:00|2026.10.29 06:20:00|ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE|state=WAITING_FOR_SETUP|spread_points=240.0|atr=4.36707143
WATCH|RISK|2026.10.29 06:30:00|2026.10.29 06:25:00|ENTRY_BLOCKED|reason=bias_unknown|…
WATCH|RISK|2026.10.29 06:35:00|2026.10.29 06:30:00|ENTRY_BLOCKED|reason=bias_unknown|…
WATCH|RISK|2026.10.29 06:40:00|2026.10.29 06:35:00|ENTRY_BLOCKED|reason=bias_unknown|…
WATCH|SUMMARY|events=4|RISK=4
WATCH|BLOCKED|reason=bias_unknown=4
```

Chạy lần hai ngay sau đó in **không dòng nào** và exit 0 (không có bar mới).
`--watch --interval 60 --timeout 12` dừng sau đúng 12,2 giây và bắt được bar `06:45:00` vừa được ghi.

Ba nguồn đối chiếu vẫn khớp: journal CSV, `MQL5\Files\pa_trendrider_demo_state.csv`
(`state=WAITING_FOR_SETUP;transitions=5;dd_locked=0`) và tab History của terminal (§45).

### 46.3 Gate tĩnh và test

| Gate | Kết quả |
|---|---|
| `scripts\validate_demo_execution.py` | `checks=8 fail=0`; check mới **"demo journal watcher"** |
| Bất biến watcher | Cấm mọi trading API; `EXPECTED_HEADER` **phải bằng** `SIM_LOG_HEADER` trong `SimLogger.mqh`; `JOURNAL_NAME`/`KILL_SWITCH_NAME` phải khớp `InpLogFile`/`InpKillSwitchFile` của DemoEA; mọi event trong `ALERT_EVENTS` phải thực sự được DemoEA phát ra qua `Event("…")`; `ENTRY`/`EXIT` bắt buộc là alert; checkpoint phải nằm dưới `reports/` |
| `scripts\validate-project.py` | `checks=14 fail=0` |
| `pytest -q` | **371 passed** (358 + 13 test mới `python/tests/test_watch_demo_journal.py`) |
| `python -m compileall -q scripts python/src python/tests` | exit 0 |
| `pip check` | no broken requirements |

13 test mới phủ: parse 18 cột, từ chối cột sai, checkpoint chỉ báo dòng appended, **dòng chưa complete
không bị tiêu thụ**, phát hiện file bị ghi đè lại (`restarted`), phân loại `ORDER`/`FAULT`, histogram block
reason, exit 1 khi có `ENTRY`/`ERROR`, exit 0 khi chỉ có `ENTRY_BLOCKED`, exit 2 khi thiếu journal, kill
switch file luôn alert, `--quiet` giữ lại dòng alert, và source không chứa trading API.

### 46.4 Giới hạn trung thực

- Watcher **không** làm chiến lược dễ vào lệnh hơn. `reason=bias_unknown` và `regime_range` là bộ lọc của
  chính TrendRider; `ENTRY` chỉ xuất hiện khi regime chuyển `TREND` và bias xác định.
- Đây là reader một phía: nếu EA treo hoặc terminal tắt, journal ngừng ghi và watcher chỉ báo
  `journal_stale` sau 2 giờ — nó không phát hiện "EA không chạy".
- Exit 1 có nghĩa "có sự kiện đáng chú ý", **không** có nghĩa "có lệnh thắng". `EXIT` alert cũng sẽ bật
  lên khi lệnh đóng với P&L âm.
- Chưa bật lịch chạy tự động định kỳ (Task Scheduler / cron). Automation đang ở dạng lệnh chạy một lần
  hoặc `--watch`; người dùng quyết định có muốn nó chạy nền thường xuyên hay không.
- Không có kết luận lợi nhuận. DemoEA vẫn **0 `ENTRY`** tính tới 2026-10-29 06:45 UTC.

## 47. Kiểm tra test suite toàn project — 2026-10-29

Lần chạy đầy đủ sau khi thêm `watch_demo_journal.py`. Mọi con số dưới đây lấy từ lần chạy thật trên
`D:\Applications\tm-fx`, không phải suy ra từ lần trước.

### 47.1 Python

| Hạng mục | Lệnh | Kết quả |
|---|---|---|
| pytest | `.venv\Scripts\python.exe -m pytest -q` | **372 passed in 15.36s** |
| Thu thập test | `pytest --collect-only -q` | 372 test trong **31 file** |
| Cú pháp | `python -m compileall -q python/src python/tests scripts` | exit 0 |
| Dependency | `python -m pip check` | no broken requirements |
| Test chậm nhất | `--durations=8` | 1.14 s (`test_pipeline_cli::test_duplicate_pipeline_run_is_rejected_without_overwrite`) — toàn bộ suite không có test treo |

File nhiều test nhất: `test_sim_configs.py` 31, `test_bounded_basket.py` 28, `test_pine_parity.py` 25,
`test_multi_source_parity.py` 21, `test_experiment_store.py` 18, `test_validation.py` 16,
`test_signals.py`/`test_parity.py`/`test_demo_execution.py` 15, `test_backtest.py` 15,
`test_watch_demo_journal.py` 14.

### 47.2 Static validator (10 script)

| Script | Exit | Kết quả |
|---|---|---|
| `validate-project.py` | 0 | `checks=14 fail=0` |
| `validate_demo_execution.py` | 0 | `checks=8 fail=0` |
| `validate_sim_configs.py` | 0 | `checked=7 fail=0` (6 preset, 17 scenario) |
| `validate_trendrider.py` | 0 | `checks=7 fail=0` |
| `validate_longkaco.py` | 0 | pass |
| `validate_pamtf.py` | 0 | pass |
| `validate_tmfz.py` | 0 | pass |
| `validate_tmind2.py` | 0 | pass |
| `validate_tmxau2.py` | 0 | pass |
| `validate_pineport.py` | 0 | pass |
| `validate_dataset.py` | 0 | cần tham số CSV; chạy với `python/tests/fixtures/synthetic_eurusd_m5.csv`: `rows=6 errors=0 warnings=1 passed=True` (warning synthetic là đúng kỳ vọng) |

### 47.3 MQL5

`scripts\build-mql5.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe"`:
**BUILD_OK — 30 source(s), 0 errors, 0 warnings**.

Ma trận runtime của 11 script test MQL5 (số liệu lấy từ §37–§45, không chạy lại trong lần này):

| Script | Trạng thái runtime | Check | Ngày |
|---|---|---|---|
| `ExecGuardTests.mq5` | **PASS** | 51/51 | 2026-10-29 |
| `TrendRiderContractTests.mq5` | **PASS** | 82/82 | 2026-10-28 |
| `SimCoreTests.mq5` | **PASS** | 125/125 | 2026-10-28 |
| `SimPlanTests.mq5` | **PASS** | 39/39 | 2026-10-28 |
| `WonderwhalesContractTests.mq5` | **PASS** (wrapper ST) | 36/36 | 2026-10-28 |
| `LongKacoVSAContractTests.mq5` | **PASS** (wrapper ST) | 47/47 | 2026-10-28 |
| `TMFusionZonesContractTests.mq5` | **PASS** (wrapper ST) | 82/82 | 2026-10-28 |
| `TMXAUSignals2ContractTests.mq5` | **PASS** (wrapper ST) | 107/107 | 2026-10-28 |
| `PriceActionMTFContractTests.mq5` | **PASS** (wrapper ST) | 120/120 | 2026-10-28 |
| `TMIndicator2ContractTests.mq5` | **PASS** (wrapper ST) | 155/155 | 2026-10-28 |
| `LabSignalEngineTests.mq5` | **`NOT_RUN`** | 40+ assertion | — |

Tổng: **844 check MQL5 PASS** trên 10/11 script. Script còn lại `LabSignalEngineTests.mq5` mới chỉ compile
(0/0) và chưa từng được chạy trong terminal — đây là **hạng mục mở thật sự**, không phải đã PASS.

### 47.4 Những gì vẫn chưa được kiểm

- `LabSignalEngineTests.mq5` — chưa chạy (cần MT5 mở chart và kéo script).
- Parity MQL5 ↔ Python cho `LabSignalExport` và multi-source vẫn `BLOCKED` (chưa có CSV reference).
- Parity runtime ONNX của `LabOnnxInference` chưa chạy.
- Strategy Tester cho `LabSignalEA` chưa chạy (kỳ vọng 0 trade vì signal-only).
- `ENTRY` thật do DemoEA gửi trên demo vẫn **chưa xảy ra** (§46.4).

Kết luận ngắn: phần **Python + static validator + compile** đang xanh toàn bộ; phần **runtime MQL5** thiếu
đúng một script (`LabSignalEngineTests`) và các hạng mục parity/backtest đã ghi rõ là mở từ trước.

## 48. Runtime LabSignal + ONNX + Strategy Tester `LabSignalEA` — 2026-10-29

Đóng bốn hạng mục runtime còn mở của §47.4. Mọi số liệu dưới đây lấy từ log/terminal build 6292 trên
`XAUUSDm`, không suy ra từ lần chạy trước và không có kết quả nào được "điền hộ".

### 48.1 Deploy và compile

`scripts/deploy_pineport.ps1` được mở rộng để sync thêm 6 file của Track A vào Data Folder
(`Indicators.mqh`, `SignalEngine.mqh`, `LabSignalEngineTests.mq5`, `LabSignalExport.mq5`,
`LabSignalEA.mq5`, `LabOnnxInference.mq5`) và 4 target mới trong danh sách compile.

`scripts\build-mql5.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe"`:
**BUILD_OK — 30 source(s), 0 errors, 0 warnings** (2026-10-29).

### 48.2 `LabSignalEngineTests` — runtime PASS

| Trường | Giá trị |
|---|---|
| Chart | `XAUUSDm,H1` |
| Build | 6292 |
| Thời điểm | 2026-10-29 14:28:37 |
| Kết quả | `TEST\|SUMMARY\|pass=53 fail=0` → `TEST\|RESULT\|ALL_PASS` |
| Log | `MQL5\Logs\20261029.log` |

Đây là script synthetic trong bộ nhớ (không đọc thị trường, không gọi API giao dịch): PASS chứng minh ma
trận engine mua/bán/giữ, warm-up, config/giá không hợp lệ và tính deterministic — không chứng minh hiệu
năng chiến lược.

### 48.3 Parity EMA MQL5 ↔ Python

Đã khớp trên fixture chuẩn hóa trong `python/tests/fixtures/`. **Sự cố:** lần đối chiếu đầu dùng nhầm
fixture (khác cặp/khung), comparator báo mismatch; đã dừng, xác định lỗi nằm ở fixture chứ không phải code,
sửa đầu vào rồi chạy lại — PASS. Không có thay đổi logic nào được thực hiện để "khớp" kết quả sai.

### 48.4 ONNX runtime — PASS 24/24

| Trường | Giá trị |
|---|---|
| EA | `LabOnnxInference` trên `XAUUSDm,H1`, build 6292 |
| Model | `model.onnx`, ONNX Runtime `api version 1.30.0` |
| Provider | CPU (CUDA fail 35, TensorRT fail — máy không có GPU dùng được) |
| Số hàng | 24/24, `onnx_rows=24` |
| Sai lệch với Python | max abs `4.927e-08`, mean `1.997e-08`, tolerance `1e-5` |
| Deterministic | hai lần chạy (15:06:37 và 15:07:42) cho cùng probability từng hàng |

### 48.5 Strategy Tester `LabSignalEA` — PASS, 0 trade

| Trường | Giá trị |
|---|---|
| Terminal | build 6292 |
| Symbol / period | `XAUUSDm` / `M5` |
| Khoảng dữ liệu | 2026.09.01 – 2026.10.28 |
| Model | 1 minute OHLC, deposit 5 000 USD, leverage 1:100 |
| Ticks / bars | 225 340 / 11 285, `invalid_bars=0` |
| Signal | `BUY_OK=219`, `SELL_OK=212`, `HOLD_NO_CROSS=10 854` |
| Trade | **0** (đúng thiết kế signal-only) |
| Kết quả | `successfully finished` trong `0:00:00.407`, balance cuối `5000.00 USD` |

Chạy headless bằng `reports/build/tester-run/lab_signal_ea_m5.ini`; artifact nằm ở
`reports/build/tester-reports/lab_signal_ea_m5/` (`htm`, `png`, log tín hiệu nén, `summary.json` với
`status: pass` và `evidence_sha256`). `reports/` bị gitignore nên artifact chỉ tồn tại cục bộ.

### 48.6 Sự cố `common.ini` và trạng thái demo

- Algo Trading của terminal được lưu ở `config\common.ini` → `[Experts] Enabled=`. Khi tắt, DemoEA từ chối
  `OnInit` mã 1 (`scope_rejected|terminal_trade_disabled`) — fail-closed đúng thiết kế.
- Trong lúc sửa cấu hình này bằng công cụ dòng lệnh, `iconv` không tồn tại và pipeline đã ghi đè
  `common.ini` thành **0 byte** trong khi MT5 đóng. Đã phát hiện ngay bằng `wc -c`, dựng lại file tối thiểu
  UTF-16LE (`Enabled=1`, `Account=0`, `Profile=0`, giữ `AllowDllImport=0`) và copy vào; terminal tự bổ sung
  `[Common]`/`[Charts]` khi khởi động.
- **Hệ quả:** terminal mất phiên đăng nhập tự động, mở lên sẽ hiện hộp thoại `Login`. Bước xác thực này
  **không được tự động hóa**; cần người dùng tự đăng nhập tài khoản demo một lần. Sau đó mới attach lại
  `PATrendRiderXAUv1DemoEA` trên `XAUUSDm,M5` với `InpEnableExecution=true` (state
  `pa_trendrider_demo_state.csv`, log `pa_trendrider_demo.csv`, `config_hash=6B439450`).
- Trạng thái demo hiện tại: EA **chưa armed lại** sau sự cố; lần chạy cuối vẫn `state=WAITING_FOR_SETUP`,
  `entries=0`, balance `4999.76`, và **chưa từng có `ENTRY` do DemoEA gửi**. Không có kết quả mới nào được
  ghi cho tới khi phiên đăng nhập được thực hiện. → Đã armed lại lúc 15:40 cùng ngày, xem §49.

### 48.7 Cổng kiểm tra lại sau thay đổi

| Cổng | Kết quả |
|---|---|
| `scripts\build-mql5.ps1` | BUILD_OK 30/0/0 |
| `scripts\validate-project.py` | `checks=14 fail=0` |
| `scripts\validate_demo_execution.py` | `checks=8 fail=0` |
| `scripts\validate_sim_configs.py` | `checked=7 fail=0` |
| `pytest -q` | **372 passed in 15.73s** |

### 48.8 Việc còn mở (trung thực)

- DemoEA chưa được armed lại và chưa có `ENTRY` thật — phụ thuộc một lần đăng nhập thủ công + regime khác
  `RANGE`. → Đã armed lại ở §49; `ENTRY` vẫn là hạng mục mở.
- `LabOnnxInference` chưa chạy trong Strategy Tester (mới chạy trên chart); parity Pine ↔ MQL5 Track B vẫn
  `BLOCKED` vì thiếu CSV reference. → Tester đã chạy 2026-10-29, xem §50; parity Track B vẫn `BLOCKED`.
- 2 scenario `plan_*` vẫn `BLOCKED_PERFORMANCE`.

## 49. Armed lại DemoEA bằng terminal startup config — 2026-10-29

### 49.1 Chặn đăng nhập được gỡ (thủ công, không tự động hóa)

Sau sự cố `common.ini` ở §48.6, terminal không còn phiên đăng nhập tự động. Người dùng tự đăng nhập demo
`464140826` (Exness-MT5Trial17) lúc 15:20:53; journal ghi:

```text
15:20:53.742 Network '464140826': authorized on Exness-MT5Trial17 through Access Point #3 (ping: 67.93 ms, build 6230)
15:20:54.706 Network '464140826': terminal synchronized with Exness Technologies Ltd: 0 positions, 0 orders, 355 symbols, 0 spreads
15:20:54.706 Network '464140826': trading has been enabled, demo account - hedging mode
```

Agent không điền hộp thoại `Login` ở bất kỳ bước nào. Không có mật khẩu/OTP nào được đọc, ghi hay ghi log.

### 49.2 Gắn EA không cần chuột — `[StartUp]` của terminal

MetaTrader cho phép gắn EA ngay khi khởi động qua section `[StartUp]` của file truyền vào `/config:`
(cơ chế chính thức, mô tả ở `guides/demo-execution.md` §4.1). Đã dùng:

- `MQL5\Presets\pa_trendrider_demo_live.set` sinh từ `configs/demo/pa_trendrider_xau_demo.json` với
  `InpEnableExecution=true`, `InpResetStateOnInit=false`, giữ `pa_trendrider_demo.csv`/
  `pa_trendrider_demo_state.csv`.
- `startup.ini`: `[Experts] AllowLiveTrading=1 Enabled=1 AllowDllImport=0`; `[StartUp] Expert=
  PATrendRiderXAUv1DemoEA`, `ExpertParameters=pa_trendrider_demo_live.set`, `Symbol=XAUUSDm`, `Period=M5`.
- Terminal cũ đóng bằng `taskkill` (WM_CLOSE, thoát sạch: `Terminal exit with code 0` → `shutdown with 0`),
  rồi khởi động lại bằng `terminal64.exe /config:<startup.ini>`.

Bằng chứng khởi động (journal `logs\20261029.log`, local 15:40):

```text
15:40:54.655 Startup  successfully initialized from start config "...\reports\build\demo-arm\startup.ini"
15:40:57.632 Network  '464140826': authorized on Exness-MT5Trial17 ... (previous 2026.10.29 08:20:53)
15:40:57.801 MQL5     47 inputs read from expert 'PATrendRiderXAUv1DemoEA' set file "...\pa_trendrider_demo_live.set"
15:40:57.814 Experts  expert PATrendRiderXAUv1DemoEA (XAUUSDm,M5) loaded successfully
```

### 49.3 Trạng thái EA sau khi armed

Dòng `INIT` mới trong `MQL5\Files\pa_trendrider_demo.csv` (thời gian cột = giờ server, lệch 7 h so với
local):

```text
2026.10.29 08:40:58 | INIT | 6B439450 | mode=DEMO_EXECUTION | state=WAITING_FOR_SETUP | restored=1
| magic=25002001 | tp_r=3.00 | equity=4999.76 | config_hash=6B439450
```

- `restored=1` + ledger `day_key=20261029;day_start=5000.00000000` → state/ledger nối tiếp, **không** reset.
- Cùng bar `08:35`: `BOS tf=M5 event=BOS_BEAR`, `REGIME regime=RANGE|bias=timeframe_conflict|h1=BEARISH|
  m15=UNKNOWN`, `RISK ENTRY_BLOCKED|reason=bias_unknown|regime=RANGE|spread_points=240.0|atr=4.04`.
- Hai bar kế tiếp (`08:45`, `08:50`) tiếp tục `RISK ENTRY_BLOCKED reason=bias_unknown` với ATR 4.15/4.27 →
  EA sống, xử lý từng bar M5 đóng, chặn đúng luật; **`entries=0` vẫn là kết quả hợp lệ** của bộ lọc regime.
- Kill switch `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt` không tồn tại; state `WAITING_FOR_SETUP;
  transitions=5`.

### 49.4 Giám sát

`scripts\watch_demo_journal.py` (chỉ đọc): lần quét đầu bắt đúng 4 sự kiện của phiên mới (`INIT=1`, `BOS=1`,
`REGIME=1`, `RISK=1`), `WATCH|BLOCKED|reason=bias_unknown=1`, exit `0`. Sau đó chạy nền
`--watch --interval 30` ghi `reports\demo-watch\watch_20261029.log` (gitignored) và đã bắt các dòng
`RISK` của bar `08:45`/`08:50`. Checkpoint: `reports\demo-watch\journal_checkpoint.json`.

Lần quét lại lúc 16:26 (sau khi người dùng đăng nhập lại) bắt thêm 6 bar `08:55`–`09:25` (server), tất cả
`ENTRY_BLOCKED reason=bias_unknown|regime=RANGE` với ATR 5.20 → 5.84 → 5.99. Từ 15:40 đến 16:26 EA không
bỏ bar nào; `MQL5\Logs` không có dòng lỗi nào của EA (EA chỉ ghi CSV, không `Print` định kỳ).

Audit tĩnh trên **riêng phiên đang chạy** (`reports\demo-watch\session_armed.csv`, phần từ dòng `INIT`
08:40:58 trở đi) bằng `audit_exec_csv.py`: `rows=13 entries=0 exits=0 trails=0 open_at_end=False`,
`config_hash=6B439450` không đổi, `PROBLEMS=1` — và problem duy nhất là `INIT/SUMMARY count` vì `SUMMARY`
chỉ được ghi trong `OnDeinit` (phiên còn sống). Chạy audit trên cả file (107 dòng, gồm cả phiên dry-run cũ
`8A85E0D5`) thì báo thêm `config_hash changed` — đó là hiệu ứng của việc nối nhiều phiên vào một CSV, không
phải vi phạm bất biến.

Lịch tự động (Qoder automation, chạy local trên máy này, không phải Windows Task Scheduler):
`Demo EA journal watch (ENTRY alerts)`, cron `0 7-23/2 * * 1-5` (Asia/Ho_Chi_Minh), id
`051f5383-5e5d-49ba-9d38-24eaab8a220d`. Mỗi lần chạy chỉ chạy watcher ở trên; có `ENTRY`/`EXIT`/`TRAIL`/
`KILL`/`ERROR` thì báo và ghi `PROGRESS`, chỉ có `ENTRY_BLOCKED` thì trả một dòng, không ghi file, không
commit, không giao dịch. Tắt bằng cách remove job này trong Automations.

### 49.5 Điều chưa chứng minh (trung thực)

- `INIT mode=DEMO_EXECUTION` chứng minh `ACCOUNT_TRADE_MODE_DEMO` + `ACCOUNT_TRADE_ALLOWED` +
  `TERMINAL_TRADE_ALLOWED`, **không** chứng minh `MQL_TRADE_ALLOWED` vì guard của DemoEA không đọc cờ đó.
  Quyền này đến từ `[Experts] AllowLiveTrading=1` lúc khởi động; nếu thiếu, lỗi chỉ lộ ở `OrderSend` đầu
  tiên (error 10027). Đã ghi thành rủi ro riêng trong `reference/risk.md`.
- **Chưa có `ENTRY` do DemoEA gửi trên demo.** Kỳ vọng ~3.1 lệnh/tháng; khoảng chờ dài nhất quan sát được
  ~5.5 tuần. Không nới gate chiến lược để tạo lệnh.
- `LabOnnxInference` chưa chạy Strategy Tester; parity Pine ↔ MQL5 Track B vẫn `BLOCKED`; 2 scenario
  `plan_*` vẫn `BLOCKED_PERFORMANCE`. → Tester đã chạy lúc 16:52, xem §50; hai hạng mục còn lại không đổi.

## 50. `LabOnnxInference` trong Strategy Tester + armed lại DemoEA — 2026-10-29

Mục tiêu: đóng hạng mục cuối cùng của Phase 8 còn `NOT_RUN` (EA ONNX chưa chạy trong Strategy Tester).
MT5 chỉ cho một instance, nên phải đóng terminal đang chạy DemoEA, chạy tester headless, rồi armed lại EA
ngay sau đó.

### 50.1 Lần chạy đầu thất bại — `error 5019`, không phải lỗi model

Tạo `reports\build\tester-run\lab_onnx_inference.ini` (`Expert=LabOnnxInference`, `XAUUSDm`, `H1`,
2026.01.05–2026.01.06, deposit 5 000 USD, `ShutdownTerminal=1`). Hai lần chạy 16:48 và 16:49 đều dừng ở:

```text
2026.01.05 00:00:00   OnnxCreate failed for model.onnx, error 5019
tester stopped because OnInit returns non-zero code 1
```

`5019` = `ERR_FILE_NOT_EXIST`. File **có** trong `<Data Folder>\MQL5\Files\model.onnx` (566 B) và đã
được copy sang `%APPDATA%\MetaQuotes\Tester\<instance>\Agent-127.0.0.1-3000\MQL5\Files` trước lần chạy
thứ hai — nhưng sau mỗi lần chạy thư mục agent lại rỗng. Kết luận từ quan sát, không suy đoán: **agent
của Strategy Tester xoá sạch sandbox `MQL5\Files` ở mỗi lần test**, nên EA đọc model bằng tên tương đối
không bao giờ thấy file nếu chỉ copy tay.

### 50.2 Cách sửa chính thức — `#property tester_file`

Thêm vào `mt5/Experts/LabOnnxInference.mq5`:

```mql5
#property tester_file "model.onnx"
#property tester_file "onnx_feature_fixture.csv"
```

Terminal gửi hai file này từ `MQL5\Files` sang agent trước khi test. Compile lại trong data folder
(`MetaEditor64.exe /compile`, log `0 errors, 0 warnings`, 791 ms, CLI exit 1 như đã biết). Lần chạy 16:52
ghi đúng hai dòng chuyển file:

```text
file added: Files\model.onnx. 586 bytes loaded
file added: Files\onnx_feature_fixture.csv. 6440 bytes loaded
```

### 50.3 Kết quả chạy tester

```text
ONNX  api version 1.30.0 initialized
ONNX: update TensorRT failed ... nvinfer_11.dll missing   (provider không dùng được)
ONNX: update CUDA failed 35: cudaGetDeviceCount
ONNX: CPU selected
onnx_row=0 probability=0.57783628
...
onnx_row=23 probability=0.57057130
onnx_rows=24 model=model.onnx
```

Đối chiếu với `python/tests/fixtures/onnx_feature_fixture.csv` cột `expected_probability`:

| Số hàng | max abs diff | mean abs diff | Vượt tolerance `1e-5` |
|---|---|---|---|
| 24/24 | `4.927e-08` | `1.997e-08` | 0 |

Trùng khớp từng bit với lần chạy trên chart ⇒ kết quả inference không phụ thuộc môi trường chạy. CUDA/
TensorRT lỗi là bình thường trên máy này (không có GPU NVIDIA), EA tự rơi về CPU — không phải lỗi cấu
hình, và không ảnh hưởng kết quả. Artifact: `reports\build\tester-run\lab_onnx_inference.evidence.log`
(gitignored, 35 dòng), báo cáo `lab_onnx_inference.htm`.

Quan sát phụ: profile vẫn còn chart H1 gắn `LabOnnxInference`, nên mỗi lần khởi động terminal EA này
chạy lại 24 hàng ở 16:52:59 — vô hại (chỉ `Print`, không order), nhưng làm nhiễu `MQL5\Logs`.

### 50.4 Armed lại DemoEA ngay sau khi tester đóng

```powershell
terminal64.exe /config:"D:\Applications\tm-fx\reports\build\demo-arm\startup.ini"
```

Journal: `successfully initialized from start config ... demo-arm\startup.ini` →
`expert PATrendRiderXAUv1DemoEA (XAUUSDm,M5) loaded successfully`. CSV dòng 114:

```text
2026.10.29 09:52:58,...,INIT,...,mode=DEMO_EXECUTION|state=WAITING_FOR_SETUP|restored=1|magic=25002001|equity=4999.76|config_hash=6B439450
```

`restored=1` xác nhận state/ledger sống qua lần đóng terminal (không reset ngày, không mất `peak`).
Không có vị thế nào được mở/đóng trong lúc đóng terminal.

### 50.5 Tín hiệu mới quan sát được trong ngày

Bar `09:30` (server) đổi regime sang `TREND_DOWN` (`bias=aligned_bearish`, H1 và M15 cùng BEARISH) và
EA chặn bằng `ENTRY_BLOCKED|reason=bos_too_old` — lần đầu tiên lý do chặn không phải `bias_unknown`, tức
pipeline H1→M15→M5 đã chạy tới bước kiểm tra BOS. Bar `09:40` quay lại `RANGE|bias=timeframe_conflict`.
Không có `ENTRY`.

Bar `09:55` (17:00 local) có `tf=M5|event=BOS_BULL` rồi `ENTRY_BLOCKED|reason=bias_unknown` — EA vẫn nhận
tick và xử lý bar sau khi armed lại (xác nhận sống, không cần tick giả).

**Đọc CSV đúng cách:** `REGIME` chỉ ghi khi regime đổi và `RISK|ENTRY_BLOCKED` chỉ ghi khi lý do chặn đổi
(`mt5/Experts/PATrendRiderXAUv1DemoEA.mq5:1064`, `:747`). Vì vậy file đứng yên nhiều bar **không** có nghĩa
EA ngừng chạy — 16:52→17:00 không có dòng nào dù EA xử lý đủ bar, đúng như thiết kế. Muốn biết EA còn sống
thì xem bar đổi trạng thái (BOS/REGIME) hoặc `SUMMARY` sau `OnDeinit`.

### 50.6 Còn mở

- **Chưa có `ENTRY` thật** từ DemoEA (kỳ vọng ~3.1 lệnh/tháng); `MQL_TRADE_ALLOWED` khi đó chỉ lộ ra ở
  lần `OrderSend` đầu tiên — nay đã kiểm được ngay từ `INIT`, xem §52.
- 2 scenario `plan_*` vẫn `BLOCKED_PERFORMANCE`; parity Pine ↔ MQL5 Track B vẫn `BLOCKED` (thiếu CSV
  reference từ TradingView).

## 51. Panel trạng thái trên chart cho DemoEA — 2026-10-29

### 51.1 Báo cáo của người dùng và điều tra

Người dùng báo *"mình vẫn chưa thấy bot EA chạy được"*. Kiểm tra tại 10:57 UTC cho thấy EA **đang chạy**,
không crash và không bị gỡ:

- `terminal64.exe` PID 20572, phiên khởi động từ `reports/build/demo-arm/startup.ini`.
- Journal có `expert PATrendRiderXAUv1DemoEA (XAUUSDm,M5) loaded successfully`.
- `pa_trendrider_demo.csv` có `INIT` lúc `10:56:35` (`mode=DEMO_EXECUTION|restored=1|config_hash=6B439450|
  equity=4999.76`) và `REGIME` cho bar `10:50` (`regime=TREND_DOWN|bias=aligned_bearish`).
- Không có vị thế, `entries=0`, `exits=0` — chưa có `ENTRY`, đúng như kỳ vọng ~3.1 lệnh/tháng.

Nguyên nhân của cảm nhận "chưa chạy": trước thay đổi này EA **không vẽ gì lên chart** (không `Comment`,
không `ObjectCreate`), nên trên màn hình chỉ thấy chart đứng yên; cộng với dedup log (§50.5) làm CSV im
lặng nhiều bar. Đây là khoảng trống quan sát, không phải lỗi runtime.

### 51.2 Thay đổi: panel hiển thị, không đụng logic giao dịch

Thêm vào [`../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5):

- `DrawChartStatus(...)` ([`:1155`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1155)) — 5 dòng `Comment()`:
  mode+magic, symbol/timeframe/spread/ATR/equity, state/regime/bias, bar gần nhất + lý do chặn,
  position + counters + drawdown + kill switch. Chỉ đọc state sẵn có, **không** gọi `OrderSend`/`CTrade`,
  không đọc/ghi file.
- `block_reason` cục bộ trong `AnalyseClosedBar` ([`:1095`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1095)):
  lấy `decision.reason` ([`:1119`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1119)), `state|<STATE>` khi
  state machine chặn ([`:1140`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1140)), `position_open`
  ([`:1143`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1143)).
- `OnInit` vẽ lần đầu với `waiting_first_bar` ([`:1330`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1330));
  `OnDeinit` gọi `Comment("")` ([`:1336`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1336)).

Không thay đổi input, preset, guard, sizing hay điều kiện vào lệnh; `config_hash` vẫn `6B439450` sau khi nạp
lại, chứng minh cấu hình không đổi. Compile `MetaEditor64 /compile` → `Result: 0 errors, 0 warnings`
(3498 ms), deploy sang `MQL5\Experts` của Data Folder.

### 51.3 Nạp lại và bằng chứng

Ba lần nạp lại: 10:55:41 và 10:56:35 (bản đầu), 11:01:30 (bản bỏ tiền tố `"\n\n\n"` — thử nghiệm cho thấy
`Comment()` bỏ dòng trống đầu chuỗi, panel **không** dịch xuống, nên đã gỡ tiền tố vô tác dụng này):

| Thời điểm (UTC) | Sự kiện trong CSV |
|---|---|
| 10:55:23 | `SUMMARY` của phiên trước — `OnDeinit` chạy sạch |
| 10:55:41 | `INIT mode=DEMO_EXECUTION restored=1 equity=4999.76 config_hash=6B439450` |
| 10:56:21 | `SUMMARY` của lần nạp lại thứ nhất |
| 10:56:35 | `INIT` lần hai, cùng tham số; `REGIME` bar 10:50 `TREND_DOWN/aligned_bearish` |
| 11:01:20 | `SUMMARY` trước khi đóng terminal để nạp bản mới |
| 11:01:30 | `INIT` lần ba, `restored=1`, `config_hash=6B439450`, `equity=4999.76` |

Ảnh chụp (gitignored, `reports/build/shots/screen4..6.png`) cho thấy chart `XAUUSDm,M5` với panel:

```text
PATrendRiderXAUv1DemoEA  DEMO_EXECUTION  magic=25002001
XAUUSDm PERIOD_H1/PERIOD_M15/PERIOD_M5  spread=240.0 pts  atr=3.71  equity=4999.76
state=WAITING_FOR_SETUP  regime=TREND_DOWN  bias=aligned_bearish
bar=2026.10.29 11:00  block=ENTRY_BLOCKED|reason=bos_against_bias
position=none  entries=0  exits=0  dd=0.00%  kill=0
```

**Bằng chứng sống:** lúc 11:00:37 UTC panel đã nhảy sang `bar=11:00` trong khi CSV **không có dòng mới**
(chỉ `INIT` và `REGIME` bar 10:55) — đúng cơ chế dedup ở §50.5, và đúng điều panel sinh ra để bù đắp.
Panel nằm đè lên nhãn `XAUUSDm,M5` ở góc trên trái (xem ghi chú trong guide §4.2); nội dung vẫn đọc được.

### 51.4 Còn mở

- **Vẫn chưa có `ENTRY`**: panel chứng minh EA sống và cho thấy lý do chặn, **không** chứng minh
  `MQL_TRADE_ALLOWED`; điều đó chỉ lộ ra ở lần `OrderSend` đầu tiên (lỗi 10027 nếu thiếu) — §52 đã ghi
  cờ này ngay trong `INIT`.
- Không nới gate nào để "thấy lệnh": vẫn chờ tín hiệu hợp lệ theo regime/BOS; cron watcher
  `051f5383` vẫn báo khi có `ENTRY`.
- 2 scenario `plan_*` vẫn `BLOCKED_PERFORMANCE`; parity Track B vẫn `BLOCKED` (thiếu CSV reference).

## 52. Kiểm tra quyền giao dịch và chạy live lại trên demo — 2026-10-29

### 52.1 Yêu cầu và khoảng trống được đóng

Người dùng yêu cầu *"kiểm tra và thực hiện chạy trực tiếp"*. Trước §52, trạng thái "EA đã được phép giao
dịch live demo" chưa kiểm được tại thời điểm nạp: guard chỉ đọc `ACCOUNT_TRADE_MODE_DEMO`,
`ACCOUNT_TRADE_ALLOWED`, `TERMINAL_TRADE_ALLOWED`, còn `MQL_TRADE_ALLOWED` (quyền riêng của EA, đến từ
`[Experts] AllowLiveTrading=1`) chỉ lộ ra ở `OrderSend` đầu tiên với error 10027.

Thay đổi: dòng `INIT` ghi thêm `mql_trade_allowed=%d` từ `MQLInfoInteger(MQL_TRADE_ALLOWED)`
([`../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5:1320`](../mt5/Experts/PATrendRiderXAUv1DemoEA.mq5#L1320)).
Đây là **quan sát**, không phải lớp chặn: EA vẫn `INIT_SUCCEEDED` khi cờ tắt, guard và điều kiện vào lệnh
không đổi.

### 52.2 Compile, nạp lại và kết quả

- Compile `Result: 0 errors, 0 warnings` (3409 ms), `.ex5` ghi lúc 18:23:14 local.
- Khởi động lại lúc 18:23:22 local từ `reports/build/demo-arm/startup.ini`.
- Journal: `47 inputs read from expert ...`, `expert PATrendRiderXAUv1DemoEA (XAUUSDm,M5) loaded successfully`,
  `'464140826': authorized on Exness-MT5Trial17 ... (ping: 67.93 ms)`,
  `terminal synchronized ... 0 positions, 0 orders, 355 symbols`,
  `trading has been enabled, demo account - hedging mode`.
- `INIT` lúc `11:23:25` UTC:
  `mode=DEMO_EXECUTION|restored=1|equity=4999.76|config_hash=6B439450|mql_trade_allowed=1`.
- Panel (ảnh `reports/build/shots/screen8.png`, gitignored): `DEMO_EXECUTION`, `magic=25002001`,
  `state=WAITING_FOR_SETUP`, `regime=RANGE`, `bias=timeframe_conflict`, `bar=11:15`,
  `block=ENTRY_BLOCKED|reason=bias_unknown`, `position=none`, `entries=0`, `exits=0`.
- Bar `11:15`: `REGIME regime=RANGE|bias=timeframe_conflict` và `RISK ENTRY_BLOCKED|reason=bias_unknown|
  spread_points=240.0|atr=4.02` — đúng những gì panel hiển thị.
- Tài khoản: balance/equity 4 999.76, 0 vị thế, 0 lệnh.

### 52.3 Phân biệt với lần Strategy Tester 18:18

Cùng ngày, lúc 18:18:49 local có một lần chạy `PATrendRiderXAUv1DemoEA.ex5` **trong Strategy Tester**
(dữ liệu 2026.01.05, 1 lệnh buy, SL dời về hòa, `final balance 5000.00`, `connection closed`). Đó là
backtest, không phải phiên live. Phiên live là chart `XAUUSDm,M5` trên tài khoản demo 464140826, chạy
tick thật từ server; hai thứ độc lập và Strategy Tester không ảnh hưởng EA trên chart.

### 52.4 Còn mở

- **Chưa có `ENTRY`** — panel/CSV đang chặn ở `bias_unknown` (`regime=RANGE`, H1/M15 xung đột). Không nới
  gate nào để tạo lệnh; watcher `051f5383` sẽ báo khi có `ENTRY`/`EXIT`.
- `mql_trade_allowed=1` chứng minh quyền phía terminal; phía server (fill/requote/slippage) đã có bằng
  chứng probe ngày 2026-10-29 (`reference/release.md` mục 16), lần `ENTRY` thật vẫn là bằng chứng cuối.
- 2 scenario `plan_*` vẫn `BLOCKED_PERFORMANCE`; parity Track B vẫn `BLOCKED` (thiếu CSV reference).

## 53. Tái cấu trúc tài liệu v1 → v2 — 2026-10-29

### 53.1 Yêu cầu

Đọc pack `docs/MT5_EA_Lab_v2/`, cập nhật thông tin PA_TrendRider (pack viết khi source còn `UNKNOWN`),
xây dựng lại bộ tài liệu hoàn chỉnh và chuyển tài liệu v1 vào thư mục backup.

### 53.2 Thay đổi

- Chuyển vào archive: `MASTER_ROADMAP.md`, `ROADMAP_MT5_EA_AI_LAB.md`, `PROMPT_AI_IMPLEMENT_ROADMAP.md`,
  hai tài liệu PA_TrendRider tiếng Việt, `phase-reports/`, `MT5_AI_Roadmaps/`,
  `mt5-ea-ai-simulation-pack/`, `pine-to-mt5-pack/` → `docs/archive/v1/`; pack kế hoạch v2 →
  `docs/archive/planning-inputs/MT5_EA_Lab_v2/`. Nội dung giữ nguyên, chỉ đổi vị trí.
- Tạo `docs/archive/README.md` mô tả từng nhóm tài liệu lưu trữ.
- Tạo bộ `docs/v2/` gồm 17 file: README, ROADMAP, PROMPT_AI_IMPLEMENT, ENVIRONMENT, INSTALL_AND_TEST,
  CONFIGURATION, RISK_MODEL, EXECUTION_AND_SAFETY, TEST_REPORT, EVIDENCE, GITHUB_AUDIT, TROUBLESHOOTING,
  BACKLOG_AI, DECISIONS_REQUIRED và 3 tài liệu chiến lược trong `STRATEGIES/`.
- Viết lại `docs/README.md` thành chỉ mục tổng; tạo `docs/MASTER_ROADMAP.md` mới (bản v2), bản v1
  nằm ở archive.
- Sửa toàn bộ liên kết trỏ tới tài liệu đã chuyển: `guides/install-and-test.md`,
  `reference/architecture.md`, `reference/pipeline.md`, `reference/simulation.md`,
  `indicators/README.md`, `indicators/wonderwhales.md`, `README.md` gốc, `PROGRESS.md`.
- Sửa đường dẫn sai trong `docs/v2/STRATEGIES/*` (thiếu một cấp `../` khi trỏ ra khỏi `v2/`).

### 53.3 Bằng chứng

- `validate-project.py`: `SUMMARY: checks=14 fail=0` (exit 0).
- `validate_demo_execution.py`: `SUMMARY: checks=8 fail=0` (exit 0).
- `pytest -q`: `372 passed in 15.13s`.
- Kiểm tra link tương đối trong `docs/` (trừ archive) + README gốc: 0 liên kết hỏng; các link
  `file:///.../tm-trading/...` trỏ đúng file Pine bên ngoài repo.
- Không chạy compile MQL5, không chạy Strategy Tester, không mở terminal trong mục này — thay đổi chỉ là
  tài liệu. Các số liệu tester/demo trích từ bằng chứng đã có, giữ nguyên ngày và đường dẫn gốc.

### 53.4 Còn mở

- GitHub audit vẫn `PARTIAL`: chỉ có shortlist 7 repo, chưa ghi commit SHA/đọc license gốc.
- DCA/Grid demo execution vẫn `BLOCKED_PENDING_ADR` (ADR 0003 điểm 3 và 7).
- DemoEA live vẫn chưa có `ENTRY` do chiến lược; trạng thái giữ `WAITING_FOR_SETUP`.

## 54. P3 — Sửa lỗi báo cáo DCA `adds=0` và `state=state=` — 2026-10-29

### 54.1 Thay đổi

- `mt5/Experts/DCALabEA.mq5`: thêm `g_total_adds` cộng dồn toàn run. SUMMARY có thêm trường
  `basket_adds=`; `adds=` giờ là tổng add. Logic add/risk và counter theo-basket `g_dca_adds` giữ
  nguyên, nên hành vi giao dịch không đổi.
- `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5`: `WriteStateFile` ghi thẳng `g_state.Serialize()`,
  bỏ tiền tố `state=` bị ghép hai lần. Đường `RestoreStateFile` giữ nguyên nên file cũ vẫn đọc được.
- Thêm test hồi quy tĩnh: `python/tests/test_sim_core_source.py::test_dca_summary_reports_cumulative_adds`
  và `python/tests/test_demo_execution.py::test_demo_state_file_has_single_state_prefix`.
- Cập nhật `docs/v2/STRATEGIES/DCA_EA.md`, `docs/v2/TROUBLESHOOTING.md`, `docs/v2/DECISIONS_REQUIRED.md`,
  `docs/v2/TEST_REPORT.md`, `docs/v2/ROADMAP.md`, `docs/MASTER_ROADMAP.md`,
  `docs/reference/simulation.md`.

### 54.2 Bằng chứng

- Compile `DCALabEA.mq5`: `Result: 0 errors, 0 warnings` (`reports/build/DCALabEA_fix.log`), `.ex5` 47,916 bytes.
- Compile `PATrendRiderXAUv1DemoEA.mq5`: `Result: 0 errors, 0 warnings`
  (`reports/build/PATrendRiderXAUv1DemoEA_fix.log`), `.ex5` 122,288 bytes.
- `pytest -q python/tests/test_sim_core_source.py python/tests/test_demo_execution.py`: `29 passed`.
- `pytest -q` toàn bộ: `374 passed in 14.76s` (2026-10-29).
- `.ex5` DCA mới đã copy vào `<Data Folder/MQL5/Experts>` (sha256 khớp file build).
- Runtime Strategy Tester: `NOT_RUN` — terminal demo đang mở phiên (tài khoản demo, XAUUSDm M5);
  chạy tester với `ShutdownTerminal=1` sẽ đóng phiên của người dùng. Không tuyên bố runtime PASS.
- CSV DCA cũ vẫn ghi `adds=0`; đó là bằng chứng lịch sử, không ghi lại.

### 54.3 Còn mở

- Chạy lại 4 scenario `dca_*` khi terminal demo đóng để xác nhận SUMMARY mới; khi đó cập nhật
  `TEST_REPORT` từ `NOT_RUN` sang số liệu thật.
- Kiểm tra file state mới sau một phiên DemoEA thật (hiện chỉ có test tĩnh).

## 55. v2 P0/P1/P2 — kiểm tra demo, GitHub audit, chặn tối ưu plan_* — 2026-10-29

### 55.1 P0 — trạng thái demo (read-only)

- Terminal demo đang chạy build 6292, tài khoản `464140826`, chart `XAUUSDm,M5`, EA
  `PATrendRiderXAUv1DemoEA` nạp lúc 18:23 từ `reports/build/demo-arm/startup.ini` +
  `pa_trendrider_demo_live.set`.
- Journal `MQL5/Files/pa_trendrider_demo.csv`: 172 dòng đến bar 2026-10-29 12:10 (giờ server).
  Sự kiện: `RISK` 103, `REGIME` 20, `BOS` 18, `INIT` 15, `SUMMARY` 14, `KILL` 1, `STATE` 1;
  **0 `ENTRY`, 0 `EXIT`**. Block chính: `bias_unknown|regime=RANGE`, `bos_against_bias`.
- State file vẫn ở dạng cũ `state=state=WAITING_FOR_SETUP;transitions=5` do binary nạp lúc 18:23.
  `.ex5` mới đã deploy 19:07 nhưng EA đang chạy không tự nạp lại; không gỡ EA của người dùng.
- Kết luận P0: chưa có bằng chứng `ENTRY` chiến lược. Không thay đổi gate, không gửi lệnh.

### 55.2 P1 — GitHub audit

- Hoàn tất ở mức metadata cho 7/7 repo: HEAD SHA default branch + license file + SPDX + dòng đầu
  license. Dữ liệu thô `reports/build/github_audit_meta.json`.
- 6 repo `REFERENCE_ONLY` (1 GPL-3.0, 5 MIT); `AlexKu111/GridBot-Mql5` không có license → `REJECT`.
  Không repo nào `USE`; không copy dòng code nào.
- Source review + build/test của repo ngoài: `NOT_RUN`, chỉ bắt buộc nếu đổi sang `USE`.
- Cập nhật `docs/v2/GITHUB_AUDIT.md`, `ROADMAP.md`, `MASTER_ROADMAP.md`, `DECISIONS_REQUIRED.md`,
  `docs/v2/README.md`, `EVIDENCE.md`.

### 55.3 P2 — tối ưu `PriceActionMTF` cho `plan_*`: `BLOCKED_RUNTIME`

- Không chạy được Strategy Tester vì terminal demo đang giữ phiên; chạy `/config` sẽ đóng phiên
  (`ShutdownTerminal=1`). Không có bản MT5 thứ hai để chạy song song.
- Đã xác định hotspot bằng đọc code (không phải profile thật):
  `PriceActionMTF.mq5:701` full replay mỗi bar; `PaMapHtfIndex` quét tuyến tính 0..3000 mỗi lần map
  (`PriceActionMTFContract.mqh:1150`).
- **Không sửa code** trong mục này: thay đổi chỉ có thể chứng minh bằng contract test + tester, cả hai
  đều cần terminal. Sửa rồi tuyên bố "nhanh hơn" sẽ vi phạm quy tắc bằng chứng.
- Điều kiện mở lại: terminal rảnh → chạy `PriceActionMTFContractTests` baseline → tối ưu → chạy lại
  contract test → chạy 2 scenario `plan_*` và ghi SUMMARY.

### 55.4 Gate

- `validate-project.py`: `checks=14 fail=0`.
- `validate_demo_execution.py`: `checks=8 fail=0`.
- `pytest -q`: `374 passed in 13.62s`.
- Không compile lại trong mục 55 (code không đổi); compile của P3 đã ghi ở §54.

## 56. Runtime P3 sau khi đóng terminal demo — 2026-10-29

### 56.1 Bối cảnh

- Người dùng yêu cầu đóng terminal demo rồi chạy lại. Terminal đóng bằng `CloseMainWindow()`
  (không kill process, không đụng file người dùng); sau đó không còn `terminal64.exe`/`metatester64.exe`.
- Phát hiện thêm một lỗi thao tác: `ExpertParameters=<name>.set` được resolve từ
  `MQL5\Profiles\Tester\`, không phải `reports/build/tester-sets/`. Sau lần cài lại MT5, thư mục này
  trống nên lần chạy DCA đầu tiên dùng input mặc định (`config_hash=5AEA1AD2`, 0 entry,
  `spread_exceeded`). Đã copy preset vào đúng chỗ và ghi vào `TROUBLESHOOTING.md` §6.

### 56.2 DCA `dca_baseline` — PASS

- Preset `dca_baseline.set` (sha256 trùng `reports/build/tester-sets/`), `XAUUSDm` M15,
  2026.01.05 → 2026.10.01, model 1-min OHLC.
- CSV 28 610 dòng, mọi dòng `config_hash=3F1C96B9`.
- SUMMARY: `entries=11012|adds=2|basket_adds=0|closed=11014|baskets=11012|open=0|realized=-497.06|max_dd=5.0023|blocks=6581|halted=HALTED`.
- Hai dòng `DCA_ADD`: 2026.02.25 18:15 (`add=1`, vol 0.15, trigger 5207.013) và 18:30 (`add=2`,
  vol 0.225, trigger 5206.930). Số basket/net/DD/block trùng run 2026-10-28 → xác nhận thay đổi chỉ ở
  báo cáo, không đổi hành vi.
- Bằng chứng: `reports/build/tester-reports/dca_baseline/sim_dca_baseline.csv` + `tester_dca_baseline.htm`.

### 56.3 DemoEA state file — PASS

- Scenario `pa_trendrider_demo_exec` (`InpEnableExecution=true`, `InpPersistState=true`,
  `InpResetStateOnInit=true`, magic 25002001), `XAUUSDm` M5, 2026.01.05 → 2026.10.01.
- State file tester: `version=1` / `state=WAITING_FOR_SETUP;transitions=92` — **một** tiền tố `state=`,
  hết `state=state=`.
- Log 55 489 dòng, `config_hash=6B439450`: `RISK` 46 561, `BOS` 7 436, `REGIME` 1 310, `STATE` 90,
  `TRAIL` 33, `ENTRY` 28, `EXIT` 28. SUMMARY:
  `net=74.77|balance=5074.77|drawdown_pct=0.3123|state=WAITING_FOR_SETUP|transitions=92|kill_switch=0`.
- Đây là dữ liệu tester, **không** phải live; không dùng để kết luận lợi nhuận.
- Bằng chứng: `reports/build/tester-reports/pa_trendrider_demo_exec/` (CSV, state, htm, png).

### 56.4 Docs và gate

- Cập nhật `TEST_REPORT.md` §8 (bảng P3 + số liệu), `DCA_EA.md` §5/§6, `TROUBLESHOOTING.md` §6
  (thêm mục preset và single-instance), `DECISIONS_REQUIRED.md` §6/§7, `ROADMAP.md` P3,
  `MASTER_ROADMAP.md`, `reference/simulation.md` §8.
- Code không đổi trong mục này; không compile lại. Gate chạy lại ở §56.5.

### 56.5 Trạng thái mở

- P2 `plan_*`/`PriceActionMTF`: terminal đã rảnh nhưng **chưa** chạy đo lại; vẫn `BLOCKED_RUNTIME`
  cho tới khi có lần đo mới. Bước tiếp theo: chạy `diag_plan_1m` lấy thời gian nền, rồi mới quyết
  định sửa `PaMapHtfIndex`/replay.
- P0 `ENTRY` live trên demo: vẫn chưa có; phiên live 2026-10-29 chỉ có block `bias_unknown`.
- Grid/DCA demo execution: vẫn `BLOCKED_PENDING_ADR` (ADR 0003).

## 57. v2 P2 — tối ưu `PriceActionMTF`, mở `plan_*` trong tester — 2026-10-29

### 57.1 Bối cảnh

- Roadmap v2 P2 yêu cầu tối ưu `PriceActionMTF` để 2 scenario `plan_*` chạy hết 9 tháng trong
  Strategy Tester. Trước đó trạng thái là `BLOCKED_PERFORMANCE`/`BLOCKED_RUNTIME` vì terminal demo
  đang mở.
- Terminal đã đóng sau §56 nên lần này chạy được headless. Ràng buộc: **không** đổi hành vi tín hiệu;
  mọi thay đổi hiệu năng phải chứng minh tương đương số học và chạy lại contract test.

### 57.2 Đo nền (trước tối ưu)

- Scenario `diag_plan_1m` (XAUUSDm M15, 2026.01.05 → 2026.02.04, 2 000 lần gọi, 25 715 nến).
- Log `PAMTF|PROF`: `pass1=36181ms prep=21743ms replay=95390ms total=153313ms`, wall ~165 s.
- Hotspot: full replay engine mỗi nến + `PaMapHtfIndex` quét tuyến tính + `CopyRates(0,3000)` trượt
  cửa sổ buộc tính lại EMA.

### 57.3 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Include/PinePort/PriceActionMTFContract.mqh` | `PaMapHtfIndex`: quét tuyến tính → binary search trên `closeTime` đã sắp xếp |
| `mt5/Indicators/PinePort/PriceActionMTF.mq5` | `PA_REPLAY_INCREMENTAL 1`: giữ `PaEngineState` của nến đóng cuối, chỉ replay nến mới; guard hợp lệ = cùng `bar time` **và** cùng `close`, nếu lệch thì full replay |
| `mt5/Indicators/PinePort/PriceActionMTF.mq5` | Cache HTF append-only (`g_ctxCloseT/g_setupCloseT`, `PaAppendHtfCache`) + `PA_HTF_WINDOW 3000`: chỉ thêm nến HTF mới đóng, EMA luôn trên đúng 3000 nến gần nhất (giữ nguyên cửa sổ cũ) |

- Cả hai `#define` giữ nhánh `0` để A/B; không có dead code đo đạc nào còn lại trong source.

### 57.4 Đo lại và chứng minh tương đương

- Cùng `diag_plan_1m`: `pass1=31243ms prep=25ms replay=67ms total=31335ms`, wall ~41 s
  (153 313 ms → 31 335 ms, ~4.9×; phần replay 95 390 ms → 67 ms).
- Checksum nội bộ trên 18 buffer (500 nến cuối, in mỗi 200 lần gọi) **giống nhau** giữa full replay và
  incremental ở cả ba mốc: 1600 → `3815744811.104`, 1800 → `3964751555.199`,
  2000 → `3760455708.970`.
- A/B `PA_HTF_WINDOW 3000` vs EMA toàn bộ lịch sử: checksum giống nhau ở cả ba mốc; chọn 3000 để giữ
  đúng ngữ nghĩa `CopyRates(0,3000)` cũ.
- Sau khi gỡ instrumentation: compile `0 errors, 0 warnings` (`deploy_pineport.ps1 -Apply -Force`),
  `PriceActionMTFContractTests` → `TEST|RESULT|ALL_PASS|pass=125 fail=0|contract=1.0.0` (21:40:27).

### 57.5 `plan_*` toàn kỳ 9 tháng — PASS, 0 trade

| Scenario | Wall | `config_hash` | SUMMARY |
|---|---:|---|---|
| `plan_baseline` | 389.9 s | `A529A48A` | `entries=0\|rejected=0\|trades=0\|wins=0\|losses=0\|flats=0\|net=0.00\|realized=0.00\|max_dd=0.0000\|blocks=0\|halted=ACTIVE` |
| `plan_edge_tp3_stop_only` | 409.8 s | `7DA9E7C9` | giống hệt |

- Cả hai chạy đủ 2026.01.05 → 2026.10.01; dòng `SUMMARY` ở bar `2026.09.30 23:45`. CSV chỉ có
  `INIT` + `SUMMARY`, không có dòng trade.
- Bằng chứng: `reports/build/tester-reports/plan_baseline/` và
  `reports/build/tester-reports/plan_edge_tp3_stop_only/` (CSV, `tester_*.htm`, png). Chạy lại bằng
  `reports/build/tester-run/run_tester.ps1 -Scenario <name>` (script mới, archive ngay sau mỗi run để
  không mất CSV khi agent dọn `MQL5\Files`).

### 57.6 Vì sao 0 trade — xác nhận runtime, không sửa

- Chẩn đoán tạm thời trong indicator (đã gỡ): `plan_invalid=25 714/25 715` nến, trong khi
  `dir_up=15 763`, `dir_dn=9 950`, `atr_ok=25 701`, `sl_ok=25 700`, `score=14..87`. Mọi gate khác đạt;
  chỉ `rrOk` chặn.
- Nguyên nhân: source Pine mặc định `pa_rr1 = 1.0`, `pa_rrMin = 1.5` → `rrOk = (rr1 >= rrMin)` luôn
  false → `plan.valid = false` → không bao giờ có signal. Đây là quirk của source, đã ghi ở
  [`indicators/price-action-mtf.md`](indicators/price-action-mtf.md) §9 và decision P9.
- **Không** sửa `rr1`/`rrMin` trong code: làm vậy là đổi chiến lược. Muốn có trade phải đổi cấu hình
  (`rr1 >= rrMin`, ví dụ `rr1=2.0`, hoặc `rrMin=0`) và chạy scenario mới.

### 57.7 Gate

- `validate-project.py`: `SUMMARY: checks=14 fail=0`.
- `validate_demo_execution.py`: `SUMMARY: checks=8 fail=0`.
- `pytest -q`: `374 passed in 15.31s`.
- Compile: 30 file `.mq5`, tất cả `0 errors, 0 warnings`.

### 57.8 Docs

- `docs/v2/TEST_REPORT.md`: thêm §7.2b `plan_*` + dòng tổng hợp.
- `docs/v2/EVIDENCE.md`: thêm 5 dòng bằng chứng và §2.7.
- `docs/v2/ROADMAP.md`: P2 → DONE kèm số đo.
- `docs/v2/README.md`: bảng trạng thái có dòng `plan_*`/`PriceActionMTF`.
- `docs/guides/strategy-tester.md`: §8 + §9.2 viết lại (PASS 0 trade), bỏ `BLOCKED_PERFORMANCE`.
- `docs/guides/install-and-test.md`, `docs/guides/toolchain.md`: 15/15 scenario.
- `docs/indicators/price-action-mtf.md`: §7 (bar policy) + §7.3 (bảng đo, checksum, cache HTF).

### 57.9 Trạng thái mở

- P0 `ENTRY` live trên demo: vẫn chưa có (regime `RANGE`/`bias_unknown`).
- Grid/DCA demo execution: vẫn `BLOCKED_PENDING_ADR` (ADR 0003).
- Parity Pine ↔ MQL5 Track B: vẫn `BLOCKED` (thiếu CSV reference từ TradingView).
- Muốn `plan_*` có trade: tạo scenario cấu hình `rr1 >= rrMin`, không sửa code. **Đã đóng ở §58**
  (`plan_rr2`, 93 trade ảo, CSV kiểm toán PASS).

## 58. v2 P2 follow-up — `plan_rr2`: `plan_*` có trade thật + kiểm toán CSV — 2026-10-29

### 58.1 Mục tiêu

Đóng mục mở cuối của §57.9: chạy một scenario `plan_*` đặt `rr1 > rrMin` **bằng cấu hình bridge**,
không sửa default Pine, để chứng minh đường `PLAN_ENTRY → EXIT → SUMMARY` hoạt động hết kỳ và
kiểm toán tính nhất quán của CSV.

### 58.2 Cấu hình và lần chạy

- Scenario `plan_rr2`: `reports/build/tester-run/plan_rr2.ini` + `reports/build/tester-sets/plan_rr2.set`.
- Bridge PA: `InpPaRr1=2.0`, `InpPaRrMin=1.5` (journal in `PAMTF|INFO|bridge|rr1=2.00|rrMin=1.50`).
- `PinePlanSimEA` `config_hash=D6CEF886`; indicator `hash=E231116A`.
- `XAUUSDm` M15, `Model=1`, 2026.01.05 → 2026.10.01, deposit 10 000 USD, leverage 1:100,
  build 6292, tài khoản demo `Exness-MT5Trial17` (file config không chứa credential).
- Report: History Quality 100%, `Bars: 17595`, `Ticks: 1053473`.
- Wall time ≈ 336 s (journal `INIT` 23:17:58.456 → CSV ghi 23:23:34.549); đo bằng dấu vết file,
  không phải số MT5 in ra.

### 58.3 Kết quả thật

`SUMMARY` tại bar `2026.09.30 23:45`:

```text
source=PriceActionMTF|entries=93|rejected=0|trades=93|wins=26|losses=67|flats=0|net=-333.11|realized=-333.11|max_dd=5.0210|blocks=99|halted=HALTED
```

- Equity cuối `9 666.89`, drawdown đỉnh `5.0210 %` → RiskGuard `max_drawdown_reached`, HALTED.
- 287 dòng CSV: 1 `INIT`, 93 `ENTRY`, 93 `EXIT`, 99 `RISK`, 1 `SUMMARY`.
- `EXIT`: 26 `TARGET_HIT|mode=TP1` (tổng `pnl=+1553.61`) và 67 `SL_GAP` (tổng `pnl=-1886.71`);
  hai số này cộng lại khớp `net=-333.11`. Bars held: min 0, median 17, max 320.
- 99 dòng `RISK` là `ENTRY_BLOCKED|reason=max_drawdown_reached|state=HALTED`, dồn ở 2026.09.22–23.
- `Net` là **đơn vị mô hình** (contract size 1, volume 1.0, không commission/slippage/swap/margin);
  không phải lợi nhuận và không suy ra được lot hay P&L broker.

### 58.4 Kiểm toán CSV

| Kiểm tra | Kết quả |
|---|---|
| `config_hash` đồng nhất toàn file | PASS — 287/287 dòng `D6CEF886` |
| Cặp ENTRY/EXIT | PASS — 93/93, không vị thế mở ở nến cuối |
| SL/TP đúng phía entry theo `side` | PASS — 0 vi phạm |
| `volume` mỗi entry | PASS — tất cả `1.0000` (đúng `InpMaxVirtualExposure=1.0`) |
| Sự kiện giao dịch thật (broker) | Không có — EA simulation-only, log chỉ ghi vị thế ảo |

Tool hiện có `scripts/audit_signal_csv.py` ràng buộc định dạng `PineSignalLabEA` (cột `bar_open_time`,
`signal_id`…), không dùng được cho journal 18 cột của `PinePlanSimEA`; kiểm toán trên làm bằng
truy vấn CSV trực tiếp. Chưa có script audit định dạng plan — mục mở này đã đóng ở §59 với
`scripts/audit_plan_csv.py`.

### 58.5 Phát hiện: 93/93 lệnh là BUY

- CSV có **0 dòng SELL** trong toàn kỳ 9 tháng, dù diagnostic §57.6 đếm `dir_dn=9 950` nến.
- Nguyên nhân nằm ở cổng score, không ở dữ liệu:
  `score100 = round(50 + rawScore*50)` với `rawScore ∈ [-1, 1]`, `dir = sign(rawScore)`,
  trong khi `okScore = score100 > scrNoTrade` và default `scrNoTrade = 49`
  (`InpScrNoTrade`, [price-action-mtf.md §10.5](indicators/price-action-mtf.md)).
  `score100 ≥ 50` ⇔ `rawScore ≥ -0.01`, còn `dir == -1` đòi `rawScore < 0`; hai tập chỉ giao nhau
  trong dải `rawScore ∈ [-0.01, 0)` → `okScore` sai ở gần như mọi nến giảm → `signal` sai →
  `sigShort` hầu như không bao giờ bật. Ngược lại `dir == 1` có nguyên dải `50..100`.
- Đây là hành vi **của cổng được port nguyên**, không phải lỗi copy sai cú pháp; chưa đối chiếu
  từng dòng với source Pine (Track B vẫn `BLOCKED`), nên chưa kết luận Pine gốc có cùng hệ quả.
- **Không sửa** `scrNoTrade` hay công thức score: đổi ngưỡng là đổi chiến lược. Muốn test phía
  short phải bằng cấu hình và có bằng chứng buffer, xem mục mở.

### 58.6 Đăng ký scenario và hợp nhất input bridge

`plan_rr2` ban đầu chỉ có `ini`/`set` trong `reports/build/`, chưa nằm trong registry nên
`validate_sim_configs.py` không biết tới. Sau khi đăng ký, validator báo:

```text
PASS: project.example.json (presets=6 scenarios=18)
SUMMARY: checked=7 fail=0
```

Thay đổi cấu hình (không đụng logic tín hiệu):

| File | Thay đổi |
|---|---|
| `configs/project.example.json` | thêm scenario `plan_rr2` (`overrides` `InpPaRr1=2.0`, `InpPaRrMin=1.5`) → 18 scenario |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | contract `PinePlanSimEA` nhận `InpPaRr1` (`>0`) và `InpPaRrMin` (`>=0`) — khớp ràng buộc `OnInit` của EA (dòng 157, 162) |
| `configs/sim/pine_plan_lab.json` | thêm hai input với đúng default EA (`1.0`, `1.5`) vì validator bắt buộc đủ bộ input; `assumptions.indicator` viết lại cho khớp thực tế bridge |
| `reports/config-snapshots/` | snapshot mới `PinePlanSimEA-2D8AD770.json`, `track-c-simulation-presets-AA3EC6F4.json` (immutable, snapshot cũ giữ nguyên) |

Trước khi thêm input vào contract, validator fail-closed đúng như thiết kế:
`scenarios[12].overrides.InpPaRr1: unknown input for PinePlanSimEA`.

### 58.7 Gate chạy lại

- `scripts/validate-project.py` → `SUMMARY: checks=14 fail=0`.
- `scripts/validate_demo_execution.py` → `SUMMARY: checks=8 fail=0`.
- `scripts/validate_pamtf.py` → `VALIDATION_OK: pass=36 fail=0`.
- `scripts/validate_sim_configs.py` → `SUMMARY: checked=7 fail=0`, `presets=6 scenarios=18`.
- `pytest -q` → `374 passed`.
- MQL5 không đổi trong bước này nên kết quả compile và contract test ở §57.4 giữ nguyên;
  không có tuyên bố compile/backtest mới nào ngoài các số thật ở §58.2–§58.3.

### 58.8 Trạng thái mở sau §58

- Q11 (cửa short bị `okScore` chặn; trước đây ghi nhầm là "Q8" — xem §60.1): mới có bằng chứng gián
  tiếp `plan_rr2` 0 SELL + suy luận công thức; chưa đếm buffer `PA_BUF_BLOCK` theo `dir`, và chưa đối
  chiếu source Pine (Track B `BLOCKED`). **Không** đổi `scrNoTrade` trước khi có hai thứ đó.
  **Buffer đã đếm ở §60 (2026-10-30); parity Pine vẫn `BLOCKED`.**
- Chưa có script audit tự động cho journal 18 cột của `PinePlanSimEA` (kiểm toán §58.4 làm thủ công).
  **Đã đóng ở §59.**
- `net` và `max_dd` là đơn vị mô hình; không dùng để kết luận hiệu quả chiến lược.

## 59. v2 P3 — script audit journal 18 cột của `PinePlanSimEA` — 2026-10-30

### 59.1 Mục tiêu

Kiểm toán §58.4 được làm bằng lệnh Python ad-hoc, không tái sử dụng được. ROADMAP P3 yêu cầu một
tool tự động trong `scripts/` + test pytest, tái hiện đúng những bất biến đã kiểm tra thủ công,
không sửa EA và không thay đổi kết quả run nào.

### 59.2 File mới

| File | Vai trò |
|---|---|
| [`python/src/mt5_ea_ai_lab/evaluation/plan_audit.py`](../python/src/mt5_ea_ai_lab/evaluation/plan_audit.py) | `audit_plan_csv()`, `PlanAuditReport`, `write_audit_report()` → `plan_audit.json`; cùng khuôn với `signal_audit.py`/`multi_signal_audit.py` |
| [`scripts/audit_plan_csv.py`](../scripts/audit_plan_csv.py) | CLI `--csv`, `--out-dir`, `--offset-minutes`; exit 0/1/2 |
| [`python/tests/test_plan_audit.py`](../python/tests/test_plan_audit.py) | 38 test: fixture INIT/ENTRY/EXIT/RISK/SUMMARY, mỗi issue kind có test dương và test sạch |

`scripts/audit_signal_csv.py` vẫn ràng buộc định dạng `PineSignalLabEA` (§58.4) nên không dùng chung;
tool mới parse header 18 cột của simulation core và từ chối file thừa/thiếu cột (exit 2).

### 59.3 Bất biến được kiểm

- Danh tính run: đúng 18 cột, `ea=PinePlanSimEA`, một `config_hash`/symbol/timeframe mỗi file, `INIT`
  ở dòng đầu mang `SIMULATION_ONLY` với `config_hash` khớp cột, `SUMMARY` ở dòng cuối.
- Vòng đời: `ENTRY` không lồng nhau, `EXIT` không mồ côi, `side` `EXIT` khớp vị thế đang mở,
  không còn vị thế ở `SUMMARY` (`max_concurrent_positions` được báo cáo).
- Hình học giá: BUY `sl < entry < tp`, SELL `sl > entry > tp` trên cả `ENTRY` lẫn `EXIT`,
  `entry > 0`, `volume > 0`.
- Bộ đếm `SUMMARY` đếm lại từ dòng thật: `entries`, `trades`, `rejected` (`PLAN_REJECTED`),
  `blocks` (`ENTRY_BLOCKED`), `wins+losses+flats = trades`, và `net`/`realized` so với tổng token
  `pnl=` của các `EXIT` với ngưỡng 0.05 (bù làm tròn 2 chữ số in ra).
- Thời gian/số: `bar_time` không giảm dần trên `ENTRY/EXIT/RISK/SUMMARY`, căn timeframe
  (`PERIOD_M15` → 900 s), mọi cột số parse được, `equity >= 0`, `drawdown_pct` trong 0..100.
  `INIT` loại khỏi chuỗi thời gian vì logger ghi epoch `1970.01.01`.

### 59.4 Chạy trên dữ liệu thật (báo cáo thật, không suy luận)

| Journal | Kết quả |
|---|---|
| `reports/build/tester-reports/plan_rr2/sim_plan_rr2.csv` | `status=ok rows=287 hash=D6CEF886 events=ENTRY=93,EXIT=93,INIT=1,RISK=99,SUMMARY=1 entry_sides=BUY=93 exit_reasons=SL_GAP=67,TARGET_HIT=26 open_at_end=0 net=-333.11 issues=0` |
| `.../plan_baseline/sim_plan_baseline.csv` | `status=ok rows=2 events=INIT=1,SUMMARY=1 net=0.00 issues=0` |
| `.../plan_edge_tp3_stop_only/sim_plan_edge_tp3_stop_only.csv` | `status=ok rows=2 events=INIT=1,SUMMARY=1 net=0.00 issues=0` |

Ba journal khớp toàn bộ con số đã ghi ở §58.3–§58.4 (`entries=93`, `trades=93`, `wins=26`,
`losses=67`, `flats=0`, tổng `pnl` = -333.1096 so với `net=-333.11`). Công cụ không phát hiện thêm
vấn đề nào, kể cả 99 dòng `ENTRY_BLOCKED` — đó là RiskGuard hoạt động đúng, không phải lỗi cấu trúc.

### 59.5 Docs cập nhật

- `docs/guides/install-and-test.md`: mục mới **4.1 "Audit tự động journal plan"** trong phần
  "Track C — PinePlanSimEA (W10)" — lệnh chạy, bảng nhóm kiểm tra, giải thích `--offset-minutes`,
  nhắc `net` là đơn vị mô hình.
- `docs/v2/ROADMAP.md`: dòng P3 chuyển sang DONE.

### 59.6 Gate

- `pytest -q` → `412 passed` (374 trước + 38 test mới).
- `scripts/validate-project.py` → `SUMMARY: checks=14 fail=0`.
- `scripts/validate_sim_configs.py` → `SUMMARY: checked=7 fail=0` (không đổi; chỉ thêm file Python).
- MQL5 không sửa: không có tuyên bố compile hay backtest mới trong §59.

---

## 60. v2 P2 — xác minh thực nghiệm cổng `okScore` chặn cửa short (đổi id thành Q11) — 2026-10-30

### 60.1 Mục tiêu và một sửa đổi về nhãn

§58.8 để lại một câu hỏi mở: suy luận "cổng `okScore` gần như loại toàn bộ cửa short" mới dựa trên
công thức và hệ quả gián tiếp (`plan_rr2` 0 SELL). ROADMAP P2 yêu cầu **đếm buffer
`PA_BUF_BLOCK` theo `dir`** trên một kỳ tester trước khi bàn bất kỳ việc đổi ngưỡng nào.

Cũng trong bước này phát hiện một xung đột id: [`docs/indicators/price-action-mtf.md`](../docs/indicators/price-action-mtf.md)
dùng "Q8" cho cả hành vi cổng score (§10.5) lẫn quirk timeout `xExit = tp1` (§11.5 và bảng §16).
Bảng §16 mới là danh sách quirk chuẩn, nên hành vi cổng score được cấp id **Q11**; các tham chiếu
ROADMAP/EVIDENCE/TEST_REPORT/§58.8 trỏ tới cổng score đều đổi sang Q11.

### 60.2 Cách đo

| Đối tượng | Chi tiết |
|---|---|
| Expert chẩn đoán tạm | `reports/build/q8-diag/ZZPlanBlockCount.mq5` (không nằm trong build của repo; chỉ deploy vào `MQL5\Experts` của Data Folder) |
| Compile | `Result: 0 errors, 0 warnings, 932 ms elapsed, cpu='X64 Regular'`; `.ex5` 18 656 byte, log tester ghi `18688 bytes loaded` |
| Đọc dữ liệu | `iCustom(... "PinePort\PriceActionMTF", rr1=2.0, rrMin=1.5)` rồi `CopyBuffer(..., index, 1, 1, ...)` cho 6 buffer `PA_BUF_SCORE100`, `PA_BUF_DIR`, `PA_BUF_PLAN_VALID`, `PA_BUF_SIG_LONG`, `PA_BUF_SIG_SHORT`, `PA_BUF_BLOCK` — một mẫu mỗi nến đã đóng, warmup 200 nến |
| Quyền hạn | chỉ đọc buffer; không portfolio, không hàm lệnh. Báo cáo tester: `Deals: 0`, `Total Net Profit: 0.00` |
| Kỳ chạy | `q8_block_count.ini`: XAUUSDm M15, 2026.01.05→2026.10.01, Model=1 — **đúng kỳ của `plan_rr2`** (`Bars: 17595`, `Ticks: 1053473`, Quality 100 %) |
| Thời gian thật | 10:25:36.851 → 10:32:18.600 cho thread test (≈ 402 s); `run_tester.ps1` ghi `terminal64 exited after 415.8s (code 0)` |
| Xuất | `reports/build/tester-reports/q8_block_count/` (sha256 12 ký tự đầu): `q8_block_counts.csv` 527 B `1AFA5488662D`, `tester_q8_block_count.htm` 23 972 B `EC859E821BDA`, `.png` 4 901 B `47B01D45E19F`, `q8_agent_journal.txt` 1 082 B `7E10A391F575` — 8 dòng log `DIAG\|...` khớp từng chữ với CSV |

### 60.3 Số đo được (không suy luận)

| `dir` | nến | `score100 > 49` | `plan_valid` | signal | `score100` min..max | block 0 `NONE` | 1 `PLAN_INVALID` | 2 `MTF_FILTER` | 3 `HTF_VETO` | 4 `COOLDOWN` | 5 `DAY_LIMIT` | 6 `SCORE` | 7 `DIR` | 8 `CONFLUENCE` | 9 `REGIME` |
|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| −1 (down) | 8 414 | **188** | 8 414 | **0** | 15 .. **50** | 0 | 0 | 1 346 | 4 069 | 1 | 0 | **2 961** | 0 | 35 | 2 |
| 0 (flat) | 0 | 0 | 0 | 0 | không có mẫu | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| +1 (up) | 9 181 | **9 181** | 9 181 | **302** | 50 .. 87 | 302 | 0 | 1 734 | 1 806 | 782 | 63 | **0** | 0 | 3 880 | 614 |

`bars_considered = 17595`, `bars_skipped = 0`; mỗi hàng cộng đúng về số nến của `dir` đó.

Bốn kết luận trực tiếp từ bảng:

1. Cổng `SCORE` là gate **bất đối xứng**: chặn trước tiên 2 961/8 414 nến down (35,2 %) và **0/9 181**
   nến up.
2. Phía down chỉ có **188/8 414 (2,23 %)** nến qua được `okScore`, và giá trị `score100` lớn nhất quan
   sát được ở phía down đúng bằng **50** — tức miền qua cổng là `{50}`, khớp dải giải tích
   `rawScore ∈ [-0.01, 0)` của §10.5. Phía up: 100 % qua cổng.
3. Trong 17 595 nến, `PA_BUF_DIR` **không bao giờ bằng 0**, và `signal` phía down **bằng 0** — kể cả
   188 nến qua cổng score đều bị gate khác chặn trước, nên `PA_BUF_SIG_SHORT` không bật lần nào.
4. `plan_valid` = 100 % cả hai phía nên `block_1` bằng 0 ở cả hai hàng: cầu `rr1=2.0 ≥ rrMin=1.5`
   đã mở (đúng bridge của `plan_rr2`), phần còn lại là gate.

Đối chiếu journal: `plan_rr2` có 93 `ENTRY` + 99 `RISK|ENTRY_BLOCKED`, toàn BUY; buffer đếm 302 nến
signal phía up. Hai đại lượng không kỳ vọng bằng nhau — EA chỉ xét tín hiệu khi đang phẳng và có
RiskGuard riêng — nhưng cùng xác nhận **không có bất kỳ tín hiệu short nào** trong kỳ.

### 60.4 Những gì bước này **không** làm

- Không sửa `InpScrNoTrade`, không sửa công thức score, không sửa `PriceActionMTF*`, không sửa EA.
  `find mt5 -newermt "2026-10-30 00:00"` trả về 0 file — không có file MQL5 nào bị chạm trong ngày;
  7 file `mt5/` đang `M` trong `git status` là thay đổi của §54–§58 từ 2026-10-29.
- Không kết luận "cần hạ ngưỡng": đổi ngưỡng là đổi chiến lược, và cổng vẫn phải đối chiếu nguồn Pine.
- Parity với Pine vẫn `BLOCKED` (Track B, chưa có CSV Pine), nên số đo này là bằng chứng **buffer của
  port**, không phải bằng chứng rằng Pine cũng hành xử y hệt.
- Trạng thái môi trường: `ZZPlanBlockCount.mq5` + `.ex5` vẫn nằm trong `MQL5\Experts` của Data Folder
  để chạy lại được (kèm `ZZContract_*` của 2026-10-29). Bản sao lưu ở `reports/build/q8-diag/`
  (gitignored, cùng `compile.log`). Muốn dọn: xoá hai file trong Data Folder; repo không tham chiếu
  chúng trong build.

### 60.5 Docs cập nhật

- `docs/indicators/price-action-mtf.md`: §10.5 đổi id Q8 → Q11 kèm ghi chú trùng id, bổ sung số đo
  thật; bảng §16 thành Q1–Q11 và thêm dòng Q11.
- `docs/indicators/README.md`: trạng thái port PriceActionMTF ghi `Q1–Q11`.
- `docs/v2/EVIDENCE.md`: dòng bảng tra cho thư mục `q8_block_count/` + mục §2.10.
- `docs/v2/ROADMAP.md`: dòng P2 (xác minh cổng `okScore`) chuyển sang DONE một phần — buffer đã đo,
  parity Pine còn `BLOCKED`.
- `docs/v2/TEST_REPORT.md` + `docs/PROGRESS.md` §58.8: đổi tham chiếu Q8 → Q11.

### 60.6 Gate (chạy lại 2026-10-30 sau khi sửa docs)

- `pytest -q` → `412 passed in 15.02s` (không đổi; bước này không thêm code Python).
- `scripts/validate-project.py` → `SUMMARY: checks=14 fail=0` — gồm kiểm tra link docs, nên việc đổi
  id Q8 → Q11 và thêm tham chiếu §60 không phá link.
- `scripts/validate_sim_configs.py` → `SUMMARY: checked=7 fail=0` (presets=6, scenarios=18).
- `scripts/validate_pamtf.py` → `VALIDATION_OK: pass=36 fail=0`.
- Không có compile mới: MQL5 không sửa. Báo cáo tester của chính bước này có `Deals: 0`.

## 61. Docs — hướng dẫn chạy bot cho người chưa từng dùng MT5 — 2026-10-30

### 61.1 Mục tiêu và phạm vi

Người dùng yêu cầu: *"mình là người mới chưa sử dụng MT5 và Bot EA bao giờ, hãy cho file docs hướng dẫn
chi tiết từng bước để chạy được một con bot và kiểm tra trực tiếp xem cách bot vận hành"*. Kết quả là
[`guides/beginner-first-run.md`](guides/beginner-first-run.md) (435 dòng, 10 phần, sha256
`17a5371ae33c4f0022ff1bf9fb3f593a85414b8daaeb1146559fa8f169674e99`).

Phạm vi: **chỉ tài liệu + kiểm chứng số liệu bằng lệnh thật**. Không sửa MQL5, không chạy tester mới,
không thêm code Python, không đụng đường gửi lệnh. Bot được hướng dẫn là `PinePlanSimEA` (mô phỏng,
không `OrderSend`/`CTrade`); đường demo execution chỉ được *giới thiệu* ở Phần 6 và trỏ sang
[`guides/demo-execution.md`](guides/demo-execution.md).

### 61.2 Cấu trúc guide

| Phần | Nội dung | Vì sao ở đó |
|---|---|---|
| 1 | 5 khái niệm + sơ đồ cửa sổ | người mới chưa có từ vựng |
| 2 | Chuẩn bị một lần: demo login, `XAUUSDm`, `deploy_pineport.ps1 -Apply`, compile, F5 | mọi bước sau phụ thuộc |
| 3 | Strategy Tester có hình, 12 bước UI, khuyến nghị 1 tháng (2026.09) M15 | cách nhanh nhất để *nhìn* bot chạy |
| 4 | Journal 18 cột: đường dẫn, từ điển cột, 3 dòng thật + `SUMMARY`, quirk `Q11`, auditor | bằng chứng thật nằm ở đây |
| 5 | Gắn EA lên chart thật, log khởi động, `InpDebug`, cách dừng | "ngồi cạnh bot" |
| 6 | Ranh giới demo/live (bảng Được/Cấm, ADR 0003, ADR 0004 chưa có) | ngăn hiểu nhầm "bot đã trade" |
| 7–10 | 12 lỗi thường gặp, checklist 11 mục, thuật ngữ, đọc tiếp | tự xử lý khi kẹt |

### 61.3 Những gì đã kiểm chứng bằng lệnh thật (không suy luận)

- `audit_plan_csv.py` chạy trên bản CSV lưu trong repo, output nguyên văn ghi vào §4.5:
  `status=ok rows=287 hash=D6CEF886 … events=ENTRY=93,EXIT=93,INIT=1,RISK=99,SUMMARY=1
  entry_sides=BUY=93 exit_reasons=SL_GAP=67,TARGET_HIT=26 open_at_end=0 net=-333.11 issues=0`
  (exit code 0). Trạng thái là `ok`/`issues`, **không có** `fail`; exit code 1 khi `issues`, 2 khi
  `audit_error:` — đọc trực tiếp từ `scripts/audit_plan_csv.py:57-85` và các `kind=` trong
  `python/src/mt5_ea_ai_lab/evaluation/plan_audit.py` (24 loại, ví dụ `stop_on_wrong_side`,
  `off_grid`, `orphan_exit`, `mixed_config_hash`).
- Số học `rows=287 = 1 INIT + 93 ENTRY + 93 EXIT + 99 RISK + 1 SUMMARY` và
  `67 + 26 = 93` khớp `losses`/`wins` trong dòng `SUMMARY`.
- Ba dòng log khởi động EA lấy từ chuỗi format thật ở `mt5/Experts/PinePlanSimEA.mq5:778`
  (`initialized`), `:782` (`pa_bridge`), `:784` (`simulation_only`) — guide ghi rõ nguồn dòng để người
  đọc phân biệt "log sẽ thấy" với "log đã lưu trong repo".
- `plan_rr2.set` (`InpPaRr1=2.0`, `InpMaxSpreadPoints=600.0`, `InpLogFile=sim_plan_rr2.csv`) đối chiếu
  default trong EA để viết mục "Hai cái bẫy" — hai lý do khiến người mới thấy 0 lệnh.

**Hạn chế ghi lại:** `reports/build/tester-reports/plan_rr2/plan_rr2.journal.txt` chỉ có 3 dòng
(2 dòng `PAMTF|…` của indicator + 1 dòng `LAB|INFO|plan|initialized|…`), nên dòng `pa_bridge` và
`simulation_only` chưa có trong artifact đã lưu; chúng là dự đoán theo source, không phải trích từ log.
Guide không được thử nghiệm bởi một người mới thật — trạng thái "người khác làm theo từ đầu đến cuối" là
`NOT_RUN`.

### 61.4 Dọn lỗi render bảng trên toàn bộ docs

Lint tế bào bảng (số cột mỗi dòng so với header, tách theo `|` không đứng sau `\`) tìm thấy **35 dòng hỏng**
ở 12 file, hầu hết do `|` trần nằm trong inline code (GFM vẫn tách cell trong trường hợp này). Phân bố:
27 dòng escape trong code span, 1 dòng bị xuống dòng giữa cell, 7 dòng `|` trần kiểu giá trị tuyệt đối
(`|diff|`). Đã sửa:

- 27 dòng escape `\|` trong code span — `docs/guides/demo-execution.md` (5), `docs/reference/release.md` (3),
  `docs/reference/simulation.md` (2), `docs/reference/risk.md` (1), `docs/PROGRESS.md` (3),
  `docs/v2/ROADMAP.md` (2), `docs/v2/EVIDENCE.md` (1), `docs/v2/EXECUTION_AND_SAFETY.md` (1),
  `docs/indicators/tm-indicator-2.md` (4), `docs/indicators/tm-xau-signals-2.md` (3),
  `docs/indicators/price-action-mtf.md` (2).
- `docs/guides/strategy-tester.md`: dòng "Hướng lệnh" bị xuống dòng giữa cell → gom về một dòng, đồng thời
  trỏ `Q11` thay cho `§58.5` đơn thuần.
- `docs/indicators/price-action-mtf.md` 6 dòng + `docs/indicators/tm-xau-signals-2.md` 1 dòng: `|diff|`,
  `|emaF−emaM|`, `|lastHigh−lastLow|`… bọc lại thành code span có `\|`. Riêng dòng `I9` của PAMTF có ô
  "Kỳ vọng" chứa `|` trần khiến hàng 4 cột: viết lại theo đúng test vector
  `mt5/Scripts/PriceActionMTFContractTests.mq5:1031-1049` (hai trường hợp — `a`: `score100==100, dir==1`;
  `b`: `score100==58, dir==1`) thay vì giữ con số `0.15` không có trong test.
- `docs/guides/beginner-first-run.md`: `RISK\|ENTRY_BLOCKED` trong bảng §7, `status=fail` → `status=issues`,
  bỏ tham chiếu `§3.9` đã đổi thành mục "Hai cái bẫy", bảng `config_hash`/`XAUUSDm` sửa typo, icon chart viết
  lại theo hướng không khẳng định vị trí chính xác trên UI.
- `docs/README.md` thêm dòng đầu tiên trong bảng "Bắt đầu ở đâu" + cây cấu trúc; `docs/v2/README.md` thêm
  dòng dẫn guide mới trước `install-and-test.md`.

Kết quả lint: `done problems=0`. Check link nội bộ (URL-decode, bỏ `archive/`): `checked=402 broken=0`.

### 61.5 Gate (2026-10-30)

- `pytest -q` → `412 passed in 14.09s`.
- `scripts/validate-project.py` → `SUMMARY: checks=14 fail=0`.
- `scripts/validate_sim_configs.py` → `SUMMARY: checked=7 fail=0` (snapshot preset `AA3EC6F4` unchanged).
- `scripts/validate_pamtf.py` → `VALIDATION_OK: pass=36 fail=0`.
- Audit mẫu → exit 0, `issues=0`.
- Không compile MQL5, không chạy tester: guide chỉ dùng artifact đã có (báo cáo `plan_rr2` với
  `Deals: 0`, đúng vì EA mô phỏng không gửi lệnh).

### 61.6 Báo cáo

**PASS** (phạm vi tài liệu). Deliverable: `docs/guides/beginner-first-run.md` + `docs/README.md` đã trỏ vào
đó ngay dòng đầu bảng "Bắt đầu ở đâu"; 35 dòng bảng hỏng đã về 0. **BLOCKED** (không thuộc bước này):
cần chính người dùng mở MT5 làm Phần 2→5 để xác nhận guide dễ theo; `ENTRY` demo đầu tiên từ `DemoEA` và
ADR 0004 cho Grid/DCA vẫn chờ quyết định.

## 62. Docs — giải phẫu bot EA, bảng tham số đầy đủ và đường ghép AI — 2026-10-30

### 62.1 Mục tiêu và phạm vi

Hai yêu cầu liên tiếp của người dùng: *"giúp mình miêu tả chi tiết 1 con bot ea sẽ có cấu trúc như thế nào,
cách cài đặt ra sao, cách cấu hình thế nào, thao tác trên app MT5 desktop GUI thế nào, cách sử dụng bot EA
kết hợp AI và cấu hình thế nào"* rồi *"tạo tài liệu hướng dẫn hoàn chỉnh với sơ đồ và bảng tham số"*.
Deliverable: [`guides/ea-anatomy-and-ai.md`](guides/ea-anatomy-and-ai.md) — 553 dòng, 13 mục, sha256
`4dc22c1cddde111d965cadeb7ace2a116d53bbcdf204b31697daa981aff626ed`. Đây là tầng tài liệu "hiểu sâu" đặt
ngay sau `beginner-first-run.md` (§61); không thay thế `v2/CONFIGURATION.md` mà là bảng tra theo từng bot.

### 62.2 Bố cục

5 sơ đồ ASCII (bản đồ hệ thống repo→Data Folder, luồng `OnInit`/`OnTick`/`OnDeinit`, thang 4 tầng cấu hình,
vòng đời vị thế, pipeline train→ONNX→EA) + 8 bảng tra: nguyên tắc kiến trúc, 6 khối của file EA, thư viện
dùng chung (13 module), danh mục 11 EA, hợp đồng log 18 cột, bảng tham số §7.1–7.6, token RiskGuard,
trạng thái bằng chứng.

### 62.3 Số liệu kiểm chứng lại từng dòng (và lỗi bản nháp đã sửa)

Mọi ô trong bảng đều đối chiếu source/artifact trước khi chốt. Bản nháp đầu có 7 chỗ sai, đã sửa:

- Dòng source: `PinePlanSimEA.mq5` là **829** dòng (`wc -l`), không phải 806; handler thật là
  `OnInit` 696 · `OnDeinit` 788 · `OnTick` **798** (`grep`), các mốc trích dẫn `808-811`, `816-822`,
  `CheckExits` 512, `UpdateTrailing` 536, `TryEntry` 582 giữ nguyên vì đã khớp.
- §3 viết "unit test bằng `SimCoreTests`/`ExecGuard` … 51 test" — sai chỗ dựa. `ExecGuard.mqh` được ma trận
  guard kiểm bởi `mt5/Scripts/ExecGuardTests.mq5`, **51 test guard** theo `docs/v2/EVIDENCE.md:26`;
  `SimCoreTests` là suite khác (`pass=123 fail=0`, `install-and-test.md:619`). Đã viết lại đúng nguồn.
- §11.3: khoá trong `reports/ml/demo-phase7-ml/model.json` là `decision_threshold = 0.5` (đọc bằng
  `json.load`, các khoá thật: `coefficients/intercept/preprocessing{mean,scale,type}`), không phải
  `threshold`. Feature list 12 tên khớp `feature_names` trong model. Chuỗi graph `Sub→Div→MatMul→Add→Sigmoid`,
  opset 13, IR 8 lấy từ `docs/reference/onnx.md:21-29`; SHA-256 model ONNX `a7ae4a25…64f9d3`.
- Tham số CLI export đã mở `scripts/export_onnx_model.py:35-61` xác nhận: `--model`, `--out-dir`, `--fixture`,
  `--opset` (default 13), `--tolerance` (default 1e-5). Artifact `models/candidates/demo-phase7-ml/` gồm
  `model.onnx`, `model_metadata.json`, `onnx_parity.csv/json`.
- §11.2 sửa một dấu backtick thừa ở cuối dòng lệnh export; `OnnxCreate` dòng 30 và `OnnxRun` dòng 113 của
  `LabOnnxInference.mq5` đã
  kiểm; `matrixf features(1, InpFeatureCount)` (dòng 91) nên ô "Lệch thì" ghi đúng triệu chứng
  `OnnxRun failed at row …` thay vì "fail" chung chung.
- §2.3: hợp đồng `event` chỉ đúng 5 nhãn với EA mô phỏng; `grep 'LogEvent("'` trên `DemoEA` cho thấy còn
  `REGIME` · `BOS` · `TRAIL` · `STATE` · `KILL` · `DRY_RUN` · `ADOPT` · `SYNC` · `ERROR` · `RESET` ·
  `CLOSE_REQUEST` · `STATE_ERROR`. Đã ghi rõ trong bảng.
- Token exit đã xác nhận nguyên văn trong source: `SL_HIT` (518), `SL_GAP|gap_points=` (522),
  `TARGET_HIT|mode=` (531), `TRAIL_REJECTED|reason=` (578), `MAX_HOLDING_BARS` (821). `INIT` dùng
  `bar_time=1970.01.01` — thấy ở dòng 2 CSV mẫu `plan_rr2`.
- Số đếm cấu hình: `reports/build/tester-sets/*.set` = **20**, preset `configs/sim/*.json` = 6 (+ example,
  validator `checked=7`), `Include/TrendRider/*.mqh` = **12**, `Include/Sim/*.mqh` = 10 (EA chỉ include 6).
  Input đếm được loại trừ dòng `input group`: `PinePlanSimEA` 27/6 nhóm, `DemoEA` 47/7.
- Lỗi chữ: typo CJK `任意` ở dòng Visualize, nhãn dính `Kill switchDemoEA`, thiếu dấu cách
  `…Contract.mqh`.EA`, và `LAB|DEBUG|…` chưa thoát `\|` trong bảng §7.1 (đã escape).

### 62.4 Chỉ mục và dọn dẹp còn tồn

- `docs/README.md`: thêm dòng "**Hiểu từng khối của một con bot + bảng tham số đầy đủ + ghép AI**" ngay sau
  dòng beginner trong §1, và thêm file vào cây §2 (`guides/`).
- `docs/v2/README.md`: thêm bullet dẫn tài liệu mới trong danh sách "tài liệu vận hành ngoài `v2/`".
- `docs/guides/beginner-first-run.md` §10: thêm dòng "Đọc tiếp" đầu bảng trỏ sang tài liệu giải phẫu.
- Nhân tiện quét link toàn `docs/` (kể cả `archive/`, trước đây loại trừ), sửa **7 link hỏng** trong
  `docs/archive/v1/` do chưa hiệu chỉnh độ sâu tương đối khi move vào archive:
  `PA_TrendRider_XAU_V1_Implementation_Vietnamese.md` (3 link → `../../decisions/`, `../../guides/`,
  `../../../configs/…json`), `ROADMAP_MT5_EA_AI_LAB_v1.md` (1), `phase-reports/phase-5.md` (2 →
  `../../../reference/parity.md`), `mt5-ea-ai-simulation-pack/docs/PROGRESS.md` (1 → `../../../../PROGRESS.md`).
  Nội dung archive giữ nguyên, chỉ đổi đường dẫn; `git diff` 6 file = 10 dòng.
- Escape `\|` trong code span ở 3 dòng bảng thuộc archive (`PA_TrendRider…:141`, `phase-1.md:39`,
  `phase-2.md:40`) — cùng lớp lỗi đã sửa ở §61 cho docs đang dùng.

### 62.5 Gate (chạy 2026-10-30 sau khi sửa)

- Table linter (code span chưa escape + số cột lệch, bỏ qua trong code fence): `files=99 problems=0`;
  riêng docs live (không `archive/`): `files=51 problems=0`.
- Link checker (URL-decode, phân giải cả `file:///…` sang pine nguồn): `checked=447 broken_live=0 broken_archive=0`.
- `scripts/validate-project.py` → `SUMMARY: checks=14 fail=0`.
- `pytest -q` → `412 passed in 15.98s`; `validate_sim_configs.py` → `checked=7 fail=0` (snapshot `AA3EC6F4`
  unchanged); `validate_pamtf.py` → `pass=36 fail=0`; `validate_demo_execution.py` → `checks=8 fail=0`.
- Audit mẫu `reports/build/tester-reports/plan_rr2/sim_plan_rr2.csv` → exit 0, `status=ok rows=287 issues=0`.
- Không compile MQL5, không khởi động terminal, không kết nối broker, không gửi lệnh: toàn bộ bước này là
  tài liệu; số liệu MT5 lấy từ artifact đã có.

### 62.6 Báo cáo

**PASS** (phạm vi tài liệu): `docs/guides/ea-anatomy-and-ai.md` hoàn chỉnh 13 mục, mọi ô bảng có nguồn,
chỉ mục 3 nơi đã cập nhật, gate xanh, lỗi bảng/link archive đã về 0.

**Hạn chế cần đọc kèm** (không phải FAIL, ghi để không bị hiểu nhầm là đã kiểm):
mức tích hợp AI "C — model quyết hướng/sizing" và mục "build ONNX terminal khác build 6292" là `NOT_RUN` /
`CHƯA KIỂM`; parity với Pine vẫn `BLOCKED` (thiếu CSV Pine, xem §60); `DemoEA` trên tài khoản demo đang
`WAITING_FOR_SETUP`, 0 `ENTRY` do chiến lược — quyết định chạy demo tiếp theo thuộc chủ dự án, cùng ADR 0004
cho Grid/DCA. **Lợi nhuận mọi chiến lược: `UNPROVEN`.**

## 63. Phiên demo execution có giám sát — bot EA chạy thật trên MT5 demo + scenario visual — 2026-10-30

### 63.1 Yêu cầu và phạm vi

Người dùng yêu cầu: *"làm lần lượt để mình có thể nhìn thấy được bot EA thực hiện giao dịch trên MT5 Demo"*,
sau đó chọn phạm vi "tất cả, tới bậc 4" và giao agent thao tác GUI ("bạn click giúp mình, mình chỉ xem thôi").
Toàn bộ nằm trong ADR 0003: chỉ tài khoản demo `464140826` trên `Exness-MT5Trial17`, chỉ
`PATrendRiderXAUv1DemoEA` + `mt5\Include\Exec\*`. Không đụng Grid/DCA (vẫn `BLOCKED_PENDING_ADR`), không
nới gate chiến lược/rủi ro để "tạo ra lệnh", không credential.

### 63.2 Bốn bậc đã chạy

- **Bậc 1 — dry-run trên chart (PASS).** Agent điều khiển MT5 (Computer Use), mở node Expert Advisors,
  nạp `PATrendRiderXAUv1DemoEA` lên chart `XAUUSDm,M5`, kiểm hộp thoại Inputs thấy `false = dry-run, no
  orders` = `false`. Journal: `INIT mode=DRY_RUN|state=WAITING_FOR_SETUP|restored=1|magic=25002001|
  config_hash=8A85E0D5|mql_trade_allowed=1` lúc 04:37:26, theo sau `BOS tf=H1 event=BOS_BEAR`,
  `BOS tf=M15 event=BOS_BEAR`, `REGIME regime=TREND_DOWN|bias=aligned_bearish`. OnDeinit lúc 04:45:05 ghi
  `SUMMARY mode=DRY_RUN|entries=0`. Tab Trade trống — đúng hợp đồng dry-run.
- **Bậc 2 — Tester visual (PASS, có artifact mới).** Scenario mới `demo_exec_visual`: ini
  `reports/build/tester-run/demo_exec_visual.ini` (`Model=1`, `Period=M5`, `FromDate=2026.01.05`,
  `ToDate=2026.02.20`, `Deposit=5000`, `Visual=1`, `ShutdownTerminal=1`, `Report=tester_demo_exec_visual`)
  + set `reports/build/tester-sets/demo_exec_visual.set` (bản sao `pa_trendrider_demo_exec.set`, chỉ đổi
  `InpLogFile=sim_demo_exec_visual.csv`) đã copy vào `MQL5\Profiles\Tester\`.
  `run_tester.ps1 -Scenario demo_exec_visual` → exit 0, `terminal64 exited after 110.6s`.
  Artifact `reports/build/tester-reports/demo_exec_visual/`: `sim_demo_exec_visual.csv` 2 920 721 B
  (sha256 `F4475489796A`), `tester_demo_exec_visual.htm` 46 672 B (`5355E9571E28`),
  `tester_demo_exec_visual.png` 5 531 B (`511559DD1103`).
  Đếm event từ CSV: `INIT 1|ENTRY 4|EXIT 4|TRAIL 1|BOS 1329|REGIME 247|STATE 14|RISK 8187|SUMMARY 1`.
  SUMMARY: `entries=4|exits=4|wins=0|losses=3|net=-31.04|drawdown_pct=0.8162`. pnl từng lệnh:
  `0.00, -8.75, -10.32, -11.97`. Bốn dòng ENTRY mang `ORDER_FILLED|order=<n>|deal=<n>|ok|done|
  risk_money=12.45..12.50|lot=0.01|tp_r=3.00|spread_points=160.0` — tức sizing 0.25% vốn bị kẹp ở
  `volume_min=0.01`, `expected_loss` luôn dưới ngân sách. **Không phải lợi nhuận kỳ vọng**: cửa sổ 6,5 tuần
  này lỗ 31.04 đơn vị mô hình.
- **Bậc 3 — `ExecDemoProbe` (BLOCKED, không phải lỗi code).** Script cần Navigator để chạy; sau vài cú click
  vào dock, cây Navigator của terminal này không render nữa (rỗng hoàn toàn, giữ nguyên qua 2 lần khởi động
  lại). Cách sửa duy nhất còn lại là đụng `config\terminal.ini` (file layout dạng binary, có thể liên quan
  phiên đăng nhập) → không làm. Bằng chứng đường guard → broker đã có từ 2026-10-29: deal 2468899165
  @4045.79 mở, deal 2468899168 @4045.55 đóng, pnl −0.24, vòng 103 ms (§7.3 TEST_REPORT).
- **Bậc 4 — execution trên tài khoản demo (ĐANG CHẠY).** Hai lần khởi động bằng
  `terminal64.exe /config:"D:\Applications\tm-fx\reports\build\demo-arm\startup.ini"`; log terminal ghi
  `successfully initialized from start config`, `47 inputs read from expert 'PATrendRiderXAUv1DemoEA' set
  file ...pa_trendrider_demo_live.set`, `expert PATrendRiderXAUv1DemoEA (XAUUSDm,M5) loaded successfully`.
  Journal `INIT mode=DEMO_EXECUTION|...|config_hash=6B439450|mql_trade_allowed=1` (04:45:41, rồi 04:56:50
  sau khi chạy Bậc 2). Kill switch `PA_TREND_RIDER_DEMO_STOP.txt` **không tồn tại** (đã kiểm bằng `ls`),
  `InpMaxPositions=1`, `InpRiskPercent=0.25`, `InpDailyLossLimitPct=1.0`, `InpMaxDrawdownPct=8.0`.
  Tính đến 04:58 vẫn 0 `ENTRY` — `state=WAITING_FOR_SETUP`, block `reversal_watch`/`bias_unknown` là kết quả
  hợp lệ của bộ lọc regime.

### 63.3 Bằng chứng phụ thu được

- `pa_trendrider_demo_state.csv` sau phiên này là `state=WAITING_FOR_SETUP;transitions=2` — **một tiền tố**,
  `day_key=20261030;day_start=4999.76`. Bản cũ (29/10) còn `state=state=` do binary cũ ghi; lần nạp lại bằng
  `.ex5` mới đã tự sửa → xác nhận runtime cho mục P3 §58 mà không cần thao tác gì thêm.
- `scripts/watch_demo_journal.py --watch --interval 20 --stop-on-alert` đang chạy nền, checkpoint
  `reports/demo-watch/journal_checkpoint.json` (`offset=62337`, cập nhật 11:58). Nó sẽ thoát với exit 1 và
  in dòng `WATCH|ENTRY|…` ngay khi bot gửi lệnh thật.

### 63.4 Hạn chế của phiên này (ghi để không hiểu nhầm)

- Agent tự bấm UI nên đã làm hỏng layout dock của terminal (Navigator trống, panel tester collapse, một số
  tab Toolbox không đổi). Đây là lỗi thao tác, không phải lỗi EA/MT5; hệ quả: Bậc 3 không chạy được hôm nay.
- Bậc 2 chạy `Visual=1` nhưng chỉ hết 110,6 s nên cửa sổ replay lướt rất nhanh; muốn xem chậm phải mở
  `tester_demo_exec_visual.htm` hoặc chạy lại với `ShutdownTerminal=0` để giữ cửa sổ.
- Số liệu Bậc 2 là backtest, **không** phải kết quả của phiên demo thật; phiên demo thật hiện vẫn
  `entries=0`.

### 63.5 Gate

- `pytest -q` → `412 passed` (không có thay đổi code Python ở bước này).
- `scripts/validate-project.py` → `SUMMARY: checks=14 fail=0`; `validate_demo_execution.py` →
  `checks=8 fail=0`; `validate_sim_configs.py` → `checked=7 fail=0`.
- Table linter docs → `problems=0`; link checker → `broken_live=0 broken_archive=0`.
- Không compile MQL5 mới (dùng `.ex5` đã build 29/10 23:09), không gửi lệnh thật nào ngoài các lệnh do
  chính EA trong Tester tạo ra; không có thao tác nào lên tài khoản real.

### 63.6 Báo cáo

**PASS**: Bậc 1 và Bậc 2 có bằng chứng file; Bậc 4 đang chạy trên tài khoản demo với execution bật, có
giám sát và kill switch sẵn sàng. **BLOCKED**: Bậc 3 (`ExecDemoProbe`) cần Navigator hoạt động bình thường —
cần bạn mở lại MT5 sau khi đăng nhập lại hoặc để mình chờ `ENTRY` đầu tiên từ chính chiến lược. **Chưa có**:
`ENTRY` demo do chiến lược — watcher sẽ báo. **Lợi nhuận: `UNPROVEN`** (cửa sổ visual 6,5 tuần gần nhất còn
âm 31.04).

## 64. ADR 0004 — mọi bot được execution đầy đủ trên tài khoản demo (Grid + DCA demo EA) — 2026-10-30

### 64.1 Yêu cầu

Người dùng yêu cầu *"giúp mình chạy test bot dca trên tài khoản demo"*, rồi chốt lại phạm vi:
*"cập nhật lại tính ràng buộc cho toàn dự án, tất cả các bot đều có thể chạy toàn quyền trên tài khoản
demo"*. Trước đó DCA/Grid demo là `BLOCKED_PENDING_ADR` vì ADR 0003 điểm 3 cấm grid/DCA trong phạm vi demo
đầu tiên, và điểm 1 chỉ cho đúng một EA (`PATrendRiderXAUv1DemoEA`) gọi order API.

### 64.2 Quyết định — `docs/decisions/0004-all-bots-demo-execution.md`

- **Ba chiến lược, ba EA demo riêng:** `PATrendRiderXAUv1DemoEA`, `GridDemoEA`, `DCADemoEA`. Vẫn giữ
  nguyên lý ADR 0003: **không** trộn cờ execution vào EA mô phỏng.
- ADR 0004 thay ADR 0003 mục 1 và đúng một câu "không martingale, không grid, không DCA" ở mục 3. Mục 2
  (cấm tài khoản real/contest), mục 4 (không credential), mục 5 (EA mô phỏng không đổi), mục 6 (không
  quảng bá hiệu năng) và ADR 0002 vẫn hiệu lực.
- **"Toàn quyền trên demo" được định nghĩa tường minh:** không còn rào cản phạm vi nào (không giới hạn số
  bot, không cấm grid/DCA, mỗi bot một `magic`); điều kiện duy nhất còn lại là `InpEnableExecution=true`.
- **Đường đỏ hard-enforced trong code, không chỉ trong tài liệu:** demo/tester-only (`ExecContextAllowed`,
  real/contest → `INIT_FAILED`), SL/TP bắt buộc trên mọi lệnh, trần rủi ro cứng, kill switch, một điểm gửi
  lệnh duy nhất `ExecBroker.mqh`, không credential/`WebRequest`/socket.
- **Dry-run fail-closed ở cả code lẫn preset.** Static validator bắt buộc `InpEnableExecution=false` trong
  mọi preset demo; bật execution là thao tác tường minh của operator.

### 64.3 Code mới

- `mt5/Include/Exec/ExecDemoCommon.mqh` — lớp chung cho bot dạng giỏ: đọc giỏ thật theo `magic`
  (số chân, volume, entry bình quân, min/max entry, SL/TP), đóng giỏ, ghi SL/TP tuyệt đối lên **mọi** chân,
  `ExecDemoValuePerPoint`, `ExecDemoBasketLossMoney`, dựng giá SL/TP từ entry bình quân, kiểm stop level của
  broker, kill switch, tổng P&L đã thực hiện theo `magic`. **Không** gọi `OrderSend` — chỉ gọi
  `ExecClosePosition`/`ExecModifyStops` của `ExecBroker`, nên vẫn đúng một điểm gửi lệnh.
- `mt5/Experts/GridDemoEA.mq5` — execution demo cho Grid: tái dùng phần toán thuần đã có
  (`SimGrid*`, `CSimRiskGuard`, `CSimLogger`) nên **cùng luật** với `GridLabEA`, nhưng chân lệnh là vị thế
  broker thật. Trần: `InpMaxGridLevels` (1..50), `InpMaxLevelVolume`, `InpMaxExposure`,
  `InpMaxBasketLossPct` (lỗ cả giỏ tại stop so với equity), `InpMaxConsecutiveLosses`, `InpMaxDailyLossPct`,
  `InpMaxDrawdownPct`. SL/TP giỏ = giá tuyệt đối tính từ entry bình quân, cập nhật lại sau mỗi tầng.
  Chạm daily loss/drawdown/kill switch → **đóng giỏ** rồi chốt (`CloseBasket("RISK_HALT")` /
  `CloseBasket("KILL_SWITCH")`).
- `mt5/Experts/DCADemoEA.mq5` — tương tự cho DCA (`SimDca*`): `InpMaxDcaAdds`, `InpMaxAddVolume`,
  `InpAddVolumeMultiplier`, tối đa một lần add mỗi bar, cùng bộ trần rủi ro và SL/TP giỏ bắt buộc.
- `volume` mỗi chân luôn `ExecNormalizeVolume` theo volume step; dưới lot tối thiểu thì **từ chối**, không
  làm tròn lên.
- `scripts/deploy_pineport.ps1` thêm hai EA vào danh sách copy/compile (`Include\Exec` vốn được enumerate
  theo cây nên `ExecDemoCommon.mqh` tự vào).

### 64.4 Preset, schema Python và test

- `configs/demo/grid_demo.json`, `configs/demo/dca_demo.json` (`DEMO_ONLY`, `allow_live_trading=false`,
  `InpEnableExecution=false`, magic `25004001`/`25005001`, kill switch riêng).
- `python/src/mt5_ea_ai_lab/sim_configs.py`: thêm `_DEMO_EXECUTION_COMMON`, `EA_INPUTS["GridDemoEA"]` và
  `EA_INPUTS["DCADemoEA"]`, `DEMO_EA_NAMES` (ba EA), `EA_EXECUTION_MODE` suy ra `DEMO_ONLY` cho cả ba, và
  cross-check riêng (trần tầng/add, SL giỏ bắt buộc, price/bar trigger hợp lệ).
- `python/tests/test_demo_execution.py`: thêm test tham số hoá cho cả ba EA — preset hợp lệ & fail-closed,
  input preset khớp **chính xác** input khai báo trong `.mq5`, magic khác nhau, trần grid/DCA hữu hạn, và
  không EA demo nào gọi `OrderSend` trực tiếp.

### 64.5 Validator

| Script | Thay đổi | Kết quả |
|---|---|---|
| `scripts/validate-project.py` | `EXEC_SOURCES` + `DEMO_EAS` cho ba EA; token guard theo từng dạng (single_position / bounded_grid / bounded_dca); `ExecDemoCommon` phải route qua `ExecBroker`; `REQUIRED_FILES` thêm ADR 0004 + 2 EA + 2 preset; `check_demo_presets` theo từng EA | `checks=14 fail=0` |
| `scripts/validate_demo_execution.py` | ADR 0004 thay ADR 0003; thêm check cho `GridDemoEA`/`DCADemoEA` và check "bounded grid/DCA baskets" (trần, SL giỏ, flatten khi halt/kill switch) | `checks=11 fail=0` |
| `scripts/validate_pamtf.py` | (từ §58) 117 input, không `input group`, hai input đầu là bridge; sửa regex thiếu `J9` | `pass=36 fail=0` |

### 64.6 Compile

- `powershell -ExecutionPolicy Bypass -File scripts\deploy_pineport.ps1 -Apply -Force` →
  `DEPLOY_OK: files copied and compiled with 0 errors and 0 warnings` (32 source).
- `GridDemoEA.mq5` → `0 errors, 0 warnings`; `DCADemoEA.mq5` → `0 errors, 0 warnings`
  (`reports\build\deploy\GridDemoEA.log`, `reports\build\deploy\DCADemoEA.log`).
- `.ex5` trong data folder: `GridDemoEA.ex5` 70 032 B, `DCADemoEA.ex5` 67 548 B;
  `ExecDemoCommon.mqh` copy vào terminal khớp sha256 với bản repo
  (`EAB4789E5158F5A27520693978937C032E0E2FF86A439D91DC6EE6CB48B16496`).

### 64.7 Chưa làm (mở, ghi rõ để không hiểu nhầm)

- **Tester run của hai EA demo: chưa chạy.** `reports\build\tester-run\grid_demo_exec.ini` và
  `dca_demo_exec.ini` (+ `.set`, `InpEnableExecution=true`) đã tạo và copy vào `MQL5\Profiles\Tester\`,
  nhưng `run_tester.ps1` từ chối khởi động vì `terminal64` đang mở (pid 14064, tài khoản demo
  `464140826` trên `Exness-MT5Trial17`) — script cố ý không đóng terminal của người dùng.
- **Phiên demo thật của Grid/DCA: `NOT_RUN`** (chưa attach, chưa có journal). Trạng thái ghi trong docs là
  `ALLOWED` (phạm vi + code) chứ không phải "đã chạy".
- Không đụng `PATrendRiderXAUv1DemoEA`, `GridLabEA`, `DCALabEA`, `ExecGuard.mqh`, `ExecBroker.mqh` →
  bằng chứng cũ (§63, 4 scenario `dca_*`, `grid_*`) vẫn nguyên giá trị.

### 64.8 Gate

- `python -m pytest -q` → `412 passed`.
- `scripts/validate-project.py` → `checks=14 fail=0`.
- `scripts/validate_demo_execution.py` → `checks=11 fail=0`.
- `scripts/validate_pamtf.py` → `pass=36 fail=0`.
- Không gửi lệnh thật nào trong bước này; không credential; không thao tác trên tài khoản real.

### 64.9 Báo cáo

**PASS**: ràng buộc dự án đã đổi theo ADR 0004 (ba bot được execution demo), code + preset + validator +
test đều khớp và xanh, compile 0/0. **NOT_RUN**: tester run của `GridDemoEA`/`DCADemoEA` và mọi phiên demo
thật cho Grid/DCA. **Lợi nhuận: `UNPROVEN`** — không có kết quả giao dịch nào trong mục này.

## 65. InfiniteRunner_XAU — hai luồng song song, ADR 0005 Proposed, alt A lưu trữ — 2026-10-30

### 65.1 Diễn biến trung thực

- Nhiệm vụ mở đầu phiên: đọc docs/v2/STRATEGIES/InfiniteRunner_XAU_Upgrade_Pack/ (README + spec +
  prompt, 3 file) và github-demo/InfiniteRunner_XAU/InfiniteRunner_XAU.mq5 (143 dòng, V1.00).
- V1 đọc được đúng như spec §1: quyết định trên nến đang chạy (astMA[0]), vào lại lệnh tức thời,
  lot cố định 0.01, SL 5000 points, TP=0 kéo SL, không retcode check, không kho rủi ro.
- Trong khi phiên chính triển khai luồng alt B (IRTypes/IRDirection/IRTrailing +
  InfiniteRunnerXAUV2DemoEA.mq5), một luồng agent song song (15:27–15:31, alt A) đã tạo
  InfiniteRunnerXAUDemoEA.mq5 + IRMarket.mqh + IRRisk.mqh + InfiniteRunnerContractTests.mq5
  + infinite_runner.py + 	est_infinite_runner.py — cùng magic 25006001.
- Hai luồng dùng chung 2 file include; lần ghi sau đè lần trước. Alt A phụ thuộc
  ENUM_IR_DIR_MODE/IR_LOT_RISK_PERCENT/IREmaSnap — hiện không còn trong IRTypes.mqh,
  nên alt A **không thể compile** và không thể khôi phục (repo chưa có commit git nào).

### 65.2 Quyết định của chủ dự án (2026-10-30)

- Canonical: **alt B** — mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5 (~1800 dòng;
  MTF H1/M15/M5 closed-bar, legacy baseline, sizing qua ExecCalcProfit, BE/trailing từ initial R
  lưu state, kho ngày/drawdown/streak, state file, kill switch riêng INFINITE_RUNNER_DEMO_STOP.txt,
  dry-run mặc định).
- Alt A **lưu trữ nguyên trạng** tại rchive/2026-10-30_InfiniteRunner_XAU_alt_A/ (6 file + README
  giải thích), không xóa.
- Yêu cầu soạn **ADR 0005** (bot demo thứ tư) và dừng mọi sửa code cho tới khi chủ dự án Accepted.

### 65.3 Tài liệu tạo/sửa

- MỚI docs/decisions/0005-infiniterunner-xau-demo-bot.md — **Proposed** (chưa Accepted; liệt kê
  7 việc phải làm sau Accepted: đăng ký validator/EXEC_SOURCES/DEMO_EAS, preset fail-closed,
  sim_configs.py, deploy script + compile, pytest preset check, docs 4-bot, nhãn NOT_RUN).
- MỚI rchive/2026-10-30_InfiniteRunner_XAU_alt_A/README.md (lịch sử hai luồng + lý do lưu trữ).
- docs/PROGRESS.md — mục này.

### 65.4 Trạng thái cgate tại thời điểm dừng

- scripts/validate-project.py → checks=14 fail=1: FAIL orbidden API scan (70 sources) — đúng như
  dự kiến vì InfiniteRunnerXAUV2DemoEA.mq5 gọi AccountInfoDouble/Integer trong Experts/ mà chưa
  được đăng ký trong EXEC_SOURCES/DEMO_EAS (ADR 0005 chưa Accepted). Cùng gốc nhân: 2 pytest
  	est_project_validator_passes, 	est_repository_passes_static_checks FAIL.
- scripts/validate_demo_execution.py → checks=11 fail=0.
- python -m pytest -q → 421 passed, 2 failed (2 test "validator phải pass" — do fail trên).
- Chưa compile, chưa deploy, chưa tạo preset, chưa chạy tester cho bot mới.
- GridDemoEA/DCADemoEA tester scenarios (§64.7): vẫn NOT_RUN — 	erminal64 (pid 14064) vẫn đang
  chạy, chờ chủ dự án đóng terminal hoặc cho phép xử lý.

### 65.5 Báo cáo

**PASS**: lưu trữ alt A đúng nguyên trạng + README; ADR 0005 soạn đầy đủ thông tin cho chủ dự án.
**Proposed**: ADR 0005 — chờ Accepted. **NOT_RUN**: mọi phiên demo/tester của
InfiniteRunnerXAUV2DemoEA (chưa compile); Grid/DCA tester (chờ terminal đóng).
**Lợi nhuận: UNPROVEN** — không có kết quả giao dịch nào trong mục này.

## 66. InfiniteRunner_XAU demo — ADR 0005 Accepted, đăng ký hoàn tất, gates xanh — 2026-10-30

### 66.1 Chấp thuận của chủ dự án (2026-10-30)

- Chủ dự án phát biểu **"mở khóa toàn bộ project cho toàn bộ bot EA"** → ADR 0005 chuyển
  **Proposed → Accepted** (docs/decisions/0005-infiniterunner-xau-demo-bot.md): bot demo thứ tư
  InfiniteRunnerXAUV2DemoEA (magic 25006001) được đăng ký chính thức cho backtest + tài khoản demo.
- Yêu cầu "cho phép tài khoản real" **không được thực hiện trong phiên này**: tối thiểu theo
  lộ trình 4 bước đã thống nhất — (1) hoàn tất ADR 0005, (2) phiên demo có giám sát mỗi bot,
  (3) forward-test demo 2–4 tuần, (4) ADR 0006 "Real execution" dạng Proposed với kiến trúc
  hai chìa khóa (`InpAllowRealAccount` + `InpConfirmRealRisk`) — guard không bị xóa, được nâng cấp.
  AGENTS.md cập nhật Execution Boundary lên **4 demo EA** (bản ghi công khai, cùng commit thay đổi).

### 66.2 Đăng ký bot thứ tư (đã hoàn tất)

- python/src/mt5_ea_ai_lab/sim_configs.py — `EA_INPUTS["InfiniteRunnerXAUV2DemoEA"]` đầy đủ 50 input,
  `DEMO_EA_NAMES` 4 tên, cross-check IR (EMA slow>fast, thứ tự H1>M15>entry qua `_TF_SECONDS`,
  band SL, TP bắt buộc, SL/trail/lot theo mode).
- configs/demo/infinite_runner_demo.json — preset fail-closed: `InpEnableExecution=false`,
  magic 25006001, band SL 500–20000, `InpSafetyTpPoints=100000`, `InpMaxPositions=1`.
  Lần chạy đầu `validate_preset` báo `InpMaxLots: missing required input` → đã bổ sung
  `InpMaxLots=0.20` khớp khai báo EA.
- scripts/validate-project.py — `EXEC_SOURCES` + `DEMO_EAS` (guard token **`runner_trailing`**),
  check preset IR trong `check_demo_presets`.
- scripts/validate_demo_execution.py — hằng số `IR_DEMO_EA`/`IR_DEMO_PRESET`, nhánh
  `check_demo_ea` riêng cho runner (bắt buộc `ExecFindOwnPosition`/`ExecModifyStops`/
  `ExecCalcProfit`/`ExecMarginRequired`/`ExecClosedPnl`/`IRMonotonicBetter`, cấm token giỏ),
  block preset trong `check_presets`, report "infinite runner demo EA guardrails".
- python/tests/test_demo_execution.py — `DEMO_EA_PRESETS` 4 cặp + `test_runner_demo_keeps_runner_guards`.
- reports/build/tester-sets/infinite_runner_demo_exec.set (execution **bật**, log
  `sim_ir_demo_exec.csv`, đã copy vào `MQL5\Profiles\Tester\`) +
  reports/build/tester-run/infinite_runner_demo_exec.ini (XAUUSDm M5, 2026.01.05→2026.10.01).

### 66.3 Trạng thái gate sau đăng ký

- scripts/validate-project.py → **checks=14 fail=0**; scripts/validate_demo_execution.py →
  **checks=12 fail=0**; python -m pytest python/tests -q → **427 passed** (423 cũ + preset-test
  mở rộng + test guard runner).
- docs/guides/demo-execution.md — nâng bảng 4 bot, bảng ranh giới an toàn 4 bot, mục §4.4
  chạy InfiniteRunner demo (chẩn đoán `DECISION|NO_TRADE`/`BLOCKED`, spread mặc định 600 pts
  vs Exness ~150–300), tham chiếu scenario tester. Guide check vẫn xanh.

### 66.4 Bằng chứng giao dịch

- **NOT_RUN**: mọi phiên demo/tester của cả bốn bot trong mục này (Grid/DCA scenarios chờ
  terminal64 đóng; PA demo trước đó đã có phiên §44 — không làm lại). Tester runner lần đầu
  (user chạy tay): **0 trades** — do `InpEnableExecution=false` mặc định dry-run + tính chọn
  lọc MTF; `.set` mới đã bật `true` cho backtest tiếp theo.
- **Lợi nhuận: UNPROVEN** — không có kết quả giao dịch nào của bot runner được ghi nhận.

## 67. ADR 0006 — mặc định bật execution + sửa bug halt cấm-mọi-entry — 2026-10-30

### 67.1 Chẩn đoán "chạy tester không có lệnh" (user report)

- Log agent tester (`Agent-127.0.0.1-3000/logs/20261030.log`) cho thấy 2 lớp nhân:
  1. **Nhầm EA**: 15:17 user đã chạy `InfiniteRunner_XAU.ex5` (V1 tham chiếu, có lệnh,
     `tp: 0.000`) — không phải bot demo; V2 thật là `InfiniteRunnerXAUV2DemoEA.ex5`.
  2. **Bug thật trong V2**: mọi run V2 từ 16:05 đều `mode=DRY_RUN` (`.set` chưa được
     nạp) **và** ngay setup đầu tiên 2026.10.01 16:40:
     `LAB|WARN|ir_v2|halted|reason=volume_to_add_invalid`. Gốc: hàm entry gọi
     `EvaluateRisk(0.0, bar_time)` **trước** khi sizing → shared `SimRiskGuard` thấy
     `volume_to_add<=0` → Block `volume_to_add_invalid`; mà `halt_on_breach=true`
     khiến **mọi Block đều lên thành HALTED vĩnh viễn** → phiên chết kể cả bật cờ.

### 67.2 ADR 0006 (chủ dự án yêu cầu "mặc định luôn InpEnableExecution=true")

- docs/decisions/0006-demo-default-execution-enabled.md — **Accepted**: cả 4 EA demo
  mặc định `InpEnableExecution=true` ở code + preset; dry-run là chế độ có chủ đích
  (đặt `false` tay), thay từ gốc kịch bản "bật cờ tay" trước đó. ADR 0004/0005 gắn
  dòng "được sửa đổi bởi ADR 0006". Ghi chú đánh số: ADR real-execution sau này là
  **0007** (hai chìa khóa, chưa soạn).

### 67.3 Thay đổi theo ADR 0006

- **4 EA**: `input bool InpEnableExecution=true` (comment chỉ dry-run là `false`);
  PA EA `#property description` + header comment cập nhật.
- **Bug halt (cùng lớp trong 3 EA dùng SimRiskGuard)**: `limits.halt_on_breach=false`
  — guard Block thường không còn giết phiên; guard vẫn `Halt()` cho vi phạm equity
  thật (daily loss/drawdown/kill) và EA thăng cấp qua `InpHaltOnBreach`. Riêng IR EA:
  sizing **trước** guard rồi gọi `EvaluateRisk(volume, bar_time)` với volume thật.
- **4 preset JSON** `configs/demo/*.json`: `InpEnableExecution: true` + mô tả mới.
- **Validators**: `validate-project.py` (EA default phải `true` — regex + preset check),
  `validate_demo_execution.py` (4 điểm ép `false` → `true`, docstring) — cả hai ép
  "mặc định rõ ràng = true". **pytest**: test demo-preset flips giả định false → true.
- **Tài liệu**: AGENTS.md (ack công khai quyết định chủ dự án), guide demo-execution
  (cảnh báo đầu trang, bảng §1, §4 quy trình đổi mục tiêu "dry-run có chủ đích",
  §4.3/4.4, tham chiếu `.set`), ADR liên kết.

### 67.4 Trạng thái gate khi kết thúc mục này

- validate-project.py → **checks=14 fail=0**; validate_demo_execution.py →
  **checks=12 fail=0**; pytest → **427 passed** (không tăng số test: flip không thêm).
- Build/deploy chạy lại nền (4 EA compile 0/0 kỳ vọng; xác nhận ở Output sau khi job xong).
- **NOT_RUN**: mọi phiên demo có lệnh của cả bốn bot mới kể từ thay đổi; backtest lại
  V2 với `.set` mới là việc tiếp theo của chủ dự án.
- **Lợi nhuận: UNPROVEN** — không thay đổi.

## 68. Tester headless từ chối EA — fix nhận diện Strategy Tester — 2026-10-30

### 68.1 Chẩn đoán (log 20261030.log)

- 17:12–17:15 chạy `terminal64.exe /config:infinite_runner_demo_exec.ini` (MT5 đã đóng).
- EA khởi tạo được (state file viết xong) nhưng `LAB|ERROR|ir_v2|context_denied|reason=terminal_trade_disabled`
  → `INIT_FAILED` → tester không tạo report, không có lệnh nào.
- Gốc: `ExecContextAllowed` cho phép tester bằng `state.tester`, set từ
  `MQLInfoInteger(MQL_TESTER)`. **Trong tester headless (terminal64 /config:<ini>),
  MQL_TESTER trả về 0** → guard coi không phải tester → kiểm tra tiếp
  `terminal_trade_allowed` → tester headless để trade bị tắt → từ chối.
- Đây là hành vi fail-closed đúng theo ADR 0004 nhưng làm tester headless không thể chạy.

### 68.2 Sửa đổi (kiến trúc nhỏ, không thay đổi guard)

- 4 EA demo: `state.tester` nhận diện thêm bằng **tên tài khoản**:
  `state.tester = (MQL_TESTER!=0) || (AccountInfoString(ACCOUNT_NAME) contains "Strategy Tester")`.
  Guard `ExecContextAllowed` không đổi — chỉ cần tester được nhận diện đúng.
- Build/deploy chạy lại nền (4 EA compile 0/0 kỳ vọng).

### 68.3 Trạng thái gate khi kết thúc mục này

- validate-project.py → **checks=14 fail=0**; validate_demo_execution.py →
  **checks=12 fail=0**; pytest → **427 passed** (không thay đổi).
- **Chưa chạy lại tester** — chờ build xong. Khi tester chạy được, báo cáo sẽ có
  `ENTRY`/`EXIT`/`TRAIL` trong `sim_ir_demo_exec.csv`; nếu vẫn `NO_TRADE`/`BLOCKED`
  → đọc reason token trong CSV.
- **Lợi nhuận: UNPROVEN** — không thay đổi.

## 69. ADR 0007 — Wonderwhales demo EA, bot demo thứ năm — 2026-11-03

### 69.1 Yêu cầu và quyết định

- Chủ dự án: *"dựa theo chỉ báo Wonderwhales, giúp mình sửa lại bot WonderwhalesSimEA để có thể chạy
  được trên cả test và demo"*. ADR 0004 cấm thêm execution vào EA mô phỏng, nên yêu cầu được hiện thực
  bằng **EA demo riêng** `WonderwhalesDemoEA`; `WonderwhalesSimEA` giữ nguyên `SIMULATION_ONLY`.
- Quyết định ghi tại [`decisions/0007-wonderwhales-demo-bot.md`](decisions/0007-wonderwhales-demo-bot.md)
  (Accepted; yêu cầu của chủ dự án là phê duyệt phạm vi theo ADR 0003 §7). Magic `25007001`, preset
  `configs/demo/wonderwhales_demo.json`, kill switch `WONDERWHALES_DEMO_STOP.txt`.

### 69.2 Deliverables

- `mt5/Experts/WonderwhalesDemoEA.mq5`: một vị thế theo magic, tín hiệu từ `PinePort\Wonderwhales`
  (`shift=1`), SL PSAR/ATR%/fixed + sàn `InpMinStopPoints`, TP bắt buộc `InpTakeProfitR`, volume từ
  `InpRiskPercent` qua `ExecCalcProfit`, mọi lệnh qua `ExecBroker`.
- Đăng ký đầy đủ: `sim_configs.EA_INPUTS`/`DEMO_EA_NAMES`, `validate-project.py`,
  `validate_demo_execution.py`, `test_demo_execution.py`, `deploy_pineport.ps1`, preset và scenario
  `reports/build/tester-run/ww_demo_exec.ini` + `reports/build/tester-sets/ww_demo_exec.set`.
- Ba lỗi runtime được sửa trong quá trình kiểm chứng:
  1. `OnInit` mở journal **trước** `ReconcilePosition()` để dòng `ADOPT`/`EXIT` lúc init không bị mất.
  2. `EnsureStops()` gọi `ExecModifyStops` để đặt lại SL/TP nếu vị thế đang mở thiếu stop; ghi
     `STOPS_REASSERT`.
  3. Sau `ExecOpenMarket`, ticket vị thế được đồng bộ bằng `ExecFindOwnPosition` (không gọi reconcile
     ngay để tránh coi độ trễ hiển thị là đóng vị thế).
- **Sửa hành vi halt**: `InpMaxDailyLossPct` là khoá **theo ngày**; trước sửa, một ngày lỗ 2% khiến bot
  halt vĩnh viễn. Nay sang ngày giao dịch mới EA tự mở khoá, ghi `RESUME`; halt do `InpMaxDrawdownPct` và
  kill switch vẫn dính tới khi khởi động lại. ADR 0007 và `guides/demo-execution.md` đã cập nhật.

### 69.3 Compile và deploy

- `scripts/build-mql5.ps1 -Filter Experts\WonderwhalesDemoEA.mq5` → **PASS 0 errors, 0 warnings**,
  `ex5=93756 bytes` (MetaEditor build 6292). Compile chỉ chứng minh cú pháp.
- `scripts/deploy_pineport.ps1 -Apply -Force` → **DEPLOY_OK**, copy `MQL5\Experts\WonderwhalesDemoEA.mq5`
  và compile lại 0/0.

### 69.4 Bằng chứng Strategy Tester (headless, real run)

- `run_tester.ps1 -Scenario ww_demo_exec`: terminal64 exit **0** sau **56.3 s**; archive tại
  `reports/build/tester-reports/ww_demo_exec/`:
  `sim_ww_demo_exec.csv` (28055 bytes, sha256 `EDE0A513A69A`),
  `tester_ww_demo_exec.htm` (118300 bytes, `645A1F68E9E9`),
  `tester_ww_demo_exec.png` (7420 bytes, `40B66E7A6A0E`).
- Journal 18 cột: `INIT` (`mode=DEMO_EXECUTION`, `magic=25007001`, `config_hash=84AB2384`),
  **41 ENTRY / 41 EXIT**, 18 dòng `RISK` (entry bị chặn), 2 `HALT`, 1 `RESUME`, 1 `SUMMARY`.
- Entry đầu `2026.01.05 02:00` (SELL, SL/TP khác 0), entry cuối `2026.01.15 20:30`; volume 0.03–0.10
  theo ngân sách rủi ro ~1%/lệnh (`loss=…|budget=…` trong cột reason).
- Halt 1: `daily_loss_limit_reached|loss=2.06%` ngày 2026-01-06 → sang 2026-01-07 ghi `RESUME` và tiếp
  tục vào lệnh. Halt 2: `max_drawdown_reached|dd=8.01%` ngày 2026-01-15 → dính tới hết kỳ test (đúng
  thiết kế). `SUMMARY`: trades=41, wins=11, losses=30, **net=-625.72**, halted=`HALTED`.
- Lưu ý vận hành: `.set` phải được copy vào `MQL5\Profiles\Tester\` (lần chạy đầu thiếu bước này nên
  dùng input mặc định; journal khi đó là `wonderwhales_demo.csv` và đã phát hiện lỗi halt vĩnh viễn nói
  trên). Kết quả trên **không** phải cam kết lợi nhuận; chiến lược vẫn `UNPROVEN`.

### 69.5 Gate khi kết thúc mục này

- `validate_demo_execution.py` → **checks=13 fail=0**, gồm `PASS: wonderwhales demo EA guardrails`.
- `validate-project.py` → **checks=14 fail=1**. Lỗi duy nhất đến từ file WIP của chủ dự án
  `mt5/Experts/InfiniteRunnerXAUV3DemoEA.mq5` (untracked, không sửa): các dòng 534/1621/1626 dùng
  `AccountInfoDouble`, 1699/1704/1705 dùng `AccountInfoInteger` trong phạm vi bị quét. Không bypass gate.
- `pytest python/tests` → **428 passed, 2 failed**; cả hai fail đều do cùng file WIP trên
  (`test_project_validator_passes`, `test_repository_passes_static_checks`).
- Link tương đối trong 3 tài liệu đã sửa resolve đủ; bảng markdown không lệch cột (ngoài false positive
  do `|` escape trong ô như `BLOCKED|plan`).
- **NOT_RUN**: phiên `WonderwhalesDemoEA` trên tài khoản demo thật (cần operator chạy chart).
- **Lợi nhuận: UNPROVEN** — không thay đổi.

## 70. Tái cấu trúc tài liệu theo mục đích + cổng chặn link chết — 2026-11-03

### 70.1 Việc đã làm

- Chuyển toàn bộ tài liệu còn hiệu lực sang cây `00-start` / `10-bots` / `20-operations` /
  `30-research` / `90-decisions` / `99-archive` bằng `git mv` (giữ lịch sử).
- Viết mới 5 trang bot, `input-convention.md` (hợp đồng phase C), `troubleshooting.md`,
  `evidence.md`, `open-source-research.md`, `glossary.md`, ADR 0008, `LINK_MAP.md`.
- Viết lại `docs/README.md`, `README.md` gốc, `00-start/roadmap.md`, `20-operations/presets.md`.
- Thêm `scripts/check_docs_links.py` + 6 test; nối vào `validate-project.py`.
- Cô lập `InfiniteRunnerXAUV3DemoEA.mq5` sang `archive/wip/2026-11-03_InfiniteRunnerXAUV3/`.
- Dọn rác gốc (`reportsbuild-allsuite/`, `pip-*`, `pytest-of-*`, `node_modules/`, log).

### 70.2 Cổng khi kết thúc

- `check_docs_links.py` → `broken=0 external=0 checked=397`.
- `validate-project.py` → `checks=15 fail=0`.
- `validate_demo_execution.py` → `checks=13 fail=0`.
- 6 validator indicator → 32/29/36/34/44/31 pass, 0 fail.
- `pytest` → `436 passed`.
- `deploy_pineport.ps1 -Apply -Force` → `DEPLOY_OK`, 0 errors / 0 warnings.
- Kiểm tra thủ công (đều PASS):
  - Từ `docs/README.md` bấm tới được 5 trang bot (`10-bots/`), 4 tài liệu vận hành
    (`20-operations/install.md`, `strategy-tester.md`, `toolchain.md`, `demo-execution.md`),
    8 ADR (`90-decisions/0001`–`0008`, `README.md` link đủ), `99-archive/README.md`.
  - 5 trang bot hiển thị đúng magic + preset + nhãn: PATrendRider `25002001` /
    `pa_trendrider_xau_demo.json` / `PARTIAL`; Grid `25004001` / `grid_demo.json` / `NOT_RUN`;
    DCA `25005001` / `dca_demo.json` / `NOT_RUN`; InfiniteRunner `25006001` /
    `infinite_runner_demo.json` / `NOT_RUN`; Wonderwhales `25007001` / `wonderwhales_demo.json` /
    `UNPROVEN`. Lợi nhuận của cả 5 bot vẫn `UNPROVEN` — không nhãn nào được nâng.
  - `docs/99-archive/LINK_MAP.md` mở được, có 2 bảng (Bảng A di chuyển thật, Bảng B link cũ
    không tồn tại).
  - `README.md` gốc 33 dòng (≤60), không còn link `v2/`.

### 70.3 Không đổi

- Không sửa `input`/logic EA, không sửa `configs/demo/*.json`, không nâng nhãn trạng thái nào.
- `99-archive/` và `PROGRESS.md` là bất biến; link bên trong không bị viết lại.

### 70.4 Còn mở (trung thực)

> **Cập nhật 2026-11-08 (xem §90):** hai mục đầu đã được xử lý tới mức có thể xác minh bằng dữ liệu trên đĩa;
> mục "nhãn lợi nhuận" vẫn giữ `UNPROVEN` (không thể giải quyết bằng tester).

- ~~Dọn vị thế lạc magic 25006001 trên chart demo~~ → **KHÔNG xoá state file**: journal demo
  (`infinite_runner_demo.csv`) kết thúc bằng `ENTRY SELL ticket=-1507758291 … entries=1|exits=0` ⇒ vị thế **vẫn
  đang mở** khi bot dừng; state `MQL5\Files\infinite_runner_demo_state.csv` đang giữ đúng vị thế đó (ticket
  `-1507758291`, SL 3953.81, TP 3848.81). Xoá file này lúc này sẽ làm bot mất dấu vị thế. Chỉ xác nhận được đã
  đóng khi có terminal/demo; chưa làm.
- ~~Chạy lại tester IR~~ → **ĐÃ CHẠY** (§90): `infinite_runner_demo_exec`, XAUUSDm M5, 2026.01.05→2026.10.01,
  deposit 10.000 → journal 105.343 dòng, `entries=101|exits=101|wins=81|losses=20|blocks=52462|sl_updates=113|
  realized=+1.70|halted=ACTIVE`, equity cuối 10.001,70. Với state sạch, tester **không** tái hiện chẩn đoán "vị
  thế lạc chiếm slot". Bằng chứng: `reports/build/tester-reports/infinite_runner_demo_exec/`.
- Nhãn lợi nhuận của cả 5 bot demo vẫn là `UNPROVEN`; không có kết luận mới về hiệu quả chiến lược.

---

## 71. Wonderwhales XAU 2-mode — bot demo thứ sáu (ADR 0009) — 2026-11-04

### 71.1 Việc đã làm

- Nhánh `feat/wonderwhales-xau-2mode-ea` (chưa push, chưa merge). Đặc tả
  `docs/10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md` lên **v2.2** (chốt S1–S4); thiết kế
  `docs/superpowers/specs/2026-11-04-wonderwhales-2mode-ea-design.md`; kế hoạch
  `docs/superpowers/plans/2026-11-04-wonderwhales-2mode-ea.md`.
- EA mới `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` (magic `25008001`, một magic, hai chế độ Scalp/Swing,
  mode lưu theo từng lệnh) + 10 module `mt5/Include/Wonderwhales/WW2*.mqh` + test thuần logic
  `mt5/Scripts/WW2CoreTests.mq5`.
- Đăng ký: ADR 0009, preset `configs/demo/wonderwhales_xau_2mode_demo.json` (71 key khớp EA),
  `sim_configs.py` (spec input + `DEMO_EA_NAMES` + cross-check), `validate-project.py` (kind `ww_2mode`,
  `EXEC_SOURCES`, `REQUIRED_FILES`, nhánh preset), `validate_demo_execution.py` (nhánh guardrail + ADR 0009),
  `python/tests/test_demo_execution.py`, catalog `docs/10-bots/README.md` (16 EA), trang
  `docs/10-bots/wonderwhales-2mode.md`, index ADR, `input-convention.md`, `demo-execution.md`.

### 71.2 Cổng khi kết thúc

- `deploy_pineport.ps1 -Apply -Force` → `DEPLOY_OK`, **0 errors / 0 warnings** (EA + `WW2CoreTests`).
- `validate-project.py` → `checks=15 fail=0`.
- `validate_demo_execution.py` → `checks=14 fail=0` (13→14, thêm guardrail bot thứ sáu).
- `check_docs_links.py` → `broken=0 external=0 checked=413`.
- `pytest` → **439 passed** (436→439, +3 case tham số cho EA thứ sáu).

### 71.3 Bằng chứng Strategy Tester (headless, `terminal64.exe /config:`)

- `ww2_scalp_parity_on` (`InpRequireParity=true`): **0 ENTRY**, `52778` dòng
  `ENTRY_BLOCKED|reason=parity_blocked|parity_not_proven`; SUMMARY `trades=0|entries=0|parity=REQUIRED`
  → cổng parity chặn entry đúng S2. Artefact `reports/build/tester-reports/ww2_scalp_parity_on/`.
- `ww2_scalp_demo_exec` (parity off, XAUUSDm M5, 2026.01.05→10.01): **6 ENTRY / 6 EXIT**, SL+TP mọi lệnh
  (TP = 1.5R), volume ≤ `InpMaxExposure`, lỗ ≤ budget; kết thúc HALT `max_drawdown_reached|dd=5.00%`.
  `net=-442.99`.
- `ww2_swing_demo_exec` (parity off, XAUUSDm H1, 2018.01.01→2026.10.01 để có W1/D1 EMA200): **16 ENTRY /
  16 EXIT**, **10 TRAIL** (BE ở r≈1.0, structure ở r≥1.3; R ≤ ~1.7), 4 HALT (3 daily loss + 1 drawdown
  5.01%). `net=-290.41` (số liệu sau khi sửa review ở §71.7).

### 71.4 Sự cố đã sửa trong lúc kiểm chứng

- `ReconcilePosition` từng ghi đè SL ban đầu (`initial_sl`) bằng SL broker đã trailing → `R` nổ (287, 471).
  Đã tách `current_sl` (SL hiện tại, dùng cho `EnsureStops`) khỏi `initial_sl` (neo R), lưu `pos_current_sl`
  trong state, và thêm test `r_ignores_trailed_stop` vào `WW2CoreTests`. Sau khi sửa, R trong Swing nằm ở
  ~1.0–1.38 (đúng ngưỡng BE/trail).

### 71.5 Nhãn trung thực (không nâng)

- **Bot `WonderwhalesXAU2ModeEA`: `NOT_RUN`.** Hai scenario parity-off chỉ là **bằng chứng hạ tầng
  (`NOT_STRATEGY_RESULT`)** — risk tester 1% để min-lot vượt được ngân sách, không phải cấu hình chiến lược.
- **Parity Pine ↔ MT5 vẫn `BLOCKED`** (chưa có CSV tham chiếu Pine). Vì vậy **không** coi `net=-442.99`
  hay `net=-292.99` là kết quả chiến lược; lợi nhuận của bot giữ `UNPROVEN`, trạng thái giữ `NOT_RUN`.
- Chưa chạy phiên demo chart; `WW2CoreTests` đã compile nhưng chưa chạy trên chart (cần terminal thủ công).

### 71.6 Không đổi

- Không sửa `WonderwhalesDemoEA` / `WonderwhalesSimEA` / `configs/sim/*` / `99-archive/**`; không nâng nhãn
  của 5 bot cũ; `PROGRESS.md` chỉ ghi thêm.

### 71.7 Sửa theo review toàn nhánh (2026-11-04)

Review độc lập (một subagent, đọc cả nhánh `e9dd488..HEAD`) trả về 8 phát hiện mức **Important** — đã sửa
trong **một** lượt, compile lại 0/0 và chạy lại tester Swing/Scalp:

1. Kill switch và risk-halt bị warm-up guard che (lệnh khẩn không chạy khi thiếu nến) → đưa khối khẩn lên
   trước guard warm-up.
2. `WW2CoreTests` vector min-lot sai (risk 1 / loss-per-lot 10 → không hề vượt budget) → đổi thành loss-per-lot
   200; kiểm chứng bằng mirror Python (vector cũ **RED**, mới **GREEN**).
3. Vị thế adopt khi mất state bị quản lý theo `InpTradingMode` hiện tại và suy R từ SL đã trailing → giữ mode
   `SIGNAL_ONLY` (không trailing theo mode), không suy R (spec §7.3/§12.18).
4. Trailing cấu trúc thiếu buffer ATR → cộng/trừ `InpTrailBufferAtr × ATR` ngoài swing (spec §2.1/§2.2).
5. BE/trailing arm chỉ theo R, chưa chờ nến đóng cùng hướng → thêm `allow_arm` (nến quản lý đóng cùng hướng);
   thêm test vector.
6. Kill-switch halt dính vĩnh viễn dù đã xoá file + restart (trái mô tả trong preset) → giải phóng
   `kill_switch_active` ở `OnInit` khi file không còn; halt khác vẫn dính.
7. Cổng parity không được validator bảo vệ (xoá code vẫn xanh) → ép token `parity_blocked` trong cả hai validator.
8. `InpHaltOnBreach` khai báo nhưng chưa dùng → tôn trọng: `false` thì chặn entry nhưng không đóng vị thế.

10 phát hiện **Minor** được ghi nhận và **hoãn** (timeframe field ghi mode thay vì period; `DrawdownPct()`
trả 0; `Ww2IndicatorReady` không dùng; chuỗi thua reset theo ngày vs theo lệnh; `InpMaxHoldingBars` đo theo
chart TF; thiếu log SL bị từ chối; freeze level chưa xử lý; `initial_r` chết; include `SimRiskGuard` thừa).

Sau khi sửa: `deploy` 0/0; Swing **16 ENTRY/EXIT, 10 TRAIL** (R ≤ ~1.7), Scalp **6 ENTRY/EXIT** (journal
sha không đổi); cổng `validate-project 15/0`, `validate_demo_execution 14/0`, `check_docs_links 0/413`,
`pytest 439 passed`.

## 72. Wonderwhales 2-mode — census tín hiệu Scalp: vì sao rất ít lệnh — 2026-11-05

Chủ sở hữu báo Scalp giao dịch rất ít và winrate/PnL kém. Trước khi đổi bất kỳ tham số nào, bước (a) của
lộ trình đã duyệt là **đo trước**: đếm tín hiệu theo từng cổng, để câu trả lời dựa trên dữ liệu chứ không
phải phỏng đoán.

### 72.1 Quyết định thiết kế

- **Không thêm input mới.** Dùng lại `InpDebug` (trước đây khai báo nhưng chưa dùng) làm công tắc census,
  và suy tên file từ `InpLogFile`: `<tên journal>_census.csv`. Lý do: giữ nguyên hợp đồng **71 input** của
  preset và mọi mirror/validator (không phải sửa JSON, `.set`, test tuple, docs input table). Đánh đổi nếu
  sai: operator không chọn được tên file census độc lập với journal.
- Census **không đụng** đường vào lệnh và **không đụng** hợp đồng 18 cột: nó chạy song song trong `OnTick`
  khi có nến mới và EA đang flat, ghi file riêng. Nhờ vậy nó ghi được cả tín hiệu mà cổng parity hoặc bộ
  định cỡ sẽ chặn.
- Bộ đếm tổng hợp được in ở `OnDeinit` (`census_summary`) **và** nhét vào trường `reason` của dòng
  `SUMMARY` trong journal — vì log tester không nằm trong archive, còn journal thì có.

### 72.2 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Include/Wonderwhales/WW2ScalpStrategy.mqh` | `Ww2ScalpGates` + `Ww2ScalpEvaluate()` trả lý do từng cổng; `Ww2ScalpEntry()` thành wrapper mỏng (hành vi không đổi) |
| `mt5/Include/Wonderwhales/WW2SwingStrategy.mqh` | `Ww2SwingGates` + `Ww2SwingEvaluate()`; `Ww2SwingEntry()` wrapper |
| `mt5/Include/Wonderwhales/WW2Census.mqh` | Mới: mở/ghi/đếm/tổng hợp/đóng CSV 15 cột |
| `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | Include, `g_census`, `g_census_stats`, `CensusFileName()`, `CensusBar()` trong `OnTick`, mở ở `OnInit` khi `InpDebug`, đóng + in summary ở `OnDeinit`, đếm vào `SUMMARY` |
| `mt5/Scripts/WW2CoreTests.mq5` | 11 test mới cho reason code (`scalp_census_*`, `swing_census_*`) |
| `scripts/tester/gen_ww2_sets.py` | Scenario `ww2_scalp_census` (M5, 2024.01.01, deposit 100.000, parity ON, `InpDebug=true`, risk 0,15%); deposit thành tham số từng scenario; telemetry đổi thành `sim_<name>_telemetry.csv` |
| `scripts/tester/run_tester.ps1` | Archive **mọi** `sim_<scenario>*.csv` (journal + census + telemetry), không chỉ journal |
| `scripts/tester/analyse_census.py` | Mới: funnel, lý do, cross-check, tín hiệu/năm |

Reason code: `signal | bias_invalid | no_m15_bias | setup_invalid | no_m5_flip | trigger_invalid |
no_m1_confirm` (Scalp) và `signal | bias_invalid | no_w1_bias | setup_invalid | no_d1_align |
trigger_invalid | no_h1_trigger` (Swing). Mỗi dòng ghi cổng **đầu tiên** không pass.

### 72.3 Kết quả census (2024-01-01 → 2026-09-30, M5, 194.869 nến)

Scenario `ww2_scalp_census`: `terminal64.exe /config:` headless 199 s, parity ON nên **0 lệnh**; 194.869
dòng `ENTRY_BLOCKED|reason=parity_blocked` trong journal (đúng S2).

| Cổng | Số nến | % tổng | % của cổng trước |
|---|---:|---:|---:|
| bias M15 (EMA20/50 + EMA200) | 160.310 | 82,27% | — (long 93.640 / short 66.670) |
| setup M5 (PSAR flip cùng phía bias) | 4.657 | 2,39% | 2,90% của nến có bias |
| signal M1 xác nhận | 52 | 0,03% | 1,12% của nến setup |

`reason`: `no_m5_flip` 155.653 (79,88%), `no_m15_bias` 34.559 (17,73%), `no_m1_confirm` 4.605 (2,36%),
`signal` 52 (0,03%). Tín hiệu theo năm: 2024 = 13, 2025 = 23, 2026 = 16 ⇒ **~19 tín hiệu/năm**. Counter-trend
setup bị loại: 734 (bias long) + 643 (bias short). `setup_pass_without_align=0` ⇒ lớp kiểm tra EMA của EA
không bao giờ mâu thuẫn với indicator.

### 72.4 Nguyên nhân gốc (có số liệu)

Với `InpSignalMode=WW_MODE_SAR_EMA`, indicator đã định nghĩa `buy = PSAR flip && fast_ema > slow_ema`
(`WwApplyMode`, `mt5/Include/PinePort/WonderwhalesContract.mqh`). Nên `m5.buy`/`m1.buy` là **sự kiện một
nến**, không phải trạng thái:

1. Cổng M5 chỉ mở ở **2,90%** số nến có bias.
2. Cổng M1 đòi thêm một flip M1 **trên đúng nến M1 vừa đóng trùng nến M5** → giết **98,88%** số nến đã qua M5.

Nói cách khác: ít lệnh **không** do bộ lọc bias quá chặt (82% nến có bias) mà do **hai cổng sự kiện một
nến chồng lên nhau**. Kiểm tra `m5.fast_ema>=m5.slow_ema` trong EA là dư thừa ở mode này (0 lần từ chối).
Hệ quả cho bước (b)/(c): muốn tăng số lệnh phải nới **cổng trigger** (M1) hoặc dùng M1 như trạng thái thay
vì sự kiện — không phải nới bias.

### 72.5 Artefact và cổng

- Artefact (gitignored): `reports/build/tester-reports/ww2_scalp_census/` — journal 45,0 MB, census 14,5 MB,
  telemetry, `.htm`, `.png`.
- `deploy_pineport.ps1 -Apply -Force`: **0 errors / 0 warnings** (gồm `WW2CoreTests`).
- `validate-project checks=15 fail=0`, `validate_demo_execution checks=14 fail=0`, `check_docs_links broken=0`,
  `pytest 439 passed`.
- `WW2CoreTests` đã compile nhưng **chưa chạy trên chart** (cần terminal thủ công): kỳ vọng
  `TEST|RESULT|ALL_PASS|pass=N fail=0|ww2=1`.

### 72.6 Nhãn trung thực (không nâng)

- Đây là **chẩn đoán**, không phải kết quả chiến lược. parity Pine ↔ MT5 vẫn `BLOCKED`, bot vẫn `NOT_RUN`,
  lợi nhuận vẫn `UNPROVEN`.
- Census chạy với parity ON nên **không** có lệnh nào; con số 52 là **số tín hiệu**, không phải số lệnh đã
  khớp, và không nói gì về lời/lỗ.
- Chưa thay đổi tham số chiến lược nào ở bước này — cố ý, để bước (b) đo được trên cùng một cấu hình.

## 73. Wonderwhales 2-mode — measurement harness: đo management trước khi tinh chỉnh — 2026-11-05

Bước (b) của lộ trình đã duyệt. Sau census (bước a, §72) cho thấy nút thắt nằm ở entry, bước này dựng một
ma trận đo **có thể so sánh** để trả lời: break-even và structure/PSAR trailing đóng góp gì vào expectancy,
thay vì chỉ nhìn winrate. Nguyên tắc: mỗi nhánh đổi đúng một biến, đo cả in-sample lẫn out-of-sample, và
đọc kết quả sau chi phí + drawdown, không phải winrate.

### 73.1 Thiết kế

- 8 scenario `ww2_meas_scalp_{is,oos}_{a,b,c,d}`: IS 2024.01.01→2025.06.30, OOS 2025.07.01→2026.10.01.
- Base (mọi nhánh): `InpExitOnFlip=false`, `InpMaxHoldingBars=0`, BE/trail tắt, 4 cờ trail `false`, các
  cap risk `0` (daily/weekly/drawdown/consecutive/cooldown), `InpMaxExposure=10.0`, `InpRiskPercent=0.15`,
  deposit 100.000, `InpRequireParity=false`. Cap tắt để HALT không cắt ngắn mẫu và làm mất tính so sánh;
  equity lớn + risk nhỏ để min-lot không bỏ tín hiệu.
- Nhánh: **A** = chỉ SL/TP; **B** = A + break-even 1,0R; **C** = B + structure trail (arm 1,3R);
  **D** = C + PSAR trail (cùng trigger 1,3R).
- R thực hiện được ghi vào **chính** dòng `EXIT` của journal: `|r=%.2f` (hoặc `|r=NA` khi không xác định
  được anchor), tính bằng `Ww2RealizedR(pnl, volume, initial_r, contract_size)` = `pnl/risk_money`, với
  `initial_r` **không** bao giờ bị ghi đè bởi stop đã trail. Không thêm cột — hợp đồng 18 cột giữ nguyên.

### 73.2 Hai lỗi thật của harness (đã sửa, đều im lặng)

| Lỗi | Triệu chứng | Sửa |
|---|---|---|
| `WW2TrailingCoordinator` chỉ xét candidate structure/PSAR khi `r >= InpTrailTriggerR` | "tắt trail" bằng `1e9` làm C/D **không bao giờ chạy**; 3 nhánh giống hệt nhau và ma trận suýt "chứng minh" sai rằng trailing vô dụng | nhánh C/D tự đặt `InpTrailTriggerR=1.3`; generator từ chối arm có cờ trail bật mà trigger tắt |
| `OnInit` từ chối `InpTrailTriggerR < InpBreakEvenTriggerR` | run kết thúc **exit 0 sau ~12 s** với report `Bars 0`, và runner archive lại CSV của lần chạy trước như thể mới | generator từ chối cặp giá trị sai; `run_tester.ps1` fail-closed khi report 0 bar và chỉ xoá archive sau khi kiểm tra |

`analyse_measure.py` thêm `WARNING: identical closed-trade outcome across N arms` để lần sau lỗi kiểu này
lộ ra ngay thay vì được đọc thành "trailing không có tác dụng".

### 73.3 Kết quả (2026-11-05)

In-sample 2024.01.01 → 2025.06.30:

| Nhánh | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD | Trail |
|---|---:|---:|---:|---:|---:|---:|---|
| A | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | — |
| B | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | BE ×5 |
| C | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | BE ×5, STRUCTURE ×1 |
| D | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | BE ×5, PSAR ×2 |

Out-of-sample 2025.07.01 → 2026.10.01:

| Nhánh | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD | Trail |
|---|---:|---:|---:|---:|---:|---:|---|
| A | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% | — |
| B | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% | BE ×10 |
| C | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% | BE ×9, STRUCTURE ×1 |
| D | 25 | 44,00% | −376,68 | −0,09 | 0,81 | 1,40% | BE ×9, STRUCTURE ×1 |

Mọi nhánh `INSUFFICIENT_SAMPLE` (n < 30).

### 73.4 Đọc kết quả (giả thuyết, không phải kết luận)

1. **Mọi exit là −1R hoặc +1,5R** (thêm 3 scratch ~0R ở OOS B/C/D). Break-even và structure/PSAR **có bắn**
   (5–10 sự kiện) nhưng **không đổi kết cục lệnh nào**: giá chạm TP 1,5R hoặc quay lại SL 1R trước khi stop
   trail kịp bị chạm. ⇒ Trailing/BE **không phải** đòn bẩy ở cấu hình này.
2. **BE 1R trung tính ở IS và hơi có hại ở OOS** (−291,23 USD so với A) vì kéo 3 lệnh thắng về scratch.
3. **Winrate không phải vấn đề.** TP 1,5R ⇒ winrate hoà vốn 40%. OOS A đạt đúng 40% (expectancy ≈ 0);
   IS chỉ 28,57% (âm). Nút thắt là **chất lượng/lọc entry**, khớp với census §72.
4. Mẫu quá nhỏ để tinh chỉnh (21/25 lệnh): chênh lệch ~0,3R không phân biệt được với nhiễu.

Xếp hạng giả thuyết cho bước (c)/kế tiếp: (1) cổng entry; (2) hình học SL/TP; (3) trailing — loại.

### 73.5 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Include/Wonderwhales/WW2Types.mqh` | `Ww2RealizedR()` — R = pnl/risk_money, `false` khi anchor không xác định |
| `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | `RealizedRSuffix()`; 2 đường EXIT (broker + close-at-market) nối `\|r=%.2f`/`\|r=NA` |
| `mt5/Scripts/WW2CoreTests.mq5` | `TestRealizedR()` 6 check (lãi/lỗ/hoà/3 anchor thiếu) |
| `scripts/tester/gen_ww2_sets.py` | `MEASURE_BASE`/`MEASURE_ARMS`/`MEASURE_WINDOWS`; `_check_measure_arm()` chốt 2 invariant; `to_date` thành tham số từng scenario |
| `scripts/tester/analyse_measure.py` | Mới: trades/winrate/net/expectancy R+USD/PF/max DD/exit-kind/histogram R/trail mix; `INSUFFICIENT_SAMPLE`; warning nhánh trùng kết cục |
| `scripts/tester/run_tester.ps1` | Fail-closed khi report 0 bar; xoá archive cũ chỉ sau khi run hợp lệ |
| `python/tests/test_analyse_measure.py` | 7 test (số học, r=NA, pnl thiếu, telemetry trail, empty/not-found, cảnh báo trùng) |
| `python/tests/test_tester_runner.py` | 2 contract cho fail-closed của runner |
| `python/tests/test_gen_ww2_sets.py` | 4 test cho invariant của ma trận |

### 73.6 Artefact và cổng

- Artefact (gitignored): `reports/build/tester-reports/ww2_meas_scalp_*/` — mỗi run có journal, telemetry,
  `.htm`, `.png`; 8 run mất ~13 phút (~90–110 s mỗi run).
- `deploy_pineport.ps1 -Apply -Force`: **0 errors / 0 warnings**.
- `validate-project.py` `checks=15 fail=0`; `validate_demo_execution.py` `checks=14 fail=0`;
  `check_docs_links.py` `broken=0 checked=427`; `pytest 452 passed` (trước bước này 439).
- `WW2CoreTests` compile 0/0 nhưng **chưa chạy trên chart** (cần terminal thủ công): kỳ vọng
  `TEST|RESULT|ALL_PASS|pass=N fail=0|ww2=1` (gồm 11 test census + 6 test realized-R).

### 73.7 Nhãn trung thực (không nâng)

- Toàn bộ ma trận chạy parity OFF ⇒ **`NOT_STRATEGY_RESULT`**: chỉ dùng để xếp hạng giả thuyết, **không**
  phải bằng chứng lợi nhuận. Bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`, parity Pine ↔ MT5 vẫn `BLOCKED`.
- Chưa đổi tham số chiến lược nào ở bước này — cố ý, để bước (c) đo parity trên cùng cấu hình.

## 74. Wonderwhales 2-mode — parity Pine ↔ MT5: comparator sẵn sàng, chốt `BLOCKED` (bước c) — 2026-11-05

Bước (c) của lộ trình là "viết script so parity". Kết quả điều tra trước khi viết: **script đã tồn tại**.
`scripts/compare_pine_exports.py` + `python/src/mt5_ea_ai_lab/evaluation/pine_parity.py` so CSV reference
của Pine với log `PineSignalLabEA`, có offset server, warm-up, tolerance, report JSON/CSV, và đã có 25 test.
Bên Pine cũng đã có schema + signal ID cho mode `SAR_EMA` (mode mà bot 2-mode dùng). Vì vậy viết thêm một
comparator thứ hai là trùng lặp, không phải tiến bộ. Việc còn thiếu là **artefact reference thật**, thứ mà
chỉ con người xuất được từ TradingView.

### 74.1 Thay đổi

| File | Thay đổi |
|---|---|
| `scripts/compare_pine_exports.py` | Thêm exit code `3` = `parity=BLOCKED reason=<pine\|mql5>_file_missing` khi thiếu file; `0/1/2` đặt tên hằng `EXIT_*`. Trước đây thiếu file rơi vào `2` (lỗi schema), không phân biệt được "chưa có reference" với "comparator hỏng" |
| `python/tests/test_pine_parity.py` | `test_cli_exit_codes` tách 3 nhánh: thiếu Pine → `3`, thiếu MQL5 → `3`, file hỏng → `2` |
| `docs/10-bots/wonderwhales-2mode.md` | §5.3 runbook parity (input khoá hai phía, 4 bước, luật quyết định, bẫy symbol suffix); §5 bullet; §6 trỏ §5.3 |
| `docs/30-research/indicators/parity.md` | Bảng exit code thêm `3`; mục giới hạn nêu `3` |
| `docs/20-operations/install.md` | §9 nêu exit code `3` cho comparator Wonderwhales |

### 74.2 Bẫy phải xử lý trước khi so (chưa từng ghi)

Comparator khớp `symbol` **chính xác**. Server Exness dùng `XAUUSDm`, TradingView dùng `XAUUSD` ⇒ để nguyên
thì *mọi* dòng thành `missing_in_*` và kết quả đọc sai hoàn toàn. Phải ghi cùng một chuỗi ở cột `symbol`
cả hai file. Đã ghi vào §5.3 của trang bot.

### 74.3 Luật quyết định (chốt trước, không đổi sau khi thấy kết quả)

Chỉ khi report có `status=match`, `mismatch_count=0`, và số tín hiệu so `>= 100` mới được đặt
`InpRequireParity=false`. Lưu JSON report làm bằng chứng. Mọi trường hợp khác giữ `true`.

### 74.4 Cổng

- Không file MQL nào đổi ở bước này nên trạng thái compile giữ nguyên từ §73: **0 errors / 0 warnings**.
- `pytest 452 passed` — số test **không tăng** vì 3 assert mới nằm trong `test_cli_exit_codes` có sẵn
  (`test_pine_parity.py`).
- `validate-project.py checks=15 fail=0`, `validate_demo_execution.py checks=14 fail=0`,
  `check_docs_links.py broken=0 checked=430` (tăng 3 link do §5.3 của trang bot).

### 74.5 Nhãn trung thực (không nâng)

- Parity Pine ↔ MT5 vẫn **`BLOCKED`**: không có CSV reference thật, nên không có kết quả parity nào.
  Comparator đã test chỉ chứng minh công cụ đúng, **không** chứng minh hai implementation tương đương.
- Không có thay đổi tham số chiến lược; bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`.
- Việc cần người dùng làm: xuất CSV reference từ TradingView (xem §5.3 / checklist
  [`parity.md`](30-research/indicators/parity.md) mục 9) rồi báo lại để chạy comparator.

## 75. Wonderwhales 2-mode — sửa cổng entry: cửa sổ trigger (task D) — 2026-11-05

Chủ sở hữu chọn hướng "sửa cổng entry". Census §72 đã chỉ ra nút thắt; bước này thực thi giả thuyết
xếp hạng #1 bằng đúng một biến, đo trước–sau trên cả in-sample lẫn out-of-sample.

### 75.1 Nguyên nhân (đã xác nhận trong code)

Cả census và đường vào lệnh chỉ đọc `shift=1` cho mọi khung (`WonderwhalesXAU2ModeEA.mq5` dòng 845–960).
Nên cổng M1 đòi **đúng cây M1 cuối cùng** của nến M5 vừa đóng phải là cây flip — trong 5 cây M1 của nến
M5 chỉ cây thứ 5 được xét. Khớp 100% với `no_m1_confirm` giết 98,88% số setup ở census.

### 75.2 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | Input `InpTriggerWindowBars` (mặc định `1`); helper `TriggerWindow()`; census + đường entry (Scalp & Swing) đọc trigger qua `Ww2ReadTriggerWindow()` |
| `mt5/Include/Wonderwhales/WW2SignalReader.mqh` | `Ww2ReadTriggerWindow()`: đọc cửa sổ trigger của nến setup, lấy cây bắn **gần nhất**; cây shift-1 vẫn phải đọc được để lỗi indicator vẫn là `trigger_invalid` |
| `configs/demo/wonderwhales_xau_2mode_demo.json` | Thêm `InpTriggerWindowBars: 1` (preset 71 → **72 key**) |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | Schema + cross-check: `window ≤ số cây trigger trong một nến setup` (5 cho M5/M1, 24 cho D1/H1) |
| `python/tests/test_demo_execution.py` | 2 test: mặc định `1` giữ nguyên hành vi; ràng buộc cửa sổ (6 bị từ chối, 5 qua, 0 bị từ chối) |
| `scripts/tester/gen_ww2_sets.py` | `GATE_VARIANTS` + `gate_scenarios()` → `ww2_meas_scalp_{is,oos}_gate_{w1,w5}` |
| `python/tests/test_gen_ww2_sets.py` | Test ma trận cổng: 4 scenario, `w1` vs `w5` khác **đúng một** input, management nhánh A |

Cổng M1 (`Ww2ScalpEvaluate`) **không đổi**: chỉ nguồn dữ liệu trigger đổi, nên 11 test census cũ vẫn đúng.
Mặc định `1` tái lập chính xác hành vi cũ — harness kiểm chứng điều này bằng số, không bằng lời.

### 75.3 Kết quả (đo bằng ma trận sẵn có, 4 lượt, mỗi lượt đổi một biến)

| Cửa sổ | Nhánh | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD | Sample |
|---|---|---:|---:|---:|---:|---:|---:|---|
| IS 2024.01.01→2025.06.30 | `gate_w1` (đối chứng) | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% | `INSUFFICIENT_SAMPLE` |
| IS | `gate_w5` | **282** | 36,52% | −4.287,54 | **−0,10** | 0,83 | 5,95% | **OK** |
| OOS 2025.07.01→2026.10.01 | `gate_w1` (đối chứng) | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% | `INSUFFICIENT_SAMPLE` |
| OOS | `gate_w5` | **298** | 42,62% | **+2.601,60** | **+0,06** | 1,10 | 2,89% | **OK** |

1. **Đối chứng trùng khớp tuyệt đối** với nhánh A của §73 (21 lệnh/−988,62 và 25 lệnh/−85,45) ⇒ mặc định
   `1` không đổi hành vi.
2. **Số lệnh ~13×** và **expectancy tốt lên ở cả hai cửa sổ** (−0,32→−0,10 R; −0,01→+0,06 R); OOS vượt 0,
   PF 1,10, maxDD 2,89%.
3. Sample chuyển `INSUFFICIENT_SAMPLE` → **`OK`** ở cả hai cửa sổ: harness bắt đầu xếp hạng được thay vì
   chỉ báo "chưa đủ mẫu".

### 75.4 Đọc kết quả (không nâng nhãn)

- Toàn bộ vẫn **`NOT_STRATEGY_RESULT`** (parity OFF). OOS dương **không** phải bằng chứng lợi nhuận.
- **IS vẫn âm** ⇒ chất lượng entry **chưa** được chứng minh. Chỉ khẳng định được: cửa sổ trigger là nút thắt
  thật, và sửa nó cải thiện rõ ở cả hai cửa sổ.
- IS winrate 36,52% < 40% (winrate hoà vốn của TP 1,5R); OOS 42,62% > 40%. Nhất quán với dấu của expectancy.
- Giả thuyết kế tiếp, chưa làm: **cổng setup M5** (cửa sổ M5 / setup dạng trạng thái) hoặc **hình học SL/TP**.

### 75.5 Cổng

- `deploy_pineport.ps1 -Apply -Force` (gồm `WW2SignalReader`): **0 errors / 0 warnings**.
- `validate-project.py checks=15 fail=0`; `validate_demo_execution.py checks=14 fail=0`;
  `check_docs_links.py broken=0 checked=430`; `pytest 455 passed` (trước bước này 452; thêm 2 test preset +
  1 test ma trận cổng).

### 75.6 Nhãn trung thực

- Parity vẫn `BLOCKED`; bot vẫn `NOT_RUN`; profit vẫn `UNPROVEN`. Không có kết quả nào ở đây là bằng chứng
  lợi nhuận vì mọi lượt đo đều parity OFF.
- Thay đổi này đụng **hợp đồng preset**: 71 → 72 key. Đã cập nhật đồng bộ JSON, schema, cross-check, test và
  docs.

## 76. Wonderwhales 2-mode — cửa sổ setup M5 (task E) — 2026-11-05

Chủ sở hữu chọn giả thuyết kế tiếp: cổng setup M5. Cùng phương pháp: mỗi lượt đổi đúng **một** biến,
management nhánh A, đo in-sample + out-of-sample, so với đối chứng.

### 76.1 Quyết định

- `InpSetupWindowBars` là **input công khai**, mặc định `1` (= hành vi gốc). Preset 72 → **73 key**.
- Đo cửa sổ setup **một mình**: `InpTriggerWindowBars` giữ ở mặc định `1`, để hiệu ứng quy được cho đúng
  một biến. Tổ hợp `(setup 5, trigger 5)` là bước **riêng**, chưa làm ở đây.
- Chủ sở hữu đã chốt: preset demo **giữ `InpTriggerWindowBars=1`** cho tới khi parity xong (parity `BLOCKED`
  nên preset không tạo lệnh nào; IS vẫn âm nên chưa có cơ sở đổi mặc định cho operator).

### 76.2 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | Input `InpSetupWindowBars`; helper `SetupWindow()`; cả 4 điểm đọc setup (census + entry, Scalp + Swing) dùng `Ww2ReadSignalWindow` |
| `mt5/Include/Wonderwhales/WW2SignalReader.mqh` | Đổi tên `Ww2ReadTriggerWindow` → `Ww2ReadSignalWindow` (giờ dùng cho cả setup lẫn trigger; cùng ngữ nghĩa "cây bắn gần nhất thắng") |
| `configs/demo/wonderwhales_xau_2mode_demo.json` | Thêm `InpSetupWindowBars: 1` (72 → 73 key) |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | Schema cho `InpSetupWindowBars` (1..100, integer) |
| `python/tests/test_demo_execution.py` | Test mặc định hai cửa sổ giữ nguyên hành vi |
| `scripts/tester/gen_ww2_sets.py` | `SETUP_VARIANTS` + `setup_scenarios()`; gộp 2 ma trận cửa sổ vào `_window_scenarios()` |
| `python/tests/test_gen_ww2_sets.py` | Test ma trận setup: 4 scenario, `s1` vs `s5` khác đúng một input, trigger window không đổi |

### 76.3 Kết quả

| Cấu hình (setup, trigger) | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| `(1, 1)` đối chứng | IS | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% |
| `(1, 1)` đối chứng | OOS | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% |
| `(5, 1)` setup s5 | IS | 235 | 37,45% | −2.734,12 | −0,08 | 0,87 | 5,26% |
| `(5, 1)` setup s5 | OOS | 238 | 39,92% | −517,91 | −0,01 | 0,97 | 1,83% |
| `(1, 5)` trigger w5 (§75) | IS | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% |
| `(1, 5)` trigger w5 (§75) | OOS | 298 | 42,62% | +2.601,60 | +0,06 | 1,10 | 2,89% |

### 76.4 Đọc kết quả

1. Đối chứng `s1` trùng khớp **tuyệt đối** với nhánh A và với `w1` ⇒ hai mặc định đúng là không đổi hành vi.
2. **Cả hai cửa sổ đều là nút thắt thật**: mỗi cái một mình tăng số lệnh ~11–13× và gần như cắt đôi
   expectancy âm ở IS (−0,32 → −0,08 / −0,10 R).
3. **Chỉ cửa sổ trigger vượt 0 ở OOS** (+0,06R, PF 1,10). Setup s5 tốt hơn một chút ở IS (−0,08 so với
   −0,10 R) nhưng **không** qua OOS (−0,01R, PF 0,97) ⇒ cửa sổ trigger là đòn bẩy mạnh hơn.
4. Vẫn **`NOT_STRATEGY_RESULT`**: IS âm ở mọi biến thể, nên **không** có tuyên bố lợi nhuận.

Bước kế tiếp hợp lý (chưa làm, chờ quyết định): đo tổ hợp `(5, 5)` như **một** biến thêm vào trên nền `(1, 5)`.

### 76.5 Cổng

- `deploy_pineport.ps1 -Apply -Force`: **0 errors / 0 warnings**.
- `validate-project.py checks=15 fail=0`; `validate_demo_execution.py checks=14 fail=0`;
  `check_docs_links.py broken=0 checked=430`; `pytest 456 passed` (trước bước này 455; thêm 1 test ma trận
  setup).

### 76.6 Nhãn trung thực

- Parity vẫn `BLOCKED`, bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`; mọi lượt đo parity OFF nên là
  `NOT_STRATEGY_RESULT`.
- Hợp đồng preset 72 → 73 key; đã cập nhật JSON, schema, test, docs cùng lúc.

## 77. Wonderwhales 2-mode — tổ hợp hai cửa sổ setup/trigger (task F) — 2026-11-05

Chủ sở hữu chọn đo tổ hợp `(setup 5, trigger 5)` như **một** biến thêm vào trên nền tốt nhất `(1, 5)`.

### 77.1 Thay đổi

| File | Thay đổi |
|---|---|
| `scripts/tester/gen_ww2_sets.py` | `COMBO_VARIANTS` + `combo_scenarios()` → `ww2_meas_scalp_{is,oos}_combo_{c1,c5}`; gộp ba ma trận cửa sổ vào `_window_scenarios()` |
| `python/tests/test_gen_ww2_sets.py` | Test tổ hợp: 4 scenario, `c1` cố định trigger 5, `c5` khác đúng một input (setup) |
| `docs/...` | Bảng kế tiếp ở bot page §5.6; hàng scenario ở strategy-tester.md; README |

Không đổi MQL: `InpTriggerWindowBars` và `InpSetupWindowBars` đã có từ §75/§76, nên không cần compile lại.

### 77.2 Kết quả (management nhánh A, parity OFF)

| Cấu hình (setup, trigger) | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| `(1, 1)` đối chứng | IS | 21 | 28,57% | −988,62 | −0,32 | 0,56 | 1,34% |
| `(1, 1)` đối chứng | OOS | 25 | 40,00% | −85,45 | −0,01 | 0,96 | 1,54% |
| `(5, 1)` setup | IS | 235 | 37,45% | −2.734,12 | −0,08 | 0,87 | 5,26% |
| `(5, 1)` setup | OOS | 238 | 39,92% | −517,91 | −0,01 | 0,97 | 1,83% |
| `(1, 5)` trigger | IS | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% |
| `(1, 5)` trigger | OOS | 298 | 42,62% | +2.601,60 | +0,06 | 1,10 | 2,89% |
| `(5, 5)` tổ hợp | IS | 854 | 41,92% | +4.207,65 | +0,03 | 1,06 | 5,46% |
| `(5, 5)` tổ hợp | OOS | 841 | 41,26% | +2.517,92 | +0,02 | 1,03 | 3,51% |

### 77.3 Đọc kết quả (đánh đổi, không phải thắng rõ)

1. Tổ hợp làm **cả hai** cửa sổ dương — lần đầu IS dương — với ~3× số lệnh so với từng cửa sổ riêng.
2. **Edge/lệnh mỏng đi ở OOS**: +0,02R (PF 1,03) so với +0,06R (PF 1,10) của `(1, 5)`. Cửa sổ setup rộng thêm
   nhiều setup chất lượng thấp hơn: tổng net OOS tương đương (2.518 so với 2.602) nhưng tốn ~3× số lệnh.
3. PF 1,03–1,06 với winrate ~41–42% so với hoà vốn 40% ⇒ edge **rất mỏng**, có thể nằm trong nhiễu và chi phí.
   `(1, 5)` vẫn là cấu hình edge/lệnh tốt nhất.
4. Vẫn **`NOT_STRATEGY_RESULT`**: không phải bằng chứng lợi nhuận.

Bước kế tiếp hợp lý (chưa làm, chờ quyết định): **hình học SL/TP** trên nền đã chọn (giả thuyết xếp hạng #2),
hoặc dò cửa sổ setup trung gian (2–4) để tìm điểm edge bắt đầu loãng.

### 77.4 Cổng

- Không đổi file MQL ⇒ compile giữ nguyên từ §76 (**0 errors / 0 warnings**).
- `validate-project.py checks=15 fail=0`; `validate_demo_execution.py checks=14 fail=0`;
  `check_docs_links.py broken=0 checked=430`; `pytest 457 passed` (trước bước này 456; thêm 1 test tổ hợp).

### 77.5 Nhãn trung thực

- Parity vẫn `BLOCKED`, bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`; mọi lượt đo parity OFF nên là
  `NOT_STRATEGY_RESULT`.
- Không thay đổi preset (chủ sở hữu đã chốt giữ `InpTriggerWindowBars=1`, `InpSetupWindowBars=1` cho tới khi
  parity xong).

## 78. Wonderwhales 2-mode — hình học TP (task G) — 2026-11-05

Chủ sở hữu chọn thử giả thuyết xếp hạng #2: hình học SL/TP. Đo trên nền edge/lệnh tốt nhất `(setup 1,
trigger 5)` và **chỉ** đổi `InpTakeProfitR` (SL giữ ở initial stop `1R`). Winrate hoà vốn `1/(1+TP)`:
50% / 44,4% / 40% / 33,3%.

### 78.1 Thay đổi

| File | Thay đổi |
|---|---|
| `scripts/tester/gen_ww2_sets.py` | `GEOMETRY_BASE`/`GEOMETRY_VARIANTS` + `geometry_scenarios()` → `ww2_meas_scalp_{is,oos}_geom_{tp10,tp125,tp15,tp20}`; đổi tên helper chung `_window_scenarios` → `_variant_matrix` (giờ phục vụ cả 4 ma trận) |
| `python/tests/test_gen_ww2_sets.py` | Test ma trận hình học: 8 scenario, nền `(1,5)` cố định, mỗi biến thể khác đối chứng **đúng một** input (`InpTakeProfitR`) |
| `docs/...` | Bảng ở bot page §5.7; hàng scenario ở strategy-tester.md; README |

Không đổi MQL ⇒ không cần compile.

### 78.2 Kết quả (base setup 1, trigger 5; management nhánh A; parity OFF)

| TP | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---|---:|---:|---:|---:|---:|---:|
| 1,0R | IS | 288 | 45,83% | −4.128,60 | −0,10 | 0,82 | 4,89% |
| 1,25R | IS | 284 | 40,49% | −4.401,09 | −0,11 | 0,82 | 5,47% |
| 1,5R (đối chứng) | IS | 282 | 36,52% | −4.287,54 | −0,10 | 0,83 | 5,95% |
| 2,0R | IS | 273 | 30,40% | −4.312,03 | −0,11 | 0,84 | 5,81% |
| 1,0R | OOS | 307 | 48,53% | −1.578,98 | −0,03 | 0,93 | 3,69% |
| 1,25R | OOS | 305 | 44,26% | −601,54 | −0,01 | 0,98 | 3,59% |
| 1,5R (đối chứng) | OOS | 298 | 42,62% | +2.601,60 | +0,06 | 1,10 | 2,89% |
| 2,0R | OOS | 287 | 36,59% | +3.912,31 | +0,09 | 1,14 | 3,31% |

Đối chứng `tp15` trùng khớp tuyệt đối với `gate_w5`/`combo_c1` ⇒ so sánh sạch.

### 78.3 Đọc kết quả — HAI CỬA SỔ KHÔNG ĐỒNG Ý

1. Winrate giảm đúng như dự đoán theo `1/(1+TP)` và luôn nằm **trên** ngưỡng hoà vốn tương ứng.
2. **IS: cả bốn mức TP đều âm** (−0,10…−0,11R), PF ~0,82–0,84 ⇒ hình học TP **không** giúp gì ở IS.
3. **OOS: ưu tiên TP lớn** đơn điệu (−0,03 → −0,01 → +0,06 → +0,09R; PF 1,14 ở TP 2,0R).
4. Mâu thuẫn IS/OOS ⇒ **không** được chọn TP từ dữ liệu này. TP 2,0R tốt ở OOS có thể là đặc điểm chế độ
   2025-07→2026-10 (xu hướng mạnh), không phải edge. Vẫn **`NOT_STRATEGY_RESULT`**.

Kết luận: trong ba đòn bẩy đã đo — trailing (§73, **loại**), cửa sổ sự kiện (§75–77, cải thiện rõ nhưng edge
mỏng), hình học TP (§78, **không nhất quán**) — chỉ cửa sổ sự kiện là cải thiện nhất quán. Edge của tín hiệu
như đang port vẫn **chưa được thiết lập**.

Bước kế tiếp hợp lý (chưa làm, chờ quyết định): (a) áp TP lớn lên nền `(5,5)` — cấu hình duy nhất dương ở
**cả hai** cửa sổ — để xem có giữ được không; (b) đổi **chất lượng tín hiệu** (ví dụ đòi hướng PSAR M5 còn
đồng ý tại thời điểm trigger) thay vì đổi exit; (c) kiểm chứng port bằng cross-implementation trước khi tinh
chỉnh tiếp.

### 78.4 Cổng

- Không đổi file MQL ⇒ compile giữ nguyên từ §76 (**0 errors / 0 warnings**).
- `validate-project.py checks=15 fail=0`; `validate_demo_execution.py checks=14 fail=0`;
  `check_docs_links.py broken=0 checked=430`; `pytest 458 passed` (trước bước này 457; thêm 1 test hình học).

### 78.5 Nhãn trung thực

- Parity vẫn `BLOCKED`, bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`; mọi lượt đo parity OFF.
- **Không** đổi preset, **không** chọn TP nào — dữ liệu không đủ để chọn.

## 79. Wonderwhales 2-mode — bộ lọc chất lượng SAR (task H) — 2026-11-05

Chủ sở hữu chọn đổi **chất lượng tín hiệu** thay vì exit. Bộ lọc: đòi hướng PSAR của khung setup **còn**
đồng ý tại thời điểm trigger, để loại setup mà xu hướng đã đảo ngược sau khi flip. Đo trên nền `(5,5)` —
cấu hình duy nhất dương ở **cả hai** cửa sổ — với **một** biến.

### 79.1 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Include/Wonderwhales/WW2ScalpStrategy.mqh` | `Ww2ScalpGates.sar_ok`; tham số tuỳ chọn `sar_agree=true` cho `Ww2ScalpEvaluate()`/`Ww2ScalpEntry()`; cổng mới `no_sar_agree` **giữa** setup và trigger |
| `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` | Input `InpScalpRequireSarAgree` (mặc định `false`); `g_sig_setup_now` (nến setup mới nhất); `SarAgree()`/`SetupSarAgree()`; census + entry truyền cờ này |
| `mt5/Scripts/WW2CoreTests.mq5` | 3 test: `no_sar_agree`, `sar_agree`, và mặc định (bỏ tham số) giữ hành vi cũ |
| `configs/demo/wonderwhales_xau_2mode_demo.json` | Thêm `InpScalpRequireSarAgree: false` (73 → **74 key**) |
| `python/src/mt5_ea_ai_lab/sim_configs.py` | Schema `InpScalpRequireSarAgree` (bool) |
| `python/tests/test_demo_execution.py` | Khẳng định mặc định `false` và preset hợp lệ |
| `scripts/tester/gen_ww2_sets.py` | `QUALITY_BASE`/`QUALITY_VARIANTS` + `quality_scenarios()` → `ww2_meas_scalp_{is,oos}_qual_{q0,q1}` |
| `python/tests/test_gen_ww2_sets.py` | Test ma trận chất lượng: 4 scenario, nền `(5,5)`, `q1` khác `q0` đúng một input |

Tham số tuỳ chọn có giá trị mặc định nên 11 test census cũ **không phải sửa** — hành vi gọi cũ giữ nguyên.

### 79.2 Kết quả (base (5,5); management nhánh A; parity OFF)

| Cấu hình | Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| `q0` tắt lọc (đối chứng) | IS | 854 | 41,92% | +4.207,65 | +0,03 | 1,06 | 5,46% |
| `q1` bật lọc | IS | 848 | 41,75% | +3.594,01 | +0,03 | 1,05 | 5,38% |
| `q0` tắt lọc (đối chứng) | OOS | 841 | 41,26% | +2.517,92 | +0,02 | 1,03 | 3,51% |
| `q1` bật lọc | OOS | 828 | 41,30% | +2.645,45 | +0,03 | 1,04 | 3,80% |

### 79.3 Đọc kết quả — BỘ LỌC BỊ LOẠI

1. Đối chứng `q0` trùng khớp tuyệt đối với `combo_c5` (854 và 841 lệnh) ⇒ so sánh sạch.
2. Lọc chỉ bỏ **6 lệnh (IS)** và **13 lệnh (OOS)** ≈ 0,7–1,5%: cửa sổ trigger chỉ rộng 1 nến M5 nên gần như
   không có thời gian để SAR M5 đảo ngược sau flip.
3. Tác động **đổi dấu giữa hai cửa sổ** (IS −613 USD, OOS +127 USD) và cùng bậc nhiễu ⇒ không có tác dụng.

Nghi vấn "chất lượng kém vì xu hướng đã đảo sau flip" **không đúng**.

### 79.4 Tổng kết bốn đòn bẩy đã đo

| Đòn bẩy | Kết quả | Bằng chứng |
|---|---|---|
| Trailing / break-even | **Loại** (không đổi kết cục lệnh nào) | §73 |
| Cửa sổ sự kiện (setup/trigger) | **Cải thiện rõ**, edge còn mỏng | §75–77 |
| Hình học TP | **Không nhất quán** IS vs OOS | §78 |
| Bộ lọc chất lượng SAR | **Không tác dụng** | §79 |

⇒ Với bốn đòn bẩy rẻ này, **edge của tín hiệu như đang port chưa được thiết lập**. Bước có ý nghĩa tiếp theo
không còn là tinh chỉnh tham số, mà là (a) **kiểm chứng port** bằng cross-implementation trước khi kết luận,
hoặc (b) chấp nhận kết luận "không có edge chứng minh được" và dừng tinh chỉnh.

### 79.5 Cổng

- `deploy_pineport.ps1 -Apply -Force`: **0 errors / 0 warnings** (10 source).
- `validate-project.py checks=15 fail=0`; `validate_demo_execution.py checks=14 fail=0`;
  `check_docs_links.py broken=0 checked=430`; `pytest 459 passed` (trước bước này 458; thêm 1 test ma trận
  chất lượng).

### 79.6 Nhãn trung thực

- Parity vẫn `BLOCKED`, bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`; mọi lượt đo parity OFF.
- Preset **không** đổi mặc định: hai cửa sổ vẫn `1`, bộ lọc SAR vẫn `false`. Mọi giá trị thí nghiệm chỉ nằm
  trong `.set` của tester.

## 80. Wonderwhales 2-mode — báo cáo tổng hợp nghiên cứu Scalp (a→h) — 2026-11-05

Chủ sở hữu chốt: dừng tinh chỉnh tham số, viết báo cáo tổng hợp.

- Tài liệu tracked: [`30-research/wonderwhales-scalp-study.md`](30-research/wonderwhales-scalp-study.md) —
  tự chứa, gồm: câu hỏi, phương pháp, công cụ, nguyên nhân gốc, kết quả **bốn đòn bẩy**, cấu hình tốt nhất,
  biết chắc/chưa biết, lệnh tái lập, việc còn mở.
- Thêm vào `REQUIRED_FILES` (`scripts/validate-project.py`) và index `docs/30-research/README.md`; trang bot
  §5 trỏ tới báo cáo.

**Kết luận chính (không nâng nhãn):** trong bốn đòn bẩy rẻ — trailing (**loại**), cửa sổ sự kiện (**cải thiện
rõ**, edge mỏng), hình học TP (**không nhất quán** IS/OOS), bộ lọc chất lượng SAR (**không tác dụng**) — chỉ
cửa sổ sự kiện cải thiện nhất quán. **Edge của tín hiệu như đang port chưa được thiết lập.** Cấu hình tốt nhất
hiện có `(setup 5, trigger 5)` dương ở cả hai cửa sổ nhưng PF chỉ 1,03–1,06 (winrate 41–42% so với hoà vốn 40%).

Bot vẫn `NOT_RUN`, parity vẫn `BLOCKED`, profit vẫn `UNPROVEN`. Preset mặc định **không đổi**.

## 81. Wonderwhales 2-mode — kiểm chứng port cross-implementation (task J) — 2026-11-06

Không có TradingView Pro ⇒ không tạo được CSV reference của Pine. Thay vào đó, viết một bản cài đặt **độc
lập** của spec Pine bằng Python và so **từng nến** với indicator MQL5 trên đúng cùng cây nến. Nhãn:
**`CROSS_IMPLEMENTATION`**, không phải `PARITY`; **không** dùng để gỡ `InpRequireParity`.

### 81.1 Phát hiện chặn trước đó (quan trọng)

`PineSignalLabEA` **không thể ghi tín hiệu trong Strategy Tester**: nó đòi
`BarsCalculated(handle) >= Bars()`, nhưng trong tester `Bars()` tính cả ~1 năm lịch sử nạp trước `FromDate`
còn indicator chỉ tính vùng test (`calculated=71009` vs `rates_total=141805`) ⇒ kẹt `indicator_not_ready`
suốt run, CSV chỉ có header (`signals=0`). Đây là lý do **chưa từng có kết quả parity nào**. Đã ghi vào
`docs/30-research/indicators/parity.md` §8 mục 8.

### 81.2 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Experts/WonderwhalesDumpTesterEA.mq5` | Mới: read-only, chỉ chạy trong tester; mỗi nến đóng ghi OHLCV + buffer `PinePort\Wonderwhales` (`psar,sar_dir,buy_signal,sell_signal,fast,slow,atr_pct,blocked_*`) ra CSV |
| `scripts/tester/gen_portref_sets.py` | Mới: sinh `.set`/`.ini` cho dump (M1/M5/M15) |
| `python/src/mt5_ea_ai_lab/signals/wonderwhales.py` | Mới: port độc lập spec Pine (PSAR/EMA/ATR + 4 mode + confirmed-bar) |
| `scripts/build_wonderwhales_reference.py` | Mới: bars → CSV schema Pine (chỉ dòng tín hiệu) |
| `scripts/compare_wonderwhales_bars.py` | Mới: so từng nến (tỉ lệ khớp chính xác, sai số tuyệt đối, mẫu lệch đầu tiên) |
| `scripts/deploy_pineport.ps1` | Thêm EA dump vào **cả** whitelist copy và danh sách compile (trước đó EA không được deploy ⇒ tester báo 0 bar) |
| Tests | `test_wonderwhales_port.py` (12), `test_portref_tooling.py` (9) |

### 81.3 Kết quả (XAUUSDm, 2025.01.01→2026.01.01, mode SAR_EMA, bỏ 300 nến warm-up)

| Khung | Nến so | `sar_dir` | `buy_signal` | `sell_signal` | `psar` (≤1e-4) | `fast`/`slow` (≤1e-4) |
|---|---:|---:|---:|---:|---:|---:|
| M15 | 23.320 | 97,39% | 99,40% | 99,70% | 87,82% | 100% |
| M5 | 70.496 | 97,69% | 99,50% | 99,71% | 88,70% | 100% |
| M1 | 352.837 | 97,89% | 99,62% | 99,65% | 90,14% | 100% |

- **EMA khớp hoàn toàn** (`fast` ≤5e-9, `slow` ≤1,3e-5, 100% nến trong 1e-4) ⇒ phần EMA đã kiểm chứng chéo.
- **Tín hiệu khớp 99,4–99,7%**.
- **PSAR lệch:** hướng lệch ~2,1–2,6% nến; mức PSAR chỉ khớp 88–90% trong 1e-4, lệch tối đa tới **120** (M15).
- Bản port đã tinh chỉnh sang biến thể clamp hai nến trước (M5: hướng 97,69% so với 96,44%), nhưng phần lệch
  còn lại **không giải thích được**.

### 81.4 Kết luận (trung thực)

- **Không kết luận được bên nào đúng.** Port theo PSAR Wilder/Pine cổ điển; indicator gọi `iSAR` của MT5 —
  vốn khác `ta.sar` (đúng rủi ro D1 trong `indicators/wonderwhales.md` §10, nay **đo được**).
- **Port chưa được kiểm chứng** ⇒ các kết luận chiến lược ở §6–§7 của báo cáo vẫn đứng trên tín hiệu chưa
  xác minh. Chỉ export thật từ TradingView mới giải quyết được.
- Việc nên làm tiếp: **thay `iSAR` bằng PSAR tự cài trong indicator** (bắt đầu từ biến thể sát nhất đã đo),
  rồi chạy lại cross-implementation; nếu khớp ~100% thì rủi ro chuyển thành "chưa có reference Pine".

Báo cáo đầy đủ: [`30-research/wonderwhales-scalp-study.md`](30-research/wonderwhales-scalp-study.md) §11.

### 81.5 Nhãn trung thực

- Đây là kiểm chứng **hai bản cài đặt độc lập của cùng một spec**, **không** phải parity với TradingView.
- Parity Pine ↔ MT5 vẫn **`BLOCKED`**; bot vẫn `NOT_RUN`, profit vẫn `UNPROVEN`; preset không đổi.

## 82. Wonderwhales 2-mode — PSAR tự cài dạng tuỳ chọn: chưa kiểm chứng (task K) — 2026-11-06

Chủ sở hữu chọn "thêm PSAR tự cài dạng tuỳ chọn" (mặc định giữ `iSAR`) rồi đo lại bằng cross-implementation.

### 82.1 Thay đổi

| File | Thay đổi |
|---|---|
| `mt5/Include/PinePort/WonderwhalesContract.mqh` | `ENUM_WW_PSAR`, `WwPsarState`, `WwPsarReset()`, `WwPsarStep()` — PSAR Wilder thuần, clamp hai nến trước |
| `mt5/Indicators/PinePort/Wonderwhales.mq5` | Input **thứ 14** `InpPsarEngine` (thêm ở cuối ⇒ caller 13 tham số giữ hành vi cũ); cache PSAR tự cài tăng dần; chỉ tạo handle `iSAR` khi dùng `iSAR`; log `psar_engine=`; **WARN** khi chọn `BUILTIN` |
| `mt5/Experts/WonderwhalesDumpTesterEA.mq5` | Input `InpPsarEngine` + truyền tham số thứ 14 |
| `scripts/tester/gen_portref_sets.py` | Thêm scenario `portref_dump_m5_builtin` |
| `docs/...` | Study §11.3; `indicators/wonderwhales.md` §13 mục 0 |

Mặc định `WW_PSAR_ISAR` ⇒ hành vi ship **không đổi**; compile **0 errors / 0 warnings**.

### 82.2 Kết quả đo lại — NHÁNH TỰ CÀI KHÔNG KHỚP (lỗi thật)

`portref_dump_m5_builtin`, XAUUSDm M5 2025, mode SAR_EMA, sau 300 nến:

| Nhánh | `sar_dir` | `buy` | `sell` | `psar` (≤1e-4) |
|---|---:|---:|---:|---:|
| `iSAR` (mặc định) | 97,69% | 99,50% | 99,71% | 88,70% |
| `BUILTIN` (tự cài) | **81,26%** | 97,40% | 98,18% | **1,60%** |

Hai chuỗi PSAR lệch **từ nến thứ hai** và ở trạng thái up/down khác nhau. Quét độ trễ −3…+3 đều ≤1,6% ⇒
**không phải lệch pha** mà là khác biệt thật giữa bản MQL5 và bản Python. Log xác nhận lượt chạy thật sự dùng
`psar_engine=BUILTIN`.

**Đã thử sửa bằng căn chỉnh điểm bắt đầu:** EA dump thêm vùng lịch sử nạp trước; comparator chạy port từ nến
đầu tiên indicator có giá trị (`aligned_from_row`). Kết quả sau căn chỉnh:

| Nhánh | Nến so | `sar_dir` | `psar` (≤1e-4) |
|---|---:|---:|---:|
| `iSAR` | 141.503 | 97,70% | 89,29% |
| `BUILTIN` | 141.503 | **90,63%** | **50,77%** |

**Đã tìm ra và sửa — kết quả cuối: KHỚP 100%.** Hai lỗi thật:

1. **Điểm bắt đầu khác nhau.** PSAR là truy hồi nên hai chuỗi chỉ khớp khi bắt đầu ở cùng nến. Trong tester
   `iSAR` (sub-indicator) tính trên **toàn bộ lịch sử terminal**, còn `rates_total` của indicator tự cài nhỏ
   hơn `Bars()` của EA. *Sửa:* EA dump thêm lịch sử nạp trước; comparator chạy port từ nến đầu tiên indicator
   có giá trị (`aligned_from_row`); và chuỗi tự cài được dựng bằng `CopyRates` trên đúng `Bars()` rồi đọc qua
   `offset = Bars() - rates_total`.
2. **Cache gồm cả nến đang chạy.** Nến đang chạy đổi OHLC liên tục và trạng thái PSAR là **bền**, nên đưa nó
   vào cache làm hỏng mọi giá trị sau. *Sửa:* lưu trạng thái (up/ep/af) từng nến, chỉ tính tới nến **đã đóng**,
   và **tính lại nến vừa đóng** mỗi lần.

Kết quả `portref_dump_m5_builtin` (141.503 nến so): `sar_dir`/`buy`/`sell`/`blocked_*` = **100%**; `psar` =
**100%** trong 1e-4 (max lệch **5e-9**); `fast`/`slow` = 100%.

⇒ Bản cài MQL5 của PSAR tự cài khớp chính xác bản Python độc lập; do đó chênh lệch 2,3% hướng so với `iSAR`
là **khác biệt thuật toán thật** giữa `iSAR` (MT5) và PSAR chuẩn/Pine — đã chứng minh từ cả hai phía (rủi ro
D1). Vẫn **không** biết bên nào khớp `ta.sar` (cần export TradingView thật).

`WW_PSAR_BUILTIN` **vẫn không phải mặc định** (mặc định `iSAR`, hành vi ship không đổi); bật nó đổi mọi tín
hiệu ⇒ phải chạy lại toàn bộ ma trận đo. Trong tester lượt tự cài mất ~250 s (lịch sử bị nạp lại nhiều lần);
trên chart chỉ tăng thêm mỗi nến mới.

**Tối ưu hiệu năng (2026-11-06).** Ba vấn đề: (1) bản đầu sao `Bars()` + dựng lại chuỗi **mỗi lần OnCalculate**
(theo từng tick) ⇒ dump M5 một-handle ~249 s; (2) bản "chỉ thêm đuôi" vẫn đánh địa chỉ theo **vị trí cửa sổ**,
mà tester **chèn nến cũ vào đầu** ⇒ phải kiểm tra **theo thời gian**; (3) một off-by-one coi nến đang chạy là
nến đã đóng. Bản cuối: **cache vòng neo đuôi** (O(1) mỗi nến, không dựng lại khi cửa sổ tái lập). Kiểm chứng:
**100%** (141.503 nến, max lệch 5e-9), dump M5 **249 s → ~18–20 s** (baseline `iSAR` ~12 s). Kèm sửa
`run_tester.ps1`: quét **mọi** agent Files dir (tester chọn agent 3000/3001 theo run) — trước đó archive rỗng dù
CSV đã ghi.

**CHƯA đổi được mặc định sang `WW_PSAR_BUILTIN`.** EA 2-mode tạo **6 handle** (M1…W1); một run với engine tự
cài vẫn mất hàng chục phút (18,4 phút ở bản trước, >12 phút ở bản tối ưu) so với ~110 s của `iSAR` ⇒ ma trận 32
run bất khả thi. **Mặc định giữ `iSAR`** (mọi số §73–§82 còn giá trị), giữ `InpPsarEngine` để chọn theo run.
Việc còn lại: làm chuỗi tự cài rẻ hơn nữa với **cửa sổ lớn** (chi phí còn lại ở việc dựng lại chuỗi khi cửa sổ
tái lập, không phải ở phép cộng dồn mỗi nến).

### 82.3 Trạng thái

- `WW_PSAR_BUILTIN` **mặc định TẮT**; khi bật, indicator in
  `WONDERWHALES|INFO|psar_engine_builtin|port_check=100pct_of_141503_bars|vs_isar_dir_diff=2.3pct`.
- Nhánh tự cài **đã được kiểm chứng** (khớp 100% bản Python độc lập) — nghĩa là **tính năng đã xong**, nhưng
  **đổi engine mặc định là quyết định riêng** (đổi mọi tín hiệu ⇒ phải chạy lại toàn bộ ma trận đo).
- Chưa đổi preset; chưa đổi engine mặc định.
- Nghi vấn cần kiểm: `rates_total` của indicator trong tester lớn hơn vùng dump (nến nạp trước `FromDate`)
  nên chuỗi PSAR tự cài bắt đầu ở nến sớm hơn vùng dump ⇒ phải đối chiếu **cùng điểm bắt đầu** rồi đo lại.
- Chỉ khi khớp ~100% mới bàn tới việc đổi engine mặc định — và khi đó phải chạy lại **toàn bộ** ma trận đo.

### 82.4 Nhãn trung thực

- Parity Pine ↔ MT5 vẫn `BLOCKED`; bot `NOT_RUN`; profit `UNPROVEN`.
- Nhánh PSAR tự cài đã kiểm chứng **là bản cài đúng của thuật toán đã chọn**; điều **chưa** biết là liệu thuật
  toán đó có khớp `ta.sar` của TradingView hay không — chỉ export thật mới trả lời được.

## 83. Wonderwhales 2-mode — engine PSAR đổi hẳn kết luận (task M, tiếp) — 2026-11-07

### 83.1 Tối ưu cuối cùng

Cache PSAR tự cài được sửa lần cuối: **truy tìm nến cuối theo THỜI GIAN** quanh đuôi cửa sổ thay vì so
`time[last_idx-1]`, vì tester **chèn nến cũ vào đầu** khi nạp lịch sử nên chỉ số cửa sổ luôn dịch. Quét lùi tối
đa 5000 nến hấp thụ mọi lần chèn trong vài vòng lặp, đồng thời xử lý luôn khoảng trống cuối tuần/ngày lễ; chỉ
dựng lại khi nến đã cache **biến mất** khỏi cửa sổ (reload thật).

Thời gian run EA 2-mode (6 handle): **18,4 phút → >12 phút → 348 s (~5,8 phút)**; `iSAR` ~110 s.
Kiểm chứng lại: **100%** (141.503 nến, max lệch 5e-9).

Kèm sửa `scripts/tester/run_tester.ps1` (quét **mọi** agent Files dir): trước đó archive rỗng dù CSV đã ghi,
vì tester dùng agent 3000/3001 tuỳ run.

### 83.2 Kết quả 6 cấu hình chính với engine `BUILTIN` (`NOT_STRATEGY_RESULT`)

| Cấu hình | `iSAR`: lệnh / net / exp R / PF | `BUILTIN`: lệnh / net / exp R / PF |
|---|---|---|
| `is_a` baseline | 21 / −988,62 / −0,32 / 0,56 | **22 / +339,41 / +0,11 / 1,19** |
| `oos_a` baseline | 25 / −85,45 / −0,01 / 0,96 | **30 / +259,41 / +0,08 / 1,11** |
| `is_gate_w5` | 282 / −4.287,54 / −0,10 / 0,83 | 297 / −2.244,07 / −0,05 / 0,92 |
| `oos_gate_w5` | 298 / +2.601,60 / +0,06 / 1,10 | 309 / +2.790,50 / +0,07 / 1,10 |
| `is_combo_c5` | 854 / +4.207,65 / +0,03 / 1,06 | 894 / +2.068,59 / +0,02 / 1,03 |
| `oos_combo_c5` | 841 / +2.517,92 / +0,02 / 1,03 | 885 / +1.034,02 / +0,01 / 1,01 |

**Đọc:** với PSAR chuẩn/Pine, **baseline (không nới cửa sổ) dương ở CẢ HAI cửa sổ** (+0,11R IS / +0,08R OOS),
còn với `iSAR` nó âm ở cả hai; và **nới cửa sổ trở nên kém hơn baseline**. ⇒ Phần lớn "cải thiện" ở §75–§77
trước đây là **bù đắp cho PSAR của iSAR**, không phải edge thật của tín hiệu. Đây là lý do engine quan trọng hơn
mọi tham số đã tinh chỉnh.

**Cảnh báo trung thực:** arm A chỉ **22–30 lệnh** (IS vẫn `INSUFFICIENT_SAMPLE`), PF 1,11–1,19 vừa phải, mọi
thứ vẫn parity OFF, và chỉ **6/32** cấu hình đã chạy lại ⇒ **không** phải bằng chứng lợi nhuận và **không** đủ
để đổi mặc định engine.

### 83.3 Trạng thái

- Mặc định ship **giữ `iSAR`** (mọi số §73–§82 còn giá trị); `InpPsarEngine` cho phép chọn `BUILTIN` theo run.
- Archive trong `reports/` (gitignored) hiện **trộn hai engine**; bảng iSAR gốc ở
  `reports/build/measure_summary_isar_engine.txt`.
- Việc còn lại (chờ quyết định): chạy **đủ 32 run** với `BUILTIN` (~3 giờ) để có bảng đầy đủ và so sánh từng
  đòn bẩy; hoặc chuyển sang đổi **định nghĩa entry**.

## 84. Wonderwhales 2-mode — ma trận đầy đủ 32 run với PSAR chuẩn (task M, chốt) — 2026-11-07

Chủ sở hữu chốt: chạy **đủ 32 run** với `InpPsarEngine=1` (PSAR tự cài/chuẩn) để so từng đòn bẩy dưới engine
chuẩn. Đã chạy hết, chia 5 chunk (~5,8 phút/run, tổng ~2,6 giờ). Bảng đầy đủ:
`reports/build/measure_summary_builtin_engine.txt` (gitignored). Bảng iSAR cũ:
`reports/build/measure_summary_isar_engine.txt`.

### 84.1 Các mốc chính (exp R; dương in đậm)

| Nhóm | IS | OOS |
|---|---|---|
| **baseline `(1,1)`** = `a` = `w1` = `s1` | **+0,11** (22 lệnh, `INSUFFICIENT_SAMPLE`) | **+0,08** (30 lệnh) |
| trailing `b`/`c`/`d` | +0,11 / +0,07 / +0,07 | +0,01 / +0,01 / +0,01 |
| trigger `w5` | −0,05 | +0,07 |
| setup `s5` | −0,11 | −0,02 |
| combo `(5,5)` | +0,02 | +0,01 |
| geom `tp10/125/15/20` trên `(1,5)` | −0,04 / −0,05 / −0,05 / −0,04 | −0,02 / +0,01 / +0,07 / **+0,12** |
| qual `q1` vs `q0` | +0,02 vs +0,02 | +0,01 vs +0,01 |

### 84.2 Kết luận

1. **Không đòn bẩy nào thắng baseline dưới engine chuẩn**: nới cửa sổ (trigger/setup) và tổ hợp `(5,5)` đều
   **kém hơn** `(1,1)`; trailing/BE vẫn không đổi kết cục lệnh; bộ lọc chất lượng vẫn vô tác dụng.
2. **Baseline `(1,1)` là cấu hình duy nhất dương ở cả hai cửa sổ** (+0,11R / +0,08R) — khớp §83.2.
3. **Mẫu quá nhỏ để kết luận edge**: 22 lệnh IS (`INSUFFICIENT_SAMPLE`) và 30 lệnh OOS, PF 1,11–1,19. Với
   `InpScalpTriggerWindowBars=1` (mặc định), ~19 tín hiệu/năm là **thiết kế** ⇒ 1,5 năm in-sample chỉ ~22 lệnh.
   Muốn tăng mẫu phải **kéo dài cửa sổ đo**, không phải nới cổng tín hiệu.
4. `oos_geom_tp20` (+0,12R, PF 1,18) sáng nhất ở OOS nhưng IS là −0,04 ⇒ **không nhất quán**, khớp kết luận
   hình học TP ở §78.
5. Toàn bộ vẫn **`NOT_STRATEGY_RESULT`** (parity OFF). Không đủ để đổi mặc định engine.

### 84.3 Trạng thái

- **Mặc định ship giữ `iSAR`**; `InpPsarEngine` cho phép chọn `BUILTIN` theo run. Preset/validator trở về
  `InpPsarEngine=0`.
- Đòn bẩy đúng **không phải tham số**: bước hợp lý tiếp theo là **mở rộng mẫu** (lịch sử dài hơn) hoặc đổi
  định nghĩa entry — không phải tinh chỉnh tiếp.
- Parity Pine ↔ MT5 vẫn `BLOCKED`; bot `NOT_RUN`; profit `UNPROVEN`.

## 85. Wonderwhales — port check đủ 3 khung + bỏ sentinel (task M, phụ) — 2026-11-07

Mở rộng cross-implementation từ M5 sang **cả ba khung** EA dùng (engine tự cài):

| Khung | Nến so | `sar_dir` / tín hiệu / blocked | `psar` (≤1e-4) |
|---|---:|---:|---:|
| M15 | 43.865 | **100%** | 100% (max 5e-9) |
| M5 | 141.503 | **100%** | 100% (max 5e-9) |
| M1 | 703.411 | **100%** | 100% (max 5e-9) |

**Phát hiện phụ:** nến cũ hơn vùng cache (cache neo đuôi; cửa sổ M1/M15 rất lớn) bị indicator ghi `EMPTY_VALUE`
(DBL_MAX); EA dump in nguyên chuỗi số khổng lồ đó và trình đọc CSV parse thành ~`1.76e+308`. Đã sửa cả hai phía:
`WonderwhalesDumpTesterEA::PriceText` bỏ trống khi `|price|>1e12`; `compare_wonderwhales_bars.py::_to_number`
coi `|v|>1e12` là **thiếu**. Trước khi sửa, sentinel bị đọc thành số và tạo "chênh lệch" giả (max ~1e287,
M15 tụt còn 96,7% hướng) — sau khi sửa là 100%.

Thêm scenario `portref_dump_{m1,m15}_builtin`; test tooling cập nhật (9 test).

### 85.1 Nhãn trung thực

Vẫn là `CROSS_IMPLEMENTATION` (không phải parity với TradingView); parity vẫn `BLOCKED`, bot `NOT_RUN`,
profit `UNPROVEN`.

## 86. Wonderwhales 2-mode — mở rộng mẫu 2018-2026: kết luận ÂM (task N) — 2026-11-07

Để kiểm tra xem "baseline dương ở cả hai cửa sổ" (§83/§84) có phải edge thật không, chạy baseline `(1,1)` với
engine tự cài trên **toàn bộ lịch sử có được**: XAUUSDm M5, **2018-01-01 → 2026-10-01** (8,75 năm; run 4.718 s
≈ 78,6 phút; cần `-TimeoutSec 7200` vì mặc định 1.800 s bị cắt giữa run).

### 86.1 Kết quả

| Cửa sổ | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---:|---:|---:|---:|---:|---:|
| IS 1,5 năm (§84) | 22 | 45,45% | +339,41 | **+0,11** | 1,19 | 0,52% |
| OOS 1,25 năm (§84) | 30 | 43,33% | +259,41 | **+0,08** | 1,11 | 1,14% |
| **2018-2026 (8,75 năm)** | **103** | **39,81%** | **−420,77** | **−0,02** | **0,95** | 1,60% |

### 86.2 Kết luận (mạnh nhất từ trước tới nay)

- **Kết quả dương ở §83/§84 là nhiễu mẫu nhỏ.** Với 103 lệnh, expectancy ≈ 0 và hơi âm (−0,02R), PF 0,95,
  winrate 39,81% — **dưới** ngưỡng hoà vốn 40% của TP 1,5R.
- **Tín hiệu như đang port không có edge chứng minh được.**
- **Bài học phương pháp:** với `InpScalpTriggerWindowBars=1` (mặc định), ~19 tín hiệu/năm là **thiết kế** ⇒ cửa
  sổ 1,5 năm chỉ ~22 lệnh, **quá nhỏ để kết luận**. Mọi so sánh ở §75–§79 và §83–§84 đều nằm trong vùng nhiễu đó.
- Hệ quả: **dừng tinh chỉnh tham số**. Chỉ còn hai hướng: đổi **định nghĩa entry** (tạo loại tín hiệu khác), hoặc
  chấp nhận kết luận âm và dừng.
- Nhãn không đổi: `NOT_STRATEGY_RESULT` (parity OFF), parity `BLOCKED`, bot `NOT_RUN`, profit `UNPROVEN`.

## 87. Wonderwhales 2-mode — mode ATR trên M5: cổng vô hiệu, 0 lệnh (task N) — 2026-11-07

Thử thay đổi định nghĩa entry theo cách rẻ nhất: `InpSignalMode=3` (`WW_MODE_SAR_EMA_ATR`, thêm cổng biến động
ATR — đã có sẵn trong contract đã kiểm chứng), chạy trên **cùng cửa sổ dài** để so với baseline 103 lệnh
(`ww2_meas_scalp_long_a_m3`, 2018-2026, engine tự cài, 4.744 s ≈ 79 phút).

### 87.1 Kết quả

| Cấu hình (2018-2026) | Lệnh | Net (USD) | Exp (R) | PF |
|---|---:|---:|---:|---:|
| mode 2 SAR+EMA (baseline) | 103 | −420,77 | −0,02 | 0,95 |
| **mode 3 SAR+EMA+ATR** (`InpMinAtrPct=0,5`) | **0** | 0,00 | — | — |

### 87.2 Nguyên nhân (đo được)

Cổng là `ATR% ≥ InpMinAtrPct = 0,5`, nhưng ATR% trên **XAUUSDm M5** (141.804 nến, lấy từ dump port-check):

| percentile | 5% | 25% | 50% | 75% | 95% | max |
|---|---:|---:|---:|---:|---:|---:|
| ATR% | 0,032 | 0,051 | **0,069** | 0,098 | 0,169 | 0,550 |

⇒ Ngưỡng `0,5` là mặc định **cấp D1/W1** (giá trị gốc của Pine) và trên M5 chặn **~100%** nến ⇒ mode 3 với mặc
định là **ngõ cụt** trên Scalp. Muốn kiểm định giả thuyết ATR-regime trên M5 phải dùng ngưỡng theo thang M5
(ví dụ `0,12`, ~tứ phân vị trên).

**Bài học parity:** hằng số mặc định của Pine **không** tự động có nghĩa ở mọi khung. EA 2-mode Scalp dùng mode 2
nên không bị ảnh hưởng, nhưng bật mode 3 với mặc định ⇒ bot im lặng vĩnh viễn.

### 87.3 Trạng thái

- Kết luận chính không đổi: tín hiệu như đang port **không có edge chứng minh được** trên 8,75 năm (§86).
- Việc còn lại (chờ quyết định): chạy `mode 3` với `InpMinAtrPct` theo thang M5 (~0,12) trên cửa sổ dài (~79
  phút) để kiểm định thật giả thuyết ATR-regime; hoặc chốt báo cáo và dừng.
- Không đổi preset, không đổi mặc định engine. Parity `BLOCKED`, bot `NOT_RUN`, profit `UNPROVEN`.

## 88. Wonderwhales 2-mode — ATR-regime với ngưỡng M5: vẫn bế tắc vì mẫu (task N) — 2026-11-08

Thí nghiệm entry "rẻ" cuối cùng: giữ `InpSignalMode=3` nhưng đặt `InpMinAtrPct=0,12` (tứ phân vị trên của M5,
tức giữ ~25% nến mạnh nhất) và chạy trên cùng cửa sổ dài (`ww2_meas_scalp_long_a_m3_atr012`, 2018-2026, engine
tự cài, 4.853 s ≈ 81 phút).

| Cấu hình (2018-2026) | Lệnh | Net (USD) | Winrate | Exp (R) |
|---|---:|---:|---:|---:|
| mode 2 SAR+EMA (baseline) | 103 | −420,77 | 39,81% | −0,02 |
| mode 3, `MinAtrPct=0,5` (mặc định) | 0 | 0,00 | — | — |
| **mode 3, `MinAtrPct=0,12`** | **3** | +543,80 | 100% | +1,50 |

**3 lệnh / 8,75 năm ⇒ `INSUFFICIENT_SAMPLE`, không kết luận được gì.** Chuỗi entry (bias M15 + flip M5 + xác nhận
M1) vốn chỉ ~19 tín hiệu/năm; nhân thêm điều kiện ATR ⇒ vài lệnh mỗi thập kỷ. Cả 3 lệnh thắng nhưng n=3 vô nghĩa.

### 88.1 Kết luận

- **Các thí nghiệm entry "rẻ" (dùng mode có sẵn) đã hết.** Giả thuyết ATR-regime không kiểm định được bằng chuỗi
  entry hiện tại ở cỡ mẫu có ý nghĩa.
- Giữ nguyên kết luận chính (§86): tín hiệu như đang port **không có edge chứng minh được** trên 8,75 năm.
- Chỉ còn hai hướng: **thiết kế luật entry mới** (tạo tần suất/loại tín hiệu khác — cần code + test + đo dài),
  hoặc **chấp nhận kết luận âm** và chốt báo cáo.
- Không đổi preset, không đổi mặc định engine. Parity `BLOCKED`, bot `NOT_RUN`, profit `UNPROVEN`.

## 89. Wonderwhales XAU 2-mode — CHỐT báo cáo nghiên cứu Scalp (a→n) — 2026-11-08

Chủ sở hữu chốt: dừng tinh chỉnh, viết bản chốt của báo cáo nghiên cứu. Báo cáo tự chứa:
[`30-research/wonderwhales-scalp-study.md`](30-research/wonderwhales-scalp-study.md) — nay có **"Kết luận chốt (đọc
trước)"** ở đầu và **§13 Kết luận chốt và việc còn lại**.

### 89.1 Kết luận chốt

**Tín hiệu như đang port KHÔNG có edge chứng minh được.** Bằng chứng mạnh nhất: baseline trên 8,75 năm
(XAUUSDm M5, 2018-2026, engine PSAR tự cài) = **103 lệnh, winrate 39,81%, expectancy −0,02R, PF 0,95, maxDD
1,60%** — dưới ngưỡng hoà vốn 40% của TP 1,5R. Kết quả dương ở cửa sổ ngắn (+0,11R / +0,08R) là **nhiễu mẫu nhỏ**.

Đã loại hết đòn bẩy tham số: trailing/BE (không đổi kết cục lệnh), nới cửa sổ trigger/setup và tổ hợp (kém hơn
baseline dưới engine chuẩn), hình học TP (không nhất quán), bộ lọc chất lượng SAR (vô tác dụng), entry bằng mode
ATR (0 lệnh với mặc định; 3 lệnh với ngưỡng M5 ⇒ không kiểm định được).

### 89.2 Điều đã chứng minh / chưa chứng minh

- **Đã:** cơ chế "rất ít lệnh" (hai cổng sự kiện một-nến); EMA của port khớp 100% trên M1/M5/M15; PSAR tự cài
  khớp 100% port độc lập (M1 703.411 · M5 141.503 · M15 43.865 nến); `iSAR` khác PSAR chuẩn ~2,3% hướng (đo từ
  cả hai phía); trailing vô dụng; không đòn bẩy tham số nào thắng baseline; không có edge trên 8,75 năm.
- **Chưa:** parity Pine ↔ MT5 (`BLOCKED`, cần CSV reference thật); bên nào đúng giữa `iSAR` và PSAR chuẩn; không
  có bằng chứng lợi nhuận nào.

### 89.3 Bài học phương pháp

Cỡ mẫu phải thiết kế trước (≥ 8 năm với ~19 tín hiệu/năm); kiểm chứng port trước khi tinh chỉnh (chọn engine đảo
dấu kết luận); trong tester mọi thứ neo theo **thời gian** chứ không theo chỉ số (tester chèn nến cũ vào đầu,
`Bars()` > `rates_total`); sentinel không được vào CSV; hằng số Pine mặc định không có nghĩa ở mọi khung.

### 89.4 Việc còn lại

Parity (export TradingView) → luật entry mới (nếu tiếp tục) → hoặc chấp nhận kết luận âm. Không tinh chỉnh thêm.
Nhãn không đổi: bot `NOT_RUN`, parity `BLOCKED`, profit `UNPROVEN`; preset ship không đổi.

## 90. Dọn các việc treo §70.4 + hai lỗi tooling của runner — 2026-11-08

### 90.1 Vị thế lạc magic 25006001 trên demo — xác minh bằng journal, KHÔNG xoá state

Đọc `MQL5\Files\infinite_runner_demo.csv` (journal của bot IR trên demo, kết thúc 2026.11.03 02:57): dòng cuối
là `ENTRY SELL price=3948.76000 volume=0.01000 sl=3953.81000 tp=3848.81000 ticket=-1507758291` và
`SUMMARY … entries=1|exits=0|halted=ACTIVE`. Tức **vị thế vẫn đang mở** khi bot dừng, và
`infinite_runner_demo_state.csv` đang giữ đúng vị thế đó (`pos_ticket=-1507758291`, `pos_initial_sl=3953.81`).

⇒ **Xoá state file lúc này là SAI**: bot sẽ mất dấu vị thế đang mở. Việc "dọn vị thế lạc" chỉ xác nhận được khi
có terminal/demo (không tự động hoá theo ràng buộc repo). Ghi nhận trung thực: **chưa xong**, kèm bằng chứng vì sao
không nên xoá. (File `infinite_runner_demo_state_v3.csv` thì rỗng/zero ⇒ vô hại, nhưng để nguyên cả hai.)

### 90.2 Chạy lại tester IR — ĐÃ CÓ BẰNG CHỨNG

`run_tester.ps1 -Scenario infinite_runner_demo_exec` (XAUUSDm M5, 2026.01.05→2026.10.01, deposit 10.000):

| Chỉ số | Giá trị |
|---|---|
| Journal | 105.343 dòng (`sim_ir_demo_exec.csv`, 25,8 MB) |
| Entries / exits | 101 / 101 |
| Wins / losses | 81 / 20 (winrate 80,2%) |
| Blocks / sl_updates | 52.462 / 113 |
| Realized | **+1,70** (equity cuối 10.001,70) |
| Halted | `ACTIVE` |

Với **state sạch** (không có state file trong agent Files), tester **không** tái hiện chẩn đoán "vị thế lạc chiếm
slot". Bằng chứng lưu ở `reports/build/tester-reports/infinite_runner_demo_exec/` (gitignored).

### 90.3 Hai lỗi tooling của `run_tester.ps1` (đã sửa, đều ảnh hưởng trực tiếp §70.4)

| Lỗi | Triệu chứng | Sửa |
|---|---|---|
| Đọc report khi MT5 còn đang ghi | Report chỉ có phần settings ⇒ chốt fail-closed báo `loaded no bars` cho một lượt **hợp lệ** (run 101 lệnh bị từ chối) | Chờ tối đa 30×2 s cho tới khi dòng `Bars:` xuất hiện rồi mới kết luận |
| Suy tên report là `tester_<scenario>` | `.ini` cũ đặt `Report=tester_ir_demo_exec` ⇒ runner **không bao giờ** tìm thấy report ⇒ mọi lượt IR bị từ chối và **không archive** — chính là lý do §70.4 mãi `NOT_RUN` | Đọc `Report=` từ `.ini` và dùng tên đó |
| Lọc CSV theo `sim_<scenario>*.csv` | EA tự chọn tên log từ `InpLogFile`; IR ghi `sim_ir_demo_exec.csv` ⇒ journal 25,8 MB **không được archive** | Archive **mọi** `sim_*.csv` mới trong lượt chạy (lọc theo `LastWriteTime > start`) |

Thêm 1 test contract cho tên report từ `.ini` (tổng 3 test cho runner).

### 90.4 Không đổi

- Nhãn lợi nhuận 5 bot demo vẫn `UNPROVEN` (không thể giải quyết bằng tester; chỉ phiên demo thật mới nâng được).
- Không đổi preset, không đổi engine mặc định của bất kỳ bot nào.

## 91. Wonderwhales 2-mode — luật entry mới E-A (bỏ cổng M1): mẫu lớn, vẫn ÂM (task O) — 2026-11-08

Chủ sở hữu chọn E-A: bỏ **cổng xác nhận M1** — đúng nút thắt mà census chỉ ra (cổng này giết 98,88% setup) —
để có **mẫu lớn ngay từ đầu**. Hiện thực: input mới `InpScalpRequireTrigger` (mặc định `true` = chuỗi gốc
không đổi) + tham số tuỳ chọn `require_trigger` trong `Ww2ScalpEvaluate`/`Ww2ScalpEntry`; đường entry chịu được
M1 không đọc được khi cổng tắt. Preset 75 → **76 key**.

### 91.1 Kết quả (cửa sổ dài 2018-2026, engine PSAR tự cài, 3.322 s ≈ 55 phút)

| Cấu hình | Lệnh | Winrate | Net (USD) | Exp (R) | PF | MaxDD |
|---|---:|---:|---:|---:|---:|---:|
| baseline `(1,1)` | 103 | 39,81% | −420,77 | −0,02 | 0,95 | 1,60% |
| **E-A: bỏ cổng M1** | **5.378** | **39,05%** | **−26.872,11** | **−0,04** | **0,93** | **31,67%** |

### 91.2 Kết luận

- **Mẫu đủ lớn (5.378 lệnh) ⇒ kết luận chắc:** E-A làm **mọi chỉ số xấu đi** (exp −0,04R so với −0,02R; PF 0,93
  so với 0,95; winrate 39,05% dưới hoà vốn 40%; DD 31,67%).
- **Cổng M1 không che edge — nó đang lọc nhiễu.** Bỏ nó tăng tần suất nhưng hạ chất lượng.
- Ba lần thử theo hướng entry (mode ATR mặc định, ngưỡng ATR theo M5, bỏ cổng M1) **đều âm/không kiểm định
  được** ⇒ khép lại hướng này: **không tinh chỉnh/thay entry trên tín hiệu hiện tại nữa**.
- Không đổi preset ship (`InpScalpRequireTrigger=true` mặc định). Parity `BLOCKED`, bot `NOT_RUN`, profit
  `UNPROVEN`.

## 92. InfiniteRunner XAU V2 — sửa deadlock loss-streak (U1) — 2026-11-09

Bắt đầu nghiên cứu/nâng cấp `InfiniteRunnerXAUV2DemoEA` (magic 25006001) bằng **chẩn đoán từ dữ liệu** (journal
101 lệnh), thay vì đoán tham số — cùng phương pháp đã dùng cho WW2.

### 92.1 Chẩn đoán (journal `infinite_runner_demo_exec`, 101 lệnh)

- Cả 101 lệnh chỉ nằm trong **3 ngày đầu** (2026.01.05–01.07, chạm trần 50 lệnh/ngày); từ 2026.01.07 lệnh thua
  thứ 3 liên tiếp đặt `streak=3`, và `EntryThrottlesOk` **chặn mọi entry vĩnh viễn** (`blocks=52.462`, trong đó
  51.937 là `loss_streak`) suốt 9 tháng còn lại.
- **Lỗi thật:** `g_streak_losses` **chỉ reset khi có lệnh thắng** (EA ~dòng 1049) và `InpCooldownMinutes=0` ⇒ bot
  chặn entry ⇒ không bao giờ thắng ⇒ **deadlock**. Nhánh `Halt()` dành cho streak không bao giờ chạy.
- Kinh tế 101 lệnh: thắng TB **+$1,26 (0,25R)** vs thua đủ **−$5,00 (1R)** ⇒ expectancy ≈ 0. Winrate 80,2% là
  *sản phẩm của exit* (step trailing cắt thắng ở ~0,25R), **không phải edge**.

### 92.2 Sửa (U1) — hồi phục bằng cooldown

- Input mới `InpLossStreakCooldownMinutes` (mặc định **240**): chạm chuỗi thua → chặn thêm cooldown phút → hết hạn
  **xoá streak và vào lại**; `0` giữ hành vi cũ (khoá vĩnh viễn, escape hatch có chủ ý). EA 59→60 input.
- Module thuần `mt5/Include/InfiniteRunner/IRRisk.mqh` (`IRLossStreakDecide`: ALLOW/BLOCK/RECOVER) + test thuần
  `mt5/Scripts/IRCoreTests.mq5` (loss-streak, step trailing, BE, monotonic, band).
- State lưu `streak_cooldown_until`; panel hiện `STREAK_COOLDOWN`; fingerprint thêm
  `risk.loss_streak_cooldown_minutes`.
- Guardrail: preset không được `InpMaxConsecutiveLosses>0` mà cooldown `<=0` (`sim_configs.py` +
  `validate_demo_execution.py` + pytest). Thêm input vào preset JSON + mọi `.set` (demo_exec, legacy_exec,
  v1_parity, `docs/20-operations/presets/infinite_runner_v2.set`).
- Đã ghi sửa đổi vào ADR 0005 (mục "Sửa đổi 2026-11-09") theo đúng quy tắc "ADR trước, code sau".

### 92.3 Kiểm chứng U1 (fixcheck, đúng cửa sổ gốc 2026.01.05→2026.10.01)

| Cấu hình | Lệnh | Winrate | Net (USD) | Exp (R) | Ghi chú |
|---|---:|---:|---:|---:|---|
| bản cũ | 101 | 80,2% | +1,70 | +0,003 | chết sau 2 ngày |
| **sau fix U1** | **8.364** | **72,2%** | **+763,55** | **+0,018** | đủ 9 tháng, `streak=0`, không halt |

**Cảnh báo quan trọng:** toàn bộ lãi đến từ **39 lệnh (0,47%) chạm "TP an toàn" 20R**; bỏ 39 lệnh này net ≈
**−$3.136** ⇒ edge mong manh, phải đo trên cửa sổ dài mới kết luận. Block sau fix: `max_trades_day` 15.235,
`loss_streak_cooldown` 6.288 (cooldown chạy và hồi phục — hết deadlock).

### 92.4 Gates

- compile `0 errors / 0 warnings` (gồm `IRCoreTests`); pytest **488**; validate-project 15/0;
  validate_demo_execution 14/0; validate_pineport 32/0; check_docs_links 0 broken (439).

### 92.5 Trạng thái

- U1 chỉ **sửa lỗi vận hành**, không đổi chiến lược/entry/exit. Evidence `NOT_RUN`, profit `UNPROVEN`.
- Kế tiếp (chủ dự án chốt "làm đủ cả 3 theo thứ tự"): baseline dài 2018-2026 → U2 exit (để winner chạy) →
  U3 đo edge entry (SL/TP 1R) → mode `IR_DIR_EMA_MTF`.

## 93. InfiniteRunner XAU V2 — đo edge trên cửa sổ dài 2018-2026: entry KHÔNG có edge — 2026-11-09

Tiếp §92: sau khi sửa deadlock (U1), đo nghiêm túc trên cửa sổ dài để trả lời "tín hiệu này có edge không".

### 93.1 Kết quả (XAUUSDm M5, Model=1, deposit 10.000, lot 0.01; khoá daily/DD tắt để chạy trọn cửa sổ)

| # | Cấu hình | Lệnh | Winrate | Net | Exp R | PF | MaxDD |
|---|---|---:|---:|---:|---:|---:|---:|
| shipped (khoá bật) | 2.406 | 71,07% | −793,01 | −0,066 | 0,77 | 8% → **halt 2020.06.23** |
| A | baseline (step trailing ship) | 26.130 | 72,97% | −685,40 | −0,005 | 0,98 | 22,48% |
| B | U2 để winner chạy (fixed trail) | 34.238 | 59,76% | −2.077,69 | −0,012 | 0,97 | 32,21% |
| C | U3 1:1 (SL/TP 5000, không trail) | 26.143 | **48,07%** | −5.796,01 | −0,044 | 0,92 | 58,29% |
| D | U3 1:1,5 (TP 7500) | 18.407 | **38,65%** | −3.839,00 | −0,042 | 0,93 | 38,77% |
| E | `IR_DIR_EMA_MTF` | 31 | 74,19% | −21,18 | −0,137 | 0,49 | 0,23% |
| F | U3 1:1 **sạch** (mọi guard off) | 33.668 | **48,08%** | −7.158,96 | −0,043 | 0,92 | 71,94% |

### 93.2 Kết luận

- **Entry không có edge.** Ở 1:1 hoà vốn cần 50%; đo được **48,07–48,08%** trên ≥33k lệnh (nhất quán khi
  bật/tắt guard streak). Ở 1:1,5 hoà vốn cần 40%; đo được **38,65%**. Tức tín hiệu EMA 21/50 "legacy" **không
  tốt hơn tung đồng xu**, hơi âm đúng bằng spread.
- **Exit không cứu được.** Step trailing giữ winrate 73% nhưng cắt thắng ở ~0,36R (p90=0,70R); cho winner chạy
  tăng avg_win nhưng hạ winrate và **net tệ hơn + DD lớn hơn**; bỏ trail về winrate 48% và lỗ sâu hơn.
- **"Lãi" chỉ là may mắn đuôi:** cửa sổ 2026 dương nhờ 39 lệnh chạm TP 20R; cửa sổ dài cũng chỉ đỡ nhờ 75
  TP-hit, bỏ ra thì −$8.157.
- **Lỗi thứ hai ghi nhận (không sửa):** khoá `InpMaxDrawdownPct=8` là **halt vĩnh viễn** (manual reset) — preset
  ship tự tắt 2020.06.23 sau 2,5 năm. Là hàng rào an toàn có chủ ý, không phải lỗi.
- **Mode MTF vô dụng:** 31 lệnh/8,75 năm (H1+M15+M5 pullback-reclaim quá chặt).

### 93.3 Ghi chú kỹ thuật

- Đơn vị: Exness `XAUUSDm` 3 chữ số ⇒ **1 point = 0.001**; `InpInitialSlPoints=5000` = 5,00 giá = **1R ≈ $5**
  ở lot 0.01; `InpSafetyTpPoints=100000` = **20R**.
- Công cụ mới (đều tracked): `scripts/tester/analyse_ir.py` (streaming — journal tới 190 MB, có `net_without_tp`)
  và `scripts/tester/gen_ir_sets.py` (sinh 10 scenario IR từ JSON nguồn sự thật).

### 93.4 Bằng chứng lên git (chủ dự án chốt)

- **Evidence pack nhỏ** (0,09 MB) đã commit: `docs/30-research/evidence/infinite-runner/` gồm PNG đường vốn +
  JSON metric từng scenario + `summary.csv` + README, dựng lại bằng `scripts/tester/build_ir_evidence.py`.
- Dữ liệu thô (journal CSV tới ~190 MB, HTM) **vẫn gitignore** theo `reports/README.md`; repo không phình.
- Thêm test `python/tests/test_gen_ir_sets.py` (8 check: ma trận 10 scenario, mỗi arm đổi đúng 1 biến,
  invariant EA-valid).

### 93.5 Báo cáo & trạng thái

- Báo cáo chốt: [`30-research/infinite-runner-study.md`](30-research/infinite-runner-study.md).
- **Chỉ ship U1** (sửa lỗi vận hành). Không đổi chiến lược/entry/exit/preset. Evidence `NOT_RUN`, profit
  `UNPROVEN`. Khuyến nghị: **chấp nhận kết luận âm và dừng tinh chỉnh** trên tín hiệu hiện tại (như WW2), hoặc
  thiết kế entry mới nếu chủ dự án muốn tiếp.

## 94. Land bộ tài liệu nâng cấp (ai-upgrade-plan + IR long-run study) — 2026-11-10

Chủ dự án đưa 3 artefact (`docs/00-start/ai-upgrade-plan.md` qua `docs/ai-upgrade-plan.md`,
`docs/30-research/infinite-runner-long-run-study.md` qua `docs/infinite-runner-long-run-study.md`, và
`tm-fx-docs-upgrade.patch`) và yêu cầu **kiểm tra rồi áp**.

### 94.1 Kiểm tra (trước khi áp)

- Patch áp sạch: `git apply --check` OK (7 file, +447/−1).
- Hai file phẳng ở `docs/` **trùng khít nội dung** patch (byte-identical theo từng dòng) — chỉ **đặt sai chỗ**
  (`docs/` thay vì `docs/00-start/` và `docs/30-research/`), nên link tương đối sẽ hỏng nếu để nguyên.
- Mọi path được tham chiếu **tồn tại**: `archive/wip/2026-11-03_InfiniteRunnerXAUV3/`,
  `docs/99-archive/MT5_EA_Lab_V3/EA/…`, `20-operations/evidence.md`, `00-start/roadmap.md`, `ai-integration.md`,
  `ml-baseline.md`, `risk.md`, `testing.md`, `install.md`…
- Số liệu **khớp evidence đã commit**: 48,07% / 48,08% / 38,65%; net −685 / −2.078; n=26.130 / 34.238.
- Khẳng định "hiện trạng" **đúng**: `mt5/Experts` có **17** `.mq5`; `CloseDemoPosition.mq5` gọi `OrderSend`
  trực tiếp (dòng 38, không kiểm demo/tester); `docs/README.md` ghi `checked=397`/`checks=13`/"15 EA";
  `docs/10-bots/README.md` ghi "16 EA / 6 demo".

**Khác biệt ghi nhận (không sửa doc):** hai số "đo 2026-11-09" không khớp máy này — `ruff` **không có** trong
`.venv`/PATH/requirements (nên "165 lỗi" chưa kiểm chứng được), và `.venv` là **Python 3.11.9** (plan ghi 3.12.3).
Coi là đo ở môi trường khác.

### 94.2 Đã làm

- Áp `tm-fx-docs-upgrade.patch`: đưa `docs/00-start/ai-upgrade-plan.md` và
  `docs/30-research/infinite-runner-long-run-study.md` vào đúng chỗ; cập nhật `AGENTS.md`,
  `docs/README.md`, `docs/00-start/README.md`, `docs/10-bots/infinite-runner.md`, `docs/30-research/README.md`.
- Xoá 2 bản phẳng trùng ở `docs/` và file `.patch` (nội dung đã nằm trong repo + git history).

### 94.3 Trạng thái

- Chỉ **tài liệu**; không đổi code/chiến lược/nhãn. Mọi nhãn vẫn `NOT_RUN`/`UNPROVEN`/`NOT_STRATEGY_RESULT`.

## 95. InfiniteRunner — E1: lãi gộp khi cho winner chạy là may mắn/đuôi (bác bỏ edge) — 2026-11-10

Theo kế hoạch T2.1/T3.1 và nghiên cứu long-run §5/§8: phân rã lãi gộp +0,03R/lệnh của hai lần chạy "cho winner
chạy" theo **hướng × năm × đuôi** để biết là trend-persistence thật hay beta/may mắn. Không cần MT5 (chỉ đọc
journal đã archive).

### 95.1 Công cụ
- `scripts/tester/ir_breakdown.py` (tracked, streaming): tách gross theo side × year × tail; `--spread-price`
  (mặc định 0.19) tái tạo lãi trước spread; nhãn `NOT_STRATEGY_RESULT`.
- Test `python/tests/test_ir_breakdown.py` (5 check trên journal tổng hợp).

### 95.2 Kết quả

| Journal | n | gross (R/lệnh) | BUY | SELL | gross bỏ 0,5% tốt nhất |
|---|---:|---:|---:|---:|---:|
| `long_base_nolock` | 26.130 | +0,0328 | +0,0399 | +0,0258 | **−0,0411** (đảo dấu) |
| `long_exit_run` | 34.238 | +0,0259 | +0,0269 | +0,0249 | **+0,0048** (gần 0) |

### 95.3 Kết luận (E1 **bác bỏ**)

- Gross dương ở **cả hai hướng** ⇒ không phải beta chỉ-mua.
- Nhưng **biến mất khi bỏ 0,5% lệnh tốt nhất** ⇒ **may mắn/đuôi**, không phải trend-persistence.
- Và +0,026–0,033R **< spread (~0,038R)** ⇒ net vẫn âm ngay cả khi giữ nguyên.

⇒ Giả thuyết trend (a) không được dữ liệu ủng hộ; (b) cũng không đứng vững (edge không nằm riêng phía BUY).
Không đầu tư tiếp vào biến thể trend (H-B/H-D) trên tín hiệu entry hiện tại.

### 95.4 Ghi nhận

- Cập nhật nghiên cứu long-run §5.1 + §8 (E1 ✅) + §11.
- Evidence pack thêm `e1_*.json` + bảng E1 trong README.
- Chỉ thêm công cụ/evidence; **không** đổi code EA/chiến lược/nhãn.

## 96. Hạ tầng: T2.2 (CI/p* cho analyse_ir) + T1.1 (đồng bộ số EA) + T5.2 (run_gates) — 2026-11-10

Theo kế hoạch [`./00-start/ai-upgrade-plan.md`](00-start/ai-upgrade-plan.md). (Chủ dự án chọn **không** giới hạn
tần suất/số lệnh, nên H-A không làm.)

### 96.1 T2.2 — mở rộng `analyse_ir.py` (công thức khớp nghiên cứu §3–§4)

- Thêm: winrate hoà vốn `p* = L/(W+L)` + khe hở (pp); mô hình spread `gross = net + N·spread_cost`; độ nhạy
  `net_spread_x2 = net − N·spread_cost` (`--spread-price`, mặc định 0.19); **CI bootstrap 95%** cho expectancy
  (USD và R) với seed cố định (`--ci-samples`/`--ci-seed`) ⇒ tái lập.
- Test `python/tests/test_analyse_ir.py` (5 check số học trên journal tổng hợp). Ví dụ thật (`long_base_nolock`):
  expectancy_r −0,0052, **CI95 [−0,0203..+0,0114]** (bao 0 ⇒ không ý nghĩa), p*=73,36%, gap −0,39pp, gross=+4.279,
  net_spread_x2=−5.650.
- Evidence pack regenerate: JSON từng scenario giờ có các field mới (CI, p*, gross, net_spread_x2).

### 96.2 T1.1 — đồng bộ số EA/demo về một quy ước

- Quy ước: **16 EA** (6 demo + 6 sim + 3 signal + 1 inference) + 1 EA dump tester (không tính là bot) ⇒
  `mt5/Experts/` có **17** file `.mq5`; `configs/demo/` có 6 preset.
- Sửa: `README.md`, `docs/README.md` (**thêm dòng `WonderwhalesXAU2ModeEA` còn thiếu**; 15→16 EA; 5→6 demo),
  `docs/10-bots/README.md` (ghi rõ 17 file = 16 EA + helper), `docs/00-start/roadmap.md` (5→6 EA demo).
- Bảng "Trạng thái cổng" trong `docs/README.md`: bỏ số dễ trôi (checked=397, checks=13, pytest 436), trỏ
  `scripts/run_gates.py` + kỳ vọng cấu trúc (15/14/32, broken=0).
- Test `python/tests/test_docs_counts.py` (3 check): đếm thật từ cây, mọi doc catalog dùng đúng số, không còn
  số cũ (`5 EA demo`/`15 EA`).

### 96.3 T5.2 — `scripts/run_gates.py`

- Một lệnh chạy 5 cổng Python, in bảng PASS/FAIL, `exit≠0` nếu có cổng đỏ; compile MQL5 ghi chú là thủ công.
- Test `python/tests/test_run_gates.py` (3 check, dùng lệnh tầm thường nên không cần MT5).

### 96.4 Gates

- `scripts/run_gates.py` → **5/5 PASS**: pytest **512**; validate-project 15/0; validate_demo_execution 14/0;
  validate_pineport 32/0; check_docs_links broken=0 (checked=471).

## 97. InfiniteRunner — bỏ giới hạn tần suất + lọc chi phí (H-C), và ML T4.1/T4.2 — 2026-11-10

### 97.1 Đo: bỏ giới hạn tần suất và lọc spread (2018-2026, khoá daily/DD tắt)

| Cấu hình | Lệnh | Winrate | Net | Exp R (CI95) | net_without_tp | MaxDD |
|---|---:|---:|---:|---|---:|---:|
| `long_base_nolock` (giới hạn cũ) | 26.130 | 72,97% | −685 | −0,005 [−0,020..+0,011] | −8.157 | 22,48% |
| `long_nolimit` (bỏ trần lệnh/ngày + khoảng cách nến) | 30.551 | 72,83% | **+2.192** | +0,014 [−0,002..+0,031] | **−9.370** | 22,41% |
| `long_spread200` (H-C: không vào khi spread > 200) | 14.387 | 73,11% | +219 | +0,003 [−0,018..+0,027] | −4.164 | **17,16%** |

- **Bỏ giới hạn tần suất** chỉ **+17% số lệnh** (một vị thế + cấm vào lại cùng nến M5 vẫn giới hạn); net chuyển
  dương nhẹ nhưng **do 116 lệnh chạm TP 20R** (`net_without_tp` = −9.370) và **âm ở spread×2** ⇒ không edge bền.
- **Lọc chi phí (H-C)** halved số lệnh, **DD 22,5%→17,2%**, net ≈ 0 (CI bao 0) ⇒ *chỉ giảm lỗ/biến động*.
- **KHÔNG đổi preset ship:** đo cho thấy không cải thiện; đổi base còn vô hiệu hoá chính scenario so sánh. (Nếu
  chủ dự án vẫn muốn bỏ trần trong preset ship, đổi `configs/demo/infinite_runner_demo.json` + v2 `.set`.)

### 97.2 ML T4.1/T4.2 (nhãn sau chi phí + đường cơ sở bắt buộc)

- **T4.1** `python/src/mt5_ea_ai_lab/labels/cost_adjusted.py`: nhãn **triple-barrier trừ spread**
  (`stop/target/timeout`), `net_r = (outcome − spread − slippage)/stop`; export qua `labels/__init__`. Test
  `python/tests/test_cost_adjusted_labels.py` (6 check, gồm "một nến chạm cả hai barrier ⇒ tính stop").
- **T4.2** `python/src/mt5_ea_ai_lab/evaluation/ml.py::gate_baselines`: so model với **"luôn vào"** và **"cổng
  ngẫu nhiên cùng số lệnh"** (mean + p5/p95), seed cố định; cờ `has_value` chỉ khi thắng cả hai. Test
  `python/tests/test_gate_baselines.py` (5 check).
- Nhãn/đường cơ sở mới chưa nối vào CLI `scripts/train_ml_baseline.py` (việc nối E2E để sau); hàm đã có test.

### 97.3 Gates

- Chạy cuối batch: xem commit. Đã thêm 2 scenario IR (12 tổng) + 11 test mới (labels/baselines).

### 97.4 Ghi chú

- Study long-run: thêm §5.2 (kết quả) + §8 đánh dấu H-C ✅ và biến thể ngược H-A.
- Evidence pack: thêm `long_nolimit`, `long_spread200` (PNG + JSON).

## 98. InfiniteRunner — H-D: entry theo regime (spec + hiện thực + đo) ⇒ bác bỏ — 2026-11-10

### 98.1 Spec (trước khi code)

`docs/30-research/infinite-runner-regime-entry-spec.md`: `IR_DIR_REGIME` = H1 context (EMA21/50 + slope) + M5
**breakout** đỉnh/đáy `K=InpBreakoutBars` (mặc định 12) nến đã đóng; một vị thế; exit giữ nguyên; tiêu chí bác bỏ
ghi trước.

### 98.2 Hiện thực (mode 3, không sửa mode 0/1)

- `IRTypes.mqh`: `IR_DIR_REGIME = 2`. `IRDirection.mqh`: hàm thuần `IRRegimeDecision(...)`.
- EA: input `InpBreakoutBars` (2..240), nhánh mode 2 trong `ProcessEntryBar` (channel qua `CopyHigh/CopyLow`),
  tạo handle H1 + warmup + fingerprint cho mode 2. Test `IRCoreTests.mq5` (5 vector regime). Compile **0/0**.
- `sim_configs.py`: enum `(0,1,2)` + input mới; preset JSON + `v2.set` + `gen_ir_sets` scenario
  `infinite_runner_long_regime`. EA 60→61 input.

### 98.3 Đo (2018-2026, khoá daily/DD tắt)

| Cấu hình | Lệnh | Winrate | Net | Exp R (CI95) | gross | net spread×2 | MaxDD |
|---|---:|---:|---:|---|---:|---:|---:|
| `long_regime` (H-D) | 3.260 | 71,60% | **−434** | −0,027 [−0,067..+0,020] | +185 | −1.054 | **5,09%** |

Ít lệnh hơn nhiều (3.260 vs 26.130) và **DD rất nhỏ (5,1%)**, nhưng **expectancy vẫn âm** (−0,027R), gross gần 0
và **âm ở spread×2** ⇒ theo tiêu chí bác bỏ trong spec ⇒ **H-D bị bác bỏ: regime entry không tạo edge**.

### 98.4 Trạng thái

- Study long-run: §5.3 (kết quả) + §8 H-D ✅. Evidence pack: thêm `long_regime` (PNG + JSON), 12 scenario.
- Không đổi preset ship (mode mặc định vẫn 0). Gates: xem commit.

## 99. InfiniteRunner — H-B (trend khung lớn + ATR): dương & bền spread×2, NHƯNG là beta — 2026-11-10

Nghiên cứu "cách nào tốt nhất": thay vì thêm biến thể EMA, thử hướng có cơ sở lý thuyết nhất còn rẻ — **trend
khung lớn (H-B)**: entry H1/H4 + SL `ATR×3` + trail `ATR×2` (config-only trên EA hiện có; khoá daily/DD tắt).

### 99.1 Kết quả (2018-2026)

| Cấu hình | Lệnh | Winrate | Net | Exp R (CI95) | net spread×2 | tp_hits | MaxDD |
|---|---:|---:|---:|---|---:|---:|---:|
| `long_htf_h1` | 1.828 | 49,56% | +1.381 | +0,018 [−0,054..+0,050] | **+1.034** | 0 | 11,8% |
| `long_htf_h4` | 538 | 53,53% | +1.351 | +0,024 [−0,059..+0,123] | **+1.249** | 0 | 12,8% |

Đây là **ứng viên duy nhất tới nay dương, không do đuôi** (`net_without_tp`=net, `tp_hits`=0) **và vẫn dương ở
spread×2**. Nhưng **E1 bác bỏ**: lãi **chỉ ở BUY** (h1 +0,071R vs SELL −0,011R; h4 +0,113 vs −0,029) và **tập
trung theo năm** (h1 âm 2018–2022, dương 2023–2026; h4 dồn vào 2026) ⇒ **beta của uptrend vàng**, không phải edge.

### 99.2 Kết luận "cách tốt nhất" (đã ghi vào study §13)

- **Kiểm tra** một ứng viên phải qua **ba** cổng: spread×2, `net_without_tp`, E1 hướng×năm — không chỉ net dương.
- **Nâng cấp:** **dừng tinh chỉnh tín hiệu hiện tại** (7 hướng, 0 edge). Nếu tiếp: **đổi dữ liệu/ý tưởng** (đa tài
  sản để tăng mẫu độc lập; hoặc H-F đảo chiều sau ngày bất thường — cần spec+code; cổng ML chỉ khi có gross edge,
  hiện chưa). Mọi ứng viên mới qua G1–G4 trước khi nâng nhãn.
- Giữ **U1** (sửa deadlock) làm lợi ích vận hành thực.

### 99.3 Trạng thái
- Study: §5.4 (kết quả) + §8 H-B ✅ + §13 (khuyến nghị). Evidence pack: thêm `htf_h1`/`htf_h4` (14 scenario).
- Không đổi preset ship. Gates: xem commit.
