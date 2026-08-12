# Research: Minimal Diagramming Set — #385 (2026-08-12)

**Purpose:** Per §44: Mermaid is portable baseline; C4 is methodology not renderer — clarify `C4 model guidance` vs `Mermaid rendering` vs `PlantUML C4` vs `Structurizr`; avoid 5 interchangeable skills; prefer minimal primitives.

## Findings

### Mermaid (primary — portable, Markdown-native, Git-native)
- **Repo:** `mermaid-js/mermaid` https://github.com/mermaid-js/mermaid — MIT, active 2026-08-12 (live editor https://mermaid.live). Diagrams: flowchart, sequence, class, state, ER, gantt, pie, gitGraph, etc. NPM `mermaid` `10.x`, `@mermaid-js/mermaid 10.9.7-preview.41` MIT, `@mermaid-js/parser` MIT.
- **Rendering:** Text → SVG/PNG via `mermaid CLI` (`mmdc`) or `docs/ARCHITECTURE.md` native GitHub rendering; no binary distribution needed.
- **Existing Toolkit:** `docs/ARCHITECTURE.md` already authors Mermaid manually — no skill; no `skills/tooling/mermaid/`.
- **Verdict:** **ADOPT** — primary. Markdown-native, smallest context cost, aligns with threat-model sequence/data-flow diagrams.

### C4 model (methodology — 4 levels, not necessarily separate renderer)
- **Spec:** Simon Brown C4 — Context, Container, Component, Code (4 levels) https://c4model.com/. Tools: **Structurizr** (DSL + CLI, open-source DSL https://github.com/structurizr/dsl, paid cloud; `go-structurizr`, `structurizr-mcp` https://github.com/cubical6/structurizr-mcp MCP server for Structurizr DSL → PlantUML/Mermaid), **C4-PlantUML** https://github.com/plantuml-stdlib/C4-PlantUML (PlantUML macros for C4), **overarch** https://github.com/soulspace-org/overarch (data model + PlantUML/Structurizr generation).
- **Evaluation:** C4 is **guidance on what to draw**, not which tool renders it. Rendering via **Mermaid** already covers Context/Container/Component with `C4-inspired via Mermaid` (flowchart + subgraph) at lower fidelity but sufficient for most Toolkit uses (architecture pack). PlantUML adds higher fidelity but requires `plantuml` or `Kroki` infra; Structurizr adds DSL consistency checks + multi-view but is heavier (DSL + CLI) and paid cloud.
- **Decision:** **ADOPT** as **architecture guidance overlay**, not separate heavy skill. Keep `mermaid` as renderer; add `c4-model` as methodology skill that teaches *when* to draw each C4 level and *how* to render C4-inspired diagrams **via Mermaid** (with PlantUML/Structurizr as optional advanced notes, not required). This satisfies §44 "may not need separate `mermaid` and `c4` skills if single architecture-diagram workflow can render C4-inspired via Mermaid" while still preserving C4 as distinct knowledge (useful for `architect + ADR + threat-model + Mermaid (+ C4)` pack composition).

### Excalidraw / draw.io / PlantUML standalone
- **Excalidraw:** `excalidraw/excalidraw` MIT — hand-drawn fidelity, binary canvas, not Markdown-native; workflow benefit not proven vs Mermaid for code-adjacent diagrams; **REJECT** for now (threat-model may prefer sequence via Mermaid).
- **draw.io / diagrams.net:** binary, drag-drop, not text-native; **REJECT** (out-of-scope per issue).
- **PlantUML standalone:** PlantUML `plantuml/plantuml` GPL + C4-PlantUML macros — powerful for C4 but requires Java/Graphviz or Kroki; **REJECT** as separate skill (keep as optional note inside `c4-model` for teams that need higher fidelity).

### Summary matrix

| Candidate | Verdict | Renderer | Why |
|-----------|---------|----------|-----|
| **Mermaid** | **ADOPT** (tooling/mermaid) | Mermaid `mermaid-js/mermaid` MIT + `@mermaid-js/mermaid` NPM | Primary, Markdown-native, Git-native, MIT, smallest cost; already used in `docs/ARCHITECTURE.md` |
| **C4 model** | **ADOPT** (architecture/c4-model) | Methodology → render **via Mermaid** (C4-inspired flowchart), PlantUML/Structurizr optional | Methodology not renderer; avoids separate heavy tool; satisfies `architect + ADR + threat-model + Mermaid (+ C4)` |
| Excalidraw | **REJECT** | Canvas | Not text-native, benefit not proven |
| draw.io | **REJECT** | Binary | Out-of-scope |
| PlantUML standalone | **REJECT** | PlantUML | Keep as optional inside `c4-model`, not separate skill |

**Risks/tradeoffs:** Mermaid C4-inspired is lower fidelity than Structurizr DSL (no consistency checks across views) — mitigate via DSL link for advanced teams; Pack `architecture` stays `architect + ADR + TRD + threat-model + mermaid (+ C4)` vendor-neutral core (matches #384 cloud optional decision).

**Next:** Add `skills/tooling/mermaid/` (primary) + `skills/architecture/c4-model/` (methodology overlay via Mermaid).
