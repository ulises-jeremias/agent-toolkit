module desktop_engine

import os

fn test_runtime_plane_jobs_via_engine_no_shell() {
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
	assert loops.len == 10
	diags := eng.loop_validate('test', 'budget: -1')
	assert diags.len > 0
	diags2 := eng.loop_validate('test', 'name: x')
	assert diags2.len > 0
	rev := eng.upsert_loop(loops[0]) or { panic(err.msg()) }
	assert rev >= 1
	rev2 := eng.toggle_loop_cron(loops[0].name, true) or { panic(err.msg()) }
	assert rev2 > rev
	id := eng.run_loop(loops[0].name) or { panic(err.msg()) }
	assert id.len > 0
	hist := eng.loops_history(loops[0].name)
	assert hist.len >= 1
	assert loops[0].budget_remaining() == loops[0].budget_total - loops[0].budget_spent
	assert eng.api_call_count() > 0
}

fn test_runtime_plane_workspace_via_engine_no_shell() {
	tmp := os.join_path(os.temp_dir(), 'runtime-ws-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	tree := eng.workspace_tree()
	assert tree.len >= 4
	ledger := eng.memory_ledger('')
	assert ledger.len >= 1
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
