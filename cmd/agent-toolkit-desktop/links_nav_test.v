module main

// Text-link contract (E2): footer 'see …' pointers and empty-state hints
// navigate through recorded OfficeNavLink rects. Zero rects and zero
// targets never consume a click.

fn test_office_nav_link_hit_guards() {
	hot := OfficeNavLink{x: 10, y: 10, w: 100, h: 18, target: 6}
	assert office_nav_link_hit(hot, 50, 19)
	assert !office_nav_link_hit(hot, 500, 500)
	assert !office_nav_link_hit(OfficeNavLink{}, 10, 10), 'zero link never hits'
	assert !office_nav_link_hit(OfficeNavLink{x: 10, y: 10, w: 100, h: 18}, 50, 15), 'zero target never hits'
}

fn test_office_nav_link_fire_navigates() {
	mut app := &GuiApp{
		selected_panel: 0
		room_ops_link: OfficeNavLink{x: 10, y: 760, w: 200, h: 18, target: 6}
	}
	assert office_nav_link_fire(mut app, app.room_ops_link, 100, 769), 'footer click must be consumed'
	assert app.selected_panel == 6, 'footer must land on Operations'
}

fn test_office_nav_link_fire_miss_falls_through() {
	mut app := &GuiApp{
		selected_panel: 0
		room_ops_link: OfficeNavLink{x: 10, y: 760, w: 200, h: 18, target: 6}
	}
	assert !office_nav_link_fire(mut app, app.room_ops_link, 600, 100)
	assert app.selected_panel == 0, 'a miss must not navigate'
	assert !office_nav_link_fire(mut app, OfficeNavLink{}, 10, 760), 'stale zero links never fire'
}

fn test_insights_hint_target_names_first_action() {
	assert insights_hint_target('cost') == 6
	assert insights_hint_target('spans') == 6
	assert insights_hint_target('budgets') == 6
	assert insights_hint_target('realtime') == 6
	assert insights_hint_target('waterfall') == 2, 'timing rows come from the catalog'
	assert insights_hint_target('gallery') == 11, 'gallery tokens live in settings'
	assert insights_hint_target('ci') == 0, 'CI names no destination in this build'
	assert insights_hint_target('unknown') == 0
}

fn test_insights_detail_link_wins_table_link() {
	mut app := &GuiApp{
		selected_panel: 12
		insights_link: OfficeNavLink{x: 300, y: 400, w: 400, h: 30, target: 6}
		insights_detail_link: OfficeNavLink{x: 900, y: 200, w: 200, h: 46, target: 2}
	}
	assert office_nav_link_fire(mut app, app.insights_detail_link, 950, 220)
	assert app.selected_panel == 2, 'detail sentence jumps to its own target'
}
