# People — durable collaborators, not running sessions

Status: **CURRENT CONTRACT (partial delivery)** — schemas, storage ownership,
scaffolding, mirror sync and offline validation are implemented. People CRUD,
import review, Start, session binding and swarm role selection in Desktop are
**not implemented**; see [Gaps](#gaps).

A Person is a collaborator you have chosen and reviewed. It persists in your
workspace, not in the toolkit. Configuration alone never creates a character:
a `people/<id>.json` file is a declaration, and the Desktop world shows only
runtime truth from `agent-toolkit serve` (ADR-034).

## Identity model

These five things are different, and the code keeps them different:

| Concept | Where it lives | What it is |
|---|---|---|
| **Agent definition** | toolkit `agents/<name>/AGENT.md` | A reusable persona template — how an AI works in a session |
| **Agent profile** | toolkit `profiles/<target>/` | A per-target adapter/overlay of toolkit capabilities |
| **Person** | workspace `people/<id>.json` | A durable collaborator you chose and reviewed |
| **Agent session** | runtime | A live conversation with ephemeral state |
| **Swarm role** | recipe | A slot in a swarm run, resolved per run |

Workspace personas (`personas/*.md`) constrain behavior and permissions during
a session; they are not identity. A Person composes an optional
`definition_id` reference plus preferences, but is its own durable thing.

## Storage

```text
<workspace>/
  people/
    README.md              scaffold (workspace init)
    <id>.json              one Person per file, spec agent-toolkit/person@1
    bindings.yaml          optional role preferences, spec agent-toolkit/people-bindings@1
  scripts/
    validate-people.py     mirrored offline validator (canonical: toolkit scripts/workspace/validate-people.py)
  schemas/
    person.schema.json     mirrored (canonical: toolkit schemas/person.schema.json)
    people-bindings.schema.json
    people-contracts.lock.json  SHA256/source lock for the mirrors
```

`workspace init` scaffolds `people/README.md` and rejects symlinked
destinations before writing anything. The mirrors are written by
`scripts/sync-people-contracts.py` from the toolkit checkout (atomic
replacement, so unrelated hardlinked inodes survive) and verified against the
lock before the validator parses any schema. A drifted mirror fails validation
with a static message; it never evaluates tampered schemas.

## Schema rules (agent-toolkit/person@1)

- Required: `spec`, `id`, `name`, `role`, `goal`, `archived`.
- Optional: `definition_id`, `avatar`, `preferred_provider`,
  `preferred_model`, `capabilities`, `skills`, `mcp_servers`, `isolation`,
  `budget`, `import_source`.
- `id` is lowercase `[a-z0-9][a-z0-9_-]*` (max 64) and must match the filename.
- Reference arrays are bounded at 32 unique entries.
- No runtime fields, no secrets, no commands, no environment, no grants.
- Source flags (`import_source.*`) are inert provenance, never instructions.
- Budget omission means inherited or unknown, never unlimited.
- `additionalProperties: false` everywhere.

## Imports (munder-difflin/hire@1)

`capabilities/imports/munder-hire-v1.json` is a **contract-only** mapping:
`review_required: true`, `auto_spawn: false`, `auto_install: false`,
`live_sync: false`. It maps name/role/goal/provider/model/skills/MCP fields;
the `definition_id` is chosen during human review. Unknown and unsafe fields
are blocked. Original character/accent are retained as inert attribution, not
external art. Never treat `hive/registry.json` as runtime authority; there is
no live synchronization.

## Validation

```bash
python3 scripts/validate-people.py --workspace <workspace>
```

Offline only: the validator uses a no-network jsonschema registry, rejects
symlinked directories/files, enforces the 64 KiB declaration limit, the
id/filename match, finite numbers (rejecting `NaN`/`Infinity`/`1e9999`),
duplicate keys, and prints a static diagnostic that never echoes values, keys,
or control bytes. Templates under `templates/people/` are validated but never
counted as configured people.

## Role resolution (contract)

When a swarm recipe names a role:

1. An explicit Person choice is used; an invalid choice fails.
2. Otherwise the first compatible preferred Person (ordered by
   `people/bindings.yaml`).
3. Otherwise an ephemeral canonical session, with role selection before start.

Not implemented yet; see below.

## Gaps

The following are explicitly **not implemented**. Do not represent schemas or
file authoring as the user interface:

- People CRUD in Desktop (create/edit/archive through the GUI).
- Import review flow in Desktop (reviewing a `munder-difflin/hire@1` payload).
- Start / session binding (starting a session as a Person).
- Swarm role picker with pre-start Person selection.
- Runtime enforcement of the resolution order above.

Until these land, the contract is the schema set, the scaffold, the mirrors
and the offline validator. Each gap lands with real GUI journeys, not
documentation-only claims.
