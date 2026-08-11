---
name: loop-runner
description: Execute and manage loop engineering primitives (init, run, status, audit) from an AI coding
  session via bin/loop CLI.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
---
# loop-runner

> Execute and manage loop engineering primitives from an AI coding session.

---

## What this skill does

This skill wraps the `bin/loop` CLI from
[ai-workspace](https://github.com/ulises-jeremias/ai-workspace), exposing loop
operations to AI coding agents without requiring the user to remember CLI flags.

**Loop engineering** is the practice of designing recursive, autonomous processes
that prompt AI agents — as opposed to prompting agents directly. Loops have
durable state (`STATE.md`), safety gates (allowlist/deny), cost budgets, and
rollout tiers (L1 report-only → L2 PR-gated → L3 unattended).

## Capabilities

| Subcommand | When to use |
|-----------|-------------|
| `loop init <pattern>` | Scaffold a new loop from a starter |
| `loop run <loop>` | Execute one loop iteration |
| `loop status` | Show all loops: tier, cadence, last run |
| `loop audit [loop]` | Summarize past run success/cost |
| `loop cost <loop>` | Estimate per-run token cost |
| `loop sync` | Push escalations to knowledge/todos |

## How to invoke

```bash
# Check if ai-workspace loop CLI is available
loop status

# Or invoke directly
~/.ai-workspace/bin/loop status
```

## Routing

1. Check if `~/.ai-workspace/bin/loop` exists → use it
2. Otherwise check `AI_WORKSPACE_LOOP_BIN` env var
3. Otherwise: guide the user to install ai-workspace

## Runner hierarchy (inside bin/loop)

When `./bin/loop run` dispatches a loop, it tries runners in this order:

| Priority | Runner | How to enable |
|----------|--------|---------------|
| 1 | **runner** | `export HARNESS_RUNNER_DIR="$HOME/.local/share//dev-companion/runner"` |
| 2 | **`claude --print`** (Claude Code CLI) | `claude` in PATH — zero setup for Claude Code users |
| 3 | Skeleton plan | Always available |

For full multi-provider support (Anthropic, OpenAI, Ollama, OpenCode), set
`HARNESS_RUNNER_DIR` to point at the runner. Claude Code
users can skip this — `claude --print` is used automatically.

## References

- [agentic-harness loop docs](https://github.com/ulises-jeremias/agentic-harness/blob/main/docs/LOOPS.md)
- [Loop engineering patterns](https://github.com/cobusgreyling/loop-engineering)
- [docs/LOOPS.md](../../../docs/LOOPS.md) — full reference

---

## Rules

1. **Always start at L1** for new loops. Only graduate to L2/L3 after reviewing
   at least 3 consecutive clean L1 runs.

2. **Budget awareness** — report the estimated cost before running an expensive
   loop (pr-babysitter, ci-sweeper). Confirm with the user.

3. **Allowlist enforcement** — never take an action not in the loop's
   `allowlist`. If uncertain: escalate (`human_escalation` exit condition).

4. **Worktree hygiene** — loops create isolated git worktrees. Clean them up
   on success; preserve on failure for postmortem.

5. **Escalation first** — when in doubt, choose `human_escalation` over
   guessing. The user can always re-run.
