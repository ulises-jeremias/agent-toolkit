module memory

// memory_authoring_test.v — Slice D memory browser authoring (issue #1231).
// Behavior-named: search/read/add/edit/delete/review/todo plus guards.

import desktop.theme
import desktop_engine
import os

fn setup_memory_vm(tag string) (string, string, &desktop_engine.Engine, &MemoryPalaceViewModel) {
	tmp := os.join_path(os.temp_dir(), 'desk-memvm-${tag}-${os.getpid()}')
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
	th := theme.default_theme()
	mut vm := new_memory_viewmodel(eng, th)
	return tmp, workspace, eng, vm
}

fn test_memory_browser_add_and_recall_roundtrip() {
	tmp, _, mut eng, mut vm := setup_memory_vm('roundtrip')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	rep := vm.add_entry('todo', '', 'Browser roundtrip todo')
	assert rep.ok, 'browser add must succeed: ${rep.message}'
	vm.set_query('roundtrip')
	assert vm.count() >= 1, 'added entry must be recallable'
	_ = eng
}

fn test_memory_browser_read_returns_entry_file() {
	tmp, _, mut eng, mut vm := setup_memory_vm('read')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	added := vm.add_entry('learning', '', 'Browser read learning')
	assert added.ok
	body := vm.read_entry('knowledge/learnings/general.md') or {
		panic('browser read must succeed: ${err.msg()}')
	}
	assert body.contains('Browser read learning')
	_ = eng
}

fn test_memory_browser_review_and_todo_reports() {
	tmp, _, mut eng, mut vm := setup_memory_vm('reports')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	review := vm.review_report(90, false)
	assert review.ok, 'clean base must review clean: ${review.message}'
	todos := vm.todo_report(false)
	assert todos.ok
	_ = eng
}

fn test_memory_browser_search_report_finds_entries() {
	tmp, _, mut eng, mut vm := setup_memory_vm('search')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	added := vm.add_entry('todo', '', 'Searchable browser todo item')
	assert added.ok
	found := vm.search_report('Searchable browser')
	assert found.ok
	assert found.message.contains('Searchable browser')
	_ = eng
}

fn test_memory_browser_delete_succeeds_when_clean_and_idle() {
	tmp, workspace, mut eng, mut vm := setup_memory_vm('delete-ok')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	target := os.join_path(workspace, 'knowledge', 'doomed.md')
	os.write_file(target, '# Doomed\n') or { panic(err.msg()) }
	assert vm.guard_reason() == '', 'clean idle tree must not block: ${vm.guard_reason()}'
	rev := vm.delete_entry('knowledge/doomed.md') or {
		panic('clean idle delete must succeed: ${err.msg()}')
	}
	assert rev > 0
	assert !os.exists(target)
	_ = eng
}

fn test_memory_browser_delete_refused_while_agent_runs() {
	tmp, workspace, mut eng, mut vm := setup_memory_vm('delete-running')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'knowledge', 'doomed.md'), '# Doomed\n') or {
		panic(err.msg())
	}
	// a running job in the Engine catalog blocks destructive ops; the seed
	// stands in for the spawner (covered by spawner tests) — the guard
	// reads the catalog, which is what this test pins
	mut repo := eng.state_repo()
	mut tx := repo.begin('authoring-test-running')
	tx.set('jobs/agent-1/cmd', 'sleep 30')
	tx.set('jobs/agent-1/status', 'running')
	tx.set('jobs/agent-1/started_at', '1')
	eng.put_transaction(mut tx) or { panic(err.msg()) }
	assert vm.running_agents() == 1, 'cataloged running job must count'
	assert vm.guard_reason().contains('running'), 'guard must name the running agent'
	if _ := vm.delete_entry('knowledge/doomed.md') {
		assert false, 'delete during a run must be refused'
	} else {
		assert err.msg().contains('running')
	}
	assert os.exists(os.join_path(workspace, 'knowledge', 'doomed.md')), 'refused delete must keep the file'
}

fn test_memory_browser_delete_refused_on_dirty_tree() {
	tmp, workspace, mut eng, mut vm := setup_memory_vm('delete-dirty')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'knowledge', 'doomed.md'), '# Doomed\n') or {
		panic(err.msg())
	}
	mut repo := eng.state_repo()
	mut tx := repo.begin('authoring-test-dirty')
	tx.set('dirty_files', 'notes.md')
	eng.put_transaction(mut tx) or { panic(err.msg()) }
	assert vm.dirty_files_total() == 1
	assert vm.guard_reason().contains('dirty'), 'guard must name the dirty tree'
	if _ := vm.delete_entry('knowledge/doomed.md') {
		assert false, 'delete on a dirty tree must be refused'
	} else {
		assert err.msg().contains('dirty')
	}
}
