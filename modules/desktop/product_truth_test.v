module desktop

import os

// S7B target truth: the GUI target roster renders from this proxy — the
// Engine catalog derived from the canonical registry
// (capabilities/targets/registry.yaml). Locks the proxy to that roster and
// to honest no-default-enabled configuration.
fn test_desktop_engine_targets_proxy_matches_engine_catalog() {
	repo_root := os.dir(os.dir(os.dir(@FILE)))
	prev_root := os.getenv('AGENT_TOOLKIT_ROOT')
	os.setenv('AGENT_TOOLKIT_ROOT', repo_root, true)
	defer { os.setenv('AGENT_TOOLKIT_ROOT', prev_root, true) }
	tmp := os.join_path(os.temp_dir(), 'desktop-targets-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut d := new_desktop(DesktopBootArgs{
		config: DesktopConfig{
			title: 'Targets Truth'
			width: 1280
			height: 800
			headless: true
		}
		persist_path: os.join_path(tmp, 'state.json')
	})
	d.boot() or { panic(err.msg()) }
	defer { d.shutdown() or {} }
	tgts := d.engine_targets()
	assert tgts.len == 11, 'engine_targets proxy must expose the registry roster: got ${tgts.len}'
	ids := tgts.map(it.id)
	for want in ['claude-code', 'cursor', 'opencode', 'gemini-cli', 'copilot-cli', 'copilot-repository', 'pi', 'windsurf', 'codex', 'muse-code', 'agent-plugins'] {
		assert want in ids, 'registry target ${want} missing from proxy: ${ids}'
	}
	for t in tgts {
		assert !t.enabled, 'fresh config must not enable targets by default: ${t.id}'
	}
	assert d.engine_api_calls() > 0
}
