# Desktop visual QA

## Attention navigation and current screenshot gallery — 2026-10-05

Source `16e3264dcf21c3f1281f68b9bf9417a061947297`, Linux Electron capture
workflow `37310981958`. I opened the refreshed large world with several real
projects, the empty valley at dusk, the Attention, Library, and People screens,
compact Operations and Terminal, the Munder import review, and the project room
at compact and large sizes. The user-facing recovery destination is now named
Attention while preserving the established `/office` route and `office` palette
alias. The retired Paper-era CSS aliases were removed without changing their
current color values.

The map still reads as a recognizable settlement with a bridge and distinct
shared landmarks, but the multi-project view has broad lawns and the path network
still turns in conspicuous straight segments. The project room is tighter and
its real stations read as a group, but the plank floor remains broad and bare.
People is a real roster view yet its canvas is spacious after the roster cards;
this is still a surface-design opportunity. These captures document progress,
not completion of the requested world and inspector art direction.

After reviewing the captures, the README and current visual evidence were
refreshed from this same source. The old `office-attention.png` evidence image
was replaced by `attention.png`, so documentation uses the visible product
language. Current assets show real backend data and a real PTY; offline People
remain absent from the world.

Opened files:

- [Several projects, large](assets/electron/world/world-several-projects-large.png),
  [empty world, large](assets/electron/world/world-empty-large.png), and
  [empty world at dusk](assets/electron/cozy-pixel-world/world-dusk.png).
- [Project room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).
- [Attention](assets/electron/cozy-pixel-world/attention.png),
  [Library](assets/electron/cozy-pixel-world/library.png),
  [People](../../static/screenshots/people.png),
  [Operations](assets/electron/cozy-pixel-world/operations.png),
  [Terminal](assets/electron/cozy-pixel-world/terminal.png), and
  [Munder import review](../../static/screenshots/people-import.png).

The capture workflow passed on this source, including the Desktop visual tour.
PR checks on this source also passed the packaged-Electron fresh-HOME job,
desktop gates, Ubuntu/Windows integration, and Ubuntu V modules. macOS and
release packaging were still running when this evidence was written; consult
the PR checks for their final result rather than inferring success from the
capture.

## Project room station composition — 2026-10-05

Source `1b148c967b88f2cb4f5962e5f882424fb94ef661`, capture workflow
`37307216771`. I opened both fresh Project Files room captures after moving the
overview/Records pair and Terminal/Files pair into closer wall stations. The
work area now has a tighter 18-tile base width instead of reserving 22 tiles;
the doorway, station labels, and real resource destinations stay visible at
compact and large sizes.

The room reads more like one project workspace, but the screenshot still shows
unused plank floor between stations and the wall. The next pass needs stronger
semantic room composition and original interior art. This is a measured layout
improvement, not a final visual sign-off.

Opened files:

- [Project room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).
- [Compact empty world](assets/electron/world/world-empty-compact.png) to check
  that the world camera and grounds were unchanged.

## Organic meadow and ground-only dusk review — 2026-10-05

Source `9eff43e91c46cfba6024943ab9122c03b0c73762`, capture workflow
`37305618460` (Linux Electron with the packaged backend and disposable
workspace). I opened empty, one-project, and several-project worlds at compact
and large sizes, the project room at both sizes, the large Library and People
screens, compact Operations and Terminal, and the compact Munder import review.
These reviewed captures also replace the README product gallery and current
world evidence images.

The latest dusk treatment now tints the ground beneath buildings and entities,
so house silhouettes, warm windows, lamps, and water accents remain readable.
The project map fits in both viewport sizes and landmarks remain distinct. The
map still has long open lawns and angular, partly rectangular paths; this pass
does not claim those composition issues are solved. The project interior still
has a broad plank floor and sparse stations, so it remains an active art task.
Library and Operations expose real, typed product actions; the compact terminal
capture shows a live PTY, and the import review remains an explicit save step.

After seeing the captures, the dusk overlay was moved below world decor and
runtime entities, and capture teardown was changed to close its real shell PTY
before Electron exits. The gallery is deliberately made from real captures;
the design-board and deprecated Paper screenshot files were removed from the
active repository, with history retained in Git.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).
- [Library, large](assets/electron/cozy-pixel-world/library.png),
  [People, large](../../static/screenshots/people.png),
  [Operations, large](../../static/screenshots/operations.png),
  [Terminal, compact](../../static/screenshots/terminal.png), and
  [Munder import review, compact](../../static/screenshots/people-import.png).

The implementation checks for this source were run in GitHub Actions rather
than on the developer host. Capture `37305618460` passed the visual tour,
`pnpm lint`, typecheck, unit tests, `build:all`, renderer E2E, capture
verification, MCP capture, staging, and `dist:dir`. The pull-request workflow
also passed Linux/Windows integration, Linux packaged Electron with fresh HOME,
V modules on Ubuntu, and all listed Linux/Python validation jobs; macOS checks
remain deferred until final-main verification under the repository's current
release policy.

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

## Meadow and commons path iteration — 2026-10-04

Source `640dc775`, captured by the Linux Electron workflow against its built
backend and disposable HOME (run `37201065893`). I opened all six empty,
one-project, and several-project views at compact and large sizes, plus both
project-room sizes. The original grass source produced many repeated clover
stamps; a deterministic set of smaller, varied clumps with fewer bright flecks
calms the lawn at normal zoom. The shared commons route also gains a shallow
deterministic sway before it reaches the fixed bridge crossing. Asset freshness,
Desktop lint, type-check, unit tests, build, renderer/Electron E2E, and packaged
directory build passed in the same remote workflow.

The updated captures confirm crisp sprites, readable house silhouettes, a clear
bridge, and no offline People represented as workers. The change to the path is
subtle at normal scale, however, and the route network still has obvious
right-angle runs. The multi-project valley continues to have wide uninterrupted
lawns, while the project room still uses a broad, bare plank floor and light
wall bands. These are visible remaining art/composition issues; this iteration
is not a claim that the requested magical world direction is complete.

Opened and refreshed files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Clear project-house silhouettes — 2026-10-04

Source `543ccbbb`, captured by the Linux Electron visual-review workflow with
the packaged backend and disposable HOME (run `37203274477`). I opened fresh
empty, one-project, and several-project views at compact and large sizes, plus
the project room at both sizes. Tree placement now checks each oversized
canopy's full bounds against building footprints, so a clear anchor cannot put
foliage across a building silhouette. The multi-project captures show cleaner
separation around the civic and project houses.

This resolves one concrete readability issue. It does not finish the requested
world direction: large areas remain open lawn, paths retain long right-angle
segments, and the project room is a spacious prototype floor with little
material or furniture variation. The next composition pass should shape the
commons and tighten the interior around its real stations, then capture and
critique the results before claiming improvement.

Opened and refreshed files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Civic bridge connection review — 2026-10-03

Source `fcb211b7`, Linux Electron capture with the real backend and disposable
workspace. I opened the refreshed empty, one-project and several-project worlds
at compact and large sizes, plus both project-room captures. The road now reaches
the west bank of the creek and connects to the bridge in empty and populated
worlds; the bridge no longer starts as an east-bank-only path fragment. The
project houses remain distinct, the camera stays crisp at compact size, and the
raised Terminal and Files fixtures have clear space above the room trim.

This is an incremental navigation correction, not the finished art direction.
The large views still show broad repeated grass, a river that reads mostly
straight at this zoom, and sparse trees between the civic quarter and project
lots. The short west-bank approach also needs more convincing integration with
the commons. Continue composition work before treating the valley as complete.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Meadow grove density review — 2026-10-03

Linux Electron screenshots were recaptured after increasing seeded flower,
creek-bank tree, and grove-edge undergrowth density. I opened all six empty,
one-project, and several-project captures at compact and large sizes. Buildings,
project selection, and path corridors stay clear; color and flora variety improve
slightly around the creek and eastern tree clusters. The multi-project valley
still has long open grass fields, the ground texture repeats, and several
landmarks read as prototype sprites at full size. This iteration is deliberately
recorded as incremental terrain work, not as the completion of the world-art
pass. The prior, lower density capture was also opened before deciding the
increase was subtle but useful rather than cluttered.

## Compact valley composition review — 2026-10-03

After tightening the civic streets and moving project houses beside the creek
crossing, empty and one-project valleys now fit at crisp 32px tiles in a
1024×640 window; the world becomes the main surface instead of a small map in
the middle of a tall lawn. Three-project layouts still use the smaller fit zoom
because preserving every house and the shared landmarks in one frame takes
priority over cropping the settlement. Opened and reviewed the fresh captures:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).

The compact one-project composition is substantially more legible and keeps
the whole project house and civic district visible. The meadow remains visually
too uniform across long distances, the path is angular, and several landmark
sprites still look like simple prototypes; those are still open art-direction
work, not quality claims closed by this framing change.

## Original valley tree sprite review — 2026-10-04

Source `e23ed2d8`, Linux Electron captures with a disposable workspace. The
five seasonal tree sources were replaced with original, deterministic,
nearest-neighbor pixel art. I opened the empty, one-project, and several-project
large captures, the project room at large size, and the empty compact capture.
The trees now have distinct silhouettes, layered foliage, warm highlights, and
consistent pixel edges; they frame the creek more clearly without obscuring
project buildings or the selection outline. At compact size the canopy shapes
remain distinguishable.

This is a focused asset improvement. The captures also confirm the larger art
gap remains: the valley ground is still an expansive repeated lawn, the creek
reads as a straight channel, civic and project lots remain aligned in rows, and
several landmark assets look like prototypes. The interior is legible but sparse
and surrounded by unused floor area. Continue with terrain composition and
semantic environmental detail before calling the world polished.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Creek bends around the settlement — 2026-10-04

Captured at source 07febccf by the Linux Electron visual-review workflow
against its bundled backend and disposable HOME. I opened empty-world compact
and large, one-project compact, and several-project compact and large captures.
The first capture revealed a sharp bend where the creek reached the Terminal;
I changed the route selection to plan the whole stream around building
footprints, with each successive row limited to a one-tile turn. Water cannot
overwrite a building, and the civic bridge stays joined to the path network.

The compact captures keep the project lot dry and the settlement legible; the
large empty capture shows the wider S-bend most clearly. The critique still
finds broad unframed grass, civic buildings in small ranks, and squared path
loops around the bridge approach. The opened project room has clear semantic
stations but a broad bare floor. These remain follow-up composition gaps; the
safer, more natural creek course does not complete the world art pass.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, large](assets/electron/world/project-files-room-large.png).

## Civic commons and doorway review — 2026-10-04

Captured at source `85f08c88` by the Linux Electron visual-review workflow
against its bundled backend and disposable HOME. I opened empty, one-project,
and several-project worlds at compact and large sizes, plus the project Files
room at both sizes. The first layout capture exposed a fit-camera regression at
compact size; I kept the 32px tile floor when the map fits edge-to-edge. The
first plaza capture then showed an isolated patch of paving. I changed paving
to follow existing connected path cells only and recaptured the full set.

The final review shows the Operations entrance connected to the path network,
shared landmarks with walkable approaches, no paved island, and no offline
worker sprites. The world and room still have clear composition debt: the civic
area reads in ranks, grass lawns are broad and repetitive, the creek is mostly
straight, and the room's stations feel sparse. This is a focused navigation and
map-readability improvement, not the completed art direction.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Winding creek banks — 2026-10-04

Captured at source `9f410815` by the Linux Electron visual-review workflow
against its bundled backend and disposable HOME. Opened empty and one-project
worlds at 1024×640 and 1920×1080, the several-project world at both sizes, and
the project Files room at both sizes. The previous channel stayed pinned to
the west bank whenever the preferred creek coordinate was outside the clear
corridor. The new layout centers that fallback in the safe space, letting the
water bend to both sides of the bridge. The bridge still lands on the
connected path; project doors and shared places stay dry.

The bend is more visible in the compact capture and the stream occupies both
banks around the crossing in the large capture. There are still sizeable flat
grass areas, and the east-bank route can make a sharp rectangular turn around
the empty-project marker. That interaction path is functional, but it is not a
finished natural composition; terrain and routing need a broader pass.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Creek shape review — 2026-10-04

Source `7c754130`, Linux Electron captures against the disposable E2E
workspace. I opened the empty large capture, the several-project large and
compact captures, and the project room at large size. The creek now bends
noticeably across the valley and widens for a few reaches; its fixed crossing
still meets the shared footpath, and the project plots remain dry. The varied
water footprint makes the river read less like a straight canal at both
reviewed scales.

The terrain beyond the banks remains sparse and too uniformly grassy, and the
two-project district still reads as a short row across an angular path. This
capture validates the water adjustment only; continue with settlement
composition and more authored ground detail.

Opened files:

- [Empty world, large](assets/electron/world/world-empty-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, large](assets/electron/world/project-files-room-large.png).

## Project room scale and floor review — 2026-10-04

Source `d97edf59`, Linux Electron captures against the disposable E2E
workspace. I opened the project interior at compact and large sizes. The real
overview board, memory records, Files, Terminal, and exit now sit in separate
stations around a clear center aisle, and the enlarged room uses substantially
more of the world viewport. The offline room contains no invented workers or
workstation activity. After the first capture exposed a repetitive vertical
stripe floor, the source generator was changed to make horizontally laid,
stagger-jointed boards; the second capture confirms a calmer, more readable
floor texture at both scales.

The floor still reads as a simple authored plank tile, and the open center is
deliberately kept clear until a real session needs space. This interior pass
does not add unsupported project Knowledge or arbitrary furniture.

Opened files:

- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

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
to run the CLI hint shown by the backend catalog. GitHub Copilot is installed via a
separate repository-scoped review because its instructions belong inside one linked
project rather than in user-level tool homes.

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

## Project-scoped Copilot review — 2026-10-03

Captured from the Electron app against the V backend using an isolated test
workspace. Library selects one linked project and previews the actual packaged
Copilot instruction file, its exact repository destination, and the single file
to be added. The file body is available on demand so the compact review stays
focused. Applying writes a receipt. Removal is a separate review bound to that
receipt and current file digest; a post-install edit disables deletion and stays
in place. The flow does not launch an agent or alter user-level tool installs.

Opened both captures. At 1024×768 the dialog's project and destination remain
readable, its action stays visible, and long path segments wrap within the panel.
At 1440×900 the Library remains visible around the centered inspector. The
temporary project path is explicit because it is the actual file that will be
written; the screenshots use a disposable test workspace. The remaining scope
gap is installation of compiled Copilot repository Skills and Agent Definitions,
so `install-capabilities` correctly remains partial.

Opened files:

- [Copilot project review, compact](assets/electron/library/copilot-project-review-compact.png)
  and [large](assets/electron/library/copilot-project-review-large.png).

## MCP credential setup — 2026-10-04

Captured from the Linux Electron workflow against the real packaged backend in
a disposable HOME. The secure-storage-unavailable state fails closed: the input
and save action are disabled, the panel explains that no value was saved, and
the screenshot contains no credential value. Opening the first captures exposed
two visual defects: the credential panel was below the visible viewport, and
its wide grid could overlap the variable name and saved-state badge inside the
Library content column. I changed the capture to target the actual panel, made
the row layout adapt to the available content width, and corrected the copy so
an unavailable keyring is never described as an encryption provider. The final
compact and large captures show the complete panel with the warning and fields
readable, no overlaps, and the secret-free state clear.

Opened files:

- [MCP provider review, compact](assets/electron/library/mcp-configure-compact.png)
  and [large](assets/electron/library/mcp-configure-large.png).
- [Private credentials, compact](assets/electron/library/mcp-credentials-compact.png)
  and [large](assets/electron/library/mcp-credentials-large.png).

## Inland meadow grove — 2026-10-04

Captured from source `85b61637` by the Linux Electron visual-review workflow
(`37209640368`) with the packaged backend and disposable HOME. I opened all six
empty, one-project, and several-project captures at compact and large sizes,
plus both project Files room captures. Moving the projectless grove anchor
inland keeps the new tree pair in the open bank clearing instead of letting the
random shoreline rejection leave the center empty. The project buildings
remain clear of the tree canopies in these layouts.

The images show a modest composition improvement, not the requested enchanted
world quality. The grass still dominates as a repeated flat field, the path
network is rigid and angular, most of the eastern meadow remains underused, and
the Files room has a large bare floor around a few isolated objects. The world
is readable, but it is not yet lush, magical, or visually cohesive enough.
Continue with richer ground transitions, intentional clearings, semantic
interior furnishing, and warm environmental lighting before calling the art
pass complete.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Staggered project neighborhood — 2026-10-04

Captured at source `3db18f79` by the Linux Electron visual-review workflow
against its bundled backend and disposable HOME. Opened the large and compact
several-project captures after increasing the alternating project-lot offset
from one to two tiles. The second house now sits clearly lower along the creek
bank at both scales, while the shared footpath bends from the bridge toward the
project porches. Empty-world, one-project, and project-room captures were also
refreshed from the same build; those layouts remain stable because the change
only affects multi-house neighborhoods.

The stronger stagger reads better than the first one-tile attempt, especially
in the compact capture. The review still finds broad meadow areas visually
quiet and civic buildings arranged too rigidly; this is a local composition
improvement, not a claim that the valley has reached the final art direction.

Opened files:

- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).

## Gentle valley magic — 2026-10-04

Captured at source `2d9f09e6` by the Linux Electron visual-review workflow
against its bundled backend and disposable HOME. Opened empty, one-project, and
several-project worlds at large and compact sizes, plus the large project room.
The new water glints remain anchored to water, while two warm lantern posts
frame the bridge approach. An initial capture put a lantern over the stream;
after reviewing it, I moved the posts to the crossing row and added a model
assertion that rejects lantern anchors on water. The final captures show both
posts standing on the banks. The room retains its semantic stations and warm
plank floor; the ambient additions do not create worker silhouettes.

This is a first ambience layer, not the requested final atmosphere: the bright
water glints read at both scales, while motes are intentionally subtle. Broad
meadow areas remain quiet, and the civic quarter still needs a less rigid
composition and richer natural framing.

Opened files:

- [Empty world, large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, large](assets/electron/world/project-files-room-large.png).

## Meadow flower glades — 2026-10-04

Captured at source `c02c8ba0` by the Linux Electron visual-review workflow in
a disposable HOME and backend. I opened empty and one-project worlds at both
1024×640 and 1920×1080, the several-project world at both sizes, and the
project Files room at both sizes. The first capture at `2c964db6` showed that
the small flower pockets blended into the meadow and sat under nearby tree
canopies. I widened the seeded clearings and opened the spacing, then reviewed
the full set again. Flower groups now register around the creek and project
approach without covering connected footpaths or project doors; placement is
stable for the same world model.

The second review confirms that the color reads better at both scales and that
project houses still have clear access. It also confirms the broader art gap:
the grass field remains too uniform, the watercourse too straight, and shared
buildings too rigidly arrayed for the requested enchanted valley. This change
improves a real weakness in the landscape but does not finish the world pass.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Connected groves and open clearings — 2026-10-04

Captured from source `cd933b8a` by the Linux Electron visual-review workflow
against the packaged backend and disposable HOME. I opened all six empty,
one-project, and several-project world captures at compact and large sizes, both
project Files room captures, and the MCP provider and credential reviews. The
first grove-density screenshot had broad overlapping canopies between civic
landmarks and around the Terminal; I reduced interior creek-bank and meadow
grove placement, then recaptured the same cases. The new several-project view
has more breathing space around the Terminal and creek crossing while keeping
the connected outer grove framing. The empty and one-project layouts remain
stable, and the MCP warning still clearly states that no secret was saved when
secure storage is unavailable.

This review still shows substantial work before the target art direction is
met: the meadow is broad and repetitive, paths remain angular, the central
watercourse reads as a regular channel, and the project room is sparse with a
large unoccupied floor. The civic cluster beside Memory still looks crowded at
large size. Keep improving terrain composition, semantic interior art, and
district hierarchy; the screenshots record current reality rather than a claim
that the world is finished.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).
- [MCP provider review, compact](assets/electron/library/mcp-configure-compact.png)
  and [large](assets/electron/library/mcp-configure-large.png).
- [Private credentials, compact](assets/electron/library/mcp-credentials-compact.png)
  and [large](assets/electron/library/mcp-credentials-large.png).

## Readable wildflower beds — 2026-10-04

Captured from source `7fed5eac` by the Linux Electron visual-review workflow
with the packaged backend and a disposable HOME. I opened empty, one-project,
and several-project worlds at compact and large sizes, plus both project Files
room captures. The first 48×32 flower bed was rejected by the world-model test:
its collision footprint left no valid placement in the empty-world fixture. I
reduced the bed to 40×28, rebuilt its leafy silhouette, and retained exact
terrain/path and canopy collision checks. The new screenshots show the flower
beds clearly beside open meadow edges while keeping routes and the creek bridge
readable. Asset generation is deterministic and `gen-world-assets.mjs --check`
passes for all 133 sprites, including the lantern aura and regenerated meadow
palette.

This is a local improvement, not completion of the requested visual direction.
The meadow still has too much uniform green, the creek and paths remain
geometric, the project room is mostly empty floor, and the interface chrome is
still visually separate from the world. These captures make the current state
reviewable; they do not imply that the enchanted-valley art pass is finished.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Sun and shade meadow palette — 2026-10-04

Captured from source `6a629a55` with the Linux Electron visual-review workflow
and disposable HOME. I opened the empty, one-project, and several-project
worlds at compact and large sizes, along with the two project Files room
captures. The new grass tiles add darker damp/shaded greens while retaining
the warm sunlit base, and reducing background flower speckles lets the larger
meadow beds read more clearly. The effect is visible in the several-project
ground, but the empty map still reads as a broad green field and some color
transitions follow tile-shaped edges. This is a small palette pass, not the
required terrain composition redesign. The project room remains sparse and
the creek/path layout remains geometric.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Pixel-step lantern auras — 2026-10-04

Captured from source `59eb9de9` with the Linux Electron visual-review workflow,
packaged backend, and disposable HOME. I opened empty, one-project, and
several-project worlds at compact and large sizes, plus the project Files room
at both sizes. The first halo pass read as a filled yellow patch beside the
bridge posts. I redrew it as a sparse, stepped ring with a transparent center;
the recapture shows warm light at the bridge and civic path lamps without
soft-focus filtering or covering the crisp lamp sprite. Bridge tests confirm
each real post has exactly one paired halo, and screenshots show that routes,
water, flowers, and project doors remain readable.

The world still needs a broader art pass: terrain is too uniformly green,
water and routes are geometric, civic buildings sit in a rigid cluster, and
the project room has a large empty floor. The lantern change adds one ambient
detail and does not close those larger gaps.

Opened files:

- [Empty world, compact](assets/electron/world/world-empty-compact.png) and
  [large](assets/electron/world/world-empty-large.png).
- [One project, compact](assets/electron/world/world-one-project-compact.png)
  and [large](assets/electron/world/world-one-project-large.png).
- [Several projects, compact](assets/electron/world/world-several-projects-compact.png)
  and [large](assets/electron/world/world-several-projects-large.png).
- [Project Files room, compact](assets/electron/world/project-files-room-compact.png)
  and [large](assets/electron/world/project-files-room-large.png).

## Project interior ambience — 2026-10-05

Captured from source `fbfa8944deaec762e9c9d6c409fa71202bcf44f2` by the Linux
Electron visual-review workflow. I opened the compact and large project-room
captures and the compact and large several-project world captures from [run
37252088667](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37252088667),
artifact `electron-review-screenshots`. The wider room gives the project overview,
archive, terminal, exit, and files stations more space. Windows, sconces, plants,
and rug add environmental detail without covering station labels or implying
live work. In the several-project captures the existing building labels, paths,
and creek remain readable. At the 1024×640 compact capture the project room
fits without clipping its stations; at 1920×1080 the larger canvas still has a
broad central wood floor. This pass adds atmosphere and does not complete the
wider composition work.

Opened artifact files:

- `project-files-room-compact.png`
- `project-files-room-large.png`
- `world-several-projects-compact.png`
- `world-several-projects-large.png`

## Forest-menu and refreshed README captures — 2026-10-05

Captured Electron from source `a9ede9dd` on the remote Linux runner in [workflow
37283342028](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37283342028),
using its packaged V backend and disposable HOME. I opened every linked PNG
below at its native resolution. The Meadows' inspector canvas is now deep
evergreen, so content panels read as framed game menus instead of sitting on a
large pale SaaS surface. The Dusk wash is lighter than the prior capture; the
world keeps its warm windows and readable creek while the daytime and evening
palettes remain distinct. The README's old static infographic SVGs are removed;
its gallery and package front pages now use captured Electron screenshots.

The world is legible and the project buildings remain distinct, and the
multi-project layout places projects across the creek. The capture also shows
unfinished art work: broad lawn regions remain visually uniform, the central
watercourse and many paths are geometric, and the project room still has a
large unused plank floor. People, Library, Operations and Settings use
readable compact information layouts; the People screen has substantial unused
vertical space at large size. These are remaining polish issues, not reasons to
claim the desired magical world art pass is finished.

Opened and preserved review images:

- [Empty world, compact](assets/electron/review-2026-10-05/world-empty-compact.png)
  and [large](assets/electron/review-2026-10-05/world-empty-large.png).
- [One project, compact](assets/electron/review-2026-10-05/world-one-project-compact.png)
  and [large](assets/electron/review-2026-10-05/world-one-project-large.png).
- [Several projects, compact](assets/electron/review-2026-10-05/world-several-projects-compact.png)
  and [large](assets/electron/review-2026-10-05/world-several-projects-large.png).
- [Project room, compact](assets/electron/review-2026-10-05/project-files-room-compact.png)
  and [large](assets/electron/review-2026-10-05/project-files-room-large.png).
- [Dusk world](assets/electron/review-2026-10-05/dusk-1920x1080-world.png),
  [People](assets/electron/review-2026-10-05/meadow-1920x1080-people.png),
  [Library](assets/electron/review-2026-10-05/meadow-1920x1080-library.png),
  [Operations](assets/electron/review-2026-10-05/meadow-1920x1080-operations.png),
  and [Settings](assets/electron/review-2026-10-05/meadow-1920x1080-settings.png).
- [Person create, compact](assets/electron/review-2026-10-05/meadow-1024x640-person-create.png),
  [Munder import review, compact](assets/electron/review-2026-10-05/meadow-1024x640-munder-import-review.png),
  [PTY with output, compact](assets/electron/review-2026-10-05/meadow-1024x640-terminal.png),
  and [PTY, large](assets/electron/review-2026-10-05/meadow-1920x1080-terminal.png).

### Terminal resize recapture

The first large terminal screenshot was captured before the resized PTY had
produced visible output. The Electron E2E now writes and checks a real marker
after each resize. I reran it on source `50704f60` in [workflow
37284850886](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37284850886)
and opened both terminal screenshots at native resolution. Output is visible at
1024×640 and 1920×1080, so both sizes are now suitable for documentation. The
README uses the compact capture; the review gallery retains both.
