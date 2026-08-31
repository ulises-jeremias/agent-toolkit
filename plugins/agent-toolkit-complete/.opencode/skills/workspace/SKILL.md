---
name: workspace
description: Scaffold and manage the stateless AI workspace — context, packs, repos, and knowledge for
  multi-repo orchestration.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - workspace
  - packs
  - context
  - multi-repo
  - orchestration
---
# Workspace

Initialize and operate the **stateless AI workspace** (`~/.ai-workspace`) that orchestrates work across any repo, team, or client via `agent-toolkit workspace` and `agent-toolkit memory`. This is the entry point for multi-repo delivery; all swarm and project work runs inside it.

## When to use

- Starting a new session (`agent-toolkit workspace context` + `agent-toolkit memory inject` + `agent-toolkit memory todo` — the session start protocol per `AGENTS.md`).
- User needs to switch client/project context via packs (`packs/*.yaml`).
- Workspace health check, pack load, or knowledge sync is needed.

## Prerequisites

- `agent-toolkit` installed (`agent-toolkit workspace --help` works).
- Workspace at `~/.ai-workspace` (or `$WORKSPACE_ROOT`) with `repos/`, `projects/` symlinks, `knowledge/`, `personas/`, `packs/`.

## Workflow

### 1. Session start protocol (always)

```bash
agent-toolkit workspace context          # inject session state (repos, packs, personas)
agent-toolkit memory inject              # load persistent knowledge
agent-toolkit memory todo                # show pending follow-ups
# Optional: load a pack
agent-toolkit workspace load packs/<client>.yaml
```

Per `AGENTS.md`: check `knowledge/` before asking a question already answered; run discovery before large edits; follow plan → implement → review → PR.

### 2. Inspect and switch context

```bash
agent-toolkit workspace context --json | jq
ls ~/.ai-workspace/projects  # symlinks to active repos
ls ~/.ai-workspace/packs
cat ~/.ai-workspace/AGENTS.md  # portable contract (primary), plus CLAUDE.md/GEMINI.md symlinks
```

Packs bundle client/project context:

```bash
agent-toolkit workspace load packs/my-client.yaml  # sets env, LLM policy, registry
# Verify LLM policy before queuing devcompanion jobs (esp. for client engagements)
dots-devcompanion llm-status  # or agent-toolkit devcompanion status
```

### 3. Knowledge lifecycle

```bash
agent-toolkit memory search "topic"           # find existing knowledge
agent-toolkit memory add --type learning "pattern"  # save after discovering
agent-toolkit memory add --type todo "follow-up"    # track
agent-toolkit memory todo                    # review before closing session
```

Knowledge is project-aware; `memory inject` surfaces prior learnings for the current repo.

### 4. Personas and routing

Per `AGENTS.md` routing table:

| Task | Delegate |
|------|----------|
| Discovery / first repo look | `assistant` skill |
| Generic delivery | `workflow-generic-project` |
| UI/UX | `figma` / `figma-implement-design` |
| JIRA / Confluence / ClickUp | `jira-assistant` / `confluence-assistant` / `clickup-cli` |
| Swarm orchestration | `swarm`, `swarm-observer`, `swarm-handoff` |
| Herdr/tmux backend | `herdr`, `worktree` |

Personas (`personas/*.md`: implementer, reviewer, researcher, architect) constrain toolset when `use-persona` is active — respect `allow/deny` and handoff.

## Boundaries

- Never `cd && command` to change repo context — use `workdir` or `--workspace`/`-C`.
- Never commit without code review; never skip plan phase for non-trivial work.
- Do not assume we are inside a repo — verify with `workspace context` first.

## Delegates to

| Need | Skill |
|------|-------|
| Repo discovery and conventions | `assistant` |
| Multi-repo clone and sync | `project` |
| Swarm delivery | `swarm` |
| Knowledge persistence | `workspace-knowledge-sync` |
| Generic delivery workflow | `workflow-generic-project` |
