# Veasel compatibility and Desktop retirement policy

Cross-repo epic: [veasel-labs/veasel#689](https://github.com/veasel-labs/veasel/issues/689) ·
Tracking issue: [#1804](https://github.com/ulises-jeremias/agent-toolkit/issues/1804) ·
Decision: ADR-0001 in `veasel-labs/veasel` (`docs/adr/0001-one-product-one-runtime.md`).

## What stays here

Agent Toolkit remains the canonical home for portable Skills, agents,
MCP configuration, context packs, workflow recipes, the CLI, and its
distribution (npm/PyPI/AUR/Homebrew/Docker). Nothing about existing
installs changes: `agent-toolkit` CLI commands, catalogs
(`capabilities/`, `skills/`, `agents/`, `packs/`, `schemas/`) and install
receipts keep working exactly as before.

## What moves, and when Desktop retires

The Desktop's Focus session runtime and World GUI are being migrated
copy-first into Veasel (Focus GUI copy: veasel-labs/veasel PR for issue
#692; provider adapters: veasel issue #691). The standalone Desktop in
this repo retires **only after all of the following are true**:

1. Veasel GUI reaches Focus parity on the canonical Veasel
   session/event API (same sessions visible in TUI and GUI).
2. Compatibility shims in this repo redirect Desktop-era entry points
   to the Veasel GUI and are shipped in a released version.
3. Packaged installers for the Veasel GUI are verified on Linux,
   macOS, and Windows.

Until then the Desktop stays fully supported, and the stacked Desktop
Rescue work (#1775, PRs #1783–#1803) is preserved — nothing is closed
or deleted as part of the consolidation without a documented successor
(see the triage ledger in veasel-labs/veasel `docs/consolidation/`).

## Shim contract (to implement under #1804)

- `agent-toolkit` CLI: unchanged. A future `desktop` verb may print a
  pointer to the Veasel GUI once condition 1 holds; it must never break
  scripts (exit 0 with guidance, or the legacy behaviour behind a flag).
- Desktop data (`userData/focus-journals`, workspace
  `.agent-toolkit/focus/` journals) migrates reversibly: the Veasel
  importer reads the JSONL journal format; originals are never deleted
  by the importer.
- Skills/agents/packs consumed by Veasel are read from this repo's
  canonical Markdown/YAML/JSON — no format fork.

## Status (2026-11-20)

All three retirement conditions are now met: Veasel Focus parity on the
canonical session API is shipped (same sessions in TUI and GUI,
veasel-labs/veasel#692 closed), packaged Veasel installers are verified
on Linux, macOS and Windows (release v0.97.0-next.0 from the fully
green main), and the `agent-toolkit gui` shim redirecting to the Veasel
Desktop is implemented (#1804). The legacy Desktop here is retired;
existing installs keep working and are never force-migrated.

New Toolkit release tags publish the CLI and portable capability
distributions only. Electron packaging remains a pull-request compatibility
check; Electron installers are not uploaded to new releases. The legacy
update panel detects whether the current platform's installer exists before
reporting an update, and links users to Veasel when it does not. Existing
Toolkit Desktop release assets and user data are left untouched.

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
