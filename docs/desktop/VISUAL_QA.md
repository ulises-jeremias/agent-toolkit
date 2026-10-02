# Desktop visual QA

Visual acceptance means running the Electron Desktop, capturing it, opening the PNG at its actual size, critiquing composition and legibility, changing the implementation, and capturing again. Generated assets and passing tests do not prove art quality.

`apps/desktop/e2e/electron/capture.spec.ts` captures both compact and large windows with real backend state. Run it after `pnpm --filter agent-toolkit-desktop build:all` and a V backend build:

```sh
ATK_CAPTURE=1 ATK_CAPTURE_DIR=/tmp/atk-visual-review \
ATK_E2E_BACKEND_BIN="$PWD/build/agent-toolkit" \
  xvfb-run --auto-servernum --server-args='-screen 0 1920x1080x24' \
  pnpm --filter agent-toolkit-desktop exec playwright test --project=electron capture.spec.ts
```

Review fresh empty/one/many-project worlds, project selection and interior, People roster/create/import, Library, Operations, swarm configuration/runtime, loops, Terminal, Settings, and onboarding at 1024×640 and 1920×1080. Exercise Meadow and Dusk, zoom, keyboard focus, reduced motion, long text, no backend, and real runtime/exit states. Do not claim a state was reviewed merely because a capture file exists. Record the source SHA and actual files opened in the PR.

The world is the dominant `/world` surface. Projects are actual buildings and shared capabilities have distinct places. A configured offline Person is shown in the roster, never as a world worker. Runtime characters require a real session/job/run and disappear when it ends. Furniture, signs, labels, and ambient animation must not imply nonexistent activity.

The old native V Paper/Ink golden fixtures and Xvfb coordinate scripts were retired with that GUI. Electron E2E and packaged-app acceptance are the executable gates. Screenshots checked into `static/screenshots/` are documentation examples and must be recaptured from the current app whenever the pictured UI changes.
