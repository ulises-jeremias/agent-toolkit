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

Also: `version`, `help`, `completion` (bash/zsh/fish/PowerShell).

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
| `insights` | **DEPRECATE** — local usage analytics (OpenCode, Cursor, Claude); [#526](https://github.com/ulises-jeremias/agent-toolkit/issues/526) |
| `tui` | Interactive TUI dashboard — dashboard/loops/skills/doctor, ANSI colors, j/k nav, r run (no-llm) |
| `serve` | Web dashboard + API server (`vlib/veb`, 27 routes, `$embed_file` SPA) — `127.0.0.1:3847` default, `AGENT_TOOLKIT_TOKEN` for remote |
| `build` | Compile canonical capabilities into target artifacts |
| `inventory` | List skills, agents, and products |
| `matrix` | Platform capability matrix |
| `release` | **REMOVE** — release artifacts (CI / `docs/RELEASING.md`); [#527](https://github.com/ulises-jeremias/agent-toolkit/issues/527) |
| `swarm` | Multi-agent swarm orchestration (pair/team/full, Herdr/tmux, budgets, handoffs) |

Swarm details: `docs/SWARMS.md`, `docs/SWARM_ARCHITECTURE.md`.

V-port dispositions for advanced commands: [`docs/v/advanced-command-disposition.md`](v/advanced-command-disposition.md) (#560).

## Migration

Existing scripts invoking advanced commands continue to work unchanged.
New users should start with `install`, `doctor`, and `skills` only; adopt
advanced commands when running an ai-workspace-style harness.

## Migration inventory (#475)

Authoritative **index** of every top-level command — **23 commands** + `help` meta = **24 entries**, mirroring
[`docs/compatibility/cli-contract.yaml`](compatibility/cli-contract.yaml)
([#549](https://github.com/ulises-jeremias/agent-toolkit/issues/549), closed).
Machine-readable flags, stdin/stdout/stderr, exit codes, env, effects, and tests live in the contract YAML — do not duplicate here.
`insights` is **DEPRECATE** (no V port) and `release` is **REMOVE** (CI-only) — both match the contract `migration.disposition` (`defer`/`retire`).

Disposition for advanced commands: [`v/advanced-command-disposition.md`](v/advanced-command-disposition.md) (#560).
Wave/complexity/risk in the YAML `migration:` block.

| Command | Surface | Owner | Disposition |
|---------|---------|-------|-------------|
| `help` | meta | — | keep |
| `version` | meta | [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) | PORT (V canonical) |
| `install` | consumer | [#607](https://github.com/ulises-jeremias/agent-toolkit/issues/607) | PORT |
| `update` | consumer | [ADR-017](adrs/ADR-017-update-ownership.md) | PORT (capability-only) |
| `uninstall` | consumer | [#461](https://github.com/ulises-jeremias/agent-toolkit/issues/461) | PORT |
| `doctor` | consumer | [#514](https://github.com/ulises-jeremias/agent-toolkit/issues/514) | PORT |
| `diff` | consumer | [#515](https://github.com/ulises-jeremias/agent-toolkit/issues/515) | PORT |
| `skills` | consumer | [#517](https://github.com/ulises-jeremias/agent-toolkit/issues/517) | PORT |
| `mcp` | consumer | [#518](https://github.com/ulises-jeremias/agent-toolkit/issues/518) | PORT |
| `plugin` | consumer | [#519](https://github.com/ulises-jeremias/agent-toolkit/issues/519) | PORT |
| `completion` | consumer | [#544](https://github.com/ulises-jeremias/agent-toolkit/issues/544) | PORT |
| `loop` | advanced | [#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523) | REDESIGN |
| `workspace` | advanced | [#520](https://github.com/ulises-jeremias/agent-toolkit/issues/520) | PORT |
| `memory` | advanced | [#521](https://github.com/ulises-jeremias/agent-toolkit/issues/521) | PORT |
| `project` | advanced | [#522](https://github.com/ulises-jeremias/agent-toolkit/issues/522) | PORT |
| `devcompanion` | advanced | [#525](https://github.com/ulises-jeremias/agent-toolkit/issues/525) | PORT |
| `insights` | advanced | [#526](https://github.com/ulises-jeremias/agent-toolkit/issues/526) | **DEPRECATE** (no V requirement) |
| `build` | advanced | compiler EPIC | PORT (V `build` exists) |
| `inventory` | advanced | [#516](https://github.com/ulises-jeremias/agent-toolkit/issues/516) | PORT |
| `matrix` | advanced | compiler EPIC | PORT |
| `release` | advanced | [#527](https://github.com/ulises-jeremias/agent-toolkit/issues/527) | **REMOVE** (CI / `docs/RELEASING.md`) |
| `swarm` | advanced | [#524](https://github.com/ulises-jeremias/agent-toolkit/issues/524) | REDESIGN |
| `tui` | advanced | [#837](https://github.com/ulises-jeremias/agent-toolkit/issues/837) | PORT |
| `serve` | advanced | [#833](https://github.com/ulises-jeremias/agent-toolkit/issues/833) | PORT |

JSON/`--json` and full flag lists: `cli-contract.yaml`, not this table.

## Exit-code contract (#48)

Consumer and advanced commands return integer status codes from their `cmd_*`
handlers. They must not call `sys.exit` for recoverable errors (missing
templates, unknown `--tools` values). argparse `--help` stays exit 0; bad
flags stay exit 2.
