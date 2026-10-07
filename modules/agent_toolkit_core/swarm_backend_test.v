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

fn test_runner_command_uses_quoted_model_for_supported_runners() {
	opencode := herdr_runner_cmd_for_model('opencode', 'reviewer', 'Review this', '.', '', 'model/with quote')
	assert opencode.contains('opencode --model ' + shell_quote('model/with quote') + ' --agent ' + shell_quote('reviewer'))
	codex := herdr_runner_cmd_for_model('codex', 'reviewer', 'Review this', '.', '', 'o3-mini')
	assert codex.contains('codex -m ' + shell_quote('o3-mini') + ' -C')
	assert herdr_runner_cmd_for_model('muse', 'reviewer', 'Review this', '.', '', 'auto') == herdr_runner_cmd('muse',
		'reviewer', 'Review this', '.', '')
}
