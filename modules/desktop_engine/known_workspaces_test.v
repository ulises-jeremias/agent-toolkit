module desktop_engine

import os
import time

// #1128 known-workspace discovery tests — bounded sources, truthful states.

struct KwFixture {
mut:
	tmp      string
	old_home string
	eng      &Engine = unsafe { nil }
}

fn kw_fixture(setup_active bool) &KwFixture {
	tmp := os.join_path(os.temp_dir(), 'atk-kw-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	mut f := &KwFixture{
		tmp:      tmp
		old_home: os.getenv('HOME')
	}
	os.setenv('HOME', tmp, true)
	// default workspace exists (designed fresh-user behavior)
	os.mkdir_all(os.join_path(tmp, '.ai-workspace', 'knowledge')) or {}
	// engine over an isolated persist inside the fixture
	eng_dir := os.join_path(tmp, 'engine')
	os.mkdir_all(eng_dir) or {}
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(eng_dir, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	f.eng = eng
	if setup_active {
		// establish active workspace + a previous via real switch seam
		ws_a := os.join_path(tmp, 'ws-a')
		os.mkdir_all(os.join_path(ws_a, 'knowledge')) or {}
		eng.switch_workspace(ws_a) or { panic(err.msg()) }
		ws_b := os.join_path(tmp, 'ws-b')
		os.mkdir_all(ws_b) or {}
		eng.switch_workspace(ws_b) or { panic(err.msg()) }
	}
	return f
}

fn (mut f KwFixture) cleanup() {
	f.eng.stop() or {}
	os.setenv('HOME', f.old_home, true)
	os.rmdir_all(f.tmp) or {}
	f.tmp = ''
}

fn kw_find(list []KnownWorkspace, suffix string) ?KnownWorkspace {
	for w in list {
		if w.path.ends_with(suffix) {
			return w
		}
	}
	return none
}

// bounded discovery: active + previous + default, deduped, active first
fn test_known_workspaces_bounded_and_truthful() {
	mut f := kw_fixture(true)
	defer {
		f.cleanup()
	}
	list := f.eng.known_workspaces()
	// exactly: ws-b (active), ws-a (previous), default ~/.ai-workspace — no crawls
	assert list.len == 3
	first := list[0]
	assert first.is_active
	assert first.path.ends_with('ws-b')
	assert first.why == 'active'
	prev := kw_find(list, 'ws-a') or { panic('previous missing') }
	assert prev.why == 'previous'
	assert !prev.is_active
	assert prev.initialized
	deflt := kw_find(list, '.ai-workspace') or { panic('default missing') }
	assert deflt.why == 'default'
	assert deflt.initialized
}

// a missing known workspace stays listed with exists=false — never dropped
fn test_known_workspace_missing_stays_listed() {
	mut f := kw_fixture(true)
	defer {
		f.cleanup()
	}
	// remove the previous workspace directory after switching away from it
	ws_a := f.tmp + '/ws-a'
	os.rmdir_all(ws_a) or {}
	list := f.eng.known_workspaces()
	missing := kw_find(list, 'ws-a') or { panic('missing ws must stay listed') }
	assert !missing.exists
	assert !missing.initialized
	// the state is concrete: not active, not initialized, but known
	assert !missing.is_active
}

// recent projects that exist join the list as 'recent project'
fn test_known_workspaces_recent_projects() {
	mut f := kw_fixture(false)
	defer {
		f.cleanup()
	}
	ws_r := os.join_path(f.tmp, 'ws-recent')
	os.mkdir_all(os.join_path(ws_r, 'repos', 'proj')) or {}
	mut repo := f.eng.state_repo()
	mut tx := repo.begin('kw-recent')
	tx.set('workspace/recent_projects', ws_r)
	f.eng.put_transaction(mut tx) or { panic(err.msg()) }
	list := f.eng.known_workspaces()
	found := kw_find(list, 'ws-recent') or { panic('recent project missing') }
	assert found.why == 'recent project'
	assert found.exists
	assert found.has_projects
	// a recent project path that no longer exists is dropped (not a dir)
	assert list.all(!it.path.ends_with('nonexistent'))
}

// the home directory itself is never listed as a workspace (#1127 rule)
fn test_known_workspaces_never_home() {
	mut f := kw_fixture(false)
	defer {
		f.cleanup()
	}
	list := f.eng.known_workspaces()
	for w in list {
		assert w.path != os.home_dir()
		assert w.path != '/'
	}
}
