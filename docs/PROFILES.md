# Profiles

A profile is the bridge between agent-toolkit's portable skill definitions and a specific AI coding assistant. Because each tool has its own configuration format and file layout, agent-toolkit ships a dedicated profile for each supported tool under `profiles/<tool>/`.

Profiles reference skills but do not duplicate them. When a skill changes, the profile reflects the change automatically — there is no per-tool copy of the skill logic.

---

## Profile Overview

| Tool | Profile directory | Key files | Install path |
|------|-------------------|-----------|--------------|
| Claude Code | `profiles/claude-code/` | `CLAUDE.md`, `settings.json`, `agents/` | `~/.claude/` |
| Cursor | `profiles/cursor/` | `rules/*.mdc` | `~/.cursor/rules/` |
| OpenCode | `profiles/opencode/` | `opencode.json`, `agents/` | `~/.config/opencode/` |
| GitHub Copilot | `profiles/copilot/` | `copilot-instructions.md` | `.github/` (per project) |
| Windsurf | `profiles/windsurf/` | `rules/*.mdc`, `memories/global_rules.md` | `~/.codeium/windsurf/` |
| Pi Coding Agent | `profiles/pi/` | `skills/*.md` | `~/.pi/agent/skills/` |
| Muse Code | `profiles/muse-code/` | Agent Skills (`SKILL.md`) | `~/.config/muse/skills/` |

---

## Claude Code

**Profile directory:** `profiles/claude-code/`

### Files

#### CLAUDE.md

The global system prompt for Claude Code. Loaded automatically at session start from `~/.claude/CLAUDE.md` (global) or `.claude/CLAUDE.md` (project-level, takes precedence).

This file contains:
- The dev companion persona and operating rules
- Repository inspection order (README → docs → AGENTS.md → CONTRIBUTING.md → task runners → CI)
- Coding standards and commit conventions
- Agent delegation table (which `@agent` to use for which task)
- Cross-tool portability note (CLAUDE.md → symlink to AGENTS.md for other tools)

#### settings.json

The Claude Code settings file. Loaded from `~/.claude/settings.json` (global) or `.claude/settings.json` (project-level).

Configures enabled plugins and inline agent definitions:

```json
{
  "enabledPlugins": {
    "context7@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "feature-dev@claude-plugins-official": true,
    "figma@claude-plugins-official": true
  },
  "agents": {
    "code-reviewer": {
      "description": "Expert code review specialist",
      "prompt": "You are a senior code reviewer. Focus on quality, security, and best practices.",
      "model": "sonnet"
    }
  }
}
```

#### agents/

Tool-specific agent definition files for agents that need more detail than the inline `settings.json` entries can hold. Each file defines a named subagent invokable with `@agent-name`.

Agent file format:

```markdown
---
name: code-reviewer
description: Expert code review for quality, security, and maintainability.
tools: Read, Grep, Glob, Bash
---

# Code Reviewer

You are a senior code reviewer...
```

### Installation

```bash
# Global install (affects all projects on this machine)
cp profiles/claude-code/CLAUDE.md ~/.claude/CLAUDE.md
cp profiles/claude-code/settings.json ~/.claude/settings.json
cp -r profiles/claude-code/agents/. ~/.claude/agents/

# Project-level install (affects this project only, overrides global)
mkdir -p .claude/agents
cp profiles/claude-code/CLAUDE.md .claude/CLAUDE.md
cp profiles/claude-code/settings.json .claude/settings.json
```

### Customization

Create `.claude/CLAUDE.md` in your project root for project-specific instructions. This takes precedence over the global file. Keep project-level instructions focused on what is unique to your project.

Common project-level additions:
- Project-specific branching and PR strategy
- Custom agent delegation for project tools
- Stack-specific coding standards (e.g. "always use Zod for validation")
- Monorepo package boundary rules

---

## Cursor

**Profile directory:** `profiles/cursor/`

### Files

#### rules/*.mdc

Cursor uses `.mdc` files (Markdown with YAML frontmatter) for its Rules for AI feature. Each file corresponds to an agent persona.

File format:

```
---
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability.
alwaysApply: false
---

# Code Reviewer

[Rule content here]
```

Rules can be scoped:
- **Global rules** in `~/.cursor/rules/` apply to all Cursor projects
- **Project rules** in `.cursor/rules/` (inside your repo) apply to the current project only

The agent-toolkit profile ships per-agent rule files (14 agent personas):

```
profiles/cursor/rules/
├── architect.mdc
├── assistant.mdc
├── build-error-resolver.mdc
├── code-reviewer.mdc
├── database-reviewer.mdc
├── docs-lookup.mdc
├── e2e-runner.mdc
├── performance-optimizer.mdc
├── planner.mdc
├── refactor-cleaner.mdc
├── reference-lookup.mdc
├── security-reviewer.mdc
├── tdd-guide.mdc
└── typescript-reviewer.mdc
```

### Installation

```bash
# Global install (all Cursor projects)
mkdir -p ~/.cursor/rules
cp profiles/cursor/rules/*.mdc ~/.cursor/rules/

# Project install (this project only)
mkdir -p .cursor/rules
cp profiles/cursor/rules/*.mdc .cursor/rules/

# Install a single domain
cp profiles/cursor/rules/code-reviewer.mdc .cursor/rules/
```

Alternatively, paste `.mdc` file contents directly into **Cursor Settings → Rules for AI** in the Cursor UI.

### Customization

Add project-specific rules by creating a new `.mdc` file in your project's `.cursor/rules/`. Cursor merges all rule files it finds. Name your file to avoid collisions with toolkit files (e.g. `myproject-conventions.mdc`).

---

## OpenCode

**Profile directory:** `profiles/opencode/`

### Files

#### opencode.json

The main OpenCode configuration file. Loaded from `~/.config/opencode/opencode.json`.

Declares provider and model configuration plus agent definitions.

#### agents/

Agent overlay files for OpenCode. Each file is loaded as an agent persona available in the session. OpenCode reads agents from `~/.config/opencode/agents/`.

Agent file format:

```markdown
---
description: Code reviewer for quality and security
mode: all
color: primary
permission:
  bash: allow
  edit: allow
---

[Agent instructions here]
```

### Installation

```bash
# Copy the full profile
cp -r profiles/opencode/. ~/.config/opencode/

# Or copy selectively
cp profiles/opencode/opencode.json ~/.config/opencode/opencode.json
cp -r profiles/opencode/agents/. ~/.config/opencode/agents/
```

### Customization

Create `.opencode/config.json` in your project root for project-specific settings. OpenCode merges project config with global config, with project config taking precedence.

---

## GitHub Copilot

**Profile directory:** `profiles/copilot/`

### Files

#### copilot-instructions.md

A Markdown file placed at `.github/copilot-instructions.md` in your repository. GitHub Copilot reads this file and uses it as additional context for all completions and chat in that repository.

Unlike other profiles, this file is committed to the repository — it is part of the project, not the user's machine configuration. The whole team benefits from it automatically.

The toolkit-provided template includes:
- Project conventions and coding standards
- Skill domain declarations (edit to select which domains apply)
- PR and commit message conventions
- Project-specific constraints

### Installation

```bash
# Copy to your project
mkdir -p .github
cp profiles/copilot/copilot-instructions.md .github/copilot-instructions.md

# Edit to select which domains apply
# Then commit
git add .github/copilot-instructions.md
git commit -m "chore: add Copilot instructions from agent-toolkit"
```

### Customization

Edit `.github/copilot-instructions.md` directly. The toolkit provides a well-structured starting template. Customize it to match your project's conventions, then commit so the whole team benefits.

Common customizations:
- Remove domain sections that do not apply (e.g. remove `design` section for backend-only repos)
- Add architecture constraints ("this is a monorepo — never cross package boundaries")
- Add tool-specific notes ("use Vitest for testing, not Jest")

---

## Windsurf

**Profile directory:** `profiles/windsurf/`

### Files

#### rules/*.mdc

Windsurf uses `.mdc` rule files with the same format as Cursor. The toolkit profile ships the same domain-organized rules adapted for Windsurf's loading format.

Windsurf looks for rules in:
- `~/.codeium/windsurf/rules/` (global, most installations)
- `~/.windsurf/rules/` (some newer installations — check your version)

#### memories/global_rules.md

Windsurf's memory system loads persistent facts at session start. The `global_rules.md` file declares conventions and standards that should always be in context, regardless of which project is open.

### Installation

```bash
# Install to Codeium's config directory
cp -r profiles/windsurf/. ~/.codeium/windsurf/

# Or install rules and memory separately
mkdir -p ~/.codeium/windsurf/rules
cp profiles/windsurf/rules/*.mdc ~/.codeium/windsurf/rules/

mkdir -p ~/.codeium/windsurf/memories
cp profiles/windsurf/memories/global_rules.md ~/.codeium/windsurf/memories/

# On newer Windsurf installations
mkdir -p ~/.windsurf/rules
cp profiles/windsurf/rules/*.mdc ~/.windsurf/rules/
```

### Customization

Add project-specific rules by creating a `.windsurfrules` file in your project root. Windsurf merges it with global rules. For persistent facts, add `.md` files to `~/.codeium/windsurf/memories/` — Windsurf loads all files in that directory.

---

## Pi Coding Agent

**Profile directory:** `profiles/pi/`

### Files

#### skills/*.md

Pi Coding Agent loads skill definitions from `~/.pi/agent/skills/`. Each `.md` file is a skill the agent can invoke.

The Pi profile ships a minimal set of 5 agent personas formatted as Pi skills (see `profiles/pi/skills/`):
- `assistant`, `architect`, `planner`, `code-reviewer`, `security-reviewer` (agents-as-skills)

> **Note:** Earlier docs listed 11 delivery/forge skills; the current profile is intentionally minimal (agents-as-skills) to match Pi's native format. For full 86 skills, use the universal Agent Skills path (`~/.pi/agent/skills/` accepts standard `SKILL.md`); track full parity in #787.

### Installation

```bash
mkdir -p ~/.pi/agent/skills
cp -r profiles/pi/skills/. ~/.pi/agent/skills/
```

### Customization

Add additional skill files to `~/.pi/agent/skills/`. Use `SKILL.md` files from the `skills/` directory as the source — Pi reads standard Markdown skill files.

---

## Deploying profiles

Use the V CLI ([ADR-007](adrs/ADR-007-install-sh-deprecation.md) removed the bash install wrappers):

```bash
agent-toolkit install
agent-toolkit install --tools claude-code,cursor
agent-toolkit install --dry-run
```

See [INSTALLATION.md](INSTALLATION.md) for the complete installation guide.

---

## Profile Portability Convention

For tools that support a primary instruction file (CLAUDE.md, AGENTS.md, etc.), the toolkit follows a symlink convention so you maintain one file referenced by all tools:

```
project-root/
├── AGENTS.md                          # Primary source of truth (committed)
├── CLAUDE.md -> AGENTS.md             # Symlink for Claude Code
├── GEMINI.md -> AGENTS.md             # Symlink for Gemini CLI
└── .github/
    └── copilot-instructions.md        # Separate (Copilot reads from .github/)
```

This avoids divergence between tool-specific instruction files. The install script can create these symlinks automatically when run with `--symlinks`.

---

## Adding a New Tool Profile

1. Create `profiles/<new-tool>/` directory
2. Add tool-specific config files using that tool's native format
3. Document the install path in this file and in `INSTALLATION.md`
4. Add detection in the V installer (`modules/agent_toolkit_cli`)
5. Open a PR with the new profile
