# Architecture

agent-toolkit is organized around three layers that compose to form a complete AI capability stack for any project or team.

---

## Three-Layer Model

### L1 — Workstation / Installer

The outermost layer is the installer or workstation harness that provisions agent-toolkit onto a machine. This layer is responsible for:

- Cloning or updating the toolkit repository
- Running `scripts/install.sh` to copy profiles to the right tool-specific locations
- Managing credentials and environment variables (but never storing secrets in this repo)
- Scheduling recurring loops via a cron or loop-runner daemon

This layer is typically managed by a separate bootstrapping tool (such as a dotfiles manager or a workstation provisioner). agent-toolkit itself does not own this layer — it only provides the install script and profiles for it to use.

### L1.5 — agent-toolkit (this repo)

The middle layer is agent-toolkit itself. It is the single source of truth for:

- **Skills** — portable capability definitions that work across all supported AI tools
- **Agent personas** — tool-agnostic role definitions (architect, code-reviewer, etc.)
- **Profiles** — tool-specific configuration files generated from the skill and agent definitions
- **Loops** — recurring agentic workflow templates with budgets and safety gates
- **MCP templates** — Model Context Protocol configuration stubs for external services
- **Packs** — curated bundles that combine skills and loops for a specific outcome

This layer is meant to be stable and opinionated. Changes here propagate to every project that uses the toolkit.

### L3 — Project Overlays

The innermost layer is the project- or client-specific customization layer. Each project can:

- Override or extend profile configurations (e.g. add project-specific rules to `.cursor/rules/`)
- Define a project-level `AGENTS.md` or `.claude/CLAUDE.md` that overrides toolkit defaults
- Add project-local loops in a `loops/` directory
- Compose a project pack that references toolkit skills plus local additions

Project overlays never modify the toolkit itself. They sit on top and take precedence for that project only.

---

## How the Layers Interact

```
┌─────────────────────────────────────────────┐
│  L1 — Workstation / Installer               │
│  (chezmoi, bootstrap script, cron runner)   │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  L1.5 — agent-toolkit (this repo)    │  │
│  │                                       │  │
│  │  skills/   profiles/   loops/         │  │
│  │  agents/   mcp/        packs/         │  │
│  │                                       │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  L3 — Project Overlay           │  │  │
│  │  │                                 │  │  │
│  │  │  .claude/CLAUDE.md              │  │  │
│  │  │  .cursor/rules/project.mdc      │  │  │
│  │  │  loops/my-loop/loop.yaml        │  │  │
│  │  │  packs/my-pack.yaml             │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

Precedence (highest to lowest): Project overlay > agent-toolkit defaults > tool built-ins.

---

## Core Concepts

### Skills

A skill is a self-contained capability definition that tells an AI tool what to do in a specific situation. Every skill is a directory containing a single `SKILL.md` file — the human-readable (and AI-readable) prompt body, written in Markdown with YAML frontmatter declaring `name`, `description`, `tools`, `triggers`, and `requires`.

No `skill.json` is required. Skills follow the [Agent Skills spec](https://github.com/vercel-labs/skills) (`SKILL.md` frontmatter only). See `docs/MIGRATION.md` for notes on retiring legacy `skill.json` files.

Skills are portable: the same skill directory can be referenced by Claude Code, Cursor, OpenCode, Windsurf, GitHub Copilot, and Pi Coding Agent. Each tool reads the file format it understands.

Skills are grouped into domains (see `skills/`) and published individually or as part of packs.

### Profiles

A profile is the tool-specific configuration that wires skills into an AI tool. Because each tool has a different configuration format, agent-toolkit ships a separate profile for each:

- `profiles/claude-code/` — `CLAUDE.md` (system prompt) + `settings.json` (plugins and agents)
- `profiles/cursor/` — `.mdc` rule files for Cursor's Rules for AI feature
- `profiles/opencode/` — `opencode.json` + agent overlay files
- `profiles/copilot/` — `copilot-instructions.md` for GitHub Copilot
- `profiles/windsurf/` — rule files + `memories/global_rules.md`
- `profiles/pi/` — skill files for Pi Coding Agent

Profiles reference skills but do not duplicate them. The install script copies profiles to the locations each tool expects.

### Loops

A loop is a recurring agentic workflow with a declared goal, safety gates, and a token budget. Each loop lives in `loops/<name>/loop.yaml` and contains:

- `goal` — what the loop is trying to accomplish
- `allowlist` / `deny` — explicit lists of permitted and forbidden actions
- `budget` — maximum tokens, runs per day, and wall-clock seconds
- `exit_conditions` — when the loop should stop (goal met, budget exhausted, human escalation)
- `request` — the prompt template the loop runner executes

Loops follow a three-tier model (L1/L2/L3) based on the risk level of their actions. See [LOOPS.md](LOOPS.md) for details.

### Packs

A pack bundles skills, agents, and loops into an outcome-oriented workflow. A pack is a `pack.yaml` file (or `README.md` + `config.yaml` directory). **Packs are docs-only** (ADR-006): they are not loaded by `agent-toolkit build`; product composition lives in `distributions/products.yaml`. (or directory with a `README.md` and `config.yaml`) that declares which skills to activate, which loops to enable, and any configuration overrides.

Packs are the recommended entry point for teams. Instead of picking individual skills, you load a pack and get a coherent setup for your context (OSS maintainer, startup delivery team, data platform, etc.).

---

## Repository Structure

```
agent-toolkit/
│
├── skills/                      # Portable capability definitions
│   ├── core/                    # Foundational patterns: memory, planning, context
│   │   ├── assistant/
│   │   ├── dev-companion/
│   │   ├── onboarding/
│   │   ├── output-handshake/
│   │   ├── pr-fallback/
│   │   └── workspace-knowledge-sync/
│   ├── delivery/                # Code review, PRs, CI, work items
│   │   ├── adr/
│   │   ├── agreement/
│   │   ├── bug/
│   │   ├── decision-log/
│   │   ├── development-workflow/
│   │   ├── epic/
│   │   ├── incident/
│   │   ├── meeting-minutes/
│   │   ├── planning/
│   │   ├── prd/
│   │   ├── project-assessment/
│   │   ├── project-assessment-evidence/
│   │   ├── spike/
│   │   ├── task/
│   │   ├── technical-unit-assessment/
│   │   ├── trd/
│   │   ├── user-story/
│   │   ├── work-item/
│   │   ├── workflow-client-bootstrap/
│   │   └── workflow-generic-project/
│   ├── design/                  # UI/UX, Figma, design systems
│   │   ├── figma/
│   │   ├── figma-code-connect-components/
│   │   ├── figma-create-design-system-rules/
│   │   ├── figma-create-new-file/
│   │   ├── figma-implement-design/
│   │   └── ui-ux-pro-max/
│   ├── forge/                   # GitHub/GitLab CLI, PR automation
│   │   ├── gh-address-comments/
│   │   ├── gh-contribution-planner/
│   │   ├── gh-fix-ci/
│   │   ├── github-cli-workflow/
│   │   ├── gitlab-cli-workflow/
│   │   ├── workflow-client-bootstrap/
│   │   └── workflow-generic-project/
│   ├── integrations/            # Slack, Linear, ClickUp
│   │   ├── clickup-cli/
│   │   ├── linear/
│   │   ├── slack-assistant/
│   │   └── slack-cli/
│   ├── data/                    # dbt, Snowflake, data pipelines
│   │   ├── dbt-validation/
│   │   └── snowflake-validation/
│   ├── tooling/                 # Jupyter, Playwright CLI
│   │   ├── jupyter-notebook/
│   │   └── playwright-cli/
│   ├── ops/                     # Triage, docs generation, cost advising
│   │   ├── docs-generator/
│   │   ├── llm-cost-advisor/
│   │   └── triage/
│   └── loops/                   # Loop runner skill
│       └── loop-runner/
│
├── agents/                      # Tool-agnostic agent persona definitions
│   ├── architect/
│   ├── assistant/
│   ├── build-error-resolver/
│   ├── client-workflow-bootstrap/
│   ├── code-reviewer/
│   ├── database-reviewer/
│   ├── docs-lookup/
│   ├── e2e-runner/
│   ├── performance-optimizer/
│   ├── planner/
│   ├── refactor-cleaner/
│   ├── reference-lookup/
│   ├── security-reviewer/
│   ├── tdd-guide/
│   ├── tech-assistant/
│   └── typescript-reviewer/
│
├── profiles/                    # Tool-specific configuration files
│   ├── claude-code/             # CLAUDE.md + settings.json + agents/
│   ├── cursor/                  # rules/*.mdc
│   ├── opencode/                # opencode.json + agents/
│   ├── copilot/                 # copilot-instructions.md
│   ├── windsurf/                # rules/*.mdc + memories/
│   └── pi/                      # skills/*.md
│
├── loops/                       # Recurring agentic workflow templates
│   ├── changelog-drafter/
│   ├── ci-sweeper/
│   ├── daily-triage/
│   ├── dep-sweeper/
│   ├── issue-triage/
│   ├── oss-daily-briefing/
│   ├── oss-pr-monitor/
│   ├── oss-triage/
│   ├── post-merge-cleanup/
│   └── pr-babysitter/
│
├── mcp/
│   └── templates/               # MCP config stubs (env var placeholders only)
│       ├── clickup/
│       ├── figma/
│       ├── github/
│       ├── linear/
│       ├── notion/
│       └── slack/
│
├── packs/                       # Outcome-oriented bundles
│   ├── delivery-discipline/
│   ├── engineering-workflow/
│   └── oss-maintenance/
│
├── catalogs/                    # Machine-readable indexes
│   ├── agent-catalog.yaml
│   └── skill-catalog.yaml
│
├── schemas/                     # JSON schemas for validation
│   ├── skill-md-frontmatter.schema.json
│   └── skill.schema.json
│
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md          # This file
│   ├── INSTALLATION.md
│   ├── LOOPS.md
│   ├── MCP.md
│   ├── PROFILES.md
│   └── SKILLS.md
│
└── scripts/                     # Install and validation scripts
    ├── install.sh
    └── validate-skills.sh
```

---

## Design Decisions

**One source, many targets.** Skills are written once and deployed to every supported AI tool. This avoids the drift that happens when teams maintain separate prompt libraries per tool.

**Explicit over implicit.** Every skill declares its compatibility, requirements, and triggers. Every loop declares its allowed and denied actions. Nothing is assumed.

**Layered override.** Project-specific instructions always win over toolkit defaults. The toolkit provides sensible defaults; projects add context.

**Safety by default.** Loops ship with conservative budgets and explicit deny lists. Escalation is always a valid exit condition. No loop auto-merges to main branches by default.

**No secrets in this repo.** MCP templates use `${ENV_VAR}` placeholders. Profile files contain no credentials. The install script reads from environment variables or prompts the user.
