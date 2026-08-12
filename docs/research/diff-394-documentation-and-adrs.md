# Diff: addyosmani/agent-skills `documentation-and-adrs` vs Toolkit `adr` + `docs-generator` — #394 (2026-08-12)

**Scope:** `https://github.com/addyosmani/agent-skills` MIT `skills/documentation-and-adrs/SKILL.md` (288 lines) vs `skills/delivery/adr/SKILL.md` (48 lines) + `skills/ops/docs-generator/SKILL.md` (85 lines) + `docs/adr/` (3 ADRs) + `docs-generator` loops.

**Method:** `find-skills` discovery + manual `git clone --depth 1` (2026-08-12), compared headings, workflows, templates, lifecycle, verification.

## Overlaps (high)

| Area | Upstream | Toolkit | Verdict |
|------|----------|---------|---------|
| ADR purpose — records *why* not *what*, highest-value docs | ✅ full Section "ADRs capture reasoning" + 5 whens + cost-to-reverse | ✅ "WHAT — Create and maintain ADRs" + 3 when-to-use + long-term impact + options pros/cons | **Overlap 80%** — same intent |
| ADR template — Status/Date/Context/Decision/Alternatives/Consequences | ✅ `docs/decisions/` + template with `PostgreSQL vs MongoDB/SQLite/MySQL` example + lifecycle `PROPOSED→ACCEPTED→(SUPERSEDED/DEPRECATED)` + "Don't delete old ADRs" | ✅ `references/default-template.md` + 6-part Title & status, Context, Options, Decision, Consequences, References + `output-handshake` gate | **Overlap** — Toolkit template more structured (6-part + PRD/TRD linking), upstream more lifecycle + example |
| README/Changelog/API | ✅ README Structure (Quick Start, Commands, Architecture, Contributing), Changelog Maintenance, OpenAPI `spec-driven` | ✅ `docs-generator` README from `package.json`/`pyproject`, CHANGELOG from `git log --oneline`, OpenAPI/GraphQL → tables, AGENTS.md starter | **Overlap** — both generate README/CHANGELOG/API from code |
| Inline gotchas — why not what | ✅ "Comment the *why*, not the *what*" + `initializeTheme` must-before-render + red flags | ❌ not in `adr`/`docs-generator` | **Gap** |
| Rules for agents — CLAUDE.md / spec files | ✅ "Documentation for Agents" — CLAUDE.md/rules, spec files, ADRs help agents, inline gotchas prevent traps | ✅ `AGENTS.md` inspection order in `docs/ARCHITECTURE.md` but not in `adr`/`docs-generator` workflows | **Gap** |

## Gaps (upstream provides, Toolkit missing or thin)

* **G1 — Matching existing convention first:** Upstream "Match the existing convention first — inspect existing ADRs, `.adr-dir`, location/format (`docs/adr/*.md` vs `Documentation/Decisions/*.rst` vs MADR vs `adr-tools`), numbering/naming, section headings; surface conflict rather than silently introducing another scheme; only default when no convention can be established." Toolkit `adr` assumes `docs/adr/` + `0001-*.md` + 6-part without inspecting existing convention — **extend**.
* **G2 — ADR lifecycle + don't-delete:** Upstream explicit `PROPOSED→ACCEPTED→(SUPERSEDED/DEPRECATED)` + "Don't delete old ADRs — historical context; write new ADR that supersedes old". Toolkit mentions supersession but not lifecycle — **extend**.
* **G3 — Inline documentation policy:** Upstream detailed Bad/Good comment examples + "When NOT to comment" + "Document Known Gotchas" + "No commented-out code / TODO weeks". Toolkit has no inline docs guidance — `docs-generator` covers README/CHANGELOG/API only — **extend docs-generator** (add Inline section, keep code generation separate).
* **G4 — Verification + Red Flags:** Upstream checklists "ADRs exist for all significant decisions, README covers quick start, API docs have types, gotchas inline, no commented-out code, rules files current, no restating code" + "Rationalizations vs Reality" table + six red flags. Toolkit has `workflow-generic-project` gates but not in `adr`/`docs-generator` verification — **extend**.
* **G5 — Persona vs skill distinction:** Upstream `agent-skills` README distinguishes `agent/persona = HOW agent thinks` (long-lived reasoning style) vs `skill/workflow = HOW task executes` (discrete procedure with inputs/outputs). Toolkit already preserves this in `docs/CONCEPTS.md` and `personas/architect.md` vs `skills/delivery/adr/` — **preserve, document**.
* **G6 — API spec-driven details:** Upstream has concise OpenAPI example with `spec.yaml` → endpoint table; Toolkit `docs-generator` already similar — **no change** (overlap).

## Decision

**REJECT vendoring `documentation-and-adrs` as new skill** — 80% overlap with `adr` + `docs-generator`; vendoring would duplicate.

**ADOPT absorb practices into existing skills** (small extensions, no new skill):

* **Extend `skills/delivery/adr/SKILL.md`** with:
  - Step 0: "Match existing convention first" (inspect `docs/adr/`, ADR dir/file extension/markup, numbering, headings; surface conflict; default to `docs/adr/0004-*.md` 6-part only when no convention).
  - ADR Template note: lifecycle `PROPOSED→ACCEPTED→SUPERSEDED/DEPRECATED` + "Don't delete — supersede with reference".
  - Red flags + verification checklist (6 items from upstream, link to `workflow-generic-project` gate).

* **Extend `skills/ops/docs-generator/SKILL.md`** with:
  - Inline Documentation section (why-not-what, Good/Bad examples, Known Gotchas, no commented-out/TODO-weeks) — preserve that docs-generator is docs-from-code, not docs-from-thin-air; agent not to invent.
  - Verification checklist (README/CHANGELOG/API/AGENTS/gotchas).

* **Preserve distinction:** `personas/*` (HOW agent thinks, e.g., `architect`, `reviewer`) vs `skills/*` (HOW task executes, discrete workflow) — already in `docs/CONCEPTS.md` — do not merge; `adr` stays workflow, `architect` stays persona that delegates to `adr`.

This closes #394 without duplication and keeps `personas/` vs `skills/` boundary intact (vs upstream's `agent/persona` vs `skill/workflow`).

## Verification

* Extended `adr` covers G1/G2/G5, `docs-generator` covers G3/G4 — no commented-out duplication.
* `uv run python scripts/validate-skills.py` → `77 → 77` (no new skill), `uv run ruff check` clean.
* Docs: this file is diff report (issue comments) + extensions.

## References

* Upstream `addyosmani/agent-skills` MIT — `skills/documentation-and-adrs/SKILL.md` 288 lines (2026-08-12), `skills/security-and-hardening/SKILL.md`, `skills/code-review-and-quality/SKILL.md` for contrast.
* Toolkit `skills/delivery/adr/SKILL.md` 48 lines + `references/default-template.md` + `docs/adr/0001-0004` (ADR-0001/0003/0004) + `skills/ops/docs-generator/SKILL.md` 85 lines.

