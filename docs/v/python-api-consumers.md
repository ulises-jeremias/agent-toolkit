# Python module API consumer audit

**Issue:** [#561](https://github.com/ulises-jeremias/agent-toolkit/issues/561)  
**Required by:** [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) (gates met; Python remains quarantined fallback, not a library API)

The published PyPI/npm **product** is the CLI. `import agent_toolkit` is not a supported library API. This audit lists who would break if the Python package were removed or reduced to a launcher-only wheel.

## Method (2026-08-13)

- GitHub code search: `import agent_toolkit`, `from agent_toolkit.`, `agent_toolkit.cli`, `agent_toolkit.compiler`, `agent_toolkit.installer` (first-party owner `ulises-jeremias` and global).
- Local trees: `agentic-workstation`, this repo.
- Workstation install path: `docs/AGENT_TOOLKIT.md` in agentic-workstation.

## Inventory

| Consumer | How it uses agent-toolkit | Breakage if Python modules go away |
|----------|---------------------------|------------------------------------|
| **This repo** (`packages/pypi/agent-toolkit-cli`, `tests/`) | First-party: `agent_toolkit.cli`, `compiler`, `installer`, `launcher` | Expected. Tests already use `agent-toolkit-py` / `-m agent_toolkit.cli` where the product launcher would exec V. |
| **agentic-workstation** | CLI only: `uv tool install --force agent-toolkit-cli && agent-toolkit install` | **None** for library imports. Breaks only if the `agent-toolkit` **command** disappears. After ADR-021 the command is the V launcher. |
| **agentic-harness** / ai-workspace | Documents CLI (`agent-toolkit workspace`, `memory`, …). No `import agent_toolkit`. | None (CLI). |
| **homebrew-tap / aur-packages** | Install GitHub Release **binary**, not the Python package | None. |
| **Unrelated GitHub projects** named `agent_toolkit` (DSPy examples, other toolkits) | Different packages | Out of scope. |

No first-party or known downstream **library** import of `ulises-jeremias/agent-toolkit`’s `agent_toolkit.*` was found outside this repository.

Public import surface today:

- `agent_toolkit.__version__` / `__author__`
- `agent_toolkit.launcher:main` (product scripts `agent-toolkit`, `agent-toolkit-cli`)
- `agent_toolkit.cli.main:main` (`agent-toolkit-py`, `python -m agent_toolkit.cli`)

`compiler/` and `installer/` are in-tree implementation, not a versioned library API.

## Migration plan

| Audience | Plan |
|----------|------|
| CLI users (`uvx`, brew, AUR, npm) | Stay on the V binary / launcher. No Python import migration. |
| In-repo tests | Keep calling `agent-toolkit-py` / `-m agent_toolkit.cli` (quarantined fallback; [python-fallback.md](python-fallback.md)). |
| Hypothetical external `import agent_toolkit.compiler` | Unsupported. If discovered later: treat as a bug, add a shim issue. |
| `#540` checklist | Cited: “#561 audit: no first-party library consumers; workstation/harness are CLI-only.” |

## Residual risk

PyPI `agent-toolkit-cli` still ships quarantined Python modules in the same wheel as the launcher. Someone *could* `from agent_toolkit.compiler.loader import load_graph` without us knowing (no telemetry). That is not a supported contract.
