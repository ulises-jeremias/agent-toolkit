module main

import gg
import os

// Office desk actions must DO the work, not announce it: Enter on a selected
// desk reveals and focuses the terminal strip; the handoff path without an
// Engine stays honest instead of claiming a route.
fn desk_enter_event() &gg.Event {
	return &gg.Event{
		typ: .key_down
		key_code: .enter
	}
}

fn test_office_enter_on_desk_reveals_and_focuses_terminal() {
	prev_cache := os.getenv('XDG_CACHE_HOME')
	tmp := os.join_path(os.temp_dir(), 'desk-enter-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer {
		os.setenv('XDG_CACHE_HOME', prev_cache, true)
		os.rmdir_all(tmp) or {}
	}
	os.setenv('XDG_CACHE_HOME', tmp, true)
	mut app := &GuiApp{
		selected_panel: 0
		selected_desk: 0
		term_visible: false
		term_mode: 3
	}
	on_event(desk_enter_event(), mut app)
	assert app.term_visible, 'Enter on a desk must reveal the terminal strip'
	assert app.ghost_focused, 'Enter on a desk must focus terminal typing'
	assert app.inspector_msg.contains('focused'), 'message must describe the real outcome: ${app.inspector_msg}'
}

fn test_office_empty_start_link_jumps_to_jobs_spawn() {
	mut app := &GuiApp{
		selected_panel: 0
	}
	office_empty_start_activate(mut app)
	assert app.selected_panel == 6, 'start link must land on Operations Jobs'
	assert app.operations_focus == 3, 'start link must focus the spawn field'
	assert app.inspector_msg.contains('Enter spawns'), 'start message must name the action: ${app.inspector_msg}'
}

fn test_office_empty_start_rect_matches_draw_advance() {
	l := OfficeLayout{
		side_x: 300
	}
	ex, ey, ew, eh := office_empty_start_rect(l, 500)
	// draw paints the prefix at side_x+12 and the link right after it
	assert ex == 300 + 12 + 'No runs recorded — '.len * 6, 'link x must follow the prefix advance'
	assert ew == 'start your first job →'.len * 6, 'link width must cover the link text'
	assert ey <= 500 + 22 && 500 + 22 <= ey + eh, 'link rect must cover the text baseline'
}

fn test_terminal_strip_toggle_hides_and_restores() {
	prev_cache := os.getenv('XDG_CACHE_HOME')
	tmp := os.join_path(os.temp_dir(), 'term-toggle-${os.getpid()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	defer {
		os.setenv('XDG_CACHE_HOME', prev_cache, true)
		os.rmdir_all(tmp) or {}
	}
	os.setenv('XDG_CACHE_HOME', tmp, true)
	mut app := &GuiApp{
		term_mode: 0
		term_visible: true
	}
	toggle_terminal_strip(mut app)
	assert app.term_mode == 3, 'toggle must hide the strip'
	assert !app.term_visible, 'visibility derives from the mode'
	toggle_terminal_strip(mut app)
	assert app.term_mode == 0, 'toggle must restore the strip'
	assert app.term_visible, 'visibility derives from the mode'
}

fn test_office_handoff_without_engine_stays_honest() {
	mut app := &GuiApp{
		selected_panel: 0
		selected_desk: 0
	}
	// desktop detached: the r shortcut must not claim a route happened
	on_event(&gg.Event{
		typ: .key_down
		char_code: u32(`r`)
	}, mut app)
	assert app.inspector_msg.contains('unavailable'), 'handoff without Engine must stay honest: ${app.inspector_msg}'
}
