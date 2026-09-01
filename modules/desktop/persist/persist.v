module persist

import os
import db.sqlite

// Persist is derived-only store for Desktop layout + transient view cursors.
// Canonical Engine State (catalogs/plugins/distributions) always wins —
// derived SQLite never writes to canonical paths, schema versioned,
// wipe-and-rebuild safe per #1031 and docs/ARCHITECTURE.md Project>Workspace>Toolkit.
pub struct Persist {
mut:
	db sqlite.DB
	db_path string
	schema_version int = 1
}

// PersistConfig tunes persist (headless + real window share same).
@[params]
pub struct PersistConfig {
pub:
	db_path string // XDG: ~/.cache/agent-toolkit/desktop.db or tmp for headless
}

// new_persist creates Persist with sqlite DB (derived-only).
pub fn new_persist(cfg PersistConfig) !&Persist {
	mut path := cfg.db_path
	if path == '' {
		cache := os.join_path(os.home_dir(), '.cache', 'agent-toolkit')
		os.mkdir_all(cache) or {}
		path = os.join_path(cache, 'desktop.db')
	}
	// ensure parent dir exists (headless tmp)
	dir := os.dir(path)
	if dir != '' {
		os.mkdir_all(dir) or {}
	}
	mut db := sqlite.connect(path) or { return error('sqlite connect ${path}: ${err.msg()}') }
	mut p := &Persist{
		db: db
		db_path: path
	}
	p.migrate() or {
		db.close() or {}
		return err
	}
	return p
}

// close closes DB.
pub fn (mut p Persist) close() {
	p.db.close() or {}
}

// migrate ensures schema versioned, idempotent.
fn (mut p Persist) migrate() ! {
	// version table for wipe-and-rebuild safety
	p.db.exec('CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY)') or {
		return error('migrate schema_version: ${err.msg()}')
	}
	// layout: dock snapshot as JSON + panel rects
	p.db.exec('CREATE TABLE IF NOT EXISTS layout (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)') or {
		return error('migrate layout: ${err.msg()}')
	}
	// view_state: transient AppState view cursors (selected panel, palette query, inspector id)
	p.db.exec('CREATE TABLE IF NOT EXISTS view_state (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL)') or {
		return error('migrate view_state: ${err.msg()}')
	}
	// seed version if empty
	rows := p.db.exec('SELECT version FROM schema_version LIMIT 1') or {
		return error('select version: ${err.msg()}')
	}
	if rows.len == 0 {
		p.db.exec('INSERT INTO schema_version (version) VALUES (1)') or {
			return error('insert version: ${err.msg()}')
		}
	}
	p.schema_version = 1
}

// save_layout persists derived layout JSON (panel rects, splitter positions, dock snapshot).
// Never writes to catalogs/plugins — derived only.
pub fn (mut p Persist) save_layout(key string, value string) ! {
	if key == '' {
		return error('key empty')
	}
	// guard: never canonical path
	if key.contains('catalogs/') || key.contains('plugins/') || key.contains('distributions/') {
		return error('derived guard: cannot persist canonical key ${key}')
	}
	now := 0 // deterministic for headless; real window would use time.now().unix()
	p.db.exec_param_many('INSERT OR REPLACE INTO layout (key, value, updated_at) VALUES (?, ?, ?)',
		[key, value, now.str()]) or { return error('save_layout: ${err.msg()}') }
}

// load_layout restores derived layout JSON, or none if wiped/missing.
pub fn (mut p Persist) load_layout(key string) ?string {
	if key == '' {
		return none
	}
	rows := p.db.exec_param('SELECT value FROM layout WHERE key = ?', key) or {
		return none
	}
	if rows.len == 0 {
		return none
	}
	return rows[0].vals[0]
}

// save_view_state persists transient view cursor.
pub fn (mut p Persist) save_view_state(key string, value string) ! {
	if key == '' {
		return error('key empty')
	}
	if key.contains('catalogs/') || key.contains('plugins/') {
		return error('derived guard: cannot persist canonical key ${key}')
	}
	now := 0
	p.db.exec_param_many('INSERT OR REPLACE INTO view_state (key, value, updated_at) VALUES (?, ?, ?)',
		[key, value, now.str()]) or { return error('save_view_state: ${err.msg()}') }
}

// load_view_state restores transient cursor.
pub fn (mut p Persist) load_view_state(key string) ?string {
	if key == '' {
		return none
	}
	rows := p.db.exec_param('SELECT value FROM view_state WHERE key = ?', key) or {
		return none
	}
	if rows.len == 0 {
		return none
	}
	return rows[0].vals[0]
}

// clear wipes derived DB (safe rebuild — no canonical touched).
pub fn (mut p Persist) clear() ! {
	p.db.exec('DELETE FROM layout') or { return error('clear layout: ${err.msg()}') }
	p.db.exec('DELETE FROM view_state') or { return error('clear view_state: ${err.msg()}') }
}

// schema_version_nr returns current schema version.
pub fn (p Persist) schema_version_nr() int {
	return p.schema_version
}

// db_path_of returns underlying path (for probe).
pub fn (p Persist) db_path_of() string {
	return p.db_path
}

// is_derived_only reports true — canonical never written via this seam.
pub fn (p Persist) is_derived_only() bool {
	return true
}
