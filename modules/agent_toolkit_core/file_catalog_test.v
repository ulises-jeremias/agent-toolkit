module agent_toolkit_core

import os

fn setup_files_ws(tag string) string {
	base := os.join_path(os.temp_dir(), 'atk-files-${tag}-${os.getpid()}')
	os.rmdir_all(base) or {}
	os.mkdir_all(os.join_path(base, 'src')) or { panic(err.msg()) }
	os.write_file(os.join_path(base, 'AGENTS.md'), '# Workspace\nhello files\n') or { panic(err.msg()) }
	os.write_file(os.join_path(base, 'src', 'main.v'), 'fn main() {}\n') or { panic(err.msg()) }
	os.write_file(os.join_path(base, '.env'), 'SECRET=1\n') or { panic(err.msg()) }
	os.mkdir_all(os.join_path(base, '.git')) or { panic(err.msg()) }
	os.write_file(os.join_path(base, '.git', 'HEAD'), 'ref: refs/heads/main\n') or { panic(err.msg()) }
	return base
}

fn test_list_skips_git_and_masks_env() {
	base := setup_files_ws('list')
	defer {
		os.rmdir_all(base) or {}
	}
	got := list_workspace_files(base, '', 2) or { panic(err.msg()) }
	assert got.ok
	assert got.root == '.'
	mut names := []string{}
	mut env_masked := false
	for n in got.nodes {
		names << n.name
		if n.path == '.env' {
			assert n.masked
			env_masked = true
		}
		assert n.path != 'HEAD'
		assert !n.path.starts_with('.git')
	}
	assert 'AGENTS.md' in names
	assert 'src' in names
	assert 'main.v' in names
	assert env_masked
}

fn test_read_masks_secret_and_rejects_escape() {
	base := setup_files_ws('read')
	defer {
		os.rmdir_all(base) or {}
	}
	masked := read_workspace_file(base, '.env') or { panic(err.msg()) }
	assert masked.masked
	assert masked.content == ''
	text := read_workspace_file(base, 'AGENTS.md') or { panic(err.msg()) }
	assert text.content.contains('hello files')
	assert !text.masked
	if _ := read_workspace_file(base, '../etc/passwd') {
		assert false
	} else {
		assert err.msg().contains('invalid path') || err.msg().contains('outside')
	}
}

fn test_search_and_atomic_write() {
	base := setup_files_ws('write')
	defer {
		os.rmdir_all(base) or {}
	}
	if _ := search_workspace_files(base, '  ') {
		assert false
	}
	hits := search_workspace_files(base, 'hello files') or { panic(err.msg()) }
	assert hits.hits.len >= 1
	assert hits.hits[0].path == 'AGENTS.md'
	wrote := write_workspace_file(base, 'src/note.md', '# Note\nnew row\n') or { panic(err.msg()) }
	assert wrote.ok
	assert wrote.path == 'src/note.md'
	read := read_workspace_file(base, 'src/note.md') or { panic(err.msg()) }
	assert read.content.contains('new row')
	if _ := write_workspace_file(base, 'src/note.md', 'x\x00y') {
		assert false
	} else {
		assert err.msg().contains('binary')
	}
}

fn test_symlink_escape_rejected() {
	base := setup_files_ws('link')
	outside := os.join_path(os.temp_dir(), 'atk-files-out-${os.getpid()}')
	os.rmdir_all(outside) or {}
	os.mkdir_all(outside) or { panic(err.msg()) }
	os.write_file(os.join_path(outside, 'secret.txt'), 'leak\n') or { panic(err.msg()) }
	defer {
		os.rmdir_all(base) or {}
		os.rmdir_all(outside) or {}
	}
	link := os.join_path(base, 'escape')
	os.symlink(outside, link) or { return }
	list := list_workspace_files(base, '', 2) or { panic(err.msg()) }
	for n in list.nodes {
		assert n.name != 'escape'
		assert !n.path.contains('secret.txt')
	}
	if _ := read_workspace_file(base, 'escape/secret.txt') {
		assert false
	} else {
		assert err.msg().contains('outside') || err.msg().contains('invalid')
	}
}

fn test_missing_workspace_is_error() {
	if _ := list_workspace_files('/nonexistent/atk-files-ws', '', 1) {
		assert false
	} else {
		assert err.msg().contains('workspace not found')
	}
}
