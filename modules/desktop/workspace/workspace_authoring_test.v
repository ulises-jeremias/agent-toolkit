module workspace

// workspace_authoring_test.v — Slice D file/run/project foundations (issue #1231).
// Behavior-named: open/tabs/read/dirty/save/errors/binary + run/project binding.

import desktop.theme
import desktop_engine
import os

fn setup_workspace_vm(tag string) (string, string, &desktop_engine.Engine, &WorkspaceViewModel) {
	tmp := os.join_path(os.temp_dir(), 'desk-wsvm-${tag}-${os.getpid()}')
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
	mut vm := new_workspace_viewmodel(eng, workspace, th)
	return tmp, workspace, eng, vm
}

fn test_workspace_open_tracks_tabs_with_dirty_state() {
	tmp, workspace, mut eng, mut vm := setup_workspace_vm('tabs')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'notes.md'), '# Notes\n') or { panic(err.msg()) }
	idx := vm.open_file(os.join_path(workspace, 'notes.md')) or {
		panic('open must succeed: ${err.msg()}')
	}
	assert vm.tabs_count() == 1
	assert vm.active_tab_index() == idx
	title, dirty, syntax := vm.tab_state(idx)
	assert title == 'notes.md'
	assert !dirty, 'freshly opened tabs are clean'
	assert syntax == 'md'
	assert vm.active_tab_content().contains('Notes')
}

fn test_workspace_edit_marks_dirty_and_save_clears() {
	tmp, workspace, mut eng, mut vm := setup_workspace_vm('edit-save')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'notes.md'), '# Notes\n') or { panic(err.msg()) }
	vm.open_file(os.join_path(workspace, 'notes.md')) or { panic(err.msg()) }
	assert vm.mark_active_dirty('# Notes\n\nedited\n')
	_, dirty, _ := vm.tab_state(vm.active_tab_index())
	assert dirty, 'staged edits must mark the tab dirty'
	rev := vm.save_active_tab() or { panic('save must succeed: ${err.msg()}') }
	assert rev > 0
	_, clean, _ := vm.tab_state(vm.active_tab_index())
	assert !clean, 'successful save must clear the dirty flag'
	assert os.read_file(os.join_path(workspace, 'notes.md')) or { '' }.contains('edited')
}

fn test_workspace_save_refuses_secrets() {
	tmp, workspace, mut eng, mut vm := setup_workspace_vm('save-secret')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'notes.md'), '# Notes\n') or { panic(err.msg()) }
	vm.open_file(os.join_path(workspace, 'notes.md')) or { panic(err.msg()) }
	vm.mark_active_dirty('key = AKIA1234567890EXAMPLE')
	if _ := vm.save_active_tab() {
		assert false, 'secret-bearing saves must be refused'
	} else {
		assert err.msg().contains('secret')
	}
}

fn test_workspace_close_guarded_keeps_unsaved_work() {
	tmp, workspace, mut eng, mut vm := setup_workspace_vm('close-guarded')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	os.write_file(os.join_path(workspace, 'notes.md'), '# Notes\n') or { panic(err.msg()) }
	vm.open_file(os.join_path(workspace, 'notes.md')) or { panic(err.msg()) }
	vm.mark_active_dirty('# Notes\n\nunsaved\n')
	if _ := vm.close_tab_guarded(0, false) {
		assert false, 'closing a dirty tab without force must be refused'
	} else {
		assert err.msg().contains('unsaved')
	}
	assert vm.tabs_count() == 1, 'refused close must keep the tab'
	assert vm.close_tab_guarded(0, true) or { panic(err.msg()) }
	assert vm.tabs_count() == 0
}

fn test_workspace_preview_reports_binary_state() {
	tmp, workspace, mut eng, mut vm := setup_workspace_vm('preview-bin')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	raw := [u8(0x89), 0x50, 0x00, 0x47].bytestr() + 'payload'
	os.write_file(os.join_path(workspace, 'shot.png'), raw) or { panic(err.msg()) }
	pv := vm.preview_file(os.join_path(workspace, 'shot.png')) or {
		panic('preview must succeed: ${err.msg()}')
	}
	assert pv.binary
	assert pv.content == ''
	_ = eng
}

fn test_workspace_open_directory_is_an_error() {
	tmp, _, mut eng, mut vm := setup_workspace_vm('open-dir')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	if _ := vm.open_file(vm.harness_root_path()) {
		assert false, 'opening a directory must fail'
	} else {
		assert err.msg().contains('is directory')
	}
	_ = eng
}

fn test_workspace_project_panel_lists_and_scans() {
	tmp, _, mut eng, mut vm := setup_workspace_vm('projects')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	list := vm.project_list()
	assert list.ok, 'empty projects/ must list cleanly: ${list.message}'
	scan := vm.project_scan()
	assert scan.ok, 'scan must succeed: ${scan.message}'
	_ = eng
}

fn test_workspace_run_binding_and_project_switch() {
	tmp, _, mut eng, mut vm := setup_workspace_vm('run-bind')
	defer {
		eng.stop() or {}
		os.rmdir_all(tmp) or {}
	}
	assert vm.running_agents() == 0, 'fresh engine runs nothing'
	assert vm.current_project() == '', 'no project is bound initially'
	res := vm.switch_project('demo') or { panic('switch must succeed: ${err.msg()}') }
	assert res.project_id == 'demo'
	assert vm.current_project() == 'demo'
	assert 'demo' in vm.recent_projects()
	assert vm.guard_reason() == '', 'clean idle workspace must not block'
}
