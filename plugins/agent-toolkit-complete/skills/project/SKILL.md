---
name: project
description: Clone, index, and orchestrate multi-repo work via agent-toolkit project — symlinks, quick
  access, and swarm workspaces.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - project
  - git
  - multi-repo
  - workspace
---
# Project

Manage the local multi-repo registry (`~/.ai-workspace/repos/` and `projects/` symlinks) so swarms and agents can target any repo by name, not path.

## When to use

- User says "clone X", "add repo Y", "list projects", or references `owner/repo` without a local path.
- Swarm needs `--workspace /path/to/repo` that isn't yet cloned.
- Workspace context shows missing `projects/` symlink for a repo referenced in a prompt.

## Prerequisites

- `agent-toolkit` with `project` subcommand (`agent-toolkit project --help`).
- `gh` authenticated for private repos (`gh auth status`).
- Workspace has `repos/github.com/<owner>/<repo>` layout.

## Workflow

### 1. Clone and index

```bash
agent-toolkit project clone owner/my-repo          # clone + symlink projects/my-repo -> repos/github.com/owner/my-repo
agent-toolkit project clone owner/my-repo --branch feat/x
# Alias resolution: swarm's config.py also resolves_owner_repo from prompt URLs like https://github.com/owner/repo

# Verify
agent-toolkit project list                         # indexed projects
ls -l ~/.ai-workspace/projects
ls ~/.ai-workspace/repos/github.com/owner/my-repo
```

### 2. Use with swarm and other skills

```bash
# Swarm can target any indexed repo via --workspace
agent-toolkit swarm start --recipe pair --ui herdr --runner opencode --model-profile balanced --workspace ~/.ai-workspace/repos/github.com/owner/my-repo --attach "task"
# Inside a cloned repo, just run from its directory — swarm's find_repo_root uses git rev-parse --git-common-dir

# Assistant discovery before swarm
# (assistant skill: README -> docs/ -> AGENTS.md -> CONTRIBUTING -> PR templates -> Makefile/package.json -> devcontainer -> CI -> configs)
```

### 3. Scan and sync

```bash
agent-toolkit project scan                         # re-index repos/ -> projects/
agent-toolkit project list --json | jq
agent-toolkit workspace context --json | jq '.repos'
```

### 4. Multi-repo swarms

For cross-repo tasks, clone all targets first, then launch swarms per repo with handoffs referencing the correct `--workspace` or `AGENT_TOOLKIT_SWARM_REPO` env:

```bash
agent-toolkit project clone org/repo-a
agent-toolkit project clone org/repo-b
export AGENT_TOOLKIT_SWARM_REPO=org/repo-a  # swarm's store respects this for run location
```

## Boundaries

- Never `git clone` by hand when `project clone` can do it — it handles symlinks and registry.
- Never assume CWD is the target repo; use `--workspace` or `workdir` per `AGENTS.md`.
- Do not delete `repos/` entries directly; use `agent-toolkit project remove` if available, or ask before manual `rm`.

## Delegates to

| Need | Skill |
|------|-------|
| Workspace packs and memory for the new repo | `workspace` |
| Repo conventions before coding | `assistant` |
| Swarm orchestration on the repo | `swarm` |
| Branch/PR after swarm promotion | `github-cli-workflow` |
