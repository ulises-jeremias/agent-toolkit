#!/usr/bin/env bash
# install-desktop.sh — install/uninstall Agent Toolkit Desktop from the
# release archive into XDG user locations (#1057/#1116, #1130 vertical).
#
# install:   ./install-desktop.sh install
# uninstall: ./install-desktop.sh uninstall
#
# XDG-compliant, no sudo:
#   binary  → ${XDG_DATA_HOME:-~/.local/share}/agent-toolkit/bin
#   desktop → ${XDG_DATA_HOME:-~/.local/share}/applications
#   icons   → ${XDG_DATA_HOME:-~/.local/share}/icons/hicolor/<size>/apps
#   man     → ${XDG_DATA_HOME:-~/.local/share}/man/man1
#   receipt → ${XDG_CONFIG_HOME:-~/.config}/agent-toolkit/receipts
#
# Ownership follows the product's install-receipt semantics (schemaVersion 1):
# 'created' files are removed on uninstall; 'merged' files (pre-existing at
# the destination before this install) are NEVER removed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PRODUCT="agent-toolkit-desktop"
TARGET="linux"
SCHEMA_VERSION=1

XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="$XDG_DATA/agent-toolkit/bin"
RECEIPT_DIR="$XDG_CONFIG/agent-toolkit/receipts"
RECEIPT="$RECEIPT_DIR/${PRODUCT}-${TARGET}.json"
DESKTOP_SRC="$HERE/${PRODUCT}.desktop"

need_file() { [ -f "$1" ] || { echo "error: missing $1 (run from the extracted archive)" >&2; exit 2; }; }

sha256_of() { sha256sum "$1" | cut -d' ' -f1; }

record_artifact() { # path ownership
  printf '"%s|%s"\n' "$1" "$2"
}

install_desktop() {
  need_file "$HERE/$PRODUCT"
  need_file "$DESKTOP_SRC"
  need_file "$HERE/install-desktop.sh"
  [ -d "$HERE/icons" ] || { echo "error: missing icons/ directory" >&2; exit 2; }
  [ -f "$HERE/share/man/man1/${PRODUCT}.1" ] || { echo "error: missing man page" >&2; exit 2; }

  mkdir -p "$BIN_DIR" "$XDG_DATA/applications" "$RECEIPT_DIR" \
    "$XDG_DATA/icons/hicolor/scalable/apps" "$XDG_DATA/man/man1"

  local manifest=()
  install_one() { # src dst
    local src="$1" dst="$2"
    local ownership="created"
    if [ -e "$dst" ]; then
      ownership="merged" # pre-existing file — recorded, never removed
    fi
    install -m 755 "$src" "$dst"
    manifest+=("$(record_artifact "$dst" "$ownership")")
  }
  install_one "$HERE/$PRODUCT" "$BIN_DIR/$PRODUCT"
  install_one "$HERE/install-desktop.sh" "$BIN_DIR/${PRODUCT}-installer.sh"

  install -m 644 "$DESKTOP_SRC" "$XDG_DATA/applications/${PRODUCT}.desktop"
  manifest+=("$(record_artifact "$XDG_DATA/applications/${PRODUCT}.desktop" "created")")

  # point Exec= at the installed binary: launcher sessions may not have
  # ~/.local/bin on PATH (#1129 context)
  local desktop_dst="$XDG_DATA/applications/${PRODUCT}.desktop"
  sed -i "s|^Exec=.*|Exec=$BIN_DIR/$PRODUCT|" "$desktop_dst"

  for size in 16 24 32 48 64 128 256 512; do
    local dir="$XDG_DATA/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$dir"
    install_one "$HERE/icons/${PRODUCT}-${size}.png" "$dir/${PRODUCT}.png"
  done
  local svg_dir="$XDG_DATA/icons/hicolor/scalable/apps"
  install_one "$HERE/icons/${PRODUCT}-scalable.svg" "$svg_dir/${PRODUCT}-scalable.svg"
  install_one "$HERE/share/man/man1/${PRODUCT}.1" "$XDG_DATA/man/man1/${PRODUCT}.1"

  local version="unknown"
  if [ -f "$HERE/VERSION" ]; then version="$(cat "$HERE/VERSION" | tr -d ' \n')"; fi
  local digest="none"
  if command -v sha256sum >/dev/null 2>&1; then digest="$(sha256_of "$HERE/$PRODUCT")"; fi
  local installed_at
  installed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local artifacts
  artifacts="$(printf '%s\n' "${manifest[@]}" | sed 's/^/    /' | paste -sd, -)"
  # core InstallReceipt schema (camelCase, schemaVersion 1) — ownership-aware
  cat > "$RECEIPT" <<JSON
{
  "schemaVersion": $SCHEMA_VERSION,
  "product": "$PRODUCT",
  "target": "$TARGET",
  "scope": "user",
  "version": "$version",
  "installedAt": "$installed_at",
  "sourceDigest": "$digest",
  "artifacts": [
$(printf '%s\n' "${manifest[@]}" | sed 's/^"//; s/"$//' | awk -F'|' '{printf "    {\"path\": \"%s\", \"digest\": \"\", \"ownership\": \"%s\"},", $1, $2}' | sed 's/,$//')
  ],
  "configPatches": [],
  "secrets": []
}
JSON
  echo "receipt: $RECEIPT"

  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$XDG_DATA/applications" || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q "$XDG_DATA/icons/hicolor" || true
  echo "installed: $BIN_DIR/$PRODUCT"
  echo "launcher:  $desktop_dst (menu entry; icon installed for all hicolor sizes)"
}

uninstall_desktop() {
  [ -f "$RECEIPT" ] || { echo "no install receipt at $RECEIPT — nothing to uninstall" >&2; exit 3; }
  # remove only 'created' artifacts; 'merged' (pre-existing) files are kept
  python3 - "$RECEIPT" <<'PY'
import json, sys, os
r = json.load(open(sys.argv[1]))
removed = kept = 0
for a in r.get("artifacts", []):
    p = a.get("path", "")
    if a.get("ownership") == "created" and os.path.isfile(p):
        os.remove(p)
        removed += 1
        d = os.path.dirname(p)
        try:
            if not os.listdir(d):
                os.rmdir(d)
        except OSError:
            pass
    else:
        kept += 1
print(f"removed {removed} owned file(s); preserved {kept} pre-existing")
PY
  rm -f "$RECEIPT"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$XDG_DATA/applications" || true
  echo "uninstalled: launcher entry, icons, man page and binary (receipt-backed)"
}

case "${1:-install}" in
  install) install_desktop ;;
  uninstall) uninstall_desktop ;;
  *) echo "usage: $0 [install|uninstall]" >&2; exit 1 ;;
esac
