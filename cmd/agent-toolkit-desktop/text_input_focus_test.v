module main

import gg

// text_input_focus_test.v — keyboard-routing contract regression tests.
//
// Contract (see text_input_focused): while a text-entry surface owns typing
// focus, printable keys belong to that surface — global single-letter
// shortcuts must not fire. These tests replay the exact UAT failures:
// typing "figma" in Library navigated to Insights (`i`), and typing `h`
// in the focused terminal opened Help.
//
// Each _test.v compiles as its own program, so the synthetic-event helper
// is defined locally (same delivery shape as panel_nav_test.v).
fn focus_key_event(c u32) &gg.Event {
	return &gg.Event{
		typ: .key_down
		char_code: c
	}
}

fn type_text(mut app &GuiApp, s string) {
	for c in s {
		on_event(focus_key_event(c), mut app)
	}
}

// Focused Library search must capture the whole query verbatim, including
// every global shortcut letter, without navigating anywhere.
fn test_library_search_focus_owns_full_query() {
	mut app := &GuiApp{
		selected_panel: 1
		library_search_focus: true
	}
	type_text(mut app, 'figma')
	assert app.selected_panel == 1, 'typing must stay on Library, got panel ${app.selected_panel}'
	assert app.skills_query == 'figma', 'query must be exactly "figma", got: ${app.skills_query}'
	assert !app.show_help, 'typing must not open Help'
	assert !app.palette_open, 'typing must not open the palette'
	assert !app.show_onboarding, 'typing must not open onboarding'
}

// Every documented single-letter shortcut must be inert while the search
// field owns focus — digits, p/i/o, h, r, t, g, j/k/c, f, u and /.
fn test_library_search_focus_blocks_all_shortcuts() {
	mut app := &GuiApp{
		selected_panel: 1
		library_search_focus: true
		term_visible: true
	}
	probe := '0123456789piohhrtgjkcfu/'
	type_text(mut app, probe)
	assert app.selected_panel == 1, 'no shortcut may navigate, got panel ${app.selected_panel}'
	assert app.skills_query == probe, 'every char must reach the query, got: ${app.skills_query}'
	assert !app.show_help, 'h must not open Help while typing'
	assert !app.palette_open, '/ must not open the palette while typing'
	assert !app.show_onboarding, 'o must not open onboarding while typing'
	// GuiApp defaults to term_mode 3 (hidden terminal): g must leave it there
	assert app.term_mode == 3, 'g must not toggle terminal mode while typing, got ${app.term_mode}'
}

// Unfocused panels keep legacy behavior: nav keys navigate, other letters
// filter. This pins the deliberate half of the contract.
fn test_library_unfocused_keeps_nav() {
	mut app := &GuiApp{
		selected_panel: 1
	}
	on_event(focus_key_event(u32(`i`)), mut app)
	assert app.selected_panel == 12, 'unfocused i must reach Insights, got ${app.selected_panel}'
	assert app.skills_query == '', 'nav letter must not pollute the filter'

	app.selected_panel = 1
	on_event(focus_key_event(u32(`x`)), mut app)
	assert app.skills_query == 'x', 'ordinary letters still filter when unfocused'
}

// Focused terminal owns every printable: typing "help" must reach the PTY
// in order and must not open the Help modal — the exact UAT failure.
fn test_terminal_focus_owns_help_word() {
	mut app := &GuiApp{
		selected_panel: 0
		ghost_focused: true
		term_visible: true
	}
	type_text(mut app, 'help')
	assert !app.show_help, 'typing help in the terminal must not open Help'
	assert app.ghost.input == 'help', 'PTY must receive "help" in order, got: ${app.ghost.input}'
}

// A fast representative printable run must arrive complete and ordered —
// the application layer must not drop or reorder distinct key events.
fn test_terminal_focus_fast_sequence_intact() {
	mut app := &GuiApp{
		selected_panel: 0
		ghost_focused: true
		term_visible: true
	}
	probe := '0123456789piohrtcfgu-/ echOk_9'
	type_text(mut app, probe)
	assert app.ghost.input == probe, 'PTY input must be exact and ordered, got: ${app.ghost.input}'
	assert app.selected_panel == 0, 'no shortcut may navigate while terminal focused'
	assert !app.show_help, 'no shortcut may open Help while terminal focused'
}

// Releasing focus restores global shortcuts: Esc drops Library focus,
// then `i` navigates to Insights again.
fn test_focus_release_restores_shortcuts() {
	mut app := &GuiApp{
		selected_panel: 1
		library_search_focus: true
	}
	on_event(focus_key_event(u32(`i`)), mut app)
	assert app.skills_query == 'i', 'focused i must type, got: ${app.skills_query}'

	on_event(&gg.Event{typ: .key_down, key_code: .escape}, mut app)
	assert !app.library_search_focus, 'Esc must release Library focus'
	assert app.skills_query == '', 'Esc must clear the Library query'

	on_event(focus_key_event(u32(`i`)), mut app)
	assert app.selected_panel == 12, 'released i must reach Insights, got ${app.selected_panel}'
}

// Focused memory palace search owns nav letters too; unfocused keeps nav.
fn test_memory_focus_owns_nav_letters() {
	mut app := &GuiApp{
		selected_panel: 9
		memory_search_focus: true
	}
	type_text(mut app, 'io16')
	assert app.selected_panel == 9, 'typing must stay on Workspace, got ${app.selected_panel}'
	assert app.memory_query == 'io16', 'memory query must be exact, got: ${app.memory_query}'

	mut unfocused := &GuiApp{
		selected_panel: 9
	}
	on_event(focus_key_event(u32(`4`)), mut unfocused)
	assert unfocused.selected_panel == 3, 'unfocused digit must navigate, got ${unfocused.selected_panel}'
}

// Navigating away from an Operations text field must release its focus: a
// stale operations_focus must neither swallow keys nor silence global
// shortcuts on the new panel (no owner would consume them there).
fn test_panel_switch_releases_operations_focus() {
	mut app := &GuiApp{
		selected_panel: 6
		operations_focus: 1
	}
	assert text_input_focused(app), 'operations field must own focus on its panel'
	select_panel(mut app, 0)
	assert app.operations_focus == 0, 'panel switch must release operations focus'
	assert !text_input_focused(app), 'no text surface may own focus after the switch'
	on_event(focus_key_event(u32(`h`)), mut app)
	assert app.show_help, 'shortcuts must work after leaving the operations field'
}

// Claiming a new owner releases scrollback search: an open find must not
// steal keys from the newly focused field (its handler runs before the
// panel fields), and global shortcuts must work once it is released.
fn test_focus_claim_releases_term_search() {
	mut app := &GuiApp{
		selected_panel: 1
		term_search_open: true
		term_search: 'hel'
		term_visible: true
	}
	select_panel(mut app, 1)
	assert !app.term_search_open, 'panel nav must close scrollback search'
	assert app.term_search == '', 'panel nav must clear the abandoned query'
	assert !text_input_focused(app), 'no owner may remain after release'
	on_event(focus_key_event(u32(`i`)), mut app)
	assert app.selected_panel == 12, 'shortcuts must work once search is released, got ${app.selected_panel}'
}

// Opening scrollback search claims typing focus: the previously focused
// field must release so keys stop going to it.
fn test_term_search_open_claims_focus() {
	mut app := &GuiApp{
		selected_panel: 1
		library_search_focus: true
		term_visible: true
	}
	on_event(&gg.Event{
		typ:       .key_down
		key_code:  .f
		modifiers: u32(gg.Modifier.ctrl)
	}, mut app)
	assert app.term_search_open, 'Ctrl+F must open scrollback search'
	assert !app.library_search_focus, 'opening search must release the field'
	assert text_input_focused(app), 'search must own focus after opening'
}

// Escape precedence: with Help open and terminal focused, Esc closes Help
// first and keeps terminal focus (documented modal precedence).
fn test_escape_closes_help_before_releasing_terminal() {
	mut app := &GuiApp{
		selected_panel: 0
		ghost_focused: true
		term_visible: true
		show_help: true
	}
	on_event(&gg.Event{typ: .key_down, key_code: .escape}, mut app)
	assert !app.show_help, 'Esc must close Help first'
	assert app.ghost_focused, 'terminal keeps focus after Esc closes Help'
}
