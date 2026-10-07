# Design note 03 — Git / worktree write lifecycle

Status: **HISTORICAL PROPOSAL** (2026-09-30). This note records the Git and
worktree design discussion at that date; its implementation claims are not
current. Check the [workflow ledger](../workflows.yaml) and current
[Desktop guide](../README.md) before treating any item as a gap. It remains
part of [WORKSTATION_REFERENCE_ANALYSIS.md](../WORKSTATION_REFERENCE_ANALYSIS.md).

Issue #1227: Git write/checkout was open future work; native worktree
*visibility* did not imply write support.

## Current truth

- Native Desktop can show a worktree rail bound to filesystem facts.
- `modules/desktop_engine/git_service.v` still reports
  `backend_available: false` and returns empty changes/history/diff.
- Checkout is omitted with a reason string (correct).
- `agent-toolkit serve` has **no** git/worktree write API.
- Electron Desktop has no Git panel yet.

Agent Office at `13c104eb` is evidence for a *lifecycle*, not a port:

- Branch `office/<slug>` where slug is `name-xxxx`.
- `git worktree add -b …` after a quiet fetch of the **current** project
  branch (not necessarily GitHub default).
- Record `path`, `branch`, `base` (SHA), `from` (PR target), `made`.
- Dirty = `git status --porcelain` line count.
- Unpushed = `rev-list --count` against HEAD + `--remotes`, minus a merged
  PR `headRefOid` (squash exemption).
- Destroy only when inspect says no dirty/unpushed (or user `--force`).
- Lost folder (#197): mark `lost`, refuse launch, user Rebuild / Send home.

## ATK mapping

Writes belong in V (`serve`), contained to the workspace/harness root,
previewable, receipted. Suggested ops (do not implement in this PR):

```text
GET  /api/v1/git/status          worktree, branch, dirty, ahead/behind
GET  /api/v1/git/diff            merge-base vs HEAD + unstaged + untracked
POST /api/v1/git/worktrees       { run, from } → preview then apply
POST /api/v1/git/commit          { paths|all, message }  confirm
POST /api/v1/git/worktrees/{id}/remove   blocked if dirty/unpushed
```

Push / `gh pr create` stay **later** and should default to `--draft` if
added (Agent Office does not — we should).

## Not adopted

- Desktop calling `git` / `gh` from Electron.
- Automatic rebuild of a deleted worktree.
- Leave-on-merge as a silent default.
- Multi-repo workspaces before single-repo writes exist.
