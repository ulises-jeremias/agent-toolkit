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
- Hardener specialization: security-reviewer | database-reviewer | performance-optimizer | typescript-reviewer (select only one justified by risk)
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

## Creating Custom Recipes

See `docs/HOW_TO_CREATE_SWARM_RECIPE.md`.
