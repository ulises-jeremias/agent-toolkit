# People data compatibility

> **Archive notice (2026-11-25):** People CRUD, import, Person Start, and
> World presence described by former Toolkit Desktop builds are not a supported
> Agent Toolkit GUI. Veasel Code owns the coding product. No verified migration
> of People records or their linked session history into Veasel is established;
> see the [preservation map](LEGACY_DESKTOP_MIGRATION.md).

This page documents the on-disk workspace format so existing data can be
identified and preserved. A schema or validator is not a user-facing People
manager and does not imply that Veasel reads these files.

## Identity and storage

A Person is a durable workspace collaborator declaration, distinct from an
agent definition, installed profile, live process, or ephemeral swarm role.
The portable Agent Toolkit does not own the old Electron process runtime.

```text
<workspace>/
  people/
    README.md                 workspace-init explanation
    <id>.json                 agent-toolkit/person@1 declaration
    bindings.yaml             agent-toolkit/people-bindings@1 role preferences
  schemas/
    person.schema.json        mirrored schema
    people-bindings.schema.json
    people-contracts.lock.json
  .agent-toolkit/
    sessions/<id>.json        former local session lifecycle records
```

The canonical schemas and offline validator are maintained in this repository
under `schemas/person.schema.json` and
`scripts/workspace/validate-people.py`. Workspace scaffolding mirrors those
contracts with a source lock. Do not edit a workspace mirror as if it were the
canonical schema.

## Declaration rules

The `agent-toolkit/person@1` object requires `spec`, `id`, `name`, `role`,
`goal`, and `archived`. Optional fields include `definition_id`, `avatar`,
provider/model preferences, capability references, skills, MCP references,
isolation, budget, import provenance, and operator-written notes. The schema
rejects unknown fields. Declarations do not contain commands, secrets,
environment values, or permission grants. Omitted budgets mean inherited or
unknown, never unlimited.

The `munder-difflin/hire@1` mapping is a one-way, review-required import
contract. It does not auto-spawn a process, install a capability, synchronize
live data, or make imported fields instructions. Preserve the source file and
review any import separately.

## Validation

The validator is offline and rejects symlinked storage, duplicate JSON keys,
invalid IDs, non-finite numbers, oversized declarations, and malformed data.
Its diagnostics are designed not to echo private values.

```sh
python3 scripts/workspace/validate-people.py --workspace <workspace>
```

Run it on a copy if you are inspecting old workspace state. Validation checks
shape and provenance; it does not start a session or establish runtime status.

## Migration boundary

- Do not delete `people/`, `bindings.yaml`, `.agent-toolkit/sessions/`, or
  Electron `userData` while retiring an old installation.
- Veasel does not automatically import these files. Do not copy old MCP
  credentials or session metadata into Veasel by hand.
- Before a future importer is implemented, it must preview mappings, preserve
  originals, back up its destination, avoid secrets in logs, and be tested on a
  disposable copy.
- The historical GUI and runtime behavior are preserved in Git history and
  the `docs/desktop/` archive; they are not current Toolkit product guidance.
