# ADR-003: Retire gen-surfaces.py in Favor of agent-toolkit build --check

**Status:** Accepted  
**Date:** 2026-08-06  
**Deciders:** maintainers (Wave 3 #264, parent #263)  
**Depends on:** ADR-001 (canonical IR)

## Context

CI still requires `scripts/gen-surfaces.vsh --check` while ADR-001 points at the compiler + `distributions/products.yaml` as the source of truth. Contributors must keep two pipelines in sync:

- `gen-surfaces.py` hard-codes a `SURFACES` dict that copies a subset of `skills/` and `agents/` into `plugins/`
- `agent-toolkit build` loads the canonical IR (`distributions/products.yaml` + SKILL.md/AGENT.md) via `compiler/loader.py` and compiles per-target adapters under `compiler/targets/`

Dual write paths are accidental complexity and a maintenance tax. `gen-surfaces.py` cannot express per-target transforms, diagnostics (emit/transform/omit/unsupported), or product composition from YAML — the compiler can.

This ADR does **not** delete code; it records the decision and migration plan.

## Decision

`gen-surfaces.py` is deprecated. The canonical check is `agent-toolkit build --check` (from a checkout: `./make.vsh build-cli && ./build/agent-toolkit build --check`). There is no product uv workspace — do not `uv run agent-toolkit`.

- **Source of truth:** `distributions/products.yaml` + `skills/` + `agents/` + `compiler/targets/`
- **Build command:** `agent-toolkit build` (writes to `plugins/`), `agent-toolkit build --check` (drift detection, exit 1 on drift)
- **Legacy script:** `scripts/gen-surfaces.vsh` remains for backward compatibility until removal milestone, but is no longer authoritative

## Migration Checklist

### CI job swap

- [x] Current `validate.yml` job `check-surfaces` runs `v run scripts/gen-surfaces.vsh --check`
- [x] Add parallel job `check-build` that runs `./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check` (keep both during dual-run) — see #678
- [ ] After dual-run green for 30 days, flip `check-surfaces` to advisory (`continue-on-error: true`) or remove, making `check-build` the required check
- [ ] Update `RELEASING.md` bump → validate → tag checklist to use `build --check` instead of `gen-surfaces.py --check`

### Contributor docs

- [x] Update `docs/HOW_TO_ADD_SKILL.md` section 6 to document `agent-toolkit build --check` as primary verification, with `gen-surfaces.py --check` noted as legacy fallback
- [x] Update `docs/RELEASING.md` and `docs/ARCHITECTURE.md` to reference `distributions/products.yaml` + `agent-toolkit build`
- [ ] Update `CONTRIBUTING.md` if it mentions `gen-surfaces.py` directly (search and replace with compiler note)
- [ ] PR template checklist: replace `gen-surfaces.py --check` entry with `agent-toolkit build --check`

### How-tos

- Contributors (after ADR merge): `./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check`
- Maintainers: `agent-toolkit build` to regenerate `plugins/` before tagging a release
- CI debugging: compare `build --check --json` output (per-target emit/omit/unsupported) vs legacy drift lines

## Timeline / Milestones

| Phase | Window | Gate | Action |
|-------|--------|------|--------|
| **Deprecate** | v1.3.x (now) | ADR-003 accepted | Add deprecation header to `scripts/gen-surfaces.vsh`, keep CI required |
| **Dual-run** | v1.4.x – v1.5.x | Both checks pass on main for 30 days | Run `gen-surfaces --check` + `build --check` in parallel; document legacy fallback |
| **Remove** | v1.6.0+ | Maintainer vote after RELEASING checklist updated | Delete `scripts/gen-surfaces.vsh` and `check-surfaces` job; `build --check` is sole gate |

No file deletion occurs in the ADR PR itself. Deletion is deferred to the **Remove** milestone and requires a follow-up PR referencing this ADR.

## Alternatives Considered

- **Keep both permanently:** Rejected — doubles the surface for bugs and onboarding confusion.
- **Patch gen-surfaces.py to read products.yaml:** Rejected — reimplements compiler loader/adapter logic poorly; better to retire it.
- **Immediate deletion:** Rejected — breaks contributor flow before docs/CI are updated (violates CMP incrementalism).

## Consequences

- **Positive:** One write path; product composition lives in YAML, visible in PR diffs
- **Positive:** Per-target diagnostics (unsupported/omitted) become CI-visible
- **Negative (transitional):** Duplicate CI time during dual-run (~30–60s)
- **Risk:** Contributors unfamiliar with compiler may need guidance — mitigated by HOW_TO_ADD_SKILL update and `build --help`

## References

- ADR-001: Canonical IR (`docs/adrs/ADR-001-canonical-ir.md`)
- `packages/pypi/agent-toolkit-cli/src/agent_toolkit/cli/build.py` (`cmd_build` / `cmd_inventory`)
- `scripts/gen-surfaces.vsh`
- `.github/workflows/validate.yml` → jobs `check-surfaces`, `validate-products`
- `distributions/products.yaml`
