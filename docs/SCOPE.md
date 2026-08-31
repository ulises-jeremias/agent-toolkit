# CLI scope — consumer vs advanced

The `agent-toolkit` CLI exposes two surfaces:

## Consumer commands (default product)

For installing and using skills, agents, and MCP in day-to-day coding:

| Command | Purpose |
|---------|---------|
| `install` | Copy profiles or compiler artifacts to tool config dirs |
| `doctor` | Verify toolkit data and tool availability |
| `diff` | Compare compiled plugins vs working tree |
| `build` | Compile products into target-native plugin bundles |
| `inventory` / `matrix` | Inspect canonical catalog and platform matrix |
| `skills` | Sync/list/validate skills |
| `mcp` | Configure MCP providers (setup, health, doctor, uninstall) |
| `plugin` | Sync/check marketplace plugin bundles |

## Advanced commands (workstation harness)

Multi-repo memory, background job queues, and loop automation —
intended for maintainers and ai-workspace-style setups, **not** the default
marketplace consumer path:

| Command | Purpose |
|---------|---------|
| `loop` | Run scheduled automation templates |
| `workspace` | Scaffold multi-repo workspace context |
| `memory` | Local knowledge base CRUD |
| `project` | Project index / clone helpers |
| `devcompanion` | Background LLM job queue |
| `swarm` | Multi-agent swarm orchestration (pair/team/full, Herdr/tmux) |

These commands remain available without a separate binary; help text lists
them under **Advanced commands** so new users are not overwhelmed.

### Disposition (not primary advanced UX)

| Command | Disposition | Tracking |
|---------|-------------|----------|
| `insights` | **DEPRECATE** (no V port requirement) | [#526](https://github.com/ulises-jeremias/agent-toolkit/issues/526), [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) |
| `release` | **REMOVE** (CI / `docs/RELEASING.md`) | [#527](https://github.com/ulises-jeremias/agent-toolkit/issues/527) |

`insights` may still be wired for back-compat; do not present it as a recommended harness command.
`release` is maintainer/CI-only and is being removed from the product CLI surface.

See also: [`CLI_SURFACES.md`](CLI_SURFACES.md), `docs/CONCEPTS.md`, `docs/INSTALLATION.md`.
