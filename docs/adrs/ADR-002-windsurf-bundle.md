# ADR-002: Windsurf Distribution as "Customization Bundle"

**Status:** Accepted  
**Date:** 2026-08-04

## Context

Official Windsurf/Devin Desktop documentation states:

> "You cannot install extensions through any marketplace on Devin Desktop."

The platform does not support a third-party plugin/extension marketplace.

## Decision

The Windsurf distribution is labeled a **"Windsurf Customization Bundle"**, not a plugin.

It contains:
- `.mdc` rule files (behavioral constraints)
- MCP server configuration (manual setup, not automated)
- Global rules / memories (optional, not distributed by default)

The `agent-toolkit install --target windsurf` command copies rules to `.windsurf/rules/`
or `~/.codeium/windsurf/rules/` (project scope by default).

## Rationale

Using the word "plugin" for files copied into a directory would falsely advertise
a platform integration that does not exist. Accurate labeling respects users.

## Consequences

- **Positive:** No false parity claims; users understand what they're getting
- **Negative:** Windsurf users get fewer automated features than Claude Code/Cursor users
- **Migration:** If Windsurf introduces a marketplace, this ADR should be revisited
