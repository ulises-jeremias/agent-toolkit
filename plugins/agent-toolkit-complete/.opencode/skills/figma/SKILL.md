---
name: figma
description: Use the Figma MCP server to fetch design context, screenshots, variables, and assets, and
  to translate Figma nodes into production code. Trigger when a task involves Figma URLs, node IDs, design-to-code
  implementation, or Figma MCP setup and troubleshooting.
origin:
  type: first-party
---
# Figma MCP

Use the Figma MCP server for Figma-driven implementation. For setup and
debugging details (env vars, tool registration, verification), see
[`references/figma-mcp-config.md`](references/figma-mcp-config.md).

This is the **entry-point skill** for the Figma family. Switch to a more
specialized skill once intent is clear:

| If the user wants to… | Use |
|---|---|
| Translate a Figma node into production code | [`figma-implement-design`](../figma-implement-design/SKILL.md) |
| Generate a full screen in Figma from code/description | `figma-generate-design` (opt-in pack — see `docs/SKILLS.md`) |
| Author Code Connect mappings | [`figma-code-connect-components`](../figma-code-connect-components/SKILL.md) |
| Create reusable agent rules (`CLAUDE.md`/`AGENTS.md`) for a design system | [`figma-create-design-system-rules`](../figma-create-design-system-rules/SKILL.md) |
| Create a brand-new Figma file | [`figma-create-new-file`](../figma-create-new-file/SKILL.md) |
| Run JS in Figma via the Plugin API | `figma-use` (opt-in pack — see `docs/SKILLS.md`) |
| Generate/import a full library | `figma-generate-library` (opt-in pack — see `docs/SKILLS.md`) |

## Figma MCP Integration Rules

These rules define how to translate Figma inputs into code for this project and
must be followed for every Figma-driven change.

### Required flow (do not skip)

1. Run `get_design_context` first to fetch the structured representation for
   the exact node(s).
2. If the response is too large or truncated, run `get_metadata` to get the
   high-level node map and then re-fetch only the required node(s) with
   `get_design_context`.
3. Run `get_screenshot` for a visual reference of the node variant being
   implemented.
4. Only after you have both `get_design_context` and `get_screenshot`, download
   any assets needed and start implementation.
5. Translate the output (usually React + Tailwind) into this project's
   conventions, styles and framework. Reuse the project's color tokens,
   components, and typography wherever possible.
6. Validate against Figma for 1:1 look and behavior before marking complete.

### Implementation rules

- Treat the Figma MCP output (React + Tailwind) as a representation of design
  and behavior, not as final code style.
- Replace Tailwind utility classes with the project's preferred utilities /
  design-system tokens when applicable.
- Reuse existing components (e.g. buttons, inputs, typography, icon wrappers)
  instead of duplicating functionality.
- Use the project's color system, typography scale, and spacing tokens
  consistently.
- Respect existing routing, state management, and data-fetch patterns already
  adopted in the repo.
- Strive for 1:1 visual parity with the Figma design. When conflicts arise,
  prefer design-system tokens and adjust spacing or sizes minimally to match
  visuals.
- Validate the final UI against the Figma screenshot for both look and
  behavior.

### Asset handling

- The Figma MCP server provides an assets endpoint that serves image and SVG
  assets.
- **Important**: if the Figma MCP server returns a `localhost` source for an
  image or SVG, use that source directly.
- **Important**: do NOT import/add new icon packages — all assets should be in
  the Figma payload.
- **Important**: do NOT use or create placeholders if a `localhost` source is
  provided.

### Link-based prompting

- The remote Figma MCP server is link-based: copy the Figma frame/layer link
  and provide that URL to the AI tool when asking for implementation help.
- The AI tool cannot browse the URL but extracts the node ID from the link.
  Always ensure the link points to the exact node/variant you want.

## Boundaries

- This skill **reads** Figma context and **writes code in the user's repo**.
  It does not write back into Figma — that lives in the opt-in `figma-use` /
  `figma-generate-design` pack (see `docs/SKILLS.md`).
- Do not bypass the MCP and call the Figma REST API directly from this skill.

## References

- [`references/figma-mcp-config.md`](references/figma-mcp-config.md) — register
  the Figma MCP in Claude Code / Cursor / OpenCode / Windsurf. Points at the
  agent-toolkit template under `~/.local/share/agent-toolkit/mcp/figma/`.
- [`references/figma-tools-and-prompts.md`](references/figma-tools-and-prompts.md)
  — tool catalog and prompt patterns.
