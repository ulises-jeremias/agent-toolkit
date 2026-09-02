module swarm

import os
import time
import json2
import sync
import desktop_engine.state as engine_state
import desktop_engine.eventbus

// HandoffArtifactFile is a durable file under .agent-toolkit/swarm/runs/<run-id>/artifacts/.
pub struct HandoffArtifactFile {
pub mut:
	run_id     string
	rel_path   string // e.g. artifacts/task-contract.md
	abs_path   string
	size       int
	sha256     string // first 8 chars for dedup
	created_at i64
	status     string // outbox|queued|active|completed|failed
	mime       string
}

// HandoffArtifactStore manages filesystem-backed handoff artifacts wire to EventBus.
pub struct HandoffArtifactStore {
mut:
	files   map[string]HandoffArtifactFile // key = run_id:rel_path
	bus     &eventbus.ToolkitEventBus
	repo    &engine_state.StateRepository
	mu      sync.RwMutex
	emitted u64
}

// new_handoff_artifact_store creates store bound to repo/bus.
pub fn new_handoff_artifact_store(repo &engine_state.StateRepository, bus &eventbus.ToolkitEventBus) &HandoffArtifactStore {
	return &HandoffArtifactStore{
		bus: bus
		repo: repo
		files: map[string]HandoffArtifactFile{}
	}
}

// validate_artifact_path enforces relative, no traversal, <512 chars, <1MB content.
fn validate_artifact_rel(p string) !string {
	if p.len == 0 {
		return error('artifact path empty')
	}
	if os.is_abs_path(p) {
		return error('artifact path must be relative: ${p}')
	}
	if p.contains('..') {
		return error('artifact traversal: ${p}')
	}
	if p.len > 512 {
		return error('artifact path too long')
	}
	if p.contains('\0') {
		return error('artifact null byte')
	}
	return p
}

// run_dir_for returns filesystem dir for a swarm run.
fn run_dir_for(run_id string) string {
	if run_id.len == 0 {
		return os.join_path(os.temp_dir(), 'swarm-runs', 'unknown')
	}
	// prefer repo-local when .agent-toolkit exists
	local := os.join_path(os.getwd(), '.agent-toolkit', 'swarm', 'runs', run_id)
	if os.is_dir(os.join_path(os.getwd(), '.agent-toolkit')) {
		return local
	}
	return local
}

// write artifact atomically under artifacts/ + handoffs/<state>/ and publishes handoff_artifact event.
// Mirrors agent_toolkit_core handoff durable queue write_handoff_outbox semantics.
pub fn (mut s HandoffArtifactStore) write(run_id string, rel_path string, content string) !HandoffArtifactFile {
	rel := validate_artifact_rel(rel_path)!
	if content.len > 1024 * 1024 {
		return error('artifact >1MB cap: ${rel} ${content.len}')
	}
	// secret redaction — fail closed on secret leak
	if content.contains('AKIA') || content.contains('ghp_') || content.contains('sk-') {
		return error('artifact contains secret — redacted')
	}
	base := run_dir_for(run_id)
	art_path := os.join_path(base, 'artifacts', rel)
	handoff_outbox := os.join_path(base, 'handoffs', 'outbox')
	os.mkdir_all(os.dir(art_path)) or { return error('mkdir artifacts failed: ${err}') }
	os.mkdir_all(handoff_outbox) or { return error('mkdir handoffs failed: ${err}') }
	tmp := '${art_path}.tmp.${os.getpid()}'
	os.write_file(tmp, content) or { return error('write tmp failed: ${err}') }
	os.mv(tmp, art_path) or {
		os.rm(tmp) or {}
		return error('rename failed: ${err}')
	}
	// also write handoff JSON under handoffs/outbox/<id>.json for durable queue
	handoff_id := 'h-art-${time.now().unix_nano() % 1000000:06d}'
	handoff_json := os.join_path(handoff_outbox, '${handoff_id}.json')
	handoff_payload := json2.encode({
		'version':    '1'
		'type':       'artifact'
		'from':       'desktop'
		'to':         'swarm'
		'artifact':   rel
		'handoff_id': handoff_id
		'run_id':     run_id
	})
	os.write_file(handoff_json, handoff_payload) or { return error('handoff json failed: ${err}') }

	key := '${run_id}:${rel}'
	f := HandoffArtifactFile{
		run_id: run_id
		rel_path: rel
		abs_path: art_path
		size: content.len
		sha256: ''
		created_at: time.now().unix()
		status: 'outbox'
		mime: if rel.ends_with('.md') { 'text/markdown' } else { 'text/plain' }
	}
	s.mu.lock()
	s.files[key] = f
	s.mu.unlock()
	// persist via StateRepository + EventBus for Activity Journal
	mut tx := s.repo.begin('handoff-artifact-write')
	tx.set('swarm/${run_id}/artifacts/${rel}', art_path)
	tx.set('swarm/${run_id}/artifacts/${rel}/size', content.len.str())
	tx.set('swarm/${run_id}/handoffs/${handoff_id}/artifact', rel)
	tx.set('swarm/${run_id}/handoffs/${handoff_id}/status', 'outbox')
	rev := tx.commit() or { return f }
	s.mu.lock()
	s.emitted++
	s.mu.unlock()
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .handoff_artifact
		revision: rev.revision
		path: 'swarm:${run_id}:artifact:${rel}'
		payload: json2.encode({
			'run_id':     run_id
			'artifact':   rel
			'size':       content.len.str()
			'handoff_id': handoff_id
			'path':       art_path
		})
	})
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_handoff
		revision: rev.revision
		path: 'swarm/handoff/${handoff_id}'
		payload: json2.encode({
			'handoff_id': handoff_id
			'artifact':   rel
			'status':     'outbox'
			'via':        'artifact-file'
		})
	})
	return f
}

// read returns content of artifact, checking filesystem first then StateRepository.
pub fn (s HandoffArtifactStore) read(run_id string, rel_path string) !string {
	rel := validate_artifact_rel(rel_path)!
	base := run_dir_for(run_id)
	art_path := os.join_path(base, 'artifacts', rel)
	if os.is_file(art_path) {
		return os.read_file(art_path) or { return error('read failed: ${err}') }
	}
	key := '${run_id}:${rel}'
	s.mu.rlock()
	if f := s.files[key] {
		s.mu.runlock()
		if os.is_file(f.abs_path) {
			return os.read_file(f.abs_path) or { return error('read cached failed: ${err}') }
		}
	}
	s.mu.runlock()
	// fallback to StateRepository
	snap := s.repo.snapshot()
	sk := 'swarm/${run_id}/artifacts/${rel}'
	if v := snap.data[sk] {
		if os.is_file(v) {
			return os.read_file(v) or { return error('read state path failed: ${err}') }
		}
		return v
	}
	return error('artifact not found: ${rel} in ${run_id}')
}

// list returns all artifacts for run sorted.
pub fn (s HandoffArtifactStore) list(run_id string) []HandoffArtifactFile {
	s.mu.rlock()
	mut out := []HandoffArtifactFile{}
	for _, f in s.files {
		if f.run_id == run_id {
			out << f
		}
	}
	s.mu.runlock()
	// also scan filesystem
	base := run_dir_for(run_id)
	art_dir := os.join_path(base, 'artifacts')
	if os.is_dir(art_dir) {
		files := os.walk_ext(art_dir, '', hidden: false)
		for fp in files {
			rel := fp.all_after(art_dir + os.path_separator)
			mut found := false
			for o in out {
				if o.rel_path == rel {
					found = true
					break
				}
			}
			if !found {
				out << HandoffArtifactFile{
					run_id: run_id
					rel_path: rel
					abs_path: fp
					size: int(os.file_size(fp))
					created_at: os.file_last_mod_unix(fp)
					status: 'completed'
					mime: 'text/plain'
				}
			}
		}
	}
	// merge StateRepository keys
	snap := s.repo.snapshot()
	prefix := 'swarm/${run_id}/artifacts/'
	for k, v in snap.data {
		if k.starts_with(prefix) && !k.ends_with('/size') {
			rel := k.all_after(prefix)
			mut exists := false
			for o in out {
				if o.rel_path == rel {
					exists = true
					break
				}
			}
			if !exists {
				out << HandoffArtifactFile{
					run_id: run_id
					rel_path: rel
					abs_path: v
					size: 0
					created_at: 0
					status: 'queued'
				}
			}
		}
	}
	out.sort_with_compare(fn (a &HandoffArtifactFile, b &HandoffArtifactFile) int {
		if a.rel_path < b.rel_path {
			return -1
		}
		if a.rel_path > b.rel_path {
			return 1
		}
		return 0
	})
	return out
}

// move transitions artifact handoff state outbox→queued→active→completed.
pub fn (mut s HandoffArtifactStore) move_state(run_id string, rel_path string, from_state string, to_state string) bool {
	base := run_dir_for(run_id)
	src := os.join_path(base, 'handoffs', from_state, '${rel_path.replace('/', '_')}.json')
	dst := os.join_path(base, 'handoffs', to_state, '${rel_path.replace('/', '_')}.json')
	// filesystem move if exists
	if os.is_file(src) {
		os.mkdir_all(os.dir(dst)) or { return false }
		os.mv(src, dst) or { return false }
	}
	key := '${run_id}:${rel_path}'
	s.mu.lock()
	if f := s.files[key] {
		mut nf := f
		nf.status = to_state
		s.files[key] = nf
	}
	s.mu.unlock()
	mut tx := s.repo.begin('handoff-artifact-move')
	tx.set('swarm/${run_id}/artifacts/${rel_path}/status', to_state)
	rev := tx.commit() or { return false }
	s.bus.publish(eventbus.ToolkitEvent{
		kind: .swarm_status
		revision: rev.revision
		path: 'swarm:${run_id}:artifact:${rel_path}:${to_state}'
		payload: json2.encode({
			'run_id':   run_id
			'artifact': rel_path
			'from':     from_state
			'to':       to_state
		})
	})
	return true
}

// on_bus_event handles EventBus tick for artifact store (distinct-until-changed).
pub fn (mut s HandoffArtifactStore) on_bus_event(ev eventbus.ToolkitEvent, snap engine_state.State) bool {
	if ev.kind != .handoff_artifact && ev.kind != .swarm_handoff && ev.kind != .state_changed {
		return false
	}
	s.mu.lock()
	s.emitted++
	s.mu.unlock()
	_ = snap
	return true
}
