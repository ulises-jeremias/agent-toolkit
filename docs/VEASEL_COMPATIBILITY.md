# Veasel compatibility and Desktop retirement policy

Cross-repo epic: [veasel-labs/veasel#689](https://github.com/veasel-labs/veasel/issues/689) ·
Tracking issue: [#1804](https://github.com/ulises-jeremias/agent-toolkit/issues/1804) ·
Decision: ADR-0001 in `veasel-labs/veasel` (`docs/adr/0001-one-product-one-runtime.md`).

## What stays here

Agent Toolkit remains the canonical home for portable Skills, agents,
MCP configuration, context packs, workflow recipes, the CLI, and its
distribution (npm/PyPI/AUR/Homebrew/Docker). Portable `agent-toolkit`
commands, catalogs (`capabilities/`, `skills/`, `agents/`, `packs/`,
`schemas/`), and install receipts keep working. The old `gui`/`desktop`
entry point is an explicit migration shim to Veasel and does not launch or
modify the retired Toolkit Desktop.

## Legacy Desktop retirement status

Veasel Code is the supported graphical product and owns the canonical
session runtime. The old Electron Desktop in this repository is retired as
a product: new Toolkit releases do not publish its installers. Its source,
historical evidence, and user data are retained during the migration audit
so unique portable assets and existing data are not lost. Retaining this
source does not mean that the old Desktop remains supported or is a second
runtime recommendation.

Veasel Focus uses the canonical Veasel session/event API, and the Toolkit
shim opens Veasel only. Official Desktop installers are published for Linux,
macOS, and Windows. Packaged same-session continuation, restart recovery, and
provider journeys remain tracked in [Veasel issue
#550](https://github.com/veasel-labs/veasel/issues/550); those acceptance
checks are not implied by this compatibility contract. See the current
[Veasel release](https://github.com/veasel-labs/veasel/releases/latest) and
[Focus migration issue](https://github.com/veasel-labs/veasel/issues/692).

## CLI compatibility shim

- `agent-toolkit gui` and its `desktop` alias remain for existing scripts,
  but they only launch an installed Veasel Desktop. The shim never searches
  for or falls back to an Agent Toolkit Electron binary. If Veasel is not
  installed, it points to Veasel's release page.
- `agent-toolkit gui --install` is deprecated guidance only; it does not
  download, install, or change files.
- The shim does not read, migrate, or delete legacy Desktop data. Existing
  user data stays at its original path. Any future importer must be a
  separate, previewable, reversible operation that preserves the source.
- Skills, agents, MCP templates, and packs remain portable Toolkit
  capabilities. Veasel consumes supported declarations without creating a
  second copy or runtime.

## Distribution status (2026-11-25)

New Toolkit release tags publish the CLI and portable capability
distributions only. Electron packaging and GUI acceptance workflows still
exist in this source tree as migration-era checks; they are not release
artifacts and do not make the retired application a supported product. The
legacy update panel detects whether the current platform's installer exists
before reporting an update, and links users to Veasel when it does not.
Historical Toolkit Desktop release assets and user data are left untouched.

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
