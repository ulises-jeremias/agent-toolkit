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
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'), 'products:\n  - id: agent-toolkit-core\n    includes:\n      skills:\n        - core/assistant\n      agents:\n        - code-reviewer\n') or {
		assert false, err.msg()
	}
	// Seed matching plugins/ so drift check is clean for cursor surface.
	os.mkdir_all(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant')) or {
		assert false, err.msg()
	}
	os.mkdir_all(os.join_path(root, 'plugins', 'agent-toolkit-core', 'agents', 'code-reviewer')) or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant', 'SKILL.md'), 'skill\n') or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'plugins', 'agent-toolkit-core', 'agents', 'code-reviewer', 'AGENT.md'), 'agent\n') or { assert false, err.msg() }
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
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'), 'products:\n  - id: agent-toolkit-core\n    includes:\n      skills:\n        - core/assistant\n      agents: []\n') or {
		assert false, err.msg()
	}
	os.mkdir_all(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant')) or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'plugins', 'agent-toolkit-core', 'skills', 'assistant', 'SKILL.md'), 'stale\n') or { assert false, err.msg() }
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

fn test_run_build_check_detects_creative_plugin_resource_drift() {
	root := os.join_path(os.temp_dir(), 'at-build-creative-drift-${os.getpid()}')
	skill_src := os.join_path(root, 'skills', 'design', 'brag')
	plugin_skill := os.join_path(root, 'plugins', 'agent-toolkit-creative-studio', 'skills', 'brag')
	os.mkdir_all(os.join_path(skill_src, 'scripts')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(plugin_skill, 'scripts')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'loops')) or { assert false, err.msg() }
	skill := '---\nname: brag\ndistribution:\n  mode: vendored\n  resources:\n  - scripts/analyze.py\n  - scripts/uv.lock\n---\nbody\n'
	os.write_file(os.join_path(skill_src, 'SKILL.md'), skill) or { assert false, err.msg() }
	os.write_file(os.join_path(skill_src, 'scripts', 'analyze.py'), 'print("ok")\n') or { assert false, err.msg() }
	os.write_file(os.join_path(skill_src, 'scripts', 'uv.lock'), 'version = 1\n') or { assert false, err.msg() }
	os.write_file(os.join_path(plugin_skill, 'SKILL.md'), skill) or { assert false, err.msg() }
	os.write_file(os.join_path(plugin_skill, 'scripts', 'analyze.py'), 'print("ok")\n') or { assert false, err.msg() }
	os.write_file(os.join_path(plugin_skill, 'scripts', 'uv.lock'), 'version = 1\n') or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'), 'products:\n  - id: agent-toolkit-creative-studio\n    includes:\n      skills:\n        - design/brag\n      agents: []\n') or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	os.setenv('AGENT_TOOLKIT_ROOT', root, true)
	defer {
		os.unsetenv('AGENT_TOOLKIT_ROOT')
	}
	matching := run_build(BuildOptions{
		check:   true
		target:  'agent-plugins'
		product: 'agent-toolkit-creative-studio'
	})
	assert matching.ok, matching.message
	assert matching.drift.len == 0
	os.rm(os.join_path(plugin_skill, 'scripts', 'uv.lock')) or { assert false, err.msg() }
	drifted := run_build(BuildOptions{
		check:   true
		target:  'agent-plugins'
		product: 'agent-toolkit-creative-studio'
	})
	assert !drifted.ok
	assert drifted.drift.any(it.contains('scripts/uv.lock')), drifted.message
	os.write_file(os.join_path(plugin_skill, 'scripts', 'uv.lock'), 'version = 1\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(plugin_skill, 'scripts', 'undeclared.txt'), 'extra\n') or {
		assert false, err.msg()
	}
	extra := run_build(BuildOptions{
		check:   true
		target:  'agent-plugins'
		product: 'agent-toolkit-creative-studio'
	})
	assert !extra.ok
	assert extra.drift.any(it.contains('unexpected in plugins: skills/brag/scripts/undeclared.txt')), extra.message
	os.rm(os.join_path(plugin_skill, 'scripts', 'undeclared.txt')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(plugin_skill, '.metadata')) or { assert false, err.msg() }
	os.write_file(os.join_path(plugin_skill, '.metadata', 'unexpected.txt'), 'extra\n') or {
		assert false, err.msg()
	}
	hidden_extra := run_build(BuildOptions{
		check:   true
		target:  'agent-plugins'
		product: 'agent-toolkit-creative-studio'
	})
	assert !hidden_extra.ok
	assert hidden_extra.drift.any(it.contains('unexpected in plugins: skills/brag/.metadata/unexpected.txt')), hidden_extra.message
	os.rmdir_all(os.join_path(root, 'plugins', 'agent-toolkit-creative-studio')) or {
		assert false, err.msg()
	}
	missing_product := run_build(BuildOptions{
		check:   true
		target:  'agent-plugins'
		product: 'agent-toolkit-creative-studio'
	})
	assert !missing_product.ok
	assert missing_product.drift.any(it.contains('missing plugin product: agent-toolkit-creative-studio')), missing_product.message
}

fn test_skill_tree_drift_includes_hidden_files() {
	root := os.join_path(os.temp_dir(), 'at-hidden-skill-drift-${os.getpid()}')
	work_skills := os.join_path(root, 'work', 'skills')
	plugin_skills := os.join_path(root, 'plugin', 'skills')
	os.mkdir_all(os.join_path(work_skills, 'brag', '.metadata')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(plugin_skills, 'brag', '.metadata')) or { assert false, err.msg() }
	os.write_file(os.join_path(work_skills, 'brag', '.metadata', 'source.txt'), 'source\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(plugin_skills, 'brag', '.metadata', 'source.txt'), 'stale\n') or {
		assert false, err.msg()
	}
	drift := skill_tree_drift(work_skills, plugin_skills)
	assert drift.any(it.contains('content digest mismatch: skills/brag/.metadata/source.txt')), drift.str()
	defer {
		os.rmdir_all(root) or {}
	}
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
	assert report.message.contains('unknown emit target'), report.message
}
