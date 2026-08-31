<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-core

**Core AI agent capabilities** for any project — marketplace baseline plugin.

[![Agent Plugins](https://img.shields.io/badge/Agent%20Plugins-1.0-7c3aed?style=flat&labelColor=1f2937)](https://agent-plugins.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)

[Monorepo](https://github.com/ulises-jeremias/agent-toolkit) ·
[Marketplace](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/wiki/Plugin-Marketplace.md) ·
[Installation](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md)

</div>

---

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

```text
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
```

Or via the CLI (auto-detects supported tools):

```bash
npm i -g agent-toolkit-cli
# or: uv tool install agent-toolkit-cli
agent-toolkit install
```

→ [agent-toolkit-cli on npm](https://www.npmjs.com/package/agent-toolkit-cli) · [agent-toolkit-cli on PyPI](https://pypi.org/project/agent-toolkit-cli/)
