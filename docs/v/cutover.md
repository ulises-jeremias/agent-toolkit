# V-default cutover

**Issue:** [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)  
**ADR:** [ADR-012](../adrs/ADR-012-python-v-coexistence.md)

V is the **canonical implementation** of consumer `agent-toolkit` (install lifecycle + skills/mcp/plugin). Python remains a **fallback** via `agent-toolkit-py` for unfinished advanced commands. PyPI/`uvx` runs a **thin launcher** over the bundled V binary ([ADR-021](../adrs/ADR-021-pypi-binary.md) / [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535)).

## What changed

| Surface | Canonical | Notes |
|---------|-----------|--------|
| From-source CLI | V (`make build-cli` / `make install-cli`) | Installs `PREFIX/bin/agent-toolkit` (default `~/.local/bin`) |
| `doctor --json` / `version --json` | engine=`v`, version, commit | Human stdout unchanged (no engine/commit pollution) |
| Unfinished advanced commands | `not_implemented` in V | Use `agent-toolkit-py` (Python extra script); **no** in-process Python exec (ADR-012 rejected C) |
| PyPI `uvx` / `uv tool install` | V binary via thin launcher (ADR-021) | `agent-toolkit-py` is the Python fallback; not a dual-engine switch |
| GitHub Release binaries | Experimental until MUST-platform promotion | See [rollback](rollback.md) |

## Experimental → stable promotion

Native artifacts stay **experimental** until [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562) / [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) MUST platforms have green smoke ([#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531)). Promotion is an explicit release decision — experimental assets must not overwrite stable channel names without that gate.

## Python fallback (advanced commands)

EPIC 5 remaining commands (`insights`, `release`) may still be `not_implemented` in V. `workspace` (#520), `memory` (#521), `project` (#522), `devcompanion`/`dc` (#525), `loop` (#523, ADR-020 process-per-run), and `swarm` (#524, ADR-008 filesystem SoT) are implemented in V. Run the Python CLI explicitly for unfinished advanced commands:

```bash
agent-toolkit-py insights opencode
# product command (V):
uvx --from agent-toolkit-cli agent-toolkit doctor
```

Do **not** set an engine env var (ADR-012 rejected option B).

## Local V install

```bash
make install-cli                 # ~/.local/bin/agent-toolkit
make install-cli PREFIX=/usr/local
agent-toolkit doctor --json      # engine/version/commit
```

Parity harness still accepts `build/agent-toolkit-v` (copy of the canonical binary).
