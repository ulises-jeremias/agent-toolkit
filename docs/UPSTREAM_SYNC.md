# How upstream synchronization works

Agent Toolkit can carry selected skills from other repositories. Here,
**upstream** means the repository and path where selected content originated;
it is not a Git remote that is merged into Toolkit. The source is declared and
pinned so a proposed update can be checked against exact upstream bytes, its
license and its security surface. Synchronization prepares a reviewable change;
it does not grant that change trust or install it on your machine.

## The path from source to a compatible tool

The flow has five distinct steps:

1. **Name the source.** A capability declares its upstream repository, exact
   path, requested ref and expected license.
2. **Discover a candidate.** For commit pins, update tooling checks the
   declared path for a different immutable commit. If GitHub returns no commit
   for that path, discovery falls back to the upstream default-branch `HEAD` and
   checks that the declared path still exists there; this can surface a branch
   head as the candidate even when the path-filter query found no commit. For
   tag pins, it checks GitHub's `releases/latest` and accepts that release only
   when its tag looks like a semantic version. Discovery reports the current
   locked license and content checksum; it does not fetch or validate the
   candidate's content.
3. **Prepare a proposal.** Applying the update fetches the literal upstream
   files, updates the source pin, regenerates the provenance lock and report,
   and marks changed content `experimental`. The workflow submits that proposal
   as a draft PR.
4. **Review and bind trust.** A person inspects the candidate diff, attribution,
   security declarations and tests. Only that reviewer can decide whether the
   content is acceptable and bind the reviewed metadata to the exact provenance
   digest.
5. **Distribute declared support.** After merge, the Toolkit can compile the
   capability for its declared products and target profiles. Support is
   specific to each capability and tool; the catalog never means “works
   everywhere.” A merged capability may remain `experimental`; that status
   travels with it and is not silently promoted by compilation or release.

The upstream source does not receive changes back from this sync, and discovery
does not install anything into a user's coding-tool profile.

## What the scheduled check does

The weekly **Update Upstream** workflow and its manual dispatch run the same
path-scoped discovery:

1. Read upstream declarations from each vendored skill's `SKILL.md` frontmatter.
2. Resolve the latest commit touching each declared path. If that path query
   returns no commit, fall back to the upstream default-branch `HEAD` and check
   that the path still exists there. For tag-pinned sources, check GitHub's
   `releases/latest` and accept it only when the tag looks like a semantic
   version. Discovery reports the currently locked license and checksum; it
   does not fetch the candidate files or claim their metadata has been
   validated. For release tags, it follows GitHub's latest-release marker
   rather than comparing semantic-version order.
3. For an eligible update, fetch the literal upstream body and sibling files,
   update the declared pin, rebuild `capabilities/upstream.lock`, and regenerate
   `docs/UPSTREAM.md`.
4. Put changed upstream content in the **experimental** trust tier and remove
   its old review binding.
5. Open a draft pull request with the source revisions and a human review
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

After the review, the human reviewer updates `trust.tier`, `trust.reviewed_by`,
and `trust.reviewed_at` in `SKILL.md`. Those fields are part of the vendored
content checksum, so finalize them **before** regenerating the lock. Then:

1. Run `python3 scripts/provenance.py lock` to calculate the new
   `provenance_digest` from the reviewed metadata and resolved source bytes.
2. Copy that exact digest into `trust.reviewed_provenance`. This binding is
   excluded from the content checksum to avoid a circular hash.
3. Run `python3 scripts/provenance.py docs` to regenerate `docs/UPSTREAM.md`.
4. Run `python3 scripts/provenance.py check`,
   `python3 scripts/provenance.py lock --check`,
   `python3 scripts/provenance.py docs --check`, and
   `python3 scripts/validate-upstream.py --check`.

Setting reviewer metadata after `lock` changes the content checksum and makes
the digest stale. Binding a digest before regenerating the lock also leaves a
stale review binding. The checks validate the lock, generated report, vendored
bytes, and review binding together. Agents and automation must not invent a
reviewer or bind trust on someone's behalf.

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
