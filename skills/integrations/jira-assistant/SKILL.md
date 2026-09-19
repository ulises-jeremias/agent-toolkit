---
name: jira-assistant
description: 'Jira Cloud, Jira Software and Jira Service Management automation through the jira-as CLI
  (2.x). Run `jira-as help` first; find operations with `jira-as api search` and `jira-as api
  describe`.'
license: MIT
allowed-tools:
- Bash
- Read
origin:
  type: upstream
upstream:
  repository: grandcamel/JIRA-Assistant-Skills
  path: skills/jira
  ref: 82370fd582cb11998646c288309b36e93b297c5b
  license: MIT
  version: 82370fd
trust:
  tier: experimental
  reviewed_at: '2026-09-19'
  reviewed_by: ulises-jeremias
maintenance:
  status: active
  last_checked: '2026-09-19'
distribution:
  mode: vendored
  redistribution_allowed: true
  attribution_file: LICENSE
security:
  scripts: false
  shell: false
  network: true
  mcp: false
  hooks: false
version: 5.0.0
author: jira-assistant-skills
---

# Jira

Requires `jira-as>=2,<3`. This file is deliberately thin: the CLI's own help is the source of truth and this skill never restates it.

1. Start every task with `jira-as help`: the surface map, groups, topics, auth and sandbox modes.
2. Find an operation with `jira-as api search WORDS`, read it with `jira-as api describe OPERATION [--full|--examples]`, run it with `jira-as api call OPERATION ...`; `jira-as api topics` lists the deep-dive topics.
3. For a known group, `jira-as help GROUP`; for a gotcha (adf, paging, search, scope, risk, auth, migration, ...), `jira-as help TOPIC`. Old 1.x verbs: `jira-as help migration`.
4. Discovery needs no credentials; calls need `JIRA_SITE_URL`, `JIRA_EMAIL` and `JIRA_API_TOKEN` or existing settings. Risk-tagged calls preview by default; `--confirm` sends. Add `--format json` for machine-readable output.
