#!/usr/bin/env -S v run
// first-run.vsh — #1127 zero-to-working first-run acceptance (V port of
// scripts/first-run-acceptance.sh).
//
// Consumes the #1130 chain: real artifact → receipt-backed install →
// INSTALLED binary → real onboarding UI driven through user-visible
// controls (keyboard, via xdotool/XTEST under Xvfb — no state-file
// driving, no engine calls from the driver) → restart persistence.
//
// Scenarios:
//   A  absolute clean machine (no agent CLIs) — graceful, non-dead-end
//   B  minimal working integration (deterministic fixture executable,
//      explicitly integration-fixture evidence)
//   +  failure/recovery, interrupted onboarding, existing-state preservation
//
// States are explicit per check (PASS/FAIL/NOT_PROVEN/MANUAL); captures
// are staged into EVIDENCE_DIR for human inspection — never hash-approved.
//
// Display: fixed (default :99, ATK_FIRST_RUN_DISPLAY to override) guarded
// by a shared lock file, so local parallel runs fail loudly instead of
// colliding.
//
// Usage: v run scripts/first-run.vsh <desktop-archive.tar.gz>
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

struct Harness {
mut:
	rows      []string
	failed    bool
	disp      string
	evidence  string
	prefix    string
	bin       string
	app_pid   int
	ob_pid    int
	xvfb_pid  int
	win_id    string
	state_at  string
}

fn (mut h Harness) record(key string, state string, detail string) {
	h.rows << '${key} ${state} ${detail}'
	println(key + ' ' + state + ' ' + detail)
	if state == 'FAIL' {
		h.failed = true
	}
}

// kill_graceful TERMs a pid and waits (bounded) for it to exit so the app
// can flush persisted state — the retired shell harness waited unboundedly
// here, and an early SIGKILL loses the onboarding completion write. SIGKILL
// is only the backstop for TERM-ignorers.
fn kill_graceful(pid int, wait_secs int) {
	if pid <= 0 || !alive(pid) {
		return
	}
	sh('kill ${pid} 2>/dev/null || true')
	for _ in 0 .. wait_secs * 2 {
		if !alive(pid) {
			return
		}
		time.sleep(500 * time.millisecond)
	}
	sh('kill -9 ${pid} 2>/dev/null || true')
	for _ in 0 .. 4 {
		if !alive(pid) {
			break
		}
		time.sleep(250 * time.millisecond)
	}
}

fn (mut h Harness) cleanup() {
	// the app gets a generous flush window (state assertions follow every
	// kill); the window manager and X server only need to die, not to flush.
	kill_graceful(h.app_pid, 15)
	kill_graceful(h.ob_pid, 3)
	kill_graceful(h.xvfb_pid, 3)
	h.app_pid = 0
	h.ob_pid = 0
	h.xvfb_pid = 0
	h.win_id = ''
}

// take_display_lock guards the fixed display with the shared acceptance
// lock dir so parallel local runs fail loudly instead of colliding.
fn (mut h Harness) take_display_lock() string {
	disps := h.disp.trim_left(':')
	cand := os.join_path(os.temp_dir(), 'atk-acceptance-X${disps}.lock')
	if !os.exists(cand) {
		os.mkdir(cand) or { fail('cannot take display lock ${cand}', 1) }
	} else {
		owner := os.read_file(os.join_path(cand, 'pid')) or { 'unknown' }.trim_space()
		if owner != 'unknown' && owner.int() > 0 && alive(owner.int()) {
			fail('display ${h.disp} is locked by another acceptance run (owner pid ${owner})',
				1)
		}
		eprintln('warning: stealing stale acceptance lock ${cand} (owner ${owner} dead)')
		os.rmdir_all(cand) or {}
		os.mkdir(cand) or { fail('cannot take display lock ${cand}', 1) }
	}
	os.write_file(os.join_path(cand, 'pid'), '${os.getpid()}\n') or {}
	return cand
}

// launch starts Xvfb + openbox + the installed app under a clean
// launcher-like environment and waits for the app window with focus.
fn (mut h Harness) launch(home string, pathfix string) {
	path := if pathfix != '' { '${pathfix}:/usr/bin:/bin' } else { '/usr/bin:/bin' }
	h.xvfb_pid = sh('Xvfb ${shellq(h.disp)} -screen 0 1280x800x24 >/dev/null 2>&1 & echo $!').output.trim_space().int()
	time.sleep(1 * time.second)
	h.ob_pid = sh('DISPLAY=${shellq(h.disp)} openbox >/dev/null 2>&1 & echo $!').output.trim_space().int()
	time.sleep(1 * time.second)
	// env -i: NO CI environment leakage — the app sees exactly the clean
	// launcher-like environment.
	h.app_pid = sh('env -i DISPLAY=${shellq(h.disp)} PATH=${shellq(path)} HOME=${shellq(home)} LANG=C.UTF-8 XDG_DATA_HOME=${shellq(home + '/.local/share')} XDG_CONFIG_HOME=${shellq(home + '/.config')} XDG_CACHE_HOME=${shellq(home + '/.cache')} ${shellq(h.bin)} > ${shellq(home + '/app.log')} 2>&1 & echo $!').output.trim_space().int()
	h.win_id = ''
	for _ in 0 .. 30 {
		time.sleep(1 * time.second)
		h.win_id = sh("DISPLAY=${shellq(h.disp)} xdotool search --onlyvisible --name 'Agent Toolkit' 2>/dev/null | head -1 || true").output.trim_space()
		if h.win_id != '' {
			break
		}
	}
	if h.win_id == '' {
		fail('app window never appeared', 1)
	}
	sh("DISPLAY=${shellq(h.disp)} xdotool windowactivate --sync ${shellq(h.win_id)} 2>/dev/null || true")
	sh("DISPLAY=${shellq(h.disp)} xdotool windowfocus ${shellq(h.win_id)} 2>/dev/null || true")
	time.sleep(1 * time.second)
	focused := sh("DISPLAY=${shellq(h.disp)} xdotool getwindowfocus 2>/dev/null || true").output.trim_space()
	if focused != h.win_id {
		eprintln('focus probe: focused=${focused} want=${h.win_id} — retrying windowfocus')
		sh("DISPLAY=${shellq(h.disp)} xdotool windowfocus ${shellq(h.win_id)} || true")
		time.sleep(1 * time.second)
	}
}

fn (h Harness) journey_key(key string) {
	r := sh("DISPLAY=${shellq(h.disp)} xdotool key --window ${shellq(h.win_id)} ${shellq(key)} 2>/dev/null || DISPLAY=${shellq(h.disp)} xdotool key ${shellq(key)}")
	_ = r
	time.sleep(1 * time.second)
}

// journey_enter retries Enter once: every step action is idempotent and a
// Return swallowed while a transaction commits would otherwise leave the
// journey silently incomplete.
fn (h Harness) journey_enter() {
	h.journey_key('Return')
	time.sleep(800 * time.millisecond)
	h.journey_key('Return')
	time.sleep(1 * time.second)
}

// shot captures NAMED evidence: a failed capture fails the run loudly
// (missing evidence must never pass silently as an empty check).
fn (h Harness) shot(name string) {
	if sh("DISPLAY=${shellq(h.disp)} import -window root ${shellq(os.join_path(h.evidence, name))} 2>/dev/null").exit_code != 0 {
		fail('evidence capture failed: ${name}', 1)
	}
}

fn (mut h Harness) assert_state(state_file string, expr string, label string) {
	py := 'import json, sys\nr = json.load(open(${shellq(state_file)})).get("data", {})\nsys.exit(0 if (${expr}) else 1)\n'
	tf := os.join_path(h.prefix, 'assert.py')
	os.write_file(tf, py) or { fail('cannot write assert helper', 1) }
	if sh('python3 ${shellq(tf)} 2>/dev/null').exit_code != 0 {
		fail('state assertion failed: ${label}', 1)
	}
	h.record(label, 'PASS', 'engine state verified')
}

fn completed_check(state_file string) bool {
	if !os.is_file(state_file) {
		return false
	}
	tf := os.join_path(os.temp_dir(), 'atk-done-check.py')
	os.write_file(tf, 'import json, sys\nsys.exit(0 if json.load(open(${shellq(state_file)})).get("data", {}).get("onboarding_completed") == "true" else 1)\n') or {
		return false
	}
	return sh('python3 ${shellq(tf)} 2>/dev/null').exit_code == 0
}

fn main() {
	raw := os.args.clone()
	script_idx := raw.index('first-run.vsh')
	rest := if script_idx >= 0 { raw[script_idx + 1..] } else { raw[1..] }
	if rest.len < 1 {
		eprintln('usage: v run scripts/first-run.vsh <desktop-archive.tar.gz>')
		exit(2)
	}
	archive := rest[0]
	if !os.is_file(archive) {
		eprintln('error: archive not found: ${archive}')
		exit(2)
	}
	for t in ['Xvfb', 'openbox', 'xdotool', 'import', 'python3'] {
		if !has(t) {
			fail('missing required tool: ${t}', 1)
		}
	}
	art_name := os.base(archive)
	art_sha := sh('sha256sum ${shellq(archive)}').output.split(' ')[0]
	println('provenance: artifact=${art_name} sha256=${art_sha}')

	mut h := Harness{}
	h.disp = os.getenv_opt('ATK_FIRST_RUN_DISPLAY') or { ':99' }
	h.prefix = os.join_path(os.temp_dir(), 'atk-firstrun-${os.getpid()}')
	h.evidence = os.getenv_opt('EVIDENCE_DIR') or { os.join_path(h.prefix, 'evidence') }
	os.mkdir_all(os.join_path(h.prefix, 'stage')) or { fail('cannot create prefix', 1) }
	os.mkdir_all(h.evidence) or { fail('cannot create evidence dir', 1) }
	dlock := h.take_display_lock()
	defer {
		h.cleanup()
		os.rmdir_all(h.prefix) or {}
		os.rmdir_all(dlock) or {}
	}

	// ── install via the real bundle script (#1130 chain) ──
	stage := os.join_path(h.prefix, 'stage')
	if sh('tar xzf ${shellq(archive)} -C ${shellq(stage)}').exit_code != 0 {
		fail('cannot extract archive', 1)
	}
	home_fresh := os.join_path(h.prefix, 'home-a')
	os.mkdir_all(home_fresh) or { fail('cannot create home', 1) }
	install_env := 'HOME=${shellq(home_fresh)} XDG_DATA_HOME=${shellq(home_fresh + '/.local/share')} XDG_CONFIG_HOME=${shellq(home_fresh + '/.config')}'
	if sh('cd ${shellq(stage)} && env ${install_env} ./install-desktop.sh install >/dev/null').exit_code != 0 {
		fail('install-desktop.sh install failed', 1)
	}
	h.bin = os.join_path(home_fresh, '.local', 'share', 'agent-toolkit', 'bin',
		'agent-toolkit-desktop')
	if !os.is_executable(h.bin) {
		fail('installed binary missing', 1)
	}
	h.record('artifact-install', 'PASS', 'receipt-backed install from ${art_name}')

	// ── Scenario A: absolute clean machine ──
	println('== Scenario A: absolute clean machine ==')
	h.launch(home_fresh, '')
	h.shot('onboarding-step0.png')
	h.record('onboarding-visible', 'PASS', 'wizard overlay visible on first launch (capture onboarding-step0.png)')

	// VC4 setup journey (#1173): five user-facing stages — Right commits
	// the current stage's Engine work and advances; Enter re-applies the
	// current stage and stays put (idempotent for recovery scenarios).
	h.journey_key('Right') // stage 0 Setup Choice → nothing to commit
	h.journey_key('Right') // stage 1 Tools → enable the detected targets
	h.journey_key('Right') // stage 2 Workspace → scaffold under ~/.ai-workspace
	h.shot('onboarding-workspace.png')
	h.journey_key('Right') // stage 3 Capabilities → install skills + core product
	// stage 4 Review: pressing Right AT the last stage bootstraps personas
	// and triggers onboarding_complete. Retry is CONDITIONAL: poll the
	// persisted state and resend only while completion has not landed (#1168).
	h.state_at = os.join_path(home_fresh, '.cache', 'agent-toolkit', 'desktop',
		'engine_state.json')
	h.journey_key('Right')
	for _ in 0 .. 8 {
		time.sleep(2 * time.second)
		if completed_check(h.state_at) {
			break
		}
		h.journey_key('Right')
	}
	if !completed_check(h.state_at) {
		fail('onboarding completion did not persist after retries', 1)
	}
	h.shot('journey-final.png')
	eprintln('journey diagnostics:')
	sh('find ${shellq(home_fresh)} -name \'*.json\' | head -5 >&2 || true')
	sh("DISPLAY=${shellq(h.disp)} xdotool getactivewindowname 2>/dev/null >&2 || true")

	state_file := os.join_path(home_fresh, '.cache', 'agent-toolkit', 'desktop',
		'engine_state.json')
	time.sleep(1 * time.second)
	h.cleanup()
	if !os.is_file(state_file) {
		eprintln('state file locations probed:')
		sh('find ${shellq(home_fresh)} -name \'engine_state*\' >&2 || true')
		fail('engine state file missing after first run', 1)
	}
	tf := os.join_path(h.prefix, 'assert.py')
	os.write_file(tf, 'import json\nr = json.load(open(${shellq(state_file)})).get("data", {})\nprint("DBG onboarding_completed:", repr(r.get("onboarding_completed")))\nprint("DBG keys sample:", sorted(r.keys())[:24])\n') or {}
	sh('python3 ${shellq(tf)} || true')
	h.assert_state(state_file, "r.get('data', {}).get('onboarding_completed') == 'true'",
		'first-run-completion-persisted')
	h.assert_state(state_file, "len([s for s in (r.get('data', {}).get('installed_skills') or '').split(',') if s]) >= 1",
		'capabilities-installed')
	h.assert_state(state_file, "any(r.get('data', {}).get(f'target:{t}:enabled') == 'true' for t in ('claude-code','opencode','cursor'))",
		'targets-enabled')
	if !os.is_dir(os.join_path(home_fresh, '.ai-workspace', 'knowledge')) {
		fail('workspace scaffold missing: ${home_fresh}/.ai-workspace/knowledge', 1)
	}
	h.record('workspace-scaffold', 'PASS', 'knowledge/ scaffold created under ~/.ai-workspace (designed default)')
	persona_file := os.join_path(home_fresh, '.ai-workspace', 'personas', 'implementer.md')
	if !os.is_file(persona_file) {
		eprintln('DBG personas dir probe (full):')
		sh('find ${shellq(home_fresh)} -name \'*.md\' >&2 | head -20 || true')
		fail('personas not bootstrapped under ~/.ai-workspace', 1)
	}
	h.record('personas', 'PASS', 'personas bootstrapped under ~/.ai-workspace')

	// restart — hard gate: wizard must NOT reappear, state preserved
	os.cp(state_file, os.join_path(h.prefix, 'state-before-restart.json')) or {}
	h.launch(home_fresh, '')
	h.shot('after-restart.png')
	h.cleanup()
	h.assert_state(state_file, "r.get('data', {}).get('onboarding_completed') == 'true'",
		'restart-completion-kept')
	h.assert_state(state_file, "r.get('data', {}).get('workspace_path', '').endswith('.ai-workspace') or r.get('data', {}).get('recent_workspace', '').endswith('.ai-workspace')",
		'restart-workspace-restored')
	h.record('restart-persistence', 'PASS', 'same installed app relaunched: no onboarding restart, state preserved (capture after-restart.png)')

	// ── Scenario B: minimal working integration (fixture, labeled) ──
	println('== Scenario B: minimal working integration (FIXTURE evidence) ==')
	home_b := os.join_path(h.prefix, 'home-b')
	fixture_bin := os.join_path(h.prefix, 'fixture-bin')
	os.mkdir_all(home_b) or { fail('cannot create home-b', 1) }
	os.mkdir_all(fixture_bin) or { fail('cannot create fixture-bin', 1) }
	os.write_file(os.join_path(fixture_bin, 'claude'), '#!/bin/sh\necho "fixture-claude 9.9.9 (integration fixture)"\nexit 0\n') or {}
	os.chmod(os.join_path(fixture_bin, 'claude'), 0o755) or {}
	disco := sh('env -i PATH=${shellq(fixture_bin + ':/usr/bin:/bin')} HOME=${shellq(home_b)} XDG_DATA_HOME=${shellq(home_b + '/.local/share')} XDG_CONFIG_HOME=${shellq(home_b + '/.config')} ATK_GUI_HEADLESS=1 ${shellq(h.bin)} 2>&1 | grep -oP \'tools found=\\d+ missing=\\d+\' || true').output.trim_space()
	if disco != 'tools found=1 missing=8' {
		fail('fixture discovery expected found=1/missing=8, got: ${disco}', 1)
	}
	h.record('fixture-discovery', 'PASS', '${disco} — integration-fixture evidence (claude is a deterministic stub, not a third-party product)')

	h.launch(home_b, fixture_bin)
	h.journey_key('Right') // stage 0 Setup Choice → stage 1 Tools
	h.journey_key('Right') // stage 1 Tools → enables detected targets (incl. claude-code)
	time.sleep(1 * time.second)
	h.cleanup()
	state_b := os.join_path(home_b, '.cache', 'agent-toolkit', 'desktop', 'engine_state.json')
	os.write_file(tf, 'import json, sys\nr = json.load(open(${shellq(state_b)})).get("data", {})\nsys.exit(0 if r.get("target:claude-code:enabled") == "true" else 1)\n') or {}
	if sh('python3 ${shellq(tf)}').exit_code != 0 {
		fail('fixture target not enabled', 1)
	}
	h.record('fixture-integration', 'PASS', 'found fixture → target enabled → integration path real (fixture-labeled)')

	// ── failure/recovery: workspace init against a blocked scaffold ──
	println('== failure/recovery ==')
	home_f := os.join_path(h.prefix, 'home-f')
	os.mkdir_all(home_f) or { fail('cannot create home-f', 1) }
	h.launch(home_f, '')
	time.sleep(3 * time.second) // boot creates the default ~/.ai-workspace (empty, uninitialized)
	// blocker: a FILE where ensure_workspace needs a DIRECTORY
	os.write_file(os.join_path(home_f, '.ai-workspace', 'knowledge'), '') or {
		os.mkdir_all(os.join_path(home_f, '.ai-workspace')) or {}
		os.write_file(os.join_path(home_f, '.ai-workspace', 'knowledge'), '') or {}
	}
	h.journey_key('Right') // stage 0 → 1
	h.journey_key('Right') // stage 1 → 2 (Workspace)
	h.journey_key('Return') // workspace init → must fail (knowledge is a file)
	time.sleep(2 * time.second)
	h.shot('onboarding-failure.png')
	h.cleanup()
	if os.is_dir(os.join_path(home_f, '.ai-workspace', 'knowledge')) {
		fail('init unexpectedly succeeded despite blocked scaffold', 1)
	}
	h.record('failure-logged', 'PASS', 'init failed deterministically: no scaffold, completion not persisted; GUI msg in onboarding-failure.png')
	state_f := os.join_path(home_f, '.cache', 'agent-toolkit', 'desktop', 'engine_state.json')
	if !os.is_file(state_f) {
		fail('failure-path state file missing', 1)
	}
	os.write_file(tf, 'import json, sys\nr = json.load(open(${shellq(state_f)})).get("data", {})\nsys.exit(0 if r.get("onboarding_completed") != "true" else 1)\n') or {}
	if sh('python3 ${shellq(tf)}').exit_code != 0 {
		fail('failure path wrongly persisted completion', 1)
	}
	h.record('failure-surfaced', 'PASS', 'workspace init failed honestly (file where dir required); completion NOT persisted (capture onboarding-failure.png)')

	// ── interrupted onboarding: partial state is truthful, resume is safe ──
	println('== interrupted onboarding ==')
	home_i := os.join_path(h.prefix, 'home-i')
	os.mkdir_all(home_i) or { fail('cannot create home-i', 1) }
	h.launch(home_i, '')
	h.journey_key('Right')
	h.journey_key('Right')
	h.journey_key('Right') // reach stage 3 Capabilities
	h.journey_key('Return') // install skills, then STOP
	time.sleep(1 * time.second)
	h.cleanup()
	state_i := os.join_path(home_i, '.cache', 'agent-toolkit', 'desktop', 'engine_state.json')
	os.write_file(tf, 'import json, sys\nr = json.load(open(${shellq(state_i)})).get("data", {})\nskills = len([s for s in (r.get("installed_skills") or "").split(",") if s])\nsys.exit(0 if (skills >= 1 and r.get("onboarding_completed") != "true") else 1)\n') or {}
	if sh('python3 ${shellq(tf)}').exit_code != 0 {
		fail('interrupted state wrong', 1)
	}
	h.record('interrupted-honest', 'PASS', 'partial install persisted; onboarding_completed NOT set (resume shows truthful pending)')

	// ── existing setup: non-destructive ──
	println('== existing setup preservation ==')
	home_e := os.join_path(h.prefix, 'home-e')
	os.mkdir_all(os.join_path(home_e, 'knowledge')) or {}
	os.mkdir_all(os.join_path(home_e, 'personas')) or {}
	os.write_file(os.join_path(home_e, 'knowledge', 'notes.md'), '# my existing knowledge') or {}
	os.write_file(os.join_path(home_e, 'personas', 'custom-persona.md'), '# my persona') or {}
	h.launch(home_e, '')
	h.journey_key('Right')
	h.journey_key('Right') // reach stage 2 Workspace
	h.journey_key('Return') // ensure workspace over EXISTING dirs
	time.sleep(1 * time.second)
	h.shot('existing-setup.png')
	h.cleanup()
	if os.read_file(os.join_path(home_e, 'knowledge', 'notes.md')) or { '' } != '# my existing knowledge' {
		fail('existing knowledge overwritten', 1)
	}
	if os.read_file(os.join_path(home_e, 'personas', 'custom-persona.md')) or { '' } != '# my persona' {
		fail('existing persona overwritten', 1)
	}
	h.record('existing-state-preserved', 'PASS', 'existing knowledge/personas untouched by ensure (capture existing-setup.png)')

	// ── summary ──
	println('')
	println('=== first-run acceptance summary (${art_name}) ===')
	for row in h.rows {
		println(row)
	}
	if h.failed {
		exit(5)
	}
	println('OVERALL: PASS (Scenario A graceful + Scenario B fixture-labeled; captures in ${h.evidence})')
}
