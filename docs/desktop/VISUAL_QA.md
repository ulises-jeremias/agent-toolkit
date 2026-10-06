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

## Latest opened review — 2026-10-06

Linux Electron run [`37408692569`](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37408692569)
was opened at compact and large sizes for an empty world, one project, several
projects, the project interior, meadow, and dusk. Added grass motifs are
crisper and more visible at normal map scale, and the dusk pass retains more
color. The project room reads as a place with actual overview, records, files,
and terminal destinations. The full map still needs work: the ground has a
strong horizontal color seam, the creek and paths look too straight, and some
trees on the eastern edge read as separated rows rather than a grove. This was
an iteration review, not visual sign-off.

A wider creek corridor and rotated meadow-noise field are on branch
`feat/enchanted-world-composition` at `046a26f6`. Fresh captures are pending in
[`desktop.yml` run 37409701733](https://github.com/ulises-jeremias/agent-toolkit/actions/runs/37409701733).
Open that run's uploaded screenshots before accepting the change. Record the
specific files reviewed and any post-capture corrections here; keep remaining
composition issues visible rather than treating asset generation or green
tests as an art-quality verdict.

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
