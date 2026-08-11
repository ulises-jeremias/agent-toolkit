---
name: swarm-handoff
description: Create artifact/commit file handoffs for Agent Toolkit swarms with worktree-per-writer, branch,
  and promotion integration.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - swarm
  - handoff
  - worktree
  - artifact
  - promotion
---
# Swarm Handoff

Create correct file handoffs between swarm roles so work moves via **Git + filesystem**, not chat copy. Every writer gets an isolated worktree/branch; the filesystem `state.json` is authoritative.

## When to use

- The swarm needs to move work: implementer → reviewer → integrator (or any `from -> to`).
- User asks to "hand off", "delegate", "send artifact", or "promote".
- After `swarm-observer` diagnoses a stuck `active` handoff.

## Prerequisites

- Run exists: `.agent-toolkit/swarm/runs/<run-id>/state.json`.
- Artifact file lives under the repo (prefer `artifacts/`). For `commit` type, commit/branch must exist locally.
- Know `from` and `to` roles from the recipe (`pair`: implementer→reviewer; `team`: implementer→reviewer→integrator).

## Workflow

### 1. Prepare the artifact (file handoff is preferred)

```bash
# Artifact — by convention in artifacts/
mkdir -p artifacts
cat > artifacts/<name>.md <<'EOF'
# Context for <to>
- What was implemented and why
- Files changed and how to verify
- Risks / open questions
EOF
git add artifacts/<name>.md  # optional, but keeps history

# Commit handoff — use when work is already committed
git log --oneline -n 5
git branch --show-current
```

### 2. Create the handoff (CLI owns state)

```bash
# Artifact handoff — triggers auto-provision of <to>'s worktree/tab + agent
agent-toolkit swarm handoff create --type artifact --from implementer --to reviewer --artifact artifacts/cna-ideas.md --run-id <run-id>

# Commit handoff
agent-toolkit swarm handoff create --type commit --from reviewer --to integrator --commit <sha> --branch <branch> --run-id <run-id>

# Auto behavior:
# - If an active handoff exists where to == from_role, it auto-completes (auto:true) and trace records handoff_completed.
# - Next role gets eager window (Waiting for handoff: <from> -> <to>) replaced by real prompt: export AGENT_TOOLKIT_SWARM_RUN_ID/RUN_DIR/REPO SWARMFORGE_ROLE + cd worktree && exec <runner> "$(cat prompt)"
```

Verify:

```bash
agent-toolkit swarm handoffs --run-id <run-id> --json | jq '.[] | {id,from,to,status,artifact,commit,auto}'
agent-toolkit swarm status --run-id <run-id> --json | jq '.trace | last'
# Expect: handoff create logs, worktree path, and runner exec with $(cat prompt)
```

### 3. Worktree-per-writer notes

- Writer roles get an isolated Git worktree (`git worktree add <path> <branch>`). The prompt is `export AGENT_TOOLKIT_SWARM_RUN_ID/... && cd <worktree> && <runner>`.
- Backend-neutral: `store.py` + `config.py` resolve repo root via `git rev-parse --git-common-dir` (handles `.git` file in worktrees). Do not bypass with manual `state.json` edits.
- Shell for `pane run` / `tmux` exec uses `_user_shell()` (`$SHELL`/`/usr/bin/zsh` fallback) as `<shell> -lc`.

### 4. Promote after verification

```bash
# After reviewer/integrator approves
agent-toolkit swarm promote --run-id <run-id> --handoff-id <id>
# or for the latest completed artifact:
agent-toolkit swarm promote --run-id <run-id>

# Then delegate push/PR
# (use github-cli-workflow skill for branch push + draft PR)
```

### 5. Reuse pattern

Same run can be reused for sequential requests — just create a new `implementer -> reviewer` artifact handoff on the same `run-id`. Eager windows stay; only the chain retriggers. Create a new run only for isolated branching.

## Boundaries

- Never copy artifact content via chat `echo` — use the file path in `--artifact`.
- Never write `state.json` directly; always via `handoff create` / `task complete`.
- For `commit` type, always pass `--commit` and `--branch`; the store validates `validate_commit_exists`.
- Keep `artifacts/` in Git so `herdr`/`tmux` runners can read it from their worktree.

## Delegates to

| Need | Skill |
|------|-------|
| Launch the swarm before handoffs | `swarm` |
| Diagnose stuck or orphaned handoffs | `swarm-observer` |
| Verify code before promotion | `code-reviewer`, `security-reviewer`, `tdd-guide` |
| Push branch and create PR | `github-cli-workflow` |
| Generate docs from handoff output | `output-handshake`, `docs-generator` |
