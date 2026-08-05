<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-cli

**The official CLI for [agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit)** — install skills, agents, loops, and MCP configs across every major AI coding assistant.

[![PyPI](https://img.shields.io/pypi/v/agent-toolkit-cli?style=flat&labelColor=1f2937&color=7c3aed)](https://pypi.org/project/agent-toolkit-cli/)
[![Python](https://img.shields.io/pypi/pyversions/agent-toolkit-cli?style=flat&labelColor=1f2937)](https://pypi.org/project/agent-toolkit-cli/)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![Validate](https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/validate.yml?branch=main&label=validate&style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml)

![skills](https://img.shields.io/badge/skills-52-7c3aed?style=flat&labelColor=1f2937)
![agents](https://img.shields.io/badge/agents-16-0891b2?style=flat&labelColor=1f2937)
![loops](https://img.shields.io/badge/loops-10-ea580c?style=flat&labelColor=1f2937)

[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-7c3aed?style=flat&labelColor=1f2937&logo=anthropic&logoColor=white)](https://github.com/ulises-jeremias/agent-toolkit/tree/main/profiles/claude-code)
[![Cursor](https://img.shields.io/badge/Cursor-rules-0891b2?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/tree/main/profiles/cursor)
[![OpenCode](https://img.shields.io/badge/OpenCode-agents-ea580c?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/tree/main/profiles/opencode)
[![Copilot](https://img.shields.io/badge/GitHub%20Copilot-instructions-16a34a?style=flat&labelColor=1f2937&logo=github&logoColor=white)](https://github.com/ulises-jeremias/agent-toolkit/tree/main/profiles/copilot)
[![Windsurf](https://img.shields.io/badge/Windsurf-rules-2563eb?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/tree/main/profiles/windsurf)
[![Pi](https://img.shields.io/badge/Pi%20Agent-skills-db2777?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/tree/main/profiles/pi)

[Monorepo](https://github.com/ulises-jeremias/agent-toolkit) ·
[Docs](https://github.com/ulises-jeremias/agent-toolkit/tree/main/docs) ·
[Installation](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md) ·
[CLI surfaces](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/CLI_SURFACES.md) ·
[Changelog](https://github.com/ulises-jeremias/agent-toolkit/blob/main/CHANGELOG.md)

</div>

---

## What is this package?

`agent-toolkit-cli` is the **published Python entrypoint** for the agent-toolkit monorepo. It ships:

- the `agent-toolkit` / `agent-toolkit-cli` console scripts
- bundled skills, agents, loops, profiles, packs, and MCP templates
- install / doctor / sync workflows that deploy the right artifacts per AI tool

One CLI. Any coding assistant. Zero duplication.

```bash
uvx --from agent-toolkit-cli agent-toolkit install
agent-toolkit doctor
```

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/architecture.svg?raw=true" width="88%" alt="agent-toolkit architecture">
</div>

---

## Quick start

**Recommended:** [uv](https://docs.astral.sh/uv/) — no permanent install required.

```bash
# One-shot (preferred)
uvx --from agent-toolkit-cli agent-toolkit install
uvx --from agent-toolkit-cli agent-toolkit doctor

# Or install the CLI persistently
uv tool install agent-toolkit-cli
agent-toolkit install    # auto-detects Claude, Cursor, OpenCode, Windsurf, Pi, Copilot
agent-toolkit doctor
```

### Other installers

```bash
pip install agent-toolkit-cli
pipx install agent-toolkit-cli

# System packages (release notify → dedicated taps)
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
yay -S agent-toolkit   # Arch Linux (AUR)
```

Full walkthrough: [docs/INSTALLATION.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md)

---

## Key concepts

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🛠️ Skills</h3>
      <sub>Reusable capability units (<code>SKILL.md</code>) that teach an agent how to do a job — delivery, forge CLIs, design, data, ops.</sub>
      <br><br>
      <sub>52 skills across 9 domains. Browse with <code>agent-toolkit inventory</code> or <code>agent-toolkit skills list</code>.</sub>
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Agents</h3>
      <sub>Personas that constrain <em>how</em> the AI works — review, plan, architect, fix CI — without rewriting prompts each time.</sub>
      <br><br>
      <sub>16 personas, compiled into each target's native format via <code>install</code>.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Loops</h3>
      <sub>Recurring agentic workflows with mutation-safety tiers (L1 observe → L2 controlled → L3 high autonomy).</sub>
      <br><br>
      <sub><code>agent-toolkit loop run daily-triage</code> · 10 bundled templates</sub>
    </td>
    <td width="50%" valign="top">
      <h3>🔗 MCP</h3>
      <sub>Provider registry + ready templates (GitHub, Slack, Notion, Linear, Figma, ClickUp) emitted into target-native configs.</sub>
      <br><br>
      <sub><code>agent-toolkit mcp list</code> · <code>mcp setup &lt;provider&gt;</code> · <code>mcp doctor</code></sub>
    </td>
  </tr>
</table>

---

## Supported tools

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/tools-grid.svg?raw=true" width="96%" alt="Supported AI tools grid">
</div>

| Tool | What `install` deploys |
|------|------------------------|
| **Claude Code** | Plugin manifest, skill references, settings |
| **Cursor** | Marketplace plugins + `.mdc` rules (IDE + Agent CLI) |
| **OpenCode** | System prompt overlays, agent configs |
| **GitHub Copilot** | `copilot-instructions.md` with domain selection |
| **Windsurf** | Rules and memory files via Cascade (`~/.codeium/windsurf/`) |
| **Pi Agent** | Skills and loop templates in Pi's native format |

```bash
# Target specific tools
agent-toolkit install --tools claude-code,cursor
agent-toolkit install --dry-run
agent-toolkit install --force
```

---

## Command reference

Everyday **consumer** commands vs **advanced** workstation / harness commands.
Details: [docs/CLI_SURFACES.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/CLI_SURFACES.md)

### Consumer

| Command | Purpose |
|---------|---------|
| `install` | Install profiles for detected or selected AI tools |
| `update` | Refresh installed profiles from latest toolkit data |
| `uninstall` | Remove toolkit-owned files using install receipts |
| `doctor` | Check toolkit data and tool availability |
| `diff` | Show changes vs currently installed plugin bundles |
| `skills` | Sync, list, and validate skills |
| `mcp` | MCP provider setup, health, doctor, uninstall |
| `plugin` | Plugin bundle sync and check |

```bash
agent-toolkit skills list
agent-toolkit skills sync --tools claude-code,cursor
agent-toolkit mcp setup github
agent-toolkit doctor --fix
```

### Advanced

Still on the same binary — start here when running an [agentic-harness](https://github.com/ulises-jeremias/agentic-harness)-style workspace:

| Command | Purpose |
|---------|---------|
| `loop` | Loop engineering: init, run, status, audit, cost, schedule, sync |
| `workspace` | Workspace scaffolding: init, context, personas, packs |
| `memory` | Knowledge base: add, search, inject, review, todo |
| `project` | Project index: clone, list, add, remove, scan |
| `devcompanion` | Background job queue (`dc` alias) |
| `insights` | Local usage analytics (OpenCode, Cursor, Claude) |
| `inventory` | List skills, agents, and products |
| `matrix` | Platform capability matrix |
| `build` / `release` | Compile / release artifacts (maintainer) |

```bash
# Loops (mutation-safety tiers L1 → L3)
agent-toolkit loop init daily-triage
agent-toolkit loop run daily-triage
agent-toolkit loop status
agent-toolkit loop audit daily-triage

# Workspace harness
agent-toolkit workspace init --dir ~/.agentic-harness
agent-toolkit memory search "topic"
agent-toolkit project clone owner/my-repo
agent-toolkit inventory
```

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/loop-tiers.svg?raw=true" width="88%" alt="Loop autonomy tiers">
</div>

| Tier | Posture | Examples |
|------|---------|----------|
| **L1** | Observe / propose (report-only) | `oss-daily-briefing`, `daily-triage`, `oss-triage` |
| **L2** | Controlled mutations (PR-gated) | `ci-sweeper`, `dep-sweeper`, `pr-babysitter` |
| **L3** | High autonomy (allowlist) | `oss-pr-monitor` |

---

## Optional dependencies

```bash
# YAML-backed pack / catalog features
uv tool install "agent-toolkit-cli[yaml]"

# Everything optional
uv tool install "agent-toolkit-cli[all]"
```

| Extra | Provides |
|-------|----------|
| `yaml` | `PyYAML` for pack overlays and richer catalog parsing |
| `all` | Currently same as `yaml` |
| `dev` | `pytest`, `ruff` (contributors) |

---

## Upgrade & uninstall

```bash
uv tool upgrade agent-toolkit-cli
agent-toolkit update          # refresh deployed profiles
agent-toolkit uninstall       # remove toolkit-owned files via receipts

uv tool uninstall agent-toolkit-cli
# or: pip uninstall agent-toolkit-cli
```

→ [docs/UNINSTALL.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/UNINSTALL.md)

---

## Ecosystem

`agent-toolkit` is the **capability distribution layer (L1.5)** in a personal DX stack:

| Layer | Repo | Role |
|-------|------|------|
| **L1** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5** | **agent-toolkit** (this CLI) | Skills, loops, profiles, MCP |
| **L3** | [agentic-harness](https://github.com/ulises-jeremias/agentic-harness) | AI workspace scaffold — memory, personas, multi-repo orchestration |

---

## Documentation

| Guide | Description |
|-------|-------------|
| [README (monorepo)](https://github.com/ulises-jeremias/agent-toolkit#readme) | Full product overview, skills, agents, packs |
| [INSTALLATION.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md) | Install paths per tool |
| [CLI_SURFACES.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/CLI_SURFACES.md) | Consumer vs advanced commands |
| [LOOPS.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/LOOPS.md) | Loop engineering reference |
| [TRUST.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/TRUST.md) | Trust boundaries and supply chain |
| [COMPATIBILITY.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/COMPATIBILITY.md) | Python / tool matrix |
| [Wiki](https://github.com/ulises-jeremias/agent-toolkit/wiki) | Extended reference |

Canonical sources live in the [agent-toolkit monorepo](https://github.com/ulises-jeremias/agent-toolkit). This package is the installable distribution of that source of truth.

---

## Requirements

- **Python** 3.10+
- Optional: [uv](https://docs.astral.sh/uv/) for `uvx` / `uv tool` workflows
- At least one supported AI coding assistant (for `install` to deploy profiles)

---

## Contributing

Issues and PRs welcome on the monorepo:

- [Contributing guide](https://github.com/ulises-jeremias/agent-toolkit/blob/main/CONTRIBUTING.md)
- [Discord](https://discord.gg/bR5VyATgka)
- Package changelog: [`CHANGELOG.md`](https://github.com/ulises-jeremias/agent-toolkit/blob/main/packages/agent-toolkit-cli/CHANGELOG.md)

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit
cd agent-toolkit
uv sync
uv run agent-toolkit --help
```

---

<div align="center">

**MIT** © [ulises-jeremias](https://github.com/ulises-jeremias) · [PyPI](https://pypi.org/project/agent-toolkit-cli/) · [GitHub](https://github.com/ulises-jeremias/agent-toolkit)

</div>
