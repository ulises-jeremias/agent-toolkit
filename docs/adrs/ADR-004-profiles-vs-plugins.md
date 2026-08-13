# ADR-004: Profiles vs Plugins — Source of Truth, Install Path, and Deprecation Timeline

**Status:** Accepted  
**Date:** 2026-08-06  
**Deciders:** maintainers (Wave 3 #265, parent #263)  
**Depends on:** ADR-001 (canonical IR), ADR-003 (gen-surfaces retirement)

## Context

`profiles/` (legacy hand-copied layouts per tool) and `plugins/` (compiler-generated marketplace bundles) coexist without a clear deprecation timeline. `CONCEPTS.md` mentions the direction but contributors still guess which directory to edit.

Four composition nouns (products / packs / profiles / plugins) overload newcomers. This ADR clarifies the intended path and what to edit.

## Decision

- **Canonical content (SoT):** `skills/` + `agents/` + `loops/` + `catalogs/` + `distributions/products.yaml`
- **Generated output:** `plugins/` is **compiler output** (via `agent-toolkit build`). It is not hand-edited.
- **Legacy install layout:** `profiles/` is **deprecated** for marketplace delivery; it remains as the *install-copy* source until the installer fully consumes compiled `plugins/` + `installer/sources.py`.

| Artifact | Edit? | Origin | Consumer |
|----------|-------|--------|----------|
| `skills/<domain>/<name>/SKILL.md` | **Yes** — create/edit | human-authored | compiler loader |
| `agents/<name>/AGENT.md` | **Yes** | human-authored | compiler loader |
| `distributions/products.yaml` | **Yes** — product composition | human-authored YAML | `agent-toolkit build` |
| `plugins/<product>/` | **Never** — generated | `agent-toolkit build` output | marketplace verification, `installer/sources.py` (preferred) |
| `profiles/<tool>/` | **Minimize** — deprecated path | legacy hand layouts | `agent-toolkit install` fallback when `plugins/` absent |
| `packs/` | Docs-only bundle | README + config | team workflow templates (ADR-006) |

Install resolution (implemented in `installer/sources.py`):

1. Prefer compiled `plugins/<product>/agents/*/AGENT.md` when `plugins/` exists
2. Fallback to `profiles/<tool>/agents/*.md` only when `plugins/` is absent
3. Profile file copies (`CLAUDE.md`, `rules/*.mdc`, etc.) still come from `profiles/<tool>/` today; target adapters will eventually emit those from the IR (tracked per-target)

## Rationale

- **One write path:** Product changes are visible in `products.yaml` diffs, not opaque Python lists or scattered profile copies.
- **Discoverability:** Contributors know to edit `skills/`/`products.yaml`, not `plugins/`.
- **Backwards compatibility:** Existing `agent-toolkit install` flows keep working during transition; compiled artifacts are preferred when available.

## Timeline / Milestones

| Phase | Window | Gate | Action |
|-------|--------|------|--------|
| **Clarify (now)** | v1.3.x | ADR-004 accepted | Docs updated; CI enforces `build --check`; `plugins/` marked generated |
| **Prefer compiled** | v1.4.x – v1.5.x | `installer/sources.py` prefers `plugins/` | Installer and tests use compiled agents when present; `profiles/` kept but not expanded |
| **Deprecate profiles/** | v1.6.x | All profile-only skills migrated to `products.yaml` | Add deprecation notice to `profiles/README.md` (if present) and `docs/PROFILES.md` header |
| **Remove or freeze** | v2.0 | Maintainer vote | Stop adding new content to `profiles/`; keep as fallback only or remove if no consumer remains |

Immediate deletion of `profiles/` is out of scope for this ADR (explicit non-goal).

## Guidance for Contributors

- **Do:** edit `skills/`, `agents/`, `loops/`, and `distributions/products.yaml`, then run `make build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check`.
- **Do not hand-edit** `plugins/` — it is overwritten by `agent-toolkit build`. CI fails on drift.
- **Profiles status:** `profiles/` is legacy. Do not add new skills/agents only in `profiles/`; add them canonically and let the compiler emit them.
- **Plugins status:** generated, validated in CI via `build --check` (see ADR-003).

## Consequences

- **Positive:** Newcomers have a single place to add capabilities; plugins parity improves.
- **Positive:** Installer progressively consumes compiler output without breaking bare checkouts.
- **Negative (transitional):** Two sources during deprecation — mitigated by `installer/sources.py` fallback rule.
- **Risk:** Profile-only files that never get modeled in `products.yaml` remain invisible to the compiler — follow-up audit should enumerate them.

## References

- ADR-001 (canonical IR), ADR-003 (retire gen-surfaces)
- `docs/CONCEPTS.md` (concept model), `docs/ARCHITECTURE.md` (three-layer model)
- `docs/PROFILES.md`, `packages/pypi/agent-toolkit-cli/src/agent_toolkit/installer/sources.py`
- `distributions/products.yaml`, `plugins/` (generated)
