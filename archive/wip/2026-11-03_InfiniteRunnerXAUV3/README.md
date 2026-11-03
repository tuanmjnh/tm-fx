# WIP — InfiniteRunner XAU V3 (cô lập 2026-11-03)

File `InfiniteRunnerXAUV3DemoEA.mq5` là bản thử nghiệm của chủ dự án, **không** phải một phần
của bộ EA demo đã đăng ký.

- **Không** được build, deploy hay đưa vào `scripts/deploy_pineport.ps1`.
- **Không** được chạy trên tài khoản thật.
- Lý do cô lập: 6 lời gọi `AccountInfoDouble`/`AccountInfoInteger` (dòng 534, 1621, 1626,
  1699, 1704, 1705) nằm ngoài `mt5/Include/Exec/*`, vi phạm ranh giới "chỉ `ExecBroker` gửi lệnh"
  mà `scripts/validate-project.py` quét.
- Điều kiện đưa trở lại `mt5/`: chuyển toàn bộ truy cập tài khoản vào `mt5/Include/Exec/*`,
  compile 0 lỗi / 0 cảnh báo, và có ADR riêng chấp thuận bot demo thứ sáu.

Trạng thái: `BLOCKED` — chưa có ADR, chưa có bằng chứng tester.
