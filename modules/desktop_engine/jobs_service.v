module desktop_engine

import time
import sync

pub enum JobStatus {
	queued
	running
	done
	failed
	canceled
}

pub struct JobRecord {
pub mut:
	id          string
	cmd         string
	status      JobStatus
	exit_code   int
	duration_ms int
	started_at  i64
	logs        []string
	canceled    bool
}

pub struct JobStore {
mut:
	mu      sync.RwMutex
	records map[string]JobRecord
	order   []string
}

pub fn new_job_store() &JobStore {
	return &JobStore{
		records: map[string]JobRecord{}
		order: []string{}
	}
}

pub fn (mut s JobStore) list() []JobRecord {
	s.mu.rlock()
	defer { s.mu.runlock() }
	mut out := []JobRecord{cap: s.order.len}
	for id in s.order {
		if rec := s.records[id] {
			out << rec
		}
	}
	return out
}

pub fn (mut s JobStore) upsert(rec JobRecord) {
	s.mu.lock()
	defer { s.mu.unlock() }
	if rec.id !in s.records {
		s.order << rec.id
	}
	s.records[rec.id] = rec
}

pub fn (mut s JobStore) get(id string) ?JobRecord {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.records[id]
}

pub fn (mut s JobStore) job_count() int {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.order.len
}

pub fn (mut e Engine) jobs_catalog() []JobRecord {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	mut ids := []string{}
	for k, _ in snap.data {
		if k.starts_with('jobs/') && k.ends_with('/cmd') {
			id := k.all_after('jobs/').all_before('/cmd')
			if id !in ids {
				ids << id
			}
		}
	}
	mut out := []JobRecord{}
	for id in ids {
		cmd := snap.data['jobs/${id}/cmd'] or { '' }
		status_str := snap.data['jobs/${id}/status'] or { 'queued' }
		status := match status_str {
			'running' { JobStatus.running }
			'done' { JobStatus.done }
			'failed' { JobStatus.failed }
			'canceled' { JobStatus.canceled }
			else { JobStatus.queued }
		}
		exit_str := snap.data['jobs/${id}/exit_code'] or { '0' }
		exit_code := exit_str.int()
		start_str := snap.data['jobs/${id}/started_at'] or { '0' }
		started := start_str.i64()
		out << JobRecord{
			id: id
			cmd: cmd
			status: status
			exit_code: exit_code
			started_at: started
		}
	}
	return out
}

pub fn (mut e Engine) spawn_job(cmd string, args []string) !string {
	if cmd == '' {
		return error('cmd empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	id := 'job-${time.now().unix_nano() % 1000000:06d}'
	mut repo := e.repo
	mut tx := repo.begin('spawn-job')
	mut all_args := [cmd]
	all_args << args
	tx.set('jobs/${id}/cmd', all_args.join(' '))
	tx.set('jobs/${id}/status', 'queued')
	tx.set('jobs/${id}/started_at', time.now().unix().str())
	tx.set('jobs/${id}/exit_code', '0')
	rev := e.put_transaction(mut tx)!
	_ = rev
	if mut sup := e.supervisor {
		spawned := sup.spawn_job(cmd, args) or { id }
		return spawned
	}
	return id
}

pub fn (mut e Engine) cancel_job(job_id string) !u64 {
	if job_id == '' {
		return error('job_id empty')
	}
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	mut repo := e.repo
	mut tx := repo.begin('cancel-job')
	tx.set('jobs/${job_id}/status', 'canceled')
	tx.set('jobs/${job_id}/canceled', 'true')
	rev := e.put_transaction(mut tx)!
	return rev.revision
}

pub fn (mut e Engine) job_logs(job_id string) []string {
	e.mu.lock()
	e.api_calls++
	e.mu.unlock()
	snap := e.repo.snapshot()
	raw := snap.data['jobs/${job_id}/logs'] or { '' }
	if raw == '' {
		return []string{}
	}
	return raw.split('\n')
}
