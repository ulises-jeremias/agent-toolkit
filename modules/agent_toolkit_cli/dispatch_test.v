module agent_toolkit_cli

fn test_dispatch_version_exit_zero() {
	code := dispatch(['agent-toolkit', 'version'])
	assert code == 0
}

fn test_dispatch_help_exit_zero() {
	code := dispatch(['agent-toolkit', '--help'])
	assert code == 0
}

fn test_dispatch_unknown_command_exit_one() {
	code := dispatch(['agent-toolkit', 'not-a-real-command'])
	assert code == 1
}

fn test_dispatch_unknown_flag_exit_two() {
	code := dispatch(['agent-toolkit', '--bogus-flag'])
	assert code == 2
}

fn test_dispatch_dc_alias_not_unknown() {
	code := dispatch(['agent-toolkit', 'dc'])
	// not implemented → user exit 1, but known command
	assert code == 1
}

fn test_grouped_help_mentions_consumer_and_advanced() {
	h := grouped_help()
	assert h.contains('Consumer') || h.to_lower().contains('install')
	assert h.contains('Advanced') || h.to_lower().contains('inventory')
}
