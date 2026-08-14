---
name: swarm
description: Launch an Agent Toolkit swarm from a natural language request using agent-toolkit swarm CLI
  with Herdr/tmux eager windows and file handoffs.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - swarm
  - herdr
  - tmux
  - orchestration
  - multi-agent
---
# Swarm

Launch a production Agent Toolkit swarm from any natural language request via the `agent-toolkit swarm` CLI. Herdr is the default UI for an excellent interactive experience; tmux is the isolated fallback.

## When to use

- User says "launch a swarm", "start a swarm", "swarm this task", or describes parallel/team work that benefits from multiple agents.
- Any task that mentions swarm, pair/team/full, Herdr, tmux, or worktree-per-writer.
- User wants to reuse an existing swarm run for a new request (same windows, new handoff).

## Prerequisites

- `agent-toolkit` installed and on PATH (`agent-toolkit swarm doctor` should pass).
- For Herdr: `herdr` CLI installed (`herdr --version`); Herdr daemon running.
- For tmux: `tmux` installed; isolated socket is `agent-toolkit-swarm-<run-id>`.
- Run inside a Git repo (or pass `--workspace /path/to/repo`).
- Optional: `~/.config/agent-toolkit/swarm.yaml` for model-profile mapping (`economy` → `opencode/mimo-v2.5-free`, `balanced` → provider default).

## Workflow

### 1. Inspect intent

Extract from the user prompt:
- **Task**: free-form objective (if missing, start swarm ready for interactive input).
- **Recipe**: `pair` (2 roles: implementer→reviewer, fast), `team` (implementer→reviewer→integrator), `full` (large, 5+ roles). Default `pair` unless task needs more.
- **Runner**: `opencode` (default, free models) or `claude` (Anthropic). Respect `--runner` if user names it.
- **Model profile**: `economy` (`opencode/mimo-v2.5-free`) or `balanced` (provider default). Default `balanced`.
- **UI**: `herdr` (default) or `tmux` (isolated). Respect `--ui` if given.

### 2. Check health

```bash
agent-toolkit swarm doctor
agent-toolkit swarm recipes
```

If doctor fails, report diagnostics and fix `herdr`/`tmux`/runner availability before launching.

### 3. Launch

Always use the CLI; never fabricate `state.json` or backend state.

```bash
# Herdr (preferred) — eager windows, shell-aware (detects $SHELL/zsh), attach by default
agent-toolkit swarm start --recipe pair --ui herdr --runner opencode --model-profile balanced --attach "task"

# Tmux (fallback) — isolated socket
agent-toolkit swarm start --recipe team --ui tmux --runner claude --model-profile economy --attach "task"

# Headless / no prompt — starts swarm ready, no initial task
agent-toolkit swarm start --recipe pair --ui herdr --runner opencode --model-profile balanced --attach

# Reuse same run/windows for a new request
agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact "artifacts/new-task.md" --run-id <run-id>
```

Flags: `--json` for machine output, `--no-attach` for CI/script mode, `--workspace / -C <path>` to target a different repo.

Eager UX (automatic):
- Every role gets a window/tab immediately with `Waiting for handoff: <pred> -> <role> | role: <role> | run: <run_id>` and `agent_waiting` trace.
- Implementer is focused on start; agents start lazily on handoff/file trigger.
- Shell is detected (`$SHELL` → `pwd.getpwuid` → `/usr/bin/zsh` fallback); commands run as `<shell> -lc`.

### 4. Monitor and handoff

```bash
agent-toolkit swarm status --run-id <run-id>
agent-toolkit swarm handoffs --run-id <run-id>
agent-toolkit swarm logs --run-id <run-id> --follow
agent-toolkit swarm task next --role reviewer --run-id <run-id>
agent-toolkit swarm task complete --run-id <run-id> --task-id <id>
agent-toolkit swarm attach --run-id <run-id>
```

File handoff: `artifacts/` → `handoff create --type artifact --from X --to Y --artifact <path>`. When `handoff create` targets an `active` handoff's `to == from_role`, that handoff auto-completes (`auto:true`) and the next agent is provisioned with its worktree/tab.

### 5. Reuse windows

Same run can handle sequential requests: send a new artifact handoff to the implementer; the chain re-triggers. Only create a new run when isolated branch/worktree is needed.

## Boundaries

- Never write ` .agent-toolkit/swarm/runs/<run-id>/state.json` or `herdr`/`tmux` state by hand; the CLI owns it.
- For large outputs, keep details in the skill; do not dump full `state.json` in chat unless asked.

## Delegates to

| Need | Skill |
|------|-------|
| Push and create PR with swarm output | `github-cli-workflow` |
| Confirm output destination | `output-handshake` |
| Repo discovery | `assistant` |
