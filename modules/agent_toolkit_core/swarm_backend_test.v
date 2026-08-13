module agent_toolkit_core

fn test_headless_always_available() {
	d := doctor_backend('headless')
	assert d.available
	assert d.name == 'headless'
}

fn test_unknown_backend() {
	d := doctor_backend('nope')
	assert !d.available
}

fn test_resolve_auto_falls_back() {
	// auto may pick herdr/tmux if installed; still a known name
	n := resolve_swarm_backend('auto')
	assert n in ['herdr', 'tmux', 'headless']
	forced := resolve_swarm_backend('headless')
	assert forced == 'headless'
}
