# ADR-020: Concurrency model for loops, swarm, and runners in V

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#528](https://github.com/ulises-jeremias/agent-toolkit/issues/528))

## Context

EPIC 5 dispositions ([#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560)) mark `loop` ([#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523)) and `swarm` ([#524](https://github.com/ulises-jeremias/agent-toolkit/issues/524)) as **REDESIGN**, not a 1:1 Python port. Python’s loop engine uses **daemon threads** to pump/tail subprocess stdio (`loop/runner.py`); swarm backends spawn UI/runner adapters (ADR-008). V already has `ProcessService` ([#500](https://github.com/ulises-jeremias/agent-toolkit/issues/500)) — argv-only, no shell.

V also has `go` coroutines. Using them (or porting Python threads) for agent work would share the CLI process heap with untrusted runner output and make budgets/timeouts harder to kill. `docs/LOOPS.md` and `docs/SWARM_ARCHITECTURE.md` stay the **behavior** source of truth; this ADR only chooses the **execution** model.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Port Python `threading` | Daemon I/O threads around subprocesses, same shape as `runner.py`. |
| **B** | V `go` coroutines + channels | In-process concurrent pumps and fan-out of swarm roles. |
| **C** | Process-per-run + single-threaded supervisor | One OS process per loop iteration / swarm role via `ProcessService`; CLI process only schedules, waits, and enforces budget. |
| **D** | OS thread pool (C / extra V runtime) | Native threads without `go`; still in-process with the CLI. |

## Decision

Adopt **C**.

1. **Agent work is always an OS process.** Loop iterations and swarm roles are started with `ProcessService.run` (argv, cwd, env, timeout). Never a shell string. Never Python `subprocess` from the V binary.
2. **The V CLI process is a supervisor, not a worker pool.** It is single-threaded: enqueue → spawn (bounded) → wait/timeout → record filesystem state → maybe spawn the next ready role. No `go` for runner I/O; `ProcessService` already captures stdout/stderr and honors timeout (kill on deadline).
3. **Bound concurrency from budget, default 2** (ADR-008 swarm default). Loop `run` is sequential (one iteration at a time) unless `loop.yaml` / CLI explicitly raises a documented cap. Swarm fan-out is `min(ready_roles, budget.concurrency, default 2)`.
4. **Filesystem state remains authoritative** (ADR-008): `STATE.md` / `runs/<id>/` for loops; `state.json`, `trace.jsonl`, `budget.json`, worktrees for swarm. Restarts resume from disk, not from in-memory goroutine state.
5. **Gates, allowlists, deny lists, and human approvals are unchanged.** `loop-gh-gate` stays an argv `PATH` shim installed for the child env (same contract as Python). Swarm merge-to-base still requires human approval.
6. **Windows:** tmux/Herdr adapters are Unix-only (document; do not fake them). Headless process supervisor and worktrees must still work on Windows for loop `run` and swarm `headless`.
7. **Do not invent Bobatea or extra runner APIs** ([#542](https://github.com/ulises-jeremias/agent-toolkit/issues/542)). Runner adapters call existing PATH binaries (`claude`, `opencode`, `gh`, …) through `ProcessService`. Missing stdin on `ProcessService` is a follow-on to #500 — until stdin exists, loop/swarm REDESIGN may write the prompt to a temp file and pass a flag, or fail closed to skeleton/`--no-llm` rather than hang.

### Rejected

- **A** — #560 forbids cloning Python threads; daemon threads are why REDESIGN exists.
- **B** — coroutines share the CLI address space with runner output; cancellation/kill is weaker than `process.signal_kill`; harder to reason about under budgets.
- **D** — same in-process hazards as B, plus CGO/pthread surface the toolkit does not want.

## Consequences

- **Positive:** Matches ProcessService already in core; kill/timeout is real; swarm isolation stays worktree + process (ADR-008); Python retirement does not require a thread runtime.
- **Negative:** Prompt-on-stdin runners need a ProcessService stdin follow-on or a file-flag workaround before full loop parity.
- **Follow-on:** [#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523) REDESIGN loop; [#524](https://github.com/ulises-jeremias/agent-toolkit/issues/524) REDESIGN swarm after loop/process patterns exist. Behavior docs (`LOOPS.md`, `SWARM_*.md`) are not rewritten by this ADR.

## Validation plan

- Loop/swarm V tests spawn **fake argv** fixtures (not real LLM binaries) under `ProcessService` with timeout and non-zero exit.
- Assert no `thread` / `go ` in `modules/agent_toolkit_core` loop/swarm modules when they land.
- Windows CI: loop `status` / swarm headless help; Unix: document tmux/Herdr skip.

## References

- Issues [#528](https://github.com/ulises-jeremias/agent-toolkit/issues/528), [#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523), [#524](https://github.com/ulises-jeremias/agent-toolkit/issues/524), [#500](https://github.com/ulises-jeremias/agent-toolkit/issues/500), [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560)
- [ADR-008](ADR-008-swarm-orchestration.md), [ADR-009](ADR-009-v-module-architecture.md), [ADR-010](ADR-010-cli-core-boundary.md)
- `docs/LOOP_RUNNER_DESIGN.md`, `docs/LOOPS.md`, `docs/SWARM_ARCHITECTURE.md`

**Verified:** 2026-08-13
