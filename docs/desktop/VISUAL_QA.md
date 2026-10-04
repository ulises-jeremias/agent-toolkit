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
