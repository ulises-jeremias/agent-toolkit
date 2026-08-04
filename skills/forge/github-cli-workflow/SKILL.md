---
name: github-cli-workflow
description: >-
  HOW — GitHub CLI (gh): push branch, create draft PR with title/body from template or file;
  fallback untracked PR_DESCRIPTION_*.md. Use when origin is GitHub.
---

# GitHub CLI — draft PR (HOW)

Use this skill when the remote is **GitHub** and you need to **push** and open a **draft** pull request. Workflow skills delegate here; this skill does **not** replace Jira or ClickUp procedures.

## Prerequisites

- `gh` authenticated (`gh auth status`).
- Branch pushed to `origin` (or the remote your team uses).

## Recommended flow

1. Ensure the working branch tracks the remote: push with upstream as usual for the repo.
2. Prefer the repository **PR template** for the body: use `--body-file` pointing at a generated file that includes template sections, or paste from `.github/pull_request_template.md` when required. If no template exists in the repo, use **`pr-fallback`** (WHAT) to build the body and **`output-handshake`** to confirm where the file lives and that a human will review before `gh pr create`.
3. Create a **draft** PR:

```bash
gh pr create --draft --title "YOUR_TITLE" --body-file /path/to/body.md
```

If the repo expects a base branch other than the default:

```bash
gh pr create --draft --base develop --title "YOUR_TITLE" --body-file /path/to/body.md
```

4. If `--draft` is rejected by `gh`, retry once without `--draft` and **state in chat** that the PR could not be created as draft via CLI.

## Title and body

- Keep titles within team conventions (often including ticket keys).
- Validate **title and body with the user** before calling the step complete.

## Fallback (CLI failure)

1. Write an **untracked** file `PR_DESCRIPTION_<WORK_ITEM_ID>.md` in the repo root or `/tmp` with title + body ready to paste.
2. **Do not** `git add` this file.
3. Give manual steps: open the compare URL on GitHub and create a **draft** PR from the branch, pasting from the file.

## Safety

- Do not expose tokens or paste secrets into PR bodies.
- Do not force-push shared default branches unless the user explicitly requests it.
