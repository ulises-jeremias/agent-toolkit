---
name: pr-ship
description: Ship and babysit pull requests in conflict-first order (conflicts, review threads, CI) with skeptical comment verification, push-before-reply SHA citations, dual GitHub check gates, and Goal v2 policy checks.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: "1.0.0"
  domain: forge
  tags:
    - pr
    - shipping
    - babysit
    - merge-frontier
    - ci
    - review-threads
    - goal-v2
    - repo-profiles
  inspired_by:
    - repository: cursor/plugins
      path: pstack/skills/babysit
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Conflict-first PR merge frontier, skeptical bot and reviewer comment triage, push-before-reply SHA discipline, and dual-API CI verification
tools:
  - universal
  - claude-code
  - cursor
  - opencode
  - copilot-cli
  - windsurf
  - pi
triggers:
  - ship PR
  - babysit PR
  - pr-ship
  - land PR
  - prepare PR for merge
  - triage PR frontier
requires:
  - git
  - gh
produces:
  - candidate-bound receipt
  - pushed fix commit
  - PR reply
  - merge readiness report
compatibility: Portable across Claude Code, Codex, Cursor, OpenCode, Gemini CLI, GitHub Copilot, and Veasel. Delegates GitHub and GitLab CLI operations to forge skills under Goal v2 policy_ceiling.
---

# PR Ship

Move an open pull request to a clean, merge-ready state using a strict conflict-first frontier, skeptical review triage, dual GitHub check verification, and Goal v2 policy gating.

## Policy ceiling and delivery mode

Before any local or remote action, check Goal v2 `policy_ceiling` and `delivery_mode` (`schemas/goal-v2.schema.json`):

| PR operation | Required Goal v2 `policy_ceiling` effect | Fallback when omitted |
| --- | --- | --- |
| Read PR metadata, threads, and checks | `github.read` | Inspect local Git state only |
| Edit files to resolve conflicts or feedback | `repository.write` | Report exact proposed diff locally |
| Run local tests, linters, or lockfile checks | `process.execute` | Skip execution and mark checks `inconclusive` |
| Commit resolved fixes locally | `git.commit` | Leave changes unstaged for user review |
| Push fix commits to PR branch | `git.push` | Stop at local commit and print push command |
| Reply on PR review threads | `github.comment.create` | Draft thread replies locally via `core/output-handshake` |
| Edit PR title, body, or update branch | `github.pr.update` | Output proposed title, body, or rebase command |
| Open a new draft PR | `github.pr.create` | Write PR text via `core/pr-fallback` |
| Merge an approved PR | `github.merge` | Stop at review-ready PR and report status |

When `delivery_mode` is `report`, perform zero remote writes (`git.push`, `github.comment.create`, `github.pr.update`, `github.pr.create`, `github.merge`). Never call `release.publish`, create tags, or dispatch release workflows from PR shipping.

## Operational safety guards

Check repository state and ownership before modifying or merging any PR:

1. **Active-session 48h guard.** Skip merge, close, or destructive branch updates when any open PR authored by the repository owner or opened from an active worktree branch (`codex/*`, `goal/*`, `wt-*`) was updated within the last 48 hours, or when an active mission file (`goals/*.md` or `knowledge/projects/*/STATE.md`) claims the repository. Report `skipped, owned by active session` with the observed PR or file path.
2. **Repository profile check.** Re-read live branch protection, rulesets, and `allow_auto_merge` at runtime instead of trusting cached assumptions. On `report-only` or `veasel-pilot` repositories, make zero GitHub writes and produce draft proposals only.
3. **No admin bypass.** Never run `gh pr merge --admin`.

## Conflict-first merge frontier

Execute these stages in order and restart at Stage 1 whenever a new commit lands on the branch:

### Stage 1: Resolve conflicts first

Never spend review or CI cycles on a conflicted PR, because resolving conflicts changes the head commit SHA and invalidates earlier check runs and line comments.

1. Inspect `git status` and query `mergeable` and `mergeable_state` on the PR.
2. If conflicts exist or the base branch moved incompatibly, invoke `forge/fix-merge-conflicts`.
3. Regenerate conflicted lockfiles with the owning package manager; never hand-edit lockfiles.
4. Run local compile, lint, and targeted tests, then commit and push (`git.push` within `policy_ceiling`) before reading review comments or debugging CI.

### Stage 2: Skeptical review thread triage

Fetch all inline review threads, review summaries, and conversation comments via `forge/gh-address-comments`.

1. **Verify every claim skeptically.** Automated bots and human reviewers both misread types, control flow, and caller contracts. Read the exact `file:line` and surrounding callers before editing code.
2. **Reject false positives with evidence.** When a comment is wrong or already satisfied, do not apply a speculative patch. Cite the concrete `file:line`, invariant, or test result that disproves it.
3. **Push before replying with the exact SHA.** For accepted comments, apply the minimal fix, run local validation (`hermetic` or `real`), commit, and push to the remote branch. Only after `git push` succeeds, reply on the thread (`github.comment.create`) citing the exact pushed commit SHA. Never post a "Fixed" reply while the fix exists only locally.

### Stage 3: Dual GitHub check verification and CI triage

Inspect CI only after conflicts are clean and pending review fixes are pushed.

1. **Query both GitHub check APIs.** Read both the Check Runs API and the Commit Statuses API for the exact `candidate_sha`:

   ```bash
   gh api "repos/$repo/commits/$sha/check-runs?per_page=100" \
     --jq '.check_runs[] | "\(.name)|\(.status)|\(.conclusion)"'
   gh api "repos/$repo/commits/$sha/status" \
     --jq '.statuses[] | "\(.context)|\(.state)"'
   ```

   Never trust only one API. Check runs alone miss Danger, Vercel, and external commit statuses that appear with `name=null` in `statusCheckRollup`.
2. **Verify expected check coverage.** Zero check runs on a PR head SHA is never green; report it as unverified. Require `conclusion=success` on every expected or required check (`skipped` or `neutral` only for non-required checks) and zero `failure` or `error` commit statuses.
3. **Baseline green-to-red regression diffing.** Before blaming the PR or merging, record the default branch's latest workflow conclusions (`gh run list --repo "$repo" --branch "$default_branch" --event push --limit 20 --json workflowName,conclusion,headSha`). Flag only green-to-red transitions introduced on the PR as PR regressions. If every open PR in the repository fails the exact same check on the base branch, report one repo-wide blocker on the base branch instead of patching symptoms per PR.
4. **Frozen lockfile check.** Whenever dependency manifests or lockfiles change, verify reproducibility with the repo's frozen install mode (`npm ci`, `pnpm install --frozen-lockfile`, `uv sync --frozen`, `yarn install --frozen-lockfile`, or `cargo check --locked`). Never add `--legacy-peer-deps` or dependency overrides without maintainer approval.
5. **Fix actionable CI failures one at a time.** Delegate CI log inspection and minimal single-failure fixes to `forge/gh-fix-ci`.

### Stage 4: Serialize lockfiles, clean prose, and ship

1. **Same-lockfile PR serialization.** When processing multiple PRs in a repository, merge at most one PR per lockfile directory per run. After each merge, re-fetch `mergeable`, `mergeable_state`, and head SHA checks for remaining PRs before acting, because two independent passing PRs can break the default branch when combined.
2. **Unslop PR text.** Run `quality/unslop` on PR titles, PR bodies, and review thread replies. Use `core/output-handshake` and `core/pr-fallback` when no PR template exists, and delegate branch push or PR updates to `forge/github-cli-workflow` or `forge/gitlab-cli-workflow`.
3. **Bind the candidate receipt.** Record a verification receipt matching `schemas/goal-evidence-v1.schema.json` (`task_id`, `attempt`, `repository`, `base_sha`, `candidate_sha`, `mode`, `environment`, `verifier_identity`, `verifier_version`, `result`, `digests`) bound to the pushed PR head SHA. Use `hermetic` or `real` mode for passing claims; never present `fixture` passes as live proof.
4. **Gate the merge.** Stop at a clean, review-ready PR unless `github.merge` is inside `policy_ceiling`, the 48h active-session guard is clear, and all dual-API checks and human approvals pass.

## Hard rules

- Never chase CI or review threads while the PR has merge conflicts.
- Never apply a bot or reviewer suggestion without verifying it against the code first.
- Never reply "Fixed" on a PR thread before `git push` succeeds and you cite the pushed commit SHA.
- Never treat Check Runs alone as complete CI proof; always check Commit Statuses too.
- Never use `--admin`, hand-edit lockfiles, or merge two same-lockfile PRs in one unrefreshed pass.
