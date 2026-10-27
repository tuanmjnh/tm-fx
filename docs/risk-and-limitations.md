# Rủi ro và giới hạn

- **Ngày:** 2026-10-27
- **Phạm vi:** toàn bộ dự án, cập nhật lần đầu ở Phase 0.

## 1. Giới hạn phạm vi

- Dự án chỉ phục vụ nghiên cứu, backtest và mô phỏng. Không có giao dịch thật, không kết nối tài khoản
  môi giới, không lưu thông tin đăng nhập.
- Kết quả mô phỏng không phải kết quả giao dịch thật và không dự đoán lợi nhuận tương lai.
- Không có cam kết “đảm bảo thắng”, “đảm bảo lợi nhuận” hay tối ưu theo một metric duy nhất.
- Phase 0 chưa có EA, chưa có backtester, chưa có model. Mọi tuyên bố hiệu năng là không thể có ở thời điểm này.

## 2. Rủi ro dữ liệu

| Rủi ro | Ảnh hưởng | Giảm thiểu dự kiến |
|---|---|---|
| Dữ liệu MT5 export thiếu bar, sai timezone/DST | Tín hiệu và metric sai lệch | Validator ở Phase 3; ghi rõ nguồn và khoảng thời gian |
| `tick_volume` bị hiểu nhầm là real volume | Feature/volume-based logic sai | Ghi rõ định nghĩa; không dùng như real volume |
| Đơn vị `spread` không nhất quán (point/pip/price) | Cost model sai | Chuẩn hóa và ghi đơn vị trong data dictionary |
| Dữ liệu tổng hợp bị coi là dữ liệu thị trường | Kết luận sai | Mọi dataset có `data_kind`; chỉ fixture synthetic cho unit test |
| Dữ liệu lớn hoặc có quyền hạn chế bị commit | Rò rỉ/vượt quyền sử dụng | `datasets/raw|processed` bị gitignore; chỉ mẫu nhỏ ở `samples/` |
| Look-ahead do dùng nhầm bar index | Kết quả đẹp giả tạo | Chỉ dùng nến đã đóng; test warm-up/boundary ở Phase 2–4 |

## 3. Rủi ro mô phỏng và chi phí

- Spread, slippage, commission và cách khớp lệnh chưa được định nghĩa. Không được báo metric backtest
  khi các giả định này chưa rõ.
- Không mô phỏng được đầy đủ thanh khoản, requote, latency, swap, gap cuối tuần và điều kiện broker thực tế.
- Kết quả phụ thuộc mạnh vào khoảng thời gian, symbol và timeframe được chọn.
- Overfitting và p-hacking có thể xảy ra nếu chọn feature/threshold trên test set hoặc thử nhiều cấu hình
  trên cùng dữ liệu. Test cuối cùng phải được giữ kín đến khi chốt model (Phase 7).
- Sharpe/Sortino chỉ được báo khi định nghĩa return series, tần suất lấy mẫu và annualization rõ ràng.

## 4. Rủi ro kỹ thuật và môi trường

| Rủi ro | Trạng thái Phase 0 | Ghi chú |
|---|---|---|
| MT5/MetaEditor thay đổi theo build | Đã ghi nhận build 5.0.0.6249 | Phải xác minh lại trước Phase 1/8 |
| Agent không có kết quả compile/tester thật | Chưa compile EA nào | Phase 1 phải chạy MetaEditor thật hoặc ghi `READY_FOR_MANUAL_VALIDATION` |
| OS là Windows 10, roadmap khuyến nghị Windows 11 | Đã ghi nhận | Không chặn Phase 0; theo dõi lỗi đặc thù MT5 |
| Khác biệt indicator MQL5 và Python | Chưa kiểm chứng | Tolerance và quy trình so sánh ở Phase 5 |
| ONNX/ONNX Runtime tương thích MT5 | Chưa xác minh | Chỉ kết luận sau Phase 8 |
| Tên menu MT5 khác theo ngôn ngữ/build | Chưa kiểm tra GUI | Hướng dẫn thủ công ghi rõ điều kiện |
| Dependency Python trôi phiên bản | Pin trong `requirements.txt` | Cập nhật có chủ đích, ghi lại lý do |
| Tự nâng cấp pip không hoàn tất trên máy kiểm thử | Đã dừng; venv dùng pip 24.0 và cài dependency thành công | Không chặn Phase 0; chỉ thử lại khi cần, không chạy đồng thời với cài dependency |
| Matplotlib không ghi được cache mặc định | Cảnh báo khi import, tạo cache tạm trong repo | Đặt `MPLCONFIGDIR` vào thư mục ghi được khi dùng plotting |

## 5. Rủi ro bảo mật và vận hành

- Không commit `.env`, token, mật khẩu, investor password, `accounts.dat`, `servers.dat` hoặc log tài khoản.
- Không chạy executable/script tải từ nguồn không được duyệt; không tự đổi firewall/antivirus/PATH.
- Repository mới được khởi tạo Git ở Phase 0 và **chưa có commit**. Chưa có remote; việc push là quyết định
  riêng của người dùng.
- Nếu phát hiện secret trong working tree, dừng lại, gỡ khỏi file và báo cáo; không commit.
- Mọi mở rộng sang execution phải là quyết định phạm vi mới, không nằm trong roadmap hiện tại.

## 6. Điều kiện để tiếp tục phase

- Phase chỉ được đánh dấu `DONE` khi deliverable và acceptance criteria đạt, test thực tế đã chạy và ghi lại.
- Nếu thiếu MT5/MetaEditor, phase MQL5 chỉ được đánh dấu `READY_FOR_MANUAL_VALIDATION`.
- Không bắt đầu phase tiếp theo nếu báo cáo phase hiện tại còn blocker chưa xử lý.
