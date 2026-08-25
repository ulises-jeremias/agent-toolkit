# Swarm Recipes

Recipes are versioned `agent-toolkit.dev/v1alpha1`, kind `SwarmRecipe`.

## Built-ins

### pair
- Roles: implementer (writer, tdd-guide, coding), reviewer (reviewer-writer, code-reviewer, review), integrator (integrator, architect, architecture, batch)
- No plan gate, final approval required, concurrency 2, round-trips 2
- Use: bugs, features, refactors, docs with examples

### team
- Roles: planner (read-only, planning), implementer, reviewer, architect (integrator, batch)
- Plan approval required
- Use: medium features, cross-module, schema, integrations, public API

### full
- Roles: planner, implementer, refactorer (writer, review), architect (integrator, batch), hardener (conditional specialist), qa
- Hardener specialization (post-#865): `security-reviewer` (still specialist) | `reviewer` via `quality/deep-review` + `references/DATABASE_CHECKLIST.md` (archived `database-reviewer`), `references/PERFORMANCE_CHECKLIST.md` (archived `performance-optimizer`), `references/TYPESCRIPT_CHECKLIST.md` (archived `typescript-reviewer`) — select only one justified by risk; archived specialists are now `reviewer` references loaded inline, not agents
- QA owns full verification, E2E, smoke tests
- Use: security-sensitive, releases, migrations, large features

## Recipe Schema

```yaml
apiVersion: agent-toolkit.dev/v1alpha1
kind: SwarmRecipe
metadata:
  name: team
  description: Four-role workflow
spec:
  ui: auto
  transport: filesystem
  workspace:
    strategy: worktree-per-writer
    base_ref: HEAD
    integration_branch: true
    keep_on_failure: true
  execution:
    max_concurrency: 2
    lazy_start: true
    resumable: true
    max_role_round_trips: 2
  budget:
    max_total_tokens: 900000
    max_cost_usd: 4.00
    max_wall_seconds: 7200
    per_role:
      planner: {max_tokens: 80000}
  gates:
    require_plan_approval: true
    require_final_approval: true
    allow_direct_base_merge: false
    allow_push: false
  roles:
    planner:
      persona: planner
      policy: read-only
      model_profile: planning
      skills: [planning]
      produces: [task-contract]
```

## Validation

`validate_recipe()` checks apiVersion, kind, metadata.name, roles non-empty, role names matching `^[a-z][a-z0-9_-]{1,31}$`, policies in {read-only, writer, reviewer-writer, integrator}, receive_mode task|batch.

## Lazy & Elastic

Topology created logically, only `planner` or `implementer` starts eagerly; others inactive until handoff. `promote RUN_ID --to team|full` preserves run ID, artifacts, branches, budget, trace. Events: `recipe_promoted`, `role_activated`, `role_deactivated`.

## UI Backends & Runners

Recipes are backend-neutral: `spec.ui` (`auto`/`herdr`/`tmux`/`headless`) selects the UI adapter, `transport: filesystem` keeps state authoritative. At runtime `agent-toolkit swarm start --ui herdr|tmux|auto` overrides the recipe default. Herdr is recommended ([SWARM_HERDR.md](SWARM_HERDR.md) — `herdr workspace create` + `herdr agent start/prompt/wait/read`), tmux is the portable fallback ([SWARM_TMUX.md](SWARM_TMUX.md) — isolated server `agent-toolkit-swarm-<run-id>`, never mutates user sessions, works over SSH). Runner (`spec` does not bind runner; choose at start via `--runner opencode|claude|codex|cursor|copilot|muse|skeleton`) and model profile (`economy`/`balanced`/`quality`/`private` → task classes `planning`/`coding`/`review`/`architecture`/`hardening`/`qa`) are resolved separately in [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md). `--runner skeleton` is always available for offline/fake demo (`swarm plan` side-effect free, no Herdr/LLM needed).

## Privacy, Cleanup & Extension

- **Privacy:** no telemetry; handoff artifacts are local files under `runs/<run-id>/artifacts/`; secrets redacted (see [SWARM_SECURITY.md](SWARM_SECURITY.md)).
- **Cleanup:** only Toolkit-owned `worktrees/<role>` and backend windows are removed by `swarm cleanup`; dirty worktrees preserved, branches never auto-deleted (see [SWARMS.md](SWARMS.md) and [SWARM_TMUX.md](SWARM_TMUX.md)).
- **Extension:** see [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md) for full guide, config precedence (`CLI → swarm.yaml → ~/.config/agent-toolkit/swarm.yaml → defaults`), and offline validation via `swarm plan --runner skeleton`.

Related: [SWARMS.md](SWARMS.md) · [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (diagrams: ecosystem boundaries, runtime layers, pair/team/full, handoff/run state machines, Herdr/tmux separation) · [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md) · [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) · [SWARM_SECURITY.md](SWARM_SECURITY.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md)

## Creating Custom Recipes

See [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md).
