# packages/pypi

PyPI adapter sources. npm equivalent: [`packages/npm/`](../npm/).

| Directory | PyPI name | Role |
|-----------|-----------|------|
| `agent-toolkit-cli/` | `agent-toolkit-cli` | Thin launcher + quarantined Python fallback (`agent-toolkit-py`). CI stamps **platform-tagged wheels** of this single project. |

There are **no** `agent-toolkit-cli-linux-*` Python packages. npm uses `optionalDependencies` per OS; pip consumes PEP 425/600 tags on one distribution (see [`distribution/pypi/README.md`](../../distribution/pypi/README.md)).
