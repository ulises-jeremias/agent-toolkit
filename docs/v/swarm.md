# V `swarm` command family

**Issue:** [#524](https://github.com/ulises-jeremias/agent-toolkit/issues/524) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **REDESIGN**)  
**Architecture:** [ADR-008](../adrs/ADR-008-swarm-orchestration.md) · [ADR-020](../adrs/ADR-020-v-concurrency.md)

Not a 1:1 port of Python threads/Herdr socket calls. The V CLI owns **filesystem state** under `.agent-toolkit/swarm/runs/<run-id>/`. UI backends (Herdr, tmux, headless) are isolated probes — this module does **not** invent Herdr APIs.

Subcommands: `recipes` / `backends` / `doctor` / `start` / `list` / `status` / `approve` / `reject` / `cancel`.

- Built-in recipes: `pair`, `team`, `full` (plan gate on team/full; final gate always).
- `start --dry-run` plans without writes. Real start writes `state.json` + `approvals.json`; UI spawn is **fail-closed** until ProcessService stdin exists.
- **Windows:** tmux/herdr unsupported; use `--backend headless`.
