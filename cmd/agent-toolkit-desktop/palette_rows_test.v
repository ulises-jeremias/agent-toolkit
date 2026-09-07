module main

import desktop
import desktop.nav
import desktop.palette
import desktop_engine
import os

// test_palette_merged_rows_registry_authority verifies the S4A production
// palette data source: registry navigation rows lead in shell order, legacy
// static rows remain appended, and queries surface registry entities with
// preserved canonical identity.
fn test_palette_merged_rows_registry_authority() {
	tmp := os.join_path(os.temp_dir(), 'atk-palette-rows-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer {
		os.rmdir_all(tmp) or {}
	}
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: desktop.DesktopConfig{
			headless: true
		}
		persist_path: os.join_path(tmp, 'state.json')
	})
	d.boot() or { panic(err.msg()) }
	defer {
		d.shutdown() or {}
	}
	mut app := &GuiApp{
		desktop: d
		selected_panel: 0
		hover_panel: -1
		selected_desk: -1
		hover_desk: -1
	}
	app.palette_reg = d.palette_registry()

	// empty query: navigation rows first, in production shell order
	rows := filtered_palette(mut app)
	assert rows.len > 13
	assert rows[0].id == 'nav:/world'
	assert rows[1].id == 'nav:/skills'
	assert rows[0].is_entity
	assert rows[0].panel == nav.PanelId.world_view
	// S4C: the static command authority is retired — every row is
	// registry-shaped (known action-id prefixes), no bare legacy ids
	known_prefixes := ['nav:', 'app:', 'skill:', 'agent:', 'target:', 'mcp:', 'product:', 'pack:',
		'loop:', 'doctor:', 'job:', 'swarm_run:', 'action:']
	for r in rows {
		prefixed := known_prefixes.any(r.id.starts_with(it))
		assert prefixed, 'non-registry row id leaked into the palette: ${r.id}'
		// no fabricated rows: every row comes from the registry
		assert r.label != ''
		assert r.is_entity
	}
	// fresh engine: no fabricated runtime rows
	for r in rows {
		assert !(r.kind == .job || r.kind == .swarm_run)
	}

	// query: registry entity identity survives fuzzy matching
	app.palette_query = 'doctor'
	qrows := filtered_palette(mut app)
	assert qrows.len > 0
	mut nav_doctor := false
	for r in qrows {
		if r.is_entity && r.kind == .navigation && r.panel == nav.PanelId.doctor {
			nav_doctor = true
		}
	}
	assert nav_doctor

	// query with no matches: no fallback rows invented
	app.palette_query = 'zzz_no_match_42'
	assert filtered_palette(mut app).len == 0
}

// test_panel_index_for_matches_production_panels locks the registry → shell
// panel index mapping.
fn test_panel_index_for_matches_production_panels() {
	assert panel_index_for(nav.PanelId.world_view) == 0
	assert panel_index_for(nav.PanelId.skills) == 1
	assert panel_index_for(nav.PanelId.agents) == 2
	assert panel_index_for(nav.PanelId.mcp) == 3
	assert panel_index_for(nav.PanelId.targets) == 4
	assert panel_index_for(nav.PanelId.doctor) == 5
	assert panel_index_for(nav.PanelId.jobs) == 6
	assert panel_index_for(nav.PanelId.loops) == 7
	assert panel_index_for(nav.PanelId.swarm) == 8
	assert panel_index_for(nav.PanelId.workspace) == 9
	assert panel_index_for(nav.PanelId.products) == 10
	assert panel_index_for(nav.PanelId.onboarding) == 11
	assert panel_index_for(nav.PanelId.insights) == 12
	assert panel_index_for(nav.PanelId.unknown) == -1
}

// test_nav_tr_key_preserves_localization locks the i18n key suffix mapping.
fn test_nav_tr_key_preserves_localization() {
	assert nav_tr_key(nav.PanelId.world_view) == 'world'
	assert nav_tr_key(nav.PanelId.skills) == 'skills'
	assert nav_tr_key(nav.PanelId.insights) == 'insights'
}

// test_desktop_palette_registry_is_stable_binding — one registry per Desktop,
// rebuilt from the live engine on demand.
fn test_desktop_palette_registry_is_stable_binding() {
	tmp := os.join_path(os.temp_dir(), 'atk-palette-reg-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer {
		os.rmdir_all(tmp) or {}
	}
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: desktop.DesktopConfig{
			headless: true
		}
		persist_path: os.join_path(tmp, 'state2.json')
	})
	d.boot() or { panic(err.msg()) }
	defer {
		d.shutdown() or {}
	}
	r1 := d.palette_registry()
	r2 := d.palette_registry()
	assert r1 == r2 // same binding, not a new registry per call
	_ = desktop_engine.EngineConfig{}
}
