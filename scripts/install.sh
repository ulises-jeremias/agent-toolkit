#!/usr/bin/env bash
# install.sh — Install agent-toolkit profiles for detected AI coding assistants
#
# Usage:
#   bash scripts/install.sh [options]
#
# Options:
#   --tools <list>  Comma-separated list of tools to install (default: auto-detect)
#                   Valid: claude-code, cursor, opencode, copilot, windsurf, pi
#   --dry-run       Print what would be installed without making any changes
#   --force         Overwrite existing files without prompting
#   --help          Show this help message
#
# Examples:
#   bash scripts/install.sh
#   bash scripts/install.sh --tools claude-code,cursor
#   bash scripts/install.sh --dry-run
#   bash scripts/install.sh --force
set -euo pipefail

# --- Deprecation notice (ADR-007) ---
# Primary install is now the Python CLI: `uvx --from agent-toolkit-cli agent-toolkit install`
# This script is kept as a legacy/offline fallback and will be removed in v2.0.
# It may delegate to `agent-toolkit install` when available (thin wrapper).
if [[ -z "${AGENT_TOOLKIT_NO_DEPRECATION_WARNING:-}" ]]; then
  printf '  [warn]  scripts/install.sh is deprecated — use `uvx --from agent-toolkit-cli agent-toolkit install` (see docs/INSTALLATION.md and docs/adrs/ADR-007-install-sh-deprecation.md)\n' >&2
fi

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

FORCE=false
DRY_RUN=false
REQUESTED_TOOLS=""

declare -a INSTALLED_TOOLS=()
declare -a SKIPPED_TOOLS=()
declare -a FAILED_TOOLS=()

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

info()    { printf '  [info]  %s\n' "$*"; }
ok()      { printf '  [ok]    %s\n' "$*"; }
warn()    { printf '  [warn]  %s\n' "$*"; }
skip_()   { printf '  [-]     %s\n' "$*"; }
dry()     { printf '  [dry]   %s\n' "$*"; }
die()     { printf '  [error] %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

usage() {
  sed -n 's/^# \{0,1\}//p' "${BASH_SOURCE[0]}" | head -20
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tools)
        [[ $# -ge 2 ]] || die "--tools requires an argument"
        REQUESTED_TOOLS="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1. Run with --help for usage."
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# File operations
# ---------------------------------------------------------------------------

# confirm "message" — prompts user; returns 0 (yes) or 1 (no)
confirm() {
  local msg="$1"
  if [[ "$FORCE" == "true" ]]; then
    return 0
  fi
  printf '  %s [y/N] ' "$msg"
  local answer
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# copy_file SRC DST — copy SRC to DST, respecting --dry-run, --force, and idempotency
copy_file() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    warn "Source not found, skipping: $src"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    dry "Would copy: $(basename "$src") -> $dst"
    return
  fi

  # Idempotency check: skip if files are identical
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    skip_ "Already up to date: $dst"
    return
  fi

  if [[ -f "$dst" ]] && [[ "$FORCE" != "true" ]]; then
    if ! confirm "Overwrite existing file: $dst?"; then
      skip_ "Skipped: $dst"
      return
    fi
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  ok "Installed: $dst"
}

# copy_dir SRC_DIR DST_DIR — copy all files in SRC_DIR into DST_DIR (recursive)
copy_dir() {
  local src_dir="$1"
  local dst_dir="$2"

  if [[ ! -d "$src_dir" ]]; then
    warn "Source directory not found, skipping: $src_dir"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    local count
    count=$(find "$src_dir" -type f | wc -l | tr -d ' ')
    dry "Would copy ${count} file(s) from $(basename "$src_dir") -> $dst_dir/"
    return
  fi

  mkdir -p "$dst_dir"

  while IFS= read -r -d '' src_file; do
    local rel="${src_file#${src_dir}/}"
    copy_file "$src_file" "${dst_dir}/${rel}"
  done < <(find "$src_dir" -type f -print0)
}

# ---------------------------------------------------------------------------
# Tool detection
# ---------------------------------------------------------------------------

detect_claude_code() {
  command -v claude &>/dev/null || [[ -d "${HOME}/.claude" ]]
}

detect_cursor() {
  command -v cursor &>/dev/null || [[ -d "${HOME}/.cursor" ]]
}

detect_opencode() {
  command -v opencode &>/dev/null || [[ -d "${HOME}/.config/opencode" ]]
}

detect_windsurf() {
  command -v windsurf &>/dev/null || \
    [[ -d "${HOME}/.codeium/windsurf" ]] || \
    [[ -d "${HOME}/.windsurf" ]]
}

detect_pi() {
  command -v pi &>/dev/null || [[ -d "${HOME}/.pi" ]]
}

windsurf_config_dir() {
  if [[ -d "${HOME}/.codeium/windsurf" ]]; then
    echo "${HOME}/.codeium/windsurf"
  elif [[ -d "${HOME}/.windsurf" ]]; then
    echo "${HOME}/.windsurf"
  else
    echo "${HOME}/.codeium/windsurf"
  fi
}

# ---------------------------------------------------------------------------
# Per-tool installers
# ---------------------------------------------------------------------------

install_claude_code() {
  echo ""
  info "Installing: Claude Code"
  local src="${TOOLKIT_DIR}/profiles/claude-code"

  if [[ ! -d "$src" ]]; then
    warn "Profile directory not found: $src"
    SKIPPED_TOOLS+=("claude-code")
    return
  fi

  copy_file "${src}/CLAUDE.md"     "${HOME}/.claude/CLAUDE.md"
  # Never overwrite ~/.claude/settings.json — user-owned (plugins/permissions).
  # Toolkit capabilities install via marketplace plugins, not global settings.
  info "Skipping ~/.claude/settings.json (user-owned)"

  if [[ -d "${src}/agents" ]]; then
    copy_dir "${src}/agents" "${HOME}/.claude/agents"
  fi

  INSTALLED_TOOLS+=("claude-code")
}

install_cursor() {
  echo ""
  info "Installing: Cursor"
  local src="${TOOLKIT_DIR}/profiles/cursor/rules"

  if [[ ! -d "$src" ]]; then
    warn "Cursor rules directory not found: $src"
    SKIPPED_TOOLS+=("cursor")
    return
  fi

  copy_dir "$src" "${HOME}/.cursor/rules"
  INSTALLED_TOOLS+=("cursor")
}

install_opencode() {
  echo ""
  info "Installing: OpenCode"
  local src="${TOOLKIT_DIR}/profiles/opencode"

  if [[ ! -d "$src" ]]; then
    warn "OpenCode profile directory not found: $src"
    SKIPPED_TOOLS+=("opencode")
    return
  fi

  copy_file "${src}/opencode.json" "${HOME}/.config/opencode/opencode.json"

  if [[ -d "${src}/agents" ]]; then
    copy_dir "${src}/agents" "${HOME}/.config/opencode/agents"
  fi

  INSTALLED_TOOLS+=("opencode")
}

install_copilot() {
  echo ""
  info "Installing: GitHub Copilot"
  info "Copilot instructions are per-project and committed to the repository."

  local src="${TOOLKIT_DIR}/profiles/copilot/copilot-instructions.md"
  if [[ ! -f "$src" ]]; then
    warn "Copilot instructions not found: $src"
    SKIPPED_TOOLS+=("copilot")
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    dry "Would copy copilot-instructions.md to <project>/.github/"
    INSTALLED_TOOLS+=("copilot")
    return
  fi

  printf '  Enter project directory path (or press Enter to skip): '
  local project_dir
  read -r project_dir

  if [[ -z "$project_dir" ]]; then
    skip_ "No project directory specified — skipping Copilot install"
    info "To install manually: cp ${src} <your-project>/.github/copilot-instructions.md"
    SKIPPED_TOOLS+=("copilot")
    return
  fi

  # Expand tilde
  project_dir="${project_dir/#\~/${HOME}}"

  if [[ ! -d "$project_dir" ]]; then
    warn "Directory not found: $project_dir"
    SKIPPED_TOOLS+=("copilot")
    return
  fi

  copy_file "$src" "${project_dir}/.github/copilot-instructions.md"
  info "Remember to: git add .github/copilot-instructions.md && git commit"
  INSTALLED_TOOLS+=("copilot")
}

install_windsurf() {
  echo ""
  info "Installing: Windsurf"
  local src="${TOOLKIT_DIR}/profiles/windsurf"

  if [[ ! -d "$src" ]]; then
    warn "Windsurf profile directory not found: $src"
    SKIPPED_TOOLS+=("windsurf")
    return
  fi

  local config_dir
  config_dir="$(windsurf_config_dir)"

  if [[ -d "${src}/rules" ]]; then
    copy_dir "${src}/rules" "${config_dir}/rules"
  fi

  if [[ -d "${src}/memories" ]]; then
    copy_dir "${src}/memories" "${config_dir}/memories"
  fi

  INSTALLED_TOOLS+=("windsurf")
}

install_pi() {
  echo ""
  info "Installing: Pi Coding Agent"
  local src="${TOOLKIT_DIR}/profiles/pi/skills"

  if [[ ! -d "$src" ]]; then
    warn "Pi skills directory not found: $src"
    SKIPPED_TOOLS+=("pi")
    return
  fi

  copy_dir "$src" "${HOME}/.pi/agent/skills"
  INSTALLED_TOOLS+=("pi")
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"

  echo ""
  echo "agent-toolkit installer"
  echo "Toolkit: ${TOOLKIT_DIR}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    warn "DRY RUN — no files will be written"
  fi

  # Determine which tools to install
  local -a tools_to_install=()

  if [[ -n "$REQUESTED_TOOLS" ]]; then
    IFS=',' read -ra tools_to_install <<< "$REQUESTED_TOOLS"
  else
    echo ""
    info "Auto-detecting installed AI tools..."

    detect_claude_code && tools_to_install+=("claude-code") && info "  Detected: Claude Code"
    detect_cursor      && tools_to_install+=("cursor")      && info "  Detected: Cursor"
    detect_opencode    && tools_to_install+=("opencode")    && info "  Detected: OpenCode"
    detect_windsurf    && tools_to_install+=("windsurf")    && info "  Detected: Windsurf"
    detect_pi          && tools_to_install+=("pi")          && info "  Detected: Pi Coding Agent"

    # Copilot requires user input (per-project, can't auto-detect)
    echo ""
    if confirm "Install GitHub Copilot instructions for a project?"; then
      tools_to_install+=("copilot")
    fi

    if [[ ${#tools_to_install[@]} -eq 0 ]]; then
      warn "No AI tools detected. Install at least one supported tool and re-run,"
      warn "or specify with: --tools claude-code,cursor,opencode,copilot,windsurf,pi"
      exit 1
    fi
  fi

  echo ""
  info "Tools to install: ${tools_to_install[*]}"

  # Install each requested tool
  for tool in "${tools_to_install[@]}"; do
    case "$tool" in
      claude-code) install_claude_code ;;
      cursor)      install_cursor ;;
      opencode)    install_opencode ;;
      copilot)     install_copilot ;;
      windsurf)    install_windsurf ;;
      pi)          install_pi ;;
      *)
        warn "Unknown tool: $tool (valid: claude-code, cursor, opencode, copilot, windsurf, pi)"
        SKIPPED_TOOLS+=("$tool")
        ;;
    esac
  done

  # Summary
  echo ""
  echo "----------------------------------------------------------------------"
  echo "Installation summary"

  if [[ ${#INSTALLED_TOOLS[@]} -gt 0 ]]; then
    ok "Installed: ${INSTALLED_TOOLS[*]}"
  fi

  if [[ ${#SKIPPED_TOOLS[@]} -gt 0 ]]; then
    skip_ "Skipped:   ${SKIPPED_TOOLS[*]}"
  fi

  echo ""
  info "Next steps:"
  info "  1. Restart your AI tool(s) to load the new profiles"
  info "  2. Run 'bash scripts/validate-skills.sh' to verify the toolkit"
  info "  3. See docs/MCP.md to configure external service integrations"
  info "  4. See docs/PROFILES.md for per-tool customization options"
  echo ""
}

main "$@"
