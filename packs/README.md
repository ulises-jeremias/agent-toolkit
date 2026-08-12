# Solution Packs

> **Docs-only** — packs are not loaded by the compiler (`agent-toolkit build`). They are workflow templates that reference skills/loops. For plugin composition, edit `distributions/products.yaml` (see `docs/adrs/ADR-006-packs-docs-only.md`).
>
> **Not the only pack noun.** The word "pack" has three meanings in this project. This file documents solution packs. See `docs/CONCEPTS.md#three-kinds-of-packs` for workspace packs (`workspace load`) and loop `--pack` overrides (`loop run --pack`).

Solution packs bundle related skills, agent personas, loop templates, and MCP configurations
into outcome-oriented workflows for common team setups.

## Available Packs

| Pack | Description | Status |
|------|-------------|--------|
| [oss-maintenance](oss-maintenance/) | Automate PR review, issue triage, and daily briefings across OSS repos | ✅ Ready |
| [engineering-workflow](engineering-workflow/) | End-to-end engineering delivery: planning → implementation → review → deploy | ✅ Ready (config shipped) |
| [delivery-discipline](delivery-discipline/) | Ticket hygiene, traceability, and process compliance | ✅ Ready (config shipped) |

## Using a Pack

Each pack has a `config.yaml` for customization and a `README.md` with setup instructions.

```bash
# Example: set up OSS maintenance for your repos
cp packs/oss-maintenance/config.yaml ~/.ai-workspace/packs/
# Edit repos list in config.yaml
# Then use loops/oss-pr-monitor, loops/oss-triage, loops/oss-daily-briefing
```

## Pack config.yaml fields

The `config.yaml` declares three top-level sections:

- `loops` — Loop overrides (`enabled`, `cadence`, `tier`, `verifier`, `goal`, `budget`).
  These are applied by `loop run --pack`. See `loop/pack.py`.
- `skills` — Advisory only. Lists which skills the pack recommends. The `loop run --pack`
  command does **not** read or apply `skills:` entries. Authors may list them as
  documentation.
- `agents` — Advisory only. Lists which agent personas the pack recommends. The `loop run --pack`
  command does **not** read or apply `agents:` entries. Authors may list them as
  documentation.

The `skills:` and `agents:` keys are human-readable labels, not machine-applied actions.
The pack format may grow a loader in the future (see ADR-006 follow-up note), but today
only `loops:` is handled by the code.

## Creating a Pack

A pack is a directory containing:
- `README.md` — purpose, setup, usage
- `config.yaml` — configurable parameters
- Optional: `AGENTS.md` snippet, skill list, loop references

## New Packs — #390 (docs-only, curated)

| Pack | Description | Status |
|------|-------------|--------|
| [design-engineering](design-engineering/) | Frontend/design-engineering: figma → frontend-design → review + a11y → mermaid/C4 | ✅ Ready (config shipped, trust_tier community) |
| [agentic-security](agentic-security/) | Supply-chain + MCP audit + OWASP agentic + threat-modeling | ✅ Ready |
| [code-quality](code-quality/) | MegaLinter v10 + CodeQL + gh-fix-ci | ✅ Ready |
| [architecture](architecture/) | Vendor-neutral core (adr/trd/threat-model/mermaid/c4) + optional cloud (cloud-design-patterns/aws-well-architected-review) | ✅ Ready |

All packs are **docs-only** per ADR-0003 (advisory `skills:`/`agents:`; only `loops:` handled by `loop run --pack`). See `docs/CONCEPTS.md#three-kinds-of-packs`. Not a giant default pack — `complete` stays experimental per #390.
