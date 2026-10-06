module agent_toolkit_core

import os

const session_test_person_json = '{"spec":"agent-toolkit/person@1","id":"lina","name":"Lina","role":"reviewer","goal":"Review changes","archived":false}'

fn session_workspace(name string) string {
	ws := os.join_path(os.temp_dir(), 'atk-person-session-${name}-${os.getpid()}')
	os.mkdir_all(os.join_path(ws, '.git')) or { panic(err) }
	os.mkdir_all(os.join_path(ws, 'projects', 'demo')) or { panic(err) }
	os.mkdir_all(os.join_path(ws, 'people')) or { panic(err) }
	os.symlink(os.join_path(ws, 'projects', 'demo'), os.join_path(ws, 'projects', 'linked-demo')) or { panic(err) }
	save_person(ws, session_test_person_json, true) or { panic(err) }
	return ws
}

fn test_person_session_history_records_only_reported_lifecycle_and_rejects_invalid_transitions() {
	ws := session_workspace('lifecycle')
	defer { os.rmdir_all(ws) or {} }
	mut store := new_person_session_store()
	file := store.session_file(ws, 'session-test') or { panic(err) }
	os.mkdir_all(os.dir(file)) or { panic(err) }
	os.write_file(file, '{"id":"session-test","person_id":"lina","person":"Lina","role":"reviewer","project_id":"linked-demo","cwd":"${os.join_path(ws, 'projects', 'demo')}","provider":"opencode","model":"","status":"launching","started_at":"2026-10-06T00:00:00Z","ended_at":"","exit_code":-1}') or { panic(err) }
	started := store.update_person_session(ws, 'session-test', 'running', -1) or { panic(err) }
	assert started.status == 'running'
	assert started.ended_at == ''
	finished := store.update_person_session(ws, 'session-test', 'completed', 0) or { panic(err) }
	assert finished.status == 'completed'
	assert finished.ended_at.len > 0
	assert finished.exit_code == 0
	listed := store.list_person_sessions(ws) or { panic(err) }
	assert listed.sessions.len == 1
	assert listed.sessions[0].person_id == 'lina'
	if _ := store.update_person_session(ws, 'session-test', 'running', -1) {
		assert false, 'terminal sessions must not return to running'
	} else {
		assert err.msg().contains('invalid session transition')
	}
}

fn test_person_session_launch_requires_active_person_real_project_and_installed_provider() {
	ws := session_workspace('launch-validation')
	defer { os.rmdir_all(ws) or {} }
	mut store := new_person_session_store()
	if _ := store.create_person_session(PersonSessionCreateRequest{
		workspace: ws
		person_id: 'lina'
		project_id: 'missing'
		provider: 'opencode'
	}) {
		assert false, 'missing projects must not create sessions'
	} else {
		assert err.msg().contains('project not found')
	}
	if _ := store.create_person_session(PersonSessionCreateRequest{
		workspace: ws
		person_id: 'lina'
		project_id: 'linked-demo'
		provider: 'skeleton'
	}) {
		assert false, 'the non-executable skeleton provider must not create sessions'
	} else {
		assert err.msg().contains('provider is unavailable')
	}
	save_person(ws, session_test_person_json.replace('"archived":false', '"archived":true'), false) or { panic(err) }
	if _ := store.create_person_session(PersonSessionCreateRequest{
		workspace: ws
		person_id: 'lina'
		project_id: 'linked-demo'
		provider: 'opencode'
	}) {
		assert false, 'archived People must not create sessions'
	} else {
		assert err.msg().contains('archived')
	}
}

fn test_person_session_list_rejects_symlinked_session_storage() {
	ws := session_workspace('symlink-storage')
	defer { os.rmdir_all(ws) or {} }
	mut store := new_person_session_store()
	external := os.join_path(os.temp_dir(), 'atk-session-outside-${os.getpid()}')
	os.mkdir_all(external) or { panic(err) }
	defer { os.rmdir_all(external) or {} }
	people_sessions := os.join_path(ws, '.agent-toolkit', 'sessions')
	os.mkdir_all(os.dir(people_sessions)) or { panic(err) }
	os.symlink(external, people_sessions) or { panic(err) }
	if _ := store.list_person_sessions(ws) {
		assert false, 'symlinked session storage must not be read'
	} else {
		assert err.msg().contains('symlink')
	}
}
