# Desktop visual quality and evidence

This is the current visual acceptance guide for Agent Toolkit Desktop. It keeps
art direction, the latest opened evidence, and unresolved findings in one place.
The dated iteration log lives in [VISUAL_QA_HISTORY.md](VISUAL_QA_HISTORY.md);
that archive is historical evidence, not the current art specification.

## Visual north star

Agent Toolkit Desktop is a semantic developer workspace represented as an
original, cozy top-down pixel world. `/world` is the primary screen: a real
workspace is the valley, projects are recognizable buildings, and shared
capabilities have distinct landmarks. Clicking, direct navigation, keyboard
commands, and the palette reach the same canonical actions. Nobody must walk
an avatar to use the product.

The world should feel lush, colorful, warm, gently magical, and composed like a
small place: layered grass, paths, trees, water and useful crossings, flower
clearings, lamps, warm windows, subtle motes, and a restrained Hornero signature.
Interiors should express real project resources. A bookshelf, filing desk,
archive, terminal, or workbench belongs only when it opens the corresponding
canonical resource. Environmental motion may make an idle valley charming; it
must never imply agent activity.

Inspectors and settings use compact game-menu frames that share the world’s
palette, pixel-cut borders, crisp shadows, and type hierarchy. Dense text,
forms, tables, logs, and terminals remain readable at working speed. Avoid
Paper Co., beige/editorial SaaS, glass, generic dashboard panels, copied game
art, fake activity, and decorative controls. The normative visual and
interaction contract is [DESIGN.md](DESIGN.md), with spatial mapping in
[SEMANTIC_WORLD.md](SEMANTIC_WORLD.md).

## Acceptance checks

For each meaningful visual change, run the app, capture, open, critique, fix,
and recapture. Review at least compact and large layouts and include the states
that the change can affect:

- empty workspace, one project, and several projects;
- selected project and its interior;
- idle world and real active runtime presence;
- People roster and create/edit/review flows when touched;
- Library, Operations, loops, swarms, terminal, settings, and onboarding when
  touched.

For each capture ask whether the screen reads as a real game world, remains a
fast developer workstation, keeps pixel art crisp, composes buildings and
terrain naturally, communicates state truthfully, and preserves readable text,
keyboard focus, contrast, and reduced-motion behavior. Do not claim full
accessibility conformance unless tested.

The [workflow ledger](workflows.yaml) records functional evidence separately;
a passing screenshot does not establish an end-to-end journey, and a passing
test does not establish visual quality.

## Release-candidate capture — v1.43.0, 2026-10-09

The packaged Desktop capture workflow ran against PR #1501 at source
`7a4d32d8cc9b108d8e2bd61255474804916886a7` in [run
37898953188](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37898953188).
I opened the post-fix workspace at compact and large sizes, the compact real
PTY terminal, the populated Meadow and Dusk worlds, the project interior, the
large People roster, Library, and Operations. The README gallery now leads
with the actual valley and uses current packaged Electron captures rather
than illustrative SVGs.

The workspace initialization fix adds the required `knowledge/processes/`
directory; the fresh-workspace validation panel now reports all context areas
valid. The terminal page can scroll independently above its persistent PTY
dock at compact size; the captured prompt runs `agent-toolkit version` and
shows the real `1.43.0` backend. The capture-tour terminal commands no longer
inject a synthetic failure, and xterm is allowed to settle after route
remounts before capture. The release branch also removes 234 Electron PNGs
that had no references from tracked files (about 23 MB); screenshots linked
from documentation remain.

This is a functional/current-state review, not visual sign-off. The world has
distinct project houses, landmarks, creek, bridge and colorful canopy, but its
paths still form conspicuous right angles and the map leaves broad flat lawn.
Meadow and Dusk differ mainly by lighting; neither yet reaches the intended
enchanted, lantern-lit atmosphere. People and Library are truthful and
readable but leave substantial unused space at large sizes. The compact
workspace and terminal remain vertically dense. Keep world composition,
ambient magic, and compact inspector density as important follow-up work; do
not mask them with decorative sprites or describe this release as the final
art direction.

The exact opened files from the run artifact were `meadow-1024x640-workspace.png`,
`meadow-1920x1080-workspace.png`, `meadow-1024x640-terminal.png`,
`world-several-projects-meadow-large.png`,
`world-several-projects-dusk-large.png`, `project-files-room-large.png`,
`people-roster-large.png`, `meadow-1920x1080-library.png`, and
`meadow-1920x1080-operations.png`. The README uses current copies of the world,
interior, People, Library, Operations, and terminal capture files from this
same run.

The capture workflow also produced compact/large empty and one-project states,
Person creation and Start, Munder import review, MCP configuration, and
Settings; these were not all opened in this review and are not claimed as
visual sign-off.

## First-run welcome review — v1.43.0 follow-up, 2026-10-09

I opened the real Electron first-run screen at 1440×900 and 1024×640 after the
v1.43.0 release. Its first pass showed a tiny desk icon and unexplained empty
space, so the welcome illustration now composes the shipped workspace-hall,
Library, creek, bridge, tree and lantern sprites. It is explicitly an
illustration: the screen creates no sample projects, People, or runtime state.
The setup copy also no longer shows a CLI command for workspace initialization;
the user stays in the GUI flow.

The first screenshot review exposed a too-dense repeating grass texture and a
bridge drawn over the Library roof. I scaled the grass to the in-world tile
size and moved the bridge crossing above the building entrances, then rebuilt
and recaptured. The final opened files are
[`onboarding.png`](../../static/screenshots/onboarding.png) and
[`onboarding-compact.png`](../../static/screenshots/onboarding-compact.png).
The compact capture keeps the backend status and Continue action visible. This
is a better first impression and a truthful preview, but it does not replace
the full semantic world as the product home or close the open terrain/path
composition findings above.

## Worn footpath pass — source `4698ce3f`, 2026-10-09

I opened the fresh Electron captures at compact and large sizes after the
terrain change: the empty compact valley is
[`world-empty-compact.png`](assets/electron/world-review-2026-10-09/world-empty-compact.png),
and the large populated valley is the current
[`README world capture`](../../static/screenshots/world.png). The capture tour
used the real Electron renderer and installed `agent-toolkit` 1.43.0 backend
with a disposable workspace. Both screenshots were opened after the change.

The old path atlas repeated solid rectangular brown bands. The generator now
creates four deterministic, edge-compatible variants for each path connection
shape, with narrower worn-earth silhouettes and small flecks. The model still
connects every real entrance, and the 45 world-model tests plus the real
project-link Electron journey pass. At the normal compact and large zooms, the
new paths break up the uniform fill without obscuring doors or crossings.

This is a measured terrain improvement, not a composition sign-off. The main
route still has conspicuous right-angle branches, some civic paths still meet
in grid-like junctions, and large grass clearings remain. Dusk lighting and
the top navigation also still need a stronger world-first treatment. Keep
those findings open; do not describe this pass as a complete world redesign.

## World context focus — 2026-10-09

On `/world`, the persistent context strip now keeps the active workspace and
the command-palette shortcut, while hiding the manual Agent and Run filters.
The map already derives active characters and work from backend evidence, so
those filters were visually noisy and did not control the world. The full
context remains on other destinations, and the workspace field remains
editable on the World route. A focused Electron E2E checks both the reduced
World strip and continued workspace visibility; typecheck, lint, production
build, and the real project-link Electron journey passed.

I opened the current Electron captures at compact and large sizes:
[Meadow compact](assets/electron/world-review-2026-10-09/world-several-projects-meadow-compact.png),
[Meadow large](../../static/screenshots/world.png),
[Dusk compact](assets/electron/world-review-2026-10-09/world-several-projects-dusk-compact.png),
[Dusk large](assets/electron/world-review-2026-10-09/world-several-projects-dusk-large.png),
an empty compact workspace, and a selected project. The smaller context strip
gives the map slightly more vertical space and reduces dashboard-like filter
chrome. The selected-project plaque and world index remain visible. This is a
small hierarchy improvement; the broad grass clearings, geometric path
junctions, conventional top navigation, and underdeveloped enchanted lighting
remain visible and are not signed off. The README world and Dusk images now
use these exact real Electron captures from the installed 1.43.0 backend.

## Creek, landmark and room review — 2026-10-07

The Electron capture workflow ran against the real 1.42.0 backend and a
disposable workspace. The successful visual-review run is
[37671764863](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37671764863).
I opened the compact and large multi-project Meadow captures, the compact
multi-project Dusk capture, the large empty world, the large project room, the
large People roster and Person Start review, compact Person creation and
Munder import review, and large Library, Operations, Terminal, Settings and
MCP configuration/credential screens. The captured world states are retained
under [`assets/electron/world/`](assets/electron/world/); representative
workflow captures are in
[`assets/electron/review-2026-10-07/`](assets/electron/review-2026-10-07/).

The stream now stays one tile wide except for occasional two-tile pools, and
the bridge still connects the shared commons to project homes. Explicit bank
stones keep a small natural detail visible without relying on random scenery.
Reduced willow density prevents the east bank from becoming a solid hedge.
The operations landmark now has its own observatory silhouette, the project
room uses continuous horizontal boards, and the Dusk overlay has clearer
blue-hour contrast. The README gallery now uses these current Electron PNGs;
the gallery contains no illustrative SVGs.

The opened screenshots also set the next visual work clearly. The water remains
a strong central separator, the main routes still turn at conspicuously square
angles, and broad grass clearings dominate the empty and populated maps. Dusk
is distinct from Meadow but still needs a more memorable lantern-lit
atmosphere. The room has a coherent floor and real resource stations, with
large wall areas that should only gain detail when a real project resource
supports it. People, import review, and Start keep the durable-person/runtime
distinction clear; the Start preview correctly says that no interactive runner
is installed. Library and Operations remain information-dense professional
inspectors rather than pixel-art scenes. These limits remain important art and
composition work, not sign-off.

The review covered these exact opened files: [Meadow compact](assets/electron/world/world-several-projects-compact.png),
[Meadow large](assets/electron/world/world-several-projects-large.png),
[Dusk compact](assets/electron/world/world-several-projects-dusk-compact.png),
[empty large](assets/electron/world/world-empty-large.png),
[project room large](assets/electron/world/project-files-room-large.png),
[People large](assets/electron/review-2026-10-07/people-roster-large.png),
[Person Start large](assets/electron/review-2026-10-07/person-start-large.png),
[Person create compact](assets/electron/review-2026-10-07/meadow-1024x640-person-create.png),
[Munder import compact](assets/electron/review-2026-10-07/meadow-1024x640-munder-import-review.png),
[Library large](assets/electron/review-2026-10-07/meadow-1920x1080-library.png),
[Operations large](assets/electron/review-2026-10-07/meadow-1920x1080-operations.png),
[Terminal large](assets/electron/review-2026-10-07/meadow-1920x1080-terminal.png),
[Settings large](assets/electron/review-2026-10-07/meadow-1920x1080-settings.png),
[MCP configure large](assets/electron/review-2026-10-07/mcp-configure-large.png),
and [MCP credentials large](assets/electron/review-2026-10-07/mcp-credentials-large.png).

## Original woodland atlas review — 2026-10-07

The six-variant tree atlas was captured from the branch backend in [visual
review run 37681553093](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37681553093).
I opened the fresh compact empty workspace and the large populated valley in
both Meadow and Dusk. The committed copies are [empty compact](assets/electron/review-2026-10-07/tree-atlas/world-empty-compact.png),
[Meadow large](assets/electron/review-2026-10-07/tree-atlas/world-several-projects-meadow-large.png),
and [Dusk large](assets/electron/review-2026-10-07/tree-atlas/world-several-projects-dusk-large.png).

The new blossoms, autumn crowns, pine and rune-lit variant give the woodland
more color and distinct silhouettes; hard alpha edges stay crisp at both
integer scales, and Dusk still separates the blue creek from warm windows.
This is a meaningful asset improvement, not final composition approval. In
the populated large map, crowns compete with project façades, the lower route
and porch approaches still read as squared-off channels, and broad grass
clearings remain dominant. The two pale signs near the creek also lack a clear
semantic affordance in this view and should be reviewed as part of layout
composition. These are composition and layout issues; adding more decorative
sprites would not solve them. Keep this atlas in the README gallery only after
a final-main capture confirms the map composition and project states at
compact and large sizes.

## Earlier iteration review — 2026-10-06 (before v1.42.0)

The dusk-ground tint adjustment at `162391b6` was captured by [Linux Electron
review run 37420506125](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37420506125).
I opened `dusk-1920x1080-world.png`, `dusk-1024x640-world.png`,
`meadow-1920x1080-world.png`, `meadow-1024x640-library.png`,
`people-roster-large.png`, `world-empty-large.png`,
`world-one-project-large.png`, `world-several-projects-large.png`,
`project-files-room-large.png`, and `project-files-room-compact.png` from that
run.
The dusk treatment now reads darker than Meadow at both world sizes while
keeping water, foliage, labels, buildings, and their warm windows distinct.
The change improves the existing nighttime state, but it does not solve the
larger map composition issues below: the creek remains mostly vertical, paths
are orthogonal, and the map still lacks a more deliberate settlement layout.
People remains a conventional inspector, with substantial unused space at
large size; this CSS-only change does not alter it. The project interior has
the expected five real destinations and remains crisp at compact size, but its
wide floor still leaves too much unstructured space. The compact Library has
clear installation/removal actions and a distinct dark game-menu frame, though
the content extends below the first viewport and needs a focused scrolling
review before screenshot-gallery refresh.

The follow-up at source `3b269c26` was captured by [Linux Electron review run
37416352771](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37416352771).
I opened `world-several-projects-large.png`,
`world-several-projects-compact.png`, `world-one-project-large.png`,
`world-empty-large.png`, `world-empty-compact.png`,
`dusk-1920x1080-world.png`, and `project-files-room-large.png` from its
screenshot artifact. Allowing diagonal
tree-root neighbors creates a denser, less orchard-like canopy on the project
bank while leaving building footprints, entrances, and the bridge clear. This
is a visible improvement at both world sizes, not final art acceptance: the
creek still reads mostly as a vertical divider, paths remain blocky, the lawn
is too broad, and the interior has large empty margins around its real
resource stations. Keep those issues open; do not add decorative furniture to
mask missing project resources.

Linux Electron runs [`37408692569`](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37408692569)
and [`37410543955`](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37410543955)
were opened at compact and large sizes. The second review specifically opened
`world-several-projects-large.png`, `world-empty-compact.png`,
`meadow-1920x1080-world.png`, `dusk-1920x1080-world.png`, and
`project-files-room-large.png`. Added grass motifs are crisp and more visible
at map scale; the dusk pass keeps its color; and the project room exposes real
overview, records, files, and terminal destinations. The full map is not yet
accepted: broad meadow areas still read as a horizontal band, the creek is
nearly a straight divider despite the wider corridor, paths remain too
geometric, and eastern trees look like separated rows rather than a grove.
The room also has too much empty floor around its semantic stations. These
captures are iteration evidence, not visual sign-off.

The follow-up at `c9231168` removed the workshop-aligned creek boundary. Its
Electron gate rejected the result before screenshots: creek bank span was only
four tiles, the bridge landing disconnected from the empty-project marker,
and the terminal entrance no longer reached the commons. Those assertions
remain intact; this candidate is rejected. The implementation has restored
the creek to its dedicated corridor between the civic and project districts,
where it can meander without cutting off town access. A fresh capture and
opened review are still required after that corrected candidate passes the
full gate. Keep the remaining composition issues visible rather than treating
generated assets or green tests as an art-quality verdict.

The project-room proportion iteration at source `4b20a576` was captured by
[Linux Electron review run 37424603379](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37424603379).
I opened `project-files-room-large.png`, `project-files-room-compact.png`,
`meadow-1920x1080-world.png`, and `meadow-1024x640-world.png`. At 1920×1080,
the 14×10 room renders at crisp 80-pixel tiles and makes the project board,
records, files, exit, and terminal easier to inspect; at 1024×640 it remains
compact and legible at 32-pixel tiles. The large room now uses more of the
available height, while its centered 1120-pixel width still leaves generous
side margins. The wall remains repetitive and the floor has visible gaps
between stations, so this is a proportion improvement rather than final
interior-art approval. The meadow capture keeps its current creek/bridge
layout at both sizes, but broad grass and rectilinear paths still need a
composition pass.

## Latest main capture — v1.42.0, 2026-10-06

The Electron visual-review workflow captured source
`ea154c2f192d6844d3f2a2e6a9764de5a5249aa3` in
[run 37445405836](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37445405836).
This is the released `v1.42.0` main SHA. I opened the full capture contact sheet
and the original-size files `meadow-1920x1080-world.png`,
`dusk-1920x1080-world.png`, `world-empty-compact.png`,
`world-one-project-large.png`, `world-several-projects-large.png`,
`project-files-room-large.png`, `meadow-1920x1080-library.png`,
`meadow-1920x1080-people.png`, `people-roster-large.png`,
`person-start-large.png`, `meadow-1024x640-person-create.png`,
`meadow-1024x640-munder-import-review.png`,
`meadow-1920x1080-operations.png`, `meadow-1920x1080-terminal.png`,
`meadow-1920x1080-settings.png`, `mcp-configure-large.png`, and
`dusk-1024x640-attention.png`. A compact contact sheet also covered
`world-empty-compact.png`, `world-one-project-compact.png`,
`world-several-projects-compact.png`, `project-files-room-compact.png`,
`people-roster-compact.png`, `person-start-compact.png`,
`meadow-1024x640-library.png`, and compact MCP configuration/credential review.
The former 54-image copy has been removed from the repository screenshot
tree as part of the unreferenced-capture cleanup in commit `7a4d32d8`; the
capture remains available through the linked workflow run.

The final captures confirm crisp pixel scaling, distinct shared landmarks,
three individually named project buildings, a bridge across the creek, and
truthful offline People states. The start review accurately explains that no
interactive runner is installed in the disposable test environment; it does
not claim to have started a session. The import review makes the no-spawn rule
and ignored fields explicit. The final code changes improve the dusk contrast
and bring the compact interior window inside the wall; screenshots now show
those exact changes.

This is still not art sign-off. The valley reads as a rectangular grass board
with highly regular terrain marks and angular paths; the creek divides the map
almost vertically. The room wall repeats the same timber pattern and leaves
large bare areas between its real resource stations. Inspectors use legible
pixel headings and hard-edged frames, but the broad flat green page and navy
cards still read closer to a conventional dashboard than a cozy game menu. The
large People roster leaves most of its canvas unused. Keep these as important
product work; passing capture and build checks does not make the experience
visually complete. The README gallery uses genuine PNG screenshots from the
released Electron build; the functional status badges are links, not product
artwork.

## Empty-world review — enchanted-lighting branch, 2026-10-06

I captured the current Electron renderer at 1024×640 and 1920×1080 in both
Meadow and Dusk against the disposable E2E workspace and the real 1.42.0
backend. The four opened images are [Meadow compact](assets/electron/world/world-empty-compact.png),
[Meadow large](assets/electron/world/world-empty-large.png),
[Dusk compact](assets/electron/world/world-empty-dusk-compact.png), and
[Dusk large](assets/electron/world/world-empty-dusk-large.png). The empty
workspace now has a project notice board with a clear “Add project” action;
it no longer draws a project house that does not exist. Both themes preserve
crisp integer-scaled sprites and warm windows, and the large view gives the
terrain and creek room to read as a place.

This review does not sign off the art direction. The empty scene still uses a
large rectangular grass field with repetitive ground marks, orthogonal paths,
and a nearly vertical creek. Dusk is the more atmospheric palette, but the
new static light treatment is subtle at normal map scale; it does not yet give
the valley the enchanted, firefly-lit quality in the product brief. At compact
size the navigation and dock consume a noticeable share of the viewport. Keep
the README’s multi-project screenshots as the product overview: the empty
world is useful for documenting first-run behavior, but is a weaker showcase.

The README currently displays real Electron screenshots in PNG format. Keep
those over illustrative SVG mockups. It uses plain-text CI, license, and release
links; there are no SVG product illustrations or README badge images. Use the
visual review archive for empty-state and edge-case screenshots rather than
replacing the product overview with an empty map.

## Resting-world label and lighting review — 2026-10-07

I captured the Electron world with the real backend and a disposable workspace
containing three projects at 1024×640 and 1920×1080. I opened the compact and
large Meadow/Dusk captures, the one-project view, and the several-project
view. Permanent plaques made the map read like an annotated dashboard, so
landmark labels now appear only for a hovered, keyboard-focused, or selected
place. Its tooltip still explains the place, state, and action. The README
hero now uses the real multi-project Meadow capture; the Dusk pair is also a
real Electron screenshot rather than an illustration.

The open map has more breathing room and the buildings and creek carry the
scene without a label on every doorway. The selected project remains named;
keyboard focus exposes the same plaque and tooltip as pointer hover. Dusk was
too dark in the first opened capture, so I reduced the terrain tint and raised
the warm clearing and creek-reflection pools, then recaptured both sizes. Water
and grass now retain separation while Dusk still reads as evening. This is a
clarity improvement, not final art sign-off: the paths remain geometric,
the project-side lawn is broad, and the room needs further composition work.
Opened multi-project references: [Meadow compact](assets/electron/world-labels-2026-10-07/world-several-projects-meadow-compact.png),
[Meadow large](assets/electron/world-labels-2026-10-07/world-several-projects-meadow-large.png),
[Dusk compact](assets/electron/world-labels-2026-10-07/world-several-projects-dusk-compact.png),
and [Dusk large](assets/electron/world-labels-2026-10-07/world-several-projects-dusk-large.png).
These captures are stored separately from the two pre-existing user-owned
Library evidence files.

## Current natural-ground capture — v1.42.0, 2026-10-06

I recaptured the empty, one-project, and three-project workspace at 1024×640 and
1920×1080, plus both project-room sizes, from the Electron app against a freshly
built 1.42.0 V backend. The capture is linked from the current files above and
the three-project large image is also the README's main valley screenshot. The
world-art source now emits fewer tiny grass flecks per tile. The creek is
unchanged in this capture; its existing bridge, entrances, and deterministic
layout all pass the terrain tests.

The opened large and compact views keep crisp scaling, real project houses,
separate civic landmarks, the shared bridge, and a quieter grass texture. The
creek still reads as a nearly straight district boundary; the broad lawn and
orthogonal paths also remain obvious. A wider, faster creek prototype was
rejected after it broke doorway connectivity and reduced the wooded frame in
the empty valley. The project room still has a repeated timber wall and empty
space between real stations. This is a reviewed iteration, not visual sign-off.

Opened references: [empty world, compact](assets/electron/world/world-empty-compact.png),
[empty world, large](assets/electron/world/world-empty-large.png),
[one project, compact](assets/electron/world/world-one-project-compact.png),
[one project, large](assets/electron/world/world-one-project-large.png),
[several projects, compact](assets/electron/world/world-several-projects-compact.png),
[several projects, large](assets/electron/world/world-several-projects-large.png),
[project room, compact](assets/electron/world/project-files-room-compact.png),
[project room, large](assets/electron/world/project-files-room-large.png),
[Copilot install review, compact](assets/electron/library/copilot-project-review-compact.png),
and [large](assets/electron/library/copilot-project-review-large.png).

## Dusk lighting review — 2026-10-06

After opening the compact and large dusk captures, the previous blue-hour
overlay still looked too close to daytime. I changed the terrain-only tint
from a low-strength soft-light blend to a stronger multiply blend with warm
clearing pools and a cool creek reflection. The authored buildings, people,
labels, and controls remain crisp and untinted; lit windows stay warm against
the darker ground. I recaptured and opened [Dusk compact](assets/electron/world/world-empty-dusk-compact.png),
[Dusk large](assets/electron/world/world-empty-dusk-large.png), [Meadow compact](assets/electron/world/world-empty-compact.png),
and [Meadow large](assets/electron/world/world-empty-large.png). The screenshot
tour now waits for the real Library landmark before saving a World image, so a
slow workspace query cannot masquerade as an empty map. Dusk now reads as a
distinct evening palette at both sizes. This improves atmosphere, but the map
composition issues above remain open; the screenshot is evidence of the
specific lighting change, not overall art sign-off.

## Screenshot policy

Checked-in screenshots must come from the running Electron app and canonical
backend against disposable test data. They are documentation examples and
review evidence, not concept-board art. Refresh `static/screenshots/` when the
pictured product changes, and keep the README gallery to a small set that
explains the current experience. The README uses genuine PNG captures and
plain-text links; do not use illustrative SVG mockups as product screenshots.
Keep operational links out of the product gallery.
Only reviewed, referenced screenshots are kept in the repository. Other
compact/large and edge-case capture sets belong to their linked workflow
artifacts rather than an ever-growing checked-in screenshot archive.
Inspiration boards must never be copied into product art or presented as
screenshots.

## Product polish review — 2026-10-06

I captured the Electron app against its disposable workspace and the real
1.42.0 backend. CI captured the full 38-image route/theme/size set; its
redundant copy has since been removed from the repository screenshot tree.
The project-link E2E also captured empty, one-project, three-project, and
project-interior scenes. These were actual GUI flows, not concept art.

I opened `meadow-1920x1080-world.png`, `dusk-1920x1080-world.png`,
`meadow-1024x640-world.png`, `dusk-1024x640-world.png`,
`world-empty-compact.png`, `world-empty-large.png`,
`world-one-project-compact.png`, `world-one-project-large.png`,
`world-several-projects-meadow-compact.png`,
`world-several-projects-meadow-large.png`,
`world-several-projects-dusk-compact.png`,
`world-several-projects-dusk-large.png`, `project-files-room-compact.png`,
`project-files-room-large.png`, `meadow-1024x640-people.png`,
`meadow-1024x640-person-create.png`,
`meadow-1024x640-munder-import-review.png`, `meadow-1024x640-library.png`,
`meadow-1024x640-operations.png`, `meadow-1024x640-terminal.png`,
`meadow-1024x640-settings.png`, `meadow-1024x640-workspace.png`, and
`dusk-1024x640-attention.png` from the new set.

The review found `.ai-workspace` leaking as a product name in the persistent
context, Workspace page, and terminal tabs. The UI now calls the default place
“AI Workspace”; focusing the context field still exposes the editable real
path, and the Workspace page retains the full path as its supporting text.
The compact and large captures confirm the terminal retains the friendly name
without losing the real PTY. A lighter Dusk overlay read too much like Meadow,
so I restored the stronger blue-hour tint and opened both sizes again; warm
lamps and windows remain clear.

The review does not sign off the art. The current valley is colorful and its
landmarks are distinct, but the terrain still reads as a rectangular board,
paths remain mostly orthogonal, and the creek divides the districts almost
vertically. The project house interior has real files, records, overview, and
terminal stations, but its timber wall repeats and leaves large bare areas.
People are truthful and legible, though the large roster still has excess
unused space. Compact Library content continues below the fold. These findings
remain open; a fresh screenshot is evidence of the label and Dusk adjustments,
not a claim that the requested enchanted world-art pass is complete.

The README gallery now uses refreshed PNG captures for the valley, Dusk,
project room, Library, People, Operations, terminal, and inert Munder review.
There are no repository-owned SVG product illustrations or README badge
images; operational destinations are plain-text links. The backend was
rebuilt from this source with `VJOBS=2` for the project-link Electron E2E; the
context-label and exited-PTY tests also passed. The app unit suite reports 45
files and 382 passing tests, and Desktop type-check, lint, and production build
pass. Builds ran in a systemd scope capped at 4 GiB and 200% CPU. An initial
E2E attempt using the older main checkout binary returned 404 for the Copilot
review route; the branch-built backend fixed that environment mismatch and
the full project-link journey then passed.

## First-run recovery — 2026-10-06

I used the real Linux Electron app and its supervised 1.42.0 backend in a
throwaway HOME, killed only that backend process, and opened the failed state at
1024×768 and 1440×960. The first capture showed an unhelpful “Starting” label
and exposed an absolute executable path by default. I changed the state label
to “Needs restart”, replaced the default error copy with a clear explanation,
and moved raw diagnostics into a collapsed disclosure. I reopened the [compact
failure screen](assets/electron/onboarding/recovery-backend-failed-compact.png)
and [large failure screen](assets/electron/onboarding/recovery-backend-failed-large.png).
The panel now explains that the workspace was not changed, provides an
immediate restart action, and keeps the technical detail available on demand.
The same E2E journey restarts the process and continues to folder selection.

## Meadow life pass — 2026-10-06

Opened fresh compact and large Electron captures of the empty valley and the
three-project meadow in both Meadow and Dusk themes. The idle valley's ambient
motes had been confined to the creek, leaving the project-side clearings quiet.
The terrain pass now adds at most four deterministic meadow motes, keeping them
off paths, doorways, and building footprints; they remain ambient decoration and
are independent of jobs, People, or sessions. The mote count stays capped at ten
including the existing creekside group. Browser visibility and reduced-motion
settings continue to govern their animation.

The opened images show the new light points among the garden and creek-side
clearings at both scales. This adds a little life without filling the lawns with
particles. It does not resolve the larger composition findings: grass still
reads as a broad rectangular field, paths are mostly orthogonal, and the creek
still separates the civic and project districts. Those remain open art work.

Captures: [empty, compact](assets/electron/meadow-motes-2026-10-06/empty-compact.png),
[empty, large](assets/electron/meadow-motes-2026-10-06/empty-large.png),
[several projects in Meadow, compact](assets/electron/meadow-motes-2026-10-06/several-meadow-compact.png),
[large](assets/electron/meadow-motes-2026-10-06/several-meadow-large.png),
[several projects in Dusk, compact](assets/electron/meadow-motes-2026-10-06/several-dusk-compact.png),
and [large](assets/electron/meadow-motes-2026-10-06/several-dusk-large.png).

## North forest frame — 2026-10-07

The forest pass had reserved the top three tile rows as a visual frame, but
required tree anchors to start below that same region. That left the north edge
empty. I moved the anchor boundary up one tile and kept the framing-row canopy
aligned so its top pixels stay inside the map. The deterministic world-model
test now requires a north-edge tree and checks that no canopy crosses the
canvas boundary.

I rebuilt the Desktop renderer and canonical V backend, then opened fresh
Electron captures with three linked projects at compact and large sizes in
Meadow and Dusk. The added crowns give the upper edge a more deliberate forest
frame without covering the creek, project entrances, bridge, or paths. The
captures still show the broader unresolved art issues: a large rectangular
meadow, mostly orthogonal paths, and a creek that divides the districts. This
small framing correction is not final visual sign-off.

The README's two world images now use the reviewed large captures. Compact and
large evidence is kept in
[`assets/electron/north-forest-frame-2026-10-07/`](assets/electron/north-forest-frame-2026-10-07/).
The run used the 1.42.0 backend built from the source checkout and the real
Electron app in a disposable workspace.

## Firefly light review — 2026-10-07

I captured a three-project workspace from Electron with the real 1.42.0 backend
at 1024×640 and 1920×1080 in Meadow and Dusk. The four screenshots were opened
after the change: [Meadow compact](assets/electron/world/firefly-light-2026-10-07/meadow-compact.png),
[Meadow large](assets/electron/world/firefly-light-2026-10-07/meadow-large.png),
[Dusk compact](assets/electron/world/firefly-light-2026-10-07/dusk-compact.png),
and [Dusk large](assets/electron/world/firefly-light-2026-10-07/dusk-large.png).
The CSS now gives environmental fireflies a crisp close halo and a softer outer
glow; Dusk strengthens those two layers. The source sprite remains pixelated,
and the effect is independent of runtime state. I kept the increase restrained
in Meadow so daytime remains clear. The Dusk captures show distinct warm glints
at ordinary map scale without obscuring the terrain or building silhouettes.

The opened captures still show the more important unresolved art issues: the
valley has a broad rectangular lawn, mostly straight paths, and a creek that
divides the civic and project districts. This small lighting improvement does
not resolve composition, interior density, or the conventional HUD taking
space from the map. The README's Meadow and Dusk hero screenshots now use the
latest reviewed Electron captures; the broader composition work remains open.

## Library receipt evidence — 2026-10-07

I opened the compact and large Electron captures after adding per-file
installation evidence, including expanded evidence-panel captures at both
sizes. The panel keeps normal receipt rows compact; expanding a receipt reveals
only its recorded paths, ownership, and digest comparison. Refresh detects a
user edit without exposing file contents or following a replacement symlink.
Changed, missing, or replaced files sort ahead of unchanged entries so the
actionable state appears first. This fits the existing dark game-menu frame and
keeps dense paths readable. The capture is evidence of the new receipt review, not a claim that every catalog
resource can yet be mapped to an installed file; the Library journey remains
partial for the existing Copilot Skills and Agent Definition gaps.

The captures are from the real Electron app and V 1.42.0 backend in a disposable
workspace: [compact receipts](assets/electron/library/install-evidence-2026-10-07/installation-receipts-compact.png),
[large receipts](assets/electron/library/install-evidence-2026-10-07/installation-receipts-large.png),
[compact expanded evidence](assets/electron/library/install-evidence-2026-10-07/installation-artifact-evidence-compact.png),
and [large expanded evidence](assets/electron/library/install-evidence-2026-10-07/installation-artifact-evidence-large.png).

## World window light — 2026-10-07

The compact and large multi-project Electron maps were captured and opened in
both Meadow and Dusk after adding static warm light over building windows. The
light sits on authored building facades, stays strongest in Dusk, and has no
connection to jobs or Person sessions. At normal map scale it helps the small
windows feel warm without changing silhouettes or obscuring labels. The pass
does not resolve the broad open lawns, straight civic path runs, or project
trees that crowd a few labels; those remain the larger composition issues.

These are live Electron captures against the real V 1.42.0 backend in a
disposable workspace: [Meadow compact](assets/electron/world/window-lights-2026-10-07/several-projects-meadow-compact.png),
[Meadow large](../../static/screenshots/world.png),
[Dusk compact](assets/electron/world/window-lights-2026-10-07/several-projects-dusk-compact.png),
and [Dusk large](../../static/screenshots/world-dusk.png).

## Moonlit room panels and screenshot refresh — 2026-10-07

I captured a fresh empty world, one-project world, three-project world, and
project interior from Electron after the wall-art and selection-context
changes at source `ea2384a2` with the 1.42.0 local V backend. I opened all eight
compact and large PNGs in
[`assets/electron/world-review-2026-10-07/`](assets/electron/world-review-2026-10-07/).
The room now mixes its warm timber with original moonlit wall panels; the
small teal and gold rune marks add a restrained magical accent without
representing runtime state. The selected-place chip now shows only the name,
concept and state, keeping absolute project paths out of the persistent
header. The project-link E2E verifies this.

The review improved wall variation and removed an unnecessary path leak, but
the room still has too much bare floor between real stations. The valley still
reads as a broad rectangular board, with highly geometric civic streets and a
creek that divides districts. These captures are current evidence, not visual
sign-off. `static/screenshots/world.png` and
`static/screenshots/project-interior.png` now use the opened Electron captures;
the README header uses direct text links instead of external badge images.

## Typed project roster review — 2026-10-07

The live Electron project-link flow now reads registered projects from the
typed V endpoint instead of parsing CLI output. I opened the compact and large
Workspace captures after the UI adjustment:
[compact](assets/electron/workspace/project-roster-typed-compact.png) and
[large](assets/electron/workspace/project-roster-typed-large.png). The long
agent start-context report is now collapsed by default, keeping the linked
project card visible and actionable at both sizes. The card exposes real link
health, the current target, and a direct route to the same project building in
World.

The compact view still shares the page with the file browser above the roster,
and the Workspace inspector remains denser and more conventional than the
spatial World. This pass improves project reachability and avoids making
verbose context output the first thing users see; it does not resolve the
larger inspector/world visual hierarchy work. The screenshots came from the
real Electron app and locally built V backend in a disposable E2E workspace;
the test also asserted the live `GET /api/v1/projects` response, safe link
review, world placement, and palette navigation.

## Offline World shell — 2026-10-07

The renderer-only smoke test caught that the whole map disappeared while
workspace queries were still pending with no backend. `/world` now renders its
known semantic places immediately, marks the map busy, and shows a small
game-menu status plaque while live project, memory, tool, job, and Person
state resolves. Read failures remain visible with their existing retry/recovery
surfaces; no worker or project is inferred from missing data. The offline
notice says that live state may be incomplete or out of date instead of
claiming that fresh data is a previous snapshot. I opened the
offline browser capture at
[1280×720](assets/renderer/world-offline-loading-2026-10-07.png): the valley
stays visible below the explicit backend-offline notice and the live-data
plaque. The focused renderer E2E now passes with the backend unavailable.

## Commons footpath fit — 2026-10-07

I retuned the shared route's bank bend slightly so its arc survives the fitted
world view without consuming so much meadow that terrain-variation checks lose
their representative grass sample. The real Electron app was captured against
the source-built 1.42.0 V backend in a disposable workspace. I opened the empty
and one-project maps at both 1024×640 and 1920×1080:
[empty compact](assets/electron/footpath-review-2026-10-07/world-empty-compact.png),
[empty large](assets/electron/footpath-review-2026-10-07/world-empty-large.png),
[one project compact](assets/electron/footpath-review-2026-10-07/world-one-project-compact.png),
and [one project large](assets/electron/footpath-review-2026-10-07/world-one-project-large.png).
The bend is subtle and keeps the bridge approach level. Opening the captures
also confirmed that this is only a small improvement: entrance routes still
form right-angle runs, and the empty valley still has a broad lawn. Those are
composition work, not visual sign-off. No runtime characters appear in these
idle captures.

## Spatial keyboard navigation — 2026-10-09

Focusable World entities now respond to arrow keys by moving focus to the
nearest inspectable place in that direction; the focused plaque explains the
place and its action, and Enter opens the same canonical route as a click. The
separate map control retains arrow-key camera panning and Home-to-fit. This
keeps navigation direct without adding an avatar or fabricated activity.

I opened the real Electron captures at [1024×640](assets/electron/world/world-spatial-focus-compact.png)
and [1920×1080](assets/electron/world/world-spatial-focus-large.png). The gold
selection frame and semantic plaque make the keyboard location visible at both
sizes, while the valley remains the dominant surface. On compact windows the
plaque sits close to neighboring art, so this is an interaction/accessibility
improvement rather than a claim that the map composition is finished. The
existing geometric path network and open lawns remain visible in both captures.

## Person session restart review — 2026-10-09

The People session lifecycle now offers **Start again** for a completed
session. This opens the normal start review with the prior project, runner,
and model as starting values, but validates those choices against current
workspace and runner availability. It explicitly starts a fresh PTY and does
not claim to restore conversation history. In compact and large Electron
captures, the previous setup summary and recovery warning remain visible; the
fixed action bar keeps Cancel and Start reachable while the detailed preview
scrolls. The compact dialog uses most of the viewport, which is appropriate
for reviewing a potentially destructive runner launch, though the form is
still dense. No session is started until the user confirms.

Reviewed captures: [compact](assets/electron/people/person-start-again-compact.png)
and [large](assets/electron/people/person-start-again-large.png).

## Typed Library catalog review — 2026-10-09

The Library now searches Skills and Agent Definitions from one field. Skill
catalog metadata comes from `GET /api/v1/skills/catalog`; the result shows
origin and source path, declared requirements, and compatibility separately
from the Toolkit receipt state. I opened the focused Skills card captures at
[compact](assets/electron/library/catalog-search-details-compact.png) and
[large](assets/electron/library/catalog-search-details-large.png). They show
the real `mcp-audit` entry, its first-party source path, no Toolkit receipt,
and the target registry summary (10 supported, 1 partial). The detailed target
list stays collapsed until opened. The compact ID now remains on one line;
the E2E asserts the applied no-wrap style as well as the metadata and
compatibility details.

These are cropped catalog-card captures rather than full-window screenshots so
the provenance and compatibility remain legible in documentation. The card is
compact and consistent with the indigo-and-gold menu language, though the
description still takes several lines on compact screens. Broader Library
layout, repository-scoped Skills/Agent Definitions, and capability-pack
discovery remain open work; this card review is not a visual sign-off for the
whole Desktop.
