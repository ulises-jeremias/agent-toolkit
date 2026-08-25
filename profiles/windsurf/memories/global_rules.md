# agent-toolkit AI Coding Standards

These rules apply globally across all workspaces for agent-toolkit engineers.

## Repository inspection order
Before writing any code in a new repository, read in this order:
1. README.md — project purpose and stack
2. docs/ directory — architecture and operational docs
3. AGENTS.md or CLAUDE.md — agent-specific instructions (primary contract)
4. CONTRIBUTING.md — contribution guidelines
5. PR templates, Makefile / package.json scripts
6. devcontainer.json and CI workflows

Always cite which file a convention comes from.

## agent-toolkit development standards

### Shell scripts
- Always use `set -euo pipefail`
- Write idempotent scripts — safe to run multiple times
- Detect OS before package manager operations
- Skip already-installed tools
- Print clear human-readable error messages

### chezmoi repositories
- `.chezmoiroot` must point to `home/`
- Internal commands: `agent-toolkit <cmd>` (install, doctor, loop, skills, mcp)
- Never modify source state directly on the managed machine

### Code quality
- Functions do one thing (Single Responsibility)
- No code duplication (DRY) — Rule of Three before abstracting
- Error handling for all failure paths
- Edge cases handled: null, empty, boundary values
- Input validation before use

### Security (always)
- Never commit secrets, tokens, or private credentials
- Use `.env.example` for credential templates
- Parameterized queries only — no SQL string concatenation
- Validate and sanitize all user inputs

### Testing
- New behavior always has test coverage
- Write tests before implementation (TDD)
- Mock external dependencies in unit tests

### Documentation
- Update documentation when behavior changes
- English for all documentation, commits, and ticket descriptions

## Available AI agents (canonical — `agents/` + `docs/AGENT_TAXONOMY.md`, Tier D = local guidance only)

Windsurf is **Tier D (minimal)** — this file is local guidance only (no marketplace, no native subagent dispatch). For rich multi-agent delegation use Tier A/B harnesses. The compiler does not emit subagent config where `subagents: false`.

**Holistic (daily):** `@assistant` (orchestrator) · `@planner` · `@architect` · `@designer` · `@implementer` · `@reviewer` · `@qa-engineer` · `@security-engineer` · `@platform-engineer` · `@researcher` · `@data-engineer` (conditional)
**Specialist (opt-in, 6):** `@code-reviewer` (backs `reviewer`), `@security-reviewer` + `@agentic-security-reviewer` (backs `security-engineer`), `@e2e-runner` (backs `qa-engineer`), `@tdd-guide` (backs `implementer`), `@build-error-resolver` (backs `platform-engineer`)
**Meta-generator:** `@client-workflow-bootstrap` — onboarding interview → `packs/` + `knowledge/` (not daily)
References archived from former specialists are loaded inline: `reviewer/references/{TYPESCRIPT,DATABASE,PERFORMANCE,REFACTOR}_CHECKLIST.md`, `researcher/references/LOOKUP_GUIDE.md`, `platform-engineer/references/WORKSTATION_OPS.md`.

Invoke with `@name` where harness supports it; otherwise follow instructions inline.

## agent-toolkit CLI

Use these commands for workspace operations:

```bash
# Workspace
agent-toolkit workspace context          # session state at start
agent-toolkit workspace init [--dir .]  # scaffold a new workspace

# Knowledge
agent-toolkit memory add --type learning "pattern"
agent-toolkit memory add --type todo "follow-up"
agent-toolkit memory search "topic"
agent-toolkit memory inject
agent-toolkit memory todo

# Loops
agent-toolkit loop run <name>
agent-toolkit loop status
agent-toolkit loop schedule <name>

# Projects
agent-toolkit project clone owner/repo
agent-toolkit project list

# Background jobs
agent-toolkit devcompanion queue <project> --request "..."
agent-toolkit devcompanion run-once
agent-toolkit devcompanion status

# Analysis
agent-toolkit insights opencode        # OpenCode usage report
agent-toolkit insights cursor          # Cursor usage report

# Health check
agent-toolkit doctor
```

**Session start:** run `agent-toolkit workspace context` then `agent-toolkit memory inject` then check `agent-toolkit memory todo`.

## Git and delivery
- Commit messages: present tense, imperative, concise (`add user auth`, not `added user auth`)
- Reference ticket in commits for traced projects: `[TICKET-123] Description`
- Small, focused commits — one logical change per commit
- Branch from main — never commit directly to main or master
