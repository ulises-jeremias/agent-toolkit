module desktop_engine

import os

fn test_dock_path_derivation_sibling_and_default() {
	persist := os.join_path('/tmp', 'scratch-${os.getpid()}', 'state.json')
	assert dock_path_for(persist) == os.join_path('/tmp', 'scratch-${os.getpid()}', dock_file_name)
	// empty persist path falls back to the XDG-derived default
	assert dock_path_for('') == dock_default_path()
	assert dock_default_path().ends_with(os.join_path('agent-toolkit', 'desktop', dock_file_name))
}

fn test_dock_snapshot_save_load_roundtrip_via_engine() {
	tmp := os.join_path(os.temp_dir(), 'engine-dock-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	// derived path is a sibling of the state file (isolated, never XDG)
	assert eng.dock_persist_path() == os.join_path(tmp, dock_file_name)
	before := eng.api_call_count()
	payload := '{"revision":7,"timestamp":123,"panels":[{"id":"skills"}]}'
	rev := eng.save_dock_snapshot(payload, 7) or { panic(err.msg()) }
	assert rev >= 1
	assert eng.api_call_count() > before, 'dock save must count as an Engine API call'
	// repository mirror holds revision + payload (single transaction)
	snap := eng.snapshot()
	assert snap.data['dock_layout'] == 'rev:7'
	assert snap.data['dock/layout_revision'] == '7'
	assert snap.data['dock/layout_payload'] == payload
	// derived file holds the exact payload
	path := eng.dock_persist_path()
	assert os.is_file(path), 'derived dock.json must exist at ${path}'
	assert os.read_file(path) or { '' } == payload
	// load returns the mirrored payload
	loaded := eng.load_dock_snapshot() or { panic('dock snapshot missing') }
	assert loaded == payload
	eng.stop()!
	// restart: the mirror survives via state.json persistence
	mut reloaded := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	reloaded.init()!
	reloaded.start()!
	defer { reloaded.stop() or {} }
	again := reloaded.load_dock_snapshot() or { panic('dock snapshot missing after restart') }
	assert again == payload
}

fn test_dock_snapshot_rejects_empty_payload() {
	tmp := os.join_path(os.temp_dir(), 'engine-dock-empty-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	if _ := eng.save_dock_snapshot('', 1) {
		assert false, 'empty dock payload must be rejected'
	} else {
		assert err.msg().contains('empty')
	}
	if _ := eng.load_dock_snapshot() {
		assert false, 'no snapshot persisted yet'
	} else {
		assert true
	}
}
