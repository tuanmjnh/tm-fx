# Quyết định cần chủ dự án

Mỗi mục ghi: vấn đề, vì sao bị chặn, lựa chọn, mặc định nếu không có quyết định. Không mục nào được
tự triển khai khi chưa có quyết định.

## 1. DCA chạy trên tài khoản demo — `BLOCKED_PENDING_ADR` — ĐÃ GIẢI QUYẾT (ADR 0004, 2026-10-30)

- **Vấn đề:** yêu cầu "test bot DCA chạy lệnh liên tục trên demo".
- **Vì sao chặn:** ADR 0003 mục 3 ghi rõ "không martingale, không grid, không DCA trong phạm vi demo
  execution đầu tiên"; mục 1 giới hạn API lệnh cho đúng ba file Exec; mục 7 yêu cầu ADR mới cho mọi
  mở rộng phạm vi.
- **Lựa chọn:**
  1. Giữ nguyên: DCA chỉ chạy trong Strategy Tester ở chế độ mô phỏng.
  2. Tạo ADR 0004 cho DCA demo, kèm guard riêng, test cap, và tiêu chí dừng.
- **Mặc định:** giữ nguyên.

Nếu chọn 2, cần tối thiểu: EA riêng tên rõ, magic riêng, hard cap số lần add + exposure, stop basket
bắt buộc, kill switch, test contract cho cap, và bằng chứng tester trước khi chạy demo.
- **Quyết định:** [ADR 0004](../decisions/0004-all-bots-demo-execution.md) cho phép mọi bot execution trên demo; implementation đã có (`GridDemoEA`/`DCADemoEA`) và static gate xanh. Phiên demo thật vẫn `NOT_RUN`.

## 2. Grid chạy trên tài khoản demo — `BLOCKED_PENDING_ADR` — ĐÃ GIẢI QUYẾT (ADR 0004, 2026-10-30)

- **Vấn đề:** cùng lý do như DCA, cộng thêm rủi ro xu hướng một chiều.
- **Lựa chọn:** giữ simulation-only, hoặc ADR riêng với cap cứng và kịch bản stress.
- **Mặc định:** giữ simulation-only.
- **Quyết định:** [ADR 0004](../decisions/0004-all-bots-demo-execution.md) cho phép mọi bot execution trên demo; implementation đã có (`GridDemoEA`/`DCADemoEA`) và static gate xanh. Phiên demo thật vẫn `NOT_RUN`.

## 3. Audit GitHub và license — đã đóng ở mức metadata

- **Vấn đề:** mới có shortlist 7 repo, chưa có commit SHA, chưa đọc license gốc, chưa đọc source.
- **Vì sao quan trọng:** copy code GPL hoặc code không rõ license sẽ ảnh hưởng cả repo.
- **Đã làm (2026-10-29):** ghi HEAD SHA + license file cho 7/7 repo; 1 repo không license → `REJECT`;
  6 repo còn lại `REFERENCE_ONLY`; **không** repo nào `USE`, nên không copy dòng code nào.
  Xem [GITHUB_AUDIT.md](GITHUB_AUDIT.md).
- **Lựa chọn còn lại:** nếu muốn dùng code của một repo cụ thể, phải duyệt `USE` và khi đó audit source
  + build/test trở thành bắt buộc tại đúng SHA đã ghi.
- **Mặc định:** tiếp tục không dùng code ngoài.

## 4. Tài khoản real / live — ngoài phạm vi

- **Vấn đề:** mọi yêu cầu chuyển sang tài khoản thật.
- **Quyết định hiện tại:** bị cấm tuyệt đối (ADR 0003 mục 2 và 7).
- **Không có lựa chọn "bật nhanh".** Muốn đổi phải có ADR mới, được duyệt trước khi viết code, cùng
  danh sách an toàn tối thiểu.

## 5. Theo dõi journal tự động (watcher)

- **Vấn đề:** script giám sát journal đã có, nhưng chưa có lịch chạy cố định.
- **Lựa chọn:** chạy tay khi cần; hoặc đặt lịch trong giờ thị trường mở.
- **Ràng buộc:** watcher chỉ đọc log, không gửi lệnh, không đăng nhập hộ.
- **Mặc định:** chạy tay.

## 6. Lỗi định dạng log `state=state=...`

- **Vấn đề:** log in lặp tiền tố, khó đọc bằng máy.
- **Ảnh hưởng:** không ảnh hưởng quyết định giao dịch; có thể ảnh hưởng parser.
- **Quyết định:** sửa ngay — không cần chủ dự án duyệt vì không đổi hành vi giao dịch.
- **Đã làm:** `WriteStateFile` ghi `g_state.Serialize()` không ghép thêm `state=`; parser đọc file cũ vẫn giữ nguyên. Test `test_demo_state_file_has_single_state_prefix`.
- **Trạng thái:** đã xử lý và kiểm chứng runtime (2026-10-29): `pa_trendrider_demo_exec` ghi `state=WAITING_FOR_SETUP;transitions=92`, một tiền tố.

## 7. Lỗi đếm `adds=0` của DCA

- **Vấn đề:** counter bị reset khi basket đóng nên summary báo 0.
- **Ảnh hưởng:** sai số liệu báo cáo, không sai logic add.
- **Quyết định:** sửa reporting — thêm counter cộng dồn, không đổi logic add/risk.
- **Đã làm:** `g_total_adds` + trường `basket_adds` trong SUMMARY; test `test_dca_summary_reports_cumulative_adds`.
- **Trạng thái:** đã xử lý và kiểm chứng runtime (2026-10-29): `dca_baseline` ghi `adds=2|basket_adds=0`, khớp 2 dòng `DCA_ADD`; CSV cũ giữ nguyên làm bằng chứng lịch sử.

## 8. Kế hoạch chứng minh lợi nhuận

- **Vấn đề:** chưa có bằng chứng lợi nhuận; tester hiện tại mẫu nhỏ, không out-of-sample.
- **Lựa chọn:**
  1. Chấp nhận `UNPROVEN`, chỉ dùng để nghiên cứu.
  2. Đầu tư protocol walk-forward: tách dữ liệu, nhiều cửa sổ, so baseline, báo cáo đầy đủ.
- **Mặc định:** `UNPROVEN`; không dùng bất kỳ con số tester nào để quảng bá.

## 9. Phiên bản MT5 trong tài liệu

- **Vấn đề:** tài liệu cũ ghi build 6249; máy hiện tại 6292.
- **Quyết định:** tài liệu v2 ghi 6292 kèm cách kiểm tra; số cũ chỉ còn trong archive.
- **Trạng thái:** đã xử lý, không cần quyết định thêm.

## 10. Cách trả lời

Khi cần quyết định, trả lời theo mẫu:

```
Mục: <số>
Chọn: <1 hoặc 2>
Điều kiện kèm theo: <nếu có>
Ngày: <YYYY-MM-DD>
```

Không có quyết định = giữ mặc định. Không mục nào được hiểu ngầm là đã duyệt.
