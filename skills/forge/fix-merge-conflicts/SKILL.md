---
name: fix-merge-conflicts
description: Resolve merge or rebase conflict markers non-interactively, validate build and tests, and
  summarize resolution choices. Use when git reports conflicts during merge/rebase, the user asks to fix
  merge conflicts, or conflict markers appear in the working tree.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: cursor-team-kit/skills/fix-merge-conflicts
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Conflict resolution workflow — minimal edits, lockfile regeneration, build/test validation
---
# Fix Merge Conflicts

Resolve merge or rebase conflicts with correctness-first, minimal edits. Preserve
authorship and public behavior; validate before staging.

## When to use

- `git status` shows unmerged paths or conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
- User asks to "fix merge conflicts", "resolve rebase conflicts", or "clean up after merge".
- A rebase or merge stopped with conflicts and needs a reliable path to a buildable state.

## Prerequisites

- You are inside the target Git repository.
- The user has started (or attempted) merge/rebase — do not force-push or rewrite history
  unless explicitly requested.

## Workflow

1. **Detect conflicts.** Run `git status` and scan for conflict markers in affected files.
   List every conflicting path before editing.
2. **Resolve each file.** For each conflict:
   - Prefer preserving **both sides** when safe and composable.
   - Otherwise choose the variant that **compiles**, keeps **public behavior stable**,
     and matches the intent of the ongoing merge/rebase.
   - Remove all conflict markers — never leave `<<<<<<<` / `=======` / `>>>>>>>`.
3. **Lockfiles.** Regenerate lockfiles with the package manager instead of hand-editing.
4. **Validate.** Run compile, lint, and relevant tests for the repo.
5. **Stage and summarize.** `git add` resolved paths. Report files resolved and build/test outcome.

## Guardrails

- Keep changes **minimal and readable** — no broad refactors during conflict resolution.
- Do **not** leave conflict markers in any file.
- Do **not** push or tag during conflict resolution — delegate to **`github-cli-workflow`**.
- Preserve contributor authorship when rebasing.

## Related skills

- **`gh-fix-ci`** — if resolution passes locally but CI fails after push
- **`planning`** — when conflict resolution implies a larger design choice
