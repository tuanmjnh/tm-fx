# Roadmap MT5 EA Lab v2 — trạng thái thật

**Phiên bản:** 2.0  
**Ngày:** 2026-10-29  
**Nguồn kế hoạch ban đầu:** [`../archive/planning-inputs/MT5_EA_Lab_v2/ROADMAP_MT5_EA_LAB_V2.md`](../archive/planning-inputs/MT5_EA_Lab_v2/ROADMAP_MT5_EA_LAB_V2.md) (đã archive; không còn là nguồn sự thật)

Tài liệu này giữ nguyên mục tiêu sản phẩm của v2 nhưng thay các giả định "chưa có source PATrendRider" bằng trạng thái đã triển khai và bằng chứng thật.

## 1. Mục tiêu sản phẩm

### Trong phạm vi

- Ba chiến lược tách biệt: `PATrendRiderXAUv1`, `GridEA`, `DCAEA`.
- Build `.mq5` → `.ex5` bằng MetaEditor; script phát hiện môi trường và compile.
- Strategy Tester có cấu hình version hóa, chạy headless, lưu report/CSV.
- Demo forward test chỉ trên tài khoản DEMO, có hard guard runtime.
- Input nhóm rõ ràng: chiến lược, symbol/timeframe, spread, lot/risk, SL/TP/trailing, giới hạn vị thế, thoát rổ, drawdown, logging.
- Nhật ký đối chiếu được: tín hiệu, lý do từ chối, request/fill, sửa SL, đóng vị thế, lỗi.
- Script build/test/validate/package và tài liệu cài đặt/cấu hình/backtest/demo/troubleshooting.
- Audit open-source trước khi tái sử dụng code ngoài.

### Ngoài phạm vi

- Giao dịch tài khoản thật/live. Không có `REAL`, `LIVE` hoặc cờ bỏ qua kiểm tra demo.
- AI/ML tạo tín hiệu hoặc tối ưu tham số trong runtime. AI chỉ nằm ở backlog.
- Cloud signal, Telegram, dashboard web, đa terminal.
- Tuyên bố lợi nhuận, preset "an toàn", hoặc tự động chọn cấu hình tối đa lợi nhuận.
- DCA/Grid demo execution khi chưa có ADR mới.

## 2. Kiến trúc đã triển khai

```text
mt5/
├── Include/
│   ├── Sim/         # simulation core dùng chung, không gọi API giao dịch
│   ├── TrendRider/  # engine Price Action: types/config/swing/structure/
│   │                # trend/pullback/signal/atr/risk/trailing/state/marketdata
│   ├── Exec/        # ExecGuard (pure) + ExecBroker (nơi duy nhất gọi OrderSend)
│   └── ...
├── Experts/
│   ├── PATrendRiderXAUv1SimEA.mq5   # SIMULATION_ONLY
│   ├── PATrendRiderXAUv1DemoEA.mq5  # DEMO_EXECUTION, dry-run mặc định
│   ├── GridLabEA.mq5                # SIMULATION_ONLY
│   ├── DCALabEA.mq5                 # SIMULATION_ONLY
│   └── ...
└── Scripts/
    ├── TrendRiderContractTests.mq5
    ├── ExecGuardTests.mq5
    └── ExecDemoProbe.mq5
```

Nguyên tắc:

- Engine tín hiệu **không** gửi lệnh.
- Execution tách khỏi signal; `ExecBroker` là biên duy nhất.
- Preset JSON là nguồn kiểm tra, EA không đọc JSON trực tiếp.
- Magic number tách biệt: sim `25001001`, demo `25002001`, probe `25002002`.
- State/ledger được persist và khôi phục sau restart.

## 3. Trạng thái từng phase

| Phase | Nội dung | Trạng thái | Bằng chứng / ghi chú |
|---|---|---|---|
| 0 | Inventory, môi trường, Git, source hiện có | **DONE** | [`ENVIRONMENT.md`](ENVIRONMENT.md), [`../PROGRESS.md`](../PROGRESS.md) §2–§3 |
| 1 | GitHub open-source audit | **DONE_METADATA** | 7/7 repo có HEAD SHA + license file; 6 MIT/GPL-3.0, 1 không license → REJECT; không copy code. Source review `NOT_RUN` (chỉ cần nếu đổi sang USE). Xem [`GITHUB_AUDIT.md`](GITHUB_AUDIT.md) |
| 2 | Đặc tả chiến lược | **DONE** cho PATrendRider và hai mô phỏng Grid/DCA | [`STRATEGIES/`](STRATEGIES/), [`../archive/v1/PA_TrendRider_XAU_V1_Specification_Vietnamese.md`](../archive/v1/PA_TrendRider_XAU_V1_Specification_Vietnamese.md) |
| 3 | Shared core, build pipeline, validator | **DONE** | `mt5/Include/Sim/*`, `mt5/Include/Exec/*`, `scripts/build-mql5.ps1`, `scripts/validate-project.py` |
| 4 | PATrendRider adapter/baseline | **DONE** (sim + demo execution) | SimEA và DemoEA compile 0/0; contract 82/82; tester có SUMMARY; demo order path có bằng chứng |
| 5 | GridEA | **DONE ở mức mô phỏng**; demo `NOT_RUN` | `GridLabEA` compile; 3 scenario tester; không có order API |
| 6 | DCAEA | **DONE mô phỏng + demo EA sẵn sàng** (`DCADemoEA`, ADR 0004; phiên demo thật `NOT_RUN`) | `DCALabEA` compile; 4 scenario tester; demo EA `DCADemoEA` theo ADR 0004; chưa có phiên demo thật |
| 7 | Strategy Tester automation | **PARTIAL** | Nhiều scenario chạy headless; chưa có pipeline tổng quát cho mọi EA |
| 8 | Demo forward verification | **PARTIAL** | DemoEA armed, 0 `ENTRY`; probe chứng minh broker demo nhận lệnh; Grid/DCA chưa có demo |
| 9 | Docs và release packaging | **DONE** (bộ v2 này) | `docs/v2/`; `scripts/package-source.ps1`; checklist ở [`../reference/release.md`](../reference/release.md) |
| 10 | AI backlog | **DONE ở mức tài liệu**, không triển khai | [`BACKLOG_AI.md`](BACKLOG_AI.md) |

## 4. Yêu cầu bắt buộc cho từng bot

### 4.1 PATrendRiderXAUv1

- Engine Price Action H1/M15/M5, BOS/CHoCH, pullback + confirmation candle.
- Một vị thế; SL cấu trúc; TP = 3R; break-even 1R; trailing từ 1.5R.
- Risk 0.25%/lệnh; daily loss 1%; drawdown 8%; 3 lỗ liên tiếp → cooldown 30 phút.
- Không thay đổi logic gốc âm thầm. Mọi thay đổi phải có test hồi quy và ghi bằng chứng.
- Không hardcode giả định XAUUSD; đọc digits, point, tick size/value, volume step, stops level từ symbol.

### 4.2 GridEA

- Grid một chiều, fixed hoặc ATR spacing; tối đa 5 level; volume multiplier 1.5 có trần từng level.
- Basket exit và basket stop bắt buộc; exposure cap; daily/drawdown guard.
- Không grid vô hạn, không martingale vô hạn, không mở thêm khi guard khóa.
- Chỉ mô phỏng. Demo execution cần ADR mới và thiết kế guard riêng.

### 4.3 DCAEA

- Phân biệt DCA theo thời gian và averaging-in theo giá.
- Tối đa 3 add; volume multiplier 1.5 có trần; basket stop bắt buộc; add phải qua risk guard.
- `max_dca_adds=0` nghĩa là **không add**, không phải không giới hạn.
- Chỉ mô phỏng. Demo execution **bị chặn** bởi ADR 0003.

## 5. Yêu cầu risk và execution

- Volume tính theo tick value/tick size/stop distance; làm tròn theo `SYMBOL_VOLUME_STEP`; kiểm tra min/max.
- Kiểm tra spread, stops level, session, quote freshness, quyền giao dịch và retcode.
- Idempotency: cùng symbol + magic + bar/signal không gửi trùng sau reconnect/restart.
- Khôi phục state từ file; không giả định RAM còn nguyên.
- Account margin mode phải được nêu rõ; nếu không hỗ trợ thì từ chối chạy.
- Có kill switch, max daily loss, max drawdown, max positions, max spread, max slippage.
- Guard là bộ ngắt, **không** phải cam kết giới hạn thiệt hại trong mọi tình huống gap/slippage/outage.

## 6. Quy trình test

1. **Unit/contract:** signal engine tách khỏi execution; test bar-close, no look-ahead, dữ liệu thiếu, NaN, lot rounding; test Grid/DCA cap; test state restore.
2. **Strategy Tester:** mỗi EA có `.ini`/`.set` version hóa; ghi model, spread, deposit, leverage, giai đoạn, build, hash input; chạy in-sample và stress.
3. **Demo forward:** chỉ DEMO; bắt đầu một bot, một symbol, một timeframe; ghi spread thật, retcode, delay, số lần từ chối; không đặt mục tiêu lợi nhuận.
4. **Gate tĩnh:** `validate-project.py`, `validate_demo_execution.py`, `pytest`.
5. **Không thay** `NOT_RUN`/`BLOCKED` bằng PASS khi chưa có log/report thật.

## 7. Definition of Done

- Source MQL5 compile được hoặc blocker được ghi rõ; không tuyên bố compile khi chưa chạy compiler.
- Có test logic cho các giới hạn risk chính.
- Strategy Tester report và cấu hình được lưu cho mỗi bot đã hoàn thành.
- Demo mode hard-gate; real account bị từ chối.
- Có GitHub audit và bảng license **trước khi** tái sử dụng code ngoài.
- Docs hướng dẫn cài đặt/cấu hình/backtest/demo đầy đủ.
- AI vẫn ở backlog.

## 8. Việc tiếp theo (ưu tiên)

| Ưu tiên | Việc | Điều kiện hoàn thành |
|---|---|---|
| P0 | Chờ `ENTRY` đầu tiên do DemoEA gửi trên demo; giám sát bằng watcher | Có dòng `ENTRY` + `ORDER_FILLED` trong journal thật, đối soát tab History |
| P0 | Quyết định ADR 0004 cho DCA demo (nếu muốn) | ADR được duyệt + thiết kế guard + test + demo evidence |
| P1 | ~~Hoàn tất GitHub audit có commit SHA/license~~ **DONE 2026-10-29** | [`GITHUB_AUDIT.md`](GITHUB_AUDIT.md): 7/7 SHA + license; 0 `USE`; source review chỉ mở lại nếu đổi quyết định |
| P1 | Thiết kế guard riêng nếu mở Grid demo | ADR + ExecGuard mở rộng + test + demo evidence |
| P2 | ~~Tối ưu `PriceActionMTF` để chạy `plan_*` trong tester~~ **DONE 2026-10-29** | Replay tăng dần + binary search `PaMapHtfIndex` + cache HTF append-only; checksum 18 buffer trùng khớp full replay ở 3 mốc. `diag_plan_1m`: 153 313 ms → 31 335 ms (wall ~165 s → ~41 s). `plan_baseline` 389.9 s, `plan_edge_tp3_stop_only` 409.8 s, cả hai đủ 9 tháng với SUMMARY (0 trade do quirk `rr1=1.0 < rrMin=1.5`, P9). Contract `ALL_PASS\|pass=125 fail=0`. Xem [`../PROGRESS.md`](../PROGRESS.md) §57 và [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §7.3 |
| P2 | ~~`plan_*` có trade thật (cấu hình `rr1 > rrMin`, không sửa code)~~ **DONE 2026-10-29** | `plan_rr2` (`InpPaRr1=2.0`, `InpPaRrMin=1.5`): SUMMARY `entries=93\|trades=93\|wins=26\|losses=67\|net=-333.11\|max_dd=5.0210\|halted=HALTED`; CSV 287 dòng kiểm toán PASS (một `config_hash`, 93/93 cặp ENTRY/EXIT, 0 SL/TP sai phía). [`../PROGRESS.md`](../PROGRESS.md) §58, [`../guides/strategy-tester.md`](../guides/strategy-tester.md) §9.3 |
| P2 | Tự động hóa lịch chạy watcher (nếu người dùng muốn) | Quyết định vận hành, không chỉ code |
| P2 | ~~Xác minh cổng `okScore` chặn cửa short (Q11)~~ **DONE (buffer) 2026-10-30** | Đếm `PA_BUF_BLOCK` theo `dir` trên đúng kỳ `plan_rr2` (17 595 nến): down 8 414 nến → 188 qua `okScore` (2,23 %), `score100` tối đa 50, 2 961 nến bị `6 SCORE` chặn trước tiên, **0 signal**; up 9 181 nến → 100 % qua cổng, `6 SCORE = 0`, 302 signal. Khớp dải giải tích `rawScore ∈ [-0.01, 0)`; không đổi ngưỡng, MQL5 không sửa. [`../PROGRESS.md`](../PROGRESS.md) §60, [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §10.5. **Còn mở:** đối chiếu source Pine (Track B `BLOCKED`) |
| P3 | ~~Script audit journal 18 cột của `PinePlanSimEA`~~ **DONE 2026-10-30** | `scripts/audit_plan_csv.py` + `python/src/mt5_ea_ai_lab/evaluation/plan_audit.py` + 38 test; ba journal thật (`plan_rr2`, `plan_baseline`, `plan_edge_tp3_stop_only`) đều `status=ok issues=0`. [`../PROGRESS.md`](../PROGRESS.md) §59, [`../guides/install-and-test.md`](../guides/install-and-test.md) §4.1 Track C PinePlanSimEA |
| P3 | ~~Dọn bug báo cáo `adds=0` của DCA~~ **DONE 2026-10-29** | SUMMARY có `adds` (tổng) + `basket_adds`; compile 0/0; test tĩnh PASS; runtime PASS: `dca_baseline` → `adds=2\|basket_adds=0`, khớp 2 dòng `DCA_ADD` |
| P3 | ~~Dọn bug `state=state=` khi ghi state~~ **DONE 2026-10-29** | File state một tiền tố; parser file cũ giữ nguyên; compile 0/0; test tĩnh PASS; runtime PASS: `pa_trendrider_demo_exec` → `state=WAITING_FOR_SETUP;transitions=92` |

## 9. Liên kết

- Trạng thái và bằng chứng chi tiết: [`../PROGRESS.md`](../PROGRESS.md)
- Bộ v1: [`../archive/v1/`](../archive/v1/)
- Pack kế hoạch ban đầu: [`../archive/planning-inputs/MT5_EA_Lab_v2/`](../archive/planning-inputs/MT5_EA_Lab_v2/)
