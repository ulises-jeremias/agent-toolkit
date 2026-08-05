---
name: gitlab-cli-workflow
description: >-
  HOW — GitLab CLI (glab): push branch, create draft MR with title/body; fallback untracked markdown.
  Use when origin is GitLab.
---

# GitLab CLI — draft MR (HOW)

Use this skill when the remote is **GitLab** and you need to **push** and open a **draft** merge request. Workflow skills delegate here.

## Prerequisites

- `glab` authenticated for the host (`glab auth status`).
- Branch pushed to the documented remote.

## Discover draft flags

Run `glab mr create --help` on the machine—subcommands and flags evolve. Prefer **draft** / **WIP** equivalents when available.

## Recommended flow

1. Push the branch and set upstream per team practice.
2. Create an MR body file: use the project’s **merge request template** when present. If the project has no template, you may align the **Markdown** with **`pr-fallback`** (same default sections as the org PR body) and **`output-handshake`** for where the description file lives and human review—then use that file for `--description` or the equivalent.
3. **Draft** MR (illustrative; confirm flags with `glab --help`):

```bash
glab mr create --draft --title "YOUR_TITLE" --description "$(cat /path/to/body.md)"
```

If the CLI prefers a file flag, use that instead of shell substitution.

4. If draft creation fails, retry with non-draft **only** if the user accepts, and note the limitation in chat.

## Fallback (CLI failure)

1. Write **untracked** `MERGE_REQUEST_DESCRIPTION_<WORK_ITEM_ID>.md` (or `PR_DESCRIPTION_<ID>.md`) with title + body.
2. **Do not** `git add` it.
3. Instruct the user to open the GitLab **New merge request** UI from the branch and paste content, choosing **draft** if the UI offers it.

## Safety

- No secrets in MR descriptions.
- No force-push to shared defaults without explicit user request.
