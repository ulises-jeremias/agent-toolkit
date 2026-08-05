# Installation

This guide covers how to install agent-toolkit for each supported AI coding assistant. You can use the automated install script for a guided experience, or follow the manual steps for full control.

---

## Prerequisites

- **git** — to clone the repository
- **bash** — for the install script (bash 4+ recommended; macOS ships bash 3, install a newer version via Homebrew: `brew install bash`)
- At least one supported AI coding assistant installed:
  - [Claude Code](https://claude.ai/code) (Anthropic)
  - [Cursor](https://cursor.sh)
  - [OpenCode](https://opencode.ai)
  - [GitHub Copilot](https://github.com/features/copilot) (requires VS Code or JetBrains + extension)
  - [Windsurf](https://codeium.com/windsurf) (Codeium)
  - [Pi Coding Agent](https://pi.ai)

Optional but recommended:
- **gh** (GitHub CLI) — required by forge skills (`gh-fix-ci`, `github-cli-workflow`, etc.)
- **jq** — used by several loop templates for JSON processing
- **node** / **npm** — for MCP server installation

---

## Quick Install

Clone the repository and run the install script:

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
bash ~/.agent-toolkit/scripts/install.sh
```

The script will:
1. Detect which AI tools are installed on your machine
2. Show you what it will install and ask for confirmation
3. Copy profiles to the correct locations for each detected tool
4. Ask before overwriting any existing files
5. Print a summary of what was installed

### Install Options

```bash
# Install for specific tools only
bash ~/.agent-toolkit/scripts/install.sh --tools claude-code,cursor

# Dry run — show what would be installed without making changes
bash ~/.agent-toolkit/scripts/install.sh --dry-run

# Force overwrite existing files without prompting
bash ~/.agent-toolkit/scripts/install.sh --force
```

---

## Manual Install

### Claude Code

```bash
# Create the directories if they don't exist
mkdir -p ~/.claude/agents

# Copy the global instructions
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md ~/.claude/CLAUDE.md

# Copy the settings (plugins, agent definitions)
cp ~/.agent-toolkit/profiles/claude-code/settings.json ~/.claude/settings.json

# Copy agent persona files
cp -r ~/.agent-toolkit/profiles/claude-code/agents/. ~/.claude/agents/
```

Restart Claude Code. Agents are now available via `@agent-name` (e.g. `@code-reviewer`, `@planner`).

**Project-level install** (overrides global for a specific project):

```bash
cd /path/to/your/project
mkdir -p .claude/agents
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md .claude/CLAUDE.md
cp ~/.agent-toolkit/profiles/claude-code/settings.json .claude/settings.json
```

---

### Cursor

```bash
# Global rules (apply to all Cursor projects)
mkdir -p ~/.cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. ~/.cursor/rules/

# Or install per-project rules
cd /path/to/your/project
mkdir -p .cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. .cursor/rules/
```

Restart Cursor. Rules are applied automatically to all projects (global) or the current project (per-project).

---

### OpenCode

```bash
# Create config directories if needed
mkdir -p ~/.config/opencode/agents

# Copy the full profile
cp ~/.agent-toolkit/profiles/opencode/opencode.json ~/.config/opencode/opencode.json
cp -r ~/.agent-toolkit/profiles/opencode/agents/. ~/.config/opencode/agents/
```

---

### GitHub Copilot

Copilot instructions are per-project and committed to the repository:

```bash
cd /path/to/your/project
mkdir -p .github
cp ~/.agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md

# Edit to select which skill domains apply to your project
$EDITOR .github/copilot-instructions.md

# Commit so the whole team benefits
git add .github/copilot-instructions.md
git commit -m "chore: add Copilot instructions from agent-toolkit"
```

---

### Windsurf

```bash
# Detect your Windsurf config directory (varies by version)
WINDSURF_DIR="${HOME}/.codeium/windsurf"
[ -d "$WINDSURF_DIR" ] || WINDSURF_DIR="${HOME}/.windsurf"

mkdir -p "${WINDSURF_DIR}/rules" "${WINDSURF_DIR}/memories"

cp -r ~/.agent-toolkit/profiles/windsurf/rules/. "${WINDSURF_DIR}/rules/"
cp ~/.agent-toolkit/profiles/windsurf/memories/global_rules.md "${WINDSURF_DIR}/memories/global_rules.md"
```

---

### Pi Coding Agent

```bash
mkdir -p ~/.pi/agent/skills
cp -r ~/.agent-toolkit/profiles/pi/skills/. ~/.pi/agent/skills/
```

---

## MCP Setup

MCP (Model Context Protocol) gives your AI tool access to external services like GitHub, Slack, and Linear. See [MCP.md](MCP.md) for provider-specific setup instructions.

Quick start for GitHub MCP:

```bash
# Install the GitHub MCP server
npm install -g @anthropic-ai/mcp-server-github

# Set your GitHub token
export GITHUB_TOKEN=ghp_your_token_here

# Copy and reference the template in your tool's MCP config
# See MCP.md for per-tool config file locations
```

---

## Verification

After installation, run these checks:

### Check profile files are in place

```bash
# Claude Code
ls ~/.claude/CLAUDE.md ~/.claude/settings.json

# Cursor
ls ~/.cursor/rules/

# OpenCode
ls ~/.config/opencode/opencode.json

# Windsurf (adjust path for your version)
ls ~/.codeium/windsurf/rules/

# Pi
ls ~/.pi/agent/skills/
```

### Validate the skill definitions

```bash
bash ~/.agent-toolkit/scripts/validate-skills.sh
```

This checks every skill directory for required files, valid frontmatter, and the absence of secret patterns. All checks should pass (exit code 0).

### Test in your AI tool

Open your AI tool of choice and ask:

- "What skills do you have available?"
- "What is your repository inspection order?"
- "Walk me through the development workflow."

The responses should reflect the agent-toolkit skill set.

---

## Staying Up to Date

```bash
cd ~/.agent-toolkit
git pull

# Re-run install to update profiles
bash scripts/install.sh

# Or force-overwrite all profile files
bash scripts/install.sh --force
```

The `--force` flag overwrites existing profile files with the latest versions. If you have customized any toolkit-managed profile files, back them up before running with `--force`. Project-level customizations (`.claude/CLAUDE.md`, `.cursor/rules/myproject.mdc`, etc.) are never touched by the install script.

---

## Troubleshooting

### Claude Code: skills not loading

Check that `~/.claude/CLAUDE.md` exists and is readable:

```bash
head -5 ~/.claude/CLAUDE.md
```

If you have both `~/.claude/CLAUDE.md` (global) and `.claude/CLAUDE.md` (project-level), the project-level file takes precedence — make sure it includes the content you need. Restart Claude Code after making changes.

### Cursor: rules not appearing

1. Confirm `.mdc` files are in the correct directory (`~/.cursor/rules/` for global, `.cursor/rules/` for project)
2. Verify each file has valid YAML frontmatter (opening `---`, `description:` field, closing `---`)
3. Restart Cursor and reopen the project

### Windsurf: rules not loading

Windsurf changed its config directory between versions. If `~/.codeium/windsurf/` does not work, try `~/.windsurf/`. Check the Windsurf release notes for your installed version.

### OpenCode: agents not available

Confirm the agents directory exists and contains `.md` files:

```bash
ls ~/.config/opencode/agents/
```

Restart OpenCode after adding new agent files.

### MCP servers not connecting

1. Verify the MCP server binary is on `$PATH`:
   ```bash
   which mcp-github-server
   ```
2. Verify the environment variable is set in the shell where your AI tool runs:
   ```bash
   echo $GITHUB_TOKEN
   ```
3. Check your AI tool's MCP logs for connection errors
4. For HTTP-based servers (Linear, Figma), verify network access to the endpoint

### validate-skills.sh fails

The script prints the exact file and field that failed. Common causes and fixes:

| Error | Fix |
|-------|-----|
| Missing `SKILL.md` | Add `SKILL.md` to the skill directory |
| Missing frontmatter `name` | Add `name:` to the `---` block in `SKILL.md` |
| Missing frontmatter `description` | Add `description:` to the `---` block |
| `skill.json` present | Remove it — only `SKILL.md` frontmatter is needed (see `docs/MIGRATION.md`) |
| Secret pattern detected | Remove the credential and use `${ENV_VAR}` placeholder instead |

---

## Uninstall

To remove agent-toolkit profiles from a machine:

```bash
# Claude Code (global)
rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json
rm -rf ~/.claude/agents/

# Cursor (global rules)
rm -f ~/.cursor/rules/agent-toolkit-*.mdc
# or remove all rules: rm -rf ~/.cursor/rules/

# OpenCode
rm -f ~/.config/opencode/opencode.json
rm -rf ~/.config/opencode/agents/

# Windsurf
rm -f ~/.codeium/windsurf/rules/agent-toolkit-*.mdc
rm -f ~/.codeium/windsurf/memories/global_rules.md

# Pi
rm -f ~/.pi/agent/skills/*.md
```

Project-level files (`.claude/CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) are tracked in their respective repositories — remove them with `git rm` when appropriate.
