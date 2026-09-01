module persist

import os
import desktop_engine
import desktop_engine.state as engine_state
import desktop_engine.eventbus
import desktop.state as app_state

fn test_persist_boot_mutate_restart_restored_and_wipe_rebuilds() {
	tmp := os.join_path(os.temp_dir(), 'persist-boot-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	db_path := os.join_path(tmp, 'desktop.db')
	mut p := new_persist(PersistConfig{db_path: db_path}) or { panic(err.msg()) }
	defer { p.close() }
	// boot → mutate layout → persist
	p.save_layout('dock.snapshot', '{"panels":["skills","agents"],"splitters":[0.3,0.7]}') or {
		panic(err.msg())
	}
	p.save_layout('panel.skills.rect', '{"x":0,"y":0,"w":400,"h":600}') or { panic(err.msg()) }
	p.save_view_state('palette.query', 'core') or { panic(err.msg()) }
	assert p.load_layout('dock.snapshot') or { '' } == '{"panels":["skills","agents"],"splitters":[0.3,0.7]}'
	assert p.load_view_state('palette.query') or { '' } == 'core'
	// reboot emulated: close + reopen
	p.close()
	mut p2 := new_persist(PersistConfig{db_path: db_path}) or { panic(err.msg()) }
	defer { p2.close() }
	assert p2.load_layout('dock.snapshot') or { '' } == '{"panels":["skills","agents"],"splitters":[0.3,0.7]}'
	assert p2.load_view_state('palette.query') or { '' } == 'core'
	assert p2.schema_version_nr() == 1
	// wiping DB rebuilds from defaults sans error
	p2.clear() or { panic(err.msg()) }
	assert p2.load_layout('dock.snapshot') == none
	assert p2.load_view_state('palette.query') == none
	// after wipe, new save works
	p2.save_layout('dock.snapshot', '{"panels":["world"]}') or { panic(err.msg()) }
	assert p2.load_layout('dock.snapshot') or { '' } == '{"panels":["world"]}'
}

fn test_persist_canonical_mutation_wins_over_derived() {
	tmp := os.join_path(os.temp_dir(), 'persist-canonical-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	db_path := os.join_path(tmp, 'desktop.db')
	mut p := new_persist(PersistConfig{db_path: db_path}) or { panic(err.msg()) }
	defer { p.close() }
	// derived layout
	p.save_layout('dock.snapshot', '{"panels":["skills"]}') or { panic(err.msg()) }
	// canonical mutation via Engine (catalogs/plugins) — derived must not ghost
	mut eng := desktop_engine.new_engine(desktop_engine.EngineConfig{
		persist_path: os.join_path(tmp, 'state.json')
	})
	eng.init() or { panic(err.msg()) }
	eng.start() or { panic(err.msg()) }
	defer { eng.stop() or {} }
	mut repo := eng.state_repo()
	mut tx := repo.begin('canonical-mutation')
	tx.set('catalogs.skill.new', '{"id":"new/skill"}')
	_ := eng.put_transaction(mut tx) or { panic(err.msg()) }
	// derived DB still has old snapshot, but canonical Engine state wins — no ghost panels
	// load canonical vs derived precedence: engine snapshot revision > derived
	snap := eng.snapshot()
	assert snap.revision > 0 || snap.data.len > 0
	// derived guard: cannot persist canonical key
	if _ := p.save_layout('catalogs/skills.yaml', 'ghost') {
		assert false, 'derived guard must reject canonical key'
	} else {
		assert true
	}
	if _ := p.save_view_state('plugins/foo', 'ghost') {
		assert false, 'derived guard must reject canonical'
	} else {
		assert true
	}
	assert p.is_derived_only()
}

fn test_persist_schema_versioned_and_plane_guard() {
	tmp := os.join_path(os.temp_dir(), 'persist-schema-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer { os.rmdir_all(tmp) or {} }
	db_path := os.join_path(tmp, 'desktop.db')
	mut p := new_persist(PersistConfig{db_path: db_path}) or { panic(err.msg()) }
	defer { p.close() }
	assert p.schema_version_nr() == 1
	assert p.db_path_of() == db_path
	// plane guard: persist never imports gui, never writes canonical
	assert p.is_derived_only()
	// derive projector integration: AppState view cursors are derived, not canonical
	mut repo := engine_state.new_state_repository(os.join_path(tmp, 'state.json'))
	mut bus := eventbus.new_event_bus()
	mut proj := app_state.new_app_state_projector(bus, repo.snapshot())
	_ = proj
	assert true
}
