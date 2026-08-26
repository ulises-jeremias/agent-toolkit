# Cursor Profile

Files in this directory configure [Cursor](https://cursor.com) for use with agent-toolkit.

## Structure

```
profiles/cursor/
├── rules/               # Per-agent .mdc rule files (18 canonical — #865)
│   ├── agentic-security-reviewer.mdc
│   ├── architect.mdc
│   ├── assistant.mdc
│   ├── build-error-resolver.mdc
│   ├── client-workflow-bootstrap.mdc
│   ├── code-reviewer.mdc
│   ├── data-engineer.mdc
│   ├── designer.mdc
│   ├── e2e-runner.mdc
│   ├── implementer.mdc
│   ├── planner.mdc
│   ├── platform-engineer.mdc
│   ├── qa-engineer.mdc
│   ├── researcher.mdc
│   ├── reviewer.mdc
│   ├── security-engineer.mdc
│   ├── security-reviewer.mdc
│   └── tdd-guide.mdc
├── README.md
└── .cursor-plugin/
    └── plugin.json      # Agent Plugins 1.0 manifest (Cursor marketplace)
```

## Rule Format

Cursor uses `.mdc` files with YAML frontmatter:

```
---
description: Software architecture and system design guidance.
alwaysApply: false
---

# Architecture Guidelines
...
```

- `description`: when the rule applies (used by Cursor for auto-apply)
- `alwaysApply: false`: rule is applied on demand, not for every request

## Installation

```bash
# Via agent-toolkit CLI (recommended)
agent-toolkit install --tools cursor

# Manual — global (all projects)
mkdir -p ~/.cursor/rules
cp profiles/cursor/rules/*.mdc ~/.cursor/rules/

# Manual — project only
mkdir -p .cursor/rules
cp profiles/cursor/rules/*.mdc .cursor/rules/

# Single agent
cp profiles/cursor/rules/code-reviewer.mdc .cursor/rules/
```

Alternatively, paste `.mdc` contents into **Cursor Settings → Rules for AI**.

## Customization

Create additional `.mdc` files in `.cursor/rules/` for project-specific conventions. Cursor merges all rules. Use a unique prefix to avoid collisions (e.g., `myproject-conventions.mdc`).

## Plugin Manifest

`agent-toolkit-cursor` is published to the Cursor marketplace via `.cursor-plugin/plugin.json` (Agent Plugins 1.0 schema). See `docs/PROFILES.md` for details.

## References

- [Cursor Rules](https://docs.cursor.com/context/rules)
- [Agent Plugins spec](https://agent-plugins.org)
- `docs/PROFILES.md` (Cursor section) — note: current docs list per-domain files but actual profile is per-agent (see #788)
