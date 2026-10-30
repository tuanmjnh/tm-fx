# Roadmap MT5 EA Lab V3 — Buildable, Testable, Configurable

**Version:** 3.0  
**Ngày:** 2026-10-30  
**Nền tảng:** Windows, MetaTrader 5 Exness Desktop, MetaEditor 5, MQL5; Python chỉ bổ trợ harness/report nếu hữu ích.  
**Phạm vi hiện tại:** Strategy Tester + kiểm thử demo được người vận hành chủ động kích hoạt; AI/ML để backlog.

---

## 1. Mục tiêu sản phẩm

Xây project có thể thực sự đi hết vòng đời kỹ thuật:

`source → build .ex5 → attach/test trong MT5 → Strategy Tester có giao dịch mô phỏng → report → demo forward verification`.

Các yêu cầu quan trọng:

1. Không chỉ tạo docs hoặc file stub: mỗi bot trong phạm vi phải có source `.mq5` và dependencies `.mqh` đầy đủ.
2. Mỗi bot build/test độc lập; thiếu source của một bot không được khóa toàn bộ project.
3. Hệ thống phải giải thích mọi lần không vào lệnh bằng reason code và counter.
4. Các filter chiến lược là cấu hình được, không bị hard-code thành điều kiện bắt buộc không thể tắt.
5. Risk/execution validation phải đúng, có ngưỡng điều chỉnh, nhưng không được bỏ kiểm tra dữ liệu, volume, margin, symbol và trạng thái runtime.
6. Strategy Tester phải sử dụng chế độ mô phỏng giao dịch của MT5, không nhầm thành `SIGNAL_ONLY`.
7. Demo execution chỉ được bật khi tài khoản được xác minh là DEMO; không có real/live mode.
8. AI/ML không triển khai ở phiên bản này.

## 2. Phạm vi chiến lược

### 2.1 PATrendRiderXAUv1

- Dựa trên đặc tả được cung cấp: đa khung H1/M15/M5; swing high/low; HH/HL, LH/LL, BOS, CHoCH; trend/range/reversal watch; pullback/retest; initial SL cấu trúc; break-even và trailing; quản trị rủi ro; logging.
- Nếu có source `.mq5/.mqh` gốc: dùng source làm baseline, test hồi quy trước khi thay đổi.
- Nếu chỉ có file đặc tả: tạo bot mới tên `PATrendRiderXAUv1_SpecBuild`; ghi rõ đây là bản triển khai theo specification, không tuyên bố tương đương source gốc chưa được cung cấp.
- Đặc tả gốc yêu cầu một vị thế, closed-bar signals, không fixed TP, risk sizing, daily/drawdown locks và demo/tester; các điểm đó được dùng như baseline, không được tự thêm filter mới mà không có input.

### 2.2 GridEA

- Grid fixed-distance hoặc ATR-distance.
- Hướng: one-way; two-way chỉ bật khi có logic/position accounting đã test rõ.
- Cấu hình step, first-entry trigger, max layers, volume plan, basket exit, spread/volatility/session filters.
- Không tăng lot vô hạn. Max layers, max total lots/exposure là giới hạn có thể điều chỉnh nhưng bắt buộc có giá trị hữu hạn.
- Test các kịch bản trend kéo dài, range, gap, spread mở rộng, restart và margin pressure.

### 2.3 DCAEA

- Phân biệt hai chế độ: `TIME_BASED_DCA` và `PRICE_AVERAGING`.
- Chỉ dùng một chế độ trong mỗi preset; không đặt tên DCA chung chung.
- Cấu hình first entry, add-on trigger, add interval, lot plan, max adds, max positions, max exposure, basket exit.
- Add-on là một quyết định mới: cần qua validation giá, spread, margin, exposure và risk cap.
- Không tự động nhân lot không giới hạn.

### 2.4 InfiniteRunner XAU (legacy migration candidate)

- Giữ V1/V2 trong `inputs/legacy_sources`.
- Audit module, compile dependencies, direction engine, trailing, stop logic và state restore.
- Không được tự gộp Runner vào PATrendRiderXAUv1. Đây là các chiến lược khác nhau cho đến khi user phê duyệt một thiết kế chung.

### 2.5 Pine indicator adapter

- Optional phase sau khi project core và các EA baseline compile/test.
- Đọc Pine source có quyền sử dụng, lập indicator specification, chuyển logic sang MQL5 custom indicators, test buffer parity và repaint behavior.
- Thiếu Pine source thì đánh dấu BLOCKED riêng, không chặn các bot còn lại.

## 3. Run modes và quyền thực thi

### 3.1 `SIGNAL_DIAGNOSTIC`

- Tính tín hiệu, hiển thị trạng thái, log mỗi stage.
- Không gửi request.
- Chế độ này được phép chạy cả trên chart terminal để xác minh data/signal.

### 3.2 `STRATEGY_TESTER`

- Được phép gọi API giao dịch trong MT5 Strategy Tester để MT5 mô phỏng order/deal/position trên dữ liệu lịch sử.
- Phải xác định môi trường bằng `MQLInfoInteger(MQL_TESTER)`; không suy đoán từ chuỗi `ACCOUNT_NAME` như `"Strategy Tester"`.
- Không để demo-only guard chặn nhầm tester.
- Khi Strategy Tester chạy, tài khoản/tester properties và symbol spec của tester được dùng cho mô phỏng.

### 3.3 `DEMO_EXECUTION`

- Chỉ hoạt động nếu `ACCOUNT_TRADE_MODE == ACCOUNT_TRADE_MODE_DEMO`, `ACCOUNT_TRADE_ALLOWED`, `ACCOUNT_TRADE_EXPERT`, `TERMINAL_TRADE_ALLOWED`, `MQL_TRADE_ALLOWED` và symbol mode đều cho phép.
- Không xác minh được loại tài khoản: fail-closed, không gửi lệnh.
- Không có `REAL`, `LIVE`, `BYPASS_DEMO_GUARD` hoặc config có thể biến demo guard thành real execution.
- Người vận hành là người chủ động attach EA và bật Algo Trading; AI coding agent không tự làm thao tác đó.

## 4. Phân loại điều kiện: mở cấu hình nhưng không bỏ validation

### 4.1 Strategy filters — tùy chọn

Mỗi filter có `Enable...` riêng và phải hỗ trợ OFF:

- trend alignment / EMA confirmation;
- Price Action confirmation;
- spread filter (bên cạnh spread cost vẫn được mô phỏng trong tester);
- abnormal volatility filter;
- trading session filter;
- cooldown;
- min bars between entries;
- max trades per day;
- min signal quality/score;
- optional candle confirmation.

`OFF` chỉ bỏ filter tương ứng, không bỏ validation về quote/price/volume/margin/stop/tick/account.

### 4.2 Risk controls — configurable nhưng hữu hạn

- Fixed lot hoặc risk-percent sizing.
- Max positions/layers/adds, max total lots, max gross/net exposure.
- Max daily loss, max equity drawdown, max consecutive losses, pause/cooldown.
- Max margin utilization / minimum free margin.
- Có thể đặt một số risk pauses ở `OFF` trong Strategy Tester để chẩn đoán logic; trong Demo profile, các giới hạn bắt buộc phải có giá trị dương và finite.
- Không dùng `0 = unlimited` cho exposure, lot, grid layers hoặc DCA adds.

### 4.3 Execution invariants — không thể bypass

- symbol/tick/quote hợp lệ và dữ liệu không stale;
- volume đúng min/max/step và symbol volume limit;
- margin calculation hợp lệ;
- trade mode và filling mode hỗ trợ;
- SL/TP tuân thủ tick size, stop level và freeze level;
- chống duplicate request;
- kiểm tra retcode và xác nhận position/deal;
- position/magic isolation và netting/hedging compatibility;
- emergency stop và demo-only account guard.

## 5. Kiến trúc code

Mỗi bot có main EA riêng; dùng chung thư viện:

```text
MQL5/Experts/MT5_EA_Lab/
  PATrendRiderXAUv1/PATrendRiderXAUv1.mq5
  GridEA/GridEA.mq5
  DCAEA/DCAEA.mq5
  InfiniteRunner/InfiniteRunnerXAU.mq5       # optional migration

MQL5/Include/MT5_EA_Lab/
  Core/Types.mqh
  Core/RunMode.mqh
  Core/SymbolContext.mqh
  Core/MarketData.mqh
  Core/BarClock.mqh
  Core/StateMachine.mqh
  Core/SignalContract.mqh
  Filters/FilterPipeline.mqh
  Risk/RiskManager.mqh
  Risk/ExposureManager.mqh
  Execution/ExecutionGate.mqh
  Execution/TradeRequest.mqh
  Execution/PositionManager.mqh
  Execution/TradeResult.mqh
  Logging/Diagnostics.mqh
  Logging/CsvLogger.mqh
```

Không tạo file rỗng. Tạo module khi có consumer/test thật. Không viết một EA khổng lồ chứa tất cả chiến lược.

## 6. Luồng chuẩn của một quyết định

`OnInit`:
1. Xác định run mode.
2. Validate config theo run mode.
3. Validate symbol contract và account context.
4. Tạo indicator handles.
5. Xác minh data readiness; nếu chưa đủ dữ liệu, trạng thái `WAITING_FOR_DATA`, không im lặng return.
6. Restore/reconcile state; nếu mismatch, `SAFE_MODE` và log.
7. Khởi tạo diagnostics counters và panel.

`OnTick`:
1. Update runtime health, quotes và position lifecycle.
2. Quản lý SL/trailing cho position hiện hữu.
3. Cập nhật risk state.
4. Chỉ chạy chiến lược trên tick/bar phù hợp; strategy phải khai báo event cadence.
5. Signal engine trả `BUY/SELL/FLAT` + reason + timestamp + source data.
6. Filter pipeline ghi từng filter PASS/BLOCK/SKIP.
7. Risk sizing và execution validation.
8. Gửi một request nếu run mode cho phép.
9. Kiểm tra result retcode và reconcile order/deal/position.
10. Cập nhật counters/panel/log.

## 7. Cấu hình mẫu cần tạo

Mỗi EA cần ít nhất các preset:

- `diagnostic_loose`: tắt các filter chiến lược không thiết yếu để chứng minh signal pipeline có thể phát tín hiệu; chỉ chạy trong Strategy Tester/SIGNAL_DIAGNOSTIC, vẫn giữ volume/margin/symbol checks.
- `baseline`: các filter/strategy settings mặc định đã được đặc tả.
- `risk_stress`: spread/commission/slippage/volatility/margin giả lập bất lợi.
- `demo_guarded`: mọi risk guard bắt buộc bật; chỉ tạo config, không tự chạy.

Không dùng `diagnostic_loose` làm preset demo.

## 8. Zero-trade observability bắt buộc

Mỗi lần test phải có counters:

- ticks received;
- bars processed theo timeframe;
- data_ready / data_not_ready;
- signals buy/sell/flat;
- signal candidates;
- filter blocks theo từng tên filter;
- risk blocks theo từng reason;
- sizing blocks (`min_lot_over_budget`, invalid tick value, etc.);
- margin blocks;
- order checks/rejections;
- requests sent;
- accepted/rejected retcodes;
- confirmed positions/deals;
- exits và net result.

Nếu `total_trades=0`, report phải nêu **first blocking stage**, số lần block và ví dụ timestamp. Không được kết luận đơn giản là "không có tín hiệu" khi chưa đo các stage.

## 9. GitHub open-source research

- Tối thiểu 5 repo; đọc source/README/LICENSE/commit SHA/dependencies/tests.
- Ưu tiên tham khảo test harness, MQL5 project structure, symbol utilities, logging, retcode handling, Strategy Tester automation và risk calculation.
- Không copy trọn EA chưa audit; license không rõ = `REFERENCE_ONLY`.
- Ghi commit SHA và thời điểm nghiên cứu để tái lập. Xem `research/GITHUB_RESEARCH_PROCESS.md`.

## 10. Roadmap phases

### Phase 0 — Inventory và project health

- Scan toàn bộ workspace; ghi nguồn đã có/thiếu; kiểm tra include graph.
- Tạo `docs/SOURCE_INVENTORY.md`, `docs/ENVIRONMENT.md`, `docs/PROGRESS.md`.
- Không dừng toàn dự án chỉ vì một bot thiếu source.

**PASS:** dependency list chính xác; mọi blocker được tách theo bot.

### Phase 1 — GitHub source audit

- Tìm tối thiểu 5 repository; kiểm tra license/commit/source/test.
- Tạo `research/GITHUB_AUDIT.md`.

**PASS:** có quyết định `USE / REFERENCE_ONLY / REJECT` và lý do, không có code copy chưa duyệt license.

### Phase 2 — Strategy specs và input schema

- Tạo specs cho PATrendRiderXAUv1, GridEA, DCAEA và legacy InfiniteRunner.
- Mỗi input phải có type, default, unit, min/max, 0/false semantics và run-mode availability.
- Đánh dấu thông tin strategy `CONFIRMED / SPECIFIED / INFERRED / UNKNOWN`.

**PASS:** không có input bắt buộc mơ hồ; không bịa logic bot chưa có source.

### Phase 3 — Build skeleton + SmokeTestEA

- Tạo common core tối thiểu.
- Tạo `SmokeTestEA.mq5` chỉ dành Strategy Tester để xác minh compile → init → tick → simulated order lifecycle → report.
- Cần có `SIGNAL_DIAGNOSTIC` để quan sát signal pipeline không gửi order.

**PASS:** MetaEditor compile thật; SmokeTestEA tạo ít nhất một giao dịch mô phỏng trong test fixture được định nghĩa, hoặc có log rõ vì sao fixture/data không đáp ứng. Không giả số liệu.

### Phase 4 — Diagnostics + configuration system

- Input groups có tên rõ; profile loading; filter switches; per-strategy validation.
- Tạo `ZERO_TRADE_DIAGNOSTICS` và panel.

**PASS:** cố ý chặn từng stage trong test thì đúng reason code/counter được ghi.

### Phase 5 — PATrendRiderXAUv1

- Tích hợp source gốc nếu có; nếu không, triển khai `SPEC_BUILD` từ đặc tả được đưa vào `inputs/specifications`.
- Test swing/BOS/CHoCH/no-lookahead, closed-bar signal, MTF alignment, pullback/retest, initial SL/trailing/risk sizing.

**PASS:** compile; ít nhất signal tests pass; backtest smoke report; source parity status được ghi đúng.

### Phase 6 — GridEA

- Implement fixed/ATR grid spacing, entry rules, basket tracking/exit, position accounting, caps.
- Cấu hình all filters và max layers/exposure.

**PASS:** grid levels/adds/basket state test; Strategy Tester baseline; stress-test trend/range.

### Phase 7 — DCAEA

- Implement time DCA hoặc averaging-in theo profile lựa chọn, không nhập nhằng.
- Basket P/L, volume plan, add conditions, caps và exit.

**PASS:** add-on idempotency; max adds/exposure; stress tests và Strategy Tester baseline.

### Phase 8 — InfiniteRunner legacy + Pine adapter (optional)

- Khôi phục đủ `.mqh` dependencies hoặc tái cấu trúc theo core V3.
- Pine adapter chỉ làm sau khi core EA ổn định.

**PASS:** từng adapter có dependency graph và regression/indicator tests; nếu thiếu source đánh dấu BLOCKED riêng.

### Phase 9 — Build scripts và compile matrix

- Implement `check-environment.ps1`, `validate-project.ps1`, `build-all.ps1`, `run-python-tests.ps1` (nếu có), `package-release.ps1`.
- Mỗi main `.mq5` compile riêng; log `.log` được lưu.

**PASS:** build script exit code phản ánh đúng compile; không log PASS giả.

### Phase 10 — Strategy Tester pipeline

- Mỗi EA có test preset; compile .ex5; chạy MT5 Strategy Tester thật hoặc hướng dẫn UI nếu tester automation chưa xác thực.
- Ghi symbol, timeframe, dates, model, deposit, leverage, spread/cost settings, config hash và report path.

**PASS:** mỗi bot đã implement có test run thực tế hoặc `BLOCKED` kèm bằng chứng; zero trades có diagnostic.

### Phase 11 — Demo-readiness verification

- Kiểm tra demo account guard, run mode, permissions, symbol, fill mode, order retcode, state restore, kill switch và duplicate prevention.
- AI chỉ tạo config và hướng dẫn; người vận hành chủ động bật demo terminal.

**PASS:** test checklist và demo report có bằng chứng; không chạy trên REAL.

### Phase 12 — Documentation/release

- README, installation, configuration, per-bot manual, troubleshoot, changelog, test reports, GitHub attribution/license, release ZIP.

**PASS:** clone/unzip → validate → build → test theo docs mà không cần hỏi lại những thông tin đã ghi.

### Backlog — AI/ML

- Dataset, labels, model evaluation, ONNX. Không triển khai trong V3.

## 11. Quy tắc làm việc của AI agent

- Không dừng sau Phase 0 khi prompt yêu cầu FULL IMPLEMENTATION.
- Có thể hoàn thành từng phase và checkpoint nhưng tự tiếp tục phase tiếp theo trong cùng task nếu không có blocker cần quyết định người dùng.
- Nếu thiếu source của một bot, đánh dấu `BLOCKED_INPUT` bot đó; tiếp tục core, diagnostics và bot khác.
- Không tạo file stub/rỗng để báo đủ cấu trúc.
- Không nói đã compile/test khi không có log thực tế.
- Không tự sửa source gốc; dùng `legacy/` read-only và tạo bản mới.

## 12. Definition of Done

- Tất cả bot trong phạm vi đã có implementation hoặc blocker input được nêu rõ; không giả vờ hoàn thành bot thiếu source.
- Mỗi bot compile được bằng MetaEditor thật.
- SmokeTestEA xác minh được Strategy Tester execution pipeline.
- Mỗi bot có diagnostic stage counters và report.
- Grid/DCA có các cap hữu hạn nhưng điều chỉnh được; không có vô hạn exposure.
- Demo mode có hard account-type guard; không có real/live code path.
- Có presets: diagnostic, baseline, stress, demo guarded.
- Có build scripts, docs, changelog, source/license audit.
- AI/ML ở backlog.

## 13. Tài liệu kỹ thuật chính thức

- MQL5 Reference: https://www.mql5.com/en/docs
- Runtime properties (`MQL_TESTER`, `MQL_TRADE_ALLOWED`): https://www.mql5.com/en/docs/constants/environment_state/mql5_programm_info
- Account properties (`ACCOUNT_TRADE_MODE`): https://www.mql5.com/en/docs/constants/environment_state/accountinformation
- Symbol properties: https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
- CTrade Buy result/retcode note: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradebuy
- Strategy Tester: https://www.metatrader5.com/en/terminal/help/algotrading/testing
- MetaEditor command-line compilation: https://www.metatrader5.com/en/metaeditor/help/beginning/integration_ide
