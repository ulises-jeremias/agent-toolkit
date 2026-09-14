module main

// Library install honesty (slice C): card-state labels never claim installed
// without receipt evidence, and the fourth action rect never overlaps the
// primary row or leaves the detail column.

fn test_library_agent_state_label_never_claims_installed() {
	assert library_agent_state_label(false, false) == 'available'
	assert library_agent_state_label(false, true) == 'configured'
	assert library_agent_state_label(true, false) == 'verified'
	assert library_agent_state_label(true, true) == 'verified', 'receipt evidence wins over the flag'
	for v in [true, false] {
		for c in [true, false] {
			assert library_agent_state_label(v, c) != 'installed', 'cards must never claim installed'
		}
	}
}

fn test_library_fourth_button_rect_geometry() {
	for size in [[1280, 800], [1024, 640], [1440, 900]] {
		mut app := make_library_test_app(3)
		l := library_layout(mut app, size[0], size[1])
		bx, by, bw, bh := library_btn_rect(l, 3)
		// inside the detail column
		assert bx >= l.side_x + 16, 'fourth button starts inside the column at ${size}'
		assert bx + bw <= l.side_x + l.side_w - 16, 'fourth button ends inside the column at ${size}'
		// on its own row under the primary row — never overlapping it
		px, py, _, ph := library_btn_rect(l, 0)
		assert by >= py + ph + 8, 'fourth row sits below the primary row at ${size}'
		assert bh == 30
		// no overlap with any first-row button
		for i in 0 .. 3 {
			ox, oy, ow, oh := library_btn_rect(l, i)
			overlap := bx < ox + ow && ox < bx + bw && by < oy + oh && oy < by + bh
			assert !overlap, 'fourth button must not overlap button ${i} at ${size}'
		}
		_ = px
	}
}

fn test_library_fourth_button_hover_code() {
	assert library_ui_fourth == library_ui_primary + 3, 'fourth hover code follows the button row'
	assert library_ui_fourth != library_ui_primary
	assert library_ui_fourth != library_ui_second
	assert library_ui_fourth != library_ui_third
}
