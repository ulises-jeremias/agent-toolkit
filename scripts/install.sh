#!/usr/bin/env bash
# install.sh — thin wrapper → `agent-toolkit install` (ADR-007 / V-first)
#
# Deprecated entrypoint kept for muscle memory. Prefer:
#   agent-toolkit install
#   uvx --from agent-toolkit-cli agent-toolkit install
# Channels: brew / AUR agent-toolkit-bin / GitHub Release / uv — see docs/INSTALLATION.md
set -euo pipefail

if [[ -z "${AGENT_TOOLKIT_NO_DEPRECATION_WARNING:-}" ]]; then
  printf '  [warn]  scripts/install.sh is deprecated — prefer `agent-toolkit install` (V CLI). See docs/INSTALLATION.md and docs/adrs/ADR-007-install-sh-deprecation.md\n' >&2
fi

if command -v agent-toolkit >/dev/null 2>&1; then
  exec agent-toolkit install "$@"
fi

printf '  [error] agent-toolkit not found on PATH.\n' >&2
printf '  Install the V CLI, then re-run (or call agent-toolkit install directly):\n' >&2
printf '    brew install ulises-jeremias/homebrew-tap/agent-toolkit\n' >&2
printf '    yay -S agent-toolkit-bin\n' >&2
printf '    uv tool install '\''agent-toolkit-cli>=1.11.0'\''\n' >&2
printf '  Docs: docs/INSTALLATION.md\n' >&2
exit 1
