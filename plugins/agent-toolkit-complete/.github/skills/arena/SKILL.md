---
name: arena
description: Run a cross-vendor multi-model candidate bakeoff in isolated git worktrees, apply blinded cross-vendor judging, graft winning elements, and emit candidate-SHA-bound evidence receipts.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: "1.0.0"
  domain: quality
  tags:
    - arena
    - cross-vendor
    - multi-model
    - worktree
    - verification
    - judging
  inspired_by:
    - repository: cursor/plugins
      path: pstack/skills/arena
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Multi-model candidate bakeoff in isolated git worktrees, blinded judging rubric, and manual cherry-pick or graft of winning elements
    - repository: cursor/plugins
      path: pstack/skills/create-verification-skill
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Candidate-SHA-bound verification receipts, non-self-judging separation, and fixture vs hermetic vs real evidence discipline
tools:
  - universal
  - claude-code
  - cursor
  - opencode
  - copilot-cli
  - windsurf
  - pi
triggers:
  - arena
  - cross-vendor bakeoff
  - multi-model bakeoff
  - compare model solutions
  - blinded review
  - cross-vendor review
requires:
  - git
produces:
  - candidate-bound receipt
  - grafted diff
  - arena verdict
compatibility: Portable across Claude Code, Codex, Cursor, OpenCode, Gemini CLI, GitHub Copilot, and Veasel. Uses isolated git worktrees via forge/worktree; runs sequential candidate passes on single-vendor or subagent-free targets and reports that limitation.
---

# Arena

Run a blinded cross-vendor bakeoff across 2 or 3 distinct model families in isolated git worktrees, graft the strongest parts onto one clean candidate commit, and emit a SHA-bound verification receipt.

## When to use

- A change carries high regression risk, touches shared modules, or admits two or more competing architectures.
- You want independent models to solve or audit the exact same base commit and acceptance criteria before merging.
- Single-model review already missed a subtle bug, lockfile hazard, or edge case.

## Policy and role separation

Bind Goal v2 `policy_ceiling` (`schemas/goal-v2.schema.json`) before spawning candidate worktrees:

- Candidate generation requires `repository.read`, `repository.write`, `process.execute`, and `git.commit`.
- Never exceed `policy_ceiling` or `delivery_mode`. When `delivery_mode` is `report`, run candidate reviews only and keep the repository unmutated.
- Enforce `implementer != reviewer != verifier`. A model family that wrote a candidate must never act as its sole judge when a second vendor or model is configured.
- On single-vendor setups without a second configured model family, run a fresh clean-context session for judging and state the single-vendor limitation in the final verdict.

## Step 1: Prepare identical isolated worktrees

1. Record `base_sha` with `git rev-parse HEAD` and confirm the working tree is clean.
2. Create one isolated git worktree per candidate via `forge/worktree`, each branched from the exact same `base_sha` (for example `arena/cand-a`, `arena/cand-b`, and `arena/cand-c`).
3. Assign 2 to 3 distinct model families when available (such as Claude, GPT or Codex, and Gemini).
4. Give every candidate the identical task brief, `base_sha`, allowed paths, and acceptance criteria. Do not leak one candidate's diff or approach to another.
5. Require each candidate to commit its solution locally in its worktree and record the commands it actually ran.

## Step 2: Anonymize candidates for blinded judging

Before judging, strip all vendor names, model identifiers, branch hints, and author metadata from each candidate bundle:

1. Label the candidates `Candidate A`, `Candidate B`, and `Candidate C` in shuffled order and keep the mapping outside the judge prompt.
2. Export only the commit diff (`git diff <base_sha>..<candidate_sha>`), changed file list, and verbatim verification command outputs with exit codes.
3. Dispatch at least one judge from a model family that did not author the top candidate, or use cross-vendor panel judging where each judge scores all candidates blind.

## Step 3: Score against the five-part rubric

Each judge evaluates every candidate on five dimensions and cites concrete `file:line` paths or command results. Discard any claim that lacks a verified file citation or command output.

| Criterion | What the judge checks | Disqualifying signal |
| --- | --- | --- |
| Correctness | Solves every acceptance criterion and handles boundary conditions | Broken edge case, failing test, or unverified claim |
| Root-cause depth | Fixes the underlying invariant or contract rather than symptoms | Band-aid condition, swallowed error, or speculative guard |
| Minimal diff | Keeps changes tight and free of unrelated edits or code slop | Unrequested refactors, thin wrappers, or bloated files |
| Test and verification proof | Proves behavior with real local tests, type checks, or runtime runs | Fixture-only pass presented as live proof, or skipped checks |
| Regression risk | Bounds downstream breakage across callers, wire formats, and state | Unchecked caller impact; invoke `quality/blast-radius` when unsure |

## Step 4: Cherry-pick and graft the winner

Do not merge a winner blindly if another candidate solved an edge case or test better:

1. Unblind the scores and select the strongest candidate as the base branch.
2. Inspect non-winning candidates for superior elements, such as a cleaner helper, stricter input check, or sharper regression test.
3. Create a clean integration worktree from `base_sha`, apply the base candidate, and manually cherry-pick or graft the selected improvements.
4. Run `quality/deslop` on the grafted code diff and `quality/unslop` on any prose, commit messages, or PR text.
5. Remove losing worktrees cleanly after grafting so no stale branches or dirty worktrees remain.

## Step 5: Emit a candidate-SHA-bound receipt

Verify the final grafted commit from scratch and record a receipt matching `schemas/goal-evidence-v1.schema.json`. Any commit made after verification invalidates the prior receipt and requires a fresh run on the new `candidate_sha`.

Every passing receipt must include all eleven required fields:

- `task_id`: task identifier from the Goal v2 manifest or work item
- `attempt`: positive integer starting at `1`
- `repository`: target repository in `owner/repo` format
- `base_sha`: 40-char or 64-char hex commit SHA where the arena started
- `candidate_sha`: exact 40-char or 64-char hex commit SHA of the grafted candidate
- `mode`: `hermetic` (isolated real test or build run) or `real` (live app, API, or provider run)
- `environment`: exact OS, runtime, toolchain version, and isolation boundary observed
- `verifier_identity`: model or tool identity that ran the verification, distinct from the author
- `verifier_version`: version string of the verifier or judge configuration
- `result`: `pass`, `fail`, or `inconclusive`
- `digests`: non-empty list of `sha256:` 64-hex digests over the verified logs or artifacts

Never claim `pass` using `mode: fixture` as proof that live providers, binaries, or production workflows executed. Synthetic fixtures test only the fixture setup itself; if live or hermetic verification could not run, mark `result` as `inconclusive` and report what remains unverified.

## Hard rules

- Never judge a candidate with the same model that authored it when a second model family is available.
- Never compare candidates from different base SHAs.
- Never claim a check passed without pasting the exact command, exit code, and `candidate_sha`.
- Never present `fixture` runs as live or `real` verification proof.
- Never leave orphaned arena worktrees behind after emitting the final verdict.
