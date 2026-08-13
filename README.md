<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%">
</p>

<div align="center">

# agent-toolkit

> **New here?** Start with [Getting Started](docs/GETTING_STARTED.md) — install → doctor → first skill.

**Composable AI agent capabilities for every major coding assistant**

[![Validate](https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/validate.yml?branch=main&label=validate&style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml)
[![MegaLinter](https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/mega-linter.yml?branch=main&label=MegaLinter&style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/mega-linter.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-16a34a?style=flat&labelColor=1f2937)](https://github.com/vercel-labs/skills)
[![Agent Plugins](https://img.shields.io/badge/Agent%20Plugins-1.0-7c3aed?style=flat&labelColor=1f2937)](https://agent-plugins.org)

![skills](https://img.shields.io/badge/skills-60-7c3aed?style=flat&labelColor=1f2937)
![agents](https://img.shields.io/badge/agents-16-0891b2?style=flat&labelColor=1f2937)
![loops](https://img.shields.io/badge/loops-10-ea580c?style=flat&labelColor=1f2937)

[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-7c3aed?style=flat&labelColor=1f2937&logo=anthropic&logoColor=white)](profiles/claude-code/)
[![Cursor](https://img.shields.io/badge/Cursor-rules-0891b2?style=flat&labelColor=1f2937)](profiles/cursor/)
[![OpenCode](https://img.shields.io/badge/OpenCode-agents-ea580c?style=flat&labelColor=1f2937)](profiles/opencode/)
[![Copilot](https://img.shields.io/badge/GitHub%20Copilot-instructions-16a34a?style=flat&labelColor=1f2937&logo=github&logoColor=white)](profiles/copilot/)
[![Windsurf](https://img.shields.io/badge/Windsurf-rules-2563eb?style=flat&labelColor=1f2937)](profiles/windsurf/)
[![Pi](https://img.shields.io/badge/Pi%20Agent-skills-db2777?style=flat&labelColor=1f2937)](profiles/pi/)
[![Muse Code](https://img.shields.io/badge/Muse%20Code-skills-ff6b35?style=flat&labelColor=1f2937)](https://developer.meta.com/ai/products/muse-code/)

[Documentation](docs/) ·
[Quick Install](#-quick-install) ·
[Skills](#%EF%B8%8F-skills--60-across-9-domains) ·
[Agents](#-agent-personas) ·
[Loops](#-loop-engineering) ·
[Contributing](#-contributing)

</div>

---

## ✨ What is agent-toolkit?

**agent-toolkit** is a modular collection of skills, agent personas, MCP configuration templates, and loop engineering patterns that work across all major AI coding assistants. Instead of maintaining separate prompt libraries for each tool, you keep **one source of truth** and deploy exactly what each tool needs.

One toolkit. Any coding assistant. Zero duplication.

```bash
# Native V CLI (any channel below), then:
agent-toolkit install
agent-toolkit doctor
```

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/architecture.svg?raw=true" width="88%">
</div>

---

## Key Concepts

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🛠️ Skills</h3>
      <sub>Reusable capability units (<code>SKILL.md</code>) that teach an agent how to do a job — delivery workflows, forge CLIs, design, data, ops.</sub>
      <br><br>
      <sub>77 skills across 9 domains. Browse <code>skills/</code> or <code>agent-toolkit inventory</code>.</sub>
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Agents</h3>
      <sub>Personas that constrain <em>how</em> the AI works in a session — review, plan, architect, fix CI — without rewriting your prompts each time.</sub>
      <br><br>
      <sub>16 personas under <code>agents/</code>, compiled into each target's native format.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Loops</h3>
      <sub>Recurring agentic workflows with mutation-safety tiers (L1 observe → L2 controlled → L3 high autonomy).</sub>
      <br><br>
      <sub><code>agent-toolkit loop run daily-triage</code> · 10 templates in <code>loops/</code></sub>
    </td>
    <td width="50%" valign="top">
      <h3>📦 Packs</h3>
      <sub>Solution bundles that combine skills, agents, and loops for a team context (OSS maintenance, engineering workflow, delivery discipline).</sub>
      <br><br>
      <sub>Declared under <code>packs/</code>; load with your workspace tooling.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🧩 Plugins</h3>
      <sub>Product distributions for Claude Code / Cursor marketplaces — core, agents, forge — compiled from one catalog.</sub>
      <br><br>
      <sub>Source of truth: <code>distributions/products.yaml</code></sub>
    </td>
    <td width="50%" valign="top">
      <h3>🔗 MCP</h3>
      <sub>Provider registry + ready templates (GitHub, Slack, Notion, Linear, Figma, ClickUp) emitted into target-native MCP configs.</sub>
      <br><br>
      <sub><code>mcp/registry/</code> · <code>mcp/templates/</code> · <code>agent-toolkit mcp</code></sub>
    </td>
  </tr>
</table>

---

## 🚀 Quick Install

**Recommended:** the product CLI is the **native V binary**. PyPI/`uv` is a thin launcher over that binary ([ADR-021](docs/adrs/ADR-021-pypi-binary.md)).

```bash
# GitHub Release — native V binary + SHA256SUMS (v1.11.0+)
# https://github.com/ulises-jeremias/agent-toolkit/releases/latest

# Homebrew
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit

# AUR (Arch) — native V binary; not the Python AUR package
yay -S agent-toolkit-bin

# PyPI launcher (execs bundled V; ADR-021)
uv tool install 'agent-toolkit-cli>=1.11.0'
uvx --from 'agent-toolkit-cli>=1.11.0' agent-toolkit install

# npm
npm i -g agent-toolkit-cli

agent-toolkit install    # auto-detects Claude, Cursor, OpenCode, Windsurf, Pi, Copilot
agent-toolkit doctor     # verify everything is set up
```

→ Full walkthrough: [docs/INSTALLATION.md](docs/INSTALLATION.md)

### Advanced install methods

Use these only when the primary CLI flow above does not fit your setup.

<details>
<summary><strong>Claude Code plugin marketplace</strong> — native plugins for Claude Code only</summary>

```
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
/plugin install agent-toolkit-forge@agent-toolkit
```

</details>

<details>
<summary><strong>Cursor plugins</strong> — Cursor IDE and Cursor Agent CLI</summary>

Native plugins from [`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json):
`agent-toolkit-core`, `agent-toolkit-agents`, `agent-toolkit-forge`.

**Cursor IDE**

1. Open **Customize** in the sidebar (or Command Palette → *Cursor: Open Plugin Marketplace*).
2. Import the marketplace repo: `https://github.com/ulises-jeremias/agent-toolkit`
3. Install the plugins you need (`agent-toolkit-core` is the baseline).

User-scoped installs sync to Cursor Agent CLI sessions automatically.

**Cursor Agent CLI**

```bash
# Interactive — browse / install from the Marketplace tab
cursor-agent
# then type: /plugin
```

Load a local plugin directory for one session (useful while developing):

```bash
cursor-agent --plugin-dir ./plugins/agent-toolkit-core
cursor-agent --plugin-dir ./plugins/agent-toolkit-agents
cursor-agent --plugin-dir ./plugins/agent-toolkit-forge
```

**Local / offline**

```bash
# Symlink into Cursor's local plugin dir, then reload the window
mkdir -p ~/.cursor/plugins/local
ln -s "$(pwd)/plugins/agent-toolkit-core" ~/.cursor/plugins/local/agent-toolkit-core
ln -s "$(pwd)/plugins/agent-toolkit-agents" ~/.cursor/plugins/local/agent-toolkit-agents
ln -s "$(pwd)/plugins/agent-toolkit-forge" ~/.cursor/plugins/local/agent-toolkit-forge
```

→ [Cursor plugins docs](https://cursor.com/docs/plugins) · [Plugin marketplace guide](docs/wiki/Plugin-Marketplace.md)

</details>

<details>
<summary><strong>npx skills</strong> — Agent Skills standard (skills only, no agents/loops)</summary>

```bash
npx skills add ulises-jeremias/agent-toolkit -g
```

</details>

<details>
<summary><strong>Homebrew / AUR</strong> — system package managers</summary>

Formulas live in dedicated repos ([homebrew-tap](https://github.com/ulises-jeremias/homebrew-tap), [aur-packages](https://github.com/ulises-jeremias/aur-packages)); release workflows notify them on tag.

```bash
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
yay -S agent-toolkit-bin   # Arch Linux (AUR) — GitHub Release V binary
npm i -g agent-toolkit-cli # optionalDependencies platform packages
```

</details>

<details>
<summary><strong>Git clone + install script</strong> — offline or pinned commit</summary>

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
bash ~/.agent-toolkit/scripts/install.sh
```

The script detects active tools and deploys profiles. Options: `--tools`, `--dry-run`, `--force`.

</details>

<details>
<summary><strong>Manual per-tool copy</strong> — full control over paths</summary>

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit

# Claude Code — reference in .claude/settings.json
# Cursor — copy profiles/cursor/rules/*.mdc → .cursor/rules/
# OpenCode — copy profiles/opencode/ → ~/.config/opencode/
# Copilot — copy profiles/copilot/copilot-instructions.md → .github/
# Windsurf — copy profiles/windsurf/ → ~/.codeium/windsurf/
# Pi Agent — copy profiles/pi/skills/ → ~/.pi/agent/skills/
```

Per-tool steps: [docs/INSTALLATION.md#manual-install](docs/INSTALLATION.md#manual-install)

</details>

---

## 🖥️ Supported Tools

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/tools-grid.svg?raw=true" width="96%">
</div>

| Tool | Type | What's deployed |
|------|------|-----------------|
| **Claude Code** | Plugin + CLI | Plugin manifest, skill references, settings |
| **Cursor** | Plugin + IDE + Agent CLI | Marketplace plugins (`.cursor-plugin/`), `.mdc` rules via profile |
| **OpenCode** | TUI | System prompt overlays, agent configs |
| **GitHub Copilot** | IDE | `copilot-instructions.md` with domain selection |
| **Windsurf** | IDE | Rules and memory files via Cascade |
| **Pi Agent** | Agentic harness | Skills and loop templates in Pi's native format |

---

## 🛠️ Skills — 60 across 9 domains

All skills use `SKILL.md` frontmatter only — no `skill.json` required. Fully compliant with the [Agent Skills spec](https://github.com/vercel-labs/skills).

| Domain | Count | Key Skills |
|--------|-------|------------|
| 🧠 `core` | 6 | assistant, dev-companion, output-handshake, pr-fallback, workspace-knowledge-sync, onboarding |
| 🚀 `delivery` | 21 | adr, bug, epic, development-workflow, planning, prd, user-story, work-item |
| 🎨 `design` | 5 | figma-implement-design, figma-code-connect-components, design-system-rules |
| ⚡ `forge` | 7 | github-cli-workflow, gitlab-cli-workflow, gh-fix-ci, gh-address-comments, gh-contribution-planner |
| 🔗 `integrations` | 4 | slack-cli, slack-assistant, linear, clickup-cli |
| 📊 `data` | 2 | dbt-validation, snowflake-validation |
| 🔧 `tooling` | 2 | jupyter-notebook, playwright-cli |
| 🛡️ `ops` | 3 | triage, docs-generator, llm-cost-advisor |
| 🔄 `loops` | 1 | loop-runner (see [Loop Engineering](#-loop-engineering) for 10 templates) |

Browse the full catalog: [`catalogs/skill-catalog.yaml`](catalogs/skill-catalog.yaml) · **membership matrix** [`docs/SKILL_PRODUCT_MATRIX.md`](docs/SKILL_PRODUCT_MATRIX.md) (`scripts/generate-skill-matrix.py --check` in CI) · regenerate with `bash scripts/validate-skills.sh` (CI) and inspect live inventory via `agent-toolkit inventory`

### Loading skills in Claude Code

```jsonc
// .claude/settings.json
{
  "skills": [
    "ulises-jeremias/agent-toolkit/skills/core/assistant",
    "ulises-jeremias/agent-toolkit/skills/delivery/workflow-generic-project",
    "ulises-jeremias/agent-toolkit/skills/delivery/bug"
  ]
}
```

---

## 🤖 Agent Personas

17 tool-agnostic agent persona definitions in `agents/`. Any supported AI coding assistant can import these via its profile config.

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
| 🧭 `client-workflow-bootstrap` | Client workflow bootstrap |
| 🛡️ `agentic-security-reviewer` | Agentic security — prompt injection, tool poisoning, excessive agency, MCP/plugin supply chain |

Full catalog: [`catalogs/agent-catalog.yaml`](catalogs/agent-catalog.yaml) · 17 personas on disk under `agents/`

---

## 🔄 Loop Engineering

Loops are recurring agentic workflows that run on a schedule or cadence. They follow a three-tier **mutation-safety** model enforced by `loop-gh-gate` (cadence is independent of tier):

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/loop-tiers.svg?raw=true" width="88%">
</div>

| Tier | Mutation posture | Purpose |
|------|------------------|---------|
| **L1** | Observe / propose | Read-only or proposal-only — no repository mutations |
| **L2** | Controlled mutations | Allowlisted writes (label, comment, limited housekeeping) — merge/close denied |
| **L3** | High-autonomy mutations | Mature allowlisted mutations including merge/close when explicitly permitted |

### Loop Templates

| Template | Tier | Default Cadence | Description |
|----------|------|-----------------|-------------|
| `changelog-drafter` | L1 | 1d | Draft release notes from merged PRs (L1, report-only) |
| `ci-sweeper` | L2 | 15m | Detect CI failures and propose fixes via draft PRs (L2, cautious) |
| `daily-triage` | L1 | 1d | Triage new issues and propose labels (report-only) |
| `dep-sweeper` | L2 | 1d | Apply patch-level dependency updates via draft PRs (L2) |
| `issue-triage` | L1 | 4h | Propose labels and routing for new issues (L1, propose-only) |
| `oss-daily-briefing` | L1 | 1d | Daily read-only briefing across OSS ecosystem repos (L1) |
| `oss-pr-monitor` | L3 | 1d | Monitor open PRs across OSS ecosystem repos and take action (L3, daily) |
| `oss-triage` | L1 | 1d | Triage issues across OSS ecosystem repos (L1, daily) |
| `post-merge-cleanup` | L2 | 6h | Off-peak housekeeping after merges (L2, low impact) |
| `pr-babysitter` | L2 | 15m | Monitor open PRs and post review comments (L2, PR-gated) |

Each loop template lives in `loops/<name>/` (10 templates on disk) with a `loop.yaml` definition (prompt in `request:`). At runtime the runner writes `STATE.md` and `report.md` under that directory.

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

## 📦 Plugins — Agent Plugins 1.0 Portable

> **New:** Every plugin in [`plugins/`](./plugins/) now ships as an **Agent Plugins 1.0** portable bundle (`plugin.json` + `skills/` + `mcp.json`) for **Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, Kiro** — plus legacy `.claude-plugin/` for **Claude Code** (dual emit until Claude supports the spec). See [docs/AGENT_PLUGINS.md](docs/AGENT_PLUGINS.md).

Product bundles are declared in [`distributions/products.yaml`](distributions/products.yaml). Four products are built for every compatible client; three ship in the Claude Code and Cursor marketplaces:

| Product | Portable (Agent Plugins 1.0) | What's included |
|---------|------------------------------|-----------------|
| `agent-toolkit-core` | `plugin.json` + `skills/` (6) + `mcp.json` (github) | 6 core skills (`assistant`, `dev-companion`, `output-handshake`, `pr-fallback`, `workspace-knowledge-sync`, `onboarding`), `code-reviewer` agent, `session-start-context` hook, GitHub MCP |
| `agent-toolkit-agents` | `plugin.json` + `agents/` via `com.anthropic.claude-code` extension | 17 agent personas — agentic-security-reviewer, architect, assistant, build-error-resolver, client-workflow-bootstrap, code-reviewer, database-reviewer, docs-lookup, e2e-runner, performance-optimizer, planner, refactor-cleaner, reference-lookup, security-reviewer, tdd-guide, tech-assistant, typescript-reviewer |
| `agent-toolkit-forge` | `plugin.json` + `skills/` (7) | 7 forge skills — `github-cli-workflow`, `gitlab-cli-workflow`, `gh-address-comments`, `gh-fix-ci`, `gh-contribution-planner`, `workflow-client-bootstrap`, `workflow-generic-project` |
| `agent-toolkit-complete` | `plugin.json` + `skills/` (60) + `mcp.json` | Full stable skill catalog (experimental; portable manifest included, marketplace pending) |

Plugin manifests: [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) · [`.cursor-plugin/marketplace.json`](.cursor-plugin/marketplace.json) · `plugins/<id>/plugin.json` (Agent Plugins `$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) · `plugins/<id>/mcp.json` (where applicable)

---

## 🎯 Solution Packs

Packs bundle skills, agents, and loops for a specific team context. Load a pack to bring in everything a setup needs in one step.

| Pack | Description |
|------|-------------|
| `oss-maintenance` | Full OSS maintainer setup: triage, PR monitor, briefings, contributor digest |
| `engineering-workflow` | Fast delivery focus: code review, CI fix, PR automation, security sweep |
| `delivery-discipline` | Governance-heavy: incident response, security review, codeowner workflows |
| `agentic-security` | Agentic security, supply-chain, MCP, OWASP, threat modeling |
| `architecture` | Architecture, ADRs, cloud design, diagramming, C4 |
| `code-quality` | Code quality, MegaLinter, CodeQL, CI fix, inventory |
| `design-engineering` | Design-engineering, frontend, a11y, Chrome DevTools |

Browse packs: [`packs/`](packs/)

---

## 📚 Documentation

| Guide | Description |
|-------|-------------|
| [🔨 How to add a skill](docs/HOW_TO_ADD_SKILL.md) | Create a new skill with SKILL.md frontmatter |
| [🤖 How to add an agent](docs/HOW_TO_ADD_AGENT.md) | Define a new agent persona |
| [🔄 How to create a loop](docs/HOW_TO_CREATE_LOOP.md) | Build a recurring agentic workflow |
| [🌐 OSS Maintenance example](examples/oss-maintenance/) | Full walkthrough of the oss-maintenance pack |
| [🚀 Project onboarding example](examples/project-onboarding/) | Bootstrap a new project with agent-toolkit |

---

## 🌐 Ecosystem

`agent-toolkit` is the **capability distribution layer (L1.5)** in a three-tier personal DX stack. It's designed to be consumed by two companion repos:

| Layer | Repo | Role |
|-------|------|------|
| **L1** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5** | **agent-toolkit** (this repo) | Capability distribution — skills, loops, profiles, MCP |
| **L3** | [agentic-harness](https://github.com/ulises-jeremias/agentic-harness) | AI workspace scaffold for multi-repo orchestration |

**agentic-workstation** installs `agent-toolkit-cli` automatically during `chezmoi apply` (via AUR on Arch Linux or pip elsewhere). Running `agent-toolkit install` deploys skills and profiles to all detected AI tools.

**agentic-harness** is an opinionated workspace scaffold that uses `agent-toolkit loop`, `agent-toolkit memory`, `agent-toolkit devcompanion`, `agent-toolkit project`, and `agent-toolkit swarm` as its primary CLI interface.

---

## 🏗️ Architecture

One source of truth, deployed per-tool. Each profile in `profiles/` adapts the shared skills and agents to the conventions of its target tool.

```text
agent-toolkit/
├── skills/              # 77 skills across 9 domains (SKILL.md frontmatter)
├── agents/              # 17 tool-agnostic agent persona definitions
├── profiles/
│   ├── claude-code/     # Plugin manifest, skill references, settings
│   ├── cursor/          # .mdc rule files per domain
│   ├── opencode/        # System prompt overlays, agent configs
│   ├── copilot/         # copilot-instructions.md with domain selection
│   ├── windsurf/        # rules.md and memory files
│   └── pi/              # Skill definitions in Pi's native format
├── loops/               # 10 recurring loop engineering templates
├── mcp/templates/       # 6 MCP config templates (JSON)
├── packs/               # 7 solution packs
├── catalogs/            # skill-catalog.yaml, agent-catalog.yaml
├── schemas/             # JSON schemas for validation
├── docs/                # How-to guides and reference docs
├── examples/            # Worked examples
└── scripts/             # Install and validation scripts
```

### Automation tiers

| Tier | Trigger | Example |
|------|---------|---------|
| **L1** | Observe / propose | `oss-triage`, `oss-daily-briefing`, `issue-triage` |
| **L2** | Controlled mutations | `ci-sweeper`, `pr-babysitter`, `dep-sweeper` |
| **L3** | High-autonomy (merge/close allowlist) | `oss-pr-monitor` |

---

## ✅ Validation

```bash
bash scripts/validate-skills.sh
bash scripts/validate-loops.sh
```

Both scripts exit non-zero on failure with human-readable error messages.
They run automatically in CI via the Validate and MegaLinter workflows.

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

[📖 Docs](docs/) · [🐛 Issues](https://github.com/ulises-jeremias/agent-toolkit/issues) ·
[💬 Discussions](https://github.com/ulises-jeremias/agent-toolkit/discussions) ·
[MIT License](LICENSE)

<sub>Built for the agentic age — one toolkit, every assistant.</sub>

</div>


## Showcase

See [SHOWCASE.md](SHOWCASE.md).