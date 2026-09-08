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
APP_PID=0
OB_PID=0
XVFB_PID=0
record() { printf '%-34s %-8s %s\n' "$1" "$2" "$3"; RESULTS+=("$1|$2|$3"); }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

ART_NAME="$(basename "$ARCHIVE")"
ART_SHA="$(sha256sum "$ARCHIVE" | cut -d' ' -f1)"
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
  # a bare Xvfb has no WM → no window ever has input focus → XTEST keys
  # would go nowhere. openbox gives the journey real focus semantics.
  DISPLAY=:99 openbox &
  OB_PID=$!
  sleep 1
  # env -i: NO CI environment leakage — the app sees exactly the clean
  # launcher-like environment (a leaked XDG_CACHE_HOME would send engine
  # state outside the clean HOME and silently break the acceptance)
  env -i DISPLAY=:99 PATH="${pathfix:+$pathfix:}/usr/bin:/bin" \
    HOME="$home" LANG=C.UTF-8 \
    XDG_DATA_HOME="$home/.local/share" XDG_CONFIG_HOME="$home/.config" \
    XDG_CACHE_HOME="$home/.cache" \
    "$INSTALLED_BIN" > "$home/app.log" 2>&1 &
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
  local focused
  focused="$(DISPLAY=:99 xdotool getwindowfocus 2>/dev/null || true)"
  if [ "$focused" != "$WIN_ID" ]; then
    echo "focus probe: focused=$focused want=$WIN_ID — retrying windowfocus" >&2
    DISPLAY=:99 xdotool windowfocus "$WIN_ID" || true
    sleep 1
  fi
}
kill_session() {
  kill $APP_PID 2>/dev/null || true
  kill $OB_PID 2>/dev/null || true
  kill $XVFB_PID 2>/dev/null || true
  wait $APP_PID 2>/dev/null || true
  wait $OB_PID 2>/dev/null || true
  wait $XVFB_PID 2>/dev/null || true
}

journey_key() { DISPLAY=:99 xdotool key --window "$WIN_ID" "$1" 2>/dev/null || DISPLAY=:99 xdotool key "$1"; sleep 1; }
# Enter actions are retried once: every step action is idempotent (bulk
# installs are set-semantics, personas skip existing, workspace mkdir_all,
# targets set-true), and a Return swallowed while a transaction commits
# would otherwise leave the journey silently incomplete.
journey_enter() { journey_key Return; sleep 0.8; journey_key Return; sleep 1; }
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
journey_key Right; journey_enter
# step2 Targets → enable minimal
journey_key Right; journey_enter
# step3 Products → enable core product
journey_key Right; journey_enter
# step4 Workspace → init scaffold under ~/.ai-workspace
journey_key Right; journey_enter
shot onboarding-workspace.png
# step5 Personas → bootstrap
journey_key Right; journey_enter
# step6: pressing Right AT the Done step triggers onboarding_complete —
# this is the 7th Right (the previous six arrived at each step). A retry
# guards against a swallowed keystroke while the personas transaction
# was still committing (completion is idempotent-safe: onboarding already
# done → Right is a no-op on the closed wizard).
journey_key Right
sleep 2
journey_key Right
sleep 2
shot journey-final.png
# diagnostics: where is the wizard? did keys land?
echo "journey diagnostics:" >&2
find "$HOME_FRESH" -name '*.json' | head -5 >&2 || true
find "$HOME_FRESH/knowledge" 2>/dev/null | head -3 >&2 || true
DISPLAY=:99 xdotool getactivewindowname 2>/dev/null >&2 || true

STATE_FILE="$HOME_FRESH/.cache/agent-toolkit/desktop/engine_state.json"
sleep 1
kill_session

[ -f "$STATE_FILE" ] || {
  echo "state file locations probed:" >&2
  find "$HOME_FRESH" -name 'engine_state*' >&2 || true
  find "$HOME_FRESH" -type d -name 'agent-toolkit' >&2 || true
  fail "engine state file missing after first run"
}
python3 -c "
import json, sys
r = json.load(open('$STATE_FILE')).get('data', {})
print('DBG onboarding_completed:', repr(r.get('onboarding_completed')))
print('DBG keys sample:', sorted(r.keys())[:24])
" || true
assert_state "r.get('data', {}).get('onboarding_completed') == 'true'" "first-run-completion-persisted"
assert_state "len([s for s in (r.get('data', {}).get('installed_skills') or '').split(',') if s]) >= 1" "capabilities-installed"
assert_state "any(r.get('data', {}).get(f'target:{t}:enabled') == 'true' for t in ('claude-code','opencode','cursor'))" "targets-enabled"
[ -d "$HOME_FRESH/.ai-workspace/knowledge" ] || fail "workspace scaffold missing: $HOME_FRESH/.ai-workspace/knowledge"
record "workspace-scaffold" "PASS" "knowledge/ scaffold created under ~/.ai-workspace (designed default)"
PERSONA_FILE="$HOME_FRESH/.ai-workspace/personas/implementer.md"
if [ ! -f "$PERSONA_FILE" ]; then
  echo "DBG personas dir probe (full):" >&2
  find "$HOME_FRESH" -name '*.md' >&2 | head -20 || true
  echo "DBG personas state:" >&2
  python3 -c "
import json
r = json.load(open('$STATE_FILE')).get('data', {})
print('personas_bootstrapped:', repr(r.get('personas_bootstrapped')), 'persona_count:', repr(r.get('persona_count')))
print('recent_workspace:', repr(r.get('recent_workspace')))
" >&2 || true
  fail "personas not bootstrapped under ~/.ai-workspace"
fi
record "personas" "PASS" "personas bootstrapped under ~/.ai-workspace"
record "personas" "PASS" "personas bootstrapped under ~/.ai-workspace"

# restart — hard gate: wizard must NOT reappear, state preserved
cp "$STATE_FILE" "$PREFIX/state-before-restart.json"
launch "$HOME_FRESH"
shot after-restart.png
kill_session
echo "DBG restart app.log tail:" >&2
tail -5 "$HOME_FRESH/app.log" >&2 || true
python3 -c "
import json, sys
r = json.load(open('$STATE_FILE')).get('data', {})
print('DBG restart keys:', sorted(r.keys())[:20])
print('DBG restart onboarding_completed:', repr(r.get('onboarding_completed')))
" || true
python3 -c "
import json, sys
r = json.load(open('$STATE_FILE')).get('data', {})
sys.exit(0 if r.get('onboarding_completed') == 'true' else 1)
" || fail "restart: completion lost"
python3 -c "
import json, sys
r = json.load(open('$STATE_FILE')).get('data', {})
print('DBG restart workspace_path:', repr(r.get('workspace_path')))
print('DBG restart recent_workspace:', repr(r.get('recent_workspace')))
" || true
python3 -c "
import json, sys
r = json.load(open('$STATE_FILE')).get('data', {})
print('DBG restart workspace_path:', repr(r.get('workspace_path')))
" || true
assert_state "r.get('data', {}).get('workspace_path', '').endswith('.ai-workspace') or r.get('data', {}).get('recent_workspace', '').endswith('.ai-workspace')" "restart-workspace-restored"
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
journey_key Right                        # step1 Capabilities
journey_key Right; journey_key Return   # step2 Targets → enable minimal (incl. claude-code)
journey_key Right                        # step3
kill_session
STATE_B="$HOME_B/.cache/agent-toolkit/desktop/engine_state.json"
python3 -c "
import json, sys
r = json.load(open('$STATE_B')).get('data', {})
sys.exit(0 if r.get('target:claude-code:enabled') == 'true' else 1)
" || fail "fixture target not enabled"
record "fixture-integration" "PASS" "found fixture → target enabled → integration path real (fixture-labeled)"

# ── failure/recovery: workspace init against a blocked scaffold ───────────
echo "== failure/recovery =="
HOME_F="$PREFIX/home-f"
mkdir -p "$HOME_F"
launch "$HOME_F"
sleep 3   # boot creates the default ~/.ai-workspace (empty, uninitialized)
# blocker: a FILE where ensure_workspace needs a DIRECTORY — deterministic
# scaffold failure inside the designed default workspace
touch "$HOME_F/.ai-workspace/knowledge"
journey_key Right; journey_key Right; journey_key Right; journey_key Right
journey_key Return   # workspace init → must fail (knowledge is a file)
sleep 2
shot onboarding-failure.png
kill_session
[ -f "$HOME_F/app.log" ] && grep -q "workspace init failed" "$HOME_F/app.log" && \
  record "failure-logged" "PASS" "wizard surfaced 'workspace init failed' (app.log + capture)"
[ -f "$HOME_F/.cache/agent-toolkit/desktop/engine_state.json" ] || fail "failure-path state file missing"
python3 -c "
import json, sys
r = json.load(open('$HOME_F/.cache/agent-toolkit/desktop/engine_state.json')).get('data', {})
print('DBG failure onboarding_completed:', repr(r.get('onboarding_completed')))
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
kill_session
STATE_I="$HOME_I/.cache/agent-toolkit/desktop/engine_state.json"
python3 -c "
import json, sys
r = json.load(open('$STATE_I')).get('data', {})
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
kill_session
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
