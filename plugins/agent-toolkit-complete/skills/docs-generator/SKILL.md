---
name: docs-generator
description: 'WHAT — Generate or update documentation from code: README.md from repo structure, CHANGELOG.md
  from git history, API reference from OpenAPI/GraphQL schemas, and AGENTS.md starters for new projects.'
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - docs
  - readme
  - changelog
  - api-reference
  - agents
---
# Docs Generator (WHAT)

Generate or refresh documentation from the actual code, schema, and git history.
Never invent — always derive from evidence in the repo.

## When to use

- README is missing, stale, or doesn't reflect the current stack
- CHANGELOG needs to be generated from merged PRs or git log
- API spec (OpenAPI/GraphQL) exists but human-readable docs don't
- New repo needs an AGENTS.md to onboard AI assistants

## Out of scope

- Does NOT write code — documentation only
- Does NOT commit or push — delegate to **`github-cli-workflow`**
- Does NOT update external systems (Confluence, Notion) — use their respective skills

## Workflow

### README.md generation

1. Inspect repo: `package.json` / `pyproject.toml` / `Cargo.toml` for name, description, stack
2. Read `Makefile` / `justfile` / `package.json scripts` for commands
3. Read `.github/workflows/` for CI structure
4. Draft README with: Purpose, Stack, Prerequisites, Quick Start, Development, Testing, Contributing
5. Apply **`output-handshake`** before writing

### CHANGELOG.md generation

```bash
# Conventional commits format
git log --oneline --no-merges --pretty="format:%h %s" $(git describe --tags --abbrev=0)..HEAD

# Group by type: feat / fix / docs / chore / refactor / perf / test
# Format: ## [Unreleased] with subsections per type
```

Draft changelog section and ask user to confirm version before finalizing.

### API reference generation

- OpenAPI spec → readable endpoint table with params, responses, auth
- GraphQL schema → type reference with fields and descriptions
- Always note the spec version and date in the generated doc

### AGENTS.md starter

Use the template from `~/.local/share//skills-catalog.yaml` patterns:

- Purpose and stack
- Repository inspection order
- What AI assistants may and must not do
- Key commands (build, test, lint)
- Links to key docs

## Inline Documentation (why, not what) — per `addyosmani/agent-skills` `documentation-and-adrs` 2026-08-12 diff `docs/research/diff-394-documentation-and-adrs.md`

Comment the *why*, not the *what*:

```typescript
// BAD: Restates the code
// Increment counter by 1
counter += 1;

// GOOD: Explains non-obvious intent
// Rate limit uses a sliding window — reset counter at window boundary,
// not on a fixed schedule, to prevent burst attacks at window edges
if (now - windowStart > WINDOW_SIZE_MS) {
  counter = 0;
  windowStart = now;
}
```

* **When NOT to comment:** self-explanatory code (`calculateTotal` reduce), week-old `TODO`s (do it now), commented-out code (delete — git has history).
* **Document Known Gotchas inline** where they matter:
```typescript
/**
 * IMPORTANT: Must be called before first render — after hydration causes FOUC
 * (theme context not available during SSR). See ADR-003.
 */
export function initializeTheme(theme: Theme): void { ... }
```

**Do not invent docs from thin air** — derive from code/specs/git history (this skill) vs ADR *why* (via `adr` skill). `personas/` (HOW agent thinks) vs `skills/` (HOW task executes) preserved — see `docs/CONCEPTS.md`.

## Verification (after documenting)

* [ ] ADRs exist for all significant decisions, README covers quick start/commands/architecture (link ADRs), API docs have types, gotchas inline, no commented-out code, `CLAUDE.md`/`AGENTS.md` current.
* Rationalizations table — "code is self-documenting" (reality: code shows what, not why/alternatives), "docs when API stabilizes" (doc is first test of design), "ADRs are overhead" (10-min ADR prevents 2-hour debate).

## Anti-patterns

- Do not guess stack or commands — read from actual config files
- Do not generate CHANGELOG from unstaged changes
- Do not overwrite existing README without showing diff first

## Delegates to

| Need | Skill |
|------|-------|
| Push and create PR with generated docs | **`github-cli-workflow`** |
| Confirm output destination | **`output-handshake`** |
| Repo discovery | **`assistant`** |
