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

- [ ] Validated locally with `bash scripts/validate-skills.sh` (if skill changes)
- [ ] Ran affected loop templates manually end-to-end (if loop changes)
- [ ] Confirmed `validate` CI workflow passes (or ran checks locally)
- [ ] Tested with at least one supported AI tool (Claude Code, Cursor, Copilot, etc.)

## Checklist

- [ ] Skill directories include both `SKILL.md` and `skill.json`
- [ ] `skill.json` validates against `schemas/skill.schema.json`
- [ ] Loop templates include required fields: `name`, `goal`, `request`
- [ ] Loop templates include `budget`, `deny`, and `exit_conditions` fields
- [ ] Loop templates validate against `schemas/loop.schema.json`
- [ ] No secrets, tokens, API keys, or credentials committed
- [ ] Documentation updated to reflect any behavior changes
- [ ] Branding-neutral: no organization-specific references in public-facing files
- [ ] Catalog entries updated (`catalogs/`) if a skill, agent, or loop was added
- [ ] Commit messages are in English and follow conventional commits format
