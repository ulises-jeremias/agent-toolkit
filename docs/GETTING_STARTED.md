# Getting Started

The fastest path from install to your first successful skill use.

## 1. Install (one primary method)

```bash
uv tool install agent-toolkit-cli
agent-toolkit install
```

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

You should see the assistant skill instructions load. Browse the full catalog: `catalogs/skill-catalog.yaml` (52 skills), regenerate with `python3 scripts/generate-catalogs.py`.

## Next steps

* **Agents:** see `agents/` (16 personas) and `catalogs/agent-catalog.yaml`
* **MCP:** see `mcp/` templates (placeholders only, add credentials locally)
* **Advanced CLI:** see [docs/SCOPE.md](SCOPE.md) and [docs/CLI_SURFACES.md](CLI_SURFACES.md) for the single-binary progressive disclosure model
* **Loops:** see `loops/` (10 templates) and `docs/HOW_TO_CREATE_LOOP.md`
* **Contributing:** see [CONTRIBUTING.md](../CONTRIBUTING.md) for CI parity (`uv sync --all-extras`, `AGENT_TOOLKIT_ROOT=$PWD uv run pytest tests/ -v`)

## Troubleshooting

* `agent-toolkit doctor` reports missing tool → install that tool first
* `inventory` empty → re-run `agent-toolkit install` with `--force`
* Broken install channel → prefer `uv tool install agent-toolkit-cli` (AUR pending)
