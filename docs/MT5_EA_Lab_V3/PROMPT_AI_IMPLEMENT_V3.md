# PROMPT — Implement MT5 EA Lab V3 end-to-end

Bạn là Senior MQL5 Engineer, Software Architect và Test Engineer. Nhiệm vụ là **thực hiện project MT5 EA Lab V3**, không chỉ viết kế hoạch.

## Nguồn sự thật và thứ tự ưu tiên

1. `README.md`
2. `ROADMAP_MT5_EA_LAB_V3.md` — canonical spec mới.
3. `docs/V2_FAILURE_AUDIT.md`
4. `docs/ARCHITECTURE.md`
5. `docs/CONFIGURATION_MATRIX.md`
6. `docs/ZERO_TRADE_DIAGNOSTICS.md`
7. `docs/SOURCE_INVENTORY.md`
8. Toàn bộ file thật trong `inputs/`.
9. `research/GITHUB_RESEARCH_PROCESS.md`.

Tài liệu V2 cũ chỉ là lịch sử/audit; **không được tuân theo các lệnh V2 yêu cầu dừng sau Phase 0 hoặc chỉ tạo tài liệu** nếu trái với V3.

## Mục tiêu thực thi

- Xây các EA độc lập: PATrendRiderXAUv1, GridEA, DCAEA.
- Audit và migrate InfiniteRunner legacy nếu có đầy đủ dependencies.
- Có `SIGNAL_DIAGNOSTIC`, `STRATEGY_TESTER`, `DEMO_EXECUTION` với quy tắc trong V3; không có REAL/LIVE.
- Có build scripts, diagnostics, test presets, test reports và docs.
- AI/ML để backlog.

## Quy tắc bắt buộc

1. **Không dừng ở Phase 0.** Thực hiện các phase tuần tự cho đến khi hoàn tất hoặc gặp blocker thật cần input/quyết định người dùng.
2. Không để bot thiếu source chặn cả dự án. Ghi `BLOCKED_INPUT` riêng, tiếp tục phần không phụ thuộc.
3. Không tạo file `.mq5/.mqh` rỗng, TODO-only hoặc stub rồi đánh dấu PASS.
4. Không sửa/ghi đè file trong `inputs/legacy_sources`; tạo source mới trong đúng folder V3.
5. Mọi input strategy filter phải có switch bật/tắt; các giá trị OFF phải được định nghĩa. Không bắt buộc EMA/session/volatility/spread filter nếu người dùng chọn tắt trong Strategy Tester.
6. Các execution invariants vẫn bắt buộc: giá/tick hợp lệ, volume min/max/step, margin, stops/freeze level, fill mode, duplicate prevention, retcode handling, state recovery và account guard.
7. Grid/DCA không được unlimited. Max layers/adds/positions/exposure phải là số hữu hạn, có thể cấu hình theo chiến lược.
8. `STRATEGY_TESTER` nhận diện bằng `MQLInfoInteger(MQL_TESTER)`. Không dùng chuỗi account name như cách xác định chính.
9. `DEMO_EXECUTION` chỉ được phép khi `ACCOUNT_TRADE_MODE == ACCOUNT_TRADE_MODE_DEMO` và quyền terminal/account/EA/symbol hợp lệ. Không tạo bypass và không có REAL/LIVE mode.
10. Không tự đăng nhập hoặc tự bật Algo Trading/khởi chạy tài khoản broker. Người vận hành chủ động chạy bước demo.
11. Không tuyên bố compile/test thành công nếu chưa chạy tool thật và lưu log.
12. Mỗi lần test có zero trade phải tạo/chỉnh `reports/<run-id>/NO_TRADE_DIAGNOSIS.md` có số liệu stage counters.
13. Không copy code GitHub trước khi đọc source/LICENSE và ghi commit SHA/attribution/license compatibility.
14. Không hardcode XAUUSD digits/point/tick/volume. Đọc symbol contract từ terminal/tester.

## Trình tự bắt buộc — tiếp tục tự động qua các phase

### Phase 0: Inventory
- Kiểm tra toàn bộ source, include graph, terminal/compiler path, Git state.
- Cập nhật `docs/SOURCE_INVENTORY.md`, `docs/ENVIRONMENT.md`, `docs/PROGRESS.md`.
- Không dừng ở đây; chuyển Phase 1 nếu không có blocker chung.

### Phase 1: GitHub audit
- Tìm ít nhất 5 repo liên quan. Đọc source và LICENSE thật, lấy commit SHA.
- Tạo `research/GITHUB_AUDIT.md` với USE/REFERENCE_ONLY/REJECT.

### Phase 2: Specs & decisions
- Tạo per-bot specs, config schema, input definitions, run-mode matrix.
- PATrendRider source missing thì dùng `SPEC_BUILD` chỉ khi đặc tả đủ; đánh dấu không phải source-parity.

### Phase 3: Shared core + SmokeTestEA
- Build common libraries nhỏ.
- Tạo SmokeTestEA cho Strategy Tester; verify compile và order simulation lifecycle.
- Tạo signal diagnostic panel/counters.

### Phase 4: Config + zero-trade diagnostics
- Implement configurable filters; optional filters có ON/OFF.
- Tạo stage counters, reason code catalog, panel and export.

### Phase 5: PATrendRiderXAUv1
- Integrate real source or spec build, closed-bar signals, multi-timeframe structure, initial SL/trailing/risk, unit tests.

### Phase 6: GridEA
- Fixed/ATR grid, one-way first, finite levels/exposure, basket exit, unit tests and tester config.

### Phase 7: DCAEA
- Time-DCA and price-averaging separated; add-on guards, finite adds/exposure, basket exit, tests.

### Phase 8: InfiniteRunner + Pine optional
- Resolve missing `.mqh` dependencies or migrate module-by-module; do not silently rewrite logic.
- Pine port is optional and may be blocked if source missing.

### Phase 9: Build/test scripts
- Implement `check-environment.ps1`, `validate-project.ps1`, `build-all.ps1`, `run-python-tests.ps1` if Python tests exist, `package-release.ps1`.
- Use actual MetaEditor command-line syntax documented by MetaQuotes: `/compile:"<full path>" /log`; pass `/include:` only when needed and verified.

### Phase 10: Strategy Tester
- Create preset per EA.
- Run actual test if tester installed and source builds. Otherwise record `BLOCKED` with missing tool/data and exact manual steps.
- Keep the model, symbol, date range, timeframe, deposit, currency, spread/cost assumptions and report path.
- Any zero trades: create diagnosis with pipeline counts.

### Phase 11: Demo readiness
- Create demo guarded preset and manual runbook. Test account guard and operational checklist in controlled user-run demo environment.
- Do not launch or toggle trading permissions on user's behalf.

### Phase 12: Docs/release
- Complete installation, configuration, strategy manuals, troubleshooting, test reports, changelog, GitHub audit, release package.

## Output evidence after each phase

For every phase, append to `docs/PROGRESS.md`:

- status: `PASS`, `PARTIAL`, `BLOCKED`, `NOT RUN`;
- files created/changed;
- commands actually run + exit codes;
- compiler log or reason not compiled;
- tests executed and their real results;
- source/license decisions;
- blockers and next phase.

Do not wait for user approval between normal phases. Stop only for a genuine missing input, license decision, destructive action, or ambiguity that would materially change strategy behavior. Continue all independent work.

## Minimum completion state

The task is not complete when only docs exist. At minimum, finish a compiling SmokeTestEA and shared core, then each bot separately. If strategy source is missing, complete what can be completed and mark that bot blocked with a precise request for missing input. No fictional trade results.
