module state

import sync
import time
import json2
import os

// Revision is monotonic u64 + timestamp + actor (who triggered).
pub struct Revision {
pub:
	revision  u64
	timestamp i64
	actor     string
}

// State is the immutable snapshot for Engine. Copy-on-write.
// Holds derived Desktop state only (recent workspaces, prefs, dock layouts).
// Canonical sources (skills/loops/swarm) remain filesystem + embedded truth per ADR-026.
pub struct State {
pub:
	revision  u64
	timestamp i64
	actor     string
	data      map[string]string
}

// clone returns immutable copy (copy-on-write barrier).
pub fn (s State) clone() State {
	mut d := map[string]string{}
	for k, v in s.data {
		d[k] = v
	}
	return State{
		revision: s.revision
		timestamp: s.timestamp
		actor: s.actor
		data: d
	}
}

// StateRepository owns revisioned immutable snapshots.
// Thread-safe: single writer via RwMutex write lock, multiple readers via read lock.
// Integrates with EventBus via commit emission (caller wires event).
pub struct StateRepository {
mut:
	mu           sync.RwMutex
	state        State
	revision     u64
	persist_path string
}

// new_state_repository creates a repository with optional persistence path.
// If persist_path == '' defaults to XDG cache/desktop/state.json derived persistence.
pub fn new_state_repository(persist_path string) &StateRepository {
	path := if persist_path.len > 0 {
		persist_path
	} else {
		default_persist_path()
	}
	return &StateRepository{
		state: State{
			revision: 0
			timestamp: time.now().unix()
			data: map[string]string{}
		}
		revision: 0
		persist_path: path
	}
}

fn default_persist_path() string {
	base := os.getenv('XDG_CACHE_HOME')
	home := os.home_dir()
	cache := if base.len > 0 { base } else { os.join_path(home, '.cache') }
	return os.join_path(cache, 'agent-toolkit', 'desktop', 'state.json')
}

// snapshot returns immutable copy of current state (read-locked).
pub fn (mut r StateRepository) snapshot() State {
	r.mu.rlock()
	defer { r.mu.runlock() }
	return r.state.clone()
}

// select projects snapshot through pure selector fn — memoizable, no side effects.
pub fn (mut r StateRepository) select(selector fn(State) string) string {
	s := r.snapshot()
	return selector(s)
}

// revision returns current monotonic revision.
pub fn (mut r StateRepository) revision_nr() u64 {
	r.mu.rlock()
	defer { r.mu.runlock() }
	return r.revision
}

// put applies a committed transaction atomically, bumps revision, emits via EventBus caller.
// Returns new Revision.
pub fn (mut r StateRepository) put(mut tx Transaction) !Revision {
	if tx.committed || tx.rolled_back {
		return error('transaction already closed')
	}
	r.mu.lock()
	defer { r.mu.unlock() }
	// validate staged keys (no empty, no traversal)
	for k, _ in tx.staged {
		if k.len == 0 {
			return error('empty path in transaction')
		}
		if k.contains('..') {
			return error('invalid path traversal: ${k}')
		}
	}
	// atomic copy-on-write
	mut next := r.state.data.clone()
	for k, v in tx.staged {
		next[k] = v
	}
	r.revision++
	now := time.now().unix()
	r.state = State{
		revision: r.revision
		timestamp: now
		actor: tx.actor
		data: next
	}
	tx.committed = true
	return Revision{
		revision: r.revision
		timestamp: now
		actor: tx.actor
	}
}

// persist writes derived state JSON under persist_path atomically (XDG path).
// Only for derived Desktop state; canonical skills/loops remain file reads.
pub fn (mut r StateRepository) persist() ! {
	s := r.snapshot()
	payload := json2.encode(s, escape_unicode: true)
	dir := os.dir(r.persist_path)
	os.mkdir_all(dir) or { return error('mkdir failed: ${err}') }
	tmp := '${r.persist_path}.tmp.${os.getpid()}'
	os.write_file(tmp, payload) or { return error('write tmp failed: ${err}') }
	os.mv(tmp, r.persist_path) or {
		os.rm(tmp) or {}
		return error('rename failed: ${err}')
	}
}

// load restores derived state JSON from persist_path if present.
pub fn (mut r StateRepository) load() ! {
	if !os.is_file(r.persist_path) {
		return
	}
	text := os.read_file(r.persist_path) or { return error('read failed: ${err}') }
	loaded := json2.decode[State](text) or { return error('decode failed: ${err}') }
	r.mu.lock()
	defer { r.mu.unlock() }
	r.state = loaded
	if loaded.revision > r.revision {
		r.revision = loaded.revision
	}
}

// Transaction is begin → set → commit | rollback — atomic, single writer.
pub struct Transaction {
pub:
	actor string
mut:
	repo        &StateRepository = unsafe { nil }
	staged      map[string]string
	committed   bool
	rolled_back bool
}

// begin creates a transaction bound to repo. Actor identifies trigger.
pub fn (mut r StateRepository) begin(actor string) Transaction {
	return Transaction{
		repo: &r
		actor: actor
		staged: map[string]string{}
	}
}

// set stages a path→value mutation (in-memory until commit).
pub fn (mut tx Transaction) set(path string, value string) {
	if tx.committed || tx.rolled_back {
		return
	}
	tx.staged[path] = value
}

// commit atomically applies staged writes via repo.put, bumps revision.
pub fn (mut tx Transaction) commit() !Revision {
	if tx.committed {
		return error('already committed')
	}
	if tx.rolled_back {
		return error('already rolled back')
	}
	return tx.repo.put(mut tx)
}

// rollback discards staged writes.
pub fn (mut tx Transaction) rollback() {
	if tx.committed || tx.rolled_back {
		return
	}
	tx.rolled_back = true
	tx.staged.clear()
}

// staged_count returns number of staged entries (testing).
pub fn (tx Transaction) staged_count() int {
	return tx.staged.len
}
