# Hướng dẫn cài đặt, build và test

## 1. Phạm vi

Hướng dẫn này thiết lập môi trường lập trình và kiểm thử mô phỏng. Không bao gồm đăng nhập tài khoản môi giới hoặc bật giao dịch bằng tiền thật. Dùng MT5 Desktop/MetaEditor đã được cài sẵn; trong Strategy Tester hãy chọn EA mô phỏng có tên `*LabEA`.

## 2. Phần mềm

- Windows 10/11 64-bit.
- MetaTrader 5 Desktop và MetaEditor 5.
- Python 3.11 64-bit.
- VS Code (khuyến nghị), Git.

MetaEditor được mở từ terminal MT5 bằng `F4`. Trong MetaEditor, biên dịch file đang mở bằng `F7`. Strategy Tester trong MT5 mở bằng `Ctrl+R`.

## 3. Khởi tạo Python

Mở PowerShell tại thư mục repository:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install pytest pandas numpy matplotlib
```

Nếu PowerShell chặn activation, có thể chạy trực tiếp `.\.venv\Scripts\python.exe`; không cần thay đổi chính sách bảo mật toàn hệ thống.

## 4. Cấu hình dự án

```powershell
Copy-Item configs/project.example.json configs/project.local.json
python scripts/validate-project.py --config configs/project.local.json
```

Không đặt mật khẩu, token, account ID hay dữ liệu cá nhân trong config hoặc log. Validator phải từ chối cấu hình khác `SIMULATION_ONLY`.

## 5. Tìm MetaEditor

Trong MetaTrader, nhấn `F4` để mở MetaEditor. Nếu cần path cho script build, dùng shortcut của ứng dụng hoặc tìm file `MetaEditor64.exe` trong thư mục cài MT5 mà bạn có quyền truy cập. Không đoán đường dẫn nếu cài đặt tùy chỉnh.

## 6. Kiểm tra môi trường và build

```powershell
.\scripts\check-environment.ps1 -ProjectRoot .
.\scripts\build-mql5.ps1 -ProjectRoot . -MetaEditorPath "C:\path\to\MetaEditor64.exe"
```

Thay path ví dụ bằng đúng đường dẫn trên máy. Script build chỉ biên dịch các file `.mq5`, lưu log trong `reports/build/` và trả lỗi nếu không tìm thấy MetaEditor, không có source, hoặc không xác minh được log. Nó không chạy Strategy Tester.

## 7. Chạy kiểm thử Python và validator

```powershell
.\scripts\run-python-tests.ps1 -ProjectRoot .
python scripts/validate-project.py --config configs/project.local.json
```

Nếu chưa có test, pytest sẽ báo không tìm thấy test; không được diễn giải điều này là toàn bộ test đã pass. AI coding agent phải tạo test trước khi nghiệm thu logic.

## 8. Chạy EA mô phỏng trong Strategy Tester

Chỉ sau khi AI đã tạo và compile EA:

1. Mở MT5 Desktop và MetaEditor; xác minh compile log không có error.
2. Đặt mã nguồn/compiled EA trong thư mục `MQL5/Experts` của chính terminal dùng để test. Đường dẫn dữ liệu cụ thể có thể mở từ MT5 qua `File → Open Data Folder`.
3. Quay về MT5; trong Navigator làm mới Expert Advisors nếu EA chưa xuất hiện.
4. Mở Strategy Tester bằng `Ctrl+R`, chọn EA `GridLabEA`, `DCALabEA` hoặc `RunnerTrailingLabEA`.
5. Chọn symbol, timeframe, khoảng ngày và mô hình tick. Dùng visual mode lúc đầu để xem logic.
6. Chạy test, kiểm tra tabs Results/Graph/Journal và lưu report cùng preset/config đã dùng.
7. Lặp lại cho từng EA và từng bộ stress test; không so sánh kết quả nếu các khoảng ngày hoặc giả định chi phí khác nhau mà không ghi chú.

Strategy Tester hỗ trợ test trên dữ liệu lịch sử, visual mode và forward testing. Real ticks thường phù hợp hơn cho kiểm tra chi tiết nếu dữ liệu có sẵn; OHLC có thể dùng để kiểm tra sơ bộ nhưng không thay thế test chi tiết. Xem tài liệu chính thức: https://www.metatrader5.com/en/terminal/help/algotrading/testing

## 9. Thư mục kết quả

- `reports/build/`: log biên dịch.
- `reports/tests/`: kết quả pytest.
- `reports/backtests/`: report Strategy Tester, preset và metadata được lưu cùng nhau.
- `reports/experiments/`: config hash, phiên bản source và ghi chú từng thử nghiệm.

Không commit raw datasets lớn hoặc log chứa thông tin tài khoản. Dùng script đóng gói để tạo bundle chia sẻ mã nguồn.

## 10. Khắc phục lỗi

- **MetaEditor không tìm thấy:** mở MT5 và nhấn `F4`, xác định lại `MetaEditor64.exe` rồi truyền bằng `-MetaEditorPath`.
- **Không có EA trong Strategy Tester:** kiểm tra đúng thư mục dữ liệu MT5, compile thành công và làm mới Navigator.
- **Thiếu dữ liệu lịch sử:** chọn phạm vi hẹp hơn hoặc kiểm tra khả năng có dữ liệu trong terminal; đánh dấu test là BLOCKED nếu dữ liệu chưa có.
- **Test khác nhau giữa lần chạy:** so sánh source commit, config, symbol, timeframe, model mode, thời gian test và giả định costs.
- **Build có exit code nhưng log không rõ:** mở log trong `reports/build/`; không công nhận thành công nếu không kiểm tra được kết quả.
