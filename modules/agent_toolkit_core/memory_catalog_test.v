module agent_toolkit_core

import os

fn setup_catalog_ws(tag string) string {
	base := os.join_path(os.temp_dir(), 'atk-memcat-${tag}-${os.getpid()}')
	os.rmdir_all(base) or {}
	init := run_workspace(WorkspaceOptions{
		subcommand: 'init'
		dir: base
	})
	if !init.ok {
		panic(init.message)
	}
	return base
}

fn test_list_empty_knowledge_is_empty() {
	base := os.join_path(os.temp_dir(), 'atk-memcat-empty-${os.getpid()}')
	os.rmdir_all(base) or {}
	os.mkdir_all(os.join_path(base, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	defer {
		os.rmdir_all(base) or {}
	}
	entries := list_memory_entries(base) or { panic(err.msg()) }
	assert entries.len == 0
}

fn test_list_and_read_after_add() {
	base := setup_catalog_ws('roundtrip')
	defer {
		os.rmdir_all(base) or {}
	}
	added := add_memory_entry(base, 'learning', '', 'Catalog row #veb')
	assert added.ok, added.message
	assert added.path == 'knowledge/learnings/general.md'
	entries := list_memory_entries(base) or { panic(err.msg()) }
	assert entries.len >= 1
	mut found := false
	for e in entries {
		if e.id == 'knowledge/learnings/general.md' {
			found = true
			assert e.kind == 'learning'
			assert e.body == ''
			assert e.snippet.contains('Catalog row')
			assert e.provenance.file == e.id
			assert e.provenance.project == os.file_name(base)
			assert e.provenance.author == ''
			assert e.provenance.agent == ''
			assert 'veb' in e.tags
		}
	}
	assert found
	read := read_memory_entry(base, 'knowledge/learnings/general.md') or { panic(err.msg()) }
	assert read.body.contains('Catalog row')
	assert read.provenance.timestamp.len == 10
}

fn test_search_requires_query_and_finds_line() {
	base := setup_catalog_ws('search')
	defer {
		os.rmdir_all(base) or {}
	}
	if _ := search_memory_entries(base, '  ') {
		assert false, 'empty query must fail'
	}
	add_memory_entry(base, 'todo', '', 'Follow up catalog search')
	hits := search_memory_entries(base, 'catalog search') or { panic(err.msg()) }
	assert hits.len >= 1
	assert hits[0].path.starts_with('knowledge/')
	assert hits[0].line > 0
	assert hits[0].kind == 'todo'
}

fn test_read_refuses_escape_and_non_markdown() {
	base := setup_catalog_ws('escape')
	defer {
		os.rmdir_all(base) or {}
	}
	if _ := read_memory_entry(base, '../AGENTS.md') {
		assert false, 'escape must fail'
	} else {
		assert err.msg().contains('invalid path') || err.msg().contains('outside knowledge')
	}
	os.write_file(os.join_path(base, 'knowledge', 'notes.txt'), 'plain') or { panic(err.msg()) }
	if _ := read_memory_entry(base, 'knowledge/notes.txt') {
		assert false, 'non-markdown must fail'
	} else {
		assert err.msg().contains('markdown only')
	}
}

fn test_edit_then_archive() {
	base := setup_catalog_ws('edit-arch')
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'knowledge', 'scratch.md'), '# Scratch\n\nold\n') or {
		panic(err.msg())
	}
	edited := edit_memory_entry(base, 'knowledge/scratch.md', '# Scratch\n\nnew #tag\n') or {
		panic(err.msg())
	}
	assert edited.ok
	assert edited.path == 'knowledge/scratch.md'
	read := read_memory_entry(base, 'knowledge/scratch.md') or { panic(err.msg()) }
	assert read.body.contains('new #tag')
	assert 'tag' in read.tags
	arch := archive_memory_entry(base, 'knowledge/scratch.md') or { panic(err.msg()) }
	assert arch.ok
	assert arch.path == 'knowledge/archive/scratch.md'
	assert !os.is_file(os.join_path(base, 'knowledge', 'scratch.md'))
	assert os.is_file(os.join_path(base, 'knowledge', 'archive', 'scratch.md'))
	if _ := archive_memory_entry(base, 'knowledge/archive/scratch.md') {
		assert false, 'second archive must fail'
	} else {
		assert err.msg().contains('already archived')
	}
}

fn test_missing_workspace_is_error() {
	if _ := list_memory_entries('/nonexistent/atk-memcat-ws') {
		assert false
	} else {
		assert err.msg().contains('workspace not found')
	}
}
