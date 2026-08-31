# oss-daily-briefing

Generates a daily read-only briefing across configured OSS ecosystem repositories, covering new PRs, active issues, and CI health.

## When to Use
Use this loop to stay updated on multiple open-source repositories from a single report.

## Execution
To run this loop:
```bash
agent-toolkit loop run oss-daily-briefing
```

## Details
* **Artifact Output:** The daily briefing is written to `loops/oss-daily-briefing/runs/<run_id>/report.md`.
* **State Checkpointing:** Supports progress checkpointing via `loops/oss-daily-briefing/STATE.md`.
* **Safety:** This loop is L1 (Observe and Report) and does not perform any mutations on repositories.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
