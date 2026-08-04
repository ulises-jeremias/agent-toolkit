# Profiles

A profile is the bridge between agent-toolkit's portable skill definitions and a specific AI
coding assistant. Because each tool has its own configuration format and file layout, agent-toolkit
ships a dedicated profile for each supported tool.

Profiles reference skills — they do not duplicate skill content. When a skill changes, the
profile reflects the change automatically.

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

---

## Claude Code

**Profile directory:** `profiles/claude-code/`

### Files

#### CLAUDE.md

The global system prompt for Claude Code. Loaded automatically at session start from
`~/.claude/CLAUDE.md` (global) or `.claude/CLAUDE.md` (project-level, takes precedence).

This file contains:

- The dev companion persona and operating rules
- Repository inspection order (README → docs → AGENTS.md → CONTRIBUTING.md → task runners → CI)
- Coding standards and commit conventions
- Agent delegation table (which `@agent` to use for which task type)
- Cross-tool portability note

#### settings.json

The Claude Code settings file. Loaded from `~/.claude/settings.json` (global) or
`.claude/settings.json` (project-level). Configures enabled plugins and inline agent definitions.

#### agents/

Tool-specific agent definition files. Each file defines a named subagent invokable with
`@agent-name`. Files use the standard AGENT.md format with YAML frontmatter.

### How profiles are structured

The Claude Code profile uses a layered structure:

```text
profiles/claude-code/
├── CLAUDE.md          # Global system prompt
├── settings.json      # Plugin and agent settings
└── agents/
    ├── code-reviewer.md
    ├── architect.md
    └── ...            # One file per agent persona
```

### Installation

```bash
# Global install (affects all projects)
cp profiles/claude-code/CLAUDE.md ~/.claude/CLAUDE.md
cp profiles/claude-code/settings.json ~/.claude/settings.json
cp -r profiles/claude-code/agents/. ~/.claude/agents/

# Project-level install (this project only, overrides global)
mkdir -p .claude/agents
cp profiles/claude-code/CLAUDE.md .claude/CLAUDE.md
cp profiles/claude-code/settings.json .claude/settings.json
```

Restart Claude Code after installing.

### Customizing for a project

Create `.claude/CLAUDE.md` in your project root for project-specific instructions. This takes
precedence over `~/.claude/CLAUDE.md`. Keep project-level instructions focused on what is unique
to your project:

```markdown
# Project: ACME Backend

Project-specific conventions:
- Use Zod for all input validation
- All async functions must have explicit error handling
- Database queries go through the repository layer only
- Monorepo package boundary: never import across packages directly

Branch strategy: feature/TICKET-ID-brief-description
PR target: main (no staging branch)
```

For project-specific agent overrides, add agent files to `.claude/agents/`:

```bash
mkdir -p .claude/agents
# Add project-specific agents here
```

### Multiple profiles (project vs. global)

Claude Code merges project-level and global configurations with project-level taking precedence.
If both `~/.claude/agents/code-reviewer.md` and `.claude/agents/code-reviewer.md` exist, the
project-level version is used.

---

## Cursor

**Profile directory:** `profiles/cursor/`

### Files

Cursor uses `.mdc` files (Markdown with YAML frontmatter) for its Rules for AI feature. Each
file corresponds to a skill domain.

```text
profiles/cursor/rules/
├── core.mdc          # Core patterns and conventions
├── delivery.mdc      # Work item lifecycle, PRD, TRD, ADR
├── design.mdc        # UI/UX and Figma integration
├── forge.mdc         # GitHub/GitLab CLI workflows
├── integrations.mdc  # Slack, Linear, ClickUp
└── ops.mdc           # Triage, incident response
```

File format:

```markdown
---
description: Forge skills — GitHub and GitLab CLI workflows.
alwaysApply: false
---

# Forge Skills

[Rule content here]
```

### How profiles are structured

Rules can be scoped:

- **Global rules** in `~/.cursor/rules/` apply to all Cursor projects
- **Project rules** in `.cursor/rules/` (inside your repo) apply to the current project only

The `alwaysApply: false` flag means Cursor will include the rule when it is contextually relevant
rather than loading it every turn (which would consume context tokens unnecessarily).

### Installation

```bash
# Global install (all Cursor projects)
mkdir -p ~/.cursor/rules
cp profiles/cursor/rules/*.mdc ~/.cursor/rules/

# Project install (this project only)
mkdir -p .cursor/rules
cp profiles/cursor/rules/*.mdc .cursor/rules/

# Install a single domain
cp profiles/cursor/rules/forge.mdc .cursor/rules/
```

Alternatively, paste `.mdc` file contents directly into **Cursor Settings → Rules for AI**.

### Customizing for a project

Add project-specific rules by creating a new `.mdc` file in your project's `.cursor/rules/`.
Cursor merges all rule files it finds. Name your file to avoid collisions with toolkit files:

```bash
# Good
.cursor/rules/acme-backend-conventions.mdc

# Avoid (conflicts with toolkit files)
.cursor/rules/forge.mdc
```

### Using multiple profiles

You can selectively install rule domains:

```bash
# Backend project: core + delivery + forge only
cp profiles/cursor/rules/core.mdc .cursor/rules/
cp profiles/cursor/rules/delivery.mdc .cursor/rules/
cp profiles/cursor/rules/forge.mdc .cursor/rules/

# Frontend project: core + design + forge
cp profiles/cursor/rules/core.mdc .cursor/rules/
cp profiles/cursor/rules/design.mdc .cursor/rules/
cp profiles/cursor/rules/forge.mdc .cursor/rules/
```

---

## OpenCode

**Profile directory:** `profiles/opencode/`

### Files

#### opencode.json

The main OpenCode configuration file. Declares provider and model configuration plus agent
definitions. Loaded from `~/.config/opencode/opencode.json`.

#### agents/

Agent overlay files for OpenCode. Each file is loaded as an agent persona available in the
session. OpenCode reads agents from `~/.config/opencode/agents/`.

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

### Customizing for a project

Create `.opencode/config.json` in your project root for project-specific settings. OpenCode merges
project config with global config, with project config taking precedence.

---

## GitHub Copilot

**Profile directory:** `profiles/copilot/`

### Files

#### copilot-instructions.md

A Markdown file placed at `.github/copilot-instructions.md` in your repository. GitHub Copilot
reads this file and uses it as additional context for all completions and chat in that repository.

Unlike other profiles, this file is **committed to the repository** — it is part of the project,
not the user's machine configuration. The whole team benefits from it automatically.

### How profiles are structured

Copilot does not support separate agent personas or separate skill files. All skill content is
inlined into the single `copilot-instructions.md` file. The template includes:

- Project conventions and coding standards
- Skill domain declarations (edit to remove domains that do not apply)
- PR and commit message conventions
- Project-specific constraints

### Installation

```bash
mkdir -p .github
cp profiles/copilot/copilot-instructions.md .github/copilot-instructions.md

# Edit to select which domains apply
$EDITOR .github/copilot-instructions.md

# Commit so the whole team benefits
git add .github/copilot-instructions.md
git commit -m "chore: add Copilot instructions from agent-toolkit"
```

### Customizing for a project

Edit `.github/copilot-instructions.md` directly:

1. **Remove domain sections** that do not apply (e.g. remove the `design` section for a
   backend-only project)
2. **Add project constraints** at the top of the file:
   ```markdown
   ## Project: ACME Backend
   
   - Language: TypeScript + Node.js
   - Database: PostgreSQL via Drizzle ORM
   - Testing: Vitest (never Jest)
   - Architecture: monorepo with clear package boundaries
   ```
3. **Add tool notes** relevant to your stack

### Note on Copilot limitations

GitHub Copilot has the fewest agent-toolkit features of any supported tool. It supports:

- Skill context via `copilot-instructions.md`
- Core, delivery, forge, and ops domain skills
- PR and commit message conventions

It does not support:

- Separate agent personas (invokable via `@mention`)
- MCP connections
- Loop runner
- workspace-knowledge-sync (requires a `knowledge/` directory)

---

## Windsurf

**Profile directory:** `profiles/windsurf/`

### Files

#### rules/*.mdc

Windsurf uses `.mdc` rule files with the same format as Cursor. The toolkit profile ships the
same domain-organized rules adapted for Windsurf's loading format.

#### memories/global_rules.md

Windsurf's memory system loads persistent facts at session start. The `global_rules.md` file
declares conventions and standards that should always be in context, regardless of which project
is open.

### How profiles are structured

Windsurf looks for rules in:

- `~/.codeium/windsurf/rules/` (global — most installations)
- `~/.windsurf/rules/` (some newer installations — check your version's release notes)

Memories are loaded from `~/.codeium/windsurf/memories/`.

### Installation

```bash
# Install to the standard location
cp -r profiles/windsurf/. ~/.codeium/windsurf/

# Or install rules and memory separately
mkdir -p ~/.codeium/windsurf/rules ~/.codeium/windsurf/memories
cp profiles/windsurf/rules/*.mdc ~/.codeium/windsurf/rules/
cp profiles/windsurf/memories/global_rules.md ~/.codeium/windsurf/memories/

# On newer Windsurf installations (alternate path)
mkdir -p ~/.windsurf/rules
cp profiles/windsurf/rules/*.mdc ~/.windsurf/rules/
```

### Customizing for a project

Add project-specific rules by creating a `.windsurfrules` file in your project root. Windsurf
merges it with global rules.

For persistent facts, add `.md` files to `~/.codeium/windsurf/memories/` — Windsurf loads all
files in that directory at session start.

---

## Pi Coding Agent

**Profile directory:** `profiles/pi/`

### Files

Pi Coding Agent loads skill definitions from `~/.pi/agent/skills/`. Each `.md` file is a skill
the agent can invoke.

The Pi profile ships a curated set of the most universally applicable skills formatted for Pi's
loading format:

- Core: `assistant`, `development-workflow`, `pr-fallback`
- Delivery: `work-item`, `planning`, `user-story`, `bug`, `incident`
- Forge: `github-cli-workflow`, `gh-fix-ci`, `gh-address-comments`
- Ops: `triage`

### Installation

```bash
mkdir -p ~/.pi/agent/skills
cp -r profiles/pi/skills/. ~/.pi/agent/skills/
```

### Customizing for a project

Add additional skill files to `~/.pi/agent/skills/`. Use `SKILL.md` files from the `skills/`
directory as the source — Pi reads standard Markdown skill files.

```bash
# Add the data skills for a dbt project
cp ~/.agent-toolkit/skills/data/dbt-validation/SKILL.md \
   ~/.pi/agent/skills/dbt-validation.md
```

---

## The Portability Convention

For tools that support a primary instruction file (CLAUDE.md, AGENTS.md), the toolkit follows a
symlink convention so you maintain one file referenced by all tools:

```text
project-root/
├── AGENTS.md                          # Primary source of truth (committed)
├── CLAUDE.md -> AGENTS.md             # Symlink for Claude Code
├── GEMINI.md -> AGENTS.md             # Symlink for Gemini CLI
└── .github/
    └── copilot-instructions.md        # Separate (Copilot reads from .github/)
```

This avoids divergence between tool-specific instruction files. Create symlinks automatically:

```bash
bash ~/.agent-toolkit/scripts/install.sh --symlinks
```

---

## Adding a New Tool Profile

If you want to add support for a new AI tool:

1. Create `profiles/<new-tool>/` directory
2. Add tool-specific config files using that tool's native format
3. Add the tool to the compatibility matrix in each relevant skill's `skill.json`
4. Document the install path in `docs/PROFILES.md` and `docs/INSTALLATION.md`
5. Add detection and copy logic to `scripts/install.sh`
6. Open a PR — see [Contributing](Contributing)

See [docs/HOW_TO_ADD_PROFILE.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/HOW_TO_ADD_PROFILE.md)
in the repository for the step-by-step guide.
