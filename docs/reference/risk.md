# Rủi ro và giới hạn

- **Ngày:** 2026-10-28
- **Phạm vi:** toàn bộ dự án, cập nhật ở Phase 9, trailing stop, bounded DCA/grid và ranh giới execution
  (ADR 0002).

## 1. Giới hạn phạm vi

- Dự án chỉ phục vụ nghiên cứu, backtest và mô phỏng. Không có giao dịch thật, không kết nối tài khoản
  môi giới, không lưu thông tin đăng nhập.
- Kết quả mô phỏng không phải kết quả giao dịch thật và không dự đoán lợi nhuận tương lai.
- Không có cam kết “đảm bảo thắng”, “đảm bảo lợi nhuận” hay tối ưu theo một metric duy nhất.
- Phase 5 đã có exporter/comparator cho parity MQL5/Python, nhưng MQL5 export **chưa chạy** trong
  terminal. Phase 6 đã có SQLite experiment store và so sánh run. Phase 7 đã có ML baseline (label,
  feature, split, logistic, model card). Phase 8 đã export ONNX, kiểm tra parity Python–ONNX offline và
  compile EA inference-only, nhưng **chưa chạy** EA/ONNX Runtime trong MT5. Phase 9 đã có pipeline
  end-to-end trên Python và đã tái lập trên snapshot commit sạch tạm thời, nhưng chưa chạy MT5 Strategy
  Tester và chưa lặp lại sau commit chính thức. Bounded DCA/grid mới là simulator Python cho một basket
  nhiều layer với hard cap, chưa có MQL5/EA và không nối experiment store. Mọi kết quả hiện tại chỉ từ
  dữ liệu offline, phần lớn là fixture synthetic.

## 2. Rủi ro dữ liệu

| Rủi ro | Ảnh hưởng | Giảm thiểu dự kiến |
|---|---|---|
| Dữ liệu MT5 export thiếu bar, sai timezone/DST | Tín hiệu và metric sai lệch | Validator ở Phase 3; ghi rõ nguồn và khoảng thời gian |
| `tick_volume` bị hiểu nhầm là real volume | Feature/volume-based logic sai | Ghi rõ định nghĩa; không dùng như real volume |
| Đơn vị `spread` không nhất quán (point/pip/price) | Cost model sai | Chuẩn hóa và ghi đơn vị trong data dictionary |
| Dữ liệu tổng hợp bị coi là dữ liệu thị trường | Kết luận sai | Mọi dataset có `data_kind`; chỉ fixture synthetic cho unit test |
| Dữ liệu lớn hoặc có quyền hạn chế bị commit | Rò rỉ/vượt quyền sử dụng | `datasets/raw|processed` bị gitignore; chỉ mẫu nhỏ ở `samples/` |
| Look-ahead do dùng nhầm bar index | Kết quả đẹp giả tạo | Chỉ dùng nến đã đóng; test warm-up/boundary ở Phase 2–4 |
| Config hash/data fingerprint bị hiểu là bảo đảm tái lập | So sánh sai hai run khác code/dữ liệu | Comparability kiểm tra config hash, data fingerprint, code version và git commit; worktree dirty là warning |

## 3. Rủi ro mô phỏng và chi phí

- Spread, slippage và commission đã có trong `ExecutionConfig` của Phase 4, nhưng vẫn là giả định cố định;
  chưa mô hình hóa spread biến động theo thời gian, slippage theo thanh khoản hoặc commission theo lot.
- Không mô phỏng được đầy đủ thanh khoản, requote, latency, swap, gap cuối tuần và điều kiện broker thực tế.
- Thứ tự intrabar không biết từ OHLC; quy ước SL-first có thể làm kết quả khác thực tế.
- Trailing stop cập nhật theo bar đã đóng và chỉ có hiệu lực từ bar kế tiếp; đây là quy ước bảo thủ, không
  mô phỏng tick path, breakeven/step trailing hay trailing theo ATR. Fill khi gap vẫn dùng open của bar.
  Trailing mới chỉ có trong backtester Python, chưa có implementation MQL5/EA.
- Bounded DCA/grid giả định mọi layer khớp đúng level hoặc tại open khi gap; không mô hình hóa requote,
  partial fill, giới hạn volume hay việc broker từ chối lệnh. Loss cap là lỗ **ròng** nhưng gap qua stop
  có thể làm lỗ vượt cap; mức vượt được báo trong `hard_limits.loss_cap_overshoot`.
- Kết quả phụ thuộc mạnh vào khoảng thời gian, symbol và timeframe được chọn.
- Overfitting và p-hacking có thể xảy ra nếu chọn feature/threshold trên test set hoặc thử nhiều cấu hình
  trên cùng dữ liệu. Phase 7 chọn threshold trên out-of-fold validation và chỉ đánh giá test một lần,
  nhưng không loại bỏ được overfitting do con người lặp lại thí nghiệm trên cùng chuỗi.
- Sharpe/Sortino chỉ được báo khi định nghĩa return series, tần suất lấy mẫu và annualization rõ ràng.

### Rủi ro ML (Phase 7)

- **Dữ liệu synthetic:** demo 1.800 bar không đại diện thị trường; ROC-AUC/strategy metric chỉ minh họa
  pipeline, không phải bằng chứng tổng quát hóa.
- **Class imbalance:** accuracy có thể bị chi phối bởi lớp đa số; phải đọc balanced accuracy,
  precision/recall, confusion matrix và benchmark majority.
- **Nonstationarity/regime shift:** quan hệ feature–label có thể đổi theo thời gian; single holdout chỉ là
  một mẫu, không đảm bảo ổn định.
- **Threshold tuning:** threshold chọn trên OOF vẫn có thể overfit validation; grid 0.30–0.70 và
  tie-break gần 0.5 chỉ là quy ước.
- **Dead zone/horizon:** thay đổi `min_return` hoặc `horizon` làm đổi phân phối nhãn và kết quả; không có
  tham số nào được chứng minh tối ưu.
- **Metric phân loại ≠ lợi nhuận:** xác suất đúng cao không đảm bảo chiến lược có lãi sau spread,
  slippage và commission; demo hiện lỗ sau chi phí.
- **Mô phỏng chồng lấn:** bỏ qua dự đoán overlap là quy ước; chiến lược thay thế có thể cho kết quả khác.
- **Artifact JSON:** tái lập phụ thuộc đúng thứ tự feature, scaler mean/scale và phiên bản dependency;
  thay đổi scikit-learn có thể làm lệch coefficient dù cùng seed.
- **Không có live evidence:** không có kết luận hiệu năng live, không tăng position size dựa trên demo.

### Rủi ro ONNX (Phase 8)

- **Runtime chưa xác minh:** EA `LabOnnxInference.mq5` mới compile 0 errors/0 warnings; ONNX Runtime
  trong MT5 build 5.0.0.6249 chưa chạy. Compile không chứng minh `OnnxCreate`/`OnnxRun` hoạt động.
- **Khác biệt float32/float64:** parity offline đạt max abs diff `4.673e-08` với tolerance `1e-5` trên
  fixture, nhưng không phải bitwise; dữ liệu khác có thể lệch nhiều hơn hoặc vượt tolerance.
- **Thứ tự feature:** ONNX chỉ nhận vector số; hoán vị feature sẽ cho xác suất sai âm thầm. Thứ tự phải
  lấy từ `model_metadata.json` và khớp `feature_schema.json`.
- **Đường dẫn model:** EA dùng tên tương đối trong `MQL5/Files`; copy sai file/thư mục hoặc model cũ làm
  kết quả không khớp. Kiểm tra SHA-256 trong metadata trước khi chạy.
- **Opset/IR/provider:** chưa kiểm tra giới hạn opset/IR và CPU/GPU provider của build MT5; nâng cấp
  terminal hoặc onnx có thể phá vỡ tương thích.
- **Harness ≠ chiến lược:** EA chỉ đọc fixture tĩnh, không lấy feature từ bar hiện tại và không tạo tín
  hiệu. Không dùng log harness làm bằng chứng hiệu năng hay sẵn sàng live.
- **Không có execution:** không có `OrderSend`/`CTrade`; mọi mở rộng sang execution là quyết định phạm vi
  mới, không thuộc roadmap hiện tại.

### Rủi ro pipeline end-to-end (Phase 9)

- **Hai chiến lược, một dataset:** backtest EMA và ML logistic chạy trên cùng dữ liệu nhưng không phải
  một chiến lược thống nhất; báo cáo không được cộng gộp hoặc so sánh như cùng hệ thống.
- **ID bất biến:** pipeline dùng `<id>-backtest`/`<id>-ml`; chạy lại cùng ID bị từ chối. Báo cáo tổng hợp
  cũng không bị ghi đè, nên muốn chạy mới phải dùng `--run-id` khác.
- **Lệch dataset giữa stage:** pipeline kiểm tra đường dẫn/`data_kind`/symbol/timeframe trước khi chạy;
  nếu cấu hình bị sửa thủ công giữa hai stage, kết quả có thể không còn so sánh được.
- **Tái lập chưa gắn commit chính thức:** đã xác minh trên snapshot commit sạch tạm thời (116 file,
  commit `d3a9ea39…`, `git status` rỗng): test, metric, data SHA-256 và model SHA-256 khớp; ONNX parity
  pass. Tuy nhiên worktree hiện vẫn dirty nên chưa có commit hash chính thức. Phải commit và lặp lại
  ngắn theo checklist trước khi dùng làm baseline.
- **Báo cáo tổng hợp chỉ chọn metric:** không thay thế `summary.json`/trades/equity của từng stage; muốn
  audit phải đọc artifact gốc.
- **Store cục bộ:** hai row demo trong SQLite không mã hóa; mất file là mất metadata, phải backup thủ công.
- **Không bao gồm ONNX/MT5:** pipeline dừng ở Python; compile/runtime MQL5 và ONNX Runtime vẫn là hạng
  mục thủ công của Phase 8.

### Rủi ro bounded DCA/grid

- **Cap không bảo đảm lỗ tối đa:** `max_basket_loss` là lỗ ròng theo giá stop tính từ average entry;
  gap qua stop, slippage lớn hơn cấu hình hoặc commission thay đổi có thể làm lỗ vượt cap. Phải đọc
  `loss_cap_overshoot` và `hard_limits` trong summary, không chỉ đọc config.
- **Không có margin/leverage:** simulator không mô hình margin, margin call, stop-out, swap hay giới hạn
  ký quỹ. Nhiều layer cùng lúc có thể bị coi là “an toàn” trong mô phỏng dù tài khoản thật không đủ ký quỹ.
- **Một basket tại một thời điểm:** không có nhiều basket song song, không có portfolio/multi-symbol;
  kết quả không mô tả chiến lược grid chạy đồng thời trên nhiều cặp.
- **Metric per-layer:** `trade_count`, `win_rate`, `profit_factor`, `exit_reason_counts` tính trên từng
  layer; một basket nhiều layer tạo nhiều row và không được đọc như nhiều trade độc lập. Số basket và lý
  do đóng basket nằm ở `basket_count`/`basket_exit_reason_counts`.
- **Thứ tự intrabar:** exit được kiểm tra trước add và loss cap thắng TP khi cùng bar; OHLC không cho biết
  thứ tự thật. Layer mới chỉ ảnh hưởng level từ bar kế tiếp, nên kết quả có thể khác bot chạy tick.
- **Simulator Python và EA MQL5 là hai implementation riêng:** từ W3–W5 đã có EA MQL5 mô phỏng bounded
  grid/DCA/runner, nhưng chưa chạy Strategy Tester; Python và MQL5 chưa được đối chiếu trên cùng chuỗi
  tick. CLI Python vẫn không ghi experiment store; không dùng demo synthetic làm bằng chứng hiệu năng
  hay sẵn sàng live.

### Rủi ro simulation MQL5 (Track C: runner/grid/DCA/plan)

- **Vị thế ảo không phải vị thế tài khoản:** `CSimPortfolio` giữ position trong bộ nhớ; không có margin,
  margin call, stop-out, swap, commission thật hay giới hạn volume của broker. Equity chỉ là mô hình.
- **Contract size = 1:** một đơn vị volume sinh lời/lỗ đúng một đơn vị tiền báo giá cho mỗi đơn vị giá;
  không khớp contract size của phần lớn symbol forex. Không dùng P&L mô phỏng để suy ra lot thật.
- **Cap không bảo đảm lỗ tối đa:** gap qua stop, slippage cấu hình thấp hơn thực tế hoặc spread mở rộng
  có thể làm lỗ vượt kỳ vọng; daily loss/drawdown tính trên equity mô phỏng, không phải equity broker.
- **Logger append:** `SimLogger` mở `FILE_READ|FILE_WRITE` và ghi nối; dùng lại `InpLogFile` sẽ trộn nhiều
  lần chạy. Phải dùng tên file riêng cho mỗi run và kiểm tra header/số dòng.
- **Preset JSON không được EA đọc trực tiếp:** EA nhận input trên chart/tester; JSON chỉ là nguồn kiểm tra
  và snapshot. Nhập sai một input là sai cấu hình dù validator đã pass cho file JSON.
- **Runtime evidence một phần:** `SimCoreTests` 123/0 và `SimPlanTests` 39/0 đã chạy thật trong MT5 ngày
  2026-10-28; 15 scenario Strategy Tester (5 EA) vẫn `NOT_RUN`. Test vector không chứng minh EA chạy đúng trên
  dữ liệu thị trường, không đo spread/slippage thực và không thay thế report tester.
- **Không có execution:** năm EA không có API gửi lệnh; Strategy Tester hiển thị 0 deal là đúng. Mọi nỗ
  lực “chạy bot trên Exness” theo nghĩa đặt lệnh nằm ngoài repo này và cần ADR riêng.
- **Plan của indicator không phải lệnh thật:** `PinePlanSimEA` khớp tại ask/bid hiện tại, không khớp
  `plan.entry`; SL/target lấy nguyên từ plan và có thể đã lỗi thời so với giá khi EA đọc. `ref_entry`
  trong log chỉ để đối chiếu. Target fill không credit gap có lợi, nên kết quả có thể kém hơn kỳ vọng.
- **EA dùng default input của indicator:** `iCustom` không truyền tham số; đổi cấu hình indicator phải
  sửa default hoặc tạo EA riêng. Kết quả có thể khác chart đang dùng cấu hình tùy chỉnh.
- **Chỉ ba nguồn plan:** LongKaco VSA và TM Fusion Zones không được đưa vào `PinePlanSimEA` vì có máy
  trạng thái riêng; dùng EA signal-only/indicator trực tiếp, không suy diễn hành vi plan.

### Rủi ro execution và “chạy trên Exness MT5”

- **Không có đường thực thi lệnh:** repository không chứa `OrderSend`, `CTrade.Buy/Sell`,
  `OrderModify/Delete`, `PositionOpen/Close` hay bất kỳ lệnh môi giới nào. `LabSignalEA` chỉ ghi tín hiệu;
  0 trade trong Strategy Tester là hành vi đúng, không phải lỗi. Xem `docs/decisions/0002-execution-boundary.md`.
- **“Chạy trên MT5” hiện chỉ nghĩa là harness offline:** compile, self-check signal engine, export parity,
  ONNX runtime harness và Strategy Tester với dữ liệu offline. Không có bước nào đặt lệnh.
- **Không đăng nhập tài khoản:** không dùng login/password/investor password/OTP; nếu terminal hiện hộp
  thoại đăng nhập thì Cancel. Không lưu credential trong config, log, report hay Git.
- **Kết quả compile không phải kết quả runtime:** 24 file `.mq5` compile 0 errors/0 warnings ngày
  2026-10-28; `SimCoreTests` và `SimPlanTests` đã PASS runtime, nhưng self-check, parity export, ONNX
  runtime và Strategy Tester **chưa chạy**. Compile chỉ chứng minh cú pháp, không chứng minh hành vi.
- **Bot live là phạm vi mới, không phải bước tiếp theo của roadmap:** muốn có execution phải lập ADR mới
  với tối thiểu: chỉ tài khoản demo, dry-run mặc định, một vị thế, SL/TP bắt buộc, giới hạn lot/risk,
  max daily loss, kill switch, không martingale/grid/DCA ở giai đoạn đầu, test Strategy Tester/demo trước.
  Không có các safeguard này thì không được thêm execution.
- **Rủi ro nếu bỏ qua ranh giới:** chạy EA có execution trên tài khoản thật khi chưa có parity runtime,
  chưa có Strategy Tester và chưa có kill switch có thể gây lỗ ngoài kiểm soát, vi phạm giới hạn đòn bẩy
  của broker và không thể tái lập. Đây là lý do ranh giới hiện tại là signal-only.
- **Copy file sang Data Folder là thủ công:** ADR 0001 loại bỏ script tự động ghi vào thư mục MT5. Lần
  sync ngày 2026-10-28 do người dùng yêu cầu và thực hiện một lần; không có script trong repo lặp lại
  thao tác này, và mọi lần copy sau vẫn phải thủ công, có kiểm tra đường dẫn.

## 4. Rủi ro kỹ thuật và môi trường

| Rủi ro | Trạng thái hiện tại | Ghi chú |
|---|---|---|
| MT5/MetaEditor thay đổi theo build | Đã xác minh build 5.0.0.6249 (EXNESS) khi compile ngày 2026-10-28 | Phải xác minh lại nếu terminal cập nhật build |
| Agent không có kết quả Strategy Tester thật | Compile 0 errors/0 warnings cho 24 file `.mq5` ngày 2026-10-28; `SimCoreTests` 123/0 và `SimPlanTests` 39/0 PASS runtime; Strategy Tester **chưa chạy** | Cần chạy Strategy Tester/self-check/parity/ONNX thủ công; giữ `READY_FOR_MANUAL_VALIDATION` cho EA |
| OS là Windows 10, roadmap khuyến nghị Windows 11 | Đã ghi nhận | Không chặn các phase hiện tại; theo dõi lỗi đặc thù MT5 |
| Khác biệt indicator MQL5 và Python | Cửa sổ EMA đã thống nhất `slow+1` và có comparator; MQL5 export chưa chạy | Chạy export thủ công và so sánh toàn bộ fixture trước khi tuyên bố tương đương |
| Parity bị suy rộng quá mức | Comparator chỉ so sánh đúng hai file; self-comparison không phải parity | Ghi rõ rows_compared, fixture và trạng thái MQL5 runtime trong báo cáo |
| MQL5 CSV exporter chỉ hỗ trợ CSV đơn giản | Field có dấu phẩy/quote sẽ parse sai | Fixture parity không dùng quoted comma; kiểm tra header và fail closed |
| ONNX/ONNX Runtime tương thích MT5 | Export + parity offline pass; EA compile 0/0; runtime **chưa chạy** | Giữ `READY_FOR_MANUAL_VALIDATION`; chạy `LabOnnxInference` và đối chiếu log trước khi kết luận |
| Tên menu MT5 khác theo ngôn ngữ/build | Chưa kiểm tra GUI | Hướng dẫn thủ công ghi rõ điều kiện |
| Dependency Python trôi phiên bản | Pin trong `requirements.txt` | Cập nhật có chủ đích, ghi lại lý do |
| Tự nâng cấp pip không hoàn tất trên máy kiểm thử | Đã dừng; venv dùng pip 24.0 và cài dependency thành công | Không chặn các phase hiện tại; chỉ thử lại khi cần |
| Matplotlib không ghi được cache mặc định | Plot dùng `.mplconfig` trong report dir | Tránh ghi cache vào thư mục hệ thống |
| Temp dir của pip/pytest rơi vào repo | Do `TMP=/tmp` không hợp lệ với Python Windows | Đã ignore `pip-*`, `pytest-of-*`, `tmpsnub_*` |
| Run bị kill để lại trạng thái `running` | Store không tự phát hiện process đã chết; ID bị khóa | `mark_interrupted` thủ công; dùng ID mới nếu cần; chưa có heartbeat |
| So sánh run trong worktree dirty | Code thực tế có thể khác commit đã ghi | Comparability vẫn cho phép nhưng phát warning `dirty_worktree`; không dùng làm bằng chứng tái lập mạnh |
| Config hash bỏ qua đường dẫn/output/notes | Hai run khác output vẫn comparable | Có chủ đích; dữ liệu được kiểm tra bằng fingerprint byte-level |
| Data fingerprint là byte-level | Cùng nội dung nhưng khác định dạng file sẽ không comparable | Ghi rõ; chưa có canonical dataframe fingerprint |
| SQLite cục bộ, không mã hóa | Mất file/không backup thì mất metadata; ai đọc được file thì đọc được config/notes | `experiments/` bị gitignore; sao lưu thủ công; không lưu secret trong config/notes |
| Nhiều process ghi đồng thời | Chưa kiểm thử; SQLite có locking nhưng hành vi chưa xác minh | Chạy tuần tự; kiểm thử concurrency trước khi dùng nhóm |
| Phiên bản scikit-learn thay đổi | Coefficient/model hash và metric có thể lệch dù cùng seed | Pin dependency; `model.json` ghi phiên bản; chạy lại test tái lập trước khi so sánh |
| Artifact model JSON bị sửa/hỏng | Dự đoán sai hoặc crash | `load_model` validate schema, số feature, scale dương và giá trị hữu hạn; fail closed |
| File ONNX bị thay thế/hỏng | EA dùng model sai hoặc `OnnxCreate` lỗi | `model_metadata.json` ghi SHA-256; đối chiếu trước khi copy; EA fail init nếu ONNX lỗi |
| Threshold chọn trên test | Kết quả đẹp giả tạo | Threshold chỉ chọn trên OOF validation; test đánh giá một lần; ghi rõ trong summary/model card |
| Feature/label lệch thứ tự hay thiếu cột | Dự đoán sai âm thầm | `feature_schema.json` + tên feature trong model; `predict` từ chối thiếu/thừa feature |

## 5. Rủi ro bảo mật và vận hành

- Không commit `.env`, token, mật khẩu, investor password, `accounts.dat`, `servers.dat` hoặc log tài khoản.
- Không đặt secret trong config, `notes` hay artifact: experiment store lưu `config_json`, `notes` và
  đường dẫn artifact, nên bất kỳ ai đọc file SQLite/report đều đọc được các field này.
- Không chạy executable/script tải từ nguồn không được duyệt; không tự đổi firewall/antivirus/PATH.
- Repository mới có commit đầu tiên; các thay đổi Phase 1–9, trailing stop và bounded DCA/grid đang ở
  working tree và do người dùng quyết định thời điểm commit. Chưa có remote; việc push là quyết định
  riêng của người dùng.
- Nếu phát hiện secret trong working tree, dừng lại, gỡ khỏi file và báo cáo; không commit.
- Mọi mở rộng sang execution phải là quyết định phạm vi mới, không nằm trong roadmap hiện tại.

## 6. Điều kiện để tiếp tục phase

- Phase chỉ được đánh dấu `DONE` khi deliverable và acceptance criteria đạt, test thực tế đã chạy và ghi lại.
- Nếu thiếu MT5/MetaEditor, phase MQL5 chỉ được đánh dấu `READY_FOR_MANUAL_VALIDATION`.
- Không bắt đầu phase tiếp theo nếu báo cáo phase hiện tại còn blocker chưa xử lý.
