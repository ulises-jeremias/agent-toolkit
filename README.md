<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%">
</p>

<div align="center">

# 🛠️ agent-toolkit

**Composable AI agent capabilities for every major coding assistant**

<p>
  <a href="https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/validate.yml?branch=main&label=validate&style=for-the-badge&labelColor=0d1117&color=9945ff" alt="Validate"/>
  </a>
  <a href="https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/mega-linter.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/mega-linter.yml?branch=main&label=megalinter&style=for-the-badge&labelColor=0d1117&color=00d4ff" alt="MegaLinter"/>
  </a>
  <a href="https://github.com/vercel-labs/skills">
    <img src="https://img.shields.io/badge/Agent%20Skills-compatible-00ff88?style=for-the-badge&labelColor=0d1117" alt="Agent Skills compatible"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-ff6b35?style=for-the-badge&labelColor=0d1117" alt="MIT License"/>
  </a>
</p>

<p>
  <img src="https://img.shields.io/badge/skills-52-9945ff?style=for-the-badge&labelColor=0d1117" alt="52 Skills"/>
  <img src="https://img.shields.io/badge/agents-16-00d4ff?style=for-the-badge&labelColor=0d1117" alt="16 Agents"/>
  <img src="https://img.shields.io/badge/loops-10-ff6b35?style=for-the-badge&labelColor=0d1117" alt="10 Loops"/>
  <img src="https://img.shields.io/badge/tests-195-00ff88?style=for-the-badge&labelColor=0d1117" alt="195 Tests"/>
  <img src="https://img.shields.io/badge/targets-9-ff00aa?style=for-the-badge&labelColor=0d1117" alt="9 Targets"/>
</p>

<p>
  <a href="profiles/claude-code/">
    <img src="https://img.shields.io/badge/Claude%20Code-plugin-9945ff?style=for-the-badge&labelColor=0d1117&logo=anthropic&logoColor=white" alt="Claude Code"/>
  </a>
  <a href="profiles/cursor/">
    <img src="https://img.shields.io/badge/Cursor-rules-00d4ff?style=for-the-badge&labelColor=0d1117" alt="Cursor"/>
  </a>
  <a href="profiles/opencode/">
    <img src="https://img.shields.io/badge/OpenCode-agents-ff6b35?style=for-the-badge&labelColor=0d1117" alt="OpenCode"/>
  </a>
  <a href="profiles/copilot/">
    <img src="https://img.shields.io/badge/GitHub%20Copilot-instructions-00ff88?style=for-the-badge&labelColor=0d1117&logo=github&logoColor=white" alt="GitHub Copilot"/>
  </a>
  <a href="profiles/windsurf/">
    <img src="https://img.shields.io/badge/Windsurf-rules-0080ff?style=for-the-badge&labelColor=0d1117" alt="Windsurf"/>
  </a>
  <a href="profiles/pi/">
    <img src="https://img.shields.io/badge/Pi%20Agent-skills-ff00aa?style=for-the-badge&labelColor=0d1117" alt="Pi Agent"/>
  </a>
</p>

[📖 Documentation](docs/) •
[🚀 Quick Install](#-quick-install) •
[🛠️ Skills](#%EF%B8%8F-skills--52-across-9-domains) •
[🤖 Agents](#-agent-personas) •
[🔄 Loops](#-loop-engineering) •
[🤝 Contributing](#-contributing)

</div>

---

## ✨ What is agent-toolkit?

**agent-toolkit** is a modular collection of skills, agent personas, MCP configuration templates, and loop engineering patterns that work across all major AI coding assistants. Instead of maintaining separate prompt libraries for each tool, you keep **one source of truth** and deploy exactly what each tool needs.

One toolkit. Any coding assistant. Zero duplication.

```bash
# Get everything in one command
npx skills add ulises-jeremias/agent-toolkit -g
```

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/architecture.svg?raw=true" width="88%">
</div>

---

## 🚀 Quick Install

### Method 1: Python CLI — `uvx` or `pip` *(works with all tools)*

```bash
# No install needed — run directly with uvx
uvx --from agent-toolkit-cli agent-toolkit install

# Or install persistently with pip
pip install agent-toolkit-cli
agent-toolkit install          # auto-detects Claude, Cursor, OpenCode, Windsurf, Pi
agent-toolkit doctor           # verify everything is set up
```

### Method 2: Claude Code Plugin Marketplace

```
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
/plugin install agent-toolkit-forge@agent-toolkit
```

### Method 3: npx skills (Agent Skills standard — skills only)

```bash
npx skills add ulises-jeremias/agent-toolkit -g
```

### Method 4: Homebrew / AUR

```bash
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
yay -S agent-toolkit   # Arch Linux
```

### Method 5: Manual install (per tool)

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit

# Claude Code — reference in .claude/settings.json
# Cursor — copy profiles/cursor/rules/*.mdc → .cursor/rules/
# OpenCode — copy profiles/opencode/ → ~/.config/opencode/
# Copilot — copy profiles/copilot/copilot-instructions.md → .github/
# Windsurf — copy profiles/windsurf/ → ~/.codeium/windsurf/
# Pi Agent — copy profiles/pi/skills/ → ~/.pi/agent/skills/
```

### Method 4: Auto-detect install script

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit.git
bash agent-toolkit/scripts/install.sh
```

The script detects your active tools and deploys the right profiles automatically.

---

## 🖥️ Supported Tools

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/tools-grid.svg?raw=true" width="96%">
</div>

| Tool | Type | What's deployed |
|------|------|-----------------|
| **Claude Code** | Plugin + CLI | Plugin manifest, skill references, settings |
| **Cursor** | IDE | `.mdc` rule files per domain |
| **OpenCode** | TUI | System prompt overlays, agent configs |
| **GitHub Copilot** | IDE | `copilot-instructions.md` with domain selection |
| **Windsurf** | IDE | Rules and memory files via Cascade |
| **Pi Agent** | Agentic harness | Skills and loop templates in Pi's native format |

---

## 🛠️ Skills — 52 across 9 domains

All skills use `SKILL.md` frontmatter only — no `skill.json` required. Fully compliant with the [Agent Skills spec](https://github.com/vercel-labs/skills).

| Domain | Count | Key Skills |
|--------|-------|------------|
| 🧠 `core` | 8 | memory, planning, context injection, session bootstrap |
| 🚀 `delivery` | 9 | code-review, github-cli-workflow, gh-fix-ci, pr-fallback, commit |
| 🎨 `design` | 6 | ui-ux-pro-max, figma-implement-design, design-system-rules |
| ⚡ `forge` | 7 | feature-dev, tdd, refactor-cleaner, simplify, code-connect |
| 🔗 `integrations` | 8 | jira, confluence, slack, linear, clickup, notion |
| 📊 `data` | 5 | dbt-validation, snowflake-validation, pipeline-review |
| 🔧 `tooling` | 6 | git-worktrees, docker, ci-cd, env-setup, keybindings |
| 🛡️ `ops` | 3 | incident, security-review, performance-optimizer |
| 🔄 `loops` | 10 | oss-pr-monitor, oss-triage, oss-daily-briefing |

Browse the full catalog: [`catalogs/skill-catalog.yaml`](catalogs/skill-catalog.yaml)

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

## 🤖 Agent Personas

16 tool-agnostic agent persona definitions in `agents/`. Any supported AI coding assistant can import these via its profile config.

| Persona | Role |
|---------|------|
| 🏗️ `architect` | System design, tradeoffs, ADR drafting |
| 📋 `planner` | Task decomposition, sequencing, estimation |
| 🔍 `code-reviewer` | Quality, maintainability, bug detection |
| 🔷 `typescript-reviewer` | TypeScript-specific review patterns |
| 🛡️ `security-reviewer` | Vulnerability audit, threat modeling |
| 🗄️ `database-reviewer` | Schema design, query optimization, migration safety |
| ⚡ `performance-optimizer` | Profiling, complexity analysis, benchmarking |
| 🧪 `tdd-guide` | Test-first development, coverage strategy |
| 🧹 `refactor-cleaner` | Dead code removal, simplification |
| 🔨 `build-error-resolver` | CI failure diagnosis, dependency conflicts |
| 🎭 `e2e-runner` | End-to-end test authoring and execution |
| 📚 `docs-lookup` | Documentation and API reference navigation |
| 🔎 `reference-lookup` | Cross-repo pattern and convention search |
| 🤝 `assistant` | General-purpose project assistant |
| ⚙️ `tech-assistant` | Stack-specific technical guidance |
| 🚀 `client-workflow-bootstrap` | Client project onboarding and delivery workflow bootstrap |

Full catalog: [`catalogs/agent-catalog.yaml`](catalogs/agent-catalog.yaml)

---

## 🔄 Loop Engineering

Loops are recurring agentic workflows that run on a schedule or cadence. They follow a three-tier model:

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/loop-tiers.svg?raw=true" width="88%">
</div>

| Tier | Cadence | Purpose |
|------|---------|---------|
| **L1** | Minutes to hours | Reactive, event-driven — PR monitoring, triage, CI alerts |
| **L2** | Daily | Summaries, health checks, security sweeps, briefings |
| **L3** | Weekly / monthly | Trend analysis, reporting, maintenance sweeps |

### Loop Templates

| Template | Tier | Default Cadence | Description |
|----------|------|-----------------|-------------|
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

Each loop template lives in `loops/<name>/` and contains a `request.md` prompt template, `report.md` output template, and `runbook.md` for human operators.

---

## 🔗 MCP Templates

Ready-to-use Model Context Protocol configuration templates. Drop into your MCP config directory and substitute your credentials.

| Template | Services Covered |
|----------|-----------------|
| `github` | Repos, PRs, issues, releases, actions |
| `slack` | Channels, messages, reactions, canvases |
| `notion` | Pages, databases, blocks |
| `linear` | Issues, projects, cycles, comments |
| `figma` | Files, components, design tokens |
| `clickup` | Tasks, lists, spaces, docs, comments |

Templates live in [`mcp/templates/`](mcp/templates/). Each file is a `.json` with clearly marked placeholder values.

---

## 📦 Plugins

Three plugins are available in the Claude Code and Cursor marketplaces:

| Plugin | What's included |
|--------|-----------------|
| `agent-toolkit-core` | Core, delivery, integrations, ops, and tooling domains — everyday coding workflows |
| `agent-toolkit-agents` | All 16 agent personas — architect, planner, reviewers, TDD guide, and more |
| `agent-toolkit-forge` | Design, forge, and data domains — code generation, UI/UX, TDD, dbt/Snowflake |

Plugin manifests: [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) · [`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json)

---

## 🎯 Solution Packs

Packs bundle skills, agents, and loops for a specific team context. Load a pack to bring in everything a setup needs in one step.

| Pack | Description |
|------|-------------|
| `oss-ecosystem` | Full OSS maintainer setup: triage, PR monitor, briefings, contributor digest |
| `startup-delivery` | Fast delivery focus: code review, CI fix, PR automation, security sweep |
| `enterprise-ops` | Governance-heavy: incident response, security review, codeowner workflows |

Browse packs: [`packs/`](packs/)

---

## 📚 Documentation

| Guide | Description |
|-------|-------------|
| [🔨 How to add a skill](docs/HOW_TO_ADD_SKILL.md) | Create a new skill with SKILL.md frontmatter |
| [🤖 How to add an agent](docs/HOW_TO_ADD_AGENT.md) | Define a new agent persona |
| [🔄 How to create a loop](docs/HOW_TO_CREATE_LOOP.md) | Build a recurring agentic workflow |
| [🌐 OSS Maintenance example](examples/oss-maintenance/) | Full walkthrough of the oss-ecosystem pack |
| [🚀 Project onboarding example](examples/project-onboarding/) | Bootstrap a new project with agent-toolkit |

---

## 🏗️ Architecture

One source of truth, deployed per-tool. Each profile in `profiles/` adapts the shared skills and agents to the conventions of its target tool.

```
agent-toolkit/
├── skills/              # 52 skills across 9 domains (SKILL.md frontmatter)
├── agents/              # 16 tool-agnostic agent persona definitions
├── profiles/
│   ├── claude-code/     # Plugin manifest, skill references, settings
│   ├── cursor/          # .mdc rule files per domain
│   ├── opencode/        # System prompt overlays, agent configs
│   ├── copilot/         # copilot-instructions.md with domain selection
│   ├── windsurf/        # rules.md and memory files
│   └── pi/              # Skill definitions in Pi's native format
├── loops/               # 10 recurring loop engineering templates
├── mcp/templates/       # 6 MCP config templates (JSON)
├── packs/               # 3 solution packs
├── catalogs/            # skill-catalog.yaml, agent-catalog.yaml
├── schemas/             # JSON schemas for validation
├── docs/                # How-to guides and reference docs
├── examples/            # Worked examples
└── scripts/             # Install and validation scripts
```

### Automation tiers

| Tier | Trigger | Example |
|------|---------|---------|
| **L1** | Event / short interval | `oss-pr-monitor`, `ci-health` |
| **L1.5** | Scheduled short-cadence | `oss-triage`, `dependency-drift` |
| **L3** | Weekly / monthly | `release-notes`, `contributor-digest` |

---

## ✅ Validation

```bash
bash scripts/validate-skills.sh
bash scripts/validate-loops.sh
```

Both scripts exit non-zero on failure with human-readable error messages. They run automatically in CI via the Validate and MegaLinter workflows.

---

## 🤝 Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

1. Fork the repo and create a branch: `feat/my-skill`
2. Add your skill under the appropriate domain in `skills/` — use `SKILL.md` frontmatter only
3. Run `bash scripts/validate-skills.sh` — all checks must pass
4. Open a PR with a clear description of what the skill does and which tools it supports

See [How to add a skill](docs/HOW_TO_ADD_SKILL.md) for the full authoring guide.

---

<div align="center">

[📖 Docs](docs/) · [🐛 Issues](https://github.com/ulises-jeremias/agent-toolkit/issues) · [💬 Discussions](https://github.com/ulises-jeremias/agent-toolkit/discussions) · [MIT License](LICENSE)

<sub>Built for the agentic age — one toolkit, every assistant.</sub>

</div>
