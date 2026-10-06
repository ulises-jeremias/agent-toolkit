module agent_toolkit_core

import os
import rand
import sync
import time
import x.json2

const person_sessions_limit = 512
const person_session_limit = 16384

// PersonSession is durable runtime history for a Person. PTY bytes and the
// child process remain owned by the Desktop adapter; these fields describe
// only lifecycle evidence reported by that adapter.
pub struct PersonSession {
pub mut:
	id         string
	person_id  string
	person     string
	role       string
	project_id string
	cwd        string
	provider   string
	model      string
	status     string
	started_at string
	ended_at   string
	exit_code  int = -1
}

pub struct PersonSessionsResponse {
pub:
	ok       bool
	sessions []PersonSession
}

pub struct PersonSessionResponse {
pub:
	ok      bool
	session PersonSession
}

pub struct PersonSessionCreateRequest {
pub:
	workspace  string
	person_id  string
	project_id string
	provider   string
	model      string
}

pub struct PersonSessionStatusRequest {
pub:
	workspace string
	status    string
	exit_code int = -1
}

pub struct PersonSessionStore {
pub mut:
	mut sync.Mutex
}

pub fn new_person_session_store() &PersonSessionStore {
	return &PersonSessionStore{}
}

fn person_sessions_dir(workspace string) !string {
	ws := find_workspace_root(workspace) or { return error('workspace not found') }
	root := os.join_path(os.real_path(ws), '.agent-toolkit')
	if os.is_link(root) { return error('session storage root is a symlink') }
	dir := os.join_path(root, 'sessions')
	if os.is_link(dir) { return error('sessions directory is a symlink') }
	return dir
}

fn (s &PersonSessionStore) session_file(workspace string, id string) !string {
	if !person_slug(id) { return error('invalid session id') }
	dir := person_sessions_dir(workspace)!
	return os.join_path(dir, '${id}.json')
}

fn valid_session_transition(from string, to string) bool {
	return match from {
		'launching' { to in ['running', 'completed', 'failed', 'stopped', 'timed_out', 'interrupted'] }
		'running' { to in ['completed', 'failed', 'stopped', 'timed_out', 'interrupted'] }
		else { false }
	}
}

// create_person_session resolves the real project path and validates the
// selected Person and provider before recording a launch. It never spawns.
pub fn (mut store PersonSessionStore) create_person_session(req PersonSessionCreateRequest) !PersonSession {
	store.mut.lock()
	defer { store.mut.unlock() }
	if req.project_id.len == 0 || req.project_id.len > 128 || req.project_id in ['.', '..']
		|| req.project_id.contains('/') || req.project_id.contains('\\') || req.project_id.contains('\x00') {
		return error('invalid project id')
	}
	person := read_person(req.workspace, req.person_id)!
	if person.person['archived']!.bool() { return error('archived People cannot start sessions') }
	project_link := os.join_path(os.real_path(find_workspace_root(req.workspace) or { return error('workspace not found') }), 'projects', req.project_id)
	if !os.is_link(project_link) { return error('project not found: ${req.project_id}') }
	target := os.readlink(project_link) or { return error('project link cannot be read') }
	if !symlink_target_exists(project_link, target) { return error('project target is missing') }
	project_target := if os.is_abs_path(target) { target } else { os.join_path(os.dir(project_link), target) }
	cwd := os.real_path(project_target)
	if !os.is_dir(cwd) { return error('project target is not a directory') }
	provider := list_providers().filter(it.id == req.provider && it.available && it.id != 'skeleton')
	if provider.len == 0 { return error('interactive provider is unavailable: ${req.provider}') }
	if req.model.len > 0 && list_models().filter(it.runner == req.provider && it.model == req.model).len == 0 {
		return error('model is not available for provider: ${req.provider}')
	}
	now := time.utc().format_rfc3339()
	id := 'session_${time.utc().unix()}_${os.getpid()}_${(rand.int_in_range(1000, 9999) or { 1000 })}'
	session := PersonSession{
		id: id
		person_id: req.person_id
		person: person.person['name']!.str()
		role: person.person['role']!.str()
		project_id: req.project_id
		cwd: cwd
		provider: req.provider
		model: req.model
		status: 'launching'
		started_at: now
	}
	dir := person_sessions_dir(req.workspace)!
	os.mkdir_all(dir) or { return error('sessions directory cannot be created') }
	if os.is_link(os.dir(dir)) || os.is_link(dir) { return error('sessions directory is a symlink') }
	file := store.session_file(req.workspace, id)!
	if os.exists(file) || os.is_link(file) { return error('session record already exists or is unsafe') }
	tmp := file + '.${os.getpid()}.tmp'
	if os.exists(tmp) || os.is_link(tmp) { return error('session write is busy') }
	os.write_file(tmp, json2.encode(session, escape_unicode: true)) or {
		return error('session record cannot be written')
	}
	os.mv(tmp, file) or {
		os.rm(tmp) or {}
		return error('session record cannot be saved')
	}
	return session
}

pub fn (mut store PersonSessionStore) update_person_session(workspace string, id string, status string, exit_code int) !PersonSession {
	store.mut.lock()
	defer { store.mut.unlock() }
	if status !in ['running', 'completed', 'failed', 'stopped', 'timed_out', 'interrupted'] {
		return error('invalid session status')
	}
	file := store.session_file(workspace, id)!
	if os.is_link(file) { return error('session record is a symlink') }
	if os.file_size(file) > person_session_limit { return error('session record is too large') }
	raw := os.read_file(file) or { return error('session not found: ${id}') }
	mut session := json2.decode[PersonSession](raw) or { return error('session record is invalid') }
	if !valid_session_transition(session.status, status) {
		return error('invalid session transition: ${session.status} -> ${status}')
	}
	session.status = status
	if status in ['completed', 'failed', 'stopped', 'timed_out', 'interrupted'] {
		session.ended_at = time.utc().format_rfc3339()
		session.exit_code = exit_code
	}
	tmp := file + '.${os.getpid()}.tmp'
	if os.exists(tmp) || os.is_link(tmp) { return error('session write is busy') }
	os.write_file(tmp, json2.encode(session, escape_unicode: true)) or {
		return error('session record cannot be updated')
	}
	os.mv(tmp, file) or {
		os.rm(tmp) or {}
		return error('session record cannot be saved')
	}
	return session
}

pub fn (mut store PersonSessionStore) list_person_sessions(workspace string) !PersonSessionsResponse {
	store.mut.lock()
	defer { store.mut.unlock() }
	dir := person_sessions_dir(workspace)!
	if !os.is_dir(dir) { return PersonSessionsResponse{ ok: true, sessions: []PersonSession{} } }
	entries := os.ls(dir) or { return error('sessions directory cannot be read') }
	if entries.len > person_sessions_limit { return error('too many session records') }
	mut sessions := []PersonSession{}
	for entry in entries {
		if !entry.ends_with('.json') { continue }
		id := entry[..entry.len - 5]
		file := store.session_file(workspace, id)!
		if os.is_link(file) { return error('session record is a symlink') }
		if os.file_size(file) > person_session_limit { return error('session record is too large') }
		raw := os.read_file(file) or { return error('session record cannot be read') }
		session := json2.decode[PersonSession](raw) or { return error('session record is invalid') }
		if session.id != id || session.status !in ['launching', 'running', 'completed', 'failed', 'stopped', 'timed_out', 'interrupted'] {
			return error('session record is invalid')
		}
		sessions << session
	}
	sessions.sort(a.started_at > b.started_at)
	return PersonSessionsResponse{ ok: true, sessions: sessions }
}
