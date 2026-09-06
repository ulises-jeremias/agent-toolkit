module desktop_engine

import os

// embedded_catalog_resolution ensures a clean machine (no AGENT_TOOLKIT_ROOT,
// no XDG data) still resolves bundled product catalogs from the embedded tier.
// This is the S1 catalog-truth acceptance test: catalog must not depend on a
// checkout or pre-installed data directory.
fn test_embedded_catalog_resolution_on_clean_machine() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	prev_data := os.getenv('XDG_DATA_HOME')
	prev_cache := os.getenv('XDG_CACHE_HOME')
	prev_home := os.getenv('HOME')
	clean_home := os.join_path(os.temp_dir(), 'atk-clean-home-${os.getpid()}')
	os.mkdir_all(os.join_path(clean_home, '.local', 'share')) or { panic(err.msg()) }
	os.setenv('AGENT_TOOLKIT_ROOT', '', true)
	os.setenv('XDG_DATA_HOME', os.join_path(clean_home, '.local', 'share'), true)
	os.setenv('XDG_CACHE_HOME', os.join_path(clean_home, '.cache'), true)
	os.setenv('HOME', clean_home, true)
	defer {
		os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true)
		os.setenv('XDG_DATA_HOME', prev_data, true)
		os.setenv('XDG_CACHE_HOME', prev_cache, true)
		os.setenv('HOME', prev_home, true)
		os.rmdir_all(clean_home) or {}
	}

	tmp := os.join_path(os.temp_dir(), 'atk-embedded-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }

	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }

	env := resolve_env()
	assert env.tier == 'embedded', 'clean machine must resolve to embedded tier, got ${env.tier}'
	assert eng.agents_catalog().len >= 18, 'agents catalog from embedded'
	assert eng.skills_catalog().len >= 116, 'skills catalog from embedded'
	assert eng.mcp_catalog().len == 7, 'MCP catalog from embedded'
	assert eng.packs_catalog().len == 7, 'packs catalog from embedded'
	assert eng.products_catalog().len >= 2, 'products catalog from embedded'
	assert eng.targets().len >= 7, 'targets catalog from embedded'
	assert eng.api_call_count() > 0
}
