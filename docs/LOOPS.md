# Loop Engineering

Loops are recurring agentic workflows. They run on a cadence, observe or act on repositories, and stop when their goal is met, their budget is exhausted, or a human escalation is required. Every loop ships with explicit safety gates so there are no surprise mutations.

---

## What Is a Loop?

A loop is a directory under `loops/<name>/` containing at minimum a `loop.yaml` file. The loop runner reads this file and executes the `request` prompt on the declared cadence.

```
loops/
└── oss-pr-monitor/
    ├── loop.yaml     # Required: loop definition
    ├── STATE.md      # Runtime: checkpoint state (written by loop runner)
    └── report.md     # Runtime: output report (written by the AI)
```

### loop.yaml Structure

```yaml
name: my-loop
description: "Short description (tier, cadence)"
tier: L1            # L1, L2, or L3
cadence: 1d         # e.g. 15m, 4h, 1d, 1w
resumable: true     # Whether the loop supports mid-run checkpointing

goal: |
  What the loop is trying to accomplish in plain language.

allowlist:          # Explicit list of permitted actions
  - comment
  - label

deny:               # Explicit list of forbidden actions
  - merge
  - close
  - push
  - approve
  - force-push

# Optional. Default ON: hard gate prepends AI disclosure to comments/reviews.
# attribution: false
# attribution:
#   enabled: true
#   template: "> 🤖 AI-assisted message posted as `@{login}` by [agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit){loop_suffix}."

exit_conditions:
  - goal_met
  - budget_exhausted
  - human_escalation

budget:
  max_tokens: 50000        # Per-run token ceiling
  max_runs_per_day: 1      # Rate limit
  max_wall_seconds: 600    # Per-run time limit

verifier: null      # Optional: name of agent to verify output

request: |
  The prompt template executed by the loop runner.
  This is the full instruction set for the AI.
```

---

## Comment attribution (default ON)

When a loop posts a GitHub comment or review body via `gh`, `loop-gh-gate` prepends a disclosure if it is missing:

```markdown
> 🤖 AI-assisted message posted as `@your-login` by [agent-toolkit](https://github.com/ulises-jeremias/agent-toolkit) (`loop-name`).
```

- **Default:** enabled for every loop run (no config required).
- **Login:** resolved from the authenticated `gh` token (`gh api user`).
- **Idempotent:** bodies that already start with `> 🤖 AI-assisted` are left unchanged.
- **Disable per loop:**

```yaml
attribution: false
# or
attribution:
  enabled: false
```

Supported injection surfaces (v1): `--body` / `-b`, `--body-file`, and `-f`/`-F body=` on comment/review commands classified as `comment` by the hard gate.

---

## The L1 / L2 / L3 Tier System

Tiers describe the **mutation/risk** level of a loop's actions (not schedule cadence). Cadence is independent of tier. The tier determines what a loop is allowed to do and how much human oversight is required.

### L1 — Observe and Report

L1 loops are read-only or proposal-only. They gather information, analyze it, and write a report. They never mutate repository state. They are safe to run frequently and are the recommended starting point when evaluating a new loop.

Typical L1 actions: read issues, read PRs, read CI status, write report.md, propose labels (without applying them).

Token budgets: 20,000 – 150,000 per run.

### L2 — Controlled Mutations

L2 loops can make changes, but only within a tightly scoped allowlist. Common L2 actions include applying labels, posting comments, opening draft PRs, and branch housekeeping — but **`loop-gh-gate` forbids merge and close at L2**. Every L2 loop has an explicit deny list that prevents high-risk actions (force-push, approve, push to main).

L2 loops typically require human review of their report before the next run. They are suitable for daily automation once the L1 equivalent has been running reliably.

Token budgets: 50,000 – 300,000 per run.

### L3 — High-Autonomy (merge/close allowlisted)

L3 is required when a loop's allowlist includes **merge** or **close** — for example `oss-pr-monitor`, which auto-merges Dependabot PRs with passing CI. Beyond that gate difference, L3 follows the same allowlist/deny discipline as L2. Promote a loop to L3 only after stable L2 (or L1) runs and explicit operator approval.

In practice, most teams run all loops at L1 or L2. Reserve L3 for proven, tightly scoped automation.

---

## All 10 Loop Templates

### changelog-drafter

**Tier:** L1 | **Cadence:** daily | **Max tokens:** 20,000 | **[README](../loops/changelog-drafter/README.md)**

Collects all PRs merged since the last git tag and drafts a release notes entry in keep-a-changelog format. Writes to `report.md` only. Never commits, pushes, or tags. Useful for maintaining a changelog without manual effort.

Allowlist: none (read-only). Deny: merge, push, commit, tag.

---

### ci-sweeper

**Tier:** L2 | **Cadence:** every 15 minutes | **Max tokens:** 100,000 per run, 48 runs/day max | **[README](../loops/ci-sweeper/README.md)**

Monitors failing CI runs on open PRs and the main branch. For straightforward failures (less than 20 lines, no design impact), opens a draft PR with a minimal fix. For complex failures, posts a diagnosis comment only. Caps at 2 draft PRs per run to avoid spam.

This loop is expensive. Run `daily-triage` first to understand your failure patterns before enabling ci-sweeper.

Allowlist: comment, create_draft_pr. Deny: merge, approve, close, force-push, delete-branch.

---

### daily-triage

**Tier:** L1 | **Cadence:** daily | **Max tokens:** 30,000 | **[README](../loops/daily-triage/README.md)**

Reviews all open issues created in the last 24 hours. Proposes labels and priority scores. Does not apply anything — writes a report only. The lowest-cost loop for staying on top of a single repo.

Allowlist: none (report-only). Deny: merge, close, label, comment, push.

---

### dep-sweeper

**Tier:** L2 | **Cadence:** daily | **Max tokens:** 50,000 | **[README](../loops/dep-sweeper/README.md)**

Detects available patch-level dependency updates across npm, pip, cargo, and other ecosystems. Groups updates by ecosystem. For each ecosystem with patch updates, creates a worktree, applies the updates, runs the test suite, and opens a draft PR if tests pass. Never bumps major or minor versions.

Allowlist: create_draft_pr, comment. Deny: merge, approve, major-version-bump, minor-version-bump.

---

### issue-triage

**Tier:** L1 | **Cadence:** every 4 hours | **Max tokens:** 25,000 per run, 6 runs/day | **[README](../loops/issue-triage/README.md)**

Finds open issues with no labels and proposes label assignments and triage routing. Flags security issues immediately for human escalation. Writes proposals to `report.md`. Does not apply labels directly.

Allowlist: none (propose-only). Deny: label, comment, close, merge.

---

### oss-daily-briefing

**Tier:** L1 | **Cadence:** daily | **Max tokens:** 80,000 | **[README](../loops/oss-daily-briefing/README.md)**

Produces a daily read-only briefing across all repos in the configured OSS ecosystem. Covers new PRs in the last 24 hours, issues needing attention, and CI health on main. Supports resumability via `STATE.md` checkpointing. No mutations of any kind.

Allowlist: none. Deny: comment, label, assign, merge, close, push, approve, force-push.

See the [OSS Maintenance Patterns](#oss-maintenance-patterns) section below for sizing guidance.

---

### oss-pr-monitor

**Tier:** L3 | **Cadence:** daily | **Max tokens:** 300,000 | **[README](../loops/oss-pr-monitor/README.md)**

The most powerful loop in the toolkit. Monitors all open PRs across every configured OSS repo. Merges Dependabot PRs with passing CI, closes dirty Dependabot PRs (they regenerate automatically), and reports on human PRs with CI failures or conflicts. Never merges or closes human PRs. Requires **L3** because `loop-gh-gate` forbids merge/close at L2.

Supports resumability via `STATE.md` checkpointing — if interrupted mid-run, it resumes from the last processed repo on the next execution.

Allowlist: merge, close, comment, label. Deny: approve, force-push, push-to-main, delete-branch.

See the [OSS Maintenance Patterns](#oss-maintenance-patterns) section below for sizing guidance.

---

### oss-triage

**Tier:** L1 | **Cadence:** daily | **Max tokens:** 150,000 | **[README](../loops/oss-triage/README.md)**

Scans open issues across all configured OSS repos. Applies labels, responds to questions where the right answer is obvious, asks for minimal reproducers on bug reports, and escalates security reports. Supports resumability. Uses roughly half the budget of `oss-pr-monitor`.

Allowlist: label, comment, assign. Deny: merge, close, push, approve, force-push.

See the [OSS Maintenance Patterns](#oss-maintenance-patterns) section below for sizing guidance.

---

### post-merge-cleanup

**Tier:** L2 | **Cadence:** every 6 hours | **Max tokens:** 20,000 per run, 4 runs/day | **[README](../loops/post-merge-cleanup/README.md)**

Off-peak housekeeping after merges. Deletes branches that have been merged into main for more than 7 days (skips main, develop, release/*). Closes issues that were closed by merged PRs but not yet marked closed. Posts stale comments on issues with no activity in 90+ days (does not close them). Skips any action it is uncertain about.

Allowlist: delete_merged_branch, close_stale_issue, comment. Deny: merge, approve, delete-unmerged-branch, close-active-issue.

---

### pr-babysitter

**Tier:** L2 | **Cadence:** every 15 minutes | **Max tokens:** 80,000 per run, 96 runs/day | **[README](../loops/pr-babysitter/README.md)**

Reviews open PRs that have not received a review in the last hour. Posts a constructive review comment with a summary and 1–3 specific suggestions. Never approves, requests changes, merges, or closes. Escalates on security issues.

This loop is expensive at high frequency. Use with caution on busy repos.

Allowlist: comment. Deny: merge, approve, close, push, label.

---

## OSS Maintenance Patterns

The three OSS loops (`oss-pr-monitor`, `oss-triage`, `oss-daily-briefing`) are designed to work together for maintainers of multi-repo OSS ecosystems. This section covers the patterns and constraints that matter at scale.

### Budget Sizing for Large Ecosystems

Token consumption scales linearly with repo count. The budgets in the loop templates are calibrated for ecosystems of 20–50 repos.

| Loop | Repos | Estimated tokens/run |
|------|-------|----------------------|
| `oss-daily-briefing` | 10 | ~20,000 |
| `oss-daily-briefing` | 40 | ~80,000 |
| `oss-triage` | 10 | ~40,000 |
| `oss-triage` | 40 | ~150,000 |
| `oss-pr-monitor` | 10 | ~80,000 |
| `oss-pr-monitor` | 40 | ~300,000 |

If your ecosystem has more than 50 repos, consider splitting it into two packs and running separate loop instances for each half.

### Resumability and Checkpointing

All three OSS loops set `resumable: true` and use a `STATE.md` file to checkpoint progress. This is critical because a 40-repo scan that runs out of budget or is interrupted mid-run should not restart from scratch.

How it works:

1. At the start of each run, the loop reads `loops/<name>/STATE.md`.
2. If `last_processed_repo` is set, it skips all repos before that name in the configured list.
3. After processing each repo, it writes `last_processed_repo: <owner>/<repo>` to `STATE.md`.
4. On successful completion, it clears `last_processed_repo` and sets `last_run_status: success`.

Example `STATE.md` after a partial run:

```markdown
last_processed_repo: owner/repo-17
last_run: 2026-08-04T09:23:11Z
last_run_status: partial (budget_exhausted)
```

On the next scheduled run, the loop picks up at `owner/repo-18` and continues.

Do not manually edit `STATE.md` during a run. Between runs, you can safely reset it by clearing `last_processed_repo` to force a full re-scan.

### When to Use Each Loop

| Loop | Use when |
|------|----------|
| `oss-daily-briefing` | You want a daily summary with no risk. Always start here. |
| `oss-triage` | Briefing is running well and you want to auto-label and respond to questions. |
| `oss-pr-monitor` | Triage is running well and you want to auto-merge Dependabot PRs. |

Run briefing for a week before enabling triage. Run triage for a week before enabling pr-monitor. This gives you confidence in the loop's behavior before enabling mutations.

---

## Creating a New Loop

1. Create a directory: `loops/<your-loop-name>/`
2. Write `loop.yaml` using the structure above
3. Choose a tier (start with L1 if uncertain)
4. Set a conservative budget (`max_tokens: 30000` is a good starting point)
5. List every permitted action in `allowlist` and every forbidden action in `deny`
6. Write a `request` prompt that references `STATE.md` for resumability if the loop scans multiple items
7. Test with a single repo before expanding to your full ecosystem

### Loop Checklist

Before deploying a new loop:

- [ ] `tier` is set (L1, L2, or L3)
- [ ] `allowlist` and `deny` are both present and non-overlapping
- [ ] `budget.max_tokens` is set
- [ ] `exit_conditions` includes `budget_exhausted` and `human_escalation`
- [ ] `request` instructs the AI to write a report
- [ ] If `resumable: true`, the `request` references `STATE.md` checkpointing
- [ ] No secrets or hardcoded tokens in `loop.yaml`

---

## Loop YAML Spec Reference

```yaml
# Required fields
name: string                     # kebab-case loop identifier
description: string              # Short description (include tier and cadence)
tier: L1 | L2 | L3              # Risk tier
cadence: string                  # e.g. 15m, 4h, 1d, 1w
goal: string (multiline)         # What the loop is trying to accomplish

allowlist:                       # Permitted actions (empty list = read-only)
  - string

deny:                            # Explicitly forbidden actions
  - string

exit_conditions:                 # When the loop stops
  - goal_met
  - budget_exhausted
  - human_escalation
  - max_iterations               # Optional

budget:
  max_tokens: integer            # Per-run token ceiling
  max_runs_per_day: integer      # Rate limit
  max_wall_seconds: integer      # Per-run time limit in seconds
  max_iterations: integer        # Optional: cap on tool-call iterations

request: string (multiline)     # The prompt template executed by the loop runner

# Optional fields
resumable: boolean               # Default: false
verifier: string | null          # Agent name to verify output (e.g. code-reviewer)
attribution: boolean | object    # Default: true; false disables AI comment disclosure
```

---

## Remote Execution (GitHub Actions)

Local `loop schedule` uses `systemd`/`launchd` and stops when the laptop sleeps. For production, run loops remotely:

```bash
# Preview
agent-toolkit loop schedule oss-triage --platform github-actions --dry-run

# Emit workflow
agent-toolkit loop schedule oss-triage --platform github-actions
# → writes .github/workflows/agent-toolkit-oss-triage.yml

# Check drift (CI-friendly)
agent-toolkit loop sync --platform github-actions
agent-toolkit loop sync --platform github-actions --dry-run  # exits 1 on drift

# Force overwrite
agent-toolkit loop schedule oss-triage --platform github-actions --force
```

**How it works:**
- `cadence` → cron: `15m`→`*/15 * * * *`, `4h`→`0 */4 * * *`, `1d`→`0 0 * * *`, `1w`→`0 0 * * 0`
- Workflow is version-pinned: `uvx --from agent-toolkit-cli==1.18.0`
- Permissions: `contents:write`, `pull-requests:write`, `issues:write`; `GITHUB_TOKEN` is auto-provided
- Concurrency: `group: agent-toolkit-<name>` prevents overlapping runs
- `STATE.md` is not persisted on ephemeral runners (remote is not resumable in v1.19.0) — daily cadence is fine; large `oss-*` at scale stays local until cache design lands
- Secrets: add `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` as repo secrets if the loop's `request` uses LLM; never committed

See `examples/remote-loops/` for a sanitized workflow.
