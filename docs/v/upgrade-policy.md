# V compiler pin and upgrade policy

**Issue:** [#496](https://github.com/ulises-jeremias/agent-toolkit/issues/496)  
**Program:** [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)

## Pin

The repository pins the V compiler with a root [`.v-version`](../../.v-version) file.

Current pin: **0.5.2** (must match local `v version` major.minor.patch used in CI once V jobs land).

## Upgrade procedure

1. Open a dedicated PR that **only** changes `.v-version` (and this doc if process changes).
2. On that PR (or an immediate follow-up):
   - Re-run `make fmt-check vet test build` for `modules/*`
   - Re-run YAML/schema fixtures that depend on `vlib/yaml` ([ADR-013](../adrs/ADR-013-yaml-strategy.md))
   - Re-run parity seed fixtures when the harness exists ([#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548))
3. Merge only when those checks are green.
4. Do **not** silently float to `v` master/`weekly` in CI for release builds.

## Non-goals

- Auto-upgrading the pin via unattended Renovate without a human-reviewed parity pass (Renovate may open the PR; humans merge after green).

**Verified:** 2026-08-12
