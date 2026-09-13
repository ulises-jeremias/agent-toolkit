# Desktop Packaging

Status: **CURRENT GUIDE** — re-confirmed 2026-09-13 at `5c7f0e0d` (sandbox install-contract proof: fresh install → idempotent reinstall → foreign-file preservation → receipt-backed uninstall in a temp HOME/XDG; shipped + installed entries pass `desktop-file-validate`).
See [WINDOWS.md](WINDOWS.md) for the honest Windows support status (unproven).

> `VERSION 1.30.0` channel, single-repo-one-binary `V 0.5.2`, `VMODULES=modules`, `gen-embedded`, `distribution/` contracts, `manifest.json`+`SHA256SUMS` per ADR-022, `docs/RELEASING.md` signed-tag gate (maintainer-only, no premature publish).

## GUI (native desktop) build

```sh
# canonical local build — the 4096² fontstash atlas matters: the GUI renders
# Fraunces + IBM Plex Sans/Mono + the CJK/Arabic i18n fonts, and sfons cannot
# expand the atlas at runtime (overflow ⇒ random .notdef tofu).
VJOBS=2 VMODULES="$PWD/modules" v -d gg_text_buff_size=4096 -o build/agent-toolkit-desktop-native cmd/agent-toolkit-desktop
# NOTE: VMODULES must be absolute — with a relative path the C backend runs
# from V's own source dir and cannot write modules/.cache (tcc "No such file
# or directory" on stbi.o).

# run
./build/agent-toolkit-desktop-native                # window (needs DISPLAY)
ATK_GUI_HEADLESS=1 ./build/agent-toolkit-desktop-native   # CI smoke, prints PASS
```

Fonts ship OFL-licensed in `assets/fonts/` (resolved next to the binary: `<exe>/fonts`,
`<exe>/../assets/fonts`, or `$ATK_FONTS`; missing ⇒ system-font fallback).
Regenerate the CJK chrome subset with `scripts/subset-sc-font.sh` after adding
translated strings — it harvests every CJK codepoint from `main.v`.

## Linux (baseline)

`build/agent-toolkit` ELF + `SHA256SUMS` + `manifest.json` via `distribution/github-release` (existing). Size baseline `+4.8M` ELF (embedded_data). `agent-toolkit --version` + `doctor` green (FHS/embedded tiers, receipts).

### Desktop bundle (#1057/#1116, validated by #1130)

`agent-toolkit-desktop-<v>-linux-<arch>.tar.gz` ships, since 2026-09-07:

| Path in archive | Purpose |
|---|---|
| `agent-toolkit-desktop` | native binary (fonts/resources embedded; Engine-owned derived state — `ui_state.env`, `dock.json` — resolves under XDG cache at first run, never in the checkout) |
| `agent-toolkit-desktop.desktop` | Desktop Entry spec launcher (`StartupWMClass` matches the window title) |
| `icons/agent-toolkit-desktop-{16,24,32,48,64,128,256,512}.png` + `-scalable.svg` | hicolor icon set — Paper Co. envelope mark (deterministic generator: `packaging/linux/gen-icon.vsh`) |
| `share/man/man1/agent-toolkit-desktop.1` | man page (synopsis, keymap, env, files) |
| `install-desktop.sh` | receipt-backed per-user install/uninstall |
| `VERSION` | version pinned into the receipt (`install-desktop.sh` refuses without it) |
| `LICENSE` | license |

**Install** (no sudo, XDG user scope):

```
tar xzf agent-toolkit-desktop-<v>-linux-<arch>.tar.gz
./install-desktop.sh install
```

lands: binary → `~/.local/share/agent-toolkit/bin/`, plus a receipt-tracked
copy of the installer itself →
`~/.local/share/agent-toolkit/bin/agent-toolkit-desktop-installer.sh`,
`.desktop` → `~/.local/share/applications/` (Exec rewritten to the installed
binary so launcher sessions work without `~/.local/bin` on PATH — the #1129
concern), icons → `~/.local/share/icons/hicolor/<size>/apps/`, man →
`~/.local/share/man/man1/`, and a schemaVersion-1 install receipt →
`~/.config/agent-toolkit/receipts/agent-toolkit-desktop-linux.json`.
A fresh install records 13 `created` artifacts. All destinations honor
`XDG_DATA_HOME`/`XDG_CONFIG_HOME` with the `~/.local/share`/`~/.config`
fallbacks above.

**Uninstall**: `./install-desktop.sh uninstall` — removes only receipt-owned
(`created`) artifacts, including the installer copy; pre-existing (`merged`)
files are preserved. A previously-owned file you modified flips to `merged`
on the next run and is then preserved too (upgrade overwrites only
byte-identical owned files). The receipt follows the core `InstallReceipt`
schema, so provenance tooling can read it.

`desktop-file-validate` runs in the release workflow on the shipped
(source-tree) entry; the installed Exec-rewritten entry validates too
(proven 2026-09-13 in a temp-HOME sandbox).

### AppImage decision: no-go (deferred)

Do **not** ship an AppImage: the tarball + `install-desktop.sh`
receipt-backed per-user install is the single canonical Linux path.

Rationale: the tarball path is proven end-to-end (fresh install → idempotent
reinstall → foreign-file preservation → receipt-backed uninstall, XDG tier
precedence, absolute Exec, `desktop-file-validate` green on shipped and
installed entries, no source-path leakage, empty-secrets receipts — sandbox
proof 2026-09-13; the BACKLOG_AUDIT precondition of verified installed
assets and cwd independence is met). An AppImage would add a second,
unfinished distribution surface (FUSE/`libfuse2` runtime variance across
distros, desktop-integration prompts, a separate signing/update story) with
no demonstrated user demand beyond the #1057 backlog line. One excellent
install path beats five unfinished ones. Revisit only when a
portable-single-file requirement is proven and someone owns the FUSE/distro-matrix
testing.

### Acceptance harnesses (all `.vsh`, all in `make.vsh`)

The install → launch → uninstall chain is proven by V harnesses against the
real packed tarball (never the source tree), in CI
(`.github/workflows/clean-machine-acceptance.yml`) and locally:

| Harness | Command | What it proves |
|---|---|---|
| `scripts/clean-machine.vsh` | `./make.vsh clean-machine --artifact=<tarball>` | layers A–B (structure, receipt-backed install, provenance, fonts, tool discovery) + receipt-backed uninstall with foreign-file preservation; layer C (Xvfb first-render) where Xvfb exists |
| `scripts/first-run.vsh` | `./make.vsh first-run --artifact=<tarball>` | #1127 zero-to-working onboarding via real keys (clean, fixture, failure, interrupted, existing-state scenarios) |
| `scripts/workspace-lifecycle.vsh` | `./make.vsh workspace-lifecycle --artifact=<tarball>` | #1128 workspace switch/restart/seed-safety/invalid-path via real panel controls |
| `scripts/browser-install.vsh` | `./make.vsh browser-install` | `agent-toolkit gui` install/run UX in an isolated HOME (release URL, prefix, missing-binary guidance) |
| `scripts/dmg-boot.vsh` | `./make.vsh dmg-boot` | macOS DMG first-boot (SKIP on other OSes) |

States are explicit per check (`PASS`/`FAIL`/`NOT_PROVEN`/`MANUAL`) — a missing
tool or capture is never a silent pass. Parallel local runs take the shared
acceptance display lock and fail loudly instead of colliding.

## macOS (7.3)

`distribution/desktop/macos/` — packaging adapter.

### Bundle layout

```
build/AgentToolkit.app/
  Contents/
    MacOS/agent-toolkit          # Mach-O from make.vsh build-cli
    Resources/agent-toolkit.icns # icns from 1024x1024.png → iconset → iconutil
    Info.plist
```

`Info.plist` keys:

- `CFBundleIdentifier=dev.agent-toolkit.desktop`
- `CFBundleVersion=$VERSION` (`1.30.0` channel, from `VERSION` file)
- `CFBundleExecutable=agent-toolkit`
- `LSMinimumSystemVersion=13.0`
- `CFBundleURLSchemes=agent-toolkit` (`agent-toolkit://` deep-link)
- `NSHighResolutionCapable=true`
- `LSApplicationCategoryType=public.app-category.developer-tools`

Icon: `static/icons/agent-toolkit.icns` generated via `iconutil -c icns` from `1024x1024.png` → `iconset` → `icns` (crisp 1x/2x via high-DPI dogs from 7.2).

### Codesign

- CI smoke: `codesign --force --deep --sign - build/AgentToolkit.app` (ad-hoc). `codesign --verify --verbose=4 build/AgentToolkit.app` logged.
- Real `Apple Development` / `Developer ID`: `codesign --sign "${APPLE_CODESIGN_IDENTITY}"` (env only, no hardcoded cert per `SECURITY.md` `${ENV_VAR}` only). Real sign is `release.yml` gated (requires secrets, not run in PR).

### Notarization

`xcrun notarytool submit build/agent-toolkit-macos-$VERSION.dmg --apple-id "${APPLE_ID}" --team-id "${APPLE_TEAM_ID}" --password "${APPLE_APP_SPECIFIC_PASSWORD}" --wait` + `xcrun stapler staple`. PR builds `notarization: false` but scripts exist and are `release.yml` gated. No Apple creds in repo (`grep -R "APPLE" distribution/desktop/macos` shows `${ENV_VAR}` only).

### DMG

`hdiutil create -volname "Agent Toolkit" -srcfolder build/AgentToolkit.app -ov -format UDZO build/agent-toolkit-macos-$VERSION.dmg` (or `create-dmg`). `hdiutil verify build/*.dmg` logged. Background `dmg-background.png` optional from tokens.

### Make target

`make.vsh package-desktop-macos` (and matrix entry `package-desktop`):

- cross-build bundle structure on Linux (plist + icns layout without `codesign`/`hdiutil`, with doc ⚠️)
- real `codesign`/`hdiutil` on `macos-latest` (pinned V via `setup-v`)
- release link flags: `v -prod -cc clang` on macOS, `v -prod -cc gcc` on Linux (never default tcc — tcc emits a runner-absolute `@rpath/libgc.dylib` that aborts with `dyld: Library not loaded` on user machines; upstream V reserves tcc for dev builds). Windows keeps default flags: that leg runs the V 0.5.2 fallback toolchain, which cannot `-prod` the stdlib `import json` in `modules/agent_toolkit_server/server.veb.v`
- linkage gates: macOS `otool -L` must show no `/Users/runner`, `thirdparty/tcc`, or `@rpath/libgc` refs; Linux `ldd` must show no `not found`; Windows logs the DLL inventory (`release.yml` fails the job; `package.sh` fails before codesign). PRs prove the flags via the `linkage-smoke` job (CLI + desktop on all three OSes)
- smoke `build/AgentToolkit.app/Contents/MacOS/agent-toolkit --version` + `doctor`; `file` Mach-O; `sha256sum`; `ls -lh` size vs `+4.8M` baseline.

Artifact verified: `Info.plist` `CFBundleVersion == VERSION`, `file` Mach-O, `sha256sum` logged, size recorded.

Deep-link: `agent-toolkit://open?repo=/tmp` registered via `CFBundleURLSchemes`; smoke `open "agent-toolkit://open?repo=/tmp"` or plist registration check.

Gatekeeper: `spctl -a -t exec -vv build/AgentToolkit.app` logged (allow ⚠️ for ad-hoc with doc — real Developer ID passes, ad-hoc shows `rejected` with note).

See also `docs/desktop/WINDOWS.md` cross-ref for Gatekeeper/notarization gaps.

## Windows (7.3) — spike decided, impl pending

`distribution/desktop/windows/` + `docs/desktop/WINDOWS.md` spike doc.
Windows is unproven at HEAD — no `windows-latest` build, window smoke, or
installer run recorded. The Inno Setup verdict in WINDOWS.md is the
evaluation gate; the installer implementation and `windows-latest` evidence
follow the verdict. The Phase-0 feasibility implementation retired in #1206
does not change this: production is `gg`/`sokol`-direct.

### Native deps bundling

`FreeType`/`HarfBuzz`/`Pango`/`vglyph` (if used by the `gg`/`sokol` renderer) status documented per build (see `docs/desktop/WINDOWS.md` for the production rendering reality):

- static link vs DLL side-by-side in `build/windows/`; `make.vsh package-desktop-windows` logs `ldd`/`objdump` + `sha256sum` of bundled DLLs; size impact vs `+4.8M` ELF baseline recorded; fallback to system `DirectWrite`/`GDI` where the `gg`/`sokol` renderer abstracts.

### Installer spike (decided: Inno Setup — impl pending, not premature pick)

| Criterion | WiX Toolset | Inno Setup | NSIS |
|---|---|---|---|
| License | MS-RL | Inno (BSD-like) | zlib/libpng |
| Script authoring | `wxs` XML | Pascal script `iss` | NSIS script |
| Silent install `/S` | ✅ | ✅ | ✅ |
| Per-user vs per-machine | ✅ | ✅ | ✅ |
| Bundles native DLLs side-by-side | ✅ | ✅ | ✅ |
| Code sign integration (`signtool`) | ✅ | ✅ | ✅ |
| `gg`/`sokol` Windows window tested | probe pending on `windows-latest` (Phase-0 spike #1018 closed; feasibility implementation retired #1206) | probe pending | probe pending |
| CI `windows-latest` support | `wix` action | `iscc` | `makensis` |

**Spike verdict: choose Inno Setup** (recommendation — simplicity, Pascal `iss` authoring, `iscc` CI support, bundles DLLs, `signtool` integration). WiX is MSI enterprise alternative, NSIS is lightweight zlib but script ergonomics lower. Verdict justified by probing the `gg`/`sokol` window on Windows, installer UX, CI cost — spike doc is acceptance gate, installer impl follows decision. No renderer code change required.

### Impl after spike

`make.vsh package-desktop-windows` builds `build/agent-toolkit-windows-$VERSION.exe` (Inno `iss`) containing `agent-toolkit.exe` + bundled DLLs + `agent-toolkit://` registry key (`HKCU\Software\Classes\agent-toolkit`), Start Menu shortcut, uninstall entry; `signtool verify` path documented with `${WINDOWS_CODESIGN_CERT}` env (ad-hoc unsigned in PR, real sign in `release.yml` gated, no cert in repo).

Cross-build installer structure on Linux (spike doc + bundle layout) + real `.exe`/`.msi` on `windows-latest` (`setup-v@0.5.2`); `file`/`sha256sum`/`ls -lh`; launch smoke `agent-toolkit.exe --version` + `doctor` (FHS/embedded tiers, receipts); `agent-toolkit://open?repo=` registry smoke via `reg query HKCU\Software\Classes\agent-toolkit`.

### Notes

All packaging respects `V 0.5.2`, single binary, `VMODULES`, `gen-embedded`; aligns `distribution/` contracts, ADR-022 `SHA256SUMS`, `docs/RELEASING.md` publish gated (no premature Homebrew/AUR/NPM/Store publish). No secrets in artifact (`grep` fail), `v vet` green.

## Auto-update (7.4) — design only, honestly unavailable

Update stays honestly unavailable until a real feed reader/updater exists:
no release-feed reader or updater exists, so Update is an
honestly-unavailable application action in the registry — it cannot execute
(see #1063 and [WORKFLOW_COVERAGE.md](WORKFLOW_COVERAGE.md)). The design
below is not implemented. `modules/desktop_engine/update_service.v` would
reuse the existing `release.yml` + `manifest.json` pattern (no second update
server). The former `modules/desktop/update/` GUI-side mock feed was
removed.

- Feed: `https://github.com/ulises-jeremias/agent-toolkit/releases` + `manifest.json` (ADR-022) as signed feed — `net.http` fetches `version`, `assets[] { name, sha256, url, provenance }`, `channel` (`stable` = `VERSION 1.30.0` line).
- Check: `Engine.check_update(current: VERSION) -> ?UpdateInfo` compares semver, respects `channel: stable|next|pinned:$VERSION`, opt-in `update.auto_check` (default prompt, not silent).
- Download + verify: stream to `XDG_CACHE_HOME/agent-toolkit/updates/$VERSION/`, verify `SHA256` vs `SHA256SUMS` + `manifest.json` provenance; mismatch → discard + rollback (keep current binary).
- Apply + restart: atomic replace (Linux binary swap, macOS bundle swap + xattr, Windows MSI/exe staged). `ProcessSupervisor` handles restart. Kill during update → consistent state (partial discarded, `StateRepository` revision unchanged).
- Rollback: keep previous at `updates/prev/` until `doctor` passes; bad checksum/provenance or `doctor` fail → revert, `EventBus` `update_failed` → toast.
- Opt-in/metered: `update.auto_check` (bool) + `update.metered` (skip on metered where OS exposes); network failure non-destructive (backoff, `update_check_failed` toast).

See `docs/desktop/WORLD_VIEW.md` for Workshop metaphor, `docs/desktop/WINDOWS.md` for Windows limitations, `docs/TRUST.md` receipts, `SECURITY.md` (`${ENV_VAR}` only).
