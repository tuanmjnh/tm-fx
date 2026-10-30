# Lộ trình tổng

- **Phiên bản:** 2.0
- **Cập nhật:** 2026-10-29
- **Trạng thái:** tài liệu quyết định. Bảng trạng thái chi tiết ở [`v2/ROADMAP.md`](v2/ROADMAP.md).
- **Lịch sử:** roadmap v1 nằm ở [`archive/v1/MASTER_ROADMAP_v1.md`](archive/v1/MASTER_ROADMAP_v1.md);
  roadmap gốc của v2 nằm ở
  [`archive/planning-inputs/MT5_EA_Lab_v2/ROADMAP_MT5_EA_LAB_V2.md`](archive/planning-inputs/MT5_EA_Lab_v2/ROADMAP_MT5_EA_LAB_V2.md).
  Cả hai đều **không còn là nguồn sự thật**.

## 1. Mục tiêu

Nghiên cứu và vận hành ba chiến lược trên XAUUSDm, với kỷ luật bằng chứng:

1. **PATrendRider XAU v1** — Price Action đa khung, một vị thế, risk cố định theo %.
2. **Grid EA** — lưới có giới hạn cứng, chỉ mô phỏng.
3. **DCA EA** — bổ sung vị thế có giới hạn cứng, chỉ mô phỏng.

Không mục tiêu nào bao gồm lợi nhuận được bảo đảm, tài khoản real, hay dịch vụ cho người khác.

## 2. Ranh giới cố định

1. Chỉ demo hoặc Strategy Tester được gửi lệnh (ADR 0003).
2. Ba file Exec là nơi duy nhất gọi API giao dịch.
3. Không credential trong bất kỳ artifact nào.
4. Không bịa kết quả; `NOT_RUN`/`BLOCKED` phải giữ nguyên cho tới khi có bằng chứng.
5. Grid/DCA demo cần ADR mới trước khi viết code.

## 3. Trạng thái phase

| Phase | Nội dung | Trạng thái |
|---|---|---|
| 0 | Inventory, môi trường, baseline | DONE |
| 1 | GitHub open-source audit | DONE_METADATA — 7/7 SHA + license, không `USE`, xem [`v2/GITHUB_AUDIT.md`](v2/GITHUB_AUDIT.md) |
| 2 | Đặc tả chiến lược | DONE |
| 3 | Shared core và build pipeline | DONE |
| 4 | PATrendRider adapter/baseline | DONE |
| 5 | Grid EA | DONE mô phỏng; demo `NOT_RUN` (bị chặn) |
| 6 | DCA EA | DONE mô phỏng; demo EA sẵn sàng (`DCADemoEA`, ADR 0004); phiên demo thật `NOT_RUN` |
| 7 | Strategy Tester automation | PARTIAL |
| 8 | Demo forward verification | PARTIAL — hạ tầng PASS, chiến lược chưa có ENTRY |
| 9 | Docs và release packaging | DONE |
| 10 | AI research backlog | chỉ tài liệu, xem [`v2/BACKLOG_AI.md`](v2/BACKLOG_AI.md) |

## 4. Việc tiếp theo, theo thứ tự ưu tiên

| Ưu tiên | Việc | Điều kiện xong |
|---|---|---|
| P0 | Giữ gate xanh sau mọi thay đổi | `validate-project.py`, `validate_demo_execution.py`, `pytest -q` đều PASS |
| P0 | Demo forward đủ dài cho PATrendRider | có `ENTRY`/`EXIT` do chính EA, log và audit khớp |
| P1 | Protocol đánh giá out-of-sample | tách dữ liệu, walk-forward, báo cáo tái lập được |
| P1 | Quyết định Grid/DCA | hoặc giữ simulation-only, hoặc ADR mới cho demo |
| P2 | ~~Đóng `PARTIAL` của GitHub audit~~ **DONE 2026-10-29** | 7/7 repo có commit SHA + license file; 0 `USE`; source review `NOT_RUN` |
| P2 | ~~Sửa lỗi báo cáo nhỏ~~ **DONE 2026-10-29** | `state=state=` và DCA `adds=0` đã sửa; test hồi quy tĩnh PASS; runtime PASS trong Strategy Tester |
| P3 | AI | chỉ mở khi P0–P1 xong và chủ dự án duyệt |

## 5. Definition of Done

- Source MQL5 compile được, hoặc blocker được ghi rõ; không tuyên bố compile khi chưa chạy compiler.
- Có test cho mọi giới hạn risk chính.
- Có report tester + config cho mỗi EA đã hoàn thành.
- Demo hard-gate; tài khoản real bị từ chối.
- Docs cho cài đặt, cấu hình, backtest, demo, troubleshooting đầy đủ.
- Không tài liệu nào hứa hẹn lợi nhuận.
- AI vẫn ở backlog.

## 6. Liên kết

- Trạng thái chi tiết: [`v2/ROADMAP.md`](v2/ROADMAP.md)
- Bằng chứng: [`v2/EVIDENCE.md`](v2/EVIDENCE.md)
- Quyết định đang chờ: [`v2/DECISIONS_REQUIRED.md`](v2/DECISIONS_REQUIRED.md)
- Quy tắc cho người/AI tiếp tục: [`v2/PROMPT_AI_IMPLEMENT.md`](v2/PROMPT_AI_IMPLEMENT.md)
