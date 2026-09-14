module desktop_engine

// workspace_authoring_test.v — Slice D file/project foundations (issue #1231).
// Behavior-named: every test states the user-visible behavior it pins.

import os

fn setup_workspace_authoring(tag string) (string, string, &Engine) {
	tmp := os.join_path(os.temp_dir(), 'desk-ws-${tag}-${os.getpid()}')
	os.rmdir_all(tmp) or {}
	workspace := os.join_path(tmp, 'workspace')
	os.mkdir_all(os.join_path(workspace, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(workspace, 'AGENTS.md'), '# Workspace\n') or { panic(err.msg()) }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	eng.switch_workspace(workspace) or { panic(err.msg()) }
	return tmp, workspace, eng
}

fn test_file_preview_reads_text_with_syntax() {
	tmp, workspace, mut eng := setup_workspace_authoring('preview-text')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'notes.md'), '# Notes\n\nhello\n') or {
		panic(err.msg())
	}
	pv := eng.open_file_preview(workspace, os.join_path(workspace, 'notes.md'), 0) or {
		panic('preview must succeed: ${err.msg()}')
	}
	assert !pv.binary
	assert !pv.truncated
	assert pv.content.contains('hello')
	assert pv.syntax == 'md'
	assert pv.title == 'notes.md'
	assert pv.size > 0
}

fn test_file_preview_flags_binary_instead_of_mojibake() {
	tmp, workspace, mut eng := setup_workspace_authoring('preview-bin')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	raw := [u8(0x89), 0x50, 0x00, 0x47, 0x0D, 0x0A, 0x1A, 0x00].bytestr() + 'payload'
	os.write_file(os.join_path(workspace, 'shot.png'), raw) or { panic(err.msg()) }
	pv := eng.open_file_preview(workspace, os.join_path(workspace, 'shot.png'), 0) or {
		panic('binary preview must succeed: ${err.msg()}')
	}
	assert pv.binary, 'NUL bytes must sniff binary'
	assert pv.content == ''
}

fn test_file_preview_truncates_large_files() {
	tmp, workspace, mut eng := setup_workspace_authoring('preview-trunc')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	mut big := ''
	for _ in 0 .. 200 {
		big += '0123456789abcdef'
	}
	os.write_file(os.join_path(workspace, 'big.md'), big) or { panic(err.msg()) }
	pv := eng.open_file_preview(workspace, os.join_path(workspace, 'big.md'), 64) or {
		panic('preview must succeed: ${err.msg()}')
	}
	assert !pv.binary
	assert pv.truncated
	assert pv.content.len == 64
	assert pv.size == big.len
}

fn test_file_preview_refuses_directories() {
	tmp, workspace, mut eng := setup_workspace_authoring('preview-dir')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	if _ := eng.open_file_preview(workspace, os.join_path(workspace, 'knowledge'), 0) {
		assert false, 'previewing a directory must fail'
	} else {
		assert err.msg().contains('is directory')
	}
}

fn test_file_preview_refuses_escapes() {
	tmp, workspace, mut eng := setup_workspace_authoring('preview-escape')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	secret := os.join_path(tmp, 'secret.md')
	os.write_file(secret, 'outside') or { panic(err.msg()) }
	if _ := eng.open_file_preview(workspace, secret, 0) {
		assert false, 'previewing outside the harness root must fail'
	} else {
		assert err.msg().contains('harness_root_escape')
	}
}

fn test_project_list_empty_workspace_reports_zero() {
	tmp, _, mut eng := setup_workspace_authoring('proj-empty')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	rep := eng.project_list_report('')
	assert rep.ok, 'empty projects/ must list cleanly: ${rep.message}'
	assert rep.data['count'] == '0'
}

fn test_project_scan_reports_linked_repo() {
	tmp, workspace, mut eng := setup_workspace_authoring('proj-scan')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	repo_dir := os.join_path(workspace, 'repos', 'github.com', 'acme', 'demo')
	os.mkdir_all(repo_dir) or { panic(err.msg()) }
	os.mkdir_all(os.join_path(workspace, 'projects')) or { panic(err.msg()) }
	os.symlink(repo_dir, os.join_path(workspace, 'projects', 'demo')) or { panic(err.msg()) }
	scan := eng.project_scan_report('')
	assert scan.ok, 'scan must succeed: ${scan.message}'
	assert scan.data['linked'] == '1'
	assert scan.data['broken'] == '0'
	list := eng.project_list_report('')
	assert list.ok
	assert list.data['count'] == '1'
	assert list.message.contains('demo')
}

fn test_project_reports_unavailable_without_workspace() {
	tmp := os.join_path(os.temp_dir(), 'desk-ws-nows-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := new_engine(EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	rep := eng.project_list_report('')
	assert !rep.ok
	assert rep.message.contains('no active workspace')
}

fn test_switch_project_binds_and_tracks_recent() {
	tmp, _, mut eng := setup_workspace_authoring('switch-proj')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	res := eng.switch_project('demo') or { panic('switch must succeed: ${err.msg()}') }
	assert res.project_id == 'demo'
	assert eng.current_project() == 'demo'
	assert 'demo' in eng.recent_projects()
}

fn test_switch_project_refuses_traversal() {
	tmp, _, mut eng := setup_workspace_authoring('switch-traversal')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	if _ := eng.switch_project('../evil') {
		assert false, 'traversal project ids must be refused'
	} else {
		assert err.msg().contains('traversal')
	}
	if _ := eng.switch_project('') {
		assert false, 'empty project ids must be refused'
	} else {
		assert err.msg().contains('empty')
	}
}
