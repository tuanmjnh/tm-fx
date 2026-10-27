# Kiểm kê môi trường — Phase 0

- **Ngày kiểm kê:** 2026-10-27
- **Phương pháp:** chỉ đọc thông tin phiên bản, danh sách thư mục và metadata file. Không cài phần mềm,
  không sửa PATH, không mở GUI, không kết nối tài khoản, không đọc nội dung file tài khoản.
- **Máy:** Windows 10.0.19045.6456 (64-bit)

## 1. Bảng kiểm kê

| Hạng mục | Kết quả | Trạng thái |
|---|---|---|
| Windows | 10.0.19045.6456 | PASS (roadmap khuyến nghị Windows 11; xem giới hạn) |
| Python | 3.11.9, cài user-scope (`%LOCALAPPDATA%\Programs\Python\Python311`) | PASS |
| Python launcher | `py -0p` chỉ có 3.11 (mặc định) | PASS |
| pip | 26.1.1 | PASS |
| Git | 2.53.0.windows.3 | PASS |
| Git repository | Ban đầu **không phải** Git repo; đã `git init -b main`, chưa commit | PASS (đã khởi tạo) |
| MT5 terminal | 5.0.0.6249, `C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe` | PASS (hiện diện) |
| MetaEditor | 5.0.0.6249, `C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe` | PASS (hiện diện) |
| MT5 Strategy Tester | `metatester64.exe` 5.0.0.6249 | PASS (hiện diện) |
| MT5 Data Folder | `%APPDATA%\MetaQuotes\Terminal\<terminal-id>` (ID cục bộ, không ghi vào repo) | PASS |
| `MQL5/Experts` | Tồn tại; chỉ có thư mục mặc định (`Advisors`, `Examples`, `Free Robots`) | PASS |
| Python venv | `.venv` tạo bằng Python 3.11.9, cài `requirements.txt` | Xem mục 3 |
| Pytest | Chạy smoke test trong `.venv` | Xem mục 3 |

Ghi chú: thư mục data của terminal chứa `accounts.dat`, `servers.dat`, `config/` và các file phiên.
Phase 0 chỉ liệt kê tên file/thư mục; **không đọc nội dung**, không sao chép vào repository. Các file này
nằm trong `.gitignore` để tránh commit nhầm.

## 2. Những gì chưa được xác minh

| Hạng mục | Lý do | Cách xác minh |
|---|---|---|
| Compile MQL5 | Phase 0 chưa có file `.mq5` | Phase 1: mở MetaEditor, compile `LabSignalEA.mq5`, đọc tab Errors |
| Strategy Tester chạy EA | Chưa có EA; agent không điều khiển GUI | Phase 1: `Ctrl+R`, chọn EA/symbol/timeframe, xem Journal/Experts |
| Dữ liệu lịch sử của terminal | Không kiểm tra/không tải dữ liệu | Phase 1/3: xác nhận symbol và khoảng ngày có sẵn |
| ONNX runtime trong MT5 | Phase 8 | Kiểm tra API và build thực tế |
| Kết nối broker/tài khoản | **Ngoài phạm vi, không được làm** | Không thực hiện |

## 3. Kết quả thiết lập Python (đã chạy thực tế)

Các lệnh dưới đây chạy trong `.venv` (Python 3.11.9) tại thư mục gốc repository.

| Lệnh | Kết quả thực tế |
|---|---|
| `py -3.11 -m venv .venv` | Tạo thành công |
| `.venv\Scripts\python.exe --version` | `Python 3.11.9` |
| `.venv\Scripts\python.exe -m pip --version` | `pip 24.0` |
| `.venv\Scripts\python.exe -m pip install --upgrade pip` | **Không hoàn tất**: tiến trình quay CPU, không có output sau khoảng 2 phút; đã dừng chủ động. Không ảnh hưởng cài dependency. |
| `.venv\Scripts\python.exe -m pip install -r requirements.txt` | Thành công: numpy 2.4.6, pandas 2.3.3, scikit-learn 1.9.1, matplotlib 3.11.2, pytest 9.1.1 (+ transitive deps) |
| `.venv\Scripts\python.exe -m pytest` | **11 passed in 0.07s** (pytest 9.1.1, rootdir `tm-fx`, config `pyproject.toml`) |
| `.venv\Scripts\python.exe -m compileall -q python/src python/tests` | Exit code 0 |
| `.venv\Scripts\python.exe -m pip check` | `No broken requirements found.` |
| Import numpy/pandas/sklearn/matplotlib/pytest | Thành công; matplotlib cảnh báo không ghi được cache mặc định `%LOCALAPPDATA%\matplotlib` và tạo cache tạm trong repo |

Chi tiết đầy đủ, bao gồm lệnh và danh sách file: [`phase-reports/phase-0.md`](phase-reports/phase-0.md).

### Ghi chú môi trường

- Không chạy `.\.venv\Scripts\Activate.ps1`; các lệnh dùng trực tiếp interpreter trong `.venv` để tránh phụ
  thuộc Execution Policy. Người dùng có thể kích hoạt thủ công nếu PowerShell cho phép.
- Nếu cần dùng matplotlib ở phase sau, đặt cache vào thư mục ghi được, ví dụ trong phiên PowerShell:
  `$env:MPLCONFIGDIR = "$PWD\.venv\matplotlib-cache"`. Không cần thay đổi biến môi trường hệ thống.
- Nâng cấp pip chỉ nên thực hiện khi cần; lần thử trong Phase 0 không hoàn tất nên baseline giữ pip 24.0.

## 4. Quy trình xác minh MT5 thủ công (cho Phase 1)

1. Mở MT5. Dùng `File → Open Data Folder` (tên menu có thể khác theo ngôn ngữ/build).
2. Xác nhận data folder mở đúng terminal đang dùng. Không commit đường dẫn tuyệt đối hoặc terminal ID vào repo.
3. Copy/sync EA từ `mt5/Experts/` vào `<Data Folder>/MQL5/Experts/` (thao tác thủ công, không tự động).
4. Mở MetaEditor (`F4`), mở file `.mq5`, compile (`F7`). Ghi lại số warning/error thực tế.
5. Trong MT5, mở Strategy Tester (`Ctrl+R`), chọn EA, symbol, timeframe, khoảng ngày và chế độ visual
   nếu cần. Chạy và đọc tab Journal/Experts.
6. Không chọn tài khoản thật để chạy; chỉ dùng dữ liệu lịch sử/offline theo roadmap.
7. Ghi lại build terminal và kết quả vào báo cáo phase tương ứng.

Không tuyên bố đã compile hoặc backtest thành công nếu chưa thực hiện các bước trên và đọc kết quả thật.
