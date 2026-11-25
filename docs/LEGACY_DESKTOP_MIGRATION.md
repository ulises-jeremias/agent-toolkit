# Former Desktop preservation and migration map

**Status:** migration inventory; not a parity claim. Updated 2026-11-25.

Agent Toolkit is the portable capability ecosystem. [Veasel Code](https://github.com/veasel-labs/veasel)
is the supported coding application and is designed to own the shared
TUI/Desktop runtime. Packaged shared-session acceptance remains tracked in
[Veasel #550](https://github.com/veasel-labs/veasel/issues/550).
The former Electron application in `apps/desktop/` is retired from active
product development. Its source remains in this repository only while the
items below are preserved, migrated, or explicitly archived. New Toolkit
features must not extend that application.

## Capability and data disposition

| Former Desktop capability or data | Current owner / disposition | Verified status and safe next step |
| --- | --- | --- |
| Portable skills, agents, context packs, MCP templates, and workflow recipes | Agent Toolkit | Active portable formats. Keep their source and provenance here; discover or link them in Veasel without copying over user files. |
| Coding conversations, provider sessions, approvals, tools, diffs, and cancellation | Veasel Code | Veasel is the intended runtime. Packaged, cross-client acceptance remains tracked by [Veasel #550](https://github.com/veasel-labs/veasel/issues/550); do not infer complete parity from source or component tests. |
| Terminal and provider process supervision | Veasel Code | Veasel owns the target runtime. Cross-platform packaged behavior is not established by this inventory; keep old implementation/tests until migration evidence covers required workflows. |
| Swarm v1 provider executor and run records | Veasel owns new orchestration; Agent Toolkit #1676 records the retirement boundary | Current main rejects new `start`/`init` requests and the old Desktop no longer presents a start flow. Existing user data is preserved; the maintainer's one completed trace was copied byte-identically to an archive. There is no general run importer. Historical inspection and explicit recovery actions remain available for existing runs; these are compatibility paths, not a supported new execution product. |
| World renderer, semantic entities, and original PXL artwork | Veasel Code is the product destination; original source and attribution remain here for now | The original `.px.js` sources, generator inputs, licenses, and tests must not be deleted or regenerated from flattened output. Migration/visual/runtime acceptance remains [Veasel #693](https://github.com/veasel-labs/veasel/issues/693). |
| People records, bindings, role preferences, and local presence | Not verified as fully migrated | Preserve `people/` records, `people/bindings.yaml`, PersonSession history, and custom fields. Veasel has no equivalent People CRUD, local Person PTY, or PersonSession persistence today; no importer is established. Never infer live activity from a Person declaration. |
| Workspace packs, registered project links, and workspace-specific configuration | Portable data remains Toolkit-owned; coding runtime is Veasel-owned | Veasel Focus can open a selected existing folder and remembers Desktop picks locally, but this does not migrate Toolkit's registered project/symlink catalog, show idle linked projects in World, or import `.active-pack` and other workspace settings. Preserve the original files and links; no automatic import is established. |
| MCP server definitions and encrypted credentials | Templates are Toolkit-owned; credentials remain user-owned | No credential importer or key migration is established. Never copy secrets into Veasel or plaintext files as part of retirement. |
| Focus journals, operation/run history, and Electron `userData` | User-owned historical data | No automatic Veasel importer is established. Existing installs and historical release assets are untouched; inspect and back up before manual migration or removal. |
| Agent Toolkit Electron install/build/release path | Retired from new product releases; source and CI still present pending this audit | Do not advertise it as current. Remove source/build/release jobs only after feature, PXL, data, and security gates below have evidence and the historical source remains recoverable in Git. |

## Removal gates

Before deleting `apps/desktop/`, its workflows, or its tests:

1. Map each user-facing workflow and unique tested behavior to a maintained
   Veasel implementation, a portable Toolkit interface, or an explicit
   documented retirement. Record current-main commit and packaged evidence.
2. Preserve original pixel-art sources, licenses, attribution, generation
   tools, and meaningful tests in their canonical owner. Flattened images alone
   are not a source-preservation strategy.
3. Document old data locations and formats. If a migration is needed, make it
   opt-in, previewable, backed up, non-destructive, and tested against a copy.
   Keep secrets out of logs and migration artifacts.
4. Search release workflows, package scripts, website links, CLI aliases,
   CI, and external install docs for references. Retire each reference in the
   same migration sequence; keep historical release assets immutable.
5. Verify the resulting portable CLI and Veasel packaged product on supported
   platforms before removing the last tested source implementation.

Until those gates pass, the code is **unmaintained migration source**, not a
supported second product. The Swarm v1 retirement E2Es verify that new Toolkit
runs are blocked, the run-directory entries and seeded state-file contents
remain unchanged, and the old UI directs users to Veasel. They do not prove
Veasel parity, packaged daily-driver acceptance, or migration of People/project
data. Other historical Desktop tests must not be described as current Veasel
acceptance.

## Current entry points

- [Veasel Code](https://github.com/veasel-labs/veasel) — coding TUI and Desktop.
- [Agent Toolkit](https://github.com/ulises-jeremias/agent-toolkit) — portable
  capabilities, CLI, provenance, and compatibility.
- [Official Veasel catalog](https://github.com/veasel-labs/agent-toolkit) —
  reviewed plugin metadata and publication, not another runtime.
- [Compatibility boundary](VEASEL_COMPATIBILITY.md).
- [Archived Electron design and evidence index](desktop/README.md).
