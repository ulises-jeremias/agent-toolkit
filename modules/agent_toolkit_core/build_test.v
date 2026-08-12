module agent_toolkit_core

import os

fn test_run_build_check_temp_repo() {
	root := os.join_path(os.temp_dir(), 'at-build-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'agents', 'code-reviewer')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'loops')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), 'skill\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'agents', 'code-reviewer', 'AGENT.md'), 'agent\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'),
		'products:\n  - id: agent-toolkit-core\n    includes:\n      skills:\n        - core/assistant\n      agents:\n        - code-reviewer\n') or {
		assert false, err.msg()
	}
	// Seed matching plugins/ so drift check is clean for cursor surface.
	os.mkdir_all(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant')) or {
		assert false, err.msg()
	}
	os.mkdir_all(os.join_path(root, 'plugins', 'agent-toolkit-core', 'agents', 'code-reviewer')) or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant', 'SKILL.md'),
		'skill\n') or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'plugins', 'agent-toolkit-core', 'agents', 'code-reviewer',
		'AGENT.md'), 'agent\n') or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	os.setenv('AGENT_TOOLKIT_ROOT', root, true)
	defer {
		os.unsetenv('AGENT_TOOLKIT_ROOT')
	}
	report := run_build(BuildOptions{
		check:       true
		target:      'cursor'
		product:     'agent-toolkit-core'
		write_files: false
	})
	assert report.ok, report.message
	assert report.mode == 'check'
	assert report.results.len == 1
	assert report.drift.len == 0
	cr := build_result(report)
	assert cr.ok
	assert cr.command == 'build'
	assert cr.data['mode'] == 'check'
}

fn test_run_build_check_detects_drift() {
	root := os.join_path(os.temp_dir(), 'at-build-drift-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'loops')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), 'canonical\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'),
		'products:\n  - id: agent-toolkit-core\n    includes:\n      skills:\n        - core/assistant\n      agents: []\n') or {
		assert false, err.msg()
	}
	os.mkdir_all(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant')) or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant', 'SKILL.md'),
		'stale\n') or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	os.setenv('AGENT_TOOLKIT_ROOT', root, true)
	defer {
		os.unsetenv('AGENT_TOOLKIT_ROOT')
	}
	report := run_build(BuildOptions{
		check:   true
		target:  'cursor'
		product: 'agent-toolkit-core'
	})
	assert !report.ok
	assert report.drift.len >= 1
}

fn test_run_build_unknown_target() {
	root := os.join_path(os.temp_dir(), 'at-build-unk-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'loops')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'), 'products: []\n') or {
		assert false, err.msg()
	}
	defer {
		os.rmdir_all(root) or {}
	}
	os.setenv('AGENT_TOOLKIT_ROOT', root, true)
	defer {
		os.unsetenv('AGENT_TOOLKIT_ROOT')
	}
	report := run_build(BuildOptions{
		check:  true
		target: 'not-a-target'
	})
	assert !report.ok
	assert report.message.contains('unknown Tier-1 target'), report.message
}
