---
name: architecture-diagram
description: >-
  WHAT — Create polished dark-themed architecture diagrams as self-contained
  HTML+SVG files (inline SVG, CSS styling, PNG/PDF export toolbar). Use when
  the user asks for system, infrastructure, cloud, security, or network
  topology diagrams rendered as a shareable visual artifact rather than code.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0.0'
  tags:
  - architecture
  - diagram
  - svg
  - html
  - visualization
  - cloud
  - security
  - topology
  domain: architecture
tools:
- claude-code
- cursor
- opencode
- windsurf
- copilot-cli
requires:
- modern browser for rendering/export
produces:
- self-contained architecture-diagram .html file
triggers:
- draw an architecture diagram
- create a system diagram
- infrastructure diagram
- network topology diagram
- cloud architecture diagram
- security architecture diagram
---

# Architecture Diagram — Self-Contained HTML+SVG Diagrams

Create professional technical architecture diagrams as **single self-contained
HTML files** with inline SVG graphics and CSS styling. The output renders
correctly when opened directly in any modern browser — no build step, no
JavaScript framework, no external images.

## When to use

- System, infrastructure, cloud, security, or network-topology diagrams.
- A shareable, presentation-ready visual artifact is the deliverable.
- Dark-theme technical aesthetic is desired.

For methodology (what to draw at each level), pair with `architecture/c4-model`;
for lightweight in-repo text diagrams, use `tooling/mermaid`. This skill covers
the **rendered artifact** case.

## Workflow

1. Copy `resources/template.html` as the starting point.
2. Customize the `<title>`, header text, and footer metadata.
3. Adjust the SVG `viewBox` if needed (default `1000 x 680`).
4. Add/reposition component boxes using the component pattern below.
5. Draw connection arrows early in the SVG (after the background grid) so they
   render behind boxes.
6. Update the three summary cards and legend.
7. Deliver one `.html` file.

## Design system

### Semantic color palette

| Component type | Fill (rgba) | Stroke |
|----------------|-------------|--------|
| Frontend | `rgba(8, 51, 68, 0.4)` | `#22d3ee` |
| Backend | `rgba(6, 78, 59, 0.4)` | `#34d399` |
| Database | `rgba(76, 29, 149, 0.4)` | `#a78bfa` |
| AWS/Cloud | `rgba(120, 53, 15, 0.3)` | `#fbbf24` |
| Security | `rgba(136, 19, 55, 0.4)` | `#fb7185` |
| Message bus | `rgba(251, 146, 60, 0.3)` | `#fb923c` |
| External/Generic | `rgba(30, 41, 59, 0.5)` | `#94a3b8` |

### Typography

JetBrains Mono throughout (monospace, technical aesthetic):

```html
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
```

Font sizes: 12px component names, 9px sublabels, 8px annotations, 7px tiny labels.

### Visual elements

**Background:** `#020617` with a subtle grid pattern:

```svg
<pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
  <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#1e293b" stroke-width="0.5"/>
</pattern>
```

**Component boxes:** rounded rectangles (`rx="6"`), 1.5px stroke,
semi-transparent fills.

**Security groups:** dashed stroke (`stroke-dasharray="4,4"`), transparent
fill, rose color.

**Region boundaries:** larger dashed stroke (`stroke-dasharray="8,4"`), amber
color, `rx="12"`.

**Arrows:** SVG marker arrowheads:

```svg
<marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
  <polygon points="0 0, 10 3.5, 0 7" fill="#64748b" />
</marker>
```

Draw arrows before boxes so they layer behind components.

**Masking arrows behind transparent fills:** semi-transparent box fills let
arrows show through. Pre-draw an opaque rect (`fill="#0f172a"`) beneath the
styled rect:

```svg
<!-- Opaque background to mask arrows -->
<rect x="X" y="Y" width="W" height="H" rx="6" fill="#0f172a"/>
<!-- Styled component on top -->
<rect x="X" y="Y" width="W" height="H" rx="6" fill="rgba(76, 29, 149, 0.4)" stroke="#a78bfa" stroke-width="1.5"/>
```

**Auth/security flows:** dashed lines, rose color (`#fb7185`).

**Message/event buses:** small connectors placed in the vertical gap between
services:

```svg
<rect x="X" y="Y" width="120" height="20" rx="4" fill="rgba(251, 146, 60, 0.3)" stroke="#fb923c" stroke-width="1"/>
<text x="CENTER_X" y="Y+14" fill="#fb923c" font-size="7" text-anchor="middle">Kafka / RabbitMQ</text>
```

### Component box pattern

```svg
<rect x="X" y="Y" width="W" height="H" rx="6" fill="FILL_COLOR" stroke="STROKE_COLOR" stroke-width="1.5"/>
<text x="CENTER_X" y="Y+20" fill="white" font-size="11" font-weight="600" text-anchor="middle">LABEL</text>
<text x="CENTER_X" y="Y+36" fill="#94a3b8" font-size="9" text-anchor="middle">sublabel</text>
```

### Info card pattern

```html
<div class="card">
  <div class="card-header">
    <div class="card-dot COLOR"></div>
    <h3>Title</h3>
  </div>
  <ul>
    <li>• Item one</li>
    <li>• Item two</li>
  </ul>
</div>
```

## Layout rules

### Vertical spacing (critical)

Standard component height is 60px (80–120px for larger blocks); keep a minimum
**40px vertical gap** between stacked components, and place inline connectors
(buses) centered inside that gap — never overlapping either component:

```text
Component A: y=70,  height=60  → ends at y=130
Gap:         y=130 to y=170   → 40px gap, bus at y=140 (20px tall)
Component B: y=170, height=60  → ends at y=230
```

### Legend placement (critical)

Place legends **outside all boundary boxes** (regions, clusters, security
groups). Compute the lowest boundary end (`y + height`), start the legend at
least 20px below it, and extend the SVG viewBox height accordingly.

### Page structure

1. Header — title with pulsing dot indicator, subtitle, export toolbar.
2. Main SVG diagram — contained in a rounded border card.
3. Summary cards — grid of three cards below the diagram.
4. Footer — minimal metadata line.

## Export toolbar

The template ships a collapsed `⋯` toggle in the header revealing three
export actions — clipboard copy, high-DPI PNG download, and one-page PDF —
all driven by two pinned CDN scripts with Subresource Integrity hashes
(`html2canvas`, `jsPDF`). Keep these intact when customizing:

- Both `<script>` tags in `<head>` (pinned versions, SRI hashes,
  `crossorigin="anonymous"`).
- `id="report-container"` on the outermost `.container` div (capture target).
- `.toolbar` markup plus `@media print { .toolbar { display: none !important; } }`.
- The `copyAsImage()`, `downloadPNG()`, `downloadPDF()` functions before
  `</body>`.

Caveats: the clipboard API needs a user gesture and a secure context;
`html2canvas` renders plain SVG shapes/text reliably but not
`<foreignObject>`; raise capture `scale` above `2` for higher-resolution output.

## Output contract

Exactly one self-contained `.html` file per diagram:

- Embedded CSS only (external exception: Google Fonts).
- Inline SVG only (no external images).
- Renders correctly opened directly in any modern browser.

## References

- Template: [`resources/template.html`](resources/template.html)
