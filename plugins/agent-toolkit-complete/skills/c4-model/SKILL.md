---
name: c4-model
description: WHAT — C4 model methodology (Context, Container, Component, Code) guidance — what to draw at each level, when, and how to render C4-inspired diagrams via Mermaid (PlantUML/Structurizr optional advanced). Methodology not renderer.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - c4
  - architecture
  - structurzr
  - plantuml
  - mermaid
---

# C4 Model — Methodology Overlay (WHAT → HOW via Mermaid)

**Sources (2026-08-12):** Simon Brown C4 https://c4model.com/ (Context, Container, Component, Code); Structurizr DSL https://github.com/structurizr/dsl (open-source DSL, paid cloud) + `structurizr-mcp` https://github.com/cubical6/structurizr-mcp + `go-structurizr`; C4-PlantUML https://github.com/plantuml-stdlib/C4-PlantUML; overarch https://github.com/soulspace-org/overarch (PlantUML/Structurizr generation); rendering **via Mermaid** `mermaid-js/mermaid` MIT per §44.

> **Pack:** `architecture` core (`architect + ADR + TRD + threat-model + mermaid (+ C4 via mermaid)`) — `c4-model` teaches *what* to draw; `mermaid` renders it. See `docs/architecture/research-385-diagram.md` for C4 vs Mermaid vs PlantUML/Structurizr decision (Excalidraw/draw.io REJECT).

## When to use

- Need system Context / Container / Component / Code views.

## Instructions

1. **Select level:** Context (system + actors) → Container (apps/data stores) → Component (modules) → Code (classes, optional).
2. **Render via Mermaid** (C4-inspired): `flowchart TD` with `subgraph` for boundaries, e.g.:
   ```mermaid
   flowchart TD
     user([User]) --> web[Web Container]
     web --> api[API Container]
     api --> db[(Database Container)]
     subgraph System Context
       user; web; api; db
     end
   ```
3. **Advanced (optional):** For consistency checks across views, use Structurizr DSL (`structurizr-cli` + `workspace.dsl` → PlantUML/Mermaid) or C4-PlantUML (`@startuml` + `!include C4_Context.puml`); note `structurizr` CLI requires DSL file and is heavier.

## Collaboration

- `architect` defines system → `c4-model` selects C4 level → `mermaid` renders → `ADR` records decision.

## Anti-patterns

- Do not mandate Structurizr DSL for every diagram — Mermaid suffices for most.
- Do not dump PlantUML infra as separate skill — keep as optional note.
