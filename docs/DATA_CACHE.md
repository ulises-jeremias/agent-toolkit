# Capability data cache

The Python wheel may ship without full `skills/`, `profiles/`, and `loops/` trees.
On first run, `agent-toolkit` downloads the matching GitHub Release source tarball
and caches capability data under:

```
~/.local/share/agent-toolkit/data/
```

## Resolution order

See `agent_toolkit._paths.find_toolkit_root()`:

1. `AGENT_TOOLKIT_ROOT` / `AI_WORKSPACE`
2. Bundled package data (full wheel)
3. XDG cache, downloading from GitHub Releases when missing
4. Editable monorepo checkout
5. Current working directory

## Offline installs

```bash
agent-toolkit install --offline
```

Uses only bundled wheel data or an existing cache — no network access.

## Refresh

Use `agent-toolkit update` to refresh cached data and re-sync installed profiles.
