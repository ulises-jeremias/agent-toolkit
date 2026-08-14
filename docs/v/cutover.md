# V-default cutover

**Issue:** [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)  
**ADR:** [ADR-012](../adrs/ADR-012-python-v-coexistence.md)

V is the **canonical implementation** of `agent-toolkit`. PyPI/`uvx` runs a **thin launcher** over the bundled V binary ([ADR-021](../adrs/ADR-021-pypi-binary.md) / [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535)). There is no Python CLI fallback ([python-fallback.md](python-fallback.md)).

## What changed

| Surface | Canonical | Notes |
|---------|-----------|--------|
| From-source CLI | V (`v run make.vsh build-cli` / `v run make.vsh install-cli`) | Installs `PREFIX/bin/agent-toolkit` (default `~/.local/bin`) |
| `doctor --json` / `version --json` | engine=`v`, version, commit | Human stdout unchanged (no engine/commit pollution) |
| Consumer + PORT/REDESIGN advanced | V | install lifecycle, skills/mcp/plugin, workspace/memory/project/loop/swarm/devcompanion |
| `insights` (DEPRECATE) / `release` (REMOVE) | disposition help / exit in V | Not ported; Python fallback removed |
| PyPI `uvx` / `uv tool install` | V binary via thin launcher (ADR-021) | npm-style trampoline only |
| GitHub Release binaries | Stable native V since `v1.11.0` | See [rollback](rollback.md). Do not retag empty `v1.10.0`. |

## Python CLI quarantine

Removed — see [python-fallback.md](python-fallback.md).

[#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) left `insights` as **DEPRECATE** and `release` as **REMOVE** — V need not port them. Run the Python CLI explicitly:

```bash
agent-toolkit-py insights opencode
# product command (V):
uvx --from agent-toolkit-cli agent-toolkit doctor
```

Do **not** set an engine env var (ADR-012 rejected option B).

## Local V install

```bash
v run make.vsh install-cli                 # ~/.local/bin/agent-toolkit
v run make.vsh install-cli PREFIX=/usr/local
agent-toolkit doctor --json      # engine/version/commit
```

Parity harness still accepts `build/agent-toolkit-v` (copy of the canonical binary).
