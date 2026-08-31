# issue-triage

Triages unlabeled issues by proposing labels, type classifications, and priority ratings.

## When to Use
Use this loop to stay organized on repositories with high issue activity.

## Execution
To run this loop:
```bash
agent-toolkit loop run issue-triage
```

## Details
* **Artifact Output:** Triage proposals are written to `loops/issue-triage/runs/<run_id>/report.md` on each run.
* **Safety:** This loop is L1 (Observe and Report). It does not apply labels or write comments directly.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
