module main

// Paper mode must resolve every panel field to the exact startup const
// values — the scripted col_* → app.pnl_* sweep is value-preserving by
// construction, and this test locks it. If it fails, Paper goldens would
// drift; fix the mapping, never the goldens.
fn test_paper_appearance_matches_startup_consts() {
	mut app := &GuiApp{}
	app.apply_appearance(.paper)
	assert app.appearance == .paper
	assert app.appearance_dark == false
	assert app.pnl_bg == col_cream50
	assert app.pnl_card == col_cream100
	assert app.pnl_card_sel == col_manila_tab
	assert app.pnl_hover == col_paper_hover
	assert app.pnl_border == col_ink300
	assert app.pnl_border_hi == col_brass_dim
	assert app.pnl_text == col_ink
	assert app.pnl_text_mut == col_ink_soft
	assert app.pnl_text_fnt == col_steel_ink
	assert app.pnl_select == col_brass
	assert app.pnl_success == col_mint
	assert app.pnl_danger == col_coral
	assert app.pnl_select_hover == ui_selection_hover(ui_theme())
}

// Ink mode must resolve the warm-dark spec values (#1097).
fn test_ink_appearance_resolves_warm_dark() {
	mut app := &GuiApp{}
	app.apply_appearance(.ink)
	assert app.appearance == .ink
	assert app.appearance_dark == true
	assert app.pnl_bg == hex_to_gg('#26231E')
	assert app.pnl_card == hex_to_gg('#26231E')
	// derived roles resolve through the documented mixes, not raw tokens
	assert app.pnl_border == ui_line_paper(appearance_theme(.ink))
	assert app.pnl_hover == ui_hover_tint(appearance_theme(.ink))
	assert app.pnl_select_hover == ui_selection_hover(appearance_theme(.ink))
	assert app.pnl_text == hex_to_gg('#F4EFE6')
	assert app.pnl_text_mut == hex_to_gg('#B3A995')
	assert app.pnl_select == hex_to_gg('#D9A648')
	// chrome consts are untouched by the switch
	assert col_ink == hex_to_gg('#252A2D')
}

// Appearance strings round-trip through ui_state persistence.
fn test_appearance_string_round_trip() {
	assert appearance_from_string('paper') == .paper
	assert appearance_from_string('ink') == .ink
	assert appearance_from_string('system') == .system
	assert appearance_from_string('bogus') == .paper
	assert appearance_from_string('') == .paper
	assert appearance_label(.paper) == 'Paper'
	assert appearance_label(.ink) == 'Ink'
	assert appearance_label(.system) == 'System'
}

// System resolution never crashes and always yields a concrete theme.
fn test_system_appearance_resolves() {
	t := appearance_theme(.system)
	assert t.kind == .light || t.kind == .dark
	mut app := &GuiApp{}
	app.apply_appearance(.system)
	assert app.appearance == .system
	assert app.appearance_dark == (appearance_theme(.system).kind == .dark)
}
