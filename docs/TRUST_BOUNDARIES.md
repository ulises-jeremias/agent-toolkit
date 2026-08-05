# Trust boundaries

Consumer-facing trust rules for hooks, MCP destructive tools, and profile installs (#98).

## Hooks

- Hook definitions are opt-in (`default_enabled: false` unless explicitly safe and local).
- Placeholder/echo handlers are forbidden in CI.
- Destructive classifications must never default-enable.
- Product bundles ship `hooks: []` until emission is certified per target.

## MCP

- Registry metadata must list env var **names** only — never secret values.
- Destructive tool lists are advisory for approval UX; default approval is read-only.
- Official providers preferred; community packages must be labeled `provenance: community`.

## Profile installs

- Installers must not overwrite unmanaged user settings (e.g. `~/.claude/settings.json`).
- Owned files are tracked via install receipts for uninstall/rollback.
- Profiles must not contain private hostnames (`.local`) or embedded credentials.

## Supply chain

- Prefer pinned GitHub Actions SHAs and release SBOM/attestations (#99).
