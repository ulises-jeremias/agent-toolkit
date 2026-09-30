module agent_toolkit_core

import os

fn setup_catalog_swarm() (string, string) {
	old_h := os.getenv('HARNESS_DIR')
	old_ws := os.getenv('AGENT_TOOLKIT_WORKSPACE')
	os.unsetenv('HARNESS_DIR')
	os.unsetenv('AGENT_TOOLKIT_WORKSPACE')
	base := os.join_path(os.temp_dir(), 'atk-swcat-${os.getpid()}')
	os.rmdir_all(base) or {}
	os.mkdir_all(os.join_path(base, '.git')) or { panic(err.msg()) }
	_ = old_h
	_ = old_ws
	start := run_swarm(SwarmOptions{
		subcommand: 'start'
		workspace_path: base
		recipe: 'team'
		backend: 'headless'
		task: 'catalog demo'
	})
	if !start.ok {
		panic(start.message)
	}
	return base, start.data['run_id']
}

fn test_list_and_status_typed() {
	base, rid := setup_catalog_swarm()
	defer {
		os.rmdir_all(base) or {}
	}
	list := list_swarm_runs_typed(base)
	assert list.ok
	assert list.runs.len == 1
	assert list.runs[0].run_id == rid
	assert list.runs[0].run_state == 'awaiting_plan_approval'
	got := get_swarm_run_typed(base, rid) or { panic(err.msg()) }
	assert got.run.run_id == rid
	assert got.approvals.len > 0
	assert got.budget.cost_status == 'accounted'
	arts := list_swarm_artifacts_typed(base, rid) or { panic(err.msg()) }
	assert arts.artifacts.len >= 1
}

fn test_approve_reject_stop_typed() {
	base, rid := setup_catalog_swarm()
	defer {
		os.rmdir_all(base) or {}
	}
	ap := approve_swarm_gate_typed(base, rid, 'plan')
	assert ap.ok, ap.message
	assert ap.status == 'running'
	rej := reject_swarm_gate_typed(base, rid, 'final', 'not yet')
	assert rej.ok, rej.message
	gates := list_swarm_approvals_typed(base, rid) or { panic(err.msg()) }
	mut saw_final := false
	for g in gates.approvals {
		if g.id == 'final' {
			saw_final = true
			assert g.rejected
		}
	}
	assert saw_final
	st := stop_swarm_run_typed(base, rid)
	assert st.ok, st.message
}

fn test_invalid_run_id() {
	if _ := get_swarm_run_typed('/tmp', '../etc') {
		assert false
	} else {
		assert err.msg().contains('invalid run_id')
	}
}
