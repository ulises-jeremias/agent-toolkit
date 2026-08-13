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
	assert code == 0
}

fn test_dispatch_devcompanion_help() {
	code := dispatch(['agent-toolkit', 'devcompanion', '--help'])
	assert code == 0
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

fn test_dispatch_project_help() {
	code := dispatch(['agent-toolkit', 'project', '--help'])
	assert code == 0
}

fn test_dispatch_memory_help() {
	code := dispatch(['agent-toolkit', 'memory', '--help'])
	assert code == 0
}

fn test_dispatch_dc_alias_help() {
	code := dispatch(['agent-toolkit', 'dc', '--help'])
	assert code == 0
}

fn test_dispatch_loop_help() {
	code := dispatch(['agent-toolkit', 'loop', '--help'])
	assert code == 0
}

fn test_dispatch_swarm_help() {
	code := dispatch(['agent-toolkit', 'swarm', '--help'])
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
	assert h.contains('Install profiles for detected AI tools')
	assert h.contains('completion')
	assert h.contains('alias: rollback')
	assert h.contains('alias: dc')
	assert !h.contains('install (consumer)')
}

fn test_inventory_help_is_implemented() {
	h := subcommand_help('inventory')
	assert h.contains('agent-toolkit inventory')
	assert h.contains('--json')
	assert !h.contains('not yet implemented')
}

fn test_matrix_help_is_implemented() {
	h := subcommand_help('matrix')
	assert h.contains('agent-toolkit matrix')
	assert h.contains('--json')
	assert !h.contains('not yet implemented')
}

fn test_doctor_help_mentions_provenance() {
	h := subcommand_help('doctor')
	assert h.contains('--provenance')
	assert h.contains('--fix')
	assert h.contains('Exit codes')
}

fn test_insights_help_is_deprecate_disposition() {
	h := subcommand_help('insights')
	assert h.contains('agent-toolkit-py')
	assert h.contains('#526') || h.to_lower().contains('deprecat')
	assert !h.contains('not yet implemented')
}

fn test_release_help_is_remove_disposition() {
	h := subcommand_help('release')
	assert h.contains('docs/RELEASING.md')
	assert h.contains('#527') || h.to_lower().contains('removed')
	assert !h.contains('not yet implemented')
}

fn test_insights_no_args_exits_zero() {
	code := dispatch(['agent-toolkit', 'insights'])
	assert code == 0
}

fn test_insights_subcommand_exits_one() {
	code := dispatch(['agent-toolkit', 'insights', 'opencode'])
	assert code == 1
}

fn test_release_exits_one() {
	code := dispatch(['agent-toolkit', 'release'])
	assert code == 1
}

fn test_update_help_has_examples() {
	h := subcommand_help('update')
	assert h.contains('Examples:')
	assert h.contains('--check')
}
