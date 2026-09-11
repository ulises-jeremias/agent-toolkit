#!/usr/bin/env -S v run
// ui-smoke.vsh — headless UI smoke test for the native desktop GUI.
//
// Boots the desktop binary on a fresh Xvfb, drives it with xdotool and saves
// a screenshot per state. App-alive checks are the assertions.
//
// KNOWN LIMITATION: xdotool can SIGSEGV intermittently under rapid XTEST
// automation on bare Xvfb (libxdo/Xvfb interaction, unrelated to the app).
// Every xdotool call is guarded; a rare run may abort with 139 — re-run.
//
// Requirements: Xvfb + xdotool + ImageMagick `import` (paths auto-probed).
// Usage: ./scripts/ui-smoke.vsh  [SMOKE_BIN=...] [SMOKE_OUT=/tmp/...]
//
// Display constraint: the smoke runs on a FIXED display (default :99,
// SMOKE_DISPLAY to override) because tour coordinates are display-bound.
// A lockd file guards it so two local runs fail loudly instead of colliding.
// The app runs under a temp HOME/XDG — real ~/.cache prefs are never read
// or written. Temp paths honor $TMPDIR. System Xvfb/xdotool are preferred;
// /tmp/opencode/xtools fallbacks stay (CI may rely on them).
//
// Process model: Xvfb and the app spawn detached (PID recorded); cleanup is
// PID-scoped (never pkill) and runs on every exit path via fail()/main-end,
// mirroring the retired script's EXIT trap, with a bounded death poll then
// SIGKILL (the shell version's unbounded wait could hang on TERM-ignorers).

import os
import time

fn C.kill(pid int, sig int) int

const sigterm = 15
const sigkill = 9

struct Ctx {
mut:
	root     string
	bin      string
	out      string
	xd       string
	xlib     string
	xvfb     string
	effdis   string
	effnum   string
	lockd    string
	home     string
	xvfb_pid int
	app_pid  int
	wid      string
}

fn sh(cmd string) os.Result {
	return os.execute(cmd)
}

fn fail(mut c Ctx, msg string, code int) {
	eprintln(msg)
	cleanup(mut c)
	exit(code)
}

fn cleanup(mut c Ctx) {
	for pid in [c.app_pid, c.xvfb_pid] {
		if pid != 0 {
			C.kill(pid, sigterm)
		}
	}
	for _ in 0 .. 50 {
		mut alive := false
		for pid in [c.app_pid, c.xvfb_pid] {
			if pid != 0 && C.kill(pid, 0) == 0 {
				alive = true
			}
		}
		if !alive {
			break
		}
		time.sleep(100 * time.millisecond)
	}
	for pid in [c.app_pid, c.xvfb_pid] {
		if pid != 0 && C.kill(pid, 0) == 0 {
			C.kill(pid, sigkill)
		}
	}
	if c.home != '' {
		os.rmdir_all(c.home) or {}
	}
	if c.lockd != '' {
		os.rmdir_all(c.lockd) or {}
	}
	c.app_pid = 0
	c.xvfb_pid = 0
}

fn spawn_detached(cmd string, log string) int {
	r := sh("${cmd} >> '${log}' 2>&1 & echo \$!")
	return r.output.trim_space().int()
}

fn lock_owner_dead(lockd string) (string, bool) {
	raw := os.read_file(os.join_path(lockd, 'pid')) or { 'unknown' }
	owner := raw.trim_space()
	if owner == 'unknown' {
		return owner, true
	}
	owner_pid := owner.int()
	if owner_pid == 0 || C.kill(owner_pid, 0) != 0 {
		return owner, true
	}
	return owner, false
}

fn take_lock(mut c Ctx) {
	lockd := c.lockd
	os.mkdir(lockd) or {
		owner, dead := lock_owner_dead(lockd)
		if !dead {
			fail(mut c, 'error: display ${c.effdis} is locked by another ui-smoke run (owner pid ${owner})',
				2)
		}
		eprintln('warning: stealing stale ui-smoke lockd ${lockd} (owner ${owner} dead)')
		os.rmdir_all(lockd) or {}
		os.mkdir(lockd) or {
			fail(mut c, 'error: cannot take ui-smoke lockd ${lockd}', 2)
		}
	}
	os.write_file(os.join_path(lockd, 'pid'), '${os.getpid()}') or {}
}

// xdt mirrors the retired `xdt()` — guarded (exit status ignored by callers
// that probe), display-scoped, XTEST-safe.
fn (c Ctx) xdt(args string) os.Result {
	return sh('DISPLAY="${c.effdis}" LD_LIBRARY_PATH="${c.xlib}" ${c.xd} ${args} 2>/dev/null || true')
}

fn (c Ctx) alive() bool {
	return c.app_pid != 0 && C.kill(c.app_pid, 0) == 0
}

fn (mut c Ctx) shot(name string) {
	time.sleep(1200 * time.millisecond)
	for _ in 0 .. 3 {
		r := sh('import -window "${c.wid}" "${c.out}/${name}.png" 2>/dev/null')
		if r.exit_code == 0 {
			return
		}
		time.sleep(500 * time.millisecond)
	}
	fail(mut c, 'SMOKE FAIL: screenshot ${name}', 1)
}

fn main() {
	mut c := Ctx{}
	c.root = os.dir(os.dir(@FILE))
	if !os.is_file(os.join_path(c.root, 'VERSION')) {
		c.root = os.getwd()
	}
	c.bin = os.getenv_opt('SMOKE_BIN') or { os.join_path(c.root, 'build', 'agent-toolkit-desktop-native') }
	c.out = os.getenv_opt('SMOKE_OUT') or {
		os.join_path(os.getenv_opt('TMPDIR') or { '/tmp' }, 'atk-ui-smoke')
	}
	c.xd = os.getenv_opt('XDOTOOL') or { 'xdotool' }
	c.xlib = os.getenv_opt('LD_LIBRARY_PATH') or { '' }
	if sh('command -v ${c.xd}').exit_code != 0
		&& os.is_executable('/tmp/opencode/xtools/usr/bin/xdotool') {
		c.xd = '/tmp/opencode/xtools/usr/bin/xdotool'
		c.xlib = '/tmp/opencode/xtools/usr/lib'
	}
	c.xvfb = os.getenv_opt('XVFB') or { 'Xvfb' }
	if sh('command -v ${c.xvfb}').exit_code != 0
		&& os.is_executable('/tmp/opencode/xtools/usr/bin/Xvfb') {
		c.xvfb = '/tmp/opencode/xtools/usr/bin/Xvfb'
	}
	c.effdis = os.getenv_opt('SMOKE_DISPLAY') or { ':99' }
	c.effnum = c.effdis.trim_left(':')
	tmpd := os.getenv_opt('TMPDIR') or { '/tmp' }
	os.setenv('DISPLAY', c.effdis, true)

	os.mkdir_all(c.out) or {}
	c.lockd = os.join_path(tmpd, 'atk-uismoke-X${c.effnum}.lockd')
	take_lock(mut c)
	defer {
		cleanup(mut c)
	}

	// temp HOME/XDG: the app must never read or write real user prefs
	mk := sh('mktemp -d "${tmpd}/atk-uismoke-home-XXXXXX"')
	c.home = mk.output.trim_space()
	os.setenv('HOME', c.home, true)
	os.setenv('XDG_CACHE_HOME', os.join_path(c.home, '.cache'), true)
	os.setenv('XDG_CONFIG_HOME', os.join_path(c.home, '.config'), true)
	os.setenv('XDG_DATA_HOME', os.join_path(c.home, '.local', 'share'), true)

	// fresh Xvfb every run (servers degrade after many client cycles),
	// owned by this run (PID-scoped kills only, never pkill)
	time.sleep(500 * time.millisecond)
	os.rm('/tmp/.X11-unix/X${c.effnum}') or {}
	xvfb_log := os.join_path(tmpd, 'atk-xvfb.log')
	c.xvfb_pid = spawn_detached('/usr/bin/env ${c.xvfb} ${c.effdis} -screen 0 1280x800x24 -nolisten tcp',
		xvfb_log)
	time.sleep(2 * time.second)
	mut up := false
	for _ in 0 .. 10 {
		if c.xdt('getdisplaygeometry').exit_code == 0 {
			up = true
			break
		}
		time.sleep(time.second)
	}
	if !up {
		fail(mut c, 'SMOKE FAIL: Xvfb not responding', 1)
	}

	// boot the app — Wayland forced off (sokol prefers it when present).
	// Direct background (no subshell) so APP_PID is the owned app process.
	app_log := os.join_path(c.out, 'app.log')
	c.app_pid = spawn_detached('env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET DISPLAY="${c.effdis}" "${c.bin}"',
		app_log)
	// software GL (llvmpipe) needs longer than 3s for the first frame — poll
	for _ in 0 .. 45 {
		r := c.xdt("search --name 'Agent Toolkit'")
		if r.exit_code == 0 {
			first := r.output.split_into_lines()
			if first.len > 0 && first[0].trim_space() != '' {
				c.wid = first[0].trim_space()
				break
			}
		}
		time.sleep(2 * time.second)
	}
	if c.wid == '' {
		fail(mut c, 'SMOKE FAIL: window not found', 1)
	}
	time.sleep(8 * time.second)
	c.xdt('windowfocus ${c.wid}')
	c.xdt('mousemove 400 70 click 1') // letterhead click = keyboard focus without pressing a row
	time.sleep(600 * time.millisecond)

	// panel tour — numeric shortcuts cover every panel; onboarding via o
	for k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'p', 'i', 'o'] {
		c.xdt('key ${k}')
		time.sleep(500 * time.millisecond)
		if !c.alive() {
			fail(mut c, 'SMOKE FAIL: app died on panel key ${k}', 1)
		}
	}
	// dock group clicks — bottom-up so expanding a group never shifts a row
	// that is still to be clicked (rows start y=58, groups step 40px)
	for gy in [258, 218, 178, 138, 98, 58] {
		c.xdt('mousemove 100 ${gy + 18} click 1')
		time.sleep(600 * time.millisecond)
		if !c.alive() {
			fail(mut c, 'SMOKE FAIL: app died on dock group y=${gy}', 1)
		}
	}
	c.shot('panels-tour')

	// palette — open, type, filter, Enter navigates
	c.xdt('key slash')
	time.sleep(500 * time.millisecond)
	c.xdt('type "insights"')
	time.sleep(500 * time.millisecond)
	c.xdt('key Return')
	time.sleep(1200 * time.millisecond)
	if !c.alive() {
		fail(mut c, 'SMOKE FAIL: app died after palette Enter', 1)
	}
	c.shot('insights')

	// insights tabs — realtime + gallery (geometry: fx+16 + i*(84+6))
	for gx in [716, 806] {
		c.xdt('mousemove ${gx} 111 click 1')
		time.sleep(800 * time.millisecond)
		if !c.alive() {
			fail(mut c, 'SMOKE FAIL: app died on insights tab ${gx}', 1)
		}
	}
	c.shot('insights-gallery')

	// language cycle EN→ES→中文→عربي→EN (header chips at w-180 + i*34, y 10..32)
	for cx in [1100, 1134, 1168, 1202] {
		c.xdt('mousemove ${cx} 21 click 1')
		time.sleep(600 * time.millisecond)
		if !c.alive() {
			fail(mut c, 'SMOKE FAIL: app died on language chip ${cx}', 1)
		}
	}
	c.shot('i18n')

	// terminal 2× mode (header button; TH = display height - status - compact term)
	c.xdt('key 1')
	time.sleep(800 * time.millisecond)
	th := 800 - 28 - 148
	c.xdt('mousemove ${1280 - 114} ${th + 12} click 1')
	time.sleep(800 * time.millisecond)
	if !c.alive() {
		fail(mut c, 'SMOKE FAIL: app died on terminal 2x', 1)
	}
	c.shot('terminal-2x')

	// Esc safety — typing + Esc must NOT quit the app (footgun regression)
	c.xdt('key 2')
	time.sleep(800 * time.millisecond)
	c.xdt('type "fig"')
	time.sleep(400 * time.millisecond)
	c.xdt('key Escape')
	time.sleep(600 * time.millisecond)
	if !c.alive() {
		fail(mut c, 'SMOKE FAIL: Esc quit the app', 1)
	}
	c.shot('esc-safety')

	c.shot('final')
	println('SMOKE PASS — ${(os.ls(c.out) or { []string{} }).filter(it.ends_with('.png')).len} screenshots in ${c.out}')
}
