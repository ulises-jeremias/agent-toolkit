# OSS Maintenance Pack

Automate PR review, issue triage, and daily briefings across a multi-repo OSS ecosystem.

## What It Does

| Loop | Tier | Cadence | What it does |
|------|------|---------|-------------|
| `oss-pr-monitor` | L2 | Daily | Merges safe dependabot PRs, closes dirty ones, reports human PRs |
| `oss-triage` | L1 | Daily | Labels issues, responds to questions, reports items needing attention |
| `oss-daily-briefing` | L1 | Daily | Read-only activity summary across all repos |

## Prerequisites

- `gh` CLI authenticated with push access to your repos
- A loop runner (`bin/loop` from [ai-workspace](https://github.com/ulises-jeremias/ai-workspace))
- Enough token budget: see [budget sizing](#budget-sizing)

## Setup

1. Copy the loop templates to your workspace:
```bash
cp -r loops/oss-pr-monitor ~/.ai-workspace/loops/
cp -r loops/oss-triage ~/.ai-workspace/loops/
cp -r loops/oss-daily-briefing ~/.ai-workspace/loops/
```

2. Edit `config.yaml` with your repo list:
```bash
cp packs/oss-maintenance/config.yaml ~/.ai-workspace/packs/oss-maintenance.yaml
# Edit the repos list
```

3. Update each loop's `request.md` with your repo list (or reference the pack config).

4. Run at L1 first (observe only):
```bash
./bin/loop run oss-daily-briefing   # cheapest, good first test
./bin/loop run oss-triage           # observe triage recommendations
./bin/loop run oss-pr-monitor       # observe PR decisions (L2 — will act)
```

## Budget Sizing

For 40 repos:
- `oss-pr-monitor`: **300k tokens** max (merges/closes PRs, needs context per PR)
- `oss-triage`: **150k tokens** max (reads issues + proposes actions)
- `oss-daily-briefing`: **80k tokens** max (read-only summary)

Formula: `max_tokens = (repo_count × 7000) + 50000`

## Resumability

All three loops support mid-run recovery. If a 40-repo scan is interrupted at repo 15, the next run skips repos 1-14 automatically.

The `last_processed_repo` field in `STATE.md` tracks progress. Clear it to restart from scratch:
```bash
sed -i '/last_processed_repo/d' ~/.ai-workspace/loops/oss-pr-monitor/STATE.md
```

## Files

- `config.yaml` — repo list and loop settings
- Loops: see `loops/oss-pr-monitor/`, `loops/oss-triage/`, `loops/oss-daily-briefing/`
