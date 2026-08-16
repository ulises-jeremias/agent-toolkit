<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-agents

**Full set of AI agent personas** for specialized tasks.

[![Agent Plugins](https://img.shields.io/badge/Agent%20Plugins-1.0-7c3aed?style=flat&labelColor=1f2937)](https://agent-plugins.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
![personas](https://img.shields.io/badge/personas-16-0891b2?style=flat&labelColor=1f2937)

[Monorepo](https://github.com/ulises-jeremias/agent-toolkit) ·
[Marketplace](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/wiki/Plugin-Marketplace.md) ·
[Installation](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md)

</div>

---

## Agents included (16)

Disk has **17** personas; `agentic-security-reviewer` is not in this plugin (see `agent-toolkit-complete` / the security pack).

| Agent | Role |
|-------|------|
| `architect` | System design, patterns, trade-offs |
| `assistant` | Primary orchestrator and fallback |
| `build-error-resolver` | TypeScript and build error specialist |
| `client-workflow-bootstrap` | Client onboarding |
| `code-reviewer` | Quality, security, maintainability review |
| `database-reviewer` | PostgreSQL and database specialist |
| `docs-lookup` | Framework docs and API reference |
| `e2e-runner` | Playwright E2E testing |
| `performance-optimizer` | Speed and memory profiling |
| `planner` | Complex feature planning |
| `refactor-cleaner` | Dead code and refactoring |
| `reference-lookup` | Pattern lookup and examples |
| `security-reviewer` | Vulnerability detection |
| `tdd-guide` | Test-driven development |
| `tech-assistant` | Technical operations |
| `typescript-reviewer` | TypeScript and JavaScript specialist |

## Install

```text
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
```

Or via the CLI:

```bash
npm i -g agent-toolkit-cli
# or: uv tool install agent-toolkit-cli
agent-toolkit install
```
