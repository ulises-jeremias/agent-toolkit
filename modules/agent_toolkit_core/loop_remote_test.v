module agent_toolkit_core

fn test_cadence_to_cron_table() {
	assert cadence_to_cron('15m')! == '*/15 * * * *'
	assert cadence_to_cron('1m')! == '* * * * *'
	assert cadence_to_cron('30m')! == '*/30 * * * *'
	assert cadence_to_cron('4h')! == '0 */4 * * *'
	assert cadence_to_cron('1h')! == '0 * * * *'
	assert cadence_to_cron('24h')! == '0 0 * * *'
	assert cadence_to_cron('1d')! == '0 0 * * *'
	assert cadence_to_cron('2d')! == '0 0 */2 * *'
	assert cadence_to_cron('1w')! == '0 0 * * 0'
}

fn test_cadence_to_cron_invalid() {
	if _ := cadence_to_cron('') {
		assert false, 'empty should error'
	} else {
		assert err.msg().contains('invalid cadence')
	}
	if _ := cadence_to_cron('2w') {
		assert false, '2w should error'
	} else {
		assert err.msg().contains('only 1w')
	}
	if _ := cadence_to_cron('60m') {
		assert false, '60m should error'
	} else {
		assert err.msg().contains('1-59')
	}
	if _ := cadence_to_cron('abc') {
		assert false, 'abc should error'
	} else {
		assert err.msg().contains('invalid cadence')
	}
}

fn test_emit_github_workflow_contains_cron() {
	yml := emit_github_workflow('oss-triage', 'L1', '1d', '0 0 * * *', '1.18.0')
	assert yml.contains("cron: '0 0 * * *'")
	assert yml.contains('agent-toolkit — oss-triage')
	assert yml.contains('concurrency:')
	assert yml.contains('group: agent-toolkit-oss-triage')
	assert yml.contains('uvx --from agent-toolkit-cli==1.18.0')
	assert yml.contains('GITHUB_TOKEN')
}

fn test_remote_platforms() {
	pls := remote_platforms()
	assert 'local' in pls
	assert 'github-actions' in pls
	assert is_remote_platform('github-actions')
	assert !is_remote_platform('gitlab-ci')
}
