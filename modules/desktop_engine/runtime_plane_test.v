module desktop_engine

import os

fn test_runtime_plane_jobs_via_engine_no_shell() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'runtime-jobs-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	id := eng.spawn_job('echo', ['hello']) or { panic(err.msg()) }
	assert id.starts_with('job-')
	jobs := eng.jobs_catalog()
	assert jobs.len >= 1
	logs := eng.job_logs(id)
	assert logs.len >= 0
	rev := eng.cancel_job(id) or { panic(err.msg()) }
	assert rev >= 1
	jobs2 := eng.jobs_catalog()
	mut found := false
	for j in jobs2 {
		if j.id == id && j.status == .canceled {
			found = true
		}
	}
	assert found
	assert eng.api_call_count() > 0
}

fn test_runtime_plane_loops_via_engine_no_shell() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'runtime-loops-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	loops := eng.loops_catalog()
	for loop in loops {
		assert !loop.name.starts_with('goal-'), 'runtime must not invent template loops'
	}
	diags := eng.loop_validate('test', 'budget: -1')
	assert diags.len > 0
	diags2 := eng.loop_validate('test', 'name: x')
	assert diags2.len > 0
	entry := LoopEntry{
		name: 'test-loop'
		goal: 'Exercise the runtime loop lifecycle'
		tier: .l1
		stage: 'l1'
		cadence: '1d'
		schedule: cadence_to_cron('1d')
		budget: loop_budget_defaults(.l1)
		budget_total: loop_budget_defaults(.l1).max_tokens
	}
	rev := eng.upsert_loop(entry) or { panic(err.msg()) }
	assert rev >= 1
	rev2 := eng.toggle_loop_cron(entry.name, true) or { panic(err.msg()) }
	assert rev2 > rev
	id := eng.run_loop(entry.name) or { panic(err.msg()) }
	assert id.len > 0
	hist := eng.loops_history(entry.name)
	assert hist.len >= 1
	assert entry.budget_remaining() == entry.budget_total - entry.budget_spent
	assert eng.api_call_count() > 0
}

fn test_runtime_plane_workspace_via_engine_no_shell() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'runtime-ws-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	// honest workspace: with no workspace configured the tree and ledger are
	// empty — never toolkit-root-derived nodes or invented memory entries
	tree := eng.workspace_tree()
	assert tree.len == 0, 'no configured workspace yields an empty tree'
	ledger := eng.memory_ledger('')
	assert ledger.len == 0, 'no fabricated memory entries'
	// configure a real workspace → the tree reflects real directories
	ws := os.join_path(tmp, 'ws')
	os.mkdir_all(os.join_path(ws, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(ws, 'knowledge', 'note.md'), '# real\n') or { panic(err.msg()) }
	eng.switch_workspace(ws) or { panic(err.msg()) }
	tree2 := eng.workspace_tree()
	assert tree2.len >= 1, 'a real workspace yields real nodes'
	mut found_note := false
	for n in tree2 {
		if n.path.contains('note.md') {
			found_note = true
		}
	}
	assert found_note, 'real workspace file must appear in the tree'
	harness := tmp
	bad := os.join_path(os.temp_dir(), 'escape')
	if _ := eng.open_path_validated(harness, bad) {
		assert false, 'escape must be blocked'
	} else {
		assert err.msg().contains('harness_root_escape')
	}
	good := os.join_path(tmp, 'knowledge')
	os.mkdir_all(good) or {}
	ok := eng.open_path_validated(harness, good) or { panic(err.msg()) }
	assert ok.len > 0
	assert eng.api_call_count() > 0
}
