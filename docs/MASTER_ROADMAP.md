# Lộ trình tổng hợp — MT5 EA Lab / PinePort / Simulation EA

- **Ngày lập:** 2026-10-28
- **Nguồn đã đọc:** toàn bộ `docs/MT5_AI_Roadmaps/` (10 file: 3 roadmap, 3 prompt, strategy spec,
  risk/validation, install/test, index) cùng `docs/PROGRESS.md`, `docs/indicators/README.md` và cây mã nguồn.
- **Phạm vi:** chỉ nghiên cứu, mô phỏng, backtest và signal-only. Không execution, không broker, không
  credential. Mọi trạng thái bên dưới phản ánh bằng chứng đã chạy thật; không suy diễn từ tài liệu.

## 1. Ba track và trạng thái thực tế

| Track | Roadmap nguồn | Đã xong | Còn lại |
|---|---|---|---|
| **A. MT5 EA & AI Lab** | `ROADMAP_MT5_EA_AI_LAB.md` | Phase 0–9: `LabSignalEA`, `Indicators/SignalEngine`, data pipeline, backtester, comparator, SQLite store, ML baseline, ONNX + `LabOnnxInference`, pipeline end-to-end; Python trailing stop và bounded DCA/grid | Chạy pipeline trên dữ liệu MT5 thật (`BLOCKED` — chưa export history); manual Strategy Tester |
| **B. Pine → MT5** | `ROADMAP_PINE_TO_MT5_EA.md` | 6 indicator PinePort (Wonderwhales, LongKacoVSA, TMFusionZones, PriceActionMTF, TMXAUSignals2, TMIndicator2): spec, repaint audit, buffer contract, MQL5 indicator + contract tests, compile 0/0; 2 EA signal-only; 2 comparator parity + audit CSV | Chạy contract tests/indicator/EA trong MT5 (`NOT_RUN`); parity dữ liệu thật (`BLOCKED` — chưa có CSV Pine); Strategy Tester (`NOT_RUN`) |
| **C. Simulation Grid/DCA/Runner** | `ROADMAP_GRID_DCA_TRAILING_SIMULATION.md` | Phase 0 (docs/skeleton trong pack); Python trailing + bounded basket simulator có test | **Toàn bộ MQL5: `RiskGuard`, `CostModel`, `VirtualPortfolio`, `RunnerTrailingLabEA`, `GridLabEA`, `DCALabEA`, preset/config, script build/test, Strategy Tester** |

Kết luận: Track A và B đã hết việc code tự động; phần còn lại là runtime thủ công hoặc dữ liệu người dùng.
**Track C là track duy nhất còn khối lượng code lớn và không bị chặn bởi dữ liệu ngoài.**

## 2. Nguyên tắc thứ tự

1. **Nền tảng trước chiến lược:** RiskGuard/CostModel/VirtualPortfolio dùng chung phải xong trước ba EA,
   để không EA nào tự định nghĩa lại giới hạn.
2. **Một việc một lượt:** mỗi work item có file, test và acceptance criteria riêng; xong mới sang việc kế.
3. **Không chặn chéo:** việc cần người dùng (runtime MT5, CSV Pine) được tách sang nhánh chờ, không kéo
   lùi phần code có thể làm ngay.
4. **Không báo PASS khống:** compile chỉ tính khi MetaEditor CLI thật sự trả 0 error/0 warning; backtest chỉ
   tính khi có report thật. Thiếu môi trường → `NOT_RUN`/`BLOCKED`.
5. **Fail-closed:** config khác `SIMULATION_ONLY` hoặc phát hiện API gửi lệnh → dừng, không chạy.

## 3. Lộ trình tuần tự

| ID | Phase | Việc chính | Deliverable | Acceptance | Phụ thuộc |
|---|---|---|---|---|---|
| **W1** | C-Phase 1 | Hoàn tất nền tảng kiểm thử MQL5: chuẩn hóa input, logger schema cố định, `VirtualPortfolio` trong bộ nhớ | `mt5/Include/Sim/SimPortfolio.mqh`, `SimLogger.mqh`; script test | Input âm/NaN/max=0 bị từ chối; portfolio tính average entry/P&L/exposure đúng ví dụ tay; compile 0/0 | — |
| **W2** | C-Phase 2 | `RiskGuard` + `CostModel` dùng chung | `SimRiskGuard.mqh`, `SimCostModel.mqh`; `SimCoreTests.mq5` | Từng cap có test; drawdown/daily loss theo equity; kill switch `HALTED`; spread/commission/slippage ghi riêng giả định | W1 |
| **W3** | C-Phase 3 | `RunnerTrailingLabEA.mq5` — một vị thế ảo, breakeven + trailing fixed/ATR | EA + test vector + preset | SL long không giảm/short không tăng; gap qua SL ghi slippage; không nới SL; compile 0/0 | W2 |
| **W4** | C-Phase 4 | `GridLabEA.mq5` — grid fixed/ATR, level cap, exposure cap, basket exit | EA + test vector + preset | Không vượt `MaxGridLevels`/`MaxVirtualExposure` dù nhiều trigger; trend một chiều bị chặn đúng cap | W2 |
| **W5** | C-Phase 5 | `DCALabEA.mq5` — DCA theo giá/thời gian, add cap, basket P&L | EA + test vector + preset | Không add khi chạm bất kỳ cap; P&L basket khớp tính tay/Python; không "gồng vô hạn" | W2 |
| **W6** | C-Phase 6 | Preset/config cho 3 EA | `configs/sim/*.json`, validator mở rộng | Validator chỉ nhận `SIMULATION_ONLY`, `allow_live_trading=false`; snapshot config vào report | W3–W5 |
| **W7** | C-Phase 7 | Script root dùng chung: check env, build MQL5, chạy pytest, validate project, package | `scripts/check-environment.ps1`, `build-mql5.ps1`, `run-python-tests.ps1`, `validate-project.py`, `package-source.ps1` | Build fail nếu thiếu MetaEditor/log; validator quét `.mq5` chặn API giao dịch; package loại `.venv`/log | W6 |
| **W8** | C-Phase 8 | Chạy Strategy Tester thủ công cho 3 EA | Report template + hướng dẫn | Có report thật cho từng EA/kịch bản stress; nếu chưa chạy ghi `NOT_RUN` | W7 + MT5 |
| **W9** | C-Phase 9 | Bàn giao: README, INSTALL_AND_TEST, risk, PROGRESS | Docs cập nhật | Người khác làm lại từ môi trường sạch; phân biệt rõ phần tự động vs thủ công | W8 |

### Nhánh chờ (không chặn W1–W7)

| ID | Việc | Trạng thái | Điều kiện mở |
|---|---|---|---|
| **B-R1** | Chạy 6 contract test script + gắn indicator + chạy 2 EA trong MT5 | `NOT_RUN` | Có terminal; chạy `deploy_pineport.ps1 -Apply` trước |
| **B-R2** | Parity Pine vs MQL5 | `BLOCKED` | Người dùng xuất CSV reference Pine cho từng indicator |
| **B-R3** | Strategy Tester cho EA PinePort | `NOT_RUN` | Có dữ liệu lịch sử trong terminal |
| **A-R1** | Pipeline Track A trên dữ liệu MT5 thật | `BLOCKED` | Có CSV/Parquet export từ MT5, không dùng synthetic thay thế |
| **A-R2** | Strategy Tester cho `LabSignalEA`/`LabOnnxInference` | `NOT_RUN` | Có terminal + model ONNX hợp lệ |

## 4. Chi tiết từng work item

### W1 — Nền tảng simulation (C-Phase 1)

- Chuẩn hóa input: `MaxLevels >= 1`, volume > 0, multiplier >= 1, spread >= 0; `OnInit` trả
  `INIT_PARAMETERS_INCORRECT` kèm log lý do.
- `SimPortfolio`: thêm/xóa virtual position trong bộ nhớ; tính average entry theo volume, floating P&L,
  exposure chuẩn hóa, equity; không đụng API tài khoản.
- `SimLogger`: schema cố định `timestamp,ea,version,config_hash,symbol,timeframe,event,side,price,volume,
  exposure,equity,drawdown_pct,reason`; ghi CSV trong `MQL5/Files`.
- Test: script MQL5 in `TEST|...|PASS/FAIL` (cùng pattern contract tests) + unit test Python đọc CSV mẫu.

### W2 — RiskGuard & CostModel (C-Phase 2)

- Cap: spread, số vị thế, số tầng, số lần add, exposure, daily loss %, drawdown %, cooldown, stale price,
  kill switch `HALTED`.
- Daily loss và drawdown tính trên **equity mô phỏng**, không chỉ lệnh đã đóng.
- CostModel: spread, commission, swap (nếu có input), slippage giả lập; mỗi giả định ghi nguồn và đơn vị.
- Test: từng cap độc lập, cap bind đúng tại biên, kill switch chặn mọi entry sau đó, không tự reset khi lỗ.

### W3 — RunnerTrailingLabEA (C-Phase 3)

- Tối đa 1 vị thế ảo; long/short; SL ban đầu; breakeven; trailing fixed/ATR; `UpdateOnClosedBarOnly`.
- Bất biến: long `newSL >= oldSL`, short `newSL <= oldSL`; từ chối candidate không cải thiện.
- Gap qua SL: fill theo open tệ hơn + slippage giả lập, ghi rõ trong log.
- Log mỗi lần đề xuất: `old_sl`, `candidate_sl`, `accepted/rejected`, `reason`.

### W4 — GridLabEA (C-Phase 4)

- Spacing fixed/ATR; `MaxGridLevels`, `MaxLevelVirtualVolume`, `MaxVirtualExposure`.
- Exit theo level hoặc basket target/stop; dừng tạo tầng khi chạm cap/drawdown.
- Log từng tầng: giá kích hoạt, volume, exposure cộng dồn, lý do mở/đóng/chặn.

### W5 — DCALabEA (C-Phase 5)

- Trigger theo khoảng giá hoặc số bar; `MaxDcaAdds` (0 = không add, không phải vô hạn).
- Average entry theo volume; basket P&L; stop/exit theo `BasketStop`/`MaxBasketLoss`.
- Test xu hướng đi ngược liên tục: RiskGuard phải chặn đúng cap, không nới.

### W6 — Preset & config (C-Phase 6)

- Preset baseline/conservative/edge cho từng EA, không chứa account/broker.
- `configs/project.example.json` mở rộng cho 3 EA; validator fail-closed nếu khác `SIMULATION_ONLY`.
- Mỗi report lưu snapshot config + hash; không ghi đè report cũ.

### W7 — Script (C-Phase 7)

- `check-environment.ps1`: Python, pytest, MetaEditor, folder; không đọc secrets.
- `build-mql5.ps1`: compile từng `.mq5`, log riêng, exit != 0 khi lỗi, không tuyên bố thành công nếu thiếu log.
- `run-python-tests.ps1`, `validate-project.py` (quét API giao dịch trong toàn bộ `mt5/`), `package-source.ps1`.
- Giữ `build_pineport.ps1`/`deploy_pineport.ps1`/`package_pineport.ps1` nguyên trạng; script mới là lớp chung.

### W8–W9 — Runtime và bàn giao

- W8 chỉ đánh dấu PASS khi có report Strategy Tester thật; nếu không, giữ `NOT_RUN` và ghi bước thủ công.
- W9 cập nhật `docs/PROGRESS.md`, `docs/reference/architecture.md`, `docs/reference/risk.md`,
  `docs/guides/install-and-test.md`, README; nêu rõ metric nào là mô phỏng.

## 5. Thứ tự thực hiện đề xuất

```text
W1 → W2 → W3 → W4 → W5 → W6 → W7 → [W8 cần MT5] → W9
```

- W1–W7 làm được hoàn toàn offline, có compile + test.
- W8 cần người dùng mở MT5; W9 làm sau W8 để báo cáo trung thực.
- B-R1/B-R3 có thể làm song song bất cứ lúc nào có terminal.
- B-R2/A-R1 chỉ mở khi có dữ liệu thật.

## 6. Definition of Done cho mỗi work item

1. File mới/sửa nằm đúng module, không monolith.
2. Grep xác nhận không có `OrderSend`, `CTrade`, `OrderSendAsync`, `MqlTradeRequest`, `PositionOpen/Close`.
3. Compile 0 error/0 warning (MetaEditor CLI) — ghi rõ file `.ex5` và kích thước.
4. Test vector chạy thật hoặc ghi `NOT_RUN` kèm lý do; không thay `NOT_RUN` bằng suy luận.
5. `pytest` toàn bộ xanh; validator liên quan pass.
6. Cập nhật `docs/PROGRESS.md` + README/docs liên quan.
7. Báo cáo cuối item theo mẫu: Phase, Status (`DONE`/`PARTIAL`/`READY_FOR_MANUAL_VALIDATION`/`BLOCKED`),
   files, commands, results, manual steps, risks, next.

## 7. Điều không làm trong lộ trình này

- Không thêm execution thật, live adapter, nút bật live, kết nối broker, lưu credential.
- Không tạo CSV reference giả, không dùng synthetic làm bằng chứng parity/backtest thị trường.
- Không tuyên bố lợi nhuận, không tối ưu trên tập test cuối, không bỏ qua cap để "chạy đẹp".
- Không sửa Pine source gốc `D:\Applications\tm-trading\pine`.
- Không commit khi chưa được yêu cầu.
