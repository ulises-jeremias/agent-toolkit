# Python CLI quarantine (named fallback)

**Gate:** [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) · **ADR:** [ADR-021](../adrs/ADR-021-pypi-binary.md)

The product command is the **native V binary**. `agent-toolkit` / `agent-toolkit-cli` are a thin PyPI launcher that `exec`s that binary. Python business logic is **quarantined** behind `agent-toolkit-py` and is not the product.

## What stays

| Surface | Role |
|---------|------|
| `packages/pypi/agent-toolkit-cli` launcher | Permanent PyPI adapter (`uv tool install agent-toolkit-cli`). **Do not delete.** |
| `agent-toolkit-py` | Named fallback for [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **DEPRECATE** `insights` and **REMOVE** `release`, plus first-party pytest |
| `scripts/` + pytest + pre-commit | Tooling, not the product CLI |

## What is not the product

- `agent_toolkit.cli`, `compiler/`, `installer/`, `loop/`, `swarm/` — in-tree Python implementation, unsupported as a library API ([python-api-consumers.md](python-api-consumers.md))
- `python -m agent_toolkit.cli` — same quarantined entry as `agent-toolkit-py`
- `python -m agent_toolkit` — launcher (V), not Python business logic

Interactive `agent-toolkit-py` prints a stderr notice (silence with `AGENT_TOOLKIT_PY_QUIET=1`). Non-TTY / CI captures are quiet by default.

## Why the modules are not deleted

EPIC 13 ([#470](https://github.com/ulises-jeremias/agent-toolkit/issues/470)) retires Python as the **product** runtime. ADR-021 keeps a thin Python **process** on PyPI. Deleting `cli/` would break pytest parity and the documented `insights` fallback. That is not required to close #540.

Future deletion of `agent-toolkit-py` is optional cleanup after `insights` is dropped; it is **not** a V CLI GA blocker.

## See also

- [cutover.md](cutover.md) · [rollback.md](rollback.md) · [pypi-launcher.md](pypi-launcher.md) · [HOW_TO_DEVELOP_V.md](../HOW_TO_DEVELOP_V.md)
