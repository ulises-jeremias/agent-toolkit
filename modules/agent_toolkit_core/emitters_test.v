module agent_toolkit_core

import os

fn test_tier1_targets_list() {
	ids := tier1_targets()
	assert 'cursor' in ids
	assert 'claude-code' in ids
	assert 'opencode' in ids
	assert is_tier1_target('cursor')
	assert !is_tier1_target('copilot')
}

fn test_compile_cursor_temp_product() {
	root := os.join_path(os.temp_dir(), 'at-emit-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'agents', 'code-reviewer')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'),
		'---\nname: assistant\n---\nbody\n') or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'agents', 'code-reviewer', 'AGENT.md'), '# agent\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'),
		'products:\n  - id: agent-toolkit-core\n    description: Core\n    includes:\n      skills:\n        - core/assistant\n      agents:\n        - code-reviewer\n') or {
		assert false, err.msg()
	}
	defer {
		os.rmdir_all(root) or {}
	}
	g := load_graph(root)
	assert g.is_valid()
	product := g.select_product('agent-toolkit-core') or {
		assert false, 'missing product'
		return
	}
	out := os.join_path(root, 'out')
	r := compile_tier1('cursor', g, product, out, root)
	assert r.is_valid(), r.errors.str()
	assert 'plugin-manifest' in r.emitted
	assert 'skill:core/assistant' in r.emitted
	assert 'agent:code-reviewer' in r.emitted
	assert 'provenance' in r.emitted
	assert os.is_file(os.join_path(out, 'agent-toolkit-core', '.cursor-plugin', 'plugin.json'))
	assert os.is_file(os.join_path(out, 'agent-toolkit-core', 'skills', 'assistant', 'SKILL.md'))
	assert os.is_file(os.join_path(out, 'agent-toolkit-core', 'agents', 'code-reviewer', 'AGENT.md'))
	assert os.is_file(os.join_path(out, 'agent-toolkit-core', '.provenance.json'))
}

fn test_compile_opencode_and_claude() {
	root := os.join_path(os.temp_dir(), 'at-emit2-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), 'x\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'),
		'products:\n  - id: demo\n    includes:\n      skills:\n        - core/assistant\n      agents: []\n') or {
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
	oc := compile_tier1('opencode', g, product, out, root)
	assert oc.is_valid(), oc.errors.str()
	assert os.is_file(os.join_path(out, 'demo', 'opencode.json'))
	assert os.is_file(os.join_path(out, 'demo', '.opencode', 'skills', 'assistant', 'SKILL.md'))
	cc := compile_tier1('claude-code', g, product, out, root)
	assert cc.is_valid(), cc.errors.str()
	assert os.is_file(os.join_path(out, 'demo', '.claude-plugin', 'plugin.json'))
}

fn test_compile_unknown_target() {
	g := CanonicalGraph{}
	p := LoadedProduct{
		id: 'x'
	}
	r := compile_tier1('copilot', g, p, '/tmp', '/tmp')
	assert !r.is_valid()
}

fn test_compile_real_core_if_checkout() {
	root := find_repo_root() or { return }
	g := load_graph(root)
	if !g.is_valid() {
		return
	}
	product := g.select_product('agent-toolkit-core') or { return }
	out := os.join_path(os.temp_dir(), 'at-emit-real-${os.getpid()}')
	defer {
		os.rmdir_all(out) or {}
	}
	r := compile_tier1('cursor', g, product, out, root)
	assert r.is_valid(), r.errors.str()
	assert r.emitted.len > 2
}
