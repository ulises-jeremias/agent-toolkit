# Upstream vs First-Party Governance

This document defines how agent-toolkit decides whether to **vendor** a third-party skill
(upstream), **enhance** an existing first-party skill, or **create** a new first-party skill.
It complements [TRUST.md](TRUST.md) (provenance mechanics) and
[SKILL_INTEGRATION_CHECKLIST.md](SKILL_INTEGRATION_CHECKLIST.md) (mandatory wiring per PR).

---

## Decision matrix

| Situation | Action | Example |
|-----------|--------|---------|
| Unique, portable skill with no first-party overlap | **Vendor literal** (`origin.type: upstream`) | `quality/unslop`, `quality/deslop`, `tooling/cli-for-agents`, `quality/blast-radius` |
| Overlap with existing first-party skill in same domain | **Enhance first-party**; do not vendor duplicate | cursor `fix-ci` → enhance `forge/gh-fix-ci` |
| Gap with no suitable upstream to vendor literally | **New first-party** skill | `forge/fix-merge-conflicts`, `quality/deep-review` |
| SaaS MCP bundles, hook-only plugins, bulk principle packs | **Reject** for this repo | cursor `third_party/*` MCP plugins, `ralph-loop` hooks |
| Rejected vendor but useful ideas | **Absorb via `metadata.inspired_by`** on first-party skill | continual-learning → `core/workspace-knowledge-sync` |

**Default:** when in doubt, prefer **first-party** and record upstream inspiration rather than
maintaining two skills that solve the same problem.

---

## Conflict resolution

When a third-party skill overlaps an existing agent-toolkit capability:

1. **First-party wins** — keep one canonical skill ID in `skills/<domain>/<name>/`.
2. **Absorb the best ideas** — add `metadata.inspired_by[]` with `{repository, path, ref, note}`.
3. **Do not vendor** the duplicate unless retiring the first-party skill (Path C below).
4. **One PR per concern** — enhancement PRs are separate from literal vendor PRs.

### Path C — Retire upstream in favor of first-party

Rare. Requires:

- ADR or decision log entry in this file's [Decisions log](#decisions-log)
- Remove vendored skill, lock entry, and product membership
- Migrate agent routing and docs to the first-party replacement
- CHANGELOG breaking-change note

---

## Product placement rules

| Rule | Rationale |
|------|-----------|
| Skills marked upstream **"Must always apply"** do **not** ship in `agent-toolkit-core` | Avoids forcing global rules on minimal installs |
| Craft / quality anti-slop skills ship in **`agent-toolkit-complete`** until **`agent-toolkit-craft`** product exists | Complete bundle first; dedicated product when stable |
| Forge skills ship in **`agent-toolkit-forge`** + complete | Matches forge domain curation |
| Upstream skills require human **`trust.reviewed_provenance`** binding before merge | ADR-0001 review lifecycle |

---

## cursor/plugins adoption (Epic #743)

Reference upstream: [cursor/plugins](https://github.com/cursor/plugins) @
`60c641e4fad674784b30abcf9f8915dea39df38d`.

| cursor/plugins skill | Decision | agent-toolkit target |
|----------------------|----------|----------------------|
| `pstack/skills/unslop` | Vendor | `quality/unslop` |
| `cursor-team-kit/skills/deslop` | Vendor | `quality/deslop` |
| `cli-for-agent/skills/cli-for-agents` | Vendor | `tooling/cli-for-agents` |
| `pstack/skills/blast-radius` | Vendor | `quality/blast-radius` |
| `fix-ci` | Enhance first-party | `forge/gh-fix-ci` (`inspired_by`) |
| `fix-merge-conflicts` | New first-party | `forge/fix-merge-conflicts` |
| `continual-learning` | Enhance first-party | `core/workspace-knowledge-sync` |
| `deep-review` / thermos rubrics | New first-party or agent extension | `quality/deep-review` or `agents/code-reviewer` |
| Whole pstack, principle-*, orchestrate, SaaS MCP | Reject | — |

---

## Decisions log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-19 | Wave 0 governance docs + ORCHESTRATION.md | Epic #743; fix missing orchestration reference |
| 2026-08-19 | Vendor unslop/deslop/cli-for-agents/blast-radius literally | Complementary, no first-party overlap |
| 2026-08-19 | Do not vendor cursor fix-ci; enhance gh-fix-ci | Single forge CI skill |
| 2026-08-19 | unslop excluded from agent-toolkit-core | Upstream "Must always apply" semantics |
| 2026-08-26 | Refresh pass #871: vercel web-interface-guidelines 4e799d4→e3d624b; 10 vendored skills retained | Only rules source had instructive delta (a11y/media/motion/gesture + curly-quote fix); all others byte-identical at pinned SHA (verified via raw fetch + body SHA) — anthropics/microsoft/cursor wrapper/megalinter no copy; lock/UPSTREAM regenerated |

---

## Related docs

- [SKILL_INTEGRATION_CHECKLIST.md](SKILL_INTEGRATION_CHECKLIST.md) — mandatory per skill PR
- [HOW_TO_ADD_SKILL.md](HOW_TO_ADD_SKILL.md) — upstream vendoring procedure
- [TRUST.md](TRUST.md) — provenance lock and review binding
- [UPSTREAM.md](UPSTREAM.md) — generated upstream attribution table
