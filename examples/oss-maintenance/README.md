# Example: OSS Maintenance Pack

This example shows how to set up automated maintenance for a multi-repository GitHub presence using the agent-toolkit OSS loop templates. By the end, you will have daily briefings, automated issue triage, and PR monitoring running as recurring agent loops.

---

## What This Example Sets Up

| Loop | Tier | Cadence | What it does |
|------|------|---------|-------------|
| `oss-daily-briefing` | L1 | Daily | Reads all repos, writes a single Markdown briefing |
| `oss-triage` | L1 → L2 | Daily | Identifies issues needing attention; optionally labels them |
| `oss-pr-monitor` | L3 | 1d | Tracks PR status; optionally merges Dependabot PRs |

---

## Prerequisites

- **git** — to clone agent-toolkit
- **gh** (GitHub CLI) — authenticated with an account that has repo access
  ```bash
  gh auth status          # Verify authentication
  gh auth login           # Authenticate if needed
  ```
- **Python 3.11+** — for loop validation scripts
- **A GitHub token** with `repo` scope (the default `gh` token works)
- At least one AI coding assistant installed (Claude Code, Cursor, or OpenCode)

Verify prerequisites:

```bash
git --version             # Any version
gh --version              # 2.40 or later recommended
python3 --version         # 3.11 or later
```

---

## Step 1: Install agent-toolkit

```bash
# Any V channel — GitHub Release, Homebrew, AUR agent-toolkit-bin, npm, or:
uvx --from agent-toolkit-cli agent-toolkit install
# permanently
uv tool install 'agent-toolkit-cli>=1.11.0' && agent-toolkit install
```

This detects your AI tools and deploys the appropriate profiles. No `git clone` or `install.sh` required.

---

## Step 2: Configure Your Repo List

The OSS loops need to know which repos to scan. Open the loop's request file and update the repo list, or set the `REPOS` environment variable.

**Option A: Hardcode in loop.yaml (recommended for stable sets)**

Edit `~/.agent-toolkit/loops/oss-daily-briefing/loop.yaml`. Find the repo list section in the `request` field and add your repos:

```yaml
# In the request field, the agent will read this list.
# You can embed it directly in your workspace config or pack.
```

For the OSS maintenance loops, create or edit a pack file at
`packs/oss-maintenance/config.yaml` in your workspace (or copy from this
repo's [`packs/oss-maintenance/`](../../packs/oss-maintenance/)):

```yaml
name: oss-maintenance
repos:
  - owner/repo-one
  - owner/repo-two
  - owner/repo-three
  # Add all repos you want monitored
config:
  stale_days: 30
  inactive_days: 14
  dependabot_auto_merge: false    # Set true when ready for L2
```

**Option B: Use gh to discover repos automatically**

If your repos are all under one owner, the loop can discover them dynamically:

```bash
# Test what gh would return
gh repo list your-org --limit 50 --json nameWithOwner --jq '.[].nameWithOwner'
```

The loop templates default to this discovery method when no pack is configured.

---

## Step 3: Validate the Loop Templates

Before running anything, confirm the loop manifests are valid:

```bash
cd ~/.agent-toolkit
pip install pyyaml jsonschema
python3 -c "
import json, yaml, sys
from pathlib import Path
from jsonschema import validate, ValidationError
schema = json.loads(Path('schemas/loop.schema.json').read_text())
errors = []
for f in sorted(Path('loops').rglob('loop.yaml')):
    try: validate(yaml.safe_load(f.read_text()), schema)
    except ValidationError as e: errors.append(f'{f}: {e.message}')
if errors:
    [print(e) for e in errors]; sys.exit(1)
print(f'All loops valid.')
"
```

---

## Step 4: Run the First Loop at L1

Start with `oss-daily-briefing`. It is read-only and produces a single Markdown report. No mutations will occur.

### Using Claude Code

Open Claude Code in your ai-workspace (or any directory containing the agent-toolkit loops). Ask:

```
Run the oss-daily-briefing loop. Read loops/oss-daily-briefing/loop.yaml for instructions.
```

Claude Code will follow the `request` prompt in the loop manifest. It will:
1. Read `STATE.md` to check for resumability state
2. Query each repo for new PRs, issues, and CI status
3. Write the briefing to `loops/oss-daily-briefing/report.md`

### Expected output

After a successful run, `loops/oss-daily-briefing/report.md` will contain:

```markdown
## OSS Daily Briefing — 2026-08-04

### New PRs (last 24h)
| Repo | # | Title | Author |
|------|---|-------|--------|
| owner/repo-one | 47 | feat: add retry logic | contributor-a |

### Issues needing attention
| Repo | # | Title | Last comment |
|------|---|-------|-------------|
| owner/repo-two | 123 | Bug: crash on empty input | 3 days ago |

### CI Health
| Repo | Status |
|------|--------|
| owner/repo-one | passing |
| owner/repo-two | failing (2 checks) |

### Highlights
- owner/repo-one v2.1.0 released yesterday
```

### Verifying STATE.md

After each repo is processed, the agent writes a checkpoint:

```markdown
last_processed_repo: owner/repo-two
last_run: 2026-08-04T08:30:00Z
last_run_status: in_progress
```

On completion:

```markdown
last_processed_repo: ""
last_run: 2026-08-04T08:34:22Z
last_run_status: success
```

---

## Step 5: Read and Interpret the Report

The briefing report is structured in priority order. Here is how to read each section:

**New PRs** — review PRs needing code review or merge. If a PR is a week old with no activity, it may need a nudge.

**Issues needing attention** — issues flagged by age, last-comment date, or absence of labels. These are candidates for triage.

**CI Health** — repos with failing CI need immediate attention. Check the workflow file and recent commits.

**Highlights** — notable events: releases, milestones, first-time contributors.

Run the briefing daily for at least 3 days. If the report is accurate and useful, proceed to Step 6.

---

## Step 6: Graduate to L2 for Automated Triage

After 3+ clean L1 runs of `oss-daily-briefing`, add `oss-triage` at L1, then graduate it to L2.

### L1 run (propose labels only)

Run `oss-triage` at L1 and review its proposals in `loops/oss-triage/report.md`. The report will include:

```markdown
## Triage Report — 2026-08-04

### Proposed labels (not applied — review before acting)
| Repo | Issue # | Current labels | Proposed labels | Reason |
|------|---------|---------------|-----------------|--------|
| owner/repo | 123 | (none) | bug, needs-info | Crash report with no steps to reproduce |
```

If the proposals look correct for 3 consecutive runs, edit `loops/oss-triage/loop.yaml`:

```yaml
tier: L2
allowlist:
  - label
  - comment
deny:
  - assign
  - merge
  - close
  - push
  - approve
  - force-push
```

Update the `request` field to apply labels instead of proposing them:

```yaml
request: |
  ...
  **Step 3 — Apply labels**
  For each proposed label change, apply it:
    gh issue edit <number> --repo <owner>/<repo> --add-label <label>
  ...
```

---

## Step 7: Expected Costs

Token costs scale linearly with repo count. These estimates are based on Sonnet-class models at typical OSS repo activity levels (10–30 open PRs, 30–100 open issues per repo):

### oss-daily-briefing (L1, 1x/day)

| Repos | Tokens/run | Approx cost/month |
|-------|-----------|------------------|
| 10 | ~20,000 | ~$0.06 |
| 20 | ~40,000 | ~$0.12 |
| 40 | ~80,000 | ~$0.24 |

### oss-triage (L1, 1x/day)

| Repos | Tokens/run | Approx cost/month |
|-------|-----------|------------------|
| 10 | ~40,000 | ~$0.12 |
| 20 | ~80,000 | ~$0.24 |
| 40 | ~150,000 | ~$0.45 |

### oss-pr-monitor (L2, every 15 min)

| Repos | Tokens/run | Runs/day | Approx cost/month |
|-------|-----------|----------|------------------|
| 10 | ~80,000 | 48 | ~$11.52 |
| 20 | ~160,000 | 48 | ~$23.04 |
| 40 | ~300,000 | 48 | ~$43.20 |

> Token prices used: input $3/MTok, output $15/MTok, blended ~$5/MTok (Sonnet-class, 2026). Check current pricing at anthropic.com.

**Cost-saving tips:**
- Run `oss-pr-monitor` hourly instead of every 15 minutes to cut costs by 4x
- Limit `oss-pr-monitor` to repos with active PR activity
- If your ecosystem has 40+ repos, split into two pack files and run separate loop instances

---

## Troubleshooting

**The loop exits with `budget_exhausted` before scanning all repos.**

This is expected behavior. The loop checkpoints its state in `STATE.md`. The next run will resume from the last processed repo. No data is lost. If this happens every run, increase `budget.max_tokens` or reduce the repo list.

**gh returns a 401 Unauthorized error.**

```bash
gh auth status    # Check current authentication
gh auth refresh   # Refresh the token
```

**The report is empty or missing sections.**

The loop ran but found nothing matching its criteria. This is correct — if you have no new PRs in 24 hours or no stale issues, the sections will be empty. Check the loop's `goal` field to confirm the criteria align with your expectations.

**STATE.md shows `last_run_status: partial` for multiple consecutive runs.**

The loop is consistently running out of budget. Options:
1. Increase `budget.max_tokens` by 50% and re-run
2. Reduce the repo list
3. Split the ecosystem into two packs
