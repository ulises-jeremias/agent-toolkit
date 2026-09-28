module main

// Orientation contract: the status bar names the typing owner and the Esc
// target (mirroring dispatch branch-for-branch), and every dock group shows
// its keyboard address with the active tab child named in place.

// text_focus_owner mirrors text_input_focused, naming instead of flagging.
fn test_text_focus_owner_names_each_surface() {
	assert text_focus_owner(&GuiApp{palette_open: true}) == 'palette'
	assert text_focus_owner(&GuiApp{header_search_focus: true}) == 'header search'
	assert text_focus_owner(&GuiApp{workspace_focus: true}) == 'workspace'
	assert text_focus_owner(&GuiApp{library_search_focus: true}) == 'library search'
	assert text_focus_owner(&GuiApp{memory_search_focus: true}) == 'memory search'
	assert text_focus_owner(&GuiApp{term_search_open: true}) == 'terminal search'
	assert text_focus_owner(&GuiApp{operations_focus: 3}) == 'operations field'
	assert text_focus_owner(&GuiApp{ghost_focused: true, term_visible: true}) == 'terminal'
	assert text_focus_owner(&GuiApp{editor_focused: true}) == 'editor'
	assert text_focus_owner(&GuiApp{}) == '', 'a clean app has no typing owner'
}

fn test_text_focus_owner_first_match_wins() {
	// same priority as text_input_focused's branch order
	assert text_focus_owner(&GuiApp{palette_open: true, editor_focused: true}) == 'palette'
	assert text_focus_owner(&GuiApp{ghost_focused: true, term_visible: true, editor_focused: true}) == 'terminal'
	assert text_focus_owner(&GuiApp{ghost_focused: true, term_visible: false}) == '', 'a hidden terminal owns nothing'
}

// esc_target mirrors the on_event Esc dispatch order.
fn test_esc_target_follows_dispatch_order() {
	assert esc_target(&GuiApp{palette_open: true, show_help: true}) == 'palette'
	assert esc_target(&GuiApp{show_help: true, show_onboarding: true}) == 'help'
	assert esc_target(&GuiApp{show_onboarding: true}) == 'setup'
	assert esc_target(&GuiApp{ghost_focused: true, term_visible: true}) == 'terminal focus'
	assert esc_target(&GuiApp{term_view: 3}) == 'desk fullscreen'
	assert esc_target(&GuiApp{selected_panel: 1, skills_query: 'x'}) == 'panel search'
	assert esc_target(&GuiApp{selected_panel: 9, editor_focused: true}) == 'editor'
	assert esc_target(&GuiApp{selected_panel: 9}) == 'workspace search'
	assert esc_target(&GuiApp{doctor_preview: 'x'}) == 'dry-run preview'
	assert esc_target(&GuiApp{mcp_drawer: 'github'}) == 'MCP drawer'
	assert esc_target(&GuiApp{}) == '', 'a clean app gives Esc nothing to do'
}

fn test_esc_target_agent_session_precedes_palette_chain() {
	assert esc_target(&GuiApp{term_mode: 2, term_view: 15}) == 'agent session'
	assert esc_target(&GuiApp{term_mode: 2, term_view: 15, palette_open: true}) == 'palette', 'an open palette still wins'
	assert esc_target(&GuiApp{term_mode: 0, term_view: 15}) == 'desk fullscreen', 'MAX-mode gate matters, not the desk index'
}

// nav_group_key gives every keyed dock group its visible address. Settings
// stays keyless: 's' would hijack type-to-filter capture.
fn test_nav_group_key_addresses() {
	assert nav_group_key(0) == '1'
	assert nav_group_key(1) == '2'
	assert nav_group_key(6) == '7'
	assert nav_group_key(9) == '0'
	assert nav_group_key(12) == 'I'
	assert nav_group_key(11) == '', 'settings has no single-letter address'
	assert nav_group_key(99) == ''
}

// nav_active_child names the selected tab child with its own key.
fn test_nav_active_child_names_hidden_tabs() {
	assert nav_active_child(2) == 'Agents · 3'
	assert nav_active_child(10) == 'Products · P'
	assert nav_active_child(7) == 'Loops · 8'
	assert nav_active_child(5) == 'Doctor · 6'
	assert nav_active_child(0) == '', 'group landings name nothing'
	assert nav_active_child(9) == ''
	assert nav_active_child(12) == ''
	assert nav_active_child(11) == ''
}
