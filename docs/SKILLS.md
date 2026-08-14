# Skills

Skills are the core unit of capability in agent-toolkit. Each skill is a portable, self-contained definition that tells an AI coding assistant what to do in a specific situation.

---

## Product membership

Discoverability: only a minority of skills appear in stable marketplace products. Check membership via:

- **Matrix (checked in):** [`docs/SKILL_PRODUCT_MATRIX.md`](SKILL_PRODUCT_MATRIX.md) — generated from `distributions/products.yaml` (`v run scripts/generate-skill-matrix.vsh --check` in CI)
- **Live CLI:** `agent-toolkit inventory` (lists skills by domain + products)

## What Is a Skill?

A skill is a directory containing a `SKILL.md` (YAML frontmatter + Markdown). No `skill.json`.

### SKILL.md

The human- and AI-readable prompt body. This is what the AI tool loads as its instruction set for the skill. It uses YAML frontmatter followed by Markdown content.

```yaml
---
name: gh-fix-ci
description: Triage failing GitHub Actions checks and propose minimal fixes
tools: [claude-code, opencode, cursor, windsurf]
triggers:
  - fix CI
  - debug failing checks
  - why is the build red
requires:
  - gh
produces:
  - plan.md
  - draft PR
---

# gh-fix-ci

[Skill body here — instructions, steps, safety rules, examples]
```

Required frontmatter fields (validated by `schemas/skill-md-frontmatter.schema.json`):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Kebab-case skill identifier, must match directory name |
| `description` | string | Yes | Short summary used in skill selection |
| `tools` | array | No | AI tools this skill is verified to work with |
| `triggers` | array | No | Natural-language phrases that should invoke this skill |
| `requires` | array | No | CLI tools or env vars the skill needs |
| `produces` | array | No | Artifact types the skill outputs |
| `compatibility` | string | No | Human-readable notes about caveats or prerequisites |

Tool compatibility is declared via optional `tools` frontmatter and validated by `scripts/validate-skills.vsh`. Legacy `skill.json` manifests were removed in v1.0.4 — see `docs/MIGRATION.md`.

---

## Skill Domains

Skills live under `skills/<domain>/<name>/`. There are **14 domains** (77 skills). Membership in marketplace products is a subset — see [`SKILL_PRODUCT_MATRIX.md`](SKILL_PRODUCT_MATRIX.md) and `agent-toolkit inventory`.

| Domain | Count | Examples |
|--------|------:|----------|
| `core` | 8 | `assistant`, `dev-companion`, `workspace`, `project`, `onboarding` |
| `delivery` | 21 | `adr`, `prd`, `bug`, `planning`, `work-item` |
| `design` | 10 | `figma-implement-design`, `frontend-design` |
| `forge` | 8 | `github-cli-workflow`, `gh-fix-ci`, `worktree` |
| `integrations` | 5 | `slack-cli`, `linear`, `clickup-cli`, `mcp` |
| `data` | 2 | `dbt-validation`, `snowflake-validation` |
| `tooling` | 6 | `playwright-cli`, `jupyter-notebook`, `herdr`, `inventory` |
| `ops` | 6 | `triage`, `swarm`, `llm-cost-advisor` |
| `loops` | 1 | `loop-runner` |
| `agentic-security` | 4 | `threat-modeling`, `mcp-audit` |
| `cloud` | 2 | `cloud-design-patterns` |
| `architecture` | 1 | `c4-model` |
| `accessibility` | 1 | `review` |
| `quality` | 2 | `megalinter`, `codeql` |

Tool compatibility is declared in each `SKILL.md` `tools:` frontmatter. Do not maintain a second compatibility matrix here — use the catalog.

## Installing Skills

### Claude Code

Reference skills in your project's `.claude/settings.json` or load the profile globally:

```bash
# Option 1: Install the full Claude Code profile globally
cp -r /path/to/agent-toolkit/profiles/claude-code/. ~/.claude/

# Option 2: Copy individual skill files
mkdir -p ~/.claude/skills/gh-fix-ci
cp /path/to/agent-toolkit/skills/forge/gh-fix-ci/SKILL.md ~/.claude/skills/gh-fix-ci/
```

For plugin-based loading, reference skills by path:

```json
{
  "skillPaths": [
    "/path/to/agent-toolkit/skills/forge/gh-fix-ci",
    "/path/to/agent-toolkit/skills/delivery/workflow-generic-project"
  ]
}
```

### Cursor

Copy rule files into your project's `.cursor/rules/` directory:

```bash
mkdir -p .cursor/rules
cp /path/to/agent-toolkit/profiles/cursor/rules/*.mdc .cursor/rules/
```

Each `.mdc` file corresponds to a domain and includes the skill instructions formatted for Cursor's Rules for AI feature.

### OpenCode

Copy the profile to OpenCode's config directory:

```bash
cp -r /path/to/agent-toolkit/profiles/opencode/. ~/.config/opencode/
```

OpenCode reads agents from `~/.config/opencode/agents/` and the main config from `~/.config/opencode/opencode.json`.

### GitHub Copilot

Copy the instructions file into your project's `.github/` directory:

```bash
mkdir -p .github
cp /path/to/agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

Edit the file to select which domains apply to your project before committing.

### Windsurf

Copy the Windsurf profile to Codeium's config directory:

```bash
cp -r /path/to/agent-toolkit/profiles/windsurf/. ~/.codeium/windsurf/
```

Windsurf reads rule files and memory files from this directory automatically.

### Pi Coding Agent

```bash
mkdir -p ~/.pi/agent/skills
cp -r /path/to/agent-toolkit/profiles/pi/skills/. ~/.pi/agent/skills/
```

---

## Compatibility Matrix Explained

Tool compatibility is declared in `SKILL.md` frontmatter via the optional `tools` list and in generated catalogs (`catalogs/skill-catalog.yaml`). A tool listed in `tools` means the skill has been tested and works with that tool's native skill-loading mechanism.

A skill not listing a tool does not mean you cannot use its concepts — it means structured loading for that tool has not been verified. You can always paste `SKILL.md` content into a tool's system prompt manually.

Common tool identifiers in frontmatter and catalogs:

| Key | Tool |
|-----|------|
| `claude-code` | Claude Code (Anthropic) |
| `cursor` | Cursor |
| `opencode` | OpenCode |
| `copilot-cli` | GitHub Copilot |
| `windsurf` | Windsurf (Codeium) |
| `pi` | Pi Coding Agent |

---

## Validating Skills

Run the validation script before deploying:

```bash
v run scripts/validate-skills.vsh
```

This checks:
- Every skill directory has `SKILL.md`
- `SKILL.md` frontmatter has required `name` and `description` fields
- Frontmatter validates against `schemas/skill-md-frontmatter.schema.json`
- No `skill.json` files are present (deprecated since v1.0.4)
- No secrets or credential patterns are present in any file
