# MT5 — InfiniteRunner demo bot

Thư mục này chứa mã MQL5 của lab: **một bot demo** `InfiniteRunnerXAUV2DemoEA` (gửi lệnh **chỉ trên tài
khoản demo/Strategy Tester** qua `Include/Exec/*`) cùng thư viện mô phỏng `Include/Sim/*`, module chiến lược
`Include/InfiniteRunner/*` và các script test/tiện ích.

Ranh giới: EA demo chỉ nhận tài khoản demo/tester; mọi lệnh đi qua `ExecBroker.mqh` (điểm gửi lệnh duy
nhất). Không credential, không `WebRequest`/socket.

## 1. Cấu trúc và ánh xạ sang thư mục MQL5

Repo giữ mã nguồn tách khỏi data folder của terminal. Khi muốn chạy trong MT5, sync thủ công (hoặc dùng
`scripts/deploy_pineport.ps1 -Apply`):

| Trong repo | Đích trong data folder |
|---|---|
| `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` | `<Data Folder>/MQL5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` |
| `mt5/Include/Exec/*.mqh` | `<Data Folder>/MQL5/Include/Exec/*.mqh` |
| `mt5/Include/Sim/*.mqh` | `<Data Folder>/MQL5/Include/Sim/*.mqh` |
| `mt5/Include/InfiniteRunner/*.mqh` | `<Data Folder>/MQL5/Include/InfiniteRunner/*.mqh` |
| `mt5/Scripts/{IRCoreTests,ExecGuardTests,ExecDemoProbe,CloseDemoPosition,SimCoreTests,SimPlanTests}.mq5` | `<Data Folder>/MQL5/Scripts/...` |

EA và script include bằng đường dẫn tương đối (`../Include/...`), nên **phải giữ nguyên cấu trúc thư mục**
`Experts/`, `Scripts/` và `Include/` khi copy.

Không copy/dùng `accounts.dat`, `servers.dat`, `origin.txt` hay bất kỳ file phiên nào vào repo.

## 2. Compile

### Trong MetaEditor (thủ công)

1. Mở MetaEditor (`F4` từ MT5, hoặc `MetaEditor64.exe`).
2. Mở `InfiniteRunnerXAUV2DemoEA.mq5` trong `MQL5/Experts/`.
3. `F7` để compile. Đọc tab **Errors** và **Warnings** (kỳ vọng `0 errors, 0 warnings`).

### Bằng CLI

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-mql5.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 EXNESS\MetaEditor64.exe" `
  -Filter "Experts\InfiniteRunnerXAUV2DemoEA.mq5" -LogDir "reports\build-demo"
```

Tiến trình MetaEditor có thể trả **exit code 1** dù log báo thành công — luôn đọc nội dung log thay vì chỉ
tin exit code. `compile.log` và `.ex5` là artifact, đã nằm trong `.gitignore`, không commit.

## 3. Demo execution — `Include/Exec/*`

| File | Vai trò |
|---|---|
| `Include/Exec/ExecGuard.mqh` | Cổng an ninh thuần (không I/O): `ExecContextAllowed`, `ExecSymbolAllowed`, `ExecSymbolTradable`, `ExecTakeProfitValid`, `ExecStopsRespectBroker`, `ExecNormalizeVolume`, `ExecRiskBudgetOk`, token lý do ổn định |
| `Include/Exec/ExecBroker.mqh` | Chỗ **duy nhất** gọi API lệnh (`OrderSend`), đã kiểm môi trường |
| `Include/Exec/ExecDemoCommon.mqh` | Helper dùng chung (đóng vị thế, modify stops, tính P&L lịch sử) route qua `ExecBroker` |
| `Scripts/ExecGuardTests.mq5` | Ma trận guard synthetic; kỳ vọng `TEST|RESULT|ALL_PASS|pass=N fail=0|suite=execguard` |
| `Scripts/ExecDemoProbe.mq5` | Probe demo một lệnh: chỉ gửi khi `InpConfirm=true`, từ chối tester/real, magic riêng `25002002` |
| `Scripts/CloseDemoPosition.mq5` | Đóng vị thế theo magic trên symbol hiện tại (tiện ích vận hành) |

## 4. Chiến lược InfiniteRunner — `Include/InfiniteRunner/*` + EA demo

| File | Vai trò |
|---|---|
| `Include/InfiniteRunner/IRTypes.mqh` | Kiểu dữ liệu, enum hướng/SL/trail/lot |
| `Include/InfiniteRunner/IRDirection.mqh` | Quyết định hướng trên nến đã đóng (EMA legacy hoặc MTF H1/M15/M5, regime) |
| `Include/InfiniteRunner/IRTrailing.mqh` | Break-even + trailing đơn điệu (`IRMonotonicBetter`), step trailing |
| `Include/InfiniteRunner/IRRisk.mqh` | Ledger rủi ro: daily loss, drawdown, chuỗi thua + cooldown, sizing |
| `Experts/InfiniteRunnerXAUV2DemoEA.mq5` | Luồng điều phối: guard demo → quyết định → ExecBroker; journal CSV 18 cột; state persist |
| `Scripts/IRCoreTests.mq5` | Test contract module IR; kỳ vọng `TEST|RESULT|ALL_PASS|pass=N fail=0|ir=1` |

Preset: `configs/demo/infinite_runner_demo.json`. Hướng dẫn chạy: `docs/20-operations/demo-execution.md`.

## 5. Thư viện mô phỏng (`Include/Sim/*`)

Thư viện thuần dùng chung (không API lệnh) cho EA demo và các script test:

| File | Vai trò |
|---|---|
| `Include/Sim/SimTypes.mqh` | Side, FNV-1a 32-bit, helper fingerprint config |
| `Include/Sim/SimValidate.mqh` | Validate price/volume/commission/levels/percent/spread/warmup/slippage |
| `Include/Sim/SimPortfolio.mqh` | Vị thế ảo trong bộ nhớ, average entry, equity, drawdown |
| `Include/Sim/SimCostModel.mqh` | Spread/commission/slippage khai báo, `FillPrice` bất lợi |
| `Include/Sim/SimRiskGuard.mqh` | Hard cap, cooldown, kill switch, `ACTIVE/BLOCKED/HALTED` |
| `Include/Sim/SimTrailing.mqh` | Breakeven + trailing thuần, stop-hit/gap helper |
| `Include/Sim/SimGrid.mqh`, `Include/Sim/SimDca.mqh` | Helper lưới/DCA có trần (giữ trong thư viện) |
| `Include/Sim/SimPlan.mqh` | Cấu trúc `SimPlan` (entry/sl/tp/ref) + validate RR |
| `Include/Sim/SimLogger.mqh` | CSV 18 cột trong `MQL5/Files` |
| `Scripts/SimCoreTests.mq5` | Test vector thư viện Sim (`pass=N fail=0`) |
| `Scripts/SimPlanTests.mq5` | Test vector `SimPlan` (`pass=N fail=0`) |

- Kiểm tra fail-closed preset: `python scripts/validate-project.py`.
- Chi tiết công thức và token lỗi: `docs/30-research/simulation.md`.

## 6. An toàn và giới hạn

- API lệnh chỉ nằm trong `Include/Exec/ExecBroker.mqh`; EA demo gọi `ExecBroker`, không tự gọi `OrderSend`.
- EA fail-closed: tài khoản không phải demo/tester → `INIT_FAILED`; thiếu SL/TP → không gửi lệnh.
- EA từ chối `AccountInfoString`/`TerminalInfoString`, `WebRequest` và socket.
- Kết quả demo/backtest không phải cam kết lợi nhuận; lợi nhuận của chiến lược là `UNPROVEN`.
