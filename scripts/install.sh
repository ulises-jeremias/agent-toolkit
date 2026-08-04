#!/usr/bin/env bash
# install.sh — Install agent-toolkit profiles for detected AI tools
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false
TOOLS=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --tools <list>    Comma-separated list of tools to install (default: auto-detect)
                    Valid: claude-code,cursor,opencode,copilot,windsurf,pi
  --dry-run         Show what would be installed without making changes
  --help            Show this help

Examples:
  bash scripts/install.sh
  bash scripts/install.sh --tools claude-code,cursor
  bash scripts/install.sh --dry-run
EOF
}

log() { echo "  $1"; }
ok()  { echo "  ✓ $1"; }
warn(){ echo "  ⚠ $1"; }
skip(){ echo "  - $1 (skipped)"; }

copy_files() {
  local src=$1 dst=$2
  if [ "$DRY_RUN" = true ]; then
    log "Would copy: $src → $dst"
  else
    mkdir -p "$dst"
    cp -rf "$src/." "$dst/"
    ok "Copied to $dst"
  fi
}

detect_tools() {
  local found=()
  command -v claude   &>/dev/null && found+=("claude-code")
  command -v cursor   &>/dev/null && found+=("cursor")
  command -v opencode &>/dev/null && found+=("opencode")
  command -v gh       &>/dev/null && found+=("copilot")  # ask for project
  [ -d "$HOME/.codeium/windsurf" ] || [ -d "$HOME/.windsurf" ] && found+=("windsurf")
  [ -d "$HOME/.pi" ] && found+=("pi")
  echo "${found[@]:-}"
}

install_claude_code() {
  echo "→ Claude Code"
  local src="$TOOLKIT_DIR/profiles/claude-code"
  [ -d "$src" ] || { warn "Profile not found: $src"; return; }

  copy_files "$src/agents" "$HOME/.claude/agents"
  if [ -f "$src/CLAUDE.md" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "Would copy: $src/CLAUDE.md → ~/.claude/CLAUDE.md"
    else
      cp "$src/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
      ok "Copied CLAUDE.md"
    fi
  fi
}

install_cursor() {
  echo "→ Cursor"
  local src="$TOOLKIT_DIR/profiles/cursor/rules"
  [ -d "$src" ] || { warn "Profile not found: $src"; return; }

  copy_files "$src" "$HOME/.cursor/rules"
}

install_opencode() {
  echo "→ OpenCode"
  local src="$TOOLKIT_DIR/profiles/opencode"
  [ -d "$src" ] || { warn "Profile not found: $src"; return; }

  copy_files "$src/agents" "$HOME/.config/opencode/agents"
  if [ -f "$src/opencode.json" ]; then
    if [ "$DRY_RUN" = true ]; then
      log "Would copy: opencode.json → ~/.config/opencode/opencode.json"
    else
      cp "$src/opencode.json" "$HOME/.config/opencode/opencode.json"
      ok "Copied opencode.json"
    fi
  fi
}

install_copilot() {
  echo "→ GitHub Copilot"
  local src="$TOOLKIT_DIR/profiles/copilot/copilot-instructions.md"
  [ -f "$src" ] || { warn "Profile not found: $src"; return; }

  if [ "$DRY_RUN" = false ]; then
    read -rp "    Enter project path to install copilot-instructions.md (or Enter to skip): " proj
    if [ -n "$proj" ] && [ -d "$proj" ]; then
      mkdir -p "$proj/.github"
      cp "$src" "$proj/.github/copilot-instructions.md"
      ok "Copied to $proj/.github/"
    else
      skip "No project path provided"
    fi
  else
    log "Would copy copilot-instructions.md to <project>/.github/"
  fi
}

install_windsurf() {
  echo "→ Windsurf"
  local src="$TOOLKIT_DIR/profiles/windsurf"
  [ -d "$src" ] || { warn "Profile not found: $src"; return; }

  local dst_base
  if [ -d "$HOME/.codeium/windsurf" ]; then
    dst_base="$HOME/.codeium/windsurf"
  elif [ -d "$HOME/.windsurf" ]; then
    dst_base="$HOME/.windsurf"
  else
    mkdir -p "$HOME/.codeium/windsurf"
    dst_base="$HOME/.codeium/windsurf"
  fi

  [ -d "$src/rules" ] && copy_files "$src/rules" "$dst_base/rules"
  [ -d "$src/memories" ] && copy_files "$src/memories" "$dst_base/memories"
}

install_pi() {
  echo "→ Pi Coding Agent"
  local src="$TOOLKIT_DIR/profiles/pi/skills"
  [ -d "$src" ] || { warn "Profile not found: $src"; return; }

  copy_files "$src" "$HOME/.pi/agent/skills"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools) TOOLS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help) usage; exit 0 ;;
    *) warn "Unknown option: $1"; usage; exit 1 ;;
  esac
done

echo ""
echo "🛠️  agent-toolkit installer"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN — no changes will be made"
  echo ""
fi

# Determine which tools to install
if [ -z "$TOOLS" ]; then
  detected=$(detect_tools)
  if [ -z "$detected" ]; then
    warn "No AI tools detected. Specify with --tools"
    usage; exit 1
  fi
  echo "Detected tools: $detected"
  echo ""
  IFS=' ' read -ra TOOL_LIST <<< "$detected"
else
  IFS=',' read -ra TOOL_LIST <<< "$TOOLS"
fi

# Install each tool
for tool in "${TOOL_LIST[@]}"; do
  case "$tool" in
    claude-code) install_claude_code ;;
    cursor)      install_cursor ;;
    opencode)    install_opencode ;;
    copilot)     install_copilot ;;
    windsurf)    install_windsurf ;;
    pi)          install_pi ;;
    *) warn "Unknown tool: $tool" ;;
  esac
done

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  • Restart your AI tool to pick up the new profiles"
echo "  • See docs/PROFILES.md for per-tool configuration details"
echo "  • Run scripts/validate-skills.sh to verify the toolkit is intact"
