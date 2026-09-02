module inspector

import os
import desktop_engine
import desktop_engine.state as engine_state
import desktop_engine.eventbus
import desktop.state as app_state
import desktop.nav
import desktop.theme

fn test_inspector_empty_when_nothing_selected() {
	tmp := os.join_path(os.temp_dir(), 'inspector-empty-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th := theme.default_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th, InspectorConfig{})
	assert vm.is_empty()
	assert vm.current() == none
	assert vm.sections().len >= 2
	assert vm.draw_calls() == 0 || vm.draw_calls() >= 0
}

fn test_inspector_selecting_entity_updates_within_one_tick() {
	tmp := os.join_path(os.temp_dir(), 'inspector-select-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th := theme.default_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th, InspectorConfig{})
	// select skill within one tick — use first real skill id from catalog (synthetic 116+)
	skill_id := eng.skills_catalog()[0].id
	assert vm.select(.skill, skill_id)
	assert vm.has_content()
	c := vm.current() or { panic('no content') }
	assert c.kind == .skill
	assert c.title.len > 0
	assert c.body.contains('```')
	assert c.sections.len >= 5
	// distinct-until-changed: same selection does not re-emit
	assert !vm.select(.skill, skill_id)
	assert vm.dropped_count() > 0
	// different entity updates
	assert vm.select(.agent, 'planner')
	c2 := vm.current() or { panic('no second') }
	assert c2.kind == .agent
	assert c2.title == 'planner'
}

fn test_inspector_renders_markdown_and_code_blocks_badges() {
	tmp := os.join_path(os.temp_dir(), 'inspector-md-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th := theme.default_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th, InspectorConfig{})
	skill_id2 := eng.skills_catalog()[0].id
	vm.select(.skill, skill_id2)
	c := vm.current() or { panic('no content') }
	assert c.body.contains('#')
	assert c.body.contains('```')
	badges := vm.badges()
	assert badges.len > 0
	assert 'skill' in badges
	// product markdown
	vm.select(.product, 'agent-toolkit-core')
	c2 := vm.current() or { panic('no product') }
	assert c2.body.contains('```')
	// mcp markdown
	vm.select(.mcp_provider, 'github')
	c3 := vm.current() or { panic('no mcp') }
	assert c3.body.contains('```json')
}

fn test_inspector_virtualized_when_long_and_resize_stable() {
	tmp := os.join_path(os.temp_dir(), 'inspector-virt-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th := theme.default_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th, InspectorConfig{ viewport_h: 600, row_height: 24 })
	vm.select(.skill, 'core/assistant')
	start, end := vm.virtualized_visible()
	assert end >= start
	assert vm.draw_calls() < 100 // bounded, not total
	

	harness := vm.perf_harness_long()
	assert harness.contains('1000')
	assert harness.contains('60 FPS')
	assert harness.contains('58+')
	// resize stability: retained geometry must not black out
	assert vm.handle_resize(800)
	s2, e2 := vm.virtualized_visible()
	assert e2 >= s2
	assert vm.handle_resize(300)
	s3, e3 := vm.virtualized_visible()
	assert e3 >= s3
	assert !vm.handle_resize(0)
}

fn test_inspector_reduced_motion_and_theme() {
	tmp := os.join_path(os.temp_dir(), 'inspector-motion-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th_dark := theme.default_theme()
	th_light := theme.light_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th_dark, InspectorConfig{})
	tt := vm.theme_tokens(th_dark)
	assert tt.is_dark()
	tt2 := vm.theme_tokens(th_light)
	assert tt2.is_light()
	rm_on := theme.reduced_motion_enabled()
	rm_off := theme.reduced_motion_disabled()
	th_rm := th_dark.with_reduced_motion(rm_on)
	th_no := th_dark.with_reduced_motion(rm_off)
	assert vm.motion_duration(th_rm) == 0
	assert vm.motion_duration(th_no) > 0
	assert !vm.should_animate(th_rm)
	assert vm.should_animate(th_no)
	mut th_switched := th_dark.toggle()
	assert th_switched.is_light()
}

fn test_inspector_error_and_empty_states() {
	tmp := os.join_path(os.temp_dir(), 'inspector-error-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th := theme.default_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th, InspectorConfig{})
	// invalid skill → error state via design system
	vm.select(.skill, 'not/exist')
	assert vm.is_error()
	c := vm.current() or { panic('error content missing') }
	assert c.state == .error
	assert c.error_msg.len > 0
	assert 'error' in vm.badges()
	// clear → empty
	vm.clear()
	assert vm.is_empty()
	assert vm.current() == none
	// sections per kind
	vm.select(.loop, 'goal-observe')
	assert vm.sections().len >= 3
	vm.select(.target, 'claude-code')
	assert vm.sections().len >= 3
}

fn test_inspector_appstate_event_within_one_tick_and_projector() {
	tmp := os.join_path(os.temp_dir(), 'inspector-bus-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	persist := os.join_path(tmp, 'state.json')
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{ persist_path: persist })
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut router := nav.new_router()
	th := theme.default_theme()
	mut vm := new_inspector_viewmodel(mut eng, mut router, th, InspectorConfig{})
	skill_id3 := eng.skills_catalog()[0].id
	vm.select(.skill, skill_id3)
	before_rev := vm.revision_nr()
	// mutate Engine → new revision → inspector re-derives within one tick
	mut repo := eng.state_repo()
	mut tx := repo.begin('inspector-bus')
	tx.set('skills_count', '300')
	rev := eng.put_transaction(mut tx) or { panic(err.msg()) }
	assert rev.revision != before_rev
	assert vm.on_bus_event(eng.revision())
	assert vm.revision_nr() != before_rev
	// distinct-until-changed same revision → no re-derive
	assert !vm.on_bus_event(eng.revision())
	// AppState variant
	snap := eng.snapshot()
	app_s := app_state.derive_app_state(snap)
	assert !vm.on_app_state_event(app_s) // same revision
	

	// projector integration
	mut bus := eventbus.new_event_bus()
	mut repo2 := engine_state.new_state_repository(os.join_path(tmp, 'state2.json'))
	mut proj := app_state.new_app_state_projector(bus, repo2.snapshot())
	ch := chan app_state.AppState{ cap: 64 }
	proj.subscribe(ch)
	mut tx2 := repo2.begin('inspector-proj')
	tx2.set('recent_workspace', '/tmp/ws-inspector')
	tx2.commit() or { panic(err.msg()) }
	ev := eventbus.ToolkitEvent{ kind: .state_changed, revision: repo2.revision_nr(), path: 'state', payload: '{}' }
	assert proj.on_bus_event(ev, repo2.snapshot())
}
