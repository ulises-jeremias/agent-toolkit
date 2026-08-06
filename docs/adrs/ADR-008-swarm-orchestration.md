# ADR-008: Backend-Neutral Local Multi-Agent Swarm Orchestration

**Status:** Accepted  
**Date:** 2026-08-06  
**Deciders:** agent-toolkit maintainers  
**Relates to:** ADR-001 (canonical IR), ADR-005 (data packaging)

## Context

Coordinated independent coding-agent sessions are useful for delivery workflows where separation of concerns improves quality (implement vs review, plan vs build vs harden). Running multiple chats in one checkout is unsafe because agents overwrite each other's files, interleave tool output, and cannot hand off code via validated commits. tmux-only orchestration is restrictive for users who prefer Herdr's interactive UI. Herdr should be the recommended UI but must not be the runtime source of truth, otherwise offline or SSH usage breaks. OpenCode should be the initial recommended runner but not the only runner, because the toolkit already supports multiple runners. Worktrees and durable handoffs are required for isolation and auditability. Budget control (tokens, cost, time, concurrency, iterations) is mandatory for cost-aware local usage with no mandatory cloud service.

## Options

### 1. No swarm — keep single-agent loops only
- **Pros:** No new complexity.
- **Cons:** Cannot express implement→review→integrate workflows; misses Herdr/tmux demand.

### 2. tmux as core engine, Herdr as plugin
- **Pros:** Simple terminal multiplexing.
- **Cons:** Conflates UI with orchestration; no durable state; couples engine to pane layout.

### 3. Herdr as source of truth (socket API)
- **Pros:** Rich UI state.
- **Cons:** Requires Herdr daemon; no portable fallback; workflow correctness depends on UI.

### 4. Backend-neutral orchestration with filesystem state (chosen)
- **Pros:** Orchestration engine owns recipes, handoffs, budgets, worktrees; UI backends (Herdr, tmux, headless) are adapters; filesystem state is authoritative; Git commits are code-change handoff unit; portable, auditable, no cloud/telemetry.
- **Cons:** More local state and tests; need to maintain two UI adapters.

## Decision

Agent Toolkit owns swarm orchestration.

- **UI and agent runners are separate adapters.** Orchestration defines what work exists, who owns it, and state transitions. UI backends (Herdr, tmux, headless) only display/control sessions. Runner adapters (OpenCode, Muse, Claude, Codex, Cursor, Copilot) only start/prompt/stop agents.
- **Filesystem state is authoritative.** `state.json`, `trace.jsonl`, `budget.json`, `handoffs/`, `artifacts/`, `worktrees/` under `.agent-toolkit/swarm/runs/<run-id>/` survive restarts.
- **Git commits are the code-change handoff unit.** Roles transfer code only via validated full SHA commits on Toolkit-owned branches `agent-toolkit-swarm/<run-id>/<role>`. No uncommitted code transfer.
- **Each writing role gets an isolated worktree.** Read-only planner may use isolated worktree when enforcement would be weak. Paths deterministic, ownership recorded, dirty worktrees preserved, branches never auto-deleted, base branch never checked out illegally.
- **Human approval is required before base-branch merge by default.** No role may push, merge to base, or publish. Gates: plan, architecture decision, cost escalation, final integration.
- **Swarms are lazy and elastic.** Topology created logically, only roles whose inputs are ready start. `pair → team → full` promotion preserves run ID, artifacts, branches, budget, audit history. Default concurrency 2, default round trips 2.
- **Herdr is recommended.** tmux is the portable fallback. Workstation provisions dependencies. Harness demonstrates usage.

Recipe format versioned `agent-toolkit.dev/v1alpha1`, kind `SwarmRecipe`. State and handoff formats versioned. Engine rejects unsupported major versions, migrates known minor versions, preserves old artifacts.

Model selection uses semantic profiles (`economy`, `balanced`, `quality`, `private`) mapping task classes (`planning`, `coding`, `review`, `architecture`, `hardening`, `qa`) to `provider/model` IDs. Discovery via runner, validated before start. Pricing stored separately, unknown pricing reported honestly; expensive fallback requires approval.

## Consequences

- **Positive:** New advanced CLI `agent-toolkit swarm`; auditable runs; controlled cost; portable fallback; no mandatory server.
- **Negative:** Additional local state; more complex tests; two UI backends to maintain.
- **Rejected alternatives:** Direct pane-to-pane messages, shared working directory, tmux as core engine, Herdr as source of truth, storing complete chat transcripts in handoffs, all roles using same frontier model, starting all six roles immediately, auto-merging into base branch, putting orchestration in Workstation or Harness.

## References

- Swarm Forge inspiration (role separation, worktree isolation, handoff protocol) — clean-room only, no code/text copy without license
- Herdr docs: workspace/create, worktree/create, agent/start, agent/prompt, agent/wait, agent/read, integration/install, plugin/link
- tmux control mode docs, OpenCode docs (provider/model, agents, permissions), Git worktree/merge/rev-parse docs
- Toolkit loop runner (`packages/agent-toolkit-cli/src/agent_toolkit/loop/runner.py`), budget (`loop/budget.py`), runner policy (`runner/policy.py`), `_paths.py`
- CLI surfaces: `docs/CLI_SURFACES.md`, `docs/ARCHITECTURE.md`, `docs/LOOP_RUNNER_DESIGN.md`
