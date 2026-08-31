# pr-babysitter

Monitors open PRs that have received no activity or reviews for over an hour and posts constructive review comments.

## When to Use
Use this loop to reduce pull request review latency and keep contributors unblocked on active repositories.

## Execution
To run this loop:
```bash
agent-toolkit loop run pr-babysitter
```

## Details
* **Artifact Output:** Execution logs are written to `loops/pr-babysitter/runs/<run_id>/plan.md` on each run.
* **Safety:** This loop is L2 (Controlled Mutations). It only writes review comments. It never merges, force-pushes, or deletes branches.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
