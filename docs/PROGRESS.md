# Phase progress — MT5 EA Lab & Pine → MT5

- **Ngày:** 2026-10-28
- **Phạm vi:** Phase 0 (audit môi trường + inventory), Phase 1–6 và Phase 8–9 Track B cho Wonderwhales;
  Phase 1–4 Track B cho LongKaco VSA, TM Fusion Zones và Price Action MTF (spec, audit, contract, indicator,
  test script). Đã compile cả chín file MQL5 và chạy Python tests. **Chưa chạy** test script MQL5,
  indicator/EA runtime, Strategy Tester hoặc parity thật.
- **Nguồn roadmap:** [`mt5-ea-ai-simulation-pack/ROADMAP_MT5_EA_LAB.md`](mt5-ea-ai-simulation-pack/ROADMAP_MT5_EA_LAB.md)
  và [`pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md`](pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md).
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
| Quét `OrderSend|CTrade|MqlTradeRequest|PositionOpen|WebRequest|Socket|Password` trong 4 file nguồn mới | 1 (không match) | `forbidden-api-scan: no matches` |
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
| `SimCoreTests` trong MT5 | **Thủ công, `NOT_RUN`** | Chưa có dòng `TEST|RESULT|ALL_PASS` thật |
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
| `SimPlanTests` trong MT5 | **PASS runtime** | `TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan` ngày 2026-10-28 18:41 (xem mục 37) |
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
  `BLOCKED` vì thiếu CSV reference.
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
  `plan_*` vẫn `BLOCKED_PERFORMANCE`.
