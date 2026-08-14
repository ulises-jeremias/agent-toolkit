---
name: gh-fix-ci
description: Diagnose failing GitHub Actions checks on a PR via gh, summarize the failure context, propose
  a plan, and only implement after explicit user approval. External CI providers (Buildkite, CircleCI,
  etc.) are reported by URL only.
origin:
  type: first-party
---
# Fix Failing PR Checks

Inspect failing GitHub Actions checks on a PR with `gh`, fetch run logs, extract
a focused failure snippet, and propose a fix plan before making any change.

## When to use

- A PR has red checks and the user asks to "fix CI", "debug the failing job",
  or "why is the build red".
- You need a fast triage of which jobs failed and the relevant log slice.

## Prerequisites

- `gh` installed and authenticated (`gh auth status` exits 0).
  `doctor` reports this under Integrations.
- `python3` for the bundled analyzer.
- The current directory is inside the target Git repository (or pass `--repo`).

## Workflow

1. **Verify auth.** `gh auth status`. If unauthenticated, ask the user to run
   `gh auth login` (repo + workflow scopes typically required).
2. **Resolve the PR.** Defaults to the current branch's PR, or pass `--pr`.
3. **Run the analyzer:**

   ```bash
   python3 ~/.local/share/agent-toolkit/skills/gh-fix-ci/scripts/inspect_pr_checks.py \
     --repo . --pr <number-or-url>
   ```

   - Add `--json` for machine-friendly output suitable for further processing.
   - Add `--max-lines <n>` / `--context <n>` to widen the snippet window.

   The script handles `gh pr checks` field drift, falls back to job-level logs
   when run-level logs are not yet available, and exits non-zero when failures
   remain (so it composes in CI / scripts).
4. **Scope external providers.** Any check whose `detailsUrl` is not a GitHub
   Actions run is reported as `external` with only the URL — do not attempt to
   fetch logs from Buildkite/CircleCI/etc.
5. **Summarize.** For each failing check report: name, run URL, conclusion,
   workflow, branch/SHA, and the failure snippet (or "logs pending" if the run
   is still in progress).
6. **Draft a plan.** Propose the fix as a short, numbered plan. **Do not edit
   files yet.** If the project has a planning skill (e.g. `planning`),
   delegate the plan structure to it.
7. **Implement after approval.** Once the user approves the plan, apply changes,
   summarize the diff, and ask whether to push (delegate the push/PR-update step
   to `github-cli-workflow`).
8. **Recheck.** Suggest re-running the relevant tests locally and `gh pr checks`
   after the new commit lands.

## Boundaries

- Read-only on CI; **never** rerun jobs or cancel workflows from this skill.
- Do not push commits — delegate to `github-cli-workflow`.
- Do not implement before explicit user approval of the plan.

## Bundled resources

- `scripts/inspect_pr_checks.py` — failure analyzer (stdlib only). Returns text
  by default; `--json` for machine-readable output.

## Validation

- `skills check` reports the `gh` and `python3` requirements.
- `doctor` shows `gh auth status` under Integrations.
