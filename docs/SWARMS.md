# Agent Toolkit Swarms — Overview

`agent-toolkit swarm` is a backend-neutral, cost-aware, local-first orchestration for coordinated groups of coding-agent sessions.

## Quickstart

```bash
# Check prerequisites
agent-toolkit swarm doctor

# List recipes
agent-toolkit swarm recipes
agent-toolkit swarm recipe show pair

# Plan without side effects
agent-toolkit swarm plan \
  --recipe pair \
  --ui auto \
  --runner opencode \
  --model-profile balanced \
  "Implement GitHub issue #123"

# Start a swarm (Herdr recommended, tmux fallback)
agent-toolkit swarm start \
  --recipe pair \
  --ui herdr \
  --runner opencode \
  --model-profile balanced \
  "Implement GitHub issue #123"

# Same workflow with tmux
agent-toolkit swarm start \
  --recipe pair \
  --ui tmux \
  --runner opencode \
  --model-profile balanced \
  "Implement GitHub issue #123"

# Observe
agent-toolkit swarm list
agent-toolkit swarm status RUN_ID
agent-toolkit swarm status RUN_ID --json
agent-toolkit swarm handoffs RUN_ID
agent-toolkit swarm artifacts RUN_ID
agent-toolkit swarm logs RUN_ID implementer
```

## Concepts

```
Orchestration engine  → what work exists, who owns it, state, handoffs, budgets
UI backend            → where sessions are displayed: herdr, tmux, headless
Agent runner          → which coding agent runs: opencode, claude, codex, cursor, copilot, muse
Model                 → which LLM the runner uses per role
Persona               → intellectual specialization
Role policy           → what the role can read/modify/execute/integrate/publish
```

Never conflate these.

## Recipes

- **pair** — implementer → reviewer/integrator → human approval (default). For bugs, features, refactors. 2 round-trip limit, concurrency 2.
- **team** — planner → implementer → reviewer → architect → human approval. For medium features, schema changes, API changes. Requires plan approval.
- **full** — planner → implementer → refactorer → architect → hardener (conditional specialist) → qa → human approval. For security-sensitive, releases, migrations.

All recipes are lazy/elastic: topology created logically, only roles whose inputs are ready start. Promote `pair → team → full` without losing run ID, artifacts, or budget.

## Worktrees & Handoffs

- One Git worktree per writing role under `.agent-toolkit/swarm/runs/<run-id>/worktrees/<role>` with branch `agent-toolkit-swarm/<run-id>/<role>`.
- Code handoffs use validated full 40-char commit SHAs, never uncommitted code.
- Durable filesystem handoff queue: `handoffs/{outbox,queued,active,completed,failed}/<id>.json`.
- Atomic writes, path traversal prevention, ownership recorded, dirty worktrees preserved, branches never auto-deleted.

## Budgets & Gates

- Budgets: `max_total_tokens`, `max_cost_usd`, `max_wall_seconds`, `max_concurrency` (default 2), `max_role_round_trips` (default 2), per-role limits.
- Human gates: plan approval, architecture decision, cost escalation, final integration. No auto-merge to base by default, no push, no publish.

## Model Profiles

Semantic profiles `economy`, `balanced`, `quality`, `private` map task classes `planning/coding/review/architecture/hardening/qa` to `provider/model`. Discover via runner (`opencode models`), validate before start, allow per-role override. Pricing stored separately; unknown pricing reported honestly; expensive fallback requires approval. Prefer different model/provider for review to reduce correlated mistakes.

## Backends

- **Herdr** (recommended): `herdr workspace create`, `herdr agent start/prompt/wait/read`, JSON output, `herdr integration install opencode`. Falls back to tmux only under `--ui auto`.
- **tmux** (portable): isolated server/socket per run `agent-toolkit-swarm-<run-id>`, never mutates user sessions, works over SSH.

## Observability

Each run under `.agent-toolkit/swarm/runs/<run-id>/` produces `run.yaml`, `state.json` (versioned), `trace.jsonl`, `budget.json`, `ownership.json`, `artifacts/`, `handoffs/`, `prompts/`, `runner/opencode/agents/`. Events: `run_created`, `worktree_created`, `handoff_created`, `approval_requested`, `budget_exhausted`, etc. Machine-readable JSON via `status --json`, `watch`, `report`.

## Security

See `docs/SWARM_SECURITY.md`. Validate identifiers, use full SHAs, atomically write state, redact secrets, deny external-directory writes/push/release/base-merge by default, fail closed on unclear ownership.

## Configuration Precedence

`CLI flags → project-local swarm.yaml → workspace config → user ~/.config/agent-toolkit/swarm.yaml → built-in defaults`. Env vars override runtime paths only.

## No Cloud Required

No mandatory cloud service, telemetry, or Herdr dependency for correctness. Filesystem state is authoritative.
