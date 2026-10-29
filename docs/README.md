# Bộ tài liệu MT5 EA & AI Lab

Điểm vào duy nhất cho toàn bộ tài liệu của repository. Mọi tài liệu chi tiết đã được gộp theo nhóm;
không còn file rời rạc ở thư mục `docs/`.

> **Ranh giới:** repository phục vụ nghiên cứu offline, mô phỏng và **demo execution có guardrail**.
> Các EA mô phỏng không có `OrderSend`/`CTrade` và chỉ tạo vị thế ảo; Strategy Tester hiển thị **0 deal**
> là đúng. Đường gửi lệnh duy nhất là `PATrendRiderXAUv1DemoEA` + `mt5/Include/Exec/*`, chỉ chấp nhận
> tài khoản demo/Strategy Tester, mặc định dry-run. Không có tài khoản real/live, không credential, không
> kết nối broker.
> Xem [`decisions/0003-demo-execution-scope.md`](decisions/0003-demo-execution-scope.md).

## 1. Trạng thái tổng hợp (2026-10-28)

| Mảng | Phạm vi | Trạng thái |
|---|---|---|
| Phase 0 | Kiểm kê môi trường, an toàn, Git | DONE |
| Phase 1–2 | `LabSignalEA`, signal engine, indicator Wonderwhales | Compile 0/0; runtime thủ công `NOT_RUN` |
| Phase 3–4 | Data pipeline, validation, backtester Python | DONE |
| Phase 5 | Parity MQL5/Python, multi-source export | `READY_FOR_MANUAL_VALIDATION`; parity `BLOCKED` vì thiếu CSV reference |
| Phase 6–7 | Experiment store, ML baseline | DONE |
| Phase 8 | ONNX export + `LabOnnxInference` | Export/parity Python PASS; runtime MT5 `NOT_RUN` |
| Phase 9 | Pipeline end-to-end | DONE |
| Track B | 6 indicator PinePort + contract headless + EA tín hiệu đa nguồn | Compile 0/0; **contract runtime 6/6 PASS** (547 check) |
| Track C W1–W7, W9, W10 | Simulation core, runner/grid/DCA, plan-driven EA, preset, toolchain | PASS offline (compile + static + Python) |
| Track C — `WonderwhalesSimEA` | EA tín hiệu Wonderwhales trên `XAUUSDm`, 3 chế độ stop | Compile 0/0 (repo + Data Folder); **Strategy Tester PASS 3/3 scenario `ww_*`** (2026-10-28, không deal) |
| Track C — `PATrendRiderXAUv1SimEA` | PA TrendRider XAU v1: H1/M15/M5, BOS/CHoCH, pullback, một vị thế ảo | Compile 0/0; contract **82/82 PASS**; Strategy Tester **2/2 scenario `pa_*`** chạy thật (2026-10-28, không deal); xem [`PA_TrendRider_XAU_V1_Implementation_Vietnamese.md`](PA_TrendRider_XAU_V1_Implementation_Vietnamese.md) |
| Demo execution — `PATrendRiderXAUv1DemoEA` | Cùng engine tín hiệu, gửi lệnh **chỉ trên demo** với guard + kill switch | Compile 0/0; `ExecGuardTests` runtime PASS (`pass=51 fail=0`, synthetic); **đường `OrderSend` đã có bằng chứng runtime trong Strategy Tester** — 31 `ENTRY` khớp lệnh, 34 `TRAIL`, 31 `EXIT`, net +53.72/5 000, audit `PROBLEMS=0` (§44); **kill switch PASS bằng file thật trên demo**; **server demo Exness đã khớp thật một lệnh guard qua `ExecDemoProbe`** (§45: `deal=2468899165` vào 4045.79 có SL/TP, đóng ở 4045.55, `pnl=-0.24` bằng đúng spread, đối soát ba nguồn); EA đang armed trên demo `464140826` (`mode=DEMO_EXECUTION`, `state=WAITING_FOR_SETUP`) nhưng **0 `ENTRY` do chính EA gửi** vì regime `RANGE`; giám sát bằng `scripts/watch_demo_journal.py` — reader chỉ đọc, báo `ENTRY`/`EXIT`/`FAULT` mới kèm exit code cho chu kỳ tự động (§46); xem [`guides/demo-execution.md`](guides/demo-execution.md) |
| Track C W8 | Strategy Tester thủ công | PASS 10/10 scenario runner/grid/DCA; 2 scenario `plan_*` `BLOCKED_PERFORMANCE` |

- **MQL5:** 30 file `.mq5` và 33 file `.mqh` compile bằng `scripts/build-mql5.ps1` với
  `0 errors, 0 warnings` (2026-10-29). Compile chỉ chứng minh cú pháp, không chứng minh hành vi.
- **Python:** test suite chạy bằng `scripts/run-python-tests.ps1`; con số chính xác lấy từ lần chạy
  gần nhất trong [`PROGRESS.md`](PROGRESS.md).
- **Preset:** `scripts/validate_sim_configs.py` kiểm tra 6 preset và 17 scenario fail-closed.
- Không có kết luận hiệu năng, P&L hay “sẵn sàng live” ở bất kỳ tài liệu nào.

## 2. Bản đồ tài liệu

```text
docs/
├── README.md                  # file này — điểm vào duy nhất
├── PROGRESS.md                # nhật ký từng phase/W, bằng chứng và trạng thái thật
├── MASTER_ROADMAP.md          # lộ trình tổng (Phase 0–9, Track B, Track C W1–W12)
├── ROADMAP_MT5_EA_AI_LAB.md   # roadmap nguồn ban đầu
├── PROMPT_AI_IMPLEMENT_ROADMAP.md
├── PA_TrendRider_XAU_V1_Specification_Vietnamese.md   # đặc tả chiến lược
├── PA_TrendRider_XAU_V1_Implementation_Vietnamese.md  # bản triển khai mô phỏng + kết quả test
├── guides/
│   ├── install-and-test.md    # cài Python/MT5, sync source, compile, chạy test/EA
│   ├── demo-execution.md      # chạy PATrendRiderXAUv1DemoEA trên tài khoản demo
│   ├── strategy-tester.md     # preset, ma trận scenario, template report
│   └── toolchain.md           # check/build/test/validate/package
├── indicators/
│   ├── README.md              # inventory Pine + compatibility
│   ├── parity.md              # contract, buffer map, trạng thái parity
│   ├── wonderwhales.md
│   ├── longkaco-vsa.md
│   ├── tm-fusion-zones.md
│   ├── price-action-mtf.md
│   ├── tm-xau-signals-2.md
│   └── tm-indicator-2.md
├── reference/
│   ├── architecture.md        # kiến trúc repo và luồng dữ liệu
│   ├── strategy-signal-spec.md
│   ├── simulation.md          # simulation core, runner, grid, DCA, PinePlanSimEA, preset
│   ├── trailing-stop.md
│   ├── bounded-basket.md
│   ├── testing.md             # test plan, metric, giả định mô phỏng
│   ├── parity.md
│   ├── risk.md                # rủi ro và giới hạn đầy đủ
│   ├── release.md             # checklist release nội bộ
│   ├── data-dictionary.md
│   ├── experiment-store.md
│   ├── ml-baseline.md
│   ├── onnx.md
│   └── pipeline.md
├── decisions/                 # ADR (0001 baseline, 0002 execution boundary, 0003 demo execution, …)
├── phase-reports/             # báo cáo Phase 0–9
├── MT5_AI_Roadmaps/           # input pack gốc, giữ nguyên
├── mt5-ea-ai-simulation-pack/ # input pack gốc, giữ nguyên
└── pine-to-mt5-pack/          # input pack gốc, giữ nguyên
```

## 3. Đọc theo mục tiêu

| Bạn muốn… | Đọc |
|---|---|
| Cài đặt và chạy thử toàn bộ | [`guides/install-and-test.md`](guides/install-and-test.md) |
| Chạy Strategy Tester và ghi report | [`guides/strategy-tester.md`](guides/strategy-tester.md) |
| Hiểu simulation core và các EA mô phỏng | [`reference/simulation.md`](reference/simulation.md) |
| Hiểu và chạy PA TrendRider XAU v1 | [`PA_TrendRider_XAU_V1_Specification_Vietnamese.md`](PA_TrendRider_XAU_V1_Specification_Vietnamese.md), [`PA_TrendRider_XAU_V1_Implementation_Vietnamese.md`](PA_TrendRider_XAU_V1_Implementation_Vietnamese.md) |
| Hiểu trailing stop / bounded DCA-grid (Python) | [`reference/trailing-stop.md`](reference/trailing-stop.md), [`reference/bounded-basket.md`](reference/bounded-basket.md) |
| Hiểu indicator PinePort và buffer contract | [`indicators/README.md`](indicators/README.md), [`indicators/parity.md`](indicators/parity.md) |
| Kiểm tra test, metric và giả định | [`reference/testing.md`](reference/testing.md) |
| Xem rủi ro và giới hạn | [`reference/risk.md`](reference/risk.md) |
| Kiểm tra trước khi release/commit | [`reference/release.md`](reference/release.md) |
| Biết việc gì đã chạy thật, việc gì `NOT_RUN` | [`PROGRESS.md`](PROGRESS.md) |
| Xem lộ trình và quyết định phạm vi | [`MASTER_ROADMAP.md`](MASTER_ROADMAP.md), [`decisions/`](decisions/) |

## 4. Quy ước trạng thái

| Nhãn | Nghĩa |
|---|---|
| `DONE` | Deliverable + acceptance criteria đạt, test/CLI đã chạy thật và có bằng chứng |
| `PASS` | Kiểm tra cụ thể đã chạy và đạt (compile, static scan, Python test) |
| `READY_FOR_MANUAL_VALIDATION` | Code compile, test offline đạt; hành vi runtime chưa được xác minh |
| `NOT_RUN` | Chưa chạy trong MT5/Strategy Tester; không được thay bằng suy luận |
| `BLOCKED` | Thiếu dữ liệu/input bên ngoài; không thay bằng dữ liệu synthetic |
| `FAIL` | Đã chạy và không đạt; phải ghi ID/lỗi thực |

Không đổi `NOT_RUN`/`BLOCKED` thành PASS nếu chưa có log, CSV hoặc report thật. Không dùng kết quả
compile, static scan hay Python test để suy ra hành vi của EA trong terminal.

## 5. Quy ước nội dung

- **Tiếng Việt** là ngôn ngữ chính; thuật ngữ kỹ thuật và token lỗi giữ nguyên tiếng Anh.
- **Token lỗi** (`plan_invalid`, `stop_too_close`, …) là hợp đồng ổn định, không đổi tùy tiện.
- **Preset JSON** là nguồn chuẩn cho input; EA không đọc JSON trực tiếp, người dùng nhập tay.
- **Số liệu** phải ghi rõ nguồn: dữ liệu synthetic hay thật, khoảng thời gian, giả định chi phí.
- **Input packs** trong `MT5_AI_Roadmaps/`, `mt5-ea-ai-simulation-pack/`, `pine-to-mt5-pack/` là
  tài liệu gốc chỉ đọc, không sửa và không trộn với tài liệu vận hành.
