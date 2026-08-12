module agent_toolkit_core

import os

fn test_remaining_targets_include_copilot() {
	ids := remaining_targets()
	assert 'copilot-cli' in ids
	assert 'copilot-repository' in ids
	assert is_known_emit_target('copilot-cli')
	assert !is_known_emit_target('muse-code')
}

fn test_compile_copilot_cli_and_repo() {
	root := os.join_path(os.temp_dir(), 'at-copilot-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'agents', 'code-reviewer')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), 'skill\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'agents', 'code-reviewer', 'AGENT.md'), 'agent\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'),
		'products:\n  - id: demo\n    name: Demo\n    description: Demo product\n    includes:\n      skills:\n        - core/assistant\n      agents:\n        - code-reviewer\n') or {
		assert false, err.msg()
	}
	defer {
		os.rmdir_all(root) or {}
	}
	g := load_graph(root)
	product := g.select_product('demo') or {
		assert false, 'missing'
		return
	}
	out := os.join_path(root, 'out')
	cli := compile_target('copilot-cli', g, product, out, root)
	assert cli.is_valid(), cli.errors.str()
	assert os.is_file(os.join_path(out, 'demo', 'plugin.json'))
	assert os.is_file(os.join_path(out, 'demo', 'skills', 'assistant', 'SKILL.md'))
	assert os.is_file(os.join_path(out, 'demo', 'agents', 'code-reviewer.agent.md'))
	repo := compile_target('copilot-repository', g, product, out, root)
	assert repo.is_valid(), repo.errors.str()
	assert os.is_file(os.join_path(out, 'demo', '.github', 'copilot-instructions.md'))
	assert os.is_file(os.join_path(out, 'demo', '.github', 'skills', 'assistant', 'SKILL.md'))
	assert os.is_file(os.join_path(out, 'demo', '.github', 'agents', 'code-reviewer.agent.md'))
}
