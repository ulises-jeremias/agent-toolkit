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
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
[![Discord](https://img.shields.io/discord/1527933660764831825?style=flat&label=Discord&labelColor=1f2937&logo=discord&logoColor=white&color=5865F2)](https://discord.gg/bR5VyATgka)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-16a34a?style=flat&labelColor=1f2937)](https://github.com/vercel-labs/skills)
[![Agent Plugins](https://img.shields.io/badge/Agent%20Plugins-1.0-7c3aed?style=flat&labelColor=1f2937)](https://agent-plugins.org)

[![npm](https://img.shields.io/npm/v/agent-toolkit-cli?style=flat&label=npm&labelColor=1f2937&color=7c3aed&logo=npm&logoColor=white)](https://www.npmjs.com/package/agent-toolkit-cli)
[![npm downloads](https://img.shields.io/npm/dm/agent-toolkit-cli?style=flat&label=npm%20downloads&labelColor=1f2937&color=0891b2)](https://www.npmjs.com/package/agent-toolkit-cli)
[![PyPI](https://img.shields.io/pypi/v/agent-toolkit-cli?style=flat&label=PyPI&labelColor=1f2937&color=7c3aed&logo=pypi&logoColor=white)](https://pypi.org/project/agent-toolkit-cli/)
[![PyPI downloads](https://img.shields.io/pypi/dm/agent-toolkit-cli?style=flat&label=PyPI%20downloads&labelColor=1f2937&color=0891b2)](https://pypi.org/project/agent-toolkit-cli/)
[![AUR](https://img.shields.io/aur/version/agent-toolkit-bin?style=flat&label=AUR&labelColor=1f2937&logo=archlinux&logoColor=white)](https://aur.archlinux.org/packages/agent-toolkit-bin)
[![Homebrew](https://img.shields.io/badge/Homebrew-ulises--jeremias%2Ftap-ea580c?style=flat&labelColor=1f2937&logo=homebrew&logoColor=white)](https://github.com/ulises-jeremias/homebrew-tap)
[![GHCR](https://img.shields.io/badge/GHCR-agent--toolkit-2563eb?style=flat&labelColor=1f2937&logo=docker&logoColor=white)](https://github.com/ulises-jeremias/agent-toolkit/pkgs/container/agent-toolkit)

[![GitHub stars](https://img.shields.io/github/stars/ulises-jeremias/agent-toolkit?style=flat&label=stars&labelColor=1f2937&color=facc15&logo=github)](https://github.com/ulises-jeremias/agent-toolkit/stargazers)
[![commits since latest release](https://img.shields.io/github/commits-since/ulises-jeremias/agent-toolkit/latest?style=flat&label=commits&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/commits/main)
[![contributors](https://img.shields.io/github/contributors/ulises-jeremias/agent-toolkit?style=flat&label=contributors&labelColor=1f2937&color=0891b2)](https://github.com/ulises-jeremias/agent-toolkit/graphs/contributors)

[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-7c3aed?style=flat&labelColor=1f2937&logo=anthropic&logoColor=white)](profiles/claude-code/)
[![Cursor](https://img.shields.io/badge/Cursor-rules-0891b2?style=flat&labelColor=1f2937)](profiles/cursor/)
[![OpenCode](https://img.shields.io/badge/OpenCode-agents-ea580c?style=flat&labelColor=1f2937)](profiles/opencode/)
[![Copilot](https://img.shields.io/badge/GitHub%20Copilot-instructions-16a34a?style=flat&labelColor=1f2937&logo=github&logoColor=white)](profiles/copilot/)
[![Windsurf](https://img.shields.io/badge/Windsurf-rules-2563eb?style=flat&labelColor=1f2937)](profiles/windsurf/)
[![Pi](https://img.shields.io/badge/Pi%20Agent-skills-db2777?style=flat&labelColor=1f2937)](profiles/pi/)
[![Muse Code](https://img.shields.io/badge/Muse%20Code-skills-ff6b35?style=flat&labelColor=1f2937)](https://developer.meta.com/ai/products/muse-code/)

[Documentation](docs/) ·
[Quick Install](#-quick-install) ·
[Skills](#%EF%B8%8F-skills--catalog-via-agent-toolkit-inventory) ·
[Agents](#-agent-personas) ·
[Loops](#-loop-engineering) ·
[Swarm](#-swarm-orchestration) ·
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
      <sub>Skills across 14 domains — live count via <code>agent-toolkit inventory</code> · Browse <code>skills/</code>.</sub>
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Agents</h3>
      <sub>Personas that constrain <em>how</em> the AI works in a session — review, plan, architect, fix CI — without rewriting your prompts each time.</sub>
      <br><br>
      <sub>Personas under <code>agents/</code>, compiled into each target's native format — see <code>agent-toolkit inventory</code>.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Loops</h3>
      <sub>Recurring agentic workflows with mutation-safety Stages (L1 observe → L2 controlled → L3 high autonomy).</sub>
      <br><br>
      <sub><code>agent-toolkit loop run daily-triage</code> · templates in <code>loops/</code> — see <code>agent-toolkit inventory</code></sub>
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
      <sub>Provider registry + ready templates (GitHub, Slack, Notion, Linear, Figma, ClickUp, Chrome DevTools) emitted into target-native MCP configs.</sub>
      <br><br>
      <sub>7 providers · <code>mcp/registry/</code> · <code>mcp/templates/</code> · <code>agent-toolkit mcp</code></sub>
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

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/quickstart.svg?raw=true" width="86%" alt="agent-toolkit quickstart: install, doctor, swarm" />
</div>

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
<summary><strong>Homebrew / AUR / GHCR</strong> — system packages and container</summary>

Formulas live in dedicated repos ([homebrew-tap](https://github.com/ulises-jeremias/homebrew-tap), [aur-packages](https://github.com/ulises-jeremias/aur-packages)); release workflows notify them on tag. The container image ships the same GitHub Release V binary.

```bash
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
yay -S agent-toolkit-bin   # Arch Linux (AUR) — GitHub Release V binary; not the Python AUR package
npm i -g agent-toolkit-cli # optionalDependencies platform packages
docker pull ghcr.io/ulises-jeremias/agent-toolkit
```

</details>

<details>
<summary><strong>Git clone + install script</strong> — offline or pinned commit</summary>

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
./make.vsh install-cli    # canonical V binary → ~/.local/bin (or --prefix=…)
agent-toolkit install
```

Prefer `./make.vsh install-cli` or a release channel above ([ADR-007](docs/adrs/ADR-007-install-sh-deprecation.md) removed the deprecated `scripts/install.sh` wrapper).

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
| **Muse Code** | CLI | Agent Skills under `~/.config/muse/skills/` |

---

## 🛠️ Skills — catalog via `agent-toolkit inventory`

All skills use `SKILL.md` frontmatter only — no `skill.json` required. Fully compliant with the [Agent Skills spec](https://github.com/vercel-labs/skills). Live counts: `agent-toolkit inventory` / `catalogs/skill-catalog.yaml` (source of truth, not README badges). Marketplace plugins ship a subset (core + forge); `agent-toolkit-complete` is the full catalog.

| Domain | Key Skills |
|--------|------------|
| 🧠 `core` | assistant, dev-companion, workspace, project, onboarding |
| 🚀 `delivery` | adr, bug, epic, development-workflow, planning, prd, user-story, work-item |
| 🎨 `design` | figma-implement-design, figma-code-connect-components, frontend-design |
| ⚡ `forge` | github-cli-workflow, gitlab-cli-workflow, gh-fix-ci, worktree |
| 🔗 `integrations` | slack-cli, slack-assistant, linear, clickup-cli, mcp, jira-*, confluence-* |
| 📊 `data` | dbt-validation, snowflake-validation |
| 🔧 `tooling` | jupyter-notebook, playwright-cli, herdr, inventory |
| 🛡️ `ops` | triage, docs-generator, llm-cost-advisor, swarm |
| 🔄 `loops` | loop-runner (see [Loop Engineering](#-loop-engineering) for 10 templates) |
| 🔐 `agentic-security` | threat-modeling, owasp-agentic-review, mcp-audit |
| ☁️ `cloud` | cloud-design-patterns, aws-well-architected-review |
| 🏛️ `architecture` | architecture-diagram, c4-model |
| ♿ `accessibility` | review |
| ✅ `quality` | megalinter, megalinter-setup, megalinter-check, megalinter-fix, codeql, blast-radius |

Browse the full catalog: [`catalogs/skill-catalog.yaml`](catalogs/skill-catalog.yaml) · **membership matrix** [`docs/SKILL_PRODUCT_MATRIX.md`](docs/SKILL_PRODUCT_MATRIX.md) (`scripts/generate-skill-matrix.vsh --check` in CI) · regenerate with `./scripts/validate-skills.vsh` (CI) and inspect live inventory via `agent-toolkit inventory` (counts shown in badges above are generic — use inventory for accurate numbers)

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

Tool-agnostic agent persona definitions in `agents/` (live count: `agent-toolkit inventory` / `catalogs/agent-catalog.yaml`). Any supported AI coding assistant can import these via its profile config. Canonical taxonomy: [`docs/AGENT_TAXONOMY.md`](docs/AGENT_TAXONOMY.md).

### Holistic roster — the daily set (11)

Every skill's `holistic_owner` in `capabilities/skills/registry.yaml` is one of these. Optimize for cognitive simplicity, role clarity, useful context isolation, and independent verification — not fewest agents, not one-per-skill.

| Persona | Responsibility | Main skill domains |
|---------|---------------|--------------------|
| 🤝 `assistant` | **Orchestrator** — intent → context → proportional delegation → synthesis | `core/*`, discovery, `output-handshake` |
| 📋 `planner` | Decomposition, PRD/TRD, work items, estimation, capacity | `delivery` (11 inc. `planning`, `project-assessment`, `workflow-generic-project`) |
| 🏗️ `architect` | System design, tradeoffs, C4, ADRs/TRDs, cloud patterns | `architecture` (2), `cloud` (2), `delivery` (adr/trd/decision-log/technical-assessment), `tooling/mermaid` |
| 🎨 `designer` | Visual direction, UX, Figma, design system, a11y — contextual routing | `design` (10), `accessibility/review` |
| 🔨 `implementer` | Feature/bug/refactoring delivery, build/test loop, docs generation | `delivery/task`, `ops/docs-generator` |
| 🔍 `reviewer` | Independent quality/craft, change-safety, anti-slop (`blast-radius`, `deep-review`, `deslop`, `unslop`) | `quality` (4) |
| 🧪 `qa-engineer` | Behavioral verification, lint gates, browser automation, E2E, bug triage | `quality/megalinter*` (4), `tooling/playwright-cli`, `tooling/chrome-devtools`, `delivery/bug` |
| 🔒 `security-engineer` | App + agentic hardening, threat modeling, supply-chain/MCP, CodeQL | `agentic-security/*` (4), `quality/codeql` |
| ⚙️ `platform-engineer` | CI/CD, GitHub/GitLab PR lifecycle, worktrees, integrations, loops/swarm, triage, cost | `forge/*` (7), `integrations/*` (5), `loops/loop-runner`, `ops/swarm*`, `tooling/cli-for-agents` |
| 🔬 `researcher` | Spikes, single evidence-intake map (`project-assessment-evidence`), framework/docs exploration | `delivery/spike`, `delivery/project-assessment-evidence` |
| 🗄️ `data-engineer` | dbt/Snowflake read-only validation, notebook scaffolding (conditional — data repos only) | `data/dbt-validation`, `data/snowflake-validation`, `tooling/jupyter-notebook` |

**Orchestrator** (not in daily count): `client-workflow-bootstrap` — meta-generates `<client>` packs/knowledge into `~/.ai-workspace` (interview-driven; not a delivery persona).

**Specialists (6 opt-in, archived 7 → `references/` #865):** `code-reviewer`, `security-reviewer` + `agentic-security-reviewer`, `e2e-runner`, `tdd-guide`, `build-error-resolver` — kept per the agent-vs-skill rule (independent verification, disjoint surface, noisy output, large diagnostic context). Archived specialists live on as inline references (`reviewer/references/`, `researcher/references/LOOKUP_GUIDE.md`, `platform-engineer/references/WORKSTATION_OPS.md`) — no knowledge deleted. Full migration map and routing chains: [`docs/AGENT_TAXONOMY.md`](docs/AGENT_TAXONOMY.md) §3/§8.

Full catalog: [`catalogs/agent-catalog.yaml`](catalogs/agent-catalog.yaml) · taxonomy: [`docs/AGENT_TAXONOMY.md`](docs/AGENT_TAXONOMY.md) · routing: [`docs/SKILL_ROUTING.md`](docs/SKILL_ROUTING.md) · personas on disk under `agents/` (see inventory)

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

| Template | Tier (Stage) | Default Cadence | Description |
|----------|--------------|-----------------|-------------|
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

> **Stage vs Layer:** Loop tiers `L1`/`L2`/`L3` are mutation-safety **Stages** (Loop Engineering discipline), not ownership Layers. See `docs/ARCHITECTURE.md` for the `L1` Machine / `L1.5` Toolkit / `L3` Workspace layer model.

Each loop template lives in `loops/<name>/` (see `agent-toolkit inventory` for live count) with a `loop.yaml` definition (prompt in `request:`). At runtime the runner writes `STATE.md` and `report.md` under that directory.

---

## 🐝 Swarm Orchestration

One command turns a task into a coordinated multi-agent run — git worktree per writer,
filesystem state-of-truth, budgets, and human approval gates.

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/swarm.svg?raw=true" width="88%" alt="agent-toolkit swarm: task → recipes → backends → worktrees → handoffs → promote" />
</div>

```bash
agent-toolkit swarm recipes                   # pair / team / full — personas + policy + budget per recipe
agent-toolkit swarm start --recipe pair --dry-run "Add a health check endpoint with tests"
agent-toolkit swarm start --recipe team --backend herdr "Migrate the auth module"
agent-toolkit swarm watch <run-id>            # observability: report / artifacts / handoffs / logs / approvals
agent-toolkit swarm promote <run-id>          # integrator merges, run moves to cleanup
```

| | agent-toolkit swarm | classic tmux swarms ([swarm-forge](https://github.com/unclebob/swarm-forge)) | legacy Python swarm |
|---|---|---|---|
| Recipes (personas + policy per role) | ✅ built-in `pair`/`team`/`full` | ✅ per-branch packs | ⚠️ manual |
| Budget enforcement (tokens / $ / wall-clock) | ✅ per-recipe (pair/team `900k / $4 / 7200s`, full `1.2M / $8 / 10800s`), `budget_exhausted` state | ❌ | ❌ |
| Handoff audit gate | ✅ `AUDIT_REQUIRED` → identical re-run passes | ✅ first-class | ❌ |
| Blocking feedback with round-trip limit | ✅ `--blocking` (limit 2) | ⚠️ approval cards | ❌ |
| Observability (watch / report / artifacts / logs / approvals) | ✅ CLI + `--json` | ✅ web cockpit | ⚠️ log files |
| Single static binary, offline-first | ✅ V, ~22 MB, no runtime deps | ❌ bash + tmux + bb + dashboard | ❌ Python env |
| JSON API / programmatic surface | ✅ `serve` + `swarm --json` everywhere | ⚠️ HTTP dashboard only | ❌ |
| Cross-platform | ✅ linux/macOS/windows binaries + brew/AUR/npm/PyPI | ⚠️ macOS-first | ⚠️ |

> Full protocol: [docs/v/swarm.md](docs/v/swarm.md) · ADR-008 (filesystem SoT) · ADR-020 (UI fail-closed)

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
| `chrome-devtools` | Browser automation and page inspection |

Templates live in [`mcp/templates/`](mcp/templates/) (7 providers). Each file is a `.json` with clearly marked placeholder values.

---

## 📦 Plugins — Agent Plugins 1.0 Portable

> **New:** Every plugin in [`plugins/`](./plugins/) now ships as an **Agent Plugins 1.0** portable bundle (`plugin.json` + `skills/` + `mcp.json`) for **Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, Kiro** — plus legacy `.claude-plugin/` for **Claude Code** (dual emit until Claude supports the spec). See [docs/AGENT_PLUGINS.md](docs/AGENT_PLUGINS.md).

Product bundles are declared in [`distributions/products.yaml`](distributions/products.yaml). Four products are built for every compatible client; three ship in the Claude Code and Cursor marketplaces:

| Product | Portable (Agent Plugins 1.0) | What's included |
|---------|------------------------------|-----------------|
| `agent-toolkit-core` | `plugin.json` + `skills/` (6) + `mcp.json` (github) | 6 core skills (`assistant`, `dev-companion`, `output-handshake`, `pr-fallback`, `workspace-knowledge-sync`, `onboarding`), `code-reviewer` agent, `session-start-context` hook, GitHub MCP |
| `agent-toolkit-agents` | `plugin.json` + `agents/` via `com.anthropic.claude-code` extension | 16 marketplace personas (disk has 17; `agentic-security-reviewer` is not in this plugin) |
| `agent-toolkit-forge` | `plugin.json` + `skills/` (7) | 7 forge skills — `github-cli-workflow`, `gitlab-cli-workflow`, `gh-address-comments`, `gh-fix-ci`, `gh-contribution-planner`, `workflow-client-bootstrap`, `workflow-generic-project` |
| `agent-toolkit-complete` | `plugin.json` + `skills/` (full catalog) + `mcp.json` | Full skill catalog (experimental; portable manifest included, marketplace pending) — count via `agent-toolkit inventory` |

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

`agent-toolkit` is the **Capability + Runtime layer (L1.5)** in a four-layer ownership stack. It exposes two internal planes (Capability and Runtime) that share one binary and one release — see `docs/ARCHITECTURE.md`. Companion repos:

| Layer | Repo | Role |
|-------|------|------|
| **L1 — Machine** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5 — Toolkit** | **agent-toolkit** (this repo) | Capability + Runtime — skills, agents, MCP, plugins, plus workspace/memory/project/loop/devcompanion/swarm (`docs/ARCHITECTURE.md` planes) |
| **L3 — Workspace** | [agentic-harness](https://github.com/ulises-jeremias/agentic-harness) | AI workspace scaffold for multi-repo orchestration |
| **Project Overlay** | per-repo | Per-project `AGENTS.md`, `.cursor/rules/`, local `loops/` — highest precedence |

> **Stages vs Layers:** `L0`–`L3` in Context/Harness/Loop Engineering is discipline **Stages** (mutation-safety / capability maturity), not ownership **Layers** `L1`/`L1.5`/`L3`. See `docs/ARCHITECTURE.md` terminology note and `docs/LOOPS.md` tier Stages. Loop tier `L1`/`L2`/`L3` below is Stages, not Layers.

**agentic-workstation** installs the V CLI during `chezmoi apply` (Homebrew, AUR `agent-toolkit-bin`, GitHub Release, or the PyPI launcher). Running `agent-toolkit install` deploys skills and profiles to all detected AI tools.

**agentic-harness** is an opinionated workspace scaffold that uses `agent-toolkit loop`, `agent-toolkit memory`, `agent-toolkit devcompanion`, `agent-toolkit project`, and `agent-toolkit swarm` as its primary CLI interface.

---

## 🏗️ Architecture

One source of truth, deployed per-tool. See `docs/ARCHITECTURE.md` for ownership Layers `L1`/`L1.5`/`L3` + Project Overlay and the two internal planes (Capability vs Runtime, ADR-015 / ADR-026). `plugins/` is canonical compiler output; `profiles/` is a deprecated install overlay (ADR-004).

```text
agent-toolkit/                 # L1.5 Toolkit — two planes, one binary
├── skills/                    # Capability: SKILL.md by domain (inventory is SoT)
├── agents/                    # Capability: tool-agnostic persona definitions
├── plugins/                   # Capability: compiler output — canonical (build --check)
├── profiles/                  # Capability: deprecated overlay — fallback only (ADR-004)
├── distributions/             # Capability: products.yaml composition SoT (compiler input)
├── distribution/              # Capability: channel contracts (aur/docker/homebrew/npm/pypi)
├── mcp/templates/             # Capability: provider templates + registry
├── packs/                     # Capability: docs-only packs (ADR-006)
├── loops/                     # Runtime: loop templates (inventory is SoT)
├── catalogs/                  # generated — skill/agent/loop catalogs
├── schemas/                   # JSON schemas for validation
├── modules/                   # V CLI — Capability + Runtime planes
├── docs/                      # How-to guides and reference docs
├── examples/                  # Worked examples
└── scripts/                   # Install and validation scripts
```
Live counts: `agent-toolkit inventory` (not hardcoded).

### Automation Stages (Loop Engineering)

> **Stage vs Layer:** `L1`/`L2`/`L3` below are **Stages** (Loop Engineering mutation-safety), not ownership Layers.

| Stage | Mutation posture | Example |
|-------|------------------|---------|
| **L1** | Observe / propose | `oss-triage`, `oss-daily-briefing`, `issue-triage` |
| **L2** | Controlled mutations | `ci-sweeper`, `pr-babysitter`, `dep-sweeper` |
| **L3** | High-autonomy (merge/close allowlist) | `oss-pr-monitor` |

---

## ✅ Validation

```bash
agent-toolkit doctor          # consumer health check
./scripts/validate-skills.vsh
./scripts/validate-loops.vsh
```

The `.vsh` validators exit non-zero on failure with human-readable error messages.
They run automatically in CI via the Validate workflow.
Contributors: [`CONTRIBUTING.md`](CONTRIBUTING.md) (`./make.vsh test`, `./make.vsh build-cli`).

---

## 🤝 Contributing

Contributions welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

1. Fork the repo and create a branch: `feat/my-skill`
2. Add your skill under the appropriate domain in `skills/` — use `SKILL.md` frontmatter only
3. Run `./scripts/validate-skills.vsh` — all checks must pass
4. Open a PR with a clear description of what the skill does and which tools it supports

See [How to add a skill](docs/HOW_TO_ADD_SKILL.md) for the full authoring guide.

---

## Showcase

See [SHOWCASE.md](SHOWCASE.md) for community usage examples and pack walkthroughs.

---

<div align="center">

**⭐ Star this repo** if you use it — it helps others discover it.

[Report a bug](https://github.com/ulises-jeremias/agent-toolkit/issues/new?template=bug-report.yml) · [Request a feature](https://github.com/ulises-jeremias/agent-toolkit/issues/new?template=feature-request.yml)

[📖 Docs](docs/) · [📜 Changelog](CHANGELOG.md) · [🔒 Security](SECURITY.md) · [💬 Discussions](https://github.com/ulises-jeremias/agent-toolkit/discussions) · [Discord](https://discord.gg/bR5VyATgka) · [MIT License](LICENSE)

<sub>Built with ❤️ for AI-assisted software delivery</sub>

</div>

## 👥 Contributors

<a href="https://github.com/ulises-jeremias/agent-toolkit/contributors">
  <img alt="Contributors" src="https://contrib.rocks/image?repo=ulises-jeremias/agent-toolkit"/>
</a>

Made with [contributors-img](https://contrib.rocks).
