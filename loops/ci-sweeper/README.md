# ci-sweeper

Monitors failing CI runs on open PRs and the main branch, diagnoses the root cause, and opens a draft PR with a minimal fix if straightforward.

## When to Use
Use this loop to automatically detect and propose fixes for minor, repetitive CI breakages (such as lockfile issues, syntax bugs, or test environment problems).

## Execution
To run this loop:
```bash
agent-toolkit loop run ci-sweeper
```

## Details
* **Artifact Output:** Execution plans are written to `loops/ci-sweeper/runs/<run_id>/plan.md` on each run.
* **Safety:** This loop is L2 (Controlled Mutations). It only comments or opens draft PRs. It never merges, force-pushes, or deletes branches.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
