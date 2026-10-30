# Xử lý sự cố

Mỗi mục: triệu chứng → nguyên nhân thật → cách kiểm → cách sửa. Không có bước nào yêu cầu nhập
credential vào file, log hay chat.

## 1. Compile

### MetaEditor trả exit code 1 nhưng không có lỗi

- **Nguyên nhân:** MetaEditor CLI trả 1 kể cả khi compile thành công.
- **Kiểm:** mở file log, đọc dòng cuối.
- **Đúng:** `Result: 0 errors, 0 warnings` và có `.ex5`.
- **Sai:** `Result: N errors, ...` → đọc các dòng `error` phía trên.

### `cannot open ... include file`

- **Nguyên nhân:** include path sai hoặc chưa deploy đúng Data Folder.
- **Kiểm:** file phải nằm ở `<Data Folder>\MQL5\Include\...` đúng cây thư mục.
- **Sửa:** deploy lại theo [INSTALL_AND_TEST.md](INSTALL_AND_TEST.md) mục 3.

### Compile ra `.ex5` nhưng EA không xuất hiện trong Navigator

- **Nguyên nhân:** compile vào thư mục khác với Data Folder terminal đang chạy.
- **Kiểm:** so `<Data Folder>` trong MT5 (File → Open Data Folder) với thư mục đã copy.
- **Sửa:** copy lại đúng chỗ, refresh Navigator (chuột phải → Refresh).

## 2. EA không vào lệnh

Đây là nhóm phổ biến nhất và **thường không phải lỗi**.

### `state=WAITING_FOR_SETUP`, block `bias_unknown`

- **Nguyên nhân:** H1 và M15 chưa cùng hướng. Đây là điều kiện thiết kế.
- **Số liệu thật:** `bias_unknown` chiếm 47.71% số lần bị chặn trong cửa sổ tester.
- **Sửa:** không sửa. Chờ. Tần suất quan sát ~3.1 lệnh/tháng, khoảng chờ dài nhất ~5.5 tuần.

### Block `regime_range`

- **Nguyên nhân:** chuỗi swing không có HH/HL hay LH/LL rõ (13.21% số block).
- **Sửa:** không sửa. Chờ cấu trúc rõ.

### Block `reversal_watch`

- **Nguyên nhân:** CHoCH vừa báo đảo chiều, EA đang chờ xác nhận (29.56%).
- **Sửa:** không sửa.

### Block `bos_against_bias`

- **Nguyên nhân:** BOS M5 ngược bias H1/M15 (3.86%).
- **Sửa:** không sửa.

### Block `volatility_high` / spread

- **Nguyên nhân:** ATR hoặc spread vượt ngưỡng cấu hình (1.52%).
- **Sửa:** chỉ nới ngưỡng nếu có lý do và ghi lại; mặc định giữ.

### Không có block nào, cũng không có ENTRY

- **Kiểm:** EA có thực sự chạy không? Xem journal `INIT` và timestamp mới nhất.
- **Kiểm:** chart có tick mới không (cuối tuần thị trường đóng).
- **Kiểm:** `mql_trade_allowed` trong dòng `INIT` phải bằng `1`.

## 3. Algo Trading

### Journal báo `trade is disabled` / `mql_trade_allowed=0`

- **Nguyên nhân:** nút Algo Trading trên toolbar đang tắt, hoặc tài khoản/server tắt algo trading.
- **Sửa:** bật nút Algo Trading trong terminal. Nếu server tắt, liên hệ broker — không có cách vòng.
- **Lưu ý:** repo không tự bật, không tự đăng nhập, không điều khiển hộp thoại xác thực.

### EA khởi động vào `ERROR_SAFE_MODE`

- **Nguyên nhân:** kill switch còn tồn tại, hoặc state cũ ghi nhận lỗi.
- **Kiểm:** file `MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt` có tồn tại không.
- **Sửa:** đóng EA, xoá file kill switch, khởi động lại. EA vẫn giữ nguyên logic risk ledger.

## 4. Lệnh bị broker từ chối

### `invalid stops`

- **Nguyên nhân:** SL/TP quá gần giá so với `SYMBOL_TRADE_STOPS_LEVEL`.
- **Kiểm:** log có retcode tương ứng.
- **Sửa:** không sửa tay trên terminal; `ExecStopsRespectBroker` phải chặn trước khi gửi. Nếu vẫn lọt,
  đó là bug cần test mới, không phải việc nới stop.

### `invalid volume`

- **Nguyên nhân:** volume không khớp `VOLUME_STEP` / `VOLUME_MIN`.
- **Kiểm:** `ExecNormalizeVolume` trả gì trong test.
- **Sửa:** kiểm lại risk budget; nếu lot tối thiểu vượt ngân sách, EA phải từ chối vào lệnh.

### `no money`

- **Nguyên nhân:** margin không đủ.
- **Sửa:** giảm risk percent hoặc nạp thêm tiền demo. Không tăng đòn bẩy để "cho chạy".

## 5. State và khôi phục

### Sau restart EA quên vị thế đang mở

- **Kiểm:** file state trong `MQL5\Files\PA_TREND_RIDER_DEMO_*` có được cập nhật không.
- **Kiểm:** dòng `INIT` có `restored=1` không.
- **Sửa:** nếu `restored=0` mà vẫn có vị thế, EA phải fail-closed (không mở thêm). Kiểm tra tay vị thế
  trên terminal trước khi bật lại.

### Hai EA cùng chạy trên một tài khoản

- **Nguyên nhân:** magic trùng hoặc chạy nhiều chart.
- **Sửa:** chỉ một instance; magic demo khác magic simulation (test Python kiểm điều này).

## 6. Log và dữ liệu

### Journal trông "trống" hoặc ký tự lạ

- **Nguyên nhân:** MT5 ghi log UTF-16LE.
- **Sửa:** đọc bằng editor hỗ trợ UTF-16, hoặc chuyển encoding trước khi grep.

### Không thấy log tester

- **Nguyên nhân:** tester chạy trong sandbox riêng của agent.
- **Đường dẫn:** `%APPDATA%\MetaQuotes\Tester\<hash>\Agent-127.0.0.1-3000\MQL5\Logs`.
- **Lưu ý:** mỗi lần chạy có thể tạo thư mục mới; đừng chỉ nhìn `Tester\logs`.
- **File CSV EA ghi trong tester** nằm ở `...\Agent-127.0.0.1-3000\MQL5\Files`; report `.htm` và
  `.png` nằm ở thư mục gốc Data Folder.

### Tester chạy nhưng input là mặc định của EA

- **Nguyên nhân:** `ExpertParameters=<name>.set` được resolve từ
  `<Data Folder>\MQL5\Profiles\Tester\`, không phải `reports/build/tester-sets/`. Sau khi cài lại MT5,
  thư mục này trống nên tester chạy im lặng bằng input mặc định.
- **Dấu hiệu:** `config_hash` khác lần chạy trước và kết quả lệch hẳn (ví dụ DCA 0 entry).
- **Sửa:** copy `.set` vào `MQL5\Profiles\Tester\` trước khi chạy, rồi xóa CSV cũ trong sandbox để
  không đọc nhầm output cũ.

### Chạy `/config` không có tác dụng

- **Nguyên nhân:** MT5 chỉ chạy một instance. Nếu terminal demo đang mở, lệnh `terminal64.exe /config:...`
  không mở thêm tester.
- **Sửa:** đóng terminal đang chạy trước, hoặc dùng một bản cài MT5 riêng cho tester.

### `config_hash` không khớp preset

- **Nguyên nhân:** EA chạy bằng input khác file preset đang đọc.
- **Sửa:** dùng đúng `.set`/`.ini` đã sinh; so `config_hash` trong `INIT` với lần chạy trước.

### Log có `state=state=...`

- **Nguyên nhân:** `TRState::Serialize()` đã trả chuỗi bắt đầu bằng `state=`, còn `WriteStateFile` ghép thêm tiền tố lần nữa.
- **Trạng thái:** đã sửa 2026-10-29 — file state ghi thẳng `g_state.Serialize()`. Đường đọc giữ nguyên nên file cũ `state=state=...` vẫn đọc được (parser lấy phần sau dấu `=` đầu tiên).
- **Kiểm chứng:** compile `0 errors, 0 warnings`; test tĩnh `test_demo_state_file_has_single_state_prefix` PASS. Runtime PASS 2026-10-29 (`pa_trendrider_demo_exec`): file state ghi `version=1` + `state=WAITING_FOR_SETUP;transitions=92`, không còn tiền tố lặp.

### DCA báo `adds=0` dù có add

- **Nguyên nhân:** counter `g_dca_adds` bị reset khi basket đóng, nên SUMMARY đọc counter theo-basket.
- **Trạng thái:** đã sửa 2026-10-29 — thêm `g_total_adds` cộng dồn; SUMMARY có `adds=` (tổng) và `basket_adds=` (basket hiện tại).
- **Lưu ý:** CSV cũ trong `reports/build/tester-reports/dca_*` vẫn ghi `adds=0`; đó là bằng chứng lịch sử, không sửa lại.
- **Kiểm chứng:** compile `0 errors, 0 warnings`; test tĩnh `test_dca_summary_reports_cumulative_adds` PASS. Runtime PASS 2026-10-29 (`dca_baseline`): `adds=2|basket_adds=0`, khớp 2 dòng `DCA_ADD`.

## 7. Môi trường

### Sai phiên bản MT5

- **Kiểm:** `(Get-Item "C:\Program Files\MetaTrader 5 EXNESS\terminal64.exe").VersionInfo.FileVersion`.
- **Hiện tại:** `5.0.0.6292`. Tài liệu cũ ghi 6249 là số cũ.

### Đăng nhập

- Repo **không** lưu và **không** tự động hoá đăng nhập. Người dùng đăng nhập terminal bằng tay.
- Không dán login/password/server vào chat, file config hay commit.

### Grid/DCA không chạy trên demo

- **Nguyên nhân:** ADR 0003 cấm grid/DCA trong scope demo đầu.
- **Trạng thái:** `ALLOWED` (ADR 0004) cho tài khoản demo; phiên demo thật `NOT_RUN`. Trong Strategy Tester chạy ở chế độ mô phỏng hoặc execution (tài khoản ảo).
- Không có cách "bật nhanh"; cần ADR mới và chủ dự án duyệt.

## 8. Khi nào dừng và hỏi

Dừng ngay, không tự xử lý, nếu:

- thấy credential trong log/config/commit;
- EA gửi lệnh ngoài phạm vi demo;
- gate tĩnh fail và cách sửa duy nhất là đổi câu chữ cho qua;
- số liệu tester không tái lập được;
- có dấu hiệu hai EA tranh chấp cùng một vị thế.

Liên hệ: xem [DECISIONS_REQUIRED.md](DECISIONS_REQUIRED.md).
