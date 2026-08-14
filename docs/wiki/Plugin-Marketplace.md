# Plugin Marketplace

agent-toolkit ships three plugins for the Claude Code and Cursor marketplaces. Plugins bundle
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
```

You do not need to install all three. Install what you need:

- **Just getting started:** install `agent-toolkit-core`
- **Want specialist subagents:** add `agent-toolkit-agents`
- **GitHub/GitLab automation:** add `agent-toolkit-forge`

### Step 3: Verify

Open a new Claude Code session and ask:

```text
"What skills do you have available?"
```

Skills from installed plugins should appear in the response.

---

## The Three Plugins Explained

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

The marketplace persona plugin (16 agents). Disk has 17 including `agentic-security-reviewer`, which is not in this plugin. Invoke with `@mention`.

**Included agents:**

| Agent | Domain | Role |
|-------|--------|------|
| `architect` | Orchestration | System design and ADR drafting |
| `assistant` | Orchestration | Primary orchestrator and fallback |
| `planner` | Orchestration | Feature breakdown and estimation |
| `client-workflow-bootstrap` | Delivery | Client project onboarding |
| `code-reviewer` | Review | Code quality and correctness |
| `database-reviewer` | Review | Schema design and query optimization |
| `performance-optimizer` | Review | Profiling and benchmarking |
| `security-reviewer` | Review | Vulnerability audit and threat modeling |
| `typescript-reviewer` | Review | TypeScript type safety |
| `tech-assistant` | Design | Technical procedures and references |
| `e2e-runner` | Testing | Playwright end-to-end tests |
| `tdd-guide` | Testing | Test-driven development |
| `build-error-resolver` | Ops | Build and type error triage |
| `docs-lookup` | Ops | Documentation and API reference |
| `reference-lookup` | Ops | Public examples and pattern search |
| `refactor-cleaner` | Ops | Dead code removal and simplification |

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
v run make.vsh install-cli && agent-toolkit install --force
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

Plugin bundles under `plugins/` are auto-synced from canonical sources. The sync is performed by
`scripts/gen-surfaces.vsh`. Editing bundles directly will result in your changes being overwritten
on the next sync.

Always edit the canonical source (`skills/<domain>/<name>/SKILL.md` or `agents/<name>/AGENT.md`)
and re-run the sync:

```bash
v run scripts/gen-surfaces.vsh
v run scripts/gen-surfaces.vsh --check  # verify no drift
```
