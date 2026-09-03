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
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SMOKE_BIN:-$ROOT/build/agent-toolkit-desktop-native}"
OUT="${SMOKE_OUT:-/tmp/atk-ui-smoke}"
XD="${XDOTOOL:-xdotool}"
# preserve a caller-provided LD_LIBRARY_PATH (user-space Xvfb/xdotool installs
# whose libs are not on the system loader path); default empty as before
XLIB="${LD_LIBRARY_PATH:-}"
if ! command -v "$XD" >/dev/null && [ -x /tmp/opencode/xtools/usr/bin/xdotool ]; then
	XD=/tmp/opencode/xtools/usr/bin/xdotool
	XLIB=/tmp/opencode/xtools/usr/lib
fi
xdt() { LD_LIBRARY_PATH="$XLIB" "$XD" "$@" 2>/dev/null || true; }
key() { xdt key "$@"; }
clk() { xdt mousemove "$1" "$2" click 1; }

mkdir -p "$OUT"

# fresh Xvfb every run (servers degrade after many client cycles)
pkill -f agent-toolkit-desktop-native 2>/dev/null || true
pkill -x Xvfb 2>/dev/null || true
sleep 0.5
rm -f /tmp/.X11-unix/X99 "$HOME/.cache/agent-toolkit/desktop/ui_state.env"
/tmp/opencode/xtools/usr/bin/Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/tmp/atk-xvfb.log 2>&1 &
sleep 2
export DISPLAY="${SMOKE_DISPLAY:-:99}"
up=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	if xdt getdisplaygeometry >/dev/null 2>&1; then
		up=1
		break
	fi
	sleep 1
done
[ "$up" = "1" ] || { echo "SMOKE FAIL: Xvfb not responding"; exit 1; }

# boot the app — Wayland forced off (sokol prefers it when present)
(env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET DISPLAY="$DISPLAY" "$BIN" >"$OUT/app.log" 2>&1 &)
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
	pgrep -f 'agent-toolkit-desktop-native' >/dev/null 2>&1
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
