#!/usr/bin/env bash
# golden.sh — golden-image regression captures for the desktop GUI.
#
# capture mode (default): boot the app on the virtual display, navigate every
# panel and save one fixture PNG per panel into tests/golden/.
# The tour boots with ATK_GOLDEN_TERMINAL=1 so the integrated terminal well
# stays open (compact 1×): the canonical design references show it open on
# every destination, and the tour doubles as the compact-terminal-visible
# responsive state.
# compare mode: re-capture and ImageMagick-compare against fixtures; fails on
# RMSE above the tolerance (catches layout drift and .notdef tofu).
#
# Usage:
#   ./scripts/golden.sh capture            # (re)create fixtures
#   ./scripts/golden.sh compare [fuzz%]    # default fuzz 8%
#   ATK_GOLDEN_THEME=ink ./scripts/golden.sh capture|compare  # Ink fixtures
# Requires: Xvfb/xdotool (see scripts/ui-smoke.sh), ImageMagick, built binary.
#
# Display constraint: captures run on a FIXED display (default :77,
# GOLDEN_DISPLAY to override) because the window id is captured per run.
# A lock file guards it so two local runs fail loudly instead of colliding.
# The app runs under a temp HOME/XDG — real ~/.cache prefs are never read
# or written. Temp paths honor $TMPDIR. System Xvfb/xdotool are preferred;
# /tmp/opencode/xtools fallbacks stay (CI may rely on them).
#
# Fixture update policy (#1111): intentional visual changes re-capture with
# capture (both themes) and include the RMSE summary in the PR description.
# Never hand-edit a fixture; compare passing on the old set is the no-drift
# proof — capture only after that proof is recorded.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SMOKE_BIN:-$ROOT/build/agent-toolkit-desktop-native}"
GOLD="$ROOT/tests/golden"
if [ "${ATK_GOLDEN_THEME:-paper}" = "ink" ]; then
	GOLD="$ROOT/tests/golden/ink"
fi
MODE="${1:-capture}"
FUZZ="${2:-8}"
XD="${XDOTOOL:-xdotool}"
# preserve a caller-provided LD_LIBRARY_PATH (user-space Xvfb/xdotool installs
# whose libs are not on the system loader path); default empty as before
XLIB="${LD_LIBRARY_PATH:-}"
if ! command -v "$XD" >/dev/null && [ -x /tmp/opencode/xtools/usr/bin/xdotool ]; then
	XD=/tmp/opencode/xtools/usr/bin/xdotool
	XLIB=/tmp/opencode/xtools/usr/lib
fi
XVFB="${XVFB:-Xvfb}"
if ! command -v "$XVFB" >/dev/null 2>&1 && [ -x /tmp/opencode/xtools/usr/bin/Xvfb ]; then
	XVFB=/tmp/opencode/xtools/usr/bin/Xvfb
fi
# timeout guards: a degraded Xvfb hangs xdotool/import forever — fail fast
# instead (#1111; observed on a long-lived :77 server)
EFFDIS="${GOLDEN_DISPLAY:-:77}"
EFFNUM="${EFFDIS#:}"
xdt() { DISPLAY="$EFFDIS" LD_LIBRARY_PATH="$XLIB" timeout 30 "$XD" "$@"; }
shot() { sleep 1.2; DISPLAY="$EFFDIS" timeout 60 import -window "$WID" "$1"; }

[ -x "$BIN" ] || { echo "error: build the desktop binary first" >&2; exit 2; }
mkdir -p "$GOLD"

# fixed-display lock: only processes owned by this run are ever signalled
LOCK="${TMPDIR:-/tmp}/atk-golden-X${EFFNUM}.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
	owner="$(cat "$LOCK/pid" 2>/dev/null || echo unknown)"
	if [ "$owner" != unknown ] && ! kill -0 "$owner" 2>/dev/null; then
		echo "warning: stealing stale golden lock $LOCK (owner $owner dead)" >&2
		rm -rf "$LOCK"
		mkdir "$LOCK" || { echo "error: cannot take golden lock $LOCK" >&2; exit 2; }
	else
		echo "error: display $EFFDIS is locked by another golden run (owner pid $owner)" >&2
		exit 2
	fi
fi
echo "$$" >"$LOCK/pid"

# temp HOME/XDG: the app must never read or write real user prefs
GOLDEN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/atk-golden-home-XXXXXX")"
export HOME="$GOLDEN_HOME"
export XDG_CACHE_HOME="$GOLDEN_HOME/.cache"
export XDG_CONFIG_HOME="$GOLDEN_HOME/.config"
export XDG_DATA_HOME="$GOLDEN_HOME/.local/share"

XVFB_PID=0
APP_PID=0
cleanup_golden() {
	if [ "$APP_PID" != 0 ]; then kill "$APP_PID" 2>/dev/null || true; fi
	if [ "$XVFB_PID" != 0 ]; then kill "$XVFB_PID" 2>/dev/null || true; fi
	if [ "$APP_PID" != 0 ]; then wait "$APP_PID" 2>/dev/null || true; fi
	if [ "$XVFB_PID" != 0 ]; then wait "$XVFB_PID" 2>/dev/null || true; fi
	rm -rf "$GOLDEN_HOME" "$LOCK"
}
trap cleanup_golden EXIT

# virtual display + app (Wayland forced off — sokol prefers it when present).
# Xvfb servers degrade after many client cycles — always start a fresh one
# owned by this run (PID-scoped kills only, never pkill).
sleep 0.5
rm -f "/tmp/.X11-unix/X${EFFNUM}"
/usr/bin/env "$XVFB" "$EFFDIS" -screen 0 1280x800x24 -nolisten tcp >"${TMPDIR:-/tmp}/atk-golden-xvfb.log" 2>&1 &
XVFB_PID=$!
sleep 1.5
xprobe_ok=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
	if timeout 5 env DISPLAY="$EFFDIS" LD_LIBRARY_PATH="$XLIB" "$XD" getdisplaygeometry >/dev/null 2>&1; then
		xprobe_ok=1
		break
	fi
	sleep 1
done
[ "$xprobe_ok" = "1" ] || {
	echo "error: Xvfb $EFFDIS not responding" >&2
	exit 2
}
# Paper determinism: temp HOME starts clean, so no ui_state.env exists yet.
if [ "${ATK_GOLDEN_THEME:-paper}" = "ink" ]; then
	# seed Ink appearance under the TEMP home only
	mkdir -p "$HOME/.cache/agent-toolkit/desktop"
	printf 'appearance=ink\n' >"$HOME/.cache/agent-toolkit/desktop/ui_state.env"
fi
env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET ATK_GUI_FREEZE=1 ATK_GOLDEN_TERMINAL=1 DISPLAY="$EFFDIS" "$BIN" >"$ROOT/tests/golden-app.log" 2>&1 &
APP_PID=$!
# software GL (llvmpipe) needs longer than 3s for the first frame — poll
WID=""
for _ in $(seq 1 45); do
	WID="$(xdt search --name 'Agent Toolkit' | head -1 || true)"
	[ -n "$WID" ] && break
	sleep 2
done
[ -n "$WID" ] || { echo "error: window not found" >&2; exit 2; }
sleep 8
# First launch owns the screen. Dismiss setup explicitly before the panel tour;
# destination shortcuts are intentionally blocked while onboarding is modal.
xdt key Escape
sleep 1

fail=0
# panel tour via numeric shortcuts (1..9,0,P,I) — deterministic across nav layouts
for k in 1 2 3 4 5 6 7 8 9 0 p i o; do
	xdt key "$k"
	sleep 1
	case "$k" in
		p) name="panel-products" ;;
		i) name="panel-insights" ;;
		o) name="panel-onboarding" ;;
		0) name="panel-09" ;;
		*) name="panel-$(printf '%02d' $((k - 1)))" ;;
	esac
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
		# Live Engine data (log timestamps, activity pulses) moves between capture
		# and compare even under ATK_GUI_FREEZE — that is ~0.2% normalized RMSE.
		# Fail only on layout-scale drift (tofu, missing panels, moved chrome).
		# Passing shots are deleted; failures keep $tmp.new.png + .diff for forensics (#1111).
		norm=$(echo "$rmse" | grep -oE '\(0?\.[0-9]+\)' | tr -d '()' || true)
		if [ -z "$rmse" ] || [ "${rmse%% *}" = "0" ] || [ "$(echo "$rmse" | cut -d' ' -f1)" = "0" ]; then
			rm -f "$tmp.diff.png" "$tmp"
			echo "OK   $name ($rmse)"
		elif [ -n "$norm" ] && awk -v n="$norm" 'BEGIN { exit (n < 0.01) ? 0 : 1 }'; then
			rm -f "$tmp.diff.png" "$tmp"
			echo "OK   $name ($rmse — live-data noise under 2%)"
		else
			echo "FAIL $name: RMSE $rmse exceeds tolerance (kept $tmp + $tmp.diff.png)"
			fail=1
		fi
	fi
done

# owned processes die via the EXIT trap (PID-scoped, never pkill)
if [ "$MODE" = "compare" ]; then
	[ "$fail" = "0" ] && echo "GOLDEN PASS" || { echo "GOLDEN FAIL"; exit 1; }
else
	echo "GOLDEN CAPTURE DONE — $(ls "$GOLD" | wc -l) fixtures in $GOLD"
fi
