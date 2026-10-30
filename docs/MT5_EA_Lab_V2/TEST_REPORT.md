# Báo cáo kiểm thử

- **Cập nhật lần cuối:** 2026-10-29
- **Nguyên tắc:** mọi con số dưới đây đến từ lần chạy thật trong repo. Không có số liệu suy đoán.
  Nếu một mục chưa chạy, nó ghi `NOT_RUN`.

## 1. Tóm tắt

| Hạng mục | Kết quả | Ghi chú |
|---|---|---|
| Contract test TrendRider | `82/82 PASS` | golden vector cho swing, BOS, CHoCH, signal, risk, trailing |
| Unit test ExecGuard | `51 PASS, 0 FAIL` | thuần logic, không cần terminal |
| Python test suite | `412 passed` (2026-10-30) | `.venv\Scripts\python.exe -m pytest -q`, 15.02 s |
| Static gate project | PASS `checks=14 fail=0` (2026-10-29) | `validate-project.py` |
| Static gate demo execution | PASS `checks=8 fail=0` (2026-10-29) | `validate_demo_execution.py` |
| Compile MQL5 | `0 errors, 0 warnings` | MetaEditor CLI trả exit 1 dù thành công |
| Tester simulation (Grid/DCA/SimEA) | PASS | CSV thật trong `reports/build/tester-reports/` |
| Tester `plan_*` (PinePlanSimEA) | PASS — 0 trade (đúng thiết kế) | `reports/build/tester-reports/plan_*/` |
| Tester demo execution | PASS | `demo_exec_gui_20261029` |
| Live demo | PARTIAL | 1 lệnh probe thật + INIT thật; chưa có ENTRY chiến lược |
| Kill switch | PASS | 2026-10-29 04:10:16 |

`PARTIAL` ở live demo nghĩa: hạ tầng đặt lệnh demo đã chứng minh chạy thật, nhưng chiến lược chưa
tạo tín hiệu nào trong thời gian quan sát. Đây không phải lỗi, cũng không phải bằng chứng lợi nhuận.

## 2. Contract test TrendRider

Bộ test này kiểm tra engine tín hiệu bằng vector cố định, không cần MT5.

Phạm vi:

- swing fractal: bất đẳng thức ngặt, bar bên phải phải đã đóng, inside bar bị loại;
- BOS: chỉ trên bar đóng, mỗi swing chỉ một lần, dedupe theo thời gian swing;
- CHoCH: ưu tiên hơn BOS trên cùng bar, tự xoá khi chuỗi swing đảo;
- chain HH/HL với ngưỡng `ATR * 0.05`;
- buffer phá mức `max(spread * 2, ATR * 0.1)`;
- signal: bias H1/M15, retest zone, nến xác nhận, tuổi tín hiệu;
- risk: sizing, stop 0.5–4.0 ATR, lock ngày/drawdown/chuỗi thua;
- trailing: break-even 1R, trail 1.5R, ATR 1.2, đơn điệu.

Kết quả gần nhất: `82/82 PASS`. Chạy lại:

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" /compile:"D:\Applications\tm-fx\mt5\Scripts\TrendRiderContractTests.mq5" /log:"D:\Applications\tm-fx\reports\build\TrendRiderContractTests.log"
```

Sau đó chạy script trong terminal và đọc dòng tổng kết ở tab Experts.

## 3. Unit test ExecGuard

`mt5/Scripts/ExecGuardTests.mq5` kiểm tra phần thuần logic của guard: cổng môi trường, symbol,
tradability, TP hợp lệ, stop tôn trọng broker, chuẩn hoá volume, ngân sách rủi ro.

Kết quả gần nhất: `51 PASS, 0 FAIL`.

Điểm quan trọng: test này **không** gửi lệnh. Nó chỉ chứng minh hàm quyết định trả đúng khi đầu vào
đúng/sai. Việc terminal thật chấp nhận lệnh là bằng chứng khác (probe, mục 7).

## 4. Python test suite

Lệnh:

```powershell
cd D:\Applications\tm-fx
.\.venv\Scripts\python.exe -m pytest -q
```

Phạm vi có ý nghĩa với an toàn:

- `python/tests/test_demo_execution.py`: preset demo phải khớp đúng input của DemoEA, magic demo khác
  magic simulation, guide chứa đủ token bắt buộc, không có từ ngữ hứa hẹn lợi nhuận;
- `python/tests/test_validate_project.py`: gate tĩnh phải chặn API lệnh ngoài file được miễn trừ;
- test registry `EA_INPUTS`: chỉ DemoEA có `execution_mode = DEMO_ONLY`; preset project không được
  liệt kê EA demo;
- test parity indicator, config, planner.

Con số lần chạy gần nhất: **412 passed** trong 15.02 s, ngày 2026-10-30. Số này thay đổi khi thêm test;
luôn lấy dòng cuối của lần chạy mới nhất thay vì trích số cũ.

## 5. Static gate

```powershell
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
```

`validate-project.py` kiểm tra: file bắt buộc tồn tại, không có API gửi lệnh ngoài danh sách miễn trừ,
không có credential, preset hợp lệ, tài liệu tham chiếu đúng.

`validate_demo_execution.py` kiểm tra riêng phạm vi demo: chỉ đúng ba file Exec được gọi API lệnh;
DemoEA có đủ guardrail; guide demo có token bắt buộc; preset demo `execution_mode: DEMO_ONLY`,
`allow_live_trading: false`.

Kết quả lần chạy gần nhất (2026-10-29): `validate-project.py` → `checks=14 fail=0`;
`validate_demo_execution.py` → `checks=8 fail=0`. Gate fail thì dừng, không sửa câu chữ để lách.

## 6. Compile

```powershell
& "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  /compile:"D:\Applications\tm-fx\mt5\Experts\PATrendRiderXAUv1DemoEA.mq5" `
  /log:"D:\Applications\tm-fx\reports\build\PATrendRiderXAUv1DemoEA.log"
```

Bằng chứng thành công là dòng cuối log `Result: 0 errors, 0 warnings` **và** file `.ex5` được tạo.
Exit code 1 của MetaEditor không có nghĩa là lỗi.

## 7. Tester và bằng chứng thật

### 7.1 Simulation

| EA | Scenario | Kết quả |
|---|---|---|
| GridLabEA | baseline | 24,052 levels / 17,581 baskets / +1,355.49 / DD 1.1301% / `ACTIVE` |
| GridLabEA | conservative | 22,916 / 17,513 / +422.91 / DD 0.2911% |
| GridLabEA | edge | 11,018 levels / −496.85 / DD 5.0003% / `HALTED` |
| DCALabEA | baseline | 11,012 baskets / −497.06 / DD 5.0023% / `HALTED` |
| DCALabEA | conservative | 6,098 / −200.06 / DD 2.0006% |
| DCALabEA | edge (`no_adds`, `bar_trigger`) | 11,018 / −496.85 / DD 5.0003% |
| PATrendRiderXAUv1SimEA | baseline 5k | 4 entries / 4 losses / −36.72 / DD 0.9312% |
| PATrendRiderXAUv1SimEA | 10k | 13 entries / 2 thắng / 11 thua / −140.46 / DD 1.7519% |
| PATrendRiderXAUv1SimEA | cost stress 5k | −37.28 / DD 0.9410% |

CSV và HTML nằm trong `reports/build/tester-reports/<run>/`. Grid baseline dương trong tester nhưng
không được coi là lợi nhuận kỳ vọng: edge scenario của cùng cấu hình lỗ và bị halt.

### 7.2 Demo execution trong tester

`demo_exec_gui_20261029`: 61,189 dòng journal; 31 ENTRY / 31 EXIT; 11 thắng / 20 thua; net +53.72;
balance 5053.72; DD 0.6530%; 14 BUY / 17 SELL; volume tối đa 0.02; 31 ticket duy nhất; audit
`PROBLEMS=0`; `config_hash=6B439450`.

Phân bố block trong cùng cửa sổ: `bias_unknown` 47.71%, `reversal_watch` 29.56%, `regime_range`
13.21%, `bos_against_bias` 3.86%, ENTRY hợp lệ 2.88%, `volatility_high` 1.52%. Tần suất ~3.1 lệnh/tháng
trên cấu hình đó; khoảng chờ dài nhất quan sát được ~5.5 tuần.

### 7.2b `plan_*` — PinePlanSimEA (2026-10-29)

Trước đây 2 scenario này bị `BLOCKED_PERFORMANCE`: PriceActionMTF full-replay mỗi nến nên 9 tháng
không xong. Sau khi tối ưu (replay tăng dần, binary search HTF, cache HTF append-only — số đo và
checksum tương đương ở [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §7.3),
cả hai chạy đủ kỳ 2026.01.05 → 2026.10.01:

| Scenario | Wall | `config_hash` | SUMMARY |
|---|---:|---|---|
| `plan_baseline` | 389.9 s | `A529A48A` | `entries=0\|rejected=0\|trades=0\|net=0.00\|max_dd=0.0000\|blocks=0\|halted=ACTIVE` |
| `plan_edge_tp3_stop_only` | 409.8 s | `7DA9E7C9` | giống hệt |

CSV chỉ có `INIT` + `SUMMARY` (bar cuối `2026.09.30 23:45`), không có dòng trade. Nguyên nhân là
quirk của source Pine: `rr1=1.0 < rrMin=1.5` → `plan.valid=false` ở mọi nến (decision P9,
[`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §9). Chẩn đoán runtime tạm
thời trên `diag_plan_1m` (1 tháng, 25 715 nến) xác nhận 25 714 nến `plan_valid=0` dù `dir`, `atr`,
`sl`, `score` đều đạt. **Không** sửa công thức để có trade; muốn có trade phải đổi cấu hình
(`rr1 >= rrMin` hoặc `rrMin=0`).

Bằng chứng: `reports/build/tester-reports/plan_baseline/` và `.../plan_edge_tp3_stop_only/`.
Contract test `PriceActionMTF` chạy lại trên binary cuối: `ALL_PASS|pass=125 fail=0|contract=1.0.0`
(`reports/build/tester-reports/contract_PriceActionMTF/`).

### 7.2c `plan_rr2` — đường `PLAN_ENTRY → EXIT` có trade thật (2026-10-29)

Cấu hình bridge `InpPaRr1=2.0`, `InpPaRrMin=1.5` (không sửa default Pine), cùng kỳ 9 tháng,
`config_hash=D6CEF886`, indicator `hash=E231116A`, `Bars=17595`, `Ticks=1053473`, History Quality 100 %.

| Kiểm tra | Kết quả |
|---|---|
| SUMMARY | `entries=93\|rejected=0\|trades=93\|wins=26\|losses=67\|flats=0\|net=-333.11\|max_dd=5.0210\|blocks=99\|halted=HALTED` |
| CSV | 287 dòng: 1 `INIT` + 93 `ENTRY` + 93 `EXIT` + 99 `RISK` + 1 `SUMMARY` |
| Cặp ENTRY/EXIT | 93/93, không vị thế mở ở nến cuối |
| `config_hash` một trị toàn file | PASS |
| SL/TP đúng phía entry | 0 vi phạm |
| Exit lý do | 26 `TARGET_HIT\|mode=TP1` (+1 553.61), 67 `SL_GAP` (−1 886.71) — cộng lại khớp `net` |
| Hướng | 93 BUY / 0 SELL → giải thích ở [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §10.5 (Q11), số đếm buffer trong [`../PROGRESS.md`](../PROGRESS.md) §60 |

Số liệu là **đơn vị mô hình** (volume 1.0, contract size 1, không commission/slippage/swap/margin),
không phải lợi nhuận. RiskGuard HALTED ở 5.02 % drawdown là hành vi đúng thiết kế.
Bằng chứng: `reports/build/tester-reports/plan_rr2/` (CSV + htm + png + journal).

### 7.3 Demo thật

- `ExecDemoProbe` 2026-10-29: BUY 0.01 XAUUSDm, deal 2468899165 @4045.79, SL 4042.79, TP 4048.79;
  đóng deal 2468899168 @4045.55, pnl −0.24; vòng mở→đóng 103 ms. Chứng minh guard + broker path chạy
  thật trên tài khoản demo.
- DemoEA khởi động thật 2026-10-29: `INIT mode=DEMO_EXECUTION|restored=1|equity=4999.76|
  config_hash=6B439450|mql_trade_allowed=1`; state `WAITING_FOR_SETUP/RANGE/bias_unknown`; 0 ENTRY.
- Kill switch 2026-10-29 04:10:16: `KILL kill_switch_file|entries_disabled`, state `ERROR_SAFE_MODE`.
- Phiên đang chạy (kiểm tra read-only 2026-10-29 ~19:10 GMT+7): journal
  `MQL5/Files/pa_trendrider_demo.csv` có 172 dòng, sự kiện cuối tại bar 2026-10-29 12:10 (giờ server);
  phân bố: `RISK` 103, `REGIME` 20, `BOS` 18, `INIT` 15, `SUMMARY` 14, `KILL` 1, `STATE` 1;
  **0 `ENTRY`, 0 `EXIT`**. Lý do block chính: `bias_unknown|regime=RANGE` và `bos_against_bias`.
- State file hiện tại vẫn là `state=state=WAITING_FOR_SETUP;transitions=5` — do binary cũ nạp lúc
  18:23 ghi. Bản `.ex5` đã sửa được copy vào `MQL5/Experts` lúc 19:07 nhưng EA đang chạy **không** tự
  nạp lại; file sẽ đúng định dạng sau lần load kế tiếp. Không gỡ EA của người dùng để ép reload.

## 8. Sửa lỗi báo cáo P3 — 2026-10-29

| Mục | Thay đổi | Bằng chứng | Runtime |
|---|---|---|---|
| DCA `adds=0` | thêm `g_total_adds`; SUMMARY có `adds=` (tổng) và `basket_adds=` | compile `0 errors, 0 warnings`; `test_dca_summary_reports_cumulative_adds` PASS | **PASS** — `adds=2`, `basket_adds=0`, 2 dòng `DCA_ADD` (`add=1` vol 0.15, `add=2` vol 0.225) |
| `state=state=` | `WriteStateFile` ghi thẳng `g_state.Serialize()`; parser file cũ giữ nguyên | compile `0 errors, 0 warnings`; `test_demo_state_file_has_single_state_prefix` PASS | **PASS** — file state tester chỉ có một tiền tố |

Runtime chạy 2026-10-29 sau khi đóng terminal demo (MT5 single-instance, `ShutdownTerminal=1`):

- `dca_baseline`: `XAUUSDm` M15, 2026.01.05 → 2026.10.01, preset `dca_baseline.set` trong
  `MQL5/Profiles/Tester`. SUMMARY: `entries=11012|adds=2|basket_adds=0|closed=11014|baskets=11012|open=0|realized=-497.06|max_dd=5.0023|blocks=6581|halted=HALTED`;
  28 610 dòng, mọi dòng `config_hash=3F1C96B9`. Hai dòng add: 2026.02.25 18:15 (`add=1`, 0.15) và
  18:30 (`add=2`, 0.225). Số liệu còn lại trùng run 2026-10-28 → thay đổi chỉ ở báo cáo.
  Bằng chứng `reports/build/tester-reports/dca_baseline/`.
- `pa_trendrider_demo_exec`: `XAUUSDm` M5, 2026.01.05 → 2026.10.01, `InpEnableExecution=true`.
  State file `pa_trendrider_demo_exec_state.csv`:
  `version=1` / `state=WAITING_FOR_SETUP;transitions=92` — không còn `state=state=`.
  Log 55 489 dòng, `config_hash=6B439450`, 28 `ENTRY` + 28 `EXIT` + 33 `TRAIL`, SUMMARY
  `net=74.77|balance=5074.77|drawdown_pct=0.3123|state=WAITING_FOR_SETUP|transitions=92`.
  Bằng chứng `reports/build/tester-reports/pa_trendrider_demo_exec/`.

Đây là tester (dữ liệu mô phỏng), **không** phải kết quả live; không dùng để suy ra lợi nhuận.

CSV DCA cũ trong `reports/build/tester-reports/dca_*` vẫn ghi `adds=0`; đó là bằng chứng lịch sử,
không sửa lại.

## 9. Những gì **chưa** được kiểm thử

| Mục | Trạng thái | Ý nghĩa |
|---|---|---|
| Lợi nhuận dài hạn của PA_TrendRider | `UNPROVEN` | tester ngắn, mẫu nhỏ, không phải cam kết |
| Walk-forward / out-of-sample | `NOT_RUN` | chưa có protocol tách dữ liệu |
| Grid/DCA trên demo | `ALLOWED`, bằng chứng `NOT_RUN` | ADR 0004 mở scope; `GridDemoEA`/`DCADemoEA` compile 0/0, static gate xanh; chưa có phiên demo thật và chưa chạy tester cho hai EA này |
| Partial fill, requote, spread biến thiên, swap | không mô phỏng | giới hạn mô hình |
| Nhiều symbol cùng lúc | `NOT_RUN` | EA demo chỉ một vị thế, một symbol |
| Khôi phục sau crash giữa lệnh | một phần | state file có, chưa có test crash injection |
| Chạy nhiều instance trên cùng tài khoản | `NOT_RUN` | magic riêng nhưng chưa test tranh chấp |

## 10. Cách tái lập nhanh

```powershell
cd D:\Applications\tm-fx
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe scripts\validate-project.py
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py
```

Ba lệnh trên không chạm terminal, không gửi lệnh. Với bước cần terminal, xem
[INSTALL_AND_TEST.md](INSTALL_AND_TEST.md).
