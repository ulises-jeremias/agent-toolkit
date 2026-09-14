module desktop_engine

// memory_authoring_test.v — Slice D memory authoring wrappers (issue #1231).
// Behavior-named: every test states the user-visible behavior it pins.

import os

fn setup_memory_authoring_ws(tag string) (string, &Engine) {
	tmp := os.join_path(os.temp_dir(), 'desk-mem-${tag}-${os.getpid()}')
	os.rmdir_all(tmp) or {}
	workspace := os.join_path(tmp, 'workspace')
	os.mkdir_all(os.join_path(workspace, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(workspace, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	eng.switch_workspace(workspace) or { panic(err.msg()) }
	return tmp, &eng
}

fn test_memory_add_todo_records_pending_entry() {
	tmp, mut eng := setup_memory_authoring_ws('add-todo')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	rep := eng.memory_add_entry('', 'todo', '', 'Investigate slow query in reports')
	assert rep.ok, 'todo add must succeed: ${rep.message}'
	assert rep.message.contains('Added todo')
	todos := eng.memory_todo_report('', false)
	assert todos.ok
	assert todos.message.contains('Investigate slow query in reports')
	assert todos.data['pending'] == '1'
}

fn test_memory_add_learning_is_searchable() {
	tmp, mut eng := setup_memory_authoring_ws('add-learning')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	rep := eng.memory_add_entry('', 'learning', '', 'Always run tests before committing')
	assert rep.ok, 'learning add must succeed: ${rep.message}'
	found := eng.memory_search_report('', 'tests before committing')
	assert found.ok
	assert found.data['hits'] != '0', 'added learning must be searchable'
}

fn test_memory_add_unknown_type_reports_usage() {
	tmp, mut eng := setup_memory_authoring_ws('add-badtype')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	rep := eng.memory_add_entry('', 'dream', '', 'flying')
	assert !rep.ok, 'unknown memory types must be refused'
	assert rep.message.contains('Valid types')
}

fn test_memory_add_without_workspace_is_unavailable() {
	tmp := os.join_path(os.temp_dir(), 'desk-mem-nows-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	// no switch_workspace: no active workspace — honest unavailability, never cwd-derived
	rep := eng.memory_add_entry('', 'todo', '', 'orphan entry')
	assert !rep.ok
	assert rep.message.contains('no active workspace')
}

fn test_memory_review_clean_base_reports_zero_issues() {
	tmp, mut eng := setup_memory_authoring_ws('review-clean')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	rep := eng.memory_review_report('', 90, false)
	assert rep.ok, 'empty knowledge base must review clean: ${rep.message}'
	assert rep.data['issues'] == '0'
}

fn test_memory_read_returns_file_content() {
	tmp, mut eng := setup_memory_authoring_ws('read')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	added := eng.memory_add_entry('', 'learning', '', 'Read-path learning')
	assert added.ok
	body := eng.memory_read_file('', 'knowledge/learnings/general.md') or {
		panic('read must succeed: ${err.msg()}')
	}
	assert body.contains('Read-path learning')
}

fn test_memory_read_refuses_paths_outside_knowledge() {
	tmp, mut eng := setup_memory_authoring_ws('read-escape')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	if _ := eng.memory_read_file('', '../AGENTS.md') {
		assert false, 'reads above knowledge/ must be refused'
	} else {
		assert err.msg().contains('harness_root_escape') || err.msg().contains('outside knowledge')
	}
}

fn test_memory_read_refuses_non_markdown() {
	tmp, mut eng := setup_memory_authoring_ws('read-nonmd')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(tmp, 'workspace', 'knowledge', 'notes.txt'), 'plain') or {
		panic(err.msg())
	}
	if _ := eng.memory_read_file('', 'knowledge/notes.txt') {
		assert false, 'non-markdown reads must be refused'
	} else {
		assert err.msg().contains('markdown only')
	}
}

fn test_memory_delete_removes_knowledge_file() {
	tmp, mut eng := setup_memory_authoring_ws('delete')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	target := os.join_path(tmp, 'workspace', 'knowledge', 'scratch.md')
	os.write_file(target, '# Scratch\n') or { panic(err.msg()) }
	rev := eng.memory_delete_file('', 'knowledge/scratch.md') or {
		panic('delete must succeed: ${err.msg()}')
	}
	assert rev > 0
	assert !os.exists(target), 'deleted memory file must be gone'
}

fn test_memory_delete_missing_file_errors() {
	tmp, mut eng := setup_memory_authoring_ws('delete-missing')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	if _ := eng.memory_delete_file('', 'knowledge/ghost.md') {
		assert false, 'deleting a missing memory must fail'
	} else {
		assert err.msg().contains('not found')
	}
}
