# Plugin Marketplace

agent-toolkit ships four plugins for the Claude Code and Cursor marketplaces. Plugins bundle
skills and agents into installable units so you can get exactly the capabilities you need without
loading the entire toolkit.

---

## Claude Code: Installing from the Marketplace

### Step 1: Add the marketplace

```text
/plugin marketplace add ulises-jeremias/agent-toolkit
```

This registers the agent-toolkit plugin repository with Claude Code. You can now browse and
install individual plugins from it.

### Step 2: Install plugins

```text
/plugin install agent-toolkit-core@agent-toolkit
/plugin install agent-toolkit-agents@agent-toolkit
/plugin install agent-toolkit-forge@agent-toolkit
/plugin install agent-toolkit-craft@agent-toolkit
```

You do not need to install all four. Install what you need:

- **Just getting started:** install `agent-toolkit-core`
- **Want specialist subagents:** add `agent-toolkit-agents`
- **GitHub/GitLab automation:** add `agent-toolkit-forge`
- **Writing quality + change safety:** add `agent-toolkit-craft`

### Step 3: Verify

Open a new Claude Code session and ask:

```text
"What skills do you have available?"
```

Skills from installed plugins should appear in the response.

---

## The Four Plugins Explained

### agent-toolkit-core

**Install command:** `/plugin install agent-toolkit-core@agent-toolkit`

Covers foundational skills and delivery workflows. This is the recommended starting plugin for
any project.

**Included skills:**

| Skill | What it does |
|-------|-------------|
| `assistant` | General-purpose orchestrator. Inspects repos, verifies conventions, coordinates across domains. |
| `dev-companion` | Dev workflow routing. Routes delivery work to the right skill or subagent. |
| `output-handshake` | Artifact gate. Confirms where to save final output before writing. |
| `pr-fallback` | Default PR body generator when the repo has no PR template. |
| `workspace-knowledge-sync` | Sync workspace knowledge base and inject session context. |
| `onboarding` | Guided project onboarding. Discovers conventions, initializes context. |

**Included agents:**

| Agent | What it does |
|-------|-------------|
| `code-reviewer` | Expert code review for quality, security, and maintainability. |

**Use this plugin if:** You want core orchestration, a sane default PR template, and a
code reviewer available for every project.

---

### agent-toolkit-agents

**Install command:** `/plugin install agent-toolkit-agents@agent-toolkit`

18 agent personas (11 holistic + 2 orchestrators + 6 specialists). 7 former specialists (`database-reviewer`, `performance-optimizer`, `typescript-reviewer`, `refactor-cleaner`, `docs-lookup`, `reference-lookup`, `tech-assistant`) archived to `references/` per #865 — invoked inline via holistic owner (see `docs/AGENT_TAXONOMY.md` §3/§8). Invoke with `@mention`.

**Included agents:**

| Agent | Domain | Role |
|-------|--------|------|
| `assistant` | Orchestration | Primary orchestrator and fallback |
| `planner` | Orchestration | Feature breakdown and estimation |
| `architect` | Orchestration | System design and ADR drafting |
| `designer` | Design | UI/UX and Figma-to-code |
| `implementer` | Delivery | Code delivery |
| `reviewer` | Review | Quality, craft, change-safety |
| `qa-engineer` | QA | Lint, browser, quality gates |
| `security-engineer` | Security | Audit and threat modeling |
| `platform-engineer` | Platform | CI, loops, health, triage |
| `data-engineer` | Data | dbt/Snowflake read-only validation |
| `researcher` | Research | Discovery & evidence |
| `client-workflow-bootstrap` | Delivery | Client project onboarding |
| `code-reviewer` | Review | Quality & correctness (backs `reviewer`) |
| `security-reviewer` | Security | Vulnerability audit (backs `security-engineer`) |
| `agentic-security-reviewer` | Security | Agentic/LLM security (backs `security-engineer`) |
| `e2e-runner` | Validation | Playwright E2E authoring (backs `qa-engineer`) |
| `tdd-guide` | Validation | TDD authoring (backs `implementer`) |
| `build-error-resolver` | Validation | Build/type error triage (backs `platform-engineer`) |

> Archived → `references/`: `database-reviewer` → `reviewer/references/DATABASE_CHECKLIST.md`, `performance-optimizer` → `reviewer/references/PERFORMANCE_CHECKLIST.md`, `typescript-reviewer` → `reviewer/references/TYPESCRIPT_CHECKLIST.md`, `refactor-cleaner` → `reviewer/references/REFACTOR_CHECKLIST.md`, `docs-lookup`+`reference-lookup` → `researcher/references/LOOKUP_GUIDE.md`, `tech-assistant` → `platform-engineer/references/WORKSTATION_OPS.md`.

**Use this plugin if:** You want specialist subagents for code review, security, architecture,
testing, and documentation tasks.

---

### agent-toolkit-forge

**Install command:** `/plugin install agent-toolkit-forge@agent-toolkit`

GitHub and GitLab automation skills. PR workflows, CI triage, review comment resolution, and
contribution planning.

**Included skills:**

| Skill | What it does |
|-------|-------------|
| `github-cli-workflow` | Push branch and create draft PR with `gh`. |
| `gitlab-cli-workflow` | Push branch and create draft MR with `glab`. |
| `gh-address-comments` | Inspect and apply fixes for open PR review comments. |
| `gh-fix-ci` | Triage failing GitHub Actions, propose minimal fixes. |
| `gh-contribution-planner` | Plan OSS contributions across repos. |

**Requires:** `gh` CLI (for GitHub skills) or `glab` CLI (for GitLab skills)

**Use this plugin if:** You do a lot of GitHub PR work and want automated CI triage and PR
automation.

### agent-toolkit-craft

**Install command:** `/plugin install agent-toolkit-craft@agent-toolkit`

Writing quality and change-safety skills: cut AI tells from prose, remove AI-generated code
slop, and prove the blast radius of a change before it ships.

**Included skills:**

| Skill | What it does |
|-------|-------------|
| `unslop` | Cut AI tells from any writing. |
| `deslop` | Remove AI-generated code slop and clean up code style. |
| `blast-radius` | Find what a change could break before it ships, beyond the diff. |

**Use this plugin if:** You want focused writing/quality guardrails without loading the full
catalog.

---

## Cursor: Installing from the Marketplace

Cursor uses a different plugin mechanism. Import agent-toolkit via the Cursor team dashboard:

1. Go to **Cursor Settings → Plugins**
2. Click **Import** and paste: `https://github.com/ulises-jeremias/agent-toolkit`
3. Select the plugins you want to install

**Alternative: local symlink install:**

```bash
# Create a symlink to the toolkit's Cursor rule files
mkdir -p ~/.cursor/rules
ln -s ~/.agent-toolkit/profiles/cursor/rules/core.mdc ~/.cursor/rules/agent-toolkit-core.mdc
ln -s ~/.agent-toolkit/profiles/cursor/rules/forge.mdc ~/.cursor/rules/agent-toolkit-forge.mdc
```

The Cursor marketplace manifest is at `.cursor-plugin/marketplace.json` in the repository.

---

## Plugin Structure

Each plugin bundle has this structure:

```text
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json     # Claude Code marketplace metadata
├── .cursor-plugin/
│   └── plugin.json     # Cursor marketplace metadata
├── README.md
├── skills/             # Bundled skill copies (auto-synced from canonical skills/)
└── agents/             # Bundled agent copies (auto-synced from canonical agents/)
```

### plugin.json format (Claude Code)

```json
{
  "name": "agent-toolkit-core",
  "version": "1.0.0",
  "description": "Core orchestrator, dev companion, output handshake, PR fallback, knowledge sync, and code-reviewer agent",
  "category": "productivity",
  "tags": ["core", "orchestrator", "assistant", "companion"]
}
```

The marketplace root manifest is at `.claude-plugin/marketplace.json`. It lists all plugins with
their source paths and metadata.

---

## Updating Plugins

After a new release of agent-toolkit, update installed plugins:

**Claude Code:**

```text
/plugin update agent-toolkit-core@agent-toolkit
/plugin update agent-toolkit-agents@agent-toolkit
/plugin update agent-toolkit-forge@agent-toolkit
/plugin update agent-toolkit-craft@agent-toolkit
```

Or update all installed plugins at once:

```text
/plugin update --all
```

**Cursor:** Re-import from the dashboard or re-run the symlink setup after pulling the latest
version of the repository.

**Via git pull (manual install):**

```bash
cd ~/.agent-toolkit
git pull
./make.vsh install-cli && agent-toolkit install --force
```

---

## Building Your Own Plugin Extension

You can build plugins on top of agent-toolkit by creating a custom bundle that references
agent-toolkit skills alongside your own. This is useful for:

- Team-specific skill collections
- Client-specific delivery workflows
- Combining agent-toolkit with proprietary internal tools

### Step 1: Create your plugin directory

```text
my-team-plugin/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── skills/
│   └── my-custom-skill/
│       └── SKILL.md
└── agents/
    └── my-custom-agent/
        └── AGENT.md
```

### Step 2: Write plugin.json

```json
{
  "name": "my-team-plugin",
  "version": "1.0.0",
  "description": "Custom skills for the ACME engineering team",
  "category": "productivity",
  "tags": ["acme", "custom"],
  "dependencies": [
    "agent-toolkit-core@agent-toolkit"
  ]
}
```

### Step 3: Create marketplace.json

```json
{
  "name": "my-team-toolkit",
  "owner": {
    "name": "my-org",
    "email": "engineering@example.com"
  },
  "metadata": {
    "description": "ACME engineering team toolkit",
    "version": "1.0.0",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "my-team-plugin",
      "source": "./plugins/my-team-plugin",
      "description": "Custom skills for the ACME engineering team",
      "version": "1.0.0",
      "category": "productivity"
    }
  ]
}
```

### Step 4: Add your team's marketplace to Claude Code

```text
/plugin marketplace add my-org/my-team-toolkit
/plugin install my-team-plugin@my-team-toolkit
```

### Important rule: never edit plugin bundles directly

Plugin bundles under `plugins/` are **compiler output** from `distributions/products.yaml`
via `agent-toolkit build` (and `agent-toolkit plugin sync`). Do not hand-edit bundles —
changes are overwritten on the next build. There is no `gen-surfaces` script.

Always edit the canonical source (`skills/<domain>/<name>/SKILL.md`, `agents/<name>/AGENT.md`,
or product membership in `distributions/products.yaml`) and re-run the build/check:

```bash
./make.vsh build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit plugin check
```
