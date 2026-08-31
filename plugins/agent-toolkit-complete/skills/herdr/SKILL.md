---
name: herdr
description: Manage Herdr workspaces, tabs, and panes for Agent Toolkit swarms with eager windows, shell-aware
  execution, and reuse.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - herdr
  - swarm
  - workspace
  - tmux
  - orchestration
---
# Herdr

Operate Herdr as the primary UI for `agent-toolkit swarm` — eager tabs, shell-consistent execution (`zsh`/`bash` via `_user_shell()`), and clean reuse of windows. This skill is the Herdr complement to `swarm` and `swarm-observer`.

## When to use

- Swarm was started with `--ui herdr` (default) and you need to inspect or recover Herdr state.
- `herdr workspace list/create/tab create/pane run` behavior is unexpected (extra workspaces `w7-wA` for `headless`, wrong `--cwd`, or missing eager windows).
- User prefers Herdr over tmux for its excellent interactive UX and wants to reuse tabs for sequential requests.

## Prerequisites

- `herdr` CLI installed and daemon running (`herdr --version`, `herdr workspace list --json` works; `--json` may be unsupported on older binaries — fallback to text).
- Swarm run exists: `.agent-toolkit/swarm/runs/<run-id>/state.json` with `ui: herdr`.
- Repo is a Git directory (worktrees are created under `.agent-toolkit/swarm/runs/<run-id>/worktrees/`).

## Workflow

### 1. Verify backend and shell

```bash
agent-toolkit swarm doctor --json | jq '.backends'
herdr --version
echo $SHELL; getent passwd $USER | cut -d: -f7  # should be /usr/bin/zsh on this host
# swarm's _user_shell() picks: $SHELL -> pwd.getpwuid -> /usr/bin/zsh -> /bin/bash
```

### 2. Inspect Herdr state for a run

```bash
herdr workspace list --json 2>&1 | jq '.[] | {id,name,path,status}' | head -n 40
# Expected: one workspace per run: swarm-20260807T...-<short>
# Orphan check: workspaces w7-wA with headless run-id -> delete after fixing backend

agent-toolkit swarm status --run-id <run-id> --json | jq '{ui,recipe,runner,model_profile,worktrees,handoffs}'
agent-toolkit swarm handoffs --run-id <run-id> --json | jq
herdr workspace list | grep swarm-<run-id>
```

### 3. Eager windows (automatic on swarm start)

On `swarm start --ui herdr`, swarm creates **one tab per role** immediately:

- `tab create --workspace swarm-<run-id> --name <role>` for each role (`implementer`, `reviewer`, `integrator`, ... plus `1` for coordinator).
- Each non-implementer tab runs: `echo "Waiting for handoff: <pred> -> <role> | role: <role> | run: <run-id>"` via `<shell> -lc` (quoted to avoid `| pipe` issues) and records `agent_waiting` trace.
- `select-window` / `workspace focus` focuses `implementer`; implementer pane runs `export AGENT_TOOLKIT_SWARM_RUN_ID=... RUN_DIR=... REPO=... SWARMFORGE_ROLE=implementer && cd <worktree> && exec <runner> "$(cat prompt)"`.

If a tab is missing:

```bash
herdr tab create --workspace swarm-<run-id> --name reviewer --json 2>&1 | jq
herdr pane run --workspace swarm-<run-id> --tab reviewer --command "/usr/bin/zsh -lc 'echo \"Waiting for handoff: implementer -> reviewer | role: reviewer | run: <run-id>\"'" --json 2>&1 | jq
```

### 4. Recover from known pitfalls

| Symptom | Fix |
|---------|-----|
| Extra workspaces for `headless` runs | `get_backend("headless")` fallback created spurious Herdr workspaces. Patch `swarm/backends/__init__.py` to return headless/noop backend; then `herdr workspace delete <id>` for orphans. |
| `--cwd` wrong (repo not found) | Ensure `herdr workspace create --cwd <repo-root>` uses `find_repo_root` result, not `cwd` when run from worktree. |
| `pane run` fails with `pipe` | Swarm fixed by quoting waiting message: `echo "Waiting..."` not `echo Waiting ... |` |
| Shell mismatch (`bash` vs `zsh`) | Swarm now uses `_user_shell()`; verify Herdr panes inherit `$SHELL`. `herdr pane run --command "/usr/bin/zsh -lc 'echo \$SHELL'"` |

### 5. Reuse tabs for new requests

Do not delete the workspace between tasks. Reuse the same `run-id`:

```bash
agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact artifacts/next-task.md --run-id <run-id>
# Herdr tabs stay; only the handoff chain retriggers. New run only for isolated branch.
```

Attach when needed:

```bash
agent-toolkit swarm attach --run-id <run-id>
herdr workspace focus --workspace swarm-<run-id>
```

## Boundaries

- Never write Herdr's workspace DB directly; use `herdr workspace/tab/pane` CLI via swarm's `HerdrBackend`.
- Never mix Herdr and tmux sockets — swarm uses `herdr` OR isolated `tmux -L agent-toolkit-swarm-<run-id>`, never both for one run.
- Do not run `herdr workspace open` (removed); use `workspace focus` / `workspace list`.

## Delegates to

| Need | Skill |
|------|-------|
| Launch or reuse a swarm | `swarm` |
| Diagnose stuck handoffs/logs | `swarm-observer` |
| Create file handoffs | `swarm-handoff` |
| Isolated fallback when Herdr unavailable | `tmux` (via `swarm --ui tmux`) |
