# Getting Started

The fastest path from install to your first successful skill use.

## 1. Install (one primary method)

```bash
uv tool install agent-toolkit-cli
agent-toolkit install
```

From a git checkout, the **canonical CLI implementation is V** ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)):

```bash
make install-cli    # ~/.local/bin/agent-toolkit
agent-toolkit doctor --json
```

PyPI/`uvx` still runs the Python wheel until native binary wrappers. Unfinished advanced commands: `uvx --from agent-toolkit-cli agent-toolkit <cmd>` (see [docs/v/cutover.md](v/cutover.md)). Rollback: [docs/v/rollback.md](v/rollback.md).

Alternatives: `uvx --from agent-toolkit-cli agent-toolkit install` (one-shot) or `yay -S agent-toolkit-cli && agent-toolkit install` on Arch Linux (AUR pending publish — use `uv` until RPC shows package).

See [docs/INSTALLATION.md](INSTALLATION.md) for full options.

## 2. Verify with doctor

```bash
agent-toolkit doctor
```

Expected: all detected tools show `installed` and `healthy`. If a tool is missing, install it first (e.g. Claude Code, Cursor, OpenCode).

## 3. Install core profile/plugin

```bash
agent-toolkit install --tools claude-code
# Check what is installed
agent-toolkit inventory
```

For Claude Code marketplace (alternative, no pip): `/plugin marketplace add ulises-jeremias/agent-toolkit` then `/plugin install agent-toolkit-core@agent-toolkit`.

## 4. Open a supported tool

Open Claude Code (or your tool from `agent-toolkit doctor` output) and confirm the plugin/skill is listed:

```bash
agent-toolkit inventory --tool claude-code
```

## 5. Invoke one named core skill

In your AI tool, invoke an existing core skill — e.g. `core/assistant`:

```
> Use the core/assistant skill to bootstrap this workspace
```

You should see the assistant skill instructions load. Browse the full catalog: `catalogs/skill-catalog.yaml` (61 skills), regenerate with `python3 scripts/generate-catalogs.py`.

## 6. Try Swarms (optional — multi-agent orchestration)

Swarms coordinate multiple coding-agent sessions with isolated Git worktrees and durable handoffs. Herdr is recommended, tmux is the portable fallback, and `--runner skeleton` lets you explore fully offline.

```bash
# Check swarm prerequisites (Herdr, tmux, runners, git)
agent-toolkit swarm doctor
agent-toolkit swarm backends --json
agent-toolkit swarm runners

# Explore recipes: pair (default), team, full
agent-toolkit swarm recipes
agent-toolkit swarm recipe show pair
agent-toolkit swarm models --runner opencode   # provider/model discovery

# Side-effect free dry-run — no worktrees, no LLM needed
agent-toolkit swarm plan --recipe pair --ui tmux --runner skeleton "Demo: add hello endpoint"

# Start a swarm — Herdr (recommended)
agent-toolkit swarm start --recipe pair --ui herdr --runner opencode --model-profile balanced "Implement issue #123"
# tmux fallback (works over SSH/headless)
agent-toolkit swarm start --recipe pair --ui tmux --runner opencode --model-profile balanced "Fix bug #42"

# Observe & operate
agent-toolkit swarm list
agent-toolkit swarm status RUN_ID --json
agent-toolkit swarm handoffs RUN_ID
agent-toolkit swarm artifacts RUN_ID
agent-toolkit swarm logs RUN_ID implementer
agent-toolkit swarm promote RUN_ID --to team   # elastic pair→team→full
agent-toolkit swarm approve RUN_ID --gate plan # human gate
```

- ** pair ** — implementer → reviewer/integrator → human approval (bugs, features).
- ** team ** — planner → implementer → reviewer → architect → human approval (medium features, requires plan approval).
- ** full ** — planner → implementer → refactorer → architect → hardener → qa → human approval (security/releases).
- Budgets: `max_total_tokens`, `max_cost_usd`, `max_wall_seconds`, concurrency/round-trip limits. Human gates: plan, architecture, cost escalation, final integration. State under `.agent-toolkit/swarm/runs/<run-id>/`.

Details: [SWARMS.md](SWARMS.md) (overview + quickstart), [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (diagrams + state machines), [SWARM_HERDR.md](SWARM_HERDR.md) (Herdr UI), [SWARM_TMUX.md](SWARM_TMUX.md) (tmux fallback), [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) (models/budgets), [SWARM_SECURITY.md](SWARM_SECURITY.md) (permissions/privacy).

Prerequisites: see [INSTALLATION.md — Swarms prerequisites](INSTALLATION.md#swarms--agent-toolkit-swarm-prerequisites) for Herdr/tmux/runner setup, or `agent_swarms.enabled=true` in [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) for auto-provision. Offline: `--runner skeleton` + `--ui tmux` works without Herdr or LLM.

## Next steps

* **Agents:** see `agents/` (16 personas) and `catalogs/agent-catalog.yaml`
* **MCP:** see `mcp/` templates (placeholders only, add credentials locally)
* **Advanced CLI:** see [docs/SCOPE.md](SCOPE.md) and [docs/CLI_SURFACES.md](CLI_SURFACES.md) for the single-binary progressive disclosure model
* **Loops:** see `loops/` (10 templates) and `docs/HOW_TO_CREATE_LOOP.md`
* **Swarms:** see `docs/SWARMS.md`, `docs/SWARM_ARCHITECTURE.md`, `docs/HOW_TO_CREATE_SWARM_RECIPE.md`
* **Contributing:** see [CONTRIBUTING.md](../CONTRIBUTING.md) for CI parity (`uv sync --project packages/pypi/agent-toolkit-cli --all-extras`, `AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v`)

## Troubleshooting

* `agent-toolkit doctor` reports missing tool → install that tool first
* `inventory` empty → re-run `agent-toolkit install` with `--force`
* Broken install channel → prefer `uv tool install agent-toolkit-cli` (AUR pending)

See also: [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for doctor error recipes.
