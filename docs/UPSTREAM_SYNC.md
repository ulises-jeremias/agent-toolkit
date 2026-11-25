# How upstream synchronization works

Agent Toolkit can carry selected skills from other repositories. The source is
declared and pinned so a proposed update can be checked against the exact
upstream bytes, license and security surface. Synchronization prepares a
reviewable change; it does not grant that change trust or install it on your
machine.

## The path from source to a compatible tool

The source repository and path identify where the content came from. The
immutable commit and checksums record what was reviewed. Agent Toolkit then
compiles eligible capabilities into its declared products and target profiles.
Support is specific to each capability and tool; the catalog never means “works
everywhere.”

## What the scheduled check does

The weekly **Update Upstream** workflow and its manual dispatch run the same
path-scoped discovery:

1. Read upstream declarations from each vendored skill's `SKILL.md` frontmatter.
2. Check the pinned source path for an eligible newer immutable revision.
3. Compare the declared license and the resolved content against the committed
   provenance lock.
4. If an update is eligible, apply the literal upstream body and sibling files,
   refresh `capabilities/upstream.lock`, and regenerate `docs/UPSTREAM.md`.
5. Put changed upstream content in the **experimental** trust tier and remove
   its old review binding.
6. Open a draft pull request with the source revisions and a human review
   checklist. The workflow never merges it.

The regular provenance check is offline with respect to upstream repositories.
It checks declarations, pinned commits, checksums, license observations,
generated catalogs and reviewed-provenance bindings from files already in the
repository. It does not fetch upstream content during normal validation. The
separate scheduled/manual **Update Upstream** workflow is the part that queries
upstream repositories.

## What a reviewer verifies

Before merging a sync proposal, a reviewer checks the actual diff and confirms:

- The changed files match the declared upstream path and expected siblings.
- The license still permits redistribution and its SPDX identifier is accurate.
- The capability's shell, network, MCP, hook and dangerous-permission declarations
  still describe what the content can do.
- Required Toolkit validation passes, and target compatibility claims remain
  limited to tested or declared formats.
- Any upstream behavior change is acceptable for Toolkit users.

After that review, a human updates `trust.reviewed_provenance` to the new digest
and records the reviewer and date in the same pull request. The check fails if
the reviewed digest does not match the source and bytes. Agents and automation
must not invent a reviewer or bind trust on someone's behalf.

## What synchronization does not do

- It does not auto-merge an upstream change.
- It does not promote changed content to `reviewed`.
- It does not execute the skill or configure an MCP server.
- It does not overwrite files in a user's coding-tool profile. Installation is
  a separate, previewable CLI action.
- It does not claim every capability works with every coding agent.

## Inspect the current pins

The generated [upstream provenance report](UPSTREAM.md) lists sources and
resolved revisions. The [Trust and Security guide](TRUST.md) describes the lock
and review binding. The [upstream governance policy](UPSTREAM_VS_FIRST_PARTY.md)
explains when content is vendored, enhanced in place or declined.

To inspect candidate updates locally:

```sh
python3 scripts/provenance.py updates --json
python3 scripts/provenance.py check
```

Applying changes is a maintainer action and should happen on a review branch:

```sh
python3 scripts/provenance.py updates --apply
python3 scripts/validate-upstream.py --check
python3 scripts/provenance.py check
```

The automated workflow creates a draft pull request so the exact generated
diff, tests, source and human trust decision stay together.
