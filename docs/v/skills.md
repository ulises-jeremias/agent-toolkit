# V `skills` command family

**Issue:** [#517](https://github.com/ulises-jeremias/agent-toolkit/issues/517) (EPIC 4b [#551](https://github.com/ulises-jeremias/agent-toolkit/issues/551))

Consumer skill management matching Python `cli/skills.py`:

- `list [--domain]` — groups from `catalogs/skills-layout.json`
- `sync [--tools]` — copy SKILL.md to `~/.claude/skills` / `~/.config/opencode/skills`; write `~/.cursor/skills-index.json`
- `validate` — SKILL.md frontmatter (`name`, `description`); warn on name/dir mismatch and leftover `skill.json`

Writes only to known tool skill locations. No swarm/tmux.
