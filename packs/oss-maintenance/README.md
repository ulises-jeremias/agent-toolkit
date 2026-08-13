# OSS Maintenance Pack

Automate PR review, issue triage, and daily briefings across a multi-repo OSS ecosystem. This pack combines three loops that work together to reduce the manual overhead of maintaining 10–50 open-source repositories.

---

## What It Does

| Loop | Tier | Cadence | Actions | Description |
|------|------|---------|---------|-------------|
| `oss-daily-briefing` | L1 | Daily | Read-only | Summarizes new PRs, issues needing attention, and CI health across all repos |
| `oss-triage` | L1 | Daily | label, comment, assign | Labels issues, responds to questions, asks for reproducers on bugs |
| `oss-pr-monitor` | L2 | Daily | merge, close, label, comment | Merges safe Dependabot PRs, closes dirty ones, reports on human PRs |

**Start with `oss-daily-briefing`.** Run it for a week before enabling `oss-triage`. Run triage for a week before enabling `oss-pr-monitor`. This progression lets you validate the loop's behavior at each tier before escalating.

---

## Prerequisites

- `gh` CLI installed and authenticated with push access to your repositories:
  ```bash
  gh auth status
  gh auth login   # if not authenticated
  ```
- A loop runner available. The loops are designed for use with the `agent-toolkit loop` runner from [agentic-harness](https://github.com/ulises-jeremias/agentic-harness), but the `request` prompt in each `loop.yaml` can be run manually or with any compatible runner.
- Token budget: see [Budget Sizing](#budget-sizing) below.

---

## Setup

### Step 1: Copy the loop templates

```bash
# From the agent-toolkit directory
cp -r loops/oss-pr-monitor  ~/.ai-workspace/loops/
cp -r loops/oss-triage      ~/.ai-workspace/loops/
cp -r loops/oss-daily-briefing ~/.ai-workspace/loops/
```

### Step 2: Configure your repo list

```bash
cp packs/oss-maintenance/config.yaml ~/.ai-workspace/packs/oss-maintenance.yaml
```

Edit `~/.ai-workspace/packs/oss-maintenance.yaml` and add your repositories:

```yaml
repos:
  - myorg/my-library
  - myorg/my-cli-tool
  - myorg/another-repo
```

### Step 3: Reference the pack from each loop

Each loop's `request` prompt uses the repos list from the pack config. If your loop runner does not inject pack config automatically, add the repo list directly to the loop's request template.

Alternatively, create a shared repos file and reference it from each loop's request:

```bash
echo "owner/repo1" > ~/.ai-workspace/loops/repos.txt
echo "owner/repo2" >> ~/.ai-workspace/loops/repos.txt
```

### Step 4: Run at each tier

Start read-only. Graduate to each tier only after confirming the previous tier runs correctly.

```bash
# Tier 1: Daily briefing (read-only, lowest cost)
agent-toolkit loop run oss-daily-briefing

# Tier 1: Issue triage (label + comment, medium cost)
agent-toolkit loop run oss-triage

# Tier 2: PR monitor (merge + close, highest cost — REVIEW THE REPORT FIRST)
agent-toolkit loop run oss-pr-monitor
```

---

## Budget Sizing

Token consumption scales with the number of repos and open PRs/issues per repo. These estimates assume moderate activity (5–15 open PRs and 10–30 open issues per repo).

| Repos | oss-daily-briefing | oss-triage | oss-pr-monitor |
|-------|--------------------|------------|----------------|
| 10    | ~20,000            | ~40,000    | ~80,000        |
| 20    | ~40,000            | ~75,000    | ~150,000       |
| 40    | ~80,000            | ~150,000   | ~300,000       |
| 60    | ~120,000           | ~225,000   | ~450,000       |

**Formula:** `max_tokens = (repo_count × avg_tokens_per_repo) + 20000` where:
- `oss-daily-briefing`: ~1,500 tokens/repo
- `oss-triage`: ~3,200 tokens/repo
- `oss-pr-monitor`: ~7,000 tokens/repo

To override the default budget in `config.yaml`:

```yaml
loops:
  oss-pr-monitor:
    enabled: true
    cadence: 1d
    budget:
      max_tokens: 450000    # for 60 repos
      max_wall_seconds: 3600
```

If your ecosystem has more than 50 repos, split it into two packs and run each with a separate loop instance:

```yaml
# oss-maintenance-alpha.yaml
repos:
  - org/repo-01
  - org/repo-02
  # ... first 25 repos

# oss-maintenance-beta.yaml
repos:
  - org/repo-26
  - org/repo-27
  # ... next 25 repos
```

---

## Resumability

All three loops support mid-run checkpointing via `STATE.md`. If a 40-repo scan is interrupted at repo 17 (budget exhausted, timeout, or error), the next run automatically skips repos 1–16 and resumes from repo 17.

### How it works

1. At run start, the loop reads `loops/<name>/STATE.md`
2. If `last_processed_repo` is set, it skips all earlier repos in the configured list
3. After processing each repo, it writes `last_processed_repo: <owner>/<repo>` to `STATE.md`
4. On successful completion, it clears `last_processed_repo` and sets `last_run_status: success`

### Inspecting state

```bash
cat ~/.ai-workspace/loops/oss-pr-monitor/STATE.md
```

Example `STATE.md` after a partial run:

```markdown
last_processed_repo: myorg/repo-17
last_run: 2026-08-04T09:23:11Z
last_run_status: partial (budget_exhausted)
```

### Resetting state

To force a full re-scan from the beginning:

```bash
# Remove the checkpoint field
sed -i '/^last_processed_repo/d' ~/.ai-workspace/loops/oss-pr-monitor/STATE.md

# Or overwrite the entire STATE.md
cat > ~/.ai-workspace/loops/oss-pr-monitor/STATE.md <<'EOF'
last_processed_repo:
last_run:
last_run_status:
EOF
```

---

## Reading the Reports

After each loop run, a report is written to `loops/<name>/report.md`.

### oss-daily-briefing report

Sections: new PRs (last 24h), issues needing attention, CI health by repo, highlights.

Review this report daily. If a repo shows persistent CI failures or a flood of new issues, investigate before the next run.

### oss-triage report

Sections: actions taken (labels applied, comments posted), items needing human review, escalations.

**Review "items needing human review" every run.** These are issues the loop flagged as too complex to handle automatically. Security escalations appear here and should be addressed immediately.

### oss-pr-monitor report

Columns: Repo, PR number, Title, Author, Type (dep/bot/human), CI status, Action taken, Pending reason.

**Review this report before the next daily run.** The loop merges Dependabot PRs automatically — the report tells you which ones were merged, which were closed, and which human PRs have CI failures or conflicts waiting for attention.

---

## Safety Gates

The loops are designed to be safe by default. Key constraints:

**oss-pr-monitor:**
- Merges Dependabot PRs only when CI is fully green — no partial passes
- Closes Dependabot PRs only when they are in a dirty state (GitHub will regenerate them)
- Never merges or closes human PRs
- Never approves any PR
- Never force-pushes
- Escalates on any security concern

**oss-triage:**
- Never closes issues
- Never merges anything
- Escalates security reports immediately (does not post a comment — uses `human_escalation` exit)

**oss-daily-briefing:**
- Fully read-only — zero mutations of any kind

---

## Files

| File | Description |
|------|-------------|
| `config.yaml` | Pack configuration: repo list and loop settings |
| `loops/oss-daily-briefing/loop.yaml` | Daily briefing loop definition |
| `loops/oss-triage/loop.yaml` | Issue triage loop definition |
| `loops/oss-pr-monitor/loop.yaml` | PR monitor loop definition |
| `loops/*/STATE.md` | Runtime checkpoint state (written by loop runner) |
| `loops/*/report.md` | Loop output reports (written by AI) |

---

## Troubleshooting

**Loop runs out of budget before finishing all repos.**
Increase `max_tokens` in `config.yaml` or split your repo list across two packs. The loop will resume from where it left off on the next run regardless.

**Dependabot PR was not merged despite passing CI.**
Check the PR's merge status with `gh pr view <number> --repo <owner>/<repo>`. The loop skips PRs that are in draft state or have branch protection rules that require human approval.

**A comment was posted that looks AI-generated.**
The loops are instructed never to leave AI-looking comments. If you see one, file an issue with the comment text and the loop name so the prompt can be improved.

**oss-pr-monitor is not picking up my repo.**
Ensure the repo is in the `repos:` list in `config.yaml`, formatted as `owner/repo` (no `https://github.com/` prefix). Verify `gh api repos/owner/repo` succeeds from your terminal.
