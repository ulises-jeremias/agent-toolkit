# Python on PyPI = trampoline only (quarantine removed)

The product command is the **native V binary**.

`agent-toolkit` / `agent-toolkit-cli` on PyPI are a **thin launcher** (same idea as [`packages/npm/agent-toolkit-cli/bin/agent-toolkit.js`](../../packages/npm/agent-toolkit-cli/bin/agent-toolkit.js)): resolve the bundled binary under `agent_toolkit/bin/`, set `AGENT_TOOLKIT_ROOT` to wheel `data/` when needed, then `exec` V.

## 9163c93 — fallback removed (2026-08-14)

At `9163c93` (`2026-08-14 01:20:52 -0300 chore(pypi): drop Python CLI quarantine; keep npm-style V trampoline`) the Python CLI was deleted — `git show --stat 9163c93` deletes 14 `packages/pypi/.../swarm` + 33 `cli/*` files and keeps only `packages/pypi/agent-toolkit-cli/hatch_build.py` + `src/agent_toolkit/launcher.py` trampoline that prefers `build/agent-toolkit` (`make.vsh:160` `build-cli`: `vcmd('-d commit=${commit} -o ${out} ${join_path(r, "cmd/agent-toolkit")}')` + `cp build/agent-toolkit-v`). There is no Python swarm fallback; `packages/pypi/.../swarm` no longer exists (last at `fbb2280` `2026-08-12 fix(ci): always tag Docker images` with 95 files incl `launcher.py`).

Old prefix `packages/agent-toolkit-cli/src/agent_toolkit/swarm` (pre `2fbb503 pypi layout`) → new `modules/agent_toolkit_core/` (`VMODULES=$(pwd)/modules` or `embedded_data.v` bundling via `scripts/generate-embedded-data.vsh`).

## Removed

| Former surface | Status |
|----------------|--------|
| `agent-toolkit-py` console script | **Removed** |
| `agent_toolkit.cli` / `compiler` / `installer` / … | **Removed** |
| Python pytest suite for CLI business logic | **Removed** — coverage is `modules/**/*_test.v` + parity fixtures + integration CI |

`insights` (#526 DEPRECATE) and `release` (#527 REMOVE) are **not** available via a Python fallback anymore. See [advanced-command-disposition.md](advanced-command-disposition.md).

## What stays in Python

- PyPI trampoline (`launcher.py`) — `AGENT_TOOLKIT_BIN` → `agent_toolkit/bin/agent-toolkit` → `AGENT_TOOLKIT_ROOT/build/agent-toolkit{,-v}`
- Packaging / docs / schema pytest that does **not** import a Python CLI
- Contributor scripts that are still `.py` only where noted (e.g. `validate-upstream.py` / provenance)

## Rollback point

`fbb2280` is the last commit with the Python swarm alive; `9163c93` is the drop. To inspect the deleted implementation:

```bash
git checkout fbb2280 -- packages/pypi/agent-toolkit-cli/src/agent_toolkit/swarm/
# or view at fbb2280:packages/pypi/agent-toolkit-cli/src/agent_toolkit/launcher.py
```

Production rollback is a **V** binary pin, not Python — see [rollback.md](rollback.md).

## Dev flow (V)

Per `docs/HOW_TO_DEVELOP_V.md` (V pin `0.5.2`, `import json` not `json2`):

```bash
./make.vsh test && ./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
# packaging pytest parity (launcher only, no Python CLI):
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
# or launcher smoke:
uv run --project packages/pypi/agent-toolkit-cli --directory . agent-toolkit --version
```

## See also

- [ADR-021](../adrs/ADR-021-pypi-binary.md) — PyPI ships the V binary via thin launcher
- [pypi-launcher.md](pypi-launcher.md) — `uv tool install 'agent-toolkit-cli>=1.11.0'` + `AGENT_TOOLKIT_ROOT=$PWD` + `VMODULES=$(pwd)/modules` vs `embedded_data`
- [cutover.md](cutover.md) — `9163c93` drop narrative
- [rollback.md](rollback.md) — rollback point `fbb2280`
- `docs/compatibility/cli-contract.yaml` vs `docs/CLI_SURFACES.md` — `serve`/`tui` V-extra (no `parity.yml`)
