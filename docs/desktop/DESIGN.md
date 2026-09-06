# Agent Toolkit Desktop Design Contract

**Status:** governing visual and interaction design direction for Agent Toolkit Desktop.

This document defines how Agent Toolkit Desktop should look, feel, and present information. It complements [PRODUCT_VISION.md](PRODUCT_VISION.md), [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md), [USER_JOURNEYS.md](USER_JOURNEYS.md), [WORKFLOW_COVERAGE.md](WORKFLOW_COVERAGE.md), and [VISUAL_QA.md](VISUAL_QA.md). It is not an executable token file and it does not override Engine truth, accessibility, or platform constraints.

The goal is simple:

> A serious native workstation for coding agents, expressed through a warm pixel-art office world.

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

## 2. Identity: Paper Co. × pixel-art office

Paper Co. remains the base design language: warm paper, ink, manila, brass, rust, sage, folders, receipts, ledgers, tabs, stamps, and editorial typography.

The evolution is a **pixel-art office workstation** inspired by the broad qualities of classic top-down adventure interiors and cozy simulation games: readable rooms, wooden floors, plants, desks, lamps, bookshelves, filing cabinets, meeting tables, rugs, tiny purposeful characters, and carefully placed environmental details.

These are references to a visual tradition, not assets to copy. Do not reproduce copyrighted game sprites, maps, characters, UI, or Munder Difflin artwork.

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

The current six primary destinations remain the baseline until journey evidence proves otherwise:

- Office
- Library
- Operations
- Workspace
- Insights
- Settings

Connections may become first-class only if journey evidence justifies it; do not change information architecture merely because a concept image includes a destination.

## 9. Office and Floor Map

Office is the flagship expression of the product identity.

It must answer, without requiring the Floor Map:

- what needs attention;
- which work is active;
- which agents exist and which are running;
- failures and approvals;
- relevant recent activity;
- how to enter a real session or operation.

The Floor Map is a spatial representation of authoritative agent identity and real activity, not the product's only navigation model.

A useful model is:

> **Operational overview + optional/integrated office world**

Desks visually read as desks. Rooms remain legible at a glance. Use spatial zones only when they communicate something useful. Candidate zones include Workspace, Meeting, Library, Operations, Lounge, Diagnostics, and Archive; do not create rooms merely to mirror navigation labels.

A catalog agent may have a desk while idle. Only runtime evidence changes the presentation to running, waiting, attention, error, handoff, or other active states.

## 10. Screen-specific design intent

### Onboarding

Warm reception/welcome-desk feeling. Explain the next choice before technical vocabulary. Pixel illustration builds confidence; it does not compete with setup decisions.

### Office

Most expressive visual surface. Operational overview and Floor Map coexist without sacrificing truth or discoverability.

### Library

Feels like an organized capability library rather than a generic app marketplace. Search, filtering, compatibility, provenance, and actions remain conventional. Shelves/catalog imagery may frame the experience.

### Operations

More serious command-center tone. Jobs, loops, swarms, and Doctor use dense conventional controls. A pixel-art operations room may reinforce context without stealing space from status and actions.

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
- Office/Floor philosophy;
- major component grammar;
- motion philosophy;
- visual asset taxonomy.

Do not update it for one bug fix, a local spacing correction, a single icon swap, or an implementation-only refactor that preserves design intent.

Architecturally significant technical decisions still require ADRs.
