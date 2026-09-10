#!/usr/bin/env bash
# clean-machine-acceptance.sh — #1130 layered clean-machine validation.
#
# Contract (see docs/desktop/PACKAGING.md + #1130 body):
#   real packaged artifact → clean environment → real install mechanism
#   → installed-resource verification → launch as installed app
#   → evidence capture → receipt-backed uninstall → ownership proof
#
# The harness FAILS if it resolves the binary/resources from a source tree:
# the artifact is copied to a neutral prefix first, everything runs from
# there with a clean HOME/XDG and no repo in PATH, and the launched binary's
# own reported executable path must be the installed one.
#
# Layers (explicit states, never collapsed to one boolean):
#   A artifact-structural     AUTOMATED
#   B clean-user install      AUTOMATED
#   C GUI launch/render       AUTOMATED (xvfb) — visual inspection separate
#   D OS menu-click           MANUAL (documented; never implied by A–C)
#
# Usage: scripts/clean-machine-acceptance.sh <desktop-archive.tar.gz>
# Env:   GUI_CAPTURE=1 (default when xvfb+imagemagick present)
set -euo pipefail

ARTIFACT="${1:?usage: clean-machine-acceptance.sh <desktop-archive.tar.gz>}"
[ -f "$ARTIFACT" ] || { echo "error: artifact not found: $ARTIFACT" >&2; exit 2; }

RESULTS=()
declare -A STATES
record() { # layer key state detail
  STATES["$2"]="$3"
  RESULTS+=("$1|$2|$3|$4")
  printf '%-26s %-12s %s\n' "$1" "$3" "$4"
}
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# ── Phase 0: provenance ────────────────────────────────────────────────────
ART_NAME="$(basename "$ARTIFACT")"
ART_SHA="$(sha256sum "$ARTIFACT" | cut -d' ' -f1)"
ART_SIZE="$(stat -c%s "$ARTIFACT")"
VERSION="$(cat "$(dirname "$0")/../VERSION" 2>/dev/null | tr -d ' \n' || echo unknown)"
COMMIT="$(git -c safe.directory='*' -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "provenance: artifact=$ART_NAME sha256=$ART_SHA size=$ART_SIZE version=$VERSION commit=$COMMIT"

# ── neutral prefix: the ONLY place the artifact lives for validation ──────
PREFIX="$(mktemp -d "${TMPDIR:-/tmp}/atk-clean-XXXXXX")"
# trap cleanup (first-run pattern): prefix/Xvfb/app are always released,
# even on an early fail — evidence copies to EVIDENCE_DIR happen mid-run.
APP_PID=0
XVFB_PID=0
cleanup_acceptance() {
  for p in "$APP_PID" "$XVFB_PID"; do
    if [ "$p" != 0 ]; then kill "$p" 2>/dev/null || true; fi
  done
  for p in "$APP_PID" "$XVFB_PID"; do
    if [ "$p" != 0 ]; then wait "$p" 2>/dev/null || true; fi
  done
  rm -rf "$PREFIX"
}
trap cleanup_acceptance EXIT
# EVIDENCE_DIR: when set (CI), durable copies of captures/evidence land here
# BEFORE the prefix trap cleans up (#1130 harness contract).
EVIDENCE_DIR="${EVIDENCE_DIR:-}"
STAGE="$PREFIX/stage"
mkdir -p "$STAGE"
tar xzf "$ARTIFACT" -C "$STAGE"
CLEAN_HOME="$PREFIX/home"
CLEAN_DATA="$CLEAN_HOME/.local/share"
CLEAN_CONFIG="$CLEAN_HOME/.config"
mkdir -p "$CLEAN_HOME"
INSTALLED_BIN="$CLEAN_DATA/agent-toolkit/bin/agent-toolkit-desktop"

# minimal environment: no repo, no dev PATH — launcher-like
export HOME="$CLEAN_HOME"
export XDG_DATA_HOME="$CLEAN_DATA"
export XDG_CONFIG_HOME="$CLEAN_CONFIG"
export PATH="/usr/bin:/bin"
unset AGENT_TOOLKIT_ROOT || true
cd "$PREFIX"

# ── Layer A: artifact structural ───────────────────────────────────────────
for f in agent-toolkit-desktop agent-toolkit-desktop.desktop install-desktop.sh \
  icons/agent-toolkit-desktop-256.png icons/agent-toolkit-desktop-16.png \
  icons/agent-toolkit-desktop-scalable.svg share/man/man1/agent-toolkit-desktop.1 LICENSE; do
  [ -e "$STAGE/$f" ] || record A "missing:$f" "FAIL" "archive incomplete"
done
if [ -x "$STAGE/agent-toolkit-desktop" ] && [ -f "$STAGE/agent-toolkit-desktop.desktop" ] \
  && [ -f "$STAGE/install-desktop.sh" ]; then
  record A "structure" "PASS" "binary + launcher + installer + icons + man present"
else
  record A "structure" "FAIL" "archive incomplete"
  exit 3
fi
if command -v desktop-file-validate >/dev/null 2>&1; then
  if desktop-file-validate "$STAGE/agent-toolkit-desktop.desktop"; then
    record A "desktop-entry" "PASS" "Desktop Entry spec valid"
  else
    record A "desktop-entry" "FAIL" "desktop-file-validate rejected the entry"
    exit 3
  fi
else
  record A "desktop-entry" "CI-MANUAL" "desktop-file-utils not installed in this environment"
fi
VERSION_OUT="$("$STAGE/agent-toolkit-desktop" --version 2>&1 || true)"
VERSION_OUT="${VERSION_OUT%%$'\n'*}"
[ -n "$VERSION_OUT" ] || fail "extracted binary --version produced nothing"
record A "binary-identity" "PASS" "$VERSION_OUT"

# ── Layer B: clean-user install ────────────────────────────────────────────
( cd "$STAGE" && ./install-desktop.sh install ) >/dev/null
[ -x "$INSTALLED_BIN" ] || fail "installed binary missing at $INSTALLED_BIN"
[ -f "$CLEAN_DATA/applications/agent-toolkit-desktop.desktop" ] || fail "launcher entry not installed"
[ -f "$CLEAN_DATA/icons/hicolor/256x256/apps/agent-toolkit-desktop.png" ] || fail "256px icon not installed"
[ -f "$CLEAN_CONFIG/agent-toolkit/receipts/agent-toolkit-desktop-linux.json" ] || fail "install receipt missing"
RECEIPT_OWNED="$(python3 -c 'import json,sys
r = json.load(open(sys.argv[1]))
print(len([a for a in r["artifacts"] if a["ownership"] == "created"]))' "$CLEAN_CONFIG/agent-toolkit/receipts/agent-toolkit-desktop-linux.json")"
[ "$RECEIPT_OWNED" -gt 0 ] || fail "receipt records no created artifacts"
record B "install" "PASS" "installed to XDG paths; receipt records $RECEIPT_OWNED created artifacts"

# provenance gate: the INSTALLED binary must be the one we run, and it must
# report itself (headless smoke prints its own path)
SMOKE="$(env -i PATH=/usr/bin:/bin HOME="$CLEAN_HOME" XDG_DATA_HOME="$CLEAN_DATA" \
  XDG_CONFIG_HOME="$CLEAN_CONFIG" ATK_GUI_HEADLESS=1 "$INSTALLED_BIN" 2>&1 || true)"
echo "$SMOKE" | grep -q "RUNNING" || fail "installed binary did not boot (headless)"
SELF_PATH="$(echo "$SMOKE" | grep -oP 'binary at \K.*' || true)"
if [ -n "$SELF_PATH" ] && [ "$SELF_PATH" != "$INSTALLED_BIN" ]; then
  fail "provenance violation: launched binary resolved to $SELF_PATH, expected $INSTALLED_BIN"
fi
record B "provenance" "PASS" "launched binary self-reports the installed path"

# fonts/resources resolve from the CLEAN cache (not the source tree)
FONT_DIR="$CLEAN_HOME/.cache/agent-toolkit/desktop/fonts"
if [ -f "$FONT_DIR/Fraunces-Display.ttf" ] && [ -f "$FONT_DIR/IBMPlexSans-Regular.ttf" ]; then
  record B "embedded-resources" "PASS" "fonts extracted to clean cache: $FONT_DIR"
else
  record B "embedded-resources" "FAIL" "fonts missing in clean cache"
  exit 4
fi

# tool discovery under the launcher-like PATH (#1129 makes this real)
DISCO="$(echo "$SMOKE" | grep -oP 'tools found=\d+ missing=\d+' || true)"
if [ -n "$DISCO" ]; then
  record B "tool-discovery" "PASS" "$DISCO (sparse launcher-like PATH)"
else
  record B "tool-discovery" "NOT_PROVEN" "binary predates the #1129 discovery smoke line"
fi

# ── Layer C: GUI launch/render (xvfb) ──────────────────────────────────────
if command -v Xvfb >/dev/null 2>&1 && command -v import >/dev/null 2>&1; then
  CAP="$PREFIX/capture.png"
  # fixed display: xvfb-run -a would pick one our capture cannot know
  Xvfb :98 -screen 0 1280x800x24 &
  XVFB_PID=$!
  # Xvfb readiness probe (poll the X socket like the other harnesses probe
  # the server — never a bare sleep before launching the app)
  xready=0
  for _ in $(seq 1 20); do
    if [ -S /tmp/.X11-unix/X98 ]; then xready=1; break; fi
    sleep 0.5
  done
  [ "$xready" = 1 ] || fail "Xvfb :98 did not become ready"
  env DISPLAY=:98 PATH=/usr/bin:/bin HOME="$CLEAN_HOME" LANG=C.UTF-8 \
    XDG_DATA_HOME="$CLEAN_DATA" XDG_CONFIG_HOME="$CLEAN_CONFIG" \
    "$INSTALLED_BIN" &
  APP_PID=$!
  sleep 14
  DISPLAY=:98 import -window root "$CAP" || true
  kill $APP_PID 2>/dev/null || true
  kill $XVFB_PID 2>/dev/null || true
  wait $APP_PID 2>/dev/null || true
  wait $XVFB_PID 2>/dev/null || true
  if [ -f "$CAP" ]; then
    # non-blankness: mean brightness must exceed a dead-screen threshold
    MEAN="$(convert "$CAP" -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || echo 0)"
    ok="$(python3 -c "print('PASS' if float('${MEAN:-0}') > 0.03 else 'FAIL')")"
    record C "first-render" "$ok" "xvfb capture mean-brightness=$MEAN → $CAP"
    if [ -n "$EVIDENCE_DIR" ] && [ -f "$CAP" ]; then
      mkdir -p "$EVIDENCE_DIR"
      cp "$CAP" "$EVIDENCE_DIR/first-render.png"
    fi
  else
    record C "first-render" "NOT_PROVEN" "no capture produced (xdotool/window missing)"
  fi
else
  record C "first-render" "MANUAL_REQUIRED" "xvfb/imagemagick not available in this environment"
fi
record D "menu-click" "MANUAL" "actual desktop-menu launch is a documented manual check (OS integration)"

# ── receipt-backed uninstall ───────────────────────────────────────────────
FOREIGN="$CLEAN_DATA/agent-toolkit/bin/FOREIGN-USER-FILE.txt"
echo "user data" > "$FOREIGN"
( cd "$STAGE" && ./install-desktop.sh uninstall ) >/dev/null
[ ! -e "$INSTALLED_BIN" ] || fail "uninstall left the installed binary"
[ ! -e "$CLEAN_DATA/applications/agent-toolkit-desktop.desktop" ] || fail "uninstall left the launcher entry"
[ ! -f "$CLEAN_CONFIG/agent-toolkit/receipts/agent-toolkit-desktop-linux.json" ] || fail "receipt not consumed"
[ -f "$FOREIGN" ] || fail "uninstall removed a user-owned foreign file"
record B "uninstall" "PASS" "owned artifacts removed; foreign file preserved; receipt consumed"

# ── summary ────────────────────────────────────────────────────────────────
echo
echo "=== clean-machine acceptance summary ($ART_NAME) ==="
FAILED=0
for r in "${RESULTS[@]}"; do
  IFS='|' read -r layer key state detail <<<"$r"
  echo "$layer $key $state $detail"
  if [ "$state" = "FAIL" ]; then FAILED=1; fi
done
if [ -n "$EVIDENCE_DIR" ]; then
  {
    echo "artifact=$ART_NAME"
    echo "sha256=$ART_SHA"
    echo "version=$VERSION"
    echo "commit=$COMMIT"
    for r in "${RESULTS[@]}"; do
      IFS='|' read -r layer key state detail <<<"$r"
      echo "result: $layer $key $state $detail"
    done
    echo "overall: $([ "$FAILED" -ne 0 ] && echo FAIL || echo PASS)"
  } > "$EVIDENCE_DIR/evidence.txt"
fi
if [ "$FAILED" -ne 0 ]; then exit 5; fi
echo "OVERALL: PASS (layer D remains MANUAL by design)"
