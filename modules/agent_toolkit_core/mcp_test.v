module agent_toolkit_core

import os

fn test_mcp_list_setup_uninstall_offline() {
	base := os.join_path(os.temp_dir(), 'at-mcp-${os.getpid()}')
	tdir := os.join_path(base, 'mcp', 'templates', 'github')
	rdir := os.join_path(base, 'mcp', 'registry')
	cfg := os.join_path(base, 'mcp-config.json')
	os.mkdir_all(tdir) or { assert false, err.msg() }
	os.mkdir_all(rdir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(tdir, 'config.template.json'), '{"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"$' + '{GITHUB_PERSONAL_ACCESS_TOKEN}"}}') or {
		assert false, err.msg()
		return
	}
	os.write_file(os.join_path(rdir, 'github.yaml'), 'id: github\ndisplay_name: GitHub\nimplementation:\n  package: ghcr.io/github/github-mcp-server\nauth:\n  env: [GITHUB_PERSONAL_ACCESS_TOKEN]\n') or {
		assert false, err.msg()
		return
	}

	listed := run_mcp(McpOptions{
		subcommand:   'list'
		toolkit_root: base
		config_path:  cfg
	})
	assert listed.ok
	assert listed.message.contains('github')
	assert !listed.message.to_lower().contains('ghp_') // no token leak

	setup := run_mcp(McpOptions{
		subcommand:   'setup'
		provider:     'github'
		offline:      true
		toolkit_root: base
		config_path:  cfg
	})
	assert setup.ok
	saved := os.read_file(cfg) or { '' }
	assert saved.contains('"github"')
	assert saved.contains('required_env')
	assert !saved.contains('ghp_')
	assert !saved.to_lower().contains('token_value')

	health := run_mcp(McpOptions{
		subcommand:   'health'
		provider:     'github'
		toolkit_root: base
		config_path:  cfg
	})
	// health.ok can be flaky on macOS CI (docker/binary not available in sandbox)
	$if !macos {
		assert health.ok
	}
	assert health.message.contains('GitHub')

	un := run_mcp(McpOptions{
		subcommand:  'uninstall'
		provider:    'github'
		config_path: cfg
	})
	assert un.ok
	after := os.read_file(cfg) or { '' }
	assert !after.contains('"github"')
}

fn test_mcp_unknown_subcommand() {
	r := run_mcp(McpOptions{
		subcommand: 'explode'
	})
	assert !r.ok
}

fn test_extract_template_env_names() {
	names := extract_template_env_names('{"env":{"A":"$' + '{FOO}","B":"$' + '{BAR}"}}')
	assert 'FOO' in names
	assert 'BAR' in names
}
