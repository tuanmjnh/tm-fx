# Bộ tài liệu MT5 EA & AI Lab

Lab nghiên cứu EA MQL5 chạy trên MetaTrader 5: **một bot demo** có guardrail
(`InfiniteRunnerXAUV2DemoEA`), pipeline Python (dữ liệu → backtest → ML → ONNX) và quy trình bằng chứng ghi
nhãn trạng thái. File này là **điểm vào duy nhất** — mọi tài liệu còn hiệu lực đều tới được từ đây
trong tối đa 2 lần bấm.

> **Ranh giới:** bot chỉ gửi lệnh trên **tài khoản demo** hoặc Strategy Tester (ADR 0004); tài khoản
> real/live bị cấm và bị `ExecGuard` từ chối. Mọi lệnh đi qua `mt5/Include/Exec/ExecBroker.mqh`.
> Bot demo duy nhất: InfiniteRunner XAU v2. Không credential, không login
> automation. Chi tiết: [`90-decisions/0004-all-bots-demo-execution.md`](90-decisions/0004-all-bots-demo-execution.md).

## Đọc theo thứ tự

| # | Thư mục | Là gì |
|---|---|---|
| 1 | [`00-start/README.md`](00-start/README.md) | Bắt đầu: hướng dẫn lần đầu chạy bot, lộ trình, thuật ngữ. |
| 2 | [`10-bots/README.md`](10-bots/README.md) | Danh mục bot (một EA demo: magic, preset, nhãn), giải phẫu EA, chuẩn input. |
| 3 | [`20-operations/README.md`](20-operations/README.md) | Vận hành: cài đặt, preset, Strategy Tester, xử lý sự cố, bằng chứng. |
| 4 | [`30-research/README.md`](30-research/README.md) | Nghiên cứu: kiến trúc, mô phỏng, rủi ro, parity, ML/ONNX. |
| 5 | [`90-decisions/README.md`](90-decisions/README.md) | ADR: vì sao hệ thống như hiện tại, mỗi quyết định phạm vi một file. |
| 6 | [`99-archive/README.md`](99-archive/README.md) | Lưu trữ V1/V2/V3 bất biến, chỉ đọc — lịch sử và bằng chứng gốc. |

Nhật ký bằng chứng append-only: [`PROGRESS.md`](PROGRESS.md) (giữ nguyên vị trí, không nằm trong luồng đọc).

## Tôi muốn…

| Tôi muốn… | Đọc |
|---|---|
| Chạy bot lần đầu | [`00-start/first-run.md`](00-start/first-run.md) |
| Cấu hình input | [`10-bots/input-convention.md`](10-bots/input-convention.md) |
| Chạy demo | [`20-operations/demo-execution.md`](20-operations/demo-execution.md) |
| Bot không vào lệnh | [`20-operations/troubleshooting.md`](20-operations/troubleshooting.md) |
| Đổi preset | [`20-operations/presets.md`](20-operations/presets.md) |
| Hiểu thuật ngữ | [`00-start/glossary.md`](00-start/glossary.md) |
| Giao việc nâng cấp cho AI agent | [`00-start/ai-upgrade-plan.md`](00-start/ai-upgrade-plan.md) |
| Hiểu vì sao InfiniteRunner chưa có edge và hướng đi dài hạn | [`30-research/infinite-runner-long-run-study.md`](30-research/infinite-runner-long-run-study.md) |

## 1 bot demo

| Bot | Magic | Preset | Trang | Nhãn |
|---|---|---|---|---|
| `InfiniteRunnerXAUV2DemoEA` | 25006001 | `configs/demo/infinite_runner_demo.json` | [`10-bots/infinite-runner.md`](10-bots/infinite-runner.md) | `NOT_RUN` |

Danh mục bot: [`10-bots/README.md`](10-bots/README.md).

## Trạng thái cổng

Một lệnh chạy mọi cổng Python và in bảng PASS/FAIL (compile MQL5 cần MetaEditor nên tách riêng):

```powershell
.venv\Scripts\python.exe scripts\run_gates.py
```

Số chi tiết của từng lần chạy ghi trong [`PROGRESS.md`](PROGRESS.md) và
[`20-operations/evidence.md`](20-operations/evidence.md). Các cổng:

| Cổng | Lệnh | Kỳ vọng |
|---|---|---|
| Test Python | `python -m pytest -q` | 0 failed |
| Cấu trúc / preset | `python scripts\validate-project.py` | `checks=7 fail=0` |
| Guardrail demo | `python scripts\validate_demo_execution.py` | `checks=8 fail=0` |
| Link tài liệu | `python scripts\check_docs_links.py` | `broken=0` |
| Compile MQL5 | `deploy_pineport.ps1 -Apply -Force` | `0 errors / 0 warnings` (cần MetaEditor) |

## Quy ước

- **Ngôn ngữ:** tiếng Việt có dấu; token kỹ thuật, token lỗi và tên input giữ nguyên tiếng Anh.
- **Nhãn trạng thái:** 9 nhãn — 6 nhãn hợp đồng (`DONE`, `PASS`, `PARTIAL`, `NOT_RUN`, `BLOCKED`,
  `UNPROVEN`) + 3 nhãn phụ (`FAIL`, `BLOCKED_PENDING_ADR`, `READY_FOR_MANUAL_VALIDATION`). Định nghĩa
  và quy tắc đặt nhãn: [`00-start/glossary.md`](00-start/glossary.md), nguồn chuẩn
  [`20-operations/evidence.md`](20-operations/evidence.md). Không nâng nhãn khi chưa có bằng chứng thật.
- **[`99-archive/`](99-archive/README.md) read-only:** không sửa file nào, kể cả link chết; ánh xạ
  link cũ → mới ở [`99-archive/LINK_MAP.md`](99-archive/LINK_MAP.md).
- **Số liệu phải ghi nguồn:** dữ liệu synthetic hay thật, khoảng thời gian, giả định chi phí; kết quả
  backtest/mô phỏng không phải bằng chứng lợi nhuận.
