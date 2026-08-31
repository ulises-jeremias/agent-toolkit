---
name: mermaid
description: WHAT — Mermaid diagrams from text (flowchart, sequence, class, state, ER, gantt, gitGraph) — Markdown-native, Git-native, MIT. Primary renderer for architecture pack; renders via GitHub native or mermaid CLI (mmdc) to SVG/PNG.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - diagram
  - mermaid
  - architecture
  - markdown
---

# Mermaid — Primary Diagram Renderer (WHAT)

**Sources (2026-08-12):** `mermaid-js/mermaid` https://github.com/mermaid-js/mermaid MIT (Mermaid live editor https://mermaid.live); NPM `mermaid 10.x` `MIT` + `@mermaid-js/mermaid 10.9.7-preview.41` `MIT`; `docs/ARCHITECTURE.md` already authors Mermaid natively.

> **Pack:** `architecture` core (`architect + ADR + TRD + threat-model + mermaid (+ C4)`) — vendor-neutral. `cloud-architecture` optional composes `cloud-design-patterns + aws-well-architected-review + mermaid`. See `docs/architecture/research-385-diagram.md` for Mermaid vs C4 vs PlantUML/Structurizr/Excalidraw decision per §44.

## When to use

- Need flowchart, sequence, class, ER, gantt, gitGraph — text → SVG/PNG.
- Threat-model data-flow / sequence diagrams.

## Instructions

1. **Author** Mermaid block in Markdown: ` ```mermaid` + `flowchart TD` / `sequenceDiagram` / `classDiagram` etc.
2. **Render** via GitHub native or `mmdc -i diagram.mmd -o diagram.svg` (mermaid CLI).
3. **Collaborate** with `architect` + `threat-model` (data-flow) and `c4-model` (C4-inspired via Mermaid).

## Anti-patterns

- Do not add Excalidraw/draw.io binary — use Mermaid text.
- Do not require PlantUML infra for basic diagrams.
