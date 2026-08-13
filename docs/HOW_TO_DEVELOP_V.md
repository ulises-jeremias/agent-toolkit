# How to develop the V CLI

The **product** is a native V binary. Python is a thin PyPI launcher (`packages/pypi/agent-toolkit-cli`) plus a **quarantined** `agent-toolkit-py` fallback ([python-fallback.md](v/python-fallback.md)), scripts, tests, and pre-commit. Do not treat `uv run agent-toolkit` or a repo-root uv workspace as the product.

Index: [`docs/v/README.md`](v/README.md) · packaging adapters: [`distribution/README.md`](../distribution/README.md)

## Toolchain

| Item | Value |
|------|--------|
| V pin | [`.v-version`](../.v-version) — currently **0.5.2** |
| JSON | `import json` (stdlib). Do **not** `import json2` or run `v fmt` in a way that rewrites `json` → `json2` |
| Layout | `modules/agent_toolkit_core`, `modules/agent_toolkit_cli`, `cmd/agent-toolkit` ([ADR-009](adrs/ADR-009-v-module-architecture.md)) |
| Output | `make build-cli` → `build/agent-toolkit` |

```bash
v version          # second field must match .v-version
make fmt-check
make vet
make test
make build-cli
./build/agent-toolkit --version
./build/agent-toolkit doctor
```

`VMODULES` is set by the Makefile (`$PWD/modules`). For a raw `v` invocation:

```bash
export VMODULES="$PWD/modules"
v -o build/agent-toolkit cmd/agent-toolkit
```

## Python adapter (not the product)

Used for pytest parity, the PyPI launcher, and quarantined `agent-toolkit-py` ([#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) / ADR-021). **Do not delete the launcher.**

```bash
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
```

Never `uv run agent-toolkit` from repo root (there is no product uv workspace). To exercise the launcher:

```bash
uv run --project packages/pypi/agent-toolkit-cli --directory . agent-toolkit --version
# quarantined fallback (Python business logic, not the product):
uv run --project packages/pypi/agent-toolkit-cli --directory . agent-toolkit-py --help
```

## Build check (skills / plugins)

After changing `skills/`, `agents/`, `loops/`, or `distributions/`:

```bash
python3 scripts/validate-skills.py
python3 scripts/validate-agents.py
python3 scripts/generate-catalogs.py
python3 scripts/gen-surfaces.py --check
make build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
```

## Packaging (do not copy Formula/PKGBUILD here)

| Channel | Where |
|---------|--------|
| GitHub Release V binaries + `SHA256SUMS` | `.github/workflows/release.yml` · [`distribution/github-release`](../distribution/github-release/README.md) |
| PyPI launcher wheels | `packages/pypi/agent-toolkit-cli` · ADR-021 |
| npm + platform optionalDeps | `packages/npm/` · ADR-025 · OIDC `publish-npm.yml` |
| Homebrew Formula | [`ulises-jeremias/homebrew-tap`](https://github.com/ulises-jeremias/homebrew-tap) |
| AUR `agent-toolkit-bin` | [`ulises-jeremias/aur-packages`](https://github.com/ulises-jeremias/aur-packages) |

Release runbook: [`docs/RELEASING.md`](RELEASING.md). **Do not retag** empty historical tags (`v1.10.0` has no assets).

## Out of scope

P3 server/TUI and Bobatea ([#492](https://github.com/ulises-jeremias/agent-toolkit/issues/492)–[#494](https://github.com/ulises-jeremias/agent-toolkit/issues/494)) — do not invent APIs.
