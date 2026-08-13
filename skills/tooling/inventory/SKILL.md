---
name: inventory
description: Discover installed skills, agents, loops, and platform capabilities via agent-toolkit inventory,
  matrix, and skills list.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - inventory
  - matrix
  - catalog
  - discovery
---
# Inventory

Discover what the toolkit can do before you build — **skills, agents, loops, MCP, and platform support** — via `agent-toolkit inventory`, `matrix`, `build --check`, and `skills list`.

## When to use

- User asks "what can agent-toolkit do?", "what skills are available?", or "is there a skill for X".
- Before starting delivery: check which workflow (`delivery/*`), forge (`github-cli-workflow`), or ops (`swarm`) skills apply.
- After `agent-toolkit install` — verify what was deployed and what needs `mcp setup`.
- Before running `build` or `plugin` — understand target support via `matrix`.

## Workflow

### 1. List everything

```bash
agent-toolkit inventory              # skills (61), agents (16), loops (10), products
agent-toolkit matrix                 # platform capability matrix (claude-code, cursor, opencode, etc.)
agent-toolkit skills list            # grouped by domain (core, ops, forge, etc.)
agent-toolkit skills list --domain ops  # filter
agent-toolkit loops --help 2>&1 | head
```

`inventory` now shows 61 skills across 9 domains including the new swarm family:
- `ops/swarm`, `ops/swarm-observer`, `ops/swarm-handoff`, `tooling/herdr`, `forge/worktree`, `core/workspace`, `core/project`, `integrations/mcp`, `tooling/inventory`.

### 2. Inspect a skill or agent

```bash
agent-toolkit skills validate        # all 61 should be ✓
muse skills validate ~/.ai-workspace/.agents/skills/swarm --json | jq .valid
cat skills/ops/swarm/SKILL.md | head -n 20
cat agents/code-reviewer/AGENT.md | head -n 20
ls plugins/  # agent-toolkit-core, agent-toolkit-forge, etc. — each maps skills+agents to targets
```

### 3. Check readiness before delivery

```bash
agent-toolkit doctor
agent-toolkit mcp doctor
agent-toolkit swarm doctor           # herdr/tmux + runner model profiles
agent-toolkit build --check          # validate compilation without writing plugins/
```

### 4. After adding skills

```bash
# After creating skills/<domain>/<id>/SKILL.md and data/skills/<domain>/<id>/SKILL.md:
python3 scripts/generate-catalogs.py          # regenerate skill-catalog.yaml
bash scripts/prepare-package-data.sh         # sync skills/catalogs to data/
# Then update installed data if testing locally:
cp catalogs/skills-layout.json packages/pypi/agent-toolkit-cli/src/agent_toolkit/data/catalogs/
cp -r skills/ops/swarm packages/pypi/agent-toolkit-cli/src/agent_toolkit/data/skills/ops/
agent-toolkit skills validate                # should show 61
agent-toolkit skills list --domain ops       # should include new skill
agent-toolkit install --dry-run | grep "Would deploy"
```

## Delegates to

| Need | Skill |
|------|-------|
| Use a discovered skill | `assistant` (discovery), `swarm` (orchestration), `workspace` (context) |
| Install or sync to a tool | `mcp` (providers), `herdr` (UI) |
| Build error after inventory | `build-error-resolver` agent |
