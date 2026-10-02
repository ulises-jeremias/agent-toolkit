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

## Latest opened review — 2026-10-02

Source build `9deb8f6b` (Linux Electron E2E). The project-link tour captures
empty, one-project and three-project worlds at 1024×640 and 1920×1080, then
enters a project and opens its real Files and Terminal routes. The People
session tour captures Lina offline, the real PTY-bound character at her project
house, and the roster after the process exits. The multi-project large capture
exposed an under-scaled camera; the layout was compacted and the final image
was recaptured at integer zoom 32. A separate job test now waits for world
hydration and verifies the completed short job leaves no worker behind.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png),
  [one project, large](assets/electron/world/world-one-project-large.png), and
  [several projects, large](assets/electron/world/world-several-projects-large.png).
- [Completed job with no runtime character](assets/electron/world/world-job-completed-large.png).
- [Project interior, compact](assets/electron/world/project-files-room-compact.png).
- [Live Person session, compact](assets/electron/people/world-person-compact.png),
  [live Person session, large](assets/electron/people/world-person-large.png),
  and [offline Person after stop](assets/electron/people/people-offline-after-stop.png).

The old native V Paper/Ink golden fixtures and Xvfb coordinate scripts were retired with that GUI. Electron E2E and packaged-app acceptance are the executable gates. Screenshots checked into `static/screenshots/` are documentation examples and must be recaptured from the current app whenever the pictured UI changes.
