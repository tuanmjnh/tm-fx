# Bằng chứng

Mỗi tuyên bố trong bộ docs này phải trỏ được về một bằng chứng cụ thể. Tài liệu này là bảng tra:
đường dẫn → chứng minh điều gì → ngày → giới hạn.

Nhãn dùng chung:

| Nhãn | Nghĩa |
|---|---|
| `CONFIRMED` | đọc được trong source/config hiện tại, hoặc có log/CSV thật |
| `PARTIAL` | có bằng chứng nhưng chưa đủ phạm vi để kết luận đầy đủ |
| `NOT_RUN` | chưa chạy, không có bằng chứng |
| `BLOCKED_PENDING_ADR` | bị chặn bởi quyết định, cần ADR mới |
| `ALLOWED` | được phép bởi quyết định hiện hành (ADR 0004); bằng chứng chạy thật có thể vẫn `NOT_RUN` |
| `UNPROVEN` | đã chạy nhưng chưa chứng minh được kết luận mong muốn |

## 1. Bảng tra bằng chứng

| Đường dẫn | Chứng minh | Ngày | Giới hạn |
|---|---|---|---|
| `mt5/Include/TrendRider/*.mqh` | toàn bộ luật PA: swing, BOS, CHoCH, bias, signal, risk, trailing | hiện tại | đọc code, không phải kết quả chạy |
| `mt5/Experts/PATrendRiderXAUv1SimEA.mq5` | đường mô phỏng, vị thế ảo, CSV | hiện tại | không gửi lệnh |
| `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` | EA demo duy nhất được gửi lệnh | hiện tại | chỉ demo/tester |
| `mt5/Include/Exec/ExecGuard.mqh` | cổng môi trường, symbol, TP, stop, volume, risk | hiện tại | logic thuần |
| `mt5/Include/Exec/ExecBroker.mqh` | wrapper gửi/sửa/đóng lệnh | hiện tại | file duy nhất gọi API lệnh |
| `mt5/Scripts/TrendRiderContractTests.mq5` | 82 vector hợp đồng | lần chạy gần nhất | môi trường contract, không phải thị trường |
| `mt5/Scripts/ExecGuardTests.mq5` | 51 test guard | lần chạy gần nhất | không gửi lệnh |
| `docs/decisions/0003-demo-execution-scope.md` | phạm vi được phép | 2026-10-29 | quyết định, không phải bằng chứng chạy |
| `docs/guides/demo-execution.md` | quy trình vận hành demo | hiện tại | hướng dẫn |
| `configs/demo/*.json` | preset `DEMO_ONLY`, `allow_live_trading: false` | hiện tại | cấu hình |
| `configs/sim/grid_lab.json` | preset Grid | hiện tại | cấu hình |
| `reports/build/tester-reports/grid_*/` | CSV/HTML Grid | 2026-10-28 | tester, không phải live |
| `reports/build/tester-reports/dca_*/` | CSV/HTML DCA | 2026-10-28 | tester, không phải live |
| `reports/build/tester-reports/dca_baseline/` | run lại 2026-10-29: SUMMARY `adds=2\|basket_adds=0`, 2 dòng `DCA_ADD` | 2026-10-29 | tester; số net/DD trùng run cũ |
| `reports/build/tester-reports/demo_exec_gui_20261029/` | 31 ENTRY/31 EXIT demo trong tester | 2026-10-29 | tester |
| `reports/build/tester-reports/pa_trendrider_demo_exec/` | 28 ENTRY/28 EXIT; state file một tiền tố `state=` | 2026-10-29 | tester 9 tháng, không phải live |
| `reports/build/tester-reports/plan_baseline/` | `plan_baseline` đủ 9 tháng: `entries=0`, `config_hash=A529A48A`, wall 389.9 s | 2026-10-29 | tester; 0 trade do quirk `rr1<rrMin` |
| `reports/build/tester-reports/plan_edge_tp3_stop_only/` | `plan_edge_tp3_stop_only` đủ 9 tháng: `entries=0`, `config_hash=7DA9E7C9`, wall 409.8 s | 2026-10-29 | tester; 0 trade do quirk `rr1<rrMin` |
| `reports/build/tester-reports/plan_rr2/` | `plan_rr2` (`rr1=2.0`): 93/93 ENTRY–EXIT cặp đúng, `net=-333.11`, `max_dd=5.0210`, `halted=HALTED`, `config_hash=D6CEF886` | 2026-10-29 | tester; đơn vị mô hình; 93 BUY / 0 SELL (Q11) |
| `reports/build/tester-reports/contract_PriceActionMTF/` | `ALL_PASS\|pass=125 fail=0\|contract=1.0.0` trên binary cuối | 2026-10-29 | contract test, không phải thị trường |
| `python/src/mt5_ea_ai_lab/evaluation/plan_audit.py` + `scripts/audit_plan_csv.py` | auditor tự động journal 18 cột; `plan_rr2`, `plan_baseline`, `plan_edge_tp3_stop_only` đều `status=ok issues=0` | 2026-10-30 | kiểm tính hợp lệ CSV, không chứng minh lợi nhuận |
| `reports/build/tester-reports/q8_block_count/` | đếm `PA_BUF_BLOCK` theo `PA_BUF_DIR`: 188/8 414 nến down qua `okScore`, 0 signal down; 9 181/9 181 nến up qua cổng, 302 signal | 2026-10-30 | tester cùng kỳ `plan_rr2`; buffer của port, chưa đối chiếu Pine |
| `mt5/Indicators/PinePort/PriceActionMTF.mq5` (`PA_REPLAY_INCREMENTAL`, `PA_HTF_WINDOW`) | replay tăng dần + cache HTF, checksum trùng full replay | 2026-10-29 | đọc code + log đo tạm thời |
| `MQL5/Logs` journal demo thật | INIT thật, state thật, kill switch | 2026-10-29 | một phiên ngắn |
| `MQL5/Files/PA_TREND_RIDER_DEMO_*` | state, journal của EA demo | 2026-10-29 | một tài khoản demo |
| `reports/build/github_audit_meta.json` | HEAD SHA + license API của 7 repo | 2026-10-29 | metadata, không đọc source |
| `MQL5/Files/pa_trendrider_demo.csv` (phiên 18:23) | 172 dòng, 0 ENTRY, 103 RISK block | 2026-10-29 19:10 | read-only, chưa có ENTRY chiến lược |
| `reports/build/DCALabEA_fix.log`, `PATrendRiderXAUv1DemoEA_fix.log` | compile 0/0 sau sửa P3 | 2026-10-29 | compile, không chứng minh runtime |
| `docs/PROGRESS.md` §40–§47 | lịch sử bằng chứng chi tiết | 2026-10-28..29 | tài liệu lịch sử |

## 2. Bằng chứng theo tuyên bố

### 2.1 "EA demo chỉ chạy trên tài khoản demo"

- Code: `ExecGuard.mqh` → `ExecContextAllowed` chỉ chấp nhận `ACCOUNT_TRADE_MODE_DEMO` hoặc tester.
- Test: `ExecGuardTests.mq5` phủ nhánh từ chối.
- Gate: `validate_demo_execution.py` kiểm tra preset `allow_live_trading: false`.
- Nhãn: `CONFIRMED`.

### 2.2 "Chỉ ba file được gọi API lệnh"

- Gate: `validate-project.py` quét toàn repo, chỉ miễn trừ `ExecBroker.mqh`, `ExecGuard.mqh`,
  `PATrendRiderXAUv1DemoEA.mq5`.
- Nhãn: `CONFIRMED` khi gate pass.

### 2.3 "Hạ tầng đặt lệnh demo hoạt động thật"

- Probe 2026-10-29: mở và đóng 0.01 XAUUSDm trong 103 ms, pnl −0.24, ticket/deal thật.
- Nhãn: `CONFIRMED` cho hạ tầng; **không** dùng để kết luận chiến lược.

### 2.4 "Chiến lược PA_TrendRider có tín hiệu và quản lý vị thế đúng luật"

- Contract test 82/82 PASS.
- DemoEA tester: 31 lệnh, audit `PROBLEMS=0`.
- DemoEA tester 2026-10-29 (`pa_trendrider_demo_exec`, 9 tháng M5): 28 ENTRY/28 EXIT, 33 `TRAIL`,
  `state=WAITING_FOR_SETUP`, `transitions=92`; state file tester đúng một tiền tố `state=`.
- Nhãn: `CONFIRMED` cho luật; `UNPROVEN` cho lợi nhuận.

### 2.5 "Lợi nhuận"

- Không có bằng chứng đủ mạnh. SimEA lỗ trong cả ba cấu hình tester; demo tester dương nhẹ +53.72
  trên 31 lệnh, mẫu quá nhỏ.
- Nhãn: `UNPROVEN`.

### 2.6 "Grid/DCA chạy được trên demo"

- ADR 0003 mục 3 cấm martingale/grid/DCA trong scope demo đầu tiên.
- Chưa có EA demo cho hai chiến lược này.
- Nhãn: `ALLOWED` (ADR 0004); phiên demo thật `NOT_RUN` (chưa có journal).

### 2.7 "`plan_*` chạy được trong tester và 0 trade là đúng"

- Trước 2026-10-29 hai scenario `plan_*` bị `BLOCKED_PERFORMANCE` vì full replay mỗi nến.
- Sau tối ưu (`PA_REPLAY_INCREMENTAL`, `PaMapHtfIndex` binary search, cache HTF append-only), cả hai
  chạy đủ 9 tháng và có `SUMMARY`; 0 trade vì `rr1=1.0 < rrMin=1.5` (quirk source, decision P9).
- Tương đương số học: checksum 18 buffer trùng giữa full replay và incremental ở 3 mốc
  (1600/1800/2000 lần gọi); contract test `pass=125 fail=0`.
- Nhãn: `CONFIRMED` cho "chạy được + không đổi tín hiệu"; `UNPROVEN` cho lợi nhuận (0 trade).

### 2.8 "`plan_rr2` có trade thật và CSV nhất quán"

- `reports/build/tester-reports/plan_rr2/sim_plan_rr2.csv`: 93 `ENTRY` / 93 `EXIT` cặp đúng,
  0 vị thế mở ở nến cuối, một `config_hash` (`D6CEF886`) cho 287 dòng, 0 SL/TP sai phía,
  `SUMMARY` `entries=93|trades=93|wins=26|losses=67|net=-333.11|max_dd=5.0210|halted=HALTED`.
- `tester_plan_rr2.htm`: `Bars: 17595`, `Ticks: 1053473`, History Quality 100 %, build 6292,
  demo `Exness-MT5Trial17`; khớp kỳ 2026.01.05–2026.10.01 trong `plan_rr2.ini`.
- `plan_rr2.journal.txt`: `PAMTF|INFO|bridge|rr1=2.00|rrMin=1.50` và `hash=E231116A` — xác nhận
  cửa `rr` mở bằng cấu hình bridge, không sửa default Pine.
- Giới hạn: `net=-333.11` là **đơn vị mô hình** (volume 1.0, không commission/slippage/swap/margin),
  không phải lợi nhuận; 93/93 BUY là hệ quả cổng `okScore` (Q11, đã đo bằng buffer ở §2.10) chứ chưa
  phải kết luận về thị trường.
- Nhãn: `CONFIRMED` cho "đường `PLAN_ENTRY → EXIT → SUMMARY` chạy thật + CSV hợp lệ";
  `PARTIAL` cho "phủ cả hai phía" (0 SELL, xem [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §10.5).

### 2.9 "Journal `plan_*` được kiểm tự động, không phải đọc bằng mắt"

- Auditor: `python/src/mt5_ea_ai_lab/evaluation/plan_audit.py` (`audit_plan_csv`), CLI
  `scripts/audit_plan_csv.py`, exit 0 = `ok`, 1 = có issue, 2 = không đọc được file.
- Năm nhóm bất biến: khung journal (INIT đầu / SUMMARY cuối / một `config_hash`), vòng đời vị thế
  (nested entry, orphan exit, sai phía, còn mở ở nến cuối), hình học SL/TP, khớp `SUMMARY` với số
  dòng thật, và thời gian theo grid timeframe + offset server.
- Chạy thật 2026-10-30 trên ba journal đã lưu: `plan_rr2` (287 dòng, `issues=0`), `plan_baseline`
  và `plan_edge_tp3_stop_only` (mỗi file `issues=0`, `entries=0`). Test: `python/tests/test_plan_audit.py`
  (38 case), gate `412 passed`.
- Nhãn: `CONFIRMED` cho "CSV nhất quán"; không thay đổi bất kỳ kết luận nào về lợi nhuận.

### 2.10 "Cổng `okScore` chặn cửa short (Q11) — đo bằng buffer, không phải suy luận"

- Run: `reports/build/tester-reports/q8_block_count/` — expert chẩn đoán `ZZPlanBlockCount`
  (chỉ `CopyBuffer`, không hàm lệnh; báo cáo `Deals: 0`, `Total Net Profit: 0.00`) trên đúng kỳ
  `plan_rr2`: XAUUSDm M15 2026.01.05–2026.10.01, `Bars: 17595`, `Ticks: 1053473`, Quality 100 %.
- Số: `dir == -1` có 8 414 nến thì **188 (2,23 %)** có `score100 > 49`, `score100` tối đa đúng bằng 50,
  `block 6 SCORE` chặn trước tiên 2 961 nến, `signal = 0`; `dir == +1` có 9 181 nến thì **100 %** qua
  cổng, `block 6 = 0`, `signal = 302`; `dir == 0` không xuất hiện lần nào.
- Khớp giải tích §10.5 của [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md):
  miền `dir == -1 ∧ okScore` đúng là dải `rawScore ∈ [-0.01, 0)` (chỉ giá trị 50 survive).
- Log kiểm chứng: `q8_agent_journal.txt` (các dòng `DIAG|DIR|...`) khớp từng chữ với CSV.
- Giới hạn: đo trên buffer của **port MQL5**; chưa đối chiếu nguồn Pine (Track B `BLOCKED`), và không
  có kết luận nào về việc nên hay không đổi ngưỡng — ngưỡng vẫn là default 49, MQL5 không sửa.
- Nhãn: `CONFIRMED` cho "bất đối xứng của gate trên dữ liệu thật"; `BLOCKED` cho parity Pine.

## 3. Cách đọc bằng chứng tester

CSV tester chỉ đúng khi:

1. dòng tổng kết có `state` rõ ràng (`ACTIVE` / `HALTED`);
2. HTML report cùng run khớp số lệnh với journal;
3. `config_hash` trong log khớp preset đã dùng.

Nếu một trong ba điều kiện sai, ghi bằng chứng là `INVALID`, không trích dẫn con số.

## 4. Bằng chứng bị cấm dùng

- Ảnh chụp không có log/CSV đi kèm.
- Con số chép từ tài liệu cũ khi chưa chạy lại.
- Kết quả tester Grid baseline dương, dùng để nói "grid có lãi".
- Bất kỳ tuyên bố nào về tài khoản real — repo không có và không được có.
- Log có chứa login/password/server/token — nếu thấy, phải xoá và báo, không trích dẫn.
