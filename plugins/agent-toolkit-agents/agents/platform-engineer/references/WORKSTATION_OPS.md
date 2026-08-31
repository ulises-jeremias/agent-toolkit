# Workstation Ops — from `tech-assistant` specialist (archived #865)

> **Provenance:** Migrated from `agents/tech-assistant/AGENT.md` (pre-865 stub: "Technical operations assistant. Use when: infrastructure, procedures, system changes. Handoffs: architect."). Converted to reference per agent-vs-skill rule: procedural, narrow capability loaded inline — holistic `platform-engineer` via `ops/triage` + `tooling/inventory` + `core/workspace` covers invocation; no separate context / parallelism / noisy-output justification. See `docs/AGENT_TAXONOMY.md` §3/§8 migration map.

Use when workstation/infra procedures, triage, loops/swarm, or install scaffolding are needed without invoking a separate specialist persona.

## When to apply
- `ops/triage` health check, `tooling/inventory` / `core/workspace` discovery, `loops/loop-runner` / `ops/swarm*` setup — all owned by `platform-engineer`
- Previously `@tech-assistant` stub delegated to `architect` for system design; that handoff remains via `architect` collaborator in `platform-engineer`

## Checklist (folded into `platform-engineer`)
- Prefer repo-documented commands (`agent-toolkit doctor`, `agent-toolkit mcp doctor`) — read `AGENTS.md`/`README`/`docs/` first
- Never invent infra state; cite `file:line` or `doctor --issue` output
- Handoff cross-cutting design to `architect`, verification to `qa-engineer`, hardening to `security-engineer`

## Caller / handoff
- **Caller (archived):** previously `platform-engineer` via `ops/triage` `specialist_agents: [tech-assistant]`. Now inlined.
- **Current:** `platform-engineer` directly drives `ops/triage`, `tooling/inventory`, `core/workspace` without delegate agent.
