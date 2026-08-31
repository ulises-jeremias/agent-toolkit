# UI UX Pro Max — Decision Record (per #392)

**Status:** REJECT vendoring, **OPTIONAL EXTERNAL** only

**Date:** 2026-08-10
**Reviewed by:** principal architect (mission)
**Related:** #358 `refactor: remove ui-ux-pro-max skill and document third-party boundary` (commit 09acb6d)

## Summary

`nextlevelbuilder/ui-ux-pro-max-skill` is **not vendored** into Agent Toolkit. It remains available as an **optional external capability** installed separately by the user, not bundled in `distributions/products.yaml` stable products.

## Upstream facts (2026-08-10)

- **Repository:** [`nextlevelbuilder/ui-ux-pro-max-skill`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
- **License:** MIT per GitHub API (`license.spdx_id: MIT`, `LICENSE` at repo root) — applies to repo root; check subdirs before redistribution.
- **Stars:** 115k+ (`size: 7544`)
- **Updated:** 2026-08-06 (active)
- **Contents:** `.claude-plugin/`, `.claude/`, `cli/`, `docs/`, `gallery/`, `src/`, `stack/`, `skill.json` — mixed CLI, datasets, documentation, generated assets (exact licensing per subdir may differ; repo LICENSE is MIT but datasets/gallery may have separate terms).
- **Size:** Large — CLI + datasets + gallery + templates (estimated >10k tokens when vendored, high context cost).
- **Network/runtime:** CLI `cli/` indicates runtime dependencies and possible network behavior (check `cli/package.json` for `curl`/dataset downloads).
- **Supported agents:** Claude-centric (`.claude-plugin/`, `CLAUDE.md`); portability to Cursor/Copilot/OpenCode not verified as native.
- **Prior Toolkit integration:** Removed in 09acb6d — boundary documented as third-party boundary.

## Decision: REJECT vendoring

**Reasons:**

1. **License ambiguity per subdir:** Root LICENSE is MIT, but `gallery/`, `src/`, `stack/`, `cli/` may contain generated datasets/assets with unclear redistribution terms. Auditing every subdir for SPDX before vendoring is costly; mis-licensing risk for MIT Toolkit.
2. **Size / context cost:** Very large — bundling would inflate every Toolkit install and `context_budget` (pack `design-engineering` would grow from ~5 skills to >15 with heavy prompts).
3. **Overlap:** `anthropics/skills` `frontend-design` (167k stars, Apache-2.0, 8.5k SKILL.md) + `microsoft/skills` `frontend-design-review` + Vercel `web-design-guidelines` already cover distinctive generation + procedural critique + quality rules. UI UX Pro Max adds design-intelligence datasets, not differentiated workflow orchestration (which Toolkit provides via `design-assessment`/`design-improvement`).
4. **Network/dataset generation:** CLI that downloads datasets/generates assets — supply-chain surface (`security: {network: true, scripts: true}`) requiring stricter audit than pure prompt skills.
5. **Native vs wrapper:** Community large pack is less portable than upstream-first Anthropic/Microsoft/Vercel skills with clear provenance.

## Distribution: OPTIONAL EXTERNAL

Users who want it can install externally — **do NOT add to `agent-toolkit-core` or stable products**:

```bash
# External install (standalone, outside Toolkit)
git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill ~/.agents/skills/ui-ux-pro-max
# or via workstation opt-in (if chezmoi flag added in future)
# install_skill_ui_ux_pro_max=true chezmoi apply
```

Toolkit may reference it as **design-intelligence pack** dependency:

```yaml
# hypothetical packs/design-engineering.yaml (docs-only today)
recommendedExternal:
  - name: ui-ux-pro-max-skill
    repository: nextlevelbuilder/ui-ux-pro-max-skill
    install: external
    note: Optional — provides dataset-backed design intelligence; Toolkit orchestration still via design-assessment
```

## Update strategy

- **No Renovate/Dependabot** from Toolkit — user tracks upstream manually (`gh api repos/nextlevelbuilder/ui-ux-pro-max-skill/commits`).
- If Toolkit ever reconsiders, require: per-subdir LICENSE audit + SPDX, size measurement + `context_budget` impact, security audit (scripts/network/MCP), portability test across Cursor/Copilot/OpenCode.

## Alternatives considered

- **PIN EXTERNALLY** (external pinned dep): Rejected — even external pin adds context cost and toolchain complexity for marginal value over curated `frontend-design` + `frontend-design-review`.
- **VENDORED**: Rejected per above.

## References

- Removal PR: 09acb6d `fix: repair 3 broken skill links + remove ui-ux-pro-max ... (#358)`
- Third-party boundary: `CONTRIBUTING.md` + `docs/TRUST.md` provenance section (per #364)
- Upstream: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
