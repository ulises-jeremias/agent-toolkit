# ADR-041 — Notify-only Desktop update check until signing exists

- **Status:** Accepted (2026-10-21); implemented in this slice
- **Deciders:** ulises-jeremias (owner)
- **Related:** Pack H gap 1 (auto-update + signing), signing policy issue #543 (closed as policy)

## Context

Desktop artifacts (AppImage/deb/dmg/nsis) ship unsigned:
`electron-builder.yml` has `publish: null` and there are no code-signing
certificates configured for macOS Gatekeeper or Windows SmartScreen.
Competitors show the two honest patterns: Munder Difflin runs
`electron-updater` against a signed GitHub feed with a creds-gated
notarization hook; Codexia signs updater artifacts with a minisign key.
Both presuppose signing material this project does not yet have.

Installing an updater now would mean downloading and executing
unverifiable binaries — worse than no updater. But users currently get
no signal at all that a newer Desktop exists.

## Decision

1. **Notify-only check.** Electron main (`electron/update-check.ts`)
   queries the GitHub `releases/latest` API with a 5 s timeout, caches
   the result on disk for 24 h, and compares versions numerically
   (a full release beats its own prerelease). The renderer reads it
   over `atk:update-status`; Settings shows installed vs latest and,
   when newer, links to the release page. Check failures degrade to
   the last cached result or an honest "unavailable" — never a fake
   "up to date".
2. **No self-update.** Desktop never downloads or applies an update by
   itself while artifacts are unsigned. The manual path (download,
   verify against the release `SHA256SUMS`, install) is documented in
   `docs/TRUST.md` ("Desktop updates"), and `publish: null` carries a
   comment recording why.
3. **Doc drift fixed.** `docs/security/threat-model.md` claimed Trivy
   scanning as implemented while `docs/TRUST.md` marks it Planned
   (#260); the threat model now agrees with TRUST.

## Consequences

- Users learn about new Desktop releases in-app, at most one network
  check per day, with zero silent binary execution added.
- When signing certificates land, the migration is mechanical: set the
  electron-builder publish provider, keep `UpdateChecker` as the
  pre-check/notification surface, and let a signed updater apply.
- Cross-platform packaged acceptance (real macOS/Windows installs) is
  still unevidenced; no claim is made until it runs on those machines.
