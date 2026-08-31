# Distributions — product composition (compiler input)

> **Not `distribution/`** — this directory is **compiler input** for marketplace plugins. `distribution/` (singular, [`../distribution/README.md`](../distribution/README.md)) is **documentation-only contracts** for packaging adapters (Homebrew, AUR, npm, PyPI, Docker).

Source of truth for product composition. Each product in [`products.yaml`](products.yaml) declares which `skills/`, `agents/`, `loops`, `hooks`, and `mcp` templates are included. The compiler (`agent-toolkit build` → `plugins/`) validates `build --check` and `catalogs/` consistency.

- **Input:** `products.yaml` + `targets/*.yaml`
- **Output:** `plugins/` (Agent Plugins, Claude/Cursor manifests, target-native bundles)
- **Validation:** `./scripts/validate-manifests.vsh`, `agent-toolkit build --check`, CI `check-skill-matrix`

See [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md#toolkit-internals-l15--build-pipeline) and [`docs/adrs/ADR-004-profiles-vs-plugins.md`](../docs/adrs/ADR-004-profiles-vs-plugins.md) for profiles vs plugins.
