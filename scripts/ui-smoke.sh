#!/usr/bin/env bash
# ui-smoke.sh — headless UI smoke test for the native desktop GUI.
#
# Boots the desktop binary on a virtual X server (or an existing DISPLAY),
# drives it with xdotool and saves a screenshot per state. Exits non-zero if
# the app dies at any step or a screenshot is missing.
#
# Requirements: Xvfb (or a free DISPLAY), xdotool, ImageMagick `import`.
# Usage:
#   ./scripts/ui-smoke.sh                # builds nothing — uses build/ binary
#   SMOKE_BIN=./my-atk ./scripts/ui-smoke.sh
#   KEEP_DISPLAY=1 ./scripts/ui-smoke.sh # reuse an already-running Xvfb :99
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SMOKE_BIN:-$ROOT/build/agent-toolkit-desktop-native}"
OUT="${SMOKE_OUT:-/tmp/atk-ui-smoke}"
XD="${XDOTOOL:-xdotool}"
XLIB=""
if ! command -v "$XD" >/dev/null && [ -x /tmp/opencode/xtools/usr/bin/xdotool ]; then
	XD=/tmp/opencode/xtools/usr/bin/xdotool
	XLIB=/tmp/opencode/xtools/usr/lib
fi
# xdt — run xdotool with its private lib path scoped per-call (a leaked
# LD_LIBRARY_PATH breaks ImageMagick's import argument parsing)
xdt() { LD_LIBRARY_PATH="${XLIB}" "$XD" "$@"; }
key() { xdt key "$@" 2>/dev/null || true; }
clk() { xdt mousemove "$1" "$2" click 1; }

if [ ! -x "$BIN" ]; then
	echo "error: $BIN not found — build it first (see docs/desktop/PACKAGING.md)" >&2
	exit 2
fi
for tool in "$XD" import; do  # shellcheck disable=SC2046 # two binaries
	command -v "$tool" >/dev/null || { echo "error: $tool missing" >&2; exit 2; }
done

mkdir -p "$OUT"
fail() { echo "SMOKE FAIL: $1" >&2; exit 1; }

# 1. virtual display
if [ "${KEEP_DISPLAY:-0}" != "1" ]; then
	(Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/tmp/atk-xvfb.log 2>&1 &) || true
	sleep 1
fi
# never inherit the caller's display — the smoke owns its virtual screen
export DISPLAY="${SMOKE_DISPLAY:-:99}"

# 2. boot the app
("$BIN" >"$OUT/app.log" 2>&1 &)
sleep 3
WID="$(xdt search --name 'Agent Toolkit' | head -1)"
[ -n "$WID" ] || fail "window not found"
xdt windowfocus "$WID" 2>/dev/null || true
# click the letterhead strip — gives the app keyboard focus without pressing a row
clk 400 70
sleep 0.6
shot() { sleep 1.2; import -window root "$OUT/$1.png" || fail "screenshot $1"; }
key() { key "$@" 2>/dev/null || true; }
alive() { pgrep -f "$(basename "$BIN")$" >/dev/null || pgrep -x "$(basename "$BIN" | cut -c1-15)" >/dev/null; }

# 3. dock navigation — every panel must render without killing the app
for i in 0 1 2 3 4 5 6 7 8 9; do
	clk 100 $((53 + i * 32 + 14))
	sleep 0.8
	alive || fail "app died on panel $i"
done
shot panels-tour

# 4. palette — open, type, filter, Enter navigates
key slash; sleep 0.5
xdt type "insights"; sleep 0.5
key Return; sleep 1.2
alive || fail "app died after palette Enter"
shot insights

# 5. insights tabs — realtime + gallery (click by geometry: fx+16 + i*(84+6))
for gx in 716 806; do
	clk "$gx" 111
	sleep 0.8
	alive || fail "app died on insights tab $gx"
done
shot insights-gallery

# 6. language cycle EN→ES→中文→عربي (header chips) + back
for cx in 873 913 953 833; do
	clk "$cx" 19
	sleep 0.6
	alive || fail "app died on language chip $cx"
done
shot i18n

# 7. terminal height modes 2× + back to 1× (header buttons)
key 1; sleep 0.8 # World
TH=$(( $(xdt getdisplaygeometry | cut -d' ' -f2) - 28 - 148 ))
clk $(( 1280 - 114 )) $(( TH + 12 )); sleep 0.8
alive || fail "app died on terminal 2x"
shot terminal-2x

# 8. Esc safety — typing + Esc must NOT quit
key 2; sleep 0.8
xdt type "fig"; sleep 0.4
key Escape; sleep 0.6
alive || fail "Esc quit the app (footgun regression)"
shot esc-safety

# 9. done — leave the last screenshot and pass
shot final
echo "SMOKE PASS — $(ls "$OUT"/*.png | wc -l) screenshots in $OUT"
