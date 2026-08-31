# post-merge-cleanup

Performs off-peak housekeeping tasks on the repository. Scans for merged branches to delete, closes resolved issues, and warns on stale ones.

## When to Use
Use this loop to keep git history, pull request interfaces, and issue boards clean on an active repository.

## Execution
To run this loop:
```bash
agent-toolkit loop run post-merge-cleanup
```

## Details
* **Artifact Output:** Cleaned up items are written to `loops/post-merge-cleanup/runs/<run_id>/plan.md` on each run.
* **Safety:** This loop is L2 (Controlled Mutations). It deletes branches merged more than 7 days ago and closes resolved issues. It never force-pushes or deletes unmerged branches.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
