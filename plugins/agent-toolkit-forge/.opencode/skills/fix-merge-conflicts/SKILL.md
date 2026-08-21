---
name: fix-merge-conflicts
description: Resolve merge conflicts non-interactively, validate build and tests, and finalize conflict resolution
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: cursor-team-kit/skills/fix-merge-conflicts
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Detect conflicting files via git status/markers, minimal correctness-first merges, regenerate lockfiles instead of hand-editing, validate via compile/lint/tests
---

# Fix Merge Conflicts

Resolve merge conflicts non-interactively and return the branch to a buildable state.

## When to use

- `git status` shows `Unmerged paths` or `CONFLICT`, or the branch reports merge conflicts against `main`.
- User asks to "fix merge conflicts", "resolve conflicts", "rebase and fix", or "make this branch mergeable".
- A PR is blocked by conflicts after pulling main.

## Prerequisites

- Inside a Git repository with write access (`git status` works).
- Conflicts come from a merge or rebase (e.g. `git merge main`, `git pull --rebase`, `gh pr update-branch`).
- Toolchain available for validation: package manager (`npm`/`yarn`/`pnpm`/`bun`/`uv`/`cargo`/etc.) and `git`.

## Workflow

1. **Detect conflicts.** Run `git status --porcelain` and scan for `UU`/`AA`/`DD`/`U*` markers. Confirm with `grep -r "<<<<<<< " --include="*.md" --include="*.ts" --include="*.js" --include="*.py" --include="*.v" --include="*.yaml" --include="*.json" -l` (and `git diff --check` for leftover markers). List every conflicting file.

2. **Resolve each conflict with minimal, correctness-first edits.** Open each file, read the `<<<<<<< / ======= / >>>>>>>` hunks, and choose the merge that compiles and preserves public behavior. Prefer preserving both sides when safe; otherwise pick the variant that keeps the build green and does not change external API semantics. Keep edits readable — no broad refactors while resolving.

3. **Regenerate lockfiles via the package manager — do not hand-edit.** If a lockfile is conflicted (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`, `Cargo.lock`, `uv.lock`, `go.sum`, `Gemfile.lock`, etc.), discard conflict markers and regenerate: `npm install --package-lock-only`, `yarn install`, `pnpm install`, `bun install`, `cargo update --workspace`, `uv lock`, or the repo's documented install command. Confirm the manager that owns the file (check `package.json` `packageManager`, `Makefile`, or `README.md`).

4. **Validate.** Run compile, lint, and the most relevant tests for the touched areas. At minimum:
   ```bash
   git diff --check  # no leftover markers / whitespace issues
   # then per-stack, e.g.:
   # npm run build  /  cargo check  /  v vet  /  make build
   # npm run lint   /  ruff check .  /  ./scripts/validate-skills.vsh
   # npm test -- <changed packages>  /  pytest -q <changed modules>
   ```
   Re-run until the working tree is clean of markers and the build succeeds.

5. **Stage and finalize.** `git add <resolved files>` then `git status` to confirm no remaining `Unmerged` paths. If a rebase/merge was in progress, run `git rebase --continue` or `git commit` as appropriate (no `git push` or `git tag` from this skill — delegate to `github-cli-workflow`).

6. **Summarize decisions.** Report: files resolved, notable resolution choices (why each hunk was kept/merged), lockfile regeneration performed, and build/test outcome with next action.

## Guardrails

- Keep changes minimal and readable.
- Do not leave conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) in any file.
- Avoid broad refactors while resolving conflicts — only what is needed to make the merge buildable.
- Do not push, tag, or force-push during conflict resolution. Delegate pushes to `github-cli-workflow` after user confirmation.
- Do not hand-edit lockfiles; always regenerate via the owning package manager.

## Output

- Files resolved (with hunk-level rationale where non-trivial)
- Notable resolution choices
- Build/lint/test outcome
- Next step (continue rebase / commit / push via `github-cli-workflow`)
