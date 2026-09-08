module desktop_engine

import os
import time

// #1128 workspace lifecycle tests — seed safety, idempotence, collisions.

struct WlFixture {
mut:
	tmp string
	eng &Engine = unsafe { nil }
}

fn wl_fixture(label string) &WlFixture {
	tmp := os.join_path(os.temp_dir(), 'atk-wl-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	return &WlFixture{
		eng: eng
		tmp: tmp
	}
}

fn (mut f WlFixture) cleanup() {
	f.eng.stop() or {}
	os.rmdir_all(f.tmp) or {}
	f.tmp = ''
}

// SEED empty destination: bundled scaffold created, offline, no related repos
fn test_seed_empty_destination() {
	mut f := wl_fixture('seed-empty')
	defer {
		f.cleanup()
	}
	ws := os.join_path(f.tmp, 'ws')
	rev := f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	assert rev > 0
	for d in ['knowledge', 'knowledge/learnings', 'knowledge/todos', 'packs', 'personas', 'repos', 'projects', '.agent-toolkit/swarm/runs'] {
		assert os.is_dir(os.join_path(ws, d)), 'missing scaffold dir: ${d}'
	}
	assert os.exists(os.join_path(ws, 'knowledge', 'README.md'))
	assert os.exists(os.join_path(ws, '.gitignore'))
	assert os.exists(os.join_path(ws, 'personas', 'implementer.md'))
	// truth planes: initialized now true; a plain dir ≠ initialized
	assert workspace_is_initialized(ws)
	plain := os.join_path(f.tmp, 'plain')
	os.mkdir_all(plain) or {}
	assert !workspace_is_initialized(plain)
}

// SEED idempotence: repeat without changes → no destructive rewrite, content
// user-visible intact, no duplicate receipts
fn test_seed_idempotent() {
	mut f := wl_fixture('seed-idem')
	defer {
		f.cleanup()
	}
	ws := os.join_path(f.tmp, 'ws')
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	notes := os.join_path(ws, 'knowledge', 'README.md')
	content_before := os.read_file(notes) or { panic('read failed') }
	rev1 := os.join_path(ws, '.agent-toolkit', 'swarm', 'runs')
	assert os.is_dir(rev1)
	// re-run
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	assert os.read_file(notes) or { panic('read failed') } == content_before
	// no duplicate persona files
	ents := os.ls(os.join_path(ws, 'personas')) or { []string{} }
	assert ents.filter(it == 'implementer.md').len == 1
	assert ents.len == 4
}

// SEED collision: user-modified existing file is NEVER overwritten
fn test_seed_collision_preserves_user_content() {
	mut f := wl_fixture('seed-collision')
	defer {
		f.cleanup()
	}
	ws := os.join_path(f.tmp, 'ws')
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	// user modifies a seeded file
	notes := os.join_path(ws, 'knowledge', 'README.md')
	os.write_file(notes, '# MY CUSTOM KNOWLEDGE — do not touch') or { panic(err.msg()) }
	// re-run: content preserved verbatim
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	assert (os.read_file(notes) or { panic('read failed') }).contains('MY CUSTOM KNOWLEDGE')
}

// SEED foreign file beside product files: preserved byte-for-byte
fn test_seed_foreign_file_preserved() {
	mut f := wl_fixture('seed-foreign')
	defer {
		f.cleanup()
	}
	ws := os.join_path(f.tmp, 'ws')
	os.mkdir_all(ws) or {}
	foreign := os.join_path(ws, 'MY-NOTES.txt')
	os.write_file(foreign, 'user own notes — must survive') or { panic(err.msg()) }
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	assert (os.read_file(foreign) or { panic('read failed') }) == 'user own notes — must survive'
}

// PARTIAL/proven: scaffold failure (scaffold parent path is a file) leaves
// existing writes visible and reports the error — no fake rollback
// PARTIAL: a blocked scaffold write is collected as a truthful seed warning
// (persisted in state), user content is preserved byte-for-byte, and the
// other scaffold files stay intact — no fake rollback, no fake full success.
fn test_seed_partial_failure_truthful() {
	mut f := wl_fixture('seed-partial')
	defer {
		f.cleanup()
	}
	ws := os.join_path(f.tmp, 'ws')
	// first init succeeds
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	// user replaces the knowledge/learnings DIR with a FILE of their own —
	// the re-init's write to knowledge/learnings/general.md is then blocked
	os.rmdir_all(os.join_path(ws, 'knowledge', 'learnings')) or {}
	user_content := 'my own learnings — do not touch'
	os.write_file(os.join_path(ws, 'knowledge', 'learnings'), user_content) or {
		panic(err.msg())
	}
	// re-init: engine reports success-with-warnings (best-effort architecture),
	// the user file is preserved byte-for-byte, other scaffold files intact
	f.eng.workspace_init_with_templates(ws, true) or { panic(err.msg()) }
	assert (os.read_file(os.join_path(ws, 'knowledge', 'learnings')) or {
		panic('read failed')
	}) == user_content
	assert os.exists(os.join_path(ws, 'knowledge', 'todos', 'pending.md'))
	// truthful warning persisted with the transaction
	r := f.eng.state_repo().snapshot().data['workspace/seed_warnings'] or { '' }
	assert r.contains('general.md'), 'seed warning must name the blocked file'
}

// SWITCH: A→B→A round trip — context updated, previous recorded, restart
// persistence (same state file re-read by a fresh Engine)
fn test_switch_round_trip_and_persistence() {
	mut f := wl_fixture('switch')
	defer {
		f.cleanup()
	}
	ws_a := os.join_path(f.tmp, 'ws-a')
	os.mkdir_all(os.join_path(ws_a, 'knowledge')) or {}
	ws_b := os.join_path(f.tmp, 'ws-b')
	os.mkdir_all(ws_b) or {}
	f.eng.switch_workspace(ws_a) or { panic(err.msg()) }
	_ = f.eng.workspace_init_with_templates(ws_a, true) or { panic(err.msg()) }
	f.eng.switch_workspace(ws_b) or { panic(err.msg()) }
	// context updated: active = b, previous = a
	list := f.eng.known_workspaces()
	active := list.filter(it.is_active)
	assert active.len == 1
	assert active[0].path.ends_with('ws-b')
	// restart: fresh Engine over the SAME state file restores b
	f.eng.stop() or {}
	mut eng2 := new_engine(EngineConfig{
		persist_path: os.join_path(f.tmp, 'state.json')
	})
	eng2.init() or { panic(err.msg()) }
	eng2.start() or { panic(err.msg()) }
	defer {
		eng2.stop() or {}
	}
	list2 := eng2.known_workspaces()
	active2 := list2.filter(it.is_active)
	assert active2.len == 1
	assert active2[0].path.ends_with('ws-b')
	// switch back to A
	eng2.switch_workspace(ws_a) or { panic(err.msg()) }
	assert eng2.known_workspaces().filter(it.is_active)[0].path.ends_with('ws-a')
}

// project ≠ workspace: switching projects never changes workspace_path
fn test_project_switch_does_not_change_workspace() {
	mut f := wl_fixture('proj')
	defer {
		f.cleanup()
	}
	ws := os.join_path(f.tmp, 'ws')
	os.mkdir_all(ws) or { panic(err.msg()) }
	f.eng.switch_workspace(ws) or { panic(err.msg()) }
	before := f.eng.known_workspaces().filter(it.is_active)[0].path
	f.eng.switch_project('my-project') or { panic(err.msg()) }
	assert f.eng.current_project() == 'my-project'
	assert f.eng.known_workspaces().filter(it.is_active)[0].path == before
}
