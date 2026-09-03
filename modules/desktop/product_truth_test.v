module desktop

import os

// R2 product-truth: the GUI target roster and counts render from this proxy
// (draw_targets, targets_total, onboarding enable-all) instead of a hardcoded
// platform list — the old GUI list drifted (copilot/muse-code vs
// cursor-plugins/cli). Locks the proxy to the Engine catalog.
fn test_desktop_engine_targets_proxy_matches_engine_catalog() {
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
	assert tgts.len == 7, 'engine_targets proxy must expose 7: got ${tgts.len}'
	ids := tgts.map(it.id)
	for want in ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf', 'cursor-plugins', 'cli'] {
		assert want in ids, 'target ${want} missing from proxy: ${ids}'
	}
	assert d.engine_api_calls() > 0
}
