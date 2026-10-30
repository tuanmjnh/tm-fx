# Giải phẫu bot EA: cấu trúc, cài đặt, cấu hình, thao tác GUI và ghép AI

**Phiên bản:** 1.0 · **Cập nhật:** 2026-10-30
**Phạm vi:** mọi nhận định trong file này lấy từ code và artifact thật của repo `D:\Applications\tm-fx`
(MQL5 build 6292, symbol `XAUUSDm`). Không có nội dung suy đoán về UI của nhà cung cấp khác.
**Người đọc mục tiêu:** bạn đã chạy xong [`beginner-first-run.md`](beginner-first-run.md) và giờ muốn hiểu
*từng khối của một con bot* + *tất cả tham số*.

> **Ranh giới an toàn (ADR 0003, [`../decisions/0003-demo-execution-scope.md`](../decisions/0003-demo-execution-scope.md)):**
> repository phục vụ nghiên cứu offline, mô phỏng và **demo execution có guardrail**. EA mô phỏng không
> chứa `OrderSend`/`CTrade`; đường gửi lệnh duy nhất là `PATrendRiderXAUv1DemoEA` + `mt5\Include\Exec\*`,
> chỉ nhận tài khoản **demo** hoặc Strategy Tester, mặc định **dry-run**. Tài khoản real/live bị cấm.
> Không credential. **Lợi nhuận của mọi chiến lược: `UNPROVEN`.**

## Mục lục

1. [Sơ đồ tổng quan hệ thống](#1-sơ-đồ-tổng-quan-hệ-thống)
2. [Giải phẫu một file EA](#2-giải-phẫu-một-file-ea)
3. [Thư viện dùng chung](#3-thư-viện-dùng-chung)
4. [Danh mục bot trong repo](#4-danh-mục-bot-trong-repo)
5. [Cài đặt](#5-cài-đặt)
6. [Cấu hình: 4 tầng và thứ tự ưu tiên](#6-cấu-hình-4-tầng-và-thứ-tự-ưu-tiên)
7. [Bảng tham số đầy đủ theo bot](#7-bảng-tham-số-đầy-đủ-theo-bot)
8. [Cổng rủi ro: token lý do và halting](#8-cổng-rủi-ro-token-lý-do-và-halting)
9. [Thao tác trên GUI MT5 desktop](#9-thao-tác-trên-gui-mt5-desktop)
10. [Vòng đời một vị thế](#10-vòng-đời-một-vị-thế)
11. [Ghép bot EA với AI](#11-ghép-bot-ea-với-ai)
12. [Trạng thái bằng chứng và việc chưa kiểm](#12-trạng-thái-bằng-chứng-và-việc-chưa-kiểm)
13. [Đọc tiếp](#13-đọc-tiếp)

---

## 1. Sơ đồ tổng quan hệ thống

```text
D:\Applications\tm-fx  (repo — nguồn chuẩn)
│
├─ mt5/                     source MQL5                ── deploy ──►  Data Folder của MT5
│   ├─ Experts/*.mq5        bot (EA)                               MQL5\Experts\*.ex5
│   ├─ Indicators/PinePort  "cảm biến" giá                          MQL5\Indicators\PinePort\*.ex5
│   ├─ Include/{Sim,Exec,                                            MQL5\Include\…
│   │          TrendRider,PinePort}  lõi dùng chung
│   ├─ Scripts/             contract test chạy trong MT5            MQL5\Scripts\
│   └─ Files/               fixture CSV/onnx                        MQL5\Files\
│
├─ configs/sim/*.json       preset (nguồn chuẩn cho input) ──►  reports/build/tester-sets/*.set
├─ scripts/*.py, *.ps1      deploy · build · validate · audit  ──►  reports/build/tester-reports/…
└─ python/src/mt5_ea_ai_lab backtester · ML · ONNX export    ──►  models/candidates/…\model.onnx

RUNTIME MT5 (terminal64.exe)
   Chart ◄── Indicator (tính điểm/plan) ◄── giá tick
     │
     └── EA: OnInit → OnTick(mỗi tick) → OnDeinit
              │            │
              │            ├─ quyết định: ENTRY / EXIT / BLOCK
              │            └─ (chỉ DemoEA) ExecGuard → ExecBroker → server demo
              └─ nhật ký: log trong tab Experts + CSV 18 cột trong MQL5\Files
```

Ba dòng bất biến của kiến trúc này:

| Nguyên tắc | Hệ quả thực tế |
|---|---|
| EA **không** chứa chiến lược, chỉ chứa *luồng điều phối* | đổi chiến lược = sửa `.mqh`, không viết lại EA |
| Mọi quyết định phải để lại **dấu vết máy đọc được** (CSV + `reason`) | có tool audit tự động, không phải nhìn bằng mắt |
| Cấu hình là **dữ liệu** (JSON → `.set`), không phải code | tái lập chính xác một lần chạy bằng `config_hash` |

---

## 2. Giải phẫu một file EA

Nguồn tham chiếu: [`mt5/Experts/PinePlanSimEA.mq5`](../../mt5/Experts/PinePlanSimEA.mq5) — 27 input, 829 dòng.

### 2.1 Sáu khối theo thứ tự trong file

| # | Khối | Dòng | Nội dung bắt buộc |
|---|---|---|---|
| 1 | `#property` | 9–12 | `copyright`, `version`, `description`. Hai dòng description là "nhãn an toàn": *Simulation-only… No trading functions* |
| 2 | `#include` | 14–22 | 6 module `Sim\*` + 3 `PinePort\*Contract.mqh`. EA chỉ include thứ nó thật sự gọi |
| 3 | `enum` cục bộ | 24–36 | `ENUM_PLAN_SOURCE`, `ENUM_PLAN_SIDE_FILTER` — giá trị enum phải khớp `enum_map` trong preset JSON |
| 4 | `input group` | 38–75 | 6 nhóm cấu hình (bảng §7.1). Mỗi input có comment cuối dòng = nhãn hiển thị trong GUI |
| 5 | Biến state + hàm | 77–694 | `CSimPortfolio g_portfolio`, `CSimCostModel g_cost`, `CSimRiskGuard g_risk`, `CSimLogger g_logger` + `g_has_position/g_entry/g_sl/g_target`, bộ đếm `g_trades/g_wins/g_losses/g_net_pnl` |
| 6 | Handler của MT5 | 696–829 | `OnInit` (696) · `OnDeinit` (788) · `OnTick` (798) |

### 2.2 Luồng thời gian thực

```text
OnInit
  ValidateInputs() ──sai──► Print LAB|ERROR + INIT_FAILED (bot không nhận chart)
      │đúng
      ├─ iCustom(Indicator, InpPaRr1, InpPaRrMin)  → g_handle
      ├─ g_portfolio.Init(InpInitialBalance)       → cân bằng ảo
      ├─ g_cost / g_risk .Init(Inp*…               → nạp ngưỡng
      ├─ g_logger.Open(InpLogFile)                 → CSV, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI
      ├─ LogEvent("INIT", … "SIMULATION_ONLY|source=…|config_hash=…")
      └─ Print LAB|INFO|plan|initialized / pa_bridge / simulation_only   (dòng 778–784)

OnTick  (chạy mỗi tick; quyết định chỉ ở nến mới)
  bid/ask = SymbolInfoDouble
  new_bar = (iTime(_Symbol,_Period,0) != g_last_bar)          ← 808-811
  if (đang giữ vị thế)
      CheckExits(bid, ask)        TP/SL + SL_GAP                ← 512
      if new_bar và InpMaxHoldingBars>0 và bars_held ≥ ngưỡng
                                  ClosePosition("MAX_HOLDING_BARS")  ← 816-822
      UpdateTrailing(new_bar)     breakeven + trailing          ← 536
  else if (new_bar && bar chưa xử lý)
      TryEntry(bar_time)                                       ← 582
          ReadPlan()  → PLAN_REJECTED nếu plan_invalid/RR thấp
          g_risk.Check() → ENTRY_BLOCKED|reason=<token>
          không chặn → mở vị thế ẢO + LogEvent("ENTRY", …)

OnDeinit
  WriteSummary() → dòng SUMMARY (entries/trades/wins/losses/net/max_dd/blocks/halted)
  g_logger.Close() · IndicatorRelease(g_handle) · Print LAB|INFO|plan|deinit|reason=…
```

### 2.3 Hợp đồng đầu ra (nhật ký 18 cột)

```text
logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,price,
volume,entry,sl,tp,exposure,equity,drawdown_pct,reason
```

| Trường | Vai trò khi đọc log |
|---|---|
| `event` | `INIT` · `ENTRY` · `EXIT` · `RISK` · `SUMMARY` (DemoEA còn thêm `REGIME` · `BOS` · `TRAIL` · `STATE` · `KILL` · `DRY_RUN` · `ADOPT` · `SYNC` · `ERROR`) |
| `bar_time` | nến áp dụng quyết định; `INIT` dùng epoch `1970.01.01` |
| `config_hash` | "vân tay" toàn bộ input — **cả file phải cùng một hash** |
| `reason` | `LABEL\|key=value\|…` — nơi trả lời "vì sao bot làm/không làm" |

Tool kiểm tra tự động: `scripts\audit_plan_csv.py` (trạng thái `ok`/`issues`).

---

## 3. Thư viện dùng chung

| Module | Trách nhiệm | Ai dùng |
|---|---|---|
| [`Include/Sim/SimPortfolio.mqh`](../../mt5/Include/Sim/SimPortfolio.mqh) | sổ cái vị thế ảo: balance/equity/peak/max_drawdown, `Init(…, contract_size)` | mọi EA mô phỏng |
| `Sim/SimCostModel.mqh` | cộng spread + slippage + commission vào giá khớp | mọi EA mô phỏng |
| `Sim/SimRiskGuard.mqh` | cổng vào lệnh + halting (bảng §8) | mọi EA mô phỏng |
| `Sim/SimTrailing.mqh` | breakeven + trailing (fixed points / ATR) | Runner, Plan, WW |
| `Sim/SimPlan.mqh` | cấu trúc `SimPlan` (entry/sl/tp/ref) + validate RR | `PinePlanSimEA` |
| `Sim/SimLogger.mqh` | ghi CSV 18 cột, `FILE_SHARE_READ` để Python đọc lúc đang chạy | mọi EA |
| `Sim/SimGrid.mqh`, `Sim/SimDca.mqh` | lưới nhiều tầng / giỏ DCA có trần | `GridLabEA`, `DCALabEA` |
| `Sim/SimValidate.mqh` | hàm kiểm input fail-closed | mọi EA |
| `PinePort/*Contract.mqh` | chỉ số buffer + engine tính điểm (không I/O) | EA + indicator + contract test |
| `TrendRider/TR*.mqh` (12 file) | swing → structure → trend → pullback → signal → risk → trailing → state machine → market data → config | `PATrendRiderXAUv1SimEA`, `…DemoEA` |
| [`Include/Exec/ExecGuard.mqh`](../../mt5/Include/Exec/ExecGuard.mqh) | **cổng an ninh**: `ExecContextAllowed`, `ExecSymbolAllowed`, `ExecSymbolTradable`, `ExecTakeProfitValid`, `ExecStopsRespectBroker`, `ExecNormalizeVolume`, `ExecRiskBudgetOk` | chỉ `DemoEA` |
| `Include/Exec/ExecBroker.mqh` | chỗ duy nhất gọi API lệnh, đã kiểm môi trường | chỉ `DemoEA` |

Vì sao tách: `ExecGuard.mqh` là **hàm thuần**, nên kiểm bằng `ExecGuardTests.mq5` (51 test ma trận guard,
không gửi lệnh) mà không cần tài khoản thật. Đây là lý do "đổi chiến lược" không được phép trở thành "sửa nhanh trong EA".

---

## 4. Danh mục bot trong repo

| EA | Input | Vị thế tạo ra ở đâu | vai trò | Trạng thái kiểm chứng |
|---|---|---|---|---|
| `PinePlanSimEA` | 27 | ảo (CSV) | bot "kế hoạch" từ 1 indicator, dễ đọc nhất | PASS Tester + audit `status=ok` |
| `WonderwhalesSimEA` | 35 | ảo | cùng lõi, nguồn tín hiệu Wonderwhales | PASS Tester |
| `RunnerTrailingLabEA` | 27 | ảo | EMA cross + bộ trailing/breakeven để so cấu hình | PASS Tester |
| `GridLabEA` | 24 | ảo | lưới nhiều tầng, có trần volume | PASS mô phỏng; demo qua `GridDemoEA`/`DCADemoEA` (ADR 0004) |
| `DCALabEA` | 21 | ảo | giỏ DCA (adds, volume multiplier, basket stop) | PASS mô phỏng; demo qua `GridDemoEA`/`DCADemoEA` (ADR 0004) |
| `PATrendRiderXAUv1SimEA` | 46 | ảo | chiến lược Price Action TrendRider, đủ 8 nhóm input | PASS Tester |
| **`PATrendRiderXAUv1DemoEA`** | 47 | **demo thật** (qua guard) hoặc dry-run | đường gửi lệnh duy nhất | PASS dry-run + 31 ENTRY/31 EXIT trong Tester; trên tài khoản demo `WAITING_FOR_SETUP`, 0 `ENTRY` do chiến lược |
| `PineSignalLabEA` | 16 | không có | xuất CSV tín hiệu 1 indicator để so parity | PASS |
| `PineMultiSignalLabEA` | 9 | không có | xuất CSV 6 indicator cùng lúc | PASS |
| `LabSignalEA` | 6 | không có | khung export tối giản | PASS |
| `LabOnnxInference` | 4 | không có | chạy **model ONNX** trên fixture, in xác suất | PASS chart + Tester (build 6292) |

---

## 5. Cài đặt

MT5 chỉ đọc **Data Folder** của nó (không đọc repo). Đường dẫn máy này:
`C:\Users\tuanmjnh\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06`.

```text
DATA_FOLDER\MQL5\
├── Experts\            *.mq5 → *.ex5        (bot)
├── Indicators\PinePort\                      (cảm biến — EA iCustom cần ở ĐÂY)
├── Include\Sim | Exec | TrendRider | PinePort\   (thư viện nguồn của #include)
├── Scripts\                                  (contract test, tool xuất dữ liệu)
└── Files\           sim_*.csv · *.onnx · kill-switch · state.csv
```

Lệnh cài (đóng MT5 trước — `.ex5` đang bị khoá thì không ghi/compile được):

```powershell
cd D:\Applications\tm-fx
.\scripts\check-environment.ps1          # kiểm Python, venv, MetaEditor, Data Folder
.\scripts\deploy_pineport.ps1            # dry-run: in ra danh sách sẽ copy
.\scripts\deploy_pineport.ps1 -Apply     # copy thật
.\scripts\build-mql5.ps1                 # compile; cần "0 errors, 0 warnings"
.\scripts\validate-project.py            # static gate 14 kiểm tra
```

Kiểm tra cài đúng (bằng mắt, trong Data Folder): có `MQL5\Experts\PinePlanSimEA.ex5` **và**
`MQL5\Indicators\PinePort\PriceActionMTF.ex5`. Thiếu file thứ hai → log EA báo `indicator_init_failed`.
Sau đó mở MT5 → **Navigator** → nhấn **F5**.

Cài thêm cho bot AI (§11): copy `models\candidates\demo-phase7-ml\model.onnx` và
`python\tests\fixtures\onnx_feature_fixture.csv` vào `MQL5\Files\`.

---

## 6. Cấu hình: 4 tầng và thứ tự ưu tiên

```text
(1) default trong code .mq5        ← "an toàn" nhưng thường KHÔNG trade được
            │  bị ghi đè bởi
(2) preset JSON  configs/sim/*.json ← nguồn chuẩn; validator fail-closed; enum_map + assumptions
            │  hiện thực hoá thành
(3) file .set    *.set (20 file)    ← MT5 Load/Save; reproducible; chạy headless được
            │  bị ghi đè bởi
(4) sửa tay trong hộp thoại Inputs  ← thử nghiệm; nếu muốn dùng lại thì phải Save .set
```

| Tầng | Nằm ở | Dùng khi nào | Bẫy |
|---|---|---|---|
| 1 | `input … = 50.0;` | đọc hiểu mặc định | `InpPaRr1=1.0 < InpPaRrMin=1.5` ⇒ 0 lệnh; `InpMaxSpreadPoints=50` < spread XAUUSDm 160–280 ⇒ toàn `RISK\|ENTRY_BLOCKED` |
| 2 | preset JSON | luôn luôn là nơi *khai* thay đổi | EA **không** tự đọc JSON; JSON chỉ sinh/đối chiếu `.set` |
| 3 | `.set` | chạy Tester, chạy headless, báo cáo | `.set` cũ + code mới ⇒ input lạ bị bỏ qua âm thầm; luôn xem `config_hash` |
| 4 | GUI | khám phá nhanh | quên **Save** là mất cấu hình |

Kiểm chứng tính nhất quán:

```powershell
.\.venv\Scripts\python.exe scripts\validate_sim_configs.py   # SUMMARY: checked=7 fail=0
.\.venv\Scripts\python.exe scripts\validate_demo_execution.py # 8/8 (ranh giới demo/live)
```

`config_hash` (8 hex, ví dụ `D6CEF886`) do `BuildConfigHash()` tổng hợp từ toàn bộ input; một file CSV có
hai hash = hai lần chạy bị trộn (`kind=mixed_config_hash`).

Chạy headless (không cần mở GUI): [`reports/build/tester-run/run_tester.ps1`](../../reports/build/tester-run/run_tester.ps1) `-Scenario plan_rr2`
đọc `plan_rr2.ini` (`Expert`, `ExpertParameters=plan_rr2.set`, `Model=1`, `Visual=0`, `ShutdownTerminal=1`,
`Report=tester_plan_rr2`) và từ chối khởi động nếu `terminal64` đang mở.

---

## 7. Bảng tham số đầy đủ theo bot

Ký hiệu: **Default** = giá trị trong code; **Preset** = giá trị khuyến nghị cho `XAUUSDm` đã kiểm chứng
(`plan_rr2.set` / `configs/sim/pine_plan_lab.json`); `0` thường nghĩa là *tắt kiểm tra*.

### 7.1 `PinePlanSimEA` — 27 input, 6 nhóm

Nhóm **Simulation**

| Input | Default | Preset | Đơn vị/Ý nghĩa | Ảnh hưởng |
|---|---|---|---|---|
| `InpSource` | `PLAN_SOURCE_PA` | — | nguồn plan: `0` PriceActionMTF · `1` TMXAUSignals2 · `2` TMIndicator2 | đổi nguồn = đổi cả log (`source=`) |
| `InpInitialBalance` | 10 000.0 | 10 000.0 | cân bằng ảo ban đầu | kéo theo `drawdown_pct` |
| `InpVolume` | 1.0 | 1.0 | khối lượng **ảo** mỗi lần vào (không phải lot) | tuyến tính trên `pnl` |
| `InpEnableLog` | true | true | bật/tắt CSV | tắt là mất toàn bộ bằng chứng |
| `InpLogFile` | `sim_plan_log.csv` | `sim_plan_rr2.csv` | tên file trong `MQL5\Files` | dùng chung tên = ghi đè/trộn run |
| `InpDebug` | false | false | thêm dòng `LAB\|DEBUG\|…` từng nến | hữu ích khi soi lý do |

Nhóm **Plan**

| Input | Default | Preset | Ý nghĩa |
|---|---|---|---|
| `InpSideFilter` | `PLAN_SIDE_BOTH` | BOTH | `1` chỉ LONG · `-1` chỉ SHORT (ghi `DIR` khi bị lọc) |
| `InpTargetMode` | `SIM_PLAN_TARGET_TP1` | TP1 | `0` TP1 · `1` TP3 · `2` không TP (chỉ SL/time) |
| `InpMinStopPoints` | 5.0 | 5.0 | SL gần hơn ⇒ `PLAN_REJECTED` |
| `InpMinTargetPoints` | 5.0 | 5.0 | target gần hơn ⇒ `PLAN_REJECTED` |
| `InpMaxHoldingBars` | 0 (tắt) | 0 | quá N nến ⇒ `EXIT reason=MAX_HOLDING_BARS` |

Nhóm **Indicator bridge (PriceActionMTF only)**

| Input | Default | Preset | Ý nghĩa |
|---|---|---|---|
| `InpPaRr1` | **1.0** | **2.0** | R của TP1; forward vào indicator |
| `InpPaRrMin` | 1.5 | 1.5 | R tối thiểu để plan hợp lệ — **bẫy §6** |

Nhóm **Management**

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpBreakEvenEnabled` | false | bật dời SL về hoà vốn |
| `InpBreakEvenTriggerPoints` | 400.0 | lãi bao nhiêu (points) thì arm |
| `InpBreakEvenOffsetPoints` | 0.0 | đặt SL lệch bao nhiêu so entry khi đã arm |
| `InpTrailEnabled` | false | bật trailing |
| `InpTrailFixedPoints` | 300.0 | khoảng cách trailing cố định |
| `InpMinStopPointsTrail` | 5.0 | sàn khoảng cách SL khi trailing |

Nhóm **RiskGuard**

| Input | Default | Preset | Ý nghĩa |
|---|---|---|---|
| `InpCooldownBars` | 1 | 1 | số nến nghỉ sau mỗi lần đóng |
| `InpMaxSpreadPoints` | **50.0** | **600.0** | spread lớn hơn ⇒ `spread_exceeded` |
| `InpMaxVirtualExposure` | 1.0 | 1.0 | trần độ hở (volume ảo) |
| `InpMaxDailyLossPct` | 2.0 | 2.0 | 0 = tắt; chạm ⇒ halt `daily_loss_limit_reached` |
| `InpMaxDrawdownPct` | 5.0 | 5.0 | 0 = tắt; chạm ⇒ halt `max_drawdown_reached` |
| `InpHaltOnBreach` | false | false | true = **dừng hẳn** sau halt; false = chỉ chặn thêm lệnh mới |

Nhóm **Costs (modelled)**

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpCommissionPerVolume` | 0.0 | phí tiền cho mỗi fill theo volume |
| `InpSlippagePoints` | 0.0 | trượt giá bất lợi cộng vào mọi fill |

### 7.2 `PATrendRiderXAUv1DemoEA` — 47 input, 7 nhóm (đường có lệnh thật)

Nhóm **Demo execution** — quyết định an toàn, đọc kỹ trước khi đổi

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpEnableExecution` | **false** | false = **dry-run** (chỉ log ý định). true = gửi lệnh demo, *vẫn* bị ExecGuard chặn nếu không phải demo/tester |
| `InpAllowedSymbols` | `XAUUSD` | allow-list **prefix**, phân tách bằng dấu phẩy |
| `InpMagicNumber` | 25002001 | gắn nhãn lệnh của bot để đối soát và không đụng lệnh tay |
| `InpMaxSlippagePoints` | 30 | deviation cho lệnh market |
| `InpTakeProfitR` | 3.0 | TP = entry ± R × 3.0 |
| `InpKillSwitchFile` | `PA_TREND_RIDER_DEMO_STOP.txt` | **tạo file này trong `MQL5\Files` = bot ngừng vào lệnh ngay** |

Nhóm **Journal and state**

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpEnableLog` / `InpLogFile` | true / `pa_trendrider_demo.csv` | nhật ký 18 cột |
| `InpPersistState` / `InpStateFile` | true / `pa_trendrider_demo_state.csv` | lưu state machine + ledger để restart không "quên" vị thế |
| `InpResetStateOnInit` | false | true = xoá state khi khởi động (chỉ khi chủ đích) |
| `InpDebug` | false | log chi tiết từng bước gate |

Nhóm **Timeframes / Structure / Risk / Stops / Volatility** (rút gọn những ô hay chỉnh)

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpTrendTF` / `InpStructureTF` / `InpEntryTF` | H1 / M15 / M5 | ba khung nhìn của chiến lược |
| `InpTrendBars` / `InpStructureBars` / `InpEntryBars` | 300/300/400 | số nến nạp |
| `InpSwingLeft`/`InpSwingRight` | 2/2 | cửa sổ xác nhận pivot |
| `InpMaxSignalAgeBars` | 8 | tín hiệu cũ hơn ⇒ bỏ |
| `InpRiskPercent` | 0.25 | rủi ro mỗi lệnh, % cân bằng — **tính sizing** |
| `InpMaxPositions` | 1 | trần vị thế đồng thời |
| `InpDailyLossLimitPct` / `InpMaxDrawdownPct` | 1.0 / 8.0 | hai ngưỡng halt |
| `InpMaxConsecutiveLosses` | 3 | 3 thua liên tiếp ⇒ cooldown |
| `InpCooldownMinutes` | 30 | độ dài cooldown |
| `InpBreakEvenAtR` / `InpTrailingStartR` | 1.0 / 1.5 | mốc R để arm |
| `InpAtrStopBuffer` / `InpAtrTrailingMultiplier` | 0.2 / 1.2 | SL và trailing theo ATR |
| `InpMinSlAtr` / `InpMaxSlAtr` | 0.5 / 4.0 | kẹp khoảng cách SL |
| `InpUpdateOnClosedBarOnly` | true | chỉ dời SL/TP ở nến đã đóng |
| `InpAbnormalAtrRatio` | 2.5 | ATR bất thường ⇒ chặn |
| `InpMaxSpreadPoints` / `InpMaxSpreadAtrRatio` | 600.0 / 0.25 | hai cổng spread |

### 7.3 `GridLabEA` (24) và `DCALabEA` (21) — tham số đặc trưng

| Bot | Input | Default | Ý nghĩa |
|---|---|---|---|
| Grid | `InpGridSide` | GRID_LONG | hướng giỏ lệnh |
| Grid | `InpSpacingMode` / `InpSpacingPoints` | FIXED / 300.0 | khoảng cách tầng |
| Grid | `InpAtrPeriod` / `InpAtrMultiplier` | 14 / 1.0 | spacing theo ATR |
| Grid | `InpMaxGridLevels` | 5 | tổng số tầng gồm tầng đầu |
| Grid | `InpBaseVirtualVolume` / `InpVolumeMultiplier` / `InpMaxLevelVolume` | 0.10 / 1.50 / 1.00 | cấp số nhân volume + trần mỗi tầng |
| Grid | `InpExitMode` / `InpLevelTargetPoints` / `InpBasketTargetPoints` / `InpBasketStopPoints` | BASKET / 300 / 600 / **900 (bắt buộc)** | thoát từng tầng hay cả giỏ; giỏ **luôn** phải có stop |
| DCA | `InpDcaSide` | DCA_LONG | hướng giỏ |
| DCA | `InpTriggerMode` / `InpDcaDistancePoints` / `InpBarsBetweenAdds` | PRICE / 300 / 5 | điều kiện "them trứng" |
| DCA | `InpMaxDcaAdds` | 3 | `0` = không add (dùng để test cạnh) |
| DCA | `InpBaseVirtualVolume` / `InpAddVolumeMultiplier` / `InpMaxAddVolume` | 0.10 / 1.50 / 1.00 | khối lượng add + trần |
| DCA | `InpBasketTargetPoints` / `InpBasketStopPoints` | 600 / 900 | thoát/thua theo giá vào trung bình |
| Cả hai | `InpMaxVirtualExposure` | 2.0 | trần độ hở đã chuẩn hoá |

> Grid/DCA nay có đường demo riêng (`GridDemoEA`/`DCADemoEA`, ADR 0004 đã được duyệt). Phiên demo thật vẫn `NOT_RUN` cho tới khi có journal.

### 7.4 `RunnerTrailingLabEA` — bộ tham số để so nghiệm pháp trailing

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpFastEma` / `InpSlowEma` / `InpAtrPeriod` | 20 / 50 / 14 | tín hiệu cross + ATR |
| `InpAtrSlMultiplier` | 2.0 | SL khởi tạo = ATR × hệ số |
| `InpTrailMode` | RUNNER_TRAIL_ATR | `FIXED` dùng `InpTrailFixedPoints`, `ATR` dùng `InpTrailAtrMultiplier` |
| `InpBreakEvenTriggerPoints` / `InpBreakEvenOffsetPoints` | 400 / 0 | arm hoà vốn |
| `InpMaxHoldingBars` | 0 | cutoff thời gian giữ lệnh |

### 7.5 Bot xuất tín hiệu (không có vị thế)

| Bot | Input chính | Đầu ra |
|---|---|---|
| `PineSignalLabEA` | `InpMode`, `InpPsarStart/Inc/Max`, `InpFastEma/SlowEma/Ema200`, `InpAtrLen`, `InpMinAtrPct`, `InpVolMaLen`, `InpWarmupBars=300`, `InpOutputFile=pine_signal_log.csv` | CSV tín hiệu từng nến để so với Pine |
| `PineMultiSignalLabEA` | `InpEnableWw/Lk/Fz/Pa/X2/Tm2` (bật 6 nguồn, mặc định chỉ WW), `InpWarmupBars`, `InpOutputFile=pine_multi_signal_log.csv` | CSV 6 nguồn cùng kỳ |

### 7.6 `LabOnnxInference` — 4 input (bot AI)

| Input | Default | Ý nghĩa |
|---|---|---|
| `InpModelFile` | `model.onnx` | **đường dẫn tương đối so với `MQL5\Files`** |
| `InpFeatureFile` | `onnx_feature_fixture.csv` | fixture dòng feature |
| `InpFeatureCount` | 12 | **phải khớp** `metadata.input.feature_names` của model |
| `InpMaxRows` | 0 | 0 = chạy hết fixture |

---

## 8. Cổng rủi ro: token lý do và halting

`CSimRiskGuard` trả về hai hạng: **block** (từ chối lệnh này, phiên vẫn chạy) và **halt** (dừng cấp lệnh,
ghi `halted=HALTED` trong `SUMMARY`). Token là hợp đồng ổn định — đừng đổi tên, và hãy grep nguyên văn:

| Token | Loại | Kích hoạt bởi | Cách xử lý đúng |
|---|---|---|---|
| `spread_exceeded` | block | `InpMaxSpreadPoints` | dùng preset 600 cho XAUUSDm, hoặc chờ phiên spread thấp |
| `cooldown_active` | block | `InpCooldownBars` | bình thường, không cần sửa |
| `max_virtual_positions_reached` | block | trần vị thế | thiết kế 1 vị thế |
| `max_virtual_exposure_reached` | block | `InpMaxVirtualExposure` | chỉ nới khi chủ đích test |
| `max_grid_levels_reached` / `max_dca_adds_reached` | block | trần lưới/add | hành vi biên của Grid/DCA |
| `daily_loss_limit_reached` | **halt** | `InpMaxDailyLossPct` | dừng theo thiết kế — **không** nâng ngưỡng để "cho bot chạy tiếp" |
| `max_drawdown_reached` | **halt** | `InpMaxDrawdownPct` | như trên (run mẫu halt ở 5.021 %) |
| `risk_guard_not_initialized` | halt | gọi check trước `Init` | lỗi code, không phải lỗi thị trường |

Bốn bước chẩn đoán khi bot "im re": log `initialized|hash=` → `pa_bridge|rr1=` → đếm `RISK|ENTRY_BLOCKED`
và đọc `reason=` → chạy `audit_plan_csv.py`.

---

## 9. Thao tác trên GUI MT5 desktop

| Mục đích | Đường dẫn thao tác | Ghi chú đã kiểm |
|---|---|---|
| Mở Strategy Tester | `Ctrl+R` | tab trái Toolbox |
| Chọn bot | Expert → `PinePlanSimEA` | rỗng ⇒ chưa compile/F5 (§5) |
| Cấu hình | tab **Inputs → Load** → `.set` → **Save** | bắt buộc với `plan_rr2.set` |
| Xem nến chạy | tích **Visualize** (chỉ hiện khi Optimization = Disabled) | kéo thanh trượt tốc độ, nhấn **Pause** |
| Chạy thật trên chart | `Ctrl+N` → kéo EA vào chart → tab **Common** tick **Allow Algo Trading** → **OK** | hai công tắc: global `Tools → Options → Expert Advisors → Allow Algorithmic Trading` + nút **Algo Trading** trên toolbar, và tick per-EA ở Common |
| Biết bot đang sống | icon trạng thái **góc trên bên phải** chart (xanh chạy / xám bị tắt) + log tab **Experts** | log đáng tin hơn icon |
| Đọc log | `Ctrl+T` → tab **Experts** (runtime) · tab **Journal** (Tester) | hai nơi khác nhau |
| Bảng trạng thái DemoEA | góc trên **trái** chart (`Comment()`) | in `DRY_RUN/DEMO_EXECUTION`, `state`, `block`, `position`, `dd`, `kill` |
| Mở file log/CSV | **File → Open Data Folder** → `MQL5\Files` | Tester ghi vào Data Folder **tạm** của agent |
| Gỡ bot | chuột phải chart → **Expert Advisors → Remove** | `OnDeinit` ghi `SUMMARY` trước khi rời |
| Tạm dừng | tắt nút **Algo Trading** | bot giữ state trong bộ nhớ |
| Kill switch (DemoEA) | tạo file `PA_TREND_RIDER_DEMO_STOP.txt` trong `MQL5\Files` | chặn vào lệnh ngay, không cần gỡ bot |

---

## 10. Vòng đời một vị thế

```text
            ┌──────────────────────────────── PLAN_REJECTED (plan_invalid / RR thấp)
            │
  FLAT ─────┴─► RISK check ──► ENTRY (price = ask/bid + spread + slippage)
                   │block: RISK|ENTRY_BLOCKED|reason=<token>
                   ▼
              IN POSITION   exposure=1 · equity theo mark-to-market
                   ├─ TP chạm ────────────► EXIT reason=TARGET_HIT|mode=TP1|bars=…|pnl=…
                   ├─ SL chạm ────────────► EXIT reason=SL_HIT
                   ├─ giá nhảy qua SL ────► EXIT reason=SL_GAP|gap_points=…
                   ├─ quá InpMaxHoldingBars► EXIT reason=MAX_HOLDING_BARS
                   ├─ breakeven arm ──────► SL dời về entry (+offset)
                   └─ trailing mỗi nến ───► SL dời theo (TRAIL_REJECTED nếu vi phạm sàn)
                   ▼
              FLAT + cooldown InpCooldownBars nến
  (halt) daily_loss / max_drawdown ──► HALTED: không ENTRY nữa, SUMMARY ghi halted=HALTED
```

| Vấn đề thực chiến | Trả lời |
|---|---|
| EA mô phỏng có hiện ở tab **Positions**? | **Không**. Vị thế chỉ tồn tại trong bot + CSV; Tester báo `Deals: 0` là đúng |
| DemoEA thì sao? | Có, khi `InpEnableExecution=true` *và* ExecGuard cho phép; đối soát bằng `InpMagicNumber` ở tab **History** |
| Hai EA cùng một tài khoản? | tách bằng magic + allow-list symbol; mặc định `InpMaxPositions=1` |
| Bạn tự tay đóng lệnh của DemoEA? | phiên sau bot học từ file state + ledger; **đừng** tắt `InpPersistState` |
| Restart MT5 giữa chừng? | DemoEA nạp lại `pa_trendrider_demo_state.csv`; EA mô phỏng chạy lại từ đầu nên phải có `.set` + log |

---

## 11. Ghép bot EA với AI

### 11.1 Ba mức tích hợp (tăng dần chi phí)

| Mức | Là gì | Trong repo | Độ chín |
|---|---|---|---|
| A — scoring rule-based | indicator tự cho điểm `rawScore ∈ [-1,1]` → `score100 = 50 + rawScore*50`, cổng `okScore = score100 > InpScrNoTrade` | `PriceActionMTFContract.mqh` + `PinePlanSimEA` | ĐANG CHẠY. Lưu ý `Q11`: cửa short gần như luôn bị chặn ⇒ bot chỉ BUY |
| B — ML inference ONNX | Python train → xuất ONNX → EA `OnnxRun` ra xác suất → dùng xác suất làm **cửa thêm** | `LabOnnxInference.mq5`, `scripts\export_onnx_model.py` | PASS cho model logistic + fixture; **chưa** đọc feature từ bar live |
| C — AI quyết định sizing/hướng + EA thực thi | model chọn hướng/kích thước, EA vẫn giữ RiskGuard + ExecGuard | chưa tồn tại | `NOT_RUN` — và chỉ được làm trên demo, sau ADR |

### 11.2 Pipeline B, lệnh thật

```text
CSV nến/synthetic ─► scripts/generate_synthetic_ml_dataset.py
                  ─► scripts/train_ml_baseline.py --config … --out-dir reports\ml\… --store … --db … --experiment-id …
                       (feature pipeline + label không rò rỉ + time split có purge + logistic)
                  ─► reports\ml\demo-phase7-ml\model.json   (12 feature, mean/scale, threshold)
                  ─► scripts/export_onnx_model.py --model … --out-dir models\candidates\demo-phase7-ml
                          --fixture python\tests\fixtures\onnx_feature_fixture.csv --opset 13 --tolerance 1e-5
                  ─► models\candidates\demo-phase7-ml\model.onnx  (SHA-256 ghi trong docs/reference/onnx.md)
                  ─► copy vào DATA_FOLDER\MQL5\Files
                  ─► LabOnnxInference.mq5: OnnxCreate(30) → matrixf(1,12) → OnnxRun(113) → probability
```

Một lệnh cho cả chuỗi nghiên cứu (backtest + ML + báo cáo): `scripts\run_pipeline.py --config … --run-id …`.

### 11.3 Bảng cấu hình phía AI — những thứ phải khớp tuyệt đối

| Hợp đồng | Nơi khai | Nơi EA phải khớp | Lệch thì |
|---|---|---|---|
| Thứ tự feature | `feature_schema.json` / `metadata.input.feature_names`: `return_1, return_3, return_5, return_10, ema_gap, ema_slope, volatility, return_z, stochastic, range_ratio, body_ratio, volume_z` | code dựng vector | model vẫn chạy, ra số **sai mà không báo lỗi** |
| Số feature | 12 | `InpFeatureCount` (dựng `matrixf(1, InpFeatureCount)`) | `OnnxRun` trả lỗi, EA in `OnnxRun failed at row …` rồi dừng |
| Kiểu dữ liệu | `float32`, input shape `[batch,12]` | `matrixf` + cast `(float)` | sai dtype ⇒ lỗi run |
| Chuẩn hoá | mean/scale **nhúng trong graph** (Sub/Div) | EA *không* tự chuẩn hoá | chuẩn hoá 2 lần ⇒ xác suất vô nghĩa |
| Ngưỡng quyết định | `decision_threshold = 0.5` trong `reports\ml\demo-phase7-ml\model.json` | nơi gate ENTRY | đổi ngưỡng = đổi chiến lược, phải ghi rõ trong preset |
| Opset / IR | opset 13, IR 8 | runtime ONNX của build 6292 | build terminal khác: `CHƯA KIỂM` |
| Đóng gói khi test | `#property tester_file "model.onnx"` (dòng 11) + fixture | — | Tester agent không có model ⇒ fail |
| Parity | dung sai tuyệt đối `1e-5`, 24 hàng | so Python ↔ ONNX | lệch là dừng, không "chấp nhận gần đúng" |

### 11.4 Công thức ghép an toàn (khuyến nghị)

```text
VÀO LỆNH  =  plan hợp lệ (SimPlan, RR ≥ InpPaRrMin)
          ∧  RiskGuard không block (spread/độ hở/cooldown)
          ∧  chưa HALTED (daily loss, drawdown)
          ∧  P(thắng) ≥ threshold            ← phần AI, chỉ là CỬA THÊM
```

Ba quy tắc không được phép đổi:
1. Model **không bao giờ** là cửa duy nhất; cổng rủi ro vẫn là chốt cuối.
2. Feature phải tính từ dữ liệu **đã đóng nến**, cùng công thức với lúc train (không leak).
3. Mọi đổi ngưỡng/feature phải thành preset + `.set` mới, kèm `config_hash`, không sửa tay trong GUI rồi báo cáo.

---

## 12. Trạng thái bằng chứng và việc chưa kiểm

| Hạng mục | Trạng thái |
|---|---|
| Compile toàn bộ source | PASS `0 errors, 0 warnings` (build 6292) |
| `PinePlanSimEA` trong Tester | PASS; audit CSV `status=ok`, 93 ENTRY/93 EXIT, 0 issue |
| `DemoEA` dry-run trên demo | PASS |
| `DemoEA` đường gửi lệnh trong Tester | PASS 31 ENTRY/31 EXIT |
| Broker demo nhận lệnh thật | PASS qua `ExecDemoProbe` |
| `DemoEA` tạo `ENTRY` do chiến lược trên tài khoản demo | **`NOT_RUN`** — đang `WAITING_FOR_SETUP` |
| Grid/DCA trên demo | `ALLOWED` (ADR 0004); phiên demo thật `NOT_RUN` |
| ONNX inference | PASS build 6292; **chưa kiểm**: build khác, model phi tuyến, feature đọc từ bar hiện tại |
| Parity với Pine (indicator nguồn) | **`BLOCKED`** — chưa có CSV Pine |
| Lợi nhuận mọi chiến lược | **`UNPROVEN`** |

Số liệu chạy thật nằm ở [`../v2/EVIDENCE.md`](../v2/EVIDENCE.md) và [`../v2/TEST_REPORT.md`](../v2/TEST_REPORT.md);
nhật ký theo ngày ở [`../PROGRESS.md`](../PROGRESS.md).

---

## 13. Đọc tiếp

| Bạn muốn… | Đọc |
|---|---|
| Lần chạy đầu tiên, click-by-click | [`beginner-first-run.md`](beginner-first-run.md) |
| Cài đặt/compile/test theo Track | [`install-and-test.md`](install-and-test.md) |
| Chạy bot demo có giám sát, kill switch | [`demo-execution.md`](demo-execution.md) |
| Ma trận scenario + preset Tester | [`strategy-tester.md`](strategy-tester.md) |
| Script check/build/test/validate/package | [`toolchain.md`](toolchain.md) |
| Chi tiết cổng điểm số và quirk | [`../indicators/price-action-mtf.md`](../indicators/price-action-mtf.md) §10.5 |
| Chi tiết pipeline ONNX | [`../reference/onnx.md`](../reference/onnx.md) |
| Mô hình rủi ro và sizing | [`../v2/RISK_MODEL.md`](../v2/RISK_MODEL.md) |
