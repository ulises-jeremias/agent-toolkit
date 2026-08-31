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
| `completion` | Emit bash/zsh/fish/PowerShell completion scripts | `bash` `zsh` `fish` `powershell` | `read:*` |
| `diff` | Show changes vs installed plugin bundles | `--target` `--product` | `read:*` |
| `doctor` | Check toolkit data and tool availability | `--json` `--fix` `--provenance` | `read:*` |
| `install` | Install profiles for detected or selected AI tools | `--tools` `--dry-run` `--force` `--offline` `--json` | `write:fs` |
| `mcp` | MCP provider setup, health, doctor, uninstall | `setup` `list` `doctor` `uninstall` | `write:mcp` |
| `plugin` | Plugin bundle sync and check | `sync` `check` | `write:plugins` |
| `skills` | Sync, list, and validate skills | `sync` `list` `validate` | `write:catalog` |
| `uninstall` | Remove toolkit-owned files using install receipts | `--tools` `--dry-run` `--rollback` | `write:fs` |
| `update` | Refresh installed profiles from latest toolkit data | `--tools` `--check` `--pin` | `write:fs` |

## advanced

| Command | Summary | Flags | Scope |
|---|---|---|---|
| `build` | Compile canonical capabilities into target artifacts | `--target` `--product` | `write:plugins` |
| `devcompanion` | Background job queue + LLM policy status | `queue` `run-once` `status` `done` `sync-todos` `llm-status` | `write:dc` |
| `insights` | AI tool usage insights — opencode, cursor, claude, windsurf, copilot, codex, all | `opencode` `cursor` `claude` `windsurf` `copilot` `codex` `all` `--days` `--output` `--no-llm` `--json` | `read:*` |
| `inventory` | List skills, agents, and products | `--json` | `read:*` |
| `loop` | Loop engineering (init, run, status, audit, cost, schedule, sync, list, templates) | `--runner` `init` `run` `status` `audit` `cost` `schedule` `sync` `list` `ls` `templates` | `write:loops` |
| `matrix` | Platform capability matrix | `--json` | `read:*` |
| `memory` | Knowledge base (add, search, inject, review, todo) | `add` `search` `inject` `review` `todo` | `write:memory` |
| `project` | Project index and scaffolding (init, clone, list, add, remove, scan) | `init` `clone` `list` `add` `remove` `scan` `OWNER/REPO` | `write:projects` |
| `serve` | Run the programmatic API server (headless runtime surface over core) | `--host` `--port` `--allow-remote` `--auth-token` `--no-browser` | `read:*` |
| `swarm` | Multi-agent swarm orchestration | `recipes` `recipe` `backends` `doctor` `runners` `models` `start` `list` `ls` `status` `approve` `reject` `cancel` `prune` `init` `plan` `activate` `deactivate` `promote` `pause` `resume` `stop` `cleanup` `watch` `report` `artifacts` `handoffs` `logs` `approvals` `handoff` `task` `attach` `--recipe` `--backend` `--runner` `--model-profile` `--run-id` `--workspace` `--json` `--dry-run` `--attach` `--no-attach` `--type` `--from` `--to` `--commit` `--branch` `--priority` `--artifact` `--blocking` `--older-than` `--force` | `write:swarm` |
| `workspace` | Workspace lifecycle (init, context, sync, use-persona, handoff, history, personas, load, profiles, validate, budget) | `init` `context` `sync` `use-persona` `handoff` `history` `personas` `load` `profiles` `validate` `budget` `--dir` `--name` `--workspace` `--explain` `--json` | `write:workspace` |

