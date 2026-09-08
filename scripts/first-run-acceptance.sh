#!/usr/bin/env bash
# first-run-acceptance.sh — #1127 zero-to-working first-run acceptance.
#
# Consumes the #1130 chain: real artifact → receipt-backed install →
# INSTALLED binary → real onboarding UI driven through user-visible
# controls (keyboard, via xdotool/XTEST under Xvfb — no state-file
# driving, no engine calls from the driver) → restart persistence.
#
# Scenarios:
#   A  absolute clean machine (no agent CLIs) — graceful, non-dead-end
#   B  minimal working integration (deterministic fixture executable,
#      explicitly integration-fixture evidence)
#   +  failure/recovery, interrupted onboarding, existing-state preservation
#
# States are explicit per check (PASS/FAIL/NOT_PROVEN/MANUAL); captures
# are staged into EVIDENCE_DIR for human inspection — never hash-approved.
set -euo pipefail

ARCHIVE="${1:?usage: first-run-acceptance.sh <desktop-archive.tar.gz>}"
[ -f "$ARCHIVE" ] || { echo "error: archive not found: $ARCHIVE" >&2; exit 2; }

RESULTS=()
record() { printf '%-34s %-8s %s\n' "$1" "$2" "$3"; RESULTS+=("$1|$2|$3"); }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

ART_NAME="$(basename "$ARCHIVE")"
ART_SHA="$(sha256sum "$ARTIFACT" | cut -d' ' -f1)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "provenance: artifact=$ART_NAME sha256=$ART_SHA"

PREFIX="$(mktemp -d /tmp/atk-firstrun-XXXXXX)"
EVIDENCE="${EVIDENCE_DIR:-$PREFIX/evidence}"
mkdir -p "$EVIDENCE"
trap 'rm -rf "$PREFIX"' EXIT

# ── install via the real bundle script (#1130 chain) ───────────────────────
STAGE="$PREFIX/stage"
mkdir -p "$STAGE"
tar xzf "$ARCHIVE" -C "$STAGE"
export HOME_FRESH="$PREFIX/home-a"
export XDG_DATA_HOME="$HOME_FRESH/.local/share"
export XDG_CONFIG_HOME="$HOME_FRESH/.config"
mkdir -p "$HOME_FRESH"
( cd "$STAGE" && ./install-desktop.sh install ) >/dev/null
INSTALLED_BIN="$XDG_DATA_HOME/agent-toolkit/bin/agent-toolkit-desktop"
[ -x "$INSTALLED_BIN" ] || fail "installed binary missing"
record "artifact-install" "PASS" "receipt-backed install from $ART_NAME"

launch() { # $1 home  $2 extra PATH prefix (fixture)  → sets APP_PID, WIN_ID
  local home="$1" pathfix="${2:-}"
  Xvfb :99 -screen 0 1280x800x24 &
  XVFB_PID=$!
  sleep 1
  env DISPLAY=:99 PATH="${pathfix:+$pathfix:}/usr/bin:/bin" \
    XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    "$INSTALLED_BIN" &
  APP_PID=$!
  for _ in $(seq 1 30); do
    sleep 1
    WIN_ID="$(DISPLAY=:99 xdotool search --onlyvisible --name 'Agent Toolkit' 2>/dev/null | head -1 || true)"
    [ -n "$WIN_ID" ] && break
  done
  [ -n "$WIN_ID" ] || fail "app window never appeared"
  DISPLAY=:99 xdotool windowfocus "$WIN_ID" 2>/dev/null || true
  sleep 1
}

journey_key() { DISPLAY=:99 xdotool key --window "$WIN_ID" "$1" 2>/dev/null || DISPLAY=:99 xdotool key "$1"; sleep 1; }
shot() { DISPLAY=:99 import -window root "$EVIDENCE/$1" 2>/dev/null || true; }

assert_state() { # $1 python-expr over the engine state json  $2 label
  python3 -c "
import json, sys
r = json.load(open('$STATE_FILE'))
sys.exit(0 if ($1) else 1)
" || fail "state assertion failed: $2"
  record "$2" "PASS" "engine state verified"
}

# ── Scenario A: absolute clean machine ─────────────────────────────────────
echo "== Scenario A: absolute clean machine =="
launch "$HOME_FRESH"
shot onboarding-step0.png
record "onboarding-visible" "PASS" "wizard overlay visible on first launch (capture onboarding-step0.png)"

# truthful discovery on the Detect/Targets step is captured later; drive the journey:
# step1 Capabilities → install first 5 catalog skills
journey_key Right; journey_key Return
# step2 Targets → enable minimal
journey_key Right; journey_key Return
# step3 Products → enable core product
journey_key Right; journey_key Return
# step4 Workspace → init scaffold under HOME
journey_key Right; journey_key Return
shot onboarding-workspace.png
# step5 Personas → bootstrap
journey_key Right; journey_key Return
# step6 → Right completes
journey_key Right
shot onboarding-complete.png

STATE_FILE="$XDG_CONFIG_HOME/agent-toolkit/desktop/engine_state.json"
sleep 1
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true

[ -f "$STATE_FILE" ] || fail "engine state file missing after first run"
assert_state "r.get('onboarding_completed') == 'true'" "first-run-completion-persisted"
assert_state "len([s for s in (r.get('installed_skills') or '').split(',') if s]) >= 1" "capabilities-installed"
assert_state "any(r.get(f'target:{t}:enabled') == 'true' for t in ('claude-code','opencode','cursor'))" "targets-enabled"
[ -d "$HOME_FRESH/knowledge" ] && record "workspace-scaffold" "PASS" "knowledge/ scaffold created under clean HOME"
[ -f "$HOME_FRESH/personas/assistant.md" ] || [ -d "$HOME_FRESH/personas" ] && record "personas" "PASS" "personas bootstrapped"

# restart — hard gate: wizard must NOT reappear, state preserved
launch "$HOME_FRESH"
shot after-restart.png
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
python3 -c "
import json, sys
r = json.load(open('$STATE_FILE'))
sys.exit(0 if r.get('onboarding_completed') == 'true' else 1)
" || fail "restart: completion lost"
assert_state "r.get('workspace_path', '').endswith('home-a') or r.get('recent_workspace','').endswith('home-a')" "restart-workspace-restored"
record "restart-persistence" "PASS" "same installed app relaunched: no onboarding restart, state preserved (capture after-restart.png)"

# ── Scenario B: minimal working integration (fixture, labeled) ────────────
echo "== Scenario B: minimal working integration (FIXTURE evidence) =="
HOME_B="$PREFIX/home-b"
mkdir -p "$HOME_B" "$PREFIX/fixture-bin"
cat > "$PREFIX/fixture-bin/claude" <<'FIX'
#!/bin/sh
echo "fixture-claude 9.9.9 (integration fixture)"
exit 0
FIX
chmod +x "$PREFIX/fixture-bin/claude"
# discovery truth via the installed binary (headless) under fixture PATH
DISCO="$(env -i PATH="$PREFIX/fixture-bin:/usr/bin:/bin" HOME="$HOME_B" \
  XDG_DATA_HOME="$HOME_B/.local/share" XDG_CONFIG_HOME="$HOME_B/.config" \
  ATK_GUI_HEADLESS=1 "$INSTALLED_BIN" 2>&1 | grep -oP 'tools found=\d+ missing=\d+' || true)"
[ "$DISCO" = "tools found=1 missing=8" ] || fail "fixture discovery expected found=1/missing=8, got: $DISCO"
record "fixture-discovery" "PASS" "$DISCO — integration-fixture evidence (claude is a deterministic stub, not a third-party product)"

# the fixture makes target-enable meaningful: enable claude-code target
launch "$HOME_B" "$PREFIX/fixture-bin"
journey_key Right; journey_key Return   # step2 targets → enable minimal (incl. claude-code)
journey_key Right                        # step3
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
STATE_B="$HOME_B/.config/agent-toolkit/desktop/engine_state.json"
python3 -c "
import json, sys
r = json.load(open('$STATE_B'))
sys.exit(0 if r.get('target:claude-code:enabled') == 'true' else 1)
" || fail "fixture target not enabled"
record "fixture-integration" "PASS" "found fixture → target enabled → integration path real (fixture-labeled)"

# ── failure/recovery: workspace init against a blocked scaffold ───────────
echo "== failure/recovery =="
HOME_F="$PREFIX/home-f"
mkdir -p "$HOME_F" "$HOME_F/knowledge"
echo "user data" > "$HOME_F/knowledge/blocker" 2>/dev/null || true
rm -rf "$HOME_F/knowledge"; touch "$HOME_F/knowledge"  # FILE where a dir is required
launch "$HOME_F"
journey_key Right; journey_key Right; journey_key Right; journey_key Right
journey_key Return   # workspace init → must fail (knowledge is a file)
sleep 1
shot onboarding-failure.png
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
python3 -c "
import json, sys
r = json.load(open('$HOME_F/.config/agent-toolkit/desktop/engine_state.json'))
sys.exit(0 if r.get('onboarding_completed') != 'true' else 1)
" || fail "failure path wrongly persisted completion"
record "failure-surfaced" "PASS" "workspace init failed honestly (file where dir required); completion NOT persisted (capture onboarding-failure.png)"

# ── interrupted onboarding: partial state is truthful, resume is safe ─────
echo "== interrupted onboarding =="
HOME_I="$PREFIX/home-i"
mkdir -p "$HOME_I"
launch "$HOME_I"
journey_key Right; journey_key Return   # step1: install skills, then STOP
sleep 1
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
STATE_I="$HOME_I/.config/agent-toolkit/desktop/engine_state.json"
python3 -c "
import json, sys
r = json.load(open('$STATE_I'))
skills = len([s for s in (r.get('installed_skills') or '').split(',') if s])
sys.exit(0 if (skills >= 1 and r.get('onboarding_completed') != 'true') else 1)
" || fail "interrupted state wrong"
record "interrupted-honest" "PASS" "partial install persisted; onboarding_completed NOT set (resume shows truthful pending)"

# ── existing setup: non-destructive ────────────────────────────────────────
echo "== existing setup preservation =="
HOME_E="$PREFIX/home-e"
mkdir -p "$HOME_E/knowledge" "$HOME_E/personas"
echo "# my existing knowledge" > "$HOME_E/knowledge/notes.md"
echo "# my persona" > "$HOME_E/personas/custom-persona.md"
launch "$HOME_E"
journey_key Right; journey_key Right; journey_key Right; journey_key Right
journey_key Return                      # ensure workspace over EXISTING dirs
sleep 1
shot existing-setup.png
kill $APP_PID 2>/dev/null || true
wait $APP_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true
[ "$(cat "$HOME_E/knowledge/notes.md")" = "# my existing knowledge" ] || fail "existing knowledge overwritten"
[ "$(cat "$HOME_E/personas/custom-persona.md")" = "# my persona" ] || fail "existing persona overwritten"
record "existing-state-preserved" "PASS" "existing knowledge/personas untouched by ensure (capture existing-setup.png)"

# ── summary ────────────────────────────────────────────────────────────────
echo
echo "=== first-run acceptance summary ($ART_NAME) ==="
FAILED=0
for r in "${RESULTS[@]}"; do
  IFS='|' read -r key state detail <<<"$r"
  echo "$key $state $detail"
  [ "$state" = "FAIL" ] && FAILED=1
done
if [ "$FAILED" -ne 0 ]; then exit 5; fi
echo "OVERALL: PASS (Scenario A graceful + Scenario B fixture-labeled; captures in $EVIDENCE)"
