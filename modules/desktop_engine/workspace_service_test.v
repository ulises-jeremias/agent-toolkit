module desktop_engine

import os

fn test_workspace_switch_persists_canonical_root_and_emits_event() {
	tmp := os.join_path(os.temp_dir(), 'desktop-workspace-switch-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	workspace := os.join_path(tmp, 'workspace')
	os.mkdir_all(os.join_path(workspace, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(workspace, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	os.write_file(os.join_path(workspace, 'knowledge', 'README.md'), '# Knowledge\n') or { panic(err.msg()) }
	plain_folder := os.join_path(tmp, 'plain-folder')
	os.mkdir_all(plain_folder) or { panic(err.msg()) }

	persist := os.join_path(tmp, 'state.json')
	mut eng := new_engine(EngineConfig{
		persist_path: persist
	})
	eng.init()!
	eng.start()!
	clean := eng.switch_workspace(workspace) or { panic(err.msg()) }
	assert clean == os.real_path(workspace)
	assert workspace_is_initialized(clean)
	assert !workspace_is_initialized(plain_folder)
	snap := eng.snapshot()
	assert snap.data['recent_workspace'] == clean
	assert snap.data['workspace_path'] == clean
	assert snap.data['workspace_initialized'] == 'true'
	mut bus := eng.event_bus()
	event := bus.replay_for(.workspace_changed) or { panic('workspace switch event missing') }
	assert event.path.contains(clean)
	eng.stop()!

	mut reloaded := new_engine(EngineConfig{
		persist_path: persist
	})
	reloaded.init()!
	reloaded.start()!
	defer { reloaded.stop() or {} }
	assert reloaded.snapshot().data['recent_workspace'] == clean
	tree := reloaded.workspace_tree()
	mut found_knowledge := false
	for node in tree {
		if node.path == os.join_path(clean, 'knowledge', 'README.md') {
			found_knowledge = true
		}
	}
	assert found_knowledge
}

fn test_workspace_root_validation_blocks_sibling_prefix_escape() {
	tmp := os.join_path(os.temp_dir(), 'desktop-workspace-boundary-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	workspace := os.join_path(tmp, 'workspace')
	sibling := workspace + '-other'
	os.mkdir_all(workspace) or { panic(err.msg()) }
	os.mkdir_all(sibling) or { panic(err.msg()) }
	secret := os.join_path(sibling, 'secret.md')
	os.write_file(secret, 'outside workspace') or { panic(err.msg()) }

	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	clean := eng.validate_workspace_root(workspace) or { panic(err.msg()) }
	assert clean == os.real_path(workspace)
	if _ := eng.open_path_validated(clean, secret) {
		assert false, 'sibling path must not pass the workspace containment check'
	} else {
		assert err.msg().contains('harness_root_escape')
	}
	if _ := eng.validate_workspace_root(os.join_path(tmp, 'missing')) {
		assert false, 'missing directory must not be selectable'
	} else {
		assert err.msg().contains('does not exist')
	}
}

fn test_workspace_root_validation_rejects_empty_and_filesystem_root() {
	tmp := os.join_path(os.temp_dir(), 'desktop-workspace-edges-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	if _ := eng.validate_workspace_root('') {
		assert false, 'empty path must not be selectable'
	} else {
		assert err.msg() != ''
	}
	if _ := eng.validate_workspace_root(os.path_separator) {
		assert false, 'filesystem root must not be selectable'
	} else {
		assert err.msg().contains('filesystem root')
	}
}
