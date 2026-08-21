# Muse Code Profile

> Meta's Muse Code — `muse` CLI (https://developer.meta.com/ai/products/muse-code/)

Muse Code follows the [Agent Skills specification](https://agentskills.io):

- **User scope**: `~/.config/muse/skills/<name>/SKILL.md` (`$XDG_CONFIG_HOME/muse`)
- **Project scope**: `.agents/skills/<name>/SKILL.md`

## Install

```bash
# Via agent-toolkit
agent-toolkit install --tools muse-code
# or alias
agent-toolkit install --tools muse

# Via standalone installer
curl -fsSL https://dev.meta.ai/install.sh | bash
muse --version

# Sync existing Claude skills
muse skills import --from claude --scope user
```

## Skills Mapping

All agent-toolkit skills are compatible with Muse Code via `muse-code: supported: true`.
The compiler emits to `skills/<name>/SKILL.md` which the installer maps to both
`~/.config/muse/skills/` and `~/.agents/skills/` (universal).

## See Also

- [Muse Code CLI](https://www.llama.com/products/cli/)
- [Agent Skills Spec](https://agentskills.io)

## Profile Status

This profile is intentionally minimal — Muse Code discovers skills via `~/.config/muse/skills/` and `~/.agents/skills/` universally. No per-tool profile files are needed beyond this README. Skills are delivered via `agent-toolkit build --target muse-code` (see `docs/PROFILES.md`).

*Related: #789*
