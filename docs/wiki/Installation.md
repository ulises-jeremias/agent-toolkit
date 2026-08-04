# Installation

This guide covers how to install agent-toolkit for each supported AI coding assistant. You can
use the automated install script for a guided experience, or follow the manual steps for full
control.

---

## Prerequisites

### Required

- **git** 2.30 or later — to clone the repository
- **bash** 5.0 or later (macOS ships with bash 3; install a newer version via Homebrew:
  `brew install bash`)

### Required: at least one supported AI coding assistant

| Tool | How to install |
|------|---------------|
| [Claude Code](https://claude.ai/code) | Follow Anthropic's install guide |
| [Cursor](https://cursor.sh) | Download from cursor.sh |
| [OpenCode](https://opencode.ai) | Follow OpenCode's install guide |
| [GitHub Copilot](https://github.com/features/copilot) | Requires VS Code or JetBrains + extension |
| [Windsurf](https://codeium.com/windsurf) | Download from Codeium |
| [Pi Coding Agent](https://pi.ai) | Follow Pi's install guide |

### Recommended (for full feature access)

- **gh** (GitHub CLI) — required by forge skills (`gh-fix-ci`, `github-cli-workflow`, etc.)
- **jq** 1.6 or later — used by several loop templates for JSON processing
- **node** / **npm** — for MCP server installation and `npx skills`
- **Python** 3.10 or later — for CLI installation and validation scripts

Verify your setup before installing:

```bash
git --version     # Should be 2.30+
bash --version    # Should be 5.0+ (macOS: /usr/local/bin/bash after brew install)
python3 --version # Should be 3.10+
gh --version      # Optional but recommended
```

---

## Method 1: Claude Code Plugin Marketplace (recommended)

The fastest way to get started if you use Claude Code. Three plugins let you install exactly the
capabilities you need.

```text
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
/plugin install agent-toolkit-forge@agent-toolkit
```

**What each plugin includes:**

| Plugin | Includes |
|--------|---------|
| `agent-toolkit-core` | Core skills (assistant, dev-companion, output-handshake, pr-fallback, workspace-knowledge-sync, onboarding) + code-reviewer agent |
| `agent-toolkit-agents` | All 16 agent personas (architect, planner, all reviewers, TDD guide, and more) |
| `agent-toolkit-forge` | GitHub and GitLab automation skills (github-cli-workflow, gh-fix-ci, gh-address-comments, gh-contribution-planner) |

You do not need to install all three. Install `agent-toolkit-core` for everyday coding workflows.
Add `agent-toolkit-agents` if you want specialist subagents. Add `agent-toolkit-forge` for GitHub
PR automation.

**Verify installation:**

After installing, open a new Claude Code session and ask:

```text
"What skills do you have available?"
```

You should see agent-toolkit skills listed in the response.

---

## Method 2: npx skills (Agent Skills standard)

This is the standard install path for any Agent Skills-compatible tool. Works with Claude Code,
Cursor, OpenCode, Windsurf, and Pi.

```bash
# Global install — all compatible tools pick up skills automatically
npx skills add ulises-jeremias/agent-toolkit -g

# Project-scoped install (skills only apply to the current directory)
npx skills add ulises-jeremias/agent-toolkit
```

Skills are installed using `SKILL.md` frontmatter only — no `skill.json` required. This is fully
compliant with the [Agent Skills spec](https://github.com/vercel-labs/skills).

**Verify installation:**

```bash
npx skills list
```

You should see agent-toolkit skills listed.

---

## Method 3: Manual install (per tool)

Clone the repository and copy profiles to the correct location for each tool.

### Step 1: Clone the repository

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
```

### Step 2: Install for your tool

**Claude Code**

```bash
mkdir -p ~/.claude/agents
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md ~/.claude/CLAUDE.md
cp ~/.agent-toolkit/profiles/claude-code/settings.json ~/.claude/settings.json
cp -r ~/.agent-toolkit/profiles/claude-code/agents/. ~/.claude/agents/
```

Restart Claude Code. Agents are now available via `@agent-name` (e.g. `@code-reviewer`).

**Project-level install** (overrides global for one project):

```bash
cd /path/to/your/project
mkdir -p .claude/agents
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md .claude/CLAUDE.md
cp ~/.agent-toolkit/profiles/claude-code/settings.json .claude/settings.json
```

**Cursor**

```bash
# Global rules (apply to all Cursor projects)
mkdir -p ~/.cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. ~/.cursor/rules/

# Or per-project rules
cd /path/to/your/project
mkdir -p .cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. .cursor/rules/
```

**OpenCode**

```bash
mkdir -p ~/.config/opencode/agents
cp ~/.agent-toolkit/profiles/opencode/opencode.json ~/.config/opencode/opencode.json
cp -r ~/.agent-toolkit/profiles/opencode/agents/. ~/.config/opencode/agents/
```

**GitHub Copilot**

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

**Windsurf**

```bash
# Detect your Windsurf config directory (varies by version)
WINDSURF_DIR="${HOME}/.codeium/windsurf"
[ -d "$WINDSURF_DIR" ] || WINDSURF_DIR="${HOME}/.windsurf"

mkdir -p "${WINDSURF_DIR}/rules" "${WINDSURF_DIR}/memories"
cp -r ~/.agent-toolkit/profiles/windsurf/rules/. "${WINDSURF_DIR}/rules/"
cp ~/.agent-toolkit/profiles/windsurf/memories/global_rules.md "${WINDSURF_DIR}/memories/global_rules.md"
```

**Pi Coding Agent**

```bash
mkdir -p ~/.pi/agent/skills
cp -r ~/.agent-toolkit/profiles/pi/skills/. ~/.pi/agent/skills/
```

---

## Method 4: Auto-detect script

The install script detects your active tools and deploys the right profiles automatically.

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit.git
bash agent-toolkit/scripts/install.sh
```

The script will:

1. Detect which AI tools are installed on your machine
2. Show you what it will install and ask for confirmation
3. Copy profiles to the correct locations for each detected tool
4. Ask before overwriting any existing files
5. Print a summary of what was installed

### Install script options

```bash
# Install for specific tools only
bash ~/.agent-toolkit/scripts/install.sh --tools claude-code,cursor

# Dry run — show what would be installed without making changes
bash ~/.agent-toolkit/scripts/install.sh --dry-run

# Force overwrite existing files without prompting
bash ~/.agent-toolkit/scripts/install.sh --force

# Create symlinks (AGENTS.md → CLAUDE.md → GEMINI.md) for portability
bash ~/.agent-toolkit/scripts/install.sh --symlinks
```

---

## Verifying Installation

### Check the doctor script

The doctor script checks AI tool availability and profile installation status:

```bash
bash ~/.agent-toolkit/scripts/doctor.sh
```

Expected output (example):

```text
── AI Tools ──
  ✓ Claude Code: 1.x.x
  ✓ Cursor: 0.x.x
  - OpenCode: not found (https://opencode.ai)
  - Windsurf: not found (https://codeium.com/windsurf)

── Profile Status ──
  ✓ Claude Code profile installed: /home/user/.claude/CLAUDE.md
  ✓ Cursor rules: /home/user/.cursor/rules/
  - OpenCode agents: /home/user/.config/opencode/agents/ (not installed)
  - Windsurf rules: /home/user/.codeium/windsurf/rules/ (not installed)
  - Pi skills: /home/user/.pi/agent/skills/ (not installed)
```

### Validate skill definitions

```bash
bash ~/.agent-toolkit/scripts/validate-skills.sh
```

All checks should pass (exit code 0). If any fail, the script prints the exact file and field
that failed.

### Test in your AI tool

Open your AI tool and ask:

```text
"What skills do you have available?"
"What is your repository inspection order?"
"Walk me through the development workflow."
```

The responses should reflect the agent-toolkit skill set.

---

## Updating to a New Version

```bash
cd ~/.agent-toolkit
git pull

# Re-run install to update profiles (will prompt before overwriting)
bash scripts/install.sh

# Or force-overwrite all profile files
bash scripts/install.sh --force
```

The `--force` flag overwrites existing profile files with the latest versions. If you have
customized any toolkit-managed profile files, back them up before running with `--force`.
Project-level customizations (`.claude/CLAUDE.md`, `.cursor/rules/myproject.mdc`, etc.) are
never touched by the install script.

After updating, restart your AI tool(s) to pick up the new profiles.

---

## Uninstalling

To remove agent-toolkit profiles from a machine:

```bash
# Claude Code (global)
rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json
rm -rf ~/.claude/agents/

# Cursor (global rules — remove only agent-toolkit files)
ls ~/.cursor/rules/
# Then: rm -f ~/.cursor/rules/<agent-toolkit-files>.mdc
# Or remove all: rm -rf ~/.cursor/rules/

# OpenCode
rm -f ~/.config/opencode/opencode.json
rm -rf ~/.config/opencode/agents/

# Windsurf
rm -f ~/.codeium/windsurf/memories/global_rules.md
# Remove agent-toolkit rule files from ~/.codeium/windsurf/rules/

# Pi
rm -f ~/.pi/agent/skills/*.md
```

Project-level files (`.claude/CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`)
are tracked in their respective repositories. Remove them with `git rm` when appropriate.

To remove the toolkit source itself:

```bash
rm -rf ~/.agent-toolkit
```

---

## Troubleshooting

### Claude Code: skills not loading

Check that `~/.claude/CLAUDE.md` exists and is readable:

```bash
head -5 ~/.claude/CLAUDE.md
```

If you have both `~/.claude/CLAUDE.md` (global) and `.claude/CLAUDE.md` (project-level), the
project-level file takes precedence — make sure it includes the content you need. Restart Claude
Code after making changes.

### Cursor: rules not appearing

1. Confirm `.mdc` files are in the correct directory (`~/.cursor/rules/` for global,
   `.cursor/rules/` for project)
2. Verify each file has valid YAML frontmatter (opening `---`, `description:` field, closing `---`)
3. Restart Cursor and reopen the project

### Windsurf: rules not loading

Windsurf changed its config directory between versions. If `~/.codeium/windsurf/` does not work,
try `~/.windsurf/`. Check the Windsurf release notes for your installed version.

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

See [MCP Setup](MCP-Setup) for provider-specific troubleshooting.

### validate-skills.sh fails

The script prints the exact file and field that failed. Common causes:

| Error | Fix |
|-------|-----|
| Missing `SKILL.md` | Add `SKILL.md` to the skill directory |
| Missing `skill.json` | Add `skill.json` to the skill directory |
| Missing frontmatter `name` | Add `name:` to the `---` block in `SKILL.md` |
| Missing frontmatter `description` | Add `description:` to the `---` block |
| Missing `version` in skill.json | Add `"version": "1.0.0"` to `skill.json` |
| Secret pattern detected | Remove the credential and use `${ENV_VAR}` placeholder instead |
