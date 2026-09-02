module agent_toolkit_core

import os

fn test_remaining_targets_cover_issue_552() {
	ids := remaining_targets()
	for need in ['copilot-cli', 'copilot-repository', 'windsurf', 'pi', 'gemini-cli', 'muse-code',
		'codex', 'agent-plugins'] {
		assert need in ids, need
	}
	assert normalize_emit_target('gemini') == 'gemini-cli'
	assert normalize_emit_target('muse') == 'muse-code'
	assert normalize_emit_target('copilot') == 'copilot-cli'
	assert is_known_emit_target('gemini')
	assert is_known_emit_target('muse')
}

fn test_compile_remaining_families_temp() {
	root := os.join_path(os.temp_dir(), 'at-remain-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'agents', 'code-reviewer')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), 'skill\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'agents', 'code-reviewer', 'AGENT.md'), 'agent\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'), 'products:\n  - id: demo\n    name: Demo\n    description: Demo product\n    includes:\n      skills:\n        - core/assistant\n      agents:\n        - code-reviewer\n') or {
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

	ws := compile_target('windsurf', g, product, out, root)
	assert ws.is_valid(), ws.errors.str()
	assert os.is_file(os.join_path(out, 'demo', 'AGENTS.md'))
	assert os.is_file(os.join_path(out, 'demo', 'rules', 'code-reviewer.mdc'))

	pi := compile_target('pi', g, product, out, root)
	assert pi.is_valid(), pi.errors.str()
	assert os.is_file(os.join_path(out, 'demo', 'pi-package.json'))

	gem := compile_target('gemini', g, product, out, root)
	assert gem.is_valid(), gem.errors.str()
	assert os.is_file(os.join_path(out, 'demo', 'gemini-extension.json'))
	assert os.is_file(os.join_path(out, 'demo', 'commands.toml'))

	muse := compile_target('muse', g, product, out, root)
	assert muse.is_valid(), muse.errors.str()
	assert os.is_file(os.join_path(out, 'demo', 'skills', 'assistant', 'SKILL.md'))

	codex := compile_target('codex', g, product, out, root)
	assert codex.is_valid(), codex.errors.str()
	assert os.is_file(os.join_path(out, 'demo', '.codex-plugin', 'plugin.json'))
	assert codex.warnings.len >= 1

	ap := compile_target('agent-plugins', g, product, out, root)
	assert ap.is_valid(), ap.errors.str()
	raw := os.read_file(os.join_path(out, 'demo', 'plugin.json')) or {
		assert false, err.msg()
		return
	}
	assert raw.contains('agent-plugins.org/schemas')
}
