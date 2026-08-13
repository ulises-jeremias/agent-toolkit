#!/usr/bin/env bash
# doctor.sh — thin wrapper → `agent-toolkit doctor` (ADR-007 / V-first)
#
# Deprecated entrypoint kept for muscle memory. Prefer:
#   agent-toolkit doctor
set -euo pipefail

if [[ -z "${AGENT_TOOLKIT_NO_DEPRECATION_WARNING:-}" ]]; then
  printf '  [warn]  scripts/doctor.sh is deprecated — prefer `agent-toolkit doctor` (V CLI). See docs/INSTALLATION.md and docs/adrs/ADR-007-install-sh-deprecation.md\n' >&2
fi

if command -v agent-toolkit >/dev/null 2>&1; then
  exec agent-toolkit doctor "$@"
fi

printf '  [error] agent-toolkit not found on PATH.\n' >&2
printf '  Install the V CLI, then re-run (or call agent-toolkit doctor directly):\n' >&2
printf '    brew install ulises-jeremias/homebrew-tap/agent-toolkit\n' >&2
printf '    yay -S agent-toolkit-bin\n' >&2
printf '    uv tool install '\''agent-toolkit-cli>=1.11.0'\''\n' >&2
printf '  Docs: docs/INSTALLATION.md\n' >&2
exit 1
