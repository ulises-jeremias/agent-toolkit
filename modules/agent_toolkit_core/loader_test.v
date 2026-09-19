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

fn write_agent_fixture(root string, name string, body string) {
	dir := os.join_path(root, name)
	os.mkdir_all(dir) or { assert false, err.msg() }
	os.write_file(os.join_path(dir, 'AGENT.md'), body) or { assert false, err.msg() }
}

fn temp_agents_root() string {
	root := os.join_path(os.temp_dir(), 'at-agents-${os.getpid()}')
	os.mkdir_all(root) or { assert false, err.msg() }
	return root
}

fn test_load_agent_tools_mapping_and_read_only() {
	root := temp_agents_root()
	defer {
		os.rmdir_all(root) or {}
	}
	write_agent_fixture(root, 'reader', '---\nname: reader\ndescription: reads\ntools: Read, Grep, Glob\n---\nBody.\n')
	write_agent_fixture(root, 'writer', '---\nname: writer\ndescription: writes\ntools: Read, Grep, Glob, Bash\n---\nBody.\n')
	agents, errs := load_agent_ids(root)
	assert errs.len == 0, errs.str()
	// Grep+Glob dedup to one fs.search, order preserved
	assert agents['reader'].allowed_tools == ['fs.read', 'fs.search']
	assert agents['reader'].read_only == true
	assert agents['writer'].allowed_tools == ['fs.read', 'fs.search', 'shell.execute']
	assert agents['writer'].read_only == false
	assert agents['reader'].description == 'reads'
}

fn test_load_agent_unknown_tool_fails_closed() {
	root := temp_agents_root()
	defer {
		os.rmdir_all(root) or {}
	}
	write_agent_fixture(root, 'demo', '---\nname: demo\ndescription: demo\ntools: Read, Frobnicate\n---\nBody.\n')
	agents, errs := load_agent_ids(root)
	assert errs.len == 1, errs.str()
	assert errs[0].contains('unknown Claude tool(s)')
	assert errs[0].contains('Frobnicate')
	assert 'demo' !in agents
}

fn test_load_agent_allowed_denied_overlap_fails_closed() {
	root := temp_agents_root()
	defer {
		os.rmdir_all(root) or {}
	}
	write_agent_fixture(root, 'demo', '---\nname: demo\ndescription: demo\nallowed_tools: fs.read\ndenied_tools: fs.read\n---\nBody.\n')
	agents, errs := load_agent_ids(root)
	assert errs.len == 1, errs.str()
	assert errs[0].contains('allowed_tools and denied_tools')
	assert 'demo' !in agents
}

fn test_load_agent_explicit_allowed_wins_and_read_only_override() {
	root := temp_agents_root()
	defer {
		os.rmdir_all(root) or {}
	}
	// explicit allowed_tools wins over the `tools` Claude list
	write_agent_fixture(root, 'strict', '---\nname: strict\ndescription: s\ntools: Read, Bash\nallowed_tools: fs.read\ndenied_tools: shell.execute\nread_only: false\n---\nBody.\n')
	agents, errs := load_agent_ids(root)
	assert errs.len == 0, errs.str()
	assert agents['strict'].allowed_tools == ['fs.read']
	assert agents['strict'].denied_tools == ['shell.execute']
	assert agents['strict'].read_only == false
}

fn test_load_agent_delegates_to_validated() {
	root := temp_agents_root()
	defer {
		os.rmdir_all(root) or {}
	}
	write_agent_fixture(root, 'boss', '---\nname: boss\ndescription: b\ntools: Read\ndelegates_to: worker\n---\nBody.\n')
	write_agent_fixture(root, 'worker', '---\nname: worker\ndescription: w\ntools: Read\n---\nBody.\n')
	write_agent_fixture(root, 'loner', '---\nname: loner\ndescription: l\ntools: Read\ndelegates_to: ghost\n---\nBody.\n')
	write_agent_fixture(root, 'selfish', '---\nname: selfish\ndescription: s\ntools: Read\ndelegates_to: selfish\n---\nBody.\n')
	agents, errs := load_agent_ids(root)
	assert errs.len == 2, errs.str()
	assert 'boss' in agents
	assert agents['boss'].delegates_to == ['worker']
	assert 'worker' in agents
	assert 'loner' !in agents
	assert 'selfish' !in agents
}

fn test_load_agent_no_frontmatter_loads_empty() {
	root := temp_agents_root()
	defer {
		os.rmdir_all(root) or {}
	}
	write_agent_fixture(root, 'plain', '# no frontmatter\n')
	agents, errs := load_agent_ids(root)
	assert errs.len == 0, errs.str()
	assert 'plain' in agents
	assert agents['plain'].allowed_tools.len == 0
	assert agents['plain'].read_only == false
}

fn test_load_real_agents_map_cleanly_if_checkout() {
	root := find_repo_root() or { return }
	agents, errs := load_agent_ids(os.join_path(root, 'agents'))
	assert errs.len == 0, errs.str()
	assert agents.len >= 15
	cr := agents['code-reviewer']
	assert cr.allowed_tools == ['fs.read', 'fs.search', 'shell.execute']
	assert cr.read_only == false
}
