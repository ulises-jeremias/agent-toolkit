# PyPI thin V launcher

**Issue:** [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535)  
**ADR:** [ADR-021](../adrs/ADR-021-pypi-binary.md)

`agent-toolkit` and `agent-toolkit-cli` console scripts call `agent_toolkit.launcher:main`, which `exec`s (POSIX) or spawns (Windows) the bundled native binary. There is no Python business logic on that path.

| Script | Implementation |
|--------|----------------|
| `agent-toolkit` | V launcher |
| `agent-toolkit-cli` | V launcher (alias) |
| `agent-toolkit-py` | Python CLI (fallback until [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540)) |

Resolution order: `AGENT_TOOLKIT_BIN` → `agent_toolkit/bin/agent-toolkit` inside the wheel → `AGENT_TOOLKIT_ROOT/build/agent-toolkit{,-v}`.

Wheel builds: `scripts/prepare-native-bin.sh` after `make build-cli`. Hatch `hatch_build.py` sets `pure_python = False` when a native file is present so pip will not install a Linux wheel on macOS.

Missing binary exits **127** and points at `agent-toolkit-py` / `make build-cli`.
