---
name: swarm-observer
description: Observe, diagnose, and recover Agent Toolkit swarm runs via status, handoffs, logs, and attach
  with worktree and shell awareness.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - swarm
  - observer
  - herdr
  - tmux
  - handoff
  - worktree
---
# Swarm Observer

Monitor any `agent-toolkit swarm` run, diagnose stuck handoffs or backend drift, and recover without losing windows. Works for both **Herdr** (tabs) and **tmux** (isolated socket `agent-toolkit-swarm-<run-id>`). Integrates with swarm's eager-window model (every role starts as `Waiting for handoff: <pred> -> <role>` with `agent_waiting` trace).

## When to use

- A swarm was launched and the user asks "is it done?", "what's the status?", "show logs", or "attach".
- A handoff has been `active` for >5m (`955be6f6e2c...` pattern) or `worktree_failed`.
- Herdr shows extra workspaces (`w7-wA`) for `headless` runs — the `get_backend("headless")` fallback case.
- User wants to reuse the same run for a new request and needs to know if windows are still alive.

## Prerequisites

- Run lives under `.agent-toolkit/swarm/runs/<run-id>/state.json` (filesystem is authoritative).
- Know `run-id` (`20260807T...-xxxxxx`) from `swarm start --json` or `swarm list --json`.
- Shell is detected (`_user_shell()`: `$SHELL` → `pwd.getpwuid` → `/usr/bin/zsh` fallback, executed as `<shell> -lc`).

## Workflow

### 1. List and pick the run

```bash
agent-toolkit swarm list --json | jq
agent-toolkit swarm status --run-id <run-id>
agent-toolkit swarm status --run-id <run-id> --json | jq '.handoffs,.worktrees,.trace'
```

### 2. Inspect handoffs and trace

```bash
agent-toolkit swarm handoffs --run-id <run-id>
agent-toolkit swarm handoffs --run-id <run-id> --json | jq '.[] | {id,from,to,status,artifact,auto}'
# Active that should have auto-completed:
#   where to==from_role and handoff create --to == that role -> auto:true
```

Trace keys to watch: `agent_waiting`, `handoff_completed auto:true`, `worktree_failed`, `headless_fallback`.

### 3. Tail logs and attach

```bash
agent-toolkit swarm logs --run-id <run-id> --follow
agent-toolkit swarm logs --run-id <run-id> --role reviewer --follow
agent-toolkit swarm attach --run-id <run-id>          # herdr: workspace focus; tmux: attach -L agent-toolkit-swarm-<run-id>
herdr workspace list --json 2>&1 | jq '.[] | {id,name,status}'
tmux -L agent-toolkit-swarm-<run-id> capture-pane -t <window> -p | tail -n 80
```

### 4. Diagnose

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Waiting for handoff: a -> b | role: b` stuck >5m | `active` handoff never `task complete` | `agent-toolkit swarm task next --role b --run-id <run-id>` then `task complete --task-id <id>` or `handoff create --from a --to b ...` which auto-completes `active where to==a` |
| `worktree_failed` | `find_repo_root` failed (`git rev-parse --git-common-dir` on `.git` file) | Re-run `handoff create` — fixed via `AGENT_TOOLKIT_SWARM_RUN_ID` export + path extract |
| Extra Herdr workspaces `w7-wA` with `headless` | `get_backend("headless")` returned `HerdrBackend` | Patch `backends/__init__.py` to return headless/noop backend; then `herdr workspace delete <id>` for orphans |
| Shell shows `bash` while user uses `zsh` | Hardcoded `bash -lc` | Fixed via `_user_shell()` / `_shell_base()` — verify `ps -o comm= -p <pid>` shows `zsh` |

### 5. Recover or reuse

```bash
# Complete stuck handoff and provision next role (worktree/tab + agent start)
agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact artifacts/fix.md --run-id <run-id>

# Reuse same windows for a new request (no new run needed)
agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact artifacts/new-task.md --run-id <run-id>
# Chain re-triggers: implementer -> reviewer -> integrator via file handoffs

# Only create a new run when isolated branch is required
agent-toolkit swarm start --recipe pair --ui herdr --runner opencode --model-profile balanced --attach "new isolated task"
```

## Boundaries

- Never edit `.agent-toolkit/swarm/runs/<run-id>/state.json` by hand; use `handoff create` / `task complete` / `promote`.
- Never create new Herdr workspaces for `headless` — fix the backend fallback instead.
- For tmux, always use isolated socket `-L agent-toolkit-swarm-<run-id>`; never the default server.

## Delegates to

| Need | Skill/Command |
|------|---------------|
| Show failure snippet before fixing | `swarm-handoff` |
| Recreate worktree | `agent-toolkit swarm handoff create` (auto-provisions) |
| Review code produced by swarm | `code-reviewer`, `security-reviewer` |
| Create PR after promotion | `github-cli-workflow` |
