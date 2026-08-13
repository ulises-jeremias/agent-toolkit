# Rollback after V-default cutover

**Issue:** [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)

The product is a **native V** binary on every channel. Rollback means pin a previous **V** release on the same channel — not switch back to Python as `agent-toolkit`.

`agent-toolkit-py` is a quarantined Python entry in the same PyPI wheel ([python-fallback.md](python-fallback.md)). It is not a channel rollback.

## GitHub Release

Download `agent-toolkit-<os>-<arch>` + `SHA256SUMS` from a previous tag (do **not** retag empty `v1.10.0`):

https://github.com/ulises-jeremias/agent-toolkit/releases

From a git checkout:

```bash
git checkout v1.11.0
make build-cli
make install-cli
```

To undo `make install-cli` only: `rm -f ~/.local/bin/agent-toolkit` (do not overwrite a brew/AUR/npm-managed binary — [ADR-017](../adrs/ADR-017-update-ownership.md)).

## PyPI

Wheels since `1.11.0` bundle V and exec it via the thin launcher ([ADR-021](../adrs/ADR-021-pypi-binary.md)):

```bash
uv tool install 'agent-toolkit-cli==1.11.0'
# or
pip install 'agent-toolkit-cli==1.11.0'
```

The console script `agent-toolkit-py` remains in the wheel as the quarantined fallback.

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
```
