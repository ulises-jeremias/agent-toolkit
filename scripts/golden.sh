#!/usr/bin/env bash
# golden.sh — golden-image regression captures for the desktop GUI.
#
# capture mode (default): boot the app on the virtual display, navigate every
# panel and save one fixture PNG per panel into tests/golden/.
# compare mode: re-capture and ImageMagick-compare against fixtures; fails on
# RMSE above the tolerance (catches layout drift and .notdef tofu).
#
# Usage:
#   ./scripts/golden.sh capture            # (re)create fixtures
#   ./scripts/golden.sh compare [fuzz%]    # default fuzz 8%
# Requires: Xvfb/xdotool (see scripts/ui-smoke.sh), ImageMagick, built binary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SMOKE_BIN:-$ROOT/build/agent-toolkit-desktop-native}"
GOLD="$ROOT/tests/golden"
MODE="${1:-capture}"
FUZZ="${2:-8}"
XD="${XDOTOOL:-xdotool}"
XLIB=""
if ! command -v "$XD" >/dev/null && [ -x /tmp/opencode/xtools/usr/bin/xdotool ]; then
	XD=/tmp/opencode/xtools/usr/bin/xdotool
	XLIB=/tmp/opencode/xtools/usr/lib
fi
xdt() { DISPLAY="${DISPLAY:-:77}" LD_LIBRARY_PATH="$XLIB" "$XD" "$@"; }
shot() { sleep 1.2; DISPLAY="${DISPLAY:-:77}" import -window "$WID" "$1"; }

[ -x "$BIN" ] || { echo "error: build the desktop binary first" >&2; exit 2; }
mkdir -p "$GOLD"

# virtual display + app (Wayland forced off — sokol prefers it when present)
pkill -f 'agent-toolkit-desktop-native' 2>/dev/null || true
# Xvfb servers degrade after many client cycles — always start a fresh one
pkill -x Xvfb 2>/dev/null || true
sleep 0.5
rm -f /tmp/.X11-unix/X77
/usr/bin/env Xvfb :77 -screen 0 1280x800x24 -nolisten tcp >/tmp/atk-golden-xvfb.log 2>&1 &
sleep 1.5
xprobe_ok=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	if timeout 5 env DISPLAY=:77 LD_LIBRARY_PATH="$XLIB" "$XD" getdisplaygeometry >/dev/null 2>&1; then
		xprobe_ok=1
		break
	fi
	sleep 1
done
[ "$xprobe_ok" = "1" ] || {
	echo "error: Xvfb :77 not responding" >&2
	exit 2
}
rm -f "$HOME/.cache/agent-toolkit/desktop/ui_state.env"
(env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET ATK_GUI_FREEZE=1 DISPLAY=:77 "$BIN" >"$GOLD/../golden-app.log" 2>&1 &)
sleep 3
WID="$(xdt search --name 'Agent Toolkit' | head -1)"
[ -n "$WID" ] || { echo "error: window not found" >&2; exit 2; }

fail=0
for i in 0 1 2 3 4 5 6 7 8 9 11 12; do
	xdt mousemove 100 $((53 + i * 32 + 14)) click 1
	sleep 1
	name="panel-$(printf '%02d' "$i")"
	if [ "$MODE" = "capture" ]; then
		shot "$GOLD/$name.png"
		echo "captured $name"
	else
		tmp="$GOLD/$name.new.png"
		shot "$tmp"
		if [ ! -f "$GOLD/$name.png" ]; then
			echo "FAIL $name: fixture missing"
			fail=1
			continue
		fi
		rmse=$(compare -metric RMSE -fuzz "$FUZZ%" "$GOLD/$name.png" "$tmp" "$tmp.diff.png" 2>&1 || true)
		rm -f "$tmp.diff.png" "$tmp"
		if [ -z "$rmse" ] || [ "${rmse%% *}" = "0" ] || [ "$(echo "$rmse" | cut -d' ' -f1)" = "0" ]; then
			echo "OK   $name ($rmse)"
		else
			echo "FAIL $name: RMSE $rmse exceeds tolerance"
			fail=1
		fi
	fi
done

pkill -f 'agent-toolkit-desktop-native' 2>/dev/null || true
if [ "$MODE" = "compare" ]; then
	[ "$fail" = "0" ] && echo "GOLDEN PASS" || { echo "GOLDEN FAIL"; exit 1; }
else
	echo "GOLDEN CAPTURE DONE — $(ls "$GOLD" | wc -l) fixtures in $GOLD"
fi
