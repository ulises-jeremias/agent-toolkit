---
name: onboarding
description: >-
  Getting started guide for new users. Walks through setup validation,
  the skill/agent hierarchy, and the three most useful commands per role (developer,
  PM, tech lead). Use when someone is new to the workstation or asks "where do I start?"
metadata:
  author: 
  version: "1.0"
  tags: [onboarding, setup, getting-started]
---

# Onboarding

Welcome to . This skill guides new users through initial setup and daily usage.

## When to use

- User asks "where do I start?" or "how does this work?"
- First-time setup after `chezmoi apply`
- Troubleshooting a broken installation
- Onboarding a teammate

## Step 1 — Validate setup

```bash
dots-doctor
```

Expected: `result: COMPLIANT`. If any check fails, `dots-doctor` shows the fix command.

For persistent issues:

```bash
dots-update-check            # check for available updates
dots-skills list             # verify skills are installed
dots-skills sync             # re-sync symlinks to AI tools
```

## Step 2 — Understand the hierarchy

```text
User message
    ↓
Orchestrator (assistant)
    ↓ routes to
Workflow skill (WHAT — decides scope and gates)
    e.g. workflow-generic-project
    ↓ delegates to
Tool skill (HOW — executes CLI commands)
    e.g. clickup-cli, github-cli-workflow
```

**Skills** are invoked via the skill tool (e.g. `/planning`).
**Agents** are invoked via `@mention` (e.g. `@planner`). Never use the skill tool for agents.

## Step 3 — First commands by role

### Developer

```bash
# Start any task
/workflow-generic-project

# After code changes — review before PR
@code-reviewer

# CI failing
/gh-fix-ci
```

### Product Manager / Tech Lead

```bash
# Plan a feature
@planner

# Create a ClickUp task
/clickup-cli  # then: clickup task create --current --name "..."

# Project health check
/project-assessment
```

### Anyone

```bash
# Check workstation health
dots-doctor

# Find which skill to use
# → ask the orchestrator: "what skill should I use for X?"

# Load client/project context
./bin/workspace-context load packs/<client>.yaml   # if in ai-workspace
```

## Key concepts in 60 seconds

| Concept | What it means |
|---------|--------------|
| **Pack** | Context bundle for a client/project (repos, constraints, commands) |
| **Skill** | Reusable AI prompt for a specific task (WHAT or HOW) |
| **Agent** | Specialized AI persona with restricted tool access (invoked via @mention) |
| **Loop** | Recurring autonomous process with state, tiers, and cost budgets |
| **L1 / L2 / L3** | Loop autonomy tiers: L1=observe-only, L2=PR-gated, L3=unattended |
| **knowledge/** | Persistent memory across sessions |

## Anti-patterns

- Do not skip `dots-doctor` — it catches 90% of setup issues
- Do not invoke agents via the skill tool — use `@mention`
- Do not run L3 loops without 3+ clean L1 runs first

## Next steps

- Load a project pack: `./bin/workspace-context load packs/<project>.yaml`
- Run your first task: `/workflow-generic-project`
- Set up daily loop: `./bin/loop init daily-triage`
