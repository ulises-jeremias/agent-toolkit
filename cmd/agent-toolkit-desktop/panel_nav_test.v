module main

import gg

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
	// VC5: the four Library tabs share one search field, so Agents filters too
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
