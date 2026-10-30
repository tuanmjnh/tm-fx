# GitHub Open-Source Research Process

## 1. Purpose

Research code that can reduce engineering time for MQL5 project structure, symbol utilities, trade wrappers, logging, tester automation, strategy state, grid/basket accounting and test harnesses. Reuse components only after source/license audit. Do not copy an entire strategy because it has screenshots or claimed performance.

## 2. Starting candidates from prior V2 research

These are discovery leads, not approvals. Re-check each repository live at implementation time:

| Repository | Initial area to inspect | Prior license indication | Default decision until audited |
|---|---|---|---|
| https://github.com/EA31337/EA31337 | MQL EA architecture/strategies | GPL-3.0 | REFERENCE_ONLY until license compatibility decided |
| https://github.com/santiquiroz/leviathan | MQL5 EA + Python backtest parity | MIT | REFERENCE_ONLY |
| https://github.com/BlamzKunG/XAUUSD-Grid-EA | XAUUSD grid structure | MIT (recheck) | REFERENCE_ONLY |
| https://github.com/ilyasyldrm0/MetaTrader5-BOT | Python MT5 bridge/backtest/testing | MIT (recheck) | REFERENCE_ONLY |
| https://github.com/omidram/trading-bot | Python strategy/risk/demo integration patterns | MIT (recheck) | REFERENCE_ONLY |
| https://github.com/edisonq/Golden-Structure-V1 | trend/structure MQL5 sample | MIT (recheck) | REFERENCE_ONLY |
| https://github.com/AlexKu111/GridBot-Mql5 | MQL5 grid sample | no formal license confirmed in prior scan | REFERENCE_ONLY; do not copy absent license |

## 3. Required audit fields

For each selected repo, record:

- canonical URL;
- audit date/time;
- default branch and exact commit SHA;
- last commit date and recent maintenance activity;
- complete LICENSE text and SPDX identifier;
- source files inspected (especially order send/modify/close and risk sizing);
- MQL4 vs MQL5 compatibility;
- tests/build workflow, coverage, data source and reproduction status;
- dependencies, scripts, binaries, network requests, credentials and suspicious obfuscation;
- exact files considered for reuse;
- license/attribution compatibility;
- `USE`, `REFERENCE_ONLY`, or `REJECT` decision and reason.

## 4. Audit rules

- A public GitHub repository is not automatically safe, maintained or profitable.
- Missing license means no copying/redistribution; source can be read as a concept reference only.
- GPL-derived code can impose obligations on derivative distributions. Do not copy into a differently licensed project without explicit compatibility review.
- Never include compiled `.ex5` from unknown sources as trusted binaries.
- Inspect `CTrade`/OrderSend code, magic handling, hedging/netting, tick-size and volume normalization, stop/freeze checks, retcodes, idempotency, state restore and kill switch.
- Ignore performance claims unless independently reproduced using a recorded dataset and configuration.
- Prefer small utility patterns and tests over entire EA imports.

## 5. Research outputs

Create `research/GITHUB_AUDIT.md`, `research/REUSE_DECISIONS.md`, `THIRD_PARTY_NOTICES.md` when appropriate. The coding agent should not stop at the old shortlist; it must verify current repository state and add better candidates if available.
