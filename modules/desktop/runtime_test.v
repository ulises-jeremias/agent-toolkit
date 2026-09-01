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
	assert wvm.all_nodes().len >= 4
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
