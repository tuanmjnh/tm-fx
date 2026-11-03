# Bots — danh mục 15 EA

Dự án có **15 EA** trong `mt5/Experts/`: 5 EA demo (gửi lệnh thật trên tài khoản demo qua
`mt5/Include/Exec/*`), 6 EA mô phỏng (vị thế ảo, không API lệnh), 3 EA tín hiệu và 1 EA inference ONNX.
Trạng thái bằng chứng ghi theo nhãn dự án (`PASS` / `PARTIAL` / `NOT_RUN` / `UNPROVEN`); định nghĩa nhãn
xem `docs/PROGRESS.md` và (sắp có) `20-operations/evidence.md`.

| EA | kind | magic | preset | trang | trạng thái |
|---|---|---|---|---|---|
| `PATrendRiderXAUv1DemoEA.mq5` | demo | 25002001 | `configs/demo/pa_trendrider_xau_demo.json` | [pa-trendrider.md](pa-trendrider.md) | `PARTIAL` |
| `GridDemoEA.mq5` | demo | 25004001 | `configs/demo/grid_demo.json` | [grid.md](grid.md) | `NOT_RUN` |
| `DCADemoEA.mq5` | demo | 25005001 | `configs/demo/dca_demo.json` | [dca.md](dca.md) | `NOT_RUN` |
| `InfiniteRunnerXAUV2DemoEA.mq5` | demo | 25006001 | `configs/demo/infinite_runner_demo.json` | [infinite-runner.md](infinite-runner.md) | `NOT_RUN` |
| `WonderwhalesDemoEA.mq5` | demo | 25007001 | `configs/demo/wonderwhales_demo.json` | [wonderwhales.md](wonderwhales.md) | `UNPROVEN` |
| `PATrendRiderXAUv1SimEA.mq5` | sim | N/A | `configs/sim/pa_trendrider_xau.json` | — | `NOT_RUN` ¹ |
| `RunnerTrailingLabEA.mq5` | sim | N/A | `configs/sim/runner_trailing.json` | — | `NOT_RUN` ¹ |
| `GridLabEA.mq5` | sim | N/A | `configs/sim/grid_lab.json` | — | `NOT_RUN` ¹ |
| `DCALabEA.mq5` | sim | N/A | `configs/sim/dca_lab.json` | — | `NOT_RUN` ¹ |
| `PinePlanSimEA.mq5` | sim | N/A | `configs/sim/pine_plan_lab.json` | — | `NOT_RUN` ¹ |
| `WonderwhalesSimEA.mq5` | sim | N/A | `configs/sim/wonderwhales_xauusdm.json` | — | `NOT_RUN` ¹ |
| `LabSignalEA.mq5` | signal | N/A | N/A | — | `PASS` (§48.5) |
| `PineSignalLabEA.mq5` | signal | N/A | N/A | — | `NOT_RUN` ¹ |
| `PineMultiSignalLabEA.mq5` | signal | N/A | N/A | — | `NOT_RUN` ¹ |
| `LabOnnxInference.mq5` | inference | N/A | N/A | — | `PARTIAL` (§50) |

Số `(§n)` trỏ tới mục bằng chứng tương ứng trong [`../PROGRESS.md`](../PROGRESS.md).

¹ **Quy tắc nhãn cho 10 EA lab (6 sim + 3 signal + 1 inference):** nhãn phải dựa trên một mục
`PROGRESS.md` **ghi nhãn tương ứng cho chính EA đó**. Có mục ghi nhãn → dùng nhãn đó kèm `(§<số>)`;
không tìm thấy → giữ `NOT_RUN`. Không suy ra `PASS` từ "validator xanh" hay "test suite dùng chung":
`SimCoreTests`/`SimPlanTests` là suite của thư viện, không phải bằng chứng của từng EA. Hai nhãn
`LabSignalEA` = `PASS` (§48.5 — tester PASS, 0 trade đúng thiết kế signal-only) và `LabOnnxInference`
= `PARTIAL` (§50 — tester chạy được, parity Track B vẫn `BLOCKED`) đã kiểm và giữ nguyên.
Lưu ý minh bạch: các EA sim **đã có** scenario chạy thật trong Strategy Tester — `PATrendRiderXAUv1SimEA`
(§42), `WonderwhalesSimEA` (§40), `RunnerTrailingLab`/`GridLab`/`DCALab`/`PinePlanSim` (§41), ghi chú
báo cáo DCA §54, `plan_rr2` §58 — nhưng là chạy unit-model / một symbol, không có kết luận
PASS/FAIL về lợi nhuận, và PROGRESS không ghi nhãn trạng thái cho từng EA (§40/§41 giữ các phần liên
quan ở `NOT_RUN`); thiếu chu kỳ validation hoàn chỉnh nên trạng thái giữ `NOT_RUN`.

> Script `mt5/Scripts/ExecDemoProbe.mq5` dùng magic **25002002** — là script kiểm tra đường gửi lệnh
> (không phải EA), không tính vào 15 dòng trên.

## Đọc tiếp

- Năm trang bot: [pa-trendrider.md](pa-trendrider.md) · [grid.md](grid.md) · [dca.md](dca.md) ·
  [infinite-runner.md](infinite-runner.md) · [wonderwhales.md](wonderwhales.md).
- Giải phẫu EA chung: [ea-anatomy.md](ea-anatomy.md). Chuẩn input dùng chung (phase C):
  `input-convention.md` — đang soạn, xem thiết kế `docs/superpowers/specs/2026-11-03-tm-fx-docs-reorg-design.md` §9.
- Cách chạy: [`../20-operations/demo-execution.md`](../20-operations/demo-execution.md),
  [`../20-operations/strategy-tester.md`](../20-operations/strategy-tester.md).
- Vì sao có từng bot: [`../90-decisions/`](../90-decisions/) (ADR 0003 → 0007).
