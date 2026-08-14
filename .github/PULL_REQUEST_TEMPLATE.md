## Summary

<!-- One to three bullet points describing what this PR does and why. -->

-
-

## Type

- [ ] New skill
- [ ] New loop template
- [ ] New agent persona
- [ ] New profile (per-tool config)
- [ ] New pack
- [ ] Catalog update (skill-catalog, agent-catalog, loop-catalog)
- [ ] Schema update
- [ ] Documentation
- [ ] Bug fix
- [ ] Other

## Changes

<!-- List the files or components changed and what was modified in each. -->

-
-

## Testing

<!-- Describe how you verified the changes work correctly. -->

**Primary (match CI):**
- [ ] `v run scripts/validate-skills.vsh` (if skill changes)
- [ ] `v run scripts/validate-agents.vsh` (if agent changes)
- [ ] Loop schemas via `python3` + `schemas/loop.schema.json` (if loop changes) — see `validate-loops` in `.github/workflows/validate.yml`
- [ ] `v run scripts/generate-catalogs.vsh` (if skill/agent/loop added; never hand-edit `*-catalog.yaml`)
- [ ] `./make.vsh test && ./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check`

**Adapter-only (optional unless changing PyPI/npm trampolines):**
- [ ] `uv run … pytest` / `npm test --prefix packages/npm/agent-toolkit-cli`

**Manual (optional):**
- [ ] Tested with at least one supported AI tool (Claude Code, Cursor, Copilot, etc.)

## Checklist

- [ ] `SKILL.md` frontmatter present (`name`, `description`) — no `skill.json` (removed in v1.0.4)
- [ ] Loop `loops/<name>/loop.yaml` includes required fields: `name`, `goal`, `request`
- [ ] Loop `tier` set (`L1`/`L2`/`L3`) with `budget` (`max_tokens`, `max_runs_per_day`, `max_wall_seconds`) and `exit_conditions`
- [ ] Loop `allowlist`/`deny` scoped correctly for tier
- [ ] Loop `loop.yaml` validates against `schemas/loop.schema.json`
- [ ] No secrets, tokens, API keys, or credentials committed
- [ ] Documentation updated to reflect any behavior changes
- [ ] Branding-neutral: no organization-specific references in public-facing files
- [ ] Catalog entries regenerated (`v run scripts/generate-catalogs.vsh`) if a skill, agent, or loop was added
- [ ] Commit messages are in English and follow conventional commits format
