# V `agent-toolkit install`

**Issue:** [#607](https://github.com/ulises-jeremias/agent-toolkit/issues/607) (EPIC 4 [#461](https://github.com/ulises-jeremias/agent-toolkit/issues/461))

Wires consumer `install` through [`InstallTransaction`](install-transaction.md):

- Flags: `--tools`, `--dry-run`, `--force`, `--offline` (dispatcher `--json`)
- Auto-detect; never auto-install Copilot (per-project; non-interactive skip)
- Prefer compiled `plugins/*/agents/*/AGENT.md` when present; skip `~/.claude/settings.json`
- Receipts for created artifacts; existing files (including JSON configs) are preserved without `--force`
- Honor `AGENT_TOOLKIT_OFFLINE` and `AGENT_TOOLKIT_INSTALL_SOURCE`

V is the in-repo canonical `agent-toolkit` entry ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)). PyPI/`uvx` still runs the Python wheel until native wrappers.
