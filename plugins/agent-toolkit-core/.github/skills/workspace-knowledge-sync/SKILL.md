---
name: workspace-knowledge-sync
description: Syncs knowledge to the agentic-harness knowledge base and AGENTS.md learned facts.
  Use when the assistant discovers new patterns, learns user preferences, workspace facts,
  or identifies information worth preserving for future sessions. Integrates with tech-assistant
  for automatic trigger points.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: continual-learning/skills/continual-learning
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Durable learned facts (user preferences / workspace facts), plain-bullet AGENTS.md
        sections, deduplication and 12-bullet cap; adapted without hooks/transcript mining to explicit sync
---

# Workspace Knowledge Sync

Automatically syncs valuable discoveries, patterns, and decisions to the agentic-harness knowledge base and durable `AGENTS.md` learned facts.

---

## Purpose

The orchestrator session accumulates knowledge through work. This skill ensures that valuable discoveries don't get lost and are available for future sessions — both in the workspace knowledge base (`knowledge/`) and as durable learned facts in `AGENTS.md`.

Inspired by `cursor/plugins` `continual-learning` (without hooks — no transcript mining or `stop` hook).

---

## Trigger Points (Automatic)

The tech-assistant will invoke this skill automatically when:

| Situation | What to Sync | Target |
|-----------|--------------|--------|
| Discovery of new skill/tool | Skill name, purpose, usage pattern | `knowledge/skills/discovered.md` |
| New process pattern | Process steps, roles, tools | `knowledge/processes/general.md` |
| Key decision made | Decision, rationale, outcome | `knowledge/learnings/general.md` |
| Pending follow-up | Task description, context | `knowledge/todos/pending.md` |
| User teaches something | Information, preference | Relevant knowledge file |
| Recurring user preference / correction | Plain bullet, durable preference | `AGENTS.md` → `## Learned User Preferences` |
| Stable workspace fact | Plain bullet, durable fact | `AGENTS.md` → `## Learned Workspace Facts` |

---

## How It Works

### Knowledge base (assistant-memory)

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

### Learned facts (AGENTS.md)

For durable, reusable facts that should survive across sessions, update `AGENTS.md` directly:

1. Read existing `AGENTS.md` first. If it does not exist, create it with only:
   - `## Learned User Preferences`
   - `## Learned Workspace Facts`
2. Pull out only durable, reusable items:
   - recurring user preferences or corrections
   - stable workspace facts
3. Update `AGENTS.md` carefully:
   - update matching bullets in place
   - add only net-new bullets
   - deduplicate semantically similar bullets
   - keep each learned section to at most 12 bullets
4. If the merge produces no `AGENTS.md` changes, leave `AGENTS.md` unchanged.

No hooks, no transcript index, no `followup_message` — the sync is explicit (manual or via tech-assistant trigger), not hook-driven.

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

AGENTS.md (workspace root)
├── ## Learned User Preferences   # max 12 plain bullets
└── ## Learned Workspace Facts    # max 12 plain bullets
```

---

## Learned Facts — Criteria and Guardrails

Inspired by `continual-learning` `agents-memory-updater` (adapted without transcript mining):

**Include only:**
- Recurring user preferences or corrections (e.g., "Always use feature branches", "Prefer pnpm over npm")
- Stable workspace facts (e.g., "Primary DB is Postgres 16 on host X", "Deploy via Vercel")

**Exclude:**
- Secrets, private data, tokens, credentials
- One-off instructions or transient details
- Evidence/confidence tags, process instructions, rationale blocks, or metadata

**Format:**
- Plain bullet points only (`- ...`)
- Keep only these sections: `## Learned User Preferences`, `## Learned Workspace Facts`
- No tables, no tags, no frontmatter in these sections

**Limits:**
- At most 12 bullets per section; deduplicate semantically similar bullets
- Update in place when a bullet already exists with similar meaning

---

## Manual Usage

You can also trigger this skill manually:

```
User: "Save that pattern for later"

Assistant: → Use knowledge-sync to preserve the pattern

User: "Remember I prefer pnpm and conventional commits"

Assistant: → Append to knowledge/learnings/general.md and AGENTS.md ## Learned User Preferences
```

---

## Integration with tech-assistant

The tech-assistant skill checks for these automatic sync opportunities:

1. **After task creation/update** → Sync initiative info
2. **After discovering space/list IDs** → Sync to knowledge base (per `knowledge-sync`).
3. **After learning user preferences** → Sync to learnings + `AGENTS.md` learned facts (if durable)
4. **When user mentions follow-up** → Add to pending
5. **After stable workspace facts emerge** → Sync to `AGENTS.md` `## Learned Workspace Facts`

---

## Best Practices

1. **Be selective** - Only sync valuable, reusable information
2. **Be specific** - Include context and usage examples
3. **Be concise** - One idea per entry, link to details
4. **Be current** - Update outdated information when found
5. **Be durable** - AGENTS.md facts must be reusable across sessions, not transient

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

### Learned fact — user preference

```
User repeatedly corrects: "use pnpm, not npm"
→ Assistant adds to AGENTS.md:
  ## Learned User Preferences
  - Use pnpm for JS package management
```

### Learned fact — workspace fact

```
Workspace uses Postgres 16 with vector extension on host db.internal
→ Assistant adds to AGENTS.md:
  ## Learned Workspace Facts
  - Postgres 16 with pgvector on db.internal
```

### Manual sync request

```
User: "Remember that we always use feature branches"
→ Assistant syncs to knowledge/processes/general.md and AGENTS.md ## Learned User Preferences
```

---

## Configuration

The skill uses these environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `KNOWLEDGE_BASE_PATH` | `~/.ai-workspace/knowledge` | Knowledge base root |

---

Base directory: `~/.local/share//skills/knowledge-sync`
