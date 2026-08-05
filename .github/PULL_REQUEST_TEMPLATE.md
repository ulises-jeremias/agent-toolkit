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

- [ ] Validated locally with `python3 scripts/validate-skills.py` (if skill changes)
- [ ] Validated loops with `python3` + `schemas/loop.schema.json` (if loop changes) — see `.github/workflows/validate.yml` `validate-loops` job
- [ ] Ran `python3 scripts/validate-agents.py` (if agent changes)
- [ ] Regenerated catalogs with `python3 scripts/generate-catalogs.py` (if skill/agent/loop added)
- [ ] Checked `python3 scripts/gen-surfaces.py --check` (if skill/agent/loop or surface changed)
- [ ] Confirmed `validate` CI workflow passes (or ran checks locally via `uv sync --all-extras && AGENT_TOOLKIT_ROOT=$PWD uv run pytest tests/ -v`)
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
- [ ] Catalog entries regenerated (`python3 scripts/generate-catalogs.py`) if a skill, agent, or loop was added
- [ ] Commit messages are in English and follow conventional commits format
