# packages/pypi

PyPI adapter sources. npm equivalent: [`packages/npm/`](../npm/).

| Directory | PyPI name | Role |
|-----------|-----------|------|
| `agent-toolkit-cli/` | `agent-toolkit-cli` | Thin launcher + quarantined Python fallback (`agent-toolkit-py`). CI stamps **platform-tagged wheels** of this single project. |

There are **no** `agent-toolkit-cli-linux-*` Python packages. npm uses `optionalDependencies` per OS; pip consumes PEP 425/600 tags on one distribution (see [`distribution/pypi/README.md`](../../distribution/pypi/README.md)).

## Published README

Consumers see [`agent-toolkit-cli/README.md`](agent-toolkit-cli/README.md) on PyPI (banner / install channels / CLI surfaces). Keep that file in sync with the npm meta-package tone.

## Why `src/` stays

`packages/pypi/agent-toolkit-cli/src/` is **required** — not obsolete after the V cutover ([ADR-021](../../docs/adrs/ADR-021-pypi-binary.md), [python-fallback.md](../../docs/v/python-fallback.md)):

| Path | Role |
|------|------|
| `src/agent_toolkit/launcher.py` | Product console scripts `agent-toolkit` / `agent-toolkit-cli` → `exec` the bundled V binary |
| `src/agent_toolkit/cli/` (+ compiler, installer, …) | Quarantined `agent-toolkit-py` fallback + pytest |
| `src/agent_toolkit/bin/` | Wheel-time home for the Release V binary (`scripts/pack_pypi.vsh`) |
| `src/agent_toolkit/data/` | Capability trees copied by `scripts/prepare-package-data.sh` before pack |

Hatchling builds from this `src` layout (`pyproject.toml` → `packages = ["src/agent_toolkit"]`). Deleting `src/` would break `uv tool install agent-toolkit-cli` and the thin-launcher product path (#540 closed with the launcher kept).
