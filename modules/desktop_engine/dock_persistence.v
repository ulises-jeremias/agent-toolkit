module desktop_engine

import os

// Dock persistence — Engine-owned derived persistence for the docking shell.
//
// The dock layout is derived state (restorable from defaults), never
// canonical. The Engine owns the persist path derivation, the atomic file
// write, and the StateRepository mirror (dock/layout_* keys). The shell keeps
// only pure serialization (see desktop.shell DockLayout.persist_payload);
// it never derives paths. Views consume via Desktop proxies, never via
// direct filesystem access.

// dock_file_name is the derived dock file next to the Engine state file.
pub const dock_file_name = 'dock.json'

// dock_default_path derives the default dock path from XDG cache
// (cache/agent-toolkit/desktop/dock.json). Used when the Engine has no
// explicit persist path.
pub fn dock_default_path() string {
	base := os.getenv('XDG_CACHE_HOME')
	home := os.home_dir()
	cache := if base.len > 0 { base } else { os.join_path(home, '.cache') }
	return os.join_path(cache, 'agent-toolkit', 'desktop', dock_file_name)
}

// dock_path_for derives the dock file for a repository persist path: a
// sibling of the state file so tests and custom layouts stay isolated.
// Empty persist_path falls back to the XDG default.
pub fn dock_path_for(persist_path string) string {
	if persist_path.trim_space() == '' {
		return dock_default_path()
	}
	return os.join_path(os.dir(persist_path), dock_file_name)
}

// dock_persist_path returns this Engine's derived dock file path.
pub fn (mut e Engine) dock_persist_path() string {
	return dock_path_for(e.repo.persist_path_of())
}

// save_dock_snapshot persists a serialized dock payload (as produced by the
// shell serializer): mirrors revision + payload into the StateRepository via
// a single Transaction (one revision bump, one state_changed event) and
// writes the derived dock.json file atomically. Strict: file errors return.
pub fn (mut e Engine) save_dock_snapshot(payload string, revision u64) !u64 {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	if payload.trim_space() == '' {
		return error('dock payload empty')
	}
	mut tx := e.repo.begin('dock')
	tx.set('dock_layout', 'rev:${revision}')
	tx.set('dock/layout_revision', revision.str())
	tx.set('dock/layout_payload', payload)
	rev := e.put_transaction(mut tx)!
	path := dock_path_for(e.repo.persist_path_of())
	os.mkdir_all(os.dir(path)) or { return error('mkdir failed: ${err}') }
	tmp := '${path}.tmp.${os.getpid()}'
	os.write_file(tmp, payload) or { return error('write tmp failed: ${err}') }
	os.mv(tmp, path) or {
		os.rm(tmp) or {}
		return error('rename failed: ${err}')
	}
	return rev.revision
}

// load_dock_snapshot returns the mirrored dock payload, if any. Falls back
// to the derived dock.json file (pre-migration layouts) before giving none.
pub fn (mut e Engine) load_dock_snapshot() ?string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	payload := snap.data['dock/layout_payload'] or { '' }
	if payload != '' {
		return payload
	}
	path := dock_path_for(e.repo.persist_path_of())
	if os.is_file(path) {
		if text := os.read_file(path) {
			if text.trim_space() != '' {
				return text
			}
		}
	}
	return none
}
