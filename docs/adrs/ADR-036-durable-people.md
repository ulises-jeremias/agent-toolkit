# ADR-036 — Durable People in the workspace, distinct from agent definitions

- **Status:** Accepted (2026-10-01); see [PEOPLE.md](../PEOPLE.md) for current implementation state
- **Deciders:** ulises-jeremias (owner)
- **Amends:** ADR-034 (semantic world — characters are runtime truth, not declarations)

## Context

The toolkit already has three identity-shaped concepts: agent definitions
(`agents/<name>/AGENT.md`), agent profiles (`profiles/<target>/`) and ephemeral
sessions. Users also keep workspace personas that constrain session behavior.
None of these is a durable collaborator: something a person has chosen,
reviewed, and can reuse across sessions and machines without re-defining it.

Import payloads (munder-difflin/hire@1) made this concrete: importing a hire
as an agent definition would mix identity with target configuration, and
auto-spawning imported people would create runtime characters from unreviewed
data — violating ADR-034 (the world shows runtime truth only) and the global
rule that configuration alone never creates characters.

## Options

### 1. Reuse agent definitions for durable people

- Pros: no new schema; definitions already exist.
- Cons: definitions are toolkit-owned and public; personal identity would leak
  into the public repo; profiles are target adapters, not people; a definition
  cannot carry import provenance or review state.

### 2. New durable Person in the workspace (chosen)

- Pros: personal identity stays in the workspace; definitions, profiles,
  people and sessions stay distinct; import provenance has a home; the world
  keeps showing runtime truth only.
- Cons: new schema set, mirrors, and validator to maintain.

## Decision

Durable People live in workspace `people/<id>.json` (`agent-toolkit/person@1`)
with optional `people/bindings.yaml` (`agent-toolkit/people-bindings@1`). The
toolkit owns the canonical schema set, the scaffold, the mirror sync script
and the offline validator; harness/reference and personal instances mirror the
contracts and keep their own declarations. Configuring a Person never creates
a runtime character.

Role resolution for swarm recipes: explicit Person choice first (invalid
choice fails), then the first compatible preferred Person in bindings order,
then an ephemeral canonical session with pre-start role selection.

## Consequences

- `AgentDefinition != AgentProfile != AgentSession != SwarmRole`, now with a
  fourth distinct concept (Person) in the workspace.
- Mirrors are locked by SHA256/source; a drifted mirror fails validation
  before any schema is evaluated, and sync never truncates an outside
  hardlink.
- Import of `munder-difflin/hire@1` stays contract-only: review required, no
  auto-spawn, no auto-install, no live sync.
- Desktop now provides GUI CRUD/archive/restore, reviewed one-way Munder
  import, Start against a real local PTY with V-owned lifecycle evidence, and
  per-role Person selection with backend preview. See [PEOPLE.md](../PEOPLE.md)
  for the current behavior and limits. Provider conversation resume, process
  continuity after Desktop exits, token/cost enforcement and inherited
  isolation are still unsupported by the local interactive PTY. Swarm Person
  bindings remain run metadata and adapter hints; they are not yet canonical
  PersonSessions or World characters. Journey evidence is maintained in
  [the Desktop workflow ledger](../desktop/workflows.yaml).

## Rollback

Remove the schema set, scripts and workspace scaffold. Workspace declarations
are user-owned data and survive the rollback untouched.
