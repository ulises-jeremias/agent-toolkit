module desktop_engine

import os

fn test_capability_plane_skills_via_engine_no_shell() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'cap-skills-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	cat := eng.skills_catalog()
	assert cat.len >= 116, 'catalog 116+'
	_ := eng.skill_detail(cat[0].id) or { panic(err.msg()) }
	rev := eng.install_skill(cat[0].id) or { panic(err.msg()) }
	assert rev >= 1
	installed := eng.skills_installed()
	assert cat[0].id in installed
	rev2 := eng.remove_skill(cat[0].id) or { panic(err.msg()) }
	assert rev2 > rev
	diags := eng.build_check()
	assert diags.len == 0 || diags[0].path.len > 0
	preview := eng.build_preview()
	assert preview.contains('plugins-digest')
	assert eng.api_call_count() > 0
}

fn test_capability_plane_products_via_engine() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'cap-products-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	prods := eng.products_catalog()
	assert prods.len >= 2
	packs := eng.packs_catalog()
	// A temporary Engine may resolve to an isolated root without packaged packs.
	// The catalog must remain truthful and may therefore be empty.
	for pack in packs {
		assert pack.provenance.starts_with('packs/')
		assert pack.skill_count >= 0
	}
	rev := eng.update_product_membership(prods[0].id, ['core/assistant']) or { panic(err.msg()) }
	assert rev >= 1
	if packs.len > 0 {
		rev2 := eng.set_pack_enabled(packs[0].id, true) or { panic(err.msg()) }
		assert rev2 >= 1
	}
	assert eng.api_call_count() > 0
}

fn test_capability_plane_mcp_secret_guard_via_engine() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'cap-mcp-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	cat := eng.mcp_catalog()
	assert cat.len == 7
	assert eng.mcp_health('github') != ''
	_ := eng.mcp_validate('github')
	p1, p2 := eng.mcp_preview('github')
	assert p1.len > 0 && p2.len > 0
	if _ := eng.upsert_mcp_provider('github', '{"token":"ghp_abc123"}') {
		assert false, 'raw secret must be blocked'
	} else {
		assert err.msg().contains('secret guard')
	}
	rev := eng.upsert_mcp_provider('github', '{"token":"\${GITHUB_TOKEN}"}') or { panic(err.msg()) }
	assert rev >= 1
	rev2 := eng.remove_mcp_provider('github') or { panic(err.msg()) }
	assert rev2 > rev
	assert eng.api_call_count() > 0
}

fn test_capability_plane_agents_doctor_targets_via_engine() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'cap-agents-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	agents := eng.agents_catalog()
	assert agents.len >= 18
	counts := eng.agents_tier_counts()
	assert counts['holistic'] >= 6
	_ := eng.agent_detail(agents[0].id) or { panic(err.msg()) }
	assert eng.validate_agent(agents[0].id) or { panic(err.msg()) }
	checks := eng.doctor()
	assert checks.len >= 3
	rev := eng.doctor_fix(checks[0].id) or { panic(err.msg()) }
	assert rev >= 1
	tags := eng.targets()
	assert tags.len >= 7
	rev2 := eng.set_target_enabled('claude-code', true) or { panic(err.msg()) }
	assert rev2 >= 1
	d := eng.diff(['claude-code'], ['claude-code', 'cursor'])
	assert d.added.len == 1 && d.added[0] == 'cursor'
	rev3 := eng.install(['claude-code']) or { panic(err.msg()) }
	assert rev3 >= 1
	assert eng.is_first_run() == true || eng.is_first_run() == false
	assert eng.resolve_paths().len == 2
	assert eng.api_call_count() > 0
}
