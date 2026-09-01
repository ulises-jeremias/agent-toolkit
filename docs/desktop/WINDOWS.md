# Windows — vlang/gui Limitations + Packaging Spike

> `V 0.5.2`, `VMODULES=modules`, `vlang/gui` only in `desktop/`, plane guard `! grep -r "import.*gui" modules/desktop_engine`, `docs/desktop/PACKAGING.md` Windows section.

This doc honestly documents `vlang/gui` Windows limitations per upstream `vlang/gui/docs/WINDOWS.md` + spike 0.3 (#1018) and the WiX vs Inno Setup vs NSIS evaluation required by EPIC 7 (7.3 Windows) — spike table is acceptance gate, installer impl follows spike verdict.

## Upstream Windows limitations (per `vlang/gui/docs/WINDOWS.md`)

| Windows limitation (per upstream) | Status | Mitigation |
|---|---|---|
| Windows MSVC requirement (master needs MSVC, not mingw) | ⚠️ partial | ADR-031 fallback: `setup-v` on Windows falls back to `V 0.5.2` artifact when master requires MSVC; local dev installs Visual Studio Build Tools |
| Windows D3D11 backend (sokol d3d11 vs OpenGL) | ⚠️ partial | `sokol` auto-selects `d3d11` on Windows; no custom GL pipeline; shader uses `sokol-shdc` cross-compile; AD R records shader stance (prefer SDF/shadow via `gui` primitives) |
| Windows IME + high-DPI manifest + dialog theming | ⚠️ partial | Manual smoke on Windows required per acceptance; headless Linux CI skips native probe; ADR records manual checklist with screenshots |
| Windows file dialogs + clipboard + DnD sandboxing | ⚠️ partial | Common dialogs via `ComDlg32`; clipboard via `Win32`; DnD requires OLE; sandboxed stores (MS Store) may block dialogs |
| Native open/save/folder dialogs | ⚠️ partial | `sokol` native dialog helper + `tinyfiledialogs` fallback; Windows: `Win32` common dialogs via `sokol`; vet on Linux headless returns stub without blocking |
| Clipboard (text-only) | ⚠️ partial | `sokol` clipboard (text only); on Wayland/X11 verify via `wl-copy/xclip` bridge; headless stub returns empty without error |
| Drag-and-drop (OS files + text onto canvas) | ❌ missing | `sokol` `dropped_files` where available; Wayland DnD protocol-limited; in-app reorder remains internal drag, not OS DnD |
| Toasts / native notifications | ❌ missing | In-app toast overlay (non-blocking, auto-dismiss, `reduced-motion` instant); native `libnotify`/`WinToast` later, not Phase 0 |
| IME / CJK composition | ⚠️ partial | Rely on `sokol` IME composition events + `vglyph` shaping; test CJK composition on Linux/macOS; Windows IME via `sokol_app` composes partially |
| BiDi / ligatures / emoji / Unicode / OpenType | ⚠️ partial | `vglyph` + HarfBuzz-equivalent via `sokol` font path; emoji as color glyphs where available; BiDi via `fribidi`-style pass |
| Text measurement / rotation / clipping | ✅ supported | `gg` text measurement + `vglyph` metrics; rotation via canvas transform; clipping via `sokol` scissor |
| High-DPI / fractional scaling | ⚠️ partial | `sokol` `dpi_scale` + `gui` density; test fractional 125%/150% on Linux/Wayland; Windows high-DPI quirks per WINDOWS.md (DPI awareness manifest) |

Each gap is `✅` / `⚠️` with mitigation — no hidden claim. Links to a11y (§7.2) gaps (IME/CJK, high-DPI, dialogs) per EPIC 7.

## Native surface probe (headless + manual)

`modules/agent_toolkit_gui/native.v` — `probe_native()` headless-safe (never opens dialog/clipboard on CI). Manual `macos-latest` / `windows-latest` runner smoke documented in `distribution/desktop/*/package.sh` logs (`Native probe headless vs DISPLAY`).

Windows probe on `windows-latest` (`setup-v@0.5.2`):

```
v run distribution/desktop/windows/probe.vsh
# logs: native probe windows: 3/7 available (stubs expected headless: dialog/clipboard via Win32, DnD deferred)
```

CI on Linux shows bundle structure cross-build with ⚠️ doc when `windows-latest` runner unavailable.

## Installer spike: WiX vs Inno Setup vs NSIS

| Criterion | WiX Toolset | Inno Setup | NSIS |
|---|---|---|---|
| License | MS-RL | Inno (BSD-like) | zlib/libpng |
| Script authoring | `wxs` XML | Pascal script `iss` | NSIS script |
| Silent install `/S` | ✅ | ✅ | ✅ |
| Per-user vs per-machine | ✅ | ✅ | ✅ |
| Bundles native DLLs side-by-side | ✅ | ✅ | ✅ |
| Code sign integration (`signtool`) | ✅ | ✅ | ✅ |
| `vlang/gui` Windows window tested | probe pending (needs `windows-latest` `vlang/gui` window smoke) | probe pending | probe pending |
| CI `windows-latest` support | `wix` action | `iscc` | `makensis` |

### Verdict: Inno Setup

**Recommend Inno Setup** for `distribution/desktop/windows/`:

- Simplicity: Pascal `iss` is concise vs `wxs` XML verbosity; NSIS script is terse but less maintained.
- Enterprise vs portable: WiX MSI is enterprise-preferred, Inno `exe` is portable and still supports per-machine/per-user + silent `/S`.
- Native DLL bundling: all three bundle side-by-side, Inno `iss` `[Files]` + `reg` clean.
- `signtool` integration: `SignTool=signtool sign /fd SHA256 /tr http://timestamp.digicert.com` in `iss` works like WiX `sign`.
- `vlang/gui` window: spike must probe `vlang/gui` window on Windows — Inno `wizard` UX + CI `iscc` is lowest friction; WiX `wix build` hello-world also works but heavier.
- CI cost: `iscc` on `windows-latest` is single binary, `wix` needs `dotnet`, `makensis` is similar but community smaller.

No code change to `vlang/gui` required. Spike doc is acceptance gate — installer impl follows spike decision (PR cannot merge without spike section). `make.vsh package-desktop-windows` produces `build/agent-toolkit-windows-$VERSION.exe` (Inno) containing `agent-toolkit.exe` + bundled DLLs + `agent-toolkit://` registry key + Start Menu shortcut + uninstall entry.

## Native deps bundling

Document how `FreeType`/`HarfBuzz`/`Pango`/`vglyph` (if used by `vlang/gui`) are bundled:

- Status: `vglyph` is V-native (no DLL); `FreeType`/`HarfBuzz`/`Pango` are abstracted via `vlang/gui` → `sokol`/`gg`/`vglyph` path. On Windows they map to `DirectWrite`/`GDI` where `vlang/gui` abstracts — no separate DLL required for `vglyph` rendering; if `Pango`/`HarfBuzz` were linked, they would be side-by-side DLLs in `build/windows/` with `ldd`/`objdump` + `sha256sum` logs and size delta vs `+4.8M` ELF baseline recorded.
- `make.vsh package-desktop-windows` logs `ldd`/`sha256sum` of bundled DLLs (if any) and `ls -lh build/*windows*` size vs baseline.
- Fallback to system `DirectWrite`/`GDI` where `vlang/gui` abstracts — not a separate `vcpkg`/`msys2` prereq (hurts single-binary portability).

## Packaging adapter

`distribution/desktop/windows/`:

- `package.sh` — cross-build installer structure on Linux + real `.exe` on `windows-latest` (`setup-v@0.5.2`); `file`/`sha256sum`/`ls -lh`; launch smoke `agent-toolkit.exe --version` + `doctor` (FHS/embedded tiers, receipts); deep-link registry smoke `reg query HKCU\Software\Classes\agent-toolkit`.
- `installer.iss` — Inno Setup script stub (after spike choice) for `agent-toolkit.exe` + DLLs + URL handler + shortcut + uninstall; `signtool verify` path with `${WINDOWS_CODESIGN_CERT}` env (ad-hoc unsigned in PR, real sign `release.yml` gated, no cert in repo).
- `probe.vsh` — headless `windows_limitations()` markdown render for CI artifact.

## Verification

- Spike: `docs/desktop/WINDOWS.md` diff shows table + verdict; reviewer can reproduce `iscc`/`makensis`/`wix build` hello-world installer on `windows-latest` per doc.
- Packaging: `windows-latest` job `make.vsh package-desktop-windows` with `setup-v@0.5.2`, `file` + `sha256sum` + `agent-toolkit.exe --version` + `doctor` logs; artifact uploaded; size `ls -lh build/*windows*`.
- Deep-link/registry: `reg query HKCU\Software\Classes\agent-toolkit` shows URL protocol; `start agent-toolkit://open?repo=C:\tmp` smoke or doc ⚠️.
- Secrets: `gitleaks`/`validate-secrets` on `build/` + `distribution/desktop/windows/`; `grep -R "WINDOWS_CODESIGN"` shows `${ENV_VAR}` only.
- Vet: `v vet` + `make.vsh vet`, plane guard `! grep -r "import.*gui" modules/desktop_engine`.

## A11y note

Windows high-DPI + IME gaps link to EPIC 7 §7.2 accessibility (high-DPI token scaling, `reduced-motion`, typography `CJK/emoji/BiDi`). Doc cross-refs `docs/desktop/PACKAGING.md` macOS/Windows packaging and `docs/desktop/WORLD_VIEW.md` workshop metaphor.
