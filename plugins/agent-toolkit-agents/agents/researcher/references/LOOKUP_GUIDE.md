# Lookup Guide — consolidated from `docs-lookup` + `reference-lookup` specialists (archived #865)

> **Provenance:** Migrated from `agents/docs-lookup/AGENT.md` + `agents/reference-lookup/AGENT.md` (pre-865). Merged into `researcher` per agent-vs-skill rule: procedural lookup, narrow capability loaded inline — holistic `researcher` + skills `delivery/spike` / `delivery/project-assessment-evidence` cover invocation. `researcher` owns discovery/evidence; standalone lookup personas redundant. See `docs/AGENT_TAXONOMY.md` §3/§8.

Use when you need framework docs, API references, config options, examples, or public-examples pattern adaptation before a `spike` or assessment. Invoke via `researcher`; do not invoke as standalone specialist.

## When to apply

**docs-lookup (framework/library docs)**
- Framework or library API docs, config options + defaults, migration guides, error explanations, env var references, code examples

**reference-lookup (toolkit public examples + patterns)**
- Official agent-toolkit examples, starter templates, established patterns in the agent-toolkit ecosystem (examples: public examples repo `https://github.com/ulises-jeremias/public examples`, API `https://raw.githubusercontent.com/agent-toolkit/public examples/refs/heads/main/examples.json`), local `docs/`, existing codebase patterns

## Workflow

1. Identify what is sought — pattern, API, config, example
2. Check local `README` / `docs/` / `AGENTS.md` / `CONTRIBUTING.md` first
3. For toolkit examples: fetch and scan the public examples examples API for matches
4. For framework/library: check local inventory / codebase patterns, then web only after local check
5. Summarize most relevant examples with key points
6. Adapt the example to current project context
7. Cite source URL or repo path (`file:line`)

## Output

**docs-lookup**
- Direct answer first, relevant code example, source reference (file path or URL), version-specific differences if relevant

**reference-lookup**
1. List of relevant examples with brief descriptions
2. Most relevant example with key implementation points
3. Adaptation notes for current project
4. Any specific considerations (source-URL cited)

## Caller / handoff
- **Caller:** `researcher` during `delivery/spike` or `delivery/project-assessment-evidence`
- **Handoff:** `planner` / `architect` consume findings; `implementer` adapts pattern; never fabricate — fetch then synthesize
