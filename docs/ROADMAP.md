# Roadmap

## Current program — Contribution Master Plan

The current public program of record is the **Contribution Master Plan**: Waves 0–2 (trust, truth, release) tracked under epic [#240](https://github.com/ulises-jeremias/agent-toolkit/issues/240), and Waves 3–5 (architecture, tests, delight) tracked under [#263](https://github.com/ulises-jeremias/agent-toolkit/issues/263).

Waves are labeled `wave:0` … `wave:5` on issues. Workstream children are filed under the parent epics as they are created.

## How to follow waves

1. Start at [#240](https://github.com/ulises-jeremias/agent-toolkit/issues/240) (Waves 0–2) and [#263](https://github.com/ulises-jeremias/agent-toolkit/issues/263) (Waves 3–5).
2. Filter by label `wave:0` … `wave:5`, `good first issue`, `help wanted`.
3. Prefer open leaf issues under those epics for implementation PRs.

## Completed predecessor

Epic [#32](https://github.com/ulises-jeremias/agent-toolkit/issues/32) — consumer-first simplification — is **closed and completed**. It superseded the earlier Phase 3–7 native multi-runtime roadmap ([#7](https://github.com/ulises-jeremias/agent-toolkit/issues/7)). Remaining gaps from #7 were folded into the #32 workstream hierarchy.

## Non-goals for next quarter

* No CLI package split (keep one CLI binary per `docs/SCOPE.md` / `docs/CLI_SURFACES.md` — locked decision per #240 North-star)
* No presets layer
* No invasive telemetry (issues #280–#282 are deferred markers unless RFC asks)

See also [CONTRIBUTING.md](../CONTRIBUTING.md) for wave-order review and [MAINTAINERS.md](../MAINTAINERS.md) for governance.
