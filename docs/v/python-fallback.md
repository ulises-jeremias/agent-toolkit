# Python on PyPI = trampoline only (quarantine removed)

The product command is the **native V binary**.

`agent-toolkit` / `agent-toolkit-cli` on PyPI are a **thin launcher** (same idea as [`packages/npm/agent-toolkit-cli/bin/agent-toolkit.js`](../../packages/npm/agent-toolkit-cli/bin/agent-toolkit.js)): resolve the bundled binary under `agent_toolkit/bin/`, set `AGENT_TOOLKIT_ROOT` to wheel `data/` when needed, then `exec` V.

## Removed

| Former surface | Status |
|----------------|--------|
| `agent-toolkit-py` console script | **Removed** |
| `agent_toolkit.cli` / `compiler` / `installer` / … | **Removed** |
| Python pytest suite for CLI business logic | **Removed** — coverage is `modules/**/*_test.v` + parity fixtures + integration CI |

`insights` (#526 DEPRECATE) and `release` (#527 REMOVE) are **not** available via a Python fallback anymore. See [advanced-command-disposition.md](advanced-command-disposition.md).

## What stays in Python

- PyPI trampoline (`launcher.py`)
- Packaging / docs / schema pytest that does **not** import a Python CLI
- Contributor scripts that are still `.py` only where noted (e.g. `validate-upstream.py` / provenance)

## See also

- [ADR-021](../adrs/ADR-021-pypi-binary.md) — PyPI ships the V binary via thin launcher
- [pypi-launcher.md](pypi-launcher.md)
- [cutover.md](archive/cutover.md)
