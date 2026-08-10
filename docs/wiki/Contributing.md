# Contributing Guide

Thank you for your interest in contributing to agent-toolkit. This document covers everything
you need to get started — from dev setup to the full walkthrough for adding skills, agents, and
loop templates.

---

## Dev Setup

### Prerequisites

| Tool | Minimum version | Purpose |
|------|----------------|---------|
| git | 2.30 | Source control |
| bash | 5.0 | Install and validation scripts. macOS ships bash 3 — install via `brew install bash` |
| Python | 3.10 | Validation scripts and CLI |
| jq | 1.6 | Catalog generation scripts |
| node / npm | 18 | npx skills and MCP server install |

Verify your setup:

```bash
git --version && bash --version && python3 --version && jq --version
```

### Clone and install

```bash
git clone https://github.com/ulises-jeremias/agent-toolkit.git
cd agent-toolkit

# Install the CLI in development mode
pip install -e ".[dev,yaml]"

# Verify
agent-toolkit --help
```

### Python development dependencies

```bash
pip install pytest ruff pyyaml jsonschema
```

### Run the test suite

```bash
pytest
```

### Validation commands

Always run all validation commands before opening a PR. All must exit 0.

```bash
# Validate all skill manifests (schema, frontmatter, no secrets)
bash scripts/validate-skills.sh

# Validate all loop template manifests
bash scripts/validate-loops.sh

# Regenerate catalogs and verify no drift with source files
bash scripts/build-catalog.sh

# Validate agent manifests
python3 scripts/validate-agents.py

# Validate skills with Python validator
python3 scripts/validate-skills.py

# Verify plugin bundles are in sync with canonical sources
python3 scripts/gen-surfaces.py --check
```

---

## Branch Naming

| Prefix | When to use |
|--------|-------------|
| `feat/` | New skill, loop template, agent persona, or major profile addition |
| `fix/` | Bug fix in an existing skill, loop, or profile |
| `docs/` | Documentation-only change |
| `chore/` | Maintenance: dependency update, script fix, catalog regeneration |
| `schema/` | Changes to JSON schemas |

Examples:

```text
feat/delivery-gh-address-comments
fix/oss-triage-missing-deny-list
docs/readme-mcp-section
chore/regenerate-catalogs
```

---

## How to Add a Skill

Full guide: [`docs/HOW_TO_ADD_SKILL.md`](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/HOW_TO_ADD_SKILL.md)

### Complete walkthrough

**Step 1 — Choose the domain**

| Domain | Purpose | Examples |
|--------|---------|---------|
| `core` | Orchestration, session management | `assistant`, `output-handshake` |
| `delivery` | Software-delivery lifecycle | `adr`, `planning`, `development-workflow` |
| `design` | UI/UX and Figma integration | `figma-implement-design`, `figma-create-design-system-rules` |
| `forge` | Version-control forge automation | `github-cli-workflow`, `gh-fix-ci` |
| `integrations` | Third-party platform connectors | `slack-cli`, `linear`, `clickup-cli` |
| `data` | Data platform validation | `dbt-validation`, `snowflake-validation` |
| `tooling` | Developer tooling | `jupyter-notebook`, `playwright-cli` |
| `ops` | Operational and health-check utilities | `triage`, `llm-cost-advisor` |
| `loops` | Recurring automation loop management | `loop-runner` |

**Step 2 — Create the directory**

```bash
mkdir -p skills/<domain>/<skill-name>
```

Skill names must be kebab-case and match the `name` field in the frontmatter exactly.

**Step 3 — Write SKILL.md**

```markdown
---
name: my-skill
description: >-
  HOW — Clear description of what this skill does and when to use it.
  Include trigger keywords so the AI knows when to invoke this skill.
metadata:
  author: your-github-username
  version: "1.0"
compatibility: Optional — any tool requirements (e.g. "requires gh CLI >= 2.40")
---

# my-skill (HOW)

One-line purpose statement.

## Capabilities

| Can do | Cannot do |
|--------|-----------|
| ... | ... |

## Step-by-step procedure

1. Step one
2. Step two
...

## Output format

Describe what the skill outputs and how it is structured.

## Safety rules

- Never do X
- Always confirm before Y

## Checklist

- [ ] Check one
- [ ] Check two
```

Use the `HOW —` prefix for tool skills (operate a CLI/API) and `WHAT —` for workflow skills
(define what to do during a project phase).

**Step 4 — Add optional references**

For skills with complex domain knowledge, create a `references/` subdirectory:

```text
skills/forge/my-skill/
├── SKILL.md
└── references/
    └── DOMAIN_REFERENCE.md
```

Keep reference files under 200 lines. Link to them explicitly from the skill body.

**Step 5 — Run validation**

```bash
python3 scripts/validate-skills.py
```

**Step 6 — Register in catalogs/skills-layout.json**

Open `catalogs/skills-layout.json` and add your skill's name to the appropriate group array.
Then regenerate:

```bash
python3 scripts/gen-surfaces.py
python3 scripts/gen-surfaces.py --check  # verify no drift
```

**Step 7 — Register in catalogs/skill-catalog.yaml**

```yaml
- name: my-skill
  domain: forge
  responsibility: HOW
  role: my_skill_role
  triggers:
    - trigger phrase one
    - trigger phrase two
  depends_on: []
```

**Step 8 — Open a PR**

PR description checklist:

```markdown
## Skill Checklist
- [ ] `skills/<domain>/<skill-name>/SKILL.md` created
- [ ] Frontmatter has `name` and `description`
- [ ] `name` in frontmatter matches directory name
- [ ] `python3 scripts/validate-skills.py` passes with no errors
- [ ] Registered in `catalogs/skills-layout.json` (correct group)
- [ ] Registered in `catalogs/skill-catalog.yaml` (with triggers)
- [ ] `python3 scripts/gen-surfaces.py --check` passes
- [ ] No secrets or hardcoded tokens in skill body
- [ ] `references/` documents linked from skill body (if present)
```

---

## How to Add an Agent

Full guide: [`docs/HOW_TO_ADD_AGENT.md`](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/HOW_TO_ADD_AGENT.md)

### Complete walkthrough

**Step 1 — Create the directory**

```bash
mkdir -p agents/<agent-name>
```

Agent names must be kebab-case and should work as an `@mention`.

**Step 2 — Write AGENT.md**

```markdown
---
name: my-agent
description: >-
  Specialist description. Use when: [trigger keywords].
  The description is shown in the agent picker — make it unambiguous.
tools: Read, Grep, Glob, Bash
---

# My Agent

You are a [role] specialist.

## When invoked

1. First action to take
2. Second action to take
...

## Domain expertise

[Tables, checklists, or structured knowledge the agent uses]

## Operating rules

**Always:**
- ...

**Never:**
- ...

**Escalate when:**
- ...

## Output format

[How the agent structures its responses]
```

Only grant `Write` or `Edit` to agents that explicitly need to mutate files. Review agents
should have `Read, Grep, Glob, Bash` only.

**Step 3 — Run validation**

```bash
python3 scripts/validate-agents.py
```

**Step 4 — Register in catalogs/agent-catalog.yaml**

```yaml
- name: my-agent
  role: my_agent_role
  domain: review
  triggers:
    - trigger phrase
    - another trigger
  handoffs:
    - code-reviewer
```

**Step 5 — Sync into plugin bundles**

```bash
python3 scripts/gen-surfaces.py
python3 scripts/gen-surfaces.py --check
```

**Step 6 — Open a PR**

PR description checklist:

```markdown
## Agent Checklist
- [ ] `agents/<agent-name>/AGENT.md` created
- [ ] Frontmatter has `name`, `description`, and `tools`
- [ ] `name` in frontmatter matches directory name
- [ ] `python3 scripts/validate-agents.py` passes with no errors
- [ ] Registered in `catalogs/agent-catalog.yaml` with triggers
- [ ] `python3 scripts/gen-surfaces.py --check` passes
- [ ] `tools` list is minimal — only what the agent genuinely needs
- [ ] No secrets or hardcoded tokens in agent body or references
```

---

## How to Create a Loop Template

Full guide: [`docs/HOW_TO_CREATE_LOOP.md`](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/HOW_TO_CREATE_LOOP.md)

### Graduated testing: always start at L1

**Never deploy a new loop at L2 or L3.** Follow this sequence:

1. Create at L1 (read-only, empty `allowlist`, full `deny` list)
2. Run at L1 for 3+ clean days (no unexpected mutations, report is accurate and stable)
3. Evaluate for upgrade to L2 (are the proposed actions correct? Do you trust it?)
4. Upgrade to L2: change `tier`, populate `allowlist`, update request prompt to act (not just propose)

### Complete walkthrough

**Step 1 — Create the directory**

```bash
mkdir -p loops/<loop-name>
```

**Step 2 — Write loop.yaml**

```yaml
name: my-loop
description: "Daily L1 read-only report of X (no mutations)"
tier: L1
cadence: 1d
resumable: true  # set true if processing 5+ items

goal: |
  What success looks like. The loop stops when this is achieved.

allowlist: []    # empty for L1
deny:
  - comment
  - label
  - assign
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
  max_tokens: 30000
  max_runs_per_day: 1
  max_wall_seconds: 600

verifier: null

request: |
  You are running the My Loop (L1 — read-only daily report).

  [Resumability instructions if resumable: true]

  Step 1 — [What to gather]
  Step 2 — [How to process]
  Step 3 — Write report to loops/my-loop/report.md

  SAFETY: [Re-state what is forbidden]
```

**Step 3 — Run validation**

```bash
python3 scripts/validate-manifests.py
```

**Step 4 — Open a PR**

PR description checklist:

```markdown
## Loop Checklist
- [ ] `loops/<loop-name>/loop.yaml` created
- [ ] `name`, `goal`, and `request` fields present
- [ ] `tier` set to L1 (all new loops start at L1)
- [ ] `budget.max_tokens` set to a conservative estimate
- [ ] `exit_conditions` includes `budget_exhausted` and `goal_met`
- [ ] `deny` list is comprehensive (L1: deny all mutations)
- [ ] `resumable: true` for any loop processing 5+ items
- [ ] Validation passes: `python3 scripts/validate-manifests.py`
- [ ] `STATE.md` and `report.md` are in `.gitignore`
- [ ] No secrets or hardcoded tokens in `loop.yaml`
- [ ] Request prompt includes explicit safety constraint statements
```

---

## Validation Commands Reference

| Command | What it checks |
|---------|---------------|
| `bash scripts/validate-skills.sh` | All skill directories have `SKILL.md`; frontmatter is valid; no secrets; no deprecated `skill.json` |
| `python3 scripts/validate-skills.py` | Same as above with more detailed error output |
| `bash scripts/validate-loops.sh` | All loop.yaml files pass the JSON schema in `schemas/loop.schema.json` |
| `python3 scripts/validate-manifests.py` | All loop manifests |
| `python3 scripts/validate-agents.py` | All agent AGENT.md files have required frontmatter |
| `bash scripts/build-catalog.sh` | Regenerates catalogs and verifies they match source files |
| `python3 scripts/gen-surfaces.py --check` | Verifies plugin bundles match canonical sources |
| `pytest` | Python CLI test suite |

---

## PR Process

1. Fork the repository
2. Create a branch: `feat/my-skill-name`
3. Make changes following the guidelines above
4. Run all validation commands (all must exit 0)
5. Open a PR with the appropriate checklist from this guide in the description
6. A maintainer will review and request changes or merge

### Commit message format

Follow Conventional Commits:

```text
feat(delivery): add gh-address-comments skill
fix(oss-triage): correct deny list in request.md
docs(readme): expand MCP templates section
chore(catalogs): regenerate after adding security-sweep loop
```

Format: `<type>(<scope>): <short imperative description>`

Types: `feat`, `fix`, `docs`, `chore`, `schema`, `refactor`, `test`

### Code of Conduct

This project follows the
[Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Report unacceptable behavior by opening a private GitHub security advisory or contacting the
maintainer directly.

### Getting help

- **GitHub Discussions** — for questions about skill design, compatibility, or architecture
- **GitHub Issues** — for bugs or feature requests
- **SECURITY.md** — for security issues
