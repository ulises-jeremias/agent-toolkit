# Skills

Skills are the core unit of capability in agent-toolkit. Each skill is a portable, self-contained definition that tells an AI coding assistant what to do in a specific situation.

---

## Product membership

Discoverability: only a minority of skills appear in stable marketplace products. Check membership via:

- **Matrix (checked in):** [`docs/SKILL_PRODUCT_MATRIX.md`](SKILL_PRODUCT_MATRIX.md) — generated from `distributions/products.yaml` (`python3 scripts/generate-skill-matrix.py --check` in CI)
- **Live CLI:** `agent-toolkit inventory` (lists skills by domain + products)

## What Is a Skill?

A skill is a directory containing exactly two files:

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

Tool compatibility is declared via optional `tools` frontmatter and validated by `scripts/validate-skills.py`. Legacy `skill.json` manifests were removed in v1.0.4 — see `docs/MIGRATION.md`.

---

## Skill Domains

Skills are grouped into 9 domains based on their primary responsibility.

### core

Foundational patterns that underpin how the AI agent operates in any session. These are the skills most likely to be loaded by default in every profile.

Skills: `assistant`, `dev-companion`, `onboarding`, `output-handshake`, `pr-fallback`, `workspace-knowledge-sync`

### delivery

Work-item lifecycle, documentation artifacts, and project delivery processes. These skills handle the full spectrum from requirements (PRD, TRD, ADR) through execution (tasks, bugs, incidents) to handoff.

Skills: `adr`, `agreement`, `bug`, `decision-log`, `development-workflow`, `epic`, `incident`, `management-unit-assessment`, `meeting-minutes`, `planning`, `prd`, `project-assessment`, `project-assessment-evidence`, `spike`, `task`, `technical-unit-assessment`, `trd`, `user-story`, `work-item`, `workflow-client-bootstrap`, `workflow-generic-project`

### design

UI/UX design, Figma integration, and design system rules. These skills bridge design tools and code.

Skills: `figma`, `figma-code-connect-components`, `figma-create-design-system-rules`, `figma-create-new-file`, `figma-implement-design`

### forge

GitHub and GitLab CLI workflows, PR automation, and contribution planning. These skills handle the mechanics of code delivery on hosted platforms.

Skills: `gh-address-comments`, `gh-contribution-planner`, `gh-fix-ci`, `github-cli-workflow`, `gitlab-cli-workflow`, `workflow-client-bootstrap`, `workflow-generic-project`

### integrations

External service integrations for team collaboration tools. These skills provide structured interfaces to Slack, Linear, and ClickUp.

Skills: `clickup-cli`, `linear`, `slack-assistant`, `slack-cli`

### data

Data platform skills for dbt, Snowflake, and pipeline validation. These skills know the idioms of data engineering and run read-only validation by default.

Skills: `dbt-validation`, `snowflake-validation`

### tooling

Developer tooling skills for browser automation and notebook workflows.

Skills: `jupyter-notebook`, `playwright-cli`

### ops

Operational skills for triage, documentation generation, and LLM cost analysis.

Skills: `docs-generator`, `llm-cost-advisor`, `triage`

### loops

Skills that support the loop engineering system, including the loop-runner skill that manages scheduling and state.

Skills: `loop-runner`

---

## Full Skill Table

| Skill | Domain | Description | Claude Code | Cursor | OpenCode | Copilot | Windsurf | Pi |
|-------|--------|-------------|:-----------:|:------:|:--------:|:-------:|:--------:|:--:|
| `assistant` | core | General-purpose AI assistant with repo inspection | Yes | Yes | Yes | Yes | Yes | Yes |
| `dev-companion` | core | Dev companion orchestration and routing | Yes | Yes | Yes | No | Yes | Yes |
| `onboarding` | core | Project onboarding and convention discovery | Yes | Yes | Yes | Yes | Yes | Yes |
| `output-handshake` | core | Artifact destination gate before writing deliverables | Yes | Yes | Yes | No | Yes | Yes |
| `pr-fallback` | core | Default PR/MR body when no repo template exists | Yes | Yes | Yes | Yes | Yes | Yes |
| `workspace-knowledge-sync` | core | Sync workspace knowledge base and inject session context | Yes | No | Yes | No | No | No |
| `adr` | delivery | Architecture Decision Record lifecycle and authoring | Yes | Yes | Yes | Yes | Yes | Yes |
| `agreement` | delivery | Agreement document with parties, terms, and validity | Yes | Yes | Yes | Yes | Yes | Yes |
| `bug` | delivery | Bug report template and bug-vs-incident classification | Yes | Yes | Yes | Yes | Yes | Yes |
| `decision-log` | delivery | Lightweight decision log entries with rationale | Yes | Yes | Yes | Yes | Yes | Yes |
| `development-workflow` | delivery | Default task lifecycle, DoR, DoD, validation model | Yes | Yes | Yes | Yes | Yes | Yes |
| `epic` | delivery | Epic template with objectives and success criteria | Yes | Yes | Yes | Yes | Yes | Yes |
| `incident` | delivery | Incident report and RCA template | Yes | Yes | Yes | Yes | Yes | Yes |
| `management-unit-assessment` | delivery | Management scorecard for governance and delivery | Yes | Yes | Yes | No | Yes | No |
| `meeting-minutes` | delivery | Meeting minutes with agenda, decisions, action items | Yes | Yes | Yes | Yes | Yes | Yes |
| `planning` | delivery | Planning, estimation, and task breakdown | Yes | Yes | Yes | Yes | Yes | Yes |
| `prd` | delivery | Product Requirements Document authoring | Yes | Yes | Yes | Yes | Yes | Yes |
| `project-assessment` | delivery | Interactive project assessment intake and scoring | Yes | Yes | Yes | No | Yes | No |
| `project-assessment-evidence` | delivery | Evidence map for assessment sources and confidence | Yes | Yes | Yes | No | Yes | No |
| `spike` | delivery | Spike and research findings with tradeoffs | Yes | Yes | Yes | Yes | Yes | Yes |
| `task` | delivery | Technical task template with acceptance criteria | Yes | Yes | Yes | Yes | Yes | Yes |
| `technical-unit-assessment` | delivery | Technical scorecard for frontend, backend, infra | Yes | Yes | Yes | No | Yes | No |
| `trd` | delivery | Technical Requirements Document authoring | Yes | Yes | Yes | Yes | Yes | Yes |
| `user-story` | delivery | User story template with persona and acceptance criteria | Yes | Yes | Yes | Yes | Yes | Yes |
| `work-item` | delivery | Route epics, stories, tasks, bugs to atomic templates | Yes | Yes | Yes | Yes | Yes | Yes |
| `workflow-client-bootstrap` | delivery | Generate client-specific workflow skill pairs | Yes | Yes | Yes | No | Yes | No |
| `workflow-generic-project` | delivery | Delivery phases for any client project | Yes | Yes | Yes | Yes | Yes | Yes |
| `figma` | design | Figma MCP entry point with required flow | Yes | No | Yes | No | Yes | No |
| `figma-code-connect-components` | design | Map Figma nodes to existing code components | Yes | No | Yes | No | Yes | No |
| `figma-create-design-system-rules` | design | Generate design system rule files from Figma | Yes | No | Yes | No | Yes | No |
| `figma-create-new-file` | design | Create a new Figma file with sane defaults | Yes | No | Yes | No | Yes | No |
| `figma-implement-design` | design | Translate Figma node to production code | Yes | Yes | Yes | No | Yes | No |
| `gh-address-comments` | forge | Inspect and apply fixes for open PR review comments | Yes | Yes | Yes | No | Yes | Yes |
| `gh-contribution-planner` | forge | Plan OSS contributions across repos | Yes | Yes | Yes | No | Yes | Yes |
| `gh-fix-ci` | forge | Triage failing GitHub Actions, propose minimal fixes | Yes | Yes | Yes | No | Yes | Yes |
| `github-cli-workflow` | forge | Push branch and create draft PR with gh | Yes | Yes | Yes | No | Yes | Yes |
| `gitlab-cli-workflow` | forge | Push branch and create draft MR with glab | Yes | Yes | Yes | No | Yes | Yes |
| `clickup-cli` | integrations | Task view, comments, and status via ClickUp CLI | Yes | Yes | Yes | No | Yes | No |
| `linear` | integrations | Manage Linear issues and cycles via Linear MCP | Yes | No | Yes | No | Yes | No |
| `slack-assistant` | integrations | Read channels, send messages, browse canvases | Yes | No | Yes | No | Yes | No |
| `slack-cli` | integrations | Slack app development via slack CLI | Yes | Yes | Yes | No | Yes | No |
| `dbt-validation` | data | Run dbt parse, compile, test, run per repo docs | Yes | Yes | Yes | No | Yes | No |
| `snowflake-validation` | data | Read-only validation patterns via CLI or SQL | Yes | Yes | Yes | No | Yes | No |
| `jupyter-notebook` | tooling | Scaffold reproducible Jupyter notebooks | Yes | Yes | Yes | No | Yes | No |
| `playwright-cli` | tooling | Drive a real browser from the terminal via Playwright | Yes | Yes | Yes | No | Yes | No |
| `docs-generator` | ops | Generate documentation from code and comments | Yes | Yes | Yes | Yes | Yes | Yes |
| `llm-cost-advisor` | ops | Analyze and advise on LLM token costs | Yes | Yes | Yes | No | Yes | No |
| `triage` | ops | General-purpose issue and task triage | Yes | Yes | Yes | Yes | Yes | Yes |
| `loop-runner` | loops | Schedule and manage recurring agentic loops | Yes | No | Yes | No | No | No |

---

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
bash scripts/validate-skills.sh
```

This checks:
- Every skill directory has `SKILL.md`
- `SKILL.md` frontmatter has required `name` and `description` fields
- Frontmatter validates against `schemas/skill-md-frontmatter.schema.json`
- No `skill.json` files are present (deprecated since v1.0.4)
- No secrets or credential patterns are present in any file
