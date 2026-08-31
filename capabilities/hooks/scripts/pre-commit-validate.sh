#!/usr/bin/env bash
# Pre-write validation hook for agent-toolkit.
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

# Reject unresolved merge conflict markers.
if grep -qE '^(<<<<<<<|=======|>>>>>>>)' "$path"; then
  echo "pre-commit-validate: merge conflict markers in $path" >&2
  exit 1
fi

# Reject obvious secret material in staged content (best-effort).
if grep -Eiq 'ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|BEGIN (RSA |OPENSSH )?PRIVATE KEY' "$path"; then
  echo "pre-commit-validate: refusing write — secret-like material detected in $path" >&2
  exit 1
fi

# Basic skill frontmatter when writing SKILL.md files.
case "$path" in
  */SKILL.md|SKILL.md)
    if ! head -n 30 "$path" | grep -q '^---$'; then
      echo "pre-commit-validate: SKILL.md missing YAML frontmatter delimiters in $path" >&2
      exit 1
    fi
    if ! head -n 30 "$path" | grep -qE '^name:'; then
      echo "pre-commit-validate: SKILL.md frontmatter missing name in $path" >&2
      exit 1
    fi
    ;;
esac

exit 0
