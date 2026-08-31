# dep-sweeper

Scans for available patch-level updates across ecosystems (npm, pip, cargo, etc.) and opens draft PRs if local tests pass.

## When to Use
Use this loop to automate mechanical, low-risk dependencies maintenance without manual checking.

## Execution
To run this loop:
```bash
agent-toolkit loop run dep-sweeper
```

## Details
* **Artifact Output:** Execution plans are written to `loops/dep-sweeper/runs/<run_id>/plan.md`.
* **SemVer Safety:** Only patch updates are applied. The loop skips updates when the major or minor versions in the version string change.
* **Safety:** This loop is L2 (Controlled Mutations). It only comments or opens draft PRs. It never merges or force-pushes.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
