# V-default cutover

**Issue:** [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)  
**ADR:** [ADR-012](../adrs/ADR-012-python-v-coexistence.md)

V is the **canonical implementation** of consumer `agent-toolkit` (install lifecycle + skills/mcp/plugin). Python remains a **fallback package** for unfinished advanced commands and for PyPI/`uvx` until native binary wrappers ship ([#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) / [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529)).

## What changed

| Surface | Canonical | Notes |
|---------|-----------|--------|
| From-source CLI | V (`make build-cli` / `make install-cli`) | Installs `PREFIX/bin/agent-toolkit` (default `~/.local/bin`) |
| `doctor --json` / `version --json` | engine=`v`, version, commit | Human stdout unchanged (no engine/commit pollution) |
| Unfinished advanced commands | `not_implemented` in V | Use `agent-toolkit-py` (Python extra script); **no** in-process Python exec (ADR-012 rejected C) |
| PyPI `uvx` / `uv tool install` | Python wheel **until** binary wrappers | Transitional; not silent mixed engines |
| GitHub Release binaries | Experimental until MUST-platform promotion | See [rollback](rollback.md) |

## Experimental → stable promotion

Native artifacts stay **experimental** until [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562) / [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) MUST platforms have green smoke ([#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531)). Promotion is an explicit release decision — experimental assets must not overwrite stable channel names without that gate.

## Python fallback (advanced commands)

EPIC 5 remaining commands (`loop`, `swarm`, `devcompanion`, `insights`, `release`) may still be `not_implemented` in V. `workspace` (#520), `memory` (#521), and `project` (#522) are implemented in V. Run the Python CLI explicitly for unfinished advanced commands:

```bash
agent-toolkit-py loop status
# or:
uvx --from agent-toolkit-cli agent-toolkit loop status
```

Do **not** set an engine env var (ADR-012 rejected option B).

## Local V install

```bash
make install-cli                 # ~/.local/bin/agent-toolkit
make install-cli PREFIX=/usr/local
agent-toolkit doctor --json      # engine/version/commit
```

Parity harness still accepts `build/agent-toolkit-v` (copy of the canonical binary).
