module agent_toolkit_core

import os

fn test_load_products_file_temp() {
	dir := os.join_path(os.temp_dir(), 'at-loader-${os.getpid()}')
	os.mkdir_all(dir) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'products.yaml')
	os.write_file(path, 'products:\n  - id: agent-toolkit-core\n    name: Core\n    stability: stable\n    includes:\n      skills:\n        - core/assistant\n      agents:\n        - code-reviewer\n') or {
		assert false, err.msg()
	}
	products, errs := load_products_file(path)
	assert errs.len == 0
	assert products.len == 1
	assert products[0].id == 'agent-toolkit-core'
	assert products[0].included_skills == ['core/assistant']
	assert products[0].included_agents == ['code-reviewer']
}

fn test_load_graph_selects_product() {
	root := os.join_path(os.temp_dir(), 'at-graph-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'agents', 'code-reviewer')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), '---\nname: assistant\n---\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'agents', 'code-reviewer', 'AGENT.md'), '# a\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'), 'products:\n  - id: agent-toolkit-core\n    includes:\n      skills:\n        - core/assistant\n        - missing/skill\n      agents:\n        - code-reviewer\n') or {
		assert false, err.msg()
	}
	defer {
		os.rmdir_all(root) or {}
	}
	g := load_graph(root)
	assert g.is_valid()
	assert 'core/assistant' in g.skills
	assert 'code-reviewer' in g.agents
	p := g.select_product('agent-toolkit-core') or {
		assert false, 'missing product'
		return
	}
	assert p.included_skills.len == 2
	assert g.warnings.len >= 1
	assert g.select_product('nope') == none
}

fn test_load_graph_missing_products_yaml() {
	root := os.join_path(os.temp_dir(), 'at-graph-miss-${os.getpid()}')
	os.mkdir_all(root) or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	g := load_graph(root)
	assert !g.is_valid()
	assert g.errors.len >= 1
}

fn test_load_real_products_yaml_if_checkout() {
	root := find_repo_root() or { return }
	path := os.join_path(root, 'distributions', 'products.yaml')
	if !os.is_file(path) {
		return
	}
	products, errs := load_products_file(path)
	assert errs.len == 0, errs.str()
	assert products.len >= 3
	mut ids := []string{}
	for p in products {
		ids << p.id
	}
	assert 'agent-toolkit-core' in ids
	g := load_graph(root)
	assert g.is_valid()
	core := g.select_product('agent-toolkit-core') or {
		assert false, 'core product missing'
		return
	}
	assert core.included_skills.len > 0
}
