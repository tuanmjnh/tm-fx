# Bằng chứng — InfiniteRunner

Repo chỉ còn bot demo `InfiniteRunnerXAUV2DemoEA` (magic `25006001`). **Không nâng nhãn** khi chưa có bằng chứng
mới trong [`../PROGRESS.md`](../PROGRESS.md).

## Nhãn hiện tại

| Bot | Nhãn | Ghi chú |
|---|---|---|
| `InfiniteRunnerXAUV2DemoEA` | `NOT_RUN` | chưa có **phiên demo thật** được ghi nhận; lợi nhuận `UNPROVEN` |

## Bằng chứng đã có (tester/đo lường — `NOT_STRATEGY_RESULT`)

- **U1** (sửa deadlock loss-streak): `PROGRESS` §92–§93.
- **Đo edge trên cửa sổ dài 2018–2026** (legacy/MTF/regime/H-B, exit/tần suất/chi phí): `PROGRESS` §93–§99 và
  [`../30-research/infinite-runner-study.md`](../30-research/infinite-runner-study.md),
  [`../30-research/infinite-runner-long-run-study.md`](../30-research/infinite-runner-long-run-study.md).
- **Evidence pack nhỏ đã commit:** [`../30-research/evidence/infinite-runner/`](../30-research/evidence/infinite-runner/README.md)
  (PNG đường vốn + JSON metric từng scenario + `summary.csv`). Dữ liệu thô (journal CSV/HTM) nằm ở
  `reports/build/tester-reports/` và **bị gitignore**.

## Trạng thái tổng

Mọi hướng entry/exit đã đo **không tạo edge bền** (phần dương là đuôi hoặc beta). Đây là **forward test vận hành**,
không phải chiến lược có lãi. Nhãn vẫn `NOT_RUN`; chỉ nâng khi có phiên demo thật ≥ ngưỡng mẫu.
