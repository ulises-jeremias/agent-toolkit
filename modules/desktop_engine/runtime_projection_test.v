module desktop_engine

import os

// loop_runtime_paths_use_runtime_path ensures loop worktrees and hygiene scans
// are scoped to the Engine runtime_path, never to toolkit_root. This is the S2
// runtime-projection boundary: bundled catalog data is immutable; runtime
// artifacts are mutable and isolated.
fn test_loop_runtime_paths_use_runtime_path() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }

	tmp := os.join_path(os.temp_dir(), 'runtime-projection-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }

	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	// runtime_path is derived from persist_path
	assert eng.runtime_path == os.join_path(tmp, 'state.runtime'), 'runtime_path derived: ${eng.runtime_path}'
	assert os.is_dir(eng.runtime_path), 'runtime_path created'

	// worktree is under runtime_path, not toolkit_root
	wt := eng.loop_worktree_path('daily-triage', 'run-001') or { panic(err.msg()) }
	assert wt.starts_with(eng.runtime_path), 'worktree must live under runtime_path: ${wt}'
	assert !wt.contains('embedded'), 'worktree must not be inside embedded catalog'
	assert wt.contains('loops/daily-triage/runs/run-001/worktree')

	// create two runs and verify hygiene detects no duplicate
	os.mkdir_all(os.join_path(eng.runtime_path, 'loops', 'daily-triage', 'runs', 'run-001', 'worktree')) or { panic(err.msg()) }
	os.mkdir_all(os.join_path(eng.runtime_path, 'loops', 'daily-triage', 'runs', 'run-002', 'worktree')) or { panic(err.msg()) }
	diags := eng.ensure_loop_worktree_hygiene('daily-triage')
	assert diags.len == 0, 'distinct worktrees should be clean: ${diags}'

	// path traversal is rejected
	if _ := eng.loop_worktree_path('..', 'run-001') {
		assert false, 'traversal must fail'
	} else {
		assert err.msg().contains('traversal')
	}
}

// empty_persist_path_falls_back_to_temp_runtime ensures an in-memory engine
// still has a runtime namespace and does not collide with the toolkit root.
fn test_runtime_path_fallback_when_persist_empty() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }

	mut eng := new_engine(EngineConfig{})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	assert eng.runtime_path.len > 0
	assert os.is_dir(eng.runtime_path)
	assert eng.runtime_path.starts_with(os.temp_dir())
}
