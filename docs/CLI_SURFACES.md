# CLI command surfaces

Progressive disclosure for the `agent-toolkit` CLI: everyday **consumer**
commands vs **advanced** workstation harness commands.

Related: [`SCOPE.md`](SCOPE.md) (product boundary), issue #48 (consumer-first
split), issue #84 (advanced runtime de-emphasis).

## Consumer commands

Install, verify, and sync toolkit content for coding assistants:

| Command | Purpose |
|---------|---------|
| `install` | Install profiles for detected or selected AI tools |
| `update` | Refresh installed profiles from latest toolkit data |
| `uninstall` | Remove toolkit-owned files using install receipts |
| `doctor` | Check toolkit data and tool availability |
| `diff` | Show changes vs installed plugin bundles |
| `skills` | Sync, list, and validate skills |
| `mcp` | MCP provider setup, health, doctor, uninstall |
| `plugin` | Plugin bundle sync and check |

Also: `version`, `help`.

## Advanced commands

Multi-repo workspace harness, loop automation, and maintainer tooling.
Still available on the same binary — de-emphasized in top-level help:

| Command | Purpose |
|---------|---------|
| `loop` | Loop engineering: init, run, status, audit, cost, schedule, sync |
| `workspace` | Workspace scaffolding: init, context, sync |
| `memory` | Knowledge base: add, search, inject, review, todo |
| `project` | Project index: clone, list, add, remove, scan |
| `devcompanion` | Background job queue (`dc` alias) |
| `insights` | Local usage analytics (OpenCode, Cursor, Claude) |
| `build` | Compile canonical capabilities into target artifacts |
| `inventory` | List skills, agents, and products |
| `matrix` | Platform capability matrix |
| `release` | Generate release artifacts (maintainer / CI) |
| `swarm` | Multi-agent swarm orchestration (pair/team/full, Herdr/tmux, budgets, handoffs) |

Swarm details: `docs/SWARMS.md`, `docs/SWARM_ARCHITECTURE.md`.

## Migration

Existing scripts invoking advanced commands continue to work unchanged.
New users should start with `install`, `doctor`, and `skills` only; adopt
advanced commands when running an ai-workspace-style harness.

## Exit-code contract (#48)

Consumer and advanced commands return integer status codes from their `cmd_*`
handlers. They must not call `sys.exit` for recoverable errors (missing
templates, unknown `--tools` values). argparse `--help` stays exit 0; bad
flags stay exit 2.
