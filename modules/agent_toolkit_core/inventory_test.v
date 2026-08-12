module agent_toolkit_core

import os

fn test_load_inventory_at_temp_tree() {
	root := os.join_path(os.temp_dir(), 'at-inv-${os.getpid()}')
	os.mkdir_all(os.join_path(root, 'skills', 'core', 'assistant')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'skills', 'forge', 'github-cli-workflow')) or {
		assert false, err.msg()
	}
	os.mkdir_all(os.join_path(root, 'agents', 'code-reviewer')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(root, 'distributions')) or { assert false, err.msg() }
	os.write_file(os.join_path(root, 'skills', 'core', 'assistant', 'SKILL.md'), '# x\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'skills', 'forge', 'github-cli-workflow', 'SKILL.md'), '# x\n') or {
		assert false, err.msg()
	}
	os.write_file(os.join_path(root, 'distributions', 'products.yaml'),
		'products:\n  - id: agent-toolkit-core\n    name: Core\n') or { assert false, err.msg() }
	defer {
		os.rmdir_all(root) or {}
	}
	snap := load_inventory_at(root) or {
		assert false, err.msg()
		return
	}
	assert snap.skill_count == 2
	assert snap.agent_count == 1
	assert snap.product_count == 1
	assert snap.domain_count == 2
	assert snap.message.contains('Skills: 2 across 2 domains')
	assert snap.message.contains('Agents: 1')
	assert snap.message.contains('agent-toolkit-core')
	r := inventory_result(snap)
	assert r.ok
	assert r.data['skills_count'] == '2'
	assert r.data['products_count'] == '1'
}

fn test_lookup_checkout_root_env() {
	dir := os.join_path(os.temp_dir(), 'at-inv-env-${os.getpid()}')
	os.mkdir_all(os.join_path(dir, 'skills')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(dir) or {}
	}
	old := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', dir, true)
	defer {
		restore_env_inv('AGENT_TOOLKIT_ROOT', old)
	}
	assert lookup_checkout_root() == dir
}

fn restore_env_inv(key string, old string) {
	if old.len > 0 {
		os.setenv(key, old, true)
	} else {
		os.unsetenv(key)
	}
}
