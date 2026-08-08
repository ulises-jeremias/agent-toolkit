# Agent Toolkit Swarms — Overview

`agent-toolkit swarm` is a backend-neutral, cost-aware, local-first orchestration for coordinated groups of coding-agent sessions.

## Quickstart

```bash
# Check prerequisites (also surfaced by `agent-toolkit doctor`)
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

## Conceptual Architecture & Repo Ownership

- **Conceptual architecture:** orchestration engine owns *what* work exists (recipes, roles, handoffs, budgets, worktrees, gates, runners, prompts, artifacts); UI backends (Herdr/tmux/headless) only display sessions; runner adapters (OpenCode, Muse, Claude, Codex, Cursor, Copilot) only run agents. Filesystem state is authoritative. See [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) and [ARCHITECTURE.md](ARCHITECTURE.md).
- **Repo ownership:** **agent-toolkit** (this repo) owns all runtime behavior — recipes, handoffs, state, worktrees, budgets, runners, Herdr/tmux adapters, prompts, artifacts — sole source of truth (ADR-008). **agentic-workstation** installs dependencies (tmux, Herdr, integrations) via `agent_swarms.enabled=true`, not orchestration. **agentic-harness** demonstrates usage, not implementation. Diagrams: ecosystem boundaries, runtime layers, Herdr/tmux adapter separation in [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md).

## Security, Permissions & Human Gates

See [SWARM_SECURITY.md](SWARM_SECURITY.md). Validate identifiers, use full SHAs, atomically write state, redact secrets, deny external-directory writes/push/release/base-merge by default, fail closed on unclear ownership.

- **Permissions:** planner `read-only`; implementer `writer`; reviewer `reviewer-writer` (optional); integrator `merge: ask`. Runner defaults: `external_directory: deny`, `git push: deny`, `git reset --hard: deny`, `git clean: deny`. `allow_direct_base_merge: false`, `allow_push: false`.
- **Human gates:** plan approval, architecture decision, cost escalation, final integration. No auto-merge. `agent-toolkit swarm approve` / `reject`.

## State Locations & Observability

State files, trace, and ownership on filesystem:

```
.agent-toolkit/swarm/runs/<run-id>/
  run.yaml | state.json (versioned, atomic) | trace.jsonl (append-only)
  budget.json | ownership.json | approvals.json
  artifacts/ | handoffs/{outbox,queued,active,completed,failed}/ | prompts/
  worktrees/<role>/ | runner/opencode/agents/
```

See [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) for run/role/handoff state machines.

## Privacy

No mandatory cloud, no telemetry, no transcript storage by default (opt-in with warning). Secrets redacted via `sanitize_args()` (`token`/`secret`/`key`/`password` → `[REDACTED]`); credentials never serialized; env scoped per process; generic UI wake-up notifications only. See [SWARM_SECURITY.md](SWARM_SECURITY.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Cleanup

- `agent-toolkit swarm stop RUN_ID` — kills backend windows (Herdr/tmux), preserves filesystem state.
- `agent-toolkit swarm cleanup RUN_ID` — removes only Toolkit-owned worktrees under `runs/<run-id>/worktrees/`, checks `git status --porcelain` dirty and refuses without `--force`, never deletes branches automatically, never removes user worktrees, fail-closed on unclear ownership. See [SWARM_TMUX.md](SWARM_TMUX.md) and [SWARM_HERDR.md](SWARM_HERDR.md).

## Herdr Plugin & tmux Fallback

- **Herdr plugin:** thin plugin at `integrations/herdr/agent-toolkit-swarm/` (`herdr-plugin.toml`, `min_herdr_version`, actions Start Pair/Team/Full, Open Status/Handoff Queue/Final Report, Pause/Resume/Stop/Clean Up) — no orchestration logic, delegates to `agent-toolkit swarm`. Local dev: `herdr plugin link ./integrations/herdr/agent-toolkit-swarm`. See [SWARM_HERDR.md](SWARM_HERDR.md).
- **tmux fallback:** isolated server/socket per run `agent-toolkit-swarm-<run-id>`, never mutates user sessions, works over SSH, `shlex.quote` safe quoting, parity via `SwarmUIBackend` interface. See [SWARM_TMUX.md](SWARM_TMUX.md).
- `--ui auto` falls back Herdr → tmux; `--ui herdr` fails with install guidance if missing.

## Offline / Fake Demo

No Herdr or LLM needed to explore swarms offline:

```bash
# Fully offline — plan is side-effect free, skeleton needs no binary
agent-toolkit swarm plan --recipe pair --ui tmux --runner skeleton "Demo: add hello endpoint" --json
agent-toolkit swarm plan --recipe team --ui tmux --runner skeleton "Design API" --json
agent-toolkit swarm start --runner skeleton --ui tmux "Offline demo"
agent-toolkit swarm models --runner opencode   # fallback to profile models when runner missing
```

`--runner skeleton` uses `true` binary, writes `task-contract.md` only, always available. Pricing unknown is reported honestly; expensive fallback requires explicit approval.

## Extension Guide

1. Create a recipe `apiVersion: agent-toolkit.dev/v1alpha1`, `kind: SwarmRecipe` — see [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md).
2. Place under `~/.config/agent-toolkit/swarm/recipes/` or `.agent-toolkit/swarm/recipes/` and reference via config.
3. Reuse personas from `agents/` (planner, architect, code-reviewer, etc.) and map `model_profile` to task classes (`planning`/`coding`/`review`/`architecture`/`hardening`/`qa`) in [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md).
4. Test offline: `agent-toolkit swarm plan --recipe your-recipe --runner skeleton "task"` should be side-effect free.

Mermaid diagrams for ecosystem boundaries, runtime layers, pair/team/full workflows, handoff/role/run state machines, and Herdr/tmux adapter separation are in [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md).

Related: [SWARM_RECIPES.md](SWARM_RECIPES.md) · [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md) · [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) · [SWARM_HERDR.md](SWARM_HERDR.md) · [SWARM_TMUX.md](SWARM_TMUX.md) · [SWARM_SECURITY.md](SWARM_SECURITY.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [adr/ADR-008-swarm-orchestration.md](adrs/ADR-008-swarm-orchestration.md)

## Configuration Precedence

`CLI flags → project-local swarm.yaml → workspace config → user ~/.config/agent-toolkit/swarm.yaml → built-in defaults`. Env vars override runtime paths only.

## Doctor Integration

`agent-toolkit doctor` reports swarm tooling status under a **Swarm tooling** section:

- tmux availability and version
- herdr availability and version
- swarm offline plan check with skeleton runner

Missing tools produce actionable installation guidance. Run `agent-toolkit doctor` for a
complete installation health picture that includes swarm prerequisites alongside system,
AI tool, profile, loop, LLM, MCP, and scheduled-loops checks. See [CLI_REFERENCE.md](CLI_REFERENCE.md)
for the full list.

## No Cloud Required

No mandatory cloud service, telemetry, or Herdr dependency for correctness. Filesystem state is authoritative.
