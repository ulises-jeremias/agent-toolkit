# Configuration and environment precedence (V migration)

**Status:** Accepted contract  
**Date:** 2026-08-12  
**Issue:** [#559](https://github.com/ulises-jeremias/agent-toolkit/issues/559)  
**Program:** [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)  
**Related:** ADR-015 ([#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547)), ADR-010 ([#480](https://github.com/ulises-jeremias/agent-toolkit/issues/480)), CLI contract ([#549](https://github.com/ulises-jeremias/agent-toolkit/issues/549))

## Precedence (authoritative)

```text
CLI flags  >  environment variables  >  config files (if any)  >  built-in defaults
```

Rules:

1. An explicit CLI flag always wins over env/config/default for the same setting.
2. Environment variables win over config files and defaults when the flag is omitted.
3. Config files (workspace/tool config) apply only when neither flag nor env set the value.
4. Defaults are last resort and must be documented (this file + CLI contract).
5. **No silent renames** of `AGENT_TOOLKIT_*` (or aliases) without a migration note in CHANGELOG and this inventory.

Resource *path* resolution (which data root wins) is ADR-015; this document covers *settings* precedence and the env inventory.

## Inventory — `AGENT_TOOLKIT_*` and related

| Variable | Purpose | Typical consumers | Notes / aliases |
|----------|---------|-------------------|-----------------|
| `AGENT_TOOLKIT_ROOT` | Override toolkit data/checkout root | `_paths.py`, loops, data sync | Also accepts `AI_WORKSPACE` as alias (same tier) |
| `AI_WORKSPACE` | Alias for toolkit root override | `_paths.py`, loops | Same precedence tier as `AGENT_TOOLKIT_ROOT`; first non-empty wins in code order |
| `AGENT_TOOLKIT_WORKSPACE` | Workspace harness root | workspace/memory/project/devcompanion/loop | Alias: `HARNESS_DIR` |
| `HARNESS_DIR` | Alias for workspace root | `_paths.py`, loop | Same tier as `AGENT_TOOLKIT_WORKSPACE` |
| `AGENT_TOOLKIT_OFFLINE` | Disable network data refresh/download | install, update, `_paths`, data sync | Truthy: `1` / `true` / `yes` (case-insensitive) |
| `AGENT_TOOLKIT_INSTALL_SOURCE` | Force install channel/source | installer sources | Empty = auto |
| `AGENT_TOOLKIT_LOOP_RUNNER` | Default loop runner when `--runner` omitted | `loop` | e.g. `claude` |
| `AGENT_TOOLKIT_SWARM_RUN_ID` | Active swarm run id | swarm CLI / tmux env | Flag `--run-id` wins |
| `AGENT_TOOLKIT_SWARM_RUN_DIR` | Active swarm run directory | swarm CLI / tmux env | |
| `AGENT_TOOLKIT_SWARM_REPO` | Swarm target repo path | swarm CLI / tmux env | |
| `AGENT_TOOLKIT_SWARM_RUNS_DIR` | Override swarm runs directory | swarm config | |
| `XDG_CACHE_HOME` | Cache base for toolkit data cache | `_paths.py` / data cache | Standard XDG; default `~/.cache` |
| `HOME` | Home directory fallback | paths, XDG defaults | OS-provided |

Constant (not user config): `AGENT_TOOLKIT_REPO_URL` in source points at the canonical GitHub repo for gate messaging — not an override env var.

## Parity / test expectations

Parity harness ([#476](https://github.com/ulises-jeremias/agent-toolkit/issues/476) / [#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548)) must include fixtures that prove:

- Flag overrides env for the same knob
- Env overrides default when flag absent
- Offline mode never downloads
- Root/workspace aliases behave as documented

## Non-goals

- Inventing new `AGENT_TOOLKIT_*` names in this change
- Implementing V readers (EPIC 1+)

**Verified:** 2026-08-12
