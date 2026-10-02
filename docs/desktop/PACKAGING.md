# Desktop packaging

Agent Toolkit Desktop is the Electron application in `apps/desktop`. It bundles the V `agent-toolkit` backend. The V modules and CLI own domain logic; Electron owns presentation, PTY windows, and interaction. The former native V GUI was removed.

## Local build

Build the backend from this checkout, then package the Desktop:

```sh
PATH="$HOME/vlang-master:$PATH" VMODULES="$PWD/modules" ./make.vsh build-cli
ATK_BACKEND_BIN="$PWD/build/agent-toolkit" pnpm --filter agent-toolkit-desktop dist:dir
```

The unpacked Linux build is `apps/desktop/release/linux-unpacked/agent-toolkit-desktop`. `pnpm --filter agent-toolkit-desktop dist` produces Linux AppImage/deb, macOS DMG, or Windows NSIS for the current host. `stage:backend` copies the real platform binary to `resources/bin` and pins its probed version; it fails if no backend is available. The release workflow builds both on each target platform and checks the source, backend, and Electron versions match.

The package contains the compiled renderer, Electron main process, and backend. It must work from an unrelated current directory and a fresh HOME/XDG environment. `Clean-machine Desktop Acceptance` packages the app and drives the packaged executable with Playwright and an isolated HOME. The normal Desktop workflow is also covered by `.github/workflows/desktop.yml`.

## Release assets

The tag workflow publishes platform installers from electron-builder alongside CLI binaries and archives. The CLI archives and `manifest.json` describe the CLI only; Desktop installers are separate release assets named `agent-toolkit-desktop-<version>-<os>-<arch>.<ext>`. Linux users can install the `.deb` or run the AppImage. macOS uses DMG and Windows uses NSIS. Signing/notarization must be configured separately before claiming trusted OS distribution.

The GUI command in older CLI releases advertised a native V binary. Use the Desktop installer from the release page until the CLI's Electron installer path is verified end to end. A local launcher may point at the unpacked package, but it is machine-specific and not part of the release artifact.
