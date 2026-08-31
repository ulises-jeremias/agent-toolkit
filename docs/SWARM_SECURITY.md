# Swarm Security

Threat model for `agent-toolkit swarm`.

## Threats

- Prompt injection from repo files / malicious issue content
- Path traversal, symlink escapes, external-directory writes
- Command injection, unsafe shell quoting, branch/role injection
- Handoff spoofing/replay, tampered commits, untrusted plugin actions
- Secret leakage, credential propagation, accidental pushes/destructive git
- Cleanup of user-owned worktrees, cross-run state confusion

## Mitigations

- Validate all identifiers: role `^[a-z][a-z0-9_-]{1,31}$`, run_id `^[a-zA-Z0-9][a-zA-Z0-9._-]{2,64}$`, branch safe, SHA 40 hex.
- Use full SHAs internally, `git cat-file -t` validation, `git rev-parse --verify` for abbrev (fails on ambiguous).
- Atomic writes via tmpfile+rename, durable `state.json` with version, `trace.jsonl` append-only.
- Path containment: `validate_artifact_path()` ensures relative, no `..`, stays under `run_dir`.
- `is_path_contained()` for worktree ownership.
- Redact secrets: `sanitize_args()` replaces token/secret/key/password values with `[REDACTED]`, never serialize credential values.
- Scope env vars per process, generic UI wake-up notifications only.
- Runner permissions: `external_directory: deny` by default, `git push: deny`, `git reset --hard: deny`, `git clean: deny`.
  - Planner: `edit: deny`
  - Implementer: `edit: allow` but `push` denied
  - Reviewer: `edit: deny` by default, reviewer-writer optional
  - Integrator: `merge: ask`, still deny push/release/credential/external writes.
- Default gates: `allow_direct_base_merge: false`, `allow_push: false`.
- Cleanup only Toolkit-owned worktrees under `.agent-toolkit/swarm/runs/<run-id>/worktrees/`, check `git status --porcelain` dirty, refuse without `--force`, never delete branches automatically, never remove user worktrees.
- Fail closed when ownership unclear.

## Defaults

- No push, no release, no base-merge, external-directory deny.
- No telemetry, no cloud upload, no transcript storage by default (optional with warning).

## Testing

Unit tests for injection: role injection (`"; rm -rf /"`), branch injection, path traversal (`../../etc/passwd`), commit tampering, handoff replay, oversized artifact (>1MB).

## Herdr / tmux & Runner Separation

- **Backend separation:** Herdr ([SWARM_HERDR.md](SWARM_HERDR.md)) and tmux ([SWARM_TMUX.md](SWARM_TMUX.md)) are adapters implementing `SwarmUIBackend` — no recipe/handoff/budget/git logic in adapters. Orchestrator never branches on backend for correctness; backend metadata stays in backend state. See adapter separation diagram in [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md).
- **Runner isolation:** permissions above apply uniformly regardless of `--runner opencode|claude|codex|cursor|copilot|muse|skeleton` or `--model-profile economy|balanced|quality|private`. `--runner skeleton` is safe for offline/CI (no LLM, no external calls).
- **State & privacy:** state under `.agent-toolkit/swarm/runs/<run-id>/` is filesystem-authoritative; no cloud. Cleanup only Toolkit-owned `worktrees/` with dirty/branch preservation; Herdr plugin never handles secrets.

Related: [SWARMS.md](SWARMS.md) · [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (security boundaries, runtime layers) · [SWARM_RECIPES.md](SWARM_RECIPES.md) · [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md) · [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) · [SWARM_HERDR.md](SWARM_HERDR.md) · [SWARM_TMUX.md](SWARM_TMUX.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md)

## References

ADR-008, `swarm/store.py`, `swarm/handoff.py`, `swarm/worktree.py`, `swarm/runner.py` permissions, [ARCHITECTURE.md](ARCHITECTURE.md), [CONCEPTS.md](CONCEPTS.md).
