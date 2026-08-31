# ADR-001: Canonical Intermediate Representation

**Status:** Accepted  
**Date:** 2026-08-04

## Context

The original repository used hard-coded Python lists to copy files from `skills/` and
`agents/` into `plugins/`. This made plugin composition opaque and required code changes
to add new products or targets.

## Decision

Introduce a canonical intermediate representation (IR) with:

1. **`distributions/products.yaml`** — declarative product catalog (replaces hard-coded SURFACES dict)
2. **`src/agent_toolkit/compiler/model.py`** — typed Python dataclasses for Skill, Agent, Product
3. **`src/agent_toolkit/compiler/loader.py`** — parses SKILL.md/AGENT.md into the IR
4. **`src/agent_toolkit/compiler/targets/`** — per-target adapters that report what they emit, transform, omit, and find unsupported

## Rationale

- Product composition is now readable YAML, not Python code
- Each target adapter explicitly documents what it can/cannot support
- Unsupported capabilities produce visible diagnostics rather than silent drops
- New targets can be added without modifying core Python logic

## Consequences

- **Positive:** Plugin bundles are now generated from canonical sources via a validated pipeline
- **Positive:** CI can verify generated vs. canonical drift
- **Negative:** Requires PyYAML for full functionality (graceful fallback exists)
- **Migration:** Old `gen-surfaces.py` is preserved for backward compatibility but deprecated in favor of `agent-toolkit build`
