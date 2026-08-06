# Example: Adding agent-toolkit to an Existing Project

This example walks through onboarding agent-toolkit onto a project that does not currently use it. By the end, every team member who installs their AI coding assistant profile will have access to the full set of agents and skills.

This covers four AI tools: Claude Code, Cursor, GitHub Copilot, and OpenCode. Do all four or only the ones your team uses.

---

## Prerequisites

- **agent-toolkit installed** on your machine (preferred: Python CLI):
  ```bash
  uvx --from agent-toolkit-cli agent-toolkit install --dry-run    # Preview (auto-detects tools)
  uvx --from agent-toolkit-cli agent-toolkit install              # Install
  # Legacy/offline fallback (deprecated, see docs/adrs/ADR-007-install-sh-deprecation.md):
  # git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
  # bash ~/.agent-toolkit/scripts/install.sh --dry-run
  ```

- **Your project cloned** and the working directory set to its root:
  ```bash
  cd /path/to/your/project
  ```

- At least one of: Claude Code, Cursor, GitHub Copilot, OpenCode installed.

---

## Step 1: Install the Claude Code Profile

The Claude Code profile sets global instructions and registers the agent-toolkit agents and settings for your machine. This is a user-level install, not committed to the repo.

```bash
# Create directories if they don't exist
mkdir -p ~/.claude/agents

# Copy global instructions (will apply to all Claude Code sessions)
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md ~/.claude/CLAUDE.md

# Copy settings.json (registers skill plugins and tool permissions)
cp ~/.agent-toolkit/profiles/claude-code/settings.json ~/.claude/settings.json

# Copy all agent persona files
cp -r ~/.agent-toolkit/profiles/claude-code/agents/. ~/.claude/agents/
```

Restart Claude Code. Test the install:

```
@code-reviewer What does this repo do?
```

If the `@code-reviewer` agent responds with context about the repository, the install worked.

### Project-level Claude Code instructions (optional, commit to repo)

For project-specific AI instructions that the whole team shares, create a `.claude/CLAUDE.md` in the project root:

```bash
mkdir -p .claude

cat > .claude/CLAUDE.md << 'EOF'
# Project AI Instructions

This project uses agent-toolkit for AI-assisted development.

## Project context
- Stack: [your stack]
- Primary workflow: feature branches → PR → code review → merge
- Test command: [your test command]

## Agents available
- @code-reviewer — code quality, security, maintainability
- @planner — feature breakdown and task planning
- @tdd-guide — test-driven development workflow

## Conventions
- [Add project-specific conventions here]
EOF

git add .claude/CLAUDE.md
git commit -m "chore: add project-level Claude Code instructions"
```

---

## Step 2: Add Cursor Rules

Cursor rules are Markdown files that Cursor loads as context for every session. They can be installed globally (for all your projects) or per-project (committed to the repo for the team).

### Global install (your machine only)

```bash
mkdir -p ~/.cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. ~/.cursor/rules/
```

Restart Cursor. The rules are available in all projects.

### Per-project install (committed to repo, team shares it)

```bash
mkdir -p .cursor/rules
cp -r ~/.agent-toolkit/profiles/cursor/rules/. .cursor/rules/

# Review what was copied
ls .cursor/rules/

# Commit
git add .cursor/rules/
git commit -m "chore: add Cursor rules from agent-toolkit"
```

### Verifying Cursor rules are active

Open Cursor, start a new chat, and type:

```
What agents are available in this project?
```

If Cursor references the agent-toolkit agents and skills, the rules are loaded. If not, check that the `.mdc` files in `.cursor/rules/` have valid YAML frontmatter (the file must start with `---`).

---

## Step 3: Commit copilot-instructions.md

GitHub Copilot reads per-project instructions from `.github/copilot-instructions.md`. This file is committed to the repo so every team member benefits without any local configuration.

```bash
mkdir -p .github
cp ~/.agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

Open the file and tailor it to your project. The template includes a placeholder section for project-specific context — fill it in:

```bash
# Open in your editor
$EDITOR .github/copilot-instructions.md
```

Look for the section that says `## Project context` and add:
- Your stack (language, framework, database)
- Test command
- PR conventions
- Any domain-specific knowledge Copilot should have

Commit and push:

```bash
git add .github/copilot-instructions.md
git commit -m "chore: add Copilot instructions from agent-toolkit"
git push
```

GitHub Copilot picks up the file automatically for all team members on next pull. No extension or plugin installation required beyond Copilot itself.

### What the copilot-instructions.md includes

The template from agent-toolkit covers:
- Available agents and when to invoke each one
- Skill domains and their purpose
- Contribution conventions (branch naming, commit format, PR template)
- Safety rules (never commit secrets, always cite sources)

---

## Step 4: Verify with doctor.sh

Run the built-in doctor script to confirm all installed profiles are correctly configured:

```bash
bash ~/.agent-toolkit/scripts/doctor.sh
```

Expected output:

```
agent-toolkit doctor v1.0

Checking installed tools...

  Claude Code
    CLAUDE.md           ✓  ~/.claude/CLAUDE.md
    settings.json       ✓  ~/.claude/settings.json
    agents/             ✓  16 agent files found

  Cursor
    Global rules        ✓  ~/.cursor/rules/ (8 files)
    Project rules       ✓  .cursor/rules/ (8 files)

  GitHub Copilot
    copilot-instructions.md  ✓  .github/copilot-instructions.md

  OpenCode
    opencode.json       -  not installed (run: install.sh --tools opencode)
    agents/             -  not installed

Summary: 3 tools configured, 1 not installed.

To install missing tools:
  bash ~/.agent-toolkit/scripts/install.sh --tools opencode
```

If a tool shows `✗` (error), the doctor output will explain what is missing and how to fix it.

---

## Step 5: Onboard the Rest of the Team

Once the project files are committed (`.claude/CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`), team members need only install agent-toolkit locally:

```bash
# One-time install per developer
git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit
bash ~/.agent-toolkit/scripts/install.sh
```

The install script detects which AI tools each developer has installed and applies only the relevant profiles. Team members who use Cursor get Cursor rules; Claude Code users get the Claude profile; all Copilot users benefit from the committed instructions without any local steps.

### Share a setup note in your CONTRIBUTING.md

Add a section to `CONTRIBUTING.md` so new team members know agent-toolkit is available:

```markdown
## AI Coding Assistant Setup

This project uses [agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit)
for AI-assisted development. To get the full set of agents and skills:

1. Install agent-toolkit: `git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit && bash ~/.agent-toolkit/scripts/install.sh`
2. Restart your AI coding assistant
3. Verify: `bash ~/.agent-toolkit/scripts/doctor.sh`

Available agents: @code-reviewer, @planner, @security-reviewer, @tdd-guide, and more.
See `agents/` in the agent-toolkit repo for the full list.
```

---

## Troubleshooting

**Claude Code does not recognize @code-reviewer.**

Confirm the agent file exists:

```bash
ls ~/.claude/agents/code-reviewer.md   # or .yaml depending on version
```

If the file is missing, re-run the install:

```bash
cp -r ~/.agent-toolkit/profiles/claude-code/agents/. ~/.claude/agents/
```

Then restart Claude Code (full quit and reopen, not just a new chat window).

**Cursor rules are present but not loading.**

Each `.mdc` file must begin with valid YAML frontmatter. Open one of the rule files and confirm it starts with:

```markdown
---
description: ...
---
```

If the frontmatter is missing or malformed, Cursor silently ignores the file.

**copilot-instructions.md is committed but Copilot ignores it.**

GitHub Copilot reads the file only when it is in `.github/copilot-instructions.md` at the repo root. Confirm the path is exact — Copilot does not check subdirectories. Also confirm you have the Copilot extension installed in VS Code or JetBrains (the browser-only Copilot does not load custom instructions).

**doctor.sh shows a tool as not installed that I have installed.**

The doctor script detects tools by looking for their executables in `$PATH`. If your tool is installed in a non-standard location, the script may not find it. Run the manual install for that tool:

```bash
bash ~/.agent-toolkit/scripts/install.sh --tools cursor
```
