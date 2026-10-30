# Execution và an toàn

**Nguồn quyền lực:** [ADR 0003](../decisions/0003-demo-execution-scope.md) — execution chỉ cho tài khoản demo/Strategy Tester. Live/real bị cấm.

## 1. Ranh giới tuyệt đối

| Được phép | Bị cấm |
|---|---|
| Gửi lệnh trên tài khoản DEMO đã xác minh | Bất kỳ lệnh nào trên tài khoản real/live/contest |
| Chạy trong Strategy Tester (mô phỏng) | Tạo cờ `REAL`, `LIVE`, `BYPASS_DEMO_CHECK` |
| Dry-run mặc định, bật execution có chủ đích | Tự bật execution khi init |
| Một vị thế, có SL/TP | Không SL/TP, nhiều vị thế, grid/DCA/martingale trong DemoEA |
| Kill switch bằng file | Tắt guard để "thử" |
| Đọc journal/CSV | Đọc/ghi credential, gọi WebRequest/socket |

Không có "chế độ live". Không có đường vòng. Nếu terminal không phải demo và không phải tester, EA phải `INIT_FAILED`.

## 2. Guard chain

`mt5/Include/Exec/ExecGuard.mqh` (pure, testable):

| Hàm | Kiểm tra | Token lỗi |
|---|---|---|
| `ExecContextAllowed` | `ACCOUNT_TRADE_MODE_DEMO` hoặc `MQL_TESTER`; `ACCOUNT_TRADE_ALLOWED`; `TERMINAL_TRADE_ALLOWED` | `not_demo_account`, `account_trade_disabled`, `terminal_trade_disabled` |
| `ExecSymbolAllowed` | Symbol nằm trong allowlist prefix | `symbol_not_allowed` |
| `ExecSymbolTradable` | `SYMBOL_TRADE_MODE` đầy đủ, không close-only | `symbol_trade_disabled`, `symbol_close_only` |
| `ExecTakeProfitPrice/Valid` | TP > 0, đúng phía, cách giá tối thiểu | `take_profit_invalid` |
| `ExecStopsRespectBroker` | SL/TP ≥ stops level + freeze level | `stop_below_broker_level` |
| `ExecNormalizeVolume` | Làm tròn volume step, min/max | `volume_invalid` |
| `ExecRiskBudgetOk` | `expected_loss ≤ risk_money` | `risk_budget_exceeded` |
| Kill switch | File tồn tại | `kill_switch_active` |
| Dry-run | `InpEnableExecution=false` | `dry_run` |

`ExecMarginRequired` kiểm tra margin trước khi gửi; thiếu margin → `free_margin_insufficient`.

## 3. Nơi duy nhất gọi `OrderSend`

`mt5/Include/Exec/ExecBroker.mqh`:

- `ExecOpenMarket` — mở market order với SL/TP trong request.
- `ExecModifyStops` — sửa SL/TP, kiểm tra stops level.
- `ExecClosePosition` — đóng vị thế.
- `ExecFindOwnPosition` — tìm vị thế theo symbol + magic (chỉ vị thế đầu tiên).
- `ExecClosedPnl` — đọc P&L đã đóng.
- `ExecMarginRequired` — `OrderCalcMargin`.

Không file nào khác được gọi các API này. `validate-project.py` và `validate_demo_execution.py` chặn nếu phát hiện.

## 4. Vòng đời DemoEA

```text
OnInit
  ├─ ExecContextAllowed (demo/tester + trade allowed)
  ├─ ExecSymbolAllowed + ExecSymbolTradable
  ├─ mở logger
  ├─ khôi phục ledger/state
  ├─ adopt vị thế cùng magic (nếu có)
  └─ log INIT (mode, symbol, magic, tp_r, config_hash, mql_trade_allowed)

OnTick
  ├─ kiểm tra quote hợp lệ
  ├─ SyncPosition (khớp state với broker)
  ├─ cập nhật equity/ledger
  ├─ kill switch → đóng vị thế, khóa entry
  ├─ ManageOpenPosition (SL/TP bị broker bỏ → sửa lại)
  ├─ UpdateTrailing (chỉ bar đã đóng)
  └─ bar M5 mới đóng → AnalyseClosedBar → tín hiệu → AttemptEntry

OnDeinit
  └─ ghi SUMMARY + state
```

## 5. Idempotency và restart

- Chỉ xử lý một lần trên mỗi bar M5 đã đóng.
- `SyncPosition` đối chiếu ticket/magic/symbol với broker.
- State/ledger persist xuống `pa_trendrider_demo_state.csv`.
- Không giả định RAM còn nguyên sau restart.
- Nếu state không khớp broker → log `SYNC`/`FAULT`, không mở thêm vị thế.

## 6. Kill switch

Tạo file:

```text
<Data Folder>\MQL5\Files\PA_TREND_RIDER_DEMO_STOP.txt
```

Hành vi đã kiểm chứng (2026-10-29 04:10:16):

```text
KILL  kill_switch_file|entries_disabled|file=PA_TREND_RIDER_DEMO_STOP.txt
STATE to=ERROR_SAFE_MODE|reason=kill_switch|transitions=3
```

- Đóng vị thế đang mở.
- Khóa entry tới khi restart.
- State `ERROR_SAFE_MODE` được persist; xóa file **không** đủ để reset. Phải reset state file hoặc dùng `InpResetStateOnInit` sau khi review.
- Kill switch không chống được terminal tắt/mất kết nối.

## 7. Bằng chứng execution

| Bằng chứng | Nội dung | Giới hạn |
|---|---|---|
| Strategy Tester `demo_exec_gui_20261029` | 31 ENTRY/31 EXIT, net +53.72/5 000, DD 0.653%, audit `PROBLEMS=0` | Tester là mô phỏng; không chứng minh broker nhận lệnh |
| `ExecDemoProbe` trên demo `464140826` | BUY 0.01 XAUUSDm có SL/TP, `deal=2468899165` → `2468899168`, `pnl=-0.24`, đóng trong 103 ms | Một lệnh, một chiều; chưa test SELL/retcode |
| DemoEA armed trên demo | `INIT mode=DEMO_EXECUTION\|...\|mql_trade_allowed=1` | 0 `ENTRY` do regime RANGE |
| Kill switch file thật | `KILL` + `ERROR_SAFE_MODE` | Chỉ chứng minh guard phần mềm |
| Watcher | `watch_demo_journal.py` đọc journal, phát hiện ENTRY/EXIT/FAULT | Chỉ đọc; không phát hiện EA bị gỡ |

Chi tiết: [`EVIDENCE.md`](EVIDENCE.md), [`../PROGRESS.md`](../PROGRESS.md) §44–§46.

## 8. DemoEA so với SimEA

| Điểm | SimEA | DemoEA |
|---|---|---|
| Order API | Không | Có, qua `ExecBroker` |
| Vị thế | Ảo trong bộ nhớ | Vị thế broker thật trên demo |
| TP | Không (thoát bằng SL/trailing/reversal) | Bắt buộc 3R |
| Journal | `pa_trendrider_log.csv` | `pa_trendrider_demo.csv` |
| Magic | 25001001 | 25002001 |
| Guard demo | Không cần | Bắt buộc |
| Kết quả tester | 0 deal (đúng) | Có deal mô phỏng |

Không trộn kết quả hai EA. Không dùng kết quả SimEA để suy ra DemoEA hoạt động trên broker.

## 9. Grid/DCA

- `GridLabEA`, `DCALabEA` chỉ tạo vị thế ảo; không có `OrderSend`.
- Demo execution cho Grid/DCA **chưa được phép**. Cần ADR mới, guard riêng và test.
- Không attach vào tài khoản thật để "xem thử".

## 10. Quy tắc vận hành

1. Kiểm tra terminal là DEMO trước khi attach.
2. Giữ `InpEnableExecution=false` cho tới khi xem `INIT` + `mql_trade_allowed=1`.
3. Không tăng risk, không bỏ SL/TP, không đổi magic để lách guard.
4. Dừng ngay nếu thấy `FAULT`, `SYNC` bất thường, hoặc journal không khớp tab History.
5. Không tự động đăng nhập; không lưu credential.
6. Không `git push`; người dùng quyết định.

## 11. Liên kết

- ADR: [`../decisions/0003-demo-execution-scope.md`](../decisions/0003-demo-execution-scope.md), [`../decisions/0002-execution-boundary.md`](../decisions/0002-execution-boundary.md)
- Hướng dẫn demo: [`../guides/demo-execution.md`](../guides/demo-execution.md)
- Guard code: [`../../mt5/Include/Exec/ExecGuard.mqh`](../../mt5/Include/Exec/ExecGuard.mqh), [`../../mt5/Include/Exec/ExecBroker.mqh`](../../mt5/Include/Exec/ExecBroker.mqh)
- Rủi ro execution: [`../reference/risk.md`](../reference/risk.md) mục 3
