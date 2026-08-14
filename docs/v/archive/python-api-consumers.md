# Python module API consumer audit

**Issue:** [#561](https://github.com/ulises-jeremias/agent-toolkit/issues/561)  
**Required by:** [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540)  
**Status:** Closed by v1.13.0 — Python CLI modules removed; PyPI is launcher-only ([python-fallback.md](python-fallback.md)).

The published PyPI/npm **product** is the CLI (V binary via trampoline). `import agent_toolkit` is **not** a supported library API beyond `__version__` and `launcher`.

## Method (2026-08-13; outcome applied 2026-08-14)

- GitHub code search and first-party trees (`agentic-workstation`, this repo).
- No first-party **library** consumers of `agent_toolkit.compiler` / `cli` / `installer` outside this repository.
- Workstation / harness / brew / AUR consume the **`agent-toolkit` command**, not Python imports.

## Inventory (current)

| Consumer | How it uses agent-toolkit | Notes |
|----------|---------------------------|--------|
| **This repo** | V CLI + `launcher.py` tests + packaging pytest | No Python CLI modules |
| **agentic-workstation** | CLI: `uv tool install` / `agent-toolkit install` | Command is V via launcher |
| **agentic-harness** | Documents CLI commands | CLI only |
| **homebrew-tap / aur-packages** | GitHub Release binary | No PyPI Python CLI |

Public Python surface today:

- `agent_toolkit.__version__` / `__author__`
- `agent_toolkit.launcher:main` (console scripts `agent-toolkit`, `agent-toolkit-cli`)

## Residual risk

Hypothetical external `from agent_toolkit.compiler…` against an **old** wheel is unsupported. New wheels do not ship those modules.
