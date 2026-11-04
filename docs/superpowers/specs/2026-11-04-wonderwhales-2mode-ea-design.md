# Thiết kế: Wonderwhales XAU 2-mode demo EA (Scalp + Swing)

- **Ngày:** 2026-11-04
- **Trạng thái:** DRAFT — chờ chủ dự án duyệt (chưa viết mã)
- **Nguồn yêu cầu:** [`../../10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md`](../../10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md)
  (spec v2.2, tiếng Việt, hai chế độ + trailing SL scalp)
- **Ràng buộc nền:** ADR 0003/0004/0006 (demo/tester only, một điểm gửi lệnh, mặc định bật execution) và
  quy chuẩn input [`../../10-bots/input-convention.md`](../../10-bots/input-convention.md)

---

## 1. Bối cảnh và mục tiêu

Spec v2.2 mô tả một EA Wonderwhales XAU **hai chế độ**: Scalp (M15 bias / M5 setup / M1 trigger) và
Swing (W1 bias / D1 setup / H1 trigger), bảo toàn vốn trước, SL/TP bắt buộc, BE + trailing có quy tắc,
risk guard theo ngày/tuần/drawdown. Spec tự ghi `IMPLEMENTATION_BLOCKED_BY_MISSING_MQL5_SOURCE_FILES`,
nhưng các file nguồn đó **đều có trong repo** — blocker gỡ được.

**Mục tiêu:** dựng EA demo 2 chế độ, chạy được trên XAUUSDm demo Exness và Strategy Tester, đúng quy
chuẩn dự án; tín hiệu lấy từ indicator `PinePort\Wonderwhales` hiện có (không tự tính lại chỉ báo).

**Vì sao:** người dùng cần một bot XAUUSD có cấu trúc quản lý vốn/trailing rõ ràng hơn `WonderwhalesDemoEA`
v1 (chỉ SL/TP, chưa BE/trailing), và tách Scalp/Swing để đo riêng từng chế độ.

## 2. Goals / Non-goals / Anti-goals

**Goals**
- EA MỚI `WonderwhalesXAU2ModeEA.mq5` với `InpTradingMode` = `SIGNAL_ONLY` | `SCALP` | `SWING`.
- Tín hiệu đọc từ contract 18 buffer; **xác minh buffer + parity Pine↔MT5 trước khi tin tín hiệu**.
- SL/TP bắt buộc mọi lệnh; volume theo `OrderCalcProfit` (không lot cố định); min-lot vượt risk → bỏ lệnh.
- Risk guard bền vững: lỗ ngày/tuần, drawdown (high-water mark), chuỗi thua, cooldown, exposure.
- BE + trailing coordinator (chỉ siết SL, không nới), R tính từ **initial SL**.
- Chạy được: compile `0/0`, tester riêng cho Scalp và Swing, forward demo.

**Non-goals (đợt này)**
- Tài khoản real (vẫn cấm; cần ADR riêng).
- Chạy đồng thời Scalp + Swing trên cùng tài khoản (spec §1.2 hoãn).
- Partial close, tối ưu tham số hàng loạt, VSA/RSI/BB làm bộ lọc (spec §5.3).
- Chạy lại/reset bộ bằng chứng tester cũ (đó là việc khác, đang hoãn).

**Anti-goals**
- Grid/DCA/martingale/nhồi lệnh khi âm; tăng lot gỡ lỗ.
- Nới SL ra xa; trailing quá sát theo tick.
- Bịa buffer index hoặc tự tính lại PSAR trong EA.
- Gắn nhãn `PROVEN`/suy ra lợi nhuận khi chưa có forward ngoài mẫu.
- Để lộ one EA gửi lệnh ngoài `ExecBroker`.

## 3. Ràng buộc (dự án + spec)

1. **Chỉ demo/Strategy Tester** (`ExecContextAllowed`); không credential/`WebRequest`/socket.
2. **Mọi lệnh qua `ExecBroker`** (`ExecOpenMarket`, `ExecModifyStops`, `ExecClosePosition`).
3. **SL/TP bắt buộc**; `InpTakeProfitR > 0` (validator ép); `InpMaxPositions = 1`.
4. **Magic duy nhất**; allow-list symbol `InpAllowedSymbols`; kill switch riêng `InpKillSwitchFile`.
5. **`InpEnableExecution=true` mặc định** (ADR 0006); dry-run là override `false`.
6. **Input theo 6 nhóm chuẩn**, `Inp` + PascalCase tiếng Anh; tên input == key trong `configs/demo/*.json`.
7. **Compile 0 errors / 0 warnings** qua `scripts/deploy_pineport.ps1 -Apply -Force`.
8. Cổng phải giữ xanh: `validate-project.py` `checks=15 fail=0`, `validate_demo_execution.py` `checks=13 fail=0`,
   `check_docs_links.py` `broken=0`, `pytest 436 passed`.
9. `docs/99-archive/**` và `docs/PROGRESS.md` (append-only) không bị sửa nội dung.

## 4. Các hướng đã cân nhắc

| Hướng | Nội dung | Đánh đổi |
|---|---|---|
| A | Lát cắt dọc: SIGNAL_ONLY + parity trước, rồi Scalp, rồi Swing (mỗi bước 1 commit) | An toàn, dễ debug; chậm hơn |
| **B** | **Build trọn EA (cả 2 chế độ + framework) rồi mới test** | **Chủ dự án chọn**; nhanh về tiến độ nhưng rủi ro tích lũy lỗi khó khoanh vùng |
| C | Chỉ Scalp trước, hoãn Swing | Tập trung; bỏ dở một nửa spec |

**Chọn B.** Giảm rủi ro của B bằng: (a) **xác minh contract buffer + parity trước khi viết logic chiến lược**
(không phải "test", mà là điều kiện đúng của mã); (b) **compile sớm và thường xuyên** trong lúc viết;
(c) một commit build duy nhất + commit đăng ký (ADR/preset/catalog).

## 5. Quyết định chính

### 5.1 EA mới hay nâng cấp?

**EA MỚI** — theo chuẩn dự án (ADR 0005/0007 cho mỗi bot demo).

| Hạng mục | Quyết định |
|---|---|
| File EA | `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` |
| `WonderwhalesDemoEA` (v1) | **Giữ nguyên** (bot demo thứ năm, magic 25007001) |
| Magic | **Một magic duy nhất `25008001`** cho cả bot (S1); mode của từng lệnh lưu trong state lúc vào lệnh, không theo Inputs khi restart |
| ADR | **ADR 0009** — đăng ký bot demo thứ sáu, mở allow-list validator cho EA + preset mới |
| Catalog | thêm dòng vào `docs/10-bots/README.md` (16 EA) + trang `docs/10-bots/wonderwhales-2mode.md` |
| Validator | thêm vào `DEMO_EAS` (`kind = "ww_2mode"`, nhánh luật riêng) + token guard + `REQUIRED_FILES` + `validate_demo_execution.py` |
| Preset | `configs/demo/wonderwhales_xau_2mode_demo.json`; `.set` tester khi chạy |

### 5.2 Input theo chuẩn dự án (ánh xạ spec → `Inp*`)

Spec dùng tên Việt (`CheDoGiaoDich`, `Scalp_ToiDaLenhMoiNgay`…). Bản triển khai dùng `Inp` + PascalCase
tiếng Anh, khai đúng **6 nhóm** của `input-convention.md`:

| Nhóm chuẩn | Input mới (trích) |
|---|---|
| `01 Execution` | `InpEnableExecution`, `InpDemoOnly` (chặn real, S3), `InpAllowedSymbols`, `InpMagicNumber` (một magic), `InpMaxSlippagePoints`, `InpTradingMode` (enum `ENUM_WW2_MODE`), `InpSignalMode` |
| `02 Risk` | `InpRiskPercent`, `InpMaxPositions=1`, `InpCooldownMinutes`, `InpMaxDailyLossPct`, `InpMaxDrawdownPct`, `InpMaxConsecutiveLosses`, `InpMaxSpreadPoints`, `InpMaxExposure`, `InpHaltOnBreach` |
| `03 Stops` | `InpTakeProfitR`, `InpScalpBufferAtr`, `InpScalpSlAtrFallback`, `InpSwingBufferAtr`, `InpSwingSlAtrFallback`, `InpMinStopPoints`, `InpMaxStopPoints` |
| `04 Journal and state` | `InpEnableLog`, `InpLogFile` (**18 cột**), `InpEnableTelemetry`, `InpTelemetryFile` (S4), `InpPersistState`, `InpStateFile`, `InpResetStateOnInit`, `InpDebug` |
| `05 Kill switch` | `InpKillSwitchFile` (`WONDERWHALES_XAU_2MODE_DEMO_STOP.txt`), `InpCloseOnKillSwitch`, `InpRequireParity` (cổng parity, S2) |
| `06 Strategy` | sub-group `Signal`: cấu hình tín hiệu chung (`InpSignalMode`, `InpPsar*`, `InpFastEma`/`InpSlowEma`/`InpEma200`, `InpAtrLen`, warm-up — độc lập với `InpTradingMode`); `Scalp`: `InpScalpRrTarget`, `InpScalpBeTriggerR`, `InpScalpTrailTriggerR`, `InpScalpMinTrailStepPoints`, `InpScalpCooldownAfterLossMinutes`; `Swing`: `InpSwingRrTarget`, `InpSwingRrMin`, `InpSwingBeTriggerR`, `InpSwingTrailTriggerR`; `Trailing`: `InpEnableStructureTrail`, `InpEnablePsarTrail`, `InpEnableAtrTrail`, `InpEnableStepTrail`, `InpStepTrailPoints`, `InpTrailBufferAtr`, `InpSwingConfirmBars`, `InpStructureLookbackBars` |

- **Không** giữ input số lệnh/ngày: spec v2.2 đã bỏ hạn mức lệnh/ngày → không có `InpMaxTradesPerDay`.
- Bảng ánh xạ đầy đủ spec→`Inp*` nằm trong `docs/10-bots/wonderwhales-2mode.md` (bước đăng ký).
- Tên file log/state: `wonderwhales_xau_2mode_demo.csv`, `..._state.csv`.

### 5.3 Mặc định (giải quyết xung đột ADR 0006 vs spec)

Spec muốn mặc định `CHI_BAO_TIN_HIEU` + không gửi lệnh. ADR 0006 buộc demo EA mặc định **bật** execution.
**Quyết định (S3):** `InpEnableExecution=true` (ADR 0006), `InpDemoOnly=true` (**chặn tài khoản real** —
mọi account không phải demo/tester → `INIT_FAILED`), `InpTradingMode=SCALP`. Chế độ `SIGNAL_ONLY` vẫn
chọn được để quan sát nhưng **không** là mặc định (dry-run là override có chủ đích). Cổng parity (S2)
vẫn có quyền chặn entry kể cả ở mặc định.

### 5.4 Tín hiệu — bắt buộc xác minh trước

- Gọi indicator `PinePort\Wonderwhales` bằng `iCustom`; đọc buffer theo `WonderwhalesContract.mqh`
  (`WW_CONTRACT_VERSION`, `WW_BUFFER_COUNT=18`, chỉ số `WW_BUF_*`).
- Đọc **`shift=1`** (nến đã đóng); kiểm tra `BarsCalculated()` và `CopyBuffer()` đủ dữ liệu.
- Nếu indicator chưa sẵn sàng / `EMPTY_VALUE` → không giao dịch.
- **Trước khi tin tín hiệu:** so ≥100 timestamp BUY/SELL giữa Pine và MT5 (parity); ghi bằng chứng.
- **Cổng parity (S2) là HALT:** parity chưa đạt → **chặn mọi entry** (cả Scalp và Swing), log
  `reason=parity_blocked`. Vẫn compile / kiểm tra indicator + `CopyBuffer` / tính SL-TP-volume / chạy
  risk guard / ghi log được, nhưng **kết quả giao dịch khi bỏ qua parity không phải kết quả chiến lược
  hợp lệ** — không dùng để đánh giá lợi nhuận hay kết luận bot tốt/xấu.

### 5.5 SL/TP và quản lý (theo spec §2, §4, §7)

- SL Scalp: dưới swing low M5 đã xác nhận + `InpScalpBufferAtr × ATR(M5)`; fallback `InpScalpSlAtrFallback × ATR(M5)`.
- SL Swing: sau swing H1 + `InpSwingBufferAtr × ATR(H1)`; fallback `InpSwingSlAtrFallback × ATR(H1)`; có thể dùng mức cấu trúc D1 nếu xa hơn (tính lại volume).
- TP bắt buộc `InpTakeProfitR` (Scalp mặc định 1.5R, Swing 2.5R); RR tối thiểu để vào (`InpSwingRrMin`).
- `WWTrailingCoordinator`: tính mọi ứng viên SL (BE có buffer chi phí → structure → PSAR → ATR → step),
  lọc broker (stop/freeze/tick), chọn mức bảo vệ tốt nhất, chỉ siết, chỉ sửa khi cải thiện ≥
  `InpScalpMinTrailStepPoints`. R luôn từ **initial SL** đã lưu.

### 5.6 Risk & state

- Tái dùng khuôn `SimRiskGuard` (daily/weekly/DD/consecutive) + high-water mark lưu trong state file;
  restart không mất halt. Daily halt tự mở lại ngày mới; DD halt/kill switch cần operator reset.
- `0` ở một ngưỡng = **tắt có chủ đích**, phải ghi trong preset description (input-convention §7.1).

### 5.7 Mode của lệnh & nhật ký (S1, S4)

- **Mode lưu theo từng lệnh:** khi vào lệnh, ghi `mode` (SCALP/SWING) kèm ticket/`POSITION_IDENTIFIER` vào
  state; khi quản lý/khôi phục, luôn dùng **mode đã lưu**, không dùng `InpTradingMode` hiện tại trên Inputs.
- **Nhật ký:** giữ **hợp đồng 18 cột** (`InpLogFile`) mà `watch_demo_journal.py`/`validate_demo_execution.py`
  đang parse; dữ liệu mở rộng (MAE/MFE, R, loại trailing, EMA/PSAR/ATR từng khung) ghi **file telemetry
  riêng** (`InpTelemetryFile`), nối với journal bằng position identifier. Không mở rộng schema 18 cột.

## 6. Kiến trúc file

Đối chiếu spec §8 với layout dự án (mỗi chiến lược một thư mục `mt5/Include/<Name>/`):

```text
mt5/
  Experts/WonderwhalesXAU2ModeEA.mq5        # EA: input, vòng đời, phối hợp
  Indicators/PinePort/Wonderwhales.mq5      # (đã có) nguồn tín hiệu
  Include/
    PinePort/WonderwhalesContract.mqh       # (đã có) contract 18 buffer
    Wonderwhales/                           # MỚI
      WW2Types.mqh                          # enum mode, struct state, R
      WW2SignalReader.mqh                   # đọc buffer theo contract (không tự tính lại)
      WW2ScalpStrategy.mqh                  # M15/M5/M1
      WW2SwingStrategy.mqh                  # W1/D1/H1
      WW2RiskSizer.mqh                      # volume theo OrderCalcProfit
      WW2RiskGuard.mqh                      # daily/weekly/DD/consecutive/cooldown
      WW2InitialStop.mqh                    # SL cấu trúc + ATR
      WW2TrailingCoordinator.mqh            # gộp ứng viên SL, chọn tốt nhất
      WW2Journal.mqh                        # ghi CSV 18 cột
    Exec/…, Sim/…                           # (đã có) dùng nguyên
```

**Ràng buộc kiến trúc:** chỉ `ExecBroker` gửi/sửa/đóng lệnh; các module `Wonderwhales/*` không gọi API
trading trực tiếp (giữ static gate "chỉ Exec gửi lệnh" còn hiệu lực).

## 7. Thay đổi đăng ký (registry / validator / docs)

1. **ADR 0009** — đăng ký bot demo thứ sáu (theo mẫu ADR 0007), nêu rõ demo-only, magic, guardrail.
2. `configs/demo/wonderwhales_xau_2mode_demo.json` — `DEMO_ONLY`, `allow_live_trading=false`,
   `InpEnableExecution=true`, đủ key trùng tên input.
3. `scripts/validate-project.py` — thêm file vào allow-list + `DEMO_EAS` (`kind="ww_2mode"`) + token guard.
4. `scripts/validate_demo_execution.py` — nhánh `ww_2mode` (SL/TP bắt buộc, `InpMaxPositions=1`,
   `InpTakeProfitR>0`, halt inputs).
5. `python/src/mt5_ea_ai_lab/sim_configs.py` — thêm EA vào `DEMO_EA_NAMES`.
6. `scripts/deploy_pineport.ps1` + `build_pineport.ps1` — deploy EA/include mới.
7. Docs: `docs/10-bots/README.md` (16 EA) + `docs/10-bots/wonderwhales-2mode.md` (trang bot: chiến lược,
   bảng input + cột phase-C, preset/magic, bằng chứng, giới hạn) + cập nhật `docs/20-operations/*` nếu cần.
8. `docs/PROGRESS.md` — append mục mới (số thật) khi có kết quả compile/tester.

## 8. Kế hoạch kiểm thử (spec §10, rút gọn theo dự án)

1. **Contract/parity:** xác minh buffer (`BarsCalculated`, `CopyBuffer`); ≥100 timestamp đối chiếu Pine↔MT5.
   Parity chưa đạt ⇒ **entry bị chặn** (S2) — nên bước này là điều kiện để có kết quả chiến lược hợp lệ.
2. **Compile:** `deploy_pineport.ps1 -Apply -Force` → 0 errors / 0 warnings.
3. **Tester Scalp riêng** và **Tester Swing riêng** (không trộn kết quả), dùng `.set` sinh từ JSON.
4. **Forward demo** từng chế độ (không real), ghi khác biệt tester↔demo.
5. **Nhãn trung thực:** `NOT_RUN` cho tới khi có journal/History thật; lợi nhuận `UNPROVEN`; parity chưa
   đạt → `BLOCKED`.

## 9. Xác minh / Definition of Done (đợt build)

- [ ] EA + các include `Wonderwhales/*` compile **0 errors / 0 warnings**.
- [ ] `WonderwhalesXAU2ModeEA` chỉ gửi lệnh qua `ExecBroker`; SL+TP trên mọi lệnh.
- [ ] Input đúng 6 nhóm chuẩn; preset JSON đủ/đúng key; `InpEnableExecution=true`, `InpDemoOnly=true`, `InpMaxPositions=1`, `InpTakeProfitR>0`.
- [ ] **Cổng parity chặn entry** khi parity Pine↔MT5 chưa đạt; kết quả bỏ qua parity không dùng để kết luận.
- [ ] **Journal 18 cột không đổi**; có **file telemetry riêng** cho trường mở rộng (MAE/MFE, R, trailing, EMA/PSAR).
- [ ] **Mode từng lệnh lưu trong state**; khôi phục quản lý theo mode đã lưu, không theo Inputs.
- [ ] ADR 0009 + catalog + trang bot + validator + `sim_configs` cập nhật.
- [ ] Cổng xanh sau khi **đo lại** (thêm bot demo thứ sáu ⇒ số check tăng): `validate-project.py fail=0`,
  `validate_demo_execution.py fail=0`, `check_docs_links.py broken=0`, `pytest` không giảm so với 436.
- [ ] Không sửa `WonderwhalesDemoEA`/`WonderwhalesSimEA`/`configs/sim/*`/`99-archive`; không real/live.
- [ ] Đã chạy tester Scalp và Swing (hoặc ghi rõ `NOT_RUN` nếu chưa) — không tuyên bố vượt bằng chứng.

## 10. Rủi ro của hướng B và cách giảm

| Rủi ro | Giảm thiểu |
|---|---|
| Tích lũy lỗi trong EA lớn, khó khoanh vùng | Xác minh contract trước; compile sau mỗi nhóm file; log `reason code` đầy đủ |
| Sai buffer/PSAR → tín hiệu sai âm thầm | Bám `WonderwhalesContract.mqh`; parity test; không tự tính lại |
| Rò rỉ API trading ra ngoài Exec | Static gate của validator; module chỉ trả giá trị, EA mới gọi Exec |
| Mặc định bật execution gây lệnh ngoài ý muốn | ADR 0006 + `InpTradingMode` mặc định SCALP + `InpDemoOnly` + allow-list + kill switch + risk halt + cổng parity |
| Bộ input phình to, preset lệch | Sinh `.set`/JSON từ một nguồn; validator đối chiếu key |

## 11. Quyết định đã chốt (không cần hỏi lại)

Từ builder check + spec, các điểm sau tự quyết được và đã chốt:

- **Tên input tránh trùng v1:** `InpTradingMode` (`ENUM_WW2_MODE` = `SIGNAL_ONLY`|`SCALP`|`SWING`) và
  `InpSignalMode` (`ENUM_WW_MODE`, giữ như v1). (v1 dùng `InpMode` cho signal mode → không tái sử dụng.)
- **Risk theo từng chế độ:** `InpScalpRiskPercent` (0.15) và `InpSwingRiskPercent` (0.25); `InpRiskPercent`
  giữ làm giá trị dùng chung dự phòng (thỏa token nhóm 02). Cooldown sau lệnh thua theo chế độ:
  `InpScalpCooldownAfterLossMinutes` (20), `InpSwingCooldownAfterLossMinutes`.
- **Weekly loss:** quản cục bộ trong `WW2RiskGuard.mqh` (daily/DD/consecutive dùng khuôn `SimRiskGuard`,
  thêm ngân sách tuần), lưu vào state; **không** sửa `SimRiskGuard.mqh` dùng chung.
- **Đa khung (MTF):** một handle `iCustom` cho **mỗi** timeframe; đọc EMA/ATR/PSAR **từ buffer indicator**
  (index 8 ATR%, 9/10/11 EMA, 5 SAR_DIR), **không** tự tính `iMA`/`iATR` phía EA.
- **Swing/structure:** swing = fractal xác nhận với `InpSwingConfirmBars` (mặc định 2) nến mỗi phía,
  cửa sổ `InpStructureLookbackBars` (mặc định 300); vô hiệu hóa khi giá đóng qua; tính từ nến giá
  (đây là cấu trúc giá, không phải logic PinePort nên không vi phạm anti-goal).
- **Input an toàn bổ sung có mặt:** `InpSkipIfMinLotExceedsRisk=true`, `InpMaxVolume` (0.10),
  `InpBreakEvenCostBuffer=true`, `InpBreakEvenBufferPoints`, `InpMaxSpreadRatioToSlPct=10`,
  `InpSessionFilter=false` (mặc định tắt; chỉ bật sau khi xác minh múi giờ server — spec §2.1/§6.7).
- **Thư mục include:** `mt5/Include/Wonderwhales/`.
- **DoD checks sẽ tăng:** thêm bot demo thứ sáu ⇒ `validate-project.py`/`validate_demo_execution.py` có
  thêm dòng PASS; kế hoạch phải **đo lại** và ghi số mới, không khoá cứng `15`/`13`.
- **S1 (đã chốt 2026-11-04):** **một magic `25008001`** cho cả bot; mode từng lệnh lưu trong state lúc
  vào, không theo Inputs khi restart.
- **S2 (đã chốt):** parity chưa đạt ⇒ **chặn entry** (halt `parity_blocked`); kết quả bỏ qua parity không
  phải kết quả chiến lược hợp lệ.
- **S3 (đã chốt):** mặc định `InpTradingMode=SCALP`, `InpEnableExecution=true`, `InpDemoOnly=true`.
- **S4 (đã chốt):** journal giữ **18 cột**; thêm **file telemetry riêng** cho MAE/MFE/R/trailing/EMA-PSAR
  từng khung.

## 12. Đã giải quyết

Toàn bộ câu hỏi chuyển cho chủ dự án (S1–S4) đã được chốt ngày **2026-11-04** và đưa vào §5/§11:
một magic `25008001`; parity chặn entry; mặc định SCALP + execution bật + demo-only; journal 18 cột +
file telemetry riêng. **Không còn câu hỏi mở chặn việc lập kế hoạch.**

## 13. Phần để builder tự quyết

- Chia module trong `Wonderwhales/*` (số file, tên cụ thể) miễn giữ §6 và ràng buộc "chỉ Exec gửi lệnh".
- Cờ CLI và cách gọi `deploy/build_pineport.ps1` (theo `--help`/script hiện có).
- Nội dung `docs/10-bots/wonderwhales-2mode.md` theo khuôn 6 mục của các trang bot khác.
- Biên dịch/logic chi tiết của `WW2TrailingCoordinator` miễn đúng §5.5 và không nới SL.
- Một commit build + một commit đăng ký (hoặc gộp nếu hợp lý), miễn §9 đạt.
