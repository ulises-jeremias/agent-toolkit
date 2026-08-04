#!/usr/bin/env bash
# validate-skills.sh — Validate skill structure and content
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

error() { echo "  ✗ $1"; ERRORS=$((ERRORS+1)); }
ok()    { echo "  ✓ $1"; }

echo ""
echo "🔍 Validating agent-toolkit skills..."
echo ""

# 1. Check each skill has SKILL.md and skill.json
echo "── Skill structure ──"
for domain in core delivery design forge integrations data tooling ops loops; do
  domain_dir="$TOOLKIT_DIR/skills/$domain"
  [ -d "$domain_dir" ] || continue
  for skill_dir in "$domain_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    
    if [ ! -f "$skill_dir/SKILL.md" ]; then
      error "$domain/$skill_name: missing SKILL.md"
    fi
    if [ ! -f "$skill_dir/skill.json" ]; then
      error "$domain/$skill_name: missing skill.json"
    fi
    
    # Check SKILL.md has required frontmatter
    if [ -f "$skill_dir/SKILL.md" ]; then
      if ! grep -q "^name:" "$skill_dir/SKILL.md"; then
        error "$domain/$skill_name/SKILL.md: missing 'name:' in frontmatter"
      fi
      if ! grep -q "^description:" "$skill_dir/SKILL.md"; then
        error "$domain/$skill_name/SKILL.md: missing 'description:' in frontmatter"
      fi
    fi
    
    # Check skill.json has required fields
    if [ -f "$skill_dir/skill.json" ]; then
      if ! python3 -c "
import json, sys
try:
  d = json.load(open('$skill_dir/skill.json'))
  required = ['name','version','description','compatibility']
  missing = [f for f in required if f not in d]
  if missing:
    print('Missing fields:', missing)
    sys.exit(1)
except json.JSONDecodeError as e:
  print('Invalid JSON:', e)
  sys.exit(1)
" 2>/dev/null; then
        error "$domain/$skill_name/skill.json: invalid or missing required fields"
      fi
    fi
  done
done

[ "$ERRORS" -eq 0 ] && ok "All skill structures valid" || true

# 2. Check loop templates
echo ""
echo "── Loop templates ──"
for loop_dir in "$TOOLKIT_DIR/loops"/*/; do
  [ -d "$loop_dir" ] || continue
  loop_name=$(basename "$loop_dir")
  
  if [ ! -f "$loop_dir/loop.yaml" ]; then
    error "loops/$loop_name: missing loop.yaml"
    continue
  fi
  
  # Check required fields
  if ! python3 -c "
import yaml, sys
try:
  d = yaml.safe_load(open('$loop_dir/loop.yaml'))
  required = ['name','goal','request']
  missing = [f for f in required if not d.get(f)]
  if missing:
    print('Missing fields:', missing)
    sys.exit(1)
except Exception as e:
  print('Error:', e)
  sys.exit(1)
" 2>/dev/null; then
    error "loops/$loop_name/loop.yaml: missing required fields (name, goal, request)"
  fi
done

[ "$ERRORS" -eq 0 ] && ok "All loop templates valid" || true

# 3. Secret scan
echo ""
echo "── Secret scan ──"
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9]{20,}'           # OpenAI keys
  'sk-ant-[a-zA-Z0-9]'            # Anthropic keys
  'xoxb-[a-zA-Z0-9]'             # Slack bot tokens
  'github_pat_'                    # GitHub PATs
  'ghp_[a-zA-Z0-9]{36}'          # GitHub tokens
  'Bearer [a-zA-Z0-9+/]{20,}'    # Bearer tokens
  'password\s*=\s*["\x27][^"\x27]{8,}' # Hardcoded passwords
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  matches=$(grep -rI -E "$pattern" \
    --include="*.md" --include="*.yaml" --include="*.json" --include="*.sh" \
    "$TOOLKIT_DIR/skills" "$TOOLKIT_DIR/profiles" "$TOOLKIT_DIR/mcp" \
    2>/dev/null | grep -v "\.env.example" | wc -l || echo 0)
  
  if [ "$matches" -gt 0 ]; then
    error "Potential secret found matching: $pattern"
    grep -rI -E "$pattern" \
      --include="*.md" --include="*.yaml" --include="*.json" --include="*.sh" \
      "$TOOLKIT_DIR/skills" "$TOOLKIT_DIR/profiles" "$TOOLKIT_DIR/mcp" \
      2>/dev/null | head -3
  fi
done

[ "$ERRORS" -eq 0 ] && ok "No secrets detected" || true

# Summary
echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "✅ All validations passed!"
else
  echo "❌ $ERRORS validation error(s) found"
  exit 1
fi
