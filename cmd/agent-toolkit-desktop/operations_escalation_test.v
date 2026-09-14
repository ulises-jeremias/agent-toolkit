module main

// Slice J escalation copy: approvals first, then failure, then waiting.

fn test_escalation_prefers_pending_approvals() {
	assert swarm_escalation_line('failed', 2) == '2 approval(s) pending'
	assert swarm_escalation_line('running', 1) == '1 approval(s) pending'
}

fn test_escalation_names_failure() {
	assert swarm_escalation_line('failed', 0) == 'run failed — see report'
}

fn test_escalation_names_bare_waiting() {
	assert swarm_escalation_line('awaiting_approval', 0) == 'waiting on approval'
}

fn test_escalation_quiet_when_nothing_needs_you() {
	assert swarm_escalation_line('running', 0) == ''
	assert swarm_escalation_line('completed', 0) == ''
	assert swarm_escalation_line('canceled', 0) == ''
}
