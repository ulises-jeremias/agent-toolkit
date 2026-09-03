module desktop_engine

import os

// R2 product-truth: the desktop GUI renders every user-visible count through
// Engine-derived helpers (cmd/agent-toolkit-desktop/main.v: skills_total,
// agents_active_total, agents_tier_summary, mcp_total, targets_total,
// products_total, packs_total). This test locks the catalog side of that
// contract — when a catalog legitimately grows, update the GUI fallbacks and
// this test together.
fn test_product_truth_catalog_counts() {
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
	assert skills.len == 227, 'skills catalog must be 227 (116 real + synthetic pad): got ${skills.len}'
	assert eng.skills_domains().len == 14, 'skills domains must be 14'

	stats := eng.agents_stats()
	assert stats.total - stats.archived == 18, 'active agents must be 18: got ${stats.total - stats.archived}'
	assert stats.holistic == 10, 'holistic agents must be 10: got ${stats.holistic}'
	assert stats.orchestrator == 2, 'orchestrator agents must be 2: got ${stats.orchestrator}'
	assert stats.specialist == 6, 'specialist agents must be 6: got ${stats.specialist}'
	assert stats.archived == 7, 'archived agents must be 7: got ${stats.archived}'

	assert eng.mcp_catalog().len == 7, 'MCP providers must be 7'

	tgts := eng.targets()
	assert tgts.len == 7, 'targets must be 7: got ${tgts.len}'
	ids := tgts.map(it.id)
	for want in ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf', 'cursor-plugins', 'cli'] {
		assert want in ids, 'target ${want} missing from Engine catalog: ${ids}'
	}

	assert eng.products_catalog().len == 5, 'products must be 5'
	assert eng.packs_catalog().len == 7, 'packs must be 7'
	assert eng.api_call_count() > 0
}
