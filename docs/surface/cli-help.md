# agent-toolkit CLI reference

_Generated from docs/compatibility/cli-contract.yaml — do not hand-edit._

## meta

| Command | Summary | Flags | Scope |
|---|---|---|---|
| `help` | Print consumer-first help text | — | `read:*` |
| `version` | Print agent-toolkit version string | — | `read:*` |

## consumer

| Command | Summary | Flags | Scope |
|---|---|---|---|
| `diff` | Show changes vs installed plugin bundles | `--tools` | `read:*` |
| `doctor` | Check toolkit data and tool availability | `--json` `--fix` | `read:*` |
| `install` | Install profiles for detected or selected AI tools | `--tools` `--dry-run` `--force` `--offline` `--json` | `write:fs` |
| `mcp` | MCP provider setup, health, doctor, uninstall | `setup` `list` `doctor` `uninstall` | `write:mcp` |
| `plugin` | Plugin bundle sync and check | `sync` `check` | `write:plugins` |
| `skills` | Sync, list, and validate skills | `sync` `list` `validate` | `write:catalog` |
| `uninstall` | Remove toolkit-owned files using install receipts | `--tools` `--force` | `write:fs` |
| `update` | Refresh installed profiles from latest toolkit data | `--check` `--offline` | `write:fs` |

## advanced

| Command | Summary | Flags | Scope |
|---|---|---|---|
| `build` | Compile canonical capabilities into target artifacts | `--target` `--product` | `write:plugins` |
| `devcompanion` | Background job queue | `queue` `run-once` `status` `done` `sync-todos` | `write:dc` |
| `insights` | Local usage analytics (OpenCode, Cursor, Claude) | `opencode` `cursor` `claude` | `read:*` |
| `inventory` | List skills, agents, and products | `--json` | `read:*` |
| `loop` | Loop engineering (init, run, status, audit, cost, schedule, sync) | `--runner` `init` `run` `status` `audit` `cost` `schedule` `sync` | `write:loops` |
| `matrix` | Platform capability matrix | `--json` | `read:*` |
| `memory` | Knowledge base (add, search, inject, review, todo) | `add` `search` `inject` `review` `todo` | `write:memory` |
| `project` | Project index (clone, list, add, remove, scan) | `clone` `list` `add` `remove` `scan` | `write:projects` |
| `release` | Generate release artifacts (maintainer / CI) | — | `write:*` |
| `swarm` | Multi-agent swarm orchestration | `--run-id` `pair` `team` `full` | `write:swarm` |
| `workspace` | Workspace scaffolding (init, context, sync) | `init` `context` `sync` `--dir` `--name` `--workspace` `--explain` `--json` | `write:workspace` |

