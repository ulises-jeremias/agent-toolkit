#!/usr/bin/env bash
# Emit a short session context hint for agent runtimes that support SessionStart.
set -euo pipefail
root="${AGENT_TOOLKIT_ROOT:-}"
echo "agent-toolkit session-start: toolkit_root=${root:-unset}"
if [[ -n "$root" && -d "$root/skills" ]]; then
  echo "skills_present=yes"
else
  echo "skills_present=unknown"
fi
exit 0
