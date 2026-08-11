# Figma Agent Ecosystem Audit — 2026-08-12

**Issue:** #376  **Related:** #375 (browser), #395 (context-cost), packs, ADR-0003

## Scope

Audit Figma capabilities available to Toolkit:

- Core: `figma`, `figma-code-connect-components`, `figma-create-design-system-rules`, `figma-create-new-file`, `figma-implement-design` (5 skills, Figma MCP via `mcp/registry/figma.yaml`)
- Candidates: `figma-use` (Plugin API 100+ commands), `figma-generate-design`, `figma-generate-library` (Figma guide), `figma/mcp-server-guide`

## Methodology

- Official repos: `figma/mcp-server-guide`, `dannote/figma-use` (MIT, 590★, 2026-08-09), Figma MCP `https://mcp.figma.com/mcp`
- Checked Figma skills current payload: `skills/design/figma*/SKILL.md` (each 1–3k tokens, first-party, no upstream vendor)
- Measured context cost: core skills load only entry `figma` (routing) → on-demand refs
- Evaluated provenance per ADR-0001: official MCP (Figma) vs vendored prompt

## Findings

| Capability | Source | Type | License | Size / Context Cost | Network / Auth | Maintenance | Decision |
|------------|--------|------|---------|---------------------|----------------|-------------|----------|
| **Figma MCP** (`get_design_context`, `get_screenshot`, `get_file_structure`, `get_metadata`) | `https://mcp.figma.com/mcp` (Figma official) + `mcp/registry/figma.yaml` | Remote MCP `streamable_http` | proprietary (Figma Terms) | Low — skill routing only, tool payload on demand | HTTPS `mcp.figma.com` + `api.figma.com`, `FIGMA_OAUTH_TOKEN` + `FIGMA_REGION` bearer-env | Official, active (2026-08-11 guide) | **ADOPT** — already vendored as 5 core skills + registry, keep default |
| `figma` / `figma-implement-design` / `figma-code-connect` / `figma-create-design-system-rules` / `figma-create-new-file` | Toolkit first-party (Figma MCP guide distilled) | Skill (first-party) | Toolkit MIT (`LICENSE.txt` in each skill) | Low–medium per skill (~1.5k tokens each, on-demand) | via Figma MCP only | Toolkit-maintained, guide-distilled | **ADOPT** — keep in `agent-toolkit-complete` (5 skills, validated) |
| `figma-use` — Control Figma via Plugin API (create shapes/text/components, set styles, export) | `dannote/figma-use` https://github.com/dannote/figma-use | CLI `npx figma-use` (100+ commands) | MIT | **High** — 989 KB repo, 15k README, 100+ commands, full read/write canvas | Local Figma Plugin API (requires Figma Desktop + plugin) | 590★, active 2026-08-09 | **REJECT as default, KEEP as opt-in pack** — already documented as `install the opt-in figma-use pack` in each figma skill. Reason: context tax + write scope (can delete nodes via Plugin API) not needed for typical design-to-code; keep opt-in for canvas authoring |
| `figma-generate-design` — Generate full screen in Figma from code/description | Referenced in `figma/SKILL.md` as opt-in | Pack (not vendored skill) | Toolkit pack docs (no upstream license) | High — would bundle design generation (large prompt) | via Figma MCP | Toolkit docs | **REJECT as default, KEEP opt-in** — already routed as `see opt-in pack` in figma skill routing table |
| `figma-generate-library` — Generate/import full library | Referenced similarly | Pack | Toolkit pack docs | High — large library generation | via Figma MCP | Toolkit docs | **REJECT as default, KEEP opt-in** |
| `figma/mcp-server-guide` | `figma/mcp-server-guide` | Guide docs | null (no LICENSE) | Low — guide only | — | 2026-08-11 | **REFERENCE** — guide, not vendored |

## Context / token cost

- Core 5 skills: entry `figma` loads routing table (6 rows) → delegates to one specialized skill on demand. Average context per task: ~2k tokens (one skill) + on-demand `references/figma-mcp-config.md` (~1k). `figma-use` alone would add ~10k+ tokens if inlined + 100 commands → violates #395.
- Decision aligns with #395: routing + on-demand + subagents keep design engineering context low. No change to `agent-toolkit-core` (figma stays in `complete` only, not core).

## Prerequisites verification

- `mcp/registry/figma.yaml`: provenance `official`, package `https://mcp.figma.com/mcp`, `FIGMA_OAUTH_TOKEN` + `FIGMA_REGION`, platforms native/bridged — **correct** (verified via `cat mcp/registry/figma.yaml`).
- `mcp/templates/figma/config.template.json`: URL `https://mcp.figma.com/mcp` with `Authorization: Bearer ${FIGMA_OAUTH_TOKEN}` + `X-Figma-Region` — **correct**.
- `skills/design/figma*/SKILL.md`: all 5 skills declare `origin: first-party`, entry `figma` documents Figma MCP flow (`get_design_context` → `get_metadata` → `get_screenshot`) and routes to specialized skills. Code Connect mentions `get_code_connect_suggestions` + `send_code_connect_mappings`. `figma-implement-design` notes design-to-code (code in repo, not canvas). All correctly note `For canvas writes (Plugin API), install the opt-in figma-use pack`.
- **No missing `requires: [figma-mcp]` needed** — frontmatter `origin` + `references` + MCP registry is the Toolkit pattern; skill bodies already gate on `FIGMA_TOKEN` env and MCP availability. Adding `requires` would duplicate registry purpose (ADR-0001: registry owns provider availability).
- Distribution: `origin: first-party` → not in `capabilities/upstream.lock` (sparse, correct) — verified `provenance check OK — 3 capabilities`.

## Figma advanced — optional vs rejected

- **figma-advanced pack decision:** Keep `figma-use` / `figma-generate-*` as **opt-in packs** (not rejected entirely, not default). They remain documented in `skills/design/figma/SKILL.md` routing table as `opt-in pack — see docs/SKILLS.md`. Rationale: advanced candidates are valid for canvas authoring / full library generation but have high context cost and write scope; default `design-assessment`/`design-improvement` workflows only need read context via Figma MCP (`get_design_context` etc.), not canvas writes.
- No new `figma-advanced` product needed — `agent-toolkit-complete` already includes 5 core figma skills; advanced packs are installed via workspace pack mechanism per ADR-0003 (packs docs-only, products own installation).

## Design-system relationship verification

Desired:

```
EXISTING APPLICATION ↔ DESIGN SYSTEM ↔ FIGMA
```

Supported today:

- **Inspect tokens:** `get_design_context` returns variables, styles, components — verified in `figma` skill `references/figma-mcp-config.md`.
- **Compare implementation vs design:** `design-assessment` Figma compare phase + `design-improvement` Figma Dev Mode compare — delegates to `figma` + `chrome-devtools` for divergence detection.
- **Use Figma as design evidence:** evidence map includes `design files` source via `project-assessment-evidence` → `design-assessment` consumes it.
- **Preserve existing system:** `design-improvement` discovers tokens via Figma + Storybook + Tailwind before inventing aesthetics — already enforced.

Not promised: `figma-use` canvas writes without opt-in; `figma-generate-library` full import without pack — correctly gated as opt-in.

## Security

- Figma tokens via `${FIGMA_OAUTH_TOKEN}` env only (registry + template) — no secrets in skill body (verified).
- `figma-use` Plugin API 100+ commands can delete/modify Figma files — kept opt-in to avoid default write exposure.

## Tests

- `validate-skills` 68 OK (5 figma skills)
- `validate-upstream` 68 checked, `provenance check` 3 caps OK (figma first-party, no lock drift)
- `agent-toolkit doctor | grep figma` — checks `FIGMA_OAUTH_TOKEN` presence (manual)
- `generate-catalogs/matrix` 68 skills, `agent-toolkit-complete` includes 5 figma skills (verified)

## Update for issue

- [x] Audit report in issue comments (this file `docs/research/figma-audit-2026-08-12.md` — payload size, license, decision ADOPT/REJECT per skill)
- [x] `figma` prerequisites correct in frontmatter + MCP registry (verified, no change needed)
- [x] `figma-advanced` decision documented (optional opt-in, not rejected nor default)
- [x] Tests validate

**Recommendation:** Close #376 as **completed** — no new vendored skills; keep 5 core figma skills default, keep figma-use/generate-* opt-in per existing routing. Refresh audit quarterly via `provenance updates` cadence (staleness warn >90d).
