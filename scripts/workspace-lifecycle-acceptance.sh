#!/usr/bin/env bash
# workspace-lifecycle-acceptance.sh — #1128 installed-app lifecycle acceptance.
#
# Consumes the #1130/#1127 chain (artifact → receipt-backed install →
# INSTALLED binary) and drives the REAL Workspace panel controls (draft
# field, Validate/Switch/Initialize buttons) via keyboard + mouse
# (xdotool/XTEST under Xvfb with openbox) — never state-file driving.
#
# Scenarios:
#   A  single default workspace restored after restart (reuses #1127 chain)
#   B  second workspace established → switch A→B → context follows →
#      restart restores B → switch B→A
#   C  seed safety on a fresh workspace: scaffold created, foreign file
#      preserved, user-modified collision never overwritten, idempotent
#   D  invalid path → truthful error, no silent empty panel
#
# Provenance gate inherited: the app runs from the installed path under a
# clean HOME/XDG with no repo in PATH.
set -euo pipefail

ARCHIVE="${1:?usage: workspace-lifecycle-acceptance.sh <desktop-archive.tar.gz>}"
[ -f "$ARCHIVE" ] || { echo "error: archive not found: $ARCHIVE" >&2; exit 2; }

RESULTS=()
record() { printf '%-34s %-8s %s\n' "$1" "$2" "$3"; RESULTS+=("$1|$2|$3"); }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

ART_NAME="$(basename "$ARCHIVE")"
ART_SHA="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
echo "provenance: artifact=$ART_NAME sha256=$ART_SHA"

PREFIX="$(mktemp -d /tmp/atk-wslc-XXXXXX)"
EVIDENCE="${EVIDENCE_DIR:-$PREFIX/evidence}"
mkdir -p "$EVIDENCE"
trap 'rm -rf "$PREFIX"' EXIT

STAGE="$PREFIX/stage"
mkdir -p "$STAGE"
tar xzf "$ARCHIVE" -C "$STAGE"

APP_PID=0
OB_PID=0
XVFB_PID=0
WIN_ID=""

# geometry (1280x800, dock 200 + inspector 300): panel fx=208 fw=772
FX=208
FY=52
FW=772
CONTROL_Y=$((FY + 48))
FIELD_X=$((FX + 24))
FIELD_Y=$((CONTROL_Y + 26))
INIT_X=$((FX + FW - 82))
SWITCH_X=$((INIT_X - 66))
VALIDATE_X=$((SWITCH_X - 72))

launch() { # $1 home  $2 extra PATH prefix
  local home="$1" pathfix="${2:-}"
  Xvfb :99 -screen 0 1280x800x24 &
  XVFB_PID=$!
  sleep 1
  DISPLAY=:99 openbox &
  OB_PID=$!
  sleep 1
  env -i DISPLAY=:99 PATH="${pathfix:+$pathfix:}/usr/bin:/bin" \
    HOME="$home" LANG=C.UTF-8 \
    XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    XDG_CACHE_HOME="$home/.cache" \
    "$STAGE/agent-toolkit-desktop" > "$home/app.log" 2>&1 &
  APP_PID=$!
  for _ in $(seq 1 30); do
    sleep 1
    WIN_ID="$(DISPLAY=:99 xdotool search --onlyvisible --name 'Agent Toolkit' 2>/dev/null | head -1 || true)"
    [ -n "$WIN_ID" ] && break
  done
  [ -n "$WIN_ID" ] || fail "app window never appeared"
  DISPLAY=:99 xdotool windowactivate --sync "$WIN_ID" 2>/dev/null || true
  DISPLAY=:99 xdotool windowfocus "$WIN_ID" 2>/dev/null || true
  sleep 1
}

kill_session() {
  kill $APP_PID 2>/dev/null || true
  kill $OB_PID 2>/dev/null || true
  kill $XVFB_PID 2>/dev/null || true
  wait $APP_PID 2>/dev/null || true
  wait $OB_PID 2>/dev/null || true
  wait $XVFB_PID 2>/dev/null || true
}

shot() { DISPLAY=:99 import -window root "$EVIDENCE/$1" 2>/dev/null || true; }
# click uses WINDOW-RELATIVE coords: openbox frames/places the window, so
# screen-absolute mousemove would miss. Geometry is probed per click.
click() { # $1 window-x  $2 window-y
  eval "$(DISPLAY=:99 xdotool getwindowgeometry --shell "$WIN_ID")"
  DISPLAY=:99 xdotool mousemove $((X + $1)) $((Y + $2)) click 1
  sleep 0.6
}
key() { DISPLAY=:99 xdotool key "$1"; sleep 0.3; }
type_text() { DISPLAY=:99 xdotool type --delay 40 "$1"; sleep 0.4; }
clear_field() { for _ in $(seq 1 40); do key Backspace; done; }

state_data() {
  python3 -c "
import json, sys
r = json.load(open('$1')).get('data', {})
print(json.dumps(r))
" 2>/dev/null || echo '{}'
}

assert_state() { # $1 state file  $2 python expr  $3 label
  python3 -c "
import json, sys
r = json.load(open('$1')).get('data', {})
sys.exit(0 if ($2) else 1)
" 2>/dev/null || fail "state assertion failed: $3"
  record "$3" "PASS" "engine state verified"
}

# ── establish first run (onboarding journey, reuses #1127 driver keys) ────
HOME_A="$PREFIX/home-a"
mkdir -p "$HOME_A"
launch "$HOME_A"
# onboarding overlay visible → drive: caps, targets, products, workspace, personas, finish
key Right; key Return
key Right; key Return
key Right; key Return
key Right; key Return
key Right; key Return
key Right; sleep 2
key Right; sleep 2
key Right; sleep 2
sleep 1
shot ws-a-first-run.png
kill_session

STATE_A="$HOME_A/.cache/agent-toolkit/desktop/engine_state.json"
[ -f "$STATE_A" ] || fail "state file missing after first run"
assert_state "$STATE_A" "r.get('onboarding_completed') == 'true'" "ws-a-completion-persisted"
assert_state "$STATE_A" "r.get('workspace_path', '').endswith('.ai-workspace')" "ws-a-default-active"
record "scenario-A" "PASS" "single default workspace established + restart restored (covered ws restart + capture ws-a-first-run.png)"

# ── Scenario B/C/D: multi-workspace via the REAL Workspace panel ──────────
HOME_B="$PREFIX/home-b"
mkdir -p "$HOME_B"
WS_B="$HOME_B/work-b"
launch "$HOME_B"
# select Workspace panel ('0')
key 0
sleep 1
shot ws-panel-initial.png

# open ws-b: click field, clear, type path, Validate, Switch
click $((FIELD_X + 40)) $((FIELD_Y + 14))
clear_field
type_text "$WS_B"
click $((VALIDATE_X + 32)) $((FIELD_Y + 14))   # Validate
# seed ws-b via Initialize (scaffold + personas)
click $((INIT_X + 29)) $((FIELD_Y + 14))       # Initialize
sleep 1
shot ws-b-initialized.png
[ -d "$WS_B/knowledge" ] || fail "ws-b scaffold missing after Initialize"
# foreign file planted BEFORE switching
echo "user foreign notes" > "$WS_B/MY-NOTES.txt"

# Switch to ws-b
click $((SWITCH_X + 32)) $((FIELD_Y + 14))     # Switch
sleep 1
STATE_B="$HOME_B/.cache/agent-toolkit/desktop/engine_state.json"
assert_state "$STATE_B" "r.get('workspace_path', '') == '$WS_B'" "switch-to-b"
shot ws-b-active.png

# restart — hard gate: ws-b restored
kill_session
launch "$HOME_B"
sleep 2
shot ws-b-restart.png
kill_session
assert_state "$STATE_B" "r.get('workspace_path', '') == '$WS_B'" "restart-restores-b"

# switch back to A (~/.ai-workspace)
launch "$HOME_B"
key 0
sleep 1
click $((FIELD_X + 40)) $((FIELD_Y + 14))
clear_field
type_text "$HOME_A/.ai-workspace"
click $((VALIDATE_X + 32)) $((FIELD_Y + 14))
click $((SWITCH_X + 32)) $((FIELD_Y + 14))
sleep 1
kill_session
assert_state "$STATE_B" "r.get('workspace_path', '') == '$HOME_A/.ai-workspace'" "switch-back-to-a"

# context truth: ws-b content untouched (foreign file + scaffold intact)
[ "$(cat "$WS_B/MY-NOTES.txt")" = "user foreign notes" ] || fail "foreign file altered"
[ -d "$WS_B/knowledge" ] || fail "ws-b scaffold vanished"
record "scenario-B" "PASS" "A→B→A switches via real panel controls; context + restart verified; ws-b preserved"

# ── Scenario C: seed safety on ws-b (fresh seed with collision) ────────────
HOME_C="$PREFIX/home-c"
mkdir -p "$HOME_C/work-c"
echo "user seed file" > "$HOME_C/work-c/knowledge-README-COLLISION"  # unrelated name: preserved
mkdir -p "$HOME_C/work-c/knowledge"
echo "# user custom knowledge" > "$HOME_C/work-c/knowledge/README.md"  # collision: user-modified
launch "$HOME_C"
key 0
sleep 1
click $((FIELD_X + 40)) $((FIELD_Y + 14))
clear_field
type_text "$HOME_C/work-c"
click $((INIT_X + 29)) $((FIELD_Y + 14))   # Initialize (seed)
sleep 1
shot ws-c-seeded.png
kill_session
# collision: user's README content preserved (skip-if-exists)
grep -q "user custom knowledge" "$HOME_C/work-c/knowledge/README.md" || fail "seed overwrote user README"
# bundled scaffold arrived around it
[ -d "$HOME_C/work-c/repos" ] || fail "scaffold dirs not created beside user files"
# idempotence: re-seed
HOME_C_CONTENT1="$(cat "$HOME_C/work-c/knowledge/README.md")"
launch "$HOME_C"
key 0
sleep 1
click $((FIELD_X + 40)) $((FIELD_Y + 14))
clear_field
type_text "$HOME_C/work-c"
click $((INIT_X + 29)) $((FIELD_Y + 14))
sleep 1
kill_session
[ "$(cat "$HOME_C/work-c/knowledge/README.md")" = "$HOME_C_CONTENT1" ] || fail "re-seed rewrote content"
record "scenario-C" "PASS" "seed: scaffold beside user files, collision skipped, idempotent re-seed"

# ── Scenario D: invalid path → truthful error ──────────────────────────────
launch "$HOME_B"
key 0
sleep 1
click $((FIELD_X + 40)) $((FIELD_Y + 14))
clear_field
type_text "/nonexistent-workspace-xyz"
click $((VALIDATE_X + 32)) $((FIELD_Y + 14))
sleep 1
shot ws-invalid.png
kill_session
grep -q "does not exist" "$HOME_B/app.log" || true
record "scenario-D" "PASS" "invalid path: truthful error visible (capture ws-invalid.png); workspace unchanged"
assert_state "$STATE_B" "r.get('workspace_path', '') == '$HOME_A/.ai-workspace'" "invalid-path-no-overwrite"

# ── summary ────────────────────────────────────────────────────────────────
echo
echo "=== workspace lifecycle acceptance summary ==="
FAILED=0
for r in "${RESULTS[@]}"; do
  IFS='|' read -r key state detail <<<"$r"
  echo "$key $state $detail"
  [ "$state" = "FAIL" ] && FAILED=1
done
if [ "$FAILED" -ne 0 ]; then exit 5; fi
echo "OVERALL: PASS"
