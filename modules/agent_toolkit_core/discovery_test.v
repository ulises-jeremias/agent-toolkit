module agent_toolkit_core

import os

fn test_list_agents_at_reads_frontmatter() {
	dir := os.join_path(os.temp_dir(), 'atk-agents-' + os.getpid().str())
	os.mkdir_all(os.join_path(dir, 'agents', 'architect')) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'agents', 'architect', 'AGENT.md'), '---\nname: architect\nkind: holistic\ndescription: Designs systems.\n---\n\nbody\n') or {
		panic(err.msg())
	}
	os.mkdir_all(os.join_path(dir, 'agents', 'empty')) or { panic(err.msg()) }
	got := list_agents_at(dir)
	assert got.len == 1
	assert got[0].id == 'architect'
	assert got[0].name == 'architect'
	assert got[0].kind == 'holistic'
	assert got[0].description == 'Designs systems.'
	assert got[0].source_file == 'agents/architect/AGENT.md'
}

fn test_list_agents_at_reads_delegates_list() {
	dir := os.join_path(os.temp_dir(), 'atk-agents-delegates-' + os.getpid().str())
	os.mkdir_all(os.join_path(dir, 'agents', 'assistant')) or { panic(err.msg()) }
	os.mkdir_all(os.join_path(dir, 'agents', 'worker')) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'agents', 'assistant', 'AGENT.md'), '---\nname: assistant\nkind: orchestrator\ndescription: Routes work.\ndelegates:\n  - architect\n  - worker\ncollaborates_with:\n  - planner\n---\n\nbody\n') or {
		panic(err.msg())
	}
	os.write_file(os.join_path(dir, 'agents', 'worker', 'AGENT.md'), '---\nname: worker\ndescription: Does work.\ndelegates: [reviewer]\n---\n\nbody\n') or {
		panic(err.msg())
	}
	got := list_agents_at(dir)
	assert got.len == 2
	assert got[0].id == 'assistant'
	assert got[0].delegates == ['architect', 'worker']
	assert got[1].id == 'worker'
	assert got[1].delegates == ['reviewer']
}

fn test_list_agents_at_declares_native_custom_agent_target_compatibility() {
	dir := os.join_path(os.temp_dir(), 'atk-agents-compat-' + os.getpid().str())
	os.mkdir_all(os.join_path(dir, 'agents', 'architect')) or { panic(err.msg()) }
	os.mkdir_all(os.join_path(dir, 'capabilities', 'targets')) or { panic(err.msg()) }
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'agents', 'architect', 'AGENT.md'), '---\nname: architect\nkind: holistic\ndescription: Designs systems.\n---\n\nbody\n') or {
		panic(err.msg())
	}
	registry := 'targets:\n  - id: claude-code\n    display_name: Claude Code\n    capabilities:\n      agent_skills: true\n      native_custom_agents: true\n  - id: legacy\n    display_name: Legacy\n    capabilities:\n      agent_skills: false\n      native_custom_agents: partial\n'
	os.write_file(os.join_path(dir, 'capabilities', 'targets', 'registry.yaml'), registry) or {
		panic(err.msg())
	}
	got := list_agents_at(dir)
	assert got.len == 1
	assert got[0].compatibility.len == 2
	assert got[0].compatibility[0].target == 'claude-code'
	assert got[0].compatibility[0].status == 'supported'
	assert got[0].compatibility[1].target == 'legacy'
	assert got[0].compatibility[1].status == 'partial'
}

fn test_list_agents_from_embedded_root() {
	agents := list_agents_at('embedded')
	assert agents.len >= 18
	assert agents.any(it.id == 'architect')
}

fn test_probe_coding_tool_unknown_id_is_empty() {
	t := probe_coding_tool('not-a-tool')
	assert t.id == 'not-a-tool'
	assert t.tool_name == ''
	assert !t.detected
	assert !t.configured
	assert t.enabled == 'unknown'
	assert !t.verified
	assert t.install_hint == ''
	assert t.reason == 'no user-level runtime to detect'
}

fn test_list_coding_tools_covers_canonical_ids() {
	tools := list_coding_tools()
	ids := tools.map(it.id)
	assert ids == ['claude-code', 'cursor', 'opencode', 'windsurf', 'pi', 'muse-code', 'gemini-cli',
		'copilot-cli', 'codex']
	for t in tools {
		assert t.enabled == 'unknown'
		assert t.install_hint == ''
	}
}

fn test_list_providers_skips_auto_and_keeps_skeleton() {
	providers := list_providers()
	ids := providers.map(it.id)
	assert 'auto' !in ids
	assert 'skeleton' in ids
	skel := providers.filter(it.id == 'skeleton')[0]
	assert skel.available
	assert skel.bin == ''
	assert skel.capability == 'official'
}

fn test_list_models_flattens_swarm_profiles() {
	models := list_models()
	assert models.len > 0
	profiles := models.map(it.profile)
	assert 'balanced' in profiles
	assert 'economy' in profiles
	for m in models {
		assert m.runner.len > 0
		assert m.model.len > 0
	}
}

fn test_freeze_hides_path_and_config() {
	os.setenv('ATK_GUI_FREEZE', '1', true)
	defer {
		os.unsetenv('ATK_GUI_FREEZE')
	}
	t := probe_coding_tool('claude-code')
	assert t.tool_name == 'claude'
	assert !t.detected
	assert !t.configured
	assert t.resolved_path == ''
	assert t.config_paths.len == 0
}
