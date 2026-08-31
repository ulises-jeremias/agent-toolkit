# V `workspace` command family

**Issue:** [#520](https://github.com/ulises-jeremias/agent-toolkit/issues/520) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **PORT**)

Harness overlay matching Python `cli/workspace.py` (**PORT**, [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560)):

- `init [--dir PATH] [--name NAME]` — scaffold AGENTS.md, knowledge/, personas/, packs/, projects/, repos/ (skip existing files)
- `context [--workspace PATH] [--explain] [--json]` — session snapshot; JSON data includes `workspace`/`timestamp`/`spec`
- `sync [--workspace PATH]` — append loop escalations into `knowledge/todos/pending.md` (idempotent)
- Persona/pack extras: `use-persona`, `handoff`, `history`, `personas`, `load`, `profiles`, `validate`, `budget`

Discovery order (#207): `--workspace` → `AGENT_TOOLKIT_WORKSPACE` → `HARNESS_DIR` → walk-up for `AGENTS.md` or `knowledge/`. No tmux/Herdr.
