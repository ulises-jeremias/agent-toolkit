# Agent Toolkit Swarm — Herdr Plugin

Thin Herdr plugin for `agent-toolkit swarm`. No orchestration logic — actions invoke `agent-toolkit swarm` CLI.

## Install

Local development:

```bash
herdr plugin link ./integrations/herdr/agent-toolkit-swarm
```

From GitHub (verify current Herdr marketplace support for subdirectory):

```bash
herdr plugin install ulises-jeremias/agent-toolkit/integrations/herdr/agent-toolkit-swarm
```

Check plugin docs: https://herdr.dev/docs/plugins/

## Actions

- Start Pair Swarm
- Start Team Swarm
- Start Full Swarm
- Open Swarm Status
- Open Handoff Queue
- Open Final Report
- Pause/Resume/Stop/Clean Up

All actions run `agent-toolkit swarm ...` and consume its JSON/JSONL output.

## Trust

Inspect third-party Herdr plugins before installing. This plugin only invokes Toolkit CLI, no external network, no credential handling.

## Requirements

- `herdr >= 0.7.0`
- `agent-toolkit-cli` with `swarm` support
- `opencode` or other runner (optional, for actual runs)

## Development

Status pane: `agent-toolkit swarm watch --current` (uses stable JSON).
