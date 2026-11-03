# Roadmap: Tích hợp Pine Script thành EA/Indicator cho MetaTrader 5

> **Mục đích:** Hướng dẫn AI coding agent kiểm kê các chỉ báo Pine Script do người dùng sở hữu hoặc có quyền sử dụng, chuyển đổi logic có thể chuyển đổi sang MQL5, kiểm tra độ tương đồng tín hiệu và xây dựng EA nghiên cứu/backtest.
>
> **Phạm vi an toàn mặc định:** signal-only, mô phỏng và backtest. Không gửi lệnh thật, không tự kết nối hay thao tác tài khoản môi giới. Không được tự ý thêm đường đi đến giao dịch thật. Mọi đánh giá hiệu quả chỉ là kết quả kiểm thử lịch sử, không đảm bảo kết quả tương lai.

## 1. Nguyên tắc cốt lõi

1. Pine Script không chạy trực tiếp bên trong MT5. Muốn sử dụng logic trong MT5, cần port logic sang MQL5 hoặc thiết kế một cầu nối dữ liệu tách biệt. Với kiểm thử trong Strategy Tester, ưu tiên port thành **custom indicator MQL5** và để EA đọc buffer của chỉ báo.
2. Không giả định có thể dịch máy Pine sang MQL5 một-một. Hai môi trường khác nhau về dữ liệu, thời điểm tính toán, semantics của timeframe, realtime bar, dữ liệu đa khung và API.
3. Không sửa hay xóa file nguồn trong repository gốc (ví dụ repo dự án TM-Trading/TM-Trang). Tạo dự án tích hợp riêng và chỉ đọc/copy các source được phép sử dụng.
4. Không đoán nội dung của chỉ báo khi chưa tìm được mã nguồn. Nếu chỉ có ảnh hoặc chỉ báo đóng mã nguồn, ghi rõ giới hạn và không tự tuyên bố đã port tương đương.
5. Không tuyên bố “khớp 100%” nếu chưa đối chiếu kết quả trên cùng dữ liệu, cùng symbol, timeframe, khoảng thời gian và input.
6. Mọi bất nhất, thiếu tính năng hoặc sai khác đều phải được ghi trong tài liệu tương thích.
7. Mặc định chỉ phát tín hiệu khi nến đã đóng. Nếu script gốc có hành vi intrabar/repainting thì phải ghi nhận, kiểm thử riêng và không âm thầm biến đổi ý nghĩa của tín hiệu.

## 2. Kết quả đầu ra mong muốn

AI cần tạo ra các thành phần sau, tùy khả năng của từng indicator:

- `docs/PINE_INVENTORY.md`: danh sách file Pine được phát hiện và trạng thái phân tích.
- `docs/INDICATOR_SPEC_<name>.md`: mô tả input, công thức, điều kiện tín hiệu, output, phụ thuộc và hành vi repainting của từng indicator.
- `docs/PINE_MQL5_COMPATIBILITY.md`: bảng tính năng Pine hỗ trợ/chưa hỗ trợ, khác biệt và quyết định port.
- Custom indicator MQL5 trong `MQL5/Indicators/PinePort/`.
- EA chỉ đọc tín hiệu trong `MQL5/Experts/PineSignalLabEA.mq5`.
- `docs/TEST_PLAN.md`, nhật ký test và báo cáo so sánh Pine-vs-MQL5.
- Scripts kiểm tra môi trường, build, kiểm tra source, chạy kiểm thử Python và đóng gói artifact.
- `README.md` hướng dẫn cài đặt, cấu hình, biên dịch, backtest, đọc log và xử lý lỗi.

Không phải mọi script Pine đều chuyển được nguyên trạng. Mỗi script cần có trạng thái: `PORTABLE`, `PORTABLE_WITH_DIFFERENCES`, `BLOCKED_NEEDS_INPUT`, hoặc `NOT_PORTABLE_AS_IS`.

## 3. Kiến trúc khuyến nghị

```text
Pine source do người dùng cung cấp/cho phép
                  |
                  v
       Pine inventory + source audit
                  |
                  v
       Indicator specification (docs)
                  |
                  v
         MQL5 custom indicator
       (buffer tín hiệu/giá trị)
                  |
             iCustom()
            CopyBuffer()
                  |
                  v
      PineSignalLabEA (signal-only)
                  |
                  v
          Strategy Tester / logs
                  |
                  v
       CSV exports + comparison tests
```

### Vì sao chọn custom indicator + EA?

- Indicator chịu trách nhiệm tính giá trị và phát tín hiệu qua các buffer.
- EA chịu trách nhiệm đọc buffer, chống ghi lặp tín hiệu và ghi log; không trộn công thức chỉ báo với cơ chế mô phỏng.
- `iCustom()` tạo handle đến custom indicator; `CopyBuffer()` đọc dữ liệu từ buffer. Phải kiểm tra handle hợp lệ, `BarsCalculated()`, giá trị trả về của `CopyBuffer()` và dữ liệu `EMPTY_VALUE`.
- Custom indicator và EA có thể được kiểm thử cùng nhau trong Strategy Tester.
- Nếu một indicator không cần nhiều logic riêng hoặc chỉ dựa trên indicator chuẩn của MT5, vẫn cần tài liệu so sánh trước khi chọn cách dùng indicator built-in.

## 4. Phase 0 — Kiểm tra repository và môi trường

AI phải làm theo thứ tự:

1. Kiểm tra `git status`, nhánh hiện tại và thay đổi chưa commit. Không ghi đè thay đổi của người dùng.
2. Tìm Pine sources trong đường dẫn workspace mà người dùng cho phép. Tìm đuôi `.pine`, `.txt`, `.md` hoặc code được lưu trong tài liệu; không đọc khóa bí mật hoặc dữ liệu không liên quan.
3. Nếu source nằm ở repository khác, chỉ đọc đường dẫn được người dùng chỉ định hoặc file đã được copy vào workspace. Không tự sửa repository đó.
4. Phát hiện cài đặt MT5/MetaEditor nếu có thể; nếu không có, đánh dấu phần compile/test MT5 là `BLOCKED` và vẫn chạy kiểm tra tĩnh/Python có thể thực hiện.
5. Ghi thông tin runtime: Windows, Python, MetaEditor path nếu xác định được, symbol/timeframe mẫu nếu đã có fixture. Không in thông tin nhạy cảm.
6. Tạo `docs/PROGRESS.md` với danh sách phase, trạng thái và bằng chứng test.

**Gate 0:** inventory có đường dẫn source rõ ràng; chưa thay đổi source Pine gốc; mọi môi trường còn thiếu được ghi rõ.

## 5. Phase 1 — Kiểm kê và phân loại Pine Script

Với từng file, ghi:

- Tên file, tên script, phiên bản Pine (`//@version=...`) và loại `indicator()` hay `strategy()`.
- Mục tiêu hiển thị/tín hiệu; vị trí overlay/pane.
- Inputs: tên, kiểu, mặc định, min/max/step, nhóm và tooltip nếu có.
- Outputs: `plot`, `plotshape`, `plotchar`, `barcolor`, `fill`, `alertcondition`, `alert`, label/line/table.
- Điều kiện BUY/SELL/EXIT/HOLD nếu có; nếu chỉ có màu hoặc hình vẽ, xác định điều kiện boolean tạo ra chúng.
- Phụ thuộc các hàm/feature: `ta.*`, `math.*`, `request.security`, `request.security_lower_tf`, `barstate.*`, `var`, mảng, vòng lặp, pivot/fractal, offset âm/dương, session/timezone, volume, external libraries.
- Tính chất realtime/historical, khả năng repaint, xác nhận nến, và điều kiện warm-up.
- Giấy phép/nguồn gốc nếu hiện diện. Nếu giấy phép không rõ, ghi là cần người dùng xác nhận quyền sử dụng trước khi phân phối.

Tạo `docs/PINE_INVENTORY.md` và một spec cho từng script. Không gộp nhiều chỉ báo thành một chiến lược nếu người dùng chưa định nghĩa cách kết hợp.

**Gate 1:** mỗi file có inventory, input/output, phụ thuộc, trạng thái chuyển đổi và các câu hỏi/blocker cụ thể.

## 6. Phase 2 — Phân tích repainting và ngữ nghĩa tín hiệu

Bắt buộc rà soát:

- Tín hiệu có thể thay đổi khi nến đang chạy không?
- Có sử dụng `barstate.isconfirmed`, `barstate.isrealtime`, `barstate.islast` hay phụ thuộc tick không?
- Có `request.security()` ở timeframe khác, `lookahead`, hoặc dùng dữ liệu lower timeframe không?
- Có pivot/fractal hoặc logic cần các nến tương lai để xác nhận không?
- Có `plot` offset làm tín hiệu nhìn như xuất hiện sớm hơn thời điểm thật không?
- Tín hiệu phát một lần khi điều kiện vừa đúng hay giữ `true` nhiều nến?
- Mốc thời gian tín hiệu là lúc nến bắt đầu hay lúc nến đóng?

Mặc định trong EA:

- Dùng nến đã đóng (`shift=1`) để tạo tín hiệu ổn định.
- Chỉ xử lý một lần mỗi nến/tín hiệu; không tạo nhiều sự kiện lặp khi có nhiều ticks.
- Phân biệt “điều kiện còn đúng” với “tín hiệu mới xuất hiện” (edge detection).
- Nếu muốn so sánh intrabar với confirmed-bar, tạo option riêng và báo cáo riêng; không đổi default an toàn.
- Không loại bỏ repainting bằng cách âm thầm thay đổi logic. Phải mô tả sự khác nhau so với Pine.

**Gate 2:** có báo cáo repainting và định nghĩa timestamp/confirmed state rõ ràng cho từng signal.

## 7. Phase 3 — Đặc tả thuật toán trước khi port

Với mỗi indicator, tạo một bảng:

| Trường | Mô tả |
|---|---|
| Signal ID | ID ổn định của điều kiện |
| Trigger | Công thức boolean hoặc điều kiện mô tả đầy đủ |
| Required inputs | Giá, indicator series, timeframe, inputs |
| Bar policy | Current bar hay confirmed bar; shift được dùng |
| Output | Buffer value, signal code hoặc EMPTY_VALUE |
| Repeated signal | Mỗi bar, khi điều kiện đổi false→true, hay theo quy tắc khác |
| Dependencies | Indicator phụ, timeframe, session, external library |
| Known differences | Những khác biệt chưa thể tránh so với Pine |

Đề xuất hợp đồng buffer nhất quán:

- Buffer 0..N: giá trị indicator cần so sánh/hiển thị.
- Buffer `BUY_SIGNAL`: `1.0` trên nến có tín hiệu BUY mới, các nến còn lại `0.0` hoặc `EMPTY_VALUE` theo quy ước thống nhất.
- Buffer `SELL_SIGNAL`: tương tự cho SELL.
- Buffer `EXIT_SIGNAL` nếu source thực sự có điều kiện thoát.
- Không dùng giá 0 làm đại diện thiếu dữ liệu nếu 0 có nghĩa hợp lệ.
- Ghi rõ thứ tự buffer, ý nghĩa, đơn vị, giá trị thiếu và warm-up trong spec.

Nếu dùng enum/số code thay vì nhiều buffer, phải tài liệu hóa và kiểm tra nhất quán trong mọi consumer.

## 8. Phase 4 — Port sang custom indicator MQL5

Quy tắc triển khai:

1. Giữ lại tên gốc của Pine và tạo tên file MQL5 riêng, không ghi đè source.
2. Khai báo input MQL5 có kiểu phù hợp; ghi rõ mọi input không thể port hoặc được ánh xạ gần đúng.
3. Tạo indicator buffers và map với `SetIndexBuffer()`; kiểm tra chỉ số và `ArraySetAsSeries()` nhất quán.
4. Xử lý `OnInit()`/`OnCalculate()` đúng; chỉ tính lại phần cần thiết nếu tối ưu hóa không làm thay đổi kết quả.
5. Tính đủ warm-up history; không dùng buffer trước khi dữ liệu sẵn có.
6. Kiểm soát `prev_calculated`, lịch sử được nạp thêm và tình huống terminal tính lại bars.
7. Tránh nhìn trước dữ liệu; không sao chép các hành vi dựa vào dữ liệu tương lai mà không ghi rõ.
8. Không báo port hoàn tất nếu chưa chạy compile. Nếu MetaEditor không khả dụng, ghi `COMPILE_BLOCKED`, không suy đoán thành công.
9. Với `iCustom()`, kiểm tra đường dẫn tương đối tới indicator và khai báo tester dependency khi cần theo quy tắc MQL5.
10. Comment giải thích các phần chuyển đổi khó và khác biệt có chủ đích.

## 9. Phase 5 — EA signal-only cho MT5

EA mẫu cần:

- Đọc indicator bằng `iCustom()` hoặc handle built-in được tài liệu hóa.
- Đọc buffer bằng `CopyBuffer()`, xác nhận số phần tử được copy và xử lý dữ liệu chưa sẵn sàng.
- Chỉ đánh giá tín hiệu theo bar policy đã thống nhất.
- Chống tạo log/event trùng cho cùng symbol + timeframe + candle time + signal ID.
- Log dạng CSV hoặc cấu trúc dễ phân tích với ít nhất: time, symbol, timeframe, indicator/version, inputs/hash, bar time, signal ID, buffer values, confirmed status, error code.
- Có input bật/tắt từng indicator và bật/tắt log; không có hàm gửi lệnh thật.
- Hiển thị tín hiệu và trạng thái đọc buffer trong visual tester nếu có ích.
- Xử lý `OnInit`, `OnDeinit`, invalid handle, missing history và `CopyBuffer` lỗi.

**Bắt buộc:** phiên bản này là `SIGNAL_ONLY`. Không thêm `CTrade.Buy`, `CTrade.Sell`, `OrderSend`, sửa/đóng lệnh môi giới hay một cơ chế ẩn nào gửi giao dịch thật. Có thể xây dựng module mô phỏng fill riêng trong Python/Strategy Tester mà không đặt lệnh thật.

## 10. Phase 6 — Kiểm chứng Pine vs MQL5

Không dựa chỉ vào nhìn biểu đồ. Chuẩn bị đối chiếu trên cùng dữ liệu và điều kiện:

1. Cùng symbol, timeframe, timezone/timestamp, khoảng ngày và input.
2. Thu thập các giá trị/tín hiệu tham chiếu từ Pine bằng cách hợp lệ, ví dụ xuất dữ liệu/giá trị hoặc dùng fixture đã được người dùng cung cấp.
3. Lưu CSV reference trong `tests/fixtures/`; không tự bịa CSV tham chiếu.
4. Tạo công cụ Python so khớp timestamp, signal ID, giá trị số và trạng thái thiếu dữ liệu.
5. Sai số số thực dùng tolerance được nêu rõ; boolean/event signals cần so sánh chính xác và báo số mismatch.
6. Báo riêng warm-up, bars bị thiếu, session differences, source data mismatch và repainting/intrabar differences.
7. Khi không thể xuất output từ Pine, đánh dấu cross-platform comparison là `BLOCKED`; chỉ chạy unit tests và ghi rõ còn thiếu bước đối chiếu.

Báo cáo gồm: số nến so sánh, số BUY/SELL/EXIT, mismatch count, mismatch timestamps mẫu, max absolute error, first valid bar và nguyên nhân sai khác.

## 11. Phase 7 — Backtest và chất lượng dữ liệu

- Chạy MQL5 custom indicator + signal-only EA trong Strategy Tester.
- Chọn dữ liệu và modeling mode phù hợp với logic chỉ báo; với logic phụ thuộc intrabar, OHLC không đại diện đầy đủ cho diễn biến tick.
- Kiểm tra nhiều khoảng thời gian và nhiều điều kiện thị trường, không chỉ một đoạn đẹp.
- Tách dữ liệu khám phá và giai đoạn kiểm tra xác nhận nếu đánh giá tín hiệu như một quy tắc chiến lược.
- Nếu tạo bộ mô phỏng Python, ghi rõ giả định spread, commission, slippage, entry/exit timing, missing bars và candle alignment.
- Báo cáo chỉ mô tả lịch sử kiểm thử; không diễn giải là bảo đảm lợi nhuận tương lai.

## 12. Phase 8 — Scripts hỗ trợ build/test

AI nên tạo các script sau nếu phù hợp với repo:

- `scripts/check-environment.ps1`: kiểm tra Python, Git, MetaEditor path và cấu trúc thư mục; không đọc secrets.
- `scripts/build-mql5.ps1`: biên dịch `.mq5` bằng MetaEditor command line khi tìm được executable, lưu log và trả mã thoát chính xác.
- `scripts/run-python-tests.ps1`: kích hoạt venv nếu phù hợp và chạy `pytest`.
- `scripts/validate-project.py`: kiểm tra cấu trúc, file docs, manifest indicator, fixture và không có placeholder quan trọng.
- `scripts/compare-indicator-exports.py`: đối chiếu CSV reference với CSV MQL5; nếu thiếu file phải báo `BLOCKED`, không tạo dữ liệu giả.
- `scripts/package-source.ps1`: đóng gói source/docs/tests; loại `.venv`, caches, logs lớn và secrets.

Các script cần có thông báo lỗi rõ ràng, đường dẫn có thể cấu hình và không báo PASS nếu bước chưa thực sự thực hiện. MetaEditor CLI flags/path có thể khác theo cài đặt; script phải kiểm tra và ghi hướng dẫn nếu chưa xác minh được trên máy.

## 13. Cấu trúc thư mục đề xuất

```text
pine-to-mt5-lab/
├── README.md
├── ROADMAP_PINE_TO_MT5_EA.md
├── PROMPT_AI_PINE_TO_MT5_EA.md
├── docs/
│   ├── PROGRESS.md
│   ├── PINE_INVENTORY.md
│   ├── PINE_MQL5_COMPATIBILITY.md
│   ├── INDICATOR_SPEC_<name>.md
│   ├── TEST_PLAN.md
│   ├── INSTALL_AND_TEST.md
│   └── TROUBLESHOOTING.md
├── pine_sources/             # source được user cho phép; read-only theo quy ước
├── MQL5/
│   ├── Indicators/PinePort/
│   ├── Experts/
│   └── Include/PinePort/
├── python/
│   ├── src/
│   └── tests/
├── tests/
│   ├── fixtures/
│   └── reports/
├── scripts/
└── artifacts/                # test reports/build logs; không chứa secrets
```

Nếu repo MT5 hiện có một cấu trúc khác, trước tiên ghi lại cấu trúc và điều chỉnh theo dự án; không di chuyển file tự động khi chưa hiểu các phụ thuộc.

## 14. Phase 9 — Tài liệu cài đặt và sử dụng

`README.md` và `docs/INSTALL_AND_TEST.md` phải giải thích từng bước:

1. Yêu cầu phần mềm và cách phát hiện MetaEditor/MT5.
2. Copy/đặt custom indicator vào `MQL5/Indicators/PinePort/`, EA vào `MQL5/Experts/` và Include nếu có.
3. Mở MetaEditor, compile indicator trước rồi compile EA.
4. Cập nhật Navigator trong terminal nếu file chưa xuất hiện.
5. Mở Strategy Tester (`Ctrl+R`), chọn EA và cấu hình symbol, timeframe, ngày test, modeling mode và inputs.
6. Bật visual mode nếu cần kiểm tra hình vẽ/tín hiệu; xem tab Journal/Experts và log CSV.
7. Cách kiểm tra `iCustom` handle, `CopyBuffer`, missing history, buffer mapping và đường dẫn indicator.
8. Cách chạy Python tests và comparison script.
9. Cách tái lập run bằng config/version/hash.
10. Giới hạn đã biết, cách rollback về commit trước và nơi lưu báo cáo.

Không yêu cầu tài khoản môi giới để chạy kiểm tra tĩnh/fixture. Nếu một bài test đòi dữ liệu terminal, đánh dấu rõ dữ liệu nào còn thiếu.

## 15. Tiêu chí nghiệm thu

Một indicator chỉ được đánh dấu `DONE` khi:

- Source/Pine version/input/output đã được ghi rõ.
- Logic tín hiệu đã được đặc tả trước khi port.
- Repainting và confirmed-bar policy được mô tả.
- MQL5 source được tạo, compile thành công nếu có MetaEditor.
- Buffer contract và `iCustom` integration đã được kiểm tra.
- Có test fixture/unit test khả dụng.
- Có kết quả đối chiếu Pine-vs-MQL5 hoặc ghi `BLOCKED` kèm nguyên nhân cụ thể.
- EA không tạo log trùng và không có đường gửi lệnh thật.
- Tài liệu cài đặt được cập nhật.
- Mọi sai khác còn tồn tại đều được ghi trong `PINE_MQL5_COMPATIBILITY.md`.

## 16. Quy tắc làm việc cho AI coding agent

- Làm từng phase, không tự động nhảy tới phase sau.
- Trước khi sửa file, đọc file hiện hữu và trạng thái Git.
- Không xóa, không format toàn bộ repo và không đổi quy ước dự án chỉ vì sở thích.
- Không lộ API keys, mật khẩu, token hoặc thông tin tài khoản trong log/docs.
- Không dùng source có giấy phép không rõ để phân phối; ghi rõ yêu cầu xác minh quyền sở hữu/license.
- Không dùng package/API không được xác thực chỉ vì có vẻ tiện.
- Nếu thiếu source Pine, yêu cầu người dùng đặt source vào workspace hoặc chỉ định đường dẫn; hoàn thành các phần không bị chặn rồi ghi blocker.
- Cuối mỗi phase, cập nhật `docs/PROGRESS.md` và báo cáo: file đổi, lệnh đã chạy, PASS/FAIL/BLOCKED, log và bước tiếp theo.

## 17. Tài liệu tham khảo chính thức

- Pine Script — Repainting: https://www.tradingview.com/pine-script-docs/concepts/repainting/
- Pine Script — Alerts: https://www.tradingview.com/pine-script-docs/faq/alerts/
- Pine Script — Strategies: https://www.tradingview.com/pine-script-docs/concepts/strategies/
- MQL5 — Application types/EA: https://www.mql5.com/en/docs
- MQL5 — Technical indicators and `iCustom`: https://www.mql5.com/en/docs/indicators
- MQL5 — `CopyBuffer`: https://www.mql5.com/en/docs/series/copybuffer
- MQL5 — Custom indicators: https://www.mql5.com/en/docs/customind
- MQL5 — Strategy Tester: https://www.mql5.com/en/docs/runtime/testing

---

## Prompt khởi động AI

Đọc toàn bộ `ROADMAP_PINE_TO_MT5_EA.md` trước khi thực hiện. Bắt đầu **Phase 0**: kiểm tra repository, trạng thái Git, môi trường, và kiểm kê mọi Pine Script mà người dùng đã cung cấp hoặc cho phép truy cập. Không sửa source Pine gốc. Tạo `docs/PROGRESS.md`, `docs/PINE_INVENTORY.md` và tài liệu blocker nếu còn thiếu đầu vào. Chỉ làm Phase 0 trong lượt này rồi dừng để báo cáo; không tạo logic giao dịch thật, không thêm API gửi lệnh thật, không khẳng định đã compile/backtest nếu chưa thực sự chạy. Nếu không tìm thấy Pine source, ghi chính xác nơi đã kiểm tra và tiếp tục các việc không bị chặn thay vì đoán thuật toán.
