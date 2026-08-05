#!/usr/bin/env bash
# Minimal pre-write validation hook for agent-toolkit.
# Reads the candidate path from AGENT_TOOLKIT_HOOK_PATH when set.
set -euo pipefail
path="${AGENT_TOOLKIT_HOOK_PATH:-${1:-}}"
if [[ -z "$path" ]]; then
  echo "pre-commit-validate: no path supplied" >&2
  exit 0
fi
if [[ ! -f "$path" ]]; then
  echo "pre-commit-validate: skip missing file $path" >&2
  exit 0
fi
# Reject obvious secret material in staged content (best-effort).
if grep -Eiq 'ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$path"; then
  echo "pre-commit-validate: refusing write — secret-like material detected in $path" >&2
  exit 1
fi
exit 0
