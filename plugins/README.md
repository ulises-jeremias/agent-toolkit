# Plugins

This directory contains the marketplace plugin bundles for Claude Code and Cursor.

## Plugins

| Plugin | What's included | Install command |
|--------|----------------|----------------|
| `agent-toolkit-core` | Core skills + code-reviewer agent | `/plugin install agent-toolkit-core@agent-toolkit` |
| `agent-toolkit-agents` | All 16 agent personas | `/plugin install agent-toolkit-agents@agent-toolkit` |
| `agent-toolkit-forge` | GitHub/GitLab automation skills | `/plugin install agent-toolkit-forge@agent-toolkit` |

## Adding the marketplace

**Claude Code:**
```
/plugin marketplace add ulises-jeremias/agent-toolkit
```

**Cursor:** Import `https://github.com/ulises-jeremias/agent-toolkit` via Dashboard → Plugins.

## Structure

Each plugin contains:
```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json     ← Claude Code marketplace metadata
├── .cursor-plugin/
│   └── plugin.json     ← Cursor marketplace metadata
├── README.md
├── skills/             ← Bundled skill copies (auto-synced from skills/)
└── agents/             ← Bundled agent copies (auto-synced from agents/)
```

Plugins are kept in sync with canonical sources via `scripts/gen-surfaces.py`.
Never edit plugin bundles directly — edit the canonical source and re-run gen-surfaces.
