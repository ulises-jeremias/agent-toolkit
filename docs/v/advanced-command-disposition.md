# Advanced command disposition (EPIC 5)

**Issue:** [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560)  
**Parent:** [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462)

Consumer commands stay **strong-compat** (`install`/`update`/`uninstall`/`doctor`/`diff`/`skills`/`mcp`/`plugin`). Advanced commands are dispositioned here so Python retirement ([#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540)) does **not** require ports marked REMOVE or DEPRECATE.

Legend: **PORT** 1:1 V rewrite · **REDESIGN** V rewrite with a different shape · **MERGE** fold into another command · **DEPRECATE** keep Python until removal, no V requirement · **REMOVE** drop from the V CLI (CI/docs replace it).

| Command | Issue | Disposition | Retirement gate? | Rationale |
|---------|-------|-------------|------------------|-----------|
| `workspace` | [#520](https://github.com/ulises-jeremias/agent-toolkit/issues/520) | **PORT** | Yes | L3 harness session contract (`init`/`context`/`sync`). Distinct from `project`. |
| `memory` | [#521](https://github.com/ulises-jeremias/agent-toolkit/issues/521) | **PORT** | Yes | Workspace knowledge base; `inject`/`todo` are session-start protocol. |
| `project` | [#522](https://github.com/ulises-jeremias/agent-toolkit/issues/522) | **PORT** | Yes | Repo index (`clone`/`list`/`add`); overlaps conceptually with workspace but different FS layout (`repos/` vs workspace overlay). Do **not** MERGE. |
| `loop` | [#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523) | **REDESIGN** | Yes | Product differentiator; do not clone Python threads — follow [#528](https://github.com/ulises-jeremias/agent-toolkit/issues/528) + process service. |
| `swarm` | [#524](https://github.com/ulises-jeremias/agent-toolkit/issues/524) | **REDESIGN** | Yes | Keep surface; backends (Herdr/tmux) behind interfaces (ADR-008). Concurrency via #528. |
| `devcompanion` | [#525](https://github.com/ulises-jeremias/agent-toolkit/issues/525) | **PORT** | Yes | Filesystem job queue used by AGENTS.md. Keep **`dc` alias** (already in V dispatcher). |
| `insights` | [#526](https://github.com/ulises-jeremias/agent-toolkit/issues/526) | **DEPRECATE** | **No** | Local DB/path parsers churn with Cursor/OpenCode; privacy-sensitive; not required for consumer cutover or Python removal. Quarantined `agent-toolkit-py` may keep it; V need not port. |
| `release` | [#527](https://github.com/ulises-jeremias/agent-toolkit/issues/527) | **REMOVE** | **No** | Maintainer artifact generation belongs in GitHub Actions / `docs/RELEASING.md`, not the runtime CLI. V help may list it as unsupported; do not port. |

## Alias policy

- **`dc` → `devcompanion`:** keep (user muscle memory; already wired).
- **`rollback` → `uninstall`:** keep (consumer).
- No new aliases for REMOVE/DEPRECATE commands.

## Overlap notes

- `workspace` vs `project`: workspace scaffolds the overlay (`AGENTS.md`, personas, packs); project manages git clones + `projects/` symlinks. Both PORT; neither absorbs the other.
- `update` vs binary upgrade: not in this table — see [ADR-017](../adrs/ADR-017-update-ownership.md).

## EPIC 5 sequencing

1. PORT `workspace` → `memory` → `project` (shared workspace root).
2. PORT `devcompanion` (queue is independent of loops).
3. REDESIGN `loop` after [#528](https://github.com/ulises-jeremias/agent-toolkit/issues/528) / [ADR-020](../adrs/ADR-020-v-concurrency.md) (process-per-run supervisor).
4. REDESIGN `swarm` after loop/process patterns exist (`docs/v/swarm.md`).
5. Close #526/#527 as dispositioned without V implementations.

Quarantined `agent-toolkit-py` remains available for DEPRECATE/REMOVE commands ([python-fallback.md](python-fallback.md)), matching [ADR-012](../adrs/ADR-012-python-v-coexistence.md) (no per-command mixed engine).
