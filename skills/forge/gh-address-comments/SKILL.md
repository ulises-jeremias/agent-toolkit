---
name: gh-address-comments
description: Triage and address open GitHub PR review and conversation comments using the gh CLI. Use
  when the user wants to "address PR comments", "resolve review threads", or "respond to reviewers" on
  the current branch's pull request.
origin:
  type: first-party
---
# Address GitHub PR Comments

Find the open PR for the current branch and walk through its review/conversation
comments using `gh`. Pair with [`github-cli-workflow`](../github-cli-workflow/SKILL.md)
when you also need to push changes or update the PR description.

## When to use

- The current branch has an open PR and reviewers left comments.
- The user asks to "address comments", "resolve review threads", or "respond to PR feedback".
- You need a summarized view of inline comments + reviews + conversation threads in one call.

## Prerequisites

- `gh` (GitHub CLI) installed and on `PATH` (covered by `bootstrap`).
- `gh auth status` exits 0. If not, ask the user to run `gh auth login` once
  (workflow + repo scopes recommended).
- `python3` (used by the bundled inspection script).

`doctor` already reports `gh auth status` under "Integrations" — confirm it
is green before invoking this skill.

## Workflow

1. **Verify auth.** Run `gh auth status`. If it fails, stop and ask the user to
   re-authenticate.
2. **Resolve the PR.** Use `gh pr view --json number,url,title` to confirm a PR
   is associated with the current branch. If none, surface that and stop.
3. **Fetch all threads in one pass.** Run the bundled script:

   ```bash
   python3 ~/.local/share/agent-toolkit/skills/gh-address-comments/scripts/fetch_comments.py \
     > /tmp/pr-comments.json
   ```

   The script paginates conversation comments, review submissions, and inline
   review threads (including resolved/outdated state) via `gh api graphql`.
4. **Summarize for the user.** Number every thread/comment and provide a one-line
   intent for each (e.g. `[3] tests/foo.test.ts:12 — reviewer asks for a null check`).
5. **Ask which to address.** Wait for the user to pick numbers before changing code.
6. **Apply fixes.** For each accepted comment, edit the relevant file and stage the
   change. Do not push or merge from this skill — delegate to `github-cli-workflow`.
7. **Optional: reply or resolve.** Once the user confirms, you can post replies
   with `gh pr comment <pr> --body "..."` or resolve threads via the GraphQL
   `resolveReviewThread` mutation when explicitly requested.

## Boundaries

- This skill **reads** PR feedback and **edits files**; it does **not** push,
  merge, or change PR metadata. Use `github-cli-workflow` for those steps.
- Scope is the open PR for the **current branch**. For arbitrary PR numbers,
  ask the user to switch branches first.
- If `gh` hits rate limits or auth errors mid-run, stop and surface the message —
  do not silently retry.

## Bundled resources

- `scripts/fetch_comments.py` — paginated GraphQL fetch (stdlib only, shells out
  to `gh api graphql`). Output is a single JSON document on stdout.

## Validation

- `skills check` reports the `gh` requirement.
- `doctor` shows `gh auth status` under Integrations.
