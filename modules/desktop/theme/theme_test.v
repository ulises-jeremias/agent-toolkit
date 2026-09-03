module theme

// Ink values are the approved warm-dark spec (#1097): panels #201D18,
// cards #26231E, borders #3E3830, text #F4EFE6 / #B3A995. Cabinet stays
// the existing near-black so chrome never moves between themes.
fn test_ink_theme_values() {
	t := ink_theme()
	assert t.is_dark()
	assert t.colors.surface_canvas == '#201D18'
	assert t.colors.surface_paper == '#26231E'
	assert t.colors.surface_cabinet == '#171C1F'
	assert t.colors.text_primary == '#F4EFE6'
	assert t.colors.text_secondary == '#B3A995'
	assert t.colors.signal_selection == '#D9A648'
}

// Paper (light) values are unchanged by the Ink addition.
fn test_paper_theme_values_unchanged() {
	t := light_theme()
	assert t.is_light()
	assert t.colors.surface_paper == '#FFF9ED'
	assert t.colors.text_primary == '#252A2D'
}

// Existing toggle/light/dark contract is preserved.
fn test_toggle_contract_preserved() {
	assert default_theme().is_dark()
	assert light_theme().is_light()
	assert default_theme().toggle().is_light()
	assert light_theme().toggle().is_dark()
}
