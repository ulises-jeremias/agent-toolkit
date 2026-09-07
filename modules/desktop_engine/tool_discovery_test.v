module desktop_engine

import os
import time

// #1129 tool-discovery tests. Environment fixtures are isolated: a temp bin
// directory replaces PATH, a temp HOME isolates config sentinels; both are
// restored after each test. Tests never depend on tools installed on the
// developer machine.

struct TdFixture {
mut:
	tmp      string
	old_path string
	old_home string
}

fn td_fixture(with_tool string, with_config_for string) &TdFixture {
	tmp := os.join_path(os.temp_dir(), 'atk-td-${with_tool}-${os.getpid()}-${time.now().unix_nano()}')
	bins := os.join_path(tmp, 'bin')
	os.mkdir_all(bins) or { panic(err.msg()) }
	if with_tool != '' {
		script := '#!/bin/sh\necho "FakeTool 1.2.3 (${with_tool})"\n'
		p := os.join_path(bins, with_tool)
		os.write_file(p, script) or { panic(err.msg()) }
		os.chmod(p, 0o755) or { panic(err.msg()) }
	}
	if with_config_for != '' {
		os.mkdir_all(os.join_path(tmp, 'home', '.claude')) or { panic(err.msg()) }
	}
	f := &TdFixture{
		tmp: tmp
		old_path: os.getenv('PATH')
		old_home: os.getenv('HOME')
	}
	os.setenv('PATH', bins, true)
	os.setenv('HOME', os.join_path(tmp, 'home'), true)
	return f
}

fn (mut f TdFixture) cleanup() {
	os.setenv('PATH', f.old_path, true)
	os.setenv('HOME', f.old_home, true)
	os.rmdir_all(f.tmp) or {}
	f.tmp = ''
}

fn td_engine() &Engine {
	tmp := os.join_path(os.temp_dir(), 'atk-td-eng-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return eng
}

// A tool present in the session PATH is found with its canonical resolved
// path and a real probed version; the reason is empty.
fn test_discovery_found_with_version() {
	mut f := td_fixture('claude', '')
	defer {
		f.cleanup()
	}
	mut eng := td_engine()
	defer {
		eng.stop() or {}
	}
	d := eng.tool_discovery('claude-code')
	assert d.found
	assert d.resolved_path != ''
	assert d.resolved_path.contains('bin/claude')
	assert d.version_known
	assert d.version.contains('FakeTool 1.2.3')
	assert d.reason == ''
	assert d.doctor_check == 'profile:claude-code'
	assert d.tool_name == 'claude'
}

// A tool absent from the session PATH is missing with a truthful reason and
// no invented version.
fn test_discovery_missing_honest() {
	mut f := td_fixture('', '')
	defer {
		f.cleanup()
	}
	mut eng := td_engine()
	defer {
		eng.stop() or {}
	}
	d := eng.tool_discovery('opencode')
	assert !d.found
	assert d.resolved_path == ''
	assert !d.version_known
	assert d.version == ''
	assert d.reason.contains("not found on this session's PATH")
	// configuration absent → the reason says so honestly
	assert d.reason.starts_with('opencode not found')
}

// Configuration evidence is distinct from PATH truth: settings found but
// binary missing says exactly that.
fn test_discovery_configured_but_binary_missing() {
	mut f := td_fixture('', 'claude')
	defer {
		f.cleanup()
	}
	mut eng := td_engine()
	defer {
		eng.stop() or {}
	}
	d := eng.tool_discovery('claude-code')
	assert !d.found
	assert d.config_paths.len == 1
	assert d.config_paths[0].ends_with('.claude')
	assert d.reason.contains('configured (settings found)')
	assert d.reason.contains('not found on this session')
}

// A version probe that fails (non-zero output constraints / junk) leaves the
// binary found and the version unknown — never a fake version.
fn test_discovery_version_probe_failure_is_unknown() {
	mut f := td_fixture('codex', '')
	defer {
		f.cleanup()
	}
	// replace the fake with a script that prints junk + long line → unknown
	bin := os.join_path(f.tmp, 'bin', 'codex')
	os.write_file(bin, '#!/bin/sh\necho ""\n') or { panic(err.msg()) }
	os.chmod(bin, 0o755) or { panic(err.msg()) }
	mut eng := td_engine()
	defer {
		eng.stop() or {}
	}
	d := eng.tool_discovery('codex')
	assert d.found
	assert !d.version_known
	assert d.version == ''
}

// GUI launchers are never executed: cursor found stays version-unknown.
fn test_discovery_gui_launcher_not_probed() {
	mut f := td_fixture('cursor', '')
	defer {
		f.cleanup()
	}
	mut eng := td_engine()
	defer {
		eng.stop() or {}
	}
	d := eng.tool_discovery('cursor')
	assert d.found
	assert !d.version_known
	assert d.version == ''
}

// The catalog drives the roster: every canonical supported target has a
// discovery result, even when nothing is found (no entity disappears).
fn test_discovery_catalog_covers_registry_roster() {
	mut f := td_fixture('', '')
	defer {
		f.cleanup()
	}
	mut eng := td_engine()
	defer {
		eng.stop() or {}
	}
	registry := eng.targets_registry()
	disco := eng.tool_discovery_catalog()
	assert disco.len == registry.len
	ids := disco.map(it.id)
	for r in registry {
		assert r.id in ids
	}
	// a supported-but-missing tool remains present with honest reason
	for d in disco {
		if !d.found && d.reason == '' {
			// copilot-repository/agent-plugins have no user-level runtime —
			// they still say so truthfully rather than silently
			assert d.id == 'copilot-repository' || d.id == 'agent-plugins'
		}
	}
}

// target_detected preserves its combined semantics: configured sentinel OR
// executable on PATH counts as detected (status truth unchanged).
fn test_target_detected_semantics_preserved() {
	mut f := td_fixture('claude', '')
	defer {
		f.cleanup()
	}
	assert target_detected('claude-code')
	// configured but no binary
	mut f2 := td_fixture('', 'claude')
	defer {
		f2.cleanup()
	}
	assert target_detected('claude-code')
	// neither
	mut f3 := td_fixture('', '')
	defer {
		f3.cleanup()
	}
	assert !target_detected('claude-code')
}

// PATH evidence helper reflects the session environment truthfully.
fn test_session_path_entry_count() {
	mut f := td_fixture('', '')
	defer {
		f.cleanup()
	}
	assert session_path_entry_count() == 1
}
