# daily-triage

Scans open issues created in the last 24 hours to propose priority scores, labels, and brief summaries.

## When to Use
Use this loop to stay on top of incoming issues on a single repository with a low token budget.

## Execution
To initialize and run this loop:
```bash
agent-toolkit loop init daily-triage
agent-toolkit loop run daily-triage
```

## Details
* **Artifact Output:** Triage proposals are written to `loops/daily-triage/runs/<run_id>/report.md`.
* **Safety:** This loop is L1 (Observe and Report). It does not write comments or apply labels directly.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
