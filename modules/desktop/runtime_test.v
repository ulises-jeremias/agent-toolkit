module desktop

import os
import desktop.runtime.jobs
import desktop.runtime.loops
import desktop.runtime.workspace
import desktop.theme
import desktop_engine
import desktop_engine.eventbus

fn test_runtime_viewmodels_via_engine_no_shell() {
	tmp := os.join_path(os.temp_dir(), 'desk-runtime-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init()!
	eng.start()!
	defer { eng.stop() or {} }
	mut bus := eventbus.new_event_bus()
	mut jvm := jobs.new_jobs_viewmodel(mut eng, bus)
	id := jvm.spawn('echo', ['hello']) or { panic(err.msg()) }
	assert id.len > 0
	assert jvm.all_jobs().len >= 1
	_ = jvm.logs(id)
	_ = jvm.cancel(id) or { panic(err.msg()) }
	assert jvm.app_state_projection().revision >= 1
	mut lvm := loops.new_loops_viewmodel(mut eng, bus)
	assert lvm.all_loops().len == 10
	loop0 := lvm.all_loops()[0]
	_ = lvm.validate(loop0.name, 'goal: test\nbudget: 100')
	_ = lvm.upsert(loop0) or { panic(err.msg()) }
	_ = lvm.toggle_cron(loop0.name, true) or { panic(err.msg()) }
	_ = lvm.run(loop0.name) or { panic(err.msg()) }
	assert lvm.history(loop0.name).len >= 1
	board := lvm.mission_board()
	assert board.len > 0
	mut wvm := workspace.new_workspace_viewmodel(mut eng)
	// no workspace configured → honest empty tree (never toolkit-root-derived)
	assert wvm.all_nodes().len == 0, 'no configured workspace yields an empty tree'
	// configure a real workspace → nodes reflect real directories
	ws := os.join_path(tmp, 'ws')
	os.mkdir_all(os.join_path(ws, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(ws, 'knowledge', 'note.md'), '# real\n') or { panic(err.msg()) }
	eng.switch_workspace(ws) or { panic(err.msg()) }
	wvm.refresh()
	assert wvm.all_nodes().len >= 1, 'real workspace yields real nodes'
	_ = wvm.memory('')
	harness := tmp
	os.mkdir_all(os.join_path(tmp, 'knowledge')) or {}
	ok := wvm.open_path(harness, os.join_path(tmp, 'knowledge')) or { panic(err.msg()) }
	assert ok.len > 0
	if _ := wvm.open_path(harness, '/etc/passwd') {
		assert false, 'escape blocked'
	} else {
		assert err.msg().contains('harness_root_escape')
	}
	th := theme.default_theme()
	assert jvm.theme_tokens(th).is_dark()
	assert lvm.theme_tokens(th).is_dark()
	assert wvm.theme_tokens(th).is_dark()
	assert eng.api_call_count() > 0
}

fn test_headless_boot_honest_empty_and_stubbed_dialogs() {
	prev := os.getenv('ATK_GUI_HEADLESS')
	os.setenv('ATK_GUI_HEADLESS', '1', true)
	defer {
		if prev == '' {
			os.unsetenv('ATK_GUI_HEADLESS')
		} else {
			os.setenv('ATK_GUI_HEADLESS', prev, true)
		}
	}
	assert is_headless_env(), 'ATK_GUI_HEADLESS=1 forces headless (DISPLAY-independent)'
	cfg := default_desktop_config()
	assert cfg.headless, 'default config honors ATK_GUI_HEADLESS=1'
	tmp := os.join_path(os.temp_dir(), 'desk-headless-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	mut d := new_desktop(DesktopBootArgs{
		config: DesktopConfig{
			title: 'Headless Empty Test'
			width: 1280
			height: 800
			headless: true
		}
		persist_path: os.join_path(tmp, 'state.json')
	})
	assert d.is_headless()
	// honest-empty before boot: no toasts recorded, nothing fabricated
	assert d.toast_count() == 0
	assert d.last_toast() == ''
	d.boot() or { panic(err.msg()) }
	defer { d.shutdown() or {} }
	assert d.is_running(), 'ATK_GUI_HEADLESS boot must go green without a window'
	// stubbed dialogs never block headless — always none, never a fake path
	if _ := d.open_file_dialog('*.md') {
		assert false, 'headless open dialog must be none'
	}
	if _ := d.save_file_dialog('*.json') {
		assert false, 'headless save dialog must be none'
	}
	if _ := d.select_folder_dialog() {
		assert false, 'headless folder dialog must be none'
	}
	// honest reason present headless (seam truth, never a fabricated path)
	reason := d.dialog_unavailable_reason()
	assert reason.len > 0, 'headless must explain the stubbed dialog'
	assert reason.contains('HeadlessBackend') || reason.contains('headless'), 'reason names the stub: ${reason}'
	// toast fallback records in-app (visible headless and windowed)
	d.notify('headless hello')
	assert d.toast_count() == 1
	assert d.last_toast() == 'headless hello'
	// Engine authority: boot derived AppState via Engine API, no shell
	assert d.engine_api_calls() > 0
	assert d.smoke_message().contains('RUNNING')
}
