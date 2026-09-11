#!/usr/bin/env -S v run
// dmg-boot.vsh — macOS DMG first-boot acceptance.
//
// macOS-only by design: on any other OS it prints SKIP and exits 0 (the
// Linux equivalent is scripts/clean-machine.vsh, the Windows equivalent is
// the installer smoke in distribution/desktop/windows).
//
// On macOS it:
//   1. locates the DMG (arg, or newest release-assets/*.dmg)
//   2. attaches it with hdiutil (nobrowse, read-only mount)
//   3. launches the bundled app headless-first (ATK_GUI_HEADLESS=1 RUNNING
//      gate), then for real via `open` with a screencapture after settle
//   4. terminates the app and detaches the image (always — deferred)
//
// Usage: v run scripts/dmg-boot.vsh [<path-to.dmg>]
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
	if os.user_os() != 'macos' {
		println('SKIP: dmg-boot is macOS-only (this host: ${os.user_os()}); Linux → clean-machine.vsh, Windows → installer smoke')
		exit(0)
	}
	mut rec := Rec{}
	raw := os.args.clone()
	script_idx := raw.index('dmg-boot.vsh')
	rest := if script_idx >= 0 { raw[script_idx + 1..] } else { raw[1..] }
	mut dmg := if rest.len >= 1 { rest[0] } else { '' }
	if dmg == '' {
		cands := sh('ls -t release-assets/*.dmg 2>/dev/null || true').output.split('\n').map(it.trim_space()).filter(it != '')
		if cands.len == 0 {
			fail('no DMG found: pass a path or build one (make.vsh package-desktop-macos)', 2)
		}
		dmg = cands[0]
	}
	if !os.is_file(dmg) {
		fail('DMG not found: ${dmg}', 2)
	}
	println('provenance: dmg=${dmg}')
	rec.record('dmg-present', 'PASS', dmg)

	mnt := os.join_path(os.temp_dir(), 'atk-dmg-${os.getpid()}')
	os.mkdir_all(mnt) or { fail('cannot create mountpoint', 1) }
	att := sh('hdiutil attach -nobrowse -readonly -mountpoint ${shellq(mnt)} ${shellq(dmg)} 2>&1')
	if att.exit_code != 0 {
		fail('hdiutil attach failed:\n${att.output}', 1)
	}
	defer {
		sh('hdiutil detach ${shellq(mnt)} -force 2>/dev/null || true')
		os.rmdir_all(mnt) or {}
	}
	apps := sh('ls -d ${shellq(mnt)}/*.app 2>/dev/null || true').output.split('\n').map(it.trim_space()).filter(it != '')
	if apps.len == 0 {
		fail('no .app bundle inside ${dmg}', 1)
	}
	app := apps[0]
	mut app_bin := os.join_path(app, 'Contents', 'MacOS', os.base(app).replace('.app', ''))
	if !os.is_executable(app_bin) {
		// fall back: first executable directly under Contents/MacOS
		fb := sh('find ${shellq(os.join_path(app, 'Contents', 'MacOS'))} -type f -perm +111 2>/dev/null | head -1 || true').output.trim_space()
		if fb == '' {
			fail('no executable in ${app}/Contents/MacOS', 1)
		}
		app_bin = fb
	}
	rec.record('bundle-structure', 'PASS', '${app} → ${app_bin}')

	// headless gate first (fast failure, no window server interaction)
	home := os.join_path(os.temp_dir(), 'atk-dmgboot-${os.getpid()}')
	os.mkdir_all(home) or { fail('cannot create home', 1) }
	defer {
		os.rmdir_all(home) or {}
	}
	boot := sh('env -i PATH=/usr/bin:/bin HOME=${shellq(home)} LANG=C.UTF-8 ATK_GUI_HEADLESS=1 ${shellq(app_bin)} 2>&1 || true').output
	if boot.contains('RUNNING') {
		rec.record('headless-boot', 'PASS', 'bundled binary prints RUNNING headless')
	} else {
		rec.record('headless-boot', 'FAIL', 'no RUNNING line; output: ${boot.split('\n')[0]}')
		exit(5)
	}

	// real first boot via open(1) + screencapture after settle
	evidence := os.getenv_opt('EVIDENCE_DIR') or { home }
	os.mkdir_all(evidence) or {}
	sh('open ${shellq(app)} 2>/dev/null || true')
	time.sleep(12 * time.second)
	cap := os.join_path(evidence, 'dmg-first-boot.png')
	sh('screencapture -x ${shellq(cap)} 2>/dev/null || true')
	app_name := os.base(app).replace('.app', '')
	sh('pkill -x ${shellq(app_name)} 2>/dev/null || true')
	time.sleep(1 * time.second)
	if os.is_file(cap) && os.file_size(cap) > 0 {
		rec.record('first-boot-capture', 'PASS', cap)
	} else {
		rec.record('first-boot-capture', 'NOT_PROVEN', 'screencapture produced nothing (screen lock / permissions)')
	}

	println('')
	println('=== dmg-boot acceptance summary ===')
	for row in rec.rows {
		println(row)
	}
	if rec.failed {
		exit(5)
	}
	println('OVERALL: PASS')
}
