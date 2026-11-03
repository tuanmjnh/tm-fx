# GitHub open-source research — starting shortlist

**Snapshot date:** 2026-10-29. This is a discovery shortlist, not a security audit or endorsement. Recheck repository contents, last commit, license text, dependencies and exact commit SHA immediately before using any source. Do not infer profitability from stars, README claims or screenshots.

## Candidates found in initial web research

| Repository | What to inspect | License reported by repository page | Initial caution |
|---|---|---|---|
| [EA31337/EA31337](https://github.com/EA31337/EA31337) | Broad MQL4/MQL5 EA architecture, strategy separation, input system, risk filters, compiler/dependency workflow, test documentation | GPL-3.0 | Large and complex; inspect current source and submodules. GPL terms can affect derivative redistribution. Better for architecture study unless GPL compatibility is explicitly accepted. |
| [santiquiroz/leviathan](https://github.com/santiquiroz/leviathan) | MQL5 EA plus Python backtester, parity between signal logic and tests, tests/docs layout | MIT | Small community footprint; validate whether Python fill assumptions really match MT5 and inspect all tests/source. |
| [BlamzKunG/XAUUSD-Grid-EA](https://github.com/BlamzKunG/XAUUSD-Grid-EA) | Grid layers, ATR/dynamic step, presets, XAUUSD-specific symbol handling, Strategy Tester guidance | MIT | Small/new repository (initial page showed only a few stars and commits). Treat all risk claims as unverified; inspect for unlimited exposure, hedge assumptions and code defects. |
| [ilyasyldrm0/MetaTrader5-BOT](https://github.com/ilyasyldrm0/MetaTrader5-BOT) | Python MT5 adapter, dry-run/paper mode, CLI structure, contract diagnostics, test suite and risk separation | MIT | README explicitly notes the sample strategy/data are not proof of profitability and some market costs may be simplified. Use as integration/test-harness reference only after reading source. |
| [omidram/trading-bot](https://github.com/omidram/trading-bot) | Python strategy module, risk engine, config, reports and MT5 demo-execution gate | MIT | Small repository; inspect execution path and test coverage. Keep demo-only guard in our own project regardless of how this one works. |
| [edisonq/Golden-Structure-V1](https://github.com/edisonq/Golden-Structure-V1) | Trend-following EA structure, closed-bar signals, risk sizing and installation docs | MIT | Strategy is not the user's PATrendRiderXAUv1. Do not assume the logic is equivalent; use only as a code-structure example after audit. |
| [AlexKu111/GridBot-Mql5](https://github.com/AlexKu111/GridBot-Mql5) | Simple MQL5 grid structure and range filter | No formal license confirmed from initial listing | Do not copy or redistribute code unless a valid license is found. Use only as a read-only reference until license status is resolved. |

## Initial findings

- `EA31337` is the broadest architecture reference but is GPL-3.0; it should not be copied casually into a project with a different licensing plan.
- The two MIT candidates with EA + Python/backtest structure (`leviathan`, `MetaTrader5-BOT`) may help reduce the effort for test architecture, but must be checked for code quality and execution-model mismatches.
- The XAUUSD grid candidate is a narrow reference, not a trusted trading system. Verify whether it handles account margin mode, symbol contract details, volume caps, grid termination and persistent state correctly.
- A public repository does not mean the code is safe, maintained, profitable, or suitable for Exness symbol conditions.
- `PATrendRiderXAUv1` is a user-owned/current bot and must be derived from its actual source/configuration. None of the public candidates should silently replace it.

## Required full audit before reuse

For every repository selected by the AI agent, record:

1. Canonical URL, checked date/time, default branch and exact commit SHA.
2. License file contents and SPDX license identifier; note missing/ambiguous licenses.
3. Source files actually read (especially order sending/modification/close logic and risk sizing).
4. Build/test workflow, test coverage, test-data provenance and whether test claims were reproduced.
5. Dependencies, runtime network calls, secrets handling, scripts, binary artifacts and suspicious obfuscation.
6. Whether the code supports MQL5/MT5 specifically (not just MT4 or a Python-only simulator).
7. What to reuse: architecture patterns, tests, utility code or documentation; avoid copying whole EAs by default.
8. Attribution/license notices and compatibility plan for every reused file.
9. Decision: `USE`, `REFERENCE_ONLY`, or `REJECT`, with a concise reason.

The coding agent must perform its own live check at implementation time. This shortlist is not a substitute for source-level review.
