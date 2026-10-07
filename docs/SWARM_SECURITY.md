# Swarm Security

Threat model for `agent-toolkit swarm`.

## Runtime boundary

Swarm worktrees isolate Git changes, not a runner's operating-system access.
Recipe role policies and gate fields describe orchestration intent; they do
not provide a cross-provider filesystem, network, credential, or subprocess
sandbox. The Claude adapter currently passes
`--dangerously-skip-permissions`; treat that runner as having the local user's
permissions. Do not run untrusted prompts or repository content under the
assumption that `read-only`, `allow_push: false`, or a worktree is a security
boundary. Use provider-native sandboxing or an external OS/container boundary
when isolation is required.

Human approval gates govern Toolkit's explicit run/approval operations. They
cannot prevent a runner from invoking its own shell or provider tools unless
that provider enforces a separate permission boundary.

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
- Artifact and ownership paths are checked by the current V implementation; these checks protect Toolkit-managed files, not arbitrary runner filesystem access.
- Run metadata is stored under the run directory. Do not assume provider credentials or runner output are universally redacted; runners inherit the environment required by their provider and may emit sensitive data.
- UI notifications carry generic wake-up information; they are not a credential-handling boundary.
- Role policies (for example `read-only`, `writer`, and `integrator`) guide
  task prompts and orchestration; they are not enforced operating-system
  permissions. Provider-native controls vary by runner.
- Built-in recipes declare `allow_direct_base_merge: false` and
  `allow_push: false`. These declarations are not a general-purpose command
  filter for actions taken inside an agent process.
- `swarm cleanup RUN_ID` operates on run-owned worktrees, checks dirty state, and refuses destructive cleanup without `--force`; it preserves branches and run records. `swarm prune` is a separate destructive retention operation that can remove eligible generated branches and run records; review its dry-run output first.
- Fail closed when ownership unclear.

## Defaults

- Built-in recipes default to no direct base merge and no push in their
  orchestration metadata. This is not a sandbox; see Runtime boundary above.
- No telemetry, no cloud upload, no transcript storage by default (optional with warning).

## Testing

The current V swarm tests cover selected recipe defaults, launch behavior,
state/catalog behavior, and command construction. They do not establish a
general runner sandbox or prove every threat listed above is mitigated. Review
the `swarm*_test.v` files alongside the implementation when relying on a
specific validation guarantee.

## Herdr / tmux & Runner Separation

- **Backend separation:** Herdr ([SWARM_HERDR.md](SWARM_HERDR.md)) and tmux ([SWARM_TMUX.md](SWARM_TMUX.md)) are adapters implementing `SwarmUIBackend` — no recipe/handoff/budget/git logic in adapters. Orchestrator never branches on backend for correctness; backend metadata stays in backend state. See adapter separation diagram in [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md).
- **Runner isolation:** provider permission behavior varies by runner. The Claude adapter currently uses `--dangerously-skip-permissions`; see Runtime boundary. `--runner skeleton` does not invoke an LLM.
- **State & privacy:** state under `.agent-toolkit/swarm/runs/<run-id>/` is filesystem-authoritative. Local state does not imply that provider requests, logs, or inherited environment are private. The Herdr plugin delegates orchestration to Toolkit.

Related: [SWARMS.md](SWARMS.md) · [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (security boundaries, runtime layers) · [SWARM_RECIPES.md](SWARM_RECIPES.md) · [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md) · [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) · [SWARM_HERDR.md](SWARM_HERDR.md) · [SWARM_TMUX.md](SWARM_TMUX.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md)

## References

ADR-008, `modules/agent_toolkit_core/swarm.v`,
`modules/agent_toolkit_core/swarm_backend.v`,
`modules/agent_toolkit_core/swarm_handoff.v`,
`modules/agent_toolkit_core/swarm_worktree.v`,
`modules/agent_toolkit_core/swarm_test.v`, [ARCHITECTURE.md](ARCHITECTURE.md),
and [CONCEPTS.md](CONCEPTS.md).
