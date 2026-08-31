---
name: gh-fix-ci
description: Diagnose failing GitHub Actions checks on a PR via gh, summarize the failure context, propose
  a plan, and only implement after explicit user approval. External CI providers (Buildkite, CircleCI,
  etc.) are reported by URL only.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: cursor-team-kit/skills/fix-ci
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Iterative fix-one-failure-at-a-time loop, gh pr checks as source of truth, minimal safe fixes
---
# Fix Failing PR Checks

Inspect failing GitHub Actions checks on a PR with `gh`, fetch run logs, extract
a focused failure snippet, propose a fix plan before making any change, and iterate
until green.

## When to use

- A PR has red checks and the user asks to "fix CI", "debug the failing job",
  or "why is the build red".
- You need a fast triage of which jobs failed and the relevant log slice.
- Branch or PR CI is failing and needs a fast, iterative path to green checks.

## Prerequisites

- `gh` installed and authenticated (`gh auth status` exits 0).
  `doctor` reports this under Integrations.
- `python3` for the bundled analyzer.
- The current directory is inside the target Git repository (or pass `--repo`).

## Workflow

1. **Verify auth.** `gh auth status`. If unauthenticated, ask the user to run
   `gh auth login` (repo + workflow scopes typically required).
2. **Resolve the PR.** Defaults to the current branch's PR, or pass `--pr`.
3. **Inspect checks as source of truth.** Use `gh pr checks` as the source of
   truth for overall PR CI state (it includes all PR-attached checks, while
   `gh run list` only covers GitHub Actions):

   ```bash
   gh pr checks --json name,bucket,state,workflow,link
   ```

   For pending checks, `gh pr checks --watch --fail-fast`.
4. **Run the analyzer:**

   ```bash
   python3 ~/.local/share/agent-toolkit/skills/gh-fix-ci/scripts/inspect_pr_checks.py \
     --repo . --pr <number-or-url>
   ```

   - Add `--json` for machine-friendly output suitable for further processing.
   - Add `--max-lines <n>` / `--context <n>` to widen the snippet window.

   The script handles `gh pr checks` field drift, falls back to job-level logs
   when run-level logs are not yet available, and exits non-zero when failures
   remain (so it composes in CI / scripts).
5. **Scope external providers.** Any check whose `detailsUrl` is not a GitHub
   Actions run is reported as `external` with only the URL — do not attempt to
   fetch logs from Buildkite/CircleCI/etc. Use the check link to identify the
   failing command or service when logs are unavailable.
6. **Summarize.** For each failing check report: name, run URL, conclusion,
   workflow, branch/SHA, and the failure snippet (or "logs pending" if the run
   is still in progress). Identify the primary failing job and root error.
7. **Draft a plan.** Propose the fix as a short, numbered plan. **Do not edit
   files yet.** If the project has a planning skill (e.g. `planning`),
   delegate the plan structure to it.
8. **Implement after approval — one failure at a time.** Once the user approves
   the plan, apply the smallest safe fix. Prefer minimal, low-risk changes
   before broader refactors. Summarize the diff and delegate the push/PR-update
   step to `github-cli-workflow`.
9. **Recheck and iterate until green.** Re-run `gh pr checks` after each push;
   the check set can change. If checks already failed, diagnose those first; if
   pending, watch with `--watch --fail-fast`. Repeat steps 4-8 for the next
   actionable failure until all required checks are green. Suggest re-running
   relevant tests locally between iterations.

## Boundaries

- Read-only on CI; **never** rerun jobs or cancel workflows from this skill.
- Do not push commits — delegate to `github-cli-workflow`.
- Do not implement before explicit user approval of the plan.
- Fix one actionable failure at a time.
- If the failure is clearly unrelated to the PR and appears fixed on main, merge latest main instead of bloating the PR with unrelated fixes.

## Bundled resources

- `scripts/inspect_pr_checks.py` — failure analyzer (stdlib only). Returns text
  by default; `--json` for machine-readable output.

## Output

- Primary failing job and root error
- Fixes applied in iteration order
- Current CI status and next action

## Validation

- `skills check` reports the `gh` and `python3` requirements.
- `doctor` shows `gh auth status` under Integrations.
