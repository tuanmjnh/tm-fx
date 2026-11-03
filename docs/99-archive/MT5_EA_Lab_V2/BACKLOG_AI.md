# Backlog AI (không triển khai)

- **Trạng thái:** `DEFERRED`
- **Quy tắc:** không huấn luyện, không suy luận, không đưa AI vào đường ra quyết định giao dịch trong
  phạm vi hiện tại.

## 1. Vì sao để sau

Ba chiến lược hiện tại (PA_TrendRider, Grid, DCA) chưa có bằng chứng lợi nhuận ổn định ngay cả khi
không có AI. Thêm model vào lúc này chỉ làm tăng số biến chưa kiểm soát:

- chưa có quy trình walk-forward cho chiến lược tất định;
- chưa có baseline out-of-sample;
- chưa có cách so sánh công bằng giữa có/không AI;
- execution demo mới chỉ chứng minh hạ tầng, chưa chứng minh chiến lược.

Điều kiện mở lại backlog: tất cả mục ở mục 5 phải xong trước.

## 2. Phạm vi kỹ thuật dự kiến

### 2.1 Dataset

- Dữ liệu bar/tick có nguồn, thời điểm tải, symbol, timezone, spread giả định.
- Lưu hash của dataset; không dùng file không truy vết được nguồn.
- Tách hoàn toàn train/validation/test theo thời gian, có purge giữa các cửa sổ.
- Không dùng dữ liệu tương lai trong feature tại thời điểm quyết định.

### 2.2 Nhãn

- Nhãn phải khớp thời điểm ra quyết định (bar đóng), không dùng giá trong tương lai gần.
- Định nghĩa rõ horizon, cách xử lý khi SL và TP cùng chạm trong một bar.
- Ghi lại tỷ lệ nhãn, phân bố theo giờ, theo regime.

### 2.3 Kiểm tra rò rỉ

- Kiểm tra tự động: feature timestamp ≤ decision timestamp.
- Kiểm tra thủ công các feature dễ rò: high/low của bar hiện tại, spread trung bình tương lai, chuỗi
  swing chưa xác nhận.

### 2.4 Validation

- Chronological split, walk-forward nhiều cửa sổ.
- So sánh với baseline tất định (PA_TrendRider hiện tại) trên cùng dữ liệu, cùng chi phí.
- Báo cáo cả phân bố lợi nhuận, drawdown, số lệnh, không chỉ một con số tổng.

### 2.5 Model versioning

- Mỗi model có id, hash file, dataset hash, tham số, ngày huấn luyện, người chạy.
- Không ghi đè model cũ; model mới là artifact mới.
- Không đưa file model vào repo nếu vượt kích thước cho phép; dùng release artifact có hash.

### 2.6 Adapter suy luận an toàn

- Suy luận chỉ tạo ra tín hiệu, không được bỏ qua bất kỳ guard nào.
- Risk sizing, daily loss, drawdown, streak, cooldown, kill switch áp dụng y hệt chiến lược tất định.
- Nếu model lỗi/không tải được → fail-closed, không vào lệnh.
- Không gọi mạng từ EA; không tải model từ URL lúc chạy.

## 3. Ranh giới tuyệt đối

- AI **không** được cấp quyền gửi lệnh ngoài các file Exec đã được ADR cho phép.
- AI **không** được nới risk cap để "cho lệnh chạy".
- AI **không** được bật tài khoản real.
- Không dùng AI để che giấu kết quả xấu hoặc chọn cửa sổ test đẹp.

## 4. Ước lượng thô (chỉ để xếp lịch)

| Hạng mục | Việc chính |
|---|---|
| Dataset | chuẩn hoá nguồn, hash, split |
| Feature/label | định nghĩa, kiểm rò rỉ, test |
| Baseline | tái lập PA_TrendRider làm mốc |
| Model | huấn luyện, versioning |
| Đánh giá | walk-forward, báo cáo |
| Adapter | suy luận fail-closed, guard |
| Tài liệu | protocol, giới hạn, cách tái lập |

Không có mốc thời gian cam kết.

## 5. Điều kiện mở lại

- [ ] PA_TrendRider có kết quả out-of-sample tái lập được.
- [ ] Grid/DCA có quyết định rõ: giữ hay bỏ (xem [DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md)).
- [ ] Demo forward có ít nhất một chu kỳ đủ dài, có log đầy đủ.
- [ ] Có hạ tầng lưu artifact model và dataset hash.
- [ ] Chủ dự án duyệt rõ phạm vi AI.

Cho tới khi đó, mọi đề xuất "thêm AI vào EA" trả lời mặc định: **không**, kèm lý do ở mục 1.
