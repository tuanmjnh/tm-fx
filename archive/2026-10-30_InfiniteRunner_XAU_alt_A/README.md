# Archive — InfiniteRunner_XAU "alt A" parallel implementation (2026-10-30)

This folder preserves the first InfiniteRunner_XAU V2 workstream so no work is
lost. It is **not buildable as-is** and must not be copied back into `mt5/`
without owner approval.

## Why this exists

Two parallel agents implemented the same Upgrade Pack on 2026-10-30:

- **alt A (this archive, written 15:27–15:31)**:
  `InfiniteRunnerXAUDemoEA.mq5` + own pure modules `IRMarket.mqh` (IREmaSnap
  swing/reclaim engine, sessions) and `IRRisk.mqh`, plus a Python port
  (`infinite_runner.py`) with 10 pytest cases and a contract test script.
- **alt B (canonical, 15:40–15:49, in `mt5/`)**:
  `InfiniteRunnerXAUV2DemoEA.mq5` + rewritten `IRTypes.mqh`,
  `IRDirection.mqh`, `IRTrailing.mqh`.

Custom of the session allowed per-file overwrite; alt B rewrote
`IRTypes.mqh`/`IRDirection.mqh` that alt A depended on (`ENUM_IR_DIR_MODE`,
`IR_LOT_RISK_PERCENT`, `IREmaSnap`), so alt A cannot compile anymore and its
original header files cannot be restored (repository had no git commits).

## Owner decision (2026-10-30)

- Canonical: **alt B** (`mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5`).
- alt A: archived here, files unchanged apart from being moved.
- ADR 0005 records the canonical state; see `docs/decisions/0005-*.md`.

## Notes

- Both threads chose magic `25006001`; the canonical EA keeps it.
- alt A's unique ideas (swing-structure triggers `IRSwingLow/High`,
  session windows `IRSessionOpen`, `IRSignalId` dedupe, `InpTakeProfitR`
  instead of a far safety TP) remain documented inside the archived sources
  if a later ADR wants to adopt them incrementally.
- The MQL5 files here include `../Include/...` paths that no longer exist
  after the move; that is expected for an archive.
