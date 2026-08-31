# changelog-drafter

Drafts release notes in [Keep a Changelog](https://keepachangelog.com/) format by collecting all pull requests merged since the last git tag.

## When to Use
Use this loop to automate draft release notes creation for review before tagging or publishing a release.

## Execution
To run this loop:
```bash
agent-toolkit loop run changelog-drafter
```

## Details
* **Artifact Output:** Draft changelog is written to `loops/changelog-drafter/runs/<run_id>/report.md` on each run.
* **Safety:** This loop is L1 (Observe and Report). It does not commit, tag, or push to the repository.
* **Configuration:** See [loop.yaml](loop.yaml) for tier, cadence, budget, and safety constraints.

For more details on loops and safety tiers, see [docs/LOOPS.md](../../docs/LOOPS.md).
