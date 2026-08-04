<!-- generated-by: agent-toolkit workspace init -->
# AGENTS.md — AI Workspace Orchestrator

**Purpose**: Stateless session that orchestrates multi-repository work across any project or team.

**Language**: Match the user's language for conversation → English for commits, PRs, tickets, docs.

---

## Work Context

- **Repos**: `./projects/` symlinks (quick access) · `./repos/` cloned on-demand
- **Knowledge**: `./knowledge/` — persistent memory across sessions
- **Personas**: `./personas/` — focused work modes with behavioral constraints
- **Packs**: `./packs/` — context bundles for switching between clients/projects

---

## agent-toolkit CLI

```bash
# Session start
agent-toolkit workspace context    # inject workspace state
agent-toolkit memory inject        # load all persistent knowledge
agent-toolkit memory todo          # review pending follow-ups

# During session
agent-toolkit memory search "topic"                      # before asking known questions
agent-toolkit memory add --type learning "pattern found" # save discoveries
agent-toolkit memory add --type todo "follow-up item"    # track follow-ups

# Async work
agent-toolkit loop run <name>                       # run a loop template
agent-toolkit devcompanion queue <project> --request "..." # background job
agent-toolkit devcompanion status                   # check queue

# Projects
agent-toolkit project clone owner/repo             # clone + symlink
agent-toolkit project list                         # list indexed projects
```

---

## Operating Rules

**Always:**
- Run `agent-toolkit workspace context` at session start
- Run `agent-toolkit memory search` before asking questions answered before
- Save discoveries after every session: `agent-toolkit memory add`
- For delivery: follow plan → implement → review → PR phases

**Never:**
- Assume we are inside a repo without verifying
- Commit without code review
- Skip the plan phase for non-trivial work

---

## Routing

| Task type | Delegate to |
|-----------|-------------|
| Discovery / first look at a repo | `assistant` skill |
| Generic delivery workflow | `workflow-generic-project` skill |
| Code review / refactor | `code-reviewer` / `refactor-cleaner` agents |
| Background async work | `agent-toolkit devcompanion queue` |
| Recurring automation | `agent-toolkit loop run` |

---

## Portability

| AI Tool | Config read |
|---------|-------------|
| Claude Code | `AGENTS.md` |
| Cursor / OpenCode / Windsurf | `CLAUDE.md` → symlink to `AGENTS.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |

---

> Customize this file to reflect your team's skills, routing, and conventions.
> See [agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit) for the full toolkit.
