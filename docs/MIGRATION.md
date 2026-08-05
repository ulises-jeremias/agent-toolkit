# Migration Guide

## From profile-copy install to native compiler

Before v1.2.0, `agent-toolkit install` copied files directly to home directories
(e.g., `~/.claude/CLAUDE.md`, `~/.cursor/rules/*.mdc`).

From v1.2.0 onwards, the canonical compiler generates native plugin bundles
which are the preferred distribution method.

### Option 1: Keep profile-based install (backward compatible)

```bash
# Still works — copies profiles to tool directories
agent-toolkit install --tools claude-code,cursor
```

Profile-based install is maintained for tools that don't support the marketplace
(Windsurf, Pi companion assets) and for development/quick setup.

### Option 2: Use native plugin bundles (recommended for Claude Code, Cursor)

**Claude Code:**
```
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
```

**Cursor:**
Import via Dashboard → Plugins → `ulises-jeremias/agent-toolkit`

### Detecting old installations

```bash
agent-toolkit doctor
# Shows: which profiles are installed, which tools are detected
```

### Migrating from old skill.json files

`skill.json` files were removed in v1.0.4. If you have custom skills with
`skill.json`, remove them — only `SKILL.md` frontmatter is needed per the
Agent Skills spec.

```bash
# Find old skill.json files
find . -name "skill.json" -path "*/skills/*"
# Remove them
find . -name "skill.json" -path "*/skills/*" -delete
```

### Migrating from agentic-workstation profile sync

If you previously used `dots-skills sync` from agentic-workstation,
replace with:

```bash
# Install via marketplace (preferred)
/plugin marketplace add ulises-jeremias/agent-toolkit

# Or install profiles directly
agent-toolkit install
```

The `dots-workstation-*` prefixed files in `~/.claude/skills/` and
`~/.cursor/rules/` will be cleaned up automatically when agentic-workstation
is updated to use agent-toolkit (via `.chezmoiremove`).
