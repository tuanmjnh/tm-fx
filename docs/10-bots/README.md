# Bots — danh mục

Dự án hiện có **một bot demo**: `InfiniteRunnerXAUV2DemoEA` gửi lệnh thật trên tài khoản demo qua
`mt5/Include/Exec/*`. Thư mục `mt5/Experts/` có đúng **một** file `.mq5`. Trạng thái bằng chứng ghi
theo nhãn dự án (`PASS` / `PARTIAL` / `NOT_RUN` / `UNPROVEN`); định nghĩa nhãn xem `docs/PROGRESS.md`
và `20-operations/evidence.md`.

| EA | kind | magic | preset | trang | trạng thái |
|---|---|---|---|---|---|
| `InfiniteRunnerXAUV2DemoEA.mq5` | demo | 25006001 | `configs/demo/infinite_runner_demo.json` | [infinite-runner.md](infinite-runner.md) | `NOT_RUN` |

Lưu ý minh bạch: các phiên demo/tester của InfiniteRunner đã có lệnh nhưng chưa ghi kết quả trong
`../PROGRESS.md`, nên trạng thái giữ `NOT_RUN`. Nhãn lợi nhuận vẫn `UNPROVEN`.

> Script `mt5/Scripts/ExecDemoProbe.mq5` dùng magic **25002002** — là script kiểm tra đường gửi lệnh
> (không phải EA), không tính vào danh mục bot.

## Đọc tiếp

- Trang bot: [infinite-runner.md](infinite-runner.md).
- Giải phẫu EA chung: [ea-anatomy.md](ea-anatomy.md). Chuẩn input dùng chung:
  [input-convention.md](input-convention.md).
- Cách chạy: [`../20-operations/demo-execution.md`](../20-operations/demo-execution.md),
  [`../20-operations/strategy-tester.md`](../20-operations/strategy-tester.md).
- Vì sao có bot này: [`../90-decisions/`](../90-decisions/) (ADR 0003 → 0006).
