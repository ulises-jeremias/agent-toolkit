# How to develop the V CLI

The **product** is a native V binary. Python on PyPI is only a thin trampoline (`packages/pypi/agent-toolkit-cli`, [python-fallback.md](v/python-fallback.md)). CLI tests live in V (`modules/**/*_test.v`). Do not treat a repo-root uv workspace as the product.

Index: [`docs/v/README.md`](v/README.md) · packaging adapters: [`distribution/README.md`](../distribution/README.md)

## Toolchain

| Item | Value |
|------|--------|
| V pin | [`.v-version`](../.v-version) — currently **0.5.2** |
| JSON | `import json` (stdlib). Do **not** `import json2` or run `v fmt` in a way that rewrites `json` → `json2` |
| Layout | `modules/agent_toolkit_core`, `modules/agent_toolkit_cli`, `cmd/agent-toolkit` ([ADR-009](adrs/ADR-009-v-module-architecture.md)) |
| Output | `./make.vsh build-cli` → `build/agent-toolkit` |
| Scripts | Repo tooling is `.vsh` with shebang — run `./scripts/…` (not `v run scripts/…`); task runner is `./make.vsh` ([vlib `build`](https://github.com/vlang/v/tree/master/vlib/build), [example](https://github.com/vlang/v/blob/master/examples/build_system/build.vsh)) — no Makefile |

```bash
v version          # second field must match .v-version
./make.vsh --tasks   # list targets (or `./make.vsh help`)
./make.vsh fmt-check
./make.vsh vet
./make.vsh test
./make.vsh build-cli
./build/agent-toolkit --version
./build/agent-toolkit doctor
# optional: precompile the task runner → ./make (gitignored)
# ./make.vsh compile-make && ./make test
# install: ./make.vsh install-cli [--prefix=/usr/local]  (PREFIX env also works)
```

`VMODULES` is set by `make.vsh` (`$PWD/modules`). For a raw `v` invocation:

```bash
export VMODULES="$PWD/modules"
v -o build/agent-toolkit cmd/agent-toolkit
```

## Python adapter (not the product)

Used for the PyPI trampoline and packaging pytest ([#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) / ADR-021). **Do not delete the launcher.**

```bash
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
```

Never `uv run agent-toolkit` from repo root (there is no product uv workspace). To exercise the launcher:

```bash
uv run --project packages/pypi/agent-toolkit-cli --directory . agent-toolkit --version
# launcher smoke (still execs the V binary via AGENT_TOOLKIT_BIN / wheel bin):
uv run --project packages/pypi/agent-toolkit-cli --directory . agent-toolkit --help
```

## npm adapter (not the product)

Thin Node launcher over the same Release V binaries ([ADR-025](adrs/ADR-025-npm-binary.md)). Tests use `node --test` (no V compile):

```bash
npm test --prefix packages/npm/agent-toolkit-cli
```

CI runs this matrix on Node **22** and **24** (`validate.yml` → `test-npm`). Pytest also invokes the same suite via `tests/test_npm_launcher.py` when `node` is on `PATH`.

## Build check (skills / plugins)

After changing `skills/`, `agents/`, `loops/`, or `distributions/`:

```bash
./scripts/validate-skills.vsh
./scripts/validate-agents.vsh
./scripts/generate-catalogs.vsh
./make.vsh build-cli
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

P3 server ([#492](https://github.com/ulises-jeremias/agent-toolkit/issues/492)–[#494](https://github.com/ulises-jeremias/agent-toolkit/issues/494); the TUI was retired in 1.23.0 per ADR-030) — do not invent APIs.
