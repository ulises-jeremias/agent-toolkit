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

## Available AI subagents (OpenCode / Claude Code)
These specialized agents are available via @mention:

- **@architect** — System design and technical trade-off analysis
- **@build-error-resolver** — Fix compilation and TypeScript errors
- **@code-reviewer** — Code quality, security, and maintainability review
- **@database-reviewer** — PostgreSQL schema, query optimization, migrations
- **@docs-lookup** — Framework and library documentation search
- **@e2e-runner** — Playwright end-to-end test writing and debugging
- **@assistant** — agent-toolkit conventions and standards enforcement
- **@performance-optimizer** — Profiling and performance analysis
- **@planner** — Feature breakdown and risk analysis before implementation
- **@refactor-cleaner** — Dead code removal and code simplification
- **@reference-lookup** — public examples examples and agent-toolkit patterns
- **@security-reviewer** — Vulnerability detection before deployment
- **@tdd-guide** — Test-driven development cycle enforcement
- **@typescript-reviewer** — TypeScript type safety and modern patterns

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
