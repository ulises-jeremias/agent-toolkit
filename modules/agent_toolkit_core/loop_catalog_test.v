module agent_toolkit_core

import os

fn setup_catalog_loop() string {
	base := os.join_path(os.temp_dir(), 'atk-loopcat-${os.getpid()}')
	os.rmdir_all(base) or {}
	dir := os.join_path(base, 'loops', 'triage')
	os.mkdir_all(os.join_path(dir, 'runs', 'run-1')) or { panic(err.msg()) }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	os.write_file(os.join_path(dir, 'loop.yaml'), 'name: triage\ntier: L1\ncadence: 1h\ngoal: triage inbox\nbudget:\n  max_tokens: 1000\n  max_runs_per_day: 3\n  max_wall_seconds: 60\n') or {
		panic(err.msg())
	}
	os.write_file(os.join_path(dir, 'STATE.md'), 'last_run: 2026-09-30\nlast_run_status: completed\nlast_run_id: run-1\nruns_today: 1\n') or {
		panic(err.msg())
	}
	os.write_file(os.join_path(dir, 'runs', 'run-1', 'trace.jsonl'), '{"kind":"run_end","status":"completed"}\n') or {
		panic(err.msg())
	}
	return base
}

fn test_list_and_status_loop() {
	base := setup_catalog_loop()
	defer {
		os.rmdir_all(base) or {}
	}
	list := list_loops_typed(base)
	assert list.ok
	assert list.loops.len == 1
	assert list.loops[0].name == 'triage'
	assert list.loops[0].tier == 'L1'
	st := get_loop_status_typed(base, 'triage') or { panic(err.msg()) }
	assert st.info.name == 'triage'
	assert st.budget.cost_status == 'unavailable'
	assert st.budget.max_tokens == 1000
	hist := get_loop_history_typed(base, 'triage') or { panic(err.msg()) }
	assert hist.runs.len == 1
	assert hist.runs[0].status == 'completed'
	audit := get_loop_audit_typed(base, 'triage') or { panic(err.msg()) }
	assert audit.completed == 1
	cost := get_loop_cost_typed(base, 'triage') or { panic(err.msg()) }
	assert cost.cost_status == 'unavailable'
}

fn test_missing_loop() {
	base := setup_catalog_loop()
	defer {
		os.rmdir_all(base) or {}
	}
	if _ := get_loop_status_typed(base, 'nope') {
		assert false
	} else {
		assert err.msg().contains('loop not found')
	}
}
