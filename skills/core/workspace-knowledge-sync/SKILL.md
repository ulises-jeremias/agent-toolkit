---
name: workspace-knowledge-sync
description: Syncs knowledge to the ai-workspace knowledge base. Use when the assistant discovers new
  patterns, learns user preferences, or identifies information worth preserving for future sessions. Integrates
  with tech-assistant for automatic trigger points.
origin:
  type: first-party
---
# Workspace Knowledge Sync

Automatically syncs valuable discoveries, patterns, and decisions to the ai-workspace knowledge base.

---

## Purpose

The orchestrator session accumulates knowledge through work. This skill ensures that valuable discoveries don't get lost and are available for future sessions.

---

## Trigger Points (Automatic)

The tech-assistant will invoke this skill automatically when:

| Situation | What to Sync | Target File |
|-----------|--------------|-------------|
| Discovery of new skill/tool | Skill name, purpose, usage pattern | `knowledge/skills/discovered.md` |
| New process pattern | Process steps, roles, tools | `knowledge/processes/general.md` |
| Key decision made | Decision, rationale, outcome | `knowledge/learnings/general.md` |
| Pending follow-up | Task description, context | `knowledge/todos/pending.md` |
| User teaches something | Information, preference | Relevant knowledge file |

---

## How It Works

The skill uses the stable `assistant-memory` API with `--from-skill` for origin tracking:

```bash
# Search before adding
assistant-memory search "<query>"

# Add a learning (with origin tracking)
assistant-memory add --type learning --from-skill knowledge-sync "Pattern: <description>"

# Add a skill (with tags)
assistant-memory add --type skill --from-skill knowledge-sync --tags jira,workflow "New skill: <name>"

# Add a pending todo
assistant-memory add --type todo --from-skill knowledge-sync "<description>"
```

---

## Knowledge Structure

```
knowledge/
├── skills/
│   └── discovered.md      # New skills found during work
├── processes/
│   ├── jira.md
│   ├── confluence.md
│   └── general.md        # Generic process patterns
├── learnings/
│   └── general.md        # Key decisions and insights
└── todos/
    └── pending.md        # Follow-up items
```

---

## Manual Usage

You can also trigger this skill manually:

```
User: "Save that pattern for later"

Assistant: → Use knowledge-sync to preserve the pattern
```

---

## Integration with tech-assistant

The tech-assistant skill checks for these automatic sync opportunities:

1. **After task creation/update** → Sync initiative info
2. **After discovering space/list IDs** → Sync to knowledge base (per `knowledge-sync`).
3. **After learning user preferences** → Sync to learnings
4. **When user mentions follow-up** → Add to pending

---

## Best Practices

1. **Be selective** - Only sync valuable, reusable information
2. **Be specific** - Include context and usage examples
3. **Be concise** - One idea per entry, link to details
4. **Be current** - Update outdated information when found

---

## Examples

### Auto-sync discovery

```
Assistant discovers Initiative list IDs for all Technology spaces
→ Syncs to knowledge/processes/clickup/spaces/
```

### Auto-sync key decision

```
Assistant and user decide on naming convention
→ Syncs to knowledge/learnings/general.md
```

### Manual sync request

```
User: "Remember that we always use feature branches"
→ Assistant syncs to knowledge/processes/general.md
```

---

## Configuration

The skill uses these environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `KNOWLEDGE_BASE_PATH` | `~/ai-workspace/knowledge` | Knowledge base root |

---

Base directory: `~/.local/share//skills/knowledge-sync`
