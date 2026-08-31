# oss-pr-monitor

Evaluates open pull requests across all configured OSS repositories. Auto-merges Dependabot PRs with passing CI, closes dirty Dependabot PRs, and reports on human PRs.

## When to Use
Use this loop to automate Dependabot updates and get quick diagnostics on human-submitted PRs across a multi-repo ecosystem.

## Execution
To run this loop:
```bash
agent-toolkit loop run oss-pr-monitor
```

## Details
* **Artifact Output:** Triage details are written to `loops/oss-pr-monitor/runs/<run_id>/report.md` on each run.
* **State Checkpointing:** Supports progress checkpointing via `loops/oss-pr-monitor/STATE.md`.
* **Safety:** This loop is L3 (High Autonomy). It only merges or closes Dependabot PRs under passing CI. It never merges or closes human PRs.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints. For discovery, see `docs/LOOPS.md` and `examples/oss-maintenance/README.md`.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
