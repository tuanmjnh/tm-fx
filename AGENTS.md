# AGENTS.md — MT5 EA & AI Lab (tm-fx)

Guidance for AI coding agents working in this repository.

## Project Overview

**MT5 EA & AI Lab (`tm-fx`)** is an independent research and development laboratory for MQL5 Expert Advisors (EAs), indicators, Python data/ML pipelines, and reproducible MetaTrader 5 backtesting and offline simulation.

- **Stack**: Python 3.11 (scikit-learn, ONNX, pytest) + MetaTrader 5 (MQL5 / MetaEditor64).
- **Scope**: Signal-only research, offline simulations (SL/TP, trailing stops, bounded basket/DCA), ML baselines, ONNX inference parity, indicator conversion, and **guarded demo-account execution** (ADR 0003). No live/real-account execution, no broker credentials, no login automation.

## Guidelines & Conventions

- **Open Source First**: Đối với những chức năng chưa quen thuộc, đừng viết từ con số 0, hãy tìm kiếm các dự án mã nguồn mở trên GitHub để so sánh ý tưởng trước khi bắt tay vào làm.
- **Language Policy**: Technical documentation, code comments, commit messages, and identifiers should be written in English (or Vietnamese where matching existing project docs).
- **Execution Boundary**: Every bot may place real orders on a **demo account** only (ADR 0004 + ADR 0005). The demo EAs are `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5`, `mt5/Experts/GridDemoEA.mq5`, `mt5/Experts/DCADemoEA.mq5` and `mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5` (magic 25006001, includes under `mt5/Include/InfiniteRunner/*`), all built on `mt5/Include/Exec/*`. Each must accept only `ACCOUNT_TRADE_MODE_DEMO` or the Strategy Tester, ship with execution enabled by default (`InpEnableExecution=true`, ADR 0006 — owner decision 2026-10-30; dry-run is the explicit `false` override), put mandatory SL/TP on every order, keep a per-magic risk ledger with hard caps (max levels/adds, exposure, risk %, daily loss, drawdown, consecutive losses), honour the kill switch, and route every order through `ExecBroker` (the single order-send point). Grid/DCA position adds are bounded, never unbounded martingale. Real/live accounts stay forbidden; do not add login, credential or `WebRequest`/socket code. Simulation EAs remain simulation-only.
- **Testing & Parity**: Verify numerical parity when porting logic between Python, Pine Script, and MQL5.

## Testing & Verification

```powershell
.\.venv\Scripts\Activate.ps1
python -m pytest
```
