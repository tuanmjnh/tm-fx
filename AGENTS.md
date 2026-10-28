# AGENTS.md — MT5 EA & AI Lab (tm-fx)

Guidance for AI coding agents working in this repository.

## Project Overview

**MT5 EA & AI Lab (`tm-fx`)** is an independent research and development laboratory for MQL5 Expert Advisors (EAs), indicators, Python data/ML pipelines, and reproducible MetaTrader 5 backtesting and offline simulation.

- **Stack**: Python 3.11 (scikit-learn, ONNX, pytest) + MetaTrader 5 (MQL5 / MetaEditor64).
- **Scope**: Signal-only research, offline simulations (SL/TP, trailing stops, bounded basket/DCA), ML baselines, ONNX inference parity, and indicator conversion. No live execution or broker credentials.

## Guidelines & Conventions

- **Open Source First**: Đối với những chức năng chưa quen thuộc, đừng viết từ con số 0, hãy tìm kiếm các dự án mã nguồn mở trên GitHub để so sánh ý tưởng trước khi bắt tay vào làm.
- **Language Policy**: Technical documentation, code comments, commit messages, and identifiers should be written in English (or Vietnamese where matching existing project docs).
- **Execution Boundary**: No live execution or order sending to live broker accounts; all trading logic remains simulated or signal-only.
- **Testing & Parity**: Verify numerical parity when porting logic between Python, Pine Script, and MQL5.

## Testing & Verification

```powershell
.\.venv\Scripts\Activate.ps1
python -m pytest
```
