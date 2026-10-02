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

fn test_project_file_catalog_is_scoped_to_registered_link_and_masks_secrets() {
	workspace := setup_files_ws('project-scope')
	project := os.join_path(os.temp_dir(), 'atk-project-files-${os.getpid()}')
	outside := os.join_path(os.temp_dir(), 'atk-project-files-outside-${os.getpid()}')
	os.rmdir_all(project) or {}
	os.rmdir_all(outside) or {}
	os.mkdir_all(os.join_path(project, 'src')) or { panic(err.msg()) }
	os.mkdir_all(outside) or { panic(err.msg()) }
	os.write_file(os.join_path(project, 'src', 'main.v'), 'module demo\n') or { panic(err.msg()) }
	os.write_file(os.join_path(project, '.env'), 'SECRET=never return\n') or { panic(err.msg()) }
	os.write_file(os.join_path(outside, 'secret.txt'), 'never return\n') or { panic(err.msg()) }
	defer {
		os.rmdir_all(workspace) or {}
		os.rmdir_all(project) or {}
		os.rmdir_all(outside) or {}
	}
	projects_dir := os.join_path(workspace, 'projects')
	os.mkdir_all(projects_dir) or { panic(err.msg()) }
	os.symlink(project, os.join_path(projects_dir, 'demo')) or { return }
	os.symlink(outside, os.join_path(project, 'escape')) or { return }
	listed := list_project_files(workspace, 'demo', '', 2) or { panic(err.msg()) }
	assert listed.root == '.'
	assert listed.nodes.any(it.path == 'src/main.v')
	assert !listed.nodes.any(it.path.starts_with('escape'))
	secret := read_project_file(workspace, 'demo', '.env') or { panic(err.msg()) }
	assert secret.masked
	assert secret.content == ''
	read := read_project_file(workspace, 'demo', 'src/main.v') or { panic(err.msg()) }
	assert read.content == 'module demo\n'
	if _ := read_project_file(workspace, 'demo', 'escape/secret.txt') {
		assert false
	} else {
		assert err.msg().contains('outside') || err.msg().contains('invalid')
	}
	if _ := list_project_files(workspace, '../outside', '', 2) {
		assert false
	} else {
		assert err.msg().contains('invalid project')
	}
	if _ := list_project_files(workspace, 'unregistered', '', 2) {
		assert false
	} else {
		assert err.msg().contains('project not found')
	}
}

fn test_missing_workspace_is_error() {
	if _ := list_workspace_files('/nonexistent/atk-files-ws', '', 1) {
		assert false
	} else {
		assert err.msg().contains('workspace not found')
	}
}
