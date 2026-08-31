# packages/pypi

<div align="center">

[![PyPI](https://img.shields.io/pypi/v/agent-toolkit-cli?style=flat&label=PyPI&labelColor=1f2937&color=7c3aed&logo=pypi&logoColor=white)](https://pypi.org/project/agent-toolkit-cli/)
[![PyPI downloads](https://img.shields.io/pypi/dm/agent-toolkit-cli?style=flat&label=downloads&labelColor=1f2937&color=0891b2)](https://pypi.org/project/agent-toolkit-cli/)
[![Python](https://img.shields.io/pypi/pyversions/agent-toolkit-cli?style=flat&labelColor=1f2937)](https://pypi.org/project/agent-toolkit-cli/)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)

</div>

PyPI adapter sources. npm equivalent: [`packages/npm/`](../npm/).

| Directory | PyPI name | Role |
|-----------|-----------|------|
| `agent-toolkit-cli/` | `agent-toolkit-cli` | **Thin trampoline** (same idea as npm’s `bin/agent-toolkit.js`) + platform-tagged wheels that embed the V binary and capability `data/`. |

There are **no** `agent-toolkit-cli-linux-*` Python packages. npm uses `optionalDependencies` per OS; pip consumes PEP 425/600 tags on one distribution (see [`distribution/pypi/README.md`](../../distribution/pypi/README.md)).

## Published README

Consumers see [`agent-toolkit-cli/README.md`](agent-toolkit-cli/README.md) on PyPI. Keep that file in sync with the npm meta-package tone.

## Why a tiny `src/` remains

PyPI installs a Python project so Hatch can emit console scripts. That package is **not** the CLI:

| Path | Role |
|------|------|
| `src/agent_toolkit/launcher.py` | `agent-toolkit` / `agent-toolkit-cli` → `exec` the bundled V binary (npm-style) |
| `src/agent_toolkit/__init__.py` / `__main__.py` | Version + `python -m agent_toolkit` |
| `src/agent_toolkit/bin/` | Wheel-time home for the Release V binary (`scripts/pack_pypi.vsh`) |
| `src/agent_toolkit/data/` | Capability trees from `scripts/prepare-package-data.sh` |

The old Python CLI (`cli/`, `compiler/`, `installer/`, …) and `agent-toolkit-py` were **removed**. Product logic and tests live in V (`modules/**`, `*_test.v`) and CI.
