#!/usr/bin/env -S v run
// browser-install.vsh — GUI install-path acceptance for `agent-toolkit gui`.
//
// The desktop GUI ships as a separate binary (agent-toolkit-desktop)
// distributed via GitHub Release; the CLI only resolves, downloads and
// launches it (see docs/ARCHITECTURE.md). This harness drives that exact
// user-visible path against a freshly built CLI in an isolated HOME:
//
//   1. gui --install --dry-run  → preview names the versioned release URL
//      and the install prefix (default ~/.local, $PREFIX, --prefix)
//   2. gui --run (empty HOME)   → truthful "binary not found" + URL, no crash
//   3. gui --run with AGENT_TOOLKIT_DESKTOP_BIN=<real binary> → "would exec"
//   4. gui --headless --dry-run → headless line, no window attempt
//   5. (best-effort) the release tag URL answers over the network —
//      NOT_PROVEN offline, never a FAIL without a response.
//
// Usage: v run scripts/browser-install.vsh [--bin <agent-toolkit-binary>]
import os

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

fn need_contains(mut r Rec, key string, hay string, needle string, detail string) {
	if hay.contains(needle) {
		r.record(key, 'PASS', detail)
	} else {
		r.record(key, 'FAIL', 'missing ${needle} in: ${hay.split('\n')[0]}')
	}
}

fn main() {
	mut rec := Rec{}
	raw := os.args.clone()
	script_idx := raw.index('browser-install.vsh')
	mut rest := if script_idx >= 0 { raw[script_idx + 1..] } else { raw[1..] }
	mut bin := ''
	for i in 0 .. rest.len {
		if rest[i] == '--bin' && i + 1 < rest.len {
			bin = rest[i + 1]
		}
	}
	_ = rest
	root := os.getwd()
	if bin == '' {
		bin = os.join_path(os.temp_dir(), 'atk-cli-${os.getpid()}')
		println('building CLI: cmd/agent-toolkit → ${bin}')
		br := sh('VMODULES=${shellq(os.join_path(root, 'modules'))} v -o ${shellq(bin)} ${shellq(os.join_path(root, 'cmd', 'agent-toolkit'))} 2>&1')
		if br.exit_code != 0 || !os.is_executable(bin) {
			fail('cannot build CLI under test:\n${br.output}', 1)
		}
	} else if !os.is_executable(bin) {
		fail('not executable: ${bin}', 2)
	}

	// isolated HOME: no installed desktop, no user config leaks
	home := os.join_path(os.temp_dir(), 'atk-gui-install-${os.getpid()}')
	os.mkdir_all(home) or { fail('cannot create isolated home', 1) }
	defer {
		os.rmdir_all(home) or {}
	}
	// env -i: no CI/shell leakage (notably XDG_DATA_HOME, which the app
	// correctly honors per #1165) — the CLI sees exactly the isolated HOME.
	env := '-i HOME=${shellq(home)} PATH=/usr/bin:/bin LANG=C.UTF-8'
	run := fn [env, bin](args string) string {
		return sh('env ${env} ${shellq(bin)} ${args} 2>&1').output
	}

	ver := sh('env ${env} ${shellq(bin)} version 2>&1 | grep -oP \'\\d+\\.\\d+\\.\\d+\' | head -1 || true').output.trim_space()

	// 1. install dry-run: versioned release URL + default prefix
	out1 := run('gui --install --dry-run')
	need_contains(mut rec, 'install-dry-run-url', out1, 'github.com/ulises-jeremias/agent-toolkit/releases/tag/v',
		'install preview names the versioned release (${ver})')
	need_contains(mut rec, 'install-dry-run-prefix', out1, '.local',
		'install preview names the default prefix (~/.local)')

	// 1b. --prefix override is honored in the preview
	custom := os.join_path(home, 'custom-prefix')
	out1b := run('gui --install --dry-run --prefix ${shellq(custom)}')
	need_contains(mut rec, 'install-prefix-override', out1b, custom,
		'--prefix override surfaces in the preview')

	// 2. run with an empty HOME: truthful missing-binary guidance, no crash
	out2 := run('gui --run')
	need_contains(mut rec, 'run-missing-guidance', out2, 'binary not found',
		'empty HOME → truthful missing-binary guidance (not a crash)')
	need_contains(mut rec, 'run-missing-url', out2, 'releases/tag/v',
		'missing-binary guidance points at the release download')

	// 3. run with a real desktop binary behind AGENT_TOOLKIT_DESKTOP_BIN
	desk := os.join_path(root, 'build', 'agent-toolkit-desktop')
	desk_bin := if os.is_executable(desk) { desk } else { '/tmp/atk-desktop-check' }
	if os.is_executable(desk_bin) {
		out3 := sh('env ${env} AGENT_TOOLKIT_DESKTOP_BIN=${shellq(desk_bin)} HOME=${shellq(home)} ${shellq(bin)} gui --run 2>&1').output
		need_contains(mut rec, 'run-resolves-binary', out3, 'would exec ${desk_bin}',
			'installed binary resolves through AGENT_TOOLKIT_DESKTOP_BIN')
	} else {
		rec.record('run-resolves-binary', 'NOT_PROVEN', 'no desktop binary available (build/agent-toolkit-desktop missing)')
	}

	// 4. headless dry-run never attempts a window
	out4 := run('gui --headless --dry-run')
	need_contains(mut rec, 'headless-dry-run', out4, 'no window',
		'headless preview states no window is opened (CI friendly)')

	// 5. best-effort: the release tag URL answers (NOT_PROVEN offline)
	if ver != '' {
		code := sh('curl -sI -o /dev/null -w "%{http_code}" --max-time 15 https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v${shellq(ver)} 2>/dev/null || echo 000').output.trim_space()
		if code == '200' {
			rec.record('release-url-live', 'PASS', 'tag v${ver} answers HTTP 200')
		} else if code == '000' {
			rec.record('release-url-live', 'NOT_PROVEN', 'no network in this environment')
		} else {
			rec.record('release-url-live', 'NOT_PROVEN', 'tag v${ver} answers HTTP ${code} (unreleased version or redirect)')
		}
	}

	println('')
	println('=== browser-install acceptance summary ===')
	for row in rec.rows {
		println(row)
	}
	if rec.failed {
		exit(5)
	}
	println('OVERALL: PASS')
}
