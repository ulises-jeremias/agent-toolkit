# Contributing Guide

Canonical contributor docs:

- [`CONTRIBUTING.md`](../../CONTRIBUTING.md) — prerequisites, validation, PR checklist
- [`AGENTS.md`](../../AGENTS.md) — agent contract
- [`docs/HOW_TO_DEVELOP_V.md`](../HOW_TO_DEVELOP_V.md) — V CLI (product). Python is the PyPI launcher + tests only.

The repo is **not** a uv workspace and **not** installed with `pip install -e .`. Build the CLI with `v run make.vsh build-cli` → `build/agent-toolkit`.

## Wiki-style links (intentional)

Pages under `docs/wiki/` may use GitHub wiki-style links such as `[[Installation]]` or
wiki-relative targets. These look broken when browsing the git tree, but **wiki-sync**
(`.github/workflows/wiki-sync.yml`) publishes this mirror to the GitHub Wiki where those
links resolve. Do **not** mass-convert them to relative markdown without checking the
wiki-sync pipeline.

