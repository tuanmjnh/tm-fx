# Phase progress — MT5 EA Lab & Pine → MT5

- **Ngày:** 2026-10-28
- **Phạm vi:** Phase 0 (audit môi trường + inventory), Phase 1–6 và Phase 8–9 Track B cho Wonderwhales.
  Đã tạo contract, custom indicator, test script, EA signal-only, comparator, script build/package và docs.
  Đã compile cả ba file MQL5 và chạy Python tests. **Chưa chạy** test script MQL5, indicator/EA runtime,
  Strategy Tester hoặc parity thật.
- **Nguồn roadmap:** [`mt5-ea-ai-simulation-pack/ROADMAP_MT5_EA_LAB.md`](mt5-ea-ai-simulation-pack/ROADMAP_MT5_EA_LAB.md)
  và [`pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md`](pine-to-mt5-pack/ROADMAP_PINE_TO_MT5_EA.md).
- **Ranh giới:** SIMULATION_ONLY. Không có `OrderSend`, `CTrade`, `MqlTradeRequest` hoặc API gửi lệnh thật.

## 1. Trạng thái tổng hợp

| Track | Phase | Trạng thái | Bằng chứng chính |
|---|---|---|---|
| A. MT5 EA Lab (Grid/DCA/Runner) | Phase 0 | PASS (có cảnh báo đã ghi) | Env check exit 0; validator exit 0; docs nền có sẵn |
| B. Pine → MT5 | Phase 0 | PASS | Inventory 86 file Pine; không sửa source gốc |
| B. Pine → MT5 | Phase 1 (Wonderwhales) | PASS (spec xong; parity còn BLOCKED) | [`INDICATOR_SPEC_Wonderwhales.md`](INDICATOR_SPEC_Wonderwhales.md); 37+13 input, 4 mode, execution semantics |
| B. Pine → MT5 | Phase 2 (Wonderwhales) | PASS (tĩnh); runtime `PENDING` | [`REPAINT_AUDIT_Wonderwhales.md`](REPAINT_AUDIT_Wonderwhales.md); 10 chính sách MQL5, 8 test thủ công chưa chạy |
| B. Pine → MT5 | Phase 3 (Wonderwhales) | PASS (contract đã chốt) | [`BUFFER_CONTRACT_Wonderwhales.md`](BUFFER_CONTRACT_Wonderwhales.md); 18 buffer, 13 input, 36 test vector |
| B. Pine → MT5 | Phase 4 (Wonderwhales) | PASS (compile); vector `NOT_RUN` | `Wonderwhales.mq5` + `WonderwhalesContract.mqh` + `WonderwhalesContractTests.mq5`; 0 error/0 warning |
| B. Pine → MT5 | Phase 5 (Wonderwhales) | PASS (compile); runtime `NOT_RUN` | `PineSignalLabEA.mq5`; 0 error/0 warning; không có API giao dịch |
| B. Pine → MT5 | Phase 6 (Wonderwhales) | PASS (comparator/tests); parity `BLOCKED` | 23 unit test pass; cần CSV reference thật |
| B. Pine → MT5 | Phase 8 (Wonderwhales) | PASS | `validate_pineport.py` pass=32; build 3 file 0/0; package 22 file |
| B. Pine → MT5 | Phase 9 (Wonderwhales) | PASS (docs) | Compatibility, test plan, install/test; Phase 7 vẫn `BLOCKED` |
| A. Phase 1 | Chưa bắt đầu | BLOCKED theo quy tắc một phase/lượt | Chờ duyệt riêng cho Track A |

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
| `pytest -q` (toàn repo) | 0 | `223 passed in 12.33s` |
| `python scripts/validate_pineport.py` | 0 | `VALIDATION_OK: pass=32 fail=0` |
| `powershell build_pineport.ps1` | 0 | 3 file compile `0 errors, 0 warnings`; log tại `reports/build/` |
| `powershell package_pineport.ps1` | 0 | 22 file; zip `wonderwhales-pineport-v1.0.0-20261028-104134.zip`; SHA256 `67b4a1d3…` |
| Link check 27 file Markdown (local + `file:///`) | 0 | `checked 131 local links in 27 files; missing=0` |
| Chạy `WonderwhalesContractTests.ex5` | **chưa chạy** | Cần MT5 terminal và chart; không tuyên bố 36/36 PASS |
| Strategy Tester / backtest | **chưa chạy** | Không có EA execution; Phase 7 `BLOCKED` |

## 4. Acceptance criteria — Track A (MT5 EA Lab)

| # | Tiêu chí Phase 0 | Trạng thái | Ghi chú |
|---|---|---|---|
| A1 | Có `docs/INSTALL_AND_TEST.md` và `docs/ARCHITECTURE.md` | PASS | Có trong pack, nội dung đầy đủ |
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
| B2 | Inventory Pine có đường dẫn rõ ràng | PASS | [`PINE_INVENTORY.md`](PINE_INVENTORY.md): 86 file |
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

- Tạo [`INDICATOR_SPEC_Wonderwhales.md`](INDICATOR_SPEC_Wonderwhales.md).
- Cập nhật [`PINE_INVENTORY.md`](PINE_INVENTORY.md): target/reference đã chốt, trạng thái 3 file,
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

- Tạo [`REPAINT_AUDIT_Wonderwhales.md`](REPAINT_AUDIT_Wonderwhales.md) (13 mục).
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

- Tạo [`BUFFER_CONTRACT_Wonderwhales.md`](BUFFER_CONTRACT_Wonderwhales.md) (12 mục).
- Cập nhật [`INDICATOR_SPEC_Wonderwhales.md`](INDICATOR_SPEC_Wonderwhales.md): bảng buffer draft thay bằng
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
- [`docs/PINE_PARITY_Wonderwhales.md`](PINE_PARITY_Wonderwhales.md): schema, quy trình, giới hạn.

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
- [`scripts/package_pineport.ps1`](../scripts/package_pineport.ps1): đóng gói allow-list 22 file, manifest
  SHA256, chặn `.ex5`/log/secret.

**Kết quả thật:**

```text
VALIDATION_OK: pass=32 fail=0
BUILD_OK: 3 source(s) compiled with 0 errors and 0 warnings.
PACKAGE_OK: reports/packages/wonderwhales-pineport-v1.0.0-20261028-104134.zip
PACKAGE_FILES: 22
PACKAGE_SHA256: 67b4a1d31202a5da935875fa20bfd05cc5c546c616377bb06e0ae9a8a6573ebd
```

Roadmap gọi comparator là `compare-indicator-exports.py`; repo dùng `compare_pine_exports.py` với cùng
mục đích. Không tạo bản trùng.

**Acceptance — Gate 8:**

| # | Tiêu chí | Trạng thái | Ghi chú |
|---|---|---|---|
| B45 | Build script không tin exit code MetaEditor | PASS | Đọc log |
| B46 | Validator bắt lỗi cấu trúc/API cấm | PASS | 32 check |
| B47 | Package loại artifact/secret | PASS | Allow-list 22 file |
| B48 | Không báo PASS cho bước chưa chạy | PASS | Runtime vẫn `NOT_RUN` |

**Kết luận:** Phase 8 PASS. Script không thay thế test runtime.

## 13. Phase 9 — Docs và trạng thái Phase 7 (Track B)

**Files created:**

- [`docs/PINE_MQL5_COMPATIBILITY.md`](PINE_MQL5_COMPATIBILITY.md): D1–D18, điểm giữ nguyên, dữ liệu,
  điều chưa kiểm chứng.
- [`docs/TEST_PLAN.md`](TEST_PLAN.md): T1–T8, lệnh, trạng thái từng lớp.
- [`docs/PINEPORT_INSTALL_AND_TEST.md`](PINEPORT_INSTALL_AND_TEST.md): copy file, compile, gắn
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
11. **Test vector 36 chưa chạy.** Script đã compile; chưa có log `ALL_PASS`.
12. **Parity thật `BLOCKED`.** Comparator đã test bằng dữ liệu tổng hợp, nhưng chưa có CSV reference từ
    Pine. Không được dùng unit test thay parity.
13. **Strategy Tester chưa chạy.** Không có execution nên không có P&L; mọi kết quả backtest đều
    `NOT_RUN`, không được diễn giải thành hiệu suất.

## 15. Việc được phép làm ở lượt sau

- Track A: Phase 1 — input normalization, `OnInit` validation, logger có schema, `VirtualPortfolio` trong
  bộ nhớ, Python schema validator + test. Không tạo logic Grid/DCA/Runner hoàn chỉnh.
- Track B: chạy `WonderwhalesContractTests` trong MT5, ghi log `ALL_PASS` hoặc lỗi cụ thể; gắn indicator
  và EA lên chart, kiểm tra CSV/dedupe; chạy Strategy Tester thủ công.
- Track B: khi người dùng cung cấp CSV reference từ Pine, chốt symbol/timeframe/input và chạy
  `compare_pine_exports.py`; lưu report thật, không tạo dữ liệu giả.
- Không thêm execution, không kết nối broker, không lưu credential.

EA theo yêu cầu “tạo bot từ logic Pine” hiện là **signal-only**. Không có execution cho đến khi có quyết
định riêng, hợp đồng execution, và kiểm chứng runtime/parity.
