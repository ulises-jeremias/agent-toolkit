# oss-triage

Scans open issues across configured OSS repositories. Flags security issues, applies labels, and drafts/posts response comments.

## When to Use
Use this loop to automate basic triage tasks (like labelling or asking for reproducers) across a multi-repository ecosystem.

## Execution
To run this loop:
```bash
agent-toolkit loop run oss-triage
```

## Details
* **Artifact Output:** Triaged items are written to `loops/oss-triage/runs/<run_id>/report.md` on each run.
* **State Checkpointing:** Supports progress checkpointing via `loops/oss-triage/STATE.md`.
* **Safety:** This loop is L1 (Observe and Report). The runner hard-gates all L1 loops as report-only, blocking mutations regardless of allowlist declarations.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
