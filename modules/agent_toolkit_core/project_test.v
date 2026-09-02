module agent_toolkit_core

import os

fn test_project_init_add_list_remove_scan() {
	base := os.join_path(os.temp_dir(), 'at-proj-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or {
		assert false, err.msg()
		return
	}
	init := run_project(ProjectOptions{
		subcommand: 'init'
		workspace_path: base
	})
	assert init.ok, init.message
	assert os.is_dir(os.join_path(base, 'repos', 'github.com'))
	assert os.is_dir(os.join_path(base, 'projects'))
	gi := os.read_file(os.join_path(base, '.gitignore')) or { '' }
	assert gi.contains('repos/')
	assert gi.contains('projects/')

	repo := os.join_path(base, 'already-cloned')
	os.mkdir_all(repo) or { assert false, err.msg() }
	os.write_file(os.join_path(repo, 'README.md'), 'x\n') or {}
	add := run_project(ProjectOptions{
		subcommand: 'add'
		workspace_path: base
		arg: repo
	})
	assert add.ok, add.message
	link := os.join_path(base, 'projects', 'already-cloned')
	assert os.is_link(link)

	list := run_project(ProjectOptions{
		subcommand: 'list'
		workspace_path: base
	})
	assert list.ok, list.message
	assert list.data['count'] == '1'
	assert list.message.contains('already-cloned')

	scan := run_project(ProjectOptions{
		subcommand: 'scan'
		workspace_path: base
	})
	assert scan.ok, scan.message
	assert scan.data['linked'] == '1'

	rm := run_project(ProjectOptions{
		subcommand: 'remove'
		workspace_path: base
		arg: 'already-cloned'
	})
	assert rm.ok, rm.message
	assert !os.exists(link)
	assert os.is_dir(repo)
}

fn test_project_clone_already_present() {
	base := os.join_path(os.temp_dir(), 'at-proj-cl-${os.getpid()}')
	os.mkdir_all(base) or { assert false, err.msg() }
	defer {
		os.rmdir_all(base) or {}
	}
	os.write_file(os.join_path(base, 'AGENTS.md'), '# ws\n') or {
		assert false, err.msg()
		return
	}
	run_project(ProjectOptions{
		subcommand: 'init'
		workspace_path: base
	})
	existing := os.join_path(base, 'repos', 'github.com', 'acme', 'demo')
	os.mkdir_all(existing) or { assert false, err.msg() }
	cl := run_project(ProjectOptions{
		subcommand: 'clone'
		workspace_path: base
		arg: 'acme/demo'
	})
	assert cl.ok, cl.message
	assert cl.message.contains('Already cloned')
	assert os.is_link(os.join_path(base, 'projects', 'demo'))
}

fn test_project_help() {
	r := run_project(ProjectOptions{
		subcommand: 'help'
	})
	assert r.ok
	assert r.message.contains('clone')
	assert r.message.contains('scan')
}
