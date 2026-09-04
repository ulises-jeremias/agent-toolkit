module main

// Swarm topology helpers — recency truth + artifact parsing (#1101).
fn test_swarm_edge_artifact_parsing() {
	assert swarm_edge_artifact('planner → implementer via GOD mailbox (artifact task-contract.md)') == 'task-contract.md'
	assert swarm_edge_artifact('implementer → reviewer commit a3f9… (GOD queued)') == ''
	assert swarm_edge_artifact('no arrow here') == ''
	assert swarm_edge_artifact('a → b (artifact deep/path.md) trailing') == 'deep/path.md'
	assert swarm_edge_artifact('') == ''
}

fn test_swarm_working_roles_recency() {
	mock := ['planner → implementer via GOD mailbox (artifact task-contract.md)',
		'implementer → reviewer commit a3f9… (GOD queued)',
		'reviewer → architect feedback blocked max_round_trips']
	w := swarm_working_roles(mock)
	assert w.len == 2
	assert 'reviewer' in w
	assert 'architect' in w
	assert swarm_working_roles([]string{}).len == 0
	assert swarm_working_roles(['garbage line']) == []string{}
}

fn test_swarm_role_desk_mapping() {
	app := &GuiApp{}
	assert swarm_role_desk(app, 'planner') == 1
	assert swarm_role_desk(app, 'implementer') == 4
	assert swarm_role_desk(app, 'reviewer') == 5
	assert swarm_role_desk(app, 'architect') == 2
	assert swarm_role_desk(app, 'no-such-role') == -1
}

fn test_swarm_zoom_geom_buttons() {
	zx, zy, px, py, zw, zh := swarm_zoom_geom(208, 52, 772, 186)
	assert zx == 208 + 772 - 150
	assert px == 208 + 772 - 122
	assert zy == 186 + 8 && py == 186 + 8
	assert zw == 24 && zh == 18
	assert zx + zw < px
}

fn test_swarm_esc_exits_attach_restoring_mode() {
	mut app := &GuiApp{}
	app.term_mode = 2
	app.term_view = 1
	app.term_mode_saved = 3
	esc_desk_fullscreen(mut app)
	assert app.term_mode == 3
	assert app.term_view == -1
	assert app.term_mode_saved == -1
	assert app.inspector_msg.contains('back to panel')
	// plain MAX + desk tab without attach drops to the fleet feed instead
	mut plain := &GuiApp{}
	plain.term_mode = 2
	plain.term_view = 4
	esc_desk_fullscreen(mut plain)
	assert plain.term_mode == 2
	assert plain.term_view == -1
}
