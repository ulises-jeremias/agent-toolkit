# Rollback after V-default cutover

**Issue:** [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)

Rollback restores a **Python** `agent-toolkit` (or a previous V binary). Channels are independent — pick the one you installed from.

## GitHub (from-source / experimental binary)

```bash
# Remove V binary installed by make install-cli
rm -f ~/.local/bin/agent-toolkit

# Restore Python CLI on PATH
uv tool install agent-toolkit-cli
# or pin a previous release:
uv tool install agent-toolkit-cli==1.10.0
```

To run a previous V build: check out that git tag, `make build-cli`, `make install-cli`.

## PyPI

PyPI still publishes the Python wheel until binary wrappers ([#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535)):

```bash
uv tool install agent-toolkit-cli==<previous>
# or
pip install 'agent-toolkit-cli==<previous>'
```

`agent-toolkit-py` is the explicit Python entry after cutover (same package).

## Homebrew

Formulae live in the Homebrew tap (not this repo). Until the Homebrew epic ([#467](https://github.com/ulises-jeremias/agent-toolkit/issues/467) / [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538)), `brew` installs remain the Python formula. Rollback: `brew reinstall agent-toolkit` from the last known Python bottle, or `brew uninstall` and use `uv tool install`.

Do not overwrite a brew-managed binary with `make install-cli` (ADR-017 / [#489](https://github.com/ulises-jeremias/agent-toolkit/issues/489)).

## AUR

Until the AUR epic ([#468](https://github.com/ulises-jeremias/agent-toolkit/issues/468) / [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539)), Arch users install via `uv` or a Python PKGBUILD. Rollback: reinstall the previous `agent-toolkit-cli` package or `uv tool install agent-toolkit-cli==<previous>`.

## Verify engine

```bash
agent-toolkit doctor --json   # "engine": "v" or Python doctor without that key
agent-toolkit version --json  # V: engine + commit in data; human line unchanged
```
