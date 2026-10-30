# MT5 EA Lab v2 — bộ tài liệu hoàn chỉnh

**Phiên bản tài liệu:** 2.0  
**Cập nhật:** 2026-10-29  
**Nền tảng:** Windows 10, MetaTrader 5 Exness build **5.0.0.6292**, MetaEditor 5, MQL5; Python 3.11.9 chỉ dùng cho harness kiểm thử, validator và công cụ đọc log.

Đây là điểm vào của bộ tài liệu v2. Bộ v1 đã được chuyển vào [`../archive/v1/`](../archive/v1/) để backup; pack kế hoạch ban đầu của v2 nằm ở [`../archive/planning-inputs/`](../archive/planning-inputs/).

---

## 1. Bộ tài liệu này giải quyết việc gì

Bộ v2 thay thế pack kế hoạch `docs/MT5_EA_Lab_v2/` — pack đó được viết khi repository **chưa có** source PATrendRider và còn ghi `UNKNOWN` cho chiến lược này. Thực tế repository hiện có:

- đặc tả Price Action đầy đủ,
- engine MQL5 `mt5/Include/TrendRider/*`,
- EA mô phỏng `PATrendRiderXAUv1SimEA`,
- EA demo execution `PATrendRiderXAUv1DemoEA`,
- bằng chứng Strategy Tester, probe broker demo và nhật ký demo thật.

Vì vậy bộ v2 ghi **sự thật có bằng chứng** thay cho `UNKNOWN`, đồng thời giữ nguyên các giới hạn: chưa có kết luận lợi nhuận, Grid/DCA chưa được phép chạy demo, live/real vẫn bị cấm.

## 2. Ba chiến lược trong phạm vi

| Chiến lược | Entry point | Chế độ hiện tại | Tài liệu |
|---|---|---|---|
| **PATrendRider XAU v1** | `PATrendRiderXAUv1SimEA` (mô phỏng) và `PATrendRiderXAUv1DemoEA` (demo execution) | Simulation PASS; demo execution armed, chưa có `ENTRY` do chính EA | [`STRATEGIES/PA_TRENDRIDER_XAU_V1.md`](STRATEGIES/PA_TRENDRIDER_XAU_V1.md) |
| **Grid EA** | `GridLabEA` | `SIMULATION_ONLY` | [`STRATEGIES/GRID_EA.md`](STRATEGIES/GRID_EA.md) |
| **DCA EA** | `DCALabEA` | `SIMULATION_ONLY`; demo execution **bị chặn** bởi ADR 0003 | [`STRATEGIES/DCA_EA.md`](STRATEGIES/DCA_EA.md) |

## 3. Ranh giới an toàn (không thương lượng)

1. **Live/real bị cấm.** Chỉ tài khoản DEMO hoặc Strategy Tester được gửi lệnh. `ExecContextAllowed` từ chối mọi trade mode khác.
2. **Đường gửi lệnh duy nhất:** `mt5/Include/Exec/ExecBroker.mqh`, được gọi từ `PATrendRiderXAUv1DemoEA` và `ExecDemoProbe`. Mọi EA khác bị static gate chặn nếu xuất hiện API giao dịch.
3. **Mặc định dry-run:** `InpEnableExecution=false`. Muốn gửi lệnh phải bật có chủ đích trên demo.
4. **SL/TP bắt buộc, giỏ hữu hạn.** TrendRider một vị thế; Grid/DCA một giỏ bị chặn bởi trần tầng/add và exposure. Không martingale vô hạn (ADR 0004).
5. **Kill switch bằng file** `MQL5/Files/PA_TREND_RIDER_DEMO_STOP.txt`.
6. **Không credential** trong code, config, log, artifact hoặc Git. Không tự động hóa hộp thoại đăng nhập.
7. **Không bịa kết quả.** Mọi con số phải có log/CSV/report thật và đường dẫn kiểm chứng.
8. **DCA/Grid demo execution cần ADR mới.** ADR 0003 điểm 3 cấm DCA trong phạm vi demo đầu tiên; điểm 1 giới hạn order API; điểm 7 yêu cầu ADR mới để mở rộng phạm vi.

Xem chi tiết: [`EXECUTION_AND_SAFETY.md`](EXECUTION_AND_SAFETY.md), [`../decisions/0003-demo-execution-scope.md`](../decisions/0003-demo-execution-scope.md).

## 4. Bản đồ tài liệu v2

```text
docs/v2/
├── README.md                    # file này
├── ROADMAP.md                   # lộ trình Phase 0–10 và trạng thái thật
├── PROMPT_AI_IMPLEMENT.md       # quy tắc cho AI/người tiếp tục triển khai
├── ENVIRONMENT.md               # môi trường đã xác minh, đường dẫn, log
├── INSTALL_AND_TEST.md          # cài đặt, compile, chạy test, chạy demo
├── CONFIGURATION.md             # preset, input, magic, state, fail-closed
├── RISK_MODEL.md                # sizing, lock, SL/TP/trailing, giới hạn
├── EXECUTION_AND_SAFETY.md      # guard chain, ADR 0003, kill switch, probe
├── TEST_REPORT.md               # toàn bộ test đã chạy và số liệu thật
├── EVIDENCE.md                  # chỉ mục bằng chứng gốc
├── GITHUB_AUDIT.md              # audit metadata 7 repo: SHA + license (không copy code)
├── TROUBLESHOOTING.md           # lỗi thường gặp và cách xử lý
├── BACKLOG_AI.md                # AI để backlog, chưa triển khai
├── DECISIONS_REQUIRED.md        # quyết định cần chủ dự án phê duyệt
└── STRATEGIES/
    ├── PA_TRENDRIDER_XAU_V1.md
    ├── GRID_EA.md
    └── DCA_EA.md
```

Tài liệu vận hành chi tiết vẫn nằm ngoài `v2/` vì validator và code đang tham chiếu trực tiếp:

- [`../guides/beginner-first-run.md`](../guides/beginner-first-run.md) — **bắt đầu từ đây nếu bạn chưa dùng
  MT5 bao giờ**: chạy bot đầu tiên và xem bot vận hành.
- [`../guides/install-and-test.md`](../guides/install-and-test.md) — cài đặt và kiểm thử theo Track.
- [`../guides/ea-anatomy-and-ai.md`](../guides/ea-anatomy-and-ai.md) — giải phẫu một file EA, sơ đồ luồng,
  bảng tham số đầy đủ theo bot và cách ghép model AI (ONNX).
- [`../guides/demo-execution.md`](../guides/demo-execution.md) — chạy DemoEA trên tài khoản demo.
- [`../guides/strategy-tester.md`](../guides/strategy-tester.md) — preset và ma trận scenario.
- [`../guides/toolchain.md`](../guides/toolchain.md) — check/build/test/validate/package.
- [`../reference/`](../reference/) — kiến trúc, simulation, risk, testing, release.
- [`../decisions/`](../decisions/) — ADR 0001–0003.
- [`../PROGRESS.md`](../PROGRESS.md) — nhật ký từng mục với bằng chứng gốc.

## 5. Đọc theo mục tiêu

| Bạn muốn… | Đọc |
|---|---|
| Hiểu tổng thể và trạng thái hiện tại | file này + [`ROADMAP.md`](ROADMAP.md) |
| Cài đặt từ đầu | [`INSTALL_AND_TEST.md`](INSTALL_AND_TEST.md) |
| Cấu hình input, preset, magic | [`CONFIGURATION.md`](CONFIGURATION.md) |
| Hiểu rủi ro và cách tính lot | [`RISK_MODEL.md`](RISK_MODEL.md) |
| Kiểm tra ranh giới demo/live | [`EXECUTION_AND_SAFETY.md`](EXECUTION_AND_SAFETY.md) |
| Xem test nào đã chạy thật | [`TEST_REPORT.md`](TEST_REPORT.md), [`EVIDENCE.md`](EVIDENCE.md) |
| Hiểu chiến lược PATrendRider | [`STRATEGIES/PA_TRENDRIDER_XAU_V1.md`](STRATEGIES/PA_TRENDRIDER_XAU_V1.md) |
| Hiểu Grid/DCA | [`STRATEGIES/GRID_EA.md`](STRATEGIES/GRID_EA.md), [`STRATEGIES/DCA_EA.md`](STRATEGIES/DCA_EA.md) |
| Xử lý lỗi | [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) |
| Biết việc gì cần quyết định | [`DECISIONS_REQUIRED.md`](DECISIONS_REQUIRED.md) |
| Xem tài liệu cũ | [`../archive/v1/`](../archive/v1/) |

## 6. Quy ước nhãn bằng chứng

| Nhãn | Nghĩa |
|---|---|
| `CONFIRMED` | Đọc trực tiếp từ source/config và/hoặc có log, CSV, report thật |
| `INFERRED` | Suy ra từ code + tài liệu, chưa có runtime riêng cho điểm đó |
| `UNKNOWN` | Chưa có đủ dữ liệu; không được thay bằng suy đoán |
| `NOT_RUN` | Chưa chạy trong MT5/Strategy Tester |
| `BLOCKED` | Thiếu đầu vào hoặc bị chặn bởi quyết định phạm vi |
| `UNPROVEN` | Chưa có bằng chứng thống kê; không đồng nghĩa thất bại |

Không đổi `NOT_RUN`/`BLOCKED`/`UNKNOWN` thành PASS nếu chưa có log/report thật. Compile 0 errors/0 warnings chỉ chứng minh cú pháp, không chứng minh hành vi.

## 7. Trạng thái tổng hợp ngắn

| Hạng mục | Trạng thái | Bằng chứng |
|---|---|---|
| MQL5 compile toàn bộ source | PASS 0 errors / 0 warnings | `reports/build/tester-run/compile_*.log` |
| TrendRider contract tests | PASS 82/82 | `reports/build/tester-reports/contract_trendrider/` |
| ExecGuard tests | PASS 51/0 (synthetic) | `mt5/Scripts/ExecGuardTests.mq5` |
| Python test suite | 412 passed (2026-10-30) | [`TEST_REPORT.md`](TEST_REPORT.md) |
| Static gates | PASS 14/14 và 8/8 | [`TEST_REPORT.md`](TEST_REPORT.md) |
| PATrendRider SimEA tester | 2 scenario có SUMMARY | `reports/build/tester-reports/pa_trendrider_*` |
| DemoEA order path trong tester | 31 ENTRY / 31 EXIT, audit 0 problems | `reports/build/tester-reports/demo_exec_gui_20261029/` |
| Broker demo chấp nhận lệnh | PASS qua `ExecDemoProbe` | [`../PROGRESS.md`](../PROGRESS.md) §45 |
| DemoEA trên demo thật | armed, 0 `ENTRY` | [`../PROGRESS.md`](../PROGRESS.md) §44–§46, §49–§52 |
| Grid/DCA demo execution | `ALLOWED` (ADR 0004); phiên demo thật `NOT_RUN` | [`../../docs/decisions/0004-all-bots-demo-execution.md`](../decisions/0004-all-bots-demo-execution.md) |
| `plan_*` / `PriceActionMTF` perf | PASS — 18/18 registry scenario có SUMMARY; `plan_baseline`/`plan_edge_tp3_stop_only` 0 trade do quirk `rr1 < rrMin`, `plan_rr2` 93 trade ảo (`net=-333.11`, đơn vị mô hình) | [`../PROGRESS.md`](../PROGRESS.md) §57, §58 |
| Lợi nhuận | `UNPROVEN` | không có kết luận trong bất kỳ tài liệu nào |

## 8. Liên hệ với bộ v1

- `docs/archive/v1/` chứa roadmap, prompt, đặc tả PATrendRider bản tiếng Việt, phase report và các input pack gốc. Nội dung được giữ nguyên để tra cứu lịch sử.
- `docs/archive/planning-inputs/MT5_EA_Lab_v2/` chứa pack kế hoạch ban đầu của v2. Pack này **không còn là nguồn sự thật**; các điểm `UNKNOWN` về PATrendRider đã được thay bằng dữ liệu `CONFIRMED` trong bộ v2.
- Tài liệu vận hành (`PROGRESS.md`, `guides/`, `reference/`, `decisions/`, `indicators/`) vẫn ở vị trí cũ vì validator, script và code đang tham chiếu trực tiếp.
