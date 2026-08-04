#!/usr/bin/env bash
# doctor.sh — Check AI tool availability and profile installation status
set -euo pipefail

echo ""
echo "🏥 agent-toolkit doctor"
echo ""

check_tool() {
  local name=$1 cmd=$2 install_hint=$3
  if command -v "$cmd" &>/dev/null; then
    version=$("$cmd" --version 2>/dev/null | head -1 || echo "installed")
    echo "  ✓ $name: $version"
  else
    echo "  ✗ $name: not found ($install_hint)"
  fi
}

check_profile() {
  local name=$1 path=$2
  if [ -e "$path" ]; then
    echo "  ✓ $name profile installed: $path"
  else
    echo "  - $name profile not installed ($path)"
  fi
}

echo "── AI Tools ──"
check_tool "Claude Code"    "claude"   "https://claude.ai/code"
check_tool "Cursor"         "cursor"   "https://cursor.sh"
check_tool "OpenCode"       "opencode" "https://opencode.ai"
check_tool "Windsurf"       "windsurf" "https://codeium.com/windsurf"

echo ""
echo "── Profile Status ──"
check_profile "Claude Code" "$HOME/.claude/CLAUDE.md"
check_profile "Cursor rules" "$HOME/.cursor/rules/"
check_profile "OpenCode agents" "$HOME/.config/opencode/agents/"
check_profile "Windsurf rules" "$HOME/.codeium/windsurf/rules/"
check_profile "Pi skills" "$HOME/.pi/agent/skills/"

echo ""
echo "Run 'bash scripts/install.sh' to install missing profiles."
echo ""
