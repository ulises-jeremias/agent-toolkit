---
name: gh-contribution-planner
description: Daily GitHub contribution planner — analyzes the gh-logged-in user's non-archived repos (owned + forks) and recent contributions, produces a prioritized plan, halts for approval, then dispatches parallel sub-agents to execute approved items via existing PR/CI/review skills.
---

# GitHub Contribution Planner

Discover what to work on across **your** GitHub footprint, propose a prioritized
daily plan, and — on approval — fan out parallel sub-agents to open draft PRs.
The skill infers the current user from the authenticated `gh` CLI, so no
manual configuration is required.

## When to use

- "Plan my GitHub contributions for today" / "what should I work on across my
  repos" / "give me a daily contribution plan".
- You want to maintain your own repositories and forks without manually
  scanning each one.
- You want to find low-friction openings (good first issues, stale PRs,
  outdated forks) in projects you have already contributed to.

Do **not** use this skill to operate on a specific PR you already picked — use
`gh-fix-ci`, `gh-address-comments`, or `github-cli-workflow` directly.

## Prerequisites

- `gh` installed and authenticated (`gh auth status` exits 0). Scopes
  typically required: `repo`, `read:org`. `dots-doctor` reports this under
  Integrations.
- `python3` for the bundled analyzer.
- Network access to `api.github.com` (or the host configured via `GH_HOST`).
- A host that supports parallel sub-agent dispatch (Claude Code's `Task` tool,
  OpenCode's subagent fan-out, etc.). Hosts without that primitive fall back
  to sequential execution.

## Workflow

1. **Verify auth.** Run `gh auth status`. If unauthenticated, ask the user to
   run `gh auth login` and stop. Do not prompt for tokens.

2. **Resolve the current user.** `gh api user --jq .login` — never ask the
   user; always infer from `gh`.

3. **Run the analyzer.**

   ```bash
   python3 ~/.local/share/agent-toolkit/skills/gh-contribution-planner/scripts/inspect_contributions.py \
     --since 90d --max-per-bucket 5
   ```

   Useful flags:

   - `--json` — machine-readable output (recommended when composing with
     another agent).
   - `--user <login>` — override the inferred login (useful for testing or
     planning for an organization the user maintains).
   - `--dry-run` — print the `gh` calls the analyzer would make and exit;
     useful for sanity-checking before a live run.
   - `--max-per-bucket <n>` — cap items per bucket (default 5).
   - `--since <window>` — lookback window for recent contributions. Accepts
     `30d`, `90d`, `180d`, or an ISO date.

   The script:

   - Calls `gh api user` to resolve the login.
   - Calls `gh api graphql` to batch-fetch viewer repos (non-archived,
     forks + sources), open PRs authored by the user, and recent
     contributions across GitHub.
   - For each fork, compares the default branch with the parent's default
     branch to compute `behind/ahead` counts.
   - For each owned repo, fetches open issues labeled `good first issue` or
     `help wanted`, plus unassigned issues older than the lookback window.
   - Scores and buckets every item.

4. **Present the plan in English** grouped into these buckets (each item must
   show repo `owner/name`, a one-line summary, an effort estimate, and a
   suggested delegate skill):

   - **Quick wins (~15 min)** — README/typo/doc fixes, dependency bumps,
     missing CI badges in your own repos.
   - **In-flight PRs** — open PRs authored by you that need attention
     (red CI → `gh-fix-ci`; rebase needed → `github-cli-workflow`).
   - **Review feedback** — PRs with unresolved review comments → delegate to
     `gh-address-comments`.
   - **Forks needing sync** — forks lagging upstream by ≥ N commits; propose a
     sync via `gh repo sync` or a merge-from-upstream PR.
   - **Maintenance** — own non-archived repos with stale unanswered issues,
     security alerts, or abandoned PRs from contributors awaiting your review.
   - **External contributions** — repos where you contributed in the lookback
     window with open `good first issue` / `help wanted` issues that are
     currently unassigned.

5. **Halt for approval.** Ask the user which buckets and which specific items
   to execute. Do **not** open PRs or push commits before approval.

6. **Dispatch parallel sub-agents** for the approved items. One sub-agent per
   item, capped at **5 concurrent** by default. Each sub-agent receives:

   - Target `owner/name` and (when relevant) issue / PR number.
   - A one-line goal extracted from the plan.
   - A directive to start with `dev-assistant` for repo discovery, then route
     to the right execution skill:
     - PR push / draft PR creation → `github-cli-workflow`.
     - Red CI on an existing PR → `gh-fix-ci`.
     - Open review comments → `gh-address-comments`.
     - Fork drift → `gh repo sync` (delegate the sync step; never force).
   - An explicit instruction to open the PR as **draft** unless the user
     marks the item as ready-for-review in the approval step.

   On hosts without parallel sub-agent dispatch, execute items sequentially in
   the same order and report progress between items.

7. **Aggregate the run.** When the parallel batch completes, summarize:
   - Draft PRs opened (`owner/repo#NN` + URL).
   - Items skipped or blocked (with reason).
   - Follow-ups that need the user's direct attention.

## Parallel execution contract

- **Concurrency cap:** 5 sub-agents at a time. Raise only on explicit user
  request.
- **Isolation:** each sub-agent works in its own git worktree or a fresh clone
  under `~/.cache/agent-toolkit/contribution-planner/<owner>-<repo>/`. Never reuse
  the host repo working tree.
- **Idempotency:** before opening a new PR, the sub-agent must check for an
  existing open PR with the same intent (label or title heuristic) and skip
  duplicates.
- **Drafts by default:** every PR is opened as draft. The user marks ready
  separately.
- **No force pushes** to branches that already exist on `origin` unless the
  user explicitly opts in.

## Boundaries

- Read-only on GitHub during planning; writes only after explicit user
  approval, and only on approved items.
- Do not author commits or PRs from this skill directly — delegate every push
  to `github-cli-workflow`.
- Do not act on repos owned by other users beyond the **external
  contributions** bucket, and even there only via PRs (never direct pushes).
- Do not interact with non-GitHub forges; for GitLab, route to
  `gitlab-cli-workflow` instead.

## Bundled resources

- `scripts/inspect_contributions.py` — stdlib-only analyzer. Defaults to
  Markdown output; `--json` for machine-readable output.

## Validation

- `dots-skills check` reports the `gh` and `python3` requirements.
- `dots-doctor` shows `gh auth status` under Integrations.
- Smoke test:

  ```bash
  python3 ~/.local/share/agent-toolkit/skills/gh-contribution-planner/scripts/inspect_contributions.py --dry-run
  ```
