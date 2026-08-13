# Migration Guide

Move between install methods without duplicate profiles, stale `skill.json`
files, or conflicting marketplace + copy installs.

---

## Quick reference

| From | To | Start here |
|------|-----|------------|
| Profile copy (`agent-toolkit install`) | Marketplace plugins | [Profile → marketplace](#profile-copy-to-marketplace-plugins) |
| Old `skill.json` skills | SKILL.md frontmatter only | [skill.json removal](#migrating-from-skilljson) |
| agentic-workstation sync | agent-toolkit | [Workstation migration](#migrating-from-agentic-workstation) |
| Any method | Clean reinstall | [UNINSTALL.md](UNINSTALL.md) then [INSTALLATION.md](INSTALLATION.md) |

---

## Profile copy to marketplace plugins

Before v1.2.0, `agent-toolkit install` copied files directly to home directories
(e.g., `~/.claude/CLAUDE.md`, `~/.cursor/rules/*.mdc`).

From v1.2.0 onwards, native plugin bundles are the preferred distribution for
Claude Code and Cursor.

### Recommended migration steps

1. **Audit current state**

   ```bash
   agent-toolkit doctor
   ```

2. **Remove old profile copies** (or back them up first) — see
   [UNINSTALL.md](UNINSTALL.md#remove-cli-installed-profiles)

3. **Install marketplace plugins**

   **Claude Code:**
   ```text
   /plugin marketplace add ulises-jeremias/agent-toolkit
   /plugin install agent-toolkit-core@agent-toolkit
   /plugin install agent-toolkit-agents@agent-toolkit
   /plugin install agent-toolkit-forge@agent-toolkit
   ```

   **Cursor:** Dashboard → Plugins → `ulises-jeremias/agent-toolkit`

4. **Verify** — new session; ask *"What skills do you have available?"*

### Keep profile-based install (still supported)

Profile copy remains for tools without marketplace support (Windsurf, Pi) and
for development:

```bash
agent-toolkit install --tools windsurf,pi
```

Do **not** run profile copy and marketplace install for the same tool — you will
get duplicate skills/rules.

---

## Migrating from skill.json

`skill.json` files were removed in v1.0.4. Only `SKILL.md` frontmatter is needed
per the [Agent Skills spec](https://github.com/vercel-labs/skills).

```bash
find . -name "skill.json" -path "*/skills/*"
find . -name "skill.json" -path "*/skills/*" -delete
```

Run validation after cleanup:

```bash
bash scripts/validate-skills.sh
```

---

## Migrating from agentic-workstation

If you previously used `dots-skills sync` from agentic-workstation, replace with:

```bash
# Marketplace (Claude Code — preferred)
/plugin marketplace add ulises-jeremias/agent-toolkit

# Or CLI profile install
uvx --from agent-toolkit-cli agent-toolkit install
```

Remove stale `dots-workstation-*` files from `~/.claude/skills/` and
`~/.cursor/rules/`. agentic-workstation may clean these via `.chezmoiremove`
when updated to use agent-toolkit.

---

## Version upgrades

| Install method | Upgrade path |
|----------------|--------------|
| CLI (`uvx` / pip) | `uv tool upgrade agent-toolkit-cli` then `agent-toolkit install --force` |
| Marketplace | Re-install or update plugins from marketplace UI |
| Git clone | `git pull` in repo; re-run `scripts/install.sh --force` |

Read [CHANGELOG.md](../CHANGELOG.md) for breaking changes between versions.
Current CLI version: `packages/pypi/agent-toolkit-cli/src/agent_toolkit/__init__.py`.

---

## Trust and audit during migration

- Review [TRUST.md](TRUST.md) for what files are written and receipt metadata
- Never commit API keys when adding Copilot instructions or MCP configs
- Use `agent-toolkit diff` (when available) to preview compiler output before applying

---

## Related guides

| Guide | Description |
|-------|-------------|
| [INSTALLATION.md](INSTALLATION.md) | Primary install flow |
| [UNINSTALL.md](UNINSTALL.md) | Remove old artifacts before migrating |
| [TRUST.md](TRUST.md) | Security and verification for consumers |
| [TARGETS.md](TARGETS.md) | Compile targets and capability matrix |
