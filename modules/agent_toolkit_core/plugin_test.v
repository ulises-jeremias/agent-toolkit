module agent_toolkit_core

import os

fn test_plugin_check_drift_then_sync() {
	base := os.join_path(os.temp_dir(), 'at-plugin-${os.getpid()}')
	src_skill := os.join_path(base, 'skills', 'core', 'assistant')
	dst_skill := os.join_path(base, 'plugins', 'agent-toolkit-core', 'skills', 'assistant')
	os.mkdir_all(src_skill) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'plugins', 'agent-toolkit-core')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'plugins', 'agent-toolkit-agents')) or { assert false, err.msg() }
	os.mkdir_all(os.join_path(base, 'plugins', 'agent-toolkit-forge')) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(src_skill, 'SKILL.md'), '---\nname: assistant\ndescription: x\n---\n') or {
		assert false, err.msg()
		return
	}
	check := run_plugin(PluginOptions{
		subcommand: 'check'
		toolkit_root: base
	})
	assert !check.ok
	assert check.drift > 0
	assert check.message.contains('DRIFT')

	sync := run_plugin(PluginOptions{
		subcommand: 'sync'
		toolkit_root: base
	})
	assert sync.ok
	assert os.is_file(os.join_path(dst_skill, 'SKILL.md'))

	again := run_plugin(PluginOptions{
		subcommand: 'check'
		toolkit_root: base
	})
	assert again.ok
	assert again.drift == 0
}

fn test_plugin_unknown_subcommand() {
	r := run_plugin(PluginOptions{
		subcommand: 'explode'
	})
	assert !r.ok
}
