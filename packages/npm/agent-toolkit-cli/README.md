<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-cli

**The official CLI for [agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit)** — install skills, agents, loops, and MCP configs across every major AI coding assistant.

[![npm](https://img.shields.io/npm/v/agent-toolkit-cli?style=flat&labelColor=1f2937&color=7c3aed)](https://www.npmjs.com/package/agent-toolkit-cli)
[![Node](https://img.shields.io/node/v/agent-toolkit-cli?style=flat&labelColor=1f2937)](https://www.npmjs.com/package/agent-toolkit-cli)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![Validate](https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/validate.yml?branch=main&label=validate&style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml)

![skills](https://img.shields.io/badge/skills-77-7c3aed?style=flat&labelColor=1f2937)
![agents](https://img.shields.io/badge/agents-17-0891b2?style=flat&labelColor=1f2937)
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

`agent-toolkit-cli` on npm is the **Node adapter** for the agent-toolkit monorepo ([ADR-025](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm.md)). It is a **thin launcher** — no JavaScript business logic. The real CLI is the native **V** binary from [GitHub Releases](https://github.com/ulises-jeremias/agent-toolkit/releases/latest).

Same product name as [PyPI](https://pypi.org/project/agent-toolkit-cli/). Same binary. Different install channel.

```bash
npm install -g agent-toolkit-cli
agent-toolkit install
agent-toolkit doctor
```

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/architecture.svg?raw=true" width="88%" alt="agent-toolkit architecture">
</div>

---

## How the binary arrives

npm cannot ship one ELF for every OS the way pip ships platform-tagged wheels. Instead:

| Package | Role |
|---------|------|
| **`agent-toolkit-cli`** (this package) | Meta-package: `bin/agent-toolkit` → thin Node launcher |
| `agent-toolkit-cli-linux-x64` | glibc ELF (optionalDependency) |
| `agent-toolkit-cli-linux-arm64` | glibc ELF (optionalDependency) |
| `agent-toolkit-cli-darwin-arm64` | macOS arm64 Mach-O |
| `agent-toolkit-cli-darwin-x64` | macOS x86_64 Mach-O |
| `agent-toolkit-cli-win32-x64` | Windows PE |

On install, npm pulls the matching platform package via `optionalDependencies`. The launcher resolves that binary and spawns it with forwarded argv, stdio, signals, and exit code.

**Platform notes**

- Linux packages require **glibc** (ADR-019). Alpine/musl is not a MUST npm tag.
- Node **≥ 18**
- Dev override: `AGENT_TOOLKIT_BIN=/path/to/agent-toolkit`

---

## Quick start

```bash
# Global install (recommended for shells)
npm install -g agent-toolkit-cli
agent-toolkit install    # auto-detects Claude, Cursor, OpenCode, Windsurf, Pi, Copilot
agent-toolkit doctor

# Or project-local
npx agent-toolkit-cli doctor
```

### Other installers

```bash
# PyPI (same CLI name, platform wheels)
uvx --from agent-toolkit-cli agent-toolkit install
uv tool install agent-toolkit-cli

# System packages (release notify → dedicated taps)
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
yay -S agent-toolkit-bin   # Arch Linux (AUR)

# Direct binary
# https://github.com/ulises-jeremias/agent-toolkit/releases/latest
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
      <sub>77 skills across domains. Browse with <code>agent-toolkit inventory</code> or <code>agent-toolkit skills list</code>.</sub>
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Agents</h3>
      <sub>Personas that constrain <em>how</em> the AI works — review, plan, architect, fix CI — without rewriting prompts each time.</sub>
      <br><br>
      <sub>17 personas, compiled into each target's native format via <code>install</code>.</sub>
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

<div align="center">
<img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/loop-tiers.svg?raw=true" width="88%" alt="Loop autonomy tiers">
</div>

---

## Upgrade & uninstall

```bash
npm update -g agent-toolkit-cli
agent-toolkit update          # refresh deployed profiles
agent-toolkit uninstall       # remove toolkit-owned files via receipts

npm uninstall -g agent-toolkit-cli
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
| [ADR-025](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm.md) | npm topology (meta + optionalDeps) |
| [TRUST.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/TRUST.md) | Trust boundaries and supply chain |
| [Wiki](https://github.com/ulises-jeremias/agent-toolkit/wiki) | Extended reference |

Publish uses GitHub Actions OIDC trusted publishing (`.github/workflows/publish-npm.yml`) — no long-lived `NPM_TOKEN`.

Canonical sources live in the [agent-toolkit monorepo](https://github.com/ulises-jeremias/agent-toolkit). This package is the installable npm distribution of that source of truth.

---

## Requirements

- **Node.js** 18+
- Matching platform optionalDependency (installed automatically on supported OS/arch)
- At least one supported AI coding assistant (for `install` to deploy profiles)

---

## Contributing

Issues and PRs welcome on the monorepo:

- [Contributing guide](https://github.com/ulises-jeremias/agent-toolkit/blob/main/CONTRIBUTING.md)
- [Discord](https://discord.gg/bR5VyATgka)

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit
cd agent-toolkit
node packages/npm/agent-toolkit-cli/bin/agent-toolkit.js --help
# Dev: AGENT_TOOLKIT_BIN=/path/to/native/agent-toolkit
```

---

<div align="center">

**MIT** © [ulises-jeremias](https://github.com/ulises-jeremias) · [npm](https://www.npmjs.com/package/agent-toolkit-cli) · [GitHub](https://github.com/ulises-jeremias/agent-toolkit)

</div>
