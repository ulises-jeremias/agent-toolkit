#!/usr/bin/env bash
# swarm-visual-test.sh — visual/live testing for `agent-toolkit swarm` backends.
#
# Usage:
#   ./swarm-visual-test.sh --phase T1                     # tmux + skeleton (structure)
#   ./swarm-visual-test.sh --phase T2                     # tmux + opencode (live)
#   ./swarm-visual-test.sh --phase T3                     # herdr + skeleton (structure)
#   ./swarm-visual-test.sh --phase T4                     # tmux + claude (live)
#   ./swarm-visual-test.sh --phase T6                     # herdr + opencode + full recipe
#   ./swarm-visual-test.sh --phase T2 --frames 15         # more timeline frames
#
# Phases: T1 tmux/skeleton · T2 tmux/opencode · T3 herdr/skeleton
#         T4 tmux/claude  · T5 attach (manual)   · T6 herdr/opencode/full
#
# Every phase: start (--json → spawns UI, no blocking attach) → wait-for-up →
# captures (txt + PNG + process probe) → asserts → teardown → report.json.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${BIN:-$(git rev-parse --show-toplevel 2>/dev/null)/build/agent-toolkit}"
PLAY="$HERE/playground"
ARTS="$HERE/artifacts"
PY="$HERE/.venv/bin/python"

PHASE="T1"
FRAMES=8
FRAME_INTERVAL=1
PROMPT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)  PHASE="$2"; shift 2 ;;
    --frames) FRAMES="$2"; shift 2 ;;
    --interval) FRAME_INTERVAL="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

case "$PHASE" in
  T1) BACKEND=tmux;  RUNNER=skeleton; RECIPE=pair; LIVE=0 ;;
  T2) BACKEND=tmux;  RUNNER=opencode; RECIPE=pair; LIVE=1 ;;
  T3) BACKEND=herdr; RUNNER=skeleton; RECIPE=pair; LIVE=0 ;;
  T4) BACKEND=tmux;  RUNNER=claude;   RECIPE=pair; LIVE=1 ;;
  T6) BACKEND=herdr; RUNNER=opencode; RECIPE=full; LIVE=1 ;;
esac
# las fases live necesitan una tarea que mantenga al agente ocupado un rato
if [[ "$LIVE" == "1" ]]; then
  TASK="Write a haiku about swarms into swarm.md, then create a file roles.txt listing the recipe roles implementer and reviewer, one per line. Take your time and be thorough."
else
  TASK="Print the banner: SWARM VISUAL SIGNAL v1. Then run ./signal.sh and show hello.txt"
fi

TS="$(date +%Y%m%dT%H%M%S)"
OUT="$ARTS/${TS}-${PHASE}-${BACKEND}-${RUNNER}"
mkdir -p "$OUT/panes"
RUN_ID=""
declare -a RESULTS=()
PASS_N=0
FAIL_N=0

note()  { echo "[$(date +%H:%M:%S)] $*"; }
pass()  { RESULTS+=("PASS $1"); PASS_N=$((PASS_N+1)); note "PASS  $1"; }
fail()  { RESULTS+=("FAIL $1"); FAIL_N=$((FAIL_N+1)); note "FAIL  $1"; }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi }

cleanup() {
  local rc=$?
  note "cleanup (rc=$rc)"
  [[ -n "$RUN_ID" ]] || { exit $rc; }
  "$BIN" swarm stop "$RUN_ID" >/dev/null 2>&1 || true
  "$BIN" swarm cleanup "$RUN_ID" >/dev/null 2>&1 || true
  tmux -L "agent-toolkit-swarm-$RUN_ID" kill-server >/dev/null 2>&1 || true
  if [[ "$BACKEND" == "herdr" ]]; then
    herdr workspace close "swarm-$RUN_ID" >/dev/null 2>&1 || \
    herdr workspace close "$("$BIN" swarm ls --json 2>/dev/null | true; echo)" >/dev/null 2>&1 || true
  fi
  exit $rc
}
trap cleanup EXIT INT TERM

# ---- start -----------------------------------------------------------------
note "phase $PHASE: backend=$BACKEND runner=$RUNNER recipe=$RECIPE"
cd "$PLAY"
START_OUT="$("$BIN" swarm start --recipe "$RECIPE" --backend "$BACKEND" \
  --runner "$RUNNER" --model-profile balanced --json "$TASK" 2>&1)"
echo "$START_OUT" > "$OUT/start.json"
RUN_ID=$(python3 - "$OUT/start.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print(d.get("data",{}).get("run_id") or d.get("run_id",""))
except Exception:
    print("")
PY
)
[[ -n "$RUN_ID" ]] || { fail "SC0 start produced run_id"; report_exit; }
echo "$RUN_ID" > "$OUT/run-id.txt"
note "run-id: $RUN_ID  → artifacts: $OUT"

SOCK="agent-toolkit-swarm-$RUN_ID"

# ---- wait for UI up --------------------------------------------------------
wait_for() { # wait_for <desc> <cmd> <tries>
  local desc="$1" cmd="$2" tries="${3:-30}"
  for _ in $(seq 1 "$tries"); do
    if eval "$cmd" >/dev/null 2>&1; then pass "wait: $desc"; return 0; fi
    sleep 2
  done
  fail "wait: $desc (timeout ${tries}x2s)"; return 1
}

if [[ "$BACKEND" == "tmux" ]]; then
  wait_for "tmux session+windows exist" "tmux -L $SOCK list-windows -t swarm-$RUN_ID" 20
elif [[ "$BACKEND" == "herdr" ]]; then
  wait_for "herdr workspace exists" "herdr workspace list | grep -q swarm-$RUN_ID" 20
fi
# workspace_id (wX) del mensaje de start — clave para filtrar panes
WS_ID=$(python3 - "$OUT/start.json" <<'PY2'
import json,re,sys
try:
    d=json.load(open(sys.argv[1]))
    m=re.search(r'\((w[A-Za-z0-9]+)\)', d.get("message",""))
    print(m.group(1) if m else "")
except Exception:
    print("")
PY2
)
[[ -n "$WS_ID" ]] && echo "$WS_ID" > "$OUT/ws-id.txt" && note "herdr workspace-id: $WS_ID"

# pipe-pane: log continuo de cada ventana (TUIs altscreen no quedan en capture)
if [[ "$BACKEND" == "tmux" ]]; then
  for role in implementer reviewer planner architect refactorer hardener qa integrator; do
    tmux -L "$SOCK" list-windows -t "swarm-$RUN_ID" -F '#{window_name}' 2>/dev/null | grep -qx "$role" || continue
    tmux -L "$SOCK" pipe-pane -o -t "swarm-$RUN_ID:$role" "cat >> '$OUT/panes/${role}.log'" 2>/dev/null || true
  done
fi

# ---- SC1: window/pane inventory per role -----------------------------------
if [[ "$BACKEND" == "tmux" ]]; then
  tmux -L "$SOCK" list-windows -t "swarm-$RUN_ID" > "$OUT/tmux-windows.txt" 2>&1 || true
  cat "$OUT/tmux-windows.txt"
  check "SC1 tmux: implementer window" "grep -q implementer '$OUT/tmux-windows.txt'"
  check "SC1 tmux: reviewer window"    "grep -q reviewer '$OUT/tmux-windows.txt'"
elif [[ "$BACKEND" == "herdr" ]]; then
  herdr workspace list > "$OUT/herdr-workspace.json" 2>&1 || true
  herdr pane list > "$OUT/herdr-panes.json" 2>&1 || true
  check "SC1 herdr: workspace registered" "grep -q 'swarm-$RUN_ID' '$OUT/herdr-workspace.json'"
  check "SC1 herdr: ≥3 panes in swarm workspace" \
    "python3 -c \"import json; d=json.load(open('$OUT/herdr-panes.json')); print(sum(1 for p in d['result']['panes'] if p['workspace_id']=='$WS_ID'))\" | grep -qE '[3-9]'"
fi

# ---- captures: per-role snapshots (txt + PNG) + process probe ---------------
capture_tmux_role() {
  local role="$1" seqn="$2"
  tmux -L "$SOCK" capture-pane -e -p -t "swarm-$RUN_ID:$role" > "$OUT/panes/${role}-${seqn}.ansi" 2>&1
  tmux -L "$SOCK" capture-pane -p    -t "swarm-$RUN_ID:$role" > "$OUT/panes/${role}-${seqn}.txt" 2>&1
  $PY "$HERE/ansi2png.py" "$OUT/panes/${role}-${seqn}.ansi" "$OUT/panes/${role}-${seqn}.png" 2>>"$OUT/render-err.log" || return 1
}

# ---- timeline frames (evidence of liveness) --------------------------------
snapshot_all() {
  local seqn="$1"
  if [[ "$BACKEND" == "tmux" ]]; then
    for role in implementer reviewer planner architect refactorer hardener qa integrator; do
      tmux -L "$SOCK" has-session -t "swarm-$RUN_ID" 2>/dev/null || break
      tmux -L "$SOCK" list-windows -t "swarm-$RUN_ID" -F '#{window_name}' 2>/dev/null | grep -qx "$role" || continue
      capture_tmux_role "$role" "$seqn" || true
    done
  else
    herdr pane list 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for p in d['result']['panes']:
        if p.get('workspace_id')=='$WS_ID':
            print(p['pane_id'])
except Exception: pass
" | while read -r pid; do
      [[ -n "$pid" ]] || continue
      herdr pane read "$pid" --source visible --lines 40 > "$OUT/panes/herdr-${pid}-${seqn}.ansi" 2>/dev/null
      $PY "$HERE/ansi2png.py" "$OUT/panes/herdr-${pid}-${seqn}.ansi" "$OUT/panes/herdr-${pid}-${seqn}.png" 2>>"$OUT/render-err.log" || true
    done
  fi
}

note "capturing $FRAMES timeline frames (${FRAME_INTERVAL}s apart)"
for i in $(seq 1 "$FRAMES"); do
  snapshot_all "$i"
  sleep "$FRAME_INTERVAL"
done
# render final del log continuo por rol (TUI completa, altscreen-proof)
if [[ "$BACKEND" == "tmux" ]]; then
  for role in implementer reviewer planner architect refactorer hardener qa integrator; do
    [[ -s "$OUT/panes/${role}.log" ]] || continue
    $PY "$HERE/ansi2png.py" "$OUT/panes/${role}.log" "$OUT/panes/${role}-full.png" \
        --cols 80 --rows 24 2>>"$OUT/render-err.log" || true
    # version texto del log (para asserts grep-ables)
    $PY - "$OUT/panes/${role}.log" > "$OUT/panes/${role}-full.txt" <<'PY2'
import sys, re, pyte
data = open(sys.argv[1], 'rb').read().decode('utf-8', errors='replace')
screen = pyte.Screen(80, 24)
stream = pyte.ByteStream(screen)
stream.feed(data.encode('utf-8', errors='replace'))
print('
'.join(''.join(screen.buffer[y][x].data for x in range(80)) for y in range(24)).rstrip())
PY2
  done
fi

# ---- SC2/SC3: live process + banner (only for live phases) ------------------
if [[ "$LIVE" == "1" ]]; then
  if [[ "$BACKEND" == "tmux" ]]; then
    wait_for "runtime process (opencode/claude) alive in panes" \
      "tmux -L $SOCK list-panes -s -t swarm-$RUN_ID -F '#{pane_current_command}' | grep -qE 'opencode|claude'" 30
    tmux -L "$SOCK" list-panes -s -t "swarm-$RUN_ID" -F '#{window_name} #{pane_current_command}' \
      > "$OUT/pane-process.txt" 2>&1 || true
    cat "$OUT/pane-process.txt"
    check "SC2 tmux: runtime process visible in pane" \
      "grep -qE 'opencode|claude' '$OUT/pane-process.txt'"
    check "SC3 tmux: first pane non-empty" \
      "test -s '$OUT/panes/implementer-1.txt' && grep -qve '^$' '$OUT/panes/implementer-1.txt'"
  fi
  # banner heuristics over any captured text
  if grep -rliE 'opencode|claude|openai|anthropic|welcome' "$OUT/panes/"*.txt >/dev/null 2>&1 \
     || grep -rliE 'opencode|claude|welcome' "$OUT/panes/"*.ansi >/dev/null 2>&1; then
    pass "SC3 banner/runtime text found in captures"
  else
    fail "SC3 banner/runtime text found in captures"
  fi
else
  check "SC2/SC3 skeleton: '[skeleton:' marker in first pane" \
    "grep -rq '\[skeleton:' '$OUT/panes/' 2>/dev/null"
fi

# ---- SC4: PNG evidence exists ----------------------------------------------
PNG_COUNT=$(find "$OUT/panes" -name '*.png' | wc -l)
check "SC4 evidence: ≥1 PNG captured ($PNG_COUNT found)" "[ '$PNG_COUNT' -ge 1 ]"
if command -v ffmpeg >/dev/null && [[ "$PNG_COUNT" -ge 3 ]]; then
  i=0; for f in $(find "$OUT/panes" -name '*.png' | sort); do
    i=$((i+1)); cp "$f" "/tmp/sv-frame-$(printf '%03d' $i).png"
  done
  ffmpeg -y -loglevel error -framerate 2 -i "/tmp/sv-frame-%03d.png" "$OUT/timeline.gif" 2>/dev/null && \
    pass "SC4 evidence: timeline.gif assembled" || fail "SC4 timeline.gif"
fi

# ---- SC6: teardown happens via trap; assert prune dry-run clean -------------
note "teardown + SC6 verification"
"$BIN" swarm stop "$RUN_ID" >/dev/null 2>&1 || true
"$BIN" swarm cleanup "$RUN_ID" >/dev/null 2>&1 || true
tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true
"$BIN" swarm prune --older-than 0s --force >/dev/null 2>&1 || true
PRUNE=$("$BIN" swarm prune --older-than 0s --dry-run 2>&1 | head -5)
check "SC6 prune: nothing left after teardown" \
  "! echo \"$PRUNE\" | grep -q \"$RUN_ID\""

# ---- report -----------------------------------------------------------------
{
  echo '{'
  echo "  \"phase\": \"$PHASE\", \"backend\": \"$BACKEND\", \"runner\": \"$RUNNER\","
  echo "  \"recipe\": \"$RECIPE\", \"run_id\": \"$RUN_ID\", \"artifacts\": \"$OUT\","
  echo '  "results": ['
  for i in "${!RESULTS[@]}"; do
    r="${RESULTS[$i]}"
    [[ $i -gt 0 ]] && echo ','
    echo "    \"$(echo "$r" | sed 's/"/\\"/g')\""
  done
  echo '  ]'
  echo '}'
} > "$OUT/report.json"
cat "$OUT/report.json"
note "phase $PHASE done: $PASS_N pass, $FAIL_N fail"
[[ "$FAIL_N" -eq 0 ]]
