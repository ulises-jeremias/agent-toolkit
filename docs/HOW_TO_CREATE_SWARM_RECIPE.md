# How to Create a Swarm Recipe

1. Choose `apiVersion: agent-toolkit.dev/v1alpha1`, `kind: SwarmRecipe`.
2. Define `metadata.name` (kebab, unique) and `description`.
3. Under `spec`:
   - `ui: auto` (herdr/tmux/headless)
   - `transport: filesystem`
   - `workspace.strategy: worktree-per-writer`, `base_ref`, `integration_branch`, `keep_on_failure`
   - `execution.max_concurrency`, `lazy_start`, `resumable`, `max_role_round_trips`
   - `budget` (max_total_tokens, max_cost_usd, max_wall_seconds, per_role)
   - `gates` (require_plan_approval, require_final_approval, allow_direct_base_merge, allow_push)
   - `roles` map: each role needs `persona` (existing agent), `policy` (read-only/writer/reviewer-writer/integrator), `model_profile` (planning/coding/review/architecture/hardening/qa), optional `worktree`, `consumes`/`produces`, `receive_mode` (task|batch), `skills`.

Example:

```yaml
apiVersion: agent-toolkit.dev/v1alpha1
kind: SwarmRecipe
metadata:
  name: docs-review
  description: Planner + implementer + reviewer for docs
spec:
  ui: auto
  transport: filesystem
  workspace:
    strategy: worktree-per-writer
    base_ref: HEAD
  execution:
    max_concurrency: 2
    lazy_start: true
    max_role_round_trips: 2
  budget:
    max_total_tokens: 400000
  gates:
    require_final_approval: true
  roles:
    planner:
      persona: planner
      policy: read-only
      model_profile: planning
      produces: [task-contract]
    implementer:
      persona: tdd-guide
      policy: writer
      model_profile: coding
      worktree: implementer
      consumes: [task-contract]
      produces: [commit]
    reviewer:
      persona: code-reviewer
      policy: reviewer-writer
      model_profile: review
      worktree: reviewer
      consumes: [commit]
      produces: [reviewed-commit]
```

4. Validate: `validate_recipe()` will check names/policies.
5. Test offline: `agent-toolkit swarm plan --recipe your-recipe --json "task"` should be side-effect free.
6. Place file under `~/.config/agent-toolkit/swarm/recipes/` or repo `.agent-toolkit/swarm/recipes/` and reference via config, or contribute built-in via PR.

Reuse personas from `agents/` (planner, architect, code-reviewer, etc.), don't create duplicate `swarm-*` personas unless overlay needed.
