# Bộ tài liệu MT5 EA & AI Lab

**Phiên bản:** 2.0 · **Cập nhật:** 2026-10-29
**Điểm vào duy nhất:** file này. Bộ tài liệu mới nằm ở [`v2/`](v2/README.md); tài liệu v1 đã chuyển
vào [`archive/v1/`](archive/v1/) để backup, chỉ đọc.

> **Ranh giới:** repository phục vụ nghiên cứu offline, mô phỏng và **demo execution có guardrail**.
> Các EA mô phỏng không có `OrderSend`/`CTrade` và chỉ tạo vị thế ảo. Đường gửi lệnh duy nhất là
> `PATrendRiderXAUv1DemoEA` + `mt5/Include/Exec/*`, chỉ chấp nhận tài khoản demo hoặc Strategy Tester,
> mặc định dry-run. Tài khoản real/live bị cấm; không credential; không kết nối broker.
> Xem [`decisions/0003-demo-execution-scope.md`](decisions/0003-demo-execution-scope.md).

## 1. Bắt đầu ở đâu

| Bạn muốn… | Đọc |
|---|---|
| **Chưa dùng MT5 bao giờ — chạy bot đầu tiên và xem bot vận hành** | [`guides/beginner-first-run.md`](guides/beginner-first-run.md) |
| **Hiểu từng khối của một con bot + bảng tham số đầy đủ + ghép AI** | [`guides/ea-anatomy-and-ai.md`](guides/ea-anatomy-and-ai.md) |
| Hiểu toàn bộ bộ tài liệu v2 | [`v2/README.md`](v2/README.md) |
| Xem trạng thái và lộ trình thật | [`MASTER_ROADMAP.md`](MASTER_ROADMAP.md), [`v2/ROADMAP.md`](v2/ROADMAP.md) |
| Cài đặt, compile, chạy test | [`v2/INSTALL_AND_TEST.md`](v2/INSTALL_AND_TEST.md) |
| Cấu hình input/preset | [`v2/CONFIGURATION.md`](v2/CONFIGURATION.md) |
| Hiểu rủi ro, sizing, trailing | [`v2/RISK_MODEL.md`](v2/RISK_MODEL.md) |
| Kiểm tra ranh giới demo/live | [`v2/EXECUTION_AND_SAFETY.md`](v2/EXECUTION_AND_SAFETY.md) |
| Xem test nào đã chạy thật | [`v2/TEST_REPORT.md`](v2/TEST_REPORT.md), [`v2/EVIDENCE.md`](v2/EVIDENCE.md) |
| Hiểu PATrendRider XAU v1 | [`v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md`](v2/STRATEGIES/PA_TRENDRIDER_XAU_V1.md) |
| Hiểu Grid / DCA | [`v2/STRATEGIES/GRID_EA.md`](v2/STRATEGIES/GRID_EA.md), [`v2/STRATEGIES/DCA_EA.md`](v2/STRATEGIES/DCA_EA.md) |
| Sửa lỗi thường gặp | [`v2/TROUBLESHOOTING.md`](v2/TROUBLESHOOTING.md) |
| Biết việc gì cần chủ dự án quyết | [`v2/DECISIONS_REQUIRED.md`](v2/DECISIONS_REQUIRED.md) |
| Xem nhật ký bằng chứng chi tiết | [`PROGRESS.md`](PROGRESS.md) |
| Xem tài liệu cũ | [`archive/README.md`](archive/README.md) |

## 2. Cấu trúc

```text
docs/
├── README.md                  # file này
├── MASTER_ROADMAP.md          # lộ trình tổng, trạng thái, việc tiếp theo
├── PROGRESS.md                # nhật ký từng phase với bằng chứng gốc
├── v2/                        # bộ tài liệu hiện hành (xem v2/README.md)
│   ├── README.md, ROADMAP.md, PROMPT_AI_IMPLEMENT.md
│   ├── ENVIRONMENT.md, INSTALL_AND_TEST.md, CONFIGURATION.md
│   ├── RISK_MODEL.md, EXECUTION_AND_SAFETY.md
│   ├── TEST_REPORT.md, EVIDENCE.md, GITHUB_AUDIT.md
│   ├── TROUBLESHOOTING.md, BACKLOG_AI.md, DECISIONS_REQUIRED.md
│   └── STRATEGIES/{PA_TRENDRIDER_XAU_V1,GRID_EA,DCA_EA}.md
├── guides/                    # hướng dẫn vận hành theo Track
│   ├── beginner-first-run.md, ea-anatomy-and-ai.md, install-and-test.md, demo-execution.md
│   ├── strategy-tester.md, toolchain.md
├── indicators/                # PinePort: inventory, parity, từng indicator
├── reference/                 # kiến trúc, simulation, risk, testing, release, ML/ONNX
├── decisions/                 # ADR 0001–0003
└── archive/
    ├── README.md              # chỉ mục tài liệu lưu trữ
    ├── v1/                    # roadmap, prompt, đặc tả, phase report, input pack v1
    └── planning-inputs/       # pack kế hoạch ban đầu của v2
```

## 3. Trạng thái tổng hợp

Số liệu chi tiết và đường dẫn bằng chứng nằm ở [`v2/TEST_REPORT.md`](v2/TEST_REPORT.md) và
[`v2/EVIDENCE.md`](v2/EVIDENCE.md). Tóm tắt:

| Hạng mục | Trạng thái |
|---|---|
| Compile MQL5 toàn bộ source | PASS `0 errors, 0 warnings` (MetaEditor build 6292) |
| Contract test TrendRider | PASS `82/82` |
| Unit test ExecGuard | PASS `51/0` |
| Python test suite | `412 passed` (2026-10-30) |
| Static gate (`validate-project.py`, `validate_demo_execution.py`) | PASS `14/14` và `8/8` (2026-10-29) |
| PATrendRider SimEA — Strategy Tester | PASS, có CSV/HTML |
| DemoEA — đường gửi lệnh trong Strategy Tester | PASS: 31 ENTRY / 31 EXIT, audit `PROBLEMS=0` |
| Broker demo chấp nhận lệnh thật | PASS qua `ExecDemoProbe` (0.01 XAUUSDm, 103 ms) |
| DemoEA trên tài khoản demo | armed, state `WAITING_FOR_SETUP`, 0 ENTRY do chiến lược |
| Grid / DCA demo execution | `ALLOWED` (ADR 0004); phiên demo thật `NOT_RUN` |
| Lợi nhuận của mọi chiến lược | `UNPROVEN` |

Compile chỉ chứng minh cú pháp; tester chỉ chứng minh hành vi trong mô phỏng; không có kết quả nào là
cam kết lợi nhuận hay bằng chứng sẵn sàng cho tài khoản thật.

## 4. Quy ước trạng thái

| Nhãn | Nghĩa |
|---|---|
| `DONE` | Deliverable và acceptance criteria đạt, đã chạy thật, có bằng chứng |
| `PASS` | Kiểm tra cụ thể đã chạy và đạt |
| `PARTIAL` | Đã làm một phần, phạm vi chưa đủ để kết luận |
| `READY_FOR_MANUAL_VALIDATION` | Code compile, test offline đạt, runtime chưa xác minh |
| `NOT_RUN` | Chưa chạy; không được thay bằng suy luận |
| `BLOCKED` / `BLOCKED_PENDING_ADR` | Thiếu đầu vào hoặc bị chặn bởi quyết định phạm vi |
| `UNPROVEN` | Đã chạy nhưng chưa chứng minh được kết luận mong muốn |
| `FAIL` | Đã chạy và không đạt; phải ghi ID/lỗi thật |

Không đổi `NOT_RUN`/`BLOCKED`/`PARTIAL` thành PASS nếu chưa có log, CSV hoặc report thật.

## 5. Quy ước nội dung

- **Tiếng Việt** là ngôn ngữ chính; thuật ngữ kỹ thuật và token lỗi giữ nguyên tiếng Anh.
- **Token lỗi** (`plan_invalid`, `max_virtual_exposure_reached`, …) là hợp đồng ổn định.
- **Preset JSON** là nguồn chuẩn cho input; EA không đọc JSON trực tiếp.
- **Số liệu** phải ghi nguồn: synthetic hay thật, khoảng thời gian, giả định chi phí.
- **Input pack** trong `archive/` là tài liệu gốc chỉ đọc, không sửa và không trộn với tài liệu vận hành.
