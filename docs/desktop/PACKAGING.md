# Desktop Packaging

> `VERSION 1.27.0` channel, single-repo-one-binary `V 0.5.2`, `VMODULES=modules`, `gen-embedded`, `distribution/` contracts, `manifest.json`+`SHA256SUMS` per ADR-022, `docs/RELEASING.md` signed-tag gate (maintainer-only, no premature publish).

## Linux (baseline)

`build/agent-toolkit` ELF + `SHA256SUMS` + `manifest.json` via `distribution/github-release` (existing). Size baseline `+4.8M` ELF (embedded_data). `agent-toolkit --version` + `doctor` green (FHS/embedded tiers, receipts).

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
- `CFBundleVersion=$VERSION` (`1.27.0` channel, from `VERSION` file)
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
- real `codesign`/`hdiutil` on `macos-latest` (`setup-v@0.5.2`)
- smoke `build/AgentToolkit.app/Contents/MacOS/agent-toolkit --version` + `doctor`; `file` Mach-O; `sha256sum`; `ls -lh` size vs `+4.8M` baseline.

Artifact verified: `Info.plist` `CFBundleVersion == VERSION`, `file` Mach-O, `sha256sum` logged, size recorded.

Deep-link: `agent-toolkit://open?repo=/tmp` registered via `CFBundleURLSchemes`; smoke `open "agent-toolkit://open?repo=/tmp"` or plist registration check.

Gatekeeper: `spctl -a -t exec -vv build/AgentToolkit.app` logged (allow ⚠️ for ad-hoc with doc — real Developer ID passes, ad-hoc shows `rejected` with note).

See also `docs/desktop/WINDOWS.md` cross-ref for Gatekeeper/notarization gaps.

## Windows (7.3) — spike + impl

`distribution/desktop/windows/` + `docs/desktop/WINDOWS.md` spike doc.

### Native deps bundling

`FreeType`/`HarfBuzz`/`Pango`/`vglyph` (if used by `vlang/gui`) status documented per build:

- static link vs DLL side-by-side in `build/windows/`; `make.vsh package-desktop-windows` logs `ldd`/`objdump` + `sha256sum` of bundled DLLs; size impact vs `+4.8M` ELF baseline recorded; fallback to system `DirectWrite`/`GDI` where `vlang/gui` abstracts.

### Installer spike (EVALUATE, not premature pick)

| Criterion | WiX Toolset | Inno Setup | NSIS |
|---|---|---|---|
| License | MS-RL | Inno (BSD-like) | zlib/libpng |
| Script authoring | `wxs` XML | Pascal script `iss` | NSIS script |
| Silent install `/S` | ✅ | ✅ | ✅ |
| Per-user vs per-machine | ✅ | ✅ | ✅ |
| Bundles native DLLs side-by-side | ✅ | ✅ | ✅ |
| Code sign integration (`signtool`) | ✅ | ✅ | ✅ |
| `vlang/gui` Windows window tested | probe pending (spike 0.3 #1018) | probe pending | probe pending |
| CI `windows-latest` support | `wix` action | `iscc` | `makensis` |

**Spike verdict: choose Inno Setup** (recommendation — simplicity, Pascal `iss` authoring, `iscc` CI support, bundles DLLs, `signtool` integration). WiX is MSI enterprise alternative, NSIS is lightweight zlib but script ergonomics lower. Verdict justified by probing `vlang/gui` window on Windows, installer UX, CI cost — spike doc is acceptance gate, installer impl follows decision. No `vlang/gui` code change required.

### Impl after spike

`make.vsh package-desktop-windows` builds `build/agent-toolkit-windows-$VERSION.exe` (Inno `iss`) containing `agent-toolkit.exe` + bundled DLLs + `agent-toolkit://` registry key (`HKCU\Software\Classes\agent-toolkit`), Start Menu shortcut, uninstall entry; `signtool verify` path documented with `${WINDOWS_CODESIGN_CERT}` env (ad-hoc unsigned in PR, real sign in `release.yml` gated, no cert in repo).

Cross-build installer structure on Linux (spike doc + bundle layout) + real `.exe`/`.msi` on `windows-latest` (`setup-v@0.5.2`); `file`/`sha256sum`/`ls -lh`; launch smoke `agent-toolkit.exe --version` + `doctor` (FHS/embedded tiers, receipts); `agent-toolkit://open?repo=` registry smoke via `reg query HKCU\Software\Classes\agent-toolkit`.

### Notes

All packaging respects `V 0.5.2`, single binary, `VMODULES`, `gen-embedded`; aligns `distribution/` contracts, ADR-022 `SHA256SUMS`, `docs/RELEASING.md` publish gated (no premature Homebrew/AUR/NPM/Store publish). No secrets in artifact (`grep` fail), `v vet` green.

## Auto-update (7.4)

`modules/desktop/update/` + `modules/desktop_engine/update_service.v` reuse existing `release.yml` + `manifest.json` pattern (no second update server).

- Feed: `https://github.com/ulises-jeremias/agent-toolkit/releases` + `manifest.json` (ADR-022) as signed feed — `net.http` fetches `version`, `assets[] { name, sha256, url, provenance }`, `channel` (`stable` = `VERSION 1.27.0` line).
- Check: `Engine.check_update(current: VERSION) -> ?UpdateInfo` compares semver, respects `channel: stable|next|pinned:$VERSION`, opt-in `update.auto_check` (default prompt, not silent).
- Download + verify: stream to `XDG_CACHE_HOME/agent-toolkit/updates/$VERSION/`, verify `SHA256` vs `SHA256SUMS` + `manifest.json` provenance; mismatch → discard + rollback (keep current binary).
- Apply + restart: atomic replace (Linux binary swap, macOS bundle swap + xattr, Windows MSI/exe staged). `ProcessSupervisor` handles restart. Kill during update → consistent state (partial discarded, `StateRepository` revision unchanged).
- Rollback: keep previous at `updates/prev/` until `doctor` passes; bad checksum/provenance or `doctor` fail → revert, `EventBus` `update_failed` → toast.
- Opt-in/metered: `update.auto_check` (bool) + `update.metered` (skip on metered where OS exposes); network failure non-destructive (backoff, `update_check_failed` toast).

See `docs/desktop/WORLD_VIEW.md` for Workshop metaphor, `docs/desktop/WINDOWS.md` for Windows limitations, `docs/TRUST.md` receipts, `SECURITY.md` (`${ENV_VAR}` only).
