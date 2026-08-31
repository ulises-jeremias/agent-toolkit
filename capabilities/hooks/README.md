# Canonical lifecycle hooks

YAML files here feed the compiler hook registry. Handlers live under
`scripts/` and are opt-in (`default_enabled: false`).

Product bundles keep `hooks: []` until adapter emission lands (#68).
