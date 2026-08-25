# Refactor Checklist — from `refactor-cleaner` specialist (archived #865)

> **Provenance:** Migrated from `agents/refactor-cleaner/AGENT.md` (pre-865). Converted to reference per agent-vs-skill rule: procedural checklist, narrow capability loaded inline — `reviewer` (holistic) via `quality/deslop` + `implementer` behavior-preservation covers invocation. See `docs/AGENT_TAXONOMY.md` §3/§8 migration map.

Use when removing dead code, simplifying complex functions, reducing duplication, or improving structure without changing behavior. Invoke via `reviewer` → `quality/deslop` (diff-scoped) or `implementer` during red-green-refactor. Do not invoke as standalone specialist.

## When to apply
- PR touches dead code, long functions, duplicated blocks, or naming debt
- Reviewer flags slop/duplication/complexity in diff hunks
- Implementer refactors with test-before/after guarantee

## Techniques by scenario

**Dead code removal**
- Search for all usages before deleting (Grep/Glob, dynamic imports, string refs, reflection)
- Check public API exports last

**Complexity reduction**
- Extract long functions into well-named sub-functions
- Replace complex conditionals with early returns (guard clauses)
- Replace nested ternaries with if/else
- Replace magic numbers with named constants

**Duplication elimination**
- Extract shared logic into utility with meaningful name
- Identify patterns in similar blocks
- Avoid over-generalizing — wait for 3 occurrences (Rule of Three)

**Naming improvement**
- Functions: verb phrases (`getUser`, `validateInput`)
- Variables: noun phrases describing value
- Avoid abbreviations except `id`, `url`, `api`

## Hard rules
- Never change behavior while refactoring — one thing at a time
- Run tests before and after each step
- One type of refactoring per commit — message `refactor: <what and why>`

## Output
Show before/after diffs with explanation of what changed and why; note preserved behavior.

## Prose hygiene
- Prose cleanup in comments/docs touched by refactor → `quality/unslop` (via `reviewer`)

## Caller / handoff
- **Caller:** `reviewer` via `quality/deslop` (diff-scoped), or `implementer` during refactor phase
- **Handoff:** `implementer` applies; `qa-engineer` verifies tests/gates; `reviewer` re-verifies craft
