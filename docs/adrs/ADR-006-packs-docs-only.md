# ADR-006: Packs are Docs-Only Solution Bundles (Not Compiler-Wired)

**Status:** Accepted  
**Date:** 2026-08-06  
**Deciders:** maintainers (Wave 3 #269, parent #263)

## Context

`packs/` are documented as solution bundles that combine skills, agents, and loops for an outcome (e.g. `oss-maintenance`). They are not loaded by `agent-toolkit build` — `distributions/products.yaml` is the compiler input for marketplace plugins. Consumers cannot tell if packs are real product surface or docs-only, and the name overloads with “products”.

## Decision

**Packs are docs-only.** They are **not** compiler-wired.

- `packs/<name>/` contains a human-oriented bundle: `README.md` + `config.yaml` (+ optional AGENTS snippet / loop refs). It is a **workflow template** that documents which skills/loops to use together and how to configure them.
- `distributions/products.yaml` remains the **sole compiler input** for `plugins/` (ADR-001). Packs do not appear in `products.yaml` and are not compiled to marketplace manifests.
- If a pack's loop/skill set should become a shipped product, create or extend a product entry in `products.yaml` referencing those same canonical IDs — do not teach the compiler to ingest `packs/`.

This is explicitly the **“mark docs-only”** option from #269, not “wire packs into compiler”.

## Rationale

- Keeps the compiler surface small (products → targets) and packs as low-ceremony team docs.
- Avoids a second composition layer before the product/pack noun is clarified with the community.
- A follow-up implementation issue can propose “wire-in” later with a clear scope (schema for `pack.yaml`, pack→product mapping, target wiring) if the community wants it.

## Follow-up (if wiring is ever desired)

Open a separate issue with:

- Proposed `packs/<name>/pack.yaml` schema (extends `distributions/products.yaml` or references it)
- How packs map to products/targets
- Compiler change scope (`loader.py` + `build.py` + one adapter)
- Migration for existing packs

No such implementation occurs in this decision issue.

## Docs updates

- `packs/README.md` header now states "Docs-only — not loaded by `agent-toolkit build`"
- `packs/README.md` now documents that `skills:` and `agents:` keys in pack config.yaml
  are advisory only and are not applied by `loop run --pack` (see `loop/pack.py`).
- `packs/engineering-workflow/config.yaml` and `packs/delivery-discipline/config.yaml`
  now carry advisory-only comments above their `skills:` and `agents:` sections.
- `docs/CONCEPTS.md` and `docs/ARCHITECTURE.md` explicitly call packs docs-only (not plugin composition)
- This ADR is the decision log; `README.md` and `packs/README.md` cross-link here

## Consequences

- **Positive:** Noun is no longer ambiguous; contributors stop hunting for “pack compiler” code
- **Positive:** Packs can evolve as workflow docs without blocking compiler work
- **Negative:** Teams wanting one-command “install a pack” still copy config manually — acceptable for now; Wave 5 may add `agent-toolkit pack install` as a docs-only helper

## References

- `packs/README.md`, `packs/{oss-maintenance,engineering-workflow,delivery-discipline}/`
- `distributions/products.yaml` (compiler SoT), `docs/CONCEPTS.md`, `docs/ARCHITECTURE.md`
- #269 (decision), #263 (CMP Wave 3)
