# Internal release checklist — MT5 EA & AI Lab

- **Ngày:** 2026-10-28 (cập nhật sau Track C W1–W9)
- **Phạm vi:** bản nghiên cứu offline (Phase 0–9 + trailing stop + bounded DCA/grid + 4 EA mô phỏng).
  Không phải sản phẩm giao dịch và không có execution.
- **Quy tắc:** không release nếu bất kỳ mục “Bắt buộc” nào chưa đạt. Mục “Thủ công” có thể để mở nhưng
  phải ghi rõ trạng thái trong báo cáo.

## 1. Bắt buộc

| # | Kiểm tra | Cách xác minh | Trạng thái |
|---|---|---|---|
| 1 | Test Python xanh | `.\.venv\Scripts\python.exe -m pytest -q` | Đạt: 324 passed |
| 2 | Không lỗi cú pháp | `python -m compileall -q python/src python/tests scripts` | Đạt: exit 0 |
| 3 | Dependency nhất quán | `python -m pip check` | Đạt: no broken requirements |
| 4 | Không có execution | grep `OrderSend`, `CTrade`, `PositionOpen/Close`, `CExpert` | Đạt: không có match |
| 5 | Không có secret/credential | Không có `.env`, token, password, `accounts.dat`, `servers.dat` trong repo | Đạt: kiểm tra thủ công |
| 6 | Không kết nối broker | Không có login/`AccountInfo*`/WebRequest tới broker | Đạt: mã nguồn |
| 7 | Pipeline end-to-end chạy được | `scripts\run_pipeline.py --config configs\pipeline.example.yaml` | Đạt: exit 0, báo cáo demo |
| 8 | Fail-safe dữ liệu/model | Test pipeline + ONNX missing model | Đạt: exit 1/2/4, không ghi đè |
| 9 | Kết quả gắn nhãn demo/synthetic | `pipeline_report.md` có mục Demo + Limitations | Đạt |
| 10 | Tài liệu giới hạn rõ | `docs/reference/risk.md`, `docs/reference/pipeline.md` | Đạt |
| 11 | Artifact không bị commit nhầm | `reports/`, `experiments/`, `models/candidates/`, `.ex5`, `.onnx` gitignored | Đạt |
| 12 | Không quảng bá hiệu năng | Không có claim lợi nhuận/live trong README/docs | Đạt |
| 13 | Bounded DCA/grid chạy và cap quan sát được | `scripts\run_basket_backtest.py` với hai config mẫu | Đạt: exit 0; DCA 57 basket/cap layer 4, grid loss cap 20 với `loss_cap_overshoot` 0 |
| 14 | Ranh giới execution được ghi nhận | `docs/decisions/0002-execution-boundary.md`, `docs/guides/install-and-test.md`, README | Đạt: ADR Accepted; guide nêu signal-only, 0 trade là đúng |
| 15 | Không có credential/account ID trong docs/log | Review `git diff` và log MT5 trước commit | Đạt: log compile không chứa account/server |
| 16 | Preset Track C fail-closed | `scripts\validate_sim_configs.py` | Đạt: checked=5 fail=0; snapshot bất biến |
| 17 | Build MQL5 toàn bộ | `scripts\build-mql5.ps1` | Đạt: 24 source, 0 errors, 0 warnings |
| 18 | Static scan toàn project | `scripts\validate-project.py` | Đạt: checks=10 fail=0; 43 source không có API giao dịch/placeholder |
| 19 | Package source loại artifact | `scripts\package-source.ps1 -Version <x.y.z>` | Đạt: không có `.venv`, `.ex5`, log, report trong zip; manifest SHA256 |

## 2. Thủ công (ghi trạng thái, không chặn bản nghiên cứu)

| # | Kiểm tra | Trạng thái |
|---|---|---|
| 1 | Compile 24 file `.mq5` | Đạt 2026-10-28 bằng `scripts\build-mql5.ps1`: 0 errors/0 warnings; MetaEditor CLI trả exit 1 dù thành công (đọc log, không đọc exit code) |
| 2 | MT5 Strategy Tester cho `LabSignalEA` | Chưa chạy; kỳ vọng 0 trade vì EA signal-only |
| 3 | `LabSignalExport` + parity MQL5/Python | Chưa chạy MQL5 export |
| 4 | `LabOnnxInference` + parity runtime ONNX | Chưa chạy; compile 0/0 |
| 5 | Tái lập sau checkout commit sạch | Đã xác minh snapshot Phase 9 (2026-10-28): 155 test pass, metric/data SHA/model SHA khớp, duplicate exit `4`, ONNX parity PASS. Trailing stop + bounded DCA/grid + Track C (324 test) chưa lặp lại trên commit sạch; chờ commit chính thức |
| 6 | `SimCoreTests` trong MT5 | **PASS** 2026-10-28: `TEST|RESULT|ALL_PASS|pass=123 fail=0|suite=sim_core` (tab Experts, terminal EXNESS chưa đăng nhập) |
| 6b | `SimPlanTests` trong MT5 | **PASS** 2026-10-28: `TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan`; lần chạy đầu phát hiện 8 vector sai đơn vị point và 1 lỗi biên số thực, đã sửa `SimPlanTests.mq5` + `SimPlan.mqh` rồi chạy lại |
| 7 | Strategy Tester cho 4 EA mô phỏng (12 scenario) | `NOT_RUN`; hướng dẫn + template ở `docs/guides/strategy-tester.md` |
| 8 | CSV thật của runner/grid/DCA/plan | `NOT_RUN`; chỉ có vector và test tĩnh |

## 3. Trước khi commit/tag

1. Review `git status`; chỉ stage file nguồn/config/docs, không stage report/database/model.
2. Kiểm tra `git diff` không chứa đường dẫn tuyệt đối, terminal ID, account ID hay secret.
3. Chạy lại mục 1.1–1.3 sau thay đổi cuối.
4. Commit Phase 0–9, trailing stop, bounded DCA/grid, Track C W1–W9 và ADR 0002; ghi commit hash vào báo
   cáo phase nếu cần.
5. Sau commit, lặp lại tái lập trên commit sạch theo `docs/reference/pipeline.md` mục 7; snapshot sạch đã đạt
   ngày 2026-10-28, chỉ cần xác nhận lại với commit hash chính thức và cập nhật checklist này.
6. Backup `experiments/*.sqlite` và `reports/` nếu cần lưu kết quả lâu dài (gitignored).

## 4. Không được làm khi release

- Không bật execution, không thêm `OrderSend`/`CTrade`, không tự mở/đóng lệnh.
- Không kết nối Exness hoặc bất kỳ tài khoản broker nào; không đăng nhập, không lưu credential.
- Không thêm bot live/grid/DCA chạy tài khoản thật dưới danh nghĩa “chạy trên MT5”. Execution là phạm vi
  mới cần ADR riêng, chỉ demo và có safeguard (xem ADR 0002).
- Không thêm script tự động copy/sync file vào MT5 Data Folder; sync là thao tác thủ công có tài liệu.
- Không commit mật khẩu, investor password, OTP, token hay file phiên.
- Không tuyên bố compile/backtest/parity/ONNX runtime thành công nếu chưa có log/kết quả thật.
- Không biến kết quả synthetic thành cam kết hiệu năng.
