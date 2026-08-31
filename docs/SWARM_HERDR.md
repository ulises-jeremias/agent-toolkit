# Swarm + Herdr

Herdr is the recommended UI, not the engine.

## Install Herdr

```bash
# Homebrew
brew install herdr

# Or official installer
curl -fsSL https://herdr.dev/install.sh | sh

# Verify
herdr --version
herdr workspace create --help
```

Via agentic-workstation: `agent_swarms.enabled=true` installs Herdr automatically.

## Integration

```bash
herdr integration install opencode
herdr integration list --json
agent-toolkit swarm doctor --json
```

Doctor reports: `herdr available`, `version`, `opencode integration installed/outdated`.

## Backend Responsibilities

- Herdr may: create workspace, worktree, tabs/panes, name agents, start/prompt/wait/read/focus/attach/stop, JSON output.
- Herdr must not: own recipe semantics, task queues, handoff validation, budgets, Git, completion decisions.

## CLI-First

```bash
herdr workspace create --cwd PATH --label LABEL --no-focus --json
herdr agent start NAME --kind opencode --pane PANE_ID --json
herdr agent prompt NAME "..." --wait --json
herdr agent wait NAME --until idle --json
herdr agent read NAME --source recent --json
```

Parse JSON, never ANSI scraping. Socket API only for persistent events.

## Degradation

- `--ui auto`: herdr unavailable → fallback to tmux if available, else error with guidance, no headless unless explicitly allowed.
- `--ui herdr`: herdr missing → error, do not silently use tmux.

```
Herdr was explicitly requested but was not found.

Install:
  https://herdr.dev/docs/install/

Or use:
  agent-toolkit swarm start --ui tmux ...
```

## Plugin

Thin Herdr plugin at `integrations/herdr/agent-toolkit-swarm/`:

- `herdr-plugin.toml` with `min_herdr_version`
- Actions: Start Pair/Team/Full Swarm, Open Status, Open Handoff Queue, Open Final Report, Pause/Resume/Stop/Clean Up
- No orchestration logic; actions invoke `agent-toolkit swarm`

Local dev: `herdr plugin link ./integrations/herdr/agent-toolkit-swarm`  
Install: `herdr plugin install ulises-jeremias/agent-toolkit/integrations/herdr/agent-toolkit-swarm`

Trust: inspect third-party plugins per Herdr docs.

## Attach

```bash
agent-toolkit swarm attach RUN_ID
# or directly:
herdr workspace open swarm-RUN_ID
```

## tmux Fallback & Parity

`--ui auto` falls back Herdr → tmux ([SWARM_TMUX.md](SWARM_TMUX.md)) when Herdr is absent; `--ui tmux` bypasses Herdr entirely and works over SSH/headless. Both share the `SwarmUIBackend` interface and identical filesystem semantics (`state.json`, `handoffs/`, budgets, worktrees). Use `swarm start --runner skeleton --ui tmux` for fully offline demo without Herdr or LLM.

## Privacy & Cleanup

No cloud/telemetry; logs are local. Herdr workspaces/tabs are removed by `swarm stop`/`swarm cleanup` only for Toolkit-owned runs; worktrees obey the same dirty/branch preservation as tmux.

## Extension & Related

Recipes in [SWARM_RECIPES.md](SWARM_RECIPES.md) declare `ui: auto|herdr|tmux` but runtime `--ui` overrides; model profiles in [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) work with any runner. See [SWARMS.md](SWARMS.md) (overview), [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (Mermaid: ecosystem, runtime layers, adapter separation), [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md), [SWARM_SECURITY.md](SWARM_SECURITY.md), [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md).
