# agent-toolkit

> Composable AI capabilities for every major coding assistant — one toolkit, any tool.

[![Validate](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml/badge.svg)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml)
[![MegaLinter](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/mega-linter.yml/badge.svg)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/mega-linter.yml)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-0A7EA4)](https://github.com/vercel-labs/skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet)](profiles/claude-code/)
[![Cursor](https://img.shields.io/badge/Cursor-rules-blue)](profiles/cursor/)
[![OpenCode](https://img.shields.io/badge/OpenCode-agents-orange)](profiles/opencode/)
[![Copilot](https://img.shields.io/badge/GitHub%20Copilot-instructions-black)](profiles/copilot/)
[![Windsurf](https://img.shields.io/badge/Windsurf-rules-teal)](profiles/windsurf/)
[![Pi](https://img.shields.io/badge/Pi%20Coding%20Agent-skills-green)](profiles/pi/)

![Skills](https://img.shields.io/badge/skills-52-brightgreen)
![Agents](https://img.shields.io/badge/agents-16-blue)
![Loops](https://img.shields.io/badge/loops-10-orange)
![Plugins](https://img.shields.io/badge/plugins-3-purple)

---

## Overview

**agent-toolkit** is a modular collection of skills, agent personas, MCP configuration templates, and loop engineering patterns designed to work across all major AI coding assistants. Instead of maintaining separate prompt libraries for each tool, you keep one source of truth and deploy exactly what each tool needs.

What's included:

- **52 skills** grouped into 9 domains — core, delivery, design, forge, integrations, data, tooling, ops, loops
- **16 agent personas** — tool-agnostic role definitions for architects, reviewers, planners, and more
- **10 loop templates** — recurring agentic workflows across 3 automation tiers
- **3 marketplace plugins** — `agent-toolkit-core`, `agent-toolkit-agents`, `agent-toolkit-forge`
- **6 tool profiles** — per-tool configurations for Claude Code, Cursor, OpenCode, GitHub Copilot, Windsurf, and Pi
- **6 MCP templates** — ready-to-use Model Context Protocol configs for popular services
- **3 solution packs** — curated bundles for common team setups

All skills use `SKILL.md` frontmatter only — no `skill.json` required. Fully compliant with the [Agent Skills spec](https://github.com/vercel-labs/skills).

---

## Installation

### Method 1: Claude Code Plugin Marketplace (recommended)

```
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
/plugin install agent-toolkit-forge@agent-toolkit
```

The three plugins let you install exactly the capabilities you need. `agent-toolkit-core` covers foundational skills and delivery workflows. `agent-toolkit-agents` brings in the full persona library. `agent-toolkit-forge` adds code generation, TDD, and refactoring patterns.

Plugin manifests: [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) | [`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json)

---

### Method 2: npx skills (Agent Skills standard)

```bash
# Global install — all tools pick up skills automatically
npx skills add ulises-jeremias/agent-toolkit -g

# Project-scoped install
npx skills add ulises-jeremias/agent-toolkit
```

This is the standard install path for any Agent Skills-compatible tool. Skills are written with `SKILL.md` frontmatter only, no `skill.json` required.

---

### Method 3: Manual install (per tool)

**Claude Code**

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
# Reference skills in your project's .claude/settings.json
```

**Cursor**

```bash
# Copy domain rules into your project
cp -r ~/.agent-toolkit/profiles/cursor/rules/*.mdc .cursorrules/

# Or for a single domain
cp ~/.agent-toolkit/profiles/cursor/rules/delivery.mdc .cursorrules/
```

**OpenCode**

```bash
cp -r ~/.agent-toolkit/profiles/opencode/ ~/.config/opencode/
```

**GitHub Copilot**

```bash
mkdir -p .github
cp ~/.agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

**Windsurf**

```bash
cp -r ~/.agent-toolkit/profiles/windsurf/ ~/.codeium/windsurf/
```

**Pi Coding Agent**

```bash
mkdir -p ~/.pi/agent/skills
cp -r ~/.agent-toolkit/profiles/pi/skills/ ~/.pi/agent/skills/
```

---

### Method 4: install.sh (auto-detect)

The install script detects your active tools and deploys the right profiles automatically.

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit.git
bash agent-toolkit/scripts/install.sh
```

---

## Skills

52 skills across 9 domains. All skills use `SKILL.md` frontmatter — no `skill.json`. Browse the full catalog: [`catalogs/skill-catalog.yaml`](catalogs/skill-catalog.yaml)

| Domain | Skills | Examples |
|---|---|---|
| `core` | 8 | memory, planning, context injection, session bootstrap |
| `delivery` | 9 | code-review, github-cli-workflow, gh-fix-ci, pr-fallback, commit |
| `design` | 6 | ui-ux-pro-max, figma-implement-design, design-system-rules |
| `forge` | 7 | feature-dev, tdd, refactor-cleaner, simplify, code-connect |
| `integrations` | 8 | jira, confluence, slack, linear, clickup, notion |
| `data` | 5 | dbt-validation, snowflake-validation, pipeline-review |
| `tooling` | 6 | git-worktrees, docker, ci-cd, env-setup, keybindings |
| `ops` | 3 | incident, security-review, performance-optimizer |
| `loops` | 10 | oss-pr-monitor, oss-triage, oss-daily-briefing (see below) |

### Loading skills in Claude Code

```jsonc
// .claude/settings.json
{
  "skills": [
    "ulises-jeremias/agent-toolkit/skills/delivery/code-review",
    "ulises-jeremias/agent-toolkit/skills/delivery/github-cli-workflow",
    "ulises-jeremias/agent-toolkit/skills/delivery/gh-fix-ci"
  ]
}
```

---

## Plugins

Three plugins are available in the Claude Code and Cursor marketplaces:

| Plugin | What's included |
|---|---|
| `agent-toolkit-core` | Core, delivery, integrations, ops, and tooling domains — everyday coding workflows |
| `agent-toolkit-agents` | All 16 agent personas — architect, planner, reviewers, TDD guide, and more |
| `agent-toolkit-forge` | Design, forge, and data domains — code generation, UI/UX, TDD, dbt/Snowflake |

---

## Agent Personas

16 tool-agnostic agent persona definitions in `agents/`. Any supported AI coding assistant can import these via its profile config.

| Persona | Role |
|---|---|
| `architect` | System design, tradeoffs, ADR drafting |
| `planner` | Task decomposition, sequencing, estimation |
| `code-reviewer` | Quality, maintainability, bug detection |
| `typescript-reviewer` | TypeScript-specific review patterns |
| `security-reviewer` | Vulnerability audit, threat modeling |
| `database-reviewer` | Schema design, query optimization, migration safety |
| `performance-optimizer` | Profiling, complexity analysis, benchmarking |
| `tdd-guide` | Test-first development, coverage strategy |
| `refactor-cleaner` | Dead code removal, simplification |
| `build-error-resolver` | CI failure diagnosis, dependency conflicts |
| `e2e-runner` | End-to-end test authoring and execution |
| `docs-lookup` | Documentation and API reference navigation |
| `reference-lookup` | Cross-repo pattern and convention search |
| `assistant` | General-purpose project assistant |
| `tech-assistant` | Stack-specific technical guidance |
| `explore` | Fast codebase search and discovery |

Full catalog: [`catalogs/agent-catalog.yaml`](catalogs/agent-catalog.yaml)

---

## Loop Engineering

Loops are recurring agentic workflows that run on a schedule or cadence. They follow a three-tier model:

| Tier | Cadence | Purpose |
|---|---|---|
| **L1** | Minutes to hours | Reactive, event-driven — PR monitoring, triage, CI alerts |
| **L2** | Daily | Summaries, health checks, security sweeps, briefings |
| **L3** | Weekly / monthly | Trend analysis, reporting, maintenance sweeps |

### Loop Templates

| Template | Tier | Default Cadence | Description |
|---|---|---|---|
| `oss-pr-monitor` | L1 | Every 30 min | Monitor open PRs across OSS repos, flag stale or failing ones |
| `oss-triage` | L1 | Every hour | Triage new issues, apply labels, draft responses |
| `ci-health` | L1 | Every 15 min | Watch CI status, auto-diagnose failures |
| `oss-daily-briefing` | L2 | Daily | Summarize activity across all tracked OSS repos |
| `dependency-drift` | L2 | Daily | Detect outdated dependencies and open upgrade PRs |
| `security-sweep` | L2 | Daily | Run vulnerability scan across repos |
| `codeowner-review` | L2 | Daily | Remind code owners of pending reviews |
| `release-notes` | L3 | Weekly | Draft release notes from merged PRs |
| `stale-branch-cleanup` | L3 | Weekly | Identify and archive stale branches |
| `contributor-digest` | L3 | Weekly | Generate contributor activity digest |

Each loop template lives in `loops/<name>/` and contains:

- `request.md` — prompt template (YAML frontmatter + body)
- `report.md` — output template for generated reports
- `runbook.md` — operational runbook for human operators

---

## MCP Templates

Ready-to-use Model Context Protocol configuration templates. Drop into your MCP config directory and substitute your credentials.

| Template | Services Covered |
|---|---|
| `github` | Repos, PRs, issues, releases, actions |
| `slack` | Channels, messages, reactions, canvases |
| `notion` | Pages, databases, blocks |
| `linear` | Issues, projects, cycles, comments |
| `figma` | Files, components, design tokens |
| `clickup` | Tasks, lists, spaces, docs, comments |

Templates live in [`mcp/templates/`](mcp/templates/). Each file is a `.json` with clearly marked placeholder values.

---

## Solution Packs

Packs bundle skills, agents, and loops for a specific team context. Load a pack to bring in everything a setup needs in one step.

| Pack | Description |
|---|---|
| `oss-ecosystem` | Full OSS maintainer setup: triage, PR monitor, briefings, contributor digest |
| `startup-delivery` | Fast delivery focus: code review, CI fix, PR automation, security sweep |
| `enterprise-ops` | Governance-heavy: incident response, security review, codeowner workflows |

Browse packs: [`packs/`](packs/)

---

## Profiles

One source of truth, deployed per-tool. Each profile in `profiles/` adapts the shared skills and agents to the conventions of its target tool.

| Tool | Profile location | What's deployed |
|---|---|---|
| [Claude Code](profiles/claude-code/) | `profiles/claude-code/` | Plugin manifest, skill references, settings |
| [Cursor](profiles/cursor/) | `profiles/cursor/` | `.mdc` rule files per domain |
| [OpenCode](profiles/opencode/) | `profiles/opencode/` | System prompt overlays, agent configs |
| [GitHub Copilot](profiles/copilot/) | `profiles/copilot/` | `copilot-instructions.md` with domain selection |
| [Windsurf](profiles/windsurf/) | `profiles/windsurf/` | `rules.md` and memory files |
| [Pi](profiles/pi/) | `profiles/pi/` | Skill definitions in Pi's native format |

---

## Repository Structure

```
agent-toolkit/
├── .claude-plugin/
│   └── marketplace.json        # Claude Code plugin manifest
├── .cursor-plugin/
│   └── marketplace.json        # Cursor plugin manifest
├── skills/
│   ├── core/                   # Foundational patterns
│   ├── delivery/               # Code review, PRs, CI
│   ├── design/                 # UI/UX, components, design systems
│   ├── forge/                  # Code generation, TDD, refactoring
│   ├── integrations/           # JIRA, Slack, Linear, ClickUp…
│   ├── data/                   # DBT, Snowflake, pipelines
│   ├── tooling/                # Git, Docker, CI/CD
│   ├── ops/                    # Incident, security, performance
│   └── loops/                  # Recurring loop skills
├── agents/                     # 16 tool-agnostic agent personas
├── profiles/
│   ├── claude-code/            # Claude Code plugin config
│   ├── cursor/                 # Cursor rules (.mdc)
│   ├── opencode/               # OpenCode system prompt overlays
│   ├── copilot/                # GitHub Copilot instructions
│   ├── windsurf/               # Windsurf rules + memory
│   └── pi/                     # Pi Coding Agent skills
├── loops/                      # 10 loop engineering templates
├── mcp/
│   └── templates/              # 6 MCP config templates
├── packs/                      # 3 solution packs
├── catalogs/                   # skill-catalog.yaml, agent-catalog.yaml
├── schemas/                    # JSON schemas for validation
├── docs/                       # Documentation and how-to guides
├── examples/                   # Worked examples
└── scripts/                    # Install and validation scripts
```

---

## How-to Guides

| Guide | Description |
|---|---|
| [How to add a skill](docs/HOW_TO_ADD_SKILL.md) | Create a new skill with SKILL.md frontmatter |
| [How to add an agent](docs/HOW_TO_ADD_AGENT.md) | Define a new agent persona |
| [How to create a loop](docs/HOW_TO_CREATE_LOOP.md) | Build a recurring agentic workflow |
| [OSS Maintenance example](examples/oss-maintenance/) | Full walkthrough of the oss-ecosystem pack |
| [Project onboarding example](examples/project-onboarding/) | Bootstrap a new project with agent-toolkit |

---

## Validation

Validate skills and loop templates before deploying:

```bash
bash scripts/validate-skills.sh
bash scripts/validate-loops.sh
```

Both scripts exit non-zero on failure and emit human-readable error messages. These run automatically in CI via the Validate and MegaLinter workflows.

---

## Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

Quick guide:

1. Fork the repo and create a branch: `feat/my-skill`
2. Add your skill under the appropriate domain in `skills/` — use `SKILL.md` frontmatter only
3. Run `bash scripts/validate-skills.sh` — all checks must pass
4. Open a PR with a clear description of what the skill does and which tools it support

See [How to add a skill](docs/HOW_TO_ADD_SKILL.md) for the full authoring guide.

---

## License

MIT — see [LICENSE](LICENSE) for details.
