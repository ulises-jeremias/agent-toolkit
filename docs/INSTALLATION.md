# Installation

This guide describes the **primary consumer install flow** for agent-toolkit, then
lists advanced methods when you need marketplace plugins, skills-only delivery, or
manual file copies.

---

## Prerequisites

The product CLI is the **native V binary** (GitHub Releases). `uvx agent-toolkit-cli` / PyPI still wrap that binary ([ADR-021](adrs/ADR-021-pypi-binary.md)). Index: [`docs/v/README.md`](v/README.md). Contributor build: [`docs/HOW_TO_DEVELOP_V.md`](HOW_TO_DEVELOP_V.md).

- **Python** 3.10 or later — **optional** unless you use the PyPI launcher / `agent-toolkit-py` fallback (`uv` / `uvx`)
- At least one supported AI coding assistant:
  - [Claude Code](https://claude.ai/code) (Anthropic)
  - [Cursor](https://cursor.sh)
  - [OpenCode](https://opencode.ai)
  - [GitHub Copilot](https://github.com/features/copilot) (VS Code or JetBrains + extension)
  - [Windsurf](https://codeium.com/windsurf) (Codeium)
  - [Pi Coding Agent](https://pi.ai)
  - [Muse Code](https://developer.meta.com/ai/products/muse-code/) (Meta)

Optional but recommended:

- **[uv](https://docs.astral.sh/uv/)** — preferred way to run `uvx` and manage the CLI
- **gh** (GitHub CLI) — required by forge skills (`gh-fix-ci`, `github-cli-workflow`, etc.)
- **jq** — used by several loop templates for JSON processing
- **node** / **npm** — for MCP server installation and `npx skills`
- **git** + **bash** — only needed for git-clone or install-script methods below

#### Swarms — `agent-toolkit swarm` prerequisites

Swarms are backend-neutral: the orchestration engine is filesystem-based, no cloud required. You need a **UI backend** and a **runner**:

- **UI backend (one required):**
  - **[Herdr](https://herdr.dev/docs/install/)** — recommended. Rich workspace/tabs UI: `brew install herdr` or `curl -fsSL https://herdr.dev/install.sh | sh`. Verify `herdr --version` and `herdr integration install opencode`. See [SWARM_HERDR.md](SWARM_HERDR.md).
  - **`tmux`** — portable fallback, works over SSH/headless Linux. Install `tmux` via your package manager (`brew install tmux`, `apt install tmux`, etc.). Swarm uses an isolated server/socket per run `agent-toolkit-swarm-<run-id>` and never mutates your normal tmux sessions. See [SWARM_TMUX.md](SWARM_TMUX.md).
  - Use `--ui auto` (Herdr → tmux fallback) or explicitly `--ui herdr` / `--ui tmux` / `--ui headless`. `swarm doctor` reports `herdr available`, `tmux available`, versions, and `opencode integration installed/outdated`.
- **Runner (one required — provides the LLM):**
  - **[OpenCode](https://opencode.ai)** — primary recommended runner (`opencode models` to list `provider/model`). Alternatives: `claude`, `codex`, `cursor-agent`, `copilot`, `muse`. Discover via `agent-toolkit swarm models --runner opencode` or `agent-toolkit swarm runners`. See [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md).
  - **Offline/fake demo:** no runner or Herdr needed — use `--runner skeleton` (always available) and `swarm plan` is side-effect free. Example: `agent-toolkit swarm start --runner skeleton --ui tmux "demo task"` or `agent-toolkit swarm plan --runner skeleton "demo"` for CI/air-gapped exploration.
- **Git:** required for worktree isolation. Each writing role gets `worktrees/<role>` on branch `agent-toolkit-swarm/<run-id>/<role>`; code moves via validated full 40-char SHAs.
- **Agentic-workstation auto-provision:** if you use [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation), set `agent_swarms.enabled=true` to install tmux + Herdr + integrations automatically.

Check everything at once:

```bash
agent-toolkit swarm doctor
agent-toolkit swarm doctor --json
agent-toolkit swarm backends --json
agent-toolkit swarm runners --json
```

---

## Primary install (recommended)

One command auto-detects your AI tools and deploys the right profiles. Pick **one** channel — all install the same V CLI.

```bash
# Homebrew
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
# AUR (native V; not the Python AUR package)
yay -S agent-toolkit-bin
# GitHub Release — download agent-toolkit-<os>-<arch> + SHA256SUMS from
# https://github.com/ulises-jeremias/agent-toolkit/releases/latest
# PyPI launcher (execs bundled V)
uv tool install 'agent-toolkit-cli>=1.11.0'
# npm
npm i -g agent-toolkit-cli

agent-toolkit install
agent-toolkit doctor
```

**From a git checkout** the canonical implementation is the V binary ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555), [HOW_TO_DEVELOP_V.md](HOW_TO_DEVELOP_V.md)):

```bash
make install-cli    # PREFIX/bin/agent-toolkit, default ~/.local/bin
agent-toolkit doctor --json
```

See [docs/v/cutover.md](v/cutover.md) and [docs/v/rollback.md](v/rollback.md). PyPI/`uvx` ships a thin Python launcher over the V binary ([ADR-021](adrs/ADR-021-pypi-binary.md)); `agent-toolkit-py` is a quarantined fallback ([python-fallback.md](v/python-fallback.md)). Do not retag empty `v1.10.0`.

### Install options

```bash
# Specific tools only
agent-toolkit install --tools claude-code,cursor

# Preview changes without writing files
agent-toolkit install --dry-run

# Overwrite existing toolkit-managed files
agent-toolkit install --force
```

---

## Verification

After the primary install:

```bash
agent-toolkit doctor
# Optional: shell completions (bash / zsh / fish / PowerShell)
agent-toolkit completion bash >> ~/.bashrc
```

Open your AI tool and ask: *"What skills do you have available?"* — responses should
reflect the agent-toolkit skill set.

To validate skill definitions from a git checkout:

```bash
bash scripts/validate-skills.sh
```

---

## Advanced install methods

Use these when the primary CLI flow does not fit your environment.

### Claude Code plugin marketplace

Native plugins for Claude Code only:

```text
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
/plugin install agent-toolkit-forge@agent-toolkit
```

### Cursor plugins (IDE + Agent CLI)

Native plugins from [`.cursor-plugin/marketplace.json`](../.cursor-plugin/marketplace.json):
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

Load a local plugin directory for one session:

```bash
cursor-agent --plugin-dir ./plugins/agent-toolkit-core
cursor-agent --plugin-dir ./plugins/agent-toolkit-agents
cursor-agent --plugin-dir ./plugins/agent-toolkit-forge
```

**Local / offline**

```bash
mkdir -p ~/.cursor/plugins/local
ln -s "$(pwd)/plugins/agent-toolkit-core" ~/.cursor/plugins/local/agent-toolkit-core
ln -s "$(pwd)/plugins/agent-toolkit-agents" ~/.cursor/plugins/local/agent-toolkit-agents
ln -s "$(pwd)/plugins/agent-toolkit-forge" ~/.cursor/plugins/local/agent-toolkit-forge
```

See [Cursor plugins docs](https://cursor.com/docs/plugins).

### npx skills (skills only)

Installs skills via the [Agent Skills](https://github.com/vercel-labs/skills) standard.
Does not deploy agents, loops, or full profiles.

```bash
npx skills add ulises-jeremias/agent-toolkit -g
```

### Homebrew / AUR

```bash
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
yay -S agent-toolkit-bin   # Arch Linux (AUR) — GitHub Release V binary
npm i -g agent-toolkit-cli # npm optionalDependencies platform packages @1.11.0
```

### Git clone + legacy script fallback (deprecated — see ADR-007)

> **Deprecated:** `scripts/install.sh` prints a warning and is kept only for offline `git clone` installs. Prefer `uvx --from agent-toolkit-cli agent-toolkit install` above. The bash script may delegate to `agent-toolkit install` when available.

For offline installs or pinning a specific commit:

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
AGENT_TOOLKIT_NO_DEPRECATION_WARNING=1 bash ~/.agent-toolkit/scripts/install.sh  # legacy fallback
# Preferred (same clone, via CLI):
uvx --from agent-toolkit-cli --from ~/.agent-toolkit agent-toolkit install
```

Legacy script options (still accepted):

```bash
bash ~/.agent-toolkit/scripts/install.sh --tools claude-code,cursor
bash ~/.agent-toolkit/scripts/install.sh --dry-run
bash ~/.agent-toolkit/scripts/install.sh --force
```

---

## Manual install

Copy profiles yourself when you need full control over paths. Clone the repo first:

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
```

### Claude Code

```bash
mkdir -p ~/.claude/agents
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md ~/.claude/CLAUDE.md
cp ~/.agent-toolkit/profiles/claude-code/settings.json ~/.claude/settings.json
cp -r ~/.agent-toolkit/profiles/claude-code/agents/. ~/.claude/agents/
```

Restart Claude Code. Agents are available via `@agent-name` (e.g. `@code-reviewer`).

**Project-level** (overrides global):

```bash
cd /path/to/your/project
mkdir -p .claude/agents
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md .claude/CLAUDE.md
cp ~/.agent-toolkit/profiles/claude-code/settings.json .claude/settings.json
```

### Cursor

```bash
mkdir -p ~/.cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. ~/.cursor/rules/
```

Per-project: copy to `.cursor/rules/` inside your repo instead.

### OpenCode

```bash
mkdir -p ~/.config/opencode/agents
cp ~/.agent-toolkit/profiles/opencode/opencode.json ~/.config/opencode/opencode.json
cp -r ~/.agent-toolkit/profiles/opencode/agents/. ~/.config/opencode/agents/
```

### GitHub Copilot

Per-project, committed to the repository:

```bash
cd /path/to/your/project
mkdir -p .github
cp ~/.agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

### Windsurf

```bash
WINDSURF_DIR="${HOME}/.codeium/windsurf"
[ -d "$WINDSURF_DIR" ] || WINDSURF_DIR="${HOME}/.windsurf"
mkdir -p "${WINDSURF_DIR}/rules" "${WINDSURF_DIR}/memories"
cp -r ~/.agent-toolkit/profiles/windsurf/rules/. "${WINDSURF_DIR}/rules/"
cp ~/.agent-toolkit/profiles/windsurf/memories/global_rules.md "${WINDSURF_DIR}/memories/global_rules.md"
```

### Pi Coding Agent

```bash
mkdir -p ~/.pi/agent/skills
cp -r ~/.agent-toolkit/profiles/pi/skills/. ~/.pi/agent/skills/
```

---

## MCP setup

MCP gives your AI tool access to external services (GitHub, Slack, Linear, etc.).
See [MCP.md](MCP.md) for per-tool config locations and provider setup.

---

## Staying up to date

Match the channel you installed:

```bash
brew upgrade agent-toolkit
# AUR
yay -Syu agent-toolkit-bin
# PyPI launcher
uv tool upgrade agent-toolkit-cli
# npm
npm update -g agent-toolkit-cli
# GitHub Release: download the new binary + SHA256SUMS from /releases/latest

agent-toolkit install --force
```

From a git checkout:

```bash
cd ~/.agent-toolkit && git pull && make install-cli && agent-toolkit install --force
```

Back up customized profile files before `--force`. See [MIGRATION.md](MIGRATION.md) when
switching from profile-copy installs to marketplace plugins.

---

## Data packaging and resolution

The product CLI is the native V binary. Homebrew and AUR consume GitHub Release assets ([distribution/](../distribution/README.md), ADR-023/024). The PyPI launcher wheel still bundles capability data; resolution order for that path is [ADR-005](adrs/ADR-005-data-packaging.md) / [ADR-015](adrs/ADR-015-runtime-resolution.md).

## Troubleshooting

### Claude Code: skills not loading

```bash
head -5 ~/.claude/CLAUDE.md
```

Project-level `.claude/CLAUDE.md` overrides global. Restart Claude Code after changes.

### Cursor: rules not appearing

1. Confirm `.mdc` files are in `~/.cursor/rules/` (global) or `.cursor/rules/` (project)
2. Verify YAML frontmatter (`---`, `description:`, closing `---`)
3. Restart Cursor

### Windsurf: rules not loading

Try `~/.windsurf/` if `~/.codeium/windsurf/` does not exist for your version.

### OpenCode: agents not available

```bash
ls ~/.config/opencode/agents/
```

Restart OpenCode after adding agent files.

### MCP servers not connecting

1. Confirm the server binary is on `$PATH`
2. Confirm env vars (e.g. `GITHUB_TOKEN`) are set in the shell your AI tool uses
3. Check MCP logs in your tool for connection errors

### validate-skills.sh fails

| Error | Fix |
|-------|-----|
| Missing `SKILL.md` | Add `SKILL.md` to the skill directory |
| Missing frontmatter `name` | Add `name:` to the `---` block in `SKILL.md` |
| Missing frontmatter `description` | Add `description:` to the `---` block |
| Secret pattern detected | Remove the credential; use `${ENV_VAR}` placeholders |

---

## Related guides

| Guide | Description |
|-------|-------------|
| [TARGETS.md](TARGETS.md) | Supported compile targets and capability matrix |
| [MIGRATION.md](MIGRATION.md) | Move from profile-copy to native plugins |
| [MCP.md](MCP.md) | MCP provider setup |

See also: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for doctor error recipes.
