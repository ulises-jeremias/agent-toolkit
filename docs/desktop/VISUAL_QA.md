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
The 54-image artifact is archived at
[`assets/electron/final-main-2026-10-06/`](assets/electron/final-main-2026-10-06/).

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
visually complete. The README gallery now uses genuine screenshots from this
released Electron build, and no tracked SVG mockups are used as product images.

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
those over illustrative SVG mockups; there are no SVG mockups in its gallery.
Use the visual review archive for empty-state and edge-case screenshots rather
than replacing the product overview with an empty map.

## Screenshot policy

Checked-in screenshots must come from the running Electron app and canonical
backend against disposable test data. They are documentation examples and
review evidence, not concept-board art. Refresh `static/screenshots/` when the
pictured product changes, and keep the README gallery to a small set that
explains the current experience. The README currently uses genuine PNG captures;
there are no tracked SVG mockups in the repository. Keep functional status
badges as links, not substitutes for product screenshots. The complete
compact/large and edge-case capture sets stay under
`docs/desktop/assets/electron/` and are linked from review evidence.
Inspiration boards must never be copied into product art or presented as
screenshots.
