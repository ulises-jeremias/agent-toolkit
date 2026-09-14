module desktop

import os

// Library install lifecycle facade (slice C): honesty-state vocabulary and
// Engine-backed lifecycle with failure/recovery and never-claims-installed.

fn test_library_install_state_labels_never_claim_installed() {
	assert library_install_state_label(.unavailable) == 'unavailable'
	assert library_install_state_label(.available) == 'available'
	assert library_install_state_label(.configured) == 'configured'
	assert library_install_state_label(.verified) == 'verified'
	for s in [LibraryInstallState.unavailable, .available, .configured, .verified] {
		assert library_install_state_label(s) != 'installed', 'no state may claim installed without receipt evidence'
	}
}

fn new_library_facade_test_desktop(suffix string) (string, &Desktop) {
	tmp := os.join_path(os.temp_dir(), 'facade-library-${suffix}-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	cfg := DesktopConfig{
		title: 'Library Facade Test'
		width: 1280
		height: 800
		headless: true
	}
	cfg.validate() or { panic(err.msg()) }
	mut d := new_desktop(DesktopBootArgs{
		config: cfg
		persist_path: os.join_path(tmp, 'state.json')
	})
	d.boot() or { panic(err.msg()) }
	return tmp, d
}

fn test_library_agent_lifecycle_unknown_is_unavailable() {
	tmp, mut d := new_library_facade_test_desktop('unknown')
	defer {
		d.shutdown() or {}
		os.rmdir_all(tmp) or {}
	}
	lc := d.library_agent_lifecycle('definitely-not-an-agent-xyz')
	assert lc.state == .unavailable
	assert lc.display == 'unavailable'
	assert !lc.validate_ok
	assert lc.validate_err != '', 'unavailable must carry the Engine error for recovery'
	assert d.library_agent_preview('definitely-not-an-agent-xyz').starts_with('cannot preview:')
}

fn test_library_agent_install_is_configured_never_verified() {
	tmp, mut d := new_library_facade_test_desktop('select')
	defer {
		d.shutdown() or {}
		os.rmdir_all(tmp) or {}
	}
	cat := d.engine.agents_catalog()
	if cat.len == 0 {
		return
	}
	id := cat[0].id
	before := d.library_agent_lifecycle(id)
	assert before.state == .available, 'fresh engine must show ${id} as available'
	preview := d.library_agent_preview(id)
	assert preview.contains('agents:installed:${id}=true'), 'preview must state the exact flag: ${preview}'
	rev := d.engine_install_agent(id) or { panic(err.msg()) }
	assert rev > 0
	after := d.library_agent_lifecycle(id)
	if after.state == .verified {
		assert after.receipt_path != '', 'verified must carry receipt evidence'
	} else {
		assert after.state == .configured, 'selection without receipt is configured, got ${after.display}'
		assert after.display != 'installed'
		assert after.evidence.contains('no receipt yet'), 'configured must name the next step: ${after.evidence}'
	}
	assert id in d.engine_agents_configured()
	_ := d.engine_remove_agent(id) or { panic(err.msg()) }
	assert id !in d.engine_agents_configured()
}

fn test_library_mcp_stage_unknown_is_unknown() {
	tmp, mut d := new_library_facade_test_desktop('mcp')
	defer {
		d.shutdown() or {}
		os.rmdir_all(tmp) or {}
	}
	stage, evidence := d.library_mcp_stage('definitely-not-a-provider-xyz')
	assert stage == 'unknown'
	assert evidence == 'not in MCP catalog'
}

fn test_library_skill_stage_unknown_is_unavailable() {
	tmp, mut d := new_library_facade_test_desktop('skill')
	defer {
		d.shutdown() or {}
		os.rmdir_all(tmp) or {}
	}
	state, evidence := d.library_skill_stage('definitely-not-a-skill-xyz')
	assert state == .unavailable
	assert evidence.contains('not in skills catalog'), 'stage must carry evidence: ${evidence}'
}
