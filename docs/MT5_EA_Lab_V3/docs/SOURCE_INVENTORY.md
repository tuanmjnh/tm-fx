# Source Inventory — what is available and what is missing

Last reconciled: 2026-10-30. Re-scan workspace before implementation.

## 1. Files included in this V3 pack

| File | Status | Notes |
|---|---|---|
| `inputs/legacy_sources/InfiniteRunner_XAU.mq5` | AVAILABLE | V1 source; inspect and keep immutable. |
| `inputs/legacy_sources/InfiniteRunnerXAUV2DemoEA.mq5` | AVAILABLE | Main V2 EA only; has missing `.mqh` dependencies below. |
| `inputs/specifications/PA_TrendRider_XAU_V1_Specification_Vietnamese.md` | AVAILABLE | Detailed specification. Does not prove source parity. |
| `inputs/legacy_docs/STRATEGY_SPEC_GRID_DCA_TRAILING.md` | AVAILABLE | Strategy spec, not complete implementation. |
| `inputs/legacy_docs/ROADMAP_GRID_DCA_TRAILING_SIMULATION.md` | AVAILABLE | Prior roadmap reference. V3 is canonical. |
| `inputs/legacy_docs/GITHUB_OPEN_SOURCE_RESEARCH.md` | AVAILABLE | Initial shortlist; not a fresh source-level audit. |

## 2. Missing source inputs

### InfiniteRunner V2 includes

The uploaded V2 `.mq5` has these includes, none of which was present in the supplied source package:

- `Exec/ExecBroker.mqh`
- `Sim/SimTypes.mqh`
- `Sim/SimValidate.mqh`
- `Sim/SimRiskGuard.mqh`
- `Sim/SimLogger.mqh`
- `InfiniteRunner/IRTypes.mqh`
- `InfiniteRunner/IRDirection.mqh`
- `InfiniteRunner/IRTrailing.mqh`

The AI must either locate these exact original files if the user adds them, or write a documented migration to V3 common core. Do not invent their existing behavior.

### PATrendRiderXAUv1

- The detailed spec is present.
- Original `.mq5`, `.mqh`, `.set`, screenshots/backtest report are not included in the known inputs.
- A `SPEC_BUILD` can be implemented from the spec, but must be labeled as a new implementation, not a verified clone of the user's current bot.

### GridEA / DCAEA

- Prior strategy specs/roadmaps are included.
- No complete `.mq5/.mqh` source or verified `.set` preset is included.
- Must be implemented and tested as new EAs; no source parity exists yet.

### Pine indicators

- No Pine source files are included in this project pack.
- Pine adapter remains optional and blocked until the user supplies source files.

## 3. AI must maintain inventory status

Each source file must be labeled:

- `USER_SOURCE_READ_ONLY`
- `NEW_V3_SOURCE`
- `THIRD_PARTY_AUDITED`
- `MISSING`
- `BLOCKED_LICENSE`
- `BLOCKED_INPUT`

Do not modify read-only files. Copy source to new paths only with a manifest and SHA256 so the original baseline remains unchanged.
