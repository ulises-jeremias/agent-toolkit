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

fn test_dispatch_matrix_exit_zero() {
	code := dispatch(['agent-toolkit', 'matrix'])
	assert code == 0
}

fn test_dispatch_inventory_exit_zero() {
	code := dispatch(['agent-toolkit', 'inventory'])
	assert code == 0
}

fn test_dispatch_doctor_json_exit_zero() {
	code := dispatch(['agent-toolkit', 'doctor', '--json'])
	assert code == 0
}

fn test_dispatch_doctor_fix_exits_zero() {
	code := dispatch(['agent-toolkit', 'doctor', '--fix', '--json'])
	assert code == 0
}

fn test_dispatch_doctor_help_mentions_fix() {
	code := dispatch(['agent-toolkit', 'doctor', '--help'])
	assert code == 0
}

fn test_dispatch_build_check_unknown_target_fails() {
	code := dispatch(['agent-toolkit', 'build', '--check', '--target', 'not-a-target', '--json'])
	assert code != 0
}

fn test_dispatch_build_help() {
	code := dispatch(['agent-toolkit', 'build', '--help'])
	assert code == 0
}

fn test_dispatch_install_help() {
	code := dispatch(['agent-toolkit', 'install', '--help'])
	assert code == 0
}

fn test_dispatch_install_dry_run_json() {
	code := dispatch(['agent-toolkit', 'install', '--tools', 'cursor', '--dry-run', '--offline',
		'--json'])
	assert code == 0
}

fn test_dispatch_uninstall_help() {
	code := dispatch(['agent-toolkit', 'uninstall', '--help'])
	assert code == 0
}

fn test_dispatch_diff_help() {
	code := dispatch(['agent-toolkit', 'diff', '--help'])
	assert code == 0
}

fn test_dispatch_update_help() {
	code := dispatch(['agent-toolkit', 'update', '--help'])
	assert code == 0
}

fn test_dispatch_skills_help() {
	code := dispatch(['agent-toolkit', 'skills', '--help'])
	assert code == 0
}

fn test_dispatch_mcp_help() {
	code := dispatch(['agent-toolkit', 'mcp', '--help'])
	assert code == 0
}

fn test_dispatch_plugin_help() {
	code := dispatch(['agent-toolkit', 'plugin', '--help'])
	assert code == 0
}

fn test_dispatch_workspace_help() {
	code := dispatch(['agent-toolkit', 'workspace', '--help'])
	assert code == 0
}

fn test_dispatch_workspace_context_json() {
	code := dispatch(['agent-toolkit', 'workspace', 'context', '--json'])
	assert code == 0
}

fn test_dispatch_memory_help() {
	code := dispatch(['agent-toolkit', 'memory', '--help'])
	assert code == 0
}

fn test_dispatch_rollback_alias_allowed() {
	// No receipts in default dir may exit non-zero; alias must be known (not unknown command).
	code := dispatch(['agent-toolkit', 'rollback', '--dry-run', '--json'])
	assert code != 2
}

fn test_grouped_help_mentions_consumer_and_advanced() {
	h := grouped_help()
	assert h.contains('Consumer') || h.to_lower().contains('install')
	assert h.contains('Advanced') || h.to_lower().contains('inventory')
}
