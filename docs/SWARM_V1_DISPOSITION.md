# Swarm v1 disposition (#1676)

Decision (2026-11-20): **Swarm v1 is feature-frozen.** Only security
and reliability fixes land on the v1 runtime. Multi-agent orchestration
moving forward is the Veasel subagent runtime (durable child runs,
isolated worktrees, approval mediation, cross-provider delegation —
veasel-labs/veasel#629 and children, all closed with evidence). No v1
state is deleted by this disposition.

## Inventory and classification

| v1 asset | Disposition |
|----------|-------------|
| Recipes (`pair`/`team`/`full`), role policies, prompts | Retain as generic primitives: they are portable skills/recipes in this repo and stay readable and runnable read-only (`swarm recipes`, `swarm plan`) |
| Herdr/tmux/headless backends, handoff records | Retain read-only; new runs should prefer Veasel delegation. No hidden second queue is introduced anywhere |
| Run state under `~/.agent-toolkit/swarm/runs/` | Read-only archive (below); originals are never deleted or rewritten by migration tooling |
| `agent-toolkit swarm` CLI | Kept working for inspection (`recipes`, `backends`, `doctor`, `runners`, `models`, `plan`); start-path output points at Veasel for new orchestration |

## Local state audit (this machine, 2026-11-20)

Exactly one v1 run exists: `runs/s20261110T125052Z` (16K, one
`trace.jsonl`, two `role_woken` events from 2026-11-10, no artifacts,
worktrees or pending approvals). It was copied — not moved — to
`~/.agent-toolkit/swarm/archive/2026-11-10-s20261110T125052Z/` with
sha256 `5fe292c0bd0e8cfde27a0f201e46d7db81015f57045babe227eda17ab96fd771`
verified identical to the original. Rollback is trivial: the original
run directory is untouched, and the archive copy can be deleted without
any state loss.

## Migration stance

There is nothing to migrate: the single local run is a completed
two-event trace with no resumable work, and v1 recipes map to Veasel
roles (explorer/reviewer/implementer) without a format conversion.
If a future machine holds live v1 runs, the preview/migrate/rollback
tooling must be built before touching them — this document is the
classification such tooling would implement, not a claim that it
exists.
