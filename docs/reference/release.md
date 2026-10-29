# Internal release checklist — MT5 EA & AI Lab

- **Ngày:** 2026-10-29 (bổ sung scope demo execution theo ADR 0003)
- **Phạm vi:** bản nghiên cứu offline (Phase 0–9 + trailing stop + bounded DCA/grid + 5 EA mô phỏng) và
  **demo execution có guardrail** (`PATrendRiderXAUv1DemoEA`). Không phải sản phẩm giao dịch; không có
  execution trên tài khoản real/live.
- **Quy tắc:** không release nếu bất kỳ mục “Bắt buộc” nào chưa đạt. Mục “Thủ công” có thể để mở nhưng
  phải ghi rõ trạng thái trong báo cáo.

> **Lưu ý (2026-10-29):** các con số trong checklist này là lần đóng gói **0.10.0** — 29 source `.mq5`
> compile 0/0, `validate-project.py checks=14`, `validate_sim_configs.py checked=7` (6 preset, 17 scenario),
> `validate_trendrider.py checks=7`, `validate_demo_execution.py checks=6`, pytest 358 passed. Bằng chứng
> chi tiết và nhật ký phiên demo thật nằm ở [`../PROGRESS.md`](../PROGRESS.md) §42–§43. Chiến lược
> `WonderwhalesSimEA` và 12 scenario Strategy Tester cũ vẫn giữ nguyên kết quả.

## 1. Bắt buộc

| # | Kiểm tra | Cách xác minh | Trạng thái |
|---|---|---|---|
| 1 | Test Python xanh | `.\.venv\Scripts\python.exe -m pytest -q` | Đạt: 358 passed |
| 2 | Không lỗi cú pháp | `python -m compileall -q python/src python/tests scripts` | Đạt: exit 0 |
| 3 | Dependency nhất quán | `python -m pip check` | Đạt: no broken requirements |
| 4 | Execution chỉ trong scope demo | `validate-project.py` + `validate_demo_execution.py`: trading API chỉ nằm trong `mt5/Include/Exec/*` và `PATrendRiderXAUv1DemoEA` | Đạt: 0 API ngoài scope; guard test compile 0/0 |
| 5 | Không có secret/credential | Không có `.env`, token, password, `accounts.dat`, `servers.dat` trong repo | Đạt: kiểm tra thủ công |
| 6 | Không kết nối broker | Không có login/`WebRequest`/socket; `AccountInfo*` chỉ đọc trade-mode trong guard demo | Đạt: mã nguồn |
| 7 | Pipeline end-to-end chạy được | `scripts\run_pipeline.py --config configs\pipeline.example.yaml` | Đạt: exit 0, báo cáo demo |
| 8 | Fail-safe dữ liệu/model | Test pipeline + ONNX missing model | Đạt: exit 1/2/4, không ghi đè |
| 9 | Kết quả gắn nhãn demo/synthetic | `pipeline_report.md` có mục Demo + Limitations | Đạt |
| 10 | Tài liệu giới hạn rõ | `docs/reference/risk.md`, `docs/reference/pipeline.md` | Đạt |
| 11 | Artifact không bị commit nhầm | `reports/`, `experiments/`, `models/candidates/`, `.ex5`, `.onnx` gitignored | Đạt |
| 12 | Không quảng bá hiệu năng | Không có claim lợi nhuận/live trong README/docs | Đạt |
| 13 | Bounded DCA/grid chạy và cap quan sát được | `scripts\run_basket_backtest.py` với hai config mẫu | Đạt: exit 0; DCA 57 basket/cap layer 4, grid loss cap 20 với `loss_cap_overshoot` 0 |
| 14 | Ranh giới execution được ghi nhận | `docs/decisions/0003-demo-execution-scope.md`, `docs/guides/demo-execution.md`, README, AGENTS.md | Đạt: ADR Accepted; guide nêu demo-only, dry-run, kill switch, 0 trade là đúng |
| 15 | Không có credential/account ID trong docs/log | Review `git diff` và log MT5 trước commit | Đạt: log compile không chứa account/server |
| 16 | Preset Track C fail-closed | `scripts\validate_sim_configs.py` | Đạt: checked=7 fail=0 (6 preset, 17 scenario); snapshot bất biến |
| 16b | Preset demo fail-closed | `scripts\validate_demo_execution.py` | Đạt: checks=6 fail=0; DEMO_ONLY, `InpEnableExecution=false`, TP bắt buộc, magic tách khỏi bản mô phỏng |
| 16c | Guard contract test | Compile + chạy `mt5\Scripts\ExecGuardTests.mq5` | Compile 0/0; **runtime PASS** 2026-10-29 (xem mục 10) |
| 17 | Build MQL5 toàn bộ | `scripts\build-mql5.ps1` | Đạt: 29 source, 0 errors, 0 warnings (2026-10-29) |
| 18 | Static scan toàn project | `scripts\validate-project.py` | Đạt: checks=14 fail=0; 62 source không có API giao dịch ngoài scope/placeholder |
| 19 | Package source loại artifact | `scripts\package-source.ps1 -Version <x.y.z>` | Đạt: không có `.venv`, `.ex5`, log, report trong zip; manifest SHA256 |

## 2. Thủ công (ghi trạng thái, không chặn bản nghiên cứu)

| # | Kiểm tra | Trạng thái |
|---|---|---|
| 1 | Compile 29 file `.mq5` | Đạt 2026-10-29 bằng `scripts\build-mql5.ps1` với MetaEditor bản Exness: 0 errors/0 warnings; MetaEditor CLI trả exit 1 dù thành công (đọc log, không đọc exit code) |
| 2 | MT5 Strategy Tester cho `LabSignalEA` | Chưa chạy; kỳ vọng 0 trade vì EA signal-only |
| 3 | `LabSignalExport` + parity MQL5/Python | Chưa chạy MQL5 export |
| 4 | `LabOnnxInference` + parity runtime ONNX | Chưa chạy; compile 0/0 |
| 5 | Tái lập sau checkout commit sạch | Đã xác minh snapshot Phase 9 (2026-10-28): 155 test pass, metric/data SHA/model SHA khớp, duplicate exit `4`, ONNX parity PASS. Trailing stop + bounded DCA/grid + Track C (324 test) chưa lặp lại trên commit sạch; chờ commit chính thức |
| 6 | `SimCoreTests` trong MT5 | **PASS** 2026-10-28: `TEST|RESULT|ALL_PASS|pass=123 fail=0|suite=sim_core` (tab Experts, terminal EXNESS chưa đăng nhập) |
| 6b | `SimPlanTests` trong MT5 | **PASS** 2026-10-28: `TEST|RESULT|ALL_PASS|pass=39 fail=0|suite=sim_plan`; lần chạy đầu phát hiện 8 vector sai đơn vị point và 1 lỗi biên số thực, đã sửa `SimPlanTests.mq5` + `SimPlan.mqh` rồi chạy lại |
| 7 | Strategy Tester cho 4 EA mô phỏng (12 scenario) | **PASS một phần** 2026-10-28: 10/10 scenario runner/grid/DCA có SUMMARY; 2 `plan_*` `BLOCKED_PERFORMANCE` (1 tháng chẩn đoán 197 s, 0 entry) |
| 8 | CSV thật của runner/grid/DCA/plan | Có CSV thật cho 10 scenario (archived, gitignored); DCA `adds=0` là bug reporting, CSV chứng minh 2 add |
| 9 | Contract test 6 indicator trong Strategy Tester | **PASS 6/6** (547 check) 2026-10-28; 3 bug implementation đã sửa |
| 10 | `ExecGuardTests` trong MetaEditor | **PASS** 2026-10-29: `TEST\|BEGIN\|suite=execguard` → `TEST\|G1..G51\|PASS` → `TEST\|RESULT\|ALL_PASS\|pass=51 fail=0\|suite=execguard` (log `MQL5\Logs\20261029.log`, chạy như script trên chart XAUUSDm,M5). Script là synthetic: không gọi `OrderSend`, không đọc thông tin tài khoản — nên PASS này chứng minh **ma trận guard**, không chứng minh đường gửi lệnh thật của `ExecBroker.mqh` |
| 11 | Dry-run `PATrendRiderXAUv1DemoEA` trên demo | **PASS** 2026-10-29 trên demo `464140826` (Exness-MT5Trial17, hedge): `INIT mode=DRY_RUN`, một `RISK ENTRY_BLOCKED reason=bias_unknown`, `SUMMARY entries=0 exits=0 net=0.00`, tab Trade trống. Lưu ý: dry-run không khởi tạo được khi nút Algo Trading của terminal tắt (`scope_rejected|terminal_trade_disabled`) |
| 12 | Demo execution một phiên có giám sát | **ĐANG CHẠY** 2026-10-29: `InpEnableExecution=true`, `INIT mode=DEMO_EXECUTION config_hash=6B439450`, `restored=1`. CSV `pa_trendrider_demo.csv` có sự kiện cấu trúc thật (`BOS tf=M5 event=BOS_BEAR`) và hai `RISK ENTRY_BLOCKED reason=regime_range` — EA sống, chặn đúng luật, chưa có `ENTRY`/`EXIT`. Kill switch mới được kiểm ở mức token (`G46`: `ExecBlockName(EXEC_BLOCK_KILL_SWITCH)=="kill_switch_active"`), chưa thử bằng file `PA_TREND_RIDER_DEMO_STOP.txt` thật. Kết luận phiên chỉ ghi khi có bằng chứng thật |

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

- Không bật execution ngoài `PATrendRiderXAUv1DemoEA`; không thêm `OrderSend`/`CTrade` vào EA mô phỏng
  hay module khác. Không mở đường live/real dưới bất kỳ tên nào.
- Không kết nối broker, không đăng nhập, không lưu credential; `AccountInfo*` chỉ được đọc trade-mode
  trong `ExecGuard` path.
- Không thêm bot live/grid/DCA chạy tài khoản thật dưới danh nghĩa “chạy trên MT5”. Demo execution có
  guardrail theo ADR 0003; live vẫn cần ADR mới.
- Không thêm script tự động copy/sync file vào MT5 Data Folder; sync là thao tác thủ công có tài liệu.
- Không commit mật khẩu, investor password, OTP, token hay file phiên.
- Không tuyên bố compile/backtest/parity/ONNX runtime thành công nếu chưa có log/kết quả thật.
- Không biến kết quả synthetic thành cam kết hiệu năng.
