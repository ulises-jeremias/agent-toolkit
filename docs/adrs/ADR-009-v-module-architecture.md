# ADR-009: V Module / Repository Architecture (Core vs CLI)

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#479](https://github.com/ulises-jeremias/agent-toolkit/issues/479), parent epic [#458](https://github.com/ulises-jeremias/agent-toolkit/issues/458))

## Context

Agent Toolkit is migrating from a Python CLI (`packages/agent-toolkit-cli`) to a native V binary-first product. Create-Vlang-App’s ADR-0001 documents a `modules/` layout with a core library and a thin CLI. Agent Toolkit needs the same separation so CLI, future HTTP (`serve`), and future TUI adapters share one domain core — without making VPM the primary distribution channel (binary GitHub Releases remain canonical; see program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)).

## Options considered

1. **Single flat V module** — one tree containing CLI and domain logic.
2. **`modules/agent_toolkit_core` + `modules/agent_toolkit_cli`** — core has no interface knowledge; CLI is a thin adapter. Server/TUI modules are **not** created until those epics start.
3. **Core + CLI + empty server/TUI stubs now** — reserve directories early.

## Decision

Adopt **option 2**.

```text
agent-toolkit/
  v.mod                          # workspace meta (optional)
  .v-version                     # pinned V compiler (separate issue)
  modules/
    agent_toolkit_core/          # domain services, models, FS/process/network
      v.mod
    agent_toolkit_cli/           # thin CLI adapter → core
      v.mod
```

Rules:

- **Core must not import CLI, TUI, or HTTP frameworks.** It must not know whether it was invoked from CLI, tests, future `serve`, or future TUI.
- **CLI is an adapter only:** parse argv, call core, render human/JSON (see ADR-010 / [#480](https://github.com/ulises-jeremias/agent-toolkit/issues/480)).
- **Do not create** `modules/agent_toolkit_server` or `modules/agent_toolkit_tui` until EPIC 14 / EPIC 16 start. Architecture *allows* them; the filesystem does not need stubs.
- **VPM is optional for developers**, never required for normal binary installation. Do **not** copy Create-Vlang-App’s VPM-primary distribution ADR.
- Existing Python package layout (`packages/agent-toolkit-cli`) remains until cutover / retirement gates; V modules land beside it during the strangler.

## Consequences

- **Positive:** Clear boundary for adapters; reusable core for parity harness and future surfaces; aligns with CVA patterns we REUSE/ADAPT.
- **Negative:** Contributors learn two `v.mod` files and a Makefile orchestration (acceptable).
- **Rejected:** Flat module (hard to keep CLI out of domain); premature server/TUI stubs (noise and false coupling).

## Validation plan

- When EPIC 1 lands: `v test` / `v vet` / `v fmt -verify` on each module; CLI depends on core via `VMODULES` (or equivalent) without circular imports.
- CI must fail if `agent_toolkit_core` gains imports of CLI/server/tui packages.

## References

- Create-Vlang-App `docs/adr/0001-module-layout.md`
- Program epic [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)
- Issue [#479](https://github.com/ulises-jeremias/agent-toolkit/issues/479)

**Verified:** 2026-08-12
