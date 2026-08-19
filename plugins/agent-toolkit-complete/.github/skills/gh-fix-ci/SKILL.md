---
name: gh-fix-ci
description: Diagnose failing GitHub Actions checks on a PR via gh, summarize the failure context, propose
  a plan, and only implement after explicit user approval. External CI providers (Buildkite, CircleCI,
  etc.) are reported by URL only. Use when branch or PR CI is red, checks fail after push, or the user
  asks to fix CI, debug a failing job, or triage GitHub Actions logs.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: cursor-team-kit/skills/fix-ci
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: CI log triage patterns — one failure at a time, gh pr checks as source of truth, iterative recheck loop
---
# Fix Failing PR Checks

Inspect failing GitHub Actions checks on a PR with `gh`, fetch run logs, extract
a focused failure snippet, and propose a fix plan before making any change.

## When to use

- A PR has red checks and the user asks to "fix CI", "debug the failing job",
  "why is the build red", or "get checks green".
- Branch CI failed after a push and you need a fast triage of which jobs failed.
- You need the first actionable error from GitHub Actions logs (or an external check URL).
- Iterative fix-and-recheck: apply a minimal fix, push, and re-run `gh pr checks`.

## Prerequisites

- `gh` installed and authenticated (`gh auth status` exits 0).
  `doctor` reports this under Integrations.
- `python3` for the bundled analyzer.
- The current directory is inside the target Git repository (or pass `--repo`).

## Workflow

1. **Verify auth.** `gh auth status`. If unauthenticated, ask the user to run
   `gh auth login` (repo + workflow scopes typically required).
2. **Resolve the PR.** Defaults to the current branch's PR, or pass `--pr`.
3. **Inspect checks (source of truth).** Use `gh pr checks` (optionally `--json name,bucket,state,workflow,link`)
   to list failing jobs before diving into logs.
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
   fetch logs from Buildkite/CircleCI/etc.
6. **Summarize.** For each failing check report: name, run URL, conclusion,
   workflow, branch/SHA, and the failure snippet (or "logs pending" if the run
   is still in progress). Extract the **first actionable error** — the command,
   assertion, or service failure to address next.
7. **Draft a plan.** Propose the fix as a short, numbered plan. **Do not edit
   files yet.** Fix **one actionable failure at a time**; prefer minimal,
   low-risk changes before broader refactors. If the project has a planning skill
   (e.g. `planning`), delegate the plan structure to it.
8. **Implement after approval.** Once the user approves the plan, apply changes,
   summarize the diff, and ask whether to push (delegate the push/PR-update step
   to `github-cli-workflow`).
9. **Recheck.** After push, re-run `gh pr checks` and repeat from step 3 until
   green or blocked on an external provider. Suggest re-running relevant tests
   locally between iterations.

## CI log triage patterns

| Pattern | Action |
|---------|--------|
| Multiple red jobs | Triage all; fix the root failure first (often lint/typecheck before e2e) |
| Flaky / in-progress | Report "logs pending"; do not guess — wait or re-fetch |
| External check URL only | Surface URL; user opens provider UI; no log fetch |
| Same job fails twice | Widen log snippet (`--max-lines`); check env/matrix differences |
| Fix verified locally but CI red | Compare CI command vs local; check cache, paths, permissions |

## Guardrails

- Fix one actionable failure at a time.
- Prefer minimal, low-risk changes before broader refactors.
- Keep `gh pr checks` as the source of truth for overall PR CI state.

## Boundaries

- Read-only on CI; **never** rerun jobs or cancel workflows from this skill.
- Do not push commits — delegate to `github-cli-workflow`.
- Do not implement before explicit user approval of the plan.

## Output

- Primary failing job and root error (with log snippet or external URL)
- Fixes applied in iteration order
- Current CI status (`gh pr checks`) and next action

## Bundled resources

- `scripts/inspect_pr_checks.py` — failure analyzer (stdlib only). Returns text
  by default; `--json` for machine-readable output.

## Validation

- `skills check` reports the `gh` and `python3` requirements.
- `doctor` shows `gh auth status` under Integrations.
