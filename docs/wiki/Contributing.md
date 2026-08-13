# Contributing Guide

Canonical contributor docs:

- [`CONTRIBUTING.md`](../../CONTRIBUTING.md) — prerequisites, validation, PR checklist
- [`AGENTS.md`](../../AGENTS.md) — agent contract
- [`docs/HOW_TO_DEVELOP_V.md`](../HOW_TO_DEVELOP_V.md) — V CLI (product). Python is the PyPI launcher + tests only.

The repo is **not** a uv workspace and **not** installed with `pip install -e .`. Build the CLI with `make build-cli` → `build/agent-toolkit`.
