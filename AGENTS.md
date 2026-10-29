# AGENTS.md — MT5 EA & AI Lab (tm-fx)

Guidance for AI coding agents working in this repository.

## Project Overview

**MT5 EA & AI Lab (`tm-fx`)** is an independent research and development laboratory for MQL5 Expert Advisors (EAs), indicators, Python data/ML pipelines, and reproducible MetaTrader 5 backtesting and offline simulation.

- **Stack**: Python 3.11 (scikit-learn, ONNX, pytest) + MetaTrader 5 (MQL5 / MetaEditor64).
- **Scope**: Signal-only research, offline simulations (SL/TP, trailing stops, bounded basket/DCA), ML baselines, ONNX inference parity, indicator conversion, and **guarded demo-account execution** (ADR 0003). No live/real-account execution, no broker credentials, no login automation.

## Guidelines & Conventions

- **Open Source First**: Đối với những chức năng chưa quen thuộc, đừng viết từ con số 0, hãy tìm kiếm các dự án mã nguồn mở trên GitHub để so sánh ý tưởng trước khi bắt tay vào làm.
- **Language Policy**: Technical documentation, code comments, commit messages, and identifiers should be written in English (or Vietnamese where matching existing project docs).
- **Execution Boundary**: The only execution path is `mt5/Experts/PATrendRiderXAUv1DemoEA.mq5` with `mt5/Include/Exec/*` (ADR 0003). It must accept only `ACCOUNT_TRADE_MODE_DEMO` or Strategy Tester, default to dry-run (`InpEnableExecution=false`), keep one position with mandatory SL/TP, honour the risk ledger and kill switch, and never use grid/DCA/martingale. Real/live accounts stay forbidden; do not add login, credential or `WebRequest`/socket code. Simulation EAs remain simulation-only.
- **Testing & Parity**: Verify numerical parity when porting logic between Python, Pine Script, and MQL5.

## Testing & Verification

```powershell
.\.venv\Scripts\Activate.ps1
python -m pytest
```
