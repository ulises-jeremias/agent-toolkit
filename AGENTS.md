# AGENTS.md — AI Agent Contract

**Purpose**: This file is the primary contract for any AI agent contributing to or working inside this repository. Read it before touching any file.

---

## What This Toolkit Does

`agent-toolkit` is a modular library of AI capabilities — skills, agent personas, loop templates, MCP configs, and per-tool profiles — designed to work across every major AI coding assistant (Claude Code, Cursor, OpenCode, GitHub Copilot, Windsurf, Pi Coding Agent, Muse Code).

The goal is a single source of truth: author a skill once, deploy it to any tool via its profile. When you add, modify, or remove anything here, you are affecting every downstream consumer who installs this toolkit.

**Operate accordingly: be precise, cite sources, and validate before finalizing.**

---

## Repository Structure

```
agent-toolkit/
├── skills/
│   ├── core/           # Session bootstrap, handshake, workspace, project
│   ├── delivery/       # PRD, ADR, work items, delivery workflows
│   ├── design/         # UI/UX, Figma, frontend
│   ├── forge/          # GitHub/GitLab CLI, CI, PRs, worktrees
│   ├── integrations/   # Slack, Linear, ClickUp, MCP
│   ├── data/           # dbt, Snowflake
│   ├── tooling/        # Playwright, Jupyter, Herdr, inventory
│   ├── ops/            # Triage, swarm, docs, cost
│   ├── loops/          # loop-runner
│   ├── agentic-security/
│   ├── architecture/
│   ├── cloud/
│   ├── accessibility/
│   └── quality/
├── agents/             # Tool-agnostic agent persona definitions
├── profiles/
│   ├── claude-code/    # .claude/settings.json overlay + CLAUDE.md
│   ├── cursor/         # .mdc rule files for Cursor
│   ├── opencode/       # System prompt overlays for OpenCode
│   ├── copilot/        # copilot-instructions.md for GitHub Copilot
│   ├── windsurf/       # rules.md + memory files for Windsurf
│   ├── pi/             # Skill files for Pi Coding Agent
│   └── muse-code/      # Muse Code Agent Skills
├── mcp/
│   └── templates/      # MCP server config templates (JSON)
├── loops/              # Loop engineering templates (loop.yaml per docs/HOW_TO_CREATE_LOOP.md)
│   └── <name>/
│       ├── loop.yaml   # Required: loop definition (tier, cadence, goal, request, budget, allow/deny)
│       ├── STATE.md    # Runtime: checkpoint state (written by runner, not committed)
│       └── report.md   # Runtime: output report (written by agent, not committed)
├── packs/              # Docs-only solution packs (ADR-006) — workflow templates, not loaded by compiler
├── plugins/            # Compiler-generated target manifests (do not hand-edit; ADR-003/004)
├── distributions/      # Product specification for compiler input (products.yaml)
├── integrations/       # Swarm UI integrations (e.g., Herdr plugin; ADR-008)
├── catalogs/
│   ├── skill-catalog.yaml
│   └── agent-catalog.yaml
├── schemas/            # JSON schemas for validation
│   ├── skill-md-frontmatter.schema.json
│   └── loop.schema.json
├── docs/               # Human-facing documentation
│   ├── CONCEPTS.md     # Public concept model — see "Three kinds of packs"
│   └── adrs/           # Architecture Decision Records
└── scripts/            # validate-skills.vsh, validate-agents.vsh, validate-loops.vsh, generate-catalogs.vsh (provenance.py kept)
```

---

## Operating Rules

**Always:**

- Check `catalogs/skill-catalog.yaml` before adding a new skill — avoid duplicates
- Validate with `./scripts/validate-skills.vsh` before marking any skill work complete
- Cite which file a convention comes from when referencing repo standards
- Use English for all file content, commit messages, and PR descriptions
- Check `SKILL.md` frontmatter (`tools`, `requires`) before claiming a skill works with a tool
- Keep secrets out of the repository — MCP templates use placeholder values only
- When adding or modifying skills, follow [docs/SKILL_INTEGRATION_CHECKLIST.md](docs/SKILL_INTEGRATION_CHECKLIST.md) — orchestration, agents, products, and build verification are mandatory
- When evaluating third-party skills, follow [docs/UPSTREAM_VS_FIRST_PARTY.md](docs/UPSTREAM_VS_FIRST_PARTY.md) — prefer first-party enhancement over duplicate upstream vendors

**Never:**

- Commit credentials, API keys, or tokens to any file
- Claim a skill is compatible with a tool without testing or explicit authorship confirmation
- Skip required `SKILL.md` frontmatter when adding a skill
- Hand-edit generated catalogs (`skill-catalog.yaml`, `agent-catalog.yaml`, `loop-catalog.yaml`) — regenerate with `./scripts/generate-catalogs.vsh` only (`skills-layout.json` is hand-maintained layout SSOT; see Catalog Generation)
- Add content specific to any private organization — this is a public, vendor-neutral toolkit
- Add third-party npm / github / url packs to `distributions/products.yaml` or `plugins/` — they belong in `agentic-workstation` via `chezmoiexternal` + `skills-external/` (see `docs/CONCEPTS.md` “Third-party boundary”)

---

## How to Add a Skill

Each skill lives in its own directory under the appropriate domain:

```
skills/<domain>/<skill-name>/
└── SKILL.md       # Human-readable description and usage guide (YAML frontmatter)
```

Skills use `SKILL.md` frontmatter only — no `skill.json` required. See `docs/MIGRATION.md` for
historical notes on the v1.0.4 removal of `skill.json`.

### SKILL.md Frontmatter Spec

Every `SKILL.md` must begin with a YAML frontmatter block:

```markdown
---
name: my-skill-name
description: One-sentence description of what this skill does.
metadata:
  author: github-username
  version: "1.0.0"
  tags:
    - tag1
    - tag2
  domain: delivery        # one of: accessibility, agentic-security, architecture, cloud, core, data, delivery, design, forge, integrations, loops, ops, quality, tooling
---

# My Skill Name

[Human-readable usage guide follows]
```

Required frontmatter fields:

| Field | Type | Description |
|---|---|---|
| `name` | string | Kebab-case skill identifier, unique within the domain |
| `description` | string | One sentence, present tense ("Reviews pull requests for…") |
| `metadata.author` | string | GitHub username of the primary author |
| `metadata.version` | string | Semver string, start at `"1.0.0"` |
| `metadata.tags` | list | Searchable tags, lowercase kebab-case |
| `metadata.domain` | string | Parent domain directory name |

Optional frontmatter fields for tool compatibility and discovery:

| Field | Type | Description |
|---|---|---|
| `tools` | list | AI tools this skill is verified to work with |
| `requires` | list | CLI tools or env vars the skill needs |
| `triggers` | list | Natural-language phrases that should invoke this skill |

Run `./scripts/validate-skills.vsh` to validate
frontmatter against `schemas/skill-md-frontmatter.schema.json`.

### Upstream vs first-party

Before vendoring a third-party skill, read [docs/UPSTREAM_VS_FIRST_PARTY.md](docs/UPSTREAM_VS_FIRST_PARTY.md).
If a first-party skill already covers the domain, **enhance it** and record `metadata.inspired_by[]`
instead of adding a duplicate upstream copy. After any skill change, complete
[docs/SKILL_INTEGRATION_CHECKLIST.md](docs/SKILL_INTEGRATION_CHECKLIST.md) (orchestration in
`skills/core/assistant/references/ORCHESTRATION.md`, agent delegates, products, `build --check`).

---

## How to Add a Loop Template

Loop templates are defined by `loops/<loop-name>/loop.yaml` per `docs/HOW_TO_CREATE_LOOP.md` and `schemas/loop.schema.json`. The legacy `request.md`/`report.md`/`runbook.md` triple is historical — all loop definition now lives in `loop.yaml`; `STATE.md` and `report.md` are runtime artifacts, not committed.

### loop.yaml — Loop Definition

```yaml
name: my-loop-name
description: "Daily L1 read-only report (no mutations)"
tier: L1                        # L1 read-only, L2 PR-gated writes, L3 allowlisted merge/close
cadence: 1d                     # \d+[mhd] e.g. 15m, 1d — see schemas/loop.schema.json
goal: |
  One sentence describing the loop objective. The loop stops when this is achieved.
allowlist: []                   # permitted mutation actions (empty = read-only)
deny:
  - merge
  - close
  - push
  - approve
  - force-push
exit_conditions:
  - goal_met
  - budget_exhausted
  - human_escalation
budget:
  max_tokens: 50000              # max tokens per run
  max_runs_per_day: 1            # max runs per 24h
  max_wall_seconds: 600          # hard timeout in seconds
verifier: null                  # post-run quality gate agent, or null
resumable: true                 # whether STATE.md checkpoints are written
request: |
  [Full prompt body — self-contained, step-by-step instructions. Use {{variables}} for substitution.]
```

Required field: `name`, `goal`, `request` (per `schemas/loop.schema.json`). Common optional fields: `tier` (`L1`|`L2`|`L3`), `cadence` (`^\d+[mhd]$`), `allowlist`/`deny`, `exit_conditions` (`goal_met`, `budget_exhausted`, `human_escalation`, `max_iterations`, `no_work_found`, `error`), `budget` (`max_tokens`, `max_runs_per_day`, `max_wall_seconds`, `max_iterations`), `verifier`, `resumable`. See `docs/HOW_TO_CREATE_LOOP.md` for tier/budget guidance and resumability pattern.

Validate before committing (same as CI `validate-loops` job):

```bash
./scripts/validate-loops.vsh
```

---

## How to Add a Profile

Profiles adapt toolkit skills for a specific tool. Each profile lives in `profiles/<tool-name>/`.

### Claude Code (`profiles/claude-code/`)

- `CLAUDE.md` — system prompt overlay referencing skills by path
- `settings.json` — skill loading configuration

### Cursor (`profiles/cursor/`)

- `rules/<domain>.mdc` — one rule file per domain, using Cursor's MDC format
- Keep each rule file focused on one domain; avoid catch-all files

### OpenCode (`profiles/opencode/`)

- `opencode.json` — system prompt that opencode loads on startup
- `skills.yaml` — list of skill paths to inject

### GitHub Copilot (`profiles/copilot/`)

- `copilot-instructions.md` — the file that gets copied to `.github/copilot-instructions.md` in projects
- Must be self-contained (Copilot cannot reference external files at runtime)

### Windsurf (`profiles/windsurf/`)

- `rules.md` — rules file that Windsurf loads from `~/.codeium/windsurf/`
- `memories/` — optional pre-seeded memory files

### Pi Coding Agent (`profiles/pi/`)

- `skills/<skill-name>.md` — individual skill files in Pi's expected format
- Pi skills are standalone; each file must be self-contained

---

## Agent Persona Format

Agent personas in `agents/` are a single `AGENT.md` with YAML frontmatter (no `persona.json` / `README.md` pair):

```
agents/<persona-name>/
└── AGENT.md       # Frontmatter + persona body (optional references/)
```

`AGENT.md` frontmatter (match real `agents/*/AGENT.md`; validated by `scripts/validate-agents.vsh`):

```markdown
---
name: persona-name
description: >-
  What this persona does and when to use it.
  Use when: trigger keywords for agent selection.
tools: Read, Grep, Glob, Bash
---

# Persona title

[Role description, operating rules, output format…]
```

| Field | Type | Description |
|---|---|---|
| `name` | string | Kebab-case; must match the directory name |
| `description` | string | Selection text for the AI tool's agent picker |
| `tools` | string | Comma-separated allowlist of tools the persona may use |

Optional: `references/` beside `AGENT.md` for domain checklists. See [`docs/HOW_TO_ADD_AGENT.md`](docs/HOW_TO_ADD_AGENT.md).

---

## Catalog Generation

`catalogs/skill-catalog.yaml`, `catalogs/agent-catalog.yaml`, and `catalogs/loop-catalog.yaml` are **generated files**. Do not edit them by hand — regenerate with `generate-catalogs.vsh` only.

`catalogs/skills-layout.json` is **not** generated by `generate-catalogs.vsh`. It is the hand-maintained SSOT for domain → skill grouping used by `agent-toolkit skills list` (`modules/agent_toolkit_core/skills.v`). Update it when adding a skill to a domain group.

To regenerate YAML catalogs after adding or modifying skills or agents:

```bash
./scripts/generate-catalogs.vsh          # regenerate catalogs/*-catalog.yaml
./scripts/generate-catalogs.vsh --check  # fail if committed catalogs drifted
```

The CI pipeline runs this automatically and will fail if the YAML catalogs are out of sync with the source files.

---

## Validation

Before marking any contribution complete (see `.github/workflows/validate.yml` for CI parity):

```bash
./scripts/validate-skills.vsh     # Validates SKILL.md frontmatter (no skill.json)
./scripts/validate-agents.vsh     # Validates AGENT.md frontmatter
./scripts/validate-loops.vsh      # Validates loops/**/loop.yaml against loop.schema.json
./scripts/generate-catalogs.vsh   # Regenerates YAML catalogs (never hand-edit)
./make.vsh test && ./make.vsh build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
# Adapter-only (optional unless changing PyPI/npm trampolines):
AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
npm test --prefix packages/npm/agent-toolkit-cli
```

All primary checks must exit 0. There is no `gen-surfaces` script — plugin digests are enforced by `build --check` only. V is the product CLI (pin `.v-version` / 0.5.2, `import json` not json2 — [`docs/HOW_TO_DEVELOP_V.md`](docs/HOW_TO_DEVELOP_V.md)). Run `uv sync --project packages/pypi/agent-toolkit-cli --all-extras` first for pytest only (the repo is not a uv workspace).
---

## Ecosystem — Where This Fits

`agent-toolkit` is the **capability distribution layer (L1.5)** in a three-tier personal DX stack:

```
L1  │ agentic-workstation  │ Machine provisioning (chezmoi, shell, packages, LLM policy)
    │                      │ https://github.com/ulises-jeremias/agentic-workstation
────┼──────────────────────┼─────────────────────────────────────────────────────────────
L1.5│ agent-toolkit        │ THIS REPO — Capability distribution (skills, loops, profiles)
    │ (this repo)          │ V binary: brew / AUR agent-toolkit-bin / GitHub / uv launcher / npm
────┼──────────────────────┼─────────────────────────────────────────────────────────────
L3  │ agentic-harness      │ AI workspace scaffold for multi-repo orchestration
    │                      │ https://github.com/ulises-jeremias/agentic-harness
```

**Integration flow:**
1. `agentic-workstation` installs the V CLI during `chezmoi apply` (brew / AUR `agent-toolkit-bin` / GitHub / `uv tool install 'agent-toolkit-cli>=1.11.0'`)
2. `agent-toolkit install` deploys profiles to detected AI tools (Claude Code, Cursor, etc.)
3. `agentic-harness` workspaces call `agent-toolkit loop`, `agent-toolkit memory`, etc.

---

## CLI Reference for Agents

When working in a workspace that has `agent-toolkit` installed, use these commands:

```bash
# Installation (V binary — pick one channel; see docs/INSTALLATION.md)
# brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
# yay -S agent-toolkit-bin
# GitHub Release: agent-toolkit-<os>-<arch> from /releases/latest
uv tool install 'agent-toolkit-cli>=1.11.0'    # PyPI launcher over bundled V
agent-toolkit install [--force]                # deploy profiles to detected AI tools
agent-toolkit doctor                           # verify installation health

# Skills and inventory
agent-toolkit inventory                        # list all 84 skills
agent-toolkit skills list                      # list with domain breakdown
agent-toolkit skills validate                  # check SKILL.md compliance

# Knowledge base (from any workspace with knowledge/)
agent-toolkit memory search "topic"            # find existing knowledge
agent-toolkit memory add --type learning "..." # save a pattern or discovery
agent-toolkit memory add --type todo "..."     # track a follow-up
agent-toolkit memory inject                    # output knowledge for context
agent-toolkit memory todo                      # review pending items

# Loop engineering (from workspace with loops/ or templates/loops/)
agent-toolkit loop init <pattern>              # scaffold from template
agent-toolkit loop run <name>                  # execute one iteration
agent-toolkit loop status                      # show all loop instances
agent-toolkit loop audit <name>                # review past runs
agent-toolkit loop schedule <name>             # install systemd/launchd timer
agent-toolkit loop templates                   # list available templates

# Workspace management
agent-toolkit workspace context                # session state snapshot
agent-toolkit workspace use-persona <name>     # activate a work mode
agent-toolkit workspace load packs/<n>.yaml    # load client context bundle
agent-toolkit workspace validate               # validate workspace schemas

# Project / repo management
agent-toolkit project init                     # create repos/ + projects/ dirs
agent-toolkit project clone owner/repo [--ssh] # clone + symlink
agent-toolkit project list                     # list indexed projects

# Background jobs
agent-toolkit devcompanion queue <project> --request "..." # queue async job
agent-toolkit devcompanion run-once            # process next job
agent-toolkit devcompanion status              # show queue state

# MCP providers
agent-toolkit mcp list                         # available providers
agent-toolkit mcp setup <provider>             # interactive MCP setup
agent-toolkit mcp doctor                       # check provider health

# Build and deploy
agent-toolkit build --check                    # dry-run compilation
agent-toolkit build --target claude-code       # compile one target
agent-toolkit diff                             # show changes vs installed bundles
```

---

## Cross-Repo Links

- **agentic-workstation** → [`AGENTS.md`](https://github.com/ulises-jeremias/agentic-workstation/blob/main/AGENTS.md) | [`docs/AGENT_TOOLKIT.md`](https://github.com/ulises-jeremias/agentic-workstation/blob/main/docs/AGENT_TOOLKIT.md)
- **agentic-harness** → [`AGENTS.md`](https://github.com/ulises-jeremias/agentic-harness/blob/main/AGENTS.md) | [`docs/ARCHITECTURE.md`](https://github.com/ulises-jeremias/agentic-harness/blob/main/docs/ARCHITECTURE.md)
