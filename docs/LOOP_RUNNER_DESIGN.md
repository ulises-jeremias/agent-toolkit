# Retired Python loop runner — migration record

**Status:** historical, not a current design contract. This note records the
Python runner implementation that preceded the V runtime migration. Its runner
names, environment variables, Python paths, mutation-gate shim, and execution
details must not be used as guidance for current behavior.

## Current implementation

The V engine owns loop execution, runner selection, budget checks, mutation
gates, state, reports, and scheduling. The maintained references are:

- [Loop Engineering](LOOPS.md) — user-facing behavior and safety contract.
- [Create a loop](HOW_TO_CREATE_LOOP.md) — authoring workflow.
- `modules/agent_toolkit_core/loop.v` — run lifecycle and pack overrides.
- `modules/agent_toolkit_core/loop_runners.v` — current runner adapters.
- `modules/agent_toolkit_core/loop_gate.v` — mutation enforcement.
- `modules/agent_toolkit_core/loop_catalog.v` — discovery and status.
- `docs/desktop/workflows.yaml` — verified Desktop journeys and known limits.

The Electron Desktop uses the same V backend through typed API operations; it
does not run or parse the retired Python loop runner.

## Why this record remains

The historical design informed the V port and is referenced by
[ADR-008](adrs/ADR-008-swarm-orchestration.md),
[ADR-020](adrs/ADR-020-v-concurrency.md), and the runner-adapter source
comments. The original implementation details remain in Git history; this
page is intentionally short so obsolete internals do not appear to be current
instructions.
