# Giải phẫu bot EA: cấu trúc chung, cài đặt, cấu hình, thao tác GUI

**Phiên bản:** 1.1 · **Cập nhật:** 2026-11-03
**Phạm vi:** mọi nhận định trong file này lấy từ code và artifact thật của repo `D:\Applications\tm-fx`
(MQL5 build 6292, symbol `XAUUSDm`). Không có nội dung suy đoán về UI của nhà cung cấp khác.
**Người đọc mục tiêu:** bạn đã chạy xong [`../00-start/first-run.md`](../00-start/first-run.md) và giờ muốn hiểu
*từng khối của một con bot*.
**Phần AI đã tách sang** [`../30-research/ai-integration.md`](../30-research/ai-integration.md);
**bảng tham số theo bot đã bỏ** — nguồn sự thật là bảng input trong 5 trang bot
([`pa-trendrider.md`](pa-trendrider.md) · [`grid.md`](grid.md) · [`dca.md`](dca.md) ·
[`infinite-runner.md`](infinite-runner.md) · [`wonderwhales.md`](wonderwhales.md)) và
[`input-convention.md`](input-convention.md).

> **Ranh giới an toàn (ADR 0003, [`../90-decisions/0003-demo-execution-scope.md`](../90-decisions/0003-demo-execution-scope.md)):**
> repository phục vụ nghiên cứu offline, mô phỏng và **demo execution có guardrail**. EA mô phỏng không
> chứa `OrderSend`/`CTrade`; đường gửi lệnh duy nhất là 5 EA demo + `mt5\Include\Exec\*`,
> chỉ nhận tài khoản **demo** hoặc Strategy Tester. Tài khoản real/live bị cấm.
> Không credential. **Lợi nhuận của mọi chiến lược: `UNPROVEN`.**

## Mục lục

1. [Sơ đồ tổng quan hệ thống](#1-sơ-đồ-tổng-quan-hệ-thống)
2. [Giải phẫu một file EA](#2-giải-phẫu-một-file-ea)
3. [Thư viện dùng chung](#3-thư-viện-dùng-chung)
4. [Danh mục bot trong repo](#4-danh-mục-bot-trong-repo)
5. [Cài đặt](#5-cài-đặt)
6. [Cấu hình: 4 tầng và thứ tự ưu tiên](#6-cấu-hình-4-tầng-và-thứ-tự-ưu-tiên)
7. [Cổng rủi ro: token lý do và halting](#7-cổng-rủi-ro-token-lý-do-và-halting)
8. [Thao tác trên GUI MT5 desktop](#8-thao-tác-trên-gui-mt5-desktop)
9. [Vòng đời một vị thế](#9-vòng-đời-một-vị-thế)
10. [Trạng thái bằng chứng và việc chưa kiểm](#10-trạng-thại-bằng-chứng-và-việc-chưa-kiểm)
11. [Đọc tiếp](#11-đọc-tiếp)

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
| 4 | `input group` | 38–75 | 6 nhóm cấu hình (bảng nhóm ở [`input-convention.md`](input-convention.md) §1). Mỗi input có comment cuối dòng = nhãn hiển thị trong GUI |
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
| `Sim/SimRiskGuard.mqh` | cổng vào lệnh + halting (bảng §7) | mọi EA mô phỏng |
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

Danh mục đầy đủ **15 EA** (5 demo + 6 sim + 3 signal + 1 inference) với magic, preset và nhãn bằng chứng:
[`README.md`](README.md) — mục lục cục bộ của thư mục `10-bots/`.
Trang chi tiết từng bot demo: [`pa-trendrider.md`](pa-trendrider.md) · [`grid.md`](grid.md) ·
[`dca.md`](dca.md) · [`infinite-runner.md`](infinite-runner.md) · [`wonderwhales.md`](wonderwhales.md).
Chuẩn input dùng chung cho 5 EA demo (hợp đồng phase C): [`input-convention.md`](input-convention.md).

---

## 5. Cài đặt

Cài đặt/compile/deploy từng bước, yêu cầu gate và cách kiểm tra Data Folder: [`../20-operations/install.md`](../20-operations/install.md).
Tóm tắt: MT5 chỉ đọc **Data Folder** của nó (không đọc repo); deploy bằng `scripts\deploy_pineport.ps1`,
compile bằng `scripts\build-mql5.ps1` (yêu cầu "0 errors, 0 warnings"), sau đó mở MT5 → **Navigator** → **F5**.

---

## 6. Cấu hình: 4 tầng và thứ tự ưu tiên

Bốn tầng cấu hình (default code → JSON → `.set` → GUI), quy tắc đổi preset an toàn và kiểm chứng
`config_hash`: [`../20-operations/presets.md`](../20-operations/presets.md).
Tóm tắt: preset JSON (`configs/demo/*.json`, `configs/sim/*.json`) là **nguồn sự thật**; file `.set` là
dẫn xuất cho Strategy Tester; sửa tay trong hộp thoại Inputs phải **Save** `.set` nếu muốn dùng lại.

---

## 7. Cổng rủi ro: token lý do và halting

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

## 8. Thao tác trên GUI MT5 desktop

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

## 9. Vòng đời một vị thế

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

## 10. Trạng thái bằng chứng và việc chưa kiểm

Nhãn trạng thái là hợp đồng dự án (`DONE / PASS / PARTIAL / NOT_RUN / BLOCKED / UNPROVEN`) — không được
nâng cấp khi chưa có bằng chứng. Danh mục 15 EA với nhãn hiện tại của **từng EA**:
[`README.md`](README.md). Bảng dưới chỉ giữ các nhận định tổng quát đã kiểm:

| Hạng mục | Trạng thái |
|---|---|
| Compile toàn bộ source | PASS `0 errors, 0 warnings` (build 6292) |
| `PinePlanSimEA` trong Tester | PASS; audit CSV `status=ok`, 93 ENTRY/93 EXIT, 0 issue |
| `DemoEA` dry-run trên demo | PASS |
| `DemoEA` đường gửi lệnh trong Tester | PASS 31 ENTRY/31 EXIT |
| Broker demo nhận lệnh thật | PASS qua `ExecDemoProbe` |
| `DemoEA` tạo `ENTRY` do chiến lược trên tài khoản demo | **`NOT_RUN`** — đang `WAITING_FOR_SETUP` |
| Grid/DCA trên demo | `ALLOWED` (ADR 0004); phiên demo thật `NOT_RUN` |
| ONNX inference (`LabOnnxInference`) | **`PARTIAL`** — tester + chart chạy được (PROGRESS §50), parity Track B vẫn `BLOCKED` |
| `LabSignalEA` | **`PASS`** (PROGRESS §48.5 — tester PASS, 0 trade đúng thiết kế signal-only) |
| Các EA lab còn lại | **`NOT_RUN`** — chưa có mục bằng chứng riêng trong PROGRESS |
| Lợi nhuận mọi chiến lược | **`UNPROVEN`** |

Nhãn từng EA demo: PA `PARTIAL` (đường lệnh có bằng chứng, chưa có ENTRY trên chart demo); Grid/DCA
`NOT_RUN`; WW `UNPROVEN` (tester đã chạy, net −625.72). Số liệu chạy thật nằm ở `99-archive/MT5_EA_Lab_V2/`
(`EVIDENCE.md`, `TEST_REPORT.md`); nhật ký theo ngày ở [`../PROGRESS.md`](../PROGRESS.md).

---

## 11. Đọc tiếp

| Bạn muốn… | Đọc |
|---|---|
| Lần chạy đầu tiên, click-by-click | [`../00-start/first-run.md`](../00-start/first-run.md) |
| Cài đặt/compile/deploy | [`../20-operations/install.md`](../20-operations/install.md) |
| Chạy bot demo có giám sát, kill switch | [`../20-operations/demo-execution.md`](../20-operations/demo-execution.md) |
| Ma trận scenario + preset Tester | [`../20-operations/strategy-tester.md`](../20-operations/strategy-tester.md) |
| Script check/build/test/validate/package | [`../20-operations/toolchain.md`](../20-operations/toolchain.md) |
| Danh mục 15 EA + nhãn bằng chứng | [`README.md`](README.md) |
| Chuẩn input dùng chung (phase C) | [`input-convention.md`](input-convention.md) |
| Chi tiết từng bot demo | [`pa-trendrider.md`](pa-trendrider.md) · [`grid.md`](grid.md) · [`dca.md`](dca.md) · [`infinite-runner.md`](infinite-runner.md) · [`wonderwhales.md`](wonderwhales.md) |
| Ghép bot EA với AI (3 mức, pipeline ONNX) | [`../30-research/ai-integration.md`](../30-research/ai-integration.md) |
| Chi tiết cổng điểm số và quirk | [`../30-research/indicators/price-action-mtf.md`](../30-research/indicators/price-action-mtf.md) §10.5 |
| Chi tiết pipeline ONNX | [`../30-research/onnx.md`](../30-research/onnx.md) |
| Mô hình rủi ro và sizing | [`../30-research/risk.md`](../30-research/risk.md) |
