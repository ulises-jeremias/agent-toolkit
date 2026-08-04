# Skills Reference

Skills are the core unit of capability in agent-toolkit. Each skill is a portable, self-contained
definition that tells an AI coding assistant what to do in a specific situation. There are 52
skills across 9 domains.

---

## What Is a Skill?

A skill is a directory containing two files:

### SKILL.md

The human- and AI-readable prompt body. This is what the AI tool loads as its instruction set for
the skill. It uses YAML frontmatter followed by Markdown content:

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

### skill.json

The machine-readable manifest. Install scripts, validators, and tool integrations read this file
to understand the skill's capabilities and compatibility.

```json
{
  "$schema": "https://raw.githubusercontent.com/ulises-jeremias/agent-toolkit/main/schemas/skill.schema.json",
  "name": "gh-fix-ci",
  "version": "1.0.0",
  "description": "Triage failing GitHub Actions checks and propose minimal fixes",
  "source": "bundled",
  "author": "ulises-jeremias",
  "tags": ["ci", "github-actions", "debugging"],
  "requires": ["gh"],
  "compatibility": {
    "claude-code": { "supported": true },
    "cursor":      { "supported": true },
    "opencode":    { "supported": true },
    "windsurf":    { "supported": true },
    "copilot-cli": { "supported": false },
    "pi":          { "supported": true }
  }
}
```

---

## SKILL.md Frontmatter Spec

Validated by `schemas/skill-md-frontmatter.schema.json`. Required fields are marked with an asterisk.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` * | string | Yes | Kebab-case skill identifier. Must match the directory name exactly. Pattern: `^[a-z0-9]+(-[a-z0-9]+)*$` |
| `description` * | string | Yes | Short summary used for skill selection by the AI. Prefix with `HOW —` for tool skills or `WHAT —` for workflow skills |
| `tools` | array | No | AI tools this skill is verified to work with. Values: `claude-code`, `opencode`, `cursor`, `windsurf`, `copilot-cli`, `pi`, `universal` |
| `triggers` | array | No | Natural-language phrases that should invoke this skill |
| `requires` | array | No | CLI tools, commands, or env vars the skill needs |
| `produces` | array | No | Artifact types the skill outputs (e.g. `plan.md`, `PR`, `comment`) |
| `compatibility` | string | No | Human-readable note about caveats or prerequisites |
| `metadata.author` | string | No | GitHub username of the skill author |
| `metadata.version` | string | No | Semantic version (e.g. `"1.0"`) |

**Description prefix convention:**

- `HOW —` for tool skills that know how to operate a specific CLI or API
- `WHAT —` for workflow skills that know what to do at each project phase

---

## Skills by Domain

### core — Orchestration and session management

8 skills that underpin how the AI agent operates in any session. These are loaded by default in
every profile.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `assistant` | General-purpose AI assistant with repo inspection and convention verification. Default entry point when no other skill matches. | Yes | Yes | Yes | Yes | Yes | Yes |
| `dev-companion` | Dev companion orchestration and routing. Use for general client or project delivery work when the right workflow skill is unclear. | Yes | Yes | Yes | No | Yes | Yes |
| `onboarding` | Guided project onboarding for new team members. Initializes workspace context, discovers conventions, and walks through the repository. | Yes | Yes | Yes | Yes | Yes | Yes |
| `output-handshake` | Artifact destination gate. Confirms where to save before writing any final output. Triggers on: "where to save", "final artifact", "output destination". | Yes | Yes | Yes | No | Yes | Yes |
| `pr-fallback` | Default PR/MR body generator when no project template exists. Structures description, motivation, testing, and checklist sections. | Yes | Yes | Yes | Yes | Yes | Yes |
| `workspace-knowledge-sync` | Sync workspace knowledge base, save learnings and todos, inject session context. Requires a `knowledge/` directory at workspace root. | Yes | No | Yes | No | No | No |

CC = Claude Code, OC = OpenCode, CP = Copilot, WS = Windsurf

---

### delivery — Software delivery lifecycle

21 skills covering the full spectrum from requirements through handoff. These skills handle PRDs,
ADRs, work items, meetings, incidents, and assessments.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `adr` | Architecture Decision Record lifecycle and authoring. Triggers on: ADR, architecture decision record, technical decision record. | Yes | Yes | Yes | Yes | Yes | Yes |
| `agreement` | Agreement document with parties, terms, conditions, and validity period. | Yes | Yes | Yes | Yes | Yes | Yes |
| `bug` | Bug report template with reproduction steps, expected vs. actual behavior, and severity classification. | Yes | Yes | Yes | Yes | Yes | Yes |
| `decision-log` | Lightweight decision log entries with rationale, alternatives considered, and reversibility. | Yes | Yes | Yes | Yes | Yes | Yes |
| `development-workflow` | Default task lifecycle, Definition of Ready, Definition of Done, and validation model. | Yes | Yes | Yes | Yes | Yes | Yes |
| `epic` | Epic template with objectives, success criteria, and scope boundaries. | Yes | Yes | Yes | Yes | Yes | Yes |
| `incident` | Incident report and root cause analysis template. Triggers on: incident, RCA, production outage, service degradation. | Yes | Yes | Yes | Yes | Yes | Yes |
| `management-unit-assessment` | Management scorecard for governance, delivery process, and AI-native management readiness. | Yes | Yes | Yes | No | Yes | No |
| `meeting-minutes` | Meeting minutes with agenda, key decisions, and action items. | Yes | Yes | Yes | Yes | Yes | Yes |
| `planning` | Planning, estimation, sprint capacity, and task breakdown. | Yes | Yes | Yes | Yes | Yes | Yes |
| `prd` | Product Requirements Document authoring with personas, success metrics, and constraints. | Yes | Yes | Yes | Yes | Yes | Yes |
| `project-assessment` | Interactive project assessment intake and scoring. Routes to technical and management unit assessments. | Yes | Yes | Yes | No | Yes | No |
| `project-assessment-evidence` | Evidence map for assessment sources, confidence levels, and missing evidence. | Yes | Yes | Yes | No | Yes | No |
| `spike` | Spike and research findings with tradeoffs, options, and recommendation. | Yes | Yes | Yes | Yes | Yes | Yes |
| `task` | Technical task template with acceptance criteria and implementation notes. | Yes | Yes | Yes | Yes | Yes | Yes |
| `technical-unit-assessment` | Technical scorecard for frontend, backend, and infrastructure readiness. | Yes | Yes | Yes | No | Yes | No |
| `trd` | Technical Requirements Document authoring with architecture context and constraints. | Yes | Yes | Yes | Yes | Yes | Yes |
| `user-story` | User story template with persona, goal, and acceptance criteria. | Yes | Yes | Yes | Yes | Yes | Yes |
| `work-item` | Routes epics, stories, tasks, bugs, and incidents to their atomic templates. | Yes | Yes | Yes | Yes | Yes | Yes |
| `workflow-client-bootstrap` | Generates client-specific workflow skill pairs for new client onboarding. | Yes | Yes | Yes | No | Yes | No |
| `workflow-generic-project` | Delivery phases (plan → implement → review → PR) for any client project. | Yes | Yes | Yes | Yes | Yes | Yes |

---

### design — UI/UX and Figma integration

6 skills that bridge design tools and code.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `figma` | Figma MCP entry point. Validates Figma MCP connection and sets up required context before any design-to-code task. Requires Figma MCP configured. | Yes | No | Yes | No | Yes | No |
| `figma-code-connect-components` | Maps Figma nodes to existing code components using Figma Code Connect annotations. | Yes | No | Yes | No | Yes | No |
| `figma-create-design-system-rules` | Generates design system rule files (AGENTS.md style) from an existing Figma file. Encodes unwritten conventions. | Yes | No | Yes | No | Yes | No |
| `figma-create-new-file` | Creates a new Figma file with sane defaults, naming conventions, and initial frame structure. | Yes | No | Yes | No | Yes | No |
| `figma-implement-design` | Translates a Figma node to production code with pixel-level fidelity. Uses Figma MCP to extract design context. | Yes | Yes | Yes | No | Yes | No |
| `ui-ux-pro-max` | UI/UX design, palette enforcement, component architecture, and accessibility review. Does not require Figma. | Yes | Yes | Yes | Yes | Yes | Yes |

**Note:** All `figma-*` skills require the Figma MCP provider to be configured. See [MCP Setup](MCP-Setup) for details.

---

### forge — GitHub and GitLab automation

5 skills for code delivery on hosted platforms.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `github-cli-workflow` | Push branch and create draft PR with `gh`. Handles branch naming, PR body, and reviewer assignment. Requires `gh` CLI. | Yes | Yes | Yes | No | Yes | Yes |
| `gitlab-cli-workflow` | Push branch and create draft MR with `glab`. GitLab equivalent of `github-cli-workflow`. Requires `glab` CLI. | Yes | Yes | Yes | No | Yes | Yes |
| `gh-address-comments` | Inspects open PR review comments and applies fixes one by one, confirming with the user before each change. | Yes | Yes | Yes | No | Yes | Yes |
| `gh-fix-ci` | Triage failing GitHub Actions checks. For simple failures, proposes a minimal fix. For complex failures, posts a diagnosis comment. | Yes | Yes | Yes | No | Yes | Yes |
| `gh-contribution-planner` | Plans OSS contributions: finds suitable issues, evaluates complexity, and drafts a contribution strategy. | Yes | Yes | Yes | No | Yes | Yes |

**Example — fix CI:**

```text
"fix CI"
"why is the build red"
"debug failing checks on this PR"
```

---

### integrations — External service connectors

4 skills for team collaboration tools.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `clickup-cli` | View ClickUp task details, add comments, and update task status via the ClickUp CLI. Triggers on task IDs with `CU-` prefix. | Yes | Yes | Yes | No | Yes | No |
| `linear` | Manage Linear issues, projects, and cycles via Linear MCP. Create issues, add comments, query sprints and assignments. Requires Linear MCP. | Yes | No | Yes | No | Yes | No |
| `slack-assistant` | Read Slack channels and messages, send messages, add reactions, and browse canvases. Requires Slack MCP. | Yes | No | Yes | No | Yes | No |
| `slack-cli` | Slack app development: scaffold Bolt apps, manage manifests, and deploy via the Slack CLI. Different from `slack-assistant`. | Yes | Yes | Yes | No | Yes | No |

**When to use `slack-assistant` vs `slack-cli`:**

- `slack-assistant` — reading channels, sending notifications, checking messages in a Slack workspace
- `slack-cli` — building and deploying Slack apps and bots

---

### data — Data platform validation

2 skills for data engineering workflows.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `dbt-validation` | Run `dbt parse`, `dbt compile`, `dbt test`, and `dbt run` according to the project's docs conventions. Triggers when `dbt_project.yml` is present. | Yes | Yes | Yes | No | Yes | No |
| `snowflake-validation` | Read-only validation patterns for Snowflake queries and tables via CLI or SQL. | Yes | Yes | Yes | No | Yes | No |

---

### tooling — Developer tooling

2 skills for browser automation and notebook workflows.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `jupyter-notebook` | Scaffold reproducible Jupyter notebooks from templates. Convert Python scripts to notebooks. | Yes | Yes | Yes | No | Yes | No |
| `playwright-cli` | Drive a real browser from the terminal via Playwright MCP. Extract data from rendered pages, reproduce UI bugs, take screenshots. | Yes | Yes | Yes | No | Yes | No |

---

### ops — Operational utilities

3 operational skills.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `docs-generator` | Generate documentation from code and inline comments. Update README or API docs after code changes. | Yes | Yes | Yes | Yes | Yes | Yes |
| `llm-cost-advisor` | Analyze and advise on LLM token costs. Estimate cost for a workflow. Compare token cost across providers. Budget loop runs. | Yes | Yes | Yes | No | Yes | No |
| `triage` | General-purpose issue and task triage for workstation health, environment diagnosis, and missing tool resolution. | Yes | Yes | Yes | Yes | Yes | Yes |

---

### loops — Loop engineering support

1 skill that manages the loop engineering system.

| Skill | Description | CC | Cursor | OC | CP | WS | Pi |
|-------|-------------|:--:|:------:|:--:|:--:|:--:|:--:|
| `loop-runner` | Schedule and manage recurring agentic loops. Handles STATE.md checkpointing, cadence management, and budget enforcement. | Yes | No | Yes | No | No | No |

---

## Installing Specific Skills

### Claude Code — via settings.json

```json
{
  "skillPaths": [
    "/path/to/agent-toolkit/skills/forge/gh-fix-ci",
    "/path/to/agent-toolkit/skills/delivery/workflow-generic-project"
  ]
}
```

Or install the full Claude Code profile:

```bash
cp -r ~/.agent-toolkit/profiles/claude-code/. ~/.claude/
```

### Cursor — copy domain .mdc files

```bash
# All domains
mkdir -p .cursor/rules
cp ~/.agent-toolkit/profiles/cursor/rules/*.mdc .cursor/rules/

# One domain only
cp ~/.agent-toolkit/profiles/cursor/rules/forge.mdc .cursor/rules/
```

Available rule files:

```text
profiles/cursor/rules/
├── core.mdc          # Core patterns and conventions
├── delivery.mdc      # Work item lifecycle, PRD, TRD, ADR
├── design.mdc        # UI/UX and Figma integration
├── forge.mdc         # GitHub/GitLab CLI workflows
├── integrations.mdc  # Slack, Linear, ClickUp
└── ops.mdc           # Triage, incident response
```

### OpenCode — copy the profile

```bash
cp -r ~/.agent-toolkit/profiles/opencode/. ~/.config/opencode/
```

### GitHub Copilot — copy instructions file

```bash
mkdir -p .github
cp ~/.agent-toolkit/profiles/copilot/copilot-instructions.md .github/copilot-instructions.md
```

Edit the file to remove domains that do not apply to your project.

### Windsurf

```bash
cp -r ~/.agent-toolkit/profiles/windsurf/. ~/.codeium/windsurf/
```

### Pi Coding Agent

```bash
mkdir -p ~/.pi/agent/skills
cp -r ~/.agent-toolkit/profiles/pi/skills/. ~/.pi/agent/skills/
```

---

## Validating Skills

Run before deploying or submitting a PR:

```bash
# Validate all skills (schema, frontmatter, no secrets)
bash scripts/validate-skills.sh

# Validate a specific skill using the Python validator
python3 scripts/validate-skills.py
```

The validators check:

- Every skill directory has both `SKILL.md` and `skill.json`
- `SKILL.md` frontmatter has required `name` and `description` fields
- `skill.json` has required `name`, `version`, and `compatibility` fields
- `name` in frontmatter matches the directory name exactly
- No secrets or credential patterns are present in any file
