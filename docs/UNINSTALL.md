# Uninstall

This guide helps you remove agent-toolkit artifacts from your machine without
leaving orphaned profiles or breaking unrelated tool configuration.

---

## Before you uninstall

1. **Identify how you installed** — CLI (`agent-toolkit install`), marketplace
   plugins, `npx skills`, Homebrew/AUR, or manual git clone + copy.
2. **Back up customizations** — if you edited toolkit-managed files, save copies
   before removal.
3. **Run doctor** (optional) — see what the CLI detects:

   ```bash
   agent-toolkit doctor
   ```

---

## Remove CLI-installed profiles

If you used `agent-toolkit install`, remove copied
profiles from each tool:

```bash
# Claude Code (global)
rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json
rm -rf ~/.claude/agents/

# Cursor (global rules — adjust glob if you added non-toolkit rules)
rm -f ~/.cursor/rules/agent-toolkit-*.mdc

# OpenCode
rm -f ~/.config/opencode/opencode.json
rm -rf ~/.config/opencode/agents/

# Windsurf (path varies by version)
rm -f ~/.codeium/windsurf/rules/agent-toolkit-*.mdc 2>/dev/null
rm -f ~/.windsurf/rules/agent-toolkit-*.mdc 2>/dev/null

# Pi
rm -f ~/.pi/agent/skills/agent-toolkit-*.md 2>/dev/null
```

**Project-level files** (`.claude/`, `.cursor/rules/`, `.github/copilot-instructions.md`)
live in your repositories — remove with `git rm` when appropriate.

---

## Remove marketplace plugins

### Claude Code

```text
/plugin uninstall agent-toolkit-core@agent-toolkit
/plugin uninstall agent-toolkit-agents@agent-toolkit
/plugin uninstall agent-toolkit-forge@agent-toolkit
```

### Cursor

Remove plugins via **Dashboard → Plugins** for `ulises-jeremias/agent-toolkit`.

---

## Remove npx skills install

Skills installed globally via the Agent Skills CLI:

```bash
npx skills remove ulises-jeremias/agent-toolkit -g
```

Consult the [Agent Skills](https://github.com/vercel-labs/skills) docs if your
version uses a different remove command.

---

## Remove package-manager installs

```bash
# Homebrew
brew uninstall agent-toolkit

# AUR (yay) — native V package
yay -R agent-toolkit-bin

# npm
npm uninstall -g agent-toolkit-cli

# pip / uv tool (PyPI launcher)
pip uninstall agent-toolkit-cli
uv tool uninstall agent-toolkit-cli
```

---

## Remove git checkout

If you cloned the repository for manual installs or loops:

```bash
rm -rf ~/.agent-toolkit
# or wherever you cloned the repo
```

---

## Clean up CLI state and receipts

The CLI stores local metadata under `~/.config/agent-toolkit/`:

```bash
# Installation receipts (when written by future install integration)
rm -rf ~/.config/agent-toolkit/receipts/

# Remove entire CLI config directory if nothing else uses it
rm -rf ~/.config/agent-toolkit/
```

Receipts record **which files were installed and their digests** — never secrets.
See [TRUST.md](TRUST.md) for the receipt schema and privacy model.

---

## Verify removal

```bash
agent-toolkit doctor    # should report no toolkit profiles (if CLI still installed)
```

Restart each AI tool and confirm skills/agents/rules no longer reference
agent-toolkit.

---

## Related guides

| Guide | Description |
|-------|-------------|
| [MIGRATION.md](MIGRATION.md) | Switch install methods without duplicate profiles |
| [TRUST.md](TRUST.md) | What the installer writes and how to audit it |
| [INSTALLATION.md](INSTALLATION.md) | Re-install after uninstall |
