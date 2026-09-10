#!/usr/bin/env bash
# ui-smoke.sh — headless UI smoke test for the native desktop GUI.
#
# Boots the desktop binary on a fresh Xvfb, drives it with xdotool and saves
# a screenshot per state. App-alive checks are the assertions.
#
# KNOWN LIMITATION: xdotool can SIGSEGV intermittently under rapid XTEST
# automation on bare Xvfb (libxdo/Xvfb interaction, unrelated to the app).
# Every xdotool call is guarded; a rare run may abort with 139 — re-run.
#
# Requirements: Xvfb + xdotool + ImageMagick `import` (paths auto-probed).
# Usage: ./scripts/ui-smoke.sh  [SMOKE_BIN=...] [SMOKE_OUT=/tmp/...]
#
# Display constraint: the smoke runs on a FIXED display (default :99,
# SMOKE_DISPLAY to override) because tour coordinates are display-bound.
# A lock file guards it so two local runs fail loudly instead of colliding.
# The app runs under a temp HOME/XDG — real ~/.cache prefs are never read
# or written. Temp paths honor $TMPDIR. System Xvfb/xdotool are preferred;
# /tmp/opencode/xtools fallbacks stay (CI may rely on them).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SMOKE_BIN:-$ROOT/build/agent-toolkit-desktop-native}"
OUT="${SMOKE_OUT:-${TMPDIR:-/tmp}/atk-ui-smoke}"
XD="${XDOTOOL:-xdotool}"
# preserve a caller-provided LD_LIBRARY_PATH (user-space Xvfb/xdotool installs
# whose libs are not on the system loader path); default empty as before
XLIB="${LD_LIBRARY_PATH:-}"
if ! command -v "$XD" >/dev/null && [ -x /tmp/opencode/xtools/usr/bin/xdotool ]; then
	XD=/tmp/opencode/xtools/usr/bin/xdotool
	XLIB=/tmp/opencode/xtools/usr/lib
fi
# system Xvfb first, user-space fallback second (never drop the fallback)
XVFB="${XVFB:-Xvfb}"
if ! command -v "$XVFB" >/dev/null 2>&1 && [ -x /tmp/opencode/xtools/usr/bin/Xvfb ]; then
	XVFB=/tmp/opencode/xtools/usr/bin/Xvfb
fi
EFFDIS="${SMOKE_DISPLAY:-:99}"
EFFNUM="${EFFDIS#:}"
xdt() { DISPLAY="$EFFDIS" LD_LIBRARY_PATH="$XLIB" "$XD" "$@" 2>/dev/null || true; }
key() { xdt key "$@"; }
clk() { xdt mousemove "$1" "$2" click 1; }

mkdir -p "$OUT"

# fixed-display lock: only processes owned by this run are ever signalled
LOCK="${TMPDIR:-/tmp}/atk-uismoke-X${EFFNUM}.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
	owner="$(cat "$LOCK/pid" 2>/dev/null || echo unknown)"
	if [ "$owner" != unknown ] && ! kill -0 "$owner" 2>/dev/null; then
		echo "warning: stealing stale ui-smoke lock $LOCK (owner $owner dead)" >&2
		rm -rf "$LOCK"
		mkdir "$LOCK" || { echo "error: cannot take ui-smoke lock $LOCK" >&2; exit 2; }
	else
		echo "error: display $EFFDIS is locked by another ui-smoke run (owner pid $owner)" >&2
		exit 2
	fi
fi
echo "$$" >"$LOCK/pid"

# temp HOME/XDG: the app must never read or write real user prefs
SMOKE_HOME="$(mktemp -d "${TMPDIR:-/tmp}/atk-uismoke-home-XXXXXX")"
export HOME="$SMOKE_HOME"
export XDG_CACHE_HOME="$SMOKE_HOME/.cache"
export XDG_CONFIG_HOME="$SMOKE_HOME/.config"
export XDG_DATA_HOME="$SMOKE_HOME/.local/share"

XVFB_PID=0
APP_PID=0
cleanup_uismoke() {
	if [ "$APP_PID" != 0 ]; then kill "$APP_PID" 2>/dev/null || true; fi
	if [ "$XVFB_PID" != 0 ]; then kill "$XVFB_PID" 2>/dev/null || true; fi
	if [ "$APP_PID" != 0 ]; then wait "$APP_PID" 2>/dev/null || true; fi
	if [ "$XVFB_PID" != 0 ]; then wait "$XVFB_PID" 2>/dev/null || true; fi
	rm -rf "$SMOKE_HOME" "$LOCK"
}
trap cleanup_uismoke EXIT

# fresh Xvfb every run (servers degrade after many client cycles),
# owned by this run (PID-scoped kills only, never pkill)
sleep 0.5
rm -f "/tmp/.X11-unix/X${EFFNUM}"
/usr/bin/env "$XVFB" "$EFFDIS" -screen 0 1280x800x24 -nolisten tcp >"${TMPDIR:-/tmp}/atk-xvfb.log" 2>&1 &
XVFB_PID=$!
sleep 2
export DISPLAY="$EFFDIS"
up=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	if xdt getdisplaygeometry >/dev/null 2>&1; then
		up=1
		break
	fi
	sleep 1
done
[ "$up" = "1" ] || { echo "SMOKE FAIL: Xvfb not responding"; exit 1; }

# boot the app — Wayland forced off (sokol prefers it when present).
# Direct background (no subshell) so APP_PID is the owned app process.
env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET DISPLAY="$DISPLAY" "$BIN" >"$OUT/app.log" 2>&1 &
APP_PID=$!
# software GL (llvmpipe) needs longer than 3s for the first frame — poll
WID=""
for _ in $(seq 1 45); do
	WID="$(xdt search --name 'Agent Toolkit' | head -1 || true)"
	[ -n "$WID" ] && break
	sleep 2
done
[ -n "$WID" ] || { echo "SMOKE FAIL: window not found"; exit 1; }
sleep 8
xdt windowfocus "$WID"
clk 400 70 # letterhead click = keyboard focus without pressing a row
sleep 0.6
shot() {
	sleep 1.2
	for _ in 1 2 3; do
		import -window "$WID" "$OUT/$1.png" 2>/dev/null && return 0
		sleep 0.5
	done
	echo "SMOKE FAIL: screenshot $1"
	exit 1
}
alive() {
	# PID-scoped: only the app process owned by this run counts
	[ "$APP_PID" != 0 ] && kill -0 "$APP_PID" 2>/dev/null
}

# panel tour — numeric shortcuts cover every panel; onboarding via o
for key in 1 2 3 4 5 6 7 8 9 0 p i o; do
	key "$key"
	sleep 0.5
	alive || { echo "SMOKE FAIL: app died on panel key $key"; exit 1; }
done
# dock group clicks — bottom-up so expanding a group never shifts a row
# that is still to be clicked (rows start y=58, groups step 40px)
for gy in 258 218 178 138 98 58; do
	clk 100 "$((gy + 18))"
	sleep 0.6
	alive || { echo "SMOKE FAIL: app died on dock group y=$gy"; exit 1; }
done
shot panels-tour

# palette — open, type, filter, Enter navigates
key slash
sleep 0.5
xdt type "insights"
sleep 0.5
key Return
sleep 1.2
alive || { echo "SMOKE FAIL: app died after palette Enter"; exit 1; }
shot insights

# insights tabs — realtime + gallery (geometry: fx+16 + i*(84+6))
for gx in 716 806; do
	clk "$gx" 111
	sleep 0.8
	alive || { echo "SMOKE FAIL: app died on insights tab $gx"; exit 1; }
done
shot insights-gallery

# language cycle EN→ES→中文→عربي→EN (header chips at w-180 + i*34, y 10..32)
for cx in 1100 1134 1168 1202; do
	clk "$cx" 21
	sleep 0.6
	alive || { echo "SMOKE FAIL: app died on language chip $cx"; exit 1; }
done
shot i18n

# terminal 2× mode (header button; TH = display height - status - compact term)
key 1
sleep 0.8
TH=$((800 - 28 - 148))
clk $((1280 - 114)) $((TH + 12))
sleep 0.8
alive || { echo "SMOKE FAIL: app died on terminal 2x"; exit 1; }
shot terminal-2x

# Esc safety — typing + Esc must NOT quit the app (footgun regression)
key 2
sleep 0.8
xdt type "fig"
sleep 0.4
key Escape
sleep 0.6
alive || { echo "SMOKE FAIL: Esc quit the app"; exit 1; }
shot esc-safety

shot final
echo "SMOKE PASS — $(ls "$OUT"/*.png | wc -l) screenshots in $OUT"
