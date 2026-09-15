module desktop

// Release UAT: the Office attention surface must never deny a capability
// the product ships — stop lives in Operations run control.

fn office_hint_row(kind string, state OfficeRunState) OfficeRunRow {
	return OfficeRunRow{
		kind: kind
		id: 'r-1'
		state: state
	}
}

fn test_office_hint_routes_running_swarm_to_operations_stop() {
	hint := office_no_actions_hint(office_hint_row('swarm', .running))
	assert hint.contains('Operations'), 'running swarm routes to Operations: ${hint}'
	assert !hint.contains('No stop control'), 'never denies shipped stop: ${hint}'
}

fn test_office_hint_routes_waiting_swarm_to_operations_stop() {
	hint := office_no_actions_hint(office_hint_row('swarm', .waiting))
	assert hint.contains('Operations'), 'waiting swarm routes to Operations: ${hint}'
	assert !hint.contains('No stop control'), 'never denies shipped stop: ${hint}'
}

fn test_office_hint_unknown_hides_actions_honestly() {
	hint := office_no_actions_hint(office_hint_row('swarm', .unknown))
	assert hint.contains('unknown'), 'unknown state names itself: ${hint}'
}
