module main

import gg

// Journey rail navigation: every onboarding sidebar row is live — Get Started
// holds the journey, Help opens the shortcut overlay above the shell, and
// Settings pauses the journey onto the real Settings destination.

fn rail_center(app &GuiApp, i int) (int, int) {
	x, y, w, h := onboarding_rail_row_rect(app, 1280, 800, i)
	return x + w / 2, y + h / 2
}

fn test_onboarding_rail_rows_fit_rail_without_overlap() {
	app := &GuiApp{}
	mut prev_end := 0
	for i in 0 .. onboarding_rail_rows.len {
		x, y, w, h := onboarding_rail_row_rect(app, 1280, 800, i)
		assert x >= 8, 'rail row ${i} starts inside the rail'
		assert x + w <= 8 + dock_w, 'rail row ${i} ends inside the rail'
		assert y >= prev_end, 'rail row ${i} overlaps its neighbour'
		prev_end = y + h
	}
}

fn test_onboarding_rail_help_opens_overlay() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: 2
	}
	hx, hy := rail_center(app, 1)
	assert onboarding_click(mut app, hx, hy, 1280, 800), 'Help row click must be consumed'
	assert app.show_help, 'Help row must open the shortcut overlay'
	assert app.show_onboarding, 'opening Help must not leave the journey'
}

fn test_onboarding_rail_settings_pauses_onto_destination() {
	mut app := &GuiApp{
		show_onboarding: true
		selected_panel: 0
		onboarding_step: 1
	}
	sx, sy := rail_center(app, 2)
	assert onboarding_click(mut app, sx, sy, 1280, 800), 'Settings row click must be consumed'
	assert !app.show_onboarding, 'Settings row must leave the journey shell'
	assert app.selected_panel == 11, 'Settings row must land on the Settings destination'
	assert app.onboarding_msg.contains('resume'), 'pause message must name the resume key: ${app.onboarding_msg}'
}

fn test_onboarding_rail_get_started_holds_journey() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: 3
	}
	gx, gy := rail_center(app, 0)
	assert onboarding_click(mut app, gx, gy, 1280, 800), 'Get Started click must be consumed'
	assert app.show_onboarding, 'Get Started must hold the journey'
	assert app.selected_panel == 0, 'Get Started must not navigate'
	assert app.onboarding_step == 3, 'Get Started must not move the stage'
}

fn test_onboarding_rail_hover_tracks_rows() {
	mut app := &GuiApp{
		show_onboarding: true
	}
	for i in 0 .. onboarding_rail_rows.len {
		hx, hy := rail_center(app, i)
		onboarding_hover_at(mut app, hx, hy, 1280, 800)
		assert app.onboarding_hover == onboarding_rail_hover_base + i, 'rail row ${i} must own its hover id'
	}
}

// onboarding_key_event synthesizes a printable key press the way sokol/X11
// delivers it after .char replay. Local to this file: each _test.v compiles
// as its own binary, so panel_nav_test.v helpers are not visible here.
fn onboarding_key_event(c u32) &gg.Event {
	return &gg.Event{
		typ: .key_down
		char_code: c
	}
}

fn test_onboarding_h_key_opens_help_mid_journey() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: 1
		selected_panel: 0
	}
	on_event(onboarding_key_event(u32(`h`)), mut app)
	assert app.show_help, 'H must open Help during onboarding'
	assert app.show_onboarding, 'H must not dismiss the journey'
}
