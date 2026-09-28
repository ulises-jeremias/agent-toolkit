module main

import desktop

// Overview-room desks answer clicks through last frame's hit rects, and the
// roster names active runs no desk owns instead of contradicting Idle pills.

// office_room_click dispatches on recorded rects only — no draw needed.
fn test_office_room_click_selects_hit_desk() {
	mut app := &GuiApp{
		selected_desk: -1
		inspector_msg: 'stale'
		room_desk_rects: [
			RoomDeskHit{x: 10, y: 10, w: 60, h: 60, desk_idx: 0},
			RoomDeskHit{x: 100, y: 10, w: 60, h: 60, desk_idx: 1},
		]
	}
	assert office_room_click(mut app, 130, 40), 'click inside desk 1 rect must be consumed'
	assert app.selected_desk == 1, 'click must select the hit desk'
	assert app.inspector_msg == '', 'selection must clear the inspector message like the floor map'
}

fn test_office_room_click_miss_selects_nothing() {
	mut app := &GuiApp{
		selected_desk: 0
		room_desk_rects: [
			RoomDeskHit{x: 10, y: 10, w: 60, h: 60, desk_idx: 0},
		]
	}
	assert !office_room_click(mut app, 500, 500), 'click outside every rect must fall through'
	assert app.selected_desk == 0, 'a miss must not move the selection'
}

fn test_office_room_click_empty_room_selects_nothing() {
	mut app := &GuiApp{
		selected_desk: -1
	}
	assert !office_room_click(mut app, 10, 10), 'a shrunken/emptied room records no rects'
	assert app.selected_desk == -1
}

fn test_office_room_click_last_drawn_wins_overlap() {
	mut app := &GuiApp{
		selected_desk: -1
		room_desk_rects: [
			RoomDeskHit{x: 10, y: 10, w: 60, h: 60, desk_idx: 0},
			RoomDeskHit{x: 40, y: 40, w: 60, h: 60, desk_idx: 1},
		]
	}
	assert office_room_click(mut app, 50, 50)
	assert app.selected_desk == 1, 'overlapping rects resolve to the last-drawn desk'
}

fn run_row(state desktop.OfficeRunState, agent string) desktop.OfficeRunRow {
	return desktop.OfficeRunRow{
		kind: 'job'
		id: 'r-${agent}-${state.key()}'
		state: state
		agent: agent
	}
}

fn test_office_roster_unattached_counts_active_without_owner() {
	rows := [
		run_row(.running, ''),
		run_row(.waiting, 'ghost-agent'),
		run_row(.needs_me, ''),
		run_row(.blocked, 'implementer'),
	]
	assert office_roster_unattached(['implementer', 'reviewer'], rows) == 3, 'running/waiting/needs-me without a roster owner count; the owned blocked row does not'
}

fn test_office_roster_unattached_ignores_terminal_states() {
	rows := [
		run_row(.failed, ''),
		run_row(.idle, ''),
		run_row(.unknown, 'nobody'),
	]
	assert office_roster_unattached(['implementer'], rows) == 0, 'failed/idle/unknown are attention or noise, never working-right-now'
}

fn test_office_roster_unattached_empty_agent_never_owned() {
	rows := [run_row(.running, '')]
	assert office_roster_unattached([''], rows) == 1, 'an empty catalog id owns nothing'
	assert office_roster_unattached([], rows) == 1
}
