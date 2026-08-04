# agent-toolkit-core

Core AI agent capabilities for any project.

## What's included

**Skills:**
- `assistant` — Primary orchestrator: repo inspection, routing, convention verification
- `dev-companion` — Dev workflow companion (WHAT phases, gates, decisions)
- `output-handshake` — Artifact gate: confirms destination before final output
- `pr-fallback` — PR body generator when no project template exists
- `workspace-knowledge-sync` — Sync workspace knowledge and todos
- `onboarding` — Guided project onboarding for new team members

**Agents:**
- `code-reviewer` — Expert code review for quality, security, maintainability

## Install

```
/plugin install agent-toolkit-core@agent-toolkit
```

Or add the marketplace first:
```
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
```
