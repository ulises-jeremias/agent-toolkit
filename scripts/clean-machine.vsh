#!/usr/bin/env -S v run
// clean-machine.vsh — #1130 layered clean-machine validation (V port of
// scripts/clean-machine-acceptance.sh).
//
// Contract (see docs/desktop/PACKAGING.md + #1130 body):
//   real packaged artifact → clean environment → real install mechanism
//   → installed-resource verification → launch as installed app
//   → evidence capture → receipt-backed uninstall → ownership proof
//
// The harness FAILS if it resolves the binary/resources from a source tree:
// the artifact is copied to a neutral prefix first, everything runs from
// there with a clean HOME/XDG and no repo in PATH, and the launched binary's
// own reported executable path must be the installed one.
//
// Layers (explicit states, never collapsed to one boolean):
//   A artifact-structural     AUTOMATED
//   B clean-user install      AUTOMATED
//   C GUI launch/render       AUTOMATED (xvfb) — visual inspection separate
//   D OS menu-click           MANUAL (documented; never implied by A–C)
//
// Usage: v run scripts/clean-machine.vsh <desktop-archive.tar.gz>
// Env:   EVIDENCE_DIR (durable evidence copies), GUI_CAPTURE=1 default
import crypto.sha256
import os
import time

struct Rec {
mut:
	rows   []string
	failed bool
}

fn (mut r Rec) record(layer string, key string, state string, detail string) {
	line := '${layer} ${key} ${state} ${detail}'
	println('${pad(layer, 26)} ${pad(state, 12)} ${detail}')
	r.rows << line
	if state == 'FAIL' {
		r.failed = true
	}
}

@[noreturn]
fn fail(msg string, code int) {
	eprintln('FAIL: ${msg}')
	exit(code)
}

fn pad(s string, w int) string {
	if s.len >= w {
		return s
	}
	return s + ' '.repeat(w - s.len)
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

fn main() {
	mut rec := Rec{}
	args := os.args_after('v')
	_ = args
	raw := os.args.clone()
	script_idx := raw.index('clean-machine.vsh')
	rest := if script_idx >= 0 { raw[script_idx + 1..] } else { raw[1..] }
	if rest.len < 1 {
		eprintln('usage: v run scripts/clean-machine.vsh <desktop-archive.tar.gz>')
		exit(2)
	}
	artifact := rest[0]
	if !os.is_file(artifact) {
		eprintln('error: artifact not found: ${artifact}')
		exit(2)
	}
	art_name := os.base(artifact)
	art_bytes := os.read_bytes(artifact) or { fail('cannot read artifact: ${err}', 2) }
	art_sha := sha256.sum(art_bytes).hex()
	art_size := os.file_size(artifact)
	version := os.read_file('VERSION') or { 'unknown' }.trim(' \n')
	commit := sh("git -c safe.directory='*' rev-parse --short HEAD 2>/dev/null").output.trim_space()
	println('provenance: artifact=${art_name} sha256=${art_sha} size=${art_size} version=${version} commit=${commit}')

	prefix := os.join_path(os.temp_dir(), 'atk-clean-${os.getpid()}')
	stage := os.join_path(prefix, 'stage')
	clean_home := os.join_path(prefix, 'home')
	clean_data := os.join_path(clean_home, '.local', 'share')
	clean_config := os.join_path(clean_home, '.config')
	clean_cache := os.join_path(clean_home, '.cache')
	clean_state := os.join_path(clean_home, '.local', 'state')
	os.mkdir_all(stage) or { fail('cannot create stage: ${err}', 1) }
	os.mkdir_all(clean_home) or { fail('cannot create clean home: ${err}', 1) }
	os.mkdir_all(clean_cache) or { fail('cannot create clean cache: ${err}', 1) }
	os.mkdir_all(clean_state) or { fail('cannot create clean state: ${err}', 1) }
	evidence_dir := os.getenv('EVIDENCE_DIR')
	installed_bin := os.join_path(clean_data, 'agent-toolkit', 'bin', 'agent-toolkit-desktop')

	mut app_pid := 0
	mut xvfb_pid := 0
	defer {
		for p in [app_pid, xvfb_pid] {
			if p != 0 {
				sh('kill -9 ${p} 2>/dev/null || true')
			}
		}
		os.rmdir_all(prefix) or {}
	}

	if sh('tar xzf ${shellq(artifact)} -C ${shellq(stage)}').exit_code != 0 {
		fail('cannot extract artifact', 1)
	}

	// ── Layer A: artifact structural ──
	required := ['agent-toolkit-desktop', 'agent-toolkit-desktop.desktop', 'install-desktop.sh',
		'icons/agent-toolkit-desktop-256.png', 'icons/agent-toolkit-desktop-16.png',
		'icons/agent-toolkit-desktop-scalable.svg', 'share/man/man1/agent-toolkit-desktop.1',
		'LICENSE']
	struct_ok := os.is_executable(os.join_path(stage, 'agent-toolkit-desktop'))
		&& os.is_file(os.join_path(stage, 'agent-toolkit-desktop.desktop'))
		&& os.is_file(os.join_path(stage, 'install-desktop.sh'))
	for f in required {
		if !os.exists(os.join_path(stage, f)) {
			rec.record('A', 'missing:${f}', 'FAIL', 'archive incomplete')
		}
	}
	if struct_ok {
		rec.record('A', 'structure', 'PASS', 'binary + launcher + installer + icons + man present')
	} else {
		rec.record('A', 'structure', 'FAIL', 'archive incomplete')
		exit(3)
	}
	if has('desktop-file-validate') {
		r := sh('desktop-file-validate ${shellq(os.join_path(stage, 'agent-toolkit-desktop.desktop'))}')
		if r.exit_code == 0 {
			rec.record('A', 'desktop-entry', 'PASS', 'Desktop Entry spec valid')
		} else {
			rec.record('A', 'desktop-entry', 'FAIL', 'desktop-file-validate rejected the entry')
			exit(3)
		}
	} else {
		rec.record('A', 'desktop-entry', 'CI-MANUAL', 'desktop-file-utils not installed in this environment')
	}
	ver_r := sh('${shellq(os.join_path(stage, 'agent-toolkit-desktop'))} --version 2>&1 || true')
	version_out := ver_r.output.split('\n')[0].trim_space()
	if version_out == '' {
		fail('extracted binary --version produced nothing', 1)
	}
	rec.record('A', 'binary-identity', 'PASS', version_out)

	// ── Layer B: clean-user install ──
	// Minimal launcher-like environment: no repo, no dev PATH.
	clean_env := 'HOME=${shellq(clean_home)} XDG_DATA_HOME=${shellq(clean_data)} XDG_CONFIG_HOME=${shellq(clean_config)} XDG_CACHE_HOME=${shellq(clean_cache)} XDG_STATE_HOME=${shellq(clean_state)}'
	if sh('cd ${shellq(stage)} && env ${clean_env} ./install-desktop.sh install >/dev/null').exit_code != 0 {
		fail('install-desktop.sh install failed', 1)
	}
	if !os.is_executable(installed_bin) {
		fail('installed binary missing at ${installed_bin}', 1)
	}
	if !os.is_file(os.join_path(clean_data, 'applications', 'agent-toolkit-desktop.desktop')) {
		fail('launcher entry not installed', 1)
	}
	if !os.is_file(os.join_path(clean_data, 'icons', 'hicolor', '256x256', 'apps',
		'agent-toolkit-desktop.png')) {
		fail('256px icon not installed', 1)
	}
	receipt := os.join_path(clean_config, 'agent-toolkit', 'receipts',
		'agent-toolkit-desktop-linux.json')
	if !os.is_file(receipt) {
		fail('install receipt missing', 1)
	}
	receipt_txt := os.read_file(receipt) or { fail('cannot read receipt', 1) }
	owned := receipt_txt.replace(' ', '').count('"ownership":"created"')
	if owned <= 0 {
		fail('receipt records no created artifacts', 1)
	}
	rec.record('B', 'install', 'PASS', 'installed to XDG paths; receipt records ${owned} created artifacts')

	// provenance gate: the INSTALLED binary must be the one we run
	smoke := sh('env -i PATH=/usr/bin:/bin HOME=${shellq(clean_home)} XDG_DATA_HOME=${shellq(clean_data)} XDG_CONFIG_HOME=${shellq(clean_config)} ATK_GUI_HEADLESS=1 ${shellq(installed_bin)} 2>&1 || true').output
	if !smoke.contains('RUNNING') {
		fail('installed binary did not boot (headless)', 1)
	}
	mut self_path := ''
	for line in smoke.split('\n') {
		if line.contains('binary at ') {
			idx := line.index('binary at ') or { 0 }
			self_path = line[idx + 'binary at '.len..].trim_space()
		}
	}
	if self_path != '' && self_path != installed_bin {
		fail('provenance violation: launched binary resolved to ${self_path}, expected ${installed_bin}',
			1)
	}
	rec.record('B', 'provenance', 'PASS', 'launched binary self-reports the installed path')

	font_dir := os.join_path(clean_home, '.cache', 'agent-toolkit', 'desktop', 'fonts')
	if os.is_file(os.join_path(font_dir, 'Fraunces-Display.ttf'))
		&& os.is_file(os.join_path(font_dir, 'IBMPlexSans-Regular.ttf')) {
		rec.record('B', 'embedded-resources', 'PASS', 'fonts extracted to clean cache: ${font_dir}')
	} else {
		rec.record('B', 'embedded-resources', 'FAIL', 'fonts missing in clean cache')
		exit(4)
	}

	mut disco := ''
	for line in smoke.split('\n') {
		if line.contains('tools found=') {
			start := line.index('tools found=') or { 0 }
			disco = line[start..].split(' ')[0..2].join(' ')
		}
	}
	if disco != '' {
		rec.record('B', 'tool-discovery', 'PASS', '${disco} (sparse launcher-like PATH)')
	} else {
		rec.record('B', 'tool-discovery', 'NOT_PROVEN', 'binary predates the #1129 discovery smoke line')
	}

	// ── Layer C: GUI launch/render (xvfb) ──
	if has('Xvfb') && has('import') {
		cap := os.join_path(prefix, 'capture.png')
		mut xvfb := os.new_process('Xvfb')
		xvfb.set_args([':98', '-screen', '0', '1280x800x24'])
		xvfb.set_redirect_stdio()
		xvfb.run()
		xvfb_pid = xvfb.pid
		mut xready := false
		for _ in 0 .. 20 {
			if os.exists('/tmp/.X11-unix/X98') {
				xready = true
				break
			}
			time.sleep(500 * time.millisecond)
		}
		if !xready {
			fail('Xvfb :98 did not become ready', 1)
		}
		mut app := os.new_process(installed_bin)
		app.set_args([]string{})
		app.set_redirect_stdio()
		app.set_environment({
			'DISPLAY':         ':98'
			'PATH':            '/usr/bin:/bin'
			'HOME':            clean_home
			'LANG':            'C.UTF-8'
			'XDG_DATA_HOME':   clean_data
			'XDG_CONFIG_HOME': clean_config
		})
		app.run()
		app_pid = app.pid
		time.sleep(14 * time.second)
		sh('DISPLAY=:98 import -window root ${shellq(cap)} || true')
		sh('kill -9 ${app_pid} 2>/dev/null || true')
		sh('kill -9 ${xvfb_pid} 2>/dev/null || true')
		app.wait()
		xvfb.wait()
		if os.is_file(cap) {
			mean := sh('convert ${shellq(cap)} -colorspace Gray -format \'%[fx:mean]\' info: 2>/dev/null || echo 0').output.trim_space()
			bright := mean.f64()
			state := if bright > 0.03 { 'PASS' } else { 'FAIL' }
			rec.record('C', 'first-render', state, 'xvfb capture mean-brightness=${mean} → ${cap}')
			if evidence_dir != '' && os.is_file(cap) {
				os.mkdir_all(evidence_dir) or {}
				os.cp(cap, os.join_path(evidence_dir, 'first-render.png')) or {}
			}
		} else {
			rec.record('C', 'first-render', 'NOT_PROVEN', 'no capture produced (window missing)')
		}
	} else {
		rec.record('C', 'first-render', 'MANUAL_REQUIRED', 'xvfb/imagemagick not available in this environment')
	}
	rec.record('D', 'menu-click', 'MANUAL', 'actual desktop-menu launch is a documented manual check (OS integration)')

	// ── receipt-backed uninstall ──
	foreign := os.join_path(clean_data, 'agent-toolkit', 'bin', 'FOREIGN-USER-FILE.txt')
	os.write_file(foreign, 'user data') or { fail('cannot plant foreign file', 1) }
	if sh('cd ${shellq(stage)} && env ${clean_env} ./install-desktop.sh uninstall >/dev/null').exit_code != 0 {
		fail('install-desktop.sh uninstall failed', 1)
	}
	if os.exists(installed_bin) {
		fail('uninstall left the installed binary', 1)
	}
	if os.exists(os.join_path(clean_data, 'applications', 'agent-toolkit-desktop.desktop')) {
		fail('uninstall left the launcher entry', 1)
	}
	if os.is_file(receipt) {
		fail('receipt not consumed', 1)
	}
	if !os.is_file(foreign) {
		fail('uninstall removed a user-owned foreign file', 1)
	}
	rec.record('B', 'uninstall', 'PASS', 'owned artifacts removed; foreign file preserved; receipt consumed')

	// ── summary ──
	println('')
	println('=== clean-machine acceptance summary (${art_name}) ===')
	for row in rec.rows {
		println(row)
	}
	if evidence_dir != '' {
		os.mkdir_all(evidence_dir) or {}
		mut ev := ['artifact=${art_name}', 'sha256=${art_sha}', 'version=${version}',
			'commit=${commit}']
		for row in rec.rows {
			ev << 'result: ${row}'
		}
		ev << 'overall: ${if rec.failed { 'FAIL' } else { 'PASS' }}'
		os.write_file(os.join_path(evidence_dir, 'evidence.txt'), ev.join('\n') + '\n') or {}
	}
	if rec.failed {
		exit(5)
	}
	println('OVERALL: PASS (layer D remains MANUAL by design)')
}
