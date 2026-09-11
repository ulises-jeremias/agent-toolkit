#!/usr/bin/env -S v run
// enter-regression.vsh — Enter-key regression harness for the desktop GUI.
//
// Pressing Return anywhere in the app (terminal view, palette, onboarding,
// workspace draft field) must route the key through the session key router
// (gg .enter → '\r', see session_key_bytes in cmd/agent-toolkit-desktop)
// and must never kill, hang, or blank the app. This harness:
//
//   1. builds cmd/agent-toolkit-desktop (or uses --bin)
//   2. asserts the headless boot gate prints RUNNING (fast failure gate)
//   3. launches the app under Xvfb, focuses its window, sends Return +
//      text + Return through the real XTEST path, then asserts the
//      process is still alive and the window still maps, with captures.
//
// Gate 3 needs Xvfb + xdotool + import. When they are absent the gate is
// recorded NOT_PROVEN with the reason (explicit state, never a silent
// skip); gates 1–2 still run. CI installs the tools (see
// .github/workflows/clean-machine-acceptance.yml) so CI always executes
// gate 3.
//
// Display: fixed (default :97, ATK_ENTER_DISPLAY to override) guarded by
// the shared acceptance lock file (see scripts/first-run.vsh).
//
// Usage: v run scripts/enter-regression.vsh [--bin <desktop-binary>]
//   SMOKE_BIN=<binary> reuses an existing build (same as ui-smoke/golden).
import os
import time

@[noreturn]
fn fail(msg string, code int) {
	eprintln('FAIL: ${msg}')
	exit(code)
}

fn sh(cmd string) os.Result {
	return os.execute(cmd)
}

fn shellq(s string) string {
	return "'${s.replace("'", "'\\''")}'"
}

fn has(cmd string) bool {
	return os.execute('command -v ${cmd} >/dev/null 2>&1').exit_code == 0
}

fn alive(pid int) bool {
	if pid <= 0 {
		return false
	}
	return os.execute('kill -0 ${pid} 2>/dev/null').exit_code == 0
}

struct Rec {
mut:
	rows   []string
	failed bool
}

fn (mut r Rec) record(key string, state string, detail string) {
	r.rows << '${key} ${state} ${detail}'
	println(key + ' ' + state + ' ' + detail)
	if state == 'FAIL' {
		r.failed = true
	}
}

fn main() {
	mut rec := Rec{}
	raw := os.args.clone()
	script_idx := raw.index('enter-regression.vsh')
	rest := if script_idx >= 0 { raw[script_idx + 1..] } else { raw[1..] }
	mut bin := ''
	for i in 0 .. rest.len {
		if rest[i] == '--bin' && i + 1 < rest.len {
			bin = rest[i + 1]
		}
	}
	root := os.getwd()
	if bin == '' {
		// SMOKE_BIN matches scripts/ui-smoke.vsh + scripts/golden.vsh so CI
		// builds the desktop binary once and shares it across harnesses.
		bin = os.getenv_opt('SMOKE_BIN') or { '' }
	}
	if bin == '' {
		bin = os.join_path(os.temp_dir(), 'atk-desktop-enter-${os.getpid()}')
		println('building desktop: cmd/agent-toolkit-desktop → ${bin}')
		br := sh('VMODULES=${shellq(os.join_path(root, 'modules'))} v -d gg_text_buff_size=4096 -o ${shellq(bin)} ${shellq(os.join_path(root, 'cmd', 'agent-toolkit-desktop'))} 2>&1')
		if br.exit_code != 0 || !os.is_executable(bin) {
			fail('cannot build desktop under test:\n${br.output}', 1)
		}
	} else if !os.is_executable(bin) {
		fail('not executable: ${bin}', 2)
	}
	rec.record('desktop-build', 'PASS', 'binary under test: ${bin}')

	// gate 2: headless boot prints RUNNING (fast failure gate — no X needed)
	home := os.join_path(os.temp_dir(), 'atk-enter-${os.getpid()}')
	os.mkdir_all(home) or { fail('cannot create home', 1) }
	defer {
		os.rmdir_all(home) or {}
	}
	boot := sh('env -i PATH=/usr/bin:/bin HOME=${shellq(home)} LANG=C.UTF-8 ATK_GUI_HEADLESS=1 ${shellq(bin)} 2>&1 || true').output
	if boot.contains('RUNNING') {
		rec.record('headless-boot', 'PASS', 'ATK_GUI_HEADLESS=1 prints RUNNING')
	} else {
		rec.record('headless-boot', 'FAIL', 'no RUNNING line; output: ${boot.split('\n')[0]}')
		exit(5)
	}

	// gate 3: live Enter keys under Xvfb
	if !has('Xvfb') || !has('xdotool') || !has('import') {
		rec.record('enter-alive', 'NOT_PROVEN', 'Xvfb/xdotool/imagemagick not available in this environment')
	} else {
		disp := os.getenv_opt('ATK_ENTER_DISPLAY') or { ':97' }
		disps := disp.trim_left(':')
		dlock := os.join_path(os.temp_dir(), 'atk-acceptance-X${disps}.lock')
		if os.exists(dlock) {
			owner := os.read_file(os.join_path(dlock, 'pid')) or { 'unknown' }.trim_space()
			if owner != 'unknown' && owner.int() > 0 && alive(owner.int()) {
				fail('display ${disp} is locked by another acceptance run (owner pid ${owner})',
					1)
			}
			eprintln('warning: stealing stale acceptance lock ${dlock} (owner ${owner} dead)')
			os.rmdir_all(dlock) or {}
		}
		os.mkdir(dlock) or { fail('cannot take display lock', 1) }
		os.write_file(os.join_path(dlock, 'pid'), '${os.getpid()}\n') or {}
		defer {
			os.rmdir_all(dlock) or {}
		}
		evidence := os.getenv_opt('EVIDENCE_DIR') or { home }
		os.mkdir_all(evidence) or {}
		xvfb_pid := sh('Xvfb ${shellq(disp)} -screen 0 1280x800x24 >/dev/null 2>&1 & echo $!').output.trim_space().int()
		defer {
			sh('kill -9 ${xvfb_pid} 2>/dev/null || true')
		}
		mut xready := false
		for _ in 0 .. 20 {
			if os.exists('/tmp/.X11-unix/X${disps}') {
				xready = true
				break
			}
			time.sleep(500 * time.millisecond)
		}
		if !xready {
			fail('Xvfb ${disp} did not become ready', 1)
		}
		app_pid := sh('env -i DISPLAY=${shellq(disp)} PATH=/usr/bin:/bin HOME=${shellq(home)} LANG=C.UTF-8 XDG_DATA_HOME=${shellq(home + '/.local/share')} XDG_CONFIG_HOME=${shellq(home + '/.config')} XDG_CACHE_HOME=${shellq(home + '/.cache')} ${shellq(bin)} > ${shellq(home + '/app.log')} 2>&1 & echo $!').output.trim_space().int()
		defer {
			sh('kill -9 ${app_pid} 2>/dev/null || true')
		}
		mut wid := ''
		for _ in 0 .. 30 {
			time.sleep(1 * time.second)
			wid = sh("DISPLAY=${shellq(disp)} xdotool search --onlyvisible --name 'Agent Toolkit' 2>/dev/null | head -1 || true").output.trim_space()
			if wid != '' {
				break
			}
		}
		if wid == '' {
			fail('app window never appeared', 1)
		}
		sh("DISPLAY=${shellq(disp)} xdotool windowactivate --sync ${shellq(wid)} 2>/dev/null || true")
		sh("DISPLAY=${shellq(disp)} xdotool windowfocus ${shellq(wid)} 2>/dev/null || true")
		time.sleep(1 * time.second)
		sh("DISPLAY=${shellq(disp)} import -window ${shellq(wid)} ${shellq(os.join_path(evidence, 'enter-before.png'))} 2>/dev/null || true")
		// the regression: Return must route, never kill/hang/blank
		for _ in 0 .. 5 {
			sh("DISPLAY=${shellq(disp)} xdotool key --window ${shellq(wid)} Return 2>/dev/null || DISPLAY=${shellq(disp)} xdotool key Return")
			time.sleep(700 * time.millisecond)
		}
		sh("DISPLAY=${shellq(disp)} xdotool type --delay 60 'enter-regression-probe' 2>/dev/null || true")
		time.sleep(400 * time.millisecond)
		sh("DISPLAY=${shellq(disp)} xdotool key --window ${shellq(wid)} Return 2>/dev/null || DISPLAY=${shellq(disp)} xdotool key Return")
		time.sleep(2 * time.second)
		sh("DISPLAY=${shellq(disp)} import -window ${shellq(wid)} ${shellq(os.join_path(evidence, 'enter-after.png'))} 2>/dev/null || true")
		if !alive(app_pid) {
			// diagnostics before failing: the log tells whether Enter killed it
			tail := sh('tail -20 ${shellq(home + '/app.log')} 2>/dev/null || true').output
			rec.record('enter-alive', 'FAIL', 'app died after Enter keys; log tail: ${tail.split('\n')[0]}')
		} else {
			still_mapped := sh("DISPLAY=${shellq(disp)} xdotool search --onlyvisible --name 'Agent Toolkit' 2>/dev/null | head -1 || true").output.trim_space()
			if still_mapped == '' {
				rec.record('enter-alive', 'FAIL', 'app alive but window unmapped after Enter keys')
			} else {
				rec.record('enter-alive', 'PASS', '5× Return + text + Return: process alive, window mapped (captures enter-before/after.png)')
			}
		}
	}

	println('')
	println('=== enter-regression summary ===')
	for row in rec.rows {
		println(row)
	}
	if rec.failed {
		exit(5)
	}
	println('OVERALL: PASS')
}
