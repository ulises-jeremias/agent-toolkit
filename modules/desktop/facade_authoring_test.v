module desktop

// facade_authoring_test.v — Slice D workspace authoring facade (issue #1231).
// Behavior-named: guard ordering, guarded ops, run binding, omitted checkout.

import desktop.theme
import desktop_engine
import os

fn setup_authoring_facade(tag string) (string, string, &desktop_engine.Engine, &WorkspaceAuthoringFacade) {
	tmp := os.join_path(os.temp_dir(), 'desk-facade-${tag}-${os.getpid()}')
	os.rmdir_all(tmp) or {}
	workspace := os.join_path(tmp, 'workspace')
	os.mkdir_all(os.join_path(workspace, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(workspace, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	eng.switch_workspace(workspace) or { panic(err.msg()) }
	mut f := new_workspace_authoring_facade(eng, workspace, theme.default_theme())
	return tmp, workspace, eng, f
}

fn seed_running_job(mut eng &desktop_engine.Engine) {
	mut repo := eng.state_repo()
	mut tx := repo.begin('authoring-test-running')
	tx.set('jobs/agent-1/cmd', 'sleep 30')
	tx.set('jobs/agent-1/status', 'running')
	tx.set('jobs/agent-1/started_at', '1')
	eng.put_transaction(mut tx) or { panic(err.msg()) }
}

fn seed_dirty_tree(mut eng &desktop_engine.Engine) {
	mut repo := eng.state_repo()
	mut tx := repo.begin('authoring-test-dirty')
	tx.set('dirty_files', 'notes.md')
	eng.put_transaction(mut tx) or { panic(err.msg()) }
}

fn test_authoring_guard_prefers_running_over_dirty() {
	assert authoring_guard_reason(1, 3).contains('running'), 'running wins over dirty'
	assert authoring_guard_reason(0, 2).contains('dirty'), 'dirty blocks when idle'
	assert authoring_guard_reason(0, 0) == '', 'clean idle workspace proceeds'
}

fn test_facade_delete_memory_guarded_by_running_agent() {
	tmp, workspace, mut eng, mut f := setup_authoring_facade('guard-running')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'knowledge', 'doomed.md'), '# Doomed\n') or {
		panic(err.msg())
	}
	seed_running_job(mut eng)
	assert f.guard_reason().contains('running')
	if _ := f.delete_memory('knowledge/doomed.md') {
		assert false, 'facade delete during a run must be refused'
	} else {
		assert err.msg().contains('running')
	}
	assert os.exists(os.join_path(workspace, 'knowledge', 'doomed.md'))
}

fn test_facade_delete_memory_guarded_by_dirty_tree() {
	tmp, workspace, mut eng, mut f := setup_authoring_facade('guard-dirty')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'knowledge', 'doomed.md'), '# Doomed\n') or {
		panic(err.msg())
	}
	seed_dirty_tree(mut eng)
	assert f.guard_reason().contains('dirty')
	if _ := f.delete_memory('knowledge/doomed.md') {
		assert false, 'facade delete on a dirty tree must be refused'
	} else {
		assert err.msg().contains('dirty')
	}
}

fn test_facade_add_review_todos_roundtrip() {
	tmp, _, mut eng, mut f := setup_authoring_facade('roundtrip')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	added := f.add_memory('todo', '', 'Facade roundtrip todo')
	assert added.ok, 'facade add must succeed: ${added.message}'
	todos := f.list_todos(false)
	assert todos.ok
	assert todos.message.contains('Facade roundtrip todo')
	review := f.review_memory(90, false)
	assert review.data['subcommand'] == 'review'
}

fn test_facade_run_binding_reflects_project_switch() {
	tmp, _, mut eng, mut f := setup_authoring_facade('run-bind')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	before := f.run_binding()
	assert before.running == 0
	assert before.current_project == ''
	f.switch_project('demo') or { panic('switch must succeed: ${err.msg()}') }
	after := f.run_binding()
	assert after.current_project == 'demo'
	assert 'demo' in after.recent_projects
}

fn test_facade_checkout_stays_omitted() {
	tmp, _, mut eng, mut f := setup_authoring_facade('checkout')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	assert f.checkout_blocked().contains('checkout unavailable')
}
