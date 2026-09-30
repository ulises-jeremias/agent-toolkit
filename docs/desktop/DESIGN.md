# Agent Toolkit Desktop Design Contract

**Status: CURRENT CONTRACT** — governing visual and interaction design
direction for Agent Toolkit Desktop. Re-confirmed 2026-09-13 at `ecc4d67c`;
**spatial home evolved 2026-09-30** ([ADR-034](../adrs/ADR-034-semantic-world.md),
[SEMANTIC_WORLD.md](SEMANTIC_WORLD.md)).

This document defines how Agent Toolkit Desktop should look, feel, and present information. It complements [PRODUCT_VISION.md](PRODUCT_VISION.md), [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md), [USER_JOURNEYS.md](USER_JOURNEYS.md), [WORKFLOW_COVERAGE.md](WORKFLOW_COVERAGE.md), [VISUAL_QA.md](VISUAL_QA.md), and [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md). It is not an executable token file and it does not override Engine truth, accessibility, or platform constraints.

The goal is simple:

> A serious workstation for coding agents: a warm **semantic pixel-art world**
> that explains the product, with Paper Co. **inspectors** for professional work.

## 0. Visual convergence goal (product direction)

### 0.1 Semantic world is the primary spatial goal (2026-09-30)

The **semantic spatial world** is the default home and the primary way the
product explains itself. Paper Co. inspectors (Operations, Library, Terminal,
Office attention, Workspace, Insights, Settings) stay professional, dense, and
fast. Policy:

- **World explains the product.** Places and objects are projections of real
  domain concepts (workspace, projects, knowledge, memory, tools, jobs).
- **Inspectors do the work.** Clicking a place opens an existing destination
  via `href()` / command palette — not a parallel fake dashboard.
- **No fake life.** Characters exist only for proven agents/runs/jobs. Ambient
  environment animation is allowed; system activity comes only from real state
  / SSE. Empty and calm are valid.
- **Not game-before-tool.** Palette, keyboard, terminal dock, and direct open
  remain. Do not require walking to be productive.
- Full vocabulary, theme keys, layout, and renderer decision:
  [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md) and
  [ADR-034](../adrs/ADR-034-semantic-world.md).

### 0.2 Paper Co. × concept references (2026-09-07, still binding for inspectors)

The visual direction in [`assets/design/`](assets/design/) — anchored by
[`concept-board.jpg`](assets/design/concept-board.jpg) and
[`office.jpg`](assets/design/office.jpg), and guiding
[`library.jpg`](assets/design/library.jpg),
[`operations.jpg`](assets/design/operations.jpg),
[`onboarding.jpg`](assets/design/onboarding.jpg) — remains a **first-class
aesthetic goal for inspector craft**: warm Paper Co. materials, editorial
typography, dark terminal treatment, coherent pixel materials — not stickers
on generic panels.

**Semantic world art direction** (2026-09-30) lives alongside those boards:

- [`asset-sheet-cozy-world.jpg`](assets/design/asset-sheet-cozy-world.jpg) —
  tilesets + building archetypes + UI chrome (slice before wiring sprites).
- [`semantic-world-product-board.jpg`](assets/design/semantic-world-product-board.jpg)
  / [`semantic-world-ui-board.jpg`](assets/design/semantic-world-ui-board.jpg)
  — world-first IA (project houses + shared places + professional inspectors).

Character rows on the asset sheet are **not** a license to invent NPCs.
See [`assets/design/README.md`](assets/design/README.md) and ADR-034.

The end state is not "a native GUI using warm colors". It is a serious
coding-agent workstation whose **home** is a truthful cozy top-down world and
whose **panels** feel like the rich Paper Co. references. Concept images stay
directional: do not copy their fictional metrics, statuses, or IA.

For every visible GUI change, actively ask:

- Does this move the production app closer to the design references?
- Does this screen feel like part of the same world?
- Does it have enough craft and environmental richness?
- Does it still look generic, empty, or dashboard-like?
- Can we make it materially closer to the concept while preserving clarity and truth?

Boundaries:

- Product truth remains authoritative. The references' fictional features,
  metrics, statuses, layouts and mock data are **not** requirements — the
  aesthetic qualities are.
- "Functionally correct" is not acceptance when the task includes meaningful
  visible UI; iterate toward visually delightful within the hierarchy in §1.
- During #1130/#1127/#1128: preserve the direction in whatever UI is
  necessarily touched, capture discrepancies, record follow-ups — but do not
  convert those slices into visual-redesign PRs.
- After the standalone-product sequence (#1129 → #1130 → #1127 → #1128), run
  an explicit **visual-convergence phase**: compare real production
  screenshots against the references destination-by-destination and
  deliberately close the remaining gap.

Quality bar from here on: **truthful + usable + native + visually convergent
with docs/desktop/assets/design/.**

The product should feel unmistakably like Agent Toolkit: capable, local, crafted, calm, technical, and delightful without becoming a game or a generic SaaS dashboard.

## 1. Design hierarchy

When design goals conflict, use this order:

> **Clarity → Control → Feedback → Discoverability → Personality → Decoration**

Personality is important. It never outranks understanding, safety, input focus, or operational truth.

### Core principles

- **Cozy productivity.** The app may feel warm and welcoming without becoming unserious.
- **Conventional interaction, distinctive presentation.** Users operate a desktop tool, not a game controller.
- **Pixel art is a material, not a sticker pack.** Use it as a coherent visual language rather than random decoration.
- **Operational truth before animation.** Visual activity represents real catalog, configuration, runtime, or evidence state.
- **Progressive richness.** Hierarchy and task clarity appear first; environmental detail rewards exploration later.
- **Calm density.** Dense information is allowed; visual noise is not.
- **Craft over novelty.** Reusable visual grammar beats one-off clever screens.
- **Standalone identity.** The design may echo Hornero craftsmanship but must not depend on HorneroConfig or sibling repositories.

## 2. Identity: Paper Co. inspectors × semantic pixel world

Paper Co. remains the base design language for chrome and inspectors: warm
paper, ink, manila, brass, rust, sage, folders, receipts, ledgers, tabs,
stamps, and editorial typography.

The spatial evolution is a **semantic cozy top-down world** (default theme
`cozy-topdown`): readable grounds and buildings that mean workspace/projects,
knowledge annexes, terminal workstations, and characters only when runtime
evidence exists. Inspectors stay Paper Co.; the world uses original/licensed
pixel materials resolved through **semantic theme keys**, not hardcoded
filenames in features.

These are references to a visual tradition, not assets to copy. Do not
reproduce copyrighted game sprites, maps, characters, UI, or Munder Difflin /
Agent Office / Stardew / Zelda artwork.

### Hornero signature

The Hornero motif connects Agent Toolkit with the maintainer's broader design language: deliberate building, a durable nest, warm craft, and a place designed around its inhabitants.

Use sparingly:

- a small hornero or nest mark;
- tiny workshop/home motifs;
- occasional builder-oriented editorial copy;
- subtle environmental objects.

Do not rename Agent Toolkit. Do not turn every empty state into a bird joke. The Hornero is a signature, not a mascot-first product strategy.

## 3. What the product must not become

Reject these directions:

- generic AI SaaS;
- purple/indigo AI gradients;
- glassmorphism;
- card soup;
- a VS Code clone;
- a generic admin dashboard;
- fake RPG mechanics, XP, levels, or achievement systems unrelated to real work;
- arbitrary pixel-art stickers on otherwise generic UI;
- meaningless ambient motion;
- heavy skeuomorphism that hides basic actions;
- forcing the Office Floor metaphor onto every workflow;
- pixel fonts for normal body text or dense operational tables;
- status communicated only by color;
- fabricated activity, progress, health, compatibility, cost, receipt, or provenance.

## 4. Visual truth model

Beautiful lies are worse than boring truth.

The UI distinguishes four kinds of truth:

1. **Catalog truth** — what Agent Toolkit actually provides or supports.
2. **Configuration truth** — what this user/workspace has actually enabled or installed.
3. **Runtime truth** — what is happening right now.
4. **Evidence truth** — what receipts, provenance, hashes, verification, and measurements actually prove.

A desk may represent a catalog agent while the agent is idle. A loop template may exist without a configured loop. A provider may be supported but not configured. Runtime emptiness never means the catalog is empty.

Concept images in this repository contain illustrative demo values. They are not product truth and must never be copied into production data paths.

## 5. Themes and color

The executable theme/token implementation remains the value authority. This document defines intent and semantic use.

### Paper

The canonical warm expression:

- paper-cream canvas;
- manila and warm neutral panels;
- restrained wood/environment surfaces;
- sage and dusty teal accents;
- brass for emphasis;
- rust for destructive/error-adjacent accents where semantically appropriate;
- dark ink typography.

### Ink

A deliberate dark expression, not a mechanical inversion:

- charcoal/near-black chrome and canvas;
- warm off-white text;
- desaturated sage/teal and brass accents;
- low-noise dark surfaces;
- pixel assets framed or variant-rendered so they remain intentional.

### System

System follows OS appearance and resolves to Paper- or Ink-compatible behavior. It is not a third unrelated visual language.

### Representative palette

These values are visual-direction anchors only; semantic tokens in code remain canonical.

| Role | Reference |
|---|---|
| Paper Cream | `#F6EBD7` |
| Manila Tan | `#D4B483` |
| Sage Green | `#7B9E7E` |
| Dusty Teal | `#4E7C7B` |
| Rust Red | `#B5523C` |
| Brass Gold | `#D4A94B` |
| Ink Charcoal | `#1F1F1F` |
| Terminal Accent | `#39FF9B` |

Prefer semantic roles such as `surface.canvas`, `surface.panel`, `text.primary`, `border.focus`, `status.warning`, and `terminal.accent` over raw colors in feature code.

## 6. Typography

Audit bundled fonts before changing dependencies. The current intended roles are:

- **Fraunces** — destination headings and rare editorial/brand moments;
- **IBM Plex Sans** — navigation, labels, forms, tables, body copy, controls;
- **IBM Plex Mono** — terminal, logs, commands, paths, IDs, hashes, code-like technical details.

Pixel fonts, if introduced, are restricted to environmental signage, floor-map labels, or decorative display moments. They never replace readable vector body text.

New fonts require licensing, packaging, i18n, shaping, and runtime validation.

## 7. Pixel-art grammar

Pixel assets must share one craft system.

### Rendering

- use a small logical sprite grid chosen from current renderer constraints;
- render pixel art with nearest-neighbor sampling;
- prefer integer positioning/scaling where the asset depends on crisp pixels;
- avoid accidental bilinear blur;
- test HiDPI at integer and non-integer UI scale combinations;
- preserve one consistent light direction, outline philosophy, and palette density.

Before canonizing 16×16, 24×24, or 32×32 assets, verify current `gg`/sokol behavior and actual UI density. Do not choose a grid from aesthetics alone.

### Asset classes

**Agent avatars** — authoritative identity with visual variants for idle, active, waiting, attention, error, and selection. Runtime state controls runtime presentation.

**Office furniture** — desks, chairs, shelves, cabinets, plants, terminals, meeting furniture, lamps, boards, couches, rugs, storage, doors.

**Operational objects** — inboxes, approval trays, receipts, documents, loop/calendar objects, connection devices, diagnostic tools, packages/crates.

**Hornero elements** — bird, nest, workshop/home details used sparingly.

### Asset licensing

Production artwork must be original or appropriately licensed. Never import copyrighted assets from Zelda, Stardew Valley, Munder Difflin, or another product.

## 8. Application shell

The shell remains conventional and fast:

- primary navigation;
- active workspace;
- Search / Run;
- content surface;
- contextual inspector/drawer;
- global activity affordance;
- terminal/session dock.

Pixel art decorates and contextualizes this shell. It does not replace standard affordances such as buttons, tabs, fields, tables, scrollbars, selection, focus, or resize handles.

Primary destinations (Electron shell):

- **World** (default home — `/` → `/world`) — semantic spatial explanation
- Office — attention inspector ("what needs me?")
- Library
- Operations
- Workspace
- Insights
- Terminal
- Settings

World is the home. The others are inspectors / workstations opened from places
or the nav/palette. Do not add destinations merely to mirror a concept image.
See [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md).

## 9. World and Office

**World** is the flagship spatial expression of product identity (ADR-034).

It must answer at a glance, without forcing a walk:

- which workspace/harness is active;
- which projects exist (real `projects/` / project list);
- whether shared knowledge/memory is present or honestly empty;
- which jobs/runs have characters (proven only);
- how to open terminal, workspace, library, or operations in one click / Cmd+K.

**Office** remains the attention inspector: failures, blocked work, self-check
problems, backend down — without inventing activity.

A useful model is:

> **Semantic world home + Paper Co. inspectors**

Places mean domain concepts. Catalog agents may appear as nameplates/desks
while idle; only runtime evidence (jobs / swarm runs / sessions) creates
characters. Do not create rooms merely to mirror every nav label or to preview
unavailable APIs.

## 10. Screen-specific design intent

### Onboarding

Warm reception/welcome-desk feeling. Explain the next choice before technical vocabulary. Pixel illustration builds confidence; it does not compete with setup decisions.

### World

Most expressive visual surface. Semantic places/objects/characters only from
real state; list fallback always present; clicks open inspectors.

### Office

Attention inspector. Dense Paper Co. tables for needs-you and running work;
not the default home.

### Library

Feels like an organized capability library rather than a generic app marketplace. Search, filtering, compatibility, provenance, and actions remain conventional. Shelves/catalog imagery may frame the experience. Install counts, ratings, "verified" badges, publisher metrics, or third-party marketplace metadata require a truthful source; the bundled catalog is not a marketplace, and absence of such data renders as honest absence rather than invented numbers.

### Operations

Workshop / inspector — a Paper Co. operations board the world opens, not a second home dashboard. Real job table (status, command, started, duration, exit). Manila for doctor. Brass marks the selected row. No decorative NPCs. Job progress is shown only when it is measured from real runtime sources; otherwise it is omitted — never estimated to fill a bar.

### Workspace

Most technical destination. Files, project context, relevant Git state, memory/context, and external-tool actions dominate. Environmental detail decreases.

### Insights

Editorial/analytical. Charts remain conventional, labeled, accessible, and evidence-backed. Pixel motifs stay secondary.

### Settings

Calm and utilitarian. Themes and appearance may show stronger visual previews; ordinary preferences should not become decorative scenes.

## 11. Components and material

Establish shared behavior before stylistic variation. Components may include Button, IconButton, TextField, SearchField, Select, Toggle, Checkbox, SegmentedControl, Chip, StatusBadge, ListRow, Table, SectionHeader, PanelHeader, EmptyState, ErrorState, LoadingState, Tooltip, Popover, Modal, Drawer, Toast, Progress, ScrollArea, FocusRing, Splitter, and TerminalPaneChrome.

Do not build a speculative widget framework. Extract primitives when repeated behavior proves the abstraction.

For interactive components define consistent states where applicable:

`default · hover · focused · pressed · selected · disabled · loading · success · warning · error`

Status must use more than color when ambiguity matters: combine text, icon/shape, border, or pattern.

### Material hierarchy

Use tactile cues without heavy skeuomorphism:

- paper canvas;
- manila/card surface;
- wood/environment surface;
- ink/terminal surface;
- brass/high-value accent.

Prefer thin borders, restrained rounding, subtle warm shadows, and occasional inset treatment. Avoid large blurry SaaS shadows and glass effects.

## 12. Spacing and geometry

Use a small spacing system compatible with crisp pixel assets and readable vector UI. Prefer a 4px/8px rhythm where current renderer geometry supports it.

Document and keep consistent:

- page margins;
- panel gaps;
- row heights;
- card padding;
- icon/text gaps;
- inspector width;
- terminal chrome;
- minimum interaction targets.

One computed geometry must drive drawing, hover, hit testing, focus, and tooltip anchoring. Pixel alignment never justifies tiny interaction targets.

## 13. Iconography

Keep three classes distinct:

1. **Functional icons** — standard interaction meaning: search, add, close, trash, expand, filter.
2. **Product/domain pixel icons** — skills, agents, loops, MCP, packs, workspace concepts.
3. **Environmental sprites** — furniture, plants, office objects, Hornero details.

Do not mix unrelated icon families. A destructive action must remain unmistakably destructive even inside the pixel-art theme.

## 14. Terminal

The terminal is a flagship surface and intentionally contrasts with the warm office:

- dark background;
- highly legible vector/mono text;
- restrained terminal accent;
- obvious pane/session focus;
- clear tab/split/close/recovery chrome.

Do not pixelate terminal text or sacrifice VT correctness for theme. Terminal input focus always outranks decorative/global shortcuts according to [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md).

## 15. Motion

Motion must communicate something real:

- state transition;
- real runtime event;
- progress;
- attention;
- navigation/context.

Legitimate examples include an agent entering an actual active state, a real handoff arriving, a job completing, or a selected avatar using a restrained idle frame.

Forbidden examples include random walking, fake envelopes, permanent pulsing, decorative activity unsupported by Engine state, or motion added only because an empty screen feels quiet.

Reduced Motion removes non-essential animation.

## 16. Responsive behavior

Pixel art cannot depend on one showcase resolution. Follow the matrix in [VISUAL_QA.md](VISUAL_QA.md).

When space decreases, preserve task completion first:

- collapse secondary environmental detail;
- move inspector content to a drawer;
- place Floor Map behind a tab when needed;
- compact navigation;
- reflow cards;
- reduce terminal height;
- preserve readable text and primary actions.

Never shrink critical text simply to preserve a decorative scene.

## 17. Accessibility and localization

Pixel art does not reduce accessibility requirements.

Design for:

- visible focus;
- keyboard-only operation;
- contrast in Paper and Ink;
- non-color status cues;
- reduced motion;
- usable scaling and interaction targets;
- long translations;
- RTL geometry;
- Arabic shaping/bidi limitations honestly documented.

Important information must not exist only inside non-localizable environmental signage. Decorative signage may remain decorative.

Do not claim unsupported OS accessibility-tree or WCAG conformance; follow [VISUAL_QA.md](VISUAL_QA.md).

## 18. Content and voice

Voice is calm, capable, builder-oriented, warm, and concise.

Prefer:

- direct action language;
- explanations of consequences;
- human task vocabulary before internal terms;
- lightly playful editorial copy in appropriate low-risk spaces.

Avoid corporate AI hype, fake enthusiasm, constant Hornero jokes, and RPG vocabulary. Errors and destructive actions remain direct and precise.

## 19. Design references

The following generated concept images are **directional references only**. They intentionally contain illustrative state, invented names, demo metrics, and speculative information architecture. Do not treat their data as implementation requirements.

- [Concept board](assets/design/concept-board.jpg)
- [Office flagship](assets/design/office.jpg)
- [Library](assets/design/library.jpg)
- [Operations](assets/design/operations.jpg)
- [Onboarding](assets/design/onboarding.jpg)

The concept board and Office are the canonical visual anchors committed with this contract. The Library, Operations, and Onboarding references are exploratory screen concepts. Additional screen concepts may be added later through focused design PRs. Concept imagery is directional only and must not override current navigation, truth, accessibility, or workflow contracts.

## 20. Validation

Major visual changes follow:

> build → run → navigate → capture → **open the screenshot** → critique → fix → recapture

Goldens answer **"did pixels change?"**. Design review answers **"are these the right pixels?"**. Both matter.

Review changes against:

- this document;
- [PRODUCT_VISION.md](PRODUCT_VISION.md);
- [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md);
- [VISUAL_QA.md](VISUAL_QA.md);
- accessibility and i18n constraints;
- executable theme tokens;
- the actual running application.

Do not update golden baselines to hide a regression.

## 21. Change policy

Update this document when changing a durable visual rule, including:

- theme philosophy;
- typography roles;
- pixel-art scale/rendering rules;
- shell presentation;
- World / Office spatial philosophy (also update [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md) / ADR-034);
- major component grammar;
- motion philosophy;
- visual asset taxonomy.

Do not update it for one bug fix, a local spacing correction, a single icon swap, or an implementation-only refactor that preserves design intent.

Architecturally significant technical decisions still require ADRs.
