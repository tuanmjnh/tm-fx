# Wonderwhales XAU 2-mode Demo EA — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. OpenCode has no todo tool: keep the task checklist in this file and tick items as you go.

**Goal:** Build a sixth demo EA, `WonderwhalesXAU2ModeEA`, that runs one guarded XAUUSD position in a Scalp (M15/M5/M1) or Swing (W1/D1/H1) mode from the existing PinePort\Wonderwhales buffers, with mandatory SL/TP, rule-based break-even/trailing and a persistent daily/weekly/drawdown risk guard — demo/tester only.

**Architecture:** One EA file orchestrates; pure-logic modules under `mt5/Include/Wonderwhales/` hold the strategy, stop, sizing and trailing math. Only the EA calls account APIs and `ExecBroker`; every module stays free of trading/account tokens so `scripts/validate-project.py` keeps treating them as non-exec sources. Signals come from `iCustom("PinePort\\Wonderwhales", …)` read through `WonderwhalesContract.mqh` — never recomputed in the EA.

**Tech Stack:** MQL5 (MetaEditor64, headless compile), the repo's PowerShell deploy/compile script, Python 3.11 static validators + pytest, MT5 Strategy Tester via `terminal64.exe /config:`.

**Spec:** `docs/10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md` (v2.2, Vietnamese) and the design `docs/superpowers/specs/2026-11-04-wonderwhales-2mode-ea-design.md` (S1–S4 settled).

## Global Constraints

- Demo account or Strategy Tester only. Real/contest → `INIT_FAILED`. No credentials, no `WebRequest`/socket, no login.
- Every order via `ExecBroker` only (`ExecOpenMarket`, `ExecModifyStops`, `ExecClosePosition`, `ExecFindOwnPosition`); no `OrderSend` anywhere.
- Mandatory SL and TP on every order. `InpTakeProfitR > 0`; exactly one position (`InpMaxPositions = 1`).
- One magic for the whole bot: `InpMagicNumber = 25008001`. Scalp/Swing are modes inside the bot, stored per position — never a second magic.
- `InpEnableExecution = true` by default (ADR 0006); `InpDemoOnly = true`; default `InpTradingMode = WW2_SCALP`.
- Parity gate: when parity Pine↔MT5 is not proven, **block every entry** (`reason=parity_blocked`). Tester results obtained with parity off are infrastructure evidence, never a strategy result.
- Journal keeps the **18-column contract** unchanged (`SIM_LOG_HEADER`, via `CSimLogger`). Extra fields go to a separate telemetry CSV.
- Inputs follow `docs/10-bots/input-convention.md`: `Inp` + PascalCase, six groups in order `01 Execution`, `02 Risk`, `03 Stops`, `04 Journal and state`, `05 Kill switch`, `06 Strategy`; input names == `configs/demo/*.json` keys.
- Any file under `mt5/Include/Wonderwhales/` is a **non-exec source**: it must not contain `OrderSend|OrderCalcProfit|OrderCalcMargin|AccountInfo*|PositionSelect|CTrade|WebRequest|Socket*`. These tokens are allowed only in the EA file, which is added to both validators' `EXEC_SOURCES` in Task 1.
- No `TODO|FIXME|TBD|PLACEHOLDER|NOT_IMPLEMENTED` anywhere under `mt5/`.
- Compile gate: MetaEditor reports `0 errors, 0 warnings` for the new EA and every module.
- Gate commands (from repo root, `.\.venv\Scripts\python.exe`): `scripts\validate-project.py`, `scripts\validate_demo_execution.py`, `scripts\check_docs_links.py`, `-m pytest -q`. Counts are **measured, not pinned** (adding a demo EA grows `validate_demo_execution.py` by one `report` and adds parametrised pytest cases).
- Do not modify `mt5/Experts/WonderwhalesDemoEA.mq5`, `WonderwhalesSimEA.mq5`, `configs/sim/*`, `docs/99-archive/**`, or the content of `docs/PROGRESS.md` (append-only).

## Review Focus

Behaviour the spec implies but no task's mechanical check exercises; each is pinned by a test/manual step in the task that owns the code:

1. **Indicator not ready / short history** — `CopyBuffer` returns `< 1` or `EMPTY_VALUE`; the EA must skip, not trade on zeros. (Task 2: `Ww2ReadSignal` false path + warm-up guard.)
2. **Stop distance after broker normalisation** — SL tick-normalised then re-checked against `SYMBOL_TRADE_STOPS_LEVEL`/freeze; a stop too close must block the entry, not be silently widened. (Task 2: `Ww2InitialStop` + `ExecStopsRespectBroker`.)
3. **Minimum lot exceeds the risk budget** — must skip, never round up. (Task 2: `Ww2SizeVolume` `min_lot_over_budget`.)
4. **Trailing never loosens** — every candidate must beat the current SL for BUY (higher) / SELL (lower) by `InpMinTrailStepPoints`, with R always from the stored initial SL. (Task 3: `Ww2BestStop` vectors.)
5. **Restart does not lose the halt** and management uses the **stored** mode, not the current `InpTradingMode`. (Task 4: state round-trip + mode-at-entry.)

---

### Task 1: Foundation — branch, design amendment, EA skeleton, registry exemption

**Files:**
- Create: `mt5/Include/Wonderwhales/WW2Types.mqh`
- Create: `mt5/Include/Wonderwhales/WW2SignalReader.mqh`
- Create: `mt5/Experts/WonderwhalesXAU2ModeEA.mq5` (skeleton)
- Modify: `scripts/validate-project.py` (`EXEC_SOURCES` set, ~line 52)
- Modify: `scripts/validate_demo_execution.py` (`EXEC_SOURCES` tuple built from `DEMO_EAS`, ~line 79 — add the new EA before `EXEC_TESTS`)
- Modify: `docs/superpowers/specs/2026-11-04-wonderwhales-2mode-ea-design.md` (amendment)
- Modify: `scripts/deploy_pineport.ps1` (include tree + copy list + compile targets)

**Interfaces (produces):**
- `enum ENUM_WW2_MODE { WW2_SIGNAL_ONLY=0, WW2_SCALP=1, WW2_SWING=2 };` and `string Ww2ModeName(const ENUM_WW2_MODE mode);`
- `struct Ww2Signal { bool valid; bool buy; bool sell; int sar_dir; double psar; double atr_pct; double fast_ema; double slow_ema; double ema200; double close; };`
- `struct Ww2Position { bool have; ulong ticket; bool is_buy; double volume; double entry; double initial_sl; double tp; datetime open_time; ENUM_WW2_MODE mode; };`
- `bool Ww2ReadSignal(const int handle, const int shift, Ww2Signal &out);` — false when the buffer is not ready or holds `EMPTY_VALUE`; reads `WW_BUF_BUY_SIGNAL/SELL_SIGNAL/SAR_DIR/PSAR/ATR_PCT/FAST_EMA/SLOW_EMA/EMA200`.
- `bool Ww2IndicatorReady(const int handle, const int min_bars);` — true when `BarsCalculated(handle) >= min_bars`.

- [ ] **Step 1: Amend the design doc.** Add a section "Điều chỉnh khi lập kế hoạch (2026-11-04)": per-mode scalars are **not** duplicated as engine inputs; a single `InpRiskPercent`, `InpTakeProfitR`, `InpBreakEvenTriggerR`, `InpTrailTriggerR`, `InpMinTrailStepPoints`, `InpCooldownMinutes` is set per mode by the **preset** (one source of truth; only one mode runs at a time per spec §1.2). Replace `InpMaxLots` with `InpMaxExposure` (input-convention §5.2/§7). Remove `InpScalpRiskPercent`/`InpSwingRiskPercent`/`InpScalpRrTarget`/`InpSwingRrTarget`/`InpScalpBeTriggerR`/`InpScalpTrailTriggerR`/`InpSwingBeTriggerR`/`InpSwingTrailTriggerR`/`InpScalpCooldownAfterLossMinutes`/`InpSwingCooldownAfterLossMinutes` from §5.2/§11.

- [ ] **Step 2: Write `WW2Types.mqh`.** Enums + the three structs above + pure helpers `Ww2ModeName`, `Ww2RiskPercentForMode` is NOT here (no inputs in modules). No account/trading tokens.

- [ ] **Step 3: Write `WW2SignalReader.mqh`.** `#include "../../PinePort/WonderwhalesContract.mqh"`. Implement `Ww2ReadSignal` (eight `CopyBuffer` calls on `shift,1` with `ArraySetAsSeries`-free fixed-size arrays, then `SimIsFinite`-style finite checks via `MathIsValidNumber`) and `Ww2IndicatorReady`. No `AccountInfo*`.

- [ ] **Step 4: Write the EA skeleton with the full input block.** Declare all 72 inputs (table below) in the six groups, in order. `OnInit`: `InpDemoOnly` check → build `ExecAccountState`, `ExecContextAllowed` → `INIT_FAILED`; symbol allow-list via `ExecSymbolAllowed`; cache symbol props; create one `iCustom` handle per distinct timeframe needed by the active mode; open the 18-column logger (`CSimLogger`); load state. `OnTick`: warm-up guard using `Ww2IndicatorReady`; kill switch via `FileIsExist(InpKillSwitchFile)`; read signals; when `InpTradingMode == WW2_SIGNAL_ONLY` log the signal and return. Keep the file compiling with later functions stubbed as real (empty-branch) code paths.

**Input table (exact names, types, defaults — group order fixed):**

```text
01 Execution
  InpEnableExecution      bool     true
  InpDemoOnly             bool     true
  InpAllowedSymbols       string   "XAUUSD"
  InpMagicNumber          long     25008001
  InpMaxSlippagePoints    int      30
  InpTradingMode          ENUM_WW2_MODE  WW2_SCALP
  InpSignalMode           ENUM_WW_MODE   WW_MODE_SAR_EMA
02 Risk
  InpRiskPercent          double   0.15
  InpMaxPositions         int      1
  InpCooldownMinutes      int      20
  InpMaxConsecutiveLosses int      2
  InpMaxDailyLossPct      double   1.0
  InpMaxWeeklyLossPct     double   2.0
  InpMaxDrawdownPct       double   5.0
  InpMaxSpreadPoints      double   600.0
  InpMaxSpreadRatioToSlPct double  10.0
  InpMaxExposure          double   0.10
  InpSkipIfMinLotExceedsRisk bool  true
  InpHaltOnBreach         bool     true
03 Stops
  InpTakeProfitR          double   1.5
  InpMinStopPoints        double   150.0
  InpMaxStopPoints        double   100000.0
  InpScalpBufferAtr       double   0.20
  InpScalpSlAtrFallback   double   1.2
  InpSwingBufferAtr       double   0.30
  InpSwingSlAtrFallback   double   2.0
  InpBreakEvenCostBuffer  bool     true
  InpBreakEvenBufferPoints double  50.0
04 Journal and state
  InpEnableLog            bool     true
  InpLogFile              string   "wonderwhales_xau_2mode_demo.csv"
  InpEnableTelemetry      bool     true
  InpTelemetryFile        string   "wonderwhales_xau_2mode_telemetry.csv"
  InpPersistState         bool     true
  InpStateFile            string   "wonderwhales_xau_2mode_demo_state.csv"
  InpResetStateOnInit     bool     false
  InpDebug                bool     false
05 Kill switch
  InpKillSwitchFile       string   "WONDERWHALES_XAU_2MODE_DEMO_STOP.txt"
  InpCloseOnKillSwitch    bool     true
  InpRequireParity        bool     true
06 Strategy
  InpPsarStart            double   0.02
  InpPsarInc              double   0.02
  InpPsarMax              double   0.20
  InpFastEma              int      20
  InpSlowEma              int      50
  InpEma200               int      200
  InpAtrLen               int      14
  InpMinAtrPct            double   0.5
  InpVolMaLen             int      20
  InpRsiLen               int      14
  InpBbLen                int      20
  InpBbMult               double   2.0
  InpWarmupBars           int      300
  InpScalpBiasTF          ENUM_TIMEFRAMES PERIOD_M15
  InpScalpSetupTF         ENUM_TIMEFRAMES PERIOD_M5
  InpScalpTriggerTF       ENUM_TIMEFRAMES PERIOD_M1
  InpSwingBiasTF          ENUM_TIMEFRAMES PERIOD_W1
  InpSwingSetupTF         ENUM_TIMEFRAMES PERIOD_D1
  InpSwingTriggerTF       ENUM_TIMEFRAMES PERIOD_H1
  InpBreakEvenTriggerR    double   1.0
  InpTrailTriggerR        double   1.3
  InpMinTrailStepPoints   double   50.0
  InpSwingRrMin           double   1.8
  InpSwingConfirmBars     int      2
  InpStructureLookbackBars int     300
  InpEnableStructureTrail bool     true
  InpEnablePsarTrail      bool     false
  InpEnableAtrTrail       bool     false
  InpEnableStepTrail      bool     false
  InpStepTrailPoints      double   300.0
  InpTrailBufferAtr       double   0.25
  InpExitOnFlip           bool     true
  InpMaxHoldingBars       int      0
```

- [ ] **Step 5: Register the EA as an exec source (both validators) so the gate stays green while the modules grow.** In `validate-project.py` add `"mt5/Experts/WonderwhalesXAU2ModeEA.mq5"` to `EXEC_SOURCES`. In `validate_demo_execution.py` add it to the `EXEC_SOURCES` tuple (next to `WW_DEMO_EA`), **not** yet to `DEMO_EAS`/`check_demo_ea`.

- [ ] **Step 6: Extend `deploy_pineport.ps1`.** Add `"mt5\Include\Wonderwhales"` to the `$tree` loop array (~line 91); add the new EA to the second `$files +=` block (~line 117); add `"MQL5\Experts\WonderwhalesXAU2ModeEA.mq5"` to `$compileTargets` (~line 159).

- [ ] **Step 7: Compile.**
Run: `powershell -NoProfile -File scripts\deploy_pineport.ps1 -Apply -Force -TerminalDataDir "C:\Users\tuanmjnh\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06"`
Expected: `DEPLOY_OK: files copied and compiled with 0 errors and 0 warnings.`

- [ ] **Step 8: Run the gates.**
Run: `.\.venv\Scripts\python.exe scripts\validate-project.py` → `SUMMARY: checks=15 fail=0`
Run: `.\.venv\Scripts\python.exe scripts\validate_demo_execution.py` → `SUMMARY: checks=13 fail=0`
Run: `.\.venv\Scripts\python.exe scripts\check_docs_links.py` → `SUMMARY: broken=0`

- [ ] **Step 9: Commit.** `git add mt5 scripts docs; git commit -m "feat(ww2): scaffold Wonderwhales 2-mode EA, types and signal reader"`

---

### Task 2: Risk guard, sizer, initial stop, swing detection — and the live entry path

**Files:**
- Create: `mt5/Include/Wonderwhales/WW2RiskGuard.mqh`
- Create: `mt5/Include/Wonderwhales/WW2RiskSizer.mqh`
- Create: `mt5/Include/Wonderwhales/WW2Swing.mqh`
- Create: `mt5/Include/Wonderwhales/WW2InitialStop.mqh`
- Modify: `mt5/Experts/WonderwhalesXAU2ModeEA.mq5`

**Interfaces (consumes Task 1; produces):**
- `CWw2RiskGuard` class: `bool Init(const double daily_pct,const double weekly_pct,const double dd_pct,const int max_losses,const int cooldown_minutes,string &error);` · `void OnEquity(const double equity,const datetime now);` · `bool EntryAllowed(const datetime now,const double spread_points,const double sl_points,const double max_spread_points,const double max_spread_ratio_pct,string &reason);` · `void RecordEntry(const datetime now);` · `void RecordClosed(const double pnl_money,const double equity,const datetime now);` · `void ForceHalt(const string reason);` · `void Reset(void);` · `bool Halted(string &reason);` · `void Save(string &out);` · `void Load(const string &in);` — daily and weekly budgets reset on the server day/week boundary; drawdown/streak halt persists until reset.
- `bool Ww2SizeVolume(const bool is_buy,const double entry,const double sl,const double risk_money,const double loss_per_lot,const double vol_min,const double vol_max,const double vol_step,const double max_exposure,const bool skip_if_min_exceeds,double &volume,string &reason);` — floor to step, reject `min_lot_over_budget`, cap at `max_exposure`, re-verify final loss ≤ `risk_money`.
- `bool Ww2FindSwingLow(const double &low[],const int start_shift,const int lookback,const int confirm,int &shift,double &price);` and `Ww2FindSwingHigh(...)` — confirmed fractal (`confirm` bars each side), newest within `lookback`.
- `double Ww2ScalpStopDistance(const bool is_buy,const double price,const double atr_pct,const double swing_price,const bool have_swing,const double buffer_atr,const double fallback_atr);` and `Ww2SwingStopDistance(...)`; both return a price distance ≥ 0.

- [ ] **Step 1: Write `WW2RiskSizer.mqh`** (pure, takes `loss_per_lot` computed by the EA via `ExecCalcProfit`).

- [ ] **Step 2: Write `WW2RiskGuard.mqh`** (pure; equity/day/week passed in; local weekly budget because `SimRiskGuard` has none).

- [ ] **Step 3: Write `WW2Swing.mqh`** + `WW2InitialStop.mqh` (pure math over arrays).

- [ ] **Step 4: Wire the entry path in the EA.** `TryEnter(bar_time)`: parity gate (`InpRequireParity` and no proven evidence file → `BlockEntry("parity_blocked")`); `Ww2RiskGuard::EntryAllowed`; spread check incl. `spread/sl ≤ InpMaxSpreadRatioToSlPct`; resolve mode bias; compute entry/SL/TP with `ExecTakeProfitPrice`/`ExecTakeProfitValid`/`ExecStopsRespectBroker`; `ExecCalcProfit` → `Ww2SizeVolume`; `ExecOpenMarket(is_buy,volume,sl,tp,InpMaxSlippagePoints,InpMagicNumber,"WW2_"+Ww2ModeName(mode),fill)`; verify retcode; store `Ww2Position` incl. **mode at entry**; `RecordEntry`.

- [ ] **Step 5: Wire the manage path.** `ReconcilePosition()` (`ExecFindOwnPosition`), `EnsureStops()` (`ExecModifyStops` re-assert), exit on flip / `InpMaxHoldingBars`, `CloseAtMarket()` (`ExecClosePosition`), `ApplyClosedPnl` (`ExecClosedPnl`) → `RecordClosed`.

- [ ] **Step 6: State persistence.** Save/load: `state_version`, `magic`, `peak_equity`, `day_key`, `day_start_equity`, `week_key`, `week_start_equity`, `streak_losses`, `halted`, `halt_reason`, `block_until`, position fields incl. `pos_mode`. Restore refuses when `state_version`/`magic` mismatch.

- [ ] **Step 7: Compile + gates.**
Run: `powershell -NoProfile -File scripts\deploy_pineport.ps1 -Apply -Force -TerminalDataDir "<data folder>"` → `DEPLOY_OK`
Run: `.\.venv\Scripts\python.exe scripts\validate-project.py` → `fail=0`
Run: `.\.venv\Scripts\python.exe scripts\validate_demo_execution.py` → `fail=0`

- [ ] **Step 8: Commit.** `git commit -m "feat(ww2): risk guard, sizing, initial stop and live entry/manage path"`

---

### Task 3: Trailing coordinator + telemetry

**Files:**
- Create: `mt5/Include/Wonderwhales/WW2TrailingCoordinator.mqh`
- Create: `mt5/Include/Wonderwhales/WW2Telemetry.mqh`
- Modify: `mt5/Experts/WonderwhalesXAU2ModeEA.mq5`

**Interfaces (consumes Task 1–2; produces):**
- `struct Ww2StopInput { bool is_buy; double entry; double initial_sl; double current_sl; double bid; double ask; double point; double min_step_points; double be_trigger_r; double be_buffer_points; double trail_trigger_r; double structure_sl; bool have_structure; double psar; bool enable_psar; double atr_distance; bool enable_atr; double step_points; bool enable_step; };`
- `double Ww2BestStop(const Ww2StopInput &in,string &reason);` — returns the best candidate SL (BUY: highest valid < bid; SELL: lowest valid > ask), only if it improves the current SL by ≥ `min_step_points`; R always from `initial_sl`. Returns `0.0` when nothing improves.
- `Ww2Telemetry*`: `bool Ww2TelemetryOpen(const string file,int &handle);` · `void Ww2TelemetryWrite(const int handle,const datetime bar_time,const ulong ticket,const ENUM_WW2_MODE mode,const double r,const double mae,const double mfe,const string trail_reason,const double ema_fast,const double ema_slow,const double ema200,const double atr_pct,const int sar_dir);` · `void Ww2TelemetryClose(const int handle);` — its own CSV, never the 18-column journal.

- [ ] **Step 1: Write `WW2TrailingCoordinator.mqh`** with candidate order BE → structure → PSAR → ATR → step, broker-filtered by the caller.

- [ ] **Step 2: Write `WW2Telemetry.mqh`** (file I/O only; header written when the file is empty).

- [ ] **Step 3: Wire `ManagePosition`.** Each closed managing bar: compute current R; if `r ≥ InpBreakEvenTriggerR` add the BE candidate (`entry ± InpBreakEvenBufferPoints` when `InpBreakEvenCostBuffer`, else `entry`); if `r ≥ InpTrailTriggerR` add structure/PSAR/ATR/step candidates; call `Ww2BestStop`; if a better SL exists and passes `ExecStopsRespectBroker`, `ExecModifyStops(ticket,new_sl,tp,fill)`; on rejection keep the old SL and log `sl_modify_failed`. Write a telemetry row per management step.

- [ ] **Step 4: Compile + gates** (same commands as Task 2 Step 7) → `DEPLOY_OK`, `fail=0`, `fail=0`.

- [ ] **Step 5: Commit.** `git commit -m "feat(ww2): trailing coordinator (BE/structure/PSAR/ATR/step) and telemetry CSV"`

---

### Task 4: Scalp and Swing strategies, mode-at-entry, parity gate

**Files:**
- Create: `mt5/Include/Wonderwhales/WW2ScalpStrategy.mqh`
- Create: `mt5/Include/Wonderwhales/WW2SwingStrategy.mqh`
- Modify: `mt5/Experts/WonderwhalesXAU2ModeEA.mq5`

**Interfaces (consumes Task 1–3; produces):**
- `bool Ww2ScalpBias(const Ww2Signal &m15,bool &bias_buy,bool &bias_sell);` — M15 EMA20/50 + close vs EMA200.
- `bool Ww2ScalpEntry(const Ww2Signal &m15,const Ww2Signal &m5,const Ww2Signal &m1,bool &is_buy);` — M5 PSAR flip with M15 bias + EMA agreement, M1 confirmation on the closed bar.
- `bool Ww2SwingEntry(const Ww2Signal &w1,const Ww2Signal &d1,const Ww2Signal &h1,bool &is_buy);` — W1 bias, D1 agreement (EMA200 preferred), H1 PSAR flip.

- [ ] **Step 1: Write `WW2ScalpStrategy.mqh`** and `WW2SwingStrategy.mqh` (pure; take `Ww2Signal` values from Task 1).

- [ ] **Step 2: Wire per-mode handles and reads.** Create one `iCustom` handle per distinct timeframe used by both modes (M1/M5/M15/H1/D1/W1), all reading the same indicator inputs. In `OnTick` read the three timeframes of the **active** mode at `shift=1` and call the matching strategy.

- [ ] **Step 3: Mode-at-entry.** Persist `pos_mode` when entering; `ManagePosition`/`ConsumeExitRules` must read the stored mode (not `InpTradingMode`) to choose BE/trail thresholds and the strike timeframe. Log a warning if the current input mode differs from the stored mode.

- [ ] **Step 4: Parity gate evidence handling.** `InpRequireParity=true` blocks entries until a parity evidence file is present and recorded as proven (a small helper reads `InpParityFile`-like evidence; document that no evidence exists yet, so entries are blocked). Log `parity_blocked` once per bar.

- [ ] **Step 5: Compile + gates** → `DEPLOY_OK`, `fail=0`, `fail=0`.

- [ ] **Step 6: Commit.** `git commit -m "feat(ww2): scalp/swing strategies, mode-at-entry and parity gate"`

---

### Task 5: Pure-logic contract tests

**Files:**
- Create: `mt5/Scripts/WW2CoreTests.mq5`
- Modify: `scripts/deploy_pineport.ps1` (add to `$files` copy block and `$compileTargets`)

**Interfaces (consumes Tasks 1–4):** asserts on `Ww2SizeVolume`, `CWw2RiskGuard`, `Ww2BestStop`, `Ww2FindSwingLow/High`, `Ww2ScalpSwingEntry` vectors.

- [ ] **Step 1: Write `WW2CoreTests.mq5`** in the shape of `ExecGuardTests.mq5`: `OnStart` prints `TEST|RESULT|ALL_PASS|pass=<N> fail=0|ww2=1`, includes only the pure modules, and covers: a below-min-lot skip; a risk-budget cap; daily-loss halt then next-day resume; weekly halt; a trailing candidate that must NOT loosen the SL; R measured from the initial SL; a confirmed-fractal swing pick; a scalp entry that fails on a clashing M15 bias.

- [ ] **Step 2: Compile.**
Run: `powershell -NoProfile -File scripts\deploy_pineport.ps1 -Apply -Force -TerminalDataDir "<data folder>"` → `DEPLOY_OK` (includes `MQL5\Scripts\WW2CoreTests.mq5`).

- [ ] **Step 3: Record the manual runtime step** in `docs/20-operations/demo-execution.md` (append a bullet: run `Scripts > WW2CoreTests` on a demo chart; expect `ALL_PASS`). Keep the guide's existing tokens intact (`demo`, `dry-run`, `kill switch`, `take profit`, `live`).

- [ ] **Step 4: Commit.** `git commit -m "test(ww2): pure-logic contract script for sizer, risk guard and trailing"`

---

### Task 6: Registration — ADR 0009, preset, validators, docs

**Files:**
- Create: `docs/90-decisions/0009-wonderwhales-xau-2mode-demo-bot.md`
- Create: `configs/demo/wonderwhales_xau_2mode_demo.json`
- Create: `docs/10-bots/wonderwhales-2mode.md`
- Modify: `python/src/mt5_ea_ai_lab/sim_configs.py` (`EA_INPUTS`, literal `DEMO_EA_NAMES`, `_cross_checks`)
- Modify: `scripts/validate-project.py` (`DEMO_EAS`, `required_by_kind`, `REQUIRED_FILES`, `check_demo_presets`)
- Modify: `scripts/validate_demo_execution.py` (constants, `DEMO_EAS`, `check_files`, `check_adr`, `check_demo_ea` branch, `check_presets` branch, `main` report)
- Modify: `python/tests/test_demo_execution.py` (`DEMO_EA_PRESETS`)
- Modify: `docs/10-bots/README.md` (catalog → 16 EA)
- Modify: `docs/90-decisions/README.md` (index ADR 0009)

- [ ] **Step 1: ADR 0009** modelled on `0007`; must contain `Accepted`, `WonderwhalesXAU2ModeEA`, `25008001`, `DEMO_ONLY`, `NOT_RUN`, `parity`.

- [ ] **Step 2: Preset JSON** `configs/demo/wonderwhales_xau_2mode_demo.json`: `schema_version 1`, `ea "WonderwhalesXAU2ModeEA"`, `version "1.00"`, `execution_mode "DEMO_ONLY"`, `allow_live_trading false`, `symbol "XAUUSDm"`, `timeframe "M5"`, `strategy "wonderwhales_2mode"`, an `enum_map` for `InpTradingMode`/`InpSignalMode`, `assumptions`, and an `inputs` object with **exactly** the 72 keys from Task 1 (scalp defaults: `InpTakeProfitR 1.5`, `InpRiskPercent 0.15`, `InpBreakEvenTriggerR 1.0`, `InpTrailTriggerR 1.3`, `InpCooldownMinutes 20`).

- [ ] **Step 3: `sim_configs.py`.** Add `"WonderwhalesXAU2ModeEA"` to the literal `DEMO_EA_NAMES` tuple (~line 462). Add an `EA_INPUTS["WonderwhalesXAU2ModeEA"]` spec: reuse `_DEMO_EXECUTION_COMMON` for the shared demo keys, then add every remaining input with the right `Num`/`Enum`/`BOOL`/`STR`/`STR_LIST` kind (timeframes via `Enum(_TIMEFRAMES)`, `InpTradingMode` via `Enum((0,1,2))`, `InpSignalMode` via `Enum((0,1,2,3))`). Add a `_cross_checks` branch: `InpSlowEma > InpFastEma`, `InpEma200 > InpSlowEma`, `InpWarmupBars >= InpEma200`, `InpTakeProfitR > 0`, `InpMaxPositions == 1`, `InpMaxExposure > 0`, `InpMaxDailyLossPct > 0`, `InpMaxWeeklyLossPct > 0`, `InpMaxDrawdownPct > 0`, `InpSwingTriggerTF < InpSwingSetupTF < InpSwingBiasTF` and `InpScalpTriggerTF < InpScalpSetupTF < InpScalpBiasTF` (seconds), `InpMaxStopPoints >= InpMinStopPoints`.

- [ ] **Step 4: `validate-project.py`.** Add `"mt5/Experts/WonderwhalesXAU2ModeEA.mq5": "ww_2mode"` to `DEMO_EAS`; add a `ww_2mode` entry to `required_by_kind` with tokens `("ExecFindOwnPosition","ExecModifyStops","ExecCalcProfit","InpTakeProfitR","InpRiskPercent","InpMaxPositions","InpMaxExposure")`; add the EA, the include files, the preset and `docs/90-decisions/0009-…`, `docs/10-bots/wonderwhales-2mode.md` to `REQUIRED_FILES`; add a `WonderwhalesXAU2ModeEA` branch to `check_demo_presets` (assert `InpTakeProfitR>0`, `InpMaxExposure>0`, `InpMaxPositions==1`, `InpRequireParity is True`).

- [ ] **Step 5: `validate_demo_execution.py`.** Add `WW2_DEMO_EA`, `WW2_DEMO_PRESET`, `ADR_0009` constants; add `WW2_DEMO_EA: "single_position"` to `DEMO_EAS`; add both to `check_files`; extend `check_adr` for ADR 0009 (`Accepted`, `WonderwhalesXAU2ModeEA`, `25008001`, `DEMO_ONLY`, `NOT_RUN`, `parity`); add a `relative == WW2_DEMO_EA` branch in `check_demo_ea` requiring `ExecFindOwnPosition/ExecModifyStops/ExecCalcProfit/ExecMarginRequired/ExecClosedPnl/ExecTakeProfitPrice/ExecTakeProfitValid/ExecStopsRespectBroker/WonderwhalesContract.mqh`, `_input_default(text,"InpMaxPositions") in (None,"1")`, and forbidding `InpMaxGridLevels/InpMaxDcaAdds/ExecDemoBasketClose`; add a `WW2_DEMO_PRESET` branch in `check_presets` (`ea` correct, `DEMO_ONLY`, `allow_live_trading False`, `InpEnableExecution True`, `InpAllowedSymbols` has XAUUSD, `InpTakeProfitR>0`, `InpMaxExposure>0`, `InpRequireParity True`); add `report("wonderwhales 2-mode demo EA guardrails", check_demo_ea(root, WW2_DEMO_EA))` in `main` (checks 13 → 14).

- [ ] **Step 6: pytest.** Add `("WonderwhalesXAU2ModeEA","wonderwhalesxau2modeea", REPO_ROOT/"configs"/"demo"/"wonderwhales_xau_2mode_demo.json")` to `DEMO_EA_PRESETS` (adds the fail-closed, input-match, magic and OrderSend parametrised cases).

- [ ] **Step 7: Catalog + bot page.** `docs/10-bots/README.md`: header "16 EA", add the row `| \`WonderwhalesXAU2ModeEA.mq5\` | demo | 25008001 | configs/demo/wonderwhales_xau_2mode_demo.json | [wonderwhales-2mode.md](wonderwhales-2mode.md) | \`NOT_RUN\` |`. New page `wonderwhales-2mode.md` with the six sections (chiến lược, cấu trúc code, bảng input + cột "Tên chuẩn", preset/magic, bằng chứng, giới hạn) and the spec→`Inp*` mapping table.

- [ ] **Step 8: Run every gate.**
Run: `.\.venv\Scripts\python.exe scripts\validate-project.py` → `fail=0` (record the new `checks=N`)
Run: `.\.venv\Scripts\python.exe scripts\validate_demo_execution.py` → `checks=14 fail=0`
Run: `.\.venv\Scripts\python.exe scripts\check_docs_links.py` → `broken=0`
Run: `.\.venv\Scripts\python.exe -m pytest -q` → all pass; record the new count (was 436)

- [ ] **Step 9: Commit.** `git commit -m "feat(ww2): register ADR 0009, demo preset, validators, catalog and bot page"`

---

### Task 7: Strategy Tester — parity gate proof + order-path proof

**Files:**
- Create: `reports/build/tester-run/gen_ww2_sets.py` (gitignored local tool)
- Create: `reports/build/tester-run/ww2_scalp_demo_exec.ini`, `ww2_swing_demo_exec.ini`, `ww2_scalp_parity_on.ini` (gitignored)
- Create: `reports/build/tester-sets/ww2_*.set` (gitignored)
- Create: `docs/20-operations/presets/wonderwhales_xau_2mode_scalp.set`, `…_swing.set` (tracked)

- [ ] **Step 1: Generator** derived from `gen_demo_exec_sets.py`: reads `configs/demo/wonderwhales_xau_2mode_demo.json`, writes `.set` + `.ini`, stages the `.set` into `MQL5\Profiles\Tester\`. Three scenarios: `ww2_scalp_demo_exec` (`InpTradingMode=1`, `InpRequireParity=false`, `Period=M5`, `InpLogFile=sim_ww2_scalp_demo_exec.csv`), `ww2_swing_demo_exec` (`InpTradingMode=2`, `InpRequireParity=false`, `Period=H1`), `ww2_scalp_parity_on` (`InpTradingMode=1`, `InpRequireParity=true`, `Period=M5`). All `Model=1`, `Symbol=XAUUSDm`, 2026.01.05→2026.10.01, `Deposit=10000`, `ShutdownTerminal=1`.

- [ ] **Step 2: Run parity-on.**
Run: `powershell -NoProfile -File reports\build\tester-run\run_tester.ps1 -Scenario ww2_scalp_parity_on`
Expected: tester completes; journal shows `parity_blocked` and **0 ENTRY** rows → the gate holds.

- [ ] **Step 3: Run scalp and swing order-path scenarios.** Same command with `ww2_scalp_demo_exec` then `ww2_swing_demo_exec`.
Expected: journal has ENTRY/EXIT rows with SL+TP on every entry → `ExecBroker` path proven.

- [ ] **Step 4: Honest labelling.** Record in the bot page §5 and `docs/PROGRESS.md`: parity-on run = gate evidence; the parity-off runs = **infrastructure only, not a strategy result** (`NOT_STRATEGY_RESULT`); strategy label stays `NOT_RUN` (no parity, no forward demo). If any scenario cannot run headlessly, record `NOT_RUN` with the exact reason instead of a fabricated result.

- [ ] **Step 5: Commit.** `git commit -m "test(ww2): headless tester runs — parity gate and order path"`

---

### Task 8: Close-out

**Files:**
- Modify: `docs/PROGRESS.md` (append §71)
- Modify: `docs/10-bots/wonderwhales-2mode.md` (fill evidence/labels)

- [ ] **Step 1: Append `docs/PROGRESS.md` §71** with: branch, commits, ADR 0009, magic 25008001, compile result, measured gate numbers, tester artefacts (paths + sha256 if available), and the honest labels. Append-only.
- [ ] **Step 2: Re-run all gates once more** on the final tree (`validate-project`, `validate_demo_execution`, `check_docs_links`, `pytest`) and paste the exact summary lines into §71.
- [ ] **Step 3: Commit** `git commit -m "docs(ww2): PROGRESS §71 and evidence labels"`.
- [ ] **Step 4: Report** the final gate numbers, the tester artefact paths, and the remaining honest `NOT_RUN`/`NOT_STRATEGY_RESULT` labels to the project owner. Do not push or merge without an explicit instruction.

## Self-Review

- **Spec coverage:** §2.1 scalp rules → Task 4; §2.2 swing → Task 4; §3 risk/daily/weekly/drawdown → Task 2; §3.3 sizing → Task 2; §4 trailing → Task 3; §5.4 parity gate → Task 4; §6 inputs → Task 1 table; §7 order flow/initial R/restart → Tasks 2/4; §8 architecture → Tasks 1–4; §9 journal + telemetry → Tasks 1/3; §10 tester → Task 7; §13 checklist → Tasks 2–7; S4 telemetry → Task 3.
- **Type consistency:** `Ww2Signal`/`Ww2Position`/`Ww2StopInput` names and `Ww2*` function signatures are defined once (Tasks 1/3) and referenced unchanged afterwards.
- **Review Focus:** each of the five items is pinned by a test or step (Task 2 Steps 1/4, Task 3 Step 5, Task 4 Step 3, Task 5 Step 1).
- **Proportion:** no module bodies are written here; only names, signatures, values and registry diffs.
