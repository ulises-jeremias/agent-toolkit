---
name: pr-fallback
description: >-
  WHAT — When the repo has no GitHub PR template, structure the pull-request body using the default in references/pr-body-default.md. Pair with output-handshake and github-cli-workflow. Does not open the PR; HOW stays in the forge skill.
---

# PR body — default when no repo template (WHAT)

## When to use

- Remote is **GitHub** and **`assistant`** (or a file search) shows **no** `PULL_REQUEST_TEMPLATE` / `pull_request_template` under `.github/`.
- You need a **reasonable default** for `gh pr create --body-file` until the repo adds its own template.

## Instructions

1. Run **`output-handshake`**: user confirms where the final description will live (e.g. `body.md` for `gh`, paste-only) and that a **human** will review.
2. If the repository adds a template later, **prefer the repo** over this file.
3. Copy sections from **`references/pr-body-default.md`**, fill placeholders (issue id, test notes), and pass the path to **`github-cli-workflow`**.

## GitLab

If there is no `.gitlab/merge_request_templates/`, you may use the same Markdown structure in the **merge request description** for consistency, subject to the user’s **destination** choice (MR description field, file, etc.) and **`output-handshake`**.

## What not to do

- Do not **assume** a PR is always in a specific ticket system; the **file** the user points to is wherever they said in the handshake.

## References

- `references/pr-body-default.md` — local copy of the default body
- `development-workflow` — default PR validation and DoD expectations
- `github-cli-workflow` — draft PR creation
- `gitlab-cli-workflow` — GitLab MRs
