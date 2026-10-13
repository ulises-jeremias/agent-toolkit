module agent_toolkit_core

import os

fn test_swarm_transitions() {
	assert swarm_can_transition('planning', 'awaiting_plan_approval')
	assert swarm_can_transition('awaiting_plan_approval', 'running')
	assert swarm_can_transition('running', 'cancelled')
	assert !swarm_can_transition('completed', 'running')
	assert !swarm_can_transition('cleanup_pending', 'running')
}

fn test_swarm_gates_and_recipes() {
	assert swarm_recipe_roles('pair').len == 3
	assert swarm_recipe_roles('team').len == 4
	assert swarm_recipe_roles('full').len == 6
	assert !swarm_require_plan_approval('pair')
	assert swarm_require_plan_approval('team')
	pair_gates := swarm_default_gates('pair')
	assert pair_gates.len == 1
	assert pair_gates[0].id == 'final'
	team_gates := swarm_default_gates('team')
	assert team_gates.len == 2
	assert team_gates[0].id == 'plan'
}

fn test_swarm_run_id() {
	assert swarm_valid_run_id('s20260813T010203Z')
	assert !swarm_valid_run_id('ab')
	assert !swarm_valid_run_id('../etc')
	assert !swarm_valid_run_id('')
}

fn test_swarm_state_roundtrips_selected_project_and_base_ref() {
	run_dir := os.join_path(os.temp_dir(), 'at-swarm-state-${os.getpid()}')
	ensure_swarm_run_dirs(run_dir) or { panic(err) }
	defer { os.rmdir_all(run_dir) or {} }
	state := SwarmStateFile{
		version:     swarm_state_version
		run_id:      'run-test'
		recipe:      'pair'
		project_id:  'agent-toolkit'
		base_ref:    'release/1.44'
	}
	write_swarm_state(run_dir, state) or { panic(err) }
	loaded := read_swarm_state(run_dir) or { panic('state did not roundtrip') }
	assert loaded.project_id == 'agent-toolkit'
	assert loaded.base_ref == 'release/1.44'
}
