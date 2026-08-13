# PyPI adapter

**Issue:** [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) · **ADR:** [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486)

**Today:** distribution name `agent-toolkit-cli`; console scripts `agent-toolkit` / `agent-toolkit-cli` (Python implementation).

**Target:** PyPI remains an **adapter**, not a second CLI. Prefer platform wheels containing the native binary plus a thin launcher (strategy A in #486). Keep the PyPI **distribution** name `agent-toolkit-cli` unless a coordinated rename is decided in that ADR. Command name stays `agent-toolkit`.

Wrapper constraints (when implemented): forward argv, signals, and exit codes; no forked business logic.

This directory does **not** vendor `setup.py` / wheel internals.
