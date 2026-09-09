module main

import gg

// VC5 (#1173) — Library composition: geometry shared by drawing and
// hit-testing, tab↔panel mapping, text wrapping, and the keyboard contract.
// These run without a gg context (lib_layout never touches app.gg).

fn lib_test_app(panel int) &GuiApp {
	return &GuiApp{
		selected_panel: panel
		hover_panel: -1
		selected_desk: -1
		hover_desk: -1
		term_visible: true
		term_height: 148
	}
}

fn test_lib_tab_panel_mapping() {
	for i, p in lib_tab_panels {
		assert lib_is_panel(p)
		assert lib_tab_for_panel(p) == i
	}
	for p in [0, 4, 5, 6, 7, 8, 9, 11, 12] {
		assert !lib_is_panel(p), 'panel ${p} is not a Library panel'
		assert lib_tab_for_panel(p) == -1
	}
}

// The grid, tabs and chips must stay inside the panel frame, the detail
// column must not overlap the panel, and no two visible cards may overlap —
// clicks are resolved against exactly these rects.
fn test_lib_layout_geometry() {
	for size in [[1280, 800], [1024, 640], [1440, 900], [900, 600]] {
		mut app := lib_test_app(1)
		l := lib_layout(mut app, size[0], size[1])
		assert l.fx >= dock_w, 'panel starts right of the dock at ${size}'
		assert l.fx + l.fw <= l.side_x, 'panel must not overlap the detail column at ${size}'
		assert l.side_x + l.side_w == size[0], 'detail column is flush right at ${size}'
		assert l.grid_y > l.chips_y, 'grid sits under the chips at ${size}'
		assert l.grid_y + l.rows * (l.card_h + l.gap) - l.gap <= l.fy + l.fh, 'card rows fit the frame at ${size}'
		assert l.cols >= 1 && l.cols <= 4
		assert l.card_h >= 86 && l.card_h <= 128, 'card height ${l.card_h} within bounds at ${size}'
		for i in 0 .. 4 {
			tx, ty, tw, th := lib_tab_rect(l, i)
			assert tx >= l.fx && tx + tw <= l.fx + l.fw, 'tab ${i} inside frame at ${size}'
			assert ty == l.tabs_y && th == l.tabs_h
		}
		n := l.cols * l.rows
		for a in 0 .. n {
			ax, ay, aw, ah := lib_card_rect(l, a)
			assert ax >= l.fx && ax + aw <= l.fx + l.fw, 'card ${a} inside frame at ${size}'
			for b in a + 1 .. n {
				bx, by, bw, bh := lib_card_rect(l, b)
				overlap := ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah
				assert !overlap, 'cards ${a} and ${b} overlap at ${size}'
			}
		}
		if l.banner_w > 0 {
			assert l.banner_x + l.banner_w <= size[0] - 8, 'banner ends inside the window at ${size}'
			assert l.side_y == l.tabs_y, 'detail column starts under the header band when the banner spans it'
		} else {
			assert l.side_y == l.fy
		}
	}
}

// RTL mirrors the header: the detail column is flush left, the banner takes
// the left half of the content row and never reaches into the panel's right
// half where the title/subtitle block is drawn.
fn test_lib_layout_rtl_banner() {
	mut app := lib_test_app(1)
	app.lang = .ar
	l := lib_layout(mut app, 1280, 800)
	assert l.side_x == 0
	assert l.fx == l.side_w + 8
	assert l.banner_w > 0, 'banner shows at 1280 in RTL'
	assert l.banner_x == 8
	assert l.banner_x + l.banner_w <= l.fx + l.fw / 2, 'RTL banner must stop before the title half'
	assert l.side_y == l.tabs_y
}

// Chips: the same label list drives measurement, drawing and hit-testing;
// every chip has a rect inside the frame and inside the measured chip band —
// rows grow with the catalog, nothing is silently dropped.
fn test_lib_chip_rects() {
	mut app := lib_test_app(2)
	l := lib_layout(mut app, 1280, 800)
	labels := lib_chips(mut app)
	assert labels.len == 5 && labels[0] == 'All'
	for i in 0 .. labels.len {
		cx, cy, cw, ch := lib_chip_rect(l, labels, i)
		assert cw > 0, 'agent chip ${i} must fit on one row'
		assert cx >= l.fx + 12 && cx + cw <= l.fx + l.fw - 12
		assert cy >= l.chips_y && cy + ch <= l.chips_y + l.chips_h
	}
	// a long catalog-style label list on a narrow frame wraps to several
	// rows; every label still gets a rect and the band height covers them
	many := ['All', 'accessibility', 'agentic-security', 'architecture', 'cloud', 'core', 'data',
		'delivery', 'design', 'forge', 'integrations', 'loops', 'ops', 'quality', 'tooling']
	rows := lib_chip_rows_for(many, l.fx, 400)
	assert rows >= 3, 'fifteen domain chips need more than two rows at 400px, got ${rows}'
	narrow := LibLayout{
		...l
		fw: 400
		chips_h: rows * 24 + (rows - 1) * 4
	}
	for i in 0 .. many.len {
		cx, cy, cw, ch := lib_chip_rect(narrow, many, i)
		assert cw > 0, 'chip ${many[i]} must be reachable'
		assert cx >= narrow.fx + 12 && cx + cw <= narrow.fx + narrow.fw - 12
		assert cy + ch <= narrow.chips_y + narrow.chips_h
	}
	_, _, none_w, _ := lib_chip_rect(l, labels, labels.len)
	assert none_w == 0, 'out-of-range chip has no rect'
}

fn test_lib_wrap() {
	assert lib_wrap('', 20, 2).len == 0
	one := lib_wrap('short line', 20, 2)
	assert one == ['short line']
	two := lib_wrap('alpha beta gamma delta epsilon zeta eta theta', 12, 2)
	assert two.len == 2
	assert two[1].ends_with('…'), 'overflow is marked on the last line: ${two}'
	for ln in two {
		assert ln.runes().len <= 12
	}
	long := lib_wrap('supercalifragilisticexpialidocious', 10, 1)
	assert long.len == 1 && long[0].runes().len <= 10 && long[0].ends_with('…')
	assert lib_clip('abcdef', 4) == 'abc…'
	assert lib_clip('abc', 4) == 'abc'
}

fn lib_key(code gg.KeyCode, ch u32) &gg.Event {
	return &gg.Event{
		typ: .key_down
		key_code: code
		char_code: ch
	}
}

// Keyboard: typing filters on every Library tab, Esc clears search and
// filters, nav keys fall through, arrows never crash without an Engine.
fn test_library_key_contract() {
	for p in lib_tab_panels {
		mut app := lib_test_app(p)
		assert library_key(mut app, lib_key(.invalid, u32(`q`)))
		assert app.skills_query == 'q', 'panel ${p} filters typed text'
		assert !library_key(mut app, lib_key(.invalid, u32(`3`))), 'nav digit falls through on panel ${p}'
		assert app.skills_query == 'q'
		// spaces are typed, not bound to the primary action (multi-word search)
		assert library_key(mut app, lib_key(.invalid, u32(` `)))
		assert app.skills_query == 'q ', 'space must append to the query on panel ${p}'
		assert library_key(mut app, lib_key(.backspace, 0))
		assert library_key(mut app, lib_key(.backspace, 0))
		assert app.skills_query == ''
		app.skills_domain = 'design'
		app.lib_filter = 'packs'
		assert library_key(mut app, lib_key(.escape, 0))
		assert app.skills_domain == '' && app.lib_filter == ''
		assert library_key(mut app, lib_key(.down, 0))
		assert library_key(mut app, lib_key(.up, 0))
		assert library_key(mut app, lib_key(.right, 0))
		// Enter without a booted Engine is a no-op, never a crash
		assert library_key(mut app, lib_key(.enter, 0))
	}
}
