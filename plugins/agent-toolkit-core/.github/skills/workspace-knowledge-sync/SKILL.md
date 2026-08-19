---
name: workspace-knowledge-sync
description: Syncs knowledge to the agentic-harness knowledge base. Use when the assistant discovers new
  patterns, learns user preferences, records learned facts, or identifies information worth preserving
  for future sessions. Integrates with tech-assistant for automatic trigger points.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: continual-learning/skills/continual-learning
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Session memory loop — search before add, capture user-taught preferences as durable facts
---
# Workspace Knowledge Sync

Automatically syncs valuable discoveries, patterns, and decisions to the agentic-harness knowledge base.

## Purpose

The orchestrator session accumulates knowledge through work. This skill ensures that valuable discoveries don't get lost and are available for future sessions.

## Trigger Points (Automatic)

| Situation | What to Sync | Target File |
|-----------|--------------|-------------|
| Discovery of new skill/tool | Skill name, purpose, usage pattern | `knowledge/skills/discovered.md` |
| New process pattern | Process steps, roles, tools | `knowledge/processes/general.md` |
| Key decision made | Decision, rationale, outcome | `knowledge/learnings/general.md` |
| Pending follow-up | Task description, context | `knowledge/todos/pending.md` |
| User teaches something | Information, preference | Relevant knowledge file |

## Learned facts (continual learning)

Capture durable facts the user teaches during a session — preferences, conventions, IDs, and
"always do X" rules — so later sessions do not re-ask.

### When to record

- User says "remember", "always", "never", "we prefer", or corrects a repeated mistake.
- You discover a stable ID, path, or convention worth reusing across repos/engagements.
- Session ends with unresolved context that the next session should inherit.

### Workflow

1. **Search before add** — `assistant-memory search "<topic>"`
2. **Add with origin tracking**:

```bash
assistant-memory add --type learning --from-skill workspace-knowledge-sync \
  --tags preference "<fact; cite source path or ticket if relevant>"
assistant-memory add --type todo --from-skill workspace-knowledge-sync "<follow-up>"
```

### Guardrails

- **No secrets** — never store tokens, passwords, or private keys.
- **Be selective** — sync reusable facts, not transient debugging noise.
- **Do not mine transcripts** — record only what the current session explicitly learned.

## How It Works

```bash
assistant-memory search "<query>"
assistant-memory add --type learning --from-skill workspace-knowledge-sync "Pattern: <description>"
assistant-memory add --type skill --from-skill workspace-knowledge-sync --tags jira,workflow "New skill: <name>"
assistant-memory add --type todo --from-skill workspace-knowledge-sync "<description>"
```

## Integration with tech-assistant

1. After task creation/update → sync initiative info
2. After discovering space/list IDs → sync to knowledge base
3. After learning user preferences → sync learnings (learned facts workflow)
4. When user mentions follow-up → add to pending

Base directory: `~/.local/share/agent-toolkit/skills/workspace-knowledge-sync`
