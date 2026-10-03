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

## Latest opened review — 2026-10-03

### Workspace switch and project isolation — 2026-10-03

Source build `8377e06a`, Linux Electron E2E with a temporary HOME. The GUI
switches from the initialized empty workspace to a second workspace, links a
real `maple-worker` folder, and shows its project building in the World. It
then switches back and confirms the original workspace still has no projects.
The test waits for the supervised backend to return to Live after each
restart. The transient "Project linked" receipt obscured the map in the first
capture, so the capture flow now dismisses it before taking the final images.

The state change is clear at both sizes, and the return image shows the real
empty-workspace state rather than a stale project. The visual review still
finds the project building small in the compact view and the field too broad
and regular at large size; this evidence closes the workspace-switch journey,
not the broader world-art quality gap.

Opened files:

- [Alternate workspace with project, compact](assets/electron/workspace/workspace-project-compact.png)
  and [large](assets/electron/workspace/workspace-project-large.png).
- [Returned empty workspace, compact](assets/electron/workspace/workspace-return-compact.png)
  and [large](assets/electron/workspace/workspace-return-large.png).

Linux Electron capture after terrain-generator and capture-viewport changes.
The review reopened empty, one-project, and multi-project workspaces at
1024×640 and 1920×1080. The first high-contrast grass palette produced a
checkerboard at map scale; that iteration was rejected. The final palette
variation is deliberately subtler. The creek now has a slower two-wave bend,
shoreline reeds, and more varied framing trees. The capture helper waits for
the renderer to reach its requested viewport before taking evidence, removing
the intermittent undersized first screenshot.

The new captures confirm stable layout and readable landmarks at both sizes.
They also confirm that the art gap remains: the large meadow still reads as a
wide lawn, project paths are visibly angular, and the landmark sprites are
simple at full scale. These images are current evidence, not a claim that the
world has reached the supplied art-direction target; terrain composition and
building art need a deeper pass.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).

## Opened review — 2026-10-02

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

## Semantic world interaction review — 2026-10-02

Source build `91cc2058` (Linux Electron E2E; temporary workspace/backend). The
capture journey was rerun after
the map bounds, semantic activation labels, memory archive routes and project
lot dressing changed. Opened the fresh empty, one-project (compact and large),
several-projects (compact and large), and project Files-room captures.

The large one-project capture still exposes a substantial art/composition gap:
the landmarks are useful and legible, but the grass field dominates, buildings
read as small isolated icons, and the terrain/path composition is too regular
and sparse for the intended cozy game-world quality. This is a concrete follow-
up for the world-art pass; the current change improves spatial scale and direct
interaction without claiming that the art direction is finished. In response
to the compact camera review, the map now sizes its horizontal bounds around
occupied project lots and keeps the first house nearer the commons. In response
to the semantic interaction review, active controls now name their actual
destination, environmental decoration is no longer focusable, and archive
objects focus the corresponding real Memory archive in the World index.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Loop scheduling review — 2026-10-02

Source build `884a9dbb` (Linux Electron E2E, temporary HOME). The schedule
journey lists the real user-level scheduler state, previews file paths and
cadence, then installs and disables a schedule through the existing backend
operation. The test's first-in-PATH `systemctl` shim forces install and stop
failures, verifies that files remain after an incomplete disable, and retries
the real action; generated unit files are created and removed under the
temporary HOME. The V unit fixture uses the same isolation principle. Neither
test can enable, stop, or disable a timer on the host.

The first screenshot review showed the entire generated unit taking over the
dialog. I changed the preview to lead with the exact target paths and trigger,
put the full generated service/timer behind an expandable details row, and kept
the confirm action fixed in the dialog footer. The compact capture still scrolls
the long content while keeping that action visible. I also dismissed the run
receipt before capturing the final report so it no longer obscures real state.
The recovery capture initially showed a generic backend hint, so I replaced it
with schedule-specific guidance and a retry button that repeats the failed
preview or apply step. At compact size the dialog scrolls to the recovery
message while the close and disable controls stay fixed at the bottom.

Opened files:

- [Schedule preview, compact](assets/electron/loops/loop-schedule-preview-compact.png)
  and [large](assets/electron/loops/loop-schedule-preview-large.png).
- [Schedule recovery, compact](assets/electron/loops/loop-schedule-recovery-compact.png)
  and [large](assets/electron/loops/loop-schedule-recovery-large.png).
- [Loop report, compact](assets/electron/loops/loop-report-compact.png),
  [large](assets/electron/loops/loop-report-large.png), and
  [completed run](assets/electron/loops/loop-report-after-run.png).

The old native V Paper/Ink golden fixtures and Xvfb coordinate scripts were retired with that GUI. Electron E2E and packaged-app acceptance are the executable gates. Screenshots checked into `static/screenshots/` are documentation examples and must be recaptured from the current app whenever the pictured UI changes.

## Rich meadow and single-project scale review — 2026-10-02

Source build `f8d94a94`, Linux Electron capture against a bundled local backend
and temporary HOME. The one-project valley now fits at
integer zoom 48 in a large window; three projects remain at integer zoom 32.
The terrain generator now uses deterministic, hand-authored clover and blade
clusters in its six grass variants, and the checked-in PNGs were regenerated
from that source.

Opened the compact one-project capture, the large one-project capture, the
large three-project capture, and the large project interior. Increasing the
one-project zoom made houses, path approaches, trees and bridge easier to read.
The grass motifs add visible texture without turning the ground into a grid of
stripes. The review still finds large calm areas too uniform, the creek bends
too mechanically, and the project interior leaves substantial empty floor
between its semantic objects. These remain follow-up art/composition work; the
new scale and texture are an incremental improvement, not the end-state.

Opened files:

- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, large](assets/electron/world/project-files-room-large.png).

## Library installation and removal — 2026-10-03

Captured from the built Electron app against the real V backend with a disposable
HOME. The install dialog shows detected targets as selectable choices, makes the
user refresh the dry-run after changing destinations, and enables apply only when
the selected set still matches the preview. The captured review explicitly targets
Claude Code and Cursor and reports 453 planned files, including profiles, Agent
Definitions, complete Skills and references. After installation the Library shows
real receipt rows with product, target, ownership counts, and a disclosure for the
local receipt path. The removal preview reads those receipts and scrolls paths in
the framed game-menu dialog while keeping confirmation fixed. Pre-existing user
content and a Toolkit file edited after installation survived the real removal.
The World tool inspector routes into this same Library review with the relevant
destination preselected; it no longer exposes a global install action or asks users
to run the CLI hint shown by the backend catalog.
GitHub Copilot remains explicitly outside this user-level installer because its
capabilities belong in a project repository; the dialog calls out that scope and
the workflow ledger keeps this journey partial until that project-scoped flow exists.

Reviewing the first captures caught two product issues: the install dialog still
said “profiles” after the operation expanded to catalog Skills, and the removal
capture included the successful-install receipt over the preview. I renamed the
dialog and confirmation action to describe the reviewed files and dismissed the
receipt before taking the final removal screenshots. At compact size the preview
stays scrollable with both actions visible; at the wider size the Library context
remains visible around the modal. The large removal list is intentionally dense,
but remains crisp, selectable monospace text with a visible scrollbar.

The follow-up review also caught a safety gap that screenshots alone could not
show: the removal confirmation was not bound to the plan that had been reviewed.
The backend now rejects a stale plan before deleting anything, and the Desktop
keeps the dialog open, disables dismissal while removal is active, and offers a
fresh preview after a conflict. A real Electron run changed a file between review
and confirmation, verified the conflict preserved it, then refreshed and removed
only unchanged Toolkit files. The opened captures confirm that this guard does not
crowd the compact or large preview. The latest screenshots now include the target
picker and the receipt-backed evidence section behind the removal dialog. On compact
screens, target names wrap inside generous hit areas and both review controls remain
visible; the detailed filesystem plan stays scrollable and readable. The receipt rows
make installation state visible without claiming that mere catalog presence means
installed. The remaining visual limitation is the intentionally dense path-by-path
audit preview, which is useful for review but reads more like a technical report than
the rest of the game-menu surface.

Opened files:

- [Install preview, compact](assets/electron/library/install-preview-compact.png)
  and [large](assets/electron/library/install-preview-large.png).
- [Persistent installation receipts, compact](assets/electron/library/installation-receipts-compact.png)
  and [large](assets/electron/library/installation-receipts-large.png).
- [Removal preview, compact](assets/electron/library/removal-preview-compact.png)
  and [large](assets/electron/library/removal-preview-large.png).
