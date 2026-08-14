---
name: worktree
description: Manage Git worktrees per writer for Agent Toolkit swarms — isolated branches, handoff promotion,
  and cleanup.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - git
  - worktree
  - swarm
  - handoff
  - branch
---
# Worktree

Create and maintain **worktree-per-writer** isolation for `agent-toolkit swarm` so each role works on its own branch without stepping on others. Integrates with `swarm-handoff` promotion and `github-cli-workflow` for PRs.

## When to use

- Swarm needs isolated writes: implementer, reviewer, integrator each own a worktree/branch.
- `worktree_failed` trace or `find_repo_root` error on `.git` file worktrees.
- Before `swarm promote` — ensure the handoff's worktree is clean and pushable.
- Cleanup after a run is promoted or abandoned.

## Prerequisites

- Repo is Git with `git worktree` available (`git worktree --help`).
- Swarm run exists: `.agent-toolkit/swarm/runs/<run-id>/state.json`; worktrees live under `.agent-toolkit/swarm/runs/<run-id>/worktrees/<role>-<short>/`.
- `find_repo_root` uses `git rev-parse --git-common-dir` to handle worktree `.git` files (not directories).

## Workflow

### 1. Inspect current worktrees

```bash
git worktree list
agent-toolkit swarm status --run-id <run-id> --json | jq '.worktrees'
# Expected: {implementer: {path, branch, commit}, reviewer: {path, branch}, ...}
cat .agent-toolkit/swarm/runs/<run-id>/state.json | jq '.trace | map(select(.event | contains("worktree")))'
```

### 2. How swarm creates them (automatic)

On `handoff create --from X --to Y` for a writer role `Y`, swarm:

1. Resolves repo root via `find_repo_root` (`git rev-parse --git-common-dir` fallback).
2. Creates branch `swarm/<run-id>/<role>` if missing.
3. Runs `git worktree add <run-dir>/worktrees/<role>-<short> <branch>`.
4. Exports `AGENT_TOOLKIT_SWARM_RUN_ID/RUN_DIR/REPO SWARMFORGE_ROLE` and `cd <worktree> && exec <runner> "$(cat prompt)"` via `_user_shell()` (`/usr/bin/zsh -lc` on this host).

Do not create worktrees by hand for swarm roles — let `handoff create` do it so `state.json` stays authoritative.

### 3. Manual recovery

If `worktree_failed`:

```bash
git rev-parse --git-common-dir  # from worktree dir — should succeed
AGENT_TOOLKIT_SWARM_RUN_ID=<run-id> agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact artifacts/retry.md --run-id <run-id>
# Re-triggers provisioning with fixed repo-root logic
```

If a worktree is orphaned or locked:

```bash
git worktree list | grep <run-id>
git worktree remove <path> --force
git worktree prune
git branch -D swarm/<run-id>/<role>  # only if run is abandoned and branch is merged/abandoned
```

### 4. Promotion and PR

After reviewer/integrator approves the handoff's artifact:

```bash
agent-toolkit swarm promote --run-id <run-id> --handoff-id <handoff-id>
git -C <worktree-path> log --oneline -n 5
git -C <worktree-path> push -u origin <branch>
# Delegate to github-cli-workflow for draft PR
gh pr create --title "swarm/<run-id>: <summary>" --body-file artifacts/<handoff-artifact> --base main
```

For reuse: same run-id reuses worktrees; no `prune` between sequential handoffs. New run only for isolated feature branches.

### 5. Cleanup after merge

```bash
gh pr merge <number> --squash --delete-branch
git worktree remove <path> --force
git worktree prune
agent-toolkit swarm list --json | jq '.[] | select(.run_id=="<run-id>") | .status'
# Optionally archive state: tar -czf /tmp/swarm-<run-id>.tgz .agent-toolkit/swarm/runs/<run-id>
```

## Boundaries

- Never edit `.agent-toolkit/swarm/runs/<run-id>/state.json` worktree entries by hand — use swarm CLI.
- Never use `git checkout` in the main worktree to switch swarm branches; always `git worktree`.
- Never delete a worktree that has an `active` handoff — complete or handoff first.

## Delegates to

| Need | Skill |
|------|-------|
| Create the handoff that provisions the worktree | `swarm-handoff` |
| Launch or observe the swarm | `swarm`, `swarm-observer` |
| Herdr/tmux pane for the worktree | `herdr` |
| Push and create PR after promotion | `github-cli-workflow` |
| Review before promotion | `code-reviewer`, `security-reviewer` |
