# CLI command surfaces

## Consumer-first (#48)

Everyday commands for installing and verifying the toolkit:

- `version`, `help`, `install`, `doctor`, `diff`, `build`, `inventory`, `matrix`

## Advanced (#84)

Power-user / maintainer surfaces (still available, de-emphasized in top-level help):

- `loop`, `workspace`, `memory`, `project`, `devcompanion`, `insights`
- `release`, `mcp`, `update`, `uninstall`

The binary keeps a single entrypoint; advanced commands remain reachable by name
but are documented separately so new users are not overwhelmed.
