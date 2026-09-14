module main

// Slice B run-control helpers: status classification, promote targets, and
// canonical loop entries. Behavior-named; no GUI boot required.

fn test_active_is_running_or_awaiting() {
	assert ops_swarm_is_active(.running) == true
	assert ops_swarm_is_active(.awaiting_approval) == true
	assert ops_swarm_is_active(.pending) == false
	assert ops_swarm_is_active(.requested) == false
	assert ops_swarm_is_active(.completed) == false
	assert ops_swarm_is_active(.failed) == false
	assert ops_swarm_is_active(.canceled) == false
}

fn test_terminal_is_completed_failed_canceled() {
	assert ops_swarm_is_terminal(.completed) == true
	assert ops_swarm_is_terminal(.failed) == true
	assert ops_swarm_is_terminal(.canceled) == true
	assert ops_swarm_is_terminal(.running) == false
	assert ops_swarm_is_terminal(.awaiting_approval) == false
	assert ops_swarm_is_terminal(.pending) == false
}

fn test_active_and_terminal_never_overlap() {
	statuses := [desktop_engine.SwarmRunStatus.requested, .pending, .running, .awaiting_approval,
		.completed, .failed, .canceled]
	for s in statuses {
		assert !(ops_swarm_is_active(s) && ops_swarm_is_terminal(s)), 'status must not be both active and terminal: ${s}'
	}
}

fn test_promote_target_follows_recipe_ladder() {
	assert ops_promote_target('pair') == 'team'
	assert ops_promote_target('team') == 'full'
	assert ops_promote_target('full') == ''
	assert ops_promote_target('unknown') == ''
	assert ops_promote_target('') == ''
}
