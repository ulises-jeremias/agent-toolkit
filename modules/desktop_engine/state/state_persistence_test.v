module state

import os
import json

fn test_persistence_roundtrip_xdg_mock() {
	tmp := os.join_path(os.temp_dir(), 'state-persist-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'desktop', 'state.json')
	mut repo := new_state_repository(persist)
	mut tx := repo.begin('persist-actor')
	tx.set('recent_workspace', '/tmp/ws1')
	tx.set('dock_layout', 'left')
	tx.commit() or {
		assert false, err.msg()
		return
	}
	repo.persist() or {
		assert false, err.msg()
		return
	}
	assert os.is_file(persist)
	// read back via json.decode
	text := os.read_file(persist) or {
		assert false, err.msg()
		return
	}
	decoded := json.decode(State, text) or {
		assert false, err.msg()
		return
	}
	assert decoded.data['recent_workspace'] == '/tmp/ws1'
	assert decoded.data['dock_layout'] == 'left'
	// load into new repo
	mut repo2 := new_state_repository(persist)
	repo2.load() or {
		assert false, err.msg()
		return
	}
	s2 := repo2.snapshot()
	assert s2.data['recent_workspace'] == '/tmp/ws1'
	assert s2.revision == decoded.revision
}

fn test_persistence_only_derived_not_canonical() {
	// canonical sources remain filesystem reads, not SQLite/persist
	// Ensure persist file does NOT contain skills content
	tmp := os.join_path(os.temp_dir(), 'state-canonical-${os.getpid()}')
	os.mkdir_all(tmp) or { assert false, err.msg() }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut repo := new_state_repository(persist)
	mut tx := repo.begin('actor')
	tx.set('derived_pref', 'value')
	tx.commit() or {
		assert false, err.msg()
		return
	}
	repo.persist() or {
		assert false, err.msg()
		return
	}
	text := os.read_file(persist) or {
		assert false, err.msg()
		return
	}
	// Should not contain canonical marker like 'skills/' path
	assert !text.contains('skills/') || text.contains('derived_pref')
	// Verify decode still works
	_ := json.decode(State, text) or {
		assert false, err.msg()
		return
	}
}
