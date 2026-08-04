#!/usr/bin/env bash
# validate-skills.sh — Validate agent-toolkit skill definitions and loop templates
#
# Checks:
#   1. Every skill directory has SKILL.md and skill.json
#   2. SKILL.md has required frontmatter (name, description)
#   3. skill.json has required fields (name, version, compatibility)
#   4. skill.json is valid JSON
#   5. No secrets or credential patterns in any tracked file
#   6. Every loop template has loop.yaml with required fields (name, goal, request)
#
# Usage:
#   bash scripts/validate-skills.sh
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ERRORS=0
WARNINGS=0
CHECKS=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

check_pass() { printf '  [pass] %s\n' "$*"; (( CHECKS++ )) || true; }
check_fail() { printf '  [FAIL] %s\n' "$*" >&2; (( ERRORS++ )) || true; (( CHECKS++ )) || true; }
check_warn() { printf '  [warn] %s\n' "$*"; (( WARNINGS++ )) || true; }
section()    { printf '\n-- %s --\n' "$*"; }

# has_frontmatter_field FILE FIELD — check that FIELD: appears inside --- fences
has_frontmatter_field() {
  local file="$1"
  local field="$2"
  # Match field at start of line within the first frontmatter block
  awk '
    /^---$/ { if (found_open) { exit } else { found_open=1; next } }
    found_open && /^'"$field"':/ { found=1; exit }
    END { exit !found }
  ' "$file"
}

# json_has_fields FILE FIELD... — check that each FIELD key exists in JSON object
json_has_fields() {
  local file="$1"
  shift
  local missing=()

  if ! python3 -c "import json; json.load(open('${file}'))" 2>/dev/null; then
    return 1
  fi

  for field in "$@"; do
    if ! python3 -c "
import json, sys
d = json.load(open('${file}'))
sys.exit(0 if '${field}' in d else 1)
" 2>/dev/null; then
      missing+=("$field")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '%s' "${missing[*]}"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Check 1: Skill structure
# ---------------------------------------------------------------------------

section "Skill structure"

SKILL_DOMAINS=(core delivery design forge integrations data tooling ops loops)
SKILL_COUNT=0
SKILL_ERRORS=0

for domain in "${SKILL_DOMAINS[@]}"; do
  domain_dir="${TOOLKIT_DIR}/skills/${domain}"
  [[ -d "$domain_dir" ]] || continue

  while IFS= read -r -d '' skill_dir; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    label="${domain}/${skill_name}"
    (( SKILL_COUNT++ )) || true

    # 1a. SKILL.md must exist
    if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
      check_fail "${label}: missing SKILL.md"
      (( SKILL_ERRORS++ )) || true
    fi

    # 1b. skill.json must exist
    if [[ ! -f "${skill_dir}/skill.json" ]]; then
      check_fail "${label}: missing skill.json"
      (( SKILL_ERRORS++ )) || true
    fi

    # 1c. SKILL.md frontmatter — name and description required
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
      if ! has_frontmatter_field "${skill_dir}/SKILL.md" "name"; then
        check_fail "${label}/SKILL.md: missing 'name:' in frontmatter"
        (( SKILL_ERRORS++ )) || true
      fi
      if ! has_frontmatter_field "${skill_dir}/SKILL.md" "description"; then
        check_fail "${label}/SKILL.md: missing 'description:' in frontmatter"
        (( SKILL_ERRORS++ )) || true
      fi
    fi

    # 1d. skill.json — valid JSON with required fields
    if [[ -f "${skill_dir}/skill.json" ]]; then
      if ! python3 -c "import json; json.load(open('${skill_dir}/skill.json'))" 2>/dev/null; then
        check_fail "${label}/skill.json: invalid JSON"
        (( SKILL_ERRORS++ )) || true
      else
        missing_fields=""
        if ! missing_fields=$(json_has_fields "${skill_dir}/skill.json" name version compatibility 2>/dev/null); then
          check_fail "${label}/skill.json: missing required field(s): ${missing_fields:-name/version/compatibility}"
          (( SKILL_ERRORS++ )) || true
        fi
      fi
    fi

  done < <(find "$domain_dir" -mindepth 1 -maxdepth 1 -type d -print0)
done

if [[ $SKILL_COUNT -eq 0 ]]; then
  check_warn "No skill directories found under skills/"
elif [[ $SKILL_ERRORS -eq 0 ]]; then
  check_pass "${SKILL_COUNT} skill(s) passed structure check"
fi

# ---------------------------------------------------------------------------
# Check 2: Loop templates
# ---------------------------------------------------------------------------

section "Loop templates"

LOOP_COUNT=0
LOOP_ERRORS=0
LOOPS_DIR="${TOOLKIT_DIR}/loops"

if [[ -d "$LOOPS_DIR" ]]; then
  while IFS= read -r -d '' loop_dir; do
    [[ -d "$loop_dir" ]] || continue
    loop_name="$(basename "$loop_dir")"
    (( LOOP_COUNT++ )) || true

    # 2a. loop.yaml must exist
    if [[ ! -f "${loop_dir}/loop.yaml" ]]; then
      check_fail "loops/${loop_name}: missing loop.yaml"
      (( LOOP_ERRORS++ )) || true
      continue
    fi

    # 2b. loop.yaml must have required fields (name, goal, request)
    for field in name goal request; do
      if ! grep -q "^${field}:" "${loop_dir}/loop.yaml" 2>/dev/null; then
        check_fail "loops/${loop_name}/loop.yaml: missing required field '${field}'"
        (( LOOP_ERRORS++ )) || true
      fi
    done

  done < <(find "$LOOPS_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

  if [[ $LOOP_COUNT -eq 0 ]]; then
    check_warn "No loop directories found under loops/"
  elif [[ $LOOP_ERRORS -eq 0 ]]; then
    check_pass "${LOOP_COUNT} loop template(s) passed structure check"
  fi
else
  check_warn "loops/ directory not found — skipping loop validation"
fi

# ---------------------------------------------------------------------------
# Check 3: Secret scan
# ---------------------------------------------------------------------------

section "Secret scan"

# Patterns that look like real credentials (not placeholders)
declare -a SECRET_PATTERNS=(
  'ghp_[A-Za-z0-9]{36,}'                        # GitHub personal access token
  'github_pat_[A-Za-z0-9_]{20,}'                # GitHub fine-grained PAT
  'sk-[A-Za-z0-9]{20,}'                         # OpenAI / generic sk- key
  'sk-ant-[A-Za-z0-9]'                          # Anthropic API key
  'xoxb-[0-9]+-[A-Za-z0-9]+'                    # Slack bot token
  'xapp-[0-9]+-[A-Za-z0-9]+'                    # Slack app-level token
  'figd_[A-Za-z0-9_]+'                          # Figma token
  'pk_[A-Za-z0-9]{20,}'                         # ClickUp API key
  'secret_[A-Za-z0-9]{20,}'                     # Notion integration token
  'Bearer [A-Za-z0-9+/=]{30,}'                  # Raw Bearer token
  'password\s*=\s*["\x27][^"\x27${}{]{8,}'      # Hardcoded password (not a var)
  'api[_-]?key\s*=\s*["\x27][A-Za-z0-9]{16,}'  # Hardcoded api_key value
)

# Directories to scan
SCAN_DIRS=(
  "${TOOLKIT_DIR}/skills"
  "${TOOLKIT_DIR}/profiles"
  "${TOOLKIT_DIR}/mcp"
  "${TOOLKIT_DIR}/loops"
  "${TOOLKIT_DIR}/packs"
)

# File types to check
SCAN_INCLUDE=(
  --include="*.md"
  --include="*.yaml"
  --include="*.yml"
  --include="*.json"
  --include="*.sh"
  --include="*.mdc"
)

SECRET_FOUND=0

for pattern in "${SECRET_PATTERNS[@]}"; do
  # Build the list of existing scan dirs
  existing_dirs=()
  for dir in "${SCAN_DIRS[@]}"; do
    [[ -d "$dir" ]] && existing_dirs+=("$dir")
  done

  if [[ ${#existing_dirs[@]} -eq 0 ]]; then
    continue
  fi

  matches=$(grep -rI -E "$pattern" "${SCAN_INCLUDE[@]}" "${existing_dirs[@]}" 2>/dev/null \
    | grep -v '\.env\.example' \
    | grep -v '\${\|%{' \
    | wc -l | tr -d ' ') || matches=0

  if [[ "$matches" -gt 0 ]]; then
    check_fail "Potential secret matching pattern: ${pattern}"
    # Show up to 3 matching lines for context
    grep -rI -E "$pattern" "${SCAN_INCLUDE[@]}" "${existing_dirs[@]}" 2>/dev/null \
      | grep -v '\.env\.example' \
      | grep -v '\${\|%{' \
      | head -3 \
      | sed 's/^/    /' >&2 || true
    (( SECRET_FOUND++ )) || true
  fi
done

if [[ $SECRET_FOUND -eq 0 ]]; then
  check_pass "No secret patterns detected"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n'
printf '======================================================================\n'

total_errors=$ERRORS

if [[ $total_errors -eq 0 ]]; then
  printf '[pass] All %d check(s) passed' "$CHECKS"
  [[ $WARNINGS -gt 0 ]] && printf ' (%d warning(s))' "$WARNINGS"
  printf '\n'
  exit 0
else
  printf '[FAIL] %d error(s) found' "$total_errors"
  [[ $WARNINGS -gt 0 ]] && printf ', %d warning(s)' "$WARNINGS"
  printf ' — see details above\n'
  exit 1
fi
