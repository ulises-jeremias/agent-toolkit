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
./scripts/validate-skills.vsh
```

The legacy `schemas/skill.schema.json` (for removed `skill.json` manifests) is archived at [`docs/archive/skill.schema.json`](archive/skill.schema.json). Skills validate via `schemas/skill-md-frontmatter.schema.json` and `scripts/validate-skills.vsh`.

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

## Agent taxonomy migration (#865 — 25 → 18 agents, 7 archived → `references/`)

`agent-toolkit` 25 − 18: 7 specialists archived as inline references (no separate
agent context, no prompt knowledge deleted). Old installations may have stale files at
`~/.claude/agents/{typescript,database,performance}-reviewer.md`,
`~/.claude/agents/{refactor-cleaner,docs-lookup,reference-lookup,tech-assistant}.md`,
`~/.cursor/rules/{database-reviewer,docs-lookup,...}.mdc`, or equivalent in
`~/.config/opencode/agents/` / `~/.pi/agent/skills/` / Windsurf rules.

### CLI `install --force` handles this automatically

`agent-toolkit install [--tools <list>] --force` regenerates compiled profiles
from current `agents/` (18) and, on the next install, removes only **previously
installed Toolkit-owned files** that are no longer present in the new release.
It **preserves user-owned files** (manual or project-local config you created).

- Stale Toolkit files (from prior install receipts) in `~/.claude/agents/`,
  `~/.cursor/rules/`, `~/.config/opencode/agents/`, etc. are detected via the
  prior install receipts under `~/.config/agent-toolkit/receipts/` and removed
  when absent from the new `plugins/` payload.
- User files (not in a receipt as `ownership: created`) are left in place.
- If no prior receipt exists (e.g., a manual `cp` install), re-running with
  `agent-toolkit install --tools <tool> --force` writes the new 18-agent set;
  stale files from the old manual copy remain until you remove them manually:

  ```bash
  # List what install owns vs what you own
  agent-toolkit doctor
  # After upgrade — force write new agents
  agent-toolkit install --force
  # If doctor still shows stale paths from a pre-receipt era — remove only those names:
  rm -f ~/.claude/agents/typescript-reviewer.md ~/.claude/agents/database-reviewer.md \
        ~/.claude/agents/performance-optimizer.md ~/.claude/agents/refactor-cleaner.md \
        ~/.claude/agents/docs-lookup.md ~/.claude/agents/reference-lookup.md \
        ~/.claude/agents/tech-assistant.md
  rm -f ~/.cursor/rules/database-reviewer.mdc ~/.cursor/rules/docs-lookup.mdc \
        ~/.cursor/rules/performance-optimizer.mdc ~/.cursor/rules/refactor-cleaner.mdc \
        ~/.cursor/rules/reference-lookup.mdc ~/.cursor/rules/typescript-reviewer.mdc
  # equivalent for opencode/pi/windsurf where used
  ```

### Inline replacements (where the knowledge went)

| Archived specialist | Invoke inline via |
|---------------------|-------------------|
| `typescript-reviewer` | `reviewer` + `quality/deep-review` + `reviewer/references/TYPESCRIPT_CHECKLIST.md` |
| `database-reviewer` | `reviewer` + `quality/deep-review` or `architect`/`technical-unit-assessment` + `reviewer/references/DATABASE_CHECKLIST.md` |
| `performance-optimizer` | `reviewer`/`architect` + `quality/blast-radius`/`deep-review` + `reviewer/references/PERFORMANCE_CHECKLIST.md` |
| `refactor-cleaner` | `reviewer` + `quality/deslop` + `reviewer/references/REFACTOR_CHECKLIST.md` |
| `docs-lookup` + `reference-lookup` | `researcher` + `delivery/spike`/`project-assessment-evidence` + `researcher/references/LOOKUP_GUIDE.md` |
| `tech-assistant` | `platform-engineer` + `ops/triage`/`tooling/inventory` + `platform-engineer/references/WORKSTATION_OPS.md` |

No prompt knowledge was deleted — only the separate agent persona wrapper. See
`docs/AGENT_TAXONOMY.md` §3/§8 for the full migration map and `docs/ARCHITECTURE.md`
table row "Archived → `references/`".

---

## Version upgrades

| Install method | Upgrade path |
|----------------|--------------|
| CLI (GitHub / brew / AUR / `uv` / npm) | Upgrade that channel, then `agent-toolkit install --force` |
| Marketplace | Re-install or update plugins from marketplace UI |
| Git clone | `git pull` then `./make.vsh install-cli && agent-toolkit install --force` |

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
