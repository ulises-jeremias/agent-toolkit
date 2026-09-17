module agent_toolkit_cli

fn test_parse_ci_wait_positional() {
	opts := parse_ci_wait_options(['owner/repo', '42']) or {
		assert false, err.msg()
		return
	}
	assert opts.repo == 'owner/repo'
	assert opts.pr == '42'
	assert opts.timeout_secs == 0
}

fn test_parse_ci_wait_flags() {
	opts := parse_ci_wait_options(['--repo=owner/repo', '--pr', '7', '--timeout=30']) or {
		assert false, err.msg()
		return
	}
	assert opts.repo == 'owner/repo'
	assert opts.pr == '7'
	assert opts.timeout_secs == 30
}

fn test_parse_ci_wait_missing_pr() {
	opts := parse_ci_wait_options(['owner/repo']) or {
		assert false, err.msg()
		return
	}
	assert opts.repo == 'owner/repo'
	assert opts.pr == ''
}

fn test_parse_ci_wait_requires_timeout_arg() {
	_ := parse_ci_wait_options(['--timeout']) or {
		assert err.msg().contains('requires an argument')
		return
	}
	assert false, 'expected error for bare --timeout'
}

fn test_dispatch_ci_wait_usage_exit_2() {
	code := dispatch(['agent-toolkit', 'ci-wait'])
	assert code == 2
}

fn test_root_command_tree_has_ci_wait() {
	root := build_root_command()
	mut found := false
	for c in root.commands {
		if c.name == 'ci-wait' {
			found = true
		}
	}
	assert found
}
