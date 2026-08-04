# 🛠️ agent-toolkit

> Composable AI capabilities for every major coding assistant — one toolkit, any tool.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-blueviolet)](https://claude.ai/code)
[![Cursor](https://img.shields.io/badge/Cursor-supported-blue)](https://cursor.sh)
[![OpenCode](https://img.shields.io/badge/OpenCode-supported-orange)](https://opencode.ai)
[![GitHub Copilot](https://img.shields.io/badge/GitHub%20Copilot-supported-black)](https://github.com/features/copilot)
[![Windsurf](https://img.shields.io/badge/Windsurf-supported-teal)](https://codeium.com/windsurf)
[![Pi](https://img.shields.io/badge/Pi%20Coding%20Agent-supported-green)](https://pi.ai)

---

## Overview

**agent-toolkit** is a modular collection of skills, agent personas, MCP configuration templates, and loop engineering patterns designed to work across all major AI coding assistants. Instead of maintaining separate prompt libraries for each tool, you keep one source of truth and deploy exactly what each tool needs.

What's included:

- **53+ skills** grouped into 9 domains (core, delivery, design, forge, integrations, data, tooling, ops, loops)
- **Agent personas** — tool-agnostic role definitions for architects, reviewers, planners, and more
- **Profiles** — per-tool configurations for Claude Code, Cursor, OpenCode, GitHub Copilot, Windsurf, and Pi
- **Loop engineering templates** — recurring agentic workflows across 3 automation tiers
- **MCP templates** — ready-to-use Model Context Protocol configs for popular services
- **Solution packs** — curated bundles for common team setups (OSS, startup, enterprise)
- **JSON schemas** — validate your skills and loops before deploying

---

## Quick Install

### Claude Code

```bash
claude plugin add ulises-jeremias/agent-toolkit
```

Or manually clone and point to the skills directory:

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
# Then reference skills in your project's .claude/settings.json
```

### Cursor

Copy the rule files for your project:

```bash
# Copy all domain rules into your project
cp -r ~/.agent-toolkit/profiles/cursor/rules/*.mdc .cursorrules/

# Or for a single domain
cp ~/.agent-toolkit/profiles/cursor/rules/delivery.mdc .cursorrules/
```

Alternatively, add the rules via **Cursor Settings → Rules for AI** by pasting the relevant `.mdc` content.

### OpenCode

```bash
# Copy profile config to opencode's config directory
cp -r ~/.agent-toolkit/profiles/opencode/ ~/.config/opencode/
```

This drops in the system prompt overlays and skill references that opencode uses on startup.

### GitHub Copilot

```bash
# Copy the Copilot instructions file into your project
mkdir -p .github
cp ~/.agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

Customize the file to select which skill domains apply to your project before committing.

### Windsurf

```bash
# Copy Windsurf profile into Codeium's config location
cp -r ~/.agent-toolkit/profiles/windsurf/ ~/.codeium/windsurf/
```

Windsurf picks up the `rules.md` and any memory files from this directory automatically.

### Pi Coding Agent

```bash
# Copy Pi skills into the Pi agent skills directory
mkdir -p ~/.pi/agent/skills
cp -r ~/.agent-toolkit/profiles/pi/skills/ ~/.pi/agent/skills/
```

---

## Skills

Skills are self-contained capability definitions. Each skill lives in a named directory containing a `SKILL.md` (human-readable) and a `skill.json` (machine-readable manifest). Skills are grouped into domains:

| Domain | Description | Skills |
|---|---|---|
| `core` | Foundational patterns: memory, planning, context injection | 8 |
| `delivery` | Code review, PR creation, CI fix, branch workflows | 9 |
| `design` | UI/UX design, component architecture, design systems | 6 |
| `forge` | Code generation, refactoring, test-driven development | 7 |
| `integrations` | JIRA, Confluence, Slack, Linear, ClickUp, Notion | 8 |
| `data` | Database review, dbt validation, Snowflake, data pipelines | 5 |
| `tooling` | Git workflows, Docker, CI/CD, environment setup | 6 |
| `ops` | Incident response, security review, performance optimization | 4 |
| `loops` | Recurring agentic workflows (see Loop Engineering below) | 10 |

Browse the full catalog: [`catalogs/skill-catalog.yaml`](catalogs/skill-catalog.yaml)

### Example: loading the delivery domain

```yaml
# In your project's .claude/settings.json
{
  "skills": [
    "ulises-jeremias/agent-toolkit/skills/delivery/code-review",
    "ulises-jeremias/agent-toolkit/skills/delivery/github-cli-workflow",
    "ulises-jeremias/agent-toolkit/skills/delivery/gh-fix-ci"
  ]
}
```

---

## Loop Engineering

Loops are recurring agentic workflows that run on a schedule or cadence. They follow a three-tier model:

| Tier | Cadence | Description |
|---|---|---|
| **L1** | Minutes to hours | Reactive, event-driven (PR monitor, triage, alerts) |
| **L2** | Daily | Summaries, health checks, briefings |
| **L3** | Weekly / monthly | Trend analysis, reporting, maintenance sweeps |

### Available Loop Templates

| Template | Tier | Default Cadence | Description |
|---|---|---|---|
| `oss-pr-monitor` | L1 | Every 30 min | Monitor open PRs across OSS repos, flag stale or failing ones |
| `oss-triage` | L1 | Every hour | Triage new issues in OSS repos, apply labels, draft responses |
| `oss-daily-briefing` | L2 | Daily | Summarize activity across all tracked OSS repos |
| `dependency-drift` | L2 | Daily | Detect outdated dependencies and open upgrade PRs |
| `ci-health` | L1 | Every 15 min | Watch CI status, auto-diagnose failures |
| `release-notes` | L3 | Weekly | Draft release notes from merged PRs |
| `security-sweep` | L2 | Daily | Run vulnerability scan across repos |
| `codeowner-review` | L2 | Daily | Remind code owners of pending reviews |
| `stale-branch-cleanup` | L3 | Weekly | Identify and archive stale branches |
| `contributor-digest` | L3 | Weekly | Generate contributor activity digest |

Each loop template lives in `loops/<name>/` and contains:

- `request.md` — the prompt template (YAML frontmatter + body)
- `report.md` — output template for reports
- `runbook.md` — operational runbook for humans

---

## Solution Packs

Packs bundle skills, agents, and loops for a specific team context. Load a pack to bring in everything a particular setup needs in one command.

| Pack | Description |
|---|---|
| `oss-ecosystem` | Full OSS maintainer setup: triage, PR monitor, briefings, contributor digest |
| `startup-delivery` | Fast delivery focus: code review, CI fix, PR automation, security sweep |
| `enterprise-ops` | Governance-heavy: incident response, security review, codeowner workflows |
| `data-platform` | Data team focus: dbt, Snowflake, pipeline review, data quality loops |

Browse packs: [`packs/`](packs/)

---

## MCP Templates

Model Context Protocol configuration templates for popular external services. Drop these into your MCP config directory and fill in your credentials.

| Template | Services Covered |
|---|---|
| `github` | Repos, PRs, issues, releases, actions |
| `slack` | Channels, messages, reactions, canvases |
| `notion` | Pages, databases, blocks |
| `linear` | Issues, projects, cycles, comments |
| `figma` | Files, components, design tokens |
| `clickup` | Tasks, lists, spaces, docs, comments |

Templates live in [`mcp/templates/`](mcp/templates/). Each template is a `.json` file with placeholder values clearly marked for substitution.

---

## Agent Personas

The `agents/` directory contains tool-agnostic agent persona definitions. These can be imported by any supported AI coding assistant via its profile configuration.

| Persona | Role |
|---|---|
| `architect` | System design, tradeoffs, ADR drafting |
| `planner` | Task decomposition, sequencing, estimation |
| `code-reviewer` | Quality, maintainability, bug detection |
| `security-reviewer` | Vulnerability audit, threat modeling |
| `performance-optimizer` | Profiling, complexity analysis, benchmarking |
| `tdd-guide` | Test-first development, coverage strategy |
| `refactor-cleaner` | Dead code removal, simplification |
| `docs-lookup` | Documentation and API reference navigation |

Browse the full agent catalog: [`catalogs/agent-catalog.yaml`](catalogs/agent-catalog.yaml)

---

## Repository Structure

```
agent-toolkit/
├── skills/
│   ├── core/           # Foundational patterns
│   ├── delivery/       # Code review, PRs, CI
│   ├── design/         # UI/UX, components
│   ├── forge/          # Code generation, TDD
│   ├── integrations/   # JIRA, Slack, Linear…
│   ├── data/           # DBT, Snowflake, pipelines
│   ├── tooling/        # Git, Docker, CI/CD
│   ├── ops/            # Incident, security, perf
│   └── loops/          # Recurring loop skills
├── agents/             # Tool-agnostic agent personas
├── profiles/
│   ├── claude-code/    # Claude Code config
│   ├── cursor/         # Cursor rules
│   ├── opencode/       # OpenCode system prompt
│   ├── copilot/        # GitHub Copilot instructions
│   ├── windsurf/       # Windsurf rules + memory
│   └── pi/             # Pi Coding Agent skills
├── mcp/
│   └── templates/      # MCP config templates
├── loops/              # Loop engineering templates
├── packs/              # Solution packs
├── catalogs/           # skill-catalog.yaml, agent-catalog.yaml
├── schemas/            # JSON schemas for validation
├── docs/               # Documentation
└── scripts/            # Install and validation scripts
```

---

## Validation

Validate your skills and loop templates before deploying:

```bash
bash scripts/validate-skills.sh
bash scripts/validate-loops.sh
```

Both scripts exit non-zero on failure and emit human-readable error messages.

---

## Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

Quick guide:

1. Fork the repo and create a branch: `feat/my-skill`
2. Add your skill under the appropriate domain in `skills/`
3. Run `bash scripts/validate-skills.sh` — all checks must pass
4. Open a PR with a clear description of what the skill does and which tools it supports

---

## License

MIT — see [LICENSE](LICENSE) for details.
