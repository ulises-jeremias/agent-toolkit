module main

import desktop
import desktop.nav
import gg
import os
import time

// nav_key_event synthesizes a printable key press the way sokol/X11 delivers
// it after .char replay: a .key_down carrying both char_code and key_code.
fn nav_key_event(c u32) &gg.Event {
	return &gg.Event{
		typ: .key_down
		char_code: c
	}
}

fn test_is_panel_nav_key() {
	for r in [`0`, `1`, `5`, `9`, `p`, `P`, `i`, `I`, `o`, `O`] {
		assert is_panel_nav_key(u32(r)), 'nav key must be recognized: ${r.str()}'
	}
	for r in [`x`, `a`, `/`, ` `, `f`, `-`, `+`] {
		assert !is_panel_nav_key(u32(r)), 'filter text must not be a nav key: ${r.str()}'
	}
}

// Filter panels must not swallow documented panel shortcuts: digits and
// p/i/o always navigate, other printables filter. Regression test for the
// golden-tour trap where keys 3..o typed into the Skills filter instead of
// switching panels (fixtures panel-02+ captured the wrong content).
fn test_panel_nav_from_skills() {
	mut app := &GuiApp{
		selected_panel: 1
	}
	on_event(nav_key_event(u32(`3`)), mut app)
	assert app.selected_panel == 2, 'digit 3 must leave Skills for Agents, got panel ${app.selected_panel}'
	assert app.skills_query == '', 'nav digit must not pollute the filter: ${app.skills_query}'

	on_event(nav_key_event(u32(`x`)), mut app)
	assert app.selected_panel == 2, 'filter char must not navigate'
	// the four Library tabs share one search field, so Agents filters too
	assert app.skills_query == 'x', 'Library tabs share the search field, got: ${app.skills_query}'
	app.skills_query = ''

	app.selected_panel = 1
	on_event(nav_key_event(u32(`x`)), mut app)
	assert app.selected_panel == 1, 'filter char must stay on Skills'
	assert app.skills_query == 'x', 'ordinary letters must still filter, got: ${app.skills_query}'

	on_event(nav_key_event(u32(`p`)), mut app)
	assert app.selected_panel == 10, 'p must jump to Products, got panel ${app.selected_panel}'
}

// The Library search field owns the letters the global shortcuts use (h =
// help, r = handoff) while a Library panel is active — otherwise "github" or
// "review" cannot be typed. Outside the Library, h still toggles help.
fn test_library_search_owns_h_and_r() {
	mut app := &GuiApp{
		selected_panel: 3
	}
	for c in 'hr' {
		on_event(nav_key_event(u32(c)), mut app)
	}
	assert app.skills_query == 'hr', 'h and r must reach the Library search, got: ${app.skills_query}'
	assert !app.show_help, 'h must not toggle help while the Library search has focus'
	on_event(nav_key_event(u32(` `)), mut app)
	assert app.skills_query == 'hr ', 'space must be typed into the search, got: ${app.skills_query}'

	mut office := &GuiApp{
		selected_panel: 0
	}
	on_event(nav_key_event(u32(`h`)), mut office)
	assert office.show_help, 'h still toggles help outside the Library'
}

fn test_panel_nav_from_mcp_and_workspace() {
	mut app := &GuiApp{
		selected_panel: 3
	}
	on_event(nav_key_event(u32(`i`)), mut app)
	assert app.selected_panel == 12, 'i must jump to Insights, got panel ${app.selected_panel}'
	assert app.skills_query == '', 'nav letter must not pollute the MCP filter'

	app.selected_panel = 3
	on_event(nav_key_event(u32(`o`)), mut app)
	assert app.selected_panel == 11, 'o must jump to Onboarding, got panel ${app.selected_panel}'

	mut wapp := &GuiApp{
		selected_panel: 9
	}
	on_event(nav_key_event(u32(`4`)), mut wapp)
	assert wapp.selected_panel == 3, 'digit 4 must leave Workspace for MCP, got panel ${wapp.selected_panel}'
	assert wapp.memory_query == '', 'nav digit must not pollute the memory query'
}

// The /onboarding deep-link (palette "Go to Onboarding") must open the
// setup-journey overlay, not the Settings panel that owns index 11.
// Regression test for the panel-11 collision: panel_index_for(onboarding)
// is -1, so activation takes the explicit overlay path (same as `o`).
fn test_palette_onboarding_opens_overlay_not_settings() {
	scratch_dir := os.join_path(os.temp_dir(), 'atk-onboarding-nav-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(scratch_dir) or { panic(err.msg()) }
	defer {
		os.rmdir_all(scratch_dir) or {}
	}
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: desktop.DesktopConfig{
			headless: true
		}
		persist_path: os.join_path(scratch_dir, 'state.json')
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
	app.palette_open = true
	app.palette_query = 'onboarding'
	rows := filtered_palette(mut app)
	mut idx := -1
	for i, r in rows {
		if r.is_entity && r.panel == nav.PanelId.onboarding {
			idx = i
			break
		}
	}
	assert idx >= 0, 'Go to Onboarding row must be reachable through the registry'
	app.palette_selected = idx
	activate_palette_selection(mut app)
	assert app.show_onboarding, 'onboarding registry row must open the overlay, not Settings'
	assert app.selected_panel == 11
	assert !app.palette_open
}
