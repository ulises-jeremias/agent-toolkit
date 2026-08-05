# Installation

This guide describes the **primary consumer install flow** for agent-toolkit, then
lists advanced methods when you need marketplace plugins, skills-only delivery, or
manual file copies.

---

## Prerequisites

- **Python** 3.10 or later — for the CLI (`uv` / `uvx` recommended)
- At least one supported AI coding assistant:
  - [Claude Code](https://claude.ai/code) (Anthropic)
  - [Cursor](https://cursor.sh)
  - [OpenCode](https://opencode.ai)
  - [GitHub Copilot](https://github.com/features/copilot) (VS Code or JetBrains + extension)
  - [Windsurf](https://codeium.com/windsurf) (Codeium)
  - [Pi Coding Agent](https://pi.ai)

Optional but recommended:

- **[uv](https://docs.astral.sh/uv/)** — preferred way to run `uvx` and manage the CLI
- **gh** (GitHub CLI) — required by forge skills (`gh-fix-ci`, `github-cli-workflow`, etc.)
- **jq** — used by several loop templates for JSON processing
- **node** / **npm** — for MCP server installation and `npx skills`
- **git** + **bash** — only needed for git-clone or install-script methods below

---

## Primary install (recommended)

One command auto-detects your AI tools and deploys the right profiles.

```bash
# Run without installing the CLI (preferred)
uvx --from agent-toolkit-cli agent-toolkit install

# Verify
uvx --from agent-toolkit-cli agent-toolkit doctor
```

### Persistent CLI install

```bash
uv tool install agent-toolkit-cli    # preferred when using uv
# pip install agent-toolkit-cli      # alternative

agent-toolkit install                # auto-detect all tools
agent-toolkit doctor                 # verify setup
```

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
yay -S agent-toolkit   # Arch Linux (AUR)
```

### Git clone + install script

For offline installs or pinning a specific commit:

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
bash ~/.agent-toolkit/scripts/install.sh
```

Script options:

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

With the CLI installed:

```bash
uv tool upgrade agent-toolkit-cli   # or: pip install -U agent-toolkit-cli
agent-toolkit install --force
```

With a git checkout:

```bash
cd ~/.agent-toolkit && git pull && bash scripts/install.sh --force
```

Back up customized profile files before `--force`. See [MIGRATION.md](MIGRATION.md) when
switching from profile-copy installs to marketplace plugins.

---

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
