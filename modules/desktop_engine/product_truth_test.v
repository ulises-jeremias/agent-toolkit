module desktop_engine

import os
import agent_toolkit_core

// Product truth: the desktop GUI renders every user-visible count through
// Engine-derived helpers. This test locks the catalog side of that contract.
fn test_product_truth_catalog_counts() {
	// Pin the resolver to this checkout so the test exercises packaged source data,
	// not a developer's ambient XDG installation.
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_override := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer {
		os.setenv('AGENT_TOOLKIT_ROOT', prev_override, true)
	}
	tmp := os.join_path(os.temp_dir(), 'product-truth-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	skills := eng.skills_catalog()
	assert skills.len == 116, 'skills catalog must contain the source entries: got ${skills.len}'
	for skill in skills {
		assert !skill.description.to_lower().contains('synthetic')
		assert skill.id.contains('/')
	}
	if _ := eng.remove_skill('missing-skill') {
		assert false, 'removing an unknown skill must not create receipt state'
	} else {
		assert err.msg().contains('skill not installed')
	}
	assert eng.skills_domains().len == 14, 'skills domains must be 14'

	stats := eng.agents_stats()
	assert stats.total - stats.archived == 18, 'active agents must be 18: got ${stats.total - stats.archived}'
	assert stats.holistic == 10, 'holistic agents must be 10: got ${stats.holistic}'
	assert stats.orchestrator == 2, 'orchestrator agents must be 2: got ${stats.orchestrator}'
	assert stats.specialist == 6, 'specialist agents must be 6: got ${stats.specialist}'
	assert stats.archived == 0, 'archived agents must come from a real catalog: got ${stats.archived}'
	for agent in eng.agents_catalog() {
		assert !agent.id.starts_with('old-agent-')
		assert agent.provenance != 'synthetic'
	}
	if _ := eng.remove_agent('missing-agent') {
		assert false, 'removing an unknown agent must not create receipt state'
	} else {
		assert err.msg().contains('agent not installed')
	}

	mcp := eng.mcp_catalog()
	assert mcp.len == 7, 'MCP providers must be 7'
	for provider in mcp {
		assert !provider.enabled, 'fresh MCP catalog must not claim ${provider.id} is enabled'
		assert provider.version == '', 'MCP version requires source evidence'
	}
	if _ := eng.remove_mcp_provider('github') {
		assert false, 'removing an unconfigured MCP must not create receipt state'
	} else {
		assert err.msg().contains('not enabled')
	}

	tgts := eng.targets()
	assert tgts.len == agent_toolkit_core.all_emit_targets().len, 'targets must match emitter catalog: got ${tgts.len}'
	ids := tgts.map(it.id)
	for want in agent_toolkit_core.all_emit_targets() {
		assert want in ids, 'target ${want} missing from Engine catalog: ${ids}'
	}
	if _ := eng.set_target_enabled('missing-target', true) {
		assert false, 'unknown targets must not create persisted state'
	} else {
		assert err.msg().contains('unsupported target')
	}
	if _ := eng.onboarding_set_targets_bulk(['missing-target']) {
		assert false, 'bulk onboarding must validate target IDs'
	} else {
		assert err.msg().contains('unsupported target')
	}

	products := eng.products_catalog()
	assert products.len == 5, 'products must be 5'
	assert products[0].skill_ids.len > 0, 'product membership must come from products.yaml'
	assert products[0].skill_ids.len < skills.len, 'product membership must not claim the whole catalog'
	if _ := eng.update_product_membership('missing-product', []) {
		assert false, 'unknown products must not create persisted state'
	} else {
		assert err.msg().contains('product not found')
	}
	if _ := eng.onboarding_set_products_bulk(['missing-product']) {
		assert false, 'bulk onboarding must validate product IDs'
	} else {
		assert err.msg().contains('product not found')
	}
	assert eng.packs_catalog().len == 7, 'packs must be 7'
	if _ := eng.set_pack_enabled('missing-pack', true) {
		assert false, 'unknown packs must not create persisted state'
	} else {
		assert err.msg().contains('pack not found')
	}
	assert eng.receipts_catalog().len == 0, 'a fresh engine must not invent receipts'
	assert eng.api_call_count() > 0
}
