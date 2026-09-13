#!/usr/bin/env -S v run
// golden.vsh — golden-image regression captures for the desktop GUI.
//
// capture mode (default): boot the app on the virtual display, navigate every
// panel and save one fixture PNG per panel into tests/golden/.
// The tour boots with ATK_GOLDEN_TERMINAL=1 so the integrated terminal well
// stays open (compact 1×): the canonical design references show it open on
// every destination, and the tour doubles as the compact-terminal-visible
// responsive state.
// compare mode: re-capture and ImageMagick-compare against fixtures; fails on
// RMSE above the tolerance (catches layout drift and .notdef tofu).
//
// Usage:
//   ./scripts/golden.vsh capture            # (re)create fixtures
//   ./scripts/golden.vsh compare [fuzz%]    # default fuzz 8%
//   ATK_GOLDEN_THEME=ink ./scripts/golden.vsh capture|compare  # Ink fixtures
// Requires: Xvfb/xdotool (see scripts/ui-smoke.vsh), ImageMagick, built binary.
//
// Display constraint: captures run on a FIXED display (default :77,
// GOLDEN_DISPLAY to override) because the window id is captured per run.
// A lock file guards it so two local runs fail loudly instead of colliding.
// The app runs under a temp HOME/XDG — real ~/.cache prefs are never read
// or written. Temp paths honor $TMPDIR. System Xvfb/xdotool are preferred;
// /tmp/opencode/xtools fallbacks stay (CI may rely on them).
//
// Fixture update policy (#1111): intentional visual changes re-capture with
// capture (both themes) and include the RMSE summary in the PR description.
// Never hand-edit a fixture; compare passing on the old set is the no-drift
// proof — capture only after that proof is recorded.
//
// Process model: Xvfb and the app spawn detached (PID recorded); cleanup is
// PID-scoped (never pkill) and runs on every exit path via fail()/main-end,
// mirroring the retired script's EXIT trap. After SIGTERM each owned process
// gets a bounded death poll, then SIGKILL — the shell version's unbounded
// wait() could hang forever on a TERM-ignoring process.

import os
import time

fn C.kill(pid int, sig int) int

const sigterm = 15
const sigkill = 9

struct GoldenRun {
mut:
	root     string
	bin      string
	gold     string
	mode     string
	fuzz     string
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
	fail     int
}

// sh runs a foreground shell command (inherits this process's environment;
// per-command env rides in the command string, like the retired script).
fn sh(cmd string) os.Result {
	return os.execute(cmd)
}

fn fail(mut c GoldenRun, msg string, code int) {
	eprintln(msg)
	cleanup(mut c)
	exit(code)
}

fn cleanup(mut c GoldenRun) {
	for pid in [c.app_pid, c.xvfb_pid] {
		if pid != 0 {
			C.kill(pid, sigterm)
		}
	}
	// Bounded death poll, then SIGKILL stragglers (see header).
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

// spawn_detached starts cmd with stdout+stderr appended to log and returns
// the child's PID (the `$!` of a backgrounded shell, like `cmd &` + `$!`).
fn spawn_detached(cmd string, log string) int {
	r := sh("${cmd} >> '${log}' 2>&1 & echo \$!")
	pid := r.output.trim_space().int()
	return pid
}

fn (c GoldenRun) xdt(args string) os.Result {
	return sh('DISPLAY="${c.effdis}" LD_LIBRARY_PATH="${c.xlib}" timeout 30 ${c.xd} ${args}')
}

fn (c GoldenRun) shot(path string) bool {
	time.sleep(1200 * time.millisecond)
	r := sh('DISPLAY="${c.effdis}" timeout 60 import -window ${c.wid} "${path}"')
	return r.exit_code == 0
}

fn pad2(n int) string {
	return if n < 10 { '0${n}' } else { '${n}' }
}

// rmse_norm extracts the normalized `(0.xxx)` figure from compare output.
fn rmse_norm(rmse string) string {
	mut i := rmse.index('(') or { return '' }
	for i < rmse.len {
		j := rmse[i..].index(')') or { return '' }
		inner := rmse[i + 1..i + j]
		if inner.starts_with('0.') || inner.starts_with('.') {
			mut ok := inner.len > 1
			for ch in inner {
				if !(ch.is_digit() || ch == `.`) {
					ok = false
					break
				}
			}
			if ok {
				return inner
			}
		}
		i = i + j + 1
		if i >= rmse.len {
			break
		}
	}
	return ''
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

fn take_lock(mut c GoldenRun) {
	lockd := c.lockd
	os.mkdir(lockd) or {
		owner, dead := lock_owner_dead(lockd)
		if !dead {
			fail(mut c, 'error: display ${c.effdis} is locked by another golden run (owner pid ${owner})',
				2)
		}
		eprintln('warning: stealing stale golden lock ${lockd} (owner ${owner} dead)')
		os.rmdir_all(lockd) or {}
		os.mkdir(lockd) or {
			fail(mut c, 'error: cannot take golden lock ${lockd}', 2)
		}
	}
	os.write_file(os.join_path(lockd, 'pid'), '${os.getpid()}') or {}
}

fn main() {
	mut args := os.args.clone()
	if args.len > 0 {
		args = args[1..].clone()
	}
	if args.len > 0 && args[0].ends_with('.vsh') {
		args = args[1..].clone()
	}
	mut c := GoldenRun{}
	c.root = os.dir(os.dir(@FILE))
	if !os.is_file(os.join_path(c.root, 'VERSION')) {
		c.root = os.getwd()
	}
	c.bin = os.getenv_opt('SMOKE_BIN') or { os.join_path(c.root, 'build', 'agent-toolkit-desktop-native') }
	c.gold = os.join_path(c.root, 'tests', 'golden')
	if (os.getenv_opt('ATK_GOLDEN_THEME') or { 'paper' }) == 'ink' {
		c.gold = os.join_path(c.root, 'tests', 'golden', 'ink')
	}
	c.mode = if args.len > 0 { args[0] } else { 'capture' }
	c.fuzz = if args.len > 1 { args[1] } else { '8' }
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
	c.effdis = os.getenv_opt('GOLDEN_DISPLAY') or { ':77' }
	c.effnum = c.effdis.trim_left(':')
	tmpd := os.getenv_opt('TMPDIR') or { '/tmp' }

	if !os.is_executable(c.bin) {
		fail(mut c, 'error: build the desktop binary first', 2)
	}
	os.mkdir_all(c.gold) or {}
	c.lockd = os.join_path(tmpd, 'atk-golden-X${c.effnum}.lock')
	take_lock(mut c)
	defer {
		cleanup(mut c)
	}

	// temp HOME/XDG: the app must never read or write real user prefs
	mk := sh('mktemp -d "${tmpd}/atk-golden-home-XXXXXX"')
	c.home = mk.output.trim_space()
	os.setenv('HOME', c.home, true)
	os.setenv('XDG_CACHE_HOME', os.join_path(c.home, '.cache'), true)
	os.setenv('XDG_CONFIG_HOME', os.join_path(c.home, '.config'), true)
	os.setenv('XDG_DATA_HOME', os.join_path(c.home, '.local', 'share'), true)

	// virtual display + app (Wayland forced off — sokol prefers it when present).
	// Xvfb servers degrade after many client cycles — always start a fresh one
	// owned by this run (PID-scoped kills only, never pkill).
	time.sleep(500 * time.millisecond)
	os.rm('/tmp/.X11-unix/X${c.effnum}') or {}
	xvfb_log := os.join_path(tmpd, 'atk-golden-xvfb.log')
	c.xvfb_pid = spawn_detached('/usr/bin/env ${c.xvfb} ${c.effdis} -screen 0 1280x800x24 -nolisten tcp',
		xvfb_log)
	time.sleep(1500 * time.millisecond)
	mut xprobe_ok := false
	for _ in 0 .. 10 {
		r := sh('timeout 5 env DISPLAY="${c.effdis}" LD_LIBRARY_PATH="${c.xlib}" ${c.xd} getdisplaygeometry')
		if r.exit_code == 0 {
			xprobe_ok = true
			break
		}
		time.sleep(time.second)
	}
	if !xprobe_ok {
		fail(mut c, 'error: Xvfb ${c.effdis} not responding', 2)
	}
	// Paper determinism: temp HOME starts clean, so no ui_state.env exists yet.
	if (os.getenv_opt('ATK_GOLDEN_THEME') or { 'paper' }) == 'ink' {
		// seed Ink appearance under the TEMP home only
		os.mkdir_all(os.join_path(c.home, '.cache', 'agent-toolkit', 'desktop')) or {}
		os.write_file(os.join_path(c.home, '.cache', 'agent-toolkit', 'desktop', 'ui_state.env'),
			'appearance=ink\n') or {}
	}
	app_log := os.join_path(c.root, 'tests', 'golden-app.log')
	c.app_pid = spawn_detached('env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET ATK_GUI_FREEZE=1 ATK_GOLDEN_TERMINAL=1 DISPLAY="${c.effdis}" "${c.bin}"',
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
		fail(mut c, 'error: window not found', 2)
	}
	time.sleep(8 * time.second)
	// First launch owns the screen. Dismiss setup explicitly before the panel tour;
	// destination shortcuts are intentionally blocked while onboarding is modal.
	c.xdt('key Escape')
	time.sleep(time.second)

	// panel tour via numeric shortcuts (1..9,0,P,I) — deterministic across nav layouts
	for k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'p', 'i', 'o'] {
		c.xdt('key ${k}')
		time.sleep(time.second)
		name := match k {
			'p' { 'panel-products' }
			'i' { 'panel-insights' }
			'o' { 'panel-onboarding' }
			'0' { 'panel-09' }
			else { 'panel-${pad2(k.int() - 1)}' }
		}
		if c.mode == 'capture' {
			if !c.shot(os.join_path(c.gold, '${name}.png')) {
				fail(mut c, 'error: capture failed for ${name}', 1)
			}
			println('captured ${name}')
		} else {
			tmp := os.join_path(c.gold, '${name}.new.png')
			if !c.shot(tmp) {
				fail(mut c, 'error: capture failed for ${name}', 1)
			}
			if !os.is_file(os.join_path(c.gold, '${name}.png')) {
				println('FAIL ${name}: fixture missing')
				c.fail = 1
				continue
			}
			r := sh('compare -metric RMSE -fuzz "${c.fuzz}%" "${c.gold}/${name}.png" "${tmp}" "${tmp}.diff.png" 2>&1 || true')
			rmse := r.output.trim_space()
			// Live Engine data (log timestamps, activity pulses) moves between capture
			// and compare even under ATK_GUI_FREEZE — that is ~0.2% normalized RMSE.
			// Fail only on layout-scale drift (tofu, missing panels, moved chrome).
			// Passing shots are deleted; failures keep $tmp.new.png + .diff for forensics (#1111).
			norm := rmse_norm(rmse)
			first_field := if rmse.contains(' ') { rmse.split(' ')[0] } else { rmse }
			if rmse == '' || first_field == '0' {
				os.rm('${tmp}.diff.png') or {}
				os.rm(tmp) or {}
				println('OK   ${name} (${rmse})')
			} else if norm != '' && norm.f64() < 0.01 {
				os.rm('${tmp}.diff.png') or {}
				os.rm(tmp) or {}
				println('OK   ${name} (${rmse} — live-data noise under 2%)')
			} else {
				println('FAIL ${name}: RMSE ${rmse} exceeds tolerance (kept ${tmp} + ${tmp}.diff.png)')
				c.fail = 1
			}
		}
	}

	// owned processes die via cleanup (PID-scoped, never pkill)
	if c.mode == 'compare' {
		if c.fail == 0 {
			println('GOLDEN PASS')
		} else {
			println('GOLDEN FAIL')
			cleanup(mut c)
			exit(1)
		}
	} else {
		println('GOLDEN CAPTURE DONE — ${os.ls(c.gold) or { []string{} }.len} fixtures in ${c.gold}')
	}
}
