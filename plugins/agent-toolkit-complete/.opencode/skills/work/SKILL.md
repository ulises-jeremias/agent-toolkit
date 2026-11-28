---
name: work
description: Entry-point engineering router. Inspects repo signals, workspace packs, and Goal v2 policy_ceiling to pick one playbook, require independent cross-vendor review, bind receipts to candidate SHAs, and ship PRs conflict-first.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: "1.0.0"
  domain: core
  tags:
    - router
    - workflow
    - goal-v2
    - cross-review
    - pr-shipping
    - verification
  inspired_by:
    - repository: cursor/plugins
      path: pstack
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Single engineering entry point, independent multi-model verification, and conflict-first PR shipping order
tools:
  - universal
  - claude-code
  - cursor
  - opencode
  - copilot-cli
  - windsurf
  - pi
triggers:
  - work
  - start work
  - ship feature
  - fix bug
  - investigate issue
  - review and ship
  - work router
  - route task
requires: []
produces:
  - plan
  - candidate-bound receipt
  - draft PR
compatibility: Portable across Claude Code, Codex, Cursor, OpenCode, Gemini CLI, GitHub Copilot, and Veasel. Uses git, gh, and agent-toolkit CLI when present; runs sequential checks on targets without subagents.
---

# Work

Use this skill as the single engineering entry point in `agent-toolkit`. It inspects repository signals, active workspace packs, and Goal v2 `policy_ceiling` to pick one playbook, enforces independent cross-vendor review with candidate-bound receipts, and ships PRs conflict-first.

## Session intake and policy ceiling

Run these three intake steps before editing code:

1. **Inspect repository signals.** Follow `core/assistant` order: `README.md`, `docs/`, `AGENTS.md`, `CONTRIBUTING.md`, PR templates, task runners (`Makefile`, `justfile`, `make.vsh`, `package.json`, `pyproject.toml`), devcontainer or Docker files, CI workflows, and linter/test configs. Treat `AGENTS.md` as the primary agent contract.
2. **Load workspace state.** If a workspace is present, run `agent-toolkit workspace context`, `agent-toolkit memory inject`, and `agent-toolkit memory todo`. Load any matching `packs/<name>.yaml` overlay so engagement boundaries and LLM policy apply before work starts.
3. **Bind Goal v2 `policy_ceiling`.** Read `policy_ceiling` and `delivery_mode` (`report` or `draft`) from the Goal v2 manifest (`schemas/goal-v2.schema.json`) or task request. Every task must include `repository.read`. Never ask for, plan, or execute an effect outside `policy_ceiling`.

The closed portable permission vocabulary in `schemas/goal-v2.schema.json` has 17 effects:

| Effect | Permits | Fallback when omitted from `policy_ceiling` |
| --- | --- | --- |
| `repository.read` | Read repository files and history | Required on every task; reject manifest if absent |
| `repository.write` | Modify or create files in authorized paths | Stop at read-only analysis or report |
| `process.execute` | Run repo build, lint, or test commands | Inspect statically; mark runtime checks `unverified` |
| `network.access` | Reach external networks or remote APIs | Run offline checks only |
| `git.commit` | Create local Git commits | Leave changes unstaged or in diff output |
| `git.push` | Push commits to a remote branch | Stop at local commit; hand push command to user |
| `github.read` | Query PRs, checks, issues, and threads via `gh` | Rely on local Git state only |
| `github.issue.create` | Open new GitHub issues | Draft issue text locally via `core/output-handshake` |
| `github.issue.update` | Edit existing GitHub issues | Draft update text locally |
| `github.pr.create` | Open a draft or ready PR | Write body locally via `core/pr-fallback` |
| `github.pr.update` | Edit PR title, body, or base branch | Report proposed PR edits to user |
| `github.comment.create` | Post PR, commit, or issue comments | Draft reply text locally |
| `github.label.set` | Add or remove GitHub labels | Recommend labels in summary |
| `github.assign` | Assign issues or PRs | Recommend assignees in summary |
| `github.close` | Close issues or PRs | Recommend closure in summary |
| `github.merge` | Merge an approved PR | Stop at draft or review-ready PR |
| `release.publish` | Publish tags, packages, or releases | Stop before release steps; require human release |

## Deterministic routing table

Consult `capabilities/skills/registry.yaml` for owners, triggers, and contraindications. Pick ONE primary playbook from observed signals. Never chain every skill in a domain mechanically.

| Signal | Playbook | Skills and recipes | Required minimum `policy_ceiling` |
| --- | --- | --- | --- |
| Unknown repo, missing test/build map, or unclear scope | Discovery | `core/assistant`, `delivery/spike`, `delivery/project-assessment-evidence` | `repository.read` |
| Bug report, regression, or failing test or CI | Investigation and RCA | `recipes/goals/bug.yaml`, `delivery/bug`, `forge/gh-fix-ci`, `quality/blast-radius` | `repository.read` (`process.execute` to run repro) |
| Scoped feature or refactor with acceptance criteria | Feature implementation | `delivery/planning`, `recipes/goals/feature.yaml`, `delivery/development-workflow` or `delivery/workflow-generic-project`, `quality/deslop` | `repository.read`, `repository.write`, `process.execute` |
| High-risk diff, shared module, security concern, or explicit audit | Cross-vendor review and arena | `quality/deep-review`, `quality/blast-radius`, `agentic-security/owasp-agentic-review`, `quality/codeql` | `repository.read` (`github.read` for PR diffs) |
| UI, frontend, Electron, or design-system change | Visual and accessibility QA | Pick one primary driver (`design/design-assessment`, `design/frontend-design-review`, or `design/web-design-guidelines`), add `accessibility/review` when a11y applies, then `design/design-improvement` with `tooling/playwright-cli` or `tooling/chrome-devtools` | `repository.read`, `process.execute` (`repository.write` for fixes) |
| Open PR, merge conflict, review thread, or red CI | Conflict-first PR shipping | `forge/fix-merge-conflicts`, `forge/gh-address-comments`, `forge/gh-fix-ci`, `quality/unslop`, `core/output-handshake`, `core/pr-fallback`, `forge/github-cli-workflow` or `forge/gitlab-cli-workflow` | `repository.read`, `repository.write`, `process.execute`, `git.commit`, `git.push`, `github.read`, `github.pr.create` or `github.pr.update`, `github.comment.create` |
| Goal v2 manifest, task DAG, or scheduled loop run | Durable Goal and Loop verification | `agent-toolkit goal validate`, `agent-toolkit goal plan`, `agent-toolkit goal export`, `loops/loop-runner`, or Veasel for multi-worker execution | `repository.read` (plus declared task effects) |

When `delivery_mode` is `report`, never mutate the remote repository or open PRs even if `git.push` appears in `policy_ceiling`.

## Independent verification and cross-vendor review

Apply these rules before marking any task complete:

1. **Separate roles: `implementer != reviewer != verifier`.** The agent or model that wrote a change must not serve as its sole reviewer or verifier. Hand the diff and acceptance criteria to an independent reviewer (`@reviewer`, `@code-reviewer`, `@qa-engineer`, or `@security-engineer`).
2. **Run a cross-vendor arena on non-trivial changes.** When multiple model vendors are available (such as Claude, GPT/Codex, and Gemini), ask at least two distinct vendors to review the same diff or blast-radius question independently. Merge findings by `file:line`, severity (`critical`, `warning`, `suggestion`), and confidence (`high`, `medium`, `low`). Discard claims that lack a verified file citation or reproduction. On single-vendor setups, record the single-model limit in the final summary.
3. **Bind receipts to the exact candidate SHA.** Follow `schemas/goal-evidence-v1.schema.json`. Every passing verification receipt must record `task_id`, `attempt`, `repository`, `base_sha`, `candidate_sha`, `mode`, `environment`, `verifier_identity`, `verifier_version`, `result`, and `sha256:` `digests`. Any new commit invalidates prior receipts and requires re-verification on the new `candidate_sha`.
4. **Distinguish `fixture`, `hermetic`, and `real` evidence.**
   - `fixture`: synthetic data, mock providers, or pre-canned failure fixtures. Never present `fixture` passes as proof that live providers, binaries, or production workflows ran.
   - `hermetic`: real local test or build execution in an isolated environment without external side effects. Record exact commands and exit codes.
   - `real`: live execution against the target app, API, or provider session. State the exact environment observed.
   - Any check not executed stays `unverified` or `inconclusive`.

## Conflict-first PR merge frontier

When babysitting or shipping a PR, execute this exact sequence until the branch is clean:

1. **Resolve conflicts first.** Run `git status` and check mergeability against the base branch. If conflicts exist, invoke `forge/fix-merge-conflicts` before reading comments or chasing CI failures, because resolving conflicts changes the commit and invalidates earlier runs.
2. **Triage review threads second.** Fetch all inline and conversation threads via `forge/gh-address-comments`. Verify every human and automated bot comment skeptically against the actual code, types, and runtime behavior. Reject false positives with concrete `file:line` evidence instead of applying speculative edits.
3. **Push the fix before replying with the exact SHA.** For accepted comments, apply the minimal fix, run local validation, commit, and push to the remote branch (`git.push` inside `policy_ceiling`). Only after `git push` succeeds, reply on the review thread citing the exact pushed commit SHA. Never post a "Fixed" reply before the commit exists on the remote.
4. **Fix CI and verify frozen lockfiles third.** Check `gh pr checks` via `forge/gh-fix-ci` and fix one actionable failure at a time. Whenever manifests or lockfiles changed, run the repository's frozen lockfile check (such as `npm ci`, `pnpm install --frozen-lockfile`, `uv sync --frozen`, or `yarn install --frozen-lockfile`). Never hand-edit lockfiles and never add `--legacy-peer-deps` or dependency overrides without maintainer approval.
5. **Ship clean PR text.** Run `quality/unslop` on PR titles, bodies, and review replies. Use `core/output-handshake` and `core/pr-fallback` when the repo has no PR template, then delegate branch push and draft PR creation to `forge/github-cli-workflow` or `forge/gitlab-cli-workflow`. Stop before merge unless `github.merge` is inside `policy_ceiling` and all required checks and human approvals pass.

## Cross-target portability

This skill runs without vendor-locked runtime dependencies across all supported targets:

- **Targets with native subagents and parallel delegation** (Claude Code, Cursor, OpenCode, Codex, Gemini CLI, Pi, Veasel): dispatch independent `@reviewer`, `@qa-engineer`, or `@security-engineer` personas and cross-vendor review sessions in separate contexts.
- **Targets without subagents or hooks** (GitHub Copilot Repository, Muse Code, Windsurf, portable `agent-plugins`): execute each phase sequentially, run a dedicated clean-context review pass against the diff before shipping, and report the single-session review limitation explicitly.

## Hard rules

- Never fabricate files, SHAs, test outputs, receipts, or tool compatibility.
- Never inline forge, ticket, or browser CLI commands here; delegate HOW procedures to the owning skill in `capabilities/skills/registry.yaml`.
- Never execute mutations or remote GitHub actions absent from Goal v2 `policy_ceiling`.
- Never skip independent review, conflict checks, frozen lockfile verification, or candidate-SHA re-verification before shipping.
