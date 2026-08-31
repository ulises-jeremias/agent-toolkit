# Rollback after V-default cutover

**Issue:** [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)

The product is a **native V** binary on every channel. Rollback means pin a previous **V** release on the same channel — not switch back to Python as `agent-toolkit`.

There is no Python CLI fallback ([python-fallback.md](python-fallback.md)). Channel rollback means reinstalling a prior V binary / wheel. Historical drop is `9163c93` (`2026-08-14 01:20:52 -0300 chore(pypi): drop Python CLI quarantine; keep npm-style V trampoline`); last Python swarm is `fbb2280` (`2026-08-12 fix(ci): always tag Docker images`).

## Historical rollback point

- `fbb2280` — last with `packages/pypi/.../swarm` (95 files incl `launcher.py`, old prefix `packages/agent-toolkit-cli/src/agent_toolkit/swarm` before `2fbb503 pypi layout` → new `modules/agent_toolkit_core/`)
- `9163c93` — deletes 14 `packages/pypi/.../swarm` + 33 `cli/*` + keeps `hatch_build.py` + `launcher.py` trampoline that prefers `build/agent-toolkit` (`make.vsh:160` `build-cli`: `vcmd('-d commit=${commit} -o ${out} ${join_path(r, "cmd/agent-toolkit")}')` + `cp build/agent-toolkit-v`)

To inspect the deleted Python implementation:

```bash
git checkout fbb2280 -- packages/pypi/agent-toolkit-cli/src/agent_toolkit/swarm/
git show fbb2280:packages/pypi/agent-toolkit-cli/src/agent_toolkit/launcher.py | sed -n '1,40p'
git show --stat 9163c93 | head -n 40
```

For dev fallback the trampoline resolves `AGENT_TOOLKIT_ROOT=$PWD` → `build/agent-toolkit` built by `./make.vsh build-cli` (`VMODULES=$(pwd)/modules` vs `embedded_data.v` bundling via `scripts/generate-embedded-data.vsh`).

## GitHub Release

Download `agent-toolkit-<os>-<arch>` + `SHA256SUMS` from a previous tag (do **not** retag empty `v1.10.0`):

https://github.com/ulises-jeremias/agent-toolkit/releases

From a git checkout:

```bash
git checkout v1.11.0
./make.vsh build-cli
./make.vsh install-cli
# dev flow per docs/HOW_TO_DEVELOP_V.md (V 0.5.2, import json not json2):
./make.vsh test && ./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
```

To undo `./make.vsh install-cli` only: `rm -f ~/.local/bin/agent-toolkit` (do not overwrite a brew/AUR/npm-managed binary — [ADR-017](../adrs/ADR-017-update-ownership.md)).

## PyPI

Wheels since `1.11.0` bundle V and exec it via the thin launcher ([ADR-021](../adrs/ADR-021-pypi-binary.md)):

```bash
uv tool install 'agent-toolkit-cli==1.11.0'
# or
pip install 'agent-toolkit-cli==1.11.0'
```

The wheel only ships the thin V trampoline + embedded binary + data (`packages/pypi/agent-toolkit-cli/src/agent_toolkit/launcher.py` → `agent_toolkit/bin/agent-toolkit` + `AGENT_TOOLKIT_ROOT=$PWD` fallback; `hatch_build.py` trampoline delegates to V).

Previous fallback `agent-toolkit-py` was removed at `9163c93`.

## Homebrew

Formulae live in [`ulises-jeremias/homebrew-tap`](https://github.com/ulises-jeremias/homebrew-tap) and install GitHub Release V binaries ([ADR-023](../adrs/ADR-023-homebrew.md)).

```bash
brew reinstall agent-toolkit
# or pin a tap revision / previous formula version
```

## AUR

Canonical package is **`agent-toolkit-bin`** ([ADR-024](../adrs/ADR-024-aur.md)):

```bash
yay -S agent-toolkit-bin
```

Optional Python `agent-toolkit` PKGBUILD is not the product.

## Verify engine

```bash
agent-toolkit doctor --json   # "engine": "v"
agent-toolkit version --json  # V: engine + commit in data; human line unchanged
# also
cat .v-version  # 0.5.2 import json not json2
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit doctor --json | grep '"engine": "v"'
```

See also: [cutover.md](cutover.md) (9163c93 drop), [python-fallback.md](python-fallback.md), `docs/HOW_TO_DEVELOP_V.md` dev flow (`./make.vsh test && build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check` + `uv sync --project packages/pypi/agent-toolkit-cli --all-extras`).

Archived version: [archive/rollback.md](archive/rollback.md).
