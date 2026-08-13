# V `doctor` command

**Issues:** [#505](https://github.com/ulises-jeremias/agent-toolkit/issues/505) (read-only), [#550](https://github.com/ulises-jeremias/agent-toolkit/issues/550) (`--fix`)

Default `doctor` is **non-mutating** health report. `--json` includes `engine`, `version`, `platform`, and `fix_applied`.

## `--fix` (allowlisted)

When profile checks warn (missing install paths for detected tools), `--fix` runs capability `update` for those tools only:

- Documents the mutation under `── Auto-fix: refreshing profiles (allowlisted) ──`
- Sets `fix_applied=true` / `fix_action=update_profiles` in JSON
- No silent privilege escalation; does not modify package-manager-owned CLI binaries (#489)

Without `--fix`, behavior remains read-only.
