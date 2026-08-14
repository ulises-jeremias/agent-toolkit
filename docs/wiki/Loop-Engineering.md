# Loop Engineering

Loops are recurring agentic workflows. They run on a cadence, observe or act on repositories,
and stop when their goal is met, their budget is exhausted, or a human escalation is required.
Every loop ships with explicit safety gates so there are no surprise mutations.

---

## Philosophy: Why Loops Over One-Shot Prompts

A one-shot prompt asks an AI to do something once. A loop asks an AI to keep doing something,
with memory of what it has already done, until a condition is met.

The key differences:

| | One-shot prompt | Loop |
|---|---|---|
| **State** | None — starts fresh every time | `STATE.md` checkpointing across runs |
| **Budget** | Unbounded — runs until done | Explicit `max_tokens` ceiling per run |
| **Safety gates** | None by default | Explicit `allowlist` and `deny` list |
| **Cadence** | Manual trigger | Scheduled (systemd, launchd, or cron) |
| **Exit conditions** | Done when the AI says so | `goal_met`, `budget_exhausted`, `human_escalation` |

Loops are appropriate when:

- The task recurs on a schedule (daily triage, weekly briefing)
- The task is too large to complete in a single run (scanning 40 repos)
- You want auditability — every run writes a `report.md` with what was done and why
- You want safety — explicit allow/deny lists prevent accidental mutations

One-shot prompts are better for ad hoc, one-time tasks where state and cadence do not matter.

---

## Loop Directory Structure

A loop is a directory under `loops/<name>/` containing at minimum a `loop.yaml` file:

```text
loops/oss-pr-monitor/
├── loop.yaml     # Required: loop definition
├── STATE.md      # Runtime: checkpoint state (written by loop runner)
└── report.md     # Runtime: output report (written by the AI)
```

`STATE.md` and `report.md` are runtime artifacts generated on each run. Do not commit them —
add them to `.gitignore` or the loop's own local `.gitignore`.

---

## Full loop.yaml Spec

```yaml
# Required fields
name: string                     # kebab-case loop identifier. Pattern: ^[a-z0-9]+(-[a-z0-9]+)*$
goal: string (multiline)         # Declarative success condition. The loop stops when this is achieved.
request: string (multiline)      # Full prompt/instructions passed to the agent at each run.

# Highly recommended
description: string              # Short human-readable description (include tier and cadence)
tier: L1 | L2 | L3              # Risk tier (see tier system below)
cadence: string                  # e.g. 15m, 4h, 1d, 1w. Pattern: ^\d+[mhd]$

allowlist:                       # Permitted mutation actions. Empty = read-only (L1 typical).
  - string                       # e.g. comment, label, merge, create_draft_pr

deny:                            # Explicitly forbidden actions (must not overlap with allowlist)
  - string                       # e.g. merge, approve, force-push, push-to-main

exit_conditions:                 # When the loop terminates normally
  - goal_met                     # The declared goal was accomplished
  - budget_exhausted             # max_tokens or max_wall_seconds reached
  - human_escalation             # Agent flagged an issue requiring human review
  - max_iterations               # Optional: agent hit the iteration cap
  - no_work_found                # Optional: nothing to process this run
  - error                        # Optional: unrecoverable error occurred

budget:
  max_tokens: integer            # Per-run token ceiling (min: 1000, max: 2,000,000)
  max_runs_per_day: integer      # Rate limit (min: 1, max: 1440)
  max_wall_seconds: integer      # Per-run time limit in seconds (min: 30, max: 86400)
  max_iterations: integer        # Optional: cap on tool-call iterations per run (max: 500)

# Optional
resumable: boolean               # Default: false. Set true to enable STATE.md checkpointing.
verifier: string | null          # Agent name to run as post-run quality gate (e.g. code-reviewer)
```

The schema is enforced by `schemas/loop.schema.json`. Run `v run scripts/validate-manifests.vsh`
to validate all loop manifests.

---

## The L1 / L2 / L3 Tier System

Tiers declare the risk level and required human oversight for a loop.

### L1 — Observe and Report

L1 loops are read-only or proposal-only. They gather information, analyze it, and write a report.
They never mutate repository state.

- `allowlist` is empty (or contains only `report`)
- `deny` lists all mutation actions
- Safe to run frequently — even every 15 minutes
- **Recommended starting tier for all new loops**

Token budgets: 20,000 – 150,000 per run.

### L2 — Controlled Mutations

L2 loops can make changes within a tightly scoped `allowlist`. Common L2 actions: apply labels, post comments, open draft PRs, branch housekeeping.

- **`loop-gh-gate` forbids merge and close at L2** regardless of allowlist
- Every L2 loop has an explicit `deny` list that prevents high-risk actions
- Prerequisite: the equivalent L1 loop has run reliably for at least 3 clean runs
- Human should review the `report.md` after each run

Token budgets: 50,000 – 300,000 per run.

### L3 — High-Autonomy (merge/close allowlisted)

L3 is required when a loop's allowlist includes **merge** or **close** — for example `oss-pr-monitor`, which auto-merges Dependabot PRs with passing CI. Beyond that gate difference, L3 follows the same allowlist/deny discipline as L2. Promote a loop to L3 only after stable L1/L2 runs and explicit operator approval.

In practice, most teams run all loops at L1 or L2. Reserve L3 for proven, tightly scoped automation.

**Graduation sequence:** L1 (3+ clean runs) → L2 (stable controlled mutations) → L3 (only when merge/close are required)

---

## All 10 Loop Templates

### changelog-drafter

| Attribute | Value |
|-----------|-------|
| **Tier** | L1 |
| **Cadence** | daily |
| **Max tokens** | 20,000 |
| **Resumable** | No |

Collects all PRs merged since the last git tag and drafts a release notes entry in
keep-a-changelog format. Writes to `report.md` only. Never commits, pushes, or tags.

```yaml
allowlist: []
deny: [merge, push, commit, tag]
```

**When to use:** Maintaining a changelog without manual effort. Run after each release cycle.

---

### ci-sweeper

| Attribute | Value |
|-----------|-------|
| **Tier** | L2 |
| **Cadence** | every 15 minutes |
| **Max tokens** | 100,000 per run |
| **Max runs/day** | 48 |
| **Resumable** | No |

Monitors failing CI runs on open PRs and the main branch. For straightforward failures (fewer
than 20 lines changed, no design impact), opens a draft PR with a minimal fix. For complex
failures, posts a diagnosis comment only. Caps at 2 draft PRs per run to avoid spam.

```yaml
allowlist: [comment, create_draft_pr]
deny: [merge, approve, close, force-push, delete-branch]
```

**Warning:** This loop is expensive at high frequency. Run `daily-triage` first to understand
your failure patterns before enabling `ci-sweeper`.

---

### daily-triage

| Attribute | Value |
|-----------|-------|
| **Tier** | L1 |
| **Cadence** | daily |
| **Max tokens** | 30,000 |
| **Resumable** | No |

Reviews all open issues created in the last 24 hours. Proposes labels and priority scores.
Does not apply anything — writes a report only. The lowest-cost loop for staying on top of a
single repo.

```yaml
allowlist: []
deny: [merge, close, label, comment, push]
```

**Recommended starting point** for any new repo or team new to loops.

---

### dep-sweeper

| Attribute | Value |
|-----------|-------|
| **Tier** | L2 |
| **Cadence** | daily |
| **Max tokens** | 50,000 |
| **Resumable** | No |

Detects available patch-level dependency updates across npm, pip, cargo, and other ecosystems.
For each ecosystem with patch updates, creates a worktree, applies the updates, runs the test
suite, and opens a draft PR if tests pass. Never bumps major or minor versions.

```yaml
allowlist: [create_draft_pr, comment]
deny: [merge, approve, major-version-bump, minor-version-bump]
```

---

### issue-triage

| Attribute | Value |
|-----------|-------|
| **Tier** | L1 |
| **Cadence** | every 4 hours |
| **Max tokens** | 25,000 per run |
| **Max runs/day** | 6 |
| **Resumable** | No |

Finds open issues with no labels and proposes label assignments and triage routing. Flags security
issues immediately for human escalation. Writes proposals to `report.md` — does not apply labels.

```yaml
allowlist: []
deny: [label, comment, close, merge]
```

---

### oss-daily-briefing

| Attribute | Value |
|-----------|-------|
| **Tier** | L1 |
| **Cadence** | daily |
| **Max tokens** | 80,000 |
| **Resumable** | Yes |

Produces a daily read-only briefing across all repos in the configured OSS ecosystem. Covers new
PRs in the last 24 hours, issues needing attention, and CI health on main. Supports resumability
via `STATE.md` checkpointing. No mutations of any kind.

```yaml
allowlist: []
deny: [comment, label, assign, merge, close, push, approve, force-push]
```

**Start here** when setting up OSS maintenance. Run for a full week before enabling `oss-triage`.

---

### oss-pr-monitor

| Attribute | Value |
|-----------|-------|
| **Tier** | L3 |
| **Cadence** | daily |
| **Max tokens** | 300,000 |
| **Resumable** | Yes |
| **Verifier** | `agent-toolkit-code-reviewer` |

The most powerful loop in the toolkit. Monitors all open PRs across every configured OSS repo.
Merges Dependabot PRs with passing CI, closes dirty Dependabot PRs (they regenerate automatically),
and reports on human PRs with CI failures or conflicts. Never merges or closes human PRs.

```yaml
allowlist: [merge, close, comment, label]
deny: [approve, force-push, push-to-main, delete-branch]
```

**Style rules enforced in the request:**

- Never @mention anyone. Never leave AI-looking comments.
- If the right action is obvious, do it silently.
- If not obvious, skip and note in report.

**Prerequisite:** Run `oss-triage` for at least one week before enabling `oss-pr-monitor`.

---

### oss-triage

| Attribute | Value |
|-----------|-------|
| **Tier** | L1 |
| **Cadence** | daily |
| **Max tokens** | 150,000 |
| **Resumable** | Yes |

Scans open issues across all configured OSS repos. Applies labels, responds to obvious questions,
asks for minimal reproducers on bug reports, and escalates security reports. Supports resumability.

```yaml
allowlist: [label, comment, assign]
deny: [merge, close, push, approve, force-push]
```

**Prerequisite:** Run `oss-daily-briefing` for at least one week before enabling `oss-triage`.

---

### post-merge-cleanup

| Attribute | Value |
|-----------|-------|
| **Tier** | L2 |
| **Cadence** | every 6 hours |
| **Max tokens** | 20,000 per run |
| **Max runs/day** | 4 |
| **Resumable** | No |

Off-peak housekeeping after merges. Deletes branches merged into main for more than 7 days (skips
main, develop, release/*). Closes issues closed by merged PRs but not yet marked closed. Posts
stale comments on issues with 90+ days of inactivity (does not close them). Skips any action it
is uncertain about.

```yaml
allowlist: [delete_merged_branch, close_stale_issue, comment]
deny: [merge, approve, delete-unmerged-branch, close-active-issue]
```

---

### pr-babysitter

| Attribute | Value |
|-----------|-------|
| **Tier** | L2 |
| **Cadence** | every 15 minutes |
| **Max tokens** | 80,000 per run |
| **Max runs/day** | 96 |
| **Resumable** | No |

Reviews open PRs that have not received a review in the last hour. Posts a constructive review
comment with a summary and 1–3 specific suggestions. Never approves, requests changes, merges, or
closes. Escalates on security issues.

```yaml
allowlist: [comment]
deny: [merge, approve, close, push, label]
```

**Warning:** This loop is expensive at high frequency. Use with caution on busy repos.

---

## Resumability: How STATE.md Checkpointing Works

Loops that process a list of items (repos, issues, PRs) set `resumable: true` and write a
`STATE.md` checkpoint after each item. This ensures that if a run hits the budget ceiling or is
interrupted, the next run picks up where it left off rather than restarting from scratch.

### How it works in practice

1. At the start of each run, the loop reads `loops/<name>/STATE.md`.
2. If `last_processed_repo` is set, the loop skips all repos before that name in the configured
   list.
3. After processing each repo, the loop writes the checkpoint to `STATE.md`.
4. On successful completion, it clears `last_processed_repo` and sets `last_run_status: success`.

**Example STATE.md after a partial run:**

```markdown
last_processed_repo: owner/repo-17
last_run: 2026-08-04T09:23:11Z
last_run_status: partial (budget_exhausted)
```

On the next scheduled run, the loop picks up at `owner/repo-18` and continues.

**Rules:**

- Do not manually edit `STATE.md` during a run.
- Between runs, you can safely reset it by clearing `last_processed_repo` to force a full re-scan.
- `STATE.md` and `report.md` should be in `.gitignore` — they are runtime artifacts, not source files.

### Request prompt pattern for resumable loops

```yaml
request: |
  **Resumability (read first):**
  Read loops/<loop-name>/STATE.md if it exists.
  If `last_processed_repo` is set, skip all repos before that name in the list.
  After processing each repo, write to STATE.md:
    last_processed_repo: <owner>/<repo>
    last_run: <ISO-8601 timestamp>
    last_run_status: in_progress
  On successful completion, write:
    last_processed_repo: ""
    last_run: <ISO-8601 timestamp>
    last_run_status: success
```

---

## Budget Sizing

### Formula

```text
max_tokens = (tokens_per_repo × repo_count) × 1.3 safety_margin
```

### Typical token costs per repo

| Operation | Tokens (approximate) |
|-----------|---------------------|
| List open PRs (20 PRs) | ~800 |
| List open issues (50 issues) | ~2,000 |
| Read CI check-suite status | ~300 |
| Write one report entry | ~150 |
| Model reasoning overhead per repo | ~500 |

### Lookup table for OSS loops

| Repo count | oss-daily-briefing | oss-triage | oss-pr-monitor |
|------------|-------------------|------------|----------------|
| 5 repos | ~15,000 | ~25,000 | ~50,000 |
| 10 repos | ~25,000 | ~40,000 | ~80,000 |
| 20 repos | ~50,000 | ~80,000 | ~160,000 |
| 40 repos | ~80,000 | ~150,000 | ~300,000 |
| 60 repos | ~120,000 | ~225,000 | ~450,000 |

**If your ecosystem has more than 50 repos:** split it into two pack configs and run separate loop
instances for each half.

When in doubt, start lower. `budget_exhausted` is a normal exit condition — the agent checkpoints
its state and the next run picks up where it left off.

---

## Scheduling

### systemd (Linux)

Create a service and timer unit pair. Example for `oss-daily-briefing`:

**`~/.config/systemd/user/oss-briefing.service`:**

```ini
[Unit]
Description=OSS Daily Briefing Loop

[Service]
Type=oneshot
WorkingDirectory=%h/.ai-workspace
ExecStart=agent-toolkit loop run oss-daily-briefing --pack %h/.ai-workspace/packs/oss-maintenance.yaml
Environment=GITHUB_TOKEN=%h/.config/secrets/github_token
StandardOutput=journal
StandardError=journal
```

**`~/.config/systemd/user/oss-briefing.timer`:**

```ini
[Unit]
Description=Run OSS Daily Briefing at 8am

[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl --user daemon-reload
systemctl --user enable --now oss-briefing.timer
systemctl --user status oss-briefing.timer
```

Check logs:

```bash
journalctl --user -u oss-briefing.service -f
```

### launchd (macOS)

**`~/Library/LaunchAgents/com.agent-toolkit.oss-briefing.plist`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agent-toolkit.oss-briefing</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/agent-toolkit</string>
        <string>loop</string>
        <string>run</string>
        <string>oss-daily-briefing</string>
        <string>--pack</string>
        <string>/Users/you/.ai-workspace/packs/oss-maintenance.yaml</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>8</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>GITHUB_TOKEN</key>
        <string>ghp_your_token_here</string>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/oss-briefing.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/oss-briefing-err.log</string>
</dict>
</plist>
```

Load and start:

```bash
launchctl load ~/Library/LaunchAgents/com.agent-toolkit.oss-briefing.plist
launchctl start com.agent-toolkit.oss-briefing
```

---

## Runner Hierarchy

When a loop runs with `--runner auto` (default), the runner selects which AI engine to use
in this priority order:

1. **harness** — if `HARNESS_RUNNER_DIR` points at a `dots-ai-devcompanion` runner package
2. **claude** — Claude Code CLI (`claude` on `$PATH`)
3. **opencode** — OpenCode CLI (`opencode` on `$PATH`)
4. **cursor** — Cursor Agent CLI (`cursor-agent` / `agent` / `cursor`)
5. **copilot** — GitHub Copilot CLI (`copilot`)
6. **codex** — OpenAI Codex CLI (`codex`)
7. **queue** — async `devcompanion` job queue
8. **skeleton** — write `plan.md` only (no LLM)

Force a specific engine (no silent fallthrough if missing):

```bash
agent-toolkit loop run oss-daily-briefing --runner claude
agent-toolkit loop run oss-pr-monitor --runner cursor --force
AGENT_TOOLKIT_LOOP_RUNNER=codex agent-toolkit loop run ci-sweeper
```

See `agent-toolkit loop help` for the full flag list and auth/workspace environment variables
(`CURSOR_API_KEY`, `COPILOT_GITHUB_TOKEN`, `OPENAI_API_KEY` / `CODEX_API_KEY`, `HARNESS_RUNNER_DIR`, …).

### Locking the runner for client engagements

For client projects, verify the LLM policy before queuing background jobs:

```bash
export ANTHROPIC_API_KEY="<client key>"
export DOTS_AI_DEVCOMPANION_LLM_ALLOWLIST="anthropic"
export DOTS_AI_DEVCOMPANION_LLM_STRICT="1"
dots-devcompanion llm-status
```

If `llm-status` does not show the expected provider, fix the policy before running any loops.

---

## Cost Tracking

The `agent-toolkit loop audit` command (if configured) outputs a summary of token usage and
estimated cost across all loop runs in a time range:

```text
Loop Audit — last 7 days

Loop                   Runs   Total tokens   Est. cost (Sonnet)
─────────────────────  ─────  ─────────────  ──────────────────
oss-daily-briefing     7      420,000        $1.26
oss-triage             7      840,000        $2.52
oss-pr-monitor         7      1,680,000      $5.04

Total                  21     2,940,000      $8.82
```

Costs are estimates based on the Anthropic Sonnet pricing at the time of the audit. Actual costs
depend on your model selection and whether prompt caching is enabled.

---

## Creating a New Loop

See [Contributing](Contributing) for the full walkthrough, including graduated testing (L1 first),
the PR checklist, and a complete example.

Quick summary:

1. Create `loops/<loop-name>/`
2. Write `loop.yaml` with required fields (`name`, `goal`, `request`)
3. Choose tier L1 for all new loops
4. Set a conservative `max_tokens` budget
5. List every permitted action in `allowlist` and every forbidden action in `deny`
6. Set `resumable: true` if the loop processes 5+ items
7. Run validation: `v run scripts/validate-manifests.vsh`
8. Test with a single repo before expanding to your full ecosystem
