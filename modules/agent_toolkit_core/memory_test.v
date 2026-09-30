module agent_toolkit_core

import os

fn test_memory_help() {
	r := run_memory(MemoryOptions{ subcommand: 'help' })
	assert r.ok
	assert r.message.contains('add')
	assert r.message.contains('search')
	assert r.message.contains('inject')
}

fn test_memory_add_search_inject_todo_roundtrip() {
	base := os.join_path(os.temp_dir(), 'at-mem-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert init.ok, init.message
	add := run_memory(MemoryOptions{
		subcommand: 'add'
		entry_type: 'learning'
		content: 'Always run v test before committing'
		workspace_path: base
	})
	assert add.ok, add.message
	todo := run_memory(MemoryOptions{
		subcommand: 'add'
		entry_type: 'todo'
		content: 'Follow up on memory port'
		workspace_path: base
	})
	assert todo.ok, todo.message
	search := run_memory(MemoryOptions{
		subcommand: 'search'
		content: 'v test'
		workspace_path: base
	})
	assert search.ok, search.message
	assert search.message.contains('Always run v test')
	inj := run_memory(MemoryOptions{
		subcommand: 'inject'
		workspace_path: base
	})
	assert inj.ok, inj.message
	assert inj.message.contains('Pending Todos')
	assert inj.message.contains('Recent Learnings')
	list := run_memory(MemoryOptions{
		subcommand: 'todo'
		workspace_path: base
	})
	assert list.ok, list.message
	assert list.message.contains('Follow up on memory port')
}

fn test_memory_review_duplicate_and_orphan() {
	base := os.join_path(os.temp_dir(), 'at-mem-rev-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	assert init.ok
	run_memory(MemoryOptions{
		subcommand: 'add'
		entry_type: 'learning'
		content: 'Never commit secrets to the repository ever'
		workspace_path: base
	})
	run_memory(MemoryOptions{
		subcommand: 'add'
		entry_type: 'learning'
		content: 'Never commit secrets to the repository ever'
		workspace_path: base
	})
	dup := run_memory(MemoryOptions{
		subcommand: 'review'
		workspace_path: base
	})
	assert !dup.ok
	assert dup.message.contains('Duplicate')
	os.write_file(os.join_path(base, 'knowledge', 'learnings', 'paths.md'), 'See `knowledge/missing/nope.md` for details that are long enough.\n') or {
		assert false, err.msg()
	}
	orph := run_memory(MemoryOptions{
		subcommand: 'review'
		workspace_path: base
	})
	assert !orph.ok
	assert orph.message.contains('orphan') || orph.message.contains('missing path')
}

fn test_memory_unknown_type() {
	base := os.join_path(os.temp_dir(), 'at-mem-bad-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	r := run_memory(MemoryOptions{
		subcommand: 'add'
		entry_type: 'note'
		content: 'x'
		workspace_path: base
	})
	assert !r.ok
}

fn test_memory_add_learning_keeps_table_rows_separate() {
	base := os.join_path(os.temp_dir(), 'at-mem-rows-${os.getpid()}')
	defer {
		os.rmdir_all(base) or {}
	}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir:        base
	})
	assert init.ok, init.message
	os.rm(os.join_path(base, 'knowledge', 'learnings', 'general.md')) or {}
	for content in ['first learning', 'second learning', 'third learning'] {
		r := run_memory(MemoryOptions{
			subcommand: 'add'
			entry_type: 'learning'
			content: content
			workspace_path: base
		})
		assert r.ok, r.message
	}
	text := os.read_file(os.join_path(base, 'knowledge', 'learnings', 'general.md')) or {
		panic(err)
	}
	lines := text.split('\n')
	sep := lines.index('|------|----------|---------|')
	assert sep > 0
	assert lines[sep - 1] == '| Date | Learning | Context |'
	assert lines[sep + 1].contains('| third learning | Session |')
	assert lines[sep + 2].contains('| second learning | Session |')
	assert lines[sep + 3].contains('| first learning | Session |')
	assert !text.contains('||')
	assert !text.contains('---------|\n\n')
}

fn test_insert_table_row_heals_blank_line_and_preserves_content() {
	header := '| Date | Learning | Context |'
	row := '| 2026-09-30 | new | Session |'
	legacy := '# L\n\n${header}\n|------|----------|---------|\n\n| 2026-09-29 | old | Session |\n\n## Next\n'
	assert insert_table_row(legacy, legacy.index(header) or { -1 }, header, row) == '# L\n\n${header}\n|------|----------|---------|\n${row}\n| 2026-09-29 | old | Session |\n\n## Next\n'
	empty := '${header}\n|------|----------|---------|\n\n## Next\n'
	assert insert_table_row(empty, 0, header, row) == '${header}\n|------|----------|---------|\n${row}\n\n## Next\n'
	no_sep := '${header}\n| 2026-09-29 | old | Session |\n'
	assert insert_table_row(no_sep, 0, header, row) == '${header}\n${row}\n| 2026-09-29 | old | Session |\n'
	bare := header
	assert insert_table_row(bare, 0, header, row) == '${header}\n${row}\n'
}
