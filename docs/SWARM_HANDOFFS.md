# Swarm Handoffs

Durable filesystem queue under `.agent-toolkit/swarm/runs/<run-id>/handoffs/{outbox,queued,active,completed,failed,awaiting_human}/<id>.json`.

## Collaboration semantics (ADR-039)

- **Speech acts** — every handoff may carry `act`: `propose`, `review`,
  `approve`, `reject`, `request_decision` or `inform`
  (`--act ACT`). Records written before acts existed decode with an empty act.
- **Hop budget** — a reply inherits `hops + 1` (and `max_hops`, when not given)
  from the active handoff it answers. Default budget: 6 (`--max-hops N`).
- **Human routing** — a reply past the budget is not dropped: its act becomes
  `request_decision` and it waits in `handoffs/awaiting_human/`. Resolve it
  with `agent-toolkit swarm task complete --handoff <id>`, then hand the work
  on explicitly.
- **Broadcast** — `--to all` creates one queued handoff per recipe role
  (except the sender) with identical validation, audit and wake-up behavior.

## Types

### artifact
```yaml
type: artifact
from: planner
to: implementer
priority: 10
artifact: artifacts/task-contract.md
```

### commit
```yaml
type: commit
from: implementer
to: reviewer
priority: 20
commit: <40-hex-sha>
branch: agent-toolkit-swarm/<run-id>/implementer
artifact: artifacts/implementation-report.md
```

### feedback
```yaml
type: feedback
from: reviewer
to: implementer
priority: 10
blocking: true
artifact: artifacts/review-02.md
```

### decision_request
```yaml
type: decision_request
from: architect
to: human
priority: 0
artifact: artifacts/architecture-options.md
```

## Requirements

- Validate sender/recipient exist and are known roles (or human).
- Validate sender owns artifact; artifact path relative, no `..`, stays under run_dir.
- Validate commit exists via `git cat-file -t`, resolve abbrev via `git rev-parse --verify`.
- Atomic write via tmpfile + rename, timestamped, state transitions logged.
- Support restart/resume; preserve failed with diagnostics.
- Enforce at most one active task per task-mode role; batch allows many.
- Artifact size ≤1MB, redact secrets, generic UI wake-up only.
- Never require roles to edit state files manually; use `agent-toolkit swarm handoff create`, `task next`, `task complete`.

## CLI for Agents

```bash
agent-toolkit swarm handoff create --type commit --from implementer --to reviewer --commit <sha> --branch agent-toolkit-swarm/<run-id>/implementer --artifact artifacts/report.md --run-id <run-id>
agent-toolkit swarm task next --role reviewer --run-id <run-id>
agent-toolkit swarm task complete --handoff <id> --run-id <run-id>
```

See [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) for handoff/run/role state machines (Mermaid: handoff `outbox → queued → active → {completed,failed}`, run, role).

## Backend-Neutral & Extension

Handoffs are transport-agnostic (`transport: filesystem`) and session-backend agnostic — Herdr ([SWARM_HERDR.md](SWARM_HERDR.md)) and tmux ([SWARM_TMUX.md](SWARM_TMUX.md)) both use the same durable queue under `.agent-toolkit/swarm/runs/<run-id>/handoffs/`. No LLM or Herdr is needed for a preview: use `swarm start --dry-run --runner skeleton`; omit `--dry-run` to create a real local run for handoff prototyping.

Related: [SWARMS.md](SWARMS.md) · [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) · [SWARM_RECIPES.md](SWARM_RECIPES.md) · [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) · [SWARM_SECURITY.md](SWARM_SECURITY.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md) · [SWARM_TMUX.md](SWARM_TMUX.md) · [SWARM_HERDR.md](SWARM_HERDR.md)
