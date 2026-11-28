# Agent Toolkit and Veasel Code: product boundary and migration

Cross-repo epic: [veasel-labs/veasel#689](https://github.com/veasel-labs/veasel/issues/689) ·
Tracking issue: [#1804](https://github.com/ulises-jeremias/agent-toolkit/issues/1804) ·
Decision: ADR-0001 in `veasel-labs/veasel` (`docs/adr/0001-one-product-one-runtime.md`).

## Product ownership

| Product | Owns |
| --- | --- |
| Agent Toolkit (this repository) | Portable skills, agent definitions, MCP templates, context/workflow recipes, provenance, compatibility tooling, CLI, and distribution |
| [Veasel Code](https://github.com/veasel-labs/veasel) | The supported coding product, designed around one TUI/Desktop backend and session runtime, Focus, and optional World |
| [Official Veasel plugin catalog](https://github.com/veasel-labs/agent-toolkit) | Curated/community plugin manifests, provenance, review policy, and publishing; no runtime |

Agent Toolkit remains independently useful with other supported coding tools.
Use Veasel Code for interactive coding. Its packaged shared-session experience
remains an acceptance gate in [Veasel #550](https://github.com/veasel-labs/veasel/issues/550).

## Former Toolkit Electron Desktop

The former Electron app (`apps/desktop/`) is retired and removed from `main`
(preserved in Git history). New Agent Toolkit releases distribute the portable
CLI and capabilities; graphical coding work belongs in Veasel Code. Historical
evidence and design notes under `docs/desktop/` remain as archival reference
only and are not a promise of Electron support.

The Veasel migration and packaged acceptance are still tracked in
[veasel-labs/veasel#550](https://github.com/veasel-labs/veasel/issues/550),
the cross-repository epic [#689](https://github.com/veasel-labs/veasel/issues/689),
and the World milestone [#693](https://github.com/veasel-labs/veasel/issues/693).
Passing component tests or publishing an installer does not close those
acceptance requirements.

## Existing installations and user data

- Existing Electron installations, release assets, workspaces, and user data
  are not deleted or rewritten by this repository's release process.
- Veasel Code does not automatically import Toolkit Desktop state. Do not
  promise that Focus journals, MCP credentials, People, workspace settings,
  or local run history have migrated unless a tested importer proves it.
- Before removing an old installation or local data directory, inspect and
  back it up. The likely locations include Electron `userData` and workspace
  `.agent-toolkit/` directories; do not assume all users share one path.
- Portable skills, agents, packs, and templates remain in their canonical
  source formats here. Their use in Veasel must preserve provenance and must
  not overwrite user-owned tool configuration.

## Compatibility command status

In current `main`, `agent-toolkit gui` / `desktop` launches an installed Veasel
Desktop binary when available. If it cannot find one, it prints Veasel install
guidance; it never launches the former Electron app. See merged
[PR #1851](https://github.com/ulises-jeremias/agent-toolkit/pull/1851). The
published v1.50.0 CLI predates this change, so its behavior may still differ
until a new Toolkit release is published. Invoke Veasel Code directly in the
meantime.

## Publishing into the Veasel catalog by reference (#1806)

Plugins from this repository enter the official Veasel catalog
(`veasel-labs/agent-toolkit`, `registry/registry.yaml`) **by reference
only** — the catalog never copies plugin source:

1. Cut a release of this repo (or choose an existing immutable tag) and
   note the exact commit the tag resolves to
   (`gh api repos/ulises-jeremias/agent-toolkit/git/ref/tags/<tag>`;
   annotated tags resolve to their target commit).
2. Open a registry PR in `veasel-labs/agent-toolkit` adding/updating the
   entry with `source: { type: github, repo:
   ulises-jeremias/agent-toolkit, path: plugins/<name>, ref: <tag>,
   sha: <resolved commit> }`, the plugin version at that commit, its
   SPDX license, and a truthful permission surface
   (shell/network/mcp/hooks/dangerous_permissions).
3. Registry CI validates manifest schema, pin format and provenance.
   Review state starts at `pending-initial-review` with trust
   `community`; promotion requires the owner's governance decision
   (veasel-labs/agent-toolkit#10) — authors never self-approve.
4. A version bump is a new reviewed registry PR moving `ref` and `sha`
   together. Veasel's runtime fetches the pinned commit, verifies HEAD
   matches the sha, and fails closed on any mismatch.

### Release tag → catalog pin checklist

| This repo | Catalog (`veasel-labs/agent-toolkit`) |
|-----------|---------------------------------------|
| Tag `vX.Y.Z` cut and pushed | Resolve to commit sha via the git refs API |
| `plugins/<name>` manifest at that commit | Entry `version` equals the manifest version |
| License file unchanged | Entry `license` matches the SPDX id |
| No new shell/network/MCP/hooks surface | Entry `permissions` stays truthful; widening needs review |

Worked example: `agent-toolkit-core` is pinned at `v1.49.0` →
`7bd44a7b4cc64afc4908b49977589666c1978920`, path
`plugins/agent-toolkit-core`, license MIT, trust `community`, review
`pending-initial-review`. Its source remains solely in this repository;
the catalog entry is the complete publication.
